extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and (scene.get("preview_ready") != true \
			or not is_instance_valid(scene.get("preview_horse_mount"))):
		await physics_frame
	var host: Node = scene.get("preview_horse_mount")
	var player: CharacterBody3D = scene.get("_player")
	if not is_instance_valid(host) or not is_instance_valid(player):
		print("HORSE_HP_HUD FAIL scene_not_ready")
		quit(1)
		return
	var horse: CharacterBody3D = host.get("horse")
	if not is_instance_valid(horse):
		print("HORSE_HP_HUD FAIL horse_missing")
		quit(1)
		return
	player.set("_free_mouse_look", true)
	scene.set("_castle_spawn_frames", 0)
	horse.global_position = player.global_position + Vector3(2.0, 0.04, -2.0)
	await physics_frame
	await physics_frame
	var failures: Array[String] = []
	var viewport := root.get_viewport()
	var taa_before := viewport.use_taa
	if horse.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
		failures.append("horse_not_interpolated")
	if not host.call("mount_now"):
		failures.append("mount_failed")
	else:
		if viewport.use_taa:
			failures.append("taa_still_on_while_riding")
		host.call("_update_hud", false)
		var panel: PanelContainer = host.get("_hp_panel")
		var viewport_size := root.get_viewport().get_visible_rect().size
		if not panel.visible:
			failures.append("hud_hidden")
		if panel.position.x < viewport_size.x - panel.size.x - 30.0 or panel.position.y > 30.0:
			failures.append("hud_not_in_corner")
		scene.call("_update_door_hint")
		scene.call("_position_door_hint")
		var mount_hint: Control = scene.get("_door_hint_panel")
		var hint_at: Vector2 = mount_hint.position
		horse.global_position += Vector3(0.5, 0.0, 0.0)
		scene.call("_position_door_hint")
		if str(scene.get("_door_hint_owner")) != "mounted_horse" or not mount_hint.visible or mount_hint.position != hint_at:
			failures.append("mounted_hint_jitters")
		if not host.call("dismount_now"):
			failures.append("dismount_failed")
		if viewport.use_taa != taa_before:
			failures.append("taa_not_restored")
	print("HORSE_HP_HUD ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
