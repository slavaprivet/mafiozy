extends SceneTree

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
	player.global_position = boat.call("_world_from_local", Vector3(0.0, 0.62, 6.01))
	player.set("_camera_yaw", 0.0)
	for i in 8:
		await physics_frame
	Input.action_press(&"preview_move_forward")
	for i in 60:
		await physics_frame
		if i % 10 == 0:
			print("SHIP78_STEP ", i, " local=", boat.call("local_of", player.global_position))
	Input.action_release(&"preview_move_forward")
	print("SHIP78_CABIN_TOP local=", boat.call("local_of", player.global_position))
	var act: Dictionary = host.call("action")
	player.global_position = boat.call("_world_from_local", Vector3(0.5, 0.62, 9.5))
	for i in 8:
		await physics_frame
	act = host.call("action")
	print("SHIP78_F_ACTION ", JSON.stringify(act))
	quit(0)
