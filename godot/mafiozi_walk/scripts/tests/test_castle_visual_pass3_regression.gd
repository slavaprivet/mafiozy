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
		print("CASTLE_PASS3_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var tower_count := 0
	var tower_non_stone := 0
	for value: Variant in castle.get("_cells"):
		var cell: Dictionary = value
		if str(cell.get("group", "")) == "tower":
			tower_count += 1
			if str(cell.get("material", "")) != "stone":
				tower_non_stone += 1
	if tower_count < 7000 or tower_non_stone != 0:
		failures.append("tower_material_noise")
	if int(castle.call("get_stats").get("bricks", 0)) != 61886:
		failures.append("brick_budget_changed")
	var bars: MultiMeshInstance3D = castle.get_node_or_null("BannerBars")
	var flags: MultiMeshInstance3D = castle.get_node_or_null("HangingBanners")
	var devices: MultiMeshInstance3D = castle.get_node_or_null("BannerDevices")
	if not is_instance_valid(bars) or bars.multimesh.instance_count != 13:
		failures.append("keep_banner_bars")
	if not is_instance_valid(flags) or flags.multimesh.instance_count != 13:
		failures.append("keep_banner_cloth")
	if not is_instance_valid(devices) or devices.multimesh.instance_count != 52:
		failures.append("keep_banner_devices")
	var centre_mod: Vector3 = castle.call("_keep_hierarchy_modulation",
		Vector3(0.0, 20.0, 5.0))
	var wing_mod: Vector3 = castle.call("_keep_hierarchy_modulation",
		Vector3(8.0, 20.0, 5.0))
	if centre_mod.x <= 1.02 or wing_mod.x >= 0.99:
		failures.append("keep_hierarchy_tint")
	var axis: Color = castle.call("_courtyard_brick_tint", 0.0, 30.0, 1.0)
	var neutral: Color = castle.call("_courtyard_brick_tint", 20.0, 30.0, 1.0)
	var edge: Color = castle.call("_courtyard_brick_tint", 65.0, 30.0, 1.0)
	if axis.get_luminance() <= neutral.get_luminance() * 1.02 \
			or edge.get_luminance() >= neutral.get_luminance() * 0.97:
		failures.append("courtyard_composition_tint")
	print("CASTLE_PASS3 ", JSON.stringify({"tower_count": tower_count,
		"tower_non_stone": tower_non_stone, "banners": [
			bars.multimesh.instance_count if is_instance_valid(bars) else -1,
			flags.multimesh.instance_count if is_instance_valid(flags) else -1,
			devices.multimesh.instance_count if is_instance_valid(devices) else -1],
		"keep_modulation": {"centre": centre_mod, "wing": wing_mod},
		"floor": {"axis": axis, "neutral": neutral, "edge": edge},
		"failures": failures}))
	print("CASTLE_PASS3_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
