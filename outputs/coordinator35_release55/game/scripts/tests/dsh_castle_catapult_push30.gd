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
	var player: CharacterBody3D = scene.get("_player")
	var errors: Array[String] = []
	player.set_mouse_captured(true)
	for frame: int in 120: await physics_frame
	var travelled: Array[float] = []
	var helpers: Array[CharacterBody3D] = []
	for crew: int in [0, 2]:
		catapult.place_near_castle(castle)
		var cart: CharacterBody3D = catapult.get("_cart")
		var start: Vector3 = cart.global_position
		player.global_position = start + Vector3(0.0, 0.05, -1.75)
		player._visual.rotation.y = 0.0
		for i: int in crew:
			var helper := CharacterBody3D.new()
			helper.position = start + Vector3(-0.55 if i == 0 else 0.55, 0.05, -1.7)
			helper.velocity = Vector3(0.0, 0.0, 1.2)
			helper.add_to_group("catapult_pushers")
			scene.add_child(helper)
			helpers.append(helper)
		Input.action_press(player.ACTION_FORWARD)
		for frame: int in 120: await physics_frame
		Input.action_release(player.ACTION_FORWARD)
		travelled.append(cart.global_position.distance_to(start))
		for helper: CharacterBody3D in helpers: helper.queue_free()
		helpers.clear()
		for frame: int in 3: await physics_frame
	if travelled[0] <= 0.05: errors.append("one_player_cannot_move_cart")
	if travelled[1] <= travelled[0] * 1.12: errors.append("extra_pushers_do_not_help")
	if float(catapult.snapshot().get("cart_mass", 0.0)) < 500.0: errors.append("cart_has_no_mass")
	var cart: CharacterBody3D = catapult.get("_cart")
	catapult.place_near_castle(castle)
	var gate_z: float = castle.global_position.z + castle.wall_half()
	cart.global_position = Vector3(castle.global_position.x, 0.05, gate_z - 2.6)
	player.global_position = cart.global_position + Vector3(0.0, 0.05, -1.8)
	Input.action_press(player.ACTION_FORWARD)
	for frame: int in 150: await physics_frame
	Input.action_release(player.ACTION_FORWARD)
	if cart.global_position.z > gate_z - 1.0: errors.append("cart_crossed_closed_gate")
	var stopped_at: Vector3 = cart.global_position
	for frame: int in 90: await physics_frame
	if cart.global_position.distance_to(stopped_at) > 0.55: errors.append("cart_does_not_settle")
	print("CASTLE_CATAPULT_PUSH30 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors,
		"travelled_one": travelled[0], "travelled_three": travelled[1], "mass": catapult.CART_MASS,
		"gate_z": gate_z, "cart_at_gate": cart.global_position.z}))
	await create_timer(0.3).timeout
	quit(0 if errors.is_empty() else 1)
