extends SceneTree
var held58: Array[Script] = []
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	var here: String=get_script().resource_path.get_base_dir()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(here.path_join("PATCH.json")))
	# Install dependency first; every consumer uses these original resource IDs.
	for rel: String in ["scripts/city/runtime/npc_threat_route30.gd","scripts/city/runtime/npc_threat_life30.gd"]:
		var path: String=here.path_join("patch").path_join(rel)
		assert(FileAccess.get_sha256("res://"+rel)==manifest[rel].base_sha256)
		assert(FileAccess.get_sha256(path)==manifest[rel].candidate_sha256)
		var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path)
		script.take_over_path("res://"+rel)
		assert(script.reload()==OK);assert(script.can_instantiate());held58.append(script)
		assert(load("res://"+rel)==script)
	if OS.get_cmdline_user_args().has("--qa-service-kind=budget"):
		root.add_child(load(here.path_join("unit58.gd")).new())
	else:
		var scene: Node=load("res://scenes/main_city.tscn").instantiate();root.add_child(scene);current_scene=scene
		var observer: Node=load(here.path_join("observer58.gd")).new();scene.add_child(observer)
