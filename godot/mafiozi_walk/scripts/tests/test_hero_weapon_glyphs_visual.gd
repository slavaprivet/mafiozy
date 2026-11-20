extends SceneTree
## Graphical contact sheet of the HUD's final-size medieval weapon glyphs.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var hud: CanvasLayer = load("res://scripts/character/hero_vitals_hud.gd").new()
	hud.configure(scene)
	hud.set_process(false)
	var glyph: Control = hud.get("_weapon_icon")
	var ids := ["none", "hatchet", "sword", "mace", "axe", "sledge", "spear", "bow", "shield"]
	var sheet := Image.create(176, 132, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.10, 0.13, 0.14))
	for index: int in ids.size():
		glyph.call("set_weapon", ids[index])
		await process_frame
		await process_frame
		var origin := Vector2i(glyph.global_position.round())
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(origin, Vector2i(32, 32)),
			Vector2i((index % 4) * 44 + 6, (index / 4) * 44 + 6))
	var path := ProjectSettings.globalize_path("user://hero_weapon_glyphs.png")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-path="): path = arg.trim_prefix("--capture-path=")
	var saved := sheet.save_png(path)
	print("HERO_WEAPON_GLYPHS ", "PASS" if saved == OK else "FAIL", " ", path)
	quit(0 if saved == OK else 1)
