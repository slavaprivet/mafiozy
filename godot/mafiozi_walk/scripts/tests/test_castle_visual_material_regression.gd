extends SceneTree

var _scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("CASTLE_VISUAL_RESULT FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	var castle: Node = _scene.get("preview_castle")
	if castle == null:
		print("CASTLE_VISUAL_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var materials: Dictionary = castle.get("_materials")
	for key: String in ["stone", "warm", "cold", "paving"]:
		var material := materials.get(key) as StandardMaterial3D
		if material == null or not material.vertex_color_use_as_albedo:
			failures.append("instance_color_disabled_" + key)
	var wood := materials.get("wood") as StandardMaterial3D
	if wood == null or wood.vertex_color_use_as_albedo:
		failures.append("wood_vertex_color_changed")
	var nonstone: Color = castle.call("_brick_tint", {
		"at": Vector3(4, 7, 3), "material": "iron", "group": "fitting"})
	if not nonstone.is_equal_approx(Color.WHITE):
		failures.append("nonstone_not_white")
	var low_total := 0.0
	var high_total := 0.0
	var minimum := INF
	var maximum := -INF
	for sample: int in 128:
		var x := -60.0 + float(sample % 32) * 3.75
		var z := -60.0 + float(sample / 32) * 40.0
		var low: Color = castle.call("_brick_tint", {
			"at": Vector3(x, 0.5, z), "material": "stone", "group": "south"})
		var high: Color = castle.call("_brick_tint", {
			"at": Vector3(x, 10.0, z), "material": "stone", "group": "south"})
		var repeated: Color = castle.call("_brick_tint", {
			"at": Vector3(x, 10.0, z), "material": "stone", "group": "south"})
		if not high.is_equal_approx(repeated):
			failures.append("nondeterministic_tint")
			break
		low_total += _luma(low)
		high_total += _luma(high)
		for value: float in [low.r, low.g, low.b, high.r, high.g, high.b]:
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
	if low_total >= high_total * 0.98:
		failures.append("damp_base_not_visible")
	if minimum < 0.76 or maximum > 1.10:
		failures.append("tint_out_of_bounds")
	var stats: Dictionary = castle.call("get_stats")
	if int(stats.get("bricks", 0)) != 61886:
		failures.append("cell_count_changed")
	print("CASTLE_VISUAL ", JSON.stringify({
		"bricks": stats.get("bricks", 0),
		"materials": materials.size(),
		"low_luma_mean": low_total / 128.0,
		"high_luma_mean": high_total / 128.0,
		"tint_min": minimum,
		"tint_max": maximum,
		"failures": failures}))
	print("CASTLE_VISUAL_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
