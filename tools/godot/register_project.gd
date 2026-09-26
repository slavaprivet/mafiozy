extends SceneTree
## Match ProjectList::add_project without replacing other registered projects.
func _initialize() -> void:
	var config_path := ""
	var project_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--projects-config="):
			config_path = arg.trim_prefix("--projects-config=")
		elif arg.begins_with("--project-directory="):
			project_path = arg.trim_prefix("--project-directory=").replace("\\", "/").trim_suffix("/")
	if not config_path.is_absolute_path() or not project_path.is_absolute_path() or not FileAccess.file_exists(project_path.path_join("project.godot")):
		quit(2)
		return
	var config := ConfigFile.new()
	var result := config.load(config_path)
	if result not in [OK, ERR_FILE_NOT_FOUND]:
		quit(3)
		return
	if not config.has_section(project_path):
		config.set_value(project_path, "favorite", false)
	result = config.save(config_path)
	var check := ConfigFile.new()
	if result != OK or check.load(config_path) != OK or not check.has_section(project_path):
		quit(4)
		return
	print("Registered project: ", project_path)
	quit(0)
