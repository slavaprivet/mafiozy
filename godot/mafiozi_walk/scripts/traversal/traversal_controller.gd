class_name NativeTraversalController
extends RefCounted
## Explicit integration seam for a CharacterBody host. It owns traversal state,
## but only returns proposals and receipts; the host remains the sole body writer.

const Probe = preload("res://scripts/traversal/traversal_probe.gd")
const Motion = preload("res://scripts/traversal/traversal_motion.gd")
const Pose = preload("res://scripts/traversal/traversal_pose.gd")
const PROVIDER := "GODOT_TRAVERSAL_CONTROLLER_V1"
const CONTACT_PREP_S := .12
const LANDING_SETTLE_S := .28

var _probe: RefCounted = Probe.new()
var _state: Dictionary = {}
var _receipt: Dictionary = {}
var _contact_elapsed_s := 0.0
var _landing_elapsed_s := 0.0
var _landing_active := false
var _lead_side := "l"


func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1, actor_rid: RID = RID()) -> void:
	_probe.configure(space, collision_mask, actor_rid)


func try_begin(from_feet: Vector3, direction: Vector3, options: Dictionary = {}) -> Dictionary:
	if active():
		return {"provider": PROVIDER, "started": false, "reason": "already_active", "receipt": _receipt.duplicate(true)}
	var candidate: Dictionary = _probe.probe(from_feet, direction, options)
	if not bool(candidate.get("admitted", false)):
		_receipt = candidate
		_state = {}
		_contact_elapsed_s = 0.0
		_landing_elapsed_s = 0.0
		_landing_active = false
		return {"provider": PROVIDER, "started": false, "reason": candidate.get("reason", "rejected"), "receipt": candidate}
	var next_state: Dictionary = Motion.begin(candidate)
	if not bool(next_state.get("valid", false)):
		_receipt = candidate
		_state = {}
		return {"provider": PROVIDER, "started": false, "reason": next_state.get("reason", "motion_rejected"), "receipt": candidate}
	_receipt = candidate
	_state = next_state
	_contact_elapsed_s = 0.0
	_landing_elapsed_s = 0.0
	_landing_active = false
	_lead_side = str(options.get("lead_side", "l"))
	if _lead_side not in ["l", "r"]:
		_lead_side = "l"
	return {"provider": PROVIDER, "started": true, "reason": "started", "receipt": candidate, "state": state()}


func propose_step(delta_s: float, options: Dictionary = {}, rig: Dictionary = {}) -> Dictionary:
	if not active():
		return {"provider": PROVIDER, "valid": false, "reason": "not_active", "accepted_samples": 0}
	if not is_finite(delta_s) or delta_s < 0.0:
		return {"provider": PROVIDER, "valid": false, "reason": "invalid_delta", "accepted_samples": 0}
	var support: Dictionary = _probe.validate_support(_receipt, options)
	if not bool(support.get("valid", false)):
		var support_reason := str(support.get("reason", "support_invalid"))
		if not _landing_active:
			_state = Motion.abort(_state, support_reason)
		_landing_active = false
		return {"provider": PROVIDER, "valid": true, "terminal": true, "reason": support_reason,
			"accepted_samples": 0, "state": state()}
	if _contact_elapsed_s < CONTACT_PREP_S:
		var contact_to := minf(CONTACT_PREP_S, _contact_elapsed_s + delta_s)
		var contact_progress := contact_to / CONTACT_PREP_S
		var contact_sample: Dictionary = Motion.sample_state(_state, 0.0)
		var contact_pose := _pose_from_sample(contact_sample, "reach", contact_progress, false, rig)
		return {"provider":PROVIDER, "valid":true, "terminal":false, "reason":"contact_prep",
			"pre_contact":true, "contact_elapsed_s":contact_to, "accepted_samples":0,
			"all_samples_clear":true, "proposal":{"valid":true,"sweep_samples":[]},
			"pose":contact_pose, "support":support}
	if _landing_active:
		var landing_to := minf(LANDING_SETTLE_S, _landing_elapsed_s + delta_s)
		var landing_progress := landing_to / LANDING_SETTLE_S
		var landing_sample: Dictionary = Motion.sample_state(_state, 1.0)
		var landing_pose := _pose_from_sample(landing_sample, "settle", landing_progress, true, rig)
		return {"provider":PROVIDER, "valid":true, "terminal":false, "reason":"landing_settle",
			"landing_settle":true, "landing_elapsed_s":landing_to, "accepted_samples":0,
			"all_samples_clear":true, "proposal":{"valid":true,"sweep_samples":[]},
			"pose":landing_pose, "support":support}
	var motion: Dictionary = Motion.propose(_state, delta_s)
	if not bool(motion.get("valid", false)):
		return {"provider": PROVIDER, "valid": false, "reason": motion.get("reason", "motion_invalid"), "accepted_samples": 0}
	var inspection: Dictionary = _probe.inspect_sweep_samples(motion.get("sweep_samples", []), options)
	var pose: Dictionary = _pose_for_motion_prefix(motion, int(inspection.accepted_samples), rig)
	return {"provider": PROVIDER, "valid": true, "terminal": false,
		"reason": inspection.reason, "proposal": motion, "accepted_samples": inspection.accepted_samples,
		"all_samples_clear": inspection.clear, "pose": pose, "support": support}


func commit_step(step: Dictionary, accepted_samples: int = -1, blocked_reason: String = "") -> Dictionary:
	if not active() or not bool(step.get("valid", false)):
		return state()
	if bool(step.get("pre_contact", false)):
		_contact_elapsed_s = clampf(float(step.get("contact_elapsed_s", _contact_elapsed_s)), _contact_elapsed_s, CONTACT_PREP_S)
		return state()
	if bool(step.get("landing_settle", false)):
		_landing_elapsed_s = clampf(float(step.get("landing_elapsed_s", _landing_elapsed_s)), _landing_elapsed_s, LANDING_SETTLE_S)
		if _landing_elapsed_s >= LANDING_SETTLE_S - .000001:
			_landing_active = false
		return state()
	if not step.has("proposal"):
		return state()
	var inspected := int(step.get("accepted_samples", 0))
	var wanted := inspected if accepted_samples < 0 else mini(inspected, accepted_samples)
	var reason := blocked_reason if not blocked_reason.is_empty() else str(step.get("reason", "dynamic_blocked"))
	_state = Motion.commit(_state, step.proposal, wanted, reason)
	if bool(_state.get("done", false)) and str(_state.get("status", "")) == "complete":
		_landing_elapsed_s = 0.0
		_landing_active = true
	return state()


func abort(reason: String = "aborted") -> Dictionary:
	if not _state.is_empty():
		_state = Motion.abort(_state, reason)
	_landing_active = false
	return state()


func active() -> bool:
	return bool(_state.get("valid", false)) and (not bool(_state.get("done", true)) or _landing_active)


func state() -> Dictionary:
	var result := _state.duplicate(true)
	result["contact_elapsed_s"] = _contact_elapsed_s
	result["contact_progress"] = clampf(_contact_elapsed_s / CONTACT_PREP_S, 0.0, 1.0)
	result["motion_started"] = _contact_elapsed_s >= CONTACT_PREP_S - .000001
	result["landing_elapsed_s"] = _landing_elapsed_s
	result["landing_active"] = _landing_active
	result["controller_done"] = bool(_state.get("done", true)) and not _landing_active
	if _landing_active:
		result["status"] = "landing"
		result["done"] = false
	return result


func receipt() -> Dictionary:
	return _receipt.duplicate(true)


## Read after commit_step(actual_count). The host's real body may accept fewer
## samples than the earlier space probe, so step.pose is only a prediction.
## This snapshot also handles zero accepted samples and terminal aborts.
func committed_pose(rig: Dictionary = {}) -> Dictionary:
	if not bool(_state.get("valid", false)) or _receipt.is_empty():
		return {"valid": false, "reason": "no_committed_state"}
	var sample := Motion.sample_state(_state, float(_state.get("progress", 0.0)))
	if _contact_elapsed_s < CONTACT_PREP_S:
		return _pose_from_sample(sample, "reach", _contact_elapsed_s / CONTACT_PREP_S, false, rig)
	if _landing_active or (bool(_state.get("done", false)) and str(_state.get("status", "")) == "complete"):
		return _pose_from_sample(sample, "settle", _landing_elapsed_s / LANDING_SETTLE_S, true, rig)
	return _pose_from_sample(sample, "traverse", 0.0, true, rig)


func _pose_for_motion_prefix(motion: Dictionary, accepted_samples: int, rig: Dictionary) -> Dictionary:
	var samples: Array = motion.get("sweep_samples", [])
	var accepted := clampi(accepted_samples, 0, samples.size())
	var pose_sample: Dictionary
	if accepted > 0 and samples[accepted - 1] is Dictionary:
		pose_sample = (samples[accepted - 1] as Dictionary).duplicate(true)
	else:
		pose_sample = Motion.sample_state(_state, float(_state.get("progress", 0.0)))
	return _pose_from_sample(pose_sample, "traverse", 0.0, true, rig)


func _pose_from_sample(pose_sample: Dictionary, stage: String, stage_progress: float,
		contact_ready: bool, rig: Dictionary) -> Dictionary:
	var enriched := pose_sample.duplicate(true)
	enriched["kind"] = _receipt.kind
	enriched["direction"] = _state.plan.direction
	enriched["edge_position"] = _receipt.edge_position
	enriched["destination_position"] = _state.plan.destination
	enriched["obstacle_height_m"] = _receipt.edge_position.y - _receipt.from_feet.y
	enriched["pose_stage"] = stage
	enriched["pose_stage_progress"] = stage_progress
	enriched["contact_ready"] = contact_ready
	enriched["lead_side"] = _lead_side
	return Pose.propose(enriched, rig)
