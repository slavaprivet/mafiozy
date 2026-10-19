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
	var cannons: Node = host.get("preview_cannons")
	var player: CharacterBody3D = scene.get("_player")
	print("SHIP101_START balls=", host.get("balls"))
	host.call("_take_from_crate", "ammo")
	for i in 4:
		await physics_frame
	print("SHIP101_TAKE balls=", host.get("balls"), " carry=",
		host.get("_carried_ball_mesh") != null and host.get("_carried_ball_mesh").visible)
	player.global_position = cannons.call("station_world", 0)
	for i in 6:
		await physics_frame
	var act: Dictionary = host.call("action")
	host.call("interact", act)
	for i in 6:
		await physics_frame
	host.call("_load_manning_cannon")
	for i in 80:
		await physics_frame
	print("SHIP101_LOAD carry=",
		host.get("_carried_ball_mesh") != null and host.get("_carried_ball_mesh").visible,
		" loaded=", cannons.call("loaded"), " balls=", host.get("balls"))
	host.call("_fire_manning_cannon")
	for i in 5:
		await physics_frame
	print("SHIP101_FIRE shots=", cannons.get("_shots"), " loaded=", cannons.call("loaded"))
	print("SHIP101_OK")
	quit(0)
