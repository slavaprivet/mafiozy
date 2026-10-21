extends RefCounted
## One owner per actor. The worker never receives a Node, Mesh, Skin or Material.
const Sever = preload("res://scripts/weapons/mesh_sever.gd")
const Anatomy = preload("res://scripts/combat/cut_anatomy28.gd")
const Wounds = preload("res://scripts/combat/local_wound28.gd")
const STAGE_BUDGET_USEC := 2000
var shard_count29 := 4
var thread: Thread
var context: Dictionary = {}
var metadata: Array[Dictionary] = []
var prepared: Array[Dictionary] = []
var operations: Array[Dictionary] = []
var operation_index := 0
var generation := -1
var rig_id := 0
var weapon_id := ""
var selected_token := false
var grounded_token := false
var actor_transform := Transform3D.IDENTITY
var rig_poses: Array[Transform3D] = []
var state := "idle"
var canceled := ""
var report: Dictionary = {}
var last_failed: Dictionary = {}
var warm_material: ShaderMaterial
var work_started := 0
var staging_usec := 0
var peak_stage_usec := 0
var moving_pose29 := false
var fixed_mode29 := true
var surface_cache29: Dictionary = {}
var cache_misses29 := 0

func _cached_surfaces29(mesh: ArrayMesh) -> Array:
	var key := mesh.get_instance_id()
	var row: Dictionary = surface_cache29.get(key,{})
	if not row.is_empty() and row.mesh.get_ref()==mesh and row.surfaces.size()==mesh.get_surface_count():
		return row.surfaces
	var surfaces: Array = []
	for i in mesh.get_surface_count(): surfaces.append(mesh.surface_get_arrays(i))
	surface_cache29[key]={"mesh":weakref(mesh),"surfaces":surfaces}
	cache_misses29+=1
	return surfaces

func _remember_surface29(mesh: ArrayMesh, arrays: Array) -> void:
	var key := mesh.get_instance_id()
	if not surface_cache29.has(key): surface_cache29[key]={"mesh":weakref(mesh),"surfaces":[]}
	surface_cache29[key].surfaces.append(arrays)

func _skinned_meshes29(host: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	var rig: Skeleton3D=host.get("_npc_rig")
	if not is_instance_valid(rig):return result
	for node: MeshInstance3D in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ArrayMesh or node.skin==null:continue
		for arrays: Array in _cached_surfaces29(node.mesh):
			if arrays.size()>Mesh.ARRAY_BONES and arrays[Mesh.ARRAY_BONES] is PackedInt32Array and not arrays[Mesh.ARRAY_BONES].is_empty():
				result.append(node);break
	return result

func warm(host: Node) -> void:
	# Loading owns GPU readback. Generated cut meshes retain their CPU arrays as
	# surfaces upload, so subsequent cuts do not fetch those arrays back either.
	for key in surface_cache29.keys():
		if surface_cache29[key].mesh.get_ref()==null: surface_cache29.erase(key)
	for node: MeshInstance3D in _skinned_meshes29(host):
		var surfaces := _cached_surfaces29(node.mesh)
		if bool(host.get("lab_fixed")):
			var row: Dictionary=surface_cache29[node.mesh.get_instance_id()]
			var binds: Array[Transform3D]=host.call("_cut_skin_transforms39",node,host.get("_npc_rig"))
			if row.get("binds",[])!=binds:
				row["binds"]=binds
				row["posed"]=[]
				for source: Array in surfaces:row.posed.append(_skin(source,binds,false))
				if "_FABRIC" in str(node.name):row["topology"]=Sever._body_topology29(row.posed)
	if warm_material != null: return
	var frame := {"u":Vector3.RIGHT,"v":Vector3.FORWARD,"n":Vector3.UP,"origin":Vector3.ZERO}
	host.call("_ensure_blood_resources")
	for mesh: SphereMesh in host.get("_blood_meshes"): mesh.get_rid()
	warm_material = Anatomy._material(Anatomy._anatomy(host.get("_npc_rig"),frame),{},false)

func cancel(reason: String) -> void:
	if busy() and canceled.is_empty(): canceled=reason

func busy() -> bool:
	return state != "idle"

func begin(host: Node, next_context: Dictionary) -> bool:
	if busy(): return false
	for key in surface_cache29.keys():
		if surface_cache29[key].mesh.get_ref()==null:surface_cache29.erase(key)
	if not last_failed.is_empty() and last_failed.generation == host.get("lab_resets") and last_failed.part == next_context.part:
		if Vector3(last_failed.point).distance_to(next_context.point)<0.025 and Vector3(last_failed.normal).dot(next_context.plane.normal)>0.995: return false
	var started := Time.get_ticks_usec()
	context = next_context
	fixed_mode29 = bool(host.get("lab_fixed"))
	moving_pose29 = _dynamic_pose29(host)
	var misses_before := cache_misses29
	generation = int(host.get("lab_resets"))
	var rig: Skeleton3D = host.get("_npc_rig")
	rig_id = rig.get_instance_id()
	actor_transform = host.get("_npc_body").global_transform
	weapon_id = str(host.get("_weapon_id"))
	selected_token = bool(host.get("_selected"))
	grounded_token = bool(host.get("_sword_grounded"))
	rig_poses.clear()
	for i in rig.get_bone_count(): rig_poses.append(rig.get_bone_global_pose(i))
	metadata.clear(); prepared.clear(); operations.clear(); operation_index=0
	canceled=""; staging_usec=0; peak_stage_usec=0
	# Suspend only during this synchronous snapshot, never during worker latency.
	Wounds.before_full_cut(host)
	var inputs: Array[Dictionary] = []
	for node: MeshInstance3D in _skinned_meshes29(host):
		var source: ArrayMesh = node.mesh
		var binds: Dictionary = host.call("_npc_limb_bind_ids",node,context.scope,rig)
		if binds.is_empty(): continue
		var local_plane: Plane = host.call("_plane_in_local",node,context.plane)
		var keep: Vector3 = node.to_local(context.keep)
		var surfaces: Array = _cached_surfaces29(source)
		var materials: Array[Material] = []
		for surface in source.get_surface_count():
			materials.append(node.get_active_material(surface))
		var transforms: Array[Transform3D] = host.call("_cut_skin_transforms39",node,rig)
		metadata.append({"node":weakref(node),"source":source,"skin":node.skin,"transform":node.global_transform,"materials":materials,"name":str(node.name),"visible":node.is_visible_in_tree()})
		inputs.append({"surfaces":surfaces,"binds":transforms,"part_binds":binds,"plane":local_plane,"keep_front":local_plane.distance_to(keep)>=0.0,"transform":node.global_transform,"name":str(node.name),"visible":node.is_visible_in_tree()})
		var cached: Dictionary=surface_cache29[source.get_instance_id()]
		if cached.has("topology"):inputs.back()["topology_template"]=cached.topology
		if cached.get("binds",[])==transforms and cached.has("posed"):
			inputs.back()["posed"]=cached.posed
			if cached.has("topology"):inputs.back()["topology"]=cached.topology
	Wounds.finish_full_cut(host,false)
	var normal: Vector3 = context.plane.normal.normalized()
	var u := normal.cross(Vector3.UP if absf(normal.y)<0.9 else Vector3.RIGHT).normalized()
	var frame := {"u":u,"v":normal.cross(u).normalized(),"n":normal,"origin":normal*context.plane.d}
	var anatomy := Anatomy._anatomy(rig,frame)
	var snapshot := {"layers":inputs,"scope":context.scope,"frame":frame,"anatomy":anatomy,"moving":moving_pose29,"shards":clampi(shard_count29,1,4)}
	report={"queued":true,"snapshot_usec":Time.get_ticks_usec()-started,"generation":generation,"state":"computing","moving_pose":moving_pose29,"snapshot_cache_misses":cache_misses29-misses_before}
	work_started=Time.get_ticks_usec()
	thread=Thread.new()
	var error := thread.start(_work.bind(snapshot))
	if error != OK:
		thread=null; state="idle"; report["failure"]="thread_start"; return false
	state="computing"
	return true

func _valid(host: Node) -> String:
	if host.get("_lab_reset_pending") or int(host.get("lab_resets"))!=generation: return "reset"
	var rig: Skeleton3D=host.get("_npc_rig")
	if not is_instance_valid(rig) or rig.is_queued_for_deletion() or rig.get_instance_id()!=rig_id or rig.get_bone_count()!=rig_poses.size(): return "actor_replaced"
	if str(host.get("_weapon_id"))!=weapon_id: return "weapon_changed"
	if bool(host.get("_selected"))!=selected_token: return "selection_changed"
	if bool(host.get("_sword_grounded"))!=grounded_token: return "weapon_dropped"
	if bool(host.get("lab_fixed"))!=fixed_mode29 or _dynamic_pose29(host)!=moving_pose29: return "pose_mode_changed"
	if not moving_pose29:
		if host.get("_npc_body").global_transform!=actor_transform: return "actor_moved"
		for i in rig_poses.size():
			if rig.get_bone_global_pose(i)!=rig_poses[i]: return "pose_changed"
	for row: Dictionary in metadata:
		var node: MeshInstance3D=row.node.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or node.mesh!=row.source or node.skin!=row.skin: return "source_changed"
		if not moving_pose29 and node.global_transform!=row.transform: return "source_changed"
	return ""

func poll(host: Node) -> void:
	if not busy(): return
	var started := Time.get_ticks_usec()
	_poll(host)
	report["peak_poll_usec"] = maxi(int(report.get("peak_poll_usec",0)),Time.get_ticks_usec()-started)
	if not busy(): host.set("clay_last_async28",report.duplicate(true))

func _poll(host: Node) -> void:
	if not busy(): return
	if canceled.is_empty(): canceled=_valid(host)
	if state=="computing":
		if thread.is_alive(): return
		var result: Dictionary=thread.wait_to_finish()
		thread=null
		report.merge(result.get("profile",{}),true)
		if not canceled.is_empty() or not result.get("ok",false):
			_finish(host,false,canceled if not canceled.is_empty() else result.get("reason","refused")); return
		prepared=result.layers
		for layer: Dictionary in prepared:
			var meta: Dictionary=metadata[layer.index]
			layer["body_mesh"]=ArrayMesh.new()
			layer["gone_mesh"]=ArrayMesh.new()
			for i in layer.kept.size():
				operations.append({"mesh":layer.body_mesh,"arrays":layer.kept[i],"material":meta.materials[layer.kept_indices[i]]})
			for i in layer.gone.size():
				operations.append({"mesh":layer.gone_mesh,"arrays":layer.gone[i],"material":meta.materials[layer.gone_indices[i]]})
			for side: String in ["kept_cap","gone_cap"]:
				if layer[side].is_empty(): continue
				var cap: Dictionary=layer[side+"_info"]
				operations.append({"mesh":layer.body_mesh if side=="kept_cap" else layer.gone_mesh,"arrays":layer[side],"cap":cap,"anatomy":result.anatomy,"layer":layer,"side":side})
			if not layer.kept_cap.is_empty() and layer.kept_cap_info.tissue and not meta.visible:
				layer["overlay_mesh"]=ArrayMesh.new()
				operations.append({"mesh":layer.overlay_mesh,"arrays":layer.kept_cap,"layer":layer,"reuse":"kept_cap_material"})
			if not layer.gone_cap.is_empty() and layer.gone_cap_info.tissue and not meta.visible:
				layer["detached_cap_mesh"]=ArrayMesh.new()
				operations.append({"mesh":layer.detached_cap_mesh,"arrays":layer.gone_cap,"layer":layer,"reuse":"gone_cap_material"})
		report["anatomy"]=result.anatomy_report
		state="staging"
	if not canceled.is_empty(): _finish(host,false,canceled); return
	var started:=Time.get_ticks_usec()
	while operation_index<operations.size():
		var op: Dictionary=operations[operation_index]
		if op.has("cap"):
			op["material"]=Anatomy._material(op.anatomy,op.cap,not op.cap.tissue)
			op.layer[op.side+"_material"]=op.material
		elif op.has("reuse"): op["material"]=op.layer[op.reuse]
		op.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,op.arrays)
		_remember_surface29(op.mesh,op.arrays)
		op.mesh.surface_set_material(op.mesh.get_surface_count()-1,op.material)
		operation_index+=1
		if Time.get_ticks_usec()-started>=STAGE_BUDGET_USEC: break
	var elapsed:=Time.get_ticks_usec()-started
	staging_usec+=elapsed; peak_stage_usec=maxi(peak_stage_usec,elapsed)
	if operation_index<operations.size(): return
	canceled=_valid(host)
	if not canceled.is_empty(): _finish(host,false,canceled); return
	var commit_started:=Time.get_ticks_usec()
	Wounds.before_full_cut(host)
	_commit(host)
	Wounds.finish_full_cut(host,true)
	report["commit_usec"]=Time.get_ticks_usec()-commit_started
	_finish(host,true,"")

func _finish(host: Node, success: bool, reason: String) -> void:
	report.merge({"success":success,"failure":reason,"state":"idle","total_latency_usec":Time.get_ticks_usec()-work_started,"staging_total_usec":staging_usec,"peak_stage_usec":peak_stage_usec},true)
	if not success and reason in ["body_contour_invalid","missing_half","missing_cap","nothing_crossed"]:
		last_failed={"generation":generation,"part":context.part,"point":context.point,"normal":context.plane.normal}
	else: last_failed.clear()
	host.set("clay_last_async28",report.duplicate(true))
	host.call("_clay_async_resolved28",success)
	state="idle"; metadata.clear(); prepared.clear(); operations.clear(); context.clear()

func dispose() -> void:
	# Shutdown only: a running owned worker must finish before its RefCounted owner
	# is released. Gameplay never waits on an unfinished thread.
	if thread!=null:
		thread.wait_to_finish(); thread=null
	state="idle"; metadata.clear(); prepared.clear(); operations.clear()
	surface_cache29.clear()

static func _current_bounds29(layer: Dictionary, binds: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	# Each weighted vertex is a convex combination of these transformed bind
	# boxes. Their union bounds conservatively contain the current posed piece.
	for index: int in layer.bind_bounds:
		if index>=binds.size(): continue
		var bounds: AABB = binds[index] * AABB(layer.bind_bounds[index])
		result = bounds if first else result.merge(bounds)
		first=false
	return result

static func _rest_bounds29(surfaces: Array) -> Dictionary:
	var boxes: Dictionary = {}
	for arrays: Array in surfaces:
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		for i in vertices.size():
			for k in 4:
				if weights[i*4+k]<=0.0: continue
				var index: int = bones[i*4+k]
				boxes[index] = AABB(boxes[index]).expand(vertices[i]) if boxes.has(index) else AABB(vertices[i],Vector3.ZERO)
	return boxes

func _commit(host: Node) -> void:
	var commit_phase:=Time.get_ticks_usec()
	var before: int=host.get("_npc_debris").size()
	var body:=RigidBody3D.new()
	body.name="ClayConnectedCut";body.mass=0.08*prepared.size()
	body.gravity_scale=1.0;body.freeze=false;body.sleeping=false
	body.continuous_cd=true;body.collision_layer=1;body.collision_mask=3
	var physics:=PhysicsMaterial.new();physics.friction=0.25;physics.bounce=0.0;body.physics_material_override=physics
	var first: Dictionary=prepared[0]
	var first_meta: Dictionary=metadata[first.index]
	var first_bounds: AABB=first.gone_mesh.get_aabb()
	var detached_rig: Skeleton3D
	var current_rig: Skeleton3D=host.get("_npc_rig")
	if moving_pose29:
		# Snapshot the CURRENT pose once at commit. Flattening global poses into
		# rest transforms retains full matrices, including scale/shear. Original
		# Skin bind matrices and names stay intact. This skeleton never animates.
		detached_rig=Skeleton3D.new();detached_rig.name="DetachedPose29"
		for i in current_rig.get_bone_count():
			detached_rig.add_bone(current_rig.get_bone_name(i))
			detached_rig.set_bone_rest(i,current_rig.get_bone_global_pose(i))
		detached_rig.reset_bone_poses()
		body.add_child(detached_rig)
		for layer: Dictionary in prepared:
			var row: Dictionary=metadata[layer.index]
			var node: MeshInstance3D=row.node.get_ref()
			row.transform=node.global_transform
			row["current_binds"]=host.call("_cut_skin_transforms39",node,current_rig)
			layer["current_bounds"]=_current_bounds29(layer,row.current_binds)
		first_bounds=first.current_bounds
	var world_body:=Transform3D(first_meta.transform.basis.orthonormalized(),first_meta.transform*first_bounds.get_center())
	if moving_pose29: detached_rig.transform=world_body.affine_inverse()*current_rig.global_transform
	var primary: MeshInstance3D
	for layer: Dictionary in prepared:
		var row: Dictionary=metadata[layer.index]
		var node: MeshInstance3D=row.node.get_ref()
		var bounds: AABB=layer.current_bounds if moving_pose29 else layer.gone_mesh.get_aabb()
		var visual:=MeshInstance3D.new();visual.name="KnightCutPiece";visual.mesh=layer.gone_mesh
		visual.transform=world_body.affine_inverse()*row.transform
		visual.set_meta("cut_source_mesh28",row.name);visual.set_meta("cut_source_visible28",row.visible)
		visual.visible=row.visible
		body.add_child(visual)
		if moving_pose29:
			visual.skin=row.skin;visual.skeleton=visual.get_path_to(detached_rig);visual.custom_aabb=bounds
		if layer.has("detached_cap_mesh"):
			var cap_visual:=MeshInstance3D.new();cap_visual.name="DetachedBodyCap28";cap_visual.mesh=layer.detached_cap_mesh
			cap_visual.transform=visual.transform;cap_visual.set_meta("cut_source_mesh28",row.name)
			cap_visual.set_meta("cut_source_visible28",true);body.add_child(cap_visual)
			if moving_pose29:
				cap_visual.skin=row.skin;cap_visual.skeleton=cap_visual.get_path_to(detached_rig);cap_visual.custom_aabb=bounds
		if primary==null:primary=visual
		var scale_value: Vector3=row.transform.basis.get_scale()
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(maxf(0.045,bounds.size.x*scale_value.x),maxf(0.045,bounds.size.y*scale_value.y),maxf(0.045,bounds.size.z*scale_value.z))
		shape.shape=box
		shape.transform=world_body.affine_inverse()*Transform3D(row.transform.basis.orthonormalized(),row.transform*bounds.get_center())
		body.add_child(shape)
		for i in row.source.get_surface_count():node.set_surface_override_material(i,null)
		node.material_override=null
		node.mesh=null if layer.whole else layer.body_mesh
		if layer.has("overlay_mesh"):
			var overlay:=Anatomy.BodyCap.new();overlay.name="CutAnatomyBodyCap28"
			overlay.owner_host=weakref(host);overlay.generation=generation;overlay.mesh=layer.overlay_mesh;overlay.skin=node.skin
			host.get("_npc_body").add_child(overlay);overlay.global_transform=row.transform
			overlay.skeleton=overlay.get_path_to(host.get("_npc_rig"));overlay.set_meta("cut_anatomy28",true)
		if not layer.gone_cap.is_empty():
			var world: Vector3=row.transform*layer.gone_cap[Mesh.ARRAY_VERTEX][0]
			if moving_pose29:
				world=row.transform*_skin(layer.anchor,row.current_binds,false)[Mesh.ARRAY_VERTEX][0]
			host.get("_clay_cap_points").append(world)
			var rest: Array=layer.anchor
			host.get("_clay_cap_sites").append({"mesh":weakref(node),"kept_mesh":weakref(node.mesh),"rest":rest[Mesh.ARRAY_VERTEX][0],"bones":rest[Mesh.ARRAY_BONES].slice(0,4),"weights":rest[Mesh.ARRAY_WEIGHTS].slice(0,4),"world":world})
		host.call("_record_actor_cut50",host.get("_npc_rig"))
	if moving_pose29:
		report["detached_pose_bones"]=detached_rig.get_bone_count()
		report["pose_changed_during_job"]=false
		for i in rig_poses.size():
			if current_rig.get_bone_global_pose(i)!=rig_poses[i]: report["pose_changed_during_job"]=true
		report["actor_moved_during_job"]=host.get("_npc_body").global_transform!=actor_transform
	report["commit_build_usec"]=Time.get_ticks_usec()-commit_phase;commit_phase=Time.get_ticks_usec()
	host.get("_world").add_child(body);body.global_transform=world_body
	host.call("_lab_debris_ignore_owner28",body)
	body.linear_velocity=context.plane.normal.normalized()*randf_range(0.6,1.8)+Vector3.UP*randf_range(0.2,0.8)
	body.angular_velocity=Vector3(randf_range(-2,2),randf_range(-2,2),randf_range(-2,2))
	body.set_meta("lab_expire_ms28",Time.get_ticks_msec()+3000)
	host.get("_npc_debris").append({"node":body,"visual":primary,"age":0.0})
	report["commit_insert_usec"]=Time.get_ticks_usec()-commit_phase;commit_phase=Time.get_ticks_usec()
	if context.head_gone:
		for anchor: Node in host.get("_npc_rig").find_children("*","BoneAttachment3D",true,false):
			if str(anchor.bone_name) not in ["head","socket_head"]:continue
			for child: Node in anchor.get_children():
				if not child is Node3D or child is CollisionObject3D or child is CollisionShape3D:continue
				if not child.find_children("*","CollisionObject3D",true,false).is_empty():continue
				var visuals: Array[Node]=child.find_children("*","MeshInstance3D",true,false)
				if child is MeshInstance3D:visuals.append(child)
				var rigid:=not visuals.is_empty()
				for item: Node in visuals:
					if item.skin!=null:rigid=false
				if rigid:child.reparent(body,true)
	report["commit_head_usec"]=Time.get_ticks_usec()-commit_phase;commit_phase=Time.get_ticks_usec()
	host.set("clay_last_anatomy",report.anatomy)
	host.call("_clay_complete_cut28",context,before,true,true)
	report["commit_finish_usec"]=Time.get_ticks_usec()-commit_phase
	report["finish_profile"]=host.get("clay_commit_profile28").duplicate()

static func _skin(source: Array, binds: Array, undo: bool) -> Array:
	var arrays:=source.duplicate(true)
	if arrays.is_empty() or binds.is_empty():return arrays
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
	if bones==null or weights==null or bones.size()!=vertices.size()*4:return arrays
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
	for i in vertices.size():
		var x:=Vector3.ZERO;var y:=Vector3.ZERO;var z:=Vector3.ZERO;var origin:=Vector3.ZERO;var total:=0.0
		for k in 4:
			var weight:float=weights[i*4+k];var index:int=bones[i*4+k]
			if weight<=0.0 or index<0 or index>=binds.size():continue
			var bind:Transform3D=binds[index]
			x+=bind.basis.x*weight;y+=bind.basis.y*weight;z+=bind.basis.z*weight;origin+=bind.origin*weight;total+=weight
		var matrix:=Transform3D(Basis(x,y,z),origin)
		if total<0.001 or absf(matrix.basis.determinant())<0.0000001:continue
		if undo:matrix=matrix.affine_inverse()
		vertices[i]=matrix*vertices[i]
		if normals.size()==vertices.size():normals[i]=(matrix.basis.inverse().transposed()*normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX]=vertices
	if not normals.is_empty():arrays[Mesh.ARRAY_NORMAL]=normals
	return arrays

static func _cap_info(arrays: Array, layer: Dictionary, frame: Dictionary) -> Dictionary:
	var uv:=PackedVector2Array()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var world: Vector3=layer.transform*vertex-Vector3(frame.origin)
		uv.append(Vector2(world.dot(frame.u),world.dot(frame.v)))
	var bounds:=Rect2(uv[0],Vector2.ZERO)
	for point: Vector2 in uv:bounds=bounds.expand(point)
	return {"source":layer.name,"visible":layer.visible,"bounds":bounds,"arrays":arrays,"uv":uv}

static func _work_shard29(snapshot: Dictionary, lane: int) -> Dictionary:
	var started:=Time.get_ticks_usec();var skin_us:=0;var cut_us:=0;var inverse_us:=0
	var layer_profiles: Array=[]
	var layers: Array[Dictionary]=[];var caps: Array=[]
	for index in range(lane,snapshot.layers.size(),int(snapshot.shards)):
		var input: Dictionary=snapshot.layers[index]
		var layer_started:=Time.get_ticks_usec()
		var posed: Array=[];var phase:=Time.get_ticks_usec()
		if input.has("posed"):posed=input.posed
		else:
			for source: Array in input.surfaces:posed.append(_skin(source,input.binds,false))
		skin_us+=Time.get_ticks_usec()-phase;phase=Time.get_ticks_usec()
		var topology:Dictionary=input.get("topology",{})
		if topology.is_empty() and input.has("topology_template"):topology=Sever._repose_body_topology29(posed,input.topology_template)
		var cut=Sever.cut_surfaces28(posed,input.plane,input.part_binds,input.keep_front,topology)
		layer_profiles.append({"name":input.name,"cut_usec":Time.get_ticks_usec()-phase,"elapsed_usec":Time.get_ticks_usec()-layer_started})
		cut_us+=Time.get_ticks_usec()-phase
		if cut.body_contour_invalid:return {"ok":false,"reason":"body_contour_invalid"}
		var kept: Array=cut.front_arrays if input.keep_front else cut.back_arrays
		var gone: Array=cut.back_arrays if input.keep_front else cut.front_arrays
		var kept_cap: Array=cut.front_cap_arrays if input.keep_front else cut.back_cap_arrays
		var gone_cap: Array=cut.back_cap_arrays if input.keep_front else cut.front_cap_arrays
		var disconnected: bool=cut.triangles_split==0 and not gone.is_empty()
		if cut.triangles_split==0 and not disconnected:continue
		if not disconnected:
			if kept.is_empty() or gone.is_empty():return {"ok":false,"reason":"missing_half"}
			if kept_cap.is_empty() or gone_cap.is_empty():
				if snapshot.scope!="_clay_torso" or not input.name.begins_with("Armor") or not cut.open_boundary_verified:return {"ok":false,"reason":"missing_cap"}
				kept_cap=[];gone_cap=[]
		var layer: Dictionary={"index":index,"kept":[],"gone":gone,"kept_cap":[],"gone_cap":gone_cap,"whole":kept.is_empty() and disconnected,"kept_indices":cut.front_surface_indices if input.keep_front else cut.back_surface_indices,"gone_indices":cut.back_surface_indices if input.keep_front else cut.front_surface_indices,"anchor":[]}
		phase=Time.get_ticks_usec()
		for arrays: Array in kept:layer.kept.append(_skin(arrays,input.binds,true))
		if not kept_cap.is_empty():
			var info:=_cap_info(kept_cap,input,snapshot.frame)
			layer["kept_cap_info"]=info;caps.append(info)
			layer.kept_cap=_skin(kept_cap,input.binds,true)
			layer.kept_cap[Mesh.ARRAY_TEX_UV2]=info.uv
		if not gone_cap.is_empty():
			var info:=_cap_info(gone_cap,input,snapshot.frame)
			layer["gone_cap_info"]=info
			# Same planar section/volume ranking applies to both halves.
			gone_cap[Mesh.ARRAY_TEX_UV2]=info.uv
			var anchor:=gone_cap.duplicate()
			for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL]:
				if anchor[slot]!=null:anchor[slot]=anchor[slot].slice(0,1)
			for slot in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:anchor[slot]=anchor[slot].slice(0,4)
			layer.anchor=_skin(anchor,input.binds,true)
		if snapshot.moving:
			# Both retained and detached halves stay in material coordinates. GPU
			# skinning applies the same current pose to both halves at commit.
			layer.gone=[]
			for arrays: Array in gone: layer.gone.append(_skin(arrays,input.binds,true))
			if not gone_cap.is_empty(): layer.gone_cap=_skin(gone_cap,input.binds,true)
			var bounded: Array=layer.gone.duplicate()
			if not layer.gone_cap.is_empty(): bounded.append(layer.gone_cap)
			layer["bind_bounds"]=_rest_bounds29(bounded)
		inverse_us+=Time.get_ticks_usec()-phase
		layers.append(layer)
	return {"ok":true,"layers":layers,"caps":caps,"profile":{"skin_usec":skin_us,"cut_usec":cut_us,"inverse_usec":inverse_us,"layer_profiles":layer_profiles,"shard_usec":Time.get_ticks_usec()-started}}

static func _work(snapshot: Dictionary) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var workers: Array[Thread]=[]
	var results: Array[Dictionary]=[]
	# Owned helpers plus this worker. They only read immutable snapshots,
	# each returns its own result; there is no shared mutable output to lock.
	# Only this background parent joins children. Main polls its outer Thread.
	for lane in range(1,int(snapshot.shards)):
		var child:=Thread.new()
		if child.start(_work_shard29.bind(snapshot,lane))==OK:workers.append(child)
		else:results.append(_work_shard29(snapshot,lane))
	results.append(_work_shard29(snapshot,0))
	for child: Thread in workers:results.append(child.wait_to_finish())
	var layers: Array[Dictionary]=[]
	var caps: Array=[]
	var layer_profiles: Array=[]
	var skin_us:=0;var cut_us:=0;var inverse_us:=0
	for result: Dictionary in results:
		if not result.ok:return result
		layers.append_array(result.layers)
		caps.append_array(result.caps)
		layer_profiles.append_array(result.profile.layer_profiles)
		skin_us+=result.profile.skin_usec;cut_us+=result.profile.cut_usec;inverse_us+=result.profile.inverse_usec
	layers.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.index<b.index)
	var anatomy_report: Dictionary={"ok":not layers.is_empty(),"bone_sections":snapshot.anatomy.starts.size(),"skull":snapshot.anatomy.skull_enabled,"async":true,"caps":0,"tissue_caps":0,"garment_rims":0,"body_cap_overlays":0,"cap_vertices":0}
	for layer: Dictionary in layers:
		for side: String in ["kept_cap","gone_cap"]:
			if layer[side].is_empty():continue
			var info: Dictionary=layer[side+"_info"]
			info["tissue"]=Anatomy._is_main_volume(info,caps)
			if not info.tissue:info["boundary"]=Anatomy._boundary(info.arrays,info.uv)
			anatomy_report.caps+=1;anatomy_report.cap_vertices+=info.uv.size()
			if info.tissue:anatomy_report.tissue_caps+=1
			else:anatomy_report.garment_rims+=1
			if side=="kept_cap" and info.tissue and not info.visible:anatomy_report.body_cap_overlays+=1
	return {"ok":not layers.is_empty(),"reason":"nothing_crossed" if layers.is_empty() else "","layers":layers,"anatomy":snapshot.anatomy,"anatomy_report":anatomy_report,"profile":{"worker_usec":Time.get_ticks_usec()-started,"skin_usec":skin_us,"cut_usec":cut_us,"inverse_usec":inverse_us,"layer_profiles":layer_profiles,"parallel_shards":snapshot.shards}}

static func _dynamic_pose29(host: Node) -> bool:
	return not bool(host.get("lab_fixed")) or (host.has_method("_clay_dynamic_pose29") and bool(host.call("_clay_dynamic_pose29")))
