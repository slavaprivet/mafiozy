extends SceneTree
## Repeat only the marginal gate view in an ABBA paired sequence.

var _scene: Node
var _castle: Node3D
var _field: Node3D
var _camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _settle(frames: int) -> void:
	for tick: int in frames:
		await process_frame

func _measure(seconds: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var previous := started
	var times: Array[float] = []
	var draws := 0.0
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	times.sort()
	var count := times.size()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	return {"fps": float(count) / maxf(0.01, elapsed),
		"mean_ms": elapsed * 1000.0 / maxf(1.0, float(count)),
		"median_ms": times[count / 2] if count > 0 else 0.0,
		"p95_ms": times[clampi(int(float(count) * 0.95), 0, count - 1)] if count > 0 else 0.0,
		"draw_calls": draws / maxf(1.0, float(count)), "frames": count}

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_GATE_PERF_FAIL scene")
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
		print("BATTLEFIELD_GATE_PERF_FAIL scene_parts")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.global_position = _castle.global_position + Vector3(0, 5, 84)
	_camera.look_at(_castle.global_position + Vector3(0, 3, 160), Vector3.UP)
	_camera.current = true
	_field.visible = true
	await _settle(90)
	var samples: Array[Dictionary] = []
	var averages: Dictionary = {"castle": {"fps": 0.0, "mean_ms": 0.0,
		"median_ms": 0.0, "p95_ms": 0.0, "draw_calls": 0.0},
		"field": {"fps": 0.0, "mean_ms": 0.0,
		"median_ms": 0.0, "p95_ms": 0.0, "draw_calls": 0.0}}
	for state: String in ["castle", "field", "field", "castle"]:
		_field.visible = state == "field"
		await _settle(60)
		var result: Dictionary = await _measure(3.0)
		result["state"] = state
		samples.append(result)
		var avg: Dictionary = averages[state]
		for key: String in ["fps", "mean_ms", "median_ms", "p95_ms", "draw_calls"]:
			avg[key] = float(avg[key]) + float(result[key]) * 0.5
		averages[state] = avg
	_field.visible = true
	var loss := 100.0 * (1.0 - float(averages["field"]["fps"]) /
		maxf(1.0, float(averages["castle"]["fps"])))
	print("BATTLEFIELD_GATE_PERF ", JSON.stringify({"pass": loss <= 15.0 and
		float(averages["field"]["fps"]) >= 90.0, "loss_pct": loss,
		"resolution": "1280x720", "order": ["castle", "field", "field", "castle"],
		"averages": averages, "samples": samples}))
	quit(0 if loss <= 15.0 and float(averages["field"]["fps"]) >= 90.0 else 1)
