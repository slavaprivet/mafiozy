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
		print("CASTLE_PASS2_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var counts: Dictionary = {}
	var arch_top_stones := 0
	var pier_base := 0
	var pier_capital := 0
	var bracket_emphasis := 0
	var tower_height_sum := [0.0, 0.0, 0.0, 0.0]
	var tower_height_count := [0, 0, 0, 0]
	for value: Variant in castle.get("_cells"):
		var cell: Dictionary = value
		var group := str(cell.get("group", ""))
		counts[group] = int(counts.get(group, 0)) + 1
		var at: Vector3 = cell.get("at", Vector3.ZERO)
		var size: Vector3 = cell.get("size", Vector3.ZERO)
		if group == "entrance_arch31" and at.y > 15.65:
			arch_top_stones += 1
		elif group == "entrance_pier31":
			if size.x > 0.95:
				pier_base += 1
			elif size.x > 0.90:
				pier_capital += 1
		elif group == "gate38_machicolation":
			if absf((at.y - size.y * 0.5) - 19.655) > 0.001:
				failures.append("machicolation_support_edge_moved")
			if size.x > 0.60:
				bracket_emphasis += 1
		elif group == "tower_crown_merlon":
			if absf((at.y - size.y * 0.5) - 27.0) > 0.001:
				failures.append("tower_support_edge_moved")
			var corner_index := (1 if at.x > 0.0 else 0) + (2 if at.z > 0.0 else 0)
			tower_height_sum[corner_index] += size.y
			tower_height_count[corner_index] += 1
	if int(castle.call("get_stats").get("bricks", 0)) != 61886:
		failures.append("brick_count_changed")
	if int(counts.get("entrance_arch31", 0)) != 46 or arch_top_stones != 10:
		failures.append("entrance_arch_profile_changed")
	if int(counts.get("entrance_pier31", 0)) != 72 or pier_base != 16 or pier_capital != 12:
		failures.append("entrance_pier_profile_changed")
	if int(counts.get("gate38_machicolation", 0)) != 7 or bracket_emphasis != 3:
		failures.append("machicolation_rhythm_changed")
	var tower_averages: Array[float] = []
	for corner: int in 4:
		if int(tower_height_count[corner]) == 0:
			failures.append("tower_corner_missing")
			tower_averages.append(0.0)
		else:
			tower_averages.append(float(tower_height_sum[corner]) \
				/ float(tower_height_count[corner]))
	for left: int in 4:
		for right: int in range(left + 1, 4):
			if absf(tower_averages[left] - tower_averages[right]) < 0.025:
				failures.append("tower_profiles_not_distinct")
	var repair_a: Color = castle.call("_brick_tint", {
		"at": Vector3(-52.0, 9.0, 68.0), "material": "stone", "group": "south_wall"})
	var repair_b: Color = castle.call("_brick_tint", {
		"at": Vector3(-52.0, 9.0, 68.0), "material": "stone", "group": "south_wall"})
	if not repair_a.is_equal_approx(repair_b):
		failures.append("regional_tint_nondeterministic")
	print("CASTLE_PASS2 ", JSON.stringify({"counts": {
		"entrance_arch31": counts.get("entrance_arch31", 0),
		"entrance_pier31": counts.get("entrance_pier31", 0),
		"gate38_machicolation": counts.get("gate38_machicolation", 0),
		"tower_crown_merlon": counts.get("tower_crown_merlon", 0)},
		"arch_top_stones": arch_top_stones, "pier_base": pier_base,
		"pier_capital": pier_capital, "bracket_emphasis": bracket_emphasis,
		"tower_averages": tower_averages, "failures": failures}))
	print("CASTLE_PASS2_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
