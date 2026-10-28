extends SceneTree
## SHIP63 end-to-end: the starboard battery shoots the identical target hulk.

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
	if not is_instance_valid(host):
		print("SHIP63_HIT_FAIL no_host")
		quit(1)
		return
	for i in 40:
		await physics_frame
	var target: Node = host.get("preview_target")
	if not is_instance_valid(target):
		print("SHIP63_HIT_FAIL no_target")
		quit(1)
		return
	var boat: Node3D = target.get("boat")
	for shot in 6:
		var at: Vector3 = boat.global_position + Vector3(-4.15, 0.45, -4.0 + float(shot) * 1.6)
		var fired: Dictionary = host.call("debug_fire_at", at)
		print("SHIP63_HIT_SHOT ", shot, " fired=", JSON.stringify(fired))
		for i in 100:
			await physics_frame
		print("SHIP63_HIT_STATE ", shot, " ", JSON.stringify(target.call("snapshot")))
	print("SHIP63_HIT_OK")
	quit(0)
