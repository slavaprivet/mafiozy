class_name NativeLadderMotion
extends RefCounted
## Pure deterministic World ladder route. The host owns physics and every body write.

const PROVIDER := "GODOT_LADDER_MOTION_V1"
const CLIMB_SPEED_MPS := 3.1
const SLIDE_SPEED_MPS := 7.2
const MAX_DELTA_S := .25
const SWEEP_STEP_M := .04
const BODY_HEIGHT_M := 1.9
const MOUNT_BLEND_S := .2
const DISMOUNT_BLEND_S := .2
const _EPSILON := .0000001


static func begin(feet: Vector3, descriptor: Dictionary, end: String) -> Dictionary:
	if not feet.is_finite() or not bool(descriptor.get("valid", false)) or end not in ["lower", "upper"]:
		return _invalid("invalid_begin")
	var route: Array = descriptor.path.duplicate()
	route.append(descriptor.step_off_point)
	var path: Array = [feet]
	if end == "lower":
		path.append_array(route)
	else:
		var down: Array = descriptor.path.duplicate()
		down.reverse()
		path.append_array(down)
	var totals := _path_totals(path)
	return {
		"provider":PROVIDER, "valid":true, "status":"active", "done":false, "blocked":false,
		"aborted":false, "reason":"active", "revision":0, "descriptor":descriptor.duplicate(true),
		"route":route, "path":path, "index":1, "root_position":feet, "travelled_m":0.0,
		"total_m":totals.total, "exit_start_m":totals.exit_start, "direction":1 if end == "lower" else -1,
		"sliding":false, "cancelling":false, "history":[feet], "elapsed_s":0.0,
		"mount_progress":0.0, "dismount_progress":0.0, "entry_end":end,
		"releasing":false, "release_elapsed_s":0.0,
	}


static func propose(state: Dictionary, delta_s: float) -> Dictionary:
	if not _active(state):
		return {"provider":PROVIDER, "valid":false, "reason":"not_active", "sweep_samples":[]}
	if not is_finite(delta_s) or delta_s < 0.0:
		return {"provider":PROVIDER, "valid":false, "reason":"invalid_delta", "sweep_samples":[]}
	var work := state.duplicate(true)
	work.blocked = false
	work.reason = "active"
	var remaining := minf(delta_s, MAX_DELTA_S)
	var samples: Array[Dictionary] = []
	while remaining > _EPSILON and int(work.index) < work.path.size():
		var goal: Vector3 = work.path[int(work.index)]
		var position: Vector3 = work.root_position
		var distance := position.distance_to(goal)
		if distance <= _EPSILON:
			_reach_goal(work, goal)
			continue
		var delta := goal - position
		var vertical_down := delta.y < -.01 and Vector2(delta.x, delta.z).length() < .02
		var speed := SLIDE_SPEED_MPS if bool(work.sliding) and vertical_down else CLIMB_SPEED_MPS
		var move := minf(distance, minf(speed * remaining, SWEEP_STEP_M))
		work.root_position = position.lerp(goal, move / distance)
		work.travelled_m = float(work.travelled_m) + move
		var spent := move / speed
		work.elapsed_s = float(work.elapsed_s) + spent
		remaining -= spent
		if distance <= move + _EPSILON:
			_reach_goal(work, goal)
		_update_blends(work)
		work.revision = int(work.revision) + 1
		samples.append(_sample(work))
	if int(work.index) >= work.path.size():
		if _uses_route_dismount(work):
			_complete(work)
			work.dismount_progress = 1.0
			if samples.is_empty():
				samples.append(_sample(work))
			else:
				samples[samples.size() - 1] = _sample(work)
		else:
			if not bool(work.get("releasing", false)):
				work.releasing = true
				work.release_elapsed_s = 0.0
				work.dismount_progress = 0.0
				work.revision = int(work.revision) + 1
				samples.append(_sample(work))
			if remaining > _EPSILON and float(work.release_elapsed_s) < DISMOUNT_BLEND_S:
				var release_spent := minf(remaining, DISMOUNT_BLEND_S - float(work.release_elapsed_s))
				work.release_elapsed_s = float(work.release_elapsed_s) + release_spent
				work.elapsed_s = float(work.elapsed_s) + release_spent
				work.dismount_progress = clampf(float(work.release_elapsed_s) / DISMOUNT_BLEND_S, 0.0, 1.0)
				work.revision = int(work.revision) + 1
				samples.append(_sample(work))
			if float(work.dismount_progress) >= 1.0 - _EPSILON:
				_complete(work)
				work.dismount_progress = 1.0
				samples[samples.size() - 1] = _sample(work)
	return {"provider":PROVIDER, "valid":true, "reason":"proposal", "source_revision":int(state.revision),
		"sweep_samples":samples, "target_state":work, "root_position":work.root_position,
		"yaw_rad":float(work.descriptor.yaw_rad), "terminal":bool(work.done)}


static func commit(state: Dictionary, proposal: Dictionary, accepted_samples: int = -1, blocked_reason: String = "dynamic_blocked") -> Dictionary:
	if not _active(state) or not bool(proposal.get("valid", false)) or int(proposal.get("source_revision", -1)) != int(state.get("revision", -2)):
		return abort(state, "stale_or_invalid_proposal")
	var samples: Array = proposal.get("sweep_samples", [])
	var accepted := samples.size() if accepted_samples < 0 else clampi(accepted_samples, 0, samples.size())
	var result := state.duplicate(true)
	if accepted > 0:
		result = (samples[accepted - 1] as Dictionary).state.duplicate(true)
	if accepted < samples.size():
		result.status = "active"
		result.done = false
		result.blocked = true
		result.reason = blocked_reason if not blocked_reason.is_empty() else "dynamic_blocked"
		result.revision = int(result.revision) + 1
	elif samples.is_empty():
		result.blocked = false
		result.reason = "active"
	return result


static func slide_down(state: Dictionary) -> Dictionary:
	if not _active(state):
		return _invalid("not_active")
	var result := state.duplicate(true)
	if int(result.direction) < 0:
		result.sliding = true
		result.blocked = false
		result.reason = "active"
		result.revision = int(result.revision) + 1
		return result
	var position: Vector3 = result.root_position
	var route: Array = result.route
	var best := {"index":1, "point":route[0], "distance":INF}
	for index in range(1, route.size()):
		var a: Vector3 = route[index - 1]
		var b: Vector3 = route[index]
		var segment := b - a
		var length_squared := segment.length_squared()
		var t := clampf((position - a).dot(segment) / length_squared, 0.0, 1.0) if length_squared > _EPSILON else 0.0
		var point := a.lerp(b, t)
		var distance := position.distance_to(point)
		if distance < float(best.distance):
			best = {"index":index, "point":point, "distance":distance}
	var reverse: Array = route.slice(0, int(best.index))
	reverse.reverse()
	result.path = [position, best.point]
	result.path.append_array(reverse)
	result.index = 1
	result.direction = -1
	result.sliding = true
	result.cancelling = false
	result.history = [position]
	result.total_m = _path_totals(result.path).total
	result.exit_start_m = 0.0
	result.travelled_m = 0.0
	result.dismount_progress = 0.0
	result.releasing = false
	result.release_elapsed_s = 0.0
	result.blocked = false
	result.reason = "active"
	result.revision = int(result.revision) + 1
	return result


static func cancel(state: Dictionary) -> Dictionary:
	if not _active(state):
		return _invalid("not_active")
	var result := state.duplicate(true)
	if bool(result.sliding):
		result.sliding = false
		result.cancelling = true
		result.blocked = false
		result.reason = "active"
		result.revision = int(result.revision) + 1
		return result
	if bool(result.cancelling):
		return result
	var reverse: Array = result.history.duplicate()
	reverse.reverse()
	result.path = [result.root_position]
	result.path.append_array(reverse)
	result.index = 1
	result.direction = -int(result.direction)
	result.sliding = false
	result.cancelling = true
	result.total_m = _path_totals(result.path).total
	result.exit_start_m = 0.0
	result.travelled_m = 0.0
	result.dismount_progress = 0.0
	result.releasing = false
	result.release_elapsed_s = 0.0
	result.blocked = false
	result.reason = "active"
	result.revision = int(result.revision) + 1
	return result


static func abort(state: Dictionary, reason: String = "aborted") -> Dictionary:
	var result := state.duplicate(true)
	if not bool(result.get("valid", false)):
		return _invalid("invalid_state")
	if bool(result.get("done", false)):
		return result
	result.status = "aborted"
	result.done = true
	result.aborted = true
	result.blocked = false
	result.reason = reason if not reason.is_empty() else "aborted"
	result.revision = int(result.get("revision", 0)) + 1
	return result


static func route_points(state: Dictionary) -> Array:
	return state.get("path", []).duplicate()


static func landing_end(state: Dictionary) -> String:
	return "upper" if int(state.get("direction", 0)) > 0 and not bool(state.get("cancelling", false)) else "lower" if (state.get("path", []) as Array).back().distance_to(state.descriptor.lower) < .01 else "upper"


static func requires_terminal_support(state: Dictionary) -> bool:
	return bool(state.get("valid", false)) and (bool(state.get("releasing", false)) or int(state.get("index", 0)) >= (state.get("path", []) as Array).size())


static func _sample(state: Dictionary) -> Dictionary:
	return {"root_position":state.root_position, "yaw_rad":float(state.descriptor.yaw_rad),
		"collision_height_m":BODY_HEIGHT_M, "travelled_m":float(state.travelled_m),
		"direction":int(state.direction), "sliding":bool(state.sliding), "cancelling":bool(state.cancelling),
		"mount_progress":float(state.mount_progress), "dismount_progress":float(state.dismount_progress),
		"releasing":bool(state.get("releasing", false)), "done":bool(state.done), "state":state.duplicate(true)}


static func _reach_goal(state: Dictionary, goal: Vector3) -> void:
	state.root_position = goal
	state.index = int(state.index) + 1
	(state.history as Array).append(goal)


static func _update_blends(state: Dictionary) -> void:
	state.mount_progress = clampf(float(state.elapsed_s) / MOUNT_BLEND_S, 0.0, 1.0)
	if _uses_route_dismount(state):
		state.dismount_progress = clampf((float(state.travelled_m) - float(state.exit_start_m)) / maxf(.01, float(state.total_m) - float(state.exit_start_m)), 0.0, 1.0)
	elif not bool(state.get("releasing", false)):
		state.dismount_progress = 0.0


static func _uses_route_dismount(state: Dictionary) -> bool:
	return int(state.direction) > 0 and not bool(state.cancelling)


static func _complete(state: Dictionary) -> void:
	state.status = "complete"
	state.done = true
	state.blocked = false
	state.reason = "complete"


static func _path_totals(path: Array) -> Dictionary:
	var total := 0.0
	var exit_start := 0.0
	for index in range(1, path.size()):
		total += (path[index - 1] as Vector3).distance_to(path[index])
		if index == 2:
			exit_start = total
	return {"total":total, "exit_start":exit_start}


static func _active(state: Dictionary) -> bool:
	return bool(state.get("valid", false)) and not bool(state.get("done", true))


static func _invalid(reason: String) -> Dictionary:
	return {"provider":PROVIDER, "valid":false, "status":"invalid", "done":true, "blocked":false, "aborted":false, "reason":reason}
