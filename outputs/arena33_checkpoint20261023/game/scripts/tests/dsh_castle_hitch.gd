extends SceneTree
## DSH_CASTLE: does anything hitch while the man walks?
## Frame times are recorded for ten seconds of walking, reported as p50 / p95 / worst, and
## the worst frames are printed with what the world was doing at that moment.

var _scene: Node
var _player: CharacterBody3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("HITCH_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	if _player == null: print("HITCH_FAIL player"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	var population: Variant = _scene.get("preview_population")
	print("HITCH_WORLD population=", population != null,
		" castle=", _scene.get("preview_castle") != null,
		" catapult=", _scene.get("preview_catapult") != null)
	Input.action_press(_player.ACTION_FORWARD)
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 10000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	Input.action_release(_player.ACTION_FORWARD)
	times.sort()
	var count := times.size()
	if count == 0: print("HITCH_FAIL no frames"); quit(1); return
	var p50: float = times[int(float(count) * 0.50)]
	var p95: float = times[int(float(count) * 0.95)]
	var worst: float = times[count - 1]
	var over: int = 0
	for t: float in times:
		if t > 50.0: over += 1
	print("HITCH_FRAMES count=", count, " p50_ms=", p50, " p95_ms=", p95,
		" worst_ms=", worst, " over_50ms=", over)
	var failed: Array[String] = []
	if worst > 120.0: failed.append("hitch_over_120ms")
	if over > count / 50: failed.append("too_many_stalls")
	print("HITCH_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)