extends SceneTree
## SHIP73: overboard rescue and deck-edge rail containment.

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
	# quarterdeck edge, starboard
	player.global_position = Vector3(118.0, 2.50, 984.0)
	player.set("_camera_yaw", 0.0)
	for i in 8:
		await physics_frame
	Input.action_press(&"preview_move_right")
	for i in 120:
		await physics_frame
	Input.action_release(&"preview_move_right")
	print("SHIP73_EDGE_Q x=", player.global_position.x, " y=", player.global_position.y,
		" local=", boat.call("local_of", player.global_position))
	# main deck edge
	player.global_position = Vector3(118.0, 1.30, 975.0)
	player.set("_camera_yaw", 0.0)
	for i in 8:
		await physics_frame
	Input.action_press(&"preview_move_right")
	for i in 120:
		await physics_frame
	Input.action_release(&"preview_move_right")
	print("SHIP73_EDGE_M x=", player.global_position.x, " y=", player.global_position.y,
		" local=", boat.call("local_of", player.global_position))
	# overboard rescue
	player.global_position = Vector3(115.0, -0.80, 978.0)
	for i in 12:
		await physics_frame
	print("SHIP73_OVERBOARD pos=", player.global_position, " floor=", player.is_on_floor())
	print("SHIP73_OK")
	quit(0)
