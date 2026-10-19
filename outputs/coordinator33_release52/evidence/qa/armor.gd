extends SceneTree
var out := "D:/MafioziCombat31/coordinator33/armor_graphical"
var scene: Node
var equipment: Node3D
var camera: Camera3D
var report: Dictionary = {}
func walk_probe(points: Array[Vector3]) -> bool:
	var body := CharacterBody3D.new()
	body.collision_layer = 0; body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.32; capsule.height = 1.75
	collision.shape = capsule; collision.position.y = 0.9
	body.add_child(collision); scene.add_child(body)
	body.global_position = points[0] + Vector3.UP * 0.03
	var reached := true
	for target: Vector3 in points.slice(1):
		var arrived := false
		for step in 240:
			await physics_frame
			var d := target - body.global_position; d.y = 0
			if d.length() < 0.15: arrived = true; break
			body.velocity = d.normalized() * 3.0 + Vector3.DOWN * 1.0
			body.move_and_slide()
		if not arrived:
			print("PATH_BLOCKED ",body.global_position," target=",target)
			reached = false; break
	body.queue_free()
	return reached
func _initialize() -> void: _run.call_deferred()
func shot(label: String, at: Vector3, target: Vector3) -> void:
	camera.global_position = at
	camera.look_at(target)
	camera.current = true
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	var deadline := Time.get_ticks_msec() + 100000
	while not scene.get("preview_ready") and Time.get_ticks_msec() < deadline: await process_frame
	equipment = scene.get_node_or_null("CastleArmorEquipment")
	if equipment == null or equipment.get("_stands") == null:
		quit(2); return
	var site: Node3D = scene.preview_castle
	var player: CharacterBody3D = scene._player
	camera = Camera3D.new(); scene.add_child(camera)
	await shot("armory", site.to_global(Vector3(8.0, 2.0, -15.5)), site.to_global(Vector3(8.3, 1.3, -19.15)))
	var light: StaticBody3D = equipment._stands.light.body
	await shot("tent", light.to_global(Vector3(0, 1.7, 3.3)), light.to_global(Vector3(0, 1.2, 0)))
	await shot("cross_back", light.to_global(Vector3(-1.7, 1.6, -1.3)), light.to_global(Vector3(0, 1.2, 0)))
	report["ready"] = bool(scene.preview_ready)
	report["stands"] = equipment._stands.size()
	report["unique_items"] = equipment.ground_items.size()
	var tent: Node3D = scene.preview_battlefield.get_node("BattlefieldProps/Cover_tent_5")
	report["tent_local"] = str(tent.to_local(light.global_position))
	report["tent_inside"] = tent.to_local(light.global_position).distance_to(Vector3(-1,.08,0)) < .01
	report["room_entry"] = await walk_probe([site.to_global(Vector3(0,.32,-14.2)), site.to_global(Vector3(4.5,.32,-14.2)), site.to_global(Vector3(4.5,.32,-16.1)), site.to_global(Vector3(8,.32,-16.1)), site.to_global(Vector3(8,.32,-17.3))])
	report["tent_entry"] = await walk_probe([tent.to_global(Vector3(4,.08,.65)), tent.to_global(Vector3(1,.08,.65)), tent.to_global(Vector3(.8,.08,0))])
	# Check each physical display socket can be selected from the front with the real camera ray.
	player.set_physics_process(false)
	player.set_process(false)
	player.set_mouse_captured(true)
	var player_camera: Camera3D = player.get_preview_camera()
	var focus_results: Dictionary = {}
	for id: String in equipment.ground_items.keys():
		var holder: Node3D = equipment.ground_items[id]
		var target: Vector3 = holder.to_global(holder.get_meta("focus_offset"))
		var front: Vector3 = holder.global_basis.z
		await physics_frame
		player.global_position = target + front * 1.4 - Vector3.UP * 0.4
		player_camera.global_position = target + front * 1.5
		player_camera.look_at(target)
		focus_results[id] = equipment.focused_item_id() == id
		if not focus_results[id]:
			var q := PhysicsRayQueryParameters3D.create(player_camera.global_position, target)
			q.exclude = [player.get_rid(), equipment._stands[holder.get_meta("stand_key")].body.get_rid()]
			print("FOCUS_DIAG ", id, " actual=", equipment.focused_item_id(), " usable=",equipment._usable(), " ray=",equipment.get_world_3d().direct_space_state.intersect_ray(q), " p=",player.global_position," camera=",player_camera.global_position," target=",target, " direction=", -player_camera.global_basis.z)
	report["focus"] = focus_results
	var transfer: Dictionary = {}
	for id: String in ["medium_torso", "light_torso", "heavy_torso"]:
		var holder: Node3D = equipment.ground_items[id]
		var target: Vector3 = holder.to_global(holder.get_meta("focus_offset"))
		player.global_position = target + holder.global_basis.z * 1.4 - Vector3.UP * .4
		player_camera.global_position = target + holder.global_basis.z * 1.5
		player_camera.look_at(target)
		transfer[id] = equipment.interact() and equipment.get_equipped_armor("torso") == id
	report["equip_swap"] = transfer
	report["no_duplicate_after_swap"] = equipment.ground_items.size() + equipment.equipped_by_slot.size() == 15
	var medium: StaticBody3D = equipment._stands.medium.body
	equipment.apply_melee_hit(medium, medium.global_position + Vector3.UP, 10.0, Vector3(0,2,1))
	equipment.apply_melee_hit(medium, medium.global_position + Vector3.UP, 10.0, Vector3(0,2,1))
	await physics_frame
	report["melee_broken"] = equipment._stands.medium.broken and not is_instance_valid(equipment._stands.medium.body)
	site.apply_explosion({"position":light.global_position + Vector3.UP,"radius":1.0,"power":60.0})
	await physics_frame
	report["explosion_broken"] = equipment._stands.light.broken and not is_instance_valid(equipment._stands.light.body)
	report["neighbor_preserved"] = not equipment._stands.heavy.broken
	report["no_duplicate_after_break"] = equipment.ground_items.size() + equipment.equipped_by_slot.size() == 15
	report["salvage"] = equipment.equip_ground("light_head").get("ok", false)
	await shot("broken_armory", site.to_global(Vector3(8, 2, -15.5)), site.to_global(Vector3(8, 1, -19)))
	var ok := true
	for value: Variant in focus_results.values(): ok = ok and bool(value)
	for value: Variant in transfer.values(): ok = ok and bool(value)
	for key: String in ["ready","tent_inside","room_entry","tent_entry","no_duplicate_after_swap","melee_broken","explosion_broken","neighbor_preserved","no_duplicate_after_break","salvage"]: ok = ok and bool(report[key])
	report["pass"] = ok
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ARMOR46 ",JSON.stringify(report))
	quit(0 if ok else 2)
