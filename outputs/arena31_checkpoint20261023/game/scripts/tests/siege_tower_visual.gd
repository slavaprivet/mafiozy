extends SceneTree
## DSH_TOWER: graphical acceptance for the siege ram tower.
## Loads the real castle scene, waits for the tower host, and saves four views.

var _scene: Node
var _host: Node
var _body: AnimatableBody3D
var _camera: Camera3D
var _out_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _shot(label: String, local_from: Vector3, local_at: Vector3) -> bool:
	var origin: Vector3 = _body.global_position
	var yaw: float = float(_body.get("_yaw"))
	var basis := Basis(Vector3.UP, yaw)
	_camera.global_position = origin + basis * local_from
	_camera.look_at(origin + basis * local_at, Vector3.UP)
	for _frame: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		print("DSH_TOWER_SHOT_FAIL empty ", label)
		return false
	var path := _out_dir.path_join("tower_%s.png" % label)
	var error := picture.save_png(path)
	print("DSH_TOWER_SHOT ", JSON.stringify({"label": label, "path": path,
		"error": error, "size": picture.get_size()}))
	return error == OK

func _run() -> void:
	_out_dir = OS.get_environment("DSH_TOWER_SHOT_DIR")
	if _out_dir.is_empty():
		_out_dir = "D:/MafioziCombat31/tower_shots"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("DSH_TOWER_VISUAL_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	if _scene.get("preview_ready") != true:
		print("DSH_TOWER_VISUAL_FAIL not_ready")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		_host = _scene.get("preview_siege_tower") as Node
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		print("DSH_TOWER_VISUAL_FAIL no_host status=", _scene.get("siege_tower_status"))
		quit(1)
		return
	_body = _host.call("body_ref") as AnimatableBody3D
	if not is_instance_valid(_body):
		print("DSH_TOWER_VISUAL_FAIL no_body")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1600, 900))
	for node: Node in _scene.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.far = 600.0
	_scene.add_child(_camera)
	_camera.current = true
	# Let the ground settle and the wheels touch.
	for _frame: int in 30:
		await physics_frame
	var results: Array[bool] = []
	results.append(await _shot("front", Vector3(10.2, 5.0, -9.2), Vector3(0.0, 5.6, 0.0)))
	results.append(await _shot("side", Vector3(12.6, 4.4, 1.8), Vector3(0.0, 4.8, 0.0)))
	results.append(await _shot("rear", Vector3(-8.2, 4.2, 11.6), Vector3(0.0, 4.8, 0.0)))
	results.append(await _shot("ram", Vector3(3.6, 2.8, -10.4), Vector3(0.0, 2.35, -7.9)))
	results.append(await _shot("top", Vector3(8.8, 13.8, 8.2), Vector3(0.0, 9.0, 0.0)))
	results.append(await _shot("scorpion", Vector3(0.6, 10.15, 0.9), Vector3(-1.4, 9.55, -2.1)))
	# The ram in motion: wind up, then catch it at the end of the strike.
	_body.call("trigger_ram")
	for _frame: int in 20:
		await physics_frame
	results.append(await _shot("ram_back", Vector3(6.4, 3.0, -4.0), Vector3(0.0, 2.5, -5.4)))
	for _frame: int in 24:
		await physics_frame
	results.append(await _shot("ram_strike", Vector3(6.4, 3.0, -4.0), Vector3(0.0, 2.5, -6.8)))
	# The view a bowman has from the fighting top: over the merlons at the gate.
	results.append(await _shot("platform_view", Vector3(0.0, 10.55, 0.9), Vector3(0.0, 2.0, -30.0)))
	# 1. Support chain: remove the platform and watch the top sections lose
	# support and drop one after another.
	_body.call("debug_break", "platform")
	for _frame: int in 16:
		await physics_frame
	results.append(await _shot("support_break", Vector3(10.6, 7.6, 10.6), Vector3(0.0, 7.2, 0.0)))
	for _frame: int in 40:
		await physics_frame
	results.append(await _shot("chain_fall", Vector3(10.6, 6.2, 10.6), Vector3(0.0, 5.6, 0.0)))
	# 2. Break the chassis: the whole machine tips over while the rest cascades.
	_body.call("blast_at", _body.to_global(Vector3(0.0, 1.15, 0.0)), 5.2, 3200.0, "powder")
	for _frame: int in 12:
		await physics_frame
	results.append(await _shot("topple_start", Vector3(18.5, 8.0, 13.0), Vector3(0.0, 5.0, 0.0)))
	for _frame: int in 22:
		await physics_frame
	results.append(await _shot("topple_mid", Vector3(19.0, 7.0, 13.5), Vector3(0.0, 4.0, 0.0)))
	for _frame: int in 45:
		await physics_frame
	results.append(await _shot("wreck", Vector3(10.4, 4.8, 9.8), Vector3(0.0, 2.2, 0.0)))
	for _frame: int in 45:
		await physics_frame
	results.append(await _shot("wreck_settled", Vector3(10.4, 4.8, 9.8), Vector3(0.0, 1.2, 0.0)))
	var snapshot: Dictionary = _host.call("snapshot")
	var passed := not results.has(false)
	print("DSH_TOWER_VISUAL ", JSON.stringify({"pass": passed, "shots": results.size(),
		"out": _out_dir, "snapshot": snapshot}))
	await create_timer(2.0).timeout
	quit(0 if passed else 1)
