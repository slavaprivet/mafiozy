extends "res://scripts/map_editor/scene_pause_owner.gd"
## Compound-only fork. Frozen v1 remains unchanged. Capsules are non-JSON,
## issuer-bound handles; captured source clocks/controls are never written back.
var _issued: RefCounted
var _applied := false
var _control_authorization: Callable
var _control_owner := {}

func configure_control_reconciliation(owner: Node, authorization: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _main == null or _issued != null or _control_authorization.is_valid() or not authorization.is_valid() or authorization.get_object() != owner: return failure("Configure-time bound actual control owner required")
	for spec: Dictionary in _nodes + _bodies:
		if spec.node.get_ref() == owner and _live(spec) and not spec.guard_fields.is_empty():
			_control_owner = spec
			_control_authorization = authorization
			return {"ok": true}
	return failure("Control owner is not in the admitted guarded inventory")

func prepare_pause(request: Dictionary) -> Dictionary:
	if not Thread.is_main_thread(): return failure("Off-thread scene pause refused")
	var result := pause_gameplay(request)
	if not _capsule.is_empty() and _issued == null: _issued = RefCounted.new()
	if _issued != null:
		result.capsule = _issued
		result.receipt = _receipt.duplicate(true)
	return result
func _owns(handle: Variant) -> bool:
	return Thread.is_main_thread() and handle != null and handle == _issued and not _capsule.is_empty()
func hold(handle: Variant) -> Dictionary:
	if not _owns(handle) or _busy: return failure("Foreign/reentrant scene capsule")
	_refreeze_owned()
	_applied = false
	if _settled_frame < 0: _settled_frame = Engine.get_physics_frames()
	return {"ok": _all_live()}
func preflight_restore(handle: Variant) -> Dictionary:
	return _preflight(handle, false)
func _preflight(handle: Variant, allow_guard_changes: bool) -> Dictionary:
	# Read-only: unlike verify_pause, this does not advance the frame barrier.
	if not _owns(handle) or _busy or _applied or not _all_live(): return failure("Scene capsule lifetime/parent changed")
	for saved: Dictionary in _capsule.nodes:
		var node: Node = saved.spec.node.get_ref()
		for flag: String in ["process", "physics", "input", "unhandled", "unhandled_key", "shortcut"]:
			if saved.spec.get("stop_" + flag, true) and _flag(node, flag): return failure("Scene participant is not held")
		for field: String in saved.fields:
			if allow_guard_changes and saved.spec.guard_fields.has(field): continue
			if node.get(field) != saved.fields[field]: return failure("Source control/clock changed; owner reconciliation required, never rewound")
		if node is Timer and (not node.paused or not _timer_unchanged(node, saved.timer)): return failure("Timer clock/configuration changed")
	for saved: Dictionary in _capsule.bodies:
		var body: RigidBody3D = saved.spec.node.get_ref()
		if not body.freeze or body.freeze_mode != RigidBody3D.FREEZE_MODE_STATIC or not body.global_transform.is_equal_approx(saved.frame) or not body.linear_velocity.is_equal_approx(saved.linear) or not body.angular_velocity.is_equal_approx(saved.angular) or body.collision_layer != saved.layer or body.collision_mask != saved.mask or body.custom_integrator != saved.custom_integrator: return failure("Native body/source support changed")
	return {"ok": true}
func reconcile_guard_fields(handle: Variant) -> Dictionary:
	# Explicit trusted source-owner recovery ONLY. No scene/control writes. Clock
	# fields must not be designated guard_fields by caller inventory.
	if not _control_authorization.is_valid() or not _live(_control_owner) or not _preflight(handle, true).ok: return failure("Control reconciliation prerequisites refused")
	var current: Array = []
	for saved: Dictionary in _capsule.nodes:
		var values := {}
		for field: String in saved.spec.guard_fields: values[field] = _detached(saved.spec.node.get_ref().get(field))
		current.append({"instance_id": saved.spec.instance, "values": values})
	_busy = true
	var result: Variant = _control_authorization.call(handle, _receipt.duplicate(true), current.duplicate(true))
	_busy = false
	if not result is Dictionary or not accepted(result) or result.get("control_owner_id") != _control_owner.instance or not _live(_control_owner) or not _preflight(handle, true).ok: return failure("Source owner refused current control receipt")
	for index in _capsule.nodes.size():
		var saved: Dictionary = _capsule.nodes[index]
		for field: String in current[index].values:
			if saved.spec.node.get_ref().get(field) != current[index].values[field]: return failure("Control changed during authorization; retry with fresh owner receipt")
	for index in _capsule.nodes.size():
		for field: String in current[index].values: _capsule.nodes[index].fields[field] = current[index].values[field]
	return {"ok": true}
func admit_resume(handle: Variant, objects: Dictionary, ground: Dictionary) -> Dictionary:
	if not preflight_restore(handle).ok or not transaction_ready(_receipt): return failure("Scene freeze barrier/transaction admission refused")
	_busy = true
	var decision: Variant = _callbacks.validate_resume.call(_receipt.duplicate(true), objects.duplicate(true), ground.duplicate(true))
	_busy = false
	if not accepted(decision) or not preflight_restore(handle).ok: return failure("Source support/nav/water/authority admission refused")
	return {"ok": true}
func apply_restore(handle: Variant) -> Dictionary:
	if not preflight_restore(handle).ok: return failure("Scene final preflight refused")
	_busy = true
	# No owner callbacks, clocks, controls, poses, velocities or authority writes.
	for saved: Dictionary in _capsule.bodies:
		var body: RigidBody3D = saved.spec.node.get_ref()
		if body.freeze_mode != saved.freeze_mode: body.freeze_mode = saved.freeze_mode
		if body.freeze != saved.freeze: body.freeze = saved.freeze
		if body.sleeping != saved.sleeping: body.sleeping = saved.sleeping
	for saved: Dictionary in _capsule.nodes:
		var node: Node = saved.spec.node.get_ref()
		node.set_process(saved.process)
		node.set_physics_process(saved.physics)
		node.set_process_input(saved.input)
		node.set_process_unhandled_input(saved.unhandled)
		node.set_process_unhandled_key_input(saved.unhandled_key)
		node.set_process_shortcut_input(saved.shortcut)
		if node is Timer: node.paused = saved.timer.paused
	_busy = false
	_applied = true
	return {"ok": _restored_exactly()}
func postflight_restore(handle: Variant) -> bool:
	return _owns(handle) and not _busy and _applied and _restored_exactly()
func finish_restore(handle: Variant) -> void:
	assert(postflight_restore(handle))
	_clear()
	_issued = null
	_applied = false
