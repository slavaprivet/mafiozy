extends SceneTree
## SHIP70: the ship card is visible only while aboard.

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
	for i in 60:
		await process_frame
	var player: CharacterBody3D = scene.get("_player")
	var boat: Node3D = host.get("boat")
	var hud: Node = host.get("hud")
	print("SHIP70_ABOARD state=", host.call("snapshot").get("aboard"),
		" panel=", hud.call("panel_visible"))
	player.global_position = Vector3(40.0, 0.6, 1000.0)
	for i in 20:
		await process_frame
	print("SHIP70_SHORE state=", host.call("snapshot").get("aboard"),
		" panel=", hud.call("panel_visible"))
	player.global_position = boat.call("world_deck", Vector3(0.0, 1.85, 8.0))
	for i in 20:
		await process_frame
	print("SHIP70_BACK state=", host.call("snapshot").get("aboard"),
		" panel=", hud.call("panel_visible"))
	print("SHIP70_OK")
	quit(0)
