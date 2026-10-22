extends SceneTree
## SHIP69: fall under the hull and get rescued onto the deck.

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
	player.global_position = Vector3(115.0, -0.30, 975.0)
	for i in 12:
		await physics_frame
	print("SHIP69_RESCUE pos=", player.global_position, " floor=", player.is_on_floor())
	print("SHIP69_RESCUE_OK")
	quit(0)
