extends "res://scripts/tests/test_npc_ragdoll_host.gd"
const Recovery = preload("res://scripts/npc_visual/npc_ragdoll_recovery.gd")
class FailedResumeHost extends Host:
	func cancel_recovery(_reason := "blocked") -> Dictionary:
		# Inject the real failure endpoint: inactive pool, preserved colliding guard.
		# This tests recovery's failure policy, not engine start() failure frequency.
		_body.reset(); mode = "RECOVERY_HOLD"
		return _result(false,"TEST_ONLY_injected_resume_failure")
var released := true
var source_dead := false
var reaction_generation := 1
var revision := 1
var recovery_us: Array[int] = []
var active_baseline_us: Array[int] = []
var active_with_recovery_us: Array[int] = []
var rise_us: Array[int] = []
func release_gate(binding: Dictionary, _phase: String) -> Dictionary:
	return {"known":true,"binding":binding.duplicate(),"release_allowed":released,"final_dead":source_dead,"reaction_generation":reaction_generation,"revision":revision}
func box_obstacle(world: Node3D, position: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new(); var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size = Vector3(2,.25,2); c.shape = s; b.add_child(c); b.position = position; world.add_child(b); return b
func scenario(entry: Dictionary, variant: String, supplied_world: Node3D = null, supplied_pair: Dictionary = {}) -> void:
	var world := supplied_world
	if world == null: world = Node3D.new(); root.add_child(world); floor_body(world)
	var pair := create_actor(world,entry) if supplied_pair.is_empty() else supplied_pair
	var initial_position: Vector3 = pair.actor.global_position
	released = true; source_dead = false; reaction_generation = 1; revision = 1
	var host: RefCounted = FailedResumeHost.new() if variant == "resume_failure" else Host.new()
	active_host = host; check(host.configure(token,world,valid,confirmed).ok,"recovery host prewarm")
	var recovery := Recovery.new()
	var configured: Dictionary = recovery.configure(host,token,pair.actor.get_child(1),world,valid,release_gate)
	check(configured.ok,"actual NPC prepared skin binding "+entry.bridge_id+" "+str(configured))
	if not configured.ok: host.dispose(); world.free(); return
	check(not recovery.advance(1.0/60.0).walking_ready,"prewarm alone is not a completed physical getup")
	await tick(); await tick()
	admit("vehicle_knockdown",Vector3(45,0,0)); check(host.activate("fixture_event").ok,"nonfatal physical fall")
	var obstacle: StaticBody3D
	var block_removed := false; var rising_seen := false; var triggered := false; var interruption_checked := false
	var moving_car: RigidBody3D; var moving_car_origin := Vector3.ZERO; var moving_car_distance := 0.0
	var cancel_error := 0.0; var commit_error := 0.0
	var max_pose_step := 0.0; var previous_frames: Dictionary = {}; var smallest_skin := INF
	var skin := skin_points(pair.rig)
	var start_attempts := 0; var stopped := ""; var contact_guard_seen := false
	for i in 960:
		await tick()
		if variant == "blocked" and i == 180:
			var s: Dictionary = host.advance(); var anchor: Vector3 = s.physical.anchor_world
			obstacle = box_obstacle(world,Vector3(anchor.x,1.4,anchor.z)); start_attempts = recovery.attempts
		if variant == "blocked" and i == 340:
			check(recovery.mode == "WAITING" and host.mode == "ACTIVE","blocked capsule retains live ragdoll")
			check(recovery.attempts>start_attempts,"blocked recovery retries rather than one-shot fails")
			obstacle.free(); obstacle = null; block_removed = true
		var before_frames: Dictionary = host._body.capture_world_frames() if host.mode == "RECOVERING" else {}
		var baseline := {}; var baseline_us := 0; var began_active: bool = host.mode == "ACTIVE"
		if began_active:
			var baseline_start := Time.get_ticks_usec(); baseline = host.advance(); baseline_us = Time.get_ticks_usec()-baseline_start
			active_baseline_us.append(baseline_us)
		var before := Time.get_ticks_usec(); var state: Dictionary = recovery.advance(1.0/60.0,baseline); var added_us := Time.get_ticks_usec()-before
		recovery_us.append(added_us)
		if began_active: active_with_recovery_us.append(baseline_us+added_us)
		else: rise_us.append(added_us)
		if is_instance_valid(moving_car): moving_car_distance = maxf(moving_car_distance,moving_car.global_position.distance_to(moving_car_origin))
		if not before_frames.is_empty() and host.mode == "ACTIVE":
			cancel_error = maxf(cancel_error,pose_error(pair.rig,before_frames))
			check(cancel_error<.00001,"interrupted physical resume preserves last displayed pose")
		if state.mode == "RISING":
			rising_seen = true
			contact_guard_seen = is_instance_valid(recovery._guard) and recovery._guard.collision_layer != 0
			check(contact_guard_seen and pair.actor.collision_layer == 0,"colliding recovery guard replaces paused body; capsule stays disabled")
			var frames: Dictionary = host._body.capture_world_frames()
			if not previous_frames.is_empty():
				for name: String in frames: max_pose_step = maxf(max_pose_step,frames[name].origin.distance_to(previous_frames[name].origin))
			previous_frames = frames
			smallest_skin = minf(smallest_skin,skin_minimum(skin,frames))
			if variant == "moving_car" and not triggered:
				triggered = true
				moving_car = actual_car_body(world,recovery._target.origin.x)
				moving_car.global_position.z = recovery._target.origin.z-3.8
				moving_car_origin = moving_car.global_position
			if variant in ["restun","final_dead","obstacle_returns","generation","disabled_capsule","changed_filters","resume_failure"] and not triggered and state.getup_progress>.3:
				triggered = true
				if variant == "restun": released = false; reaction_generation += 1; revision += 1
				elif variant == "final_dead":
					admit("final_death"); check(host.confirm_final_death("fixture_event").ok,"confirmed later death interrupts rise")
					source_dead = true; revision += 1
				elif variant == "generation": token.life_generation += 1
				elif variant == "disabled_capsule": pair.actor.get_child(0).disabled = true
				elif variant == "changed_filters": pair.actor.collision_layer = 1
				elif variant == "resume_failure":
					admit("final_death"); check(not host.confirm_final_death("fixture_event").ok,"injected final-death resume failure reported")
					source_dead = true; revision += 1
				else: obstacle = box_obstacle(world,Vector3(recovery._target.origin.x,1.4,recovery._target.origin.z))
		elif rising_seen and triggered and not interruption_checked and state.mode in ["WAITING","FINAL_DEAD","DISPOSED","HOLD"]:
			interruption_checked = true
			if variant == "restun":
				check(host.mode == "ACTIVE" and pair.actor.collision_layer == 0,"re-stun resumes actual physics without walking")
				released = true; revision += 1; stopped = "restun_cancelled"
			if variant == "obstacle_returns":
				check(host.mode == "ACTIVE" and pair.actor.collision_layer == 0,"returning obstacle resumes physics")
				obstacle.free(); obstacle = null; block_removed = true; stopped = "obstacle_cancelled"
			if variant == "moving_car":
				check(host.mode == "ACTIVE" and pair.actor.collision_layer == 0,"actual moving chassis blocks rise and resumes physics")
				stopped = "moving_chassis_cancelled"; break
			if variant == "final_dead":
				check(host.status().final_dead and pair.actor.collision_layer == 0 and not state.walking_ready,"final dead never stands")
				stopped = "final_dead"; break
			if variant == "generation": check(not state.walking_ready,"stale generation cannot stand"); stopped = "stale"; break
			if variant in ["disabled_capsule","changed_filters"]:
				check(not state.walking_ready and state.mode == "DISPOSED","changed walking collision ownership cannot commit")
				stopped = "collision_ownership_changed"; break
			if variant == "resume_failure":
				check(state.mode == "HOLD" and host.mode == "RECOVERY_HOLD" and host.status().final_dead,"failed final-death resume retains HOLD")
				check(is_instance_valid(recovery._guard) and recovery._guard.collision_layer != 0 and pair.actor.collision_layer == 0,"failed final-death resume preserves sole protective collider")
				check(not state.walking_ready,"failed resume never acknowledges standing")
				stopped = "physical_resume_hold"; break
		if state.walking_ready:
			commit_error = pose_error(pair.rig,recovery._frames(recovery._proposed))
			check(commit_error<.0001,"final walking commit preserves displayed world pose")
			check(host.mode == "IDLE" and pair.actor.collision_layer == 1 and pair.actor.collision_mask == 1,"atomic collision/gait-ready handoff")
			check(not is_instance_valid(recovery._guard),"temporary recovery guard removed on successful commit")
			stopped = "stood"; break
		if state.mode != "RISING": previous_frames.clear()
	check(rising_seen,"eventually attempts physical rise "+variant+" "+entry.bridge_id+" last="+str(recovery.status()))
	if variant in ["clear","blocked","restun","obstacle_returns","actual_main"]: check(stopped == "stood","complete physical getup "+variant+" "+entry.bridge_id+" last="+str(recovery.status()))
	else: check(triggered and not stopped.is_empty(),"interrupt semantics "+variant+" last="+str(recovery.status()))
	if variant == "moving_car": check(stopped == "moving_chassis_cancelled" and moving_car_distance>.2 and recovery.interruptions == 1,"moving actual native chassis interrupts blocked rise")
	check(max_pose_step<.12,"bounded continuous getup frame displacement "+variant)
	check(smallest_skin>=recovery._floor_y-.002,"full actual skin remains above support during getup "+variant)
	var diagnostic: Dictionary = host._body.snapshot() if host._body != null else {}
	var target_only: Dictionary = target_only_probe(recovery) if recovery.reason == "initial_skin_blocked" else {}
	rows.append({"actor":entry.bridge_id,"variant":variant,"initial_position":str(initial_position),"stopped":stopped,"last":recovery.status(),"canonical_correction_m":recovery._canonical_error_m,"max_bone_frame_step_m":max_pose_step,"cancel_pose_error_m":cancel_error,"commit_pose_error_m":commit_error,"actual_chassis_travel_m":moving_car_distance,"min_skin_y":smallest_skin if is_finite(smallest_skin) else null,"collision_guard_seen":contact_guard_seen,"block_removed":block_removed,"skin_sweep_valid":recovery._proposed_sweep.get("valid"),"skin_sweep_reason":recovery._proposed_sweep.get("reason"),"initial_skin_bounds":str(recovery._accepted_skin.get("bounds")),"physical_settled":diagnostic.get("settled"),"max_linear_speed":diagnostic.get("max_linear_speed"),"max_angular_speed":diagnostic.get("max_angular_speed"),"max_joint_error":diagnostic.get("max_joint_anchor_error_m")})
	rows[-1]["target_only_lift_probe"] = target_only
	recovery.dispose(); host.dispose()
	if supplied_world == null: world.free()
	active_host = null; await process_frame
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"visual_manifest.json"))
	for entry: Dictionary in manifest.entries: await scenario(entry,"clear")
	for variant: String in ["blocked","restun","final_dead","obstacle_returns","generation","moving_car","disabled_capsule","changed_filters","resume_failure"]: await scenario(manifest.entries[0],variant)
	recovery_us.sort()
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"rows":rows,"step_us_p50":recovery_us[recovery_us.size()/2] if not recovery_us.is_empty() else -1,"step_us_p95":recovery_us[int(recovery_us.size()*.95)] if not recovery_us.is_empty() else -1,"host_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_ragdoll_host.gd"),"recovery_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_ragdoll_recovery.gd"),"GPU":false,"full_scene_FPS":"NOT_RUN","source_gate":"TEST_ONLY external current-release fixture"}
	report["cost"] = costs()
	var file := FileAccess.open("../../outputs/artist22_npc_recovery/RESULT.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NPC_RECOVERY ",JSON.stringify(report)); quit(0 if errors.is_empty() else 1)
func costs() -> Dictionary:
	active_baseline_us.sort(); active_with_recovery_us.sort(); rise_us.sort()
	var result := {"scope":"paired same-physics-tick ACTIVE host.advance before recovery.advance(delta, supplied_sample); component CPU, not engine total/FPS"}
	for item: Array in [["active_without_recovery",active_baseline_us],["active_with_recovery",active_with_recovery_us],["rising_recovery",rise_us]]:
		var samples: Array = item[1]
		result[item[0]] = {"n":samples.size(),"p50_us":samples[samples.size()/2] if not samples.is_empty() else -1,"p95_us":samples[int(samples.size()*.95)] if not samples.is_empty() else -1}
	return result
func target_only_probe(recovery: RefCounted) -> Dictionary:
	if not recovery._accepted_skin.get("valid",false): return {}
	var original: Transform3D = recovery._base_world
	var initial: Dictionary = recovery._from.duplicate(true)
	var skin: Dictionary = recovery._clearance.snapshot(initial,original,false)
	if not skin.get("valid",false): return {}
	var lift: float = maxf(0.0,recovery._floor_y-skin.bounds.position.y)+.003
	var lifted := original; lifted.origin.y += lift
	initial.visual_offset -= lifted.basis.inverse()*Vector3.UP*lift
	var adjusted: Dictionary = recovery._clearance.snapshot(initial,lifted,false)
	var first_sweep: Dictionary = recovery._clearance.between(adjusted,adjusted,recovery._floor_y)
	check(absf(skin.bounds.position.y-adjusted.bounds.position.y)<.00001,"target-only lift preserves initial world geometry")
	check(not first_sweep.get("valid",false),"target-only lift cannot bypass intersecting initial skin")
	return {"target_lift_m":lift,"original_initial_min_y":skin.bounds.position.y,"preserved_initial_min_y":adjusted.bounds.position.y,"first_sweep_valid":first_sweep.get("valid",false),"reason":first_sweep.get("reason"),"source_ragdoll_moved":false,"clearance_relaxed":false}
