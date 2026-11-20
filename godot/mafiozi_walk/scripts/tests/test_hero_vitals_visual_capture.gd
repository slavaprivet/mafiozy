extends SceneTree
## Graphical QA capture of actual equipment and the shared death camera.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("user://")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var armor: Node = scene.get_node_or_null("CastleArmorEquipment")
	if not is_instance_valid(armor):
		print("HERO_VISUAL_CAPTURE FAIL armor")
		quit(1)
		return
	for id: String in ["light_torso", "medium_hands", "heavy_legs", "light_feet"]:
		if not bool((armor.call("equip_ground", id) as Dictionary).get("ok", false)):
			print("HERO_VISUAL_CAPTURE FAIL equip ", id)
			quit(1)
			return
	for frame: int in 30: await process_frame
	var armor_path := output.path_join("hero_armor_hud.png")
	var armor_result := scene.get_viewport().get_texture().get_image().save_png(armor_path)
	var sword: Node = scene.get("preview_sword_prototype")
	var player: CharacterBody3D = scene.get("_player")
	sword.call("_kill_player", player.global_position + Vector3.UP, Vector3.RIGHT, 65.0)
	var death_state: Dictionary = sword.call("snapshot").get("player_death_physics31", {})
	print("HERO_VISUAL_DEATH_STATE ", death_state,
		" authority=", player.get("_pose_authority"))
	if not bool(death_state.get("started", false)) or not bool(death_state.get("impulse_ok", false)):
		print("HERO_VISUAL_CAPTURE FAIL physical_death")
		quit(1)
		return
	for frame: int in 90: await process_frame
	var rig: Skeleton3D = sword.get("_rig")
	var fell := false
	if is_instance_valid(rig):
		var head := (rig.global_transform * rig.get_bone_global_pose(rig.find_bone("head"))).origin
		var pelvis := (rig.global_transform * rig.get_bone_global_pose(rig.find_bone("pelvis"))).origin
		print("HERO_VISUAL_POSE head=", head, " pelvis=", pelvis, " delta=", head - pelvis)
		fell = head.y - pelvis.y < 1.0
	var death_path := output.path_join("hero_death_camera.png")
	var death_result := scene.get_viewport().get_texture().get_image().save_png(death_path)
	print("HERO_VISUAL_CAPTURE ", "PASS" if armor_result == OK and death_result == OK and fell else "FAIL",
		" armor=", armor_path, " death=", death_path)
	quit(0 if armor_result == OK and death_result == OK and fell else 1)
