extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	var castle: Node3D = scene.get("preview_castle")
	var catapult: Node3D = scene.get("preview_catapult")
	catapult.place_near_castle(castle)
	var cart: CharacterBody3D = catapult.get("_cart")
	var camera := Camera3D.new()
	camera.fov = 58.0; camera.far = 200.0
	scene.add_child(camera)
	camera.current = true
	camera.global_position = cart.global_position + Vector3(4.2, 2.8, -6.3)
	camera.look_at(cart.global_position + Vector3(0.0, 1.0, 0.0))
	for frame: int in 12: await process_frame
	var file: String = OS.get_environment("DSH_SHOT_DIR").path_join("castle_catapult_visual30.png")
	var saved: Error = root.get_texture().get_image().save_png(file)
	print("CASTLE_CATAPULT_VISUAL30 ", JSON.stringify({"passed": saved == OK, "file": file,
		"parts": catapult.snapshot().parts, "weld": catapult.get("_weld_report")}))
	quit(0 if saved == OK else 1)
