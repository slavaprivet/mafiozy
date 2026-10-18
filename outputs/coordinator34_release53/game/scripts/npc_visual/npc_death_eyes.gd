extends RefCounted
## Presentation only: same actor/rig/material/skin weights, confirmed final death.
## Precomputed closed pose uses only original authored eye and lid surfaces.
const ASSET_DIR="res://assets/npc_visual/death_eyes/"
const MANIFEST_SHA="90d20822a859a7a19ff5785772d0dcbde3bbfb8ff15a40636f5c290af5b4131f"
var _physical:WeakRef
var _binding:Dictionary={}
var _meshes:Array[Dictionary]=[]
var _ready:=false
var _retired:=false
var _busy:=false
var closed:=false
var fault:="unconfigured"
var prepare_us:=0
var close_us:=0

static func mesh_digest(mesh:ArrayMesh)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256)
	for surface in mesh.get_surface_count():
		for stream:Variant in mesh.surface_get_arrays(surface):
			if stream!=null:h.update(stream.to_byte_array())
	return h.finish().hex_encode()

func configure(physical:RefCounted,token:Dictionary,directory:String=ASSET_DIR)->Dictionary:
	if _ready or _retired or _busy or not Thread.is_main_thread():return {"ok":false,"reason":"lifetime"}
	var started:=Time.get_ticks_usec()
	if not is_instance_valid(physical) or physical.mode!="IDLE" or not physical._is_current():return {"ok":false,"reason":"physical_lease"}
	if not token.get("rig") is Skeleton3D or token.rig.get_instance_id()!=physical._binding.rig_instance_id or token.get("bridge_id")!=physical._binding.bridge_id:return {"ok":false,"reason":"same_rig"}
	if FileAccess.get_sha256(directory+"assets_manifest.json")!=MANIFEST_SHA:return {"ok":false,"reason":"manifest_hash"}
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"assets_manifest.json"))
	if not data.actors.has(token.bridge_id):return {"ok":false,"reason":"unsupported_original_model"}
	var actor:Node=token.body
	var plans:Array[Dictionary]=[]
	for spec:Dictionary in data.actors[token.bridge_id].meshes:
		var matches:Array[Node]=actor.find_children(spec.node,"MeshInstance3D",true,false)
		if matches.size()!=1:return {"ok":false,"reason":"unique_original_mesh"}
		var node:MeshInstance3D=matches[0]
		if not node.mesh is ArrayMesh or node.mesh.get_blend_shape_count()!=0 or mesh_digest(node.mesh)!=spec.source_digest:return {"ok":false,"reason":"original_mesh_hash"}
		if FileAccess.get_sha256(directory+spec.resource)!=spec.resource_sha256:return {"ok":false,"reason":"closed_pose_hash"}
		var loaded:ArrayMesh=load(directory+spec.resource)
		if loaded==null or mesh_digest(loaded)!=spec.closed_digest:return {"ok":false,"reason":"closed_pose_streams"}
		# The geometry resource is per actor. All actual original material references
		# and material overrides remain attached; no face texture/shader is invented.
		var replacement:ArrayMesh=loaded.duplicate()
		for i in node.mesh.get_surface_count():replacement.surface_set_material(i,node.mesh.surface_get_material(i))
		plans.append({"node":weakref(node),"original":node.mesh,"closed":replacement,"skin":node.skin,"skeleton":node.skeleton,"transform":node.transform})
	if plans.size()!=2:return {"ok":false,"reason":"both_original_meshes"}
	_physical=weakref(physical);_binding=physical._binding.duplicate();_meshes=plans;_ready=true;fault=""
	prepare_us=Time.get_ticks_usec()-started
	return {"ok":true,"ready":true,"closed":false,"prepare_us":prepare_us}

func _nodes_match()->bool:
	for plan:Dictionary in _meshes:
		var node:MeshInstance3D=plan.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() or node.mesh!=(plan.closed if closed else plan.original) or node.skin!=plan.skin or node.skeleton!=plan.skeleton or node.transform!=plan.transform:return false
	return _meshes.size()==2

func close_after_confirmed_death()->bool:
	if not Thread.is_main_thread() or _busy or _retired or not _ready:return false
	_busy=true
	var started:=Time.get_ticks_usec()
	var physical:RefCounted=_physical.get_ref()
	if not is_instance_valid(physical) or physical._binding!=_binding or not physical._is_current():_busy=false;return false
	# Callback may synchronously retire/replace this controller or mesh owner.
	if _retired or not _ready or not is_instance_valid(physical) or physical.mode not in ["ACTIVE","RECOVERING"] or not physical._final_dead or physical._death_key.is_empty() or physical._binding!=_binding or not _nodes_match():_busy=false;return false
	if closed:_busy=false;return true
	for plan:Dictionary in _meshes:plan.node.get_ref().mesh=plan.closed
	closed=true;close_us=Time.get_ticks_usec()-started;_busy=false
	return true

func dispose()->void:
	if _retired:return
	_retired=true;_ready=false
	# A final corpse remains closed if physics retires while its visual survives.
	# No stale-lifetime teardown may reopen a dead face or alter a replacement.
	# MeshInstance owns the installed pose until the original actor is removed.
	_meshes.clear();_physical=null
