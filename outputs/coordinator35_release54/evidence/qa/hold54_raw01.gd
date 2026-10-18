extends SceneTree
var game: Node3D
var sword: Node
var player: CharacterBody3D
var storage: Node
var weapon := "sword"
var button := MOUSE_BUTTON_RIGHT
var out := ""
var rows: Array = []
var errors: Array[String] = []
var photos: Array = []
var spectator: Camera3D

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="): weapon = arg.trim_prefix("--weapon=")
		if arg == "--left": button = MOUSE_BUTTON_LEFT
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func mouse(which: int, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which; event.pressed = down
	Input.parse_input_event(event)

func motion(value: Vector2) -> void:
	var event := InputEventMouseMotion.new(); event.relative = value
	Input.parse_input_event(event)

func key(code: int) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); await frames(2)
	event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); await frames(3)

func sample(stage: String) -> void:
	var head: Vector3 = sword._rig.global_transform * sword._rig.get_bone_global_pose(sword._bone_head).origin
	var chest: Vector3 = sword._rig.global_transform * sword._rig.get_bone_global_pose(sword._bone_chest).origin
	var pelvis: Vector3 = sword._rig.global_transform * sword._rig.get_bone_global_pose(sword._bone_pelvis).origin
	var rear: Vector3 = sword._sword.global_transform * Vector3(-sword.weapon_rear_extent(),0,0)
	var tip: Vector3 = sword._sword.global_transform * Vector3(sword._weapon_length+0.06,0,0)
	var clearance: float = minf(sword._segment_distance(rear,tip,chest,pelvis)-0.20,sword._segment_distance(rear,tip,head,head)-0.18)
	rows.append({"stage":stage,"held":sword._held,"blocking":sword._blocking,"side":str(sword._active_side()),"hand":sword._hand,"direction":sword._dir,"omega":sword._omega.length(),"grip":sword._grip_hand_error,"clearance":clearance,"can_damage":sword._swing_can_damage31(),"phase":sword._swing_phase,"coast":sword._sword_coasting31(),"hand_position":sword._palm_position(sword._active_side())})
	if not sword._dir.is_finite() or not sword._hand.is_finite(): errors.append(stage+"_nonfinite")
	if sword._grip_hand_error > 0.05: errors.append(stage+"_grip")
	if clearance < -0.001: errors.append(stage+"_self_penetration")

func photograph(stage: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := out.path_join(stage+".png")
	if root.get_texture().get_image().save_png(path) != OK: errors.append("screenshot")
	photos.append(path)

func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://scenes/castle.tscn").instantiate(); root.add_child(game); current_scene = game
	while game.get("preview_ready") != true: await process_frame
	await frames(180); game._castle_spawn_frames = 0
	player = game._player; storage = game.preview_castle.armory_storage
	var acquired: Dictionary = storage.acquire_or_select(weapon)
	if not acquired.get("ok",false): errors.append("equip")
	sword = game.preview_sword_prototype
	player.global_position = Vector3(0,.1,990); player.velocity = Vector3.ZERO
	player._camera_yaw = 0; player._camera_pitch = -.12; player._heading = 0; player._visual.rotation.y = PI
	player._update_camera_rotation(); player.set_mouse_captured(true); await frames(60)
	var before: float = player._camera_yaw; motion(Vector2(10,0)); await frames(1)
	var delivered: float = -wrapf(float(player._camera_yaw)-before,-PI,PI)/float(player.mouse_sensitivity)
	if absf(delivered-10)>.05: errors.append("mouse_not_1to1")
	motion(Vector2(-10,0)); await frames(3)
	if DisplayServer.get_name() != "headless":
		spectator = Camera3D.new(); game.add_child(spectator); spectator.global_position = player.global_position+Vector3(2.6,1.8,-3.1)
		spectator.look_at(player.global_position+Vector3(0,1,0)); spectator.current = true
	mouse(button,true)
	var max_omega := 0.0
	var active_frames := 0
	var blocking_frames := 0
	var strike_frames := 0
	var directions: Array[Vector3] = []
	# One uninterrupted hold through four deliberate directions and a still-hand pause.
	for phase in 5:
		var step: Vector2 = [Vector2(12,0),Vector2(-12,0),Vector2(0,-8),Vector2(0,8),Vector2.ZERO][phase]
		for tick in 30:
			if step != Vector2.ZERO: motion(step)
			await frames(1); sample("hold_"+str(phase))
			max_omega = maxf(max_omega,sword._omega.length())
			if sword._swing_can_damage31(): active_frames += 1
			if sword._blocking: blocking_frames += 1
			if sword._swing_phase == "strike": strike_frames += 1
			if not sword._held: errors.append("hold_lost")
			if sword._active_side() != (&"left" if button == MOUSE_BUTTON_LEFT else &"right"): errors.append("wrong_hand")
		directions.append(sword._dir)
		await photograph("hold_"+str(phase))
	if max_omega < 1.0: errors.append("no_free_swing")
	if blocking_frames != 0: errors.append("fixed_guard_instead_of_free_swing")
	if active_frames < 140 or strike_frames < 30: errors.append("hold_does_not_keep_strike_active")
	if directions[0].angle_to(directions[1]) < .2 or directions[2].angle_to(directions[3]) < .2: errors.append("direction_range")
	mouse(button,false); await frames(1); sample("released")
	await frames(90); sample("settled")
	if sword._held or sword._hold_left or sword._hold_right or sword._swing_can_damage31(): errors.append("release_stuck")
	# New hold after release must immediately regain the same physical steering.
	mouse(button,true); motion(Vector2(15,-5)); await frames(5); sample("reheld")
	if not sword._held or sword._blocking or not sword._swing_can_damage31(): errors.append("rehold")
	# UI cursor ownership cancels held buttons without depending on a later release.
	player.set_mouse_captured(false); await frames(5)
	if sword._held or sword._hold_left or sword._hold_right: errors.append("cursor_release_stuck")
	mouse(button,false); player.set_mouse_captured(true); await frames(10)
	# A real G/E transfer while RMB is held must not leave a phantom attack.
	mouse(button,true); await frames(4); await key(KEY_G); await frames(20)
	if storage._carried.has(weapon) or not sword._sword_grounded or sword._held: errors.append("held_drop")
	mouse(button,false); await key(KEY_E); await frames(20)
	if not storage._carried.has(weapon) or sword._sword_grounded: errors.append("pickup")
	var report := {"passed":errors.is_empty(),"weapon":weapon,"button":button,"errors":errors,"rows":rows,"max_omega":max_omega,"active_frames":active_frames,"strike_frames":strike_frames,"blocking_frames":blocking_frames,"photos":photos,"input_delivered":delivered,"scope":"Full merged castle, real engine input and 1:1 viewport. Continuous 150-tick hold, lateral/vertical movement, real grip/proxy clearance, release, rehold, cursor cancellation and native G/E. No injected damage; separate contact matrix covers actual target hits."}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HOLD54 ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"weapon":weapon,"button":button}))
	quit(0 if errors.is_empty() else 2)
