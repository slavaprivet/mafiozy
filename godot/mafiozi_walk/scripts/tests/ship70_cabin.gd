extends SceneTree
## SHIP70: cabin hatch interaction (the deckhouse is too low to walk in).

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
	player.global_position = Vector3(115.0, 1.25, 981.20)
	for i in 10:
		await physics_frame
	var act: Dictionary = host.call("action")
	print("SHIP70_CABIN_OUT ", JSON.stringify(act), " local=", boat.call("local_of", player.global_position))
	print("SHIP70_CABIN_ENTER ", host.call("interact", act))
	for i in 10:
		await physics_frame
	print("SHIP70_CABIN_INSIDE local=", boat.call("local_of", player.global_position))
	var act2: Dictionary = host.call("action")
	print("SHIP70_CABIN_IN_ACTION ", JSON.stringify(act2))
	print("SHIP70_CABIN_EXIT ", host.call("interact", act2))
	for i in 10:
		await physics_frame
	print("SHIP70_CABIN_BACK local=", boat.call("local_of", player.global_position))
	print("SHIP70_CABIN_OK")
	quit(0)
