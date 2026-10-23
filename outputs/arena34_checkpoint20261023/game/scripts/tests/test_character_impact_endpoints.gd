extends SceneTree
const Player = preload("res://scripts/preview_player.gd")
const Driver = preload("res://scripts/character_physics/character_physics_driver.gd")
class FaultBody extends "res://scripts/character_physics/exit_ragdoll_body.gd":
	var fail_start := false
	var impulse_calls := 0
	func start(frames: Dictionary,v: Vector3,j := Vector3.ZERO,w := Vector3.ZERO,ref := Vector3.ZERO) -> Dictionary:
		if fail_start: return {"ok":false,"error":"injected_start_failure"}
		return super.start(frames,v,j,w,ref)
	func apply_impulse(p: Vector3,j: Vector3,id := "") -> Dictionary:
		impulse_calls += 1
		super.apply_impulse(p,j,id)
		return {"ok":false,"error":"injected_unknown_after_real_impulse"}
var checks := 0
var errors: Array[String] = []
var serial := 0
var world: Node3D
var player: CharacterBody3D
var driver: RefCounted
var binding := {"actor_id":"impact_endpoint_test","life_generation":1,"session_id":"isolated_native_test","session_generation":1}
var timings: Array[int] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: errors.append(label)
func setup() -> void:
	world = Node3D.new(); root.add_child(world)
	player = Player.new(); world.add_child(player); player.set_physics_process(false)
	player.set_meta("actor_id",binding.actor_id); player.set_meta("life_generation",1)
	player.position = Vector3(7,4,-3); player.rotation.y = .63
	driver = Driver.new()
	check(driver.configure(player,world).ok,"actual rig configured")
	check(driver.bind_impact_session(binding).ok,"actual life bound")
func cleanup() -> void:
	driver.dispose(); world.free()
func owner() -> Dictionary:
	var value := binding.duplicate()
	value.merge(driver.impact_owner_state())
	value.merge({"pose_epoch":player._pose_epoch,"pose_owner":str(player._pose_authority),"physics_tick":Engine.get_physics_frames(),"transport_state":"none","transport_token":""})
	return value
func point() -> Vector3:
	var frame: Transform3D = driver.body.capture_world_frames().head * driver.body._bone_to_body.head
	if driver.mode == "FALLING": frame = driver.body._bodies.head.global_transform
	return frame.origin+frame.basis.x*.04
func command(action: String,j := Vector3(0,1,0)) -> Dictionary:
	serial += 1
	var observed := "observ" in action
	var input := {"delivery":"solver_observed" if observed else "command_unapplied","world_point":point(),"impulse_ns":j,"physics_tick":Engine.get_physics_frames(),"force_profile_id":"TEST_ONLY"}
	if observed:
		var rid: RID = driver.impact_owner_state().physical_body_rids[0]
		var state := PhysicsServer3D.body_get_direct_state(rid)
		var reference := state.transform.origin + Vector3(.11,.03,-.08)
		input.merge({"solver_body_rid":rid,"post_velocity":state.linear_velocity+state.angular_velocity.cross(reference-state.transform*state.center_of_mass_local),"post_angular_velocity":state.angular_velocity,"velocity_reference":reference})
	return {"event_key":"test_"+str(serial),"binding":binding.duplicate(),"owner_before":owner(),"physical_input":input,"admitted":{"world_point":input.world_point},"action":action,"apply_impulse_ns":Vector3.ZERO if observed else j,"final_dead":false}
func dispatch(cmd: Dictionary) -> Dictionary:
	var plan: Dictionary = driver.preflight_impact(cmd)
	check(plan.ok,"preflight "+str(plan))
	if not plan.ok: return plan
	cmd.expected_pose_epoch = plan.pose_epoch; cmd.expected_pose_owner = plan.pose_owner
	var start := Time.get_ticks_usec()
	var result: Dictionary = driver.dispatch_impact(cmd)
	timings.append(Time.get_ticks_usec()-start)
	check(result.ok,"dispatch "+str(result))
	return result
func momentum() -> Vector3:
	var value := Vector3.ZERO
	for part: RigidBody3D in driver.body.owned_bodies(): value += PhysicsServer3D.body_get_direct_state(part.get_rid()).linear_velocity*part.mass
	return value
func assert_frames(expected: Dictionary,label: String) -> void:
	var actual: Dictionary = driver.body.snapshot().bone_world_frames
	for name in expected:
		check(expected[name].origin.distance_to(actual[name].origin)<.00002,label+" origin "+name)
		check(expected[name].basis.is_equal_approx(actual[name].basis),label+" basis "+name)
func run() -> void:
	setup()
	await physics_frame; await process_frame
	check(driver.impact_owner_state().physical_body_rids == [player.get_rid()],"idle owner capsule only")
	var original_epoch: int = player._pose_epoch
	var original_filter := Vector2i(player.collision_layer,player.collision_mask)
	for kind in ["far","force","lease","life","session","nan","delivery","planned","tick"]:
		var cmd := command("begin_point_impulse")
		match kind:
			"far": cmd.physical_input.world_point += Vector3(10,0,0); cmd.admitted.world_point=cmd.physical_input.world_point
			"force": cmd.apply_impulse_ns=Vector3(9999,0,0); cmd.physical_input.impulse_ns=cmd.apply_impulse_ns
			"lease": cmd.owner_before.pose_epoch+=1
			"life": cmd.binding.life_generation+=1
			"session": cmd.binding.session_generation+=1
			"nan": cmd.physical_input.world_point.x=NAN
			"delivery": cmd.physical_input.delivery="solver_observed"
			"planned": cmd.expected_pose_epoch=999; cmd.expected_pose_owner="physical_impact"
			"tick": cmd.physical_input.physics_tick-=1
		var result: Dictionary = driver.dispatch_impact(cmd) if kind=="planned" else driver.preflight_impact(cmd)
		check(not result.ok,"reject "+kind)
		check(driver.mode=="IDLE" and player._pose_epoch==original_epoch and Vector2i(player.collision_layer,player.collision_mask)==original_filter,"no mutation "+kind)
	player._pose_motion.rotation.z=.17
	player.velocity=Vector3(2,.3,-.7)
	var inherited := player.velocity
	var frames: Dictionary = driver.body.capture_world_frames()
	var motion: Transform3D = player._pose_motion.transform
	var cmd := command("begin_point_impulse")
	var initial: Dictionary = dispatch(cmd)
	check(initial.ok,"begin committed")
	if not initial.ok: cleanup(); finish(); return
	assert_frames(frames,"begin skin continuity")
	check(player._pose_motion.transform.is_equal_approx(motion),"setter preserves displayed motion")
	check(momentum().distance_to(inherited*75.0+cmd.apply_impulse_ns)<.0001,"first exact localized momentum")
	check(player.collision_mask==0 and player.collision_layer==0,"single physical owner")
	var target: RigidBody3D = driver.body._bodies[initial.bone]
	var state := PhysicsServer3D.body_get_direct_state(target.get_rid())
	var arm: Vector3 = cmd.physical_input.world_point-target.global_position
	var first_spin := state.angular_velocity
	check(first_spin.length()>.01,"first immediate point impulse has torque")
	check(target.inertia==Vector3.ZERO,"automatic inertia restored")
	var epoch: int = player._pose_epoch
	var pool: Array = driver.body.body_rids()
	var elapsed: float = driver._elapsed
	var before := momentum()
	var next := command("apply_existing")
	dispatch(next)
	check(momentum().distance_to(before+next.apply_impulse_ns)<.0001,"second localized J once")
	check(state.angular_velocity.distance_to(first_spin*2.0)<.00001,"first and second same pose torque identical")
	check(driver.body.body_rids()==pool and player._pose_epoch==epoch and driver._elapsed==elapsed,"existing no restart or lease change")
	var observation := command("observe_existing",Vector3(7,2,1))
	before=momentum(); var spin_before:=state.angular_velocity
	dispatch(observation)
	check(momentum().distance_to(before)<.00001 and state.angular_velocity.distance_to(spin_before)<.00001,"observation adds zero J and torque")
	observation=command("observe_existing"); observation.physical_input.post_velocity.x+=.01
	check(not driver.preflight_impact(observation).ok,"reject fabricated solver velocity")
	# Remove gravity/damping/joints only in this conservation fixture. Let native
	# automatic inertia compute, then compare against initial immediate torque.
	for row: Dictionary in driver.body._joints:
		row.node.node_a=NodePath(""); row.node.node_b=NodePath("")
	for part: RigidBody3D in driver.body.owned_bodies():
		part.gravity_scale=0; part.linear_damp=0; part.angular_damp=0
		part.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE; part.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
		part.collision_mask=0; part.linear_velocity=Vector3.ZERO; part.angular_velocity=Vector3.ZERO
	var target_transform:=target.global_transform
	await physics_frame; await process_frame
	target.global_transform=target_transform; target.force_update_transform()
	var native_expected:=state.inverse_inertia_tensor*arm.cross(cmd.apply_impulse_ns)
	check(native_expected.distance_to(first_spin)<.00001,"first torque equals native automatic inertia after tick")
	target.apply_impulse(cmd.apply_impulse_ns,arm)
	check(state.angular_velocity.distance_to(first_spin)<.00001,"first torque equals native warmed direct impulse")
	cleanup()
	# Recovery interruption uses the presently displayed skin, not frozen frames.
	setup(); await physics_frame; await process_frame
	dispatch(command("begin_point_impulse",Vector3.ZERO))
	driver.body.stop_preserve(); driver.mode="GETTING_UP"
	var skel: Skeleton3D=player._pose_skeleton
	skel.set_bone_pose_rotation(skel.find_bone("upperarm_l"),Quaternion(Vector3.FORWARD,.41))
	player._pose_motion.rotation.x=.13
	frames=driver.body.capture_world_frames(); epoch=player._pose_epoch
	var resumed:=command("resume_point_impulse",Vector3(.2,.4,.1))
	dispatch(resumed)
	assert_frames(frames,"GETUP displayed continuity")
	check(driver.mode=="FALLING" and player._pose_epoch==epoch,"GETUP keeps lease")
	check(momentum().distance_to(resumed.apply_impulse_ns)<.00001,"GETUP localized J once")
	var death:=command("apply_existing",Vector3.ZERO); death.final_dead=true
	dispatch(death)
	check(driver.impact_owner_state().dead and driver.impact_owner_state().recovery_suppressed,"death suppresses actual recovery")
	var alive:=command("apply_existing",Vector3.ZERO); alive.owner_before.dead=false
	check(not driver.preflight_impact(alive).ok,"same life death cannot clear")
	driver._elapsed=10; driver._stable=1; driver._recovery_stable=1
	driver.advance(0.0,true)
	check(driver.mode=="FALLING","dead advance never GETUP")
	var stale:=command("apply_existing"); player._pose_epoch+=1
	check(not driver.dispatch_impact(stale).ok,"changed pose lease rejects")
	check(not driver.fault_impact_owner("removed").ok,"removed host cannot fault replacement lease")
	player._pose_epoch-=1
	check(driver.fault_impact_owner("removed").ok and driver.mode=="FAULTED","same owner explicit host fault")
	check(player.collision_layer==0 and player.collision_mask==0,"host fault never enables walking")
	cleanup()
	# Observed begin inherits actual capsule velocity, never reported J again.
	setup(); await physics_frame; await process_frame
	PhysicsServer3D.body_set_state(player.get_rid(),PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,Vector3(.7,.2,-.3))
	var observed_begin:=command("begin_observed",Vector3(20,30,40))
	var observed_v: Vector3=observed_begin.physical_input.post_velocity
	dispatch(observed_begin)
	check(momentum().distance_to(observed_v*75.0)<.0001,"observed begin inherits actual capsule state without J")
	check(driver.body.body_rids().size()==16,"observed begin pool is actual physical owner")
	driver.body.stop_preserve(); driver.mode="GETTING_UP"
	player._pose_motion.rotation.z=-.11
	frames=driver.body.capture_world_frames()
	var observed_resume:=command("resume_observed",Vector3(30,40,50))
	dispatch(observed_resume)
	assert_frames(frames,"observed resume exact displayed frames")
	check(momentum().length()<.00001,"observed resume zero new momentum")
	var false_mode:=command("apply_existing"); driver.body.stop_preserve()
	check(not driver.preflight_impact(false_mode).ok,"reject paused pool posing as FALLING")
	cleanup()
	setup(); await physics_frame; await process_frame
	var freed:=command("begin_point_impulse"); player._pose_skeleton.free()
	check(not driver.preflight_impact(freed).ok,"freed rig rejects cleanly")
	cleanup()
	for fail_start in [true,false]:
		setup(); await physics_frame; await process_frame
		driver.body.dispose()
		var fault:=FaultBody.new(); fault.fail_start=fail_start
		check(fault.configure(player._pose_skeleton,world,{"total_mass_kg":75.0,"collision_layer":256,"collision_mask":257,"exceptions":[player]}).ok,"fault fixture actual pool")
		driver.body=fault
		var failing:=command("begin_point_impulse")
		var planned: Dictionary=driver.preflight_impact(failing)
		check(planned.ok,"failure branch preflight")
		failing.expected_pose_epoch=planned.pose_epoch; failing.expected_pose_owner=planned.pose_owner
		var receipt: Dictionary=driver.dispatch_impact(failing)
		check(not receipt.ok and receipt.irreversible,"partial failure explicit irreversible")
		check(player._pose_authority==&"physical_impact" and player.collision_mask==0,"no false lease/collision rollback")
		if fail_start:
			check(driver.mode=="FAULTED" and not receipt.may_have_applied and fault.impulse_calls==0,"failed start explicit fault with zero J")
		else:
			check(receipt.may_have_applied and receipt.applied_impulse_ns==null and fault.impulse_calls==1,"unknown actual application no retry")
			check(momentum().distance_to(failing.apply_impulse_ns)<.00001,"uncertain receipt retains actual force")
		cleanup()
	finish()
func finish() -> void:
	timings.sort()
	var result: Dictionary={"pass":errors.is_empty(),"checks":checks,"errors":errors,"dispatch_us":timings,"driver_sha256":FileAccess.get_sha256("res://scripts/character_physics/character_physics_driver.gd"),"body_sha256":FileAccess.get_sha256("res://scripts/character_physics/exit_ragdoll_body.gd"),"scope":"headless physical endpoint only; not source admission or LIVE FPS"}
	var file:=FileAccess.open("res://../../outputs/character_impact_endpoint/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
