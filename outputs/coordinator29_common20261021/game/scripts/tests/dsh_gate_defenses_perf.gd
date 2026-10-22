extends SceneTree
## Quick A/B frame-time probe: the same gate camera with and without the new props.


func _initialize() -> void:
	call_deferred("_run")


func _measure(frames: int) -> float:
	var start := Time.get_ticks_usec()
	for i: int in frames:
		await process_frame
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	return float(frames) / maxf(elapsed, 0.001)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and game.get("preview_ready") != true:
		await process_frame
	var castle: Node3D = game.get("preview_castle") as Node3D
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 500.0
	game.add_child(camera)
	camera.current = true
	camera.global_position = castle.global_position + Vector3(0.0, 5.0, 91.0)
	camera.look_at(castle.global_position + Vector3(0.0, 13.0, 68.0), Vector3.UP)
	await _measure(90)
	var with_props := await _measure(240)
	for key: String in ["_gate_gallery", "_stone_hatch", "_gate_cauldron", "_sally_port"]:
		var node: Node = castle.get(key) as Node
		if node != null:
			node.queue_free()
	for i: int in 30:
		await process_frame
	var without_props := await _measure(240)
	print("GATE_PERF ", JSON.stringify({"with_props_fps": with_props,
		"without_props_fps": without_props, "draw_calls": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}))
	quit(0)
