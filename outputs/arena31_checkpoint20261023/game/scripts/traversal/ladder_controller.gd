class_name NativeLadderController
extends RefCounted
## Input-agnostic ladder seam. The host owns E/Ctrl arbitration, body and rig writes.

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
const Probe = preload("res://scripts/traversal/ladder_probe.gd")
const Motion = preload("res://scripts/traversal/ladder_motion.gd")
const Pose = preload("res://scripts/traversal/ladder_pose.gd")
const PROVIDER := "GODOT_LADDER_CONTROLLER_V1"

var _probe: RefCounted = Probe.new()
var _descriptors: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _state: Dictionary = {}
var _receipt: Dictionary = {}
var _actor_rid := RID()
var _actor_body: PhysicsBody3D
var _owned_route_exceptions: Array[RID] = []


func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1, actor_rid: RID = RID()) -> void:
	_release_route_exceptions()
	_actor_body = null
	_actor_rid = actor_rid
	_probe.configure(space, collision_mask, actor_rid)


func configure_actor(space: PhysicsDirectSpaceState3D, collision_mask: int, actor: PhysicsBody3D) -> void:
	_release_route_exceptions()
	_actor_body = actor
	_actor_rid = actor.get_rid() if is_instance_valid(actor) else RID()
	_probe.configure(space, collision_mask, _actor_rid)


func register_ladders(values: Array) -> Dictionary:
	_descriptors.clear()
	_by_id.clear()
	var rejected: Array[Dictionary] = []
	for value: Variant in values:
		if not value is Dictionary:
			rejected.append({"reason":"not_dictionary"})
			continue
		var descriptor: Dictionary = Descriptor.normalize(value)
		if not descriptor.valid or _by_id.has(descriptor.get("id", "")):
			rejected.append({"id":descriptor.get("id", value.get("id", "")), "reason":"duplicate_id" if descriptor.valid else descriptor.reason})
			continue
		_descriptors.append(descriptor)
		_by_id[descriptor.id] = descriptor
	return {"provider":PROVIDER, "registered":_descriptors.size(), "rejected":rejected}


func nearest_prompt(feet: Vector3) -> Variant:
	return null if active() else _probe.nearest_prompt(feet, _descriptors)


func try_begin(feet: Vector3, candidate: Dictionary, input_action: StringName = &"interact", options: Dictionary = {}) -> Dictionary:
	if input_action != &"interact":
		return {"provider":PROVIDER, "started":false, "claimed":false, "reason":"input_pass_through"}
	if active():
		return {"provider":PROVIDER, "started":false, "claimed":true, "reason":"already_active"}
	var id := str(candidate.get("ladder_id", ""))
	if not _by_id.has(id):
		return {"provider":PROVIDER, "started":false, "claimed":false, "reason":"stale_candidate"}
	var current := candidate.duplicate(true)
	current.descriptor = _by_id[id]
	var validation: Dictionary = _probe.validate_candidate(feet, current)
	if not validation.valid:
		return {"provider":PROVIDER, "started":false, "claimed":false, "reason":validation.reason}
	var proposed: Dictionary = Motion.begin(feet, current.descriptor, str(current.end))
	if not proposed.valid:
		return {"provider":PROVIDER, "started":false, "claimed":true, "reason":proposed.reason}
	var route: Dictionary = _probe.inspect_route(Motion.route_points(proposed), current.descriptor, Motion.landing_end(proposed), options)
	if not route.clear:
		return {"provider":PROVIDER, "started":false, "claimed":true, "reason":route.reason}
	var exception_report := _acquire_route_exceptions(current.descriptor)
	if not bool(exception_report.ready):
		return {"provider":PROVIDER, "started":false, "claimed":true, "reason":"collision_exception_body_required"}
	_state = proposed
	_receipt = {"provider":PROVIDER, "ladder_id":id, "end":current.end, "descriptor":current.descriptor,
		"input_action":&"interact", "route_clear":true, "landing_end":Motion.landing_end(proposed),
		"route_exclude_rids":exception_report.requested, "managed_collision_exceptions":exception_report.owned}
	return {"provider":PROVIDER, "started":true, "claimed":true, "reason":"started",
		"receipt":_receipt.duplicate(true), "state":_state.duplicate(true)}


func request_slide(options: Dictionary = {}) -> Dictionary:
	if not active():
		return {"provider":PROVIDER, "claimed":false, "accepted":false, "reason":"input_pass_through"}
	var next: Dictionary = Motion.slide_down(_state)
	var route: Dictionary = _probe.inspect_route(Motion.route_points(next), next.descriptor, Motion.landing_end(next), options)
	if not route.clear:
		return {"provider":PROVIDER, "claimed":true, "accepted":false, "reason":route.reason}
	_state = next
	return {"provider":PROVIDER, "claimed":true, "accepted":true, "reason":"slide_active", "state":_state.duplicate(true)}


func request_cancel() -> Dictionary:
	if not active():
		return {"provider":PROVIDER, "claimed":false, "accepted":false, "reason":"input_pass_through"}
	_state = Motion.cancel(_state)
	return {"provider":PROVIDER, "claimed":true, "accepted":true, "reason":"safe_cancel", "state":_state.duplicate(true)}


func propose_step(delta_s: float, options: Dictionary = {}, rig: Dictionary = {}) -> Dictionary:
	if not active():
		return {"provider":PROVIDER, "valid":false, "reason":"not_active", "accepted_samples":0}
	var motion: Dictionary = Motion.propose(_state, delta_s)
	if not motion.valid:
		return {"provider":PROVIDER, "valid":false, "reason":motion.reason, "accepted_samples":0}
	var inspection: Dictionary = _probe.inspect_sweep_samples(motion.sweep_samples, _state.descriptor, options)
	var pose_state: Dictionary = _state
	if int(inspection.accepted_samples) > 0:
		pose_state = motion.sweep_samples[int(inspection.accepted_samples)-1].state
	var pose_sample := {"root_position":pose_state.root_position, "travelled_m":pose_state.travelled_m,
		"direction":pose_state.direction, "sliding":pose_state.sliding,
		"mount_progress":pose_state.mount_progress, "dismount_progress":pose_state.dismount_progress}
	var pose: Dictionary = Pose.propose(_state.descriptor, pose_sample, rig)
	return {"provider":PROVIDER, "valid":true, "reason":inspection.reason, "proposal":motion,
		"accepted_samples":inspection.accepted_samples, "all_samples_clear":inspection.clear,
		"pose":pose, "claimed_actions":[&"interact", &"ladder_slide"]}


func commit_step(step: Dictionary, accepted_samples: int = -1, blocked_reason: String = "", options: Dictionary = {}) -> Dictionary:
	if not active() or not bool(step.get("valid", false)) or not step.has("proposal"):
		return state()
	var inspected := int(step.get("accepted_samples", 0))
	var wanted := inspected if accepted_samples < 0 else mini(inspected, accepted_samples)
	var reason := blocked_reason if not blocked_reason.is_empty() else str(step.get("reason", "dynamic_blocked"))
	var samples: Array = step.proposal.get("sweep_samples", [])
	for index in wanted:
		var sample: Dictionary = samples[index]
		var candidate_state: Dictionary = sample.get("state", {})
		if Motion.requires_terminal_support(candidate_state) and not _probe.landing_supported(sample.root_position, options):
			wanted = index
			reason = "terminal_unsupported"
			break
	_state = Motion.commit(_state, step.proposal, wanted, reason)
	if bool(_state.get("done", false)):
		_release_route_exceptions()
	return state()


func abort(reason: String = "aborted") -> Dictionary:
	if not _state.is_empty():
		_state = Motion.abort(_state, reason)
	_release_route_exceptions()
	return state()


func dispose() -> void:
	_release_route_exceptions()
	_state.clear()
	_receipt.clear()


func collision_exception_state() -> Dictionary:
	return {"actor_rid":_actor_rid, "owned":_owned_route_exceptions.duplicate()}


func active() -> bool:
	return bool(_state.get("valid", false)) and not bool(_state.get("done", true))


func state() -> Dictionary:
	return _state.duplicate(true)


func receipt() -> Dictionary:
	return _receipt.duplicate(true)


## Read after committing actual body acceptance. Terminal support checks inside
## commit_step can truncate the prefix further than the host's accepted count.
func committed_pose(rig: Dictionary = {}) -> Dictionary:
	if not bool(_state.get("valid", false)):
		return {"valid": false, "reason": "no_committed_state"}
	var sample := {"root_position":_state.root_position, "travelled_m":_state.travelled_m,
		"direction":_state.direction, "sliding":_state.sliding,
		"mount_progress":_state.mount_progress, "dismount_progress":_state.dismount_progress}
	return Pose.propose(_state.descriptor, sample, rig)


func descriptors() -> Array[Dictionary]:
	return _descriptors.duplicate(true)


func _acquire_route_exceptions(descriptor: Dictionary) -> Dictionary:
	_release_route_exceptions()
	var requested: Array[RID] = []
	for value: Variant in descriptor.get("route_exclude_rids", []):
		if value is RID and (value as RID).is_valid() and value != _actor_rid and not requested.has(value):
			requested.append(value)
	if not _actor_rid.is_valid() or not is_instance_valid(_actor_body):
		return {"requested":requested, "owned":[], "ready":requested.is_empty()}
	var existing: Array[RID] = []
	for body: PhysicsBody3D in _actor_body.get_collision_exceptions():
		if is_instance_valid(body):
			existing.append(body.get_rid())
	for rid: RID in requested:
		if existing.has(rid):
			continue
		PhysicsServer3D.body_add_collision_exception(_actor_rid, rid)
		_owned_route_exceptions.append(rid)
	return {"requested":requested, "owned":_owned_route_exceptions.duplicate(), "ready":true}


func _release_route_exceptions() -> void:
	if _actor_rid.is_valid() and is_instance_valid(_actor_body):
		for rid: RID in _owned_route_exceptions:
			if rid.is_valid():
				PhysicsServer3D.body_remove_collision_exception(_actor_rid, rid)
	_owned_route_exceptions.clear()
