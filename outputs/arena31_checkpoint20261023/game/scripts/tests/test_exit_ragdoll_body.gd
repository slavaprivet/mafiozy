extends SceneTree
const Ragdoll = preload("res://scripts/character_physics/exit_ragdoll_body.gd")
const Player = preload("res://scripts/preview_player.gd")
const ExitPose = preload("res://scripts/vehicle_visual/vehicle_exit_pose.gd")
var checks := 0
var errors: Array[String] = []
var scenarios: Array = []
var snapshot_us: Array[int] = []
var source_hash := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and errors.size() < 40: errors.append(label)

func add_box(parent: Node3D, pos: Vector3, size: Vector3, angle := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

func lowest_point(rag: RefCounted) -> float:
	var lowest := INF
	for body: RigidBody3D in rag.owned_bodies():
		var shape: CapsuleShape3D = body.get_child(0).shape
		var end_offset := body.global_basis.y*(shape.height*.5-shape.radius)
		lowest = minf(lowest, minf((body.position-end_offset).y,(body.position+end_offset).y)-shape.radius)
	return lowest

func scenario(obstacle: bool, tucked := false) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := add_box(world,Vector3(0,-.1,0),Vector3(40,.2,40))
	if obstacle: add_box(world,Vector3(1.3,.65,0),Vector3(.2,1.3,3.0),.28)
	var player = Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0
	var skeleton: Skeleton3D = player._pose_skeleton
	if tucked:
		var pose := ExitPose.new()
		check(pose.configure(skeleton,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._pose_motion),"actual release pose binding")
		var sampled := pose.sample(0.0,1.0,Callable(),null,0)
		check(sampled.get("valid",false),"actual authored tuck sample")
		for i in skeleton.get_bone_count(): skeleton.set_bone_pose(i,sampled.poses[i])
		player._pose_motion.position = sampled.visual_offset
		player._pose_motion.quaternion = sampled.visual_rotation
		pose.dispose()
	var initial_player: Transform3D = player.transform
	var bone_poses: Array[Transform3D] = []
	for i in skeleton.get_bone_count(): bone_poses.append(skeleton.get_bone_pose(i))
	var rag := Ragdoll.new()
	var configure_start := Time.get_ticks_usec()
	var configured := rag.configure(skeleton,world,{"exceptions":[player]})
	var configure_us := Time.get_ticks_usec()-configure_start
	check(configured.get("ok",false),"configure actual canonical player "+str(configured))
	if not configured.get("ok",false): world.free(); return
	check(configured.bodies == 16 and configured.joints == 15,"bounded physical topology")
	for body: RigidBody3D in rag.owned_bodies():
		check(body.get_collision_exceptions().size() >= 15,"bounded internal-only proxy exclusions prewarmed")
		check(not floor in body.get_collision_exceptions(),"actual world floor never excluded")
	check(not rag.snapshot().active,"prewarm off on foot")
	var ids: Array[int] = []
	for body: RigidBody3D in rag.owned_bodies():
		ids.append(body.get_instance_id())
		check(body.freeze and body.collision_layer == 0 and body.collision_mask == 0 and body.get_child(0).disabled,"inactive collider fully disabled")
	await physics_frame
	await physics_frame
	var frames := rag.capture_world_frames()
	var placement := Transform3D(Basis(Vector3.FORWARD,.22),Vector3(0,1.2,0))
	for name: String in frames: frames[name] = placement*frames[name]
	check(not rag.start({},Vector3.ZERO).ok,"missing world frames fail closed")
	check(not rag.start(frames,Vector3(INF,0,0)).ok,"nonfinite velocity rejected")
	var begin := Time.get_ticks_usec()
	var started := rag.start(frames,Vector3(1.5,0,.2),Vector3(60,0,0))
	var start_us := Time.get_ticks_usec()-begin
	check(started.get("ok",false),"start physical fall "+str(started))
	if not started.get("ok",false): rag.dispose();world.free();return
	var initial := rag.snapshot()
	check(initial.valid and initial.bone_world_frames.size() == skeleton.get_bone_count(),"full world bone snapshot")
	var start_pose_error := 0.0
	for name: String in frames:
		var t: Transform3D = initial.bone_world_frames[name]
		start_pose_error = maxf(start_pose_error,t.origin.distance_to(frames[name].origin))
		check(t.basis.is_equal_approx(frames[name].basis),"initial bone basis preserved "+name)
	check(start_pose_error < .00001,"no handoff pose snap")
	check(not rag.freeze_at_rest().ok,"moving ragdoll cannot freeze as settled")
	var changed_rotation := 0.0
	var max_joint_error := 0.0
	var worst_joint := ""
	var worst_floor := INF
	var max_contacts := 0
	var max_support := 0
	var max_side := 0
	var settled_at := -1
	var final := {}
	var maximum_elbow_change := 0.0
	var knee_min := INF
	var knee_max := -INF
	var initial_elbow: Basis = (frames.upperarm_l as Transform3D).basis.inverse()*(frames.forearm_l as Transform3D).basis
	for tick in 600:
		await physics_frame
		await process_frame
		var before := Time.get_ticks_usec()
		final = rag.snapshot()
		snapshot_us.append(Time.get_ticks_usec()-before)
		check(final.get("valid",false),"finite actual simulated frames")
		if not final.get("valid",false): break
		check(final.energy_valid and is_finite(final.kinetic_energy_j) and final.kinetic_energy_j >= 0,"active native inertia produces finite nonnegative kinetic energy")
		check(final.core_max_linear_speed <= final.max_linear_speed and final.core_max_angular_speed <= final.max_angular_speed,"core maximum bounded by whole body")
		check(final.settled == (final.contact_count > 0 and final.max_linear_speed < .12 and final.max_angular_speed < .3 and final.max_joint_anchor_error_m < .035),"diagnostics preserve previous settled condition")
		max_support = maxi(max_support,final.support_contact_count)
		max_side = maxi(max_side,final.side_contact_count)
		if final.max_joint_anchor_error_m > max_joint_error:
			max_joint_error = final.max_joint_anchor_error_m
			for row: Dictionary in rag._joints:
				if (rag._bodies[row.parent].global_transform*row.a).distance_to(rag._bodies[row.child].global_transform*row.b) >= max_joint_error-.000001: worst_joint = str(row.child)+":"+str(tick)
		max_contacts = maxi(max_contacts,final.contact_count)
		worst_floor = minf(worst_floor,lowest_point(rag))
		var frame: Transform3D = final.bone_world_frames.chest
		for side: String in ["l","r"]:
			var knee: Basis = (final.bone_world_frames["thigh_"+side] as Transform3D).basis.inverse()*(final.bone_world_frames["shin_"+side] as Transform3D).basis
			var canonical: Basis = (rag._rest["thigh_"+side] as Transform3D).basis.inverse()*(rag._rest["shin_"+side] as Transform3D).basis
			var angle := (canonical.inverse()*knee).orthonormalized().get_euler().x
			knee_min = minf(knee_min,angle); knee_max = maxf(knee_max,angle)
		var relative_elbow: Basis = (final.bone_world_frames.upperarm_l as Transform3D).basis.inverse()*(final.bone_world_frames.forearm_l as Transform3D).basis
		maximum_elbow_change = maxf(maximum_elbow_change,initial_elbow.orthonormalized().get_rotation_quaternion().angle_to(relative_elbow.orthonormalized().get_rotation_quaternion()))
		changed_rotation = maxf(changed_rotation,frame.basis.orthonormalized().get_rotation_quaternion().angle_to(frames.chest.basis.orthonormalized().get_rotation_quaternion()))
		if final.settled and tick > 120:
			settled_at = tick
			break
	check(max_contacts > 0,"actual external collision contacts")
	check(max_support > 0,"actual world-up floor contact normal")
	if obstacle: check(max_side > 0,"oblique wall contacts distinguished from support")
	check(worst_floor > -.055,"capsules do not tunnel through floor")
	check(max_joint_error < .075,"joint anchors stay bounded under off-axis impact")
	check(changed_rotation > .2,"real contacts rotate body, no animation")
	check(maximum_elbow_change > .08,"limbs articulate independently of chest rotation")
	check(settled_at >= 0,"physics reaches contact and low speed settled state")
	var rolled_floor_contact := false
	for body: RigidBody3D in rag.owned_bodies():
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		for contact in state.get_contact_count():
			if state.get_contact_collider_object(contact) != floor: continue
			var actual := state.get_contact_local_normal(contact)
			check(actual.dot(Vector3.UP) > .95,"actual flat-floor contact normal remains world-up on rolled body")
			if (body.global_basis*actual).dot(Vector3.UP) < .5: rolled_floor_contact = true
	check(rolled_floor_contact,"floor-support proof includes rolled body where extra basis multiplication would be wrong")
	check(player.transform == initial_player,"does not mutate character authority transform")
	for i in skeleton.get_bone_count(): check(skeleton.get_bone_pose(i) == bone_poses[i],"single external visual writer retained")
	var hit_point: Vector3 = rag._bodies.head.global_position + rag._bodies.head.global_basis.x*.08
	var applied := rag.apply_impulse(hit_point,Vector3(-4,10,2),"physical-test")
	check(applied.get("ok",false),"localized impact accepted")
	check(not rag.apply_impulse(Vector3(1000,1000,1000),Vector3.ONE).ok,"distant impact rejected")
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	check(rag.snapshot().max_linear_speed > .12,"impact wakes actual physics")
	check(rag.snapshot().max_angular_speed > .3,"off-centre impact produces real torque")
	check(rag.stop_preserve().ok,"freeze existing final pose for host getup")
	var held := rag.snapshot()
	await physics_frame
	await physics_frame
	check(rag.snapshot().pelvis_body_transform == held.pelvis_body_transform,"frozen getup has no drift")
	check(rag.reset().ok and not rag.snapshot().active,"reusable inactive reset")
	check(rag.body_rids().size() == 16,"clearance exclusion RIDs bounded")
	for body: RigidBody3D in rag.owned_bodies(): check(body.get_instance_id() in ids and body.freeze and body.collision_mask == 0,"reset preserves prewarm without live physics")
	check(not rag.start(frames,Vector3.ZERO,Vector3.ZERO,Vector3(INF,0,0)).ok,"nonfinite angular velocity rejected")
	check(not rag.start(frames,Vector3.ZERO,Vector3.ZERO,Vector3(0,31,0)).ok,"bounded angular velocity rejected")
	check(not rag.start(frames,Vector3.ZERO,Vector3.ZERO,Vector3.UP,Vector3(INF,0,0)).ok,"nonfinite reference rejected")
	check(not rag.start(frames,Vector3.ZERO,Vector3.ZERO,Vector3.UP,Vector3(1000,0,0)).ok,"excess per-segment velocity rejects before mutation")
	var ref_point := Vector3(3,2,-4)
	var omega := Vector3(.2,1,-.3)
	var inherited := Vector3(3,1,2)
	var distributed_impulse := Vector3(75,0,0)
	check(rag.start(frames,inherited,distributed_impulse,omega,ref_point).ok,"second physical start inherits angular velocity and reuses pool")
	var actual_momentum := Vector3.ZERO
	var system_com := Vector3.ZERO
	var total_mass := 0.0
	for body: RigidBody3D in rag.owned_bodies():
		actual_momentum += body.linear_velocity*body.mass
		system_com += body.global_position*body.mass
		total_mass += body.mass
		check(body.angular_velocity.is_equal_approx(omega),"all parts inherit vehicle angular velocity")
		check(body.linear_velocity.distance_to(inherited+omega.cross(body.global_position-ref_point)+distributed_impulse/75.0) < .00001,"actual segment point velocity")
	system_com /= total_mass
	var expected_momentum := total_mass*(inherited+omega.cross(system_com-ref_point))+distributed_impulse
	check(actual_momentum.distance_to(expected_momentum) < .001,"system COM orbital velocity plus outward impulse conserves linear momentum")
	if tucked:
		world.remove_child(rag._root)
		check(not rag.snapshot().valid,"teardown outside world rejects snapshot")
	rag.stop_preserve()
	var body_refs := rag.owned_bodies()
	rag.dispose()
	for body: RigidBody3D in body_refs: check(not is_instance_valid(body),"dispose removes owned body")
	check(not rag.snapshot().valid,"disposed closed")
	scenarios.append({"obstacle":obstacle,"tucked":tucked,"worst_joint":worst_joint,"knee_min":knee_min,"knee_max":knee_max,"configure_us":configure_us,"start_us":start_us,"settled_tick":settled_at,"max_joint_error_m":max_joint_error,"minimum_capsule_y":worst_floor,"max_external_contacts":max_contacts,"chest_rotation_rad":changed_rotation,"maximum_relative_elbow_rotation":maximum_elbow_change,"final_anchor":str(final.get("anchor_world")),"final_sleeping":final.get("sleeping_count"),"final_joint_error":final.get("max_joint_anchor_error_m"),"final_linear_speed":final.get("max_linear_speed"),"final_angular_speed":final.get("max_angular_speed"),"start_pose_error_m":start_pose_error})
	world.free()
	await physics_frame

func run() -> void:
	source_hash = FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd")
	await scenario(false)
	await scenario(true)
	await scenario(true,true)
	check(FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd") == source_hash,"frozen module throughout")
	snapshot_us.sort()
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"module_sha256":source_hash,"scenarios":scenarios,"snapshot_us_p50":snapshot_us[snapshot_us.size()/2] if not snapshot_us.is_empty() else 0,"snapshot_us_p95":snapshot_us[int(snapshot_us.size()*.95)] if not snapshot_us.is_empty() else 0,"limits":"headless physics prototype; snapshot CPU excludes engine solver and is not whole-scene FPS; no source ragdoll parity claim"}
	var out := FileAccess.open("../../outputs/exit_ragdoll_body_test.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")+"\n")
	out.close()
	print("EXIT_RAGDOLL_BODY ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
