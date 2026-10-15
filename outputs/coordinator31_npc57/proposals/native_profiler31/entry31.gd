extends SceneTree
func _initialize() -> void: _start.call_deferred()
func _start() -> void:
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	var observer: Node = load(get_script().resource_path.get_base_dir().path_join("observer31.gd")).new()
	scene.add_child(observer)
