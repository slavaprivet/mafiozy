extends SceneTree
## SHIP61 interaction probe: the F key really reaches the host through main.gd.

func _initialize() -> void:
	call_deferred("_run")

func _press_f() -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = KEY_F
	down.physical_keycode = KEY_F
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = KEY_F
	up.physical_keycode = KEY_F
	Input.parse_input_event(up)
	for i in 4:
		await physics_frame

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
		print("SHIP61_F_FAIL no_host")
		quit(1)
		return
	for i in 60:
		await physics_frame
	var boat: Node3D = host.get("boat")
	var player: CharacterBody3D = scene.get("_player")
	print("SHIP61_F_START player=", player.global_position, " action=", host.call("action"))
	await _press_f()
	print("SHIP61_F_HELM station=", host.get("_station"), " action=", host.call("action"))
	# Sails open, then steer with the D key for a second and a half.
	host.call("interact", "ship_sail")
	await _press_f()  # leave the helm so the prompt is free
	var heading_before: float = float(host.call("snapshot").get("ship", {}).get("heading", 0.0))
	for i in 120:
		await physics_frame
	print("SHIP61_F_SPEED ", host.call("snapshot").get("ship", {}).get("speed"))
	# Back at the wheel: F, then hold D.
	await _press_f()
	var down := InputEventKey.new()
	down.pressed = true
	down.keycode = KEY_D
	down.physical_keycode = KEY_D
	Input.parse_input_event(down)
	for i in 120:
		await physics_frame
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = KEY_D
	up.physical_keycode = KEY_D
	Input.parse_input_event(up)
	var heading_after: float = float(host.call("snapshot").get("ship", {}).get("heading", 0.0))
	print("SHIP61_F_HEADING ", heading_before, " -> ", heading_after)
	await _press_f()
	# The sail lever, then the ammo crate, by teleporting the standing player.
	var lever: Vector3 = boat.to_global(Vector3(1.0, 2.2, 0.2))
	player.global_position = lever + Vector3(0.0, 0.0, 1.0)
	await physics_frame
	print("SHIP61_F_LEVER_ACTION ", host.call("action"))
	host.call("interact", "ship_sail")
	print("SHIP61_F_SAILS ", host.call("snapshot").get("ship", {}).get("sails_open"))
	var ammo: Vector3 = boat.to_global(Vector3(-2.0, 0.95, 10.2))
	player.global_position = ammo + Vector3(0.0, 0.0, 1.2)
	await physics_frame
	print("SHIP61_F_AMMO_ACTION ", host.call("action"))
	var before := int(host.call("snapshot").get("balls", 0))
	host.call("interact", "ship_ammo")
	print("SHIP61_F_AMMO ", before, " -> ", host.call("snapshot").get("balls"))
	print("SHIP61_F_OK")
	quit(0)
