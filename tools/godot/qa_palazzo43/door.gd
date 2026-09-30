extends SceneTree
## Independent v4 QA, based on revision3's actual main/E/input fixture.
## Cold actor setup is explicit. After each setup, no scripted player movement
## occurs while a close/refusal/rollback is measured. No runtime fields written.
var game: Node3D
var host: Node
var player: CharacterBody3D
var camera: Camera3D
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var finished := false
var output := "res://tests/door43_result.json"
var screenshots := true
var pose_writes := 0
var watching := false
var watch_origin := Vector3.ZERO
var watch_max_delta := 0.0
var watch_pose_writes := 0

func _initialize() -> void:
	run.call_deferred()

func _process(_delta: float) -> bool:
	if watching and is_instance_valid(player):
		watch_max_delta = maxf(watch_max_delta, player.global_position.distance_to(watch_origin))
	return false

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); print("DOOR43_V4 FAIL ", label)
	return ok

func step(count: int = 1) -> void:
	for index: int in count:
		if finished: return
		await physics_frame
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = pressed
	root.push_input(event, true)

func press_e() -> void:
	key(KEY_E, true); await step(); key(KEY_E, false)

func pose(local: Vector3, yaw: float) -> void:
	check(not watching, "fixture never writes actor position during a measured scenario")
	pose_writes += 1
	player.global_position = host.site.to_global(local); player.velocity = Vector3.ZERO
	player._camera_yaw = yaw + host.site.global_rotation.y; player._camera_pitch = -0.08
	player._update_camera_rotation()

func aim(local_target: Vector3) -> void:
	for index: int in 70:
		var direction: Vector3 = (host.site.to_global(local_target) - camera.global_position).normalized()
		var yaw: float = atan2(-direction.x, -direction.z)
		var pitch: float = asin(clampf(direction.y, -0.98, 0.98))
		var event := InputEventMouseMotion.new()
		event.position = root.get_visible_rect().get_center(); event.global_position = event.position
		event.relative = Vector2(-clampf(wrapf(yaw - player._camera_yaw, -PI, PI) * 0.35, -0.045, 0.045) / player.mouse_sensitivity, -clampf((pitch - player._camera_pitch) * 0.35, -0.045, 0.045) / player.mouse_sensitivity)
		root.push_input(event, true); await step()

func watch_start() -> void:
	watch_origin = player.global_position; watch_max_delta = 0.0
	watch_pose_writes = pose_writes; watching = true

func watch_end(label: String, require_stationary: bool = true) -> Dictionary:
	watching = false
	var row := {"before":watch_origin, "after":player.global_position, "maximum_displacement_m":watch_max_delta, "fixture_pose_writes_during_measurement":pose_writes - watch_pose_writes}
	check(pose_writes == watch_pose_writes, label + ": no scripted actor movement after setup")
	if require_stationary: check(watch_max_delta <= 0.002, label + ": actual actor remains at the setup position (2 mm numerical tolerance)")
	return row

func helper_state() -> Dictionary:
	var helper: Variant = host.site.get("_door_close43")
	return helper.snapshot() if helper != null else {"phase":"not_created", "owned_exception_pairs":0}

func own_parts() -> Array[PhysicsBody3D]:
	var result: Array[PhysicsBody3D] = [host.site._door]
	var glazing: Node = host.site.get_node_or_null("OwnedWindowGlazing")
	if not is_instance_valid(glazing): return result
	for child: Node in glazing.get_children():
		if not child is StaticBody3D: continue
		var proof: Dictionary = glazing.call("validate_pane_contact", child, child.global_position)
		if proof.get("ok", false) and proof.get("wall") == host.site._door: result.append(child)
	return result

func exception_ids(body: PhysicsBody3D) -> Array[int]:
	var ids: Array[int] = []
	if not is_instance_valid(body): return ids
	for other: PhysicsBody3D in body.get_collision_exceptions():
		if is_instance_valid(other): ids.append(other.get_instance_id())
	ids.sort(); return ids

func exception_snapshot(parts: Array[PhysicsBody3D]) -> Dictionary:
	var result := {"player":exception_ids(player), "parts":{}}
	for part: PhysicsBody3D in parts:
		if is_instance_valid(part): result.parts[str(part.get_instance_id())] = exception_ids(part)
	return result

func overlaps(parts: Array[PhysicsBody3D], actor: PhysicsBody3D, closed_pose: bool = false, probe_angle: float = -1.0) -> bool:
	var excluded: Array[RID] = []
	for part: PhysicsBody3D in parts:
		if is_instance_valid(part): excluded.append(part.get_rid())
	var current_leaf: Transform3D = host.site._door.global_transform
	var projected: bool = closed_pose or probe_angle >= 0.0
	var closed_leaf: Transform3D = host.site.building.global_transform * host.site._door_pose(0.0 if closed_pose else maxf(0.0, probe_angle))
	for part: PhysicsBody3D in parts:
		if not is_instance_valid(part): continue
		var frame: Transform3D = closed_leaf * current_leaf.affine_inverse() * part.global_transform if projected else part.global_transform
		for child: Node in part.get_children():
			if not child is CollisionShape3D or child.disabled or child.shape == null: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape; query.transform = frame * child.transform
			query.collision_mask = 0xFFFFFFFF; query.exclude = excluded
			var hits: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(query, 64)
			if hits.size() >= 64: check(false, "independent overlap query saturated"); return true
			for hit: Dictionary in hits:
				if hit.get("collider") == actor: return true
	return false

func foreign_actor(local: Vector3, static_actor: bool = false) -> PhysicsBody3D:
	var npc: PhysicsBody3D = StaticBody3D.new() if static_actor else CharacterBody3D.new()
	npc.name = "Door43LegacyActor_StaticLayer2" if static_actor else "Door43ForeignNPC_Layer1"
	npc.collision_layer = 2 if static_actor else 1; npc.collision_mask = 1
	var collision := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30; capsule.height = 1.80
	collision.shape = capsule; collision.position = Vector3(0, 0.9, 0)
	npc.add_child(collision); game.add_child(npc)
	npc.global_position = host.site.to_global(local)
	return npc

func capture_closed(label: String) -> void:
	if not screenshots:
		evidence[label] = {"skipped":true, "reason":"headless display"}; return
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if not check(pixels != null and not pixels.is_empty(), "actual closing result screenshot available"): return
	var path: String = output.get_base_dir().path_join(label + ".png")
	var error: Error = pixels.save_png(path)
	check(error == OK, "actual closed screenshot saved")
	evidence[label] = {"path":path, "error":error, "open":host.site._door_open, "angle":host.site._door_angle, "actor":player.global_position, "current_camera":camera == root.get_camera_3d()}

func open_from_outside(label: String) -> bool:
	pose(Vector3(1, 0.11, 4.3), 0.0); await step(12); await aim(Vector3(1, 1.57, 3))
	if not check(game._current_door_action().get("owner") == "palazzo", label + ": real door selected outside"): return false
	if not host.site._door_open:
		await press_e(); await step(40)
	return check(host.site._door_open and absf(host.site._door_angle - PI * 0.5) < 0.001, label + ": actual E leaves door fully open")

func positive_inside() -> bool:
	if not await open_from_outside("positive"): return false
	pose(Vector3(1, 0.31, 2.2), PI); await step(12); await aim(Vector3(1, 1.57, 3))
	if not check(game._current_door_action().get("owner") == "palazzo", "inside-arc positive selects opening"): return false
	var parts: Array[PhysicsBody3D] = own_parts()
	check(parts.size() > 1, "positive includes the actual door leaf and its exact native pane")
	check(not overlaps(parts, player, true), "independent final closed geometry is free of initiator before E")
	var previous: Dictionary = exception_snapshot(parts)
	watch_start(); await press_e(); await step(2)
	var active: Dictionary = helper_state()
	check(active.phase == "moving" and active.owned_exception_pairs > 0, "E inside arc starts closing with scoped initiator pairs")
	await step(40)
	check(not host.site._door_open and absf(host.site._door_angle) < 0.001, "inside-arc positive ends fully CLOSED")
	check(watch_max_delta <= 0.002 and pose_writes == watch_pose_writes, "close preserves the real actor position without any fixture pose write")
	check(not overlaps(parts, player), "closed leaf and real pane do not overlap unchanged actor")
	check(helper_state().phase == "idle" and helper_state().owned_exception_pairs == 0, "successful close ends helper and removes owned pairs")
	check(exception_snapshot(parts) == previous, "successful close restores exact symmetric exception baseline")
	var closed_state: Dictionary = helper_state()
	var closed_position: Vector3 = player.global_position
	await capture_closed("inside_arc_closed")
	check(game._current_door_action().get("owner") == "palazzo", "same unchanged inside point immediately selects OPEN AGAIN")
	await press_e(); await step(2)
	var reopen_active: Dictionary = helper_state()
	check(reopen_active.phase == "moving" and reopen_active.owned_exception_pairs > 0, "OPEN AGAIN protects only the same initiating actor through the sweep")
	await step(40)
	var motion: Dictionary = watch_end("inside-arc CLOSE then OPEN AGAIN")
	check(host.site._door_open and absf(host.site._door_angle - PI * 0.5) < 0.001, "same-position native E opens again to the exact fully open angle")
	check(not overlaps(parts, player), "reopened leaf and own pane do not overlap the unchanged actor")
	check(helper_state().phase == "idle" and helper_state().owned_exception_pairs == 0 and exception_snapshot(parts) == previous, "reopening removes its pairs and restores the exact original baseline")
	evidence.inside_arc_positive = {"motion":motion, "closing_active":active, "closed":closed_state, "closed_actor_position":closed_position, "reopening_active":reopen_active, "final":helper_state(), "parts":parts.size(), "before_exceptions":previous, "after_exceptions":exception_snapshot(parts)}
	await capture_closed("inside_arc_open_again")
	return failures.is_empty()

func final_threshold_refusal() -> void:
	if not await open_from_outside("threshold refusal"): return
	pose(Vector3(1, 0.31, 3.0), PI); await step(12); await aim(Vector3(1, 1.57, 3))
	var parts: Array[PhysicsBody3D] = own_parts()
	check(overlaps(parts, player, true), "threshold negative actually overlaps independent final leaf/pane geometry")
	check(game._current_door_action().get("owner") == "palazzo", "threshold negative reaches actual E handler")
	var previous: Dictionary = exception_snapshot(parts); var angle: float = host.site._door_angle
	watch_start(); await press_e(); await step(40)
	var motion: Dictionary = watch_end("threshold refusal")
	check(host.site._door_open and is_equal_approx(host.site._door_angle, angle), "final-pose occupant is never exempted; door stays open")
	check(exception_snapshot(parts) == previous and helper_state().owned_exception_pairs == 0, "refused final-pose close creates no orphan exception")
	evidence.threshold_refusal = {"motion":motion, "state":helper_state()}

func other_actor_refusals() -> void:
	if not await open_from_outside("foreign NPC refusal"): return
	for fixture: Dictionary in [{"at":Vector3(1, 0.31, 2.2),"static":false}, {"at":Vector3(1, 0.31, 3.0),"static":false}, {"at":Vector3(1, 0.31, 2.2),"static":true}, {"at":Vector3(1, 0.31, 3.0),"static":true}]:
		var local: Vector3 = fixture.at
		var label: String = "StaticBody ACTOR_LAYER2" if bool(fixture.get("static", false)) else "CharacterBody NPC layer1"
		var npc: PhysicsBody3D = foreign_actor(local, bool(fixture.get("static", false))); await step(3)
		# Upper right of the real opening is above this standing fixture NPC.
		# This avoids an unrelated line-of-sight refusal masking the sweep test.
		await aim(Vector3(1.65, 2.65, 3))
		var parts: Array[PhysicsBody3D] = own_parts(); var previous: Dictionary = exception_snapshot(parts)
		check(game._current_door_action().get("owner") == "palazzo", label + " at " + str(local) + " leaves actual E target visible")
		var angle: float = host.site._door_angle; var npc_position: Vector3 = npc.global_position
		watch_start(); await press_e(); await step(40)
		var motion: Dictionary = watch_end("foreign NPC refusal " + str(local))
		check(host.site._door_open and is_equal_approx(host.site._door_angle, angle), label + " blocks full sweep/final pose at " + str(local))
		check(npc.global_position == npc_position and npc.get_collision_exceptions().is_empty(), "foreign NPC is neither moved nor granted an exception")
		check(exception_snapshot(parts) == previous and helper_state().owned_exception_pairs == 0, "foreign NPC refusal restores all original exception pairs")
		evidence["foreign_" + label + "_" + str(local.z)] = {"motion":motion, "npc_layer":npc.collision_layer, "state":helper_state()}
		npc.queue_free(); await step(3)

func begin_inside_close(label: String) -> bool:
	if not await open_from_outside(label): return false
	pose(Vector3(1, 0.31, 2.2), PI); await step(12); await aim(Vector3(1, 1.57, 3))
	if not check(game._current_door_action().get("owner") == "palazzo", label + ": inside opening selected"): return false
	watch_start(); await press_e()
	return check(helper_state().phase == "moving" and helper_state().owned_exception_pairs > 0, label + ": actual close has scoped pairs")

func mid_tween_intrusion() -> void:
	if not await begin_inside_close("dynamic intrusion"): watching = false; return
	var parts: Array[PhysicsBody3D] = own_parts()
	var overlapping := false
	for index: int in 26:
		if helper_state().phase != "moving": break
		if overlaps(parts, player): overlapping = true; break
		await step()
	if not check(overlapping, "mid-tween fixture observes actual current overlap protected by initiator pairs"):
		watching = false; return
	var intrusion_angle: float = host.site._door_angle
	var npc: PhysicsBody3D = foreign_actor(Vector3(1, 0.31, 3.0))
	await step(4)
	var return_path_clear := not overlaps(parts, player, false, PI * 0.5)
	for index: int in range(0, 19):
		if overlaps(parts, npc, false, lerpf(intrusion_angle, PI * 0.5, float(index) / 18.0)): return_path_clear = false
	check(return_path_clear, "dynamic fixture proves its original endpoint and return path are physically clear; exact rollback expectation is valid")
	check(not overlaps(parts, npc), "rollback/current stopped geometry never overlaps the new final-pose NPC")
	await step(20)
	var motion: Dictionary = watch_end("dynamic intrusion")
	check(host.site._door_open and absf(host.site._door_angle - PI * 0.5) < 0.001, "occupied endpoint aborts and returns to the exact safe original open angle")
	check(host.site._door.transform.is_equal_approx(host.site._door_pose(PI * 0.5)), "rollback publishes exact original leaf transform, not an intermediate pose")
	check(not overlaps(parts, player) and not overlaps(parts, npc), "safe rollback clears actual initiator/NPC geometry including pane")
	check(helper_state().phase == "idle" and helper_state().owned_exception_pairs == 0, "safe rollback clears all owned exception pairs")
	for part: PhysicsBody3D in parts:
		check(not exception_ids(player).has(part.get_instance_id()) and not exception_ids(part).has(player.get_instance_id()), "rollback clears both directions of each owned pair")
	check(npc.get_collision_exceptions().is_empty(), "dynamic NPC never receives any exception")
	evidence.dynamic_intrusion = {"intrusion_angle":intrusion_angle, "return_path_clear":return_path_clear, "motion":motion, "final_angle":host.site._door_angle, "state":helper_state()}
	npc.queue_free(); await step(3)

func reset_cleanup() -> void:
	if not await begin_inside_close("reset cleanup"): watching = false; return
	var helper: RefCounted = host.site._door_close43
	var parts: Array[PhysicsBody3D] = own_parts()
	var old_ids: Array[int] = []
	for part: PhysicsBody3D in parts: old_ids.append(part.get_instance_id())
	var generation: int = host.site.rebuild_generation
	key(KEY_J, true); await step(); key(KEY_J, false); await step(120)
	# Reset rebuilds the floor; record native settling without confusing it with
	# forbidden actor motion by the door or a fixture teleport during E testing.
	var motion: Dictionary = watch_end("reset cleanup", false)
	check(host.site.rebuild_generation == generation + 1 and not host.site._door_open, "actual J resets to a new closed generation")
	check(helper.snapshot().phase == "idle" and helper.snapshot().owned_exception_pairs == 0, "old helper synchronously retires its exception ownership during J")
	for id: int in old_ids: check(not exception_ids(player).has(id), "reset leaves no old door/pane exception on the surviving actor")
	check(not overlaps(own_parts(), player), "new closed leaf/pane do not overlap unchanged reset actor")
	evidence.reset_cleanup = {"motion":motion, "old_part_ids":old_ids, "state":helper.snapshot(), "new_generation":host.site.rebuild_generation}

func exit_cleanup() -> void:
	if not await begin_inside_close("tree exit cleanup"): watching = false; return
	var site: Node3D = host.site
	var helper: RefCounted = site._door_close43
	var parts: Array[PhysicsBody3D] = own_parts()
	# Teardown of this isolated fixture only. Remove the site while keeping the
	# actual player alive; assert its tree_exiting cleanup before another frame.
	site.get_parent().remove_child(site)
	var motion: Dictionary = watch_end("tree exit cleanup")
	check(helper.snapshot().phase == "idle" and helper.snapshot().owned_exception_pairs == 0, "site tree_exiting synchronously disposes active close ownership")
	for part: PhysicsBody3D in parts:
		if not is_instance_valid(part): continue
		check(part.collision_layer == 0 and part.collision_mask == 0, "retired exit body becomes non-colliding before exception cleanup")
		check(not exception_ids(player).has(part.get_instance_id()) and not exception_ids(part).has(player.get_instance_id()), "tree exit leaves no orphan symmetric collision pair")
	evidence.exit_cleanup = {"motion":motion, "state":helper.snapshot(), "player_alive_during_check":is_instance_valid(player), "no_frame_after_site_removal":true}
	site.queue_free()

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--qa43-out="): output = arg.trim_prefix("--qa43-out=").path_join("door43_result.json")
	if DisplayServer.get_name() == "headless": screenshots = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	create_timer(150).timeout.connect(func():
		if not finished: check(false, "150 second focused v4 watchdog"); finish())
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if not check(packed != null, "real main scene"): finish(); return
	game = packed.instantiate(); root.add_child(game); current_scene = game
	for index: int in 1200:
		await process_frame
		if game.preview_ready: break
	if not check(game.preview_ready, "real main ready"): finish(); return
	player = game._player; host = game.preview_palazzo; camera = player.get_preview_camera()
	if not check(is_instance_valid(host) and is_instance_valid(host.site), "existing owned Palazzo host"): finish(); return
	if not check(camera == root.get_camera_3d(), "actual current player camera"): finish(); return
	await step(6)
	if not player._free_mouse_look:
		var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
		root.push_input(click, true); await step()
		click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = false
		root.push_input(click, true); await step(3)
	if not check(player._free_mouse_look, "native click captures input"): finish(); return
	if not await positive_inside(): finish(); return
	await final_threshold_refusal()
	await other_actor_refusals()
	await mid_tween_intrusion()
	await reset_cleanup()
	await exit_cleanup()
	finish()

func finish() -> void:
	if finished: return
	finished = true; watching = false; key(KEY_E, false); key(KEY_J, false)
	var report := {"status":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures, "evidence":evidence, "native_scene":"res://scenes/main.tscn", "input_route":"Viewport.push_input(local=true)", "fixture_teleports":true, "fixture_pose_writes":pose_writes, "physical_OS_input_verified":false, "performance_accepted":false, "runtime_source_modified_by_test":false, "native_executed_by_author":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	else: print("DOOR43_V4 report write failure ", output)
	print("DOOR43_V4 ", report.status, " checks=", checks, " failures=", failures.size(), " report=", output)
	quit(0 if failures.is_empty() else 2)
