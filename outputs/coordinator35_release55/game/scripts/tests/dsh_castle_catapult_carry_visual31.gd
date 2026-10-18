extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.get("preview_ready") != true:
		print("CASTLE_CARRY_VISUAL31 failed scene_not_ready")
		quit(1); return
	var catapult: Node3D = scene.get("preview_catapult")
	var player: CharacterBody3D = scene.get("_player")
	var stone: RigidBody3D = catapult.get("_stone")
	catapult.place_near_castle(scene.get("preview_castle"))
	player.set_mouse_captured(true)
	for frame: int in 120: await physics_frame
	player.global_position = stone.global_position + Vector3(0.45, 0.0, 0.0)
	player._visual.rotation.y = 0.0
	for frame: int in 6: await physics_frame
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.far = 100.0
	scene.add_child(camera)
	camera.current = true
	camera.global_position = player.global_position + Vector3(1.45, 1.65, 3.25)
	camera.look_at(player.global_position + Vector3(0.0, 1.05, 0.0))
	var taken: bool = catapult._try_interact()
	if not taken or not catapult.snapshot().carrying:
		print("CASTLE_CARRY_VISUAL31 failed stone_not_taken")
		quit(1); return
	var directory: String = OS.get_environment("DSH_SHOT_DIR")
	for frame: int in 5: await physics_frame
	for frame: int in 3: await process_frame
	var lifting: String = directory.path_join("castle_stone_lifting31.png")
	var lift_saved: Error = root.get_texture().get_image().save_png(lifting)
	for frame: int in 25: await physics_frame
	for frame: int in 3: await process_frame
	var carried: String = directory.path_join("castle_stone_carried31.png")
	var carried_saved: Error = root.get_texture().get_image().save_png(carried)
	print("CASTLE_CARRY_VISUAL31 ", JSON.stringify({"passed": lift_saved == OK and carried_saved == OK,
		"lifting": lifting, "carried": carried,
		"hand_distance": catapult._hand_midpoint().distance_to(stone.global_position),
		"arms_hugging": catapult.get("_arms_hugging"),
		"stone_in_hands": catapult.snapshot().carrying}))
	quit(0 if lift_saved == OK and carried_saved == OK else 1)
