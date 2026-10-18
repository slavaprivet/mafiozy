extends SceneTree
## DSH_OPT: one blast in a curtain wall, timed. The gate blast is measured by the probe;
## this is the same destruction path against masonry, from a fixed camera, so the cost of a
## breach has a number of its own.

var _scene: Node
var _castle: Node3D
var _camera: Camera3D
var _out_dir := ""

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _measure(seconds: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var last := started
	var worst := 0.0
	var frames := 0
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
	return {"fps": float(frames) / (float(Time.get_ticks_usec() - started) / 1000000.0),
		"max_ms": worst, "frames": frames}

func _shot(name: String) -> void:
	if _out_dir == "": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null: return
	image.save_png(_out_dir.path_join("wall_%s.png" % name))
	print("WALL_SHOT ", _out_dir)

func _run() -> void:
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	var packed: PackedScene = load("res://scenes/castle.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null:
		print("WALL_FAIL")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.current = true
	_camera.global_position = base + Vector3(30.0, 7.0, half + 20.0)
	_camera.look_at(base + Vector3(30.0, 7.0, half), Vector3.UP)
	await _settle(40)
	await _shot("before")
	var hit: Vector3 = base + Vector3(30.0, 7.0, half)
	var started := Time.get_ticks_usec()
	var result: Dictionary = _castle.call("apply_explosion", {
		"position": hit, "radius": 0.85, "power": 240.0,
		"direction": Vector3(0.0, 0.0, -1.0), "event_id": "wall_probe:1",
	})
	var apply_ms := float(Time.get_ticks_usec() - started) / 1000.0
	print("WALL_APPLY_MS ", apply_ms)
	print("WALL_RESULT ", JSON.stringify(result))
	var measured: Dictionary = await _measure(2.0)
	print("WALL_FRAMES ", JSON.stringify(measured))
	var stats: Dictionary = _castle.call("get_stats")
	print("WALL_STATS ", JSON.stringify({"detached": stats.get("detached", 0),
		"collapsed": stats.get("collapsed", 0), "falling": stats.get("falling", 0)}))
	await _shot("after")
	quit(0)
