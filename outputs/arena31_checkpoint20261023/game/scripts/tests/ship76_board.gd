extends SceneTree
## SHIP76: boarding ladders from shore/water to the main deck.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var host: Node = null
	var host_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < host_deadline:
		host = scene.get("preview_ship")
		if is_instance_valid(host):
			break
		await process_frame
	for i in 50:
		await physics_frame
	var player: CharacterBody3D = scene.get("_player")
	var boat: Node3D = host.get("boat")
	var start: Vector3 = boat.call("_world_from_local", Vector3(4.90, 0.45, -3.0))
	player.global_position = start
	player.velocity = Vector3.ZERO
	for i in 12:
		await physics_frame
	Input.action_press(&"preview_move_forward")
	for i in 130:
		await physics_frame
	Input.action_release(&"preview_move_forward")
	print("SHIP76_BOARD_TOP local=", boat.call("local_of", player.global_position),
		" floor=", player.is_on_floor(), " zone=",
		boat.call("in_boarding_zone", player.global_position))
	# descend the same ladder
	Input.action_press(&"preview_move_back")
	for i in 130:
		await physics_frame
	Input.action_release(&"preview_move_back")
	print("SHIP76_BOARD_DOWN local=", boat.call("local_of", player.global_position),
		" zone=", boat.call("in_boarding_zone", player.global_position))
	print("SHIP76_BOARD_OK")
	quit(0)
