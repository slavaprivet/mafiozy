extends SceneTree
var candidates: Array = []
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var here: String = get_script().resource_path.get_base_dir()
	var candidate := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--candidate31=1": candidate = true
	if candidate:
		for rel: String in ["scripts/navigation/npc_passage31.gd","scripts/hospital/npc_physical_route51.gd","scripts/navigation/npc_local_avoidance29.gd","scripts/navigation/npc_avoidance_world29.gd"]:
			var script := GDScript.new()
			var source: String = FileAccess.get_file_as_string(here.path_join("patch").path_join(rel))
			# The new source is absent on the readonly baseline disk. Resolve only
			# this diagnostic preload to its saved candidate; merged runs use res://.
			source = source.replace("res://scripts/navigation/npc_passage31.gd",here.path_join("patch/scripts/navigation/npc_passage31.gd"))
			script.source_code = source
			script.take_over_path("res://"+rel)
			assert(script.reload()==OK)
			assert(script != null and script.can_instantiate())
			candidates.append(script)
	var fixture: Node = load(here.path_join("fixture31.gd")).new()
	root.add_child(fixture)
