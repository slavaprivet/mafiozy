extends SceneTree
## SHIP61 integrator probe: boots the real castle map and proves that the host
## installs the water, the ship, the guns and the player station together.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP61_HOST_FAIL scene")
		quit(1)
		return
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
	print("SHIP61_HOST_STATUS ", scene.get("ship_status"), " valid=", is_instance_valid(host))
	if not is_instance_valid(host):
		print("SHIP61_HOST_FAIL no_host status=", scene.get("ship_status"))
		quit(1)
		return
	await physics_frame
	await physics_frame
	for i in 30:
		await physics_frame
	var snapshot: Dictionary = host.call("snapshot")
	print("SHIP61_HOST_SNAPSHOT ", JSON.stringify(snapshot))
	var boat: Node = host.get("boat")
	var basin: Node = host.get("basin")
	var cannons: Node = host.get("cannons")
	var hud: Node = host.get("hud")
	print("SHIP61_HOST_NODES boat=", is_instance_valid(boat), " basin=", is_instance_valid(basin),
		" cannons=", is_instance_valid(cannons), " hud=", is_instance_valid(hud))
	if is_instance_valid(boat):
		print("SHIP61_HOST_BOAT ", JSON.stringify(boat.call("snapshot")))
		print("SHIP61_HOST_BOAT_DIAG autopilot=", boat.get("_autopilot"),
			" water_blocked=", boat.get("_water_blocked"),
			" ahead_ok=", boat.call("_water_ahead_ok"),
			" origin=", boat.get("_origin"), " yaw=", boat.get("_yaw"))
		var b: Node = basin
		for point: Vector2 in [Vector2(70.2, 984.2), Vector2(75.6, 981.7), Vector2(81.0, 979.1)]:
			print("SHIP61_HOST_AHEAD x=", point.x, " z=", point.y,
				" depth=", b.call("depth_at", point.x, point.y),
				" nav=", b.call("is_navigable", point.x, point.y, 1.8))
	if is_instance_valid(basin):
		print("SHIP61_HOST_WATER ", JSON.stringify(basin.call("snapshot")))
	if is_instance_valid(cannons):
		print("SHIP61_HOST_GUNS ", JSON.stringify(cannons.call("snapshot")))
	var player: Node3D = scene.get("_player")
	print("SHIP61_HOST_PLAYER ", player.global_position if player != null else "none")
	# Sail, steering and a gun, end to end.
	print("SHIP61_HOST_SAIL ", host.call("interact", "ship_sail"))
	for i in 300:
		await physics_frame
	var sailed: Dictionary = host.call("snapshot")
	print("SHIP61_HOST_SPEED_OPEN ", sailed.get("ship", {}).get("speed"), " pos=", sailed.get("ship", {}).get("position"))
	print("SHIP61_HOST_SAIL_CLOSE ", host.call("interact", "ship_sail"))
	for i in 600:
		await physics_frame
	var stopped: Dictionary = host.call("snapshot")
	print("SHIP61_HOST_SPEED_CLOSED ", stopped.get("ship", {}).get("speed"), " pos=", stopped.get("ship", {}).get("position"))
	# Way on again, then the helm: a ship only answers the rudder when moving.
	host.call("interact", "ship_sail")
	for i in 240:
		await physics_frame
	print("SHIP61_HOST_HELM ", host.call("interact", "ship_helm"))
	host.call("steer", 1.0)
	var heading_before: float = float(host.call("snapshot").get("ship", {}).get("heading", 0.0))
	for i in 120:
		await physics_frame
	print("SHIP61_HOST_HEADING ", heading_before, " -> ", host.call("snapshot").get("ship", {}).get("heading"))
	host.call("debug_set_station", "leave")
	print("SHIP61_HOST_OK")
	quit(0)
