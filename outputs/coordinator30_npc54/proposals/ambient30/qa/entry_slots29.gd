extends SceneTree
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var marker := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-ready="): marker = arg.trim_prefix("--qa-ready=")
	var deadline: int = Time.get_ticks_msec()+30000
	while not marker.is_empty() and not FileAccess.file_exists(marker):
		if Time.get_ticks_msec() >= deadline: quit(2); return
		await create_timer(.05).timeout
	var scene: Node = load(get_script().resource_path.get_base_dir().path_join("slots_fixture29.gd")).new()
	root.add_child(scene); current_scene = scene
