extends RefCounted
## One articulated owner during a fall. The host remains the only pose writer.
const Body = preload("res://scripts/character_physics/exit_ragdoll_body.gd")
const Pose = preload("res://scripts/character_physics/character_physics_pose.gd")
const Clearance = preload("res://scripts/character_physics/recovery_clearance.gd")
const MIN_FALL_TIME := 1.2
const STABLE_TIME := .35
const RECOVERY_STABLE_TIME := .2
const GET_UP_TIME := .9
var body: RefCounted
var mode := "UNBOUND"
var last_snapshot: Dictionary = {}
var recovery_block_reason := ""
var fault_reason := ""
var _dead := false
var _player: CharacterBody3D
var _pose: RefCounted
var _identity: Dictionary
var _pose_epoch := -1
var _pose_owner: StringName = &""
var _saved_layer := 0
var _saved_mask := 0
var _elapsed := 0.0
var _stable := 0.0
var _recovery_stable := 0.0
var _getup_elapsed := 0.0
var _proxy_height := .65
var _getup_pose: Dictionary = {}
var _getup_from := Vector3.ZERO
var _getup_to := Vector3.ZERO
var _floor_ray: PhysicsRayQueryParameters3D
var _stand_query: PhysicsShapeQueryParameters3D
var _recovery_query: PhysicsShapeQueryParameters3D
var _recovery_shape: BoxShape3D
var _clearance: RefCounted
var _accepted_skin: Dictionary = {}

func configure(player: CharacterBody3D, parent: Node3D) -> Dictionary:
	if mode != "UNBOUND" or not is_instance_valid(player): return {"ok":false,"error":"binding"}
	_player = player
	_identity = {"actor_id":player.get_meta("actor_id", ""), "life_generation":player.get_meta("life_generation", 0)}
	body = Body.new()
	var configured: Dictionary = body.configure(player._pose_skeleton, parent, {"total_mass_kg":75.0,"collision_layer":256,"collision_mask":257,"exceptions":[player]})
	if not configured.get("ok", false): return configured
	_pose = Pose.new()
	if not _pose.configure(player._pose_skeleton, player._pose_motion, player._locomotion._rest_poses, player._model_scale, player._pose_motion):
		body.dispose()
		return {"ok":false,"error":"pose_binding"}
	_clearance = Clearance.new()
	if not _clearance.configure(_pose):
		body.dispose()
		_pose.dispose()
		return {"ok":false,"error":"clearance_binding"}
	_floor_ray = PhysicsRayQueryParameters3D.new()
	_floor_ray.collision_mask = player.collision_mask
	_floor_ray.exclude = [player.get_rid()]
	_stand_query = PhysicsShapeQueryParameters3D.new()
	_stand_query.shape = (player.get_node("PlayerCapsule") as CollisionShape3D).shape
	_stand_query.margin = .001
	_stand_query.collision_mask = player.collision_mask
	_stand_query.exclude = [player.get_rid()]
	_recovery_shape = BoxShape3D.new()
	_recovery_query = PhysicsShapeQueryParameters3D.new()
	_recovery_query.shape = _recovery_shape
	_recovery_query.margin = .001
	_recovery_query.collision_mask = player.collision_mask
	_recovery_query.exclude = [player.get_rid()]
	mode = "IDLE"
	return {"ok":true}

func _valid_life() -> bool:
	return is_instance_valid(_player) and _player.is_inside_tree() and _player.get_meta("actor_id", "") == _identity.actor_id and _player.get_meta("life_generation", -1) == _identity.life_generation

func _valid_snapshot(value: Dictionary) -> bool:
	return value.get("valid", false) and value.get("active", false) and value.get("anchor_world") is Vector3 and value.anchor_world.is_finite() and value.get("bone_world_frames") is Dictionary

func start_fall(inherited_velocity: Vector3, outward_delta_velocity: Vector3, inherited_angular_velocity: Vector3 = Vector3.ZERO, velocity_reference: Vector3 = Vector3.ZERO) -> Dictionary:
	if mode not in ["IDLE", "DONE"] or not _valid_life(): return {"ok":false,"error":"lifetime_or_mode"}
	if not inherited_velocity.is_finite() or not outward_delta_velocity.is_finite() or not inherited_angular_velocity.is_finite() or not velocity_reference.is_finite(): return {"ok":false,"error":"nonfinite_velocity"}
	var frames: Dictionary = body.capture_world_frames()
	body.reset()
	var started: Dictionary = body.start(frames, inherited_velocity, outward_delta_velocity * 75.0, inherited_angular_velocity, velocity_reference)
	if not started.get("ok", false): return started
	_saved_layer = _player.collision_layer
	_saved_mask = _player.collision_mask
	_pose_epoch = _player._pose_epoch
	_pose_owner = _player._pose_authority
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.velocity = Vector3.ZERO
	_elapsed = 0.0
	_stable = 0.0
	_recovery_stable = 0.0
	_dead = false
	recovery_block_reason = ""
	fault_reason = ""
	_getup_pose.clear()
	mode = "FALLING"
	last_snapshot = body.snapshot()
	if not _valid_snapshot(last_snapshot):
		cancel()
		return {"ok":false,"error":"initial_snapshot"}
	_proxy_height = maxf(.2, float(last_snapshot.anchor_world.y) - _player.global_position.y)
	_player._pose_motion.position = Vector3.ZERO
	_player._pose_motion.quaternion = Quaternion.IDENTITY
	mode = "FALLING"
	return {"ok":true}

func advance(delta: float, allow_getup: bool = true) -> Dictionary:
	if not _valid_life() or not is_finite(delta) or delta < 0.0 or delta > .1: return {"valid":false,"reason":"lifetime_or_delta"}
	if _player._pose_epoch != _pose_epoch or _player._pose_authority != _pose_owner: return {"valid":false,"reason":"pose_owner_changed"}
	if mode == "FAULTED": return {"valid":false,"reason":fault_reason,"faulted":true}
	if mode in ["IDLE", "DONE"]: return {"valid":true,"mode":mode,"done":mode == "DONE"}
	_elapsed += delta
	allow_getup = allow_getup and not _dead
	if mode == "FALLING":
		last_snapshot = body.snapshot()
		if not _valid_snapshot(last_snapshot): return _fault("physical_snapshot")
		# A noncolliding proxy follows the physical COM for camera/void detection.
		# It never pulls the articulated bodies back toward a scripted trajectory.
		_player.global_position = last_snapshot.anchor_world - Vector3.UP * _proxy_height
		_player._pose_motion.position = Vector3.ZERO
		_player._pose_motion.quaternion = Quaternion.IDENTITY
		var selected: Dictionary = _pose.from_world_frames(last_snapshot.bone_world_frames, _player._pose_epoch)
		if not selected.get("valid", false): return selected
		_stable = _stable + delta if bool(last_snapshot.settled) else 0.0
		_recovery_stable = _recovery_stable + delta if _ready_to_recover(last_snapshot) else 0.0
		if allow_getup and _elapsed >= MIN_FALL_TIME and (_stable >= STABLE_TIME or _recovery_stable >= RECOVERY_STABLE_TIME):
			var support := _standing_support()
			recovery_block_reason = "standing_support" if support.is_empty() else ""
			if not support.is_empty():
				recovery_block_reason = ""
				# Rebase the invisible proxy; retarget world bone frames so no visible
				# part moves. Recovery now has no unswept proxy translation.
				_getup_to = support.position
				_player.global_position = _getup_to
				_getup_pose = _pose.from_world_frames(last_snapshot.bone_world_frames, _player._pose_epoch)
				selected = _getup_pose
				_accepted_skin = _clearance.snapshot(selected, _player._pose_motion.get_parent().global_transform, false)
				_getup_elapsed = 0.0
				body.stop_preserve()
				mode = "GETTING_UP"
		return {"valid":true,"mode":mode,"done":false,"pose":selected,"snapshot":last_snapshot}
	if mode == "GETTING_UP":
		# Recheck moving obstacles; never stand inside a returning car.
		if not _standing_clear(_getup_to):
			# A moving obstacle restores physical ownership instead of freezing a
			# disabled body forever or rewinding to the first recovery pose.
			return _resume_fall("standing_capsule_blocked")
		var proposed_time := minf(GET_UP_TIME, _getup_elapsed + delta)
		var progress := smoothstep(0.0, GET_UP_TIME, proposed_time)
		_player.global_position = _getup_to
		# Sampling is pure. Keep the last displayed motion transform until the
		# host accepts this pose, so a blocked step resumes from that exact skin.
		var selected: Dictionary = _pose.standing_blend(_getup_pose, progress, Callable(self, "_floor_height"), _player._pose_epoch)
		if not selected.get("valid", false): return selected
		var next_skin: Dictionary = _clearance.snapshot(selected, _player._pose_motion.get_parent().global_transform)
		var sweep: Dictionary = _clearance.between(_accepted_skin, next_skin)
		if not _recovery_path_clear(sweep): return _resume_fall("recovery_skin_blocked")
		_accepted_skin = next_skin
		_getup_elapsed = proposed_time
		if _getup_elapsed >= GET_UP_TIME:
			_player.collision_layer = _saved_layer
			_player.collision_mask = _saved_mask
			_player.velocity = Vector3.ZERO
			mode = "DONE"
		return {"valid":true,"mode":mode,"done":mode == "DONE","pose":selected,"snapshot":last_snapshot}
	return {"valid":false,"reason":"mode"}

func _standing_support() -> Dictionary:
	var center: Vector3 = last_snapshot.anchor_world
	_floor_ray.from = center + Vector3.UP * .5
	_floor_ray.to = center - Vector3.UP * 2.5
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(_floor_ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < .7: return {}
	var feet: Vector3 = hit.position + Vector3.UP * .003
	return {"position":feet} if _standing_clear(feet) else {}

func _ready_to_recover(snapshot: Dictionary) -> bool:
	# Authored active-recovery gate, separate from the stricter sleep/settled
	# definition. A supported, slow torso may start getting up while fingers or
	# arms still move. Standing capsule and full skin checks remain mandatory.
	return snapshot.get("energy_valid", false) and int(snapshot.get("core_support_contact_count", 0)) > 0 and int(snapshot.get("support_contact_count", 0)) > 0 \
		and float(snapshot.get("core_max_linear_speed", INF)) <= .35 and float(snapshot.get("core_max_angular_speed", INF)) <= .8 \
		and float(snapshot.get("max_linear_speed", INF)) <= 1.5 and float(snapshot.get("max_angular_speed", INF)) <= 4.0 \
		and float(snapshot.get("specific_kinetic_energy_j_kg", INF)) <= .15 and float(snapshot.get("max_joint_anchor_error_m", INF)) <= .025

func _standing_clear(feet: Vector3) -> bool:
	_stand_query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * _player.model_target_height * .5)
	return _player.get_world_3d().direct_space_state.intersect_shape(_stand_query, 1).is_empty()

func _recovery_path_clear(sweep: Dictionary) -> bool:
	if not sweep.get("valid", false): return false
	var bounds: AABB = sweep.bounds
	_recovery_shape.size = bounds.size.max(Vector3.ONE * .001)
	_recovery_query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
	var contacts: Array[Vector3] = _player.get_world_3d().direct_space_state.collide_shape(_recovery_query, 32)
	if contacts.size() >= 64 or contacts.size() % 2 != 0: return false
	var support_y := _getup_to.y - .003
	var below_support_side := false
	for i in range(0, contacts.size(), 2):
		var separation := contacts[i + 1] - contacts[i]
		# Only the admitted horizontal support plane may touch the padded box.
		# Do not exclude its RID: a compound floor can also contain a wall.
		if separation.length() < .000001: return false
		if separation.length() > float(sweep.angular_padding_m) + .012: return false
		if separation.normalized().dot(Vector3.UP) >= .95 and absf(contacts[i + 1].y - support_y) <= .01:
			continue
		# A padded sweep can hit the SIDE of an adjacent coplanar floor tile.
		# Only sub-support pairs qualify; do not whitelist the floor's RID.
		if maxf(contacts[i].y, contacts[i + 1].y) > support_y + .0001: return false
		below_support_side = true
	if below_support_side:
		# Independently reject any obstacle in the above-support portion. This
		# catches a compound floor+wall even when its first manifold is below.
		var upper := bounds.end
		var lower := bounds.position
		lower.y = maxf(lower.y, support_y + .002)
		if upper.y <= lower.y: return false
		_recovery_shape.size = (upper - lower).max(Vector3.ONE * .001)
		_recovery_query.transform = Transform3D(Basis.IDENTITY, (upper + lower) * .5)
		if not _player.get_world_3d().direct_space_state.intersect_shape(_recovery_query, 1).is_empty(): return false
	return true

func _resume_fall(reason: String) -> Dictionary:
	var current_frames: Dictionary = body.capture_world_frames()
	body.reset()
	var resumed: Dictionary = body.start(current_frames, Vector3.ZERO)
	if not resumed.get("ok", false): return _fault("resume_physics:" + str(resumed.get("error", "unknown")))
	mode = "FALLING"
	_stable = 0.0
	_recovery_stable = 0.0
	recovery_block_reason = reason
	return advance(0.0, false)

func _fault(reason: String) -> Dictionary:
	# A broken pool cannot prove a safe standing position. Retain the last
	# displayed pose and ownership, stop simulation, and require a host restart.
	# Never report FALLING/DONE or grant walking without a physical body.
	mode = "FAULTED"
	fault_reason = reason
	if body != null: body.reset()
	return {"valid":false,"reason":reason,"faulted":true}

func _floor_height(x: float, z: float) -> float:
	_floor_ray.from = Vector3(x, _player.global_position.y + 2.0, z)
	_floor_ray.to = Vector3(x, _player.global_position.y - 2.0, z)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(_floor_ray)
	return float(hit.position.y) if not hit.is_empty() else NAN

func cancel() -> void:
	if body != null and body.has_method("reset"): body.reset()
	if _valid_life() and mode in ["FALLING", "GETTING_UP", "FAULTED"] and _player._pose_epoch == _pose_epoch and _player._pose_authority == _pose_owner:
		_player.collision_layer = _saved_layer
		_player.collision_mask = _saved_mask
	mode = "IDLE"
	_getup_pose.clear()

func continue_after_death() -> void:
	if not _valid_life() or mode not in ["FALLING", "GETTING_UP"]: return
	if mode == "GETTING_UP":
		var frames: Dictionary = body.capture_world_frames()
		body.reset()
		var resumed: Dictionary = body.start(frames, Vector3.ZERO)
		if not resumed.get("ok", false):
			_fault("dead_resume_physics:" + str(resumed.get("error", "unknown")))
			return
		mode = "FALLING"
	_dead = true
	_pose_epoch = _player._pose_epoch
	_pose_owner = _player._pose_authority

func dispose() -> void:
	cancel()
	if body != null: body.dispose()
	if _pose != null: _pose.dispose()
	mode = "DISPOSED"
