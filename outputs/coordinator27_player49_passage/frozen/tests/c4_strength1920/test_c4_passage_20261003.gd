extends "frozen/test_c4.gd"
## QA only. Actual main, real Q/LMB/remote, then W/S through the same lower wall.
## Root alone owns engine slot, mutex, staging and the hard 60-second timeout.
const Observe = preload("frozen/c4_perf_observer45.gd")
const LIMIT_USEC := 55000000
const LANE_X := -3.0
const WALL_Z := 3.0
const START_Z := 4.6
const PLANT_Z := 4.15
const OUTSIDE_Z := 4.1
const INSIDE_Z := 1.9
const PLANT_LOCAL := Vector3(0.0, -.95, .17)
var phase := "source"
var manifest_path := ""
var blast: Node
var capsule: CollisionShape3D
var actor_policy: Dictionary = {}
var original_geometry: Dictionary = {}
var original_generation := -1
var wall_origin := Transform3D.IDENTITY
var movements: Array[Dictionary] = []
var outcomes: Dictionary = {}
var stable_ticks := 0
var setup_closed := false
var first_charge_frame := -1
var hold_actor := Vector3.ZERO
var hold_drift := 0.0
var watching_hold := false

func _process(delta: float) -> bool:
	super._process(delta)
	if finished: return false
	if started_usec > 0 and Time.get_ticks_usec() - started_usec > LIMIT_USEC:
		check(false, "INCOMPLETE: 55-second deadline in " + phase)
		finish()
		return false
	if watching_hold and is_instance_valid(player) and is_instance_valid(equipment):
		hold_drift = maxf(hold_drift, player.global_position.distance_to(hold_actor))
		if first_charge_frame < 0 and equipment._charges.size() == 1:
			first_charge_frame = Engine.get_physics_frames()
	return false

func provenance() -> bool:
	if not check(not manifest_path.is_empty(), "explicit root staged source manifest required"): return false
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not check(raw is Dictionary, "root source manifest readable"): return false
	var pins: Dictionary = raw.get("source_pins", raw.get("expected_source_pins", {}))
	if not check(not pins.is_empty(), "full project source pins required"): return false
	var bad: Array[String] = []
	for path: String in pins:
		if path.is_absolute_path() or path.contains("..") or path.contains(":") or FileAccess.get_sha256("res://" + path) != pins[path]: bad.append(path)
	var here: String = get_script().resource_path.get_base_dir()
	var frozen_sha: String = FileAccess.get_sha256(here.path_join("frozen/test_c4.gd"))
	check(frozen_sha == "12db538fe15d4419b72a62fc3868b8840dd2621a03159305c4ed244e60831b34", "exact inherited input helper retained")
	check(FileAccess.get_sha256("res://scripts/destruction/palazzo/c4_equipment.gd") == "11f9c4127d27a3349bc0e1242b3661fb9637e8f2bcd267217ade9db3c4e7cd29", "actual current C4 surface equipment")
	check(FileAccess.get_sha256("res://scripts/destruction/palazzo/c4_building_blast.gd") == "54a39ca265a692c77456e9f1e243924fc40bf9840509fa7dd6820a1d3adf2888", "actual final C4 1920/3.2/48 owner")
	evidence.provenance = {"manifest":manifest_path, "manifest_sha256":FileAccess.get_sha256(manifest_path), "checked":pins.size(), "mismatches":bad, "fixture_sha256":FileAccess.get_sha256(get_script().resource_path), "base_input_sha256":frozen_sha}
	return check(bad.is_empty(), "every staged runtime source matches root manifest") and failures.is_empty()

func current_policy() -> Dictionary:
	return {"actor_id":player.get_instance_id(), "life":player.get_meta("life_generation"), "layer":player.collision_layer, "mask":player.collision_mask, "capsule_id":capsule.get_instance_id(), "shape_id":capsule.shape.get_instance_id(), "disabled":capsule.disabled, "height":capsule.shape.height, "radius":capsule.shape.radius, "local_frame":str(capsule.transform), "walk_speed":player.walk_speed, "run_speed":player.run_speed}

func unchanged_actor(label: String) -> bool:
	return check(current_policy() == actor_policy and not capsule.disabled and camera == player.get_preview_camera(), label + ": same native actor/capsule/mask/speed/camera")

func ray_corridor(label: String) -> void:
	var rows: Array[Dictionary] = []
	var excluded: Array[RID] = [player.get_rid()]
	for height: float in [.4, .95, 1.5, 1.85]:
		var a: Vector3 = site.to_global(Vector3(LANE_X, height, 4.0))
		var b: Vector3 = site.to_global(Vector3(LANE_X, height, 2.0))
		var query := PhysicsRayQueryParameters3D.create(a, b, player.collision_mask, excluded)
		query.hit_from_inside = true
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		var body: CollisionObject3D = hit.get("collider") as CollisionObject3D
		rows.append({"height":height, "hit":not hit.is_empty(), "body":str(body.get_path()) if is_instance_valid(body) else "", "id":body.get_instance_id() if is_instance_valid(body) else 0, "layer":body.collision_layer if is_instance_valid(body) else 0, "point":Observe.vector(hit.get("position", Vector3.ZERO)), "detached":body.get_meta("detached", false) if is_instance_valid(body) else false})
	evidence[label] = rows

func aim_lane() -> bool:
	# Mouse-only adjustment to the facade-normal yaw; W and S then share a line.
	# Far target suppresses the native third-person shoulder's parallax.
	target = camera.global_position - site.global_basis.z.normalized() * 1000.0 + Vector3.DOWN * 80.0
	tracking = true
	var ready := 0
	for index: int in 180:
		await step()
		if finished: return false
		var yaw_error: float = absf(wrapf(player._camera_yaw - site.global_rotation.y, -PI, PI))
		if yaw_error < .0015 and player.velocity.length() < .06: ready += 1
		else: ready = 0
		if ready >= 6: break
	tracking = false
	return check(ready >= 6, "ordinary mouse input aligns movement with the same facade-normal lane")

func walk_line(label: String, code: Key, destination_z: float, max_frames: int, must_block: bool = false) -> bool:
	phase = label
	var start: Vector3 = site.to_local(player.global_position)
	var prior: Vector3 = start
	var stationary := 0
	var rows: Array[Dictionary] = []
	var contacts: Dictionary = {}
	var low_z: float = start.z
	var max_lane_error := 0.0
	var max_height_change := 0.0
	var reached := false
	key(code, true)
	for index: int in max_frames:
		await step()
		if finished: key(code, false); return false
		var at: Vector3 = site.to_local(player.global_position)
		low_z = minf(low_z, at.z)
		max_lane_error = maxf(max_lane_error, absf(at.x - LANE_X))
		max_height_change = maxf(max_height_change, absf(at.y - start.y))
		var delta_xz: float = Vector2(at.x - prior.x, at.z - prior.z).length()
		stationary = stationary + 1 if delta_xz < .003 else 0
		for c: int in player.get_slide_collision_count():
			var collision: KinematicCollision3D = player.get_slide_collision(c)
			var other: Object = collision.get_collider()
			if other is CollisionObject3D:
				contacts[str(other.get_instance_id())] = {"path":str(other.get_path()), "normal":Observe.vector(collision.get_normal()), "point":Observe.vector(collision.get_position()), "layer":other.collision_layer, "owned":site.owns_collider(other), "detached":other.get_meta("detached", false)}
		rows.append({"frame":Engine.get_physics_frames(), "local":Observe.vector(at), "velocity":Observe.vector(player.velocity), "on_floor":player.is_on_floor(), "held":Input.is_physical_key_pressed(code), "step_m":delta_xz})
		prior = at
		reached = at.z <= destination_z if code == KEY_W else at.z >= destination_z
		if reached or (must_block and stationary >= 12): break
	key(code, false)
	await step(8)
	if finished: return false
	var end: Vector3 = site.to_local(player.global_position)
	var record: Dictionary = {"label":label, "key":"W" if code == KEY_W else "S", "start":Observe.vector(start), "end":Observe.vector(end), "target_z":destination_z, "reached":reached, "stationary_ticks":stationary, "min_local_z":low_z, "max_lane_error_m":max_lane_error, "max_height_change_m":max_height_change, "contacts":contacts, "samples":rows}
	movements.append(record)
	check(max_lane_error <= .20 and max_height_change <= .60, label + ": stayed in the same lower-wall lane, not around or over it")
	unchanged_actor(label)
	if must_block:
		var physical_blocker := false
		for contact: Dictionary in contacts.values():
			if contact.owned and not contact.detached and absf(Vector3(contact.normal[0], contact.normal[1], contact.normal[2]).dot(site.global_basis.z.normalized())) > .5: physical_blocker = true
		return check(not reached and stationary >= 12 and low_z > WALL_Z + .17 and start.z - end.z >= .2 and physical_blocker, "before C4 actual W is blocked by intact lower Palazzo geometry")
	return check(reached, label + ": actual input reached the opposite endpoint")

func callback(event: Dictionary) -> Dictionary:
	# Only observe and forward the exact callback from the real physical item.
	var before: int = blast._pending.size()
	var result: Variant = original_callback.call(event)
	callbacks.append({"event_id":event.event_id, "placement_id":event.placement_id, "physics_frame":Engine.get_physics_frames(), "damage":event.damage, "radius":event.radius, "pending_before":before, "pending_after":blast._pending.size(), "result":result})
	return result if result is Dictionary else {"ok":false}

func plant_and_detonate() -> bool:
	phase = "plant_lower_wall"
	if not await q_choice(equipment._button, "actual inventory C4") or not await aim_wall(PLANT_LOCAL): return false
	var aimed: Dictionary = equipment._target()
	if not check(not aimed.is_empty() and aimed.body == wall, "actual lower stone wall admitted by equipment"): return false
	var local: Vector3 = wall.to_local(aimed.point)
	if not check(absf(local.x) < .10 and local.y < -.83, "charge aims below the window opening on solid stone"): return false
	hold_actor = player.global_position
	watching_hold = true
	var start_frame: int = Engine.get_physics_frames()
	mouse(MOUSE_BUTTON_LEFT, true)
	await create_timer(3.15, false, true).timeout
	if finished: return false
	var held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	mouse(MOUSE_BUTTON_LEFT, false)
	await step(3)
	watching_hold = false
	if not check(held and equipment._charges.size() == 1 and equipment.snapshot().mode == "remote", "real 3.15-second LMB plants exactly one charge"): return false
	check(first_charge_frame - start_frame >= ceili(3.0 * Engine.physics_ticks_per_second) - 1 and hold_drift <= .04 and callbacks.is_empty(), "independent hold clock, stationary actor and no premature blast")
	var id: String = str(equipment._charges.keys()[0])
	var charge: Node3D = equipment._charges[id].node.get_ref()
	if not check(is_instance_valid(charge) and charge.get_parent() == wall, "physical charge is attached to that same lower wall"): return false
	var charge_at: Vector3 = charge.global_position
	evidence.placement = {"id":id, "point":Observe.vector(charge_at), "contact":Observe.vector(aimed.point), "wall_local":Observe.vector(local), "start_frame":start_frame, "first_placed_frame":first_charge_frame, "drift_m":hold_drift, "wall_id":wall.get_instance_id(), "generation":site.rebuild_generation}
	await capture("passage_planted")
	if not await aim_lane(): return false
	if not await walk_line("native_retreat", KEY_S, 7.0, 150): return false
	if not check(player.global_position.distance_to(charge_at) > 3.5, "native S retreat safely exits charge radius"): return false
	phase = "detonation_and_support"
	var prior_fx: int = blast.snapshot().fx.total
	mouse(MOUSE_BUTTON_LEFT, true)
	mouse(MOUSE_BUTTON_LEFT, false)
	var immediate: Dictionary = blast.snapshot()
	check(callbacks.size() == 1 and immediate.pending == 1 and equipment._charges.is_empty(), "one remote click consumes and queues the real charge before physics")
	var settled := false
	for index: int in 900:
		await step()
		if finished: return false
		var state: Dictionary = blast.snapshot()
		var support: Dictionary = site._structure.diagnostics()
		var stable: bool = state.pending == 0 and state.events.size() == 1 and state.fx.active == 0 and support.get("ok", false) and not support.get("busy", true) and support.get("pending", -1) == 0 and support.get("state", "") == "stable"
		stable_ticks = stable_ticks + 1 if stable else 0
		if stable_ticks >= 30: settled = true; break
	var after: Dictionary = blast.snapshot()
	evidence.blast = after
	evidence.support_after_blast = site._structure.diagnostics()
	if not check(settled, "native support follow-up and FX both finish before passage, stable for 30 ticks"): return false
	if not check(after.events.size() == 1 and after.fx.total == prior_fx + 1, "exactly one committed native event and real effect"): return false
	var event: Dictionary = after.events[0]
	check(event.event_id == callbacks[0].event_id and event.physical_charge_consumed and event.damage == 1920 and event.radius == 3.2 and event.direct_fragment_budget == 48, "committed event keeps real item identity and final profile")
	check(not event.released.is_empty() and event.released.size() <= 48, "building fragments actually released within agreed bound")
	check(wall.get_meta("fracture_active", false) and wall.collision_layer == 0, "production fracture retires the original intact wall hull")
	var released: Array[Dictionary] = []
	for body_id: int in event.released:
		var body: Variant = instance_from_id(body_id)
		check(is_instance_valid(body) and body is RigidBody3D and site.owns_collider(body) and body.get_meta("detached", false), "each claimed fragment is an actual owned detached body")
		if is_instance_valid(body) and body is RigidBody3D:
			released.append({"id":body_id, "path":str(body.get_path()), "layer":body.collision_layer, "mask":body.collision_mask, "position":Observe.vector(body.global_position), "frozen":body.freeze, "parked":body.get_meta("parked", false)})
	evidence.released_bodies = released
	mouse(MOUSE_BUTTON_LEFT, true)
	mouse(MOUSE_BUTTON_LEFT, false)
	await step(3)
	check(callbacks.size() == 1 and blast.snapshot().fx.total == prior_fx + 1, "empty remote replay emits no new charge/effect")
	return failures.is_empty()

func run() -> void:
	started_usec = Time.get_ticks_usec()
	output = "res://tests/c4_passage_20261003.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		elif arg.begins_with("--qa-manifest="): manifest_path = arg.trim_prefix("--qa-manifest=")
	if DisplayServer.get_name() == "headless": screenshots = false
	if not provenance(): finish(); return
	phase = "main_startup"
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if not check(packed != null, "actual main scene available"): finish(); return
	game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	while not finished and game.get("preview_ready") != true: await process_frame
	if finished: return
	player = game._player
	weapons = game.preview_weapons
	camera = player.get_preview_camera()
	site = game.preview_palazzo.site
	equipment = game.get_node_or_null("LocalC4Equipment")
	blast = game.preview_c4_blast
	capsule = player.get_node_or_null("PlayerCapsule") as CollisionShape3D
	if not check(is_instance_valid(equipment) and equipment.snapshot().ready and is_instance_valid(blast) and is_instance_valid(capsule) and capsule.shape is CapsuleShape3D, "integrated C4 and original physical player configured"): finish(); return
	actor_policy = current_policy()
	original_geometry = Observe.geometry(site)
	original_generation = site.rebuild_generation
	evidence.original_geometry = original_geometry
	evidence.static_geometry = Observe.static_geometry_after_host(site)
	evidence.population_before = Observe.population(game)
	evidence.actor_policy = actor_policy
	check((player.collision_mask & 1) != 0 and (player.collision_mask & 512) == 0, "unchanged accepted movement/rubble policy: solid walls block, loose rubble uses native push")
	for body: RigidBody3D in site.wall_panels:
		if str(body.name).begins_with("Facade") and body.position.distance_to(Vector3(-3, 1.57, 3)) < .05: wall = body
	if not check(is_instance_valid(wall) and wall.freeze and not wall.get_meta("fracture_active", false), "intact front-left lower wall present"): finish(); return
	wall_origin = wall.global_transform
	original_callback = equipment._explosion
	if not check(original_callback.is_valid(), "original C4 callback bound"): finish(); return
	equipment._explosion = Callable(self, "callback")
	# The only actor/camera assignments are this explicit cold scenario setup.
	player.global_position = site.to_global(Vector3(LANE_X, .12, START_Z))
	player.velocity = Vector3.ZERO
	player._camera_yaw = site.global_rotation.y
	player._camera_pitch = -.08
	player._update_camera_rotation()
	setup_closed = true
	await step(25)
	if not player._free_mouse_look:
		mouse(MOUSE_BUTTON_LEFT, true); await step(); mouse(MOUSE_BUTTON_LEFT, false); await step(3)
	if not check(player._free_mouse_look and player.is_on_floor(), "native mouse capture and ground contact"): finish(); return
	if not await aim_lane(): finish(); return
	ray_corridor("corridor_before")
	outcomes.blocked_before = await walk_line("intact_W_blocked", KEY_W, INSIDE_Z, 120, true)
	if not outcomes.blocked_before: finish(); return
	await capture("passage_intact_blocked")
	if not await walk_line("back_to_placement", KEY_S, PLANT_Z, 90): finish(); return
	if not await plant_and_detonate(): finish(); return
	ray_corridor("corridor_after")
	await capture("passage_destroyed_outside")
	if not await aim_lane(): finish(); return
	outcomes.inside = await walk_line("through_breach_W", KEY_W, INSIDE_Z, 240)
	if not outcomes.inside: finish(); return
	await capture("passage_inside")
	outcomes.outside = await walk_line("back_through_breach_S", KEY_S, OUTSIDE_Z, 180)
	if not outcomes.outside: finish(); return
	await capture("passage_outside_again")
	evidence.final_geometry = Observe.geometry(site)
	evidence.population_after = Observe.population(game)
	check(evidence.final_geometry.native_stats.native_body_count == original_geometry.native_stats.native_body_count and evidence.final_geometry.native_stats.native_shape_count == original_geometry.native_stats.native_shape_count, "production native body/shape inventory retained through passage")
	check(site.rebuild_generation == original_generation and site.global_transform.is_finite(), "same building generation throughout, no J/reset/substitution")
	check(evidence.population_before.ids == evidence.population_after.ids and evidence.population_before.hp_owners == evidence.population_after.hp_owners, "original resident identities and HP owners retained")
	unchanged_actor("final")
	finish()

func finish() -> void:
	if finished: return
	watching_hold = false
	key(KEY_W, false); key(KEY_A, false); key(KEY_D, false); key(KEY_SHIFT, false); key(KEY_SPACE, false)
	evidence.phase = phase
	evidence.movements = movements
	evidence.outcomes = outcomes
	evidence.cold_setup_closed = setup_closed
	evidence.passage_complete = outcomes.get("blocked_before", false) and outcomes.get("inside", false) and outcomes.get("outside", false)
	evidence.scope = {"collision_or_damage_mutation":false, "transform_writes_after_cold_setup":false, "actual_native_player_input":true, "manual_OS_input":false, "performance_acceptance":false, "whole_building_or_other_facades":false, "loose_rubble_policy":"Existing player mask excludes512. Production push_from_actor handles released rubble. The fixture never changes that policy.", "root_floor_visual_and_commonwall_perf":"Separate pre-existing QA, intentionally not duplicated"}
	if not evidence.passage_complete: check(false, "INCOMPLETE: both directions of actual lower-wall passage were not established")
	super.finish()
