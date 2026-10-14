extends Node
## Tools-only owner for the one native preview car. Never alters collision or visuals.
## Attach beneath PreviewTransport before using it from a K workspace.

const SAMPLE_COUNT := 31
const MAX_LINEAR_MPS := 0.03
const MAX_ANGULAR_RADPS := 0.005
const MAX_HALF_SECOND_DRIFT_M := 0.01
const MAX_HALF_SECOND_YAW_RAD := 0.003
var _transport: Node3D
var _samples: Array[Dictionary] = []
var _receipt: Dictionary = {}

func _ready() -> void:
	_transport = get_parent() as Node3D
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if not _receipt.is_empty(): return
	var body := _body()
	if body == null or not _owner_resting(body):
		_samples.clear()
		return
	_record_sample(body)

func _record_sample(body: RigidBody3D) -> void:
	var tick := int(body._physics_tick)
	if not _samples.is_empty():
		var previous_tick := int(_samples.back().tick)
		if tick == previous_tick: return
		if tick != previous_tick + 1: _samples.clear()
	_samples.append({"tick":tick, "transform":body.global_transform,
		"linear":body.linear_velocity, "angular":body.angular_velocity,
		"id":body.get_instance_id(), "vehicle_id":body.get_meta("vehicle_id", ""),
		"life":body.get_meta("life_generation", 0), "ground":int(body._grounded_wheel_mask)})
	if _samples.size() > SAMPLE_COUNT: _samples.pop_front()

func _body() -> RigidBody3D:
	if not is_instance_valid(_transport) or not is_instance_valid(_transport.body): return null
	return _transport.body as RigidBody3D

func _owner_resting(body: RigidBody3D) -> bool:
	return _transport.ready_for_play and _transport.phase == "ON_FOOT" and _transport._parked_brake \
		and not _transport._e_down and not _transport._pending_exit and not _transport._blocked_transition \
		and body.has_meta("vehicle_id") and int(body.get_meta("life_generation", 0)) > 0 \
		and not body.freeze and body.global_transform.is_finite() and body.linear_velocity.is_finite() \
		and body.angular_velocity.is_finite() and body._contact_buffer.size() == 0 \
		and not body._contact_buffer.has_gap() and body._grounded_wheel_mask == 15 \
		and body._throttle == 0.0 and body._steering_input == 0.0 and body._handbrake

func _stable_window(body: RigidBody3D) -> bool:
	if _samples.size() != SAMPLE_COUNT: return false
	var first: Dictionary = _samples[0]
	var last: Dictionary = _samples.back()
	if last.tick - first.tick != SAMPLE_COUNT - 1: return false
	if last.id != body.get_instance_id() or last.vehicle_id != body.get_meta("vehicle_id", "") \
		or last.life != body.get_meta("life_generation", 0): return false
	if last.transform != body.global_transform or last.linear != body.linear_velocity or last.angular != body.angular_velocity: return false
	var origin: Vector3 = first.transform.origin
	var base_yaw: Quaternion = first.transform.basis.get_rotation_quaternion()
	for sample: Dictionary in _samples:
		if sample.id != last.id or sample.vehicle_id != last.vehicle_id or sample.life != last.life \
			or sample.ground != 15 or sample.tick < first.tick: return false
		if (sample.linear as Vector3).length() > MAX_LINEAR_MPS or (sample.angular as Vector3).length() > MAX_ANGULAR_RADPS: return false
		if (sample.transform as Transform3D).origin.distance_to(origin) > MAX_HALF_SECOND_DRIFT_M: return false
		if base_yaw.angle_to((sample.transform as Transform3D).basis.get_rotation_quaternion()) > MAX_HALF_SECOND_YAW_RAD: return false
	return true

func acquire() -> Dictionary:
	if not _receipt.is_empty(): return {}
	var body := _body()
	if body == null or not _owner_resting(body): return {}
	# A caller can run between the body's physics update and this node's next
	# callback. Capture that exact current tick once, never reuse a stale window.
	_record_sample(body)
	if not _stable_window(body): return {}
	if not _transport.has_method("map_editor_vehicle_acquire"): return {}
	_receipt = _transport.map_editor_vehicle_acquire(_samples.duplicate(true))
	if _receipt.is_empty() or not verify(_receipt): return {}
	_samples.clear()
	return _receipt.duplicate(true)

func verify(receipt: Dictionary) -> bool:
	return not _receipt.is_empty() and receipt == _receipt and is_instance_valid(_transport) \
		and _transport.has_method("map_editor_vehicle_verify") and _transport.map_editor_vehicle_verify(receipt)

func release(receipt: Dictionary) -> bool:
	if not verify(receipt): return false
	if not _transport.has_method("map_editor_vehicle_release") or not _transport.map_editor_vehicle_release(receipt): return false
	_receipt.clear()
	_samples.clear()
	return true

func held() -> bool:
	return not _receipt.is_empty()
