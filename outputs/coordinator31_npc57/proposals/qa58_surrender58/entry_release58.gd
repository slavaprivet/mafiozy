extends SceneTree
## DSH_SURRENDER58 release branch: aim at a civilian, hold, then LOWER the weapon
## without ever shooting. Proves the lease expiry path (pose lowers, life released)
## which the existing threat harness cannot reach because it always fires.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var out := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-out="): out = argument.trim_prefix("--qa-out=")
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var observer: Node = load(get_script().resource_path.get_base_dir().path_join("observer_release58.gd")).new()
	observer.out_dir = out
	scene.add_child(observer)
