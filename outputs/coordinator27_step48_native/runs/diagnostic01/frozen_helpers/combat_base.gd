extends SceneTree
## External integration QA: ordinary main tick, walking population, attached camera.
## One explicit clear-floor player placement; no resident/HP/RNG/physics overrides.
var game: Node3D
var player: CharacterBody3D
var weapons: Node
var owner: RefCounted
var out := ""
var done := false
var tracking := false
var checks := 0
var errors: Array[String] = []
var shots: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var stages: Array[Dictionary] = []
var initial_actors: Dictionary = {}
var placement: Dictionary = {}
var dead_row: Dictionary = {}
var dead_revision := -1
var dead_impulse: Dictionary = {}
var observer: Camera3D

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: errors.append(label); print("FAIL ", label)
	return value

func sync(count: int = 1) -> void:
	for i in count:
		if done: return
		await physics_frame
		await process_frame

func button(code: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	player._unhandled_input(event)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	player._unhandled_input(event)

func physical() -> RefCounted:
	return game.preview_population.residents._ragdolls.get(owner._token.source_id)

func target_point() -> Vector3:
	var body := physical()
	if body != null and body.status().get("mode", "") == "ACTIVE":
		for segment: RigidBody3D in body.owned_bodies():
			if str(segment.name).to_lower().contains("chest"): return segment.global_position
		var segments: Array = body.owned_bodies()
		if not segments.is_empty(): return segments[0].global_position
	var rig: Skeleton3D = owner._token.rig
	var bone := rig.find_bone("head")
	var pose: Transform3D = rig.global_transform * rig.get_bone_global_pose(bone)
	return pose * ((owner._head_zone._head_min + owner._head_zone._head_max) * .5)

func aim() -> void:
	var camera: Camera3D = player.get_preview_camera()
	var direction := (target_point() - camera.global_position).normalized()
	var wanted_yaw := atan2(-direction.x, -direction.z)
	var wanted_pitch := asin(clampf(direction.y, -.99, .99))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(wanted_yaw - player._camera_yaw, -PI, PI) / player.mouse_sensitivity, -(wanted_pitch - player._camera_pitch) / player.mouse_sensitivity)
	player._unhandled_input(event)

func _process(_delta: float) -> bool:
	if tracking and not done:
		# Headless/offscreen input fixture only; this does not claim OS-focus QA.
		player._free_mouse_look = true
		aim()
	return false

func owns(collider: Variant) -> bool:
	if collider == owner._token.body: return true
	var body := physical()
	return body != null and collider in body.owned_bodies()

func sight() -> Dictionary:
	var camera: Camera3D = player.get_preview_camera()
	var ray: Dictionary = weapons._projectile_ray({"origin":camera.global_position, "direction":-camera.global_basis.z, "range":100.0})
	var muzzle: Dictionary = weapons.presentation.current_muzzle()
	if not ray.has("point") or not muzzle.get("ok", false): return {"ok":false, "reason":"camera_or_muzzle"}
	var direction: Vector3 = (ray.point - muzzle.origin).normalized()
	var actual: Dictionary = weapons._projectile_ray({"origin":muzzle.origin, "direction":direction, "range":muzzle.origin.distance_to(ray.point) + .03})
	return {"ok":owns(ray.get("collider")) and owns(actual.get("collider")), "camera_collider":str(ray.get("collider")), "muzzle_collider":str(actual.get("collider")), "point":str(actual.get("point"))}

func stage(label: String) -> void:
	var snapshot: Dictionary = owner.snapshot()
	stages.append({"label":label, "frame":Engine.get_physics_frames(), "row":snapshot.row, "physical":physical().status(), "marks":owner.marks.renderer._marks.size(), "postmortem":owner.get("postmortem_count"), "last_postmortem":owner.get("last_postmortem"), "ammo":weapons.fire_state.magazine, "player_move":player.completed_ground_move_receipt() if player.has_method("completed_ground_move_receipt") else {}})
	FileAccess.open(out.path_join("STAGES.json"), FileAccess.WRITE).store_string(JSON.stringify(stages, "  "))

func fire_once(label: String) -> bool:
	if weapons.fire_state.magazine == 0:
		key(KEY_R, true)
		await sync()
		key(KEY_R, false)
	for i in 240:
		if done: return false
		if float(weapons.fire_state.cooldown) <= 0 and float(weapons.fire_state.reloadRemaining) <= 0: break
		await sync()
	var clear := false
	for i in 120:
		await sync()
		if sight().get("ok", false): clear = true; break
	if not check(clear, label + ":attached_camera_and_native_muzzle_reach_target:" + str(sight())): return false
	var ammo: int = weapons.fire_state.magazine
	var count: int = weapons.shots_count
	var terminal_count := contacts.size()
	button(MOUSE_BUTTON_LEFT, true)
	await sync(2)
	button(MOUSE_BUTTON_LEFT, false)
	await sync(30)
	check(weapons.shots_count == count + 1, label + ":one_native_shot")
	check(weapons.fire_state.magazine == ammo - 1, label + ":finite_round_spent")
	check(contacts.size() > terminal_count, label + ":native_contact_emitted")
	stage(label)
	return true

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or done: return
	tracking = false
	observer.global_position = target_point() + Vector3(2.2, 1.2, 2.2)
	observer.look_at(target_point(), Vector3.UP)
	observer.make_current()
	await sync(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(label + ".png")) == OK, "capture:" + label)
	player.get_preview_camera().make_current()
	tracking = true

func place_player() -> bool:
	var at: Vector3 = owner._token.body.global_position + Vector3(0, 0, 6)
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4, at - Vector3.UP * 4, 1, [player.get_rid()])
	var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y < .9: return check(false, "clear_floor_fixture")
	var start: Vector3 = floor_hit.position + Vector3.UP * .03
	var shape: CollisionShape3D = player.get_node("PlayerCapsule")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(player.global_basis, start) * shape.transform
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.margin = 0
	if not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return check(false, "fixture_capsule_clear")
	placement = {"before":str(player.global_position), "after":str(start), "floor":str(floor_hit.collider), "one_explicit_setup_placement":true}
	player.global_position = start
	return true

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if out.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(100).timeout.connect(func():
		if not done: check(false, "bounded_timeout"); finish())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await sync(5)
	if not check(game.preview_ready and game.preview_population.hit_owners.size() == 3, "ordinary_main_three_actors"): finish(); return
	player = game._player
	weapons = game.preview_weapons
	for item: RefCounted in game.preview_population.hit_owners:
		initial_actors[item._token.source_id] = {"body":item._token.body.get_instance_id(), "rig":item._token.rig.get_instance_id(), "start":str(item._token.body.global_position), "row":item.snapshot().row}
		if item._token.source_id == "resident_72": owner = item
	if not check(owner != null and owner.get("postmortem_count") != null, "postmortem_candidate_bound"): finish(); return
	if not place_player(): finish(); return
	observer = Camera3D.new()
	game.add_child(observer)
	button(MOUSE_BUTTON_LEFT, true)
	button(MOUSE_BUTTON_LEFT, false)
	if not check(weapons.equip("tt_pistol").get("ok", false), "native_inventory_tt_equip"): finish(); return
	weapons.shot_emitted.connect(func(shot: Dictionary, muzzle: Dictionary, _origin: Vector3, _direction: Vector3):
		check(muzzle.get("ok", false) and muzzle.pose_revision == player._pose_revision, "fresh_native_presented_muzzle")
		shots.append({"shot_id":shot.shotId, "ammo":weapons.fire_state.magazine, "frame":Engine.get_physics_frames()}))
	weapons.effects.cosmetic_impact.connect(func(hit: Dictionary):
		contacts.append({"shot_id":hit.shotId, "point":str(hit.point), "collider":str(hit.collider), "owned":owns(hit.collider)}))
	tracking = true
	button(MOUSE_BUTTON_RIGHT, true)
	await sync(60)
	check(not player.get_preview_camera().top_level, "original_attached_camera")
	stage("before_fire")
	for i in 20:
		if owner.snapshot().row.get("dead", false): break
		if not await fire_once("live_" + str(i)): finish(); return
	if not check(owner.snapshot().row.get("dead", false) and physical().status().get("final_dead", false), "natural_final_death_from_actual_shots"): finish(); return
	await sync(60)
	dead_row = owner.snapshot().row.duplicate(true)
	dead_revision = int(owner.last_result.get("revision", -1))
	dead_impulse = owner.last_impulse.duplicate(true)
	await capture("01_dead_before_extra_hits")
	var before_marks: int = owner.marks.renderer._marks.size()
	var before_cosmetics: int = owner.postmortem_count
	for i in 3:
		if not await fire_once("postmortem_" + str(i)): finish(); return
		check(owner.snapshot().row == dead_row, "postmortem_row_unchanged_" + str(i))
		check(owner.last_impulse == dead_impulse, "postmortem_no_new_impulse_" + str(i))
		check(int(owner.last_result.get("revision", -1)) == dead_revision, "postmortem_hp_revision_unchanged_" + str(i))
	check(owner.postmortem_count >= before_cosmetics + 3, "three_authenticated_postmortem_receipts")
	check(owner.marks.renderer._marks.size() >= mini(24, before_marks + 3), "postmortem_marks_persist_cap24")
	await capture("02_dead_after_extra_hits")
	check(game.preview_population.hit_owners.size() == 3, "population_count_preserved")
	for item: RefCounted in game.preview_population.hit_owners:
		check(item._token.body.get_instance_id() == initial_actors[item._token.source_id].body and item._token.rig.get_instance_id() == initial_actors[item._token.source_id].rig, "original_actor_identity:" + item._token.source_id)
	finish()

func finish() -> void:
	if done: return
	done = true
	tracking = false
	if is_instance_valid(player):
		button(MOUSE_BUTTON_LEFT, false)
		button(MOUSE_BUTTON_RIGHT, false)
	var report := {"checks":checks, "errors":errors, "passed":errors.is_empty(), "scope":"ordinary main ticks and moving NPCs; real inventory equip/RMB/mouse motion/LMB/native muzzle/finite ammo; one clear-floor player fixture; no HP/RNG/resident/physics override; not manual OS input or FPS acceptance", "placement":placement, "initial_actors":initial_actors, "shots":shots, "contacts":contacts, "stages":stages, "test_sha256":FileAccess.get_sha256(get_script().resource_path)}
	FileAccess.open(out.path_join("RESULT.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("ORDINARY_POSTMORTEM_RESULT ", errors.size(), " failures / ", checks, " checks")
	if is_instance_valid(game): game.queue_free()
	quit(0 if errors.is_empty() else 1)
