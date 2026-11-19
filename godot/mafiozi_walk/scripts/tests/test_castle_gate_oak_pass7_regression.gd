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
		print("CASTLE_GATE_OAK7_RESULT FAIL castle")
		quit(1)
		return
	var failures: Array[String] = []
	var tone_counts := {"wood": 0, "wood_alt": 0}
	var uniform_columns := 0
	for column: int in 6:
		var column_tones: Dictionary = {}
		for row: int in 8:
			var tone: String = castle.call("_gate_board_tone", row, column)
			tone_counts[tone] = int(tone_counts.get(tone, 0)) + 1
			column_tones[tone] = true
		if column_tones.size() < 2:
			uniform_columns += 1
	if tone_counts != {"wood": 36, "wood_alt": 12}:
		failures.append("tone_distribution")
	if uniform_columns != 0:
		failures.append("vertical_stripes")
	var leaves: Array = castle.get("_gate_leaves")
	if leaves.size() != 2:
		failures.append("leaf_count")
	var board_counts: Array[int] = []
	var bucket_counts: Array[int] = []
	var inner_piece_counts: Array[int] = []
	for entry: Dictionary in leaves:
		var boards: Array = entry.get("boards", [])
		var pivot: Node = entry.get("pivot")
		board_counts.append(boards.size())
		var mapped_slots: Dictionary = {}
		for board: Dictionary in boards:
			var multi: MultiMeshInstance3D = board.get("multi")
			var slot: int = int(board.get("slot", -1))
			var key := "%d:%d" % [multi.get_instance_id(), slot]
			if mapped_slots.has(key):
				failures.append("duplicate_board_slot")
			mapped_slots[key] = true
			if multi.get_parent() != pivot or slot < 0 or slot >= multi.multimesh.instance_count:
				failures.append("board_slot_mapping")
		var buckets := 0
		for child: Node in pivot.get_children():
			if child.name.begins_with("GateBoards_"):
				buckets += 1
		bucket_counts.append(buckets)
		var piece_count := 0
		for board: Dictionary in boards:
			piece_count += (board.get("inner40", []) as Array).size()
		inner_piece_counts.append(piece_count)
	if board_counts != [48, 48]:
		failures.append("board_count")
	if bucket_counts != [2, 2]:
		failures.append("bucket_count")
	if inner_piece_counts != [106, 106]:
		failures.append("reverse_piece_count")
	var board_w := 9.2 * 0.5 / 6.0
	for column: int in range(1, 6):
		var left_board_x := board_w * (float(column) + 0.5)
		var right_board_x := -board_w * (float(column) + 0.5)
		var left_seam: float = castle.call("_inner_gate_seam_x", left_board_x, board_w, -1.0)
		var right_seam: float = castle.call("_inner_gate_seam_x", right_board_x, board_w, 1.0)
		if absf(left_seam + right_seam) > 0.0001:
			failures.append("reverse_seam_mirror")
			break
	if int(castle.call("_gate_board_colliders_active")) != 96:
		failures.append("collider_count")
	var target_board: Dictionary = (leaves[0] as Dictionary).get("boards", [])[1]
	var state: Array = castle.call("gate_state")
	state[0]["b"][1] = true
	var changed: int = castle.call("apply_gate_state", state)
	await physics_frame
	if changed != 1 or int(castle.call("_gate_boards_broken")) != 1:
		failures.append("single_board_break")
	if int(castle.call("_gate_board_colliders_active")) != 95:
		failures.append("single_collider_disable")
	if int(castle.call("_gate_leaves_detached")) != 0:
		failures.append("unexpected_leaf_detach")
	if not bool(target_board.get("broken", false)):
		failures.append("target_board_flag")
	print("CASTLE_GATE_OAK7 ", JSON.stringify({"tone_counts": tone_counts,
		"uniform_columns": uniform_columns, "boards": board_counts,
		"buckets": bucket_counts, "inner_pieces": inner_piece_counts,
		"changed": changed,
		"active_colliders": castle.call("_gate_board_colliders_active"),
		"failures": failures}))
	print("CASTLE_GATE_OAK7_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
