extends SceneTree
## Ordinary interactive launch. Finite50 RPG is the user's requested test inventory.
var _output := ""
var _title := "Актуальная версия"
var _revision := ""
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt-dir="): _output = argument.trim_prefix("--receipt-dir=")
		if argument.begins_with("--release-title="): _title = argument.trim_prefix("--release-title=")
		if argument.begins_with("--release-revision="): _revision = argument.trim_prefix("--release-revision=")
	_start.call_deferred()
func _report(value: Dictionary) -> void:
	print("CURRENT_GAME_READY ", JSON.stringify(value))
	if not _output.is_empty():
		var file := FileAccess.open(_output.path_join("CURRENT_READY.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(value, "  ")); file.close()
func _start() -> void:
	var scene = load("res://scenes/main.tscn")
	if scene == null: _report({"ok": false, "reason": "missing_scene"}); return
	var game: Node3D = scene.instantiate()
	root.add_child(game); current_scene = game
	root.title = "Мафиози — " + _title
	for frame in 1200:
		if game.get("preview_ready") == true: break
		await process_frame
	if game.get("preview_ready") != true: _report({"ok": false, "reason": "scene_not_ready"}); return
	var constants: Dictionary = game.get_script().get_script_constant_map()
	var actual_revision: String = str(constants.get("PREVIEW_RUNTIME_REVISION", ""))
	if actual_revision != _revision:
		_report({"ok": false, "reason": "wrong_runtime_revision", "actual": actual_revision, "expected": _revision}); return
	var weapons: Node = game.get("preview_weapons")
	if not is_instance_valid(weapons): _report({"ok": false, "reason": "weapons_missing"}); return
	game._player.set_mouse_captured(true)
	var equipped: Dictionary = weapons.equip("rpg")
	if not equipped.get("ok", false): _report({"ok": false, "reason": "rpg_equip"}); return
	var requested: Dictionary = weapons.fire_state.duplicate(true)
	requested.magazine = 1; requested.reserveAmmo = 49
	var committed: Dictionary = weapons.inventory.update_fire_state(requested)
	if not committed.get("ok", false): _report({"ok": false, "reason": "inventory"}); return
	weapons.fire_state = committed.fireState; weapons._refresh_ui()
	var badge_layer := CanvasLayer.new(); badge_layer.layer = 100
	root.add_child(badge_layer)
	var badge := Label.new(); badge.text = _title
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color("ffd77a"))
	badge.add_theme_color_override("font_shadow_color", Color.BLACK)
	badge.add_theme_constant_override("shadow_offset_x", 1); badge.add_theme_constant_override("shadow_offset_y", 1)
	badge.position = Vector2(16, 76); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_layer.add_child(badge)
	if not _output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_output.path_join("opened.png"))
	var actual: Dictionary = weapons.inventory.get_fire_state("rpg")
	_report({"ok": actual.magazine == 1 and actual.reserveAmmo == 49, "revision": _revision, "title": _title, "rpg_total": actual.magazine + actual.reserveAmmo, "interactive": true, "player_position": str(game._player.global_position)})
