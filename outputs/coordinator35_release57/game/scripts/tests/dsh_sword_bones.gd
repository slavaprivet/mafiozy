extends SceneTree
## DSH_SWORD_PROTO: print the hero rig bone names so the prototype can pick the
## right arm chain by name instead of guessing.
func _initialize() -> void:
	var packed: PackedScene = load("res://assets/hero.glb")
	if packed == null:
		print("BONES_FAIL load"); quit(1); return
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	var skeletons: Array = root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		print("BONES_FAIL no_skeleton"); quit(1); return
	var rig: Skeleton3D = skeletons[0]
	print("BONES_COUNT ", rig.get_bone_count())
	for i: int in rig.get_bone_count():
		print("BONE ", i, " name=", rig.get_bone_name(i), " parent=", rig.get_bone_parent(i))
	quit(0)
