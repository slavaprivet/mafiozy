extends "res://scripts/preview_printshop_interior.gd"
const ExactSource = preload("../map_editor_candidate/scripts/map_editor/trusted_json.gd")
## Separate source-only owner extension, never authorises navigation/custody or
## installs itself into main. Original source package/materials stay unchanged.
var _placement_root: Node3D
var _source_frame := Transform3D.IDENTITY
var _current_frame := Transform3D.IDENTITY
var _current_interior := Transform3D.IDENTITY
var _door_holds := {}
var _scene_owner: WeakRef
var _scene_parent: WeakRef
var _owner_frame := Transform3D.IDENTITY
var _callbacks := {}
var _source_data := {}
var _immutable_source := false
var _inventory: Array = []
var _resources: Array[Resource] = []
var _shader_parameters: Array = []
var _unsupported_multimesh := false
var _poisoned := false
var _editing := false
var _issued: RefCounted
var _plan := {}
var _external_receipt: RefCounted
var _busy := false
var _retained := false

static func failure(message: String) -> Dictionary: return {"ok": false, "error": message}
static func accepted(value: Variant) -> bool: return value is Dictionary and value.get("ok", false) == true
func configure_placement_owner(owner: Node3D, placement_root: Node3D, callbacks: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _scene_owner != null or not ready_for_use or not is_instance_valid(owner) or get_parent() != owner or not is_instance_valid(placement_root) or placement_root.get_parent() != owner or not placement_root.is_ancestor_of(_visual) or placement_root.get_meta("source_id", "") != SOURCE_ID:
		return failure("Explicit current printshop placement and source owner required")
	for name in ["held", "prepare", "validate", "commit", "rollback", "can_resume"]:
		if not callbacks.get(name) is Callable or not callbacks[name].is_valid() or callbacks[name].get_object() != owner: return failure("Missing bound source-owner callback: " + name)
	_scene_owner = weakref(owner)
	_scene_parent = weakref(get_parent())
	_owner_frame = owner.global_transform
	_placement_root = placement_root
	_source_frame = placement_root.global_transform
	_current_frame = _source_frame
	_current_interior = global_transform
	_source_data = _data.duplicate(true)
	_callbacks = callbacks.duplicate()
	_capture(placement_root)
	_capture(self)
	return {"ok": true}
func _capture(node: Node) -> void:
	var row := {"node": weakref(node), "parent": weakref(node.get_parent()), "instance": node.get_instance_id()}
	row.children = []
	for child in node.get_children(true): row.children.append(child.get_instance_id())
	row.identity = {}
	for key in ["source_id", "source_index", "interior_kind", "printshop_interior_attached", "life_generation"]:
		if node.has_meta(key): row.identity[key] = node.get_meta(key)
	var moving_door := ""
	for key: String in _doors:
		if _doors[key].node == node: moving_door = key
	if not moving_door.is_empty(): row.door_key = moving_door; row.base = _doors[moving_door].base
	elif node is Node3D and node != self and node != _placement_root: row.frame = node.transform
	if node is VisualInstance3D: row.visible = node.visible; row.layers = node.layers
	if node is GeometryInstance3D:
		row.shadow = node.cast_shadow
		row.material_overlay = node.material_overlay
		_watch(node.material_overlay)
	if node is MeshInstance3D:
		row.mesh = node.mesh
		row.material_override = node.material_override
		_watch(node.mesh)
		_watch(node.material_override)
		row.surface_overrides = []
		if node.mesh != null:
			for surface in node.mesh.get_surface_count():
				_watch(node.mesh.surface_get_material(surface))
				row.surface_overrides.append(node.get_surface_override_material(surface))
				_watch(node.get_surface_override_material(surface))
	# Native instance setters do not emit changed; Dummy/headless readback cannot
	# prove storage parity. Do not admit an unsupported mutable MultiMesh lease.
	if node is MultiMeshInstance3D:
		row.multimesh = node.multimesh
		_unsupported_multimesh = true
		_watch(node.multimesh)
	if node is CollisionShape3D: row.shape = node.shape; row.disabled = node.disabled; _watch(node.shape)
	if node is CollisionObject3D: row.layer = node.collision_layer; row.mask = node.collision_mask
	_inventory.append(row)
	for child in node.get_children(true): _capture(child)
func _watch(resource: Resource) -> void:
	if resource == null or _resources.has(resource): return
	_resources.append(resource)
	resource.changed.connect(_resource_changed)
	if resource is ShaderMaterial:
		_watch(resource.shader)
		var parameters := {}
		if resource.shader != null:
			for uniform in resource.shader.get_shader_uniform_list():
				var value: Variant = resource.get_shader_parameter(uniform.name)
				parameters[uniform.name] = value if value is Resource else var_to_bytes(value)
				if value is Resource: _watch(value)
		_shader_parameters.append({"material": resource, "parameters": parameters})
func _resource_changed() -> void: _poisoned = true
static func _freeze_json(value: Variant) -> void:
	if value is Dictionary:
		for key in value: _freeze_json(value[key])
		value.make_read_only()
	elif value is Array:
		for item in value: _freeze_json(item)
		value.make_read_only()
func adopt_immutable_source_descriptor(admit: Callable) -> Dictionary:
	# Explicit owner adoption: preserve exact values while removing writable
	# source aliases. Never freeze a foreign/main-owned caller dictionary in place.
	if _busy or _editing or _immutable_source or not _live() or not admit.is_valid() or admit.get_object() != _scene_owner.get_ref(): return failure("Actual source owner must admit immutable descriptor adoption")
	var frozen: Dictionary = _source_data.duplicate(true)
	_freeze_json(frozen)
	_busy = true
	var result: Variant = admit.call(SOURCE_ID, frozen)
	_busy = false
	if not accepted(result) or not _live(): return failure("Source descriptor adoption refused or source changed")
	_source_data = frozen
	_data = frozen
	for key: String in _doors: _doors[key].spec = frozen.doors[key]
	_immutable_source = true
	return {"ok": true}
func _live() -> bool:
	if not Thread.is_main_thread() or _scene_owner == null or _poisoned or _unsupported_multimesh or not ready_for_use or not is_instance_valid(_placement_root): return false
	var owner: Variant = _scene_owner.get_ref()
	if not is_instance_valid(owner) or not owner.is_inside_tree() or get_parent() != _scene_parent.get_ref() or get_parent() != owner or owner.global_transform != _owner_frame: return false
	if _immutable_source:
		if not is_same(_source_data, _data) or not _data.is_read_only(): return false
	else:
		if not ExactSource.equal(_source_data, _data): return false
	if _placement_root.global_transform != _current_frame or global_transform != _current_interior: return false
	for shader_row: Dictionary in _shader_parameters:
		for key in shader_row.parameters:
			var original: Variant = shader_row.parameters[key]
			var current: Variant = shader_row.material.get_shader_parameter(key)
			if original is Resource:
				if not is_same(original, current): return false
			elif original != var_to_bytes(current): return false
	for row: Dictionary in _inventory:
		var node: Variant = row.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.get_parent() != row.parent.get_ref() or node.get_instance_id() != row.instance: return false
		if node.get_child_count(true) != row.children.size(): return false
		for child_index in row.children.size():
			if node.get_child(child_index, true).get_instance_id() != row.children[child_index]: return false
		for key in row.identity:
			if not node.has_meta(key) or not ExactSource.equal(row.identity[key], node.get_meta(key)): return false
		if row.has("frame") and node.transform != row.frame: return false
		if row.has("door_key"):
			if not _doors.has(row.door_key) or _doors[row.door_key].node != node or _doors[row.door_key].base != row.base: return false
			if _immutable_source and not is_same(_doors[row.door_key].spec, _source_data.doors[row.door_key]): return false
			if _door_holds.has(row.door_key):
				var saved: Dictionary = _door_holds[row.door_key]
				if node.transform != saved.frame or _doors[row.door_key].fraction != saved.fraction or _doors[row.door_key].target != saved.target: return false
		if row.has("visible") and (node.visible != row.visible or node.layers != row.layers): return false
		if row.has("shadow") and (node.cast_shadow != row.shadow or node.material_overlay != row.material_overlay): return false
		if row.has("mesh") and (node.mesh != row.mesh or node.material_override != row.material_override): return false
		if row.has("surface_overrides"):
			for surface in row.surface_overrides.size():
				if node.get_surface_override_material(surface) != row.surface_overrides[surface]: return false
		if row.has("multimesh") and node.multimesh != row.multimesh: return false
		if row.has("shape") and (node.shape != row.shape or node.disabled != row.disabled): return false
		if row.has("layer") and (node.collision_layer != row.layer or node.collision_mask != row.mask): return false
	return true
func _held() -> bool:
	if _busy or not _live(): return false
	_busy = true
	var result: Variant = _callbacks.held.call()
	_busy = false
	return result is bool and result and _live()
func begin_editor_placement() -> Dictionary:
	if _busy or _editing or not _held(): return failure("Real source-owner paused lease required")
	for key: String in _doors:
		var d: Dictionary = _doors[key]
		_door_holds[key] = {"frame": d.node.transform, "fraction": d.fraction, "target": d.target}
	_editing = true
	return {"ok": true}
func prepare_placement(target: Transform3D) -> Dictionary:
	if _busy or not _editing or _issued != null or not _held() or not target.is_finite(): return failure("Printshop placement transaction unavailable")
	var delta := target * _source_frame.affine_inverse()
	# Source occupant capsules/proximity use metres and upright height. Scaling or
	# tilting them silently is not a compatible source-owner operation.
	if not delta.basis.is_equal_approx(delta.basis.orthonormalized()) or delta.basis.determinant() <= 0.0 or not delta.basis.y.is_equal_approx(Vector3.UP): return failure("Only rigid upright source placements are admitted")
	var request := {"source_id": SOURCE_ID, "source_asset_sha": ASSET_SHA, "before": _placement_root.global_transform, "after": target, "interior_before": global_transform, "interior_after": delta, "current_anchors": {}}
	for key in _data.anchors: request.current_anchors[key] = delta * _v3(_data.anchors[key])
	_busy = true
	var result: Variant = _callbacks.prepare.call(request.duplicate(true))
	_busy = false
	if not result is Dictionary or not result.get("receipt") is RefCounted:
		if result is Dictionary and not result.get("ok", false) and result.get("unchanged", false) == true and _held(): return failure("Source owner refused preparation without mutation")
		# Unknown partial preparation is never treated as an unchanged rejection.
		_issued = RefCounted.new()
		_plan = request.duplicate(true)
		_retained = true
		return {"ok": false, "error": "Unreceipted source preparation; retained owner repair required", "handle": _issued}
	_issued = RefCounted.new()
	_external_receipt = result.receipt
	_plan = request.duplicate(true)
	if not _held(): _retained = true; return failure("Source changed during owner preparation; retained repair required")
	if not accepted(result):
		var rollback := rollback_placement(_issued)
		return {"ok": false, "error": "Source preparation refused", "rollback": rollback, "retained": not rollback.ok}
	return {"ok": true, "handle": _issued}
func _owns(handle: RefCounted) -> bool: return handle != null and handle == _issued and _editing and Thread.is_main_thread()
func apply_placement(handle: RefCounted) -> Dictionary:
	if _busy or _retained or not _owns(handle) or not _held(): return failure("Stale or unheld source placement")
	_busy = true
	var valid: Variant = _callbacks.validate.call(_external_receipt, _plan.duplicate(true))
	_busy = false
	if not accepted(valid) or not _held(): return failure("Owner source placement validation refused")
	_placement_root.global_transform = _plan.after
	global_transform = _plan.interior_after
	_current_frame = _placement_root.global_transform
	_current_interior = global_transform
	_busy = true
	var result: Variant = _callbacks.commit.call(_external_receipt, _plan.duplicate(true))
	_busy = false
	if not accepted(result) or not _held():
		var rollback := rollback_placement(handle)
		return {"ok": false, "error": "Source-owner commit refused", "rollback": rollback, "retained": not rollback.ok}
	_issued = null
	_external_receipt = null
	_plan.clear()
	return {"ok": true}
func rollback_placement(handle: RefCounted) -> Dictionary:
	# A foreign/stale/reentrant handle has no authority to change transaction state.
	if _busy or not _owns(handle): return failure("Stale or reentrant source rollback")
	if not _held(): _retained = true; return failure("Source lifetime/geometry must be repaired before rollback")
	_busy = true
	var result: Variant = _callbacks.rollback.call(_external_receipt, _plan.duplicate(true))
	_busy = false
	if not accepted(result) or not _held(): _retained = true; return failure("External source rollback refused; participants remain held")
	_placement_root.global_transform = _plan.before
	global_transform = _plan.interior_before
	_current_frame = _placement_root.global_transform
	_current_interior = global_transform
	_retained = false
	_issued = null
	_external_receipt = null
	_plan.clear()
	return {"ok": true}
func end_editor_placement() -> Dictionary:
	if _busy or not _editing or _issued != null or _retained or not _held(): return failure("Source placement is still retained")
	_busy = true
	var result: Variant = _callbacks.can_resume.call(global_transform)
	_busy = false
	if not accepted(result) or not _held(): return failure("Edited source support/nav/water/HUD not admitted")
	_editing = false
	_door_holds.clear()
	return {"ok": true}
func placement_state() -> Dictionary: return {"editing": _editing, "pending": _issued != null, "retained": _retained, "source_current_frame": global_transform, "production_wired": false}
func anchor(key: String) -> Vector3:
	var original := super.anchor(key)
	return global_transform * original if original.is_finite() else original
func nearest_action(actor_position: Vector3) -> Dictionary:
	if _editing or not actor_position.is_finite(): return {}
	return super.nearest_action(global_transform.affine_inverse() * actor_position)
func request_door(key: String, open: bool, actor_position: Vector3, occupants: Array) -> Dictionary:
	if _editing: return {"accepted": false, "reason": "editor-source-owner-held"}
	if not ready_for_use or not _doors.has(key) or not actor_position.is_finite(): return {"accepted": false, "reason": "invalid-door-request"}
	var local := global_transform.affine_inverse() * actor_position
	var d: Dictionary = _doors[key]
	if key == "service" and open and local.distance_to(_v3(_data.anchors.doorInside)) > 0.25: return {"accepted": false, "reason": "staff-not-at-door"}
	if key == "public" and local.distance_to(_v3(d.spec.anchor)) > float(d.spec.proximity): return {"accepted": false, "reason": "out-of-range"}
	var target := 1.0 if open else 0.0
	if not _sweep_clear(d, float(d.fraction), target, occupants): return {"accepted": false, "reason": "door-sweep-occupied"}
	d.target = target
	return {"accepted": true, "open": open}
func advance(delta: float, occupants: Array) -> void:
	if not _editing: super.advance(delta, occupants)
func _sweep_clear(door: Dictionary, from: float, to: float, occupants: Array) -> bool:
	var transformed: Array = []
	if occupants.size() > 64: return false
	for occupant: Variant in occupants:
		if not occupant is Dictionary or not occupant.get("position") is Vector3: return false
		var row: Dictionary = occupant.duplicate(true)
		row.position = global_transform.affine_inverse() * occupant.position
		transformed.append(row)
	return super._sweep_clear(door, from, to, transformed)
