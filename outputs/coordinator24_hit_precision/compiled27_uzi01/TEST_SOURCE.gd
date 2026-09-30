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
var precision: Array[Dictionary] = []
var corpse_target := "chest"
var reloads: Array[Dictionary] = []
var stages: Array[Dictionary] = []
var initial_actors: Dictionary = {}
var placement: Dictionary = {}
var dead_row: Dictionary = {}
var dead_revision := -1
var dead_impulse: Dictionary = {}
var observer: Camera3D
var measured_phase := ""
var measurement_started_us := 0
var phase_started_us := 0
var last_draw_us := 0
var total_draws := 0
var samples: Array[Dictionary] = []
var measured_phases: Array[Dictionary] = []
var camera_mismatches := 0
var sampler_total_us := 0
var sampler_max_us := 0
var expect_compiled := false
var expected_revision := ""
var runtime_scripts: Array[Dictionary] = []

func _initialize() -> void:
	# Never focus the diagnostic window or capture the user's system cursor.
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-32000, -32000))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	measurement_started_us = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	RenderingServer.frame_post_draw.connect(_drawn)
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
			if str(segment.name).to_lower().contains(corpse_target): return segment.global_position
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
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	phase_begin("alive_hit" if label.begins_with("live_") else "postmortem_hit", label)
	await RenderingServer.frame_post_draw # Prime interval before native input; retain the first impact cost.
	button(MOUSE_BUTTON_LEFT, true)
	await sync(2)
	button(MOUSE_BUTTON_LEFT, false)
	await sync(30)
	phase_end()
	check(weapons.shots_count == count + 1, label + ":one_native_shot")
	check(weapons.fire_state.magazine == ammo - 1, label + ":finite_round_spent")
	check(contacts.size() > terminal_count, label + ":native_contact_emitted")
	if label.begins_with("postmortem_"): check_precision(label)
	stage(label)
	return true

func reload_native() -> bool:
	phase_begin("native_reload", "R_partial_magazine")
	await RenderingServer.frame_post_draw
	var before := {"magazine":int(weapons.fire_state.magazine), "reserve":int(weapons.fire_state.reserveAmmo), "shots":int(weapons.shots_count), "uid":weapons.inventory.get_item_uid("uzi")}
	key(KEY_R, true)
	await sync()
	key(KEY_R, false)
	if not check(float(weapons.fire_state.reloadRemaining) > 0.0, "actual_R_starts_native_reload"): return false
	for i in 240:
		if done: return false
		if float(weapons.fire_state.reloadRemaining) <= 0.0: break
		await sync()
	var after := {"magazine":int(weapons.fire_state.magazine), "reserve":int(weapons.fire_state.reserveAmmo), "shots":int(weapons.shots_count), "uid":weapons.inventory.get_item_uid("uzi")}
	phase_end()
	reloads.append({"before":before, "after":after, "frame":Engine.get_physics_frames()})
	check(float(weapons.fire_state.reloadRemaining) == 0.0 and after.magazine > before.magazine, "actual_R_completes_and_refills_partial_magazine")
	check(after.reserve < before.reserve and before.magazine + before.reserve == after.magazine + after.reserve, "reload_conserves_finite_ammunition")
	check(after.shots == before.shots and after.uid == before.uid, "reload_no_extra_shot_or_weapon_replacement")
	stage("native_R_reload")
	return true

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or done: return
	phase_end() # Observer camera and PNG readback are excluded from every measured phase.
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
	var shape: CollisionShape3D = player.get_node("PlayerCapsule")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.margin = 0
	placement = {"attempts":[], "one_explicit_setup_placement":true}
	# The old +Z6m fixture collided before firing. Select one actually clear
	# ground location with read-only native queries, then make exactly one move.
	for distance: float in [6.0, 4.5, 8.0]:
		for angle: float in [PI, -3.0*PI/4.0, 3.0*PI/4.0, -PI/2.0, PI/2.0, -PI/4.0, PI/4.0, 0.0]:
			var at: Vector3 = owner._token.body.global_position + Vector3(sin(angle), 0, cos(angle)) * distance
			var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4, at - Vector3.UP * 4, 1, [player.get_rid()])
			var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
			var probe := {"at":str(at), "distance":distance, "angle":angle}
			if floor_hit.is_empty() or floor_hit.normal.y < .9:
				probe["rejection"] = "missing_or_sloped_floor"; placement.attempts.append(probe); continue
			var start: Vector3 = floor_hit.position + Vector3.UP * .03
			query.transform = Transform3D(player.global_basis, start) * shape.transform
			var overlaps := player.get_world_3d().direct_space_state.intersect_shape(query, 4)
			if not overlaps.is_empty():
				probe["rejection"] = "capsule_obstructed"; probe["colliders"] = str(overlaps); placement.attempts.append(probe); continue
			var sight_ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 1.6, target_point(), 1, [player.get_rid(), owner._token.body.get_rid()])
			var obstruction := player.get_world_3d().direct_space_state.intersect_ray(sight_ray)
			if not obstruction.is_empty():
				probe["rejection"] = "world_obstructed"; probe["collider"] = str(obstruction.collider); placement.attempts.append(probe); continue
			probe["accepted"] = true; placement.attempts.append(probe)
			placement.merge({"before":str(player.global_position), "after":str(start), "floor":str(floor_hit.collider)})
			player.global_position = start
			return true
	return check(false, "native_clear_floor_fixture_not_found:" + str(placement))

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg == "--expect-compiled": expect_compiled = true
		if arg.begins_with("--expected-revision="): expected_revision = arg.trim_prefix("--expected-revision=")
	if out.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	if not check(DisplayServer.get_name() != "headless", "GPU_observer_requires_rendering_backend"): finish(); return
	var update_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	if not check(not expected_revision.is_empty() and str(update_data.get("runtime_revision", "")) == expected_revision, "exact_runtime_revision"): finish(); return
	create_timer(100).timeout.connect(func():
		if not done: check(false, "bounded_timeout"); finish())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await sync(5)
	if not check(game.preview_ready and game.preview_population.hit_owners.size() == 3, "ordinary_main_three_actors"): finish(); return
	player = game._player
	weapons = game.preview_weapons
	if not verify_runtime_scripts(): finish(); return
	check(root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "NO_FOCUS_window")
	for item: RefCounted in game.preview_population.hit_owners:
		initial_actors[item._token.source_id] = {"body":item._token.body.get_instance_id(), "rig":item._token.rig.get_instance_id(), "start":str(item._token.body.global_position), "row":item.snapshot().row}
		if item._token.source_id == "resident_72": owner = item
	if not check(owner != null and owner.get("postmortem_count") != null, "postmortem_candidate_bound"): finish(); return
	if not place_player(): finish(); return
	observer = Camera3D.new()
	game.add_child(observer)
	# External logical-input fixture: skip the initial OS-cursor acquisition click.
	player._free_mouse_look = true
	if not check(weapons.equip("uzi").get("ok", false), "native_inventory_uzi_equip"): finish(); return
	weapons.shot_emitted.connect(func(shot: Dictionary, muzzle: Dictionary, _origin: Vector3, _direction: Vector3):
		check(muzzle.get("ok", false) and muzzle.pose_revision == player._pose_revision, "fresh_native_presented_muzzle")
		shots.append({"at_us":Time.get_ticks_usec()-measurement_started_us, "shot_id":shot.shotId, "ammo":weapons.fire_state.magazine, "frame":Engine.get_physics_frames()}))
	weapons.effects.cosmetic_impact.connect(func(hit: Dictionary):
		contacts.append({"at_us":Time.get_ticks_usec()-measurement_started_us, "frame":Engine.get_physics_frames(), "shot_id":hit.shotId, "point":str(hit.point), "world_point":hit.point, "incoming":hit.direction, "normal":hit.normal, "collider":str(hit.collider), "owned":owns(hit.collider)}))
	tracking = true
	button(MOUSE_BUTTON_RIGHT, true)
	phase_begin("before_fire", "ordinary_attached_aim_60_ticks")
	await sync(60)
	phase_end()
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
	if not await reload_native(): finish(); return
	await capture("01_dead_before_extra_hits")
	var before_marks: int = owner.marks.renderer._marks.size()
	var before_cosmetics: int = owner.postmortem_count
	for i in 3:
		corpse_target = ["spine_01", "pelvis", "chest"][i]
		if not await fire_once("postmortem_" + str(i)): finish(); return
		check(owner.snapshot().row == dead_row, "postmortem_row_unchanged_" + str(i))
		check(owner.last_impulse == dead_impulse, "postmortem_no_new_impulse_" + str(i))
		check(int(owner.last_result.get("revision", -1)) == dead_revision, "postmortem_hp_revision_unchanged_" + str(i))
	check(owner.postmortem_count >= before_cosmetics + 3, "three_authenticated_postmortem_receipts")
	check(owner.marks.renderer._marks.size() >= mini(24, before_marks + 3), "postmortem_marks_persist_cap24")
	phase_begin("rest", "ordinary_attached_aim_120_ticks")
	await sync(120)
	phase_end()
	await capture("02_dead_after_extra_hits")
	check(game.preview_population.hit_owners.size() == 3, "population_count_preserved")
	for item: RefCounted in game.preview_population.hit_owners:
		check(item._token.body.get_instance_id() == initial_actors[item._token.source_id].body and item._token.rig.get_instance_id() == initial_actors[item._token.source_id].rig, "original_actor_identity:" + item._token.source_id)
	finish()

func finish() -> void:
	if done: return
	phase_end()
	if is_instance_valid(player):
		check(total_draws > 0 and not samples.is_empty(), "actual_rendered_frame_samples")
		check(camera_mismatches == 0, "all_measured_frames_use_original_attached_camera")
		check(root.unfocusable and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "diagnostic_final_NO_FOCUS_and_cursor_visible")
	FileAccess.open(out.path_join("GPU_METRICS.json"), FileAccess.WRITE).store_string(JSON.stringify(metrics_report(), "  "))
	done = true
	tracking = false
	if is_instance_valid(player):
		button(MOUSE_BUTTON_LEFT, false)
		button(MOUSE_BUTTON_RIGHT, false)
	var final_actors := {}
	if is_instance_valid(game) and game.preview_population != null:
		for item: RefCounted in game.preview_population.hit_owners:
			final_actors[item._token.source_id] = {"position":str(item._token.body.global_position), "body":item._token.body.get_instance_id(), "rig":item._token.rig.get_instance_id(), "row":item.snapshot().row}
	var report := {"checks":checks, "errors":errors, "passed":errors.is_empty(), "scope":"ordinary main ticks and moving NPCs; real inventory equip/RMB/mouse motion/LMB/native muzzle/finite ammo and actual R reload; one clear-floor player fixture; no HP/RNG/resident/physics override; not manual OS input or FPS acceptance", "placement":placement, "initial_actors":initial_actors, "final_actors":final_actors, "shots":shots, "contacts":contacts, "precision":precision, "reloads":reloads, "stages":stages, "test_sha256":FileAccess.get_sha256(get_script().resource_path)}
	FileAccess.open(out.path_join("RESULT.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("ORDINARY_POSTMORTEM_RESULT ", errors.size(), " failures / ", checks, " checks")
	if is_instance_valid(game): game.queue_free()
	quit(0 if errors.is_empty() else 1)

func verify_runtime_scripts() -> bool:
	for object: Object in [game, player, weapons, game.preview_population]:
		var script: Script = object.get_script()
		if not check(script != null, "runtime_script_exists"): return false
		var record := {"path":script.resource_path, "has_source_code":script.has_source_code()}
		runtime_scripts.append(record)
		if expect_compiled and not check(not script.has_source_code(), "compiled_runtime_script:" + script.resource_path): return false
	return true

func phase_begin(name: String, detail: String) -> void:
	phase_end()
	measured_phase = name
	phase_started_us = Time.get_ticks_usec()
	last_draw_us = 0 # Skip intervals crossing setup, camera swaps, readback or phase boundaries.
	measured_phases.append({"name":name, "detail":detail, "start_us":phase_started_us - measurement_started_us, "start_frame":Engine.get_physics_frames(), "sample_start":samples.size()})

func phase_end() -> void:
	if measured_phase.is_empty(): return
	var phase: Dictionary = measured_phases[-1]
	phase["end_us"] = Time.get_ticks_usec() - measurement_started_us
	phase["end_frame"] = Engine.get_physics_frames()
	phase["sample_end"] = samples.size()
	phase["summary"] = summarize(samples.slice(int(phase.sample_start), samples.size()))
	measured_phase = ""
	last_draw_us = 0

func _drawn() -> void:
	if done: return
	total_draws += 1
	if measured_phase.is_empty(): return
	var now := Time.get_ticks_usec()
	if last_draw_us > 0:
		var viewport_rid := root.get_viewport_rid()
		var attached: bool = is_instance_valid(player) and root.get_camera_3d() == player.get_preview_camera() and not player.get_preview_camera().top_level
		if not attached: camera_mismatches += 1
		samples.append({"at_us":now - measurement_started_us, "phase":measured_phase, "physics_frame":Engine.get_physics_frames(), "process_frame":Engine.get_process_frames(), "frame_post_draw_ms":(now-last_draw_us)/1000.0,
			"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid), "render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),
			"process_monitor_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, "physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
			"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC), "vram_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"drawcalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"active_bodies":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), "shot_count":int(weapons.shots_count), "attached_camera":attached})
	last_draw_us = now
	var cost := Time.get_ticks_usec() - now
	sampler_total_us += cost
	sampler_max_us = maxi(sampler_max_us, cost)

func summarize(rows: Array) -> Dictionary:
	var summary := {"count":rows.size()}
	for metric: String in ["frame_post_draw_ms", "gpu_ms", "render_cpu_ms", "process_monitor_ms", "physics_monitor_ms", "static_bytes", "vram_bytes", "drawcalls", "primitives", "active_bodies"]:
		var values: Array[float] = []
		for row: Dictionary in rows: values.append(float(row[metric]))
		values.sort()
		if values.is_empty(): continue
		summary[metric] = {"min":values[0], "p50":values[int(floor((values.size()-1)*.50))], "p95":values[int(ceil((values.size()-1)*.95))], "max":values[-1]}
	return summary

func metrics_report() -> Dictionary:
	var positive_gpu := 0
	for sample: Dictionary in samples:
		if float(sample.gpu_ms) > 0.0: positive_gpu += 1
	return {"scope":"Diagnostic full-scene offscreen render; ordinary main/player/NPC/transport ticks, attached combat camera; logical event fixture, not OS-input or standalone FPS acceptance. No world, population, physics, rate or graphics-setting overrides.",
		"phase_interval_policy":"First frame per phase excluded; screenshot observer camera and PNG readback excluded. GPU/Performance telemetry may refer to earlier frames; shot_count and frame IDs provide correlation, not exclusive callback cost.",
		"primitive_policy":"Godot RENDER_TOTAL_PRIMITIVES_IN_FRAME is reported as primitives; it is not asserted to be an exact triangle count for non-triangle draws.",
		"memory_policy":"Godot static memory and reported video allocation only; not process RSS or peak committed memory.",
		"backend":DisplayServer.get_name(), "engine":Engine.get_version_info(), "runtime_scripts":runtime_scripts, "expect_compiled":expect_compiled,
		"expected_revision":expected_revision, "window_size":str(root.size), "window_position":str(DisplayServer.window_get_position()), "unfocusable":root.unfocusable,
		"physics_ticks_per_second":Engine.physics_ticks_per_second, "engine_max_fps":Engine.max_fps, "vsync_mode":DisplayServer.window_get_vsync_mode(),
		"total_rendered_frames":total_draws, "camera_mismatches":camera_mismatches, "positive_gpu_samples":positive_gpu, "gpu_telemetry_available":positive_gpu > 0,
		"sampler_total_us":sampler_total_us, "sampler_max_us":sampler_max_us, "phases":measured_phases, "samples":samples}

func check_precision(label: String) -> void:
	# Read the actual native receipt and immutable accept-time anchor metadata.
	# No ray/point/mark is created by this instrumentation.
	var post: Dictionary = owner.last_postmortem
	var impact: Dictionary = {}
	var expected_shot: String = str(shots[-1].shot_id)
	for item: Dictionary in contacts:
		if str(item.shot_id)==expected_shot and item.owned: impact=item
	if not check(not impact.is_empty() and str(post.get("shot_id", ""))==expected_shot and post.get("rendered",false),label+":exact_native_postmortem_contact_rendered"): return
	var accepted: Dictionary = {}
	for mark: Dictionary in owner.marks.renderer._marks:
		if mark.id==post.event_id: accepted=mark
	if not check(not accepted.is_empty(),label+":same_event_id_visible_mark"): return
	var ray_origin: Vector3 = impact.world_point
	var direction: Vector3 = impact.incoming.normalized()
	var centers: Array[Vector3] = []
	for triangle: Dictionary in accepted.triangles:
		for anchor: Dictionary in triangle.anchors:
			if anchor.probe==Vector2.ZERO: centers.append(anchor.world_point)
	if not check(not centers.is_empty(),label+":original_triangle_center_anchors_exist"): return
	var maximum_lateral := 0.0
	var minimum_axial := INF
	var maximum_axial := -INF
	for center: Vector3 in centers:
		var difference := center-ray_origin
		var axial := difference.dot(direction)
		maximum_lateral=maxf(maximum_lateral,(difference-direction*axial).length())
		minimum_axial=minf(minimum_axial,axial)
		maximum_axial=maxf(maximum_axial,axial)
	var camera: Camera3D=player.get_preview_camera()
	var camera_direction: Vector3=(target_point()-camera.global_position).normalized()
	precision.append({"label":label,"shot_id":expected_shot,"event_id":post.event_id,"intended_physical_part":corpse_target,"actual_native_collider":impact.collider,"native_contact":str(ray_origin),"native_direction":str(direction),"accept_time_center":str(centers[0]),"center_anchor_count":centers.size(),"maximum_lateral_error_m":maximum_lateral,"minimum_signed_axial_m":minimum_axial,"maximum_signed_axial_m":maximum_axial,"camera_downward_component":-camera_direction.y,"native_incoming_downward_component":-direction.y,"original_attached_camera":not camera.top_level})
	check(maximum_lateral<=.0001,label+":center_matches_actual_projectile_ray_within_0_1mm")
	check(minimum_axial>=-.001 and maximum_axial<=float(owner.marks._height)*1.5+.001,label+":center_inside_original_forward_mesh_admission_depth")
