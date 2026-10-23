extends RefCounted
## Bounded external 32-mark runtime. The host owns hit/raycast/HP authority and
## supplies a frozen planner receipt in the target mesh's explicit local frame.

const Geometry=preload("res://scripts/transport/transport_damage_mark_geometry.gd")
const Plan=preload("res://scripts/transport/transport_damage_mark_plan.gd")
const Pose=preload("res://scripts/transport/transport_source_mark_pose.gd")
const POOL_SIZE:=Plan.POOL_SIZE
const MAX_BINDINGS:=4096

var _configured:=false
var _disposed:=false
var _generation:=0
var _cursor:=0
var _vehicle_root: Node3D
var _external_parent: Node3D
var _effects_root: Node3D
var _bindings: Dictionary={}
var _slots: Array[MeshInstance3D]=[]
var _slot_sources: Array[StringName]=[]
var _slot_local_poses: Array[Transform3D]=[]
var _slot_active:=PackedByteArray()
var _prepared: Dictionary={}
var _resources_dirty:=false

func configure(vehicle_root_value: Variant,external_parent_value: Variant,target_bindings_value: Variant,generation_value: Variant) -> Dictionary:
	if _configured or _disposed: return _error("lifetime")
	if not vehicle_root_value is Node3D or not is_instance_valid(vehicle_root_value): return _error("vehicle_root")
	if not external_parent_value is Node3D or not is_instance_valid(external_parent_value): return _error("external_parent")
	var vehicle_root: Node3D=vehicle_root_value; var external_parent: Node3D=external_parent_value
	if not vehicle_root.is_inside_tree() or not external_parent.is_inside_tree() or vehicle_root.get_parent()!=external_parent: return _error("external_sibling")
	if vehicle_root.is_queued_for_deletion() or external_parent.is_queued_for_deletion() or not _finite_transform(vehicle_root.global_transform) or not _finite_transform(external_parent.global_transform): return _error("transform")
	if not target_bindings_value is Dictionary or target_bindings_value.is_empty() or target_bindings_value.size()>MAX_BINDINGS: return _error("bindings")
	if not generation_value is int or int(generation_value)<1: return _error("generation")
	var staged_bindings: Dictionary={}; var seen_nodes: Dictionary={}
	for key in target_bindings_value:
		if not (key is String or key is StringName) or String(key).is_empty(): return _error("source_id")
		var target: Variant=target_bindings_value[key]
		if not target is MeshInstance3D or not is_instance_valid(target) or target.is_queued_for_deletion() or target.mesh==null or not _is_descendant(target,vehicle_root) or not _finite_transform(target.global_transform): return _error("target")
		var instance_id: int=target.get_instance_id()
		if seen_nodes.has(instance_id): return _error("bindings")
		seen_nodes[instance_id]=true; staged_bindings[StringName(key)]={"target":weakref(target)}
	var prepared:=Geometry.prepare()
	if not prepared.ok: return {"ok":false,"error":"geometry_"+String(prepared.get("error","unknown"))}
	var effects_root:=Node3D.new(); effects_root.name="Vehicle_damage_marks_external"; external_parent.add_child(effects_root)
	var staged_slots: Array[MeshInstance3D]=[]; var staged_sources: Array[StringName]=[]; var staged_local_poses: Array[Transform3D]=[]; var staged_active:=PackedByteArray(); staged_active.resize(POOL_SIZE); staged_active.fill(0)
	for slot in POOL_SIZE:
		var node:=MeshInstance3D.new(); node.name="Damage_mark_%02d"%slot; node.mesh=prepared.meshes[prepared.slot_types[slot]]; node.visible=false; effects_root.add_child(node); staged_slots.append(node); staged_sources.append(StringName()); staged_local_poses.append(Transform3D.IDENTITY)
	_vehicle_root=vehicle_root; _external_parent=external_parent; _effects_root=effects_root; _bindings=staged_bindings; _prepared=prepared; _slots=staged_slots; _slot_sources=staged_sources; _slot_local_poses=staged_local_poses; _slot_active=staged_active; _generation=int(generation_value); _cursor=0; _resources_dirty=false
	for resource in [prepared.meshes.scratch,prepared.meshes.crater,prepared.materials.scratch,prepared.materials.crater]: resource.changed.connect(_on_prepared_resource_changed)
	_configured=true
	return {"ok":true,"generation":_generation,"slots":POOL_SIZE,"cursor":_cursor,"effects_root":_effects_root,"fixture_sha":Geometry.FIXTURE_SHA,"limitations":prepared.limitations.duplicate()}

func commit(target_value: Variant,source_id_value: Variant,plan_receipt_value: Variant,expected_generation: Variant) -> Dictionary:
	var state:=_state(expected_generation)
	if not state.ok: return state
	if not (source_id_value is String or source_id_value is StringName): return _error("source_id")
	var source_id:=StringName(source_id_value)
	if not _bindings.has(source_id): return _error("source_id")
	var bound_target: Variant=(_bindings[source_id].target as WeakRef).get_ref()
	if not target_value is MeshInstance3D or not is_instance_valid(target_value) or target_value.is_queued_for_deletion() or target_value!=bound_target: return _error("target")
	var target: MeshInstance3D=target_value
	if not _target_valid(target): return _error("target_state")
	if not plan_receipt_value is Dictionary: return _error("receipt")
	var receipt: Dictionary=plan_receipt_value
	if receipt.get("ok")!=true or not receipt.get("kind") is String or not receipt.get("slot") is int or not receipt.get("next_cursor") is int or not receipt.get("slot_kind") is String: return _error("receipt")
	var expected:=_expected_cursor(String(receipt.kind),_cursor)
	if not expected.ok or receipt.slot!=expected.slot or receipt.next_cursor!=expected.next_cursor or receipt.slot_kind!=_prepared.slot_types[expected.slot]: return _error("cursor")
	var pose:=Pose.compose(receipt.get("position"),receipt.get("quaternion"),receipt.get("scale"))
	if not pose.ok: return {"ok":false,"error":"pose_"+String(pose.get("error","unknown"))}
	if not is_instance_valid(_effects_root) or _effects_root.is_queued_for_deletion() or _effects_root.get_parent()!=_external_parent or not _finite_transform(_effects_root.global_transform) or not _finite_transform(target.global_transform): return _error("external_root")
	var local_to_external: Transform3D=_effects_root.global_transform.affine_inverse()*target.global_transform*pose.native_transform
	if not _finite_transform(local_to_external): return _error("transform")
	var slot: int=expected.slot; var node:=_slots[slot]
	if _resources_dirty or not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_parent()!=_effects_root or node.mesh!=_prepared.meshes[_prepared.slot_types[slot]] or node.material_override!=null or node.material_overlay!=null or node.mesh.get_surface_count()!=1 or node.mesh.surface_get_material(0)!=_prepared.materials[_prepared.slot_types[slot]]: return _error("slot_state")
	# Mutation begins only after every binding, hierarchy, pose and resource
	# check above succeeds. Cursor advances last.
	node.transform=local_to_external; _slot_sources[slot]=source_id; _slot_local_poses[slot]=pose.native_transform; _slot_active[slot]=1; node.visible=true; _cursor=expected.next_cursor
	return {"ok":true,"generation":_generation,"slot":slot,"slot_kind":_prepared.slot_types[slot],"cursor":_cursor,"node":node}

## Explicit bounded maintenance hook; there is no per-frame process or TTL.
func reconcile_targets(expected_generation: Variant) -> Dictionary:
	var state:=_state(expected_generation)
	if not state.ok: return state
	if not _slots_valid(): return _error("slot_state")
	if not _finite_transform(_effects_root.global_transform): return _error("external_root")
	var effects_inverse:=_effects_root.global_transform.affine_inverse(); var desired_visible:=PackedByteArray(); desired_visible.resize(POOL_SIZE); var desired_transforms: Array[Transform3D]=[]; desired_transforms.resize(POOL_SIZE)
	var visible:=0
	for slot in POOL_SIZE:
		desired_transforms[slot]=_slots[slot].transform
		if _slot_active[slot]==0: continue
		var source_id:=_slot_sources[slot]; var target: Variant=null
		if _bindings.has(source_id): target=(_bindings[source_id].target as WeakRef).get_ref()
		var should_show:=target is MeshInstance3D and is_instance_valid(target) and _target_valid(target)
		if should_show:
			var target_transform: Transform3D=target.global_transform
			if not _finite_transform(target_transform): return _error("target_transform")
			var next_transform:=effects_inverse*target_transform*_slot_local_poses[slot]
			if not _finite_transform(next_transform): return _error("transform")
			desired_transforms[slot]=next_transform; desired_visible[slot]=1; visible+=1
	var changed:=0
	for slot in POOL_SIZE:
		var should_show:=desired_visible[slot]!=0
		if should_show: _slots[slot].transform=desired_transforms[slot]
		if _slots[slot].visible!=should_show: _slots[slot].visible=should_show; changed+=1
	return {"ok":true,"generation":_generation,"checked":POOL_SIZE,"changed":changed,"visible":visible,"cursor":_cursor}

func reset(new_generation: Variant) -> Dictionary:
	var state:=_state(_generation)
	if not state.ok: return state
	if not new_generation is int or int(new_generation)<=_generation: return _error("generation")
	if not _slots_valid(): return _error("slot_state")
	for slot in POOL_SIZE:
		_slots[slot].visible=false; _slot_active[slot]=0; _slot_sources[slot]=StringName(); _slot_local_poses[slot]=Transform3D.IDENTITY; _slots[slot].transform=Transform3D.IDENTITY
	_generation=int(new_generation); _cursor=0
	return {"ok":true,"generation":_generation,"cursor":_cursor,"slots":POOL_SIZE}

func snapshot() -> Dictionary:
	var state:=_state(_generation)
	if not state.ok: return state
	if not _slots_valid(): return _error("slot_state")
	var active:=0; var visible:=0
	for slot in POOL_SIZE:
		if _slot_active[slot]!=0: active+=1
		if _slots[slot].visible: visible+=1
	return {"ok":true,"generation":_generation,"cursor":_cursor,"slots":POOL_SIZE,"active":active,"visible":visible,"effects_root":_effects_root}

func get_slot_node(slot: int) -> MeshInstance3D:
	if not _configured or _disposed or slot<0 or slot>=POOL_SIZE: return null
	return _slots[slot] if is_instance_valid(_slots[slot]) else null

func dispose() -> void:
	if _disposed: return
	if not _prepared.is_empty():
		var callback:=Callable(self,"_on_prepared_resource_changed")
		for resource in [_prepared.meshes.scratch,_prepared.meshes.crater,_prepared.materials.scratch,_prepared.materials.crater]:
			if is_instance_valid(resource) and resource.changed.is_connected(callback): resource.changed.disconnect(callback)
	if is_instance_valid(_effects_root): _effects_root.free()
	_bindings.clear(); _slots.clear(); _slot_sources.clear(); _slot_local_poses.clear(); _slot_active=PackedByteArray(); _prepared.clear(); _resources_dirty=false; _vehicle_root=null; _external_parent=null; _effects_root=null; _configured=false; _disposed=true

func _state(expected_generation: Variant) -> Dictionary:
	if not _configured or _disposed: return _error("lifetime")
	if not expected_generation is int or int(expected_generation)!=_generation: return _error("generation")
	if not is_instance_valid(_vehicle_root) or _vehicle_root.is_queued_for_deletion() or not _vehicle_root.is_inside_tree() or not is_instance_valid(_external_parent) or _external_parent.is_queued_for_deletion() or not _external_parent.is_inside_tree() or _vehicle_root.get_parent()!=_external_parent: return _error("vehicle_root")
	if not is_instance_valid(_effects_root) or _effects_root.is_queued_for_deletion() or not _effects_root.is_inside_tree() or not _effects_root.visible or _effects_root.get_parent()!=_external_parent: return _error("external_root")
	return {"ok":true}

func _slots_valid() -> bool:
	if _resources_dirty or _slots.size()!=POOL_SIZE or _slot_sources.size()!=POOL_SIZE or _slot_local_poses.size()!=POOL_SIZE or _slot_active.size()!=POOL_SIZE: return false
	for kind in ["scratch","crater"]:
		var mesh: ArrayMesh=_prepared.meshes[kind]
		if not is_instance_valid(mesh) or mesh.get_surface_count()!=1 or mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES or mesh.surface_get_material(0)!=_prepared.materials[kind]: return false
	for slot in POOL_SIZE:
		if not is_instance_valid(_slots[slot]) or _slots[slot].is_queued_for_deletion() or _slots[slot].get_parent()!=_effects_root or _slots[slot].mesh!=_prepared.meshes[_prepared.slot_types[slot]] or _slots[slot].material_override!=null or _slots[slot].material_overlay!=null: return false
	return true

func _on_prepared_resource_changed() -> void: _resources_dirty=true

func _target_valid(target: MeshInstance3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree() or not target.is_visible_in_tree() or not _is_descendant(target,_vehicle_root): return false
	var node: Node=target
	while node!=null:
		if node is Node3D and not (node as Node3D).visible: return false
		if node==_vehicle_root: return true
		node=node.get_parent()
	return false

static func _is_descendant(node: Node,ancestor: Node) -> bool:
	var current: Node=node
	while current!=null:
		if current==ancestor: return true
		current=current.get_parent()
	return false

static func _expected_cursor(kind: String,cursor_value: int) -> Dictionary:
	var cursor:=cursor_value
	if kind=="bullet":
		while (cursor%POOL_SIZE)%Plan.SCRATCH_MODULO==0: cursor+=1
	elif kind=="collision_scratch":
		while cursor%Plan.SCRATCH_MODULO!=0: cursor+=1
		while (cursor%POOL_SIZE)%Plan.SCRATCH_MODULO!=0: cursor+=1
	elif kind!="collision_round": return _error("kind")
	if cursor+1>Plan.MAX_SAFE_CURSOR: return _error("cursor")
	return {"ok":true,"slot":cursor%POOL_SIZE,"next_cursor":cursor+1}

static func _finite_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite() and absf(value.basis.determinant())>1e-12
static func _error(reason: String) -> Dictionary: return {"ok":false,"error":reason}
