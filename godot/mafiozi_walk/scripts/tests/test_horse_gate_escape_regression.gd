extends SceneTree

var _scene: Node
var _blockers: Array[StaticBody3D] = []

func _initialize() -> void:
	call_deferred("_run")

func _make_blocker(at: Vector3, size: Vector3, rubble: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TestRubble" if rubble else "TestIntactWall"
	body.collision_layer = 1
	body.collision_mask = 1
	if rubble:
		body.set_meta("castle_rubble", true)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_scene.add_child(body)
	body.global_position = at
	_blockers.append(body)
	return body

func _horse_volume_free(horse: CharacterBody3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 2.10, 2.35)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, horse.rotation.y),
		horse.global_position + Vector3.UP * 1.10)
	query.collision_mask = 1
	query.exclude = [horse.get_rid()]
	query.margin = 0.001
	return root.world_3d.direct_space_state.intersect_shape(query, 1).is_empty()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("HORSE_GATE_ESCAPE_RESULT FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true \
				and is_instance_valid(_scene.get("preview_horse_mount")):
			break
		await physics_frame
	var host: Node = _scene.get("preview_horse_mount")
	var castle: Node3D = _scene.get("preview_castle")
	var player: CharacterBody3D = _scene.get("_player")
	if not is_instance_valid(host) or not is_instance_valid(castle) \
			or not is_instance_valid(player):
		print("HORSE_GATE_ESCAPE_RESULT FAIL install")
		quit(1)
		return
	var horse: CharacterBody3D = host.get("horse")
	if not is_instance_valid(horse):
		print("HORSE_GATE_ESCAPE_RESULT FAIL horse")
		quit(1)
		return
	await physics_frame
	var failures: Array[String] = []
	var local_horse: Vector3 = castle.to_local(horse.global_position)
	var wall_half := float(castle.call("wall_half"))
	if absf(local_horse.x) < 6.0 and absf(local_horse.z - wall_half) < 4.0:
		failures.append("horse_in_gate_corridor")
	if not _horse_volume_free(horse):
		failures.append("horse_spawn_overlaps_world")
	player.set("_free_mouse_look", true)
	if not bool(host.call("mount_now")):
		failures.append("normal_mount_failed")
	elif not bool(host.call("dismount_now")):
		failures.append("normal_dismount_failed")
	if not failures.is_empty():
		print("HORSE_GATE_ESCAPE ", JSON.stringify({"horse_local": local_horse,
			"failures": failures, "snapshot": host.call("snapshot")}))
		print("HORSE_GATE_ESCAPE_RESULT FAIL")
		quit(1)
		return
	if not bool(host.call("mount_now")):
		failures.append("fallback_mount_failed")
	else:
		for side: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var at: Vector3 = horse.to_global(side * 2.15)
			_make_blocker(Vector3(at.x, horse.global_position.y + 1.0, at.z),
				Vector3(0.92, 2.0, 0.92), true)
		await physics_frame
		await physics_frame
		if not bool(host.call("dismount_now")):
			failures.append("rubble_fallback_failed")
		else:
			var receipt: Dictionary = host.get("_last_dismount")
			if not bool(receipt.get("fallback", false)):
				failures.append("fallback_not_reported")
			var radius := float(receipt.get("radius", 0.0))
			if radius < 3.19 or radius > 6.81:
				failures.append("fallback_radius_unbounded")
			if bool(player.get("_mount_mode")) or int(player.collision_layer) == 0:
				failures.append("walking_state_not_restored")
			if not bool(host.call("_capsule_free", player.global_position)):
				failures.append("fallback_capsule_blocked")
	# An intact wall may never be skipped by the emergency path query.
	var path_target := horse.global_position + horse.global_transform.basis.x.normalized() * 5.0
	var wall_at := horse.global_position.lerp(path_target, 0.5) + Vector3.UP * 1.05
	_make_blocker(wall_at, Vector3(0.35, 3.0, 4.0), false)
	await physics_frame
	if bool(host.call("_dismount_path_clear", path_target)):
		failures.append("intact_wall_was_skipped")
	print("HORSE_GATE_ESCAPE ", JSON.stringify({"horse_local": local_horse,
		"spawn_anchor": host.get("_safe_spawn_anchor"),
		"dismount": host.get("_last_dismount"), "failures": failures}))
	print("HORSE_GATE_ESCAPE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
