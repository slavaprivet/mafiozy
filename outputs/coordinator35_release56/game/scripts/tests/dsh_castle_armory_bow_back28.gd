extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _use(castle: Node3D, player: CharacterBody3D, at: Vector3) -> void:
	player.global_position = castle.to_global(at)
	if at.distance_to(Vector3(5.4, 0.1, -16.2)) < 0.2:
		castle.armory_storage.open_window()
	else:
		castle.armory_storage.interact()

func _run() -> void:
	var game: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(game)
	var castle: Node3D = game.get("preview_castle")
	var weapons: Node = game.get("preview_weapons")
	var player: CharacterBody3D = game.get("_player")
	var storage: Node = castle.armory_storage
	var errors: Array[String] = []
	player.set_mouse_captured(true)
	_use(castle, player, Vector3(9.1, 0.1, -18.05))
	_use(castle, player, Vector3(9.1, 0.1, -10.35))
	await process_frame
	var bow: Node = game.get("preview_bow_prototype")
	if not storage.snapshot().back_bow or storage.snapshot().bow_active or storage.snapshot().hand_weapon != "sword":
		errors.append("bow_with_sword_on_back")
	if not is_instance_valid(bow) or not bow._bow.visible or not bow._quiver.visible:
		errors.append("back_model_and_quiver")
	var q := InputEventKey.new(); q.physical_keycode = KEY_Q; q.keycode = KEY_Q; q.pressed = true
	weapons._input(q)
	if not storage.snapshot().bow_active or weapons.fire_state.get("weaponId", "") != "bow":
		errors.append("q_select_bow")
	if bow._arrows_left <= 0 or not bow._quiver_worn:
		errors.append("bow_has_no_arrows")
	var arrows_before: int = bow._arrows_left
	var aim := InputEventMouseButton.new(); aim.button_index = MOUSE_BUTTON_RIGHT; aim.pressed = true
	bow._input(aim)
	for frame: int in 420:
		await process_frame
		if bow.ready_to_fire(): break
	if not bow.ready_to_fire():
		print("CASTLE_BOW_DRAW_STATE ", JSON.stringify(bow.snapshot()))
		errors.append("bow_cannot_draw")
	else:
		var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.pressed = true
		bow._input(release)
		if bow._arrows_left != arrows_before - 1 or bow.last_fired_index() < 0:
			errors.append("bow_cannot_shoot")
	aim.pressed = false; bow._input(aim)
	weapons._input(q)
	await process_frame
	if storage.snapshot().bow_active or weapons.fire_state.get("weaponId", "") != "sword" or not bow._bow.visible:
		errors.append("q_return_sword")
	_use(castle, player, Vector3(9.1, 0.1, -9.0))
	if not storage.snapshot().hand_shield: errors.append("shield_with_back_bow")
	weapons._input(q)
	if not storage.snapshot().bow_active or storage.snapshot().hand_shield != true:
		errors.append("bow_selected_shield_owned")
	weapons._input(q)
	if storage.snapshot().bow_active or not storage.snapshot().hand_shield:
		errors.append("shield_rewear")
	_use(castle, player, Vector3(5.4, 0.1, -16.2))
	var stored: Dictionary = storage.store_held("bow")
	if not stored.get("ok", false) or storage.snapshot().back_bow or storage.snapshot().slots.size() != 1:
		errors.append("store_back_bow")
	var retrieved: Dictionary = storage._take_slot(0, int(storage.snapshot().revision))
	if not retrieved.get("ok", false) or not storage.snapshot().back_bow or storage.snapshot().slots.size() != 0:
		errors.append("retrieve_back_bow_once")
	storage.open_window()
	storage.store_held()
	storage.store_held("shield")
	storage.close_window()
	_use(castle, player, Vector3(9.1, 0.1, -14.65))
	if storage.snapshot().hand_weapon != "axe" or not storage.snapshot().back_bow:
		errors.append("twohand_with_back_bow")
	weapons._input(q)
	if not storage.snapshot().bow_active or weapons.fire_state.get("weaponId", "") != "bow":
		errors.append("q_twohand_to_bow")
	weapons._input(q)
	if storage.snapshot().bow_active or weapons.fire_state.get("weaponId", "") != "axe":
		errors.append("q_bow_to_twohand")
	print("CASTLE_ARMORY_BOW_BACK ", JSON.stringify({"passed": errors.is_empty(), "errors": errors,
		"state": storage.snapshot(), "arrows": bow._arrows_left, "selected": weapons.fire_state.get("weaponId", "none")}))
	await create_timer(0.5).timeout
	quit(0 if errors.is_empty() else 1)
