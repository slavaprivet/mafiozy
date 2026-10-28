extends SceneTree
## SHIP64: one screenshot of the new gun camera and one of the helm.

const OUT := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_fix64"

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("SHIP64_VIEW_FAIL ", name)
		return
	var path := OUT.path_join(name)
	image.save_png(path)
	print("SHIP64_VIEW_SAVED ", path)

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
	for i in 45:
		await process_frame
	host.call("debug_set_station", "cannon", 2)
	for i in 30:
		await process_frame
	var camera := root.get_viewport().get_camera_3d()
	print("SHIP64_VIEW_GUN_CAM ", camera.global_position if is_instance_valid(camera) else Vector3.ZERO)
	_shot("gun_camera.png")
	host.call("debug_set_station", "leave", -1)
	for i in 10:
		await process_frame
	host.call("debug_set_station", "helm", -1)
	for i in 35:
		await process_frame
	_shot("helm_view.png")
	print("SHIP64_VIEW_OK")
	quit(0)
