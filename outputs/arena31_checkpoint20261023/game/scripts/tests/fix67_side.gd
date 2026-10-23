extends SceneTree
## SHIP66: side view after removing the static rigging clutter.

const OUT := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_fix67"

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("SHIP66_SHOT_FAIL ", name)
		return
	var path := OUT.path_join(name)
	image.save_png(path)
	print("SHIP66_SHOT_SAVED ", path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
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
		await process_frame
	var boat: Node3D = host.get("boat")
	var ship := boat.global_position
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.global_position = ship + Vector3(-22.0, 10.0, 9.0)
	camera.look_at(ship + Vector3(0.0, 4.5, 0.0), Vector3.UP)
	camera.current = true
	for i in 12:
		await process_frame
	_shot("after_01_side_clean.png")
	camera.global_position = ship + Vector3(14.0, 9.0, 20.0)
	camera.look_at(ship + Vector3(0.0, 4.0, 0.0), Vector3.UP)
	for i in 12:
		await process_frame
	_shot("after_02_stern_clean.png")
	print("SHIP66_SHOT_OK")
	quit(0)
