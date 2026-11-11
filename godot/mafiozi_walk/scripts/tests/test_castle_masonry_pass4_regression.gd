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
		print("CASTLE_MASONRY4_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var tower_count := 0
	var crown_count := 0
	var merlon_count := 0
	var keep_merlon_count := 0
	var min_tower_cover := INF
	var min_crown_cover := INF
	var min_tower_height := INF
	var max_tower_axis_error := 0.0
	var crown_bounds := {0: Vector2(INF, -INF), 1: Vector2(INF, -INF)}
	var around := maxi(12, int(round(TAU * 5.6 / (1.0 * 0.98))))
	var half: float = castle.call("wall_half")
	for value: Variant in castle.get("_cells"):
		var cell: Dictionary = value
		var group := str(cell.get("group", ""))
		var size: Vector3 = cell.get("size", Vector3.ZERO)
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		if group == "tower":
			tower_count += 1
			var centre := Vector3(signf(at.x) * half, 0.0, signf(at.z) * half)
			var radius := Vector2(at.x - centre.x, at.z - centre.z).length()
			var required := 2.0 * (radius + size.x * 0.5) * tan(PI / float(around))
			min_tower_cover = minf(min_tower_cover, size.z / required)
			min_tower_height = minf(min_tower_height, size.y * 1.005)
			var visual: Transform3D = castle.call("_brick_transform", cell)
			var expected := Vector3(size.x * 0.995, size.y * 1.005, size.z)
			var measured := Vector3(visual.basis.x.length(), visual.basis.y.length(),
				visual.basis.z.length()) * Vector3(1.0, 0.54, 0.58)
			max_tower_axis_error = maxf(max_tower_axis_error, absf(measured.x - expected.x))
			max_tower_axis_error = maxf(max_tower_axis_error, absf(measured.y - expected.y))
			max_tower_axis_error = maxf(max_tower_axis_error, absf(measured.z - expected.z))
		elif group == "tower_crown":
			crown_count += 1
			var centre := Vector3(signf(at.x) * half, 0.0, signf(at.z) * half)
			var radius := Vector2(at.x - centre.x, at.z - centre.z).length()
			var required := 2.0 * (radius + size.x * 0.5) * tan(PI / float(around))
			min_crown_cover = minf(min_crown_cover, size.z / required)
			var tier := int(cell.get("row", -1))
			var bounds: Vector2 = crown_bounds[tier]
			bounds.x = minf(bounds.x, at.y - size.y * 0.5)
			bounds.y = maxf(bounds.y, at.y + size.y * 0.5)
			crown_bounds[tier] = bounds
		elif group == "tower_crown_merlon":
			merlon_count += 1
			if size.z <= size.x or absf((at.y - size.y * 0.5) - 27.0) > 0.001:
				failures.append("tower_merlon_orientation_or_support_edge")
		elif group == "keep_merlon":
			keep_merlon_count += 1
			if maxf(size.x, size.z) < 2.34:
				failures.append("keep_crenel_too_sparse")
	if tower_count != 7056 or crown_count != 288 or merlon_count != 72:
		failures.append("masonry_counts")
	if min_tower_cover < 1.02 or min_tower_height < 0.54:
		failures.append("tower_course_gap")
	if max_tower_axis_error > 0.001:
		failures.append("tower_local_axis_scale")
	if min_crown_cover < 1.02:
		failures.append("crown_tangential_gap")
	var lower: Vector2 = crown_bounds[0]
	var upper: Vector2 = crown_bounds[1]
	if lower.x > 27.001 or lower.y < upper.x or upper.y < 27.3:
		failures.append("crown_vertical_gap")
	if keep_merlon_count != 28:
		failures.append("keep_merlon_count")
	if int(castle.call("get_stats").get("bricks", 0)) != 61886:
		failures.append("brick_budget_changed")
	print("CASTLE_MASONRY4 ", JSON.stringify({"tower": tower_count,
		"crown": crown_count, "tower_merlons": merlon_count,
		"keep_merlons": keep_merlon_count, "tower_cover": min_tower_cover,
		"crown_cover": min_crown_cover, "tower_height": min_tower_height,
		"tower_axis_error": max_tower_axis_error,
		"crown_bounds": crown_bounds, "failures": failures}))
	print("CASTLE_MASONRY4_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
