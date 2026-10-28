extends SceneTree
## DSH_CATAPULT: what does the machine itself cost per frame?
## The same frame loop is timed twice - with the machine live, and with it switched off - and
## the difference is its price. No code is changed to measure this.

var _scene: Node

func _initialize() -> void:
	_run()

func _timed_frames(count: int) -> float:
	var started := Time.get_ticks_usec()
	for i: int in count:
		await process_frame
	return float(Time.get_ticks_usec() - started) / float(count)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("COST_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	var catapult: Node = _scene.get("preview_catapult")
	if catapult == null: print("COST_FAIL no catapult"); quit(1); return
	for settle: int in 10:
		await process_frame
	var live_us: float = await _timed_frames(240)
	catapult.set_process(false)
	catapult.set_physics_process(false)
	for settle: int in 10:
		await process_frame
	var off_us: float = await _timed_frames(240)
	print("COST live_us=", snappedf(live_us, 0.01), " off_us=", snappedf(off_us, 0.01),
		" catapult_us=", snappedf(live_us - off_us, 0.01))
	print("COST_DONE")
	quit(0)
