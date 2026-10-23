extends RefCounted
## Current displayed skin only. No actor selection, contact admission or HP.
## Host supplies an isolated accepted MeleeNativeSkin object and publishes its
## owner receipt AFTER the sole writer accepts a displayed pose.
const MAX_VERTICES := 65536
const MAX_TRIANGLES := 131072
const MAX_BINDS := 1024
const MAX_MESHES := 64
const MAX_SURFACES := 128
var _actor: WeakRef
var _visual: WeakRef
var _rig: WeakRef
var _native: WeakRef
var _tree: WeakRef
var _identity: Dictionary = {}
var _receipt_meta: StringName
var _version := -1
var _ready := false
var _invalid := false
var _busy := false
var _meshes: Array[Dictionary] = []
var _ignored_meshes: Array[Dictionary] = []
var _parts: Array[Dictionary] = []
var _vertices := PackedVector3Array()
var _joints := PackedInt32Array()
var _weights := PackedFloat32Array()
var _indices := PackedInt32Array()
var _bind_bones := PackedInt32Array()
var _bind_poses: Array[Transform3D] = []
var _last_revision := -1
var _last_frames := PackedVector3Array()
var _last_visible := PackedByteArray()

static func _fail(reason: String) -> Dictionary: return {"ok":false,"error":reason}
static func _live_node(value: Variant) -> bool:
	if not is_instance_valid(value) or not value is Node or not value.is_inside_tree(): return false
	while value != null:
		if value.is_queued_for_deletion(): return false
		value=value.get_parent()
	return true
static func _json_value(value: Variant, depth: int = 0) -> bool:
	if depth>12: return false
	if value==null or value is bool or value is String or value is int: return true
	if value is float: return is_finite(value)
	if value is Array:
		if value.size()>2048: return false
		for item in value:
			if not _json_value(item,depth+1): return false
		return true
	if value is Dictionary:
		if value.size()>256: return false
		for key in value:
			if not key is String or not _json_value(value[key],depth+1): return false
		return true
	return false
static func resolve_bind(rig: Skeleton3D, skin: Skin, slot: int) -> int:
	if not is_instance_valid(rig) or skin==null or slot<0 or slot>=skin.get_bind_count(): return -1
	var name:=skin.get_bind_name(slot)
	var bone:=rig.find_bone(name) if not name.is_empty() else skin.get_bind_bone(slot)
	return bone if bone>=0 and bone<rig.get_bone_count() else -1

func configure(actor_root: Node, visual_root: Node3D, skeleton: Skeleton3D, native_skin: Object, expected_identity: Dictionary, receipt_meta: StringName = &"melee_skin_pose") -> Dictionary:
	if _ready or _busy or not Thread.is_main_thread(): return _fail("state")
	dispose()
	if not _live_node(actor_root) or not _live_node(visual_root) or not _live_node(skeleton) or not (actor_root==visual_root or actor_root.is_ancestor_of(visual_root)) or not visual_root.is_ancestor_of(skeleton): return _fail("hierarchy")
	if not is_instance_valid(native_skin) or native_skin.get_class()!="MeleeNativeSkin" or native_skin.get_script()!=null or not native_skin.has_method("skin"): return _fail("native_kernel")
	if expected_identity.size()!=2 or not expected_identity.get("actor_id") is String or expected_identity.actor_id.is_empty() or expected_identity.actor_id.length()>256 or not expected_identity.get("life_generation") is int or expected_identity.life_generation<1 or receipt_meta.is_empty(): return _fail("identity")
	if skeleton.get_bone_count()<1 or skeleton.get_bone_count()>256: return _fail("rig_capacity")
	_actor=weakref(actor_root);_visual=weakref(visual_root);_rig=weakref(skeleton);_native=weakref(native_skin)
	_identity=expected_identity.duplicate(true);_receipt_meta=receipt_meta;_version=skeleton.get_version()
	if _owner_receipt().is_empty(): dispose();return _fail("owner_receipt")
	var source_meshes:=visual_root.find_children("*","MeshInstance3D",true,false)
	if source_meshes.is_empty() or source_meshes.size()>MAX_MESHES: dispose();return _fail("mesh_capacity")
	var surface_count:=0
	var traversal_order:=-1
	for node: Node in source_meshes:
		traversal_order+=1
		var mesh:=node as MeshInstance3D
		# The source contact producer explicitly skips non-SkinnedMesh nodes.
		# Keep a lifetime guard so assigning a Skin later cannot silently add a
		# previously omitted contact surface under the same configured topology.
		if mesh.skin==null:
			_ignored_meshes.append({"node":weakref(mesh),"path":str(visual_root.get_path_to(mesh))})
			continue
		if mesh.mesh==null or mesh.skin==null or mesh.get_node_or_null(mesh.skeleton)!=skeleton or not mesh.mesh is ArrayMesh or mesh.mesh.get_blend_shape_count()!=0:
			dispose();return _fail("mesh_binding_or_blend_shape")
		var metadata:Variant=mesh.get_meta("extras",{})
		if not _json_value(metadata):dispose();return _fail("source_metadata")
		var bind_first:=_bind_poses.size();var vertex_first:=_vertices.size();var triangle_first:=_indices.size()/3
		var bindings:Array[Dictionary]=[];var head_slots:=PackedFloat32Array();var local_indices:=PackedInt32Array();var surfaces:Array[Dictionary]=[]
		if mesh.skin.get_bind_count()<1 or bind_first+mesh.skin.get_bind_count()>MAX_BINDS:dispose();return _fail("bind_capacity")
		for slot in mesh.skin.get_bind_count():
			var bone:=resolve_bind(skeleton,mesh.skin,slot);var bind:=mesh.skin.get_bind_pose(slot)
			if bone<0 or not bind.is_finite():dispose();return _fail("skin_bind")
			_bind_bones.append(bone);_bind_poses.append(bind)
			bindings.append({"slot":slot,"source_name":str(mesh.skin.get_bind_name(slot)),"source_index":mesh.skin.get_bind_bone(slot),"resolved_bone":bone,"resolved_name":str(skeleton.get_bone_name(bone))})
		for surface in mesh.mesh.get_surface_count():
			surface_count+=1
			if surface_count>MAX_SURFACES or mesh.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:dispose();return _fail("surface_type_or_capacity")
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var count:=indices.size() if not indices.is_empty() else vertices.size()
			if vertices.is_empty() or joints.size()!=vertices.size()*4 or weights.size()!=joints.size() or count%3!=0 or _vertices.size()+vertices.size()>MAX_VERTICES or _indices.size()+count>MAX_TRIANGLES*3:dispose();return _fail("surface_arrays")
			var start:=_vertices.size();var face_start:=local_indices.size()/3
			for index in vertices.size():
				if not vertices[index].is_finite():dispose();return _fail("vertex")
				for influence in 4:
					var at:=index*4+influence;var weight:=weights[at];var slot:=joints[at]
					if not is_finite(weight) or weight<0 or weight>1 or (weight>0 and (slot<0 or slot>=bindings.size())):dispose();return _fail("skin_influence")
					_joints.append(slot+bind_first);_weights.append(weight)
					head_slots.append(weight if weight>0 and bindings[slot].resolved_name=="head" else 0.0)
			_vertices.append_array(vertices)
			for at in count:
				var index:=indices[at] if not indices.is_empty() else at
				if index<0 or index>=vertices.size():dispose();return _fail("triangle_index")
				_indices.append(start+index);local_indices.append(start-vertex_first+index)
			surfaces.append({"surface_index":surface,"vertex_first":start-vertex_first,"vertex_count":vertices.size(),"face_first":face_start,"triangle_count":count/3,"original_indices":indices.duplicate(),"indexed":not indices.is_empty()})
		var order:=traversal_order;var path:=str(visual_root.get_path_to(mesh))
		_parts.append({"mesh_id":path,"mesh_name":str(mesh.name),"mesh_order":order,"vertex_first":vertex_first,"vertex_count":_vertices.size()-vertex_first,"triangle_first":triangle_first,"triangle_count":local_indices.size()/3,"indices":local_indices,"head_slot_weights":head_slots,"bindings":bindings,"surfaces":surfaces,"source_metadata":metadata.duplicate(true) if metadata is Dictionary or metadata is Array else metadata})
		_meshes.append({"node":weakref(mesh),"mesh":weakref(mesh.mesh),"skin":weakref(mesh.skin),"path":path,"skeleton":mesh.skeleton,"metadata":metadata.duplicate(true) if metadata is Dictionary or metadata is Array else metadata})
	if _meshes.is_empty():dispose();return _fail("no_skinned_mesh")
	for item:Dictionary in _meshes:
		for key in ["mesh","skin"]:
			var resource:Resource=item[key].get_ref()
			if not resource.changed.is_connected(_invalidate_resource):resource.changed.connect(_invalidate_resource)
	_tree=weakref(actor_root.get_tree());actor_root.get_tree().node_added.connect(_node_added)
	_ready=true
	return {"ok":true,"vertices":_vertices.size(),"triangles":_indices.size()/3,"meshes":_meshes.size(),"bind_slots":_bind_poses.size(),"identity":_identity.duplicate(true)}

func _owner_receipt() -> Dictionary:
	if _actor==null or not _live_node(_actor.get_ref()):return {}
	var actor:Node=_actor.get_ref();var receipt:Variant=actor.get_meta(_receipt_meta,{})
	if actor.get_meta("actor_id",null)!=_identity.get("actor_id") or actor.get_meta("life_generation",null)!=_identity.get("life_generation"):return {}
	if not receipt is Dictionary or receipt.size()!=5 or receipt.get("actor_id")!=_identity.actor_id or receipt.get("life_generation")!=_identity.life_generation:return {}
	if not receipt.get("pose_revision") is int or receipt.pose_revision<1 or not receipt.get("pose_epoch") is int or receipt.pose_epoch<0 or not receipt.get("pose_owner") is String or receipt.pose_owner.is_empty() or receipt.pose_owner.length()>128:return {}
	return receipt.duplicate(true)

func _invalidate_resource() -> void:_invalid=true
func _node_added(node:Node) -> void:
	if node is MeshInstance3D and _visual!=null and is_instance_valid(_visual.get_ref()) and _visual.get_ref().is_ancestor_of(node):_invalid=true

func _geometry_live() -> bool:
	if not _ready or _invalid or not _live_node(_actor.get_ref()) or not _live_node(_visual.get_ref()) or not _live_node(_rig.get_ref()) or not is_instance_valid(_native.get_ref()):return false
	var visual:Node=_visual.get_ref();var rig:Skeleton3D=_rig.get_ref();var actor:Node=_actor.get_ref()
	if actor.get_meta("actor_id",null)!=_identity.actor_id or actor.get_meta("life_generation",null)!=_identity.life_generation:
		_invalid=true
		return false
	if not (actor==visual or actor.is_ancestor_of(visual)) or not visual.is_ancestor_of(rig) or rig.get_version()!=_version:return false
	for item:Dictionary in _ignored_meshes:
		var mesh:Variant=item.node.get_ref()
		if not _live_node(mesh) or not visual.is_ancestor_of(mesh) or str(visual.get_path_to(mesh))!=item.path or mesh.skin!=null:return false
	for item:Dictionary in _meshes:
		var mesh:Variant=item.node.get_ref()
		if not _live_node(mesh) or not visual.is_ancestor_of(mesh) or str(visual.get_path_to(mesh))!=item.path or mesh.skeleton!=item.skeleton or mesh.get_node_or_null(mesh.skeleton)!=rig or not is_instance_valid(item.mesh.get_ref()) or not is_instance_valid(item.skin.get_ref()) or mesh.mesh!=item.mesh.get_ref() or mesh.skin!=item.skin.get_ref() or mesh.get_meta("extras",{})!=item.metadata:return false
	return true

func _visibility() -> PackedByteArray:
	var values:=PackedByteArray()
	for item:Dictionary in _meshes:
		var node:Node=item.node.get_ref();var visible:=true
		while node!=null:
			if node is Node3D and not node.visible:visible=false;break
			node=node.get_parent()
		values.append(1 if visible else 0)
	return values

func _frames() -> PackedVector3Array:
	var rig:Skeleton3D=_rig.get_ref();var world:=rig.global_transform
	if not world.is_finite():return PackedVector3Array()
	var bones:Array[Transform3D]=[]
	for bone in rig.get_bone_count():
		var frame:=world*rig.get_bone_global_pose(bone)
		if not frame.is_finite():return PackedVector3Array()
		bones.append(frame)
	var packed:=PackedVector3Array();packed.resize(_bind_poses.size()*4)
	for index in _bind_poses.size():
		var frame:=bones[_bind_bones[index]]*_bind_poses[index]
		if not frame.is_finite():return PackedVector3Array()
		packed[index*4]=frame.basis.x;packed[index*4+1]=frame.basis.y;packed[index*4+2]=frame.basis.z;packed[index*4+3]=frame.origin
	return packed

func capture(expected_pose_revision: int) -> Dictionary:
	if not Thread.is_main_thread() or _busy or expected_pose_revision<1:return _fail("state_or_revision")
	if not _geometry_live():return _fail("geometry_lifetime")
	var receipt:=_owner_receipt()
	if receipt.is_empty() or receipt.pose_revision!=expected_pose_revision or expected_pose_revision<_last_revision:return _fail("owner_receipt")
	_busy=true
	var visible:=_visibility();var frames:=_frames()
	if frames.is_empty():_busy=false;return _fail("bone_frame")
	if expected_pose_revision==_last_revision and (frames!=_last_frames or visible!=_last_visible):_busy=false;return _fail("unpublished_pose_change")
	# The accepted stateless native object cannot call GDScript or yield. No
	# arbitrary factory/validator callback is invoked in the capture interval.
	var vertices:Variant=_native.get_ref().call("skin",_vertices,_joints,_weights,frames)
	if not vertices is PackedVector3Array or vertices.size()!=_vertices.size():_busy=false;return _fail("native_skin")
	if not _geometry_live() or _owner_receipt()!=receipt or _visibility()!=visible or _frames()!=frames:_busy=false;return _fail("capture_changed")
	var parts:Array[Dictionary]=_parts.duplicate(true)
	for index in parts.size():
		parts[index].visible=visible[index]!=0
		parts[index].world_vertices=vertices.slice(parts[index].vertex_first,parts[index].vertex_first+parts[index].vertex_count)
	_last_revision=expected_pose_revision;_last_frames=frames;_last_visible=visible;_busy=false
	return {"ok":true,"vertices":vertices,"indices":_indices.duplicate(),"parts":parts,"identity":_identity.duplicate(true),"owner_receipt":receipt,"pose_revision":receipt.pose_revision,"pose_epoch":receipt.pose_epoch,"pose_owner":receipt.pose_owner,"actor_root_world":(_actor.get_ref() as Node3D).global_transform if _actor.get_ref() is Node3D else Transform3D.IDENTITY}

func current(owner_receipt: Dictionary) -> bool:
	if not Thread.is_main_thread() or _busy or not _geometry_live() or owner_receipt.is_empty():return false
	return _owner_receipt()==owner_receipt and owner_receipt.get("pose_revision")==_last_revision and _visibility()==_last_visible and _frames()==_last_frames

func invalidate() -> void:_invalid=true
func dispose() -> void:
	for item:Dictionary in _meshes:
		for key in ["mesh","skin"]:
			var resource:Variant=item[key].get_ref()
			if is_instance_valid(resource) and resource.changed.is_connected(_invalidate_resource):resource.changed.disconnect(_invalidate_resource)
	if _tree!=null:
		var tree:Variant=_tree.get_ref()
		if is_instance_valid(tree) and tree.node_added.is_connected(_node_added):tree.node_added.disconnect(_node_added)
	_ready=false;_invalid=false;_busy=false;_actor=null;_visual=null;_rig=null;_native=null;_tree=null
	_meshes.clear();_ignored_meshes.clear();_parts.clear();_vertices.clear();_joints.clear();_weights.clear();_indices.clear();_bind_bones.clear();_bind_poses.clear();_identity.clear()
	_last_revision=-1;_last_frames.clear();_last_visible.clear()
