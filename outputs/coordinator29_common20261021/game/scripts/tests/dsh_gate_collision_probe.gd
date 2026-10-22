extends SceneTree
## Collision audit for the gate props: does the cauldron or the stone pile start inside
## castle masonry, and does the cauldron body overlap static collision?

const Layout = preload("res://scripts/siege/gate_defense_layout.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and game.get("preview_ready") != true:
		await process_frame
	for i: int in 30:
		await physics_frame
	var castle: Node3D = game.get("preview_castle") as Node3D
	var cauldron: Node3D = castle.get("_gate_cauldron") as Node3D
	var hatch: Node3D = castle.get("_stone_hatch") as Node3D
	var sally: Node3D = castle.get("_sally_port") as Node3D
	print("COLLISION_CASTLE_ORIGIN ", castle.global_position)
	var cells: Array = castle.get("_cells")
	var cauldron_box := _world_box(castle, Vector3(-2.65, 20.0, 69.1), Vector3(-1.05, 22.0, 70.8))
	var hatch_box := _world_box(castle, Vector3(0.75, 19.9, 69.95), Vector3(2.05, 21.0, 71.25))
	var sally_box := _world_box(castle, Vector3(-9.2, 0.0, 67.1), Vector3(-7.2, 2.7, 68.9))
	var cauldron_hits: Array[String] = []
	var hatch_hits: Array[String] = []
	var sally_hits: Array[String] = []
	for cell: Dictionary in cells:
		if not bool(cell.get("alive", false)):
			continue
		var group := str(cell.get("group", ""))
		var at: Vector3 = castle.to_global(cell.get("at", Vector3.ZERO))
		var size: Vector3 = cell.get("size", Vector3.ONE)
		var box := AABB(at - size * 0.5, size)
		if cauldron_box.intersects(box) and ("merlon" in group or "crown" in group \
				or group.begins_with("gatehouse")):
			cauldron_hits.append("%s %s" % [group, at])
		if hatch_box.intersects(box) and ("merlon" in group or "crown" in group \
				or group.begins_with("gatehouse")):
			hatch_hits.append("%s %s" % [group, at])
		if sally_box.intersects(box) and (group.begins_with("gatehouse") or "merlon" in group):
			sally_hits.append("%s %s" % [group, at])
	print("COLLISION_CELLS ", JSON.stringify({
		"cauldron": cauldron_hits, "hatch": hatch_hits, "sally": sally_hits}))

	if cauldron != null:
		var body: AnimatableBody3D = cauldron.get("_body") as AnimatableBody3D
		var space := body.get_world_3d().direct_space_state
		var params := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.45, 1.55, 1.30)
		params.shape = shape
		params.transform = body.global_transform * Transform3D(Basis.IDENTITY,
			Vector3(0.0, 0.78, 0.0))
		params.exclude = [body.get_rid()]
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var hits := space.intersect_shape(params, 24)
		var names: Array[String] = []
		for hit: Dictionary in hits:
			var collider: Object = hit.get("collider")
			if collider is Node:
				var node := collider as Node
				var info := "%s meta=%s" % [node.name, str(node.get_meta("surface", ""))]
				if node is StaticBody3D:
					for child: Node in node.get_children():
						if child is CollisionShape3D:
							info += " shape_pos=%s" % str((child as CollisionShape3D).global_position)
				names.append(info)
		print("COLLISION_OVERLAP ", JSON.stringify({"cauldron_body": names}))

	# A body in front of the cauldron must stop the push, not be passed through.
	var can_before: bool = bool(cauldron.call("_can_move_to",
		float(cauldron.call("get_stats").get("z", Layout.CAULDRON_START.z)) + 0.3))
	var blocker := StaticBody3D.new()
	var cauldron_body: Node3D = cauldron.get("_body") as Node3D
	blocker.position = cauldron_body.position + Vector3(0.0, 0.95, 0.55)
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(1.6, 1.4, 0.8)
	blocker_shape.shape = blocker_box
	blocker.add_child(blocker_shape)
	castle.add_child(blocker)
	await physics_frame
	await physics_frame
	await physics_frame
	var can_blocked: bool = bool(cauldron.call("_can_move_to",
		float(cauldron.call("get_stats").get("z", Layout.CAULDRON_START.z)) + 0.3))
	blocker.queue_free()
	# The dressed jambs close the 2 m brick opening to the 1.3 m leaf.
	var space2 := castle.get_world_3d().direct_space_state
	var jamb := PhysicsShapeQueryParameters3D.new()
	var jamb_shape := BoxShape3D.new()
	jamb_shape.size = Vector3(0.30, 2.0, 1.0)
	jamb.shape = jamb_shape
	jamb.transform = Transform3D(Basis.IDENTITY, castle.to_global(Vector3(-9.025, 1.0, 68.0)))
	var jamb_hits := space2.intersect_shape(jamb, 4).size()
	var passage := PhysicsShapeQueryParameters3D.new()
	var passage_shape := BoxShape3D.new()
	passage_shape.size = Vector3(1.20, 1.60, 0.40)
	passage.shape = passage_shape
	passage.transform = Transform3D(Basis.IDENTITY, castle.to_global(Vector3(-8.2, 1.30, 67.6)))
	var passage_hits := space2.intersect_shape(passage, 4)
	var passage_names: Array[String] = []
	for hit: Dictionary in passage_hits:
		var collider: Object = hit.get("collider")
		if collider is Node:
			var node := collider as Node
			var text := str(node.name) + " pos=" + str((node as Node3D).global_position)
			if node is StaticBody3D:
				for child: Node in node.get_children():
					if child is CollisionShape3D:
						var shape := (child as CollisionShape3D)
						text += " shape_pos=" + str(shape.global_position)
						if shape.shape is BoxShape3D:
							text += " size=" + str((shape.shape as BoxShape3D).size)
			passage_names.append(text)
	print("COLLISION_BEHAVIOUR ", JSON.stringify({"can_before": can_before,
		"can_blocked": can_blocked, "jamb_hits": jamb_hits,
		"passage_hits": passage_hits.size(), "passage": passage_names,
		"pass": can_before and not can_blocked and jamb_hits > 0 and passage_hits.is_empty()}))
	quit(0)


func _world_box(castle: Node3D, low: Vector3, high: Vector3) -> AABB:
	var a := castle.to_global(low)
	var b := castle.to_global(high)
	return AABB(Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)),
		Vector3(absf(b.x - a.x), absf(b.y - a.y), absf(b.z - a.z)))
