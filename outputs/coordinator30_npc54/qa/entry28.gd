extends SceneTree

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var script_path: String = get_script().resource_path.get_base_dir().path_join("observer28.gd")
	var observer: Node = load(script_path).new()
	scene.add_child(observer)
