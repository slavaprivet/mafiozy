extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func _run() -> void:
	var game: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	while not bool(game.get("preview_ready")) and Time.get_ticks_msec() < deadline:
		await process_frame
	var errors: Array[String] = []
	if not bool(game.get("preview_ready")):
		print("CASTLE_Q_SELECTION ", JSON.stringify({"passed": false, "errors": ["scene_not_ready"]}))
		quit(1)
		return
	var weapons: Node = game.get("preview_weapons")
	var player: CharacterBody3D = game.get("_player")
	var storage: Node = weapons.get("castle_storage_owner")
	var ui: Control = weapons.get("_walk_ui")
	player.set_mouse_captured(true)
	for i in 10: await process_frame
	# The bow used to intercept Q here and prevent the arsenal opening.
	var bow_result: Dictionary = storage.acquire_or_select("bow")
	if not bool(bow_result.get("ok", false)): errors.append("bow_acquire")
	var sword_result: Dictionary = storage.acquire_or_select("sword")
	if not bool(sword_result.get("ok", false)): errors.append("sword_acquire")
	if not storage.has_back_bow(): errors.append("bow_not_on_back")
	weapons._input(_key(KEY_Q))
	player._unhandled_input(_key(KEY_Q))
	await process_frame
	if not weapons.menu_open: errors.append("q_did_not_open_with_bow_on_back")
	if bool(storage.snapshot().bow_active): errors.append("q_selected_bow_instead")
	var choices: Dictionary = ui.get("choices")
	var shield_button: Button = choices["shield"].button
	if shield_button.disabled: errors.append("shield_card_unavailable")
	else:
		shield_button.pressed.emit()
		await process_frame
		if not bool(storage.snapshot().hand_shield): errors.append("shield_not_equipped")
	for id in ["axe", "mace", "sledge", "spear", "hatchet"]:
		if not weapons.menu_open: weapons.set_menu(true)
		await process_frame
		var button: Button = choices[id].button
		if button.disabled or not button.is_visible_in_tree():
			errors.append(id + "_card_unavailable")
			continue
		if id == "axe":
			await _click(button.get_global_rect().get_center())
		else:
			button.pressed.emit()
		await process_frame
		if str(weapons.fire_state.get("weaponId", "")) != id:
			errors.append(id + "_not_selected")
		if id != "hatchet" and str(storage.snapshot().hand_weapon) != id:
			errors.append(id + "_not_in_hand")
		if id == "axe" and bool(storage.snapshot().hand_shield):
			errors.append("two_handed_weapon_kept_shield")
	weapons.set_menu(true)
	weapons._input(_key(KEY_Q))
	if weapons.menu_open: errors.append("q_did_not_close_menu")
	# The separate shortcut still selects the bow without stealing Q.
	weapons._input(_key(KEY_7))
	if not bool(storage.snapshot().bow_active): errors.append("seven_did_not_select_bow")
	weapons._input(_key(KEY_7))
	if bool(storage.snapshot().bow_active): errors.append("seven_did_not_restore_weapon")
	print("CASTLE_Q_SELECTION ", JSON.stringify({"passed": errors.is_empty(), "errors": errors,
		"weapon": weapons.fire_state.get("weaponId", "none"), "storage": storage.snapshot()}))
	quit(0 if errors.is_empty() else 1)
