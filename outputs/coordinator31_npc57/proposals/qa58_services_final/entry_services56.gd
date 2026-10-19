extends SceneTree

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.add_child(load(get_script().resource_path.get_base_dir().path_join("observer_services56.gd")).new())
