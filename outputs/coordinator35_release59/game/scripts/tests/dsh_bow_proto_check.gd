extends SceneTree
## DSH_BOW_PROTO check: the bow prototype and its integration must at least LOAD
## and instantiate headlessly, before any driven run is worth attempting.

func _initialize() -> void:
	var failures: Array[String] = []
	for path: String in [
		"res://scripts/weapons/bow_prototype.gd",
		"res://scripts/main.gd",
		"res://scripts/weapons/preview_weapons.gd",
	]:
		var script: Script = load(path)
		if script == null:
			failures.append(path)
			continue
		if not script.can_instantiate():
			failures.append(path + " (cannot instantiate)")
	print("BOW_PROTO_CHECK_RESULT ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
