extends SceneTree

var _scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_scene = load("res://scenes/castle.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	var castle: Node = _scene.get("preview_castle")
	if castle == null:
		print("PASS2_SUPPORT_RESULT FAIL castle")
		quit(1)
		return
	var wanted: Array[String] = ["entrance_arch31", "entrance_pier31",
		"gate38_machicolation", "tower_crown_merlon"]
	var selected: Dictionary = {}
	var before: Dictionary = {}
	for index: int in castle.get("_cells").size():
		var cell: Dictionary = castle.get("_cells")[index]
		var group := str(cell.get("group", ""))
		if group not in wanted:
			continue
		before[group] = int(before.get(group, 0)) + 1
		if not selected.has(group):
			selected[group] = index
	for group: String in wanted:
		if selected.has(group):
			castle.call("_kill_brick", int(selected[group]), Vector3.ZERO, 1.0)
	for frame: int in 720:
		await physics_frame
	var after: Dictionary = {}
	for value: Variant in castle.get("_cells"):
		var cell: Dictionary = value
		var group := str(cell.get("group", ""))
		if group in wanted and bool(cell.get("alive", false)):
			after[group] = int(after.get(group, 0)) + 1
	var stats: Dictionary = castle.call("get_stats")
	var failures: Array[String] = []
	var expected_before := {"entrance_arch31": 46, "entrance_pier31": 72,
		"gate38_machicolation": 7, "tower_crown_merlon": 72}
	var expected_after := {"entrance_arch31": 4, "entrance_pier31": 54,
		"gate38_machicolation": 3, "tower_crown_merlon": 71}
	if before != expected_before:
		failures.append("group_counts_changed")
	if after != expected_after:
		failures.append("support_cascade_changed")
	if int(stats.get("collapsed", 0)) != 204:
		failures.append("collapse_count_changed")
	if int(stats.get("support_pending", 0)) != 0:
		failures.append("support_queue_not_drained")
	print("PASS2_SUPPORT ", JSON.stringify({"selected": selected, "before": before,
		"after": after, "collapsed": stats.get("collapsed", 0),
		"pending": stats.get("support_pending", 0), "failures": failures}))
	print("PASS2_SUPPORT_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
