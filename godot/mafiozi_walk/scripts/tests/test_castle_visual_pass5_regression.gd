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
		print("CASTLE_PASS5_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var roof_count := 0
	var pinnacle_count := 0
	var pinnacle_tip_count := 0
	var tier_counts := [0, 0, 0, 0, 0]
	var tier_bounds: Array[Vector2] = []
	for tier: int in 5:
		tier_bounds.append(Vector2(INF, -INF))
	for value: Variant in castle.get("_cells"):
		var cell: Dictionary = value
		var group := str(cell.get("group", ""))
		var size: Vector3 = cell.get("size", Vector3.ZERO)
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		if group == "tower_roof55":
			roof_count += 1
			if size.distance_to(Vector3(9.6, 1.64, 9.6)) > 0.001 \
					or absf(at.y - 27.87) > 0.001 or at.y - size.y * 0.5 < 27.04:
				failures.append("tower_roof_profile")
		elif group == "keep_pinnacle31":
			pinnacle_count += 1
			var tier := int(cell.get("row", -1))
			if tier < 0 or tier > 4:
				failures.append("pinnacle_tier")
				continue
			tier_counts[tier] += 1
			var bounds := tier_bounds[tier]
			bounds.x = minf(bounds.x, at.y - size.y * 0.5)
			bounds.y = maxf(bounds.y, at.y + size.y * 0.5)
			tier_bounds[tier] = bounds
			var expected_width: float = [2.30, 1.86, 1.42, 1.02, 0.66][tier]
			if absf(size.x - expected_width) > 0.001 or absf(size.z - expected_width) > 0.001:
				failures.append("pinnacle_width")
			var rotation: Vector3 = cell.get("rotation", Vector3.ZERO)
			var expected_rotation := PI * 0.25 if tier % 2 == 1 else 0.0
			if absf(rotation.y - expected_rotation) > 0.001:
				failures.append("pinnacle_rotation")
		elif group == "keep_pinnacle_tip31":
			pinnacle_tip_count += 1
			if absf((at.y - size.y * 0.5) - 41.54) > 0.001:
				failures.append("pinnacle_tip_gap")
	if roof_count != 4 or pinnacle_count != 20 or tier_counts != [4, 4, 4, 4, 4]:
		failures.append("feature_counts")
	if pinnacle_tip_count != 4:
		failures.append("pinnacle_tip_count")
	for tier: int in 4:
		if tier_bounds[tier].y < tier_bounds[tier + 1].x:
			failures.append("pinnacle_vertical_gap")
	if tier_bounds[0].x > 38.24:
		failures.append("pinnacle_roof_gap")
	var roof_mesh: CylinderMesh = castle.get("_furniture_meshes").get("tower_roof55")
	if not is_instance_valid(roof_mesh) or roof_mesh.radial_segments != 12:
		failures.append("roof_facets")
	var roof_tint: Color = castle.call("_brick_tint", {"at": Vector3(67, 27.87, 67),
		"group": "tower_roof55", "material": "cold"})
	var plain_tint: Color = castle.call("_brick_tint", {"at": Vector3(67, 27.87, 67),
		"group": "plain", "material": "cold"})
	if roof_tint.get_luminance() >= plain_tint.get_luminance() * 0.90:
		failures.append("roof_slate_tint")
	if int(castle.call("get_stats").get("bricks", 0)) != 61886:
		failures.append("brick_budget_changed")
	print("CASTLE_PASS5 ", JSON.stringify({"roof_count": roof_count,
		"roof_segments": roof_mesh.radial_segments if is_instance_valid(roof_mesh) else -1,
		"pinnacles": pinnacle_count, "pinnacle_tips": pinnacle_tip_count,
		"tier_bounds": tier_bounds,
		"roof_tint": roof_tint, "plain_tint": plain_tint, "failures": failures}))
	print("CASTLE_PASS5_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
