extends RefCounted
## Proof-only wet exit lease and physical transition. It never mutates Host seats.

const WaterPose = preload("res://scripts/transport/transport_water_doorway_pose.gd")
const Surface = preload("res://scripts/transport/transport_water_exit_surface.gd")
const CAR_EXIT_SOURCE_SHA256 := "c89df365c19659e02cd89a5ba75df1a3218808845a8154e0973ce682fb7ee263"

const PROVIDER := "TRANSPORT_WET_EXIT_AUTHORITY_CANDIDATE_V1"
const HOLD_DURATION_US := 300000
const MAX_HOLD_GAP_US := 120000
const RELEASE_DURATION_S := .55
const BODY_DURATION_S := .6
const EXIT_RADIUS_M := .58
const MAX_DELTA_S := 1.0
const MAX_STEP_S := .1
const MAX_ACTIVE := 16

class WetToken extends RefCounted:
	var nonce: int
	func _init(value: int) -> void: nonce = value

var _configured := false
var _disposed := false
var _catalog: RefCounted
var _epoch := 0
var _water_at: Callable
var _ground_height: Callable
var _planar_allowed: Callable
var _own_vehicle_clear: Callable
var _source_motion: Callable
var _states: Dictionary = {}
var _actor_tokens: Dictionary = {}
var _actor_clocks: Dictionary = {}
var _next_nonce := 1

func configure(catalog: RefCounted, authority_epoch: int, water_at: Callable, ground_height: Callable,
		planar_allowed: Callable, own_vehicle_clear: Callable, source_motion: Callable) -> Dictionary:
	if _disposed: return _result("DISPOSED")
	if _configured: return _result("ALREADY_CONFIGURED")
	if catalog == null or not catalog.has_method("profile") or not catalog.has_method("seat") or authority_epoch < 1:
		return _result("CONFIGURATION")
	for callback in [water_at, ground_height, planar_allowed, own_vehicle_clear, source_motion]:
		if not (callback as Callable).is_valid(): return _result("CALLBACK")
	_catalog = catalog; _epoch = authority_epoch
	_water_at = water_at; _ground_height = ground_height
	_planar_allowed = planar_allowed; _own_vehicle_clear = own_vehicle_clear
	_source_motion = source_motion
	_configured = true
	return _result("OK", {"authority_epoch": _epoch, "provider": PROVIDER})

func begin_hold(actor_ref: Dictionary, vehicle_ref: Dictionary, profile_id: String, seat_id: String,
		source_clock: int, actor: CharacterBody3D, vehicle: CollisionObject3D,
		capsule_adapter: RefCounted, door_ready: bool, expected_epoch: int) -> Dictionary:
	var gate := _gate(expected_epoch)
	if not gate.is_empty(): return _result(gate)
	if source_clock < 1 or not door_ready or _states.size() >= MAX_ACTIVE: return _result("ADMISSION")
	var actor_key := _actor_key(actor_ref)
	if actor_key.is_empty() or _actor_tokens.has(actor_key): return _result("ACTOR_BUSY")
	if source_clock <= int(_actor_clocks.get(actor_key, 0)): return _result("STALE_CLOCK")
	var binding := _binding(actor_ref, vehicle_ref, profile_id, seat_id, actor, vehicle, capsule_adapter)
	if not bool(binding.get("ok", false)): return binding
	var adapter: RefCounted = binding.adapter
	var bound: Variant = adapter.call("bind", actor, vehicle, true)
	if not bound is Dictionary or typeof((bound as Dictionary).get("ok")) != TYPE_BOOL or not (bound as Dictionary).ok:
		adapter.call("dispose")
		return _result("CAPSULE_BINDING")
	var height_value: Variant = (bound as Dictionary).get("height")
	if typeof(height_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(height_value)) or float(height_value) <= 0.0:
		adapter.call("dispose"); return _result("CAPSULE_HEIGHT")
	var plan := _find_plan(binding.seat, vehicle.global_transform, adapter, float(height_value), vehicle)
	if not bool(plan.get("ok", false)):
		adapter.call("dispose"); return plan
	var token := WetToken.new(_next_nonce); _next_nonce += 1
	var state := {
		"token": token, "epoch": _epoch, "phase": "HOLDING", "actor_key": actor_key,
		"actor_ref": actor_ref.duplicate(true), "vehicle_ref": vehicle_ref.duplicate(true),
		"profile_id": profile_id, "seat_id": seat_id, "seat": binding.seat,
		"actor": actor, "vehicle": vehicle, "adapter": adapter,
		"actor_instance_id": actor.get_instance_id(), "vehicle_instance_id": vehicle.get_instance_id(),
		"capsule_height": float(height_value), "distance": float(plan.distance),
		"started_clock": source_clock, "last_clock": source_clock,
		"elapsed": 0.0, "body_elapsed": 0.0, "body_velocity": Vector3.ZERO,
		"blocked": false, "next_owner_required": "",
	}
	_states[token.nonce] = state; _actor_tokens[actor_key] = token.nonce
	_actor_clocks[actor_key] = source_clock
	return _result("HOLDING", {"token": token, "authority_epoch": _epoch, "remaining_us": HOLD_DURATION_US,
		"distance_m": plan.distance, "seat_id": seat_id, "door_id": binding.seat.door_id})

func advance_hold(token: RefCounted, expected_epoch: int, pressed: bool, door_ready: bool, source_clock: int) -> Dictionary:
	var located := _locate(token, expected_epoch)
	if not bool(located.get("ok", false)): return located
	var state: Dictionary = located.state
	if state.phase != "HOLDING": return _result("PHASE")
	if source_clock <= int(state.last_clock): return _result("STALE_CLOCK")
	if source_clock - int(state.last_clock) > MAX_HOLD_GAP_US:
		_actor_clocks[state.actor_key] = source_clock
		_cancel_state(state); return _result("CONTINUITY_LOST")
	if not pressed or not door_ready:
		_actor_clocks[state.actor_key] = source_clock
		_cancel_state(state); return _result("RELEASED" if not pressed else "DOOR_NOT_READY")
	var valid := _validate_state(state)
	if not valid.is_empty(): _cancel_state(state); return _result(valid)
	var state_adapter := state.get("adapter") as RefCounted
	var state_vehicle := state.get("vehicle") as CollisionObject3D
	var plan := _find_plan(state.seat, state_vehicle.global_transform,
		state_adapter, float(state.capsule_height), state_vehicle)
	if not bool(plan.get("ok", false)):
		_cancel_state(state); return plan
	state.distance = float(plan.distance); state.last_clock = source_clock
	_actor_clocks[state.actor_key] = source_clock
	_states[(state.token as WetToken).nonce] = state
	var elapsed := source_clock - int(state.started_clock)
	if elapsed < HOLD_DURATION_US:
		return _result("HOLDING", {"token": token, "authority_epoch": _epoch, "held_us": elapsed,
			"remaining_us": HOLD_DURATION_US - elapsed, "distance_m": state.distance})
	state.phase = "TRANSITION_REQUIRED"; _states[(state.token as WetToken).nonce] = state
	return _result("TRANSITION_REQUIRED", {"token": token, "authority_epoch": _epoch,
		"release_duration_us": int(RELEASE_DURATION_S * 1000000.0), "body_duration_us": int(BODY_DURATION_S * 1000000.0)})

func begin_transition(token: RefCounted, expected_epoch: int, source_clock: int) -> Dictionary:
	var located := _locate(token, expected_epoch)
	if not bool(located.get("ok", false)): return located
	var state: Dictionary = located.state
	if state.phase != "TRANSITION_REQUIRED": return _result("PHASE")
	if source_clock <= int(state.last_clock): return _result("STALE_CLOCK")
	var valid := _validate_state(state)
	if not valid.is_empty(): _cancel_state(state); return _result(valid)
	if not ((state.vehicle as CollisionObject3D) in (state.actor as CharacterBody3D).get_collision_exceptions()):
		_cancel_state(state); return _result("SEATED_EXCEPTION_REQUIRED")
	var seat_pose: Dictionary = WaterPose.water_seat_point((state.vehicle as CollisionObject3D).global_transform, state.seat)
	if not bool(seat_pose.get("ok", false)) or (state.actor as CharacterBody3D).global_position.distance_to(seat_pose.world_position_m) > .25:
		_cancel_state(state); return _result("ACTOR_POSE")
	state.phase = "RELEASE"; state.elapsed = 0.0; state.last_clock = source_clock
	_actor_clocks[state.actor_key] = source_clock
	_states[(state.token as WetToken).nonce] = state
	return _result("ACTIVE", _public_state(state))

func advance(token: RefCounted, expected_epoch: int, delta: float, source_clock: int) -> Dictionary:
	var located := _locate(token, expected_epoch)
	if not bool(located.get("ok", false)): return located
	var state: Dictionary = located.state
	if state.phase not in ["RELEASE", "BODY"]: return _result("PHASE")
	if not is_finite(delta) or delta < 0.0 or delta > MAX_DELTA_S or source_clock <= int(state.last_clock): return _result("CLOCK")
	var valid := _validate_state(state)
	if not valid.is_empty(): _cancel_state(state); return _result(valid)
	state.last_clock = source_clock
	_actor_clocks[state.actor_key] = source_clock
	var remaining := delta; var latest := _result("ACTIVE")
	if remaining <= .0000001: latest = _advance_step(state, 0.0)
	while remaining > .0000001:
		var dt := minf(remaining, MAX_STEP_S)
		latest = _advance_step(state, dt); remaining -= dt
		if latest.code not in ["ACTIVE", "BLOCKED"]: break
		if latest.code == "BLOCKED" and state.phase == "RELEASE":
			_cancel_state(state)
			latest["retain_vehicle_owner"] = true
			return latest
	if latest.code in ["LIFETIME_ENDED", "INVALID_OUTWARD", "CALLBACK_RESULT", "CAPSULE_RESULT", "SOURCE_MOTION",
			"SOURCE_MOTION_IDENTITY", "SOURCE_MOTION_TRANSFORM", "SOURCE_STEP", "SOURCE_STEP_RANGE"]:
		_cancel_state(state); return latest
	if latest.code == "WET_AUTHORITY_PENDING":
		# The proof receipt is deliberately one-shot. There is no candidate-side
		# authority commit, so retaining an adapter/token after physical completion
		# would create an unauthorised second ownership lifetime.
		_cancel_state(state); latest["lease_consumed"] = true; latest["retain_vehicle_owner"] = true
		return latest
	_states[(state.token as WetToken).nonce] = state
	return latest

func cancel(token: RefCounted, expected_epoch: int, reason: String = "CANCELLED") -> Dictionary:
	var located := _locate(token, expected_epoch)
	if not bool(located.get("ok", false)): return located
	var state: Dictionary = located.state
	var abort_pose: Dictionary = {}
	if _validate_state(state).is_empty():
		abort_pose = WaterPose.water_seat_point((state.vehicle as CollisionObject3D).global_transform, state.seat)
	_cancel_state(state)
	return _result("CANCELLED", {"reason": reason, "retain_vehicle_owner": true, "abort_pose": abort_pose})

func reset(new_authority_epoch: int) -> Dictionary:
	if _disposed: return _result("DISPOSED")
	if not _configured or new_authority_epoch <= _epoch: return _result("STALE_EPOCH")
	_cancel_all(); _actor_clocks.clear(); _epoch = new_authority_epoch
	return _result("OK", {"authority_epoch": _epoch})

func state(token: RefCounted, expected_epoch: int) -> Dictionary:
	var located := _locate(token, expected_epoch)
	return _public_state(located.state) if bool(located.get("ok", false)) else located

func dispose() -> void:
	if _disposed: return
	_cancel_all(); _actor_clocks.clear(); _catalog = null; _water_at = Callable(); _ground_height = Callable()
	_planar_allowed = Callable(); _own_vehicle_clear = Callable(); _source_motion = Callable(); _configured = false; _disposed = true

func _advance_step(state: Dictionary, dt: float) -> Dictionary:
	var actor := state.actor as CharacterBody3D; var vehicle := state.vehicle as CollisionObject3D
	if state.phase == "RELEASE":
		state.elapsed = minf(RELEASE_DURATION_S, float(state.elapsed) + dt)
		var progress := clampf(float(state.elapsed) / RELEASE_DURATION_S, 0.0, 1.0)
		var pose: Dictionary = WaterPose.water_departure_point(vehicle.global_transform, state.seat, float(state.distance), progress)
		if not bool(pose.get("ok", false)) or not _adapter_can(state.adapter, pose.world_position_m, float(state.capsule_height)):
			state.blocked = true; return _result("BLOCKED", {"reason": "DOORWAY_BLOCKED", "pose": pose})
		if not _move_actual(actor, pose.world_position_m):
			state.blocked = true; return _result("BLOCKED", {"reason": "ACTUAL_MOVEMENT_BLOCKED", "pose": pose})
		if float(state.elapsed) < RELEASE_DURATION_S - .000001:
			return _result("ACTIVE", {"phase": "RELEASE", "progress": progress, "pose": pose})
		var seat_pose: Dictionary = WaterPose.water_seat_point(vehicle.global_transform, state.seat)
		if not bool(seat_pose.get("ok", false)): return _result("LIFETIME_ENDED")
		var outward := (pose.world_position_m as Vector3) - (seat_pose.world_position_m as Vector3); outward = outward.slide(Vector3.UP)
		if outward.length_squared() < .000001: return _result("INVALID_OUTWARD")
		var motion := _source_launch_motion(state, outward)
		if not bool(motion.get("ok", false)): return motion
		state.body_velocity = motion.native_velocity_mps
		var begun: Variant = (state.adapter as RefCounted).call("begin", _ground_height, _water_at)
		if not begun is Dictionary or typeof((begun as Dictionary).get("ok")) != TYPE_BOOL or not (begun as Dictionary).ok \
				or not (begun as Dictionary).get("state") is Dictionary:
			state.blocked = true; return _result("BLOCKED", {"reason": "SURFACE_BEGIN"})
		state.phase = "BODY"; state.body_elapsed = 0.0; state.elapsed = 0.0; state.blocked = false
		return _result("ACTIVE", {"phase": "BODY", "progress": 0.0})
	var velocity: Vector3 = state.body_velocity; var speed := velocity.length()
	var next_speed := maxf(0.0, speed - 6.0 * dt)
	var next_velocity := velocity * (next_speed / speed) if speed > .00001 else Vector3.ZERO
	var delta := (velocity + next_velocity) * .5 * dt
	var moved := _source_move_planar(actor.global_position, delta, EXIT_RADIUS_M)
	if not bool(moved.get("ok", false)): return moved
	var source_blocked := bool(moved.blocked)
	if source_blocked and dt > 0.0:
		next_velocity = Vector3((float(moved.x) - actor.global_position.x) / dt, 0.0,
			(float(moved.z) - actor.global_position.z) / dt)
	var proposed := Vector3(float(moved.x), actor.global_position.y, float(moved.z))
	state.body_velocity = next_velocity; state.body_elapsed = minf(BODY_DURATION_S, float(state.body_elapsed) + dt)
	var body_done := float(state.body_elapsed) >= BODY_DURATION_S - .000001
	var advanced: Variant = (state.adapter as RefCounted).call("advance", proposed.x, proposed.z, dt, body_done)
	if not advanced is Dictionary or typeof((advanced as Dictionary).get("ok")) != TYPE_BOOL or not (advanced as Dictionary).ok:
		state.blocked = true; return _result("CAPSULE_RESULT", {"reason": "CAPSULE_ADVANCE", "adapter": advanced})
	var row: Dictionary = advanced; var surface_state_value: Variant = row.get("state")
	var finish_value: Variant = row.get("finish_ready", false)
	if not surface_state_value is Dictionary or typeof(finish_value) != TYPE_BOOL: return _result("CAPSULE_RESULT")
	var surface_state: Dictionary = surface_state_value
	if typeof(surface_state.get("blocked")) != TYPE_BOOL or typeof(surface_state.get("grounded")) != TYPE_BOOL:
		return _result("CAPSULE_RESULT")
	state.blocked = bool(surface_state.blocked) or source_blocked
	if bool(finish_value):
		var next_owner_value: Variant = row.get("next_owner_required")
		if typeof(next_owner_value) not in [TYPE_STRING, TYPE_STRING_NAME]: return _result("CAPSULE_RESULT")
		var next_owner := String(next_owner_value)
		var water_value: Variant = surface_state.get("water")
		var has_water := water_value is Dictionary and not _water_sample(water_value).is_empty()
		if not bool(surface_state.grounded) or bool(surface_state.blocked) or next_owner not in ["swim", "on_foot"] \
				or next_owner != ("swim" if has_water else "on_foot"):
			return _result("CAPSULE_RESULT")
		state.phase = "WET_AUTHORITY_PENDING"; state.next_owner_required = next_owner
		return _result("WET_AUTHORITY_PENDING", _pending_receipt(state))
	return _result("BLOCKED" if state.blocked else "ACTIVE", {"phase": "BODY", "progress": float(state.body_elapsed) / BODY_DURATION_S,
		"blocked": state.blocked, "surface": row.get("state", {})})

func _binding(actor_ref: Dictionary, vehicle_ref: Dictionary, profile_id: String, seat_id: String,
		actor: CharacterBody3D, vehicle: CollisionObject3D, adapter: RefCounted) -> Dictionary:
	if profile_id.is_empty() or seat_id.is_empty() or actor == null or vehicle == null or adapter == null: return _result("IDENTITY")
	if not actor.is_inside_tree() or not vehicle.is_inside_tree() or actor.get_world_3d() != vehicle.get_world_3d(): return _result("WORLD")
	if not _body_identity(actor, actor_ref, "actor_id") or not _body_identity(vehicle, vehicle_ref, "vehicle_id"): return _result("IDENTITY")
	if String(vehicle.get_meta("profile_id", "")) != profile_id: return _result("PROFILE_IDENTITY")
	var profile_value: Variant = _catalog.call("profile", profile_id)
	var seat_value: Variant = _catalog.call("seat", profile_id, seat_id)
	if not profile_value is Dictionary or not seat_value is Dictionary: return _result("CATALOG_RESULT")
	var profile: Dictionary = profile_value
	var seat: Dictionary = seat_value
	if profile.is_empty() or seat.is_empty() or String(seat.get("id", "")) != seat_id or String(seat.get("door_id", "")) != seat_id:
		return _result("SEAT_IDENTITY")
	for method in ["bind", "valid", "can_occupy", "begin", "advance", "dispose"]:
		if not adapter.has_method(method): return _result("CAPSULE_ADAPTER")
	return {"ok": true, "seat": seat, "adapter": adapter}

func _find_plan(seat: Dictionary, vehicle_transform: Transform3D, adapter: RefCounted, height: float, vehicle: CollisionObject3D) -> Dictionary:
	var saw_wet := false
	for distance in [1.9, 2.4]:
		var endpoint: Dictionary = WaterPose.water_departure_point(vehicle_transform, seat, distance, 1.0)
		if not bool(endpoint.get("ok", false)): return _result("POSE")
		var endpoint_position: Vector3 = endpoint.world_position_m
		var endpoint_water := _water_sample(_water_at.call(endpoint_position.x, endpoint_position.z))
		if endpoint_water.is_empty() or not (endpoint_position.y < float(endpoint_water.level) - Surface.WATER_OFFSET_M): continue
		saw_wet = true
		var final_point := Vector3.ZERO; var clear := true
		for index in range(25):
			var pose: Dictionary = WaterPose.water_departure_point(vehicle_transform, seat, distance, float(index) / 24.0)
			if not bool(pose.get("ok", false)) or not _adapter_can(adapter, pose.get("world_position_m", Vector3(NAN,NAN,NAN)), height):
				clear = false; break
			final_point = pose.world_position_m
		if not clear: continue
		var vehicle_clear := _call_bool(_own_vehicle_clear, [vehicle, final_point, EXIT_RADIUS_M])
		if not bool(vehicle_clear.get("ok", false)): return _result("CALLBACK_RESULT")
		if not bool(vehicle_clear.value): continue
		if not Surface.can_ascend_from_vehicle(final_point, _water_at, Callable(adapter, "can_occupy"), height): continue
		return {"ok": true, "distance": distance, "landing": final_point}
	return _result("WET_BLOCKED" if saw_wet else "NOT_WET")

func _validate_state(state: Dictionary) -> String:
	if int(state.get("epoch", 0)) != _epoch: return "STALE_EPOCH"
	var actor := state.get("actor") as CharacterBody3D; var vehicle := state.get("vehicle") as CollisionObject3D
	if actor == null or vehicle == null or not is_instance_valid(actor) or not is_instance_valid(vehicle): return "LIFETIME_ENDED"
	if actor.get_instance_id() != int(state.actor_instance_id) or vehicle.get_instance_id() != int(state.vehicle_instance_id): return "LIFETIME_ENDED"
	if not actor.is_inside_tree() or not vehicle.is_inside_tree() or actor.get_world_3d() != vehicle.get_world_3d(): return "LIFETIME_ENDED"
	if not _body_identity(actor, state.actor_ref, "actor_id") or not _body_identity(vehicle, state.vehicle_ref, "vehicle_id"): return "LIFETIME_ENDED"
	if String(vehicle.get_meta("profile_id", "")) != String(state.profile_id): return "FOREIGN_VEHICLE"
	var current_seat_value: Variant = _catalog.call("seat", String(state.profile_id), String(state.seat_id))
	if not current_seat_value is Dictionary: return "CATALOG_RESULT"
	var current_seat: Dictionary = current_seat_value
	if current_seat != state.seat: return "SEAT_CHANGED"
	var adapter := state.get("adapter") as RefCounted
	if adapter == null or not adapter.has_method("valid"): return "CAPSULE_CHANGED"
	var valid_value: Variant = adapter.call("valid")
	if typeof(valid_value) != TYPE_BOOL or not bool(valid_value): return "CAPSULE_CHANGED"
	for callback in [_water_at, _ground_height, _planar_allowed, _own_vehicle_clear, _source_motion]:
		if not (callback as Callable).is_valid(): return "CALLBACK"
	return ""

func _locate(token: RefCounted, expected_epoch: int) -> Dictionary:
	var gate := _gate(expected_epoch)
	if not gate.is_empty(): return _result(gate)
	if token == null or not token is WetToken: return _result("TOKEN")
	var nonce := (token as WetToken).nonce; var state: Dictionary = _states.get(nonce, {})
	if state.is_empty() or state.get("token") != token: return _result("TOKEN")
	return {"ok": true, "state": state}

func _gate(expected_epoch: int) -> String:
	if _disposed: return "DISPOSED"
	if not _configured: return "NOT_CONFIGURED"
	if expected_epoch != _epoch: return "STALE_EPOCH"
	return ""

func _cancel_state(state: Dictionary) -> void:
	var token := state.get("token") as WetToken
	if token != null: _states.erase(token.nonce)
	_actor_tokens.erase(String(state.get("actor_key", "")))
	var adapter := state.get("adapter") as RefCounted
	if adapter != null and adapter.has_method("dispose"): adapter.call("dispose")

func _cancel_all() -> void:
	var values: Array = _states.values().duplicate()
	for value in values: _cancel_state(value)
	_states.clear(); _actor_tokens.clear()

func _pending_receipt(state: Dictionary) -> Dictionary:
	return {"provider": PROVIDER, "authority_pending": true, "host_seat_mutated": false,
		"authority_epoch": _epoch, "token": state.token, "actor": (state.actor_ref as Dictionary).duplicate(true),
		"vehicle": (state.vehicle_ref as Dictionary).duplicate(true), "profile_id": state.profile_id,
		"seat_id": state.seat_id, "source_exit_kind": "walk", "body_done": true,
		"surface_target_reached": true, "blocked": false, "next_owner_required": state.next_owner_required}

func _public_state(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	return {"provider": PROVIDER, "authority_epoch": _epoch, "phase": state.phase, "token": state.token,
		"profile_id": state.profile_id, "seat_id": state.seat_id, "source_clock": state.last_clock,
		"distance_m": state.distance, "elapsed_s": state.elapsed, "body_elapsed_s": state.body_elapsed,
		"body_velocity_mps": state.body_velocity, "blocked": state.blocked,
		"next_owner_required": state.next_owner_required, "host_seat_mutated": false}

func _adapter_can(adapter: RefCounted, point: Variant, height: float) -> bool:
	if not point is Vector3 or not (point as Vector3).is_finite() or adapter == null or not adapter.has_method("valid"):
		return false
	var valid_value: Variant = adapter.call("valid")
	if typeof(valid_value) != TYPE_BOOL or not bool(valid_value): return false
	var value: Variant = adapter.call("can_occupy", point, height)
	return typeof(value) == TYPE_BOOL and bool(value)

func _call_bool(callback: Callable, arguments: Array) -> Dictionary:
	if not callback.is_valid(): return {"ok": false}
	var value: Variant = callback.callv(arguments)
	return {"ok": typeof(value) == TYPE_BOOL, "value": bool(value) if typeof(value) == TYPE_BOOL else false}

func _source_launch_motion(state: Dictionary, outward_native: Vector3) -> Dictionary:
	var vehicle := state.get("vehicle") as CollisionObject3D
	var value: Variant = _source_motion.call(vehicle, int(state.last_clock))
	if not value is Dictionary: return _result("SOURCE_MOTION")
	var row: Dictionary = value
	if String(row.get("vehicle_id", "")) != String((state.vehicle_ref as Dictionary).get("vehicle_id", "")) \
			or int(row.get("life_generation", 0)) != int((state.vehicle_ref as Dictionary).get("life_generation", 0)) \
			or int(row.get("source_clock", 0)) != int(state.last_clock):
		return _result("SOURCE_MOTION_IDENTITY")
	for key in ["speed", "yaw"]:
		var number: Variant = row.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)): return _result("SOURCE_MOTION")
	var travel_value: Variant = row.yaw if row.get("travel_yaw") == null else row.travel_yaw
	if typeof(travel_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(travel_value)): return _result("SOURCE_MOTION")
	var side_value: Variant = (state.seat as Dictionary).get("source_side")
	if typeof(side_value) not in [TYPE_INT, TYPE_FLOAT] or absf(float(side_value)) != 1.0: return _result("SOURCE_MOTION")
	var inherited := float(row.speed) * .45; var source_yaw := float(row.yaw); var source_travel := float(travel_value)
	var native_forward := (vehicle.global_transform.basis * Vector3(0.0, 0.0, -1.0)).slide(Vector3.UP)
	if native_forward.length_squared() < .000001: return _result("SOURCE_MOTION_TRANSFORM")
	var transform_source_yaw := atan2(-native_forward.normalized().x, -native_forward.normalized().z)
	if absf(wrapf(source_yaw - transform_source_yaw, -PI, PI)) > .001: return _result("SOURCE_MOTION_TRANSFORM")
	var source_vx := sin(source_travel) * inherited + cos(source_yaw) * float(side_value) * .8
	var source_vz := cos(source_travel) * inherited - sin(source_yaw) * float(side_value) * .8
	var native_velocity := Vector3(-source_vx, 0.0, -source_vz)
	if not native_velocity.is_finite() or outward_native.length_squared() < .000001: return _result("SOURCE_MOTION")
	return {"ok": true, "native_velocity_mps": native_velocity, "source_speed_mps": float(row.speed),
		"source_yaw_rad": source_yaw, "source_travel_yaw_rad": source_travel}

func _source_move_planar(position: Vector3, delta: Vector3, radius: float) -> Dictionary:
	if not position.is_finite() or not delta.is_finite() or not is_finite(radius) or radius <= 0.0: return _result("SOURCE_STEP")
	var count := maxi(1, ceili(Vector2(delta.x, delta.z).length() / minf(.12, radius * .5)))
	if count > 200: return _result("SOURCE_STEP_RANGE")
	var x := position.x; var z := position.z; var dx := delta.x / float(count); var dz := delta.z / float(count)
	for index in range(count):
		var diagonal := _source_circle_fits(x + dx, z + dz, radius)
		if not bool(diagonal.get("ok", false)): return diagonal
		if bool(diagonal.value): x += dx; z += dz; continue
		var x_only := _source_circle_fits(x + dx, z, radius)
		if not bool(x_only.get("ok", false)): return x_only
		if bool(x_only.value): x += dx; continue
		var z_only := _source_circle_fits(x, z + dz, radius)
		if not bool(z_only.get("ok", false)): return z_only
		if bool(z_only.value): z += dz
	var blocked := Vector2(x - position.x - delta.x, z - position.z - delta.z).length() > .001
	return {"ok": true, "x": x, "z": z, "blocked": blocked}

func _source_circle_fits(x: float, z: float, radius: float) -> Dictionary:
	var center := _call_bool(_planar_allowed, [x, z])
	if not bool(center.get("ok", false)) or not bool(center.value): return center
	for index in range(12):
		var angle := float(index) * PI / 6.0
		var sample := _call_bool(_planar_allowed, [x + cos(angle) * radius, z + sin(angle) * radius])
		if not bool(sample.get("ok", false)) or not bool(sample.value): return sample
	return {"ok": true, "value": true}

func _water_sample(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var row: Dictionary = value; var depth: Variant = row.get("depth"); var level: Variant = row.get("level")
	if typeof(depth) not in [TYPE_INT, TYPE_FLOAT] or not (float(depth) > 0.0): return {}
	if typeof(level) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(level)): return {}
	return row

func _move_actual(actor: CharacterBody3D, target: Vector3) -> bool:
	if not target.is_finite(): return false
	var motion := target - actor.global_position
	var horizontal := motion.slide(Vector3.UP)
	if horizontal.length_squared() > .00000001 and actor.move_and_collide(horizontal) != null: return false
	var vertical := Vector3.UP * (target.y - actor.global_position.y)
	if vertical.length_squared() > .00000001 and actor.move_and_collide(vertical) != null: return false
	return actor.global_position.distance_to(target) <= .002

func _body_identity(body: CollisionObject3D, ref: Dictionary, id_field: String) -> bool:
	var id := String(ref.get(id_field, "")); var generation := int(ref.get("life_generation", 0))
	return not id.is_empty() and generation > 0 and String(body.get_meta(id_field, "")) == id and int(body.get_meta("life_generation", 0)) == generation

func _actor_key(ref: Dictionary) -> String:
	var id := String(ref.get("actor_id", "")); var generation := int(ref.get("life_generation", 0))
	return "%s@%d" % [id, generation] if not id.is_empty() and generation > 0 else ""

func _result(code: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"code": code}; out.merge(extra); return out
