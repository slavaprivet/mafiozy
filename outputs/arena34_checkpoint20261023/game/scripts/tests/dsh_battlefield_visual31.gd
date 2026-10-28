extends SceneTree
## Graphical scene acceptance at player height and close range; screenshots on D:.

var _scene: Node
var _castle: Node3D
var _field: Node3D
var _camera: Camera3D
var _out_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _take_shot(label: String, from: Vector3, toward: Vector3) -> bool:
	var base: Vector3 = _castle.global_position
	_camera.global_position = base + from
	_camera.look_at(base + toward, Vector3.UP)
	for frame: int in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		return false
	var file_name := _out_dir.path_join("battlefield_%s.png" % label)
	var error: Error = picture.save_png(file_name)
	print("BATTLEFIELD_VISUAL_SHOT ", JSON.stringify({"label": label,
		"path": file_name, "error": error, "size": picture.get_size()}))
	return error == OK

func _run() -> void:
	_out_dir = OS.get_environment("DSH_BATTLEFIELD_OUT")
	if not _out_dir.replace("\\", "/").to_lower().begins_with("d:/"):
		print("BATTLEFIELD_VISUAL_FAIL output_must_be_on_D")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_VISUAL_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_castle = _scene.get("preview_castle") as Node3D
	_field = _scene.get("preview_battlefield") as Node3D
	if _castle == null or _field == null:
		print("BATTLEFIELD_VISUAL_FAIL scene_parts")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.current = true
	var results: Array[bool] = []
	results.append(await _take_shot("player_155_toward_camp", Vector3(0, 1.8, 155), Vector3(0, 1.6, 225)))
	if OS.get_environment("DSH_BATTLEFIELD_VISUAL_TERRAIN_ONLY") != "1":
		results.append(await _take_shot("player_215_toward_gate", Vector3(0, 1.8, 215), Vector3(0, 1.6, 115)))
		results.append(await _take_shot("tent_closeup", Vector3(33, 2.2, 189), Vector3(33, 1.8, 205)))
		results.append(await _take_shot("cart_closeup", Vector3(51, 2.4, 135), Vector3(63, 1.25, 143)))
	var passed := not results.has(false)
	print("BATTLEFIELD_VISUAL ", JSON.stringify({"pass": passed,
		"shots": results.size(), "field_node": _field.name}))
	await create_timer(3.0).timeout
	quit(0 if passed else 1)
