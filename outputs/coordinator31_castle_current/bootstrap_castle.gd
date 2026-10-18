extends SceneTree
## Canonical castle bootstrap: observe the pinned scene without changing gameplay.
var _out := ""
var _revision := ""
var _title := "Замок и осадное поле"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt-dir="): _out = arg.trim_prefix("--receipt-dir=")
		if arg.begins_with("--release-revision="): _revision = arg.trim_prefix("--release-revision=")
		if arg.begins_with("--release-title="): _title = arg.trim_prefix("--release-title=")
	_start.call_deferred()

func _report(value: Dictionary) -> void:
	value["revision"] = _revision
	value["title"] = _title
	value["scene_kind"] = "castle"
	print("CURRENT_GAME_READY ", JSON.stringify(value))
	if not _out.is_empty():
		var file := FileAccess.open(_out.path_join("CURRENT_READY.json"), FileAccess.WRITE)
		if file == null:
			push_error("Cannot write castle readiness receipt")
		else:
			file.store_string(JSON.stringify(value, "\t"))
			file.close()
	if OS.get_cmdline_user_args().has("--castle-play-check=1"):
		quit(0 if value.get("ok", false) else 1)

func _start() -> void:
	root.title = "Мафиози — " + _title
	if _revision.is_empty() or _out.is_empty():
		_report({"ok": false, "reason": "missing_release_identity_or_receipt_directory"})
		return
	var packed := load("res://scenes/castle.tscn") as PackedScene
	if packed == null:
		_report({"ok": false, "reason": "castle_scene_missing"})
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 110000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.get("preview_ready") != true:
		_report({"ok": false, "reason": "castle_startup_timeout"})
		return
	# Final catapult/spawn placement occurs in physics after scene construction.
	for tick: int in 30:
		await physics_frame
	var castle := scene.get("preview_castle") as Node3D
	var field := scene.get("preview_battlefield") as Node3D
	var player := scene.get("_player") as CharacterBody3D
	var props: Node = field.get_node_or_null("BattlefieldProps") if is_instance_valid(field) else null
	var field_stats: Dictionary = field.call("get_stats") if is_instance_valid(field) and field.has_method("get_stats") else {}
	var props_stats: Dictionary = props.call("get_stats") if is_instance_valid(props) and props.has_method("get_stats") else {}
	var local_player := castle.to_local(player.global_position) if is_instance_valid(castle) and is_instance_valid(player) else Vector3.ZERO
	var outside := is_instance_valid(castle) and is_instance_valid(player) and local_player.z > float(castle.call("wall_half"))
	var checks := {
		"preview_ready": scene.get("preview_ready") == true,
		"castle_mode": scene.get("castle_map") == true and is_instance_valid(castle),
		"battlefield": is_instance_valid(field) and int(field_stats.get("terrain_chunks", 0)) > 0,
		"battlefield_props": is_instance_valid(props) and int(props_stats.get("tents", 0)) > 0 and int(props_stats.get("barriers", 0)) > 0,
		"player_outside": outside,
		"player_grounded": is_instance_valid(player) and player.is_on_floor(),
		"city_population_absent": scene.get("preview_population") == null,
	}
	var ready := true
	for value: bool in checks.values(): ready = ready and value
	var screenshot := ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		screenshot = _out.path_join("opened.png")
		var image_error := root.get_texture().get_image().save_png(screenshot)
		if image_error != OK:
			ready = false
			checks["screenshot_saved"] = false
		else:
			checks["screenshot_saved"] = true
	_report({"ok": ready, "checks": checks, "scene": "res://scenes/castle.tscn",
		"player_position": str(player.global_position) if is_instance_valid(player) else "missing",
		"battlefield_stats": field_stats, "props_stats": props_stats,
		"screenshot": screenshot, "interactive": DisplayServer.get_name() != "headless",
		"performance_accepted": false})
