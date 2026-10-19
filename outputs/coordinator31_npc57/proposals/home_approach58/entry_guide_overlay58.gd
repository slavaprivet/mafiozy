extends SceneTree
var out_path := ""
func _initialize() -> void: _start.call_deferred()
func _start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out_path=arg.trim_prefix("--qa-out=")
	if out_path.is_empty(): quit(2);return
	var overlay:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out_path.path_join("OVERLAY.json")))
	if not ProjectSettings.load_resource_pack(out_path.path_join("OVERLAY.zip"),true):push_error("overlay load refused");quit(2);return
	for rel:String in overlay:
		if FileAccess.get_sha256("res://"+rel)!=overlay[rel]:push_error("overlay SHA mismatch "+rel);quit(2);return
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	var observer: Node=load(get_script().resource_path.get_base_dir().path_join("observer_guide_overlay58.gd")).new()
	observer.scene=scene;observer.out_path=out_path
	root.add_child(observer)
