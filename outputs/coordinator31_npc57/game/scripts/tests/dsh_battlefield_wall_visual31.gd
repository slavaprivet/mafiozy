extends SceneTree
## Same fixed castle-wall viewpoints on published baseline and siege candidate.

func _initialize() -> void:
	call_deferred("_run")

func _shot(camera: Camera3D, castle: Node3D, folder: String,
		label: String, from: Vector3, toward: Vector3) -> bool:
	camera.global_position = castle.global_position + from
	camera.look_at(castle.global_position + toward, Vector3.UP)
	for frame: int in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path: String = folder.path_join(label + ".png")
	var result: Error = image.save_png(path)
	print("SIEGE_WALL_SHOT ", JSON.stringify({"label": label,
		"path": path, "error": result, "size": image.get_size()}))
	return result == OK

func _run() -> void:
	var folder: String = OS.get_environment("DSH_BATTLEFIELD_OUT")
	if not folder.replace("\\", "/").to_lower().begins_with("d:/"):
		print("SIEGE_WALL_VISUAL_FAIL output_must_be_on_D")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		quit(1)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	var deadline: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and game.get("preview_ready") != true:
		await process_frame
	var castle: Node3D = game.get("preview_castle") as Node3D
	if castle == null:
		print("SIEGE_WALL_VISUAL_FAIL castle")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 1200.0
	game.add_child(camera)
	camera.current = true
	var shots: Array[bool] = []
	shots.append(await _shot(camera, castle, folder, "wall_wide",
		Vector3(0, 3.0, 115), Vector3(0, 8.0, 69)))
	shots.append(await _shot(camera, castle, folder, "ladder_close",
		Vector3(27, 2.2, 86), Vector3(21, 10.0, 70)))
	shots.append(await _shot(camera, castle, folder, "scars_close",
		Vector3(32, 2.0, 100), Vector3(30, 0.3, 85)))
	var passed: bool = not shots.has(false)
	print("SIEGE_WALL_VISUAL ", JSON.stringify({"pass": passed,
		"shots": shots.size()}))
	current_scene = null
	game.queue_free()
	packed = null
	for tick: int in 18:
		await process_frame
	quit(0 if passed else 1)
