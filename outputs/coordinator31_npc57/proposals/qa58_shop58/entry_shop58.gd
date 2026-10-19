extends SceneTree
## DSH_SHOP58: one live purchase through the shop's own callback on the unified build,
## then the arsenal's own owned list is read back. Component level: it calls the same
## `_on_purchase` the goods window calls, so no mouse click is simulated.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var out := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-out="): out = argument.trim_prefix("--qa-out=")
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var observer: Node = load(get_script().resource_path.get_base_dir().path_join("observer_shop58.gd")).new()
	observer.out_dir = out
	scene.add_child(observer)
