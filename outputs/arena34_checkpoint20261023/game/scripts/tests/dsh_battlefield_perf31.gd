extends SceneTree
## Paired graphical benchmark: exact same camera with and without battlefield visuals.
## Exclusive perf lane only. Optional screenshots go to DSH_BATTLEFIELD_OUT on D:.

var _scene: Node
var _castle: Node3D
var _battlefield: Node3D
var _camera: Camera3D
var _out_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _has_property(object: Object, name: String) -> bool:
	for item: Dictionary in object.get_property_list():
		if String(item.get("name", "")) == name:
			return true
	return false

func _install_if_needed() -> bool:
	if _has_property(_scene, "preview_battlefield"):
		_battlefield = _scene.get("preview_battlefield") as Node3D
	if _battlefield != null:
		return true
	var script: GDScript = load("res://scripts/city/battlefield_site.gd") as GDScript
	if script == null:
		return false
	_battlefield = script.new() as Node3D
	if _battlefield == null:
		return false
	_castle.add_child(_battlefield)
	var result: Dictionary = _battlefield.call("install", _scene, _castle)
	if not bool(result.get("ok", true)):
		print("BATTLEFIELD_PERF_INSTALL_FAIL ", JSON.stringify(result))
		return false
	var props_script: GDScript = load("res://scripts/city/battlefield_props.gd") as GDScript
	if props_script != null:
		var props: Node3D = props_script.new() as Node3D
		if props != null:
			_battlefield.add_child(props)
			var props_result: Dictionary = props.call("install", _castle)
			if not bool(props_result.get("ok", true)):
				print("BATTLEFIELD_PERF_PROPS_FAIL ", JSON.stringify(props_result))
				return false
	return true

func _settle(frames: int) -> void:
	for tick: int in frames:
		await process_frame

func _measure(seconds: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var previous := started
	var frame_ms: Array[float] = []
	var draw_total := 0.0
	var object_total := 0.0
	var primitive_total := 0.0
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - previous) / 1000.0)
		previous = now
		draw_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		object_total += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitive_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frame_ms.sort()
	var count: int = frame_ms.size()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	return {"fps": float(count) / maxf(0.01, elapsed),
		"p95_ms": frame_ms[clampi(int(float(count) * 0.95), 0, count - 1)] if count > 0 else 0.0,
		"p99_ms": frame_ms[clampi(int(float(count) * 0.99), 0, count - 1)] if count > 0 else 0.0,
		"draw_calls": draw_total / maxf(1.0, float(count)),
		"objects": object_total / maxf(1.0, float(count)),
		"primitives": primitive_total / maxf(1.0, float(count)), "frames": count}

func _screenshot(label: String) -> void:
	if _out_dir == "":
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null:
		print("BATTLEFIELD_SHOT_FAIL ", label)
		return
	var path := _out_dir.path_join("battlefield_%s.png" % label)
	var error := picture.save_png(path)
	print("BATTLEFIELD_SHOT ", path, " status=", error)

func _camera_view(name: String) -> void:
	var base := _castle.global_position
	match name:
		"gate":
			_camera.global_position = base + Vector3(0.0, 5.0, 84.0)
			_camera.look_at(base + Vector3(0.0, 3.0, 160.0), Vector3.UP)
		"field":
			_camera.global_position = base + Vector3(0.0, 9.0, 164.0)
			_camera.look_at(base + Vector3(0.0, 5.0, 235.0), Vector3.UP)
		"flank":
			_camera.global_position = base + Vector3(61.0, 6.0, 155.0)
			_camera.look_at(base + Vector3(0.0, 3.0, 194.0), Vector3.UP)

func _run() -> void:
	_out_dir = OS.get_environment("DSH_BATTLEFIELD_OUT")
	if _out_dir != "" and _out_dir.replace("\\", "/").to_lower().begins_with("d:/"):
		DirAccess.make_dir_recursive_absolute(_out_dir)
	else:
		_out_dir = ""
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_PERF_FAIL scene")
		quit(1)
		return
	var load_started := Time.get_ticks_usec()
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_castle = _scene.get("preview_castle") as Node3D
	if _castle == null or not _install_if_needed():
		print("BATTLEFIELD_PERF_FAIL castle_or_field")
		quit(1)
		return
	var load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
	var resolution := Vector2i(1280, 720)
	if OS.get_environment("DSH_BATTLEFIELD_RESOLUTION") == "1920x1080":
		resolution = Vector2i(1920, 1080)
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.current = true
	var reports: Dictionary = {}
	var passed := true
	for view_name: String in ["gate", "field", "flank"]:
		_camera_view(view_name)
		_battlefield.visible = false
		await _settle(45)
		var castle_only: Dictionary = await _measure(3.0)
		_battlefield.visible = true
		await _settle(45)
		var with_field: Dictionary = await _measure(3.0)
		var loss := 100.0 * (1.0 - float(with_field["fps"]) / maxf(1.0, float(castle_only["fps"])))
		reports[view_name] = {"castle_only": castle_only, "with_field": with_field,
			"fps_loss_pct": loss}
		if loss > 15.0 or float(with_field["fps"]) < 90.0:
			passed = false
		await _screenshot(view_name)
	print("BATTLEFIELD_PERF ", JSON.stringify({"pass": passed,
		"load_ms": load_ms, "resolution": "%dx%d" % [resolution.x, resolution.y], "views": reports}))
	quit(0 if passed else 1)
