extends SceneTree
## DSH_CASTLE: the destruction, seen.
## Renders the wall before a shot, fires the machine at it, and renders the same view after
## the breach - so the damage can be judged by eye and not only by a counter.

var _scene: Node
var _castle: Node3D
var _catapult: Node3D
var _camera: Camera3D
var _out_dir := ""

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null: print("DSHOT_FAIL image ", name); return
	var path: String = _out_dir.path_join("castle_destroy_%s.png" % name)
	image.save_png(path)
	print("DSHOT_SAVED ", path)

func _run() -> void:
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	if _out_dir == "": _out_dir = "C:/Users/Слава/Documents/deepseek-harness/default-workspace"
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("DSHOT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	_catapult = _scene.get("preview_catapult")
	if _castle == null or _catapult == null: print("DSHOT_FAIL missing"); quit(1); return
	if _catapult.has_method("place_near_castle"):
		_catapult.call("place_near_castle", _castle)
	await _settle(40)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 900.0
	_scene.add_child(_camera)
	_camera.current = true
	# A view of the wall a little to the side of the gate, from outside.
	_camera.global_position = base + Vector3(26.0, 10.0, half + 34.0)
	_camera.look_at(base + Vector3(16.0, 9.0, half), Vector3.UP)
	await _settle(20)
	_shot("before")
	# Load, aim at the wall, fire.
	_catapult.call("_set_stone_on_spoon")
	for i: int in 60:
		await process_frame
		if bool((_catapult.call("snapshot") as Dictionary).get("stone_on_spoon", false)): break
	_catapult.call("aim_at", base + Vector3(16.0, 9.0, half))
	await _settle(4)
	_catapult.call("_fire")
	var fired := false
	for i: int in 400:
		await process_frame
		var snap: Dictionary = _catapult.call("snapshot")
		if bool(snap.get("flying", false)): fired = true
		if fired and not bool(snap.get("flying", false)): break
	await _settle(80)
	_shot("after")
	var stats: Dictionary = _castle.call("get_stats")
	print("DSHOT_STATS fired=", fired, " detached=", stats.get("detached", 0),
		" collapsed=", stats.get("collapsed", 0), " falling=", stats.get("falling", 0))
	print("DSHOT_DONE")
	quit(0)