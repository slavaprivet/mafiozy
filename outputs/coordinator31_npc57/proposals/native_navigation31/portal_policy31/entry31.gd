extends SceneTree
var held: Array[Script] = []
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var here: String = get_script().resource_path.get_base_dir()
	if OS.get_cmdline_user_args().has("--candidate=1"):
		for rel: String in ["scripts/navigation/npc_passage31.gd","scripts/venues/npc_venue_capacity29.gd","scripts/venues/npc_venue_registry29.gd"]:
			var script := GDScript.new(); script.source_code = FileAccess.get_file_as_string(here.path_join("patch").path_join(rel))
			script.take_over_path("res://" + rel); assert(script.reload() == OK); held.append(script)
	root.add_child(load(here.path_join("fixture_portal31.gd")).new())
