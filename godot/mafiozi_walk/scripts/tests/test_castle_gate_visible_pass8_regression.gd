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
		print("CASTLE_GATE_VISIBLE8_RESULT FAIL castle")
		quit(1)
		return
	await process_frame
	await process_frame
	var failures: Array[String] = []
	var materials: Dictionary = castle.get("_materials")
	var wood: StandardMaterial3D = materials.get("wood")
	var wood_alt: StandardMaterial3D = materials.get("wood_alt")
	var gate_wood: StandardMaterial3D = materials.get("gate_wood")
	var gate_wood_alt: StandardMaterial3D = materials.get("gate_wood_alt")
	if gate_wood == null or gate_wood_alt == null:
		failures.append("gate_materials_missing")
	else:
		var contrast := Vector3(gate_wood.albedo_color.r, gate_wood.albedo_color.g,
			gate_wood.albedo_color.b).distance_to(Vector3(gate_wood_alt.albedo_color.r,
			gate_wood_alt.albedo_color.g, gate_wood_alt.albedo_color.b))
		if contrast < 0.20:
			failures.append("gate_oak_contrast")
		if wood.albedo_color != Color(0.38, 0.24, 0.13) \
				or wood_alt.albedo_color != Color(0.33, 0.205, 0.11):
			failures.append("shared_oak_changed")
	var leaf_width := 9.2 * 0.5
	var left: Array = castle.call("_gate_cross_brace_specs", -1.0, leaf_width)
	var right: Array = castle.call("_gate_cross_brace_specs", 1.0, leaf_width)
	if left.size() != 2 or right.size() != 2:
		failures.append("brace_spec_count")
	else:
		for index: int in 2:
			var left_spec: Dictionary = left[index]
			var right_spec: Dictionary = right[index]
			if float((left_spec["size"] as Vector3).y) < 10.5:
				failures.append("brace_too_short")
			if absf(float((left_spec["at"] as Vector3).x)
					+ float((right_spec["at"] as Vector3).x)) > 0.0001:
				failures.append("brace_centres_not_mirrored")
			if absf(float(left_spec["angle"]) - float(right_spec["angle"])) > 0.0001:
				failures.append("brace_angles_not_equal")
	var leaves: Array = castle.get("_gate_leaves")
	var mesh_counts: Array[int] = []
	var multi_counts: Array[int] = []
	var stray_braces := 0
	for entry: Dictionary in leaves:
		var pivot: Node = entry.get("pivot")
		mesh_counts.append(pivot.find_children("*", "MeshInstance3D", true, false).size())
		multi_counts.append(pivot.find_children("*", "MultiMeshInstance3D", true, false).size())
		stray_braces += pivot.find_children("GateCross*", "Node", true, false).size()
	if mesh_counts != [2, 2]:
		failures.append("final_mesh_node_budget")
	if multi_counts != [4, 4]:
		failures.append("final_multimesh_budget")
	if stray_braces != 0:
		failures.append("braces_not_merged")
	if int(castle.call("_gate_board_colliders_active")) != 96:
		failures.append("collider_budget")
	print("CASTLE_GATE_VISIBLE8 ", JSON.stringify({"mesh_nodes": mesh_counts,
		"multi_nodes": multi_counts, "stray_braces": stray_braces,
		"active_colliders": castle.call("_gate_board_colliders_active"),
		"failures": failures}))
	print("CASTLE_GATE_VISIBLE8_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
