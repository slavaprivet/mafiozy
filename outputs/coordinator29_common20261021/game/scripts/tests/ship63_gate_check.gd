extends SceneTree
## SHIP63: death releases a station; a sunk ship refuses every control.

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
	for i in 40:
		await physics_frame
	print("SHIP63_GATE_HELM ", host.call("interact", "ship_helm"), " station=", host.get("_station"))
	scene.set("preview_dead", true)
	for i in 6:
		await physics_frame
	print("SHIP63_GATE_DEAD station=", host.get("_station"), " hold=", scene.get("_player").get("_vehicle_hold"))
	scene.set("preview_dead", false)
	host.call("interact", "ship_helm")  # leave
	for i in 4:
		await physics_frame
	# Sink the player's ship.
	host.call("debug_hit_ship", 8)
	var boat: Node = host.get("boat")
	for i in 2400:
		boat.call("simulate_step", 0.05)
	print("SHIP63_GATE_SUNK sunk=", boat.call("is_sunk"), " usable=", host.get("usable"),
		" station=", host.get("_station"))
	var act: Dictionary = host.call("action")
	print("SHIP63_GATE_ACTION ", JSON.stringify(act))
	print("SHIP63_GATE_HELM2 ", host.call("interact", "ship_helm"))
	print("SHIP63_GATE_SAIL ", host.call("interact", "ship_sail"))
	print("SHIP63_GATE_CANNON ", host.call("interact", "ship_cannon"))
	print("SHIP63_GATE_STATE ", JSON.stringify(host.call("snapshot").get("ship")))
	print("SHIP63_GATE_OK")
	quit(0)
