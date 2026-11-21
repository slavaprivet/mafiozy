extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var errors: Array[String] = []
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while (scene.get("preview_ready") != true or not is_instance_valid(scene.get("preview_power_barrels"))
			or not is_instance_valid(scene.get("preview_ship"))) and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.get("preview_ready") != true:
		print("CARRY_DROP_HINTS FAIL scene_not_ready")
		quit(1)
		return
	var player: CharacterBody3D = scene.get("_player")
	var barrels: Node3D = scene.get("preview_power_barrels")
	var ship: Node3D = scene.get("preview_ship")
	var barrel_list: Array = barrels.get("barrels")
	if barrel_list.is_empty() or not barrels.pick_up(barrel_list[0]):
		errors.append("barrel_pickup")
	else:
		for frame: int in 2: await physics_frame
		var action: Dictionary = scene.call("_current_door_action")
		if str(action.get("label", "")) != "Поставить бочку · G — бросить": errors.append("barrel_label")
		scene.call("_update_door_hint")
		scene.call("_position_door_hint")
		var panel: Control = scene.get("_door_hint_panel")
		var first: Vector2 = panel.position
		player.global_position += Vector3(0.8, 0.0, 0.0)
		scene.call("_position_door_hint")
		if not panel.visible or panel.position != first: errors.append("barrel_label_jitters")
		barrels.throw_carried()
	ship.call("_set_carry_ball", true)
	for frame: int in 2: await physics_frame
	var ball_action: Dictionary = scene.call("_current_door_action")
	if str(ball_action.get("key", "")) != "G" or str(ball_action.get("label", "")) != "Бросить ядро":
		errors.append("ball_label")
	ship.call("_set_carry_ball", false)
	print("CARRY_DROP_HINTS ", "PASS" if errors.is_empty() else "FAIL " + str(errors))
	quit(0 if errors.is_empty() else 1)
