extends SceneTree
## SHIP61 interior and gunnery visual check.

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
		print("SHIP61_LOOK2_FAIL no_host")
		quit(1)
		return
	for i in 30:
		await process_frame
	var boat: Node3D = host.get("boat")
	var player: Node3D = scene.get("_player")
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 500.0
	scene.add_child(camera)
	# The cabin, from the companionway looking aft at the two crates.
	camera.global_position = boat.to_global(Vector3(0.0, 1.75, 6.3))
	camera.look_at(boat.to_global(Vector3(0.0, 1.1, 10.4)), Vector3.UP)
	camera.current = true
	for i in 14:
		await process_frame
	_shot("cabin")
	# The upper deck / fighting top.
	camera.global_position = boat.to_global(Vector3(2.4, 6.4, 2.6))
	camera.look_at(boat.to_global(Vector3(0.0, 5.6, -2.0)), Vector3.UP)
	for i in 14:
		await process_frame
	_shot("upper_deck")
	# The bow platform, looking back down the ship.
	camera.global_position = boat.to_global(Vector3(0.0, 3.2, -14.4))
	camera.look_at(boat.to_global(Vector3(0.0, 2.4, -2.0)), Vector3.UP)
	for i in 14:
		await process_frame
	_shot("bow_platform")
	# Back to the player's camera for the gunner's own view.
	camera.current = false
	var player_camera := player.get("_camera") as Camera3D
	if is_instance_valid(player_camera):
		player_camera.current = true
	# The port battery, aimed at the castle.
	host.call("debug_set_station", "cannon", 0)
	await physics_frame
	await physics_frame
	for i in 10:
		await process_frame
	_shot("cannon_aim")
	# Broadside: four shots at the east wall, then look at the breach.
	for i in 4:
		host.call("debug_fire_at", Vector3(60.0, 9.0, 900.0 + float(i) * 12.0 - 18.0))
		for f in 30:
			await process_frame
	camera.global_position = boat.to_global(Vector3(-10.0, 10.0, 6.0))
	camera.look_at(Vector3(64.0, 8.0, 900.0), Vector3.UP)
	for i in 20:
		await process_frame
	_shot("broadside")
	print("SHIP61_LOOK2_OK")
	quit(0)
