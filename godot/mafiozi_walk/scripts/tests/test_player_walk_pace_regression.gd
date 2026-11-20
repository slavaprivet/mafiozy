extends SceneTree
## Compare world travel with physics time and wall-clock time in the castle.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await physics_frame
	var player: CharacterBody3D = scene.get("_player")
	if not is_instance_valid(player): print("WALK_PACE FAIL setup"); quit(1); return
	for frame: int in 90: await physics_frame
	player.set("_free_mouse_look", true)
	player.set("_camera_yaw", 0.0)
	var weapons: Node = scene.get("preview_weapons")
	var armor: Node = scene.get_node_or_null("CastleArmorEquipment")
	print("WALK_PACE_STATE ", {"time_scale": Engine.time_scale,
		"physics_hz": Engine.physics_ticks_per_second,
		"walk_speed": player.walk_speed, "run_speed": player.run_speed,
		"armor_scale": armor.speed_multiplier() if is_instance_valid(armor) else -1.0,
		"weapon_posture": weapons.get("_posture_view") if is_instance_valid(weapons) else {},
		"leg_scale": player._leg_support_scale50(), "injury_scale": player._injury32.speed_scale()})
	Input.action_press(&"preview_move_forward")
	var begin := player.global_position
	var start_us := Time.get_ticks_usec()
	for frame: int in 120: await physics_frame
	var elapsed := float(Time.get_ticks_usec() - start_us) / 1000000.0
	var travelled := Vector2(player.global_position.x - begin.x, player.global_position.z - begin.z).length()
	Input.action_release(&"preview_move_forward")
	print("WALK_PACE ", {"metres": travelled, "wall_seconds": elapsed,
		"metres_per_wall_second": travelled / maxf(0.01, elapsed),
		"metres_per_physics_second": travelled / 2.0,
		"fps": Engine.get_frames_per_second(), "end": player.global_position,
		"velocity": player.velocity, "real_velocity": player.get_real_velocity()})
	var pace := travelled / maxf(0.01, elapsed)
	var valid := is_equal_approx(Engine.time_scale, 1.0) and pace > 3.7 and pace < 4.25
	print("WALK_PACE_RESULT ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
