extends SceneTree
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
	var scene: Node3D = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene = scene
	scene.add_child(load(get_script().resource_path.get_base_dir().path_join("observer_soak58_v5.gd")).new())
	DisplayServer.window_set_title("РњР°С„РёРѕР·Рё вЂ” QA31: 10 Р¶РёС‚РµР»РµР№, РѕР¶РёРґР°РЅРёРµ Рё РЅР°РіСЂСѓР·РєР°")
