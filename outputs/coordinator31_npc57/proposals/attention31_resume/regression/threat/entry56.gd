extends SceneTree
var overlays: Array=[]
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	if OS.get_cmdline_user_args().has("--candidate31=1"):
		var folder: String=get_script().resource_path.get_base_dir().path_join("../../patch_yaw31")
		for rel: String in ["scripts/city/runtime/npc_threat_life30.gd","scripts/npc_visual/npc_attention29.gd"]:
			var replacement:=GDScript.new();replacement.source_code=FileAccess.get_file_as_string(folder.path_join(rel));replacement.take_over_path("res://"+rel)
			assert(replacement.reload()==OK and replacement.can_instantiate());overlays.append(replacement)
	var scene: Node=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	scene.add_child(load(get_script().resource_path.get_base_dir().path_join("observer56.gd")).new())
