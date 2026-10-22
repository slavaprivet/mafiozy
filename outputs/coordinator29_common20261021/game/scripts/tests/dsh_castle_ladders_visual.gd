extends SceneTree
## Graphical evidence for the wall ladders: the crawl pose on the rungs, and a ladder
## after a projectile has taken several pieces out of it.

var _game: Node
var _castle: Node3D
var _player: CharacterBody3D
var _dressing: Node3D
var _camera: Camera3D
var _out := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(label: String, from: Vector3, toward: Vector3) -> bool:
	var base := _castle.global_position
	_camera.global_position = base + from
	_camera.look_at(base + toward, Vector3.UP)
	for i: int in 35:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path := _out.path_join("ladder_%s.png" % label)
	var error := image.save_png(path)
	print("LADDER_SHOT ", JSON.stringify({"label": label, "path": path, "error": error}))
	return error == OK


func _run() -> void:
	_out = OS.get_environment("DSH_LADDER_SHOTS")
	if _out.is_empty():
		_out = "res://outputs/ladder_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	var packed: PackedScene = load("res://scenes/castle.tscn")
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and _game.get("preview_ready") != true:
		await process_frame
	for i: int in 240:
		await physics_frame
	for node: Node in _game.find_children("*", "CanvasLayer", true, false):
		if String(node.name).begins_with("ShipHud"):
			(node as CanvasLayer).visible = false
	_castle = _game.get("preview_castle") as Node3D
	_player = _game.get("_player") as CharacterBody3D
	var field: Node3D = _game.get("preview_battlefield") as Node3D
	_dressing = field.get_node_or_null("SiegeWallDressing") as Node3D if field != null else null
	if _dressing == null:
		print("LADDER_VISUAL_FAIL")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.far = 300.0
	_game.add_child(_camera)
	_camera.current = true
	# Mid-ladder, with the crawl pose active.
	_player.global_position = _dressing.to_global(Vector3(-38.0, 9.6, 71.4))
	_player.set_physics_process(false)
	_dressing.call("debug_climb_axis", 1.0)
	for i: int in 30:
		_dressing.call("climb_assist", _player, 1.0 / 60.0)
	var results: Array[bool] = []
	results.append(await _shot("climb", Vector3(-47.0, 12.0, 82.0), Vector3(-38.0, 10.0, 71.0)))
	results.append(await _shot("climb_close", Vector3(-42.0, 10.6, 76.5), Vector3(-38.0, 9.8, 71.3)))
	# A siege hit takes rungs and stringers out of the middle.
	_dressing.call("apply_damage", _dressing.to_global(Vector3(-38.0, 10.6, 71.6)),
		2.6, 90.0, 70.0)
	results.append(await _shot("broken", Vector3(-47.0, 12.0, 82.0), Vector3(-38.0, 10.0, 71.0)))
	results.append(await _shot("broken_close", Vector3(-42.0, 10.6, 76.5), Vector3(-38.0, 9.8, 71.3)))
	print("LADDER_VISUAL ", JSON.stringify({"pass": not results.has(false), "shots": results.size(),
		"status": _dressing.call("ladder_status")}))
	await create_timer(1.0).timeout
	quit(0 if not results.has(false) else 1)
