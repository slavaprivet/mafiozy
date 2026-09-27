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
var _impact_binding: Dictionary = {}
var _impact_busy := false
var _impact_dead := false

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
	allow_getup = allow_getup and not _dead and not _impact_dead
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
		if not _recovery_support_valid(): return _resume_fall("recovery_support_changed")
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
		if not selected.get("valid", false):
			if selected.get("reason", "") == "floor-unavailable-or-outside-source-grid":
				return _resume_fall("recovery_floor_changed")
			return selected
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
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < .7 or not _support_velocity_low(hit): return {}
	var feet: Vector3 = hit.position + Vector3.UP * .003
	return {"position":feet} if _standing_clear(feet) else {}

func _ready_to_recover(snapshot: Dictionary) -> bool:
	# Authored active-recovery gate, separate from the stricter sleep/settled
	# definition. A supported, slow torso may start getting up while fingers or
	# arms still move. Standing capsule and full skin checks remain mandatory.
	# Spine/limbs can support a quiet body without pelvis/chest touching floor.
	# This indirect support needs two external upward contacts and lower energy.
	var indirect_support := int(snapshot.get("support_contact_count", 0)) >= 2 and float(snapshot.get("specific_kinetic_energy_j_kg", INF)) <= .02
	return snapshot.get("energy_valid", false) and (int(snapshot.get("core_support_contact_count", 0)) > 0 or indirect_support) and int(snapshot.get("support_contact_count", 0)) > 0 \
		and float(snapshot.get("core_max_linear_speed", INF)) <= .35 and float(snapshot.get("core_max_angular_speed", INF)) <= .8 \
		and float(snapshot.get("max_linear_speed", INF)) <= 1.5 and float(snapshot.get("max_angular_speed", INF)) <= 4.0 \
		and float(snapshot.get("specific_kinetic_energy_j_kg", INF)) <= .15 and float(snapshot.get("max_joint_anchor_error_m", INF)) <= .025

func _support_velocity_low(hit: Dictionary) -> bool:
	var state := PhysicsServer3D.body_get_direct_state(hit.rid)
	if state == null: return false
	var world_com: Vector3 = state.transform * state.center_of_mass_local
	var velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross((hit.position as Vector3) - world_com)
	return velocity.is_finite() and velocity.length() <= .15

func _recovery_support_valid() -> bool:
	# Recovery is anchored in world space. Do not freeze in air or slide along a
	# departing car/platform: resume from the displayed pose if support changes.
	_floor_ray.from = _getup_to + Vector3.UP * .08
	_floor_ray.to = _getup_to - Vector3.UP * .08
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(_floor_ray)
	return not hit.is_empty() and hit.normal.dot(Vector3.UP) >= .7 \
		and absf(float(hit.position.y) - (_getup_to.y - .003)) <= .025 and _support_velocity_low(hit)

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

## Trusted synchronous sink endpoints. Source admission/replay remain host-owned.
func bind_impact_session(binding: Dictionary) -> Dictionary:
	if not _impact_binding.is_empty() or not _valid_life() or mode not in ["IDLE", "DONE"]: return {"ok":false,"error":"binding"}
	if binding.size() != 4: return {"ok":false,"error":"binding_schema"}
	for key in ["actor_id", "session_id"]:
		if not binding.get(key) is String or binding[key].is_empty() or binding[key].length() > 256: return {"ok":false,"error":"binding_schema"}
	for key in ["life_generation", "session_generation"]:
		if not binding.get(key) is int or binding[key] <= 0: return {"ok":false,"error":"binding_schema"}
	if binding.actor_id != _identity.actor_id or binding.life_generation != _identity.life_generation: return {"ok":false,"error":"binding_identity"}
	_impact_binding = binding.duplicate()
	return {"ok":true,"error":""}

func impact_owner_state() -> Dictionary:
	var rids: Array[RID] = []
	if _valid_life():
		if mode in ["IDLE", "DONE"]: rids.append(_player.get_rid())
		elif body != null and mode in ["FALLING", "GETTING_UP"]: rids = body.body_rids()
	return {"driver_mode":mode,"dead":_dead or _impact_dead,"recovery_suppressed":_dead or _impact_dead,"physical_body_rids":rids}

func _impact_error(reason: String) -> Dictionary:
	return {"ok":false,"error":reason,"irreversible":false,"may_have_applied":false}

func _impact_vector(value: Variant, bound: float) -> bool:
	return value is Vector3 and value.is_finite() and value.length() <= bound

func _impact_inertia(part: RigidBody3D, shape: CapsuleShape3D) -> Vector3:
	# Exact GodotPhysics 4.7.2 GodotCapsuleShape3D AABB inertia, NOT the
	# textbook solid-capsule formula. Pool has one centered unscaled capsule.
	var r2 := shape.radius * shape.radius
	var h2 := shape.height * shape.height * .25
	return Vector3(h2+r2, 2.0*r2, h2+r2) * (part.mass/3.0)

func _prepare_impact(command: Dictionary) -> Dictionary:
	if _impact_busy or not Thread.is_main_thread(): return _impact_error("reentry_or_thread")
	if _impact_binding.is_empty() or not _valid_life() or body == null or not body._pool_valid(): return _impact_error("lifetime_or_pool")
	if not is_instance_valid(_player._pose_skeleton) or not is_instance_valid(_player._pose_motion) or body._skeleton.get_ref() != _player._pose_skeleton: return _impact_error("rig_replaced")
	if not _player._pose_skeleton.is_inside_tree() or not _player._pose_motion.is_inside_tree(): return _impact_error("rig_lifetime")
	if command.get("binding") != _impact_binding or not command.get("owner_before") is Dictionary: return _impact_error("session")
	var owner: Dictionary = command.owner_before
	for key in _impact_binding:
		if owner.get(key) != _impact_binding[key] or typeof(owner.get(key)) != typeof(_impact_binding[key]) or typeof(command.binding.get(key)) != typeof(_impact_binding[key]): return _impact_error("owner_binding")
	if not owner.get("pose_epoch") is int or owner.pose_epoch != _player._pose_epoch or owner.get("pose_owner") != str(_player._pose_authority) or owner.get("driver_mode") != mode: return _impact_error("pose_lease")
	if owner.get("physical_body_rids") != impact_owner_state().physical_body_rids: return _impact_error("physical_owner")
	if not command.get("final_dead") is bool or not owner.get("dead") is bool: return _impact_error("death_schema")
	if (_dead or _impact_dead) and not owner.dead: return _impact_error("death_regression")
	if not command.get("event_key") is String or command.event_key.is_empty() or command.event_key.length() > 4096: return _impact_error("event_key")
	if not command.get("physical_input") is Dictionary or not command.get("admitted") is Dictionary: return _impact_error("input_schema")
	var input: Dictionary = command.physical_input
	var action: String = command.get("action", "")
	var begin := action in ["begin_point_impulse", "begin_observed"]
	var resume := action in ["resume_point_impulse", "resume_observed"]
	var observed := action in ["begin_observed", "resume_observed", "observe_existing"]
	if begin:
		if mode not in ["IDLE", "DONE"] or _player._pose_authority != &"on_foot" or owner.get("transport_state") != "none": return _impact_error("begin_owner")
	elif resume or action in ["apply_existing", "observe_existing"]:
		if mode != ("GETTING_UP" if resume else "FALLING") or _player._pose_epoch != _pose_epoch or _player._pose_authority != _pose_owner: return _impact_error("existing_owner")
		if not body._active or body._paused != resume: return _impact_error("physical_mode")
	else: return _impact_error("action")
	if input.get("delivery") != ("solver_observed" if observed else "command_unapplied"): return _impact_error("delivery")
	if not _impact_vector(input.get("world_point"), 17320508.0) or not _impact_vector(input.get("impulse_ns"), Body.MAX_IMPULSE_NS) or not _impact_vector(command.get("apply_impulse_ns"), Body.MAX_IMPULSE_NS): return _impact_error("force_or_contact")
	if command.apply_impulse_ns != (Vector3.ZERO if observed else input.impulse_ns): return _impact_error("impulse_contract")
	if not _impact_vector(command.admitted.get("world_point"),17320508.0) or command.admitted.world_point.distance_to(input.world_point) > .0001: return _impact_error("admitted_contact")
	if not input.get("physics_tick") is int or not owner.get("physics_tick") is int or input.physics_tick != Engine.get_physics_frames() or owner.physics_tick != input.physics_tick: return _impact_error("physics_tick")
	var frames: Dictionary = body.capture_world_frames() if begin or resume else {}
	var velocity: Vector3 = _player.velocity if begin else Vector3.ZERO
	var angular := Vector3.ZERO
	var reference: Vector3 = _player.global_position
	if observed:
		if not input.get("solver_body_rid") is RID or not owner.physical_body_rids.has(input.solver_body_rid): return _impact_error("solver_rid")
		if not _impact_vector(input.get("post_velocity"),80.0) or not _impact_vector(input.get("post_angular_velocity"),30.0) or not _impact_vector(input.get("velocity_reference"),17320508.0): return _impact_error("solver_state")
		var state := PhysicsServer3D.body_get_direct_state(input.solver_body_rid)
		if state == null: return _impact_error("solver_state_unavailable")
		reference = input.velocity_reference
		angular = state.angular_velocity
		velocity = state.linear_velocity + angular.cross(reference - state.transform * state.center_of_mass_local)
		if velocity.distance_to(input.post_velocity) > .0001 or angular.distance_to(input.post_angular_velocity) > .0001: return _impact_error("solver_state_mismatch")
	if not _impact_vector(velocity,80.0): return _impact_error("inherited_velocity")
	if begin or resume:
		for name: String in body._bones:
			if not Body._finite_frame(frames.get(name)) or frames[name].basis.get_scale().distance_to(body._rest[name].basis.get_scale()) > .0001: return _impact_error("bone_frame:"+name)
	var best := INF
	var selected := ""
	var selected_frame := Transform3D.IDENTITY
	var inertias := {}
	var total_mass := 0.0
	# Bound the supported owner topology before acquiring/changing any lease.
	# 4.7.2 official register_types.cpp registers GodotPhysics3D as DEFAULT;
	# Jolt registers a selectable server but does not replace that default.
	var backend := str(ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"))
	if backend != "GodotPhysics3D" and not (backend == "DEFAULT" and Engine.get_version_info().hash == "ed1daf0bf001b61586d9930840f2f1394092c079"): return _impact_error("physics_backend")
	for name: String in Body.BODY_NAMES:
		var part: RigidBody3D = body._bodies[name]
		var collider: CollisionShape3D = body._shapes[name]
		if not collider.shape is CapsuleShape3D or not collider.transform.is_equal_approx(Transform3D.IDENTITY) or part.inertia != Vector3.ZERO or part.center_of_mass_mode != RigidBody3D.CENTER_OF_MASS_MODE_AUTO or part.get_shape_owners().size() != 1: return _impact_error("unsupported_inertia")
		var frame: Transform3D = frames[name]*body._bone_to_body[name] if begin or resume else part.global_transform
		if not frame.basis.get_scale().is_equal_approx(Vector3.ONE): return _impact_error("body_scale")
		if begin or resume:
			if absf(float(body._segment(name,frames).length)-float(body._dimensions[name].length)) > .01: return _impact_error("rig_length")
			if (velocity+angular.cross(frame.origin-reference)).length() > 80.0: return _impact_error("segment_velocity")
		var capsule: CapsuleShape3D = collider.shape
		if absf(capsule.radius-float(body._dimensions[name].radius))>.000001 or absf(capsule.height-float(body._dimensions[name].height))>.000001: return _impact_error("changed_shape")
		var point: Vector3 = frame.affine_inverse()*input.world_point
		var half := maxf(0.0,capsule.height*.5-capsule.radius)
		var distance := maxf(0.0,point.distance_to(Vector3(0,clampf(point.y,-half,half),0))-capsule.radius)
		if distance < best: best = distance; selected = name; selected_frame = frame
		inertias[name] = _impact_inertia(part,capsule)
		total_mass += part.mass
	if absf(total_mass-75.0) > .001 or best > .75 or selected.is_empty(): return _impact_error("mass_or_contact")
	var target: RigidBody3D = body._bodies[selected]
	var target_v := velocity+angular.cross(selected_frame.origin-reference)
	var target_w := angular
	if not begin and not resume:
		var target_state := PhysicsServer3D.body_get_direct_state(target.get_rid())
		if target_state == null: return _impact_error("target_state")
		target_v = target_state.linear_velocity; target_w = target_state.angular_velocity
	var inverse := selected_frame.basis * Basis.from_scale((inertias[selected] as Vector3).inverse()) * selected_frame.basis.transposed()
	var next_w: Vector3 = target_w + inverse*((input.world_point-selected_frame.origin).cross(command.apply_impulse_ns))
	if (target_v+command.apply_impulse_ns/target.mass).length() > 80.0 or next_w.length() > 30.0: return _impact_error("post_impulse_velocity")
	return {"ok":true,"pose_epoch":_player._pose_epoch+1 if begin else _player._pose_epoch,"pose_owner":"physical_impact" if begin else str(_player._pose_authority),"frames":frames,"velocity":velocity,"angular":angular,"reference":reference,"begin":begin,"resume":resume,"selected":selected,"inertia":inertias[selected],"contact_distance":best}

func preflight_impact(command: Dictionary) -> Dictionary:
	var plan := _prepare_impact(command)
	if not plan.ok: return plan
	return {"ok":true,"pose_epoch":plan.pose_epoch,"pose_owner":plan.pose_owner,"bone":plan.selected,"contact_distance":plan.contact_distance}

func dispatch_impact(command: Dictionary) -> Dictionary:
	var plan := _prepare_impact(command)
	if not plan.ok: return plan
	if not command.get("expected_pose_epoch") is int or command.expected_pose_epoch != plan.pose_epoch or command.get("expected_pose_owner") != plan.pose_owner: return _impact_error("planned_lease")
	_impact_busy = true
	if plan.begin or plan.resume:
		if plan.begin:
			var motion: Transform3D = _player._pose_motion.transform
			_saved_layer = _player.collision_layer; _saved_mask = _player.collision_mask
			_player.set_preview_pose_authority(&"physical_impact")
			_player._pose_motion.transform = motion
			_pose_epoch = _player._pose_epoch; _pose_owner = _player._pose_authority
			_player.collision_layer = 0; _player.collision_mask = 0
		_player.velocity = Vector3.ZERO
		body.reset()
		var started: Dictionary = body.start(plan.frames,plan.velocity,Vector3.ZERO,plan.angular,plan.reference)
		if not started.get("ok",false):
			_impact_busy = false
			_fault("impact_start:"+str(started.get("error","unknown")))
			return {"ok":false,"error":fault_reason,"irreversible":true,"may_have_applied":false,"applied_impulse_ns":Vector3.ZERO}
		mode = "FALLING"
		_elapsed = 0.0
		_getup_pose.clear()
		last_snapshot = body.snapshot()
		_proxy_height = maxf(.2,float(last_snapshot.anchor_world.y)-_player.global_position.y)
	_stable = 0.0; _recovery_stable = 0.0
	_impact_dead = _impact_dead or _dead or command.final_dead or command.owner_before.dead
	_dead = _impact_dead
	var applied := Vector3.ZERO
	if command.apply_impulse_ns != Vector3.ZERO:
		var target: RigidBody3D = body._bodies[plan.selected]
		# Freeze clears native inverse inertia. Force the exact auto value now,
		# before the first point impulse; restore automatic calculation afterward.
		target.inertia = plan.inertia
		var result: Dictionary = body.apply_impulse(command.physical_input.world_point,command.apply_impulse_ns,command.event_key)
		target.inertia = Vector3.ZERO
		if not result.get("ok",false):
			_impact_busy = false
			return {"ok":false,"error":"point_impulse_failed","irreversible":true,"may_have_applied":true,"applied_impulse_ns":null}
		applied = command.apply_impulse_ns
	last_snapshot = body.snapshot()
	_impact_busy = false
	return {"ok":true,"error":"","event_key":command.event_key,"pose_epoch":_player._pose_epoch,"applied_impulse_ns":applied,"irreversible":true,"may_have_applied":false,"bone":plan.selected,"recovery_suppressed":_dead}

func fault_impact_owner(reason: String) -> Dictionary:
	if _impact_busy or _impact_binding.is_empty() or not _valid_life() or mode not in ["FALLING","GETTING_UP"] or _player._pose_authority != &"physical_impact" or _pose_owner != &"physical_impact" or _player._pose_epoch != _pose_epoch: return _impact_error("fault_owner_changed")
	_fault("impact_host:"+reason.left(256))
	return {"ok":true,"faulted":true,"irreversible":true,"pose_epoch":_pose_epoch}
