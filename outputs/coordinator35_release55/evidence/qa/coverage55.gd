extends SceneTree

var scene: Node3D
var castle: Node3D
var out := ""
var errors: Array[String] = []
var results := {}

func _initialize() -> void: call_deferred("_run")

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	scene = load("res://scenes/castle.tscn").instantiate(); root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 75000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline: await process_frame
	castle = scene.get("preview_castle")
	if not is_instance_valid(castle): errors.append("not_ready"); finish(); return
	await ticks(10)
	var cells: Array = castle.get("_cells")
	var groups: Array[String] = ["north", "south", "east", "west", "tower", "gatehouse", "keep",
		"keep_partition", "corner_pier", "gate_bypass_pier", "room_wall_pier", "room_pier_cap", "room_vault",
		"keep_sill55", "gate_corbel55", "tower_floor55", "tower_roof55"]
	for cell: Dictionary in cells:
		var g: String = cell.group
		var decoration := g.begins_with("entrance_") or g.begins_with("gate38_") or g.begins_with("wall_arcade") or g.begins_with("curtain_trim")
		decoration = decoration or "buttress" in g or "corbel" in g or "quoin" in g or "merlon" in g or "plinth" in g or "parapet" in g or "crown" in g or "pinnacle" in g or g.begins_with("stairs_pier_") or g.begins_with("keep_window") or g.begins_with("gate_jamb")
		if decoration and g not in groups and cell.material in ["stone", "warm", "cold", "dark", "ochre"]: groups.append(g)
	var measures := []
	for group: String in groups:
		var chosen := -1
		var total := 0
		for i: int in cells.size():
			if cells[i].group != group: continue
			total += 1
			if cells[i].alive and chosen < 0: chosen = i
		if total == 0: errors.append("missing_group:" + group); continue
		if chosen < 0: measures.append({"group": group, "all_already_destroyed": true}); continue
		var cell: Dictionary = cells[chosen]
		var size: Vector3 = cell.size
		# Strike a real edge/foot, not the cell centre. Side faces are independent
		# of _cell_distance55 and exercise long members across spatial buckets.
		var offset := Vector3(size.x * 0.5, 0, 0)
		if size.y > 3.0: offset = Vector3(size.x * 0.5, -size.y * 0.5 + 0.4, 0)
		if group == "tower_roof55": offset = Vector3(0.8, size.y * 0.5, 0)
		var point: Vector3 = cell.at + Basis.from_euler(cell.rotation) * offset
		var start := Time.get_ticks_usec()
		var response: Dictionary = castle.apply_explosion({"position": castle.to_global(point), "radius": 0.85, "power": 240.0, "direction": Vector3.FORWARD, "event_id": "coverage:" + group})
		var cost_ms := float(Time.get_ticks_usec() - start) / 1000.0
		await ticks(2)
		var alive: bool = cells[chosen].alive
		if alive: errors.append("edge_did_not_break:" + group)
		var collider_disabled := true
		var owned_shape: CollisionShape3D = castle.get("_masonry_shapes55").get(chosen)
		if is_instance_valid(owned_shape): collider_disabled = owned_shape.disabled
		if not collider_disabled: errors.append("dead_shape_active:" + group)
		measures.append({"group": group, "index": chosen, "alive_after": alive, "owned_shape_disabled": collider_disabled, "apply_ms": cost_ms, "response": response})
	results.groups = measures
	# Geometric narrowphase: empty corners of a circular platform/roof are air.
	for cell: Dictionary in cells:
		if cell.group == "tower_floor55":
			var distance: float = castle._cell_distance55(cell, cell.at + Vector3(5, 0, 5))
			results.cylinder_corner_distance = distance
			if distance <= 1.0: errors.append("cylinder_empty_corner_hit")
			break
	for cell: Dictionary in cells:
		if cell.group == "tower_roof55":
			var distance: float = castle._cell_distance55(cell, cell.at + Vector3(5, 1.2, 0))
			results.roof_corner_distance = distance
			if distance <= 1.0: errors.append("roof_empty_corner_hit")
			break
	await ticks(140)
	var remaining_dead_shapes := 0
	for index: int in castle.get("_masonry_shapes55"):
		var shape: CollisionShape3D = castle.get("_masonry_shapes55")[index]
		if not cells[index].alive and is_instance_valid(shape) and not shape.disabled: remaining_dead_shapes += 1
	results.dead_shapes_active_after_cascade = remaining_dead_shapes
	if remaining_dead_shapes > 0: errors.append("cascade_ghost_collision")
	results.stats = castle.get_stats()
	results.exact_shapes = castle.get("_masonry_shapes55").size()
	results.compound_bodies = castle.get("_masonry_bodies55").size()
	results.performance_limit = "Functional run beside user game; apply times include headless scheduling and are not clean game FPS."
	finish()

func finish() -> void:
	var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(JSON.stringify({"passed": errors.is_empty(), "errors": errors, "results": results}, "\t")); f.close()
	print("COVERAGE55 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors})); quit(0 if errors.is_empty() else 1)
