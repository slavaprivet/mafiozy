extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.get("preview_ready") != true:
		print("CASTLE_CATAPULT_CARRY31 ", JSON.stringify({"passed": false, "errors": ["scene_not_ready"]}))
		quit(1); return
	var catapult: Node3D = scene.get("preview_catapult")
	var castle: Node3D = scene.get("preview_castle")
	var player: CharacterBody3D = scene.get("_player")
	var weapons: Node = scene.get("preview_weapons")
	var storage: Node = weapons.castle_storage_owner
	catapult.place_near_castle(castle)
	player.set_mouse_captured(true)
	for frame: int in 120: await physics_frame
	var equipped: Dictionary = weapons.equip("sword")
	if not bool(equipped.get("ok", false)): errors.append("sword_not_equipped")
	var owned_before: Dictionary = storage.snapshot().carried
	var stone: RigidBody3D = catapult.get("_stone")
	player.global_position = stone.global_position + Vector3(0.45, 0.0, 0.0)
	for frame: int in 6: await physics_frame
	catapult._try_interact()
	if not catapult.snapshot().carrying: errors.append("stone_not_taken")
	if not bool(weapons.get("_catapult_stone_carry")): errors.append("two_hands_not_reserved")
	if str(weapons.fire_state.weaponId) != "none": errors.append("weapon_still_active")
	if bool(weapons.equip("mace").get("ok", false)): errors.append("equipped_second_weapon_during_carry")
	if storage.snapshot().carried != owned_before: errors.append("ownership_changed_during_carry")
	var wheel: Node3D = catapult.get("_wheel_nodes")[0]
	var wheel_at_rest: float = wheel.rotation.x
	for frame: int in 30: await physics_frame
	if absf(wheel.rotation.x - wheel_at_rest) > 0.00001: errors.append("wheel_spins_at_rest")
	var hand_midpoint: Vector3 = catapult._hand_midpoint()
	if hand_midpoint == Vector3.ZERO or hand_midpoint.distance_to(stone.global_position) > 0.55:
		errors.append("stone_not_between_hands")
	var drop_key := InputEventKey.new()
	drop_key.physical_keycode = KEY_G
	drop_key.pressed = true
	Input.parse_input_event(drop_key)
	for frame: int in 3: await physics_frame
	if catapult.snapshot().carrying: errors.append("g_did_not_drop_stone")
	if str(weapons.fire_state.weaponId) != "sword": errors.append("sword_not_restored_after_drop")
	if storage.snapshot().carried != owned_before: errors.append("ownership_changed_after_drop")
	var shield_result: Dictionary = weapons.equip("shield")
	if not bool(shield_result.get("ok", false)): errors.append("shield_not_equipped")
	player.global_position = stone.global_position + Vector3(0.45, 0.0, 0.0)
	for frame: int in 3: await physics_frame
	catapult._try_interact()
	if not catapult.snapshot().carrying: errors.append("stone_not_retaken")
	var sword_host: Node = scene.get("preview_sword_prototype")
	if bool(sword_host.shield_status().get("worn", false)): errors.append("shield_still_in_hand_with_stone")
	player.global_position = catapult._spoon_point() + Vector3(0.0, 0.0, 1.0)
	catapult._try_interact()
	for frame: int in 28: await physics_frame
	if not catapult.snapshot().stone_on_spoon: errors.append("stone_not_loaded")
	if bool(weapons.get("_catapult_stone_carry")): errors.append("hands_not_released_after_loading")
	if str(weapons.fire_state.weaponId) != "sword": errors.append("sword_not_restored_after_loading")
	if not bool(sword_host.shield_status().get("worn", false)): errors.append("shield_not_restored_after_loading")
	if stone.collision_layer != 0: errors.append("loaded_stone_blocks_cart")
	var cart: CharacterBody3D = catapult.get("_cart")
	player.global_position = cart.global_position + Vector3(0.0, 0.05, -1.75)
	player._visual.rotation.y = 0.0
	var push_start: Vector3 = cart.global_position
	var previous_player: Vector3 = player.global_position
	var max_player_backstep := 0.0
	var max_player_side_step := 0.0
	Input.action_press(player.ACTION_FORWARD)
	for frame: int in 120:
		await physics_frame
		max_player_backstep = maxf(max_player_backstep, previous_player.z - player.global_position.z)
		max_player_side_step = maxf(max_player_side_step, absf(player.global_position.x - previous_player.x))
		previous_player = player.global_position
	Input.action_release(player.ACTION_FORWARD)
	if cart.global_position.distance_to(push_start) < 0.1: errors.append("loaded_cart_did_not_move")
	if max_player_backstep > 0.12 or max_player_side_step > 0.12:
		errors.append("player_jerks_while_pushing_loaded_cart")
	var before: Vector3 = catapult.get("_cart").global_position
	catapult._release()
	var highest := 0.0
	for frame: int in 24:
		await physics_frame
		highest = maxf(highest, float(catapult.snapshot().recoil_hop_y))
	var moved_forward: float = catapult.get("_cart").global_position.z - before.z
	if highest < 0.05: errors.append("no_recoil_hop")
	if moved_forward < 0.005: errors.append("no_forward_lurch")
	var wheels: Array = catapult.get("_wheel_nodes")
	if wheels.size() != 4: errors.append("wheel_count")
	for wheel_node: Node3D in wheels:
		if absf(wheel_node.position.x) < 1.15: errors.append("wheel_intersects_side_rail")
	print("CASTLE_CATAPULT_CARRY31 ", JSON.stringify({"passed": errors.is_empty(),
		"errors": errors, "recoil_hop_m": highest, "forward_lurch_m": moved_forward,
		"push_with_stone_m": cart.global_position.distance_to(push_start),
		"max_player_backstep_m": max_player_backstep, "max_player_sidestep_m": max_player_side_step,
		"wheels": wheels.size(), "owned": storage.snapshot().carried}))
	await create_timer(0.2).timeout
	quit(0 if errors.is_empty() else 1)
