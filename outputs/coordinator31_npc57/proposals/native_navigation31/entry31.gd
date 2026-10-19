extends SceneTree
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var here: String = get_script().resource_path.get_base_dir()
	root.add_child(load(here.path_join("fixture31.gd")).new())
