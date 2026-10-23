extends SceneTree
## Paired graphical attribution on one fixed view. No game source mutation.
## Four visual states in mirrored order reduce warmup/temperature bias.

var _scene: Node
var _castle: Node3D
var _field: Node3D
var _props: Node3D
var _terrain_meshes: Array[MeshInstance3D] = []
var _camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _settle(frames: int) -> void:
	for tick: int in frames:
		await process_frame

func _state(name: String) -> void:
	_props.visible = name == "props" or name == "all"
	for mesh: MeshInstance3D in _terrain_meshes:
		mesh.visible = name == "terrain" or name == "all"

func _measure(seconds: float) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var previous := started
	var frames_ms: Array[float] = []
	var draw_total := 0.0
	var object_total := 0.0
	var primitive_total := 0.0
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames_ms.append(float(now - previous) / 1000.0)
		previous = now
		draw_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		object_total += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitive_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frames_ms.sort()
	var count := frames_ms.size()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	return {"fps": float(count) / maxf(0.01, elapsed),
		"mean_ms": 1000.0 * elapsed / maxf(1.0, float(count)),
		"p95_ms": frames_ms[clampi(int(float(count) * 0.95), 0, count - 1)] if count > 0 else 0.0,
		"draw_calls": draw_total / maxf(1.0, float(count)),
		"objects": object_total / maxf(1.0, float(count)),
		"primitives": primitive_total / maxf(1.0, float(count)), "frames": count}

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_ATTRIBUTION_FAIL scene")
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
		print("BATTLEFIELD_ATTRIBUTION_FAIL scene_parts")
		quit(1)
		return
	_props = _field.get_node_or_null("BattlefieldProps") as Node3D
	for child: Node in _field.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Terrain_"):
			_terrain_meshes.append(child as MeshInstance3D)
	if _props == null or _terrain_meshes.size() != 9:
		print("BATTLEFIELD_ATTRIBUTION_FAIL groups props=", _props,
			" terrain_meshes=", _terrain_meshes.size())
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	var view_name := OS.get_environment("DSH_BATTLEFIELD_ATTR_VIEW")
	if view_name == "gate":
		_camera.global_position = _castle.global_position + Vector3(0, 5, 84)
		_camera.look_at(_castle.global_position + Vector3(0, 3, 160), Vector3.UP)
	else:
		view_name = "field"
		_camera.global_position = _castle.global_position + Vector3(0, 9, 164)
		_camera.look_at(_castle.global_position + Vector3(0, 5, 235), Vector3.UP)
	_camera.current = true
	# Warm every material/view before timing the mirrored sequence.
	for name: String in ["none", "terrain", "props", "all"]:
		_state(name)
		await _settle(35)
	var sequence: Array[String] = ["none", "terrain", "props", "all",
		"all", "props", "terrain", "none"]
	var samples: Array[Dictionary] = []
	var sums: Dictionary = {}
	for name: String in sequence:
		_state(name)
		await _settle(45)
		var result: Dictionary = await _measure(2.5)
		result["state"] = name
		samples.append(result)
		if not sums.has(name):
			sums[name] = {"fps": 0.0, "mean_ms": 0.0, "p95_ms": 0.0,
				"draw_calls": 0.0, "objects": 0.0, "primitives": 0.0}
		var total: Dictionary = sums[name]
		for key: String in ["fps", "mean_ms", "p95_ms", "draw_calls", "objects", "primitives"]:
			total[key] = float(total[key]) + float(result[key]) * 0.5
		sums[name] = total
	_state("all")
	print("BATTLEFIELD_ATTRIBUTION ", JSON.stringify({"pass": true,
		"resolution": "1280x720", "view": view_name,
		"terrain_meshes": _terrain_meshes.size(), "order": sequence,
		"averages": sums, "samples": samples}))
	quit(0)
