extends SceneTree
## Run with the console engine --main-pack exported.pck --script this-file.
## Windows release templates ignore external --script; this is PCK admission,
## not evidence that the standalone release executed a test harness.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := ""
	var require_upgrade := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-output="):
			output = arg.trim_prefix("--smoke-output=")
		elif arg == "--require-water-dive-finishes":
			require_upgrade = true
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null or output.is_empty():
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in range(15):
		await process_frame
	var player: Node = main.get("_player")
	var passed: bool = main.get("preview_ready") == true and main.get("printshop_status") == "ready" and player != null
	var status: Dictionary = player.get_preview_status() if player != null else {}
	passed = passed and bool(status.get("airborne", {}).get("ready", false))
	var features: Dictionary = {}
	if require_upgrade:
		var roles: Array[String] = []
		var interior: Node = main.get("_printshop")
		if interior != null:
			var materials: Dictionary = interior.get("_material_cache")
			for material: Material in materials.values():
				if material is ShaderMaterial and material.has_meta("source_program_key"):
					var role := str(material.get_meta("source_program_key"))
					if not roles.has(role):
						roles.append(role)
		features = {"water": main.get("water_status"), "water_counts": main.get("water_summary"),
			"source_dive_ready": status.get("source_dive_ready", false), "finish_roles": roles}
		passed = passed and features.water == "detail_ready" and features.source_dive_ready
		passed = passed and roles.has("interior-finish-v2-4-true") and roles.has("interior-finish-v2-1-false")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"passed": passed, "executable": OS.get_executable_path(), "headless": DisplayServer.get_name() == "headless", "main_ready": main.get("preview_ready"), "printshop": main.get("printshop_status"), "airborne": status.get("airborne", {}), "features": features, "live": false}))
	file.close()
	quit(0 if passed else 1)
