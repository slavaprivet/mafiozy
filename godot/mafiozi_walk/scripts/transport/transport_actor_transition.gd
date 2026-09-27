extends RefCounted

const Timing = preload("res://scripts/transport/transport_timing.gd")

const PROVIDER := "TRANSPORT_ACTOR_TRANSITION_V1"
const EXIT_TUMBLE_SPEED := 15.0 / 3.6
const MAX_STEP := .1
const MAX_DELTA := 1.0
const SEAT_TOLERANCE := .08
const APPROACH_TOLERANCE := .25

var _access: RefCounted
var _states: Dictionary = {}
var _owned_seated_exceptions: Dictionary = {}

func configure(access_provider: RefCounted) -> void:
	_access = access_provider

func begin(token: String, action: String, actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int,
		actor: CharacterBody3D, vehicle: RigidBody3D, seat_local_m: Vector3, approach_local_m: Vector3) -> Dictionary:
	if token.is_empty() or _states.has(token): return _result("TOKEN")
	if action not in ["BOARD", "EXIT"] or source_clock < 1: return _result("REQUEST")
	if not _body_identity(actor, actor_ref, "actor_id") or not _body_identity(vehicle, vehicle_ref, "vehicle_id"): return _result("IDENTITY")
	if not actor.is_inside_tree() or not vehicle.is_inside_tree() or actor.get_world_3d() != vehicle.get_world_3d(): return _result("WORLD")
	if action == "BOARD" and vehicle.linear_velocity.length() > .5: return _result("VEHICLE_MOVING")
	var seat_world := vehicle.global_transform * seat_local_m
	var approach_world := vehicle.global_transform * approach_local_m
	var expected := approach_world if action == "BOARD" else seat_world
	if actor.global_position.distance_to(expected) > APPROACH_TOLERANCE: return _result("ACTOR_POSE")
	var exception_key := _exception_key(actor_ref, vehicle_ref)
	var already_excepted := vehicle in actor.get_collision_exceptions()
	if not already_excepted: actor.add_collision_exception_with(vehicle)
	var speed := vehicle.linear_velocity.length()
	var state := {
		"token": token, "action": action, "actor_ref": actor_ref.duplicate(true), "vehicle_ref": vehicle_ref.duplicate(true), "seat_id": seat_id,
		"actor": actor, "vehicle": vehicle, "seat_local_m": seat_local_m, "approach_local_m": approach_local_m,
		"source_clock_started": source_clock, "source_clock": source_clock, "elapsed": 0.0, "phase": "ENTRY" if action == "BOARD" else "RELEASE",
		"exit_kind": "tumble" if speed > EXIT_TUMBLE_SPEED else "walk", "recovery_velocity": Vector3.ZERO,
		"exception_added": not already_excepted, "exception_key": exception_key, "blocked": false,
	}
	_states[token] = state
	return _result("ACTIVE", _public_state(state))

func step(token: String, delta: float, source_clock: int) -> Dictionary:
	if not _states.has(token): return _result("TOKEN")
	var state: Dictionary = _states[token]
	if not is_finite(delta) or delta < 0.0 or delta > MAX_DELTA or source_clock <= int(state.source_clock): return _result("CLOCK")
	if state.phase == "COMPLETE":
		state.source_clock = source_clock
		var cached: Dictionary = state.completed_result.duplicate(true)
		cached.receipt.source_clock = source_clock
		_states[token] = state
		return cached
	var actor := state.actor as CharacterBody3D; var vehicle := state.vehicle as RigidBody3D
	if not is_instance_valid(actor) or not is_instance_valid(vehicle) or not actor.is_inside_tree() or not vehicle.is_inside_tree():
		_cancel_state(state); return _result("LIFETIME_ENDED")
	if not _body_identity(actor, state.actor_ref, "actor_id") or not _body_identity(vehicle, state.vehicle_ref, "vehicle_id"):
		_cancel_state(state); return _result("LIFETIME_ENDED")
	state.source_clock = source_clock
	var remaining := delta; var result: Dictionary = {}
	if remaining <= .0000001:
		result = _step_board(state, actor, vehicle, 0.0) if state.action == "BOARD" else _step_exit(state, actor, vehicle, 0.0)
	while remaining > .0000001:
		var dt := minf(remaining, MAX_STEP)
		result = _step_board(state, actor, vehicle, dt) if state.action == "BOARD" else _step_exit(state, actor, vehicle, dt)
		remaining -= dt
		if result.code in ["BLOCKED", "COMPLETE"]: break
	if result.code == "BLOCKED":
		state.blocked = true; _states[token] = state
		return result
	if result.code == "COMPLETE":
		var required_us := Timing.BOARD_DURATION_US if state.action == "BOARD" else Timing.EXIT_RELEASE_US + (Timing.EXIT_TUMBLE_RECOVERY_US if state.exit_kind == "tumble" else Timing.EXIT_WALK_RECOVERY_US)
		var clock_elapsed := source_clock - int(state.source_clock_started)
		if clock_elapsed < required_us:
			_states[token] = state
			return _result("ACTIVE", {"source_clock_remaining_us": required_us - clock_elapsed, "pose": result.get("pose", _public_state(state))})
		state.phase = "COMPLETE"; state.completed_result = result.duplicate(true); _states[token] = state
		return result
	_states[token] = state
	return result

func cancel(token: String) -> Dictionary:
	if not _states.has(token): return _result("TOKEN")
	var state: Dictionary = _states[token]; _cancel_state(state)
	return _result("CANCELLED")

func commit(token: String) -> Dictionary:
	if not _states.has(token): return _result("TOKEN")
	var state: Dictionary = _states[token]
	if state.get("phase", "") != "COMPLETE": return _result("PHASE")
	var actor := state.actor as CharacterBody3D; var vehicle := state.vehicle as RigidBody3D
	if state.action == "BOARD":
		if bool(state.exception_added): _owned_seated_exceptions[state.exception_key] = {"actor": actor, "vehicle": vehicle}
	else:
		var owned_exception: Dictionary = _owned_seated_exceptions.get(state.exception_key, {})
		if (bool(state.exception_added) or not owned_exception.is_empty()) and is_instance_valid(actor) and is_instance_valid(vehicle): actor.remove_collision_exception_with(vehicle)
		_owned_seated_exceptions.erase(state.exception_key)
	_states.erase(token)
	return _result("COMMITTED")

func cancel_all() -> void:
	for value in _states.values(): _cancel_state(value, true)
	_states.clear()
	for value in _owned_seated_exceptions.values():
		var actor := value.get("actor") as CharacterBody3D; var vehicle := value.get("vehicle") as RigidBody3D
		if is_instance_valid(actor) and is_instance_valid(vehicle): actor.remove_collision_exception_with(vehicle)
	_owned_seated_exceptions.clear()

func state(token: String) -> Dictionary:
	return _public_state(_states.get(token, {}))

func _step_board(state: Dictionary, actor: CharacterBody3D, vehicle: RigidBody3D, dt: float) -> Dictionary:
	state.elapsed = minf(Timing.BOARD_DURATION_S, float(state.elapsed) + dt)
	var progress := clampf(float(state.elapsed) / Timing.BOARD_DURATION_S, 0.0, 1.0)
	var seat_blend := _smooth((progress - .29) / .44)
	var local: Vector3 = (state.approach_local_m as Vector3).lerp(state.seat_local_m as Vector3, seat_blend)
	local.y += .08 * sin(PI * seat_blend)
	var target := vehicle.global_transform * local
	if not _move_actual(actor, target): return _result("BLOCKED", _public_state(state))
	var side := float(state.get("seat_local_m", Vector3.ZERO).x)
	var vehicle_yaw := vehicle.global_rotation.y
	actor.global_rotation.y = lerp_angle(actor.global_rotation.y, vehicle_yaw + signf(side) * (1.0 - seat_blend) * PI * .5, clampf(dt * 8.0, 0.0, 1.0))
	if float(state.elapsed) < Timing.BOARD_DURATION_S - .000001: return _result("ACTIVE", _pose_state(state, progress, seat_blend))
	var seat_world := vehicle.global_transform * (state.seat_local_m as Vector3)
	if actor.global_position.distance_to(seat_world) > SEAT_TOLERANCE: return _result("BLOCKED", _public_state(state))
	return _result("COMPLETE", {"receipt": _receipt(state, {"seat_reached": true}), "pose": _pose_state(state, 1.0, 1.0)})

func _step_exit(state: Dictionary, actor: CharacterBody3D, vehicle: RigidBody3D, dt: float) -> Dictionary:
	if state.phase == "RELEASE":
		state.elapsed = minf(Timing.EXIT_RELEASE_S, float(state.elapsed) + dt)
		var progress := clampf(float(state.elapsed) / Timing.EXIT_RELEASE_S, 0.0, 1.0)
		var u := 1.0 - progress
		var seat_blend := _smooth((u - .25) / .5)
		var local: Vector3 = (state.approach_local_m as Vector3).lerp(state.seat_local_m as Vector3, seat_blend)
		local.y += .08 * sin(PI * seat_blend)
		if not _move_actual(actor, vehicle.global_transform * local): return _result("BLOCKED", _public_state(state))
		var side := float((state.seat_local_m as Vector3).x)
		actor.global_rotation.y = vehicle.global_rotation.y + signf(side) * (1.0 - seat_blend) * PI * .5
		if float(state.elapsed) < Timing.EXIT_RELEASE_S - .000001: return _result("ACTIVE", _pose_state(state, progress, seat_blend))
		var outward := (vehicle.global_basis * ((state.approach_local_m as Vector3) - (state.seat_local_m as Vector3))).slide(Vector3.UP).normalized()
		var tumble: bool = state.exit_kind == "tumble"
		state.recovery_velocity = vehicle.linear_velocity.slide(Vector3.UP) * (.6 if tumble else .45) + outward * (2.4 if tumble else .8)
		state.recovery_initial_speed_mps = (state.recovery_velocity as Vector3).length()
		state.recovery_distance_m = 0.0
		state.phase = "RECOVERY"; state.elapsed = 0.0
		return _result("ACTIVE", _pose_state(state, 0.0, 0.0))
	var duration := Timing.EXIT_TUMBLE_RECOVERY_S if state.exit_kind == "tumble" else Timing.EXIT_WALK_RECOVERY_S
	var old_velocity: Vector3 = state.recovery_velocity
	var speed := old_velocity.length()
	var next_speed := maxf(0.0, speed - (9.0 if state.exit_kind == "tumble" else 6.0) * dt)
	var next_velocity := old_velocity * (next_speed / speed) if speed > 0.00001 else Vector3.ZERO
	var motion := (old_velocity + next_velocity) * .5 * dt
	var vertical_speed := float(state.get("recovery_vertical_speed_mps", 0.0)) - float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8)) * dt
	motion.y = vertical_speed * dt
	var before := actor.global_position
	var remaining_motion := motion
	for contact in range(4):
		if remaining_motion.length_squared() < .00000001: break
		var collision := actor.move_and_collide(remaining_motion)
		if collision == null: break
		if collision.get_normal().dot(Vector3.UP) >= .7 and vertical_speed < 0.0: vertical_speed = 0.0
		remaining_motion = collision.get_remainder().slide(collision.get_normal())
	state.recovery_vertical_speed_mps = vertical_speed
	var actual := actor.global_position - before
	state.recovery_distance_m = float(state.get("recovery_distance_m", 0.0)) + actual.slide(Vector3.UP).length()
	var blocked := (actual.slide(Vector3.UP) - motion.slide(Vector3.UP)).length() > .001
	state.blocked = blocked
	state.recovery_velocity = actual.slide(Vector3.UP) / dt if blocked and dt > 0.0 else next_velocity
	if actual.slide(Vector3.UP).length_squared() > .000001: actor.global_rotation.y = atan2(-actual.x, -actual.z)
	state.elapsed = minf(duration, float(state.elapsed) + dt)
	var progress := clampf(float(state.elapsed) / duration, 0.0, 1.0)
	if float(state.elapsed) < duration - .000001: return _result("ACTIVE", _pose_state(state, progress, 0.0))
	var physical := _final_exit_probe(state, actor, vehicle)
	var ground_collision := KinematicCollision3D.new()
	var touching_floor := actor.test_move(actor.global_transform, Vector3.DOWN * .005, ground_collision, .001, true) and ground_collision.get_normal().dot(Vector3.UP) >= .7
	if not touching_floor: return _result("BLOCKED", {"physical": physical, "pose": _pose_state(state, progress, 0.0), "reason":"AWAIT_PHYSICAL_GROUND"})
	if not bool(physical.get("reachable", false)): return _result("BLOCKED", {"physical": physical, "pose": _pose_state(state, progress, 0.0)})
	actor.velocity = Vector3.ZERO
	return _result("COMPLETE", {"receipt": _receipt(state, {"outside_reached": true, "source_exit_kind": state.exit_kind, "door_release_done": true, "recovery_done": true, "grounded": true, "blocked": false}), "physical": physical, "pose": _pose_state(state, 1.0, 0.0)})

func _move_actual(actor: CharacterBody3D, target: Vector3) -> bool:
	var motion := target - actor.global_position
	if motion.length_squared() <= .00000001: return true
	# Split planar and vertical motion so a resting floor cannot cancel the
	# horizontal part of the staged doorway sweep.
	var horizontal := motion.slide(Vector3.UP)
	if horizontal.length_squared() > .00000001 and actor.move_and_collide(horizontal) != null: return false
	var vertical := Vector3.UP * (target.y - actor.global_position.y)
	if vertical.length_squared() > .00000001:
		var collision := actor.move_and_collide(vertical)
		if collision != null and not (vertical.y < 0.0 and collision.get_normal().dot(Vector3.UP) >= .7): return false
	var horizontal_error := (actor.global_position - target).slide(Vector3.UP).length()
	return horizontal_error <= .01 and actor.global_position.y >= target.y - .02

func _final_exit_probe(state: Dictionary, actor: CharacterBody3D, vehicle: RigidBody3D) -> Dictionary:
	if _access == null: return {"reachable": false}
	_access.configure(actor.get_world_3d().direct_space_state, actor.collision_mask)
	var exclude: Array[RID] = [actor.get_rid(), vehicle.get_rid()]
	return _access.probe_access(state.actor_ref, state.vehicle_ref, state.seat_id, "EXIT", int(state.source_clock), actor.global_position, actor.global_position, exclude)

func _receipt(state: Dictionary, extra: Dictionary) -> Dictionary:
	var receipt := {"provider": PROVIDER, "action": state.action, "token": state.token, "source_clock": state.source_clock, "pose_done": true, "physical_safe": true}
	receipt.merge(extra)
	return receipt

func _pose_state(state: Dictionary, progress: float, seat_blend: float) -> Dictionary:
	var out := _public_state(state); out["progress"] = progress; out["seat_blend"] = seat_blend
	if state.action == "BOARD":
		var inner_leg := _smooth((progress - .30) / .25); var outer_leg := _smooth((progress - .55) / .25)
		var hand_reach := _smooth(progress / .12) * (1.0 - _smooth((progress - .24) / .13))
		var close_reach := _smooth((progress - .81) / .08) * (1.0 - _smooth((progress - .93) / .07))
		out.merge({"source_phase": _entry_phase(progress), "fold": (inner_leg + outer_leg) * .5, "door": _smooth((progress - .10) / .17) * (1.0 - _smooth((progress - .87) / .13)), "reach": maxf(hand_reach, close_reach) * .8, "hand_reach": hand_reach, "duck": _smooth((progress - .20) / .16) * (1.0 - _smooth((progress - .71) / .14)), "inner_leg": inner_leg, "outer_leg": outer_leg, "close_reach": close_reach})
	elif state.phase == "RELEASE":
		var u := 1.0 - progress
		out.merge({"source_phase":"exit", "fold":_smooth((u - .12) / .36), "door":_smooth(progress / .2) * (1.0 - _smooth((progress - .8) / .2)), "reach":sin(PI * progress) * .8})
	else:
		out.merge({"source_phase":"exit_body", "door":maxf(0.0, 1.0 - float(state.elapsed) / .3), "body_progress":progress, "recovery_initial_speed_mps":state.get("recovery_initial_speed_mps",0.0), "recovery_speed_mps":(state.recovery_velocity as Vector3).length(), "recovery_elapsed_s":state.elapsed, "recovery_distance_m":state.get("recovery_distance_m",0.0), "body_hop_m":.28 * sin(PI * float(state.elapsed) / .3) if state.exit_kind == "tumble" and float(state.elapsed) < .3 else 0.0, "body_visual_lift_m":.28 * sin(PI * float(state.elapsed) / .3) if state.exit_kind == "tumble" and float(state.elapsed) < .3 else 0.0})
	return out

func _entry_phase(progress: float) -> String:
	if progress < .12: return "reach"
	if progress < .26: return "open"
	if progress < .35: return "duck"
	if progress < .49: return "inner_leg"
	if progress < .61: return "sit"
	if progress < .8: return "outer_leg"
	if progress < 1.0: return "close"
	return "seated"

func _public_state(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	return {"token": state.token, "action": state.action, "seat_id": state.seat_id, "phase": state.phase, "elapsed": state.elapsed, "exit_kind": state.exit_kind, "blocked": state.blocked, "recovery_initial_speed_mps":state.get("recovery_initial_speed_mps",0.0), "recovery_speed_mps":(state.recovery_velocity as Vector3).length(), "recovery_elapsed_s":state.elapsed if state.phase == "RECOVERY" else 0.0, "recovery_distance_m":state.get("recovery_distance_m",0.0)}

func _cancel_state(state: Dictionary, release_all: bool = false) -> void:
	_states.erase(state.token)
	var actor := state.actor as CharacterBody3D; var vehicle := state.vehicle as RigidBody3D
	if bool(state.exception_added) and is_instance_valid(actor) and is_instance_valid(vehicle):
		if state.action == "BOARD" or release_all or state.get("phase", "") == "COMPLETE": actor.remove_collision_exception_with(vehicle)
		else: _owned_seated_exceptions[state.exception_key] = {"actor": actor, "vehicle": vehicle}

func _body_identity(body: CollisionObject3D, ref: Dictionary, id_field: String) -> bool:
	return body != null and String(body.get_meta(id_field, "")) == String(ref.get(id_field, "")) and int(body.get_meta("life_generation", 0)) == int(ref.get("life_generation", -1))

func _exception_key(actor_ref: Dictionary, vehicle_ref: Dictionary) -> String:
	return "%s@%d|%s@%d" % [actor_ref.get("actor_id", ""), actor_ref.get("life_generation", 0), vehicle_ref.get("vehicle_id", ""), vehicle_ref.get("life_generation", 0)]

func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _result(code: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"code": code}; out.merge(extra); return out






