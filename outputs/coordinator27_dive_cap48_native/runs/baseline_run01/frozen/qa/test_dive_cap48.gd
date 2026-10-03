extends SceneTree
## Observe the genuine accepted48 player/input/physics path. No jump-state writes.
var world: Node3D
var player: CharacterBody3D
var sampler: GDScript
var out := ""
var variant := ""
var done := false
var checks := 0
var errors: Array[String] = []
var input_blocked: Array[String] = []
var cases: Array[Dictionary] = []
var active := false
var before: Dictionary = {}
var ticks: Array[Dictionary] = []
var initial_identity: Dictionary = {}
var setup_position := Vector3.ZERO

class Tap extends Node:
	var harness
	var before_player := false
	func _physics_process(delta: float) -> void:
		if before_player: harness.before_physics(delta)
		else: harness.after_physics(delta)

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
		print("QA_FAIL ", label)

func tick(count: int = 1) -> void:
	for i in count:
		await physics_frame
		await process_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func identity() -> Dictionary:
	var capsule: CollisionShape3D = player.get_node("PlayerCapsule")
	var shape: CapsuleShape3D = capsule.shape
	return {"actor":player.get_instance_id(), "body_rid":str(player.get_rid()),
		"world_rid":str(player.get_world_3d().space), "capsule":capsule.get_instance_id(),
		"shape":shape.get_instance_id(), "height":shape.height, "radius":shape.radius,
		"local_transform":str(capsule.transform), "disabled":capsule.disabled,
		"layer":player.collision_layer, "mask":player.collision_mask,
		"authority":str(player.get("_pose_authority")), "epoch":player.get("_pose_epoch"),
		"permission_shape":player.get("_jump_permission_shape").get_instance_id(),
		"permission_radius":player.get("_jump_permission_shape").radius,
		"permission_height":player.get("_jump_permission_shape").height,
		"permission_mask":player.get("_jump_query").collision_mask}

func horizontal(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

func before_physics(delta: float) -> void:
	before = {}
	if not active: return
	var state: Dictionary = player.get("_jump").duplicate(true)
	if state.is_empty(): return
	var steps: PackedFloat64Array = sampler.frame_steps(delta, true)
	# Ordinary 60Hz native physics is one proposal/move here. Preserve evidence
	# and reject a different fixture schedule instead of claiming summed receipts.
	if steps.size() != 1:
		input_blocked.append("Expected one source substep per observed native tick")
		return
	var proposal: Dictionary = sampler.cinematic_proposal(state, steps[0])
	before = {"frame":Engine.get_physics_frames(), "delta":delta,
		"wall_ms":Time.get_ticks_msec(), "state":state,
		"position":player.global_position, "proposal":proposal}

func after_physics(_delta: float) -> void:
	if before.is_empty(): return
	var state: Dictionary = before.state
	var after_state: Dictionary = player.get("_jump").duplicate(true)
	var pose: Dictionary = player.get("_jump_pose").duplicate(true)
	var displacement: Vector3 = player.global_position - before.position
	var contacts: Array[Dictionary] = []
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		contacts.append({"collider_id":c.get_collider_id(), "normal":c.get_normal(), "position":c.get_position()})
	ticks.append({"frame":before.frame, "delta":before.delta, "wall_ms":before.wall_ms,
		"before_elapsed":state.elapsed, "after_elapsed":pose.get("elapsed", -1.0),
		"before_mode":state.mode, "profile":state.get("profile", ""),
		"source_proposal_for_observed_pre_state":before.proposal,
		"displacement":displacement, "horizontal_displacement":horizontal(displacement),
		"position":player.global_position, "native_position_delta":player.get_position_delta(),
		"native_last_motion":player.get_last_motion(), "native_real_velocity":player.get_real_velocity(),
		"is_on_floor":player.is_on_floor(), "is_on_ceiling":player.is_on_ceiling(),
		"contacts":contacts, "pose":pose, "jump_empty":after_state.is_empty(),
		"identity_unchanged":identity()==initial_identity})
	before = {}

func choose_existing_clear_floor() -> bool:
	var original := player.global_position
	var yaw: float = player.get("_camera_yaw")
	var direction := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var space := player.get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.ZERO, Vector3(8,0,0), Vector3(-8,0,0), Vector3(0,0,8), Vector3(16,0,0), Vector3(-16,0,0)]:
		var origin := original + offset
		var floor_query := PhysicsRayQueryParameters3D.create(origin+Vector3.UP*4.0, origin-Vector3.UP*4.0, 1, [player.get_rid()])
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty(): continue
		origin.y = floor_hit.position.y + 0.02
		var clear := true
		for i in 13:
			var foot := origin + direction * float(i) * 0.5
			if not world.preview_jump_surface_allowed(foot, 0.36): clear=false; break
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = player.get("_jump_permission_shape")
			query.collision_mask = 1
			query.exclude = [player.get_rid()]
			query.margin = 0.001
			for y: float in [0.0, 1.05]:
				query.transform = Transform3D(Basis.IDENTITY, foot+Vector3.UP*(0.95+y))
				if not space.intersect_shape(query, 1).is_empty(): clear=false; break
			if not clear: break
		if clear:
			setup_position = origin
			return true
	return false

func run_case(label: String, target_elapsed: float) -> void:
	key(KEY_W, false)
	key(KEY_SPACE, false)
	check(player.get("_jump").is_empty(), label+": previous jump cleared")
	# Sole explicit placement for this case, before all input/observations.
	player.global_position = setup_position
	await tick(20)
	if not player.is_on_floor() or not player.get("_jump").is_empty():
		input_blocked.append(label+": setup not grounded/idle")
		return
	initial_identity = identity()
	check(is_equal_approx(float(initial_identity.height),1.9) and is_equal_approx(float(initial_identity.radius),0.30), label+": actual full capsule")
	check(initial_identity.authority=="on_foot" and not initial_identity.disabled, label+": current authority")
	ticks.clear()
	active = true
	var start := player.global_position
	key(KEY_W, true)
	key(KEY_SPACE, true)
	var first: Dictionary = player.get("_jump").duplicate(true)
	key(KEY_SPACE, false)
	# Jump direction is latched; release movement before later ground recovery.
	key(KEY_W, false)
	if first.is_empty() or first.get("mode", "") != "normal":
		input_blocked.append(label+": first real Space did not start normal jump")
		active=false
		return
	var second_before: Dictionary = {}
	var second_after: Dictionary = {}
	var age := -1.0
	if target_elapsed >= 0.0:
		while not player.get("_jump").is_empty() and float(player.get("_jump").elapsed) < target_elapsed:
			await tick()
		second_before = player.get("_jump").duplicate(true)
		if second_before.is_empty():
			input_blocked.append(label+": jump ended before second input")
			active=false
			return
		age = float(Time.get_ticks_msec())-float(second_before.startedAt)
		var reachable: bool = age>=0.0 and age<=500.0 and float(second_before.elapsed)<0.8 and second_before.mode=="normal" and not second_before.falling and not second_before.ceilingHit and not second_before.done
		if (target_elapsed<0.5 and not reachable) or (target_elapsed>0.5 and age<=500.0):
			input_blocked.append(label+": actual wall/input timing outside case; age="+str(age))
		key(KEY_SPACE, true)
		second_after = player.get("_jump").duplicate(true)
		key(KEY_SPACE, false)
		check(second_after.mode==("dive" if target_elapsed<0.5 else "normal"), label+": genuine second-input reachability")
	var deadline := Time.get_ticks_msec()+6000
	while not player.get("_jump").is_empty() and Time.get_ticks_msec()<deadline:
		await tick()
	active = false
	check(player.get("_jump").is_empty(), label+": contact/recovery completed")
	check(not ticks.is_empty(), label+": observed native physics")
	var own_total := 0.0
	var actual_path := 0.0
	var after_cap_count := 0
	var after_cap_max := 0.0
	var first_contact := -1.0
	var completion := -1.0
	var last_position := start
	for row: Dictionary in ticks:
		check(row.identity_unchanged, label+": body/shape/owner unchanged frame"+str(row.frame))
		var proposal: Dictionary = row.source_proposal_for_observed_pre_state
		own_total += float(proposal.travel)
		actual_path += float(row.horizontal_displacement)
		last_position = row.position
		if float(row.before_elapsed)>=0.8 and row.before_mode=="dive":
			after_cap_count += 1
			after_cap_max = maxf(after_cap_max,absf(float(proposal.travel)))
		var pose: Dictionary = row.pose
		if float(pose.get("contact_elapsed",-1.0))>=0.0 and first_contact<0.0:
			first_contact=float(pose.contact_elapsed)
			check(row.is_on_floor,label+": first cinematic contact is native floor")
		if bool(pose.get("done",false)): completion=float(pose.elapsed)
	var positive := target_elapsed>=0.0 and target_elapsed<0.5
	var observed_t := float(second_before.get("elapsed",0.0))
	var expected := (3.36 if variant=="candidate" else 5.25)-0.7*observed_t if positive else 2.8
	check(absf(own_total-expected)<0.0001, label+": source own-travel total")
	check(horizontal(last_position-start)<=own_total+0.01, label+": real endpoint bounded by own proposal")
	check(actual_path<=own_total+0.01, label+": summed native path bounded")
	check(completion>=1.25-0.0001,label+": clock completion not shortened")
	if positive:
		check(after_cap_count>0,label+": observed post .8 flight")
		check(first_contact>=0.0 and completion-first_contact>=0.45-0.0001,label+": actual contact then recovery .45")
		if variant=="candidate": check(after_cap_max<=0.0000001,label+": own travel zero after .8")
		else: check(after_cap_max>0.0,label+": baseline old travel negative canary")
	var summary := {"label":label,"setup_position":setup_position,"launch_position":start,
		"first_input_state":first,"second_before":second_before,"second_after":second_after,
		"second_wall_age_ms":age,"observed_upgrade_elapsed":observed_t,"own_proposal_total_m":own_total,
		"expected_proposal_m":expected,"native_endpoint_m":horizontal(last_position-start),
		"native_path_m":actual_path,"post_08_proposal_samples":after_cap_count,"post_08_proposal_max":after_cap_max,
		"contact_elapsed":first_contact,"completion_elapsed":completion,"identity":initial_identity,"ticks":ticks.duplicate(true)}
	cases.append(summary)
	print("DIVE_CASE ",JSON.stringify({"label":label,"own":own_total,"endpoint":summary.native_endpoint_m,"wall_age":age,"contact":first_contact,"completion":completion}))
	await tick(3)

func finish() -> void:
	if done: return
	done=true
	active=false
	key(KEY_W,false)
	key(KEY_SPACE,false)
	var result := {"schema":"dive-cap48.actual-player-input/v1","variant":variant,
		"passed":errors.is_empty() and input_blocked.is_empty() and cases.size()==4,"checks":checks,
		"errors":errors,"input_blocked":input_blocked,"cases":cases,
		"performance_accepted":false,"scope":"Real Main/player/hero/capsule; genuine synthetic key events, natural physics; one setup placement per case. Source-linked own proposal from observed pre-state; native receipts are last move, per-tick displacements measured independently. No rotated-volume39/return41/weapon IK/visual/FPS acceptance."}
	var file := FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("DIVE_CAP48_RESULT ",JSON.stringify({"passed":result.passed,"checks":checks,"errors":errors,"input_blocked":input_blocked}))
	quit(0 if result.passed else 2)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out=arg.trim_prefix("--out=")
		if arg.begins_with("--variant="): variant=arg.trim_prefix("--variant=")
	if out.is_empty() or variant not in ["baseline","candidate"]: quit(3); return
	create_timer(85.0).timeout.connect(func(): input_blocked.append("fixture watchdog"); finish())
	sampler=load("res://scripts/preview_dive.gd")
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	while not bool(world.get("preview_ready")): await tick()
	player=world.get("_player")
	if player==null or player.get("_dive")==null:
		input_blocked.append("actual hero dive sampler not bound"); finish(); return
	check(bool(player.get("_dive").get_status().ready),"actual hero sampler ready")
	await tick(30)
	if not choose_existing_clear_floor(): input_blocked.append("no actual clear floor path"); finish(); return
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=Vector2(root.size)*0.5
	click.pressed=true
	root.push_input(click,true)
	click=click.duplicate()
	click.pressed=false
	root.push_input(click,true)
	await tick()
	if not bool(player.get("_free_mouse_look")): input_blocked.append("LMB capture not delivered"); finish(); return
	var pre := Tap.new()
	pre.harness=self
	pre.before_player=true
	pre.process_physics_priority=-1000
	world.add_child(pre)
	var post := Tap.new()
	post.harness=self
	post.process_physics_priority=1000
	world.add_child(post)
	await run_case("normal_control",-1.0)
	await run_case("double_early",0.0)
	await run_case("double_mid",0.4)
	await run_case("late_rejected",0.79)
	finish()
