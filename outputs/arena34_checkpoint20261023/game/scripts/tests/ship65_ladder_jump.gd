extends SceneTree
## SHIP65: jump on deck and walkable ladder up/down.

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
	print("SHIP65_START pos=", player.global_position, " floor=", player.is_on_floor(),
		" vehicle=", player.get("_vehicle_hold"), " station=", player.get("_station_hold"),
		" authority=", player.get("_pose_authority"), " free=", player.get("_free_mouse_look"))
	player.set("_free_mouse_look", true)
	player.call("_request_preview_jump", Time.get_ticks_msec())
	await physics_frame
	print("SHIP65_JUMP_DIRECT jump=", player.get("_jump"), " dy=", player.velocity.y)
	var before: Vector3 = player.global_position
	Input.action_press(&"preview_jump")
	await physics_frame
	await physics_frame
	Input.action_release(&"preview_jump")
	for i in 12:
		await physics_frame
	print("SHIP65_JUMP dy=", player.global_position.y - before.y, " floor=", player.is_on_floor(),
		" jump=", player.get("_jump"), " air=", player.get("_airborne") != null)
	# Ladder base -> up.
	player.global_position = boat.call("world_deck", Vector3(0.0, 1.80, 2.30))
	for i in 6:
		await physics_frame
	var b0: Vector3 = player.global_position
	Input.action_press(&"preview_move_forward")
	for i in 150:
		await physics_frame
	Input.action_release(&"preview_move_forward")
	var b1: Vector3 = player.global_position
	print("SHIP65_LADDER_UP before=", b0, " after=", b1, " dy=", b1.y - b0.y)
	# Ladder top -> down.
	player.global_position = boat.call("world_deck", Vector3(0.0, 5.28, 1.95))
	for i in 10:
		await physics_frame
	var t0: Vector3 = player.global_position
	Input.action_press(&"preview_move_back")
	for i in 150:
		await physics_frame
	Input.action_release(&"preview_move_back")
	var t1: Vector3 = player.global_position
	print("SHIP65_LADDER_DOWN before=", t0, " after=", t1, " dy=", t1.y - t0.y)
	# Walk up the hidden ramp from the deck (no teleport into the ladder zone).
	player.global_position = boat.to_global(Vector3(0.0, 1.82, 4.20))
	player.set("_camera_yaw", 0.0)
	for i in 8:
		await physics_frame
	var w0: Vector3 = player.global_position
	Input.action_press(&"preview_move_forward")
	for i in 200:
		await physics_frame
	Input.action_release(&"preview_move_forward")
	var w1: Vector3 = player.global_position
	print("SHIP65_RAMP_UP before=", w0, " after=", w1, " dy=", w1.y - w0.y)
	# Walk down from the fighting top onto the ramp and to the main deck.
	player.global_position = boat.to_global(Vector3(0.0, 5.30, 1.35))
	player.set("_camera_yaw", 0.0)
	for i in 8:
		await physics_frame
	var d0: Vector3 = player.global_position
	Input.action_press(&"preview_move_back")
	for i in 220:
		await physics_frame
	Input.action_release(&"preview_move_back")
	var d1: Vector3 = player.global_position
	print("SHIP65_RAMP_DOWN before=", d0, " after=", d1, " dy=", d1.y - d0.y)
	print("SHIP65_OK")
	quit(0)
