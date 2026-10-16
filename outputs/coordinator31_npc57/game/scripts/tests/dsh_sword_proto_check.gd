extends SceneTree
## DSH_SWORD_PROTO check: loads the prototype and the touched owners and treats
## any script error during the load as a failure (load() alone can return a
## resource whose parse failed).
func _initialize() -> void:
	var failed: Array[String] = []
	for path: String in [
		"res://scripts/weapons/sword_prototype.gd",
		"res://scripts/main.gd",
		"res://scripts/preview_player.gd",
	]:
		var script: Resource = load(path)
		if script == null or not script.can_instantiate():
			failed.append(path)
			continue
		print("SWORD_PROTO_CHECK load_ok ", path)
	var message := "PASS" if failed.is_empty() else "FAIL " + str(failed)
	print("SWORD_PROTO_CHECK_RESULT ", message)
	quit(1 if not failed.is_empty() else 0)
