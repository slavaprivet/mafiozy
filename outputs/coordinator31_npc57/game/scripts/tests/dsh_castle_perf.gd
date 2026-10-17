extends SceneTree
## DSH_CASTLE: what does the map cost, near and far?
## Frames are counted from two viewpoints - in the courtyard, and outside the walls with the
## whole castle in view - so the brick LOD can be judged by a number rather than an opinion.

var _scene: Node
var _castle: Node3D
var _camera: Camera3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _measure(seconds: float) -> float:
	var started := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await process_frame
		frames += 1
	return float(frames) / maxf(0.05, float(Time.get_ticks_msec() - started) / 1000.0)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("PERF_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null: print("PERF_FAIL castle"); quit(1); return
	# The display caps at 60 with vsync on, and a capped number says nothing about cost.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.current = true
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	_camera.global_position = base + Vector3(0.0, 6.0, 20.0)
	_camera.look_at(base + Vector3(0.0, 8.0, half), Vector3.UP)
	await _settle(40)
	var near_fps: float = await _measure(2.5)
	print("PERF_COURTYARD fps=", near_fps)
	_camera.global_position = base + Vector3(half + 90.0, 55.0, half + 90.0)
	_camera.look_at(base + Vector3(0.0, 10.0, 0.0), Vector3.UP)
	await _settle(40)
	var far_fps: float = await _measure(2.5)
	print("PERF_WHOLE fps=", far_fps)
	var render: Dictionary = _castle.call("render_stats")
	print("PERF_CHUNKS ", JSON.stringify(render))
	var failed: Array[String] = []
	if near_fps < 90.0: failed.append("courtyard_slow")
	if far_fps < 90.0: failed.append("whole_castle_slow")
	print("PERF_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)