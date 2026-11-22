extends SceneTree
## Graphical inspection of each complete set and all fifteen equipment transfers.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ProjectSettings.globalize_path("user://armor_visual_all_tiers")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	while not bool(game.get("preview_ready")) and Time.get_ticks_msec() < deadline:
		await process_frame
	var errors: Array[String] = []
	if not bool(game.get("preview_ready")):
		errors.append("scene_not_ready")
	else:
		var equipment: Node = game.get_node("CastleArmorEquipment")
		var visual: Node = equipment.get("visual")
		var player: CharacterBody3D = game.get("_player")
		var camera := Camera3D.new()
		camera.fov = 42.0
		game.add_child(camera)
		camera.current = true
		for tier in ["light", "medium", "heavy"]:
			for slot in ["head", "torso", "hands", "legs", "feet"]:
				var id: String = tier + "_" + slot
				var result: Dictionary = equipment.equip_ground(id)
				if not bool(result.get("ok", false)): errors.append(id + "_equip")
				var roots: Dictionary = visual.get("_roots")
				var ornaments := 0
				for anchor: Node in roots.get(slot, []):
					for child: Node in anchor.get_children():
						if child is MeshInstance3D and bool(child.get_meta("armor_cosmetic", false)):
							ornaments += 1
				if ornaments == 0: errors.append(id + "_no_ornament")
			for frame in 25: await process_frame
			camera.global_position = player.global_position + Vector3(0, 1.15, 3.2)
			camera.look_at(player.global_position + Vector3.UP * 0.95)
			for frame in 4: await process_frame
			var path := output.path_join(tier + "_front.png")
			if game.get_viewport().get_texture().get_image().save_png(path) != OK: errors.append(tier + "_capture")
		var final_roots: Dictionary = visual.get("_roots")
		visual.on_severed("head")
		if final_roots["head"][0].visible: errors.append("severed_head_kept_ornament")
		visual.reset_severed()
		if not final_roots["head"][0].visible: errors.append("reset_head_ornament_hidden")
		visual.on_severed("hand_l")
		var left_hidden := false
		var right_visible := false
		for anchor: Node in final_roots["hands"]:
			if str(anchor.get_meta("armor_bone", "")) == "hand_l" and not anchor.visible: left_hidden = true
			if str(anchor.get_meta("armor_bone", "")) == "hand_r" and anchor.visible: right_visible = true
		if not left_hidden or not right_visible: errors.append("severed_hand_ornament_side")
		visual.reset_severed()
		var debris := Node3D.new()
		game.add_child(debris)
		var cut: Dictionary = visual.cut_rigid31({"scope": "head", "head_gone": true,
			"plane": Plane(Vector3.UP, 0.0), "keep": Vector3.ZERO}, {}, debris)
		if int(cut.get("detached", 0)) < 2: errors.append("head_cut_did_not_detach_armor")
		visual.reset_severed()
		if not final_roots["head"][0].visible: errors.append("head_cut_not_restored")
	print("ARMOR_ALL_TIERS ", JSON.stringify({"passed": errors.is_empty(), "errors": errors, "output": output}))
	quit(0 if errors.is_empty() else 1)
