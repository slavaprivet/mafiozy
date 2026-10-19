extends SceneTree
## DSH_TOWER: one close-up of the ram head, for visual iteration.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var host: Node = null
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		host = scene.get("preview_siege_tower") as Node
		if is_instance_valid(host):
			break
		await process_frame
	if not is_instance_valid(host):
		print("DSH_RAM_SHOT_FAIL no_host")
		quit(1)
		return
	var body: Node3D = host.call("body_ref") as Node3D
	for node: Node in scene.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.current = true
	var yaw: float = float(body.get("_yaw"))
	var basis := Basis(Vector3.UP, yaw)
	var origin := body.global_position
	for _i: int in 30:
		await physics_frame
	var out_dir := OS.get_environment("DSH_TOWER_SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "D:/MafioziCombat31/tower_shots/ram"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var views := [
		["ram_front", Vector3(3.6, 2.9, -10.6), Vector3(0.0, 2.35, -7.9)],
		["ram_threequarter", Vector3(5.4, 3.2, -9.2), Vector3(0.0, 2.35, -7.9)],
		["ram_side", Vector3(7.4, 2.8, -8.0), Vector3(0.0, 2.30, -7.9)],
	]
	for view: Array in views:
		camera.global_position = origin + basis * (view[1] as Vector3)
		camera.look_at(origin + basis * (view[2] as Vector3), Vector3.UP)
		for _i: int in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("tower_%s.png" % str(view[0]))
		var error := root.get_texture().get_image().save_png(path)
		print("DSH_RAM_SHOT ", JSON.stringify({"path": path, "error": error}))
	await create_timer(1.0).timeout
	quit(0)
