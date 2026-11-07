extends SceneTree

var _scene: Node

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed := load("res://scenes/castle.tscn") as PackedScene
	if packed == null:
		print("SINGLE_SUPPORT FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	var castle: Node = _scene.get("preview_castle")
	if not is_instance_valid(castle):
		print("SINGLE_SUPPORT FAIL castle")
		quit(1)
		return
	var cells: Array = castle.get("_cells")
	var chosen := -1
	for index: int in cells.size():
		var cell: Dictionary = cells[index]
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		var size: Vector3 = cell.get("size", Vector3.ZERO)
		if bool(cell.get("alive", false)) and str(cell.get("group", "")) == "south" \
				and at.y > 4.0 and at.y < 8.0 and absf(at.x) > 12.0 \
				and absf(size.y - 0.54) < 0.08:
			chosen = index
			break
	if chosen < 0:
		print("SINGLE_SUPPORT FAIL candidate")
		quit(1)
		return
	var selected: Dictionary = cells[chosen]
	var before: Dictionary = castle.call("get_stats")
	castle.call("_kill_brick", chosen, Vector3.DOWN, 5.0)
	var peak_pending := 0
	var peak_falling := 0
	var worst_tick_us := 0
	for frame: int in 360:
		var started := Time.get_ticks_usec()
		await physics_frame
		worst_tick_us = maxi(worst_tick_us, Time.get_ticks_usec() - started)
		var stats: Dictionary = castle.call("get_stats")
		peak_pending = maxi(peak_pending, int(stats.get("support_pending", 0)))
		peak_falling = maxi(peak_falling, int(stats.get("falling", 0)))
	var after: Dictionary = castle.call("get_stats")
	var report := {
		"chosen": chosen,
		"group": selected.get("group", ""),
		"at": selected.get("at", Vector3.ZERO),
		"detached_delta": int(after.get("detached", 0)) - int(before.get("detached", 0)),
		"collapsed_delta": int(after.get("collapsed", 0)) - int(before.get("collapsed", 0)),
		"pending": after.get("support_pending", -1),
		"peak_pending": peak_pending,
		"peak_falling": peak_falling,
		"worst_tick_ms": float(worst_tick_us) / 1000.0,
		"support_checks_peak": after.get("support_checks_peak", -1),
		"support_work_us_peak": after.get("support_work_us_peak", -1),
	}
	print("SINGLE_SUPPORT REPORT ", JSON.stringify(report))
	var failed: Array[String] = []
	if int(report.detached_delta) != 1: failed.append("non_local_detach")
	if int(report.collapsed_delta) != 0: failed.append("false_cascade")
	if int(report.peak_pending) > 16: failed.append("broad_queue")
	if int(report.pending) != 0: failed.append("queue_not_drained")
	if int(report.support_checks_peak) > 32: failed.append("check_budget")
	print("SINGLE_SUPPORT RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)
