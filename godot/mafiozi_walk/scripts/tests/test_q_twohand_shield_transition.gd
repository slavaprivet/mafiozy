extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	while not bool(game.get("preview_ready")) and Time.get_ticks_msec() < deadline:
		await process_frame
	var errors: Array[String] = []
	if not bool(game.get("preview_ready")):
		errors.append("scene_not_ready")
	else:
		var player: CharacterBody3D = game.get("_player")
		var weapons: Node = game.get("preview_weapons")
		var prototype: Node = game.get("preview_sword_prototype")
		player.set_mouse_captured(true)
		for id in ["sword", "shield", "axe", "sword", "shield", "sledge", "sword", "shield", "spear"]:
			var result: Dictionary = weapons.equip(id)
			if not bool(result.get("ok", false)): errors.append(id + "_equip_refused")
			if id in ["axe", "sledge", "spear"]:
				if bool(prototype.shield_status().get("worn", false)):
					errors.append(id + "_shield_remains_worn")
				if str(weapons.fire_state.get("weaponId", "")) != id:
					errors.append(id + "_state_mismatch")
	print("Q_TWOHAND_SHIELD ", JSON.stringify({"passed": errors.is_empty(), "errors": errors}))
	quit(0 if errors.is_empty() else 1)
