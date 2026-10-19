extends SceneTree
var candidates: Array=[]
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	var here: String=get_script().resource_path.get_base_dir()
	if OS.get_cmdline_user_args().has("--candidate31=1"):
		for rel: String in ["scripts/city/runtime/npc_threat_life30.gd","scripts/npc_visual/npc_attention29.gd"]:
			var script:=GDScript.new()
			script.source_code=FileAccess.get_file_as_string(here.path_join("patch").path_join(rel))
			script.take_over_path("res://"+rel)
			assert(script.reload()==OK and script.can_instantiate())
			candidates.append(script)
	root.add_child(load(here.path_join("fixture31.gd")).new())
