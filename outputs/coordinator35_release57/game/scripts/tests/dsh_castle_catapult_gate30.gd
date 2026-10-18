extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	var castle: Node3D = scene.get("preview_castle")
	var catapult: Node3D = scene.get("preview_catapult")
	var errors: Array[String] = []
	catapult.place_near_castle(castle)
	for frame: int in 40: await physics_frame
	var before: Dictionary = castle.get_stats()
	catapult._set_stone_on_spoon()
	for frame: int in 60:
		await physics_frame
		if catapult.snapshot().stone_on_spoon: break
	var target: Vector3 = castle.global_position + Vector3(1.0, 3.4, castle.wall_half())
	catapult.aim_at(target)
	catapult._fire()
	var fired := false
	for frame: int in 420:
		await physics_frame
		if catapult.snapshot().flying: fired = true
		if fired and not catapult.snapshot().flying: break
	var after: Dictionary = castle.get_stats()
	var impact: Dictionary = catapult.snapshot().last_impact
	if not fired: errors.append("stone_never_flew")
	if not impact.get("ok", false) or not impact.get("castle", false): errors.append("no_castle_impact")
	if int(after.get("gate_boards_broken", 0)) <= int(before.get("gate_boards_broken", 0)):
		errors.append("gate_wood_did_not_break")
	if int(after.get("falling", 0)) <= 0: errors.append("no_flying_fragments")
	print("CASTLE_CATAPULT_GATE30 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors,
		"gate_boards_before": before.get("gate_boards_broken"), "gate_boards_after": after.get("gate_boards_broken"),
		"falling": after.get("falling"), "impact": impact}))
	await create_timer(0.3).timeout
	quit(0 if errors.is_empty() else 1)
