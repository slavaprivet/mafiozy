extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var castle: Node = scene.get("preview_castle")
	if not is_instance_valid(castle):
		print("CASTLE_JUNCTION6_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var corner_walks := 0
	var wall_walks := 0
	var min_corner_overlap := INF
	var min_deck_overlap := INF
	var max_axis_leak := 0.0
	var stair_width := INF
	var landing_width := INF
	var walk_outer := -INF
	var stair_walk_inner := INF
	var wide_walks := 0
	var rail_outer := -INF
	var merlon_inner := INF
	var nominal_span := 136.0 / 28.0
	for value: Variant in castle.get("_cells"):
		var cell: Dictionary = value
		var group := str(cell.get("group", ""))
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		var size: Vector3 = cell.get("size", Vector3.ZERO)
		if group == "corner_walk":
			corner_walks += 1
			var outward_edge := absf(at.x) + size.x * 0.5 if absf(at.x) < absf(at.z) \
				else absf(at.z) + size.z * 0.5
			min_corner_overlap = minf(min_corner_overlap, outward_edge - 62.75)
		if group in ["north_walk", "south_walk", "east_walk", "west_walk"]:
			wall_walks += 1
			var along_size := size.x if group in ["north_walk", "south_walk"] else size.z
			min_deck_overlap = minf(min_deck_overlap, along_size - nominal_span)
			walk_outer = maxf(walk_outer, absf(at.z) + size.z * 0.5 if group in ["north_walk", "south_walk"] else absf(at.x) + size.x * 0.5)
			var cross_size := size.z if group in ["north_walk", "south_walk"] else size.x
			if cross_size > 4.5:
				wide_walks += 1
			elif group == "north_walk":
				stair_walk_inner = minf(stair_walk_inner, absf(at.z) - size.z * 0.5)
		if group in ["stairs_north", "stairs_south", "stairs_east", "stairs_west"]:
			stair_width = minf(stair_width, size.x if group in ["stairs_north", "stairs_south"] else size.z)
		if group.begins_with("stair_landing_"):
			landing_width = minf(landing_width, size.x if group in ["stair_landing_north", "stair_landing_south"] else size.z)
		if group == "north_parapet" and absf(at.x) < 10.0:
			rail_outer = maxf(rail_outer, absf(at.z) + size.z * 0.5)
		if group == "north_merlon" and int(cell.get("row", -1)) == 0:
			merlon_inner = minf(merlon_inner, absf(at.z) - size.z * 0.5)
		var aligned := group.ends_with("_walk") or group.ends_with("_parapet") \
			or group in ["corner_walk", "corner_parapet", "gate_bypass", "gate_bypass_pier"]
		if aligned:
			var visual: Transform3D = castle.call("_brick_transform", cell)
			max_axis_leak = maxf(max_axis_leak, absf(visual.basis.x.y))
			max_axis_leak = maxf(max_axis_leak, absf(visual.basis.x.z))
			max_axis_leak = maxf(max_axis_leak, absf(visual.basis.y.x))
			max_axis_leak = maxf(max_axis_leak, absf(visual.basis.y.z))
			max_axis_leak = maxf(max_axis_leak, absf(visual.basis.z.x))
			max_axis_leak = maxf(max_axis_leak, absf(visual.basis.z.y))
	if corner_walks != 8 or min_corner_overlap < 0.09:
		failures.append("corner_tower_floor_gap")
	if wall_walks != 112 or min_deck_overlap < 0.04:
		failures.append("wall_walk_span_gap")
	if max_axis_leak > 0.00001:
		failures.append("walk_visual_collision_misalignment")
	if stair_width < 3.55 or landing_width < 4.95:
		failures.append("stair_landing_too_narrow")
	if merlon_inner - rail_outer < 2.7 or absf(walk_outer - 68.95) > 0.05:
		failures.append("wall_walk_clearance")
	if wide_walks < 104 or stair_walk_inner < 65.9:
		failures.append("stair_ramp_notch")
	if int(castle.call("get_stats").get("bricks", 0)) != 61886:
		failures.append("brick_budget_changed")
	print("CASTLE_JUNCTION6 ", JSON.stringify({"corner_walks": corner_walks,
		"wall_walks": wall_walks, "corner_overlap": min_corner_overlap,
		"deck_overlap": min_deck_overlap, "axis_leak": max_axis_leak,
		"stair_width": stair_width, "landing_width": landing_width,
		"walk_outer": walk_outer, "clear_width": merlon_inner - rail_outer,
		"wide_walks": wide_walks, "stair_walk_inner": stair_walk_inner,
		"failures": failures}))
	print("CASTLE_JUNCTION6_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
