extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	var scene: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline: int = Time.get_ticks_msec() + 60000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.get("preview_ready") != true:
		print("CASTLE_CATAPULT_FALL31 ", JSON.stringify({"passed": false, "errors": ["scene_not_ready"]}))
		quit(1); return
	var catapult: Node3D = scene.get("preview_catapult")
	var player: CharacterBody3D = scene.get("_player")
	var stone: RigidBody3D = catapult.get("_stone")
	var weapons: Node = scene.get("preview_weapons")
	catapult.place_near_castle(scene.get("preview_castle"))
	for i: int in 100: await physics_frame
	if not bool(weapons.equip("sword").get("ok", false)):
		errors.append("sword_host_not_equipped")
	var low: int = catapult._stone_damage_for_speed(2.0)
	var medium: int = catapult._stone_damage_for_speed(5.0)
	var high: int = catapult._stone_damage_for_speed(10.0)
	if low != 0 or medium <= 0 or high <= medium or high < 90:
		errors.append("impact_energy_not_monotonic")
	player.global_position = Vector3(7.0, 0.1, 946.0)
	player.velocity = Vector3.ZERO
	for i: int in 15: await physics_frame
	catapult._stone_hit_victims.clear()
	catapult._carrying_stone = false
	catapult._stone_on_spoon = false
	catapult._loading = false
	catapult._stone_collision_enabled = true
	stone.freeze = false
	stone.collision_layer = 1
	stone.collision_mask = 1
	stone.linear_velocity = Vector3.ZERO
	stone.global_position = player.global_position + Vector3.UP * 8.5
	for i: int in 120:
		await physics_frame
		if not catapult.get("_last_stone_damage").is_empty(): break
	var hit: Dictionary = catapult.get("_last_stone_damage")
	if hit.is_empty(): errors.append("fall_did_not_hit_player")
	elif int(hit.get("damage", 0)) < 90 or not bool(hit.get("result", {}).get("dead", false)):
		errors.append("high_fall_not_lethal")
	var report := {"passed": errors.is_empty(), "errors": errors,
		"damage_at_2_5_10_mps": [low, medium, high], "fall_hit": hit,
		"player_dead": scene.get("preview_dead"),
		"sword_host": is_instance_valid(scene.get("preview_sword_prototype"))}
	print("CASTLE_CATAPULT_FALL31 ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
