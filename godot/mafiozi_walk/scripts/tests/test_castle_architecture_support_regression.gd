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
		print("ARCH_SUPPORT_RESULT FAIL castle")
		quit(1)
		return
	var cells: Array = castle.get("_cells")
	var wanted: Array[String] = ["south_merlon", "tower_crown", "gate_shield",
		"keep_pinnacle31", "gate38_gallery_merlon", "gate38_slate_roof",
		"gate38_pediment"]
	var selected: Dictionary = {}
	var before_by_group: Dictionary = {}
	for index: int in cells.size():
		var cell: Dictionary = cells[index]
		var group := str(cell.get("group", ""))
		if group not in wanted:
			continue
		before_by_group[group] = int(before_by_group.get(group, 0)) + 1
		if not selected.has(group):
			selected[group] = index
	var failures: Array[String] = []
	for group: String in wanted:
		if not selected.has(group):
			failures.append("missing_" + group)
			continue
		castle.call("_kill_brick", int(selected[group]), Vector3.ZERO, 1.0)
	for frame: int in 360:
		await physics_frame
	var after_by_group: Dictionary = {}
	var removed_by_group: Dictionary = {}
	for cell_value: Variant in castle.get("_cells"):
		var cell: Dictionary = cell_value
		var group := str(cell.get("group", ""))
		if not bool(cell.get("alive", false)):
			removed_by_group[group] = int(removed_by_group.get(group, 0)) + 1
		if group in wanted and bool(cell.get("alive", false)):
			after_by_group[group] = int(after_by_group.get(group, 0)) + 1
	var stats: Dictionary = castle.call("get_stats")
	# These are the exact structural-family outcomes under the same seven
	# direct removals. Small relief families are intentionally one local ornament
	# stack, so removing their first supporting cell drops that whole tiny family.
	# What matters here is that the detail pass does not spread the cascade into
	# adjacent masonry. Pass5 deliberately seats each pinnacle tip on its stack, so
	# the selected corner stack now carries (and releases) its one finial as well.
	var expected_before := {"south_merlon": 204, "tower_crown": 288,
		"gate_shield": 4, "keep_pinnacle31": 20, "gate38_gallery_merlon": 7,
		"gate38_slate_roof": 64, "gate38_pediment": 5}
	var expected_after := {"south_merlon": 201, "tower_crown": 285,
		"keep_pinnacle31": 15, "gate38_slate_roof": 47}
	if before_by_group != expected_before:
		failures.append("baseline_group_counts_changed")
	if after_by_group != expected_after:
		failures.append("baseline_cascade_changed")
	if int(stats.get("support_pending", 0)) != 0:
		failures.append("support_queue_not_drained")
	if int(stats.get("collapsed", 0)) != 66:
		failures.append("baseline_collapse_count_changed")
	print("ARCH_SUPPORT ", JSON.stringify({"selected": selected,
		"before": before_by_group, "after": after_by_group,
		"removed_by_group": removed_by_group,
		"collapsed": stats.get("collapsed", 0),
		"pending": stats.get("support_pending", 0), "failures": failures}))
	print("ARCH_SUPPORT_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
