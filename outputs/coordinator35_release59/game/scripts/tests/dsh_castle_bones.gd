extends SceneTree
## DSH_CASTLE: what bones does the player's rig actually have?

var _scene: Node

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("BONES_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	var player: Node = _scene.get("_player")
	var found: Array[Node] = player.find_children("*", "Skeleton3D", true, false)
	print("BONES_SKELETONS count=", found.size())
	if found.is_empty():
		print("BONES_RESULT no_skeleton")
		quit(0)
		return
	var skeleton: Skeleton3D = found[0] as Skeleton3D
	var names: Array[String] = []
	for bone: int in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(bone))
	print("BONES_LIST ", JSON.stringify(names))
	print("BONES_RESULT done")
	quit(0)