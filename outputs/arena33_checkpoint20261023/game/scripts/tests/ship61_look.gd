extends SceneTree
## SHIP61 visual check: the actual first view, the ship from the shore, and the deck.

const OUT := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_ship61"

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("DSHOT_FAIL ", name)
		return
	var path: String = OUT.path_join("ship61_%s.png" % name)
	image.save_png(path)
	print("DSHOT_SAVED ", path)

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
	if not is_instance_valid(host):
		print("SHIP61_LOOK_FAIL no_host status=", scene.get("ship_status"))
		quit(1)
		return
	for i in 30:
		await process_frame
	_shot("first_view")
	var boat: Node3D = host.get("boat")
	var ship_pos: Vector3 = boat.global_position
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.global_position = ship_pos + Vector3(-22.0, 9.0, 6.0)
	camera.look_at(ship_pos + Vector3(0.0, 4.0, 0.0), Vector3.UP)
	camera.current = true
	for i in 12:
		await process_frame
	_shot("ship_side")
	camera.global_position = ship_pos + Vector3(14.0, 8.0, -18.0)
	camera.look_at(ship_pos + Vector3(0.0, 4.0, 2.0), Vector3.UP)
	for i in 12:
		await process_frame
	_shot("ship_bow")
	# Back to the player's own camera and walk to the deck centre.
	var player: Node3D = scene.get("_player")
	camera.current = false
	player.global_position = boat.to_global(Vector3(0.0, 1.85, 2.0))
	player.velocity = Vector3.ZERO
	for i in 30:
		await process_frame
	_shot("deck")
	print("SHIP61_LOOK_OK")
	quit(0)
