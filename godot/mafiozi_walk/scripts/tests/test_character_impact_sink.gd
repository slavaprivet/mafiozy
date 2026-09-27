extends SceneTree
const Sink = preload("res://scripts/character_physics/character_impact_sink.gd")
const Rag = preload("res://scripts/character_physics/exit_ragdoll_body.gd")
const Player = preload("res://scripts/preview_player.gd")
const PROFILE := {"mass_kg":75.0,"max_impulse_ns":10000.0,"stance_thresholds_mps":{"standing":1.0,"crouched":1.2,"prone":2.0,"airborne":.5,"seated":1.0}}
const IDENTITY := {"actor_id":"test-actor","life_generation":3,"session_id":"test-local-session","session_generation":2}
class PresentationNode extends Node:
	func decorate(_delta: float, base: Dictionary) -> Dictionary: return base
var checks := 0
var errors: Array[String] = []
var owner := {}
var admissions := {}
var sink: RefCounted
var dispatches := 0
var presentations := 0
var clears := 0
var deny_local := false
var reenter := false
var reentry_result := {}
var change_epoch := false
var dispatch_fail := false
var bad_receipt := false
var bad_decorate := false
var commit_fault := ""
var replacement_rid: RID
var native := false
var rag: RefCounted
var native_frames := {}
var last_command := {}
var report := {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
func current_owner() -> Dictionary: return owner
func resolve_admitted(handle: Variant) -> Dictionary:
	return admissions.get(handle,{"ok":false}).duplicate(true)
func clear_local(_epoch: int) -> void: clears += 1
func decorate_local(_delta: float, base: Dictionary) -> Dictionary:
	presentations += 1
	if bad_decorate: base.visual_offset = Vector3(100,0,0)
	return base
func preflight(route: String, command: Dictionary) -> Dictionary:
	if reenter:
		reentry_result = sink.submit("reentrant",physical(Vector3.ONE))
		sink.dispose()
	if change_epoch: owner.pose_epoch += 1
	if route == "local" and deny_local: return {"ok":false,"error":"unsupported_leg_contact"}
	var epoch: int = owner.pose_epoch
	var authority: String = owner.pose_owner
	if route == "physical" and command.action not in ["apply_existing","observe_existing"]:
		epoch += 1; authority = "physical"
	return {"ok":true,"pose_epoch":epoch,"pose_owner":authority}
func isolate_native() -> void:
	for row: Dictionary in rag._joints:
		for axis in 3:
			PhysicsServer3D.generic_6dof_joint_set_flag(row.node.get_rid(),axis,PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT,false)
			PhysicsServer3D.generic_6dof_joint_set_flag(row.node.get_rid(),axis,PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT,false)
	for body: RigidBody3D in rag.owned_bodies():
		body.collision_layer = 0; body.collision_mask = 0; body.gravity_scale = 0
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; body.linear_damp = 0
		body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; body.angular_damp = 0
func dispatch(route: String, command: Dictionary) -> Dictionary:
	dispatches += 1; last_command = command
	if route == "physical":
		if native:
			if command.action == "begin_point_impulse":
				var started: Dictionary = rag.start(native_frames,Vector3.ZERO)
				if not started.ok: return {"ok":false}
				isolate_native()
			if command.apply_impulse_ns != Vector3.ZERO:
				var applied: Dictionary = rag.apply_impulse(command.admitted.world_point,command.apply_impulse_ns,command.event_key)
				if not applied.ok: return {"ok":false}
		owner.driver_mode = "FALLING"
		owner.pose_epoch = command.expected_pose_epoch; owner.pose_owner = command.expected_pose_owner
		if command.final_dead:
			if commit_fault != "ignore_death": owner.dead = true
			owner.recovery_suppressed = true
			if commit_fault == "recovery_false": owner.recovery_suppressed = false
			elif commit_fault == "recovery_missing": owner.erase("recovery_suppressed")
			elif commit_fault == "recovery_wrong_type": owner.recovery_suppressed = 1
		if commit_fault == "resurrect": owner.dead = false
		if commit_fault == "swap_pool": owner.physical_body_rids = [replacement_rid]
	if dispatch_fail: return {"ok":false}
	return {"ok":true,"event_key":command.event_key,"pose_epoch":owner.pose_epoch,"applied_impulse_ns":Vector3.ONE if bad_receipt else command.apply_impulse_ns}
func reset_fixture() -> void:
	if sink != null: sink.dispose()
	owner = IDENTITY.duplicate()
	owner.merge({"pose_epoch":4,"pose_owner":"on_foot","stance":"standing","driver_mode":"IDLE","transport_state":"none","transport_token":"","physics_tick":100,"geometry_revision":7,"dead":false,"recovery_suppressed":false,"mass_kg":75.0,"physical_body_rids":[]})
	admissions.clear(); dispatches = 0; presentations = 0; clears = 0
	deny_local = false; reenter = false; change_epoch = false; dispatch_fail = false; bad_receipt = false; bad_decorate = false; native = false
	commit_fault = ""
	sink = Sink.new()
	var configured: Dictionary = sink.configure(IDENTITY,PROFILE,{"current_owner":current_owner,"resolve_admitted":resolve_admitted,"preflight":preflight,"dispatch":dispatch,"decorate_local":decorate_local,"clear_local":clear_local})
	check(configured.ok,"configure exact current owner")
func admit(id: String, point: Vector3 = Vector3.ZERO) -> void:
	var value := IDENTITY.duplicate()
	value.merge({"ok":true,"pose_epoch":owner.pose_epoch,"geometry_revision":owner.geometry_revision,"producer_id":"fixture-provider","event_id":id,"kind":"bullet","world_point":point,"final_dead":false,"authoritative_knockdown":false})
	admissions[id] = value
func physical(impulse: Vector3, point: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"delivery":"command_unapplied","world_point":point,"impulse_ns":impulse,"physics_tick":owner.physics_tick,"force_profile_id":"EXPLICIT_TEST_ONLY_FORCE"}
func send(id: String, impulse: Vector3 = Vector3.ONE) -> Dictionary:
	admit(id)
	return sink.submit(id,physical(impulse))
func contract_tests() -> void:
	reset_fixture()
	check(sink.submit("missing",physical(Vector3.ONE)).error == "source_admission","missing source admission denied")
	check(send("weak").status == "local_presented" and dispatches == 1,"weak hit one local endpoint")
	check(sink.submit("weak",physical(Vector3.ONE)).error == "duplicate_event" and dispatches == 1,"duplicate cannot dispatch again")
	check(last_command.apply_impulse_ns == Vector3.ZERO,"local presentation cannot claim body impulse")
	var base := {"valid":true,"poses":[],"visual_offset":Vector3.ZERO,"visual_rotation":Quaternion.IDENTITY,"authority_epoch":owner.pose_epoch}
	check(sink.decorate_selected(.016,base) == base and presentations == 1,"existing pose metadata preserved")
	var float_epoch := base.duplicate(); float_epoch.authority_epoch = float(owner.pose_epoch)
	check(not sink.decorate_selected(.016,float_epoch).get("valid",false),"pose epoch exact integer type")
	bad_decorate = true
	check(not sink.decorate_selected(.016,base).get("valid",false),"presentation port cannot move root")
	bad_decorate = false
	owner.pose_epoch += 1
	check(sink.submit("weak",physical(Vector3.ONE)).error == "stale_admission","old pose admission rejected")
	admit("weak")
	check(sink.submit("weak",physical(Vector3.ONE)).error == "duplicate_event","same life pose reset does not reset dedup")
	for field: String in ["actor_id","session_id","life_generation","session_generation"]:
		reset_fixture(); admit("stale")
		if field in ["actor_id","session_id"]: owner[field] = "other"
		else: owner[field] += 1
		check(sink.submit("stale",physical(Vector3.ONE)).error == "current_owner" and dispatches == 0,"stale current "+field)
	reset_fixture(); admit("wrong_source"); admissions.wrong_source.life_generation = 2
	check(sink.submit("wrong_source",physical(Vector3.ONE)).error == "stale_admission","source life rejected")
	admit("wrong_geometry"); admissions.wrong_geometry.geometry_revision = 99
	check(sink.submit("wrong_geometry",physical(Vector3.ONE)).error == "stale_admission","changed skin geometry rejected")
	admit("point_changed"); admissions.point_changed.world_point = Vector3.UP
	check(sink.submit("point_changed",physical(Vector3.ONE)).error == "contact_changed","no invented center contact")
	admit("bad_impulse"); var invalid := physical(Vector3(NAN,0,0))
	check(sink.submit("bad_impulse",invalid).error == "impulse","NaN rejected")
	check(sink.submit("bad_impulse",physical(Vector3.ONE)).ok,"invalid input does not poison event")
	admit("stale_tick"); invalid = physical(Vector3.ONE); invalid.physics_tick -= 1
	check(sink.submit("stale_tick",invalid).error == "physical_sample","stale force sample rejected")
	reset_fixture(); deny_local = true
	check(send("leg").error == "unsupported_route" and dispatches == 0 and sink.state().remembered_events == 0,"unsupported local leg route fails before consumption")
	deny_local = false
	check(sink.submit("leg",physical(Vector3.ONE)).status == "local_presented","owner can resolve admitted supported route without new ID")
	reset_fixture(); reenter = true
	check(send("outer").ok and reentry_result.error == "reentry_or_thread" and dispatches == 1 and not sink.state().disposed,"reentry including dispose blocked")
	reset_fixture(); change_epoch = true
	check(send("changed").status == "rejected" and dispatches == 0 and sink.state().remembered_events == 0,"owner swap inside preflight denied")
	reset_fixture(); dispatch_fail = true
	var failed := send("once")
	check(failed.status == "consumed_failed" and failed.may_have_applied and failed.physical_applied == null and failed.applied_impulse_ns == null,"failed endpoint remains uncertain terminal receipt")
	dispatch_fail = false
	check(sink.submit("once",physical(Vector3.ONE)).error == "duplicate_event" and dispatches == 1,"failed endpoint never automatically retried")
	reset_fixture(); bad_receipt = true
	check(send("false_write").status == "consumed_failed","lying applied-impulse receipt rejected")
	for transport: String in ["seated","transition"]:
		reset_fixture(); owner.transport_state = transport; owner.transport_token = "lease-1"
		check(send("seat",Vector3(100,0,0)).status == "owner_deferred" and dispatches == 0 and sink.state().remembered_events == 0,"transport owner keeps "+transport)
	reset_fixture(); owner.transport_state = "exit_physical"; owner.transport_token = "lease-2"; owner.driver_mode = "FALLING"; owner.pose_owner = "vehicle"
	check(send("exit_hit").status == "physical_applied" and last_command.action == "apply_existing","existing transport physical owner retained")
	reset_fixture(); owner.driver_mode = "GETTING_UP"; owner.pose_owner = "physical"
	check(send("recover_hit").status == "physical_applied" and last_command.action == "resume_point_impulse","getup resumes through one owner transaction")
	reset_fixture(); check(send("blocked_blast",Vector3.ZERO).status == "no_reaction" and dispatches == 0,"zero impulse produces no endpoint")
	check(sink.submit("blocked_blast",physical(Vector3(100,0,0))).error == "duplicate_event","zero event cannot replay as positive blast")
	reset_fixture(); admit("death"); admissions.death.final_dead = true
	check(sink.submit("death",physical(Vector3.ZERO)).status == "physical_started" and owner.dead and last_command.final_dead,"source final death requests physical ownership without invented J")
	owner.driver_mode = "FAULTED"
	check(send("fault").error == "physical_owner_unavailable","faulted owner not revived")
	reset_fixture()
	for i in 65: check(send("bounded-"+str(i),Vector3.ZERO).ok,"bounded accepted zero event")
	check(sink.state().remembered_events == 64,"bounded receipt history")
	check(sink.submit("bounded-0",physical(Vector3.ZERO)).ok,"evicted replay explicitly not durable protection")
	sink.dispose()
	check(sink.submit("late",{}).error == "lifetime","disposed rejects")
	check(sink.state().remembered_events == 0,"dispose releases history")
	reset_fixture()
	var ephemeral := PresentationNode.new()
	sink._ports.decorate_local = Callable(ephemeral,"decorate")
	ephemeral.free()
	check(send("freed_port").error == "lifetime" and dispatches == 0,"freed callable owner fails closed without script error")
func momentum() -> Vector3:
	var result := Vector3.ZERO
	for body: RigidBody3D in rag.owned_bodies(): result += body.linear_velocity*body.mass
	return result
func postcommit_tests() -> void:
	var original := PhysicsServer3D.body_create()
	replacement_rid = PhysicsServer3D.body_create()
	for observed: bool in [false,true]:
		reset_fixture(); owner.driver_mode = "FALLING"; owner.pose_owner = "physical"; owner.physical_body_rids = [original]
		commit_fault = "swap_pool"; admit("swapped")
		var input := physical(Vector3.ONE)
		if observed: input.merge({"delivery":"solver_observed","solver_body_rid":original,"post_velocity":Vector3.ZERO,"post_angular_velocity":Vector3.ZERO,"velocity_reference":Vector3.ZERO},true)
		var result: Dictionary = sink.submit("swapped",input)
		check(result.status == "consumed_failed" and result.consumed and result.may_have_applied and result.physical_applied == null and result.applied_impulse_ns == null,"existing body swap has terminal uncertain outcome "+str(observed))
		owner.physical_body_rids = [original]
		check(sink.submit("swapped",input).error == "duplicate_event" and dispatches == 1,"pool failure never repeats point impulse "+str(observed))
	for fault: String in ["resurrect","ignore_death","recovery_false","recovery_missing","recovery_wrong_type"]:
		reset_fixture(); commit_fault = fault
		owner.driver_mode = "FALLING"; owner.pose_owner = "physical"; owner.physical_body_rids = [original]
		if fault == "resurrect": owner.dead = true; owner.recovery_suppressed = true
		admit("death-commit"); admissions["death-commit"].final_dead = true
		var result: Dictionary = sink.submit("death-commit",physical(Vector3.ZERO))
		check(result.status == "consumed_failed" and result.consumed and result.may_have_applied and result.physical_applied == null and result.applied_impulse_ns == null,"death/recovery commit rejected "+fault)
		check(sink.state().requires_dead,"definitive death remains monotonic "+fault)
		owner.dead = false; owner.recovery_suppressed = false
		admit("new-event-after-bad-death")
		check(sink.submit("new-event-after-bad-death",physical(Vector3.ONE)).error == "current_owner" and dispatches == 1,"new event cannot revive same life "+fault)
		owner.dead = true; owner.recovery_suppressed = true
		check(sink.submit("death-commit",physical(Vector3.ZERO)).error == "duplicate_event" and dispatches == 1,"reconciled owner does not retry consumed death "+fault)
	reset_fixture(); owner.driver_mode = "FALLING"; owner.pose_owner = "physical"; owner.dead = true; owner.recovery_suppressed = true; owner.physical_body_rids = [original]
	check(send("valid-corpse-hit").status == "physical_applied" and owner.dead and owner.recovery_suppressed,"valid existing corpse keeps death and suppressed recovery")
	sink.dispose(); PhysicsServer3D.free_rid(original); PhysicsServer3D.free_rid(replacement_rid)
func native_tests() -> void:
	reset_fixture(); native = true
	var world := Node3D.new(); root.add_child(world)
	var player: CharacterBody3D = Player.new(); world.add_child(player)
	player.set_physics_process(false); player.collision_layer = 0; player.collision_mask = 0
	rag = Rag.new(); check(rag.configure(player._pose_skeleton,world).ok,"actual body configure")
	native_frames = rag.capture_world_frames(); owner.physical_body_rids = rag.body_rids()
	var point: Vector3 = rag._rest_body.head.origin+Vector3(.085,.012,.003)
	admit("native-first",point)
	var impulse := Vector3(90,3,-1)
	var began := Time.get_ticks_usec()
	var initial: Dictionary = sink.submit("native-first",physical(impulse,point))
	var first_us := Time.get_ticks_usec()-began
	check(initial.status == "physical_applied" and last_command.action == "begin_point_impulse","actual body one point-J start")
	await physics_frame; await process_frame; await physics_frame; await process_frame
	var first_error := momentum().distance_to(impulse)
	check(first_error < .0001,"native start does not add J/M and point J twice")
	point = rag._bodies.head.global_position+Vector3(.085,.012,.003)
	admit("native-second",point)
	var before := momentum(); var second := Vector3(2,3,-1)
	began = Time.get_ticks_usec()
	var second_result: Dictionary = sink.submit("native-second",physical(second,point))
	var second_us := Time.get_ticks_usec()-began
	check(second_result.status == "physical_applied" and last_command.action == "apply_existing","already falling weak event uses one current body")
	await physics_frame; await process_frame; await physics_frame; await process_frame
	var second_error := (momentum()-before).distance_to(second)
	check(second_error < .0001,"second native impulse not multiplied")
	# Native physical impulse represents an already committed solver observation.
	point = rag._bodies.head.global_position
	check(rag.apply_impulse(point,Vector3(1,2,0)).ok,"fixture applies physical observed contact once")
	await physics_frame; await process_frame; await physics_frame; await process_frame
	before = momentum(); admit("native-observed",point)
	var observed := physical(Vector3(1,2,0),point)
	observed.delivery = "solver_observed"; observed.solver_body_rid = rag._bodies.head.get_rid()
	observed.post_velocity = rag._bodies.head.linear_velocity; observed.post_angular_velocity = rag._bodies.head.angular_velocity; observed.velocity_reference = rag._bodies.head.global_position
	began = Time.get_ticks_usec()
	var observed_result: Dictionary = sink.submit("native-observed",observed)
	var observed_us := Time.get_ticks_usec()-began
	check(observed_result.status == "observed_only" and last_command.apply_impulse_ns == Vector3.ZERO,"solver observation dispatch requests zero new impulse")
	await physics_frame; await process_frame; await physics_frame; await process_frame
	var observed_error := momentum().distance_to(before)
	check(observed_error < .0001,"solver observation adds no native momentum")
	check(sink.submit("native-observed",observed).error == "duplicate_event","observed duplicate rejected")
	admit("unknown-solver",point); observed.solver_body_rid = RID()
	check(sink.submit("unknown-solver",observed).error == "solver_owner","foreign solver body denied")
	report.native_momentum_error_ns = {"first":first_error,"second":second_error,"observed_additional":observed_error,"scope":"Real 16-body rig with contacts/joints/gravity/damping disabled only in test to isolate conservation; transaction owner is a test stub, not source gameplay admission."}
	report.native_dispatch_us_single_samples = {"begin_point_impulse":first_us,"apply_existing":second_us,"observe_existing":observed_us}
	sink.dispose(); rag.dispose(); world.free(); native = false
func run() -> void:
	var hash := FileAccess.get_sha256("res://scripts/character_physics/character_impact_sink.gd")
	var dependencies := {}
	for path: String in ["res://scripts/character_physics/character_impact_policy.gd","res://scripts/character_physics/exit_ragdoll_body.gd"]: dependencies[path] = FileAccess.get_sha256(path)
	contract_tests()
	postcommit_tests()
	await native_tests()
	reset_fixture(); var costs: Array[int] = []
	for i in 1000:
		admit("cost-"+str(i)); var began := Time.get_ticks_usec()
		var result: Dictionary = sink.submit("cost-"+str(i),physical(Vector3.ONE))
		costs.append(Time.get_ticks_usec()-began); check(result.ok,"cost dispatch valid")
	costs.sort(); sink.dispose()
	check(hash == FileAccess.get_sha256("res://scripts/character_physics/character_impact_sink.gd"),"sink immutable during suite")
	for path: String in dependencies: check(dependencies[path] == FileAccess.get_sha256(path),"dependency immutable: "+path)
	report.dependency_sha256 = dependencies
	report.merge({"checks":checks,"passed":errors.is_empty(),"errors":errors,"module_sha256":hash,"local_dispatch_us":{"p50":costs[500],"p95":costs[950],"max":costs[-1]},"limits":"Headless module/port-stub cost, not production source authority, renderer or full-scene FPS. Source combat producers remain unwired."})
	var out := FileAccess.open("../../outputs/character_impact_sink_test.json",FileAccess.WRITE); out.store_string(JSON.stringify(report,"\t")); out.close()
	print("CHARACTER_IMPACT_SINK ",JSON.stringify(report)); quit(0 if errors.is_empty() else 1)
