class_name NativeTraversalMotion
extends RefCounted
## Pure source-parity traversal trajectory. A physics host owns every sweep and
## body write. This helper only validates an admitted plan and proposes roots.

const PROVIDER := "GODOT_TRAVERSAL_MOTION_V1"
const STANDING_HEIGHT_M := 1.9
const CARRY_HEIGHT_M := 1.1
const LIFT_END := .28
const CARRY_END := .76
const CROUCH_IN_END := .2
const SWEEP_STEP_M := .04
const MIN_DURATION_S := .85
const MAX_DURATION_S := 1.25
const _EPSILON := .000001


## Accepts NativeTraversalProbe receipts and source-shaped plans. It returns a
## detached state; neither the input plan nor any Node/physics object is kept.
static func begin(plan: Dictionary) -> Dictionary:
	var normalized := _normalize_plan(plan)
	if not bool(normalized.get("valid", false)):
		return _invalid_state(str(normalized.get("reason", "invalid_plan")))
	var first := _sample(normalized, 0.0)
	return {
		"provider": PROVIDER,
		"valid": true,
		"status": "active",
		"done": false,
		"blocked": false,
		"aborted": false,
		"reason": "active",
		"elapsed_s": 0.0,
		"duration_s": normalized.duration_s,
		"progress": 0.0,
		"root_position": first.root_position,
		"yaw_rad": first.yaw_rad,
		"pose_phase": first.pose_phase,
		"pose_phase_progress": first.pose_phase_progress,
		"collision_height_m": first.collision_height_m,
		"plan": normalized,
	}


## Absolute-time proposal. sweep_samples are source-bounded root proposals for
## the host to test in order. This function never mutates state or world data.
static func propose(state: Dictionary, delta_s: float) -> Dictionary:
	if not bool(state.get("valid", false)) or not state.has("plan"):
		return {"valid": false, "reason": "invalid_state", "sweep_samples": []}
	if not is_finite(delta_s) or delta_s < 0.0:
		return {"valid": false, "reason": "invalid_delta", "sweep_samples": []}
	if bool(state.get("done", false)):
		return _terminal_proposal(state)
	var duration := float(state.get("duration_s", 0.0))
	var from_elapsed := float(state.get("elapsed_s", 0.0))
	if not is_finite(duration) or duration <= 0.0 or not is_finite(from_elapsed):
		return {"valid": false, "reason": "invalid_state_clock", "sweep_samples": []}
	var to_elapsed := minf(duration, from_elapsed + delta_s)
	var from_progress := clampf(from_elapsed / duration, 0.0, 1.0)
	var to_progress := clampf(to_elapsed / duration, 0.0, 1.0)
	var plan: Dictionary = state.plan
	var count := _sweep_count(plan, from_progress, to_progress)
	var samples: Array[Dictionary] = []
	for index in range(1, count + 1):
		var progress := lerpf(from_progress, to_progress, float(index) / float(count))
		var sample := _sample(plan, progress)
		sample["elapsed_s"] = progress * duration
		samples.append(sample)
	var target := _sample(plan, to_progress)
	return {
		"provider": PROVIDER,
		"valid": true,
		"terminal": false,
		"reason": "proposal",
		"from_elapsed_s": from_elapsed,
		"elapsed_s": to_elapsed,
		"duration_s": duration,
		"progress": target.progress,
		"root_position": target.root_position,
		"yaw_rad": target.yaw_rad,
		"pose_phase": target.pose_phase,
		"pose_phase_progress": target.pose_phase_progress,
		"collision_height_m": target.collision_height_m,
		"sweep_samples": samples,
	}


## Commit all proposed samples, or only the leading samples accepted by the
## host's physical sweeps. A partial acceptance is terminal and blocked at the
## last safe root. No later proposal can restart a terminal state.
static func commit(state: Dictionary, proposal: Dictionary, accepted_samples: int = -1,
		blocked_reason: String = "dynamic_blocked") -> Dictionary:
	if bool(state.get("done", false)):
		return state.duplicate(true)
	if not _proposal_matches(state, proposal):
		return abort(state, "stale_or_invalid_proposal")
	var samples: Array = proposal.get("sweep_samples", [])
	var accepted := samples.size() if accepted_samples < 0 else clampi(accepted_samples, 0, samples.size())
	var blocked := accepted < samples.size()
	var result := state.duplicate(true)
	if accepted > 0:
		var last: Dictionary = samples[accepted - 1]
		result.elapsed_s = float(last.elapsed_s)
		result.progress = float(last.progress)
		result.root_position = last.root_position
		result.yaw_rad = float(last.yaw_rad)
		result.pose_phase = str(last.pose_phase)
		result.pose_phase_progress = float(last.pose_phase_progress)
		result.collision_height_m = float(last.collision_height_m)
	if blocked:
		result.status = "blocked"
		result.done = true
		result.blocked = true
		result.aborted = false
		result.reason = blocked_reason if not blocked_reason.is_empty() else "dynamic_blocked"
		return result
	result.elapsed_s = float(proposal.elapsed_s)
	result.progress = float(proposal.progress)
	result.root_position = proposal.root_position
	result.yaw_rad = float(proposal.yaw_rad)
	result.pose_phase = str(proposal.pose_phase)
	result.pose_phase_progress = float(proposal.pose_phase_progress)
	result.collision_height_m = float(proposal.collision_height_m)
	if result.progress >= 1.0 - _EPSILON:
		result.status = "complete"
		result.done = true
		result.reason = "complete"
	return result


## Explicit external cancellation (authority loss, support invalidation, death).
## The last accepted root is preserved and remains stable forever.
static func abort(state: Dictionary, reason: String = "aborted") -> Dictionary:
	var result := state.duplicate(true)
	if not bool(result.get("valid", false)):
		return _invalid_state("invalid_state")
	if bool(result.get("done", false)):
		return result
	result.status = "aborted"
	result.done = true
	result.blocked = false
	result.aborted = true
	result.reason = reason if not reason.is_empty() else "aborted"
	return result


## Public pure sample for animation/diagnostics. The state overload avoids
## exposing internal normalization to the integration host.
static func sample_state(state: Dictionary, progress: float) -> Dictionary:
	if not bool(state.get("valid", false)) or not state.has("plan") or not is_finite(progress):
		return {"valid": false, "reason": "invalid_sample"}
	return _sample(state.plan, clampf(progress, 0.0, 1.0))


static func _sample(plan: Dictionary, progress_value: float) -> Dictionary:
	var progress := clampf(progress_value, 0.0, 1.0)
	var start: Vector3 = plan.start
	var destination: Vector3 = plan.destination
	var travel := 0.0
	var y := start.y
	if progress < LIFT_END:
		y = lerpf(start.y, float(plan.clearance_y_m), _smooth(progress / LIFT_END))
	elif progress < CARRY_END:
		travel = _smooth((progress - LIFT_END) / (CARRY_END - LIFT_END))
		y = float(plan.clearance_y_m)
	else:
		travel = 1.0
		y = lerpf(float(plan.clearance_y_m), destination.y, _smooth((progress - CARRY_END) / (1.0 - CARRY_END)))
	var crouch := minf(_smooth(progress / CROUCH_IN_END), 1.0 - _smooth((progress - CARRY_END) / (1.0 - CARRY_END)))
	var phase := _phase(progress)
	return {
		"valid": true,
		"kind": plan.kind,
		"progress": progress,
		"root_position": Vector3(lerpf(start.x, destination.x, travel), y, lerpf(start.z, destination.z, travel)),
		"yaw_rad": float(plan.yaw_rad),
		"direction": plan.direction,
		"pose_phase": phase.name,
		"pose_phase_progress": phase.progress,
		"collision_height_m": lerpf(STANDING_HEIGHT_M, CARRY_HEIGHT_M, crouch),
		"edge_position": plan.edge,
		"obstacle_height_m": plan.obstacle_height_m,
		"support_kind": plan.support_kind,
		"support_id": plan.support_id,
		"support_rid": plan.support_rid,
		"support_transform": plan.support_transform,
		"destination_support_local": plan.destination_support_local,
		"support_instance_id": plan.support_instance_id,
		"support_revision": plan.support_revision,
	}


static func _phase(progress: float) -> Dictionary:
	if progress >= 1.0 - _EPSILON:
		return {"name": "complete", "progress": 1.0}
	if progress < LIFT_END:
		return {"name": "lift", "progress": clampf(progress / LIFT_END, 0.0, 1.0)}
	if progress < CARRY_END:
		return {"name": "carry", "progress": clampf((progress - LIFT_END) / (CARRY_END - LIFT_END), 0.0, 1.0)}
	return {"name": "land", "progress": clampf((progress - CARRY_END) / (1.0 - CARRY_END), 0.0, 1.0)}


static func _sweep_count(plan: Dictionary, from_progress: float, to_progress: float) -> int:
	var start: Vector3 = plan.start
	var destination: Vector3 = plan.destination
	var horizontal := Vector2(destination.x - start.x, destination.z - start.z).length()
	var rate := maxf(absf(float(plan.clearance_y_m) - start.y) / LIFT_END,
		horizontal / (CARRY_END - LIFT_END))
	rate = maxf(rate, absf(float(plan.clearance_y_m) - destination.y) / (1.0 - CARRY_END))
	rate = maxf(rate, (STANDING_HEIGHT_M - CARRY_HEIGHT_M) / CROUCH_IN_END) * 1.5
	return maxi(1, int(ceil(maxf(0.0, to_progress - from_progress) * rate / SWEEP_STEP_M)))


static func _normalize_plan(plan: Dictionary) -> Dictionary:
	if plan.has("admitted") and not bool(plan.admitted):
		return {"valid": false, "reason": "plan_not_admitted"}
	var kind := str(plan.get("kind", ""))
	if kind not in ["vault", "mantle", "shore"]:
		return {"valid": false, "reason": "invalid_kind"}
	var start_value: Variant = plan.get("start", plan.get("from_feet"))
	var edge_value: Variant = plan.get("edge", plan.get("edge_position"))
	var destination_value: Variant = plan.get("destination", plan.get("destination_feet"))
	var start := _as_vector3(start_value)
	var edge := _as_vector3(edge_value)
	var destination := _as_vector3(destination_value)
	if not start.valid or not edge.valid or not destination.valid:
		return {"valid": false, "reason": "invalid_points"}
	var direction_value: Variant = plan.get("direction", destination.value - start.value)
	var direction_result := _as_vector3(direction_value)
	if not direction_result.valid:
		return {"valid": false, "reason": "invalid_direction"}
	var direction: Vector3 = direction_result.value
	direction.y = 0.0
	if direction.length_squared() < .000001:
		return {"valid": false, "reason": "direction_required"}
	direction = direction.normalized()
	var clearance := float(plan.get("clearance_y_m", plan.get("clearanceY", NAN)))
	var duration := float(plan.get("duration_s", plan.get("duration", NAN)))
	if not is_finite(clearance) or clearance < maxf(start.value.y, destination.value.y):
		return {"valid": false, "reason": "invalid_clearance"}
	if not is_finite(duration) or duration < MIN_DURATION_S - _EPSILON or duration > MAX_DURATION_S + _EPSILON:
		return {"valid": false, "reason": "invalid_duration"}
	var support_transform: Variant = plan.get("support_transform", Transform3D.IDENTITY)
	if not support_transform is Transform3D:
		return {"valid": false, "reason": "invalid_support_transform"}
	var support_local_result := _as_vector3(plan.get("destination_support_local", Vector3.ZERO))
	if not support_local_result.valid:
		return {"valid": false, "reason": "invalid_support_anchor"}
	# Godot's actor visual faces -Z. This is the existing preview player heading
	# convention; source-style travel yaw remains derivable from direction.
	var yaw := atan2(-direction.x, -direction.z)
	return {
		"valid": true,
		"kind": kind,
		"start": start.value,
		"edge": edge.value,
		"destination": destination.value,
		"direction": direction,
		"clearance_y_m": clearance,
		"duration_s": duration,
		"yaw_rad": yaw,
		"obstacle_height_m": float(plan.get("obstacle_height_m", plan.get("rise_m", edge.value.y - start.value.y))),
		"support_kind": str(plan.get("support_kind", "static")),
		"support_id": str(plan.get("support_id", "")),
		"support_rid": plan.get("support_rid", RID()),
		"support_transform": support_transform,
		"destination_support_local": support_local_result.value,
		"support_instance_id": int(plan.get("support_instance_id", 0)),
		"support_revision": int(plan.get("support_revision", 0)),
	}


static func _as_vector3(value: Variant) -> Dictionary:
	var result := Vector3.ZERO
	if value is Vector3:
		result = value
	elif value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		result = Vector3(float(value.x), float(value.y), float(value.z))
	else:
		return {"valid": false, "value": Vector3.ZERO}
	return {"valid": result.is_finite(), "value": result}


static func _proposal_matches(state: Dictionary, proposal: Dictionary) -> bool:
	return bool(proposal.get("valid", false)) and not bool(proposal.get("terminal", false)) \
		and is_equal_approx(float(proposal.get("from_elapsed_s", NAN)), float(state.get("elapsed_s", NAN))) \
		and is_equal_approx(float(proposal.get("duration_s", NAN)), float(state.get("duration_s", NAN)))


static func _terminal_proposal(state: Dictionary) -> Dictionary:
	return {
		"provider": PROVIDER,
		"valid": true,
		"terminal": true,
		"reason": state.get("reason", "terminal"),
		"from_elapsed_s": state.get("elapsed_s", 0.0),
		"elapsed_s": state.get("elapsed_s", 0.0),
		"duration_s": state.get("duration_s", 0.0),
		"progress": state.get("progress", 0.0),
		"root_position": state.get("root_position", Vector3.ZERO),
		"yaw_rad": state.get("yaw_rad", 0.0),
		"pose_phase": state.get("pose_phase", "terminal"),
		"pose_phase_progress": state.get("pose_phase_progress", 0.0),
		"collision_height_m": state.get("collision_height_m", STANDING_HEIGHT_M),
		"sweep_samples": [],
	}


static func _invalid_state(reason: String) -> Dictionary:
	return {"provider": PROVIDER, "valid": false, "status": "invalid", "done": true,
		"blocked": false, "aborted": false, "reason": reason, "sweep_samples": []}


static func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
