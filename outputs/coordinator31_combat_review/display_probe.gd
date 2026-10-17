extends SceneTree

var display_samples: Array = []
var telemetry = load(get_script().resource_path.get_base_dir().path_join("qa31/pose_telemetry.gd"))

var scene: Node
var player: Node
var sword: Node
var samples: Array = []
var out_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--combat-out="): out_dir = arg.trim_prefix("--combat-out=")
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if is_instance_valid(player): player.set_mouse_captured(true)
	return false

func _frames(n: int) -> void:
	for i in n: await physics_frame

func _hands(left: bool, right: bool) -> void:
	# Engine button polling does not reflect injected events; use the existing
	# diagnostic switch for button state, and the real input path for mouse motion.
	sword.set("_synthetic_hands", true)
	sword.set("_hold_left", left)
	sword.set("_hold_right", right)
	sword.set("_held_event", left)
	sword.set("_held", left or right)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))

func _run() -> void:
	scene = load("res://scenes/castle.tscn").instantiate()
	scene.set("preview_residents_enabled", false)
	# No city simulation is requested in this isolated castle combat fixture.
	# An empty registry object avoids the legacy missing-meta diagnostic.
	scene.set_meta("npc_home_registry58", RefCounted.new())
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 180000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	player = scene.get("_player")
	sword = scene.get("preview_sword_prototype")
	if scene.get("preview_ready") != true or sword == null:
		push_error("COMBAT_PROBE: scene not ready"); quit(1); return
	player.set_mouse_captured(true)
	scene.get("preview_weapons").equip("sword")
	await _frames(60)
	await _shot("ready")
	var initial_yaw: float = player.get("_camera_yaw")
	var initial_pitch: float = player.get("_camera_pitch")
	for grip in ["one", "two"]:
		_hands(false, false)
		# Controlled camera reset makes both grip sequences start from the same view.
		player.set("_camera_yaw", initial_yaw)
		player.set("_camera_pitch", initial_pitch)
		player._update_camera_rotation()
		await _frames(90)
		_hands(true, grip == "two")
		for tick in 420:
			var dx := 0.0
			var dy := 0.0
			if tick < 30: dx = 3.0
			elif tick < 60: dx = -3.0
			elif tick < 80: dx = 24.0
			elif tick < 100: dx = -24.0
			elif tick < 120: dx = 24.0
			elif tick >= 240 and tick < 270: dy = -18.0
			elif tick >= 270 and tick < 300: dy = 18.0
			elif tick >= 300 and tick < 330: dx = -18.0; dy = -18.0
			elif tick >= 330 and tick < 360: dx = 18.0; dy = 18.0
			if dx != 0.0 or dy != 0.0:
				var motion := InputEventMouseMotion.new()
				motion.relative = Vector2(dx, dy)
				Input.parse_input_event(motion)
			await physics_frame
			await RenderingServer.frame_post_draw
			display_samples.append(telemetry.sample(sword))
			var snap: Dictionary = sword.snapshot()
			samples.append({"grip": grip, "tick": tick, "dx": dx, "omega": snap.omega,
				"dir": snap.direction, "active": snap.weapon_active, "selected": snap.selected,
				"hand": snap.hand, "camera_yaw": player.get("_camera_yaw"),
				"blocks": snap.blocks, "hits": snap.hits, "grip_error": snap.grip_hand_error,
				"blade_in_world": snap.blade_in_world, "dummy_hp": snap.dummy_hp,
				"head_clearance": snap.head_clearance, "body_clearance": snap.body_clearance,
				"support_error": snap.left_hand_error, "body_pitch": snap.body_pitch,
				"body_roll": snap.body_roll})
			if tick in [60, 78, 98, 118, 220, 268, 298, 328, 358]: await _shot(grip + "_" + str(tick))
	_hands(false, false)
	player.set("_camera_pitch", initial_pitch)
	player._update_camera_rotation()
	await _frames(60)
	# Walk and turn with neither mouse button held: use real movement actions.
	Input.action_press("preview_move_forward")
	for tick in 360:
		if tick == 120: Input.action_press("preview_run")
		if tick == 240:
			Input.action_release("preview_run")
			Input.action_release("preview_move_forward")
		if tick < 240:
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(3.0, 0.0)
			Input.parse_input_event(motion)
		await physics_frame
		await RenderingServer.frame_post_draw
		display_samples.append(telemetry.sample(sword))
		var snap: Dictionary = sword.snapshot()
		samples.append({"grip": "carry", "tick": tick, "held": snap.held,
			"head_clearance": snap.head_clearance, "body_clearance": snap.body_clearance,
			"support_error": snap.left_hand_error, "omega": snap.omega,
			"blade_in_world": snap.blade_in_world, "player_position": snap.player_position})
		if tick in [100, 200, 300]: await _shot("carry_" + str(tick))
	# A downward cut into the existing floor, sustained pressure, then withdrawal.
	_hands(true, false)
	for tick in 300:
		if tick < 35 or (tick >= 240 and tick < 275):
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(0.0, 22.0 if tick < 35 else -22.0)
			Input.parse_input_event(motion)
		await physics_frame
		await RenderingServer.frame_post_draw
		display_samples.append(telemetry.sample(sword))
		var snap: Dictionary = sword.snapshot()
		samples.append({"grip":"ground", "tick":tick, "direction":snap.direction,
			"contact": sword.get("_contact_plane_active"), "ground_ms":sword.get("_ground_touch_ms"),
			"omega":snap.omega, "head_clearance":snap.head_clearance,"body_clearance":snap.body_clearance,
			"support_error":snap.left_hand_error,"blade_in_world":snap.blade_in_world})
		if tick in [50, 200, 290]: await _shot("ground_" + str(tick))
	_hands(false, false)
	player.set("_camera_pitch", initial_pitch)
	player._update_camera_rotation()
	for weapon in ["mace", "axe", "sledge", "spear"]:
		scene.get("preview_weapons").equip(weapon)
		await _frames(30)
		_hands(true, weapon != "mace")
		await _frames(30)
		await RenderingServer.frame_post_draw
		display_samples.append(telemetry.sample(sword))
		var snap: Dictionary = sword.snapshot()
		samples.append({"grip":weapon,"head_clearance":snap.head_clearance,"body_clearance":snap.body_clearance,
			"support_error":snap.left_hand_error,"omega":snap.omega})
		await _shot(weapon)
		_hands(false,false)
	var report := {"scope": "Castle scene, synthetic buttons, injected mouse events; not manual play or FPS acceptance", "samples": samples, "display_samples":display_samples}
	var file := FileAccess.open(out_dir.path_join("samples.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("COMBAT_PROBE_DONE samples=", samples.size())
	quit(0)