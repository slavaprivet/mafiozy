extends SceneTree
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	var count: int=10
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-residents="):count=int(arg.trim_prefix("--qa-residents="))
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	scene.add_child(load(get_script().resource_path.get_base_dir().path_join("../mass30/observer_mass30.gd")).new())
	DisplayServer.window_set_title("Мафиози — ПРОВЕРКА ПАРТИИ: %d ЖИТЕЛЕЙ" % count)
