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
	var deadline := Time.get_ticks_msec() + 60000
	while game.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	if game.get("preview_ready") != true:
		push_error("castle preview timeout")
		quit(2)
		return
	for frame: int in 120:
		if game.get("_catapult_at_castle") == true: break
		await physics_frame
	var castle: Node3D = game.get("preview_castle")
	var weapons: Node = game.get("preview_weapons")
	var player: CharacterBody3D = game.get("_player")
	var storage: Node = castle.armory_storage
	var errors: Array[String] = []
	player.set_mouse_captured(true)
	game.set("_castle_spawn_frames", 0)
	_use(castle, player, Vector3(9.1, 0.1, -18.05))
	print("ARMORY_STAGE sword ", JSON.stringify(storage.snapshot()))
	if storage.snapshot().hand_weapon != "sword": errors.append("take_sword")
	var ground_blocked: Dictionary = storage.can_adopt_ground_melee31("axe", "sword", false)
	if ground_blocked.get("ok", true) or ground_blocked.get("reason", "") != "hand_occupied":
		errors.append("ground_axe_with_sword")
	var ground_after_throw: Dictionary = storage.can_adopt_ground_melee31("axe", "sword", true)
	if not ground_after_throw.get("ok", false) or not ground_after_throw.get("departed", false):
		errors.append("ground_replacement_after_throw")
	_use(castle, player, Vector3(9.1, 0.1, -17.15))
	if not storage.snapshot().rack.has("mace") or storage.snapshot().hand_weapon != "sword":
		errors.append("rack_second_onehand_with_sword")
	_use(castle, player, Vector3(9.1, 0.1, -14.65))
	print("ARMORY_STAGE axe_block ", JSON.stringify(storage.snapshot()))
	if not storage.snapshot().rack.has("axe") or storage.snapshot().hand_weapon != "sword":
		errors.append("rack_twohand_with_sword")
	if storage.interaction_label() != "Рука занята": errors.append("rack_occupied_label")
	_use(castle, player, Vector3(9.1, 0.1, -9.0))
	print("ARMORY_STAGE shield ", JSON.stringify(storage.snapshot()))
	if not storage.snapshot().hand_shield or not storage.snapshot().carried.has("shield"):
		errors.append("shield_on_wall_take")
	if storage.can_adopt_ground_melee31("axe", "sword", true).get("ok", true):
		errors.append("ground_axe_with_shield")
	_use(castle, player, Vector3(9.1, 0.1, -10.35))
	if storage.snapshot().rack.has("bow") or not storage.snapshot().back_bow or storage.snapshot().bow_active:
		errors.append("bow_stowed_with_sword_shield")
	_use(castle, player, Vector3(5.4, 0.1, -16.2))
	storage.store_held()
	if storage.snapshot().hand_weapon != "" or not storage.snapshot().hand_shield:
		errors.append("sword_to_chest_shield_remains")
	storage._take_slot(0, int(storage.snapshot().revision))
	if storage.snapshot().hand_weapon != "sword" or not storage.snapshot().hand_shield:
		errors.append("sword_from_chest_with_shield")
	storage.open_window(); storage.store_held(true); storage.close_window()
	if storage.snapshot().hand_shield or storage.snapshot().hand_weapon != "sword":
		errors.append("shield_to_chest")
	player.global_position = castle.to_global(Vector3(5.4, 0.1, -12.0))
	var g := InputEventKey.new(); g.physical_keycode = KEY_G; g.keycode = KEY_G; g.pressed = true
	weapons._input(g)
	if storage.snapshot().hand_weapon != "" or not storage.snapshot().fallen.has("sword"):
		errors.append("g_drop_sword")
	_use(castle, player, Vector3(9.1, 0.1, -14.65))
	if storage.snapshot().hand_weapon != "axe": errors.append("take_axe_empty_hands")
	_use(castle, player, Vector3(5.4, 0.1, -16.2))
	storage.store_held(); storage.close_window()
	if storage.snapshot().hand_weapon != "": errors.append("axe_to_chest")
	var dropped_sword: Vector3 = storage.snapshot().fallen.get("sword", Vector3(5.4, 0.1, -12.0))
	_use(castle, player, dropped_sword)
	if storage.snapshot().hand_weapon != "sword": errors.append("pickup_dropped_sword")
	storage.open_window()
	var axe_slot := -1
	for index: int in storage.snapshot().slots.size():
		if storage.snapshot().slots[index].id == "axe": axe_slot = index
	if axe_slot < 0: errors.append("axe_slot_missing")
	else:
		var blocked: Dictionary = storage._take_slot(axe_slot, int(storage.snapshot().revision))
		if blocked.get("reason", "") != "hand_occupied" or storage._feedback != "Рука занята":
			errors.append("chest_occupied_label")
	storage.close_window()
	weapons._input(g)
	if storage.snapshot().hand_weapon != "": errors.append("drop_for_twohand")
	storage.open_window()
	var taken: Dictionary = storage._take_slot(axe_slot, int(storage.snapshot().revision))
	if not taken.get("ok", false) or storage.snapshot().hand_weapon != "axe":
		errors.append("take_axe_after_drop")
	storage.open_window()
	var shield_slot := -1
	for index: int in storage.snapshot().slots.size():
		if storage.snapshot().slots[index].id == "shield": shield_slot = index
	if shield_slot < 0: errors.append("shield_slot_missing")
	else:
		var blocked: Dictionary = storage._take_slot(shield_slot, int(storage.snapshot().revision))
		if blocked.get("reason", "") != "hand_occupied" or storage.snapshot().hand_shield:
			errors.append("shield_with_axe")
	storage.store_held()
	var shield_taken: Dictionary = storage._take_slot(shield_slot, int(storage.snapshot().revision))
	if not shield_taken.get("ok", false) or not storage.snapshot().hand_shield:
		errors.append("shield_first_after_axe_stored")
	print("CASTLE_ARMORY_HANDS ", JSON.stringify({"passed": errors.is_empty(),
		"errors": errors, "state": storage.snapshot(), "equipped": weapons.fire_state.get("weaponId", "none")}))
	await create_timer(0.7).timeout
	quit(0 if errors.is_empty() else 1)
