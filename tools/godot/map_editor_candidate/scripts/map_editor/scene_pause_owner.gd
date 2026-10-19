extends RefCounted
## Explicit CPU pause ownership for current nodes/bodies. Never pauses SceneTree,
## discovers actors, edits authority, clears controls or rebuilds nav/water.
## An independent early input router must remain outside this inventory.
var _main: WeakRef
var _nodes: Array = []
var _bodies: Array = []
var _callbacks := {}
var _request := {}
var _receipt := {}
var _capsule := {}
var _busy := false
var _fault := false
var _sequence := 0
var _settled_frame := -1
var _last_error := ""

static func accepted(value: Variant) -> bool:
	return (value is bool and value) or (value is Dictionary and value.get("ok", false) == true)
static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
static func _detached(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
static func _state_safe(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		for key in value:
			if not _state_safe(key) or not _state_safe(value[key]): return false
	if value is Array:
		for item in value:
			if not _state_safe(item): return false
	return true

func configure(main: Node, node_inventory: Array, body_inventory: Array, callbacks: Dictionary) -> Dictionary:
	if _main != null or not is_instance_valid(main) or not main.is_inside_tree() or node_inventory.is_empty(): return failure("Current main and explicit participant inventory required")
	for name: String in ["admit_pause", "validate_resume", "transaction_ready", "ground_patch"]:
		if not callbacks.get(name) is Callable or not callbacks[name].is_valid(): return failure("Missing real scene owner callback: " + name)
	if callbacks.has("pause_step") and (not callbacks.pause_step is Callable or not callbacks.pause_step.is_valid()): return failure("Invalid pause step owner hook")
	var seen := {}
	var nodes: Array = []
	var bodies: Array = []
	for spec: Variant in node_inventory + body_inventory:
		if not spec is Dictionary or not spec.get("node") is Node: return failure("Invalid supplied participant")
		var node: Node = spec.node
		if node is AnimationMixer or node is GPUParticles3D or node is CPUParticles3D: return failure("Internal animation/particle simulation needs its real owner pause adapter")
		if not node.is_inside_tree() or (node != main and not main.is_ancestor_of(node)) or seen.has(node.get_instance_id()): return failure("Duplicate or foreign scene participant")
		var identity: Variant = spec.get("identity", {})
		if not identity is Dictionary or not _state_safe(identity): return failure("Invalid identity guards")
		for key in identity:
			if not key is String or not node.has_meta(key) or node.get_meta(key) != identity[key]: return failure("Participant lifetime metadata mismatch")
		seen[node.get_instance_id()] = true
		var copied: Dictionary = spec.duplicate()
		copied.node = weakref(node)
		copied.parent = weakref(node.get_parent())
		copied.instance = node.get_instance_id()
		copied.identity = identity.duplicate(true)
		if not spec.get("fields", []) is Array: return failure("Explicit state fields must be an array")
		copied.fields = spec.get("fields", []).duplicate()
		for field: Variant in copied.fields:
			if not field is String or not _has_property(node, field) or not _state_safe(node.get(field)): return failure("Unsupported explicit state field")
		if not spec.get("guard_fields", []) is Array: return failure("Invalid guarded owner fields")
		copied.guard_fields = spec.get("guard_fields", []).duplicate()
		for field: Variant in copied.guard_fields:
			if not field is String or not copied.fields.has(field): return failure("Guarded field must be captured explicitly")
		if spec in body_inventory:
			if not node is RigidBody3D: return failure("Explicit physics participant must be RigidBody3D")
			bodies.append(copied)
		else:
			nodes.append(copied)
	_main = weakref(main)
	_nodes = nodes
	_bodies = bodies
	_callbacks = callbacks.duplicate()
	return {"ok": true}

static func _has_property(node: Node, field: String) -> bool:
	for item: Dictionary in node.get_property_list():
		if item.name == field: return true
	return false
func _live(spec: Dictionary) -> bool:
	var main: Node = _main.get_ref() if _main != null else null
	var node: Node = spec.node.get_ref()
	var parent: Node = spec.parent.get_ref()
	if not is_instance_valid(main) or not main.is_inside_tree() or not is_instance_valid(node) or not node.is_inside_tree() or not is_instance_valid(parent) or node.get_parent() != parent or node.get_instance_id() != spec.instance or (node != main and not main.is_ancestor_of(node)): return false
	for key in spec.identity:
		if not node.has_meta(key) or node.get_meta(key) != spec.identity[key]: return false
	return true
func _all_live() -> bool:
	if _main == null: return false
	for spec: Dictionary in _nodes + _bodies:
		if not _live(spec): return false
	return true
func _capture() -> Dictionary:
	if not _all_live(): return failure("Scene owner, parent or lifetime changed")
	var states: Array = []
	for spec: Dictionary in _nodes + _bodies:
		var node: Node = spec.node.get_ref()
		var fields := {}
		for field: String in spec.fields:
			if not _state_safe(node.get(field)): return failure("Owner state field type changed")
			fields[field] = _detached(node.get(field))
		var state := {"spec": spec, "process": node.is_processing(), "physics": node.is_physics_processing(), "input": node.is_processing_input(), "unhandled": node.is_processing_unhandled_input(), "unhandled_key": node.is_processing_unhandled_key_input(), "shortcut": node.is_processing_shortcut_input(), "fields": fields}
		if node is Timer: state.timer = {"paused": node.paused, "left": node.time_left, "wait": node.wait_time, "stopped": node.is_stopped(), "one_shot": node.one_shot, "autostart": node.autostart, "process_callback": node.process_callback}
		states.append(state)
	var bodies: Array = []
	for spec: Dictionary in _bodies:
		var body: RigidBody3D = spec.node.get_ref()
		bodies.append({"spec": spec, "frame": body.global_transform, "linear": body.linear_velocity, "angular": body.angular_velocity, "freeze": body.freeze, "freeze_mode": body.freeze_mode, "sleeping": body.sleeping, "layer": body.collision_layer, "mask": body.collision_mask, "custom_integrator": body.custom_integrator})
	return {"ok": true, "nodes": states, "bodies": bodies}

func pause_gameplay(request: Dictionary) -> Dictionary:
	if _busy or _fault or not _request.is_empty() or not _all_live(): return failure("Pause owner is busy or needs repair")
	var main: Node = _main.get_ref()
	if request.get("owner_id") != main.get_instance_id() or not request.get("request_id") is String or request.request_id.is_empty(): return failure("Invalid pause request identity")
	_busy = true
	if not accepted(_callbacks.admit_pause.call(request.duplicate(true))):
		_busy = false
		return failure("Gameplay owner refused editor entry")
	var captured := _capture()
	if not captured.ok:
		_busy = false
		return captured
	_capsule = captured
	_request = request.duplicate(true)
	_sequence += 1
	_receipt = {"owner_id": main.get_instance_id(), "request_id": request.request_id, "token": "%s:%s" % [get_instance_id(), _sequence]}
	for state: Dictionary in _capsule.nodes:
		var node: Node = state.spec.node.get_ref()
		if state.spec.get("stop_process", true): node.set_process(false)
		if state.spec.get("stop_physics", true): node.set_physics_process(false)
		if state.spec.get("stop_input", true): node.set_process_input(false)
		if state.spec.get("stop_unhandled", true): node.set_process_unhandled_input(false)
		if state.spec.get("stop_unhandled_key", true): node.set_process_unhandled_key_input(false)
		if state.spec.get("stop_shortcut", true): node.set_process_shortcut_input(false)
		if node is Timer: node.paused = true # Timer uses internal processing.
		if not _step("node", state.spec.instance):
			_busy = false
			_fault = true
			return failure("Owner refused partial node pause; cancellation required")
	for state: Dictionary in _capsule.bodies:
		var body: RigidBody3D = state.spec.node.get_ref()
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true
		if not _step("body", state.spec.instance):
			_busy = false
			_fault = true
			return failure("Owner refused partial body pause; cancellation required")
	_settled_frame = -1
	_busy = false
	if not verify_pause(_receipt):
		_fault = true
		return failure("Native pause did not hold; owner rollback required")
	return {"ok": true, "receipt": _receipt.duplicate(true)}

func _step(kind: String, instance: int) -> bool:
	return not _callbacks.has("pause_step") or accepted(_callbacks.pause_step.call({"kind": kind, "instance_id": instance, "request": _request.duplicate(true)}))

func verify_pause(receipt: Dictionary) -> bool:
	if _busy or receipt != _receipt or _receipt.is_empty() or not _all_live(): return false
	for state: Dictionary in _capsule.nodes:
		var node: Node = state.spec.node.get_ref()
		for flag: String in ["process", "physics", "input", "unhandled", "unhandled_key", "shortcut"]:
			if not state.spec.get("stop_" + flag, true): continue
			if _flag(node, flag): return false
		for field: String in state.fields:
			if node.get(field) != state.fields[field]: return false
		if node is Timer and (not node.paused or not _timer_unchanged(node, state.timer)): return false
	for state: Dictionary in _capsule.bodies:
		var body: RigidBody3D = state.spec.node.get_ref()
		if not body.freeze or body.freeze_mode != RigidBody3D.FREEZE_MODE_STATIC or not body.global_transform.is_equal_approx(state.frame) or not body.linear_velocity.is_equal_approx(state.linear) or not body.angular_velocity.is_equal_approx(state.angular) or body.collision_layer != state.layer or body.collision_mask != state.mask or body.custom_integrator != state.custom_integrator: return false
	var frame := Engine.get_physics_frames()
	if _settled_frame < 0: _settled_frame = frame
	return true
static func _flag(node: Node, name: String) -> bool:
	match name:
		"process": return node.is_processing()
		"physics": return node.is_physics_processing()
		"input": return node.is_processing_input()
		"unhandled": return node.is_processing_unhandled_input()
		"unhandled_key": return node.is_processing_unhandled_key_input()
		"shortcut": return node.is_processing_shortcut_input()
	return true
func transaction_ready(_receipt_value: Dictionary) -> bool:
	if _fault or not verify_pause(_receipt_value) or Engine.get_physics_frames() <= _settled_frame: return false
	_busy = true
	var value: Variant = _callbacks.transaction_ready.call(_receipt_value.duplicate(true))
	_busy = false
	return accepted(value) and verify_pause(_receipt_value)
func ground_patch() -> Variant:
	if _busy or not _callbacks.has("ground_patch"): return null
	_busy = true
	var value: Variant = _callbacks.ground_patch.call()
	_busy = false
	return _detached(value)

func _restore() -> Dictionary:
	# No participant is changed when another dependency is already gone.
	if not _all_live():
		_fault = true
		return failure("Owner must restore scene lifetime/parent before resume")
	for state: Dictionary in _capsule.nodes:
		var node: Node = state.spec.node.get_ref()
		for field: String in state.spec.guard_fields:
			if node.get(field) != state.fields[field]:
				_refreeze_owned()
				_fault = true
				return failure("Guarded owner control/authority changed; explicit owner repair required")
		if node is Timer and not _timer_unchanged(node, state.timer):
			_refreeze_owned()
			_fault = true
			return failure("Timer phase changed; owner must repair before exact restoration")
	for state: Dictionary in _capsule.bodies:
		var body: RigidBody3D = state.spec.node.get_ref()
		body.global_transform = state.frame
		body.linear_velocity = state.linear
		body.angular_velocity = state.angular
		body.collision_layer = state.layer
		body.collision_mask = state.mask
		body.custom_integrator = state.custom_integrator
		body.freeze_mode = state.freeze_mode
		body.freeze = state.freeze
		body.sleeping = state.sleeping
	for state: Dictionary in _capsule.nodes:
		var node: Node = state.spec.node.get_ref()
		for field: String in state.fields: node.set(field, _detached(state.fields[field]))
		node.set_process(state.process)
		node.set_physics_process(state.physics)
		node.set_process_input(state.input)
		node.set_process_unhandled_input(state.unhandled)
		node.set_process_unhandled_key_input(state.unhandled_key)
		node.set_process_shortcut_input(state.shortcut)
		if node is Timer: node.paused = state.timer.paused
	if not _restored_exactly():
		_refreeze_owned()
		_fault = true
		return failure("Restoration changed owner state; surviving owned participants remain stopped")
	return {"ok": true}
func _restored_exactly() -> bool:
	if not _all_live(): return false
	for state: Dictionary in _capsule.nodes:
		var node: Node = state.spec.node.get_ref()
		for flag: String in ["process", "physics", "input", "unhandled", "unhandled_key", "shortcut"]:
			if _flag(node, flag) != state[flag]: return false
		for field: String in state.fields:
			if node.get(field) != state.fields[field]: return false
		if node is Timer and (node.paused != state.timer.paused or not _timer_unchanged(node, state.timer)): return false
	for state: Dictionary in _capsule.bodies:
		var body: RigidBody3D = state.spec.node.get_ref()
		if not body.global_transform.is_equal_approx(state.frame) or not body.linear_velocity.is_equal_approx(state.linear) or not body.angular_velocity.is_equal_approx(state.angular) or body.freeze != state.freeze or body.freeze_mode != state.freeze_mode or body.sleeping != state.sleeping or body.collision_layer != state.layer or body.collision_mask != state.mask or body.custom_integrator != state.custom_integrator: return false
	return true
func _refreeze_owned() -> void:
	for state: Dictionary in _capsule.nodes:
		if not _live(state.spec): continue
		var node: Node = state.spec.node.get_ref()
		if state.spec.get("stop_process", true): node.set_process(false)
		if state.spec.get("stop_physics", true): node.set_physics_process(false)
		if state.spec.get("stop_input", true): node.set_process_input(false)
		if state.spec.get("stop_unhandled", true): node.set_process_unhandled_input(false)
		if state.spec.get("stop_unhandled_key", true): node.set_process_unhandled_key_input(false)
		if state.spec.get("stop_shortcut", true): node.set_process_shortcut_input(false)
		if node is Timer: node.paused = true
	for state: Dictionary in _capsule.bodies:
		if not _live(state.spec): continue
		var body: RigidBody3D = state.spec.node.get_ref()
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true
static func _timer_unchanged(timer: Timer, saved: Dictionary) -> bool:
	return is_equal_approx(timer.time_left, saved.left) and timer.wait_time == saved.wait and timer.is_stopped() == saved.stopped and timer.one_shot == saved.one_shot and timer.autostart == saved.autostart and timer.process_callback == saved.process_callback
func cancel_pause(request: Dictionary) -> Dictionary:
	if _busy: return failure("Reentrant pause cancellation refused")
	if _request.is_empty(): return {"ok": true, "unchanged": true}
	if request != _request: return failure("Foreign pause cancellation refused")
	_busy = true
	var result := _restore()
	_busy = false
	if result.ok: _clear()
	return result
func resume_gameplay(receipt: Dictionary, objects: Dictionary, ground: Dictionary) -> Dictionary:
	if not transaction_ready(receipt): return failure("Native freeze barrier or owner transaction is not ready")
	_busy = true
	var accepted_resume: Variant = _callbacks.validate_resume.call(receipt.duplicate(true), objects.duplicate(true), ground.duplicate(true))
	_busy = false
	if not accepted(accepted_resume) or not verify_pause(receipt): return failure("Real scene support/nav/water/authority admission refused")
	_busy = true
	var restored := _restore()
	_busy = false
	if not restored.ok: return restored
	var result := {"ok": true, "owner_id": _receipt.owner_id, "request_id": _receipt.request_id}
	_clear()
	return result
func _clear() -> void:
	_request.clear()
	_receipt.clear()
	_capsule.clear()
	_fault = false
	_settled_frame = -1
	_last_error = ""
func callbacks() -> Dictionary:
	return {"pause_gameplay": pause_gameplay, "cancel_pause": cancel_pause, "verify_pause": verify_pause, "resume_gameplay": resume_gameplay, "transaction_ready": transaction_ready, "ground_patch": ground_patch}
func state() -> Dictionary:
	return {"leased": not _receipt.is_empty(), "fault": _fault, "busy": _busy, "physics_barrier_ready": not _receipt.is_empty() and not _fault and _settled_frame >= 0 and Engine.get_physics_frames() > _settled_frame}
