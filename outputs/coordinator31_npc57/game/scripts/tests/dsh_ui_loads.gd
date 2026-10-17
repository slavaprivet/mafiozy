extends SceneTree
## Loads every script this work touches, so a parse error in the arsenal UI cannot hide
## behind checks that only preload the weapons.

func _initialize() -> void:
	var paths := [
		"res://scripts/weapons/walk_weapon_ui.gd",
		"res://scripts/weapons/preview_weapons.gd",
		"res://scripts/weapons/sword_prototype.gd",
		"res://scripts/weapons/bow_prototype.gd",
		"res://scripts/weapons/catapult_prototype.gd",
		"res://scripts/weapons/mesh_sever.gd",
		"res://scripts/weapons/mesh_merge.gd",
	]
	var failed: Array[String] = []
	for path: String in paths:
		var script: Variant = load(path)
		if script == null:
			failed.append(path)
			print("UI_LOADS_FAIL ", path)
		else:
			print("UI_LOADS_OK ", path)
	print("UI_LOADS_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)