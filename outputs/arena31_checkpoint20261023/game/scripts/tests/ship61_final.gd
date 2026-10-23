extends SceneTree
## SHIP61 final showcase: hero, sails, breach, sinking.

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
		print("SHIP61_FINAL_FAIL no_host")
		quit(1)
		return
	for i in 60:
		await physics_frame
	var boat: Node3D = host.get("boat")
	var ship_pos: Vector3 = boat.global_position
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.current = true
	# Hero: sails open, ship from the sea, castle behind.
	host.call("interact", "ship_sail")
	for i in 90:
		await physics_frame
	camera.global_position = ship_pos + Vector3(24.0, 11.0, 24.0)
	camera.look_at(ship_pos + Vector3(-4.0, 5.0, -6.0), Vector3.UP)
	for i in 20:
		await process_frame
	_shot("final_hero")
	# The deck with canvas set.
	camera.global_position = ship_pos + Vector3(2.0, 7.5, 18.0)
	camera.look_at(ship_pos + Vector3(0.0, 5.0, -4.0), Vector3.UP)
	for i in 16:
		await process_frame
	_shot("final_sails")
	# Broadside at the east wall, then the breach.
	for i in 6:
		host.call("debug_fire_at", Vector3(68.0, 7.5, 878.0 + float(i) * 11.0))
		for f in 55:
			await physics_frame
	var stats: Dictionary = scene.get("preview_castle").call("get_stats")
	print("SHIP61_FINAL_CASTLE detached=", stats.get("detached", 0), " falling=", stats.get("falling", 0))
	camera.global_position = Vector3(104.0, 9.0, 930.0)
	camera.look_at(Vector3(66.0, 7.0, 905.0), Vector3.UP)
	for i in 30:
		await process_frame
	_shot("final_breach")
	# Damage and sink her.
	host.call("debug_hit_ship", 5)
	var sunk := false
	for i in 1400:
		boat.call("simulate_step", 0.05)
		if bool(boat.call("is_sunk")):
			sunk = true
	print("SHIP61_FINAL_SUNK ", sunk, " flooding=", boat.call("flooding"),
		" integrity=", boat.call("hull_integrity"))
	var at: Vector3 = boat.global_position
	camera.global_position = at + Vector3(22.0, 9.0, 22.0)
	camera.look_at(at + Vector3(0.0, -1.0, 0.0), Vector3.UP)
	for i in 20:
		await process_frame
	_shot("final_sinking")
	print("SHIP61_FINAL_OK")
	quit(0)
