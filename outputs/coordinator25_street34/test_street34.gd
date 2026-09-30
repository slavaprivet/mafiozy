extends SceneTree
## Exact-pack additive acceptance. Accepted native TT shots are the only positive
## break input; synthetic signal receipts appear solely in rejection tests.
var game: Node3D
var player: CharacterBody3D
var controls: Node
var lamps: Node
var weapons: Node
var camera: Camera3D
var observer: Camera3D
var selected: Dictionary = {}
var target := Vector3.ZERO
var tracking := false
var gpu := false
var finished := false
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {"limitations": ["Logical native-input fixture, not manual OS-input acceptance. Loaded preview quarter only, not full-city performance."]}
var terminals: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var out := ""
var phase := ""
var last_draw := 0
var frame_samples: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)
	return value

func step(count: int = 1) -> void:
	for i in count:
		if finished: return
		await physics_frame
		await process_frame

func button(code: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	player._unhandled_input(event)

func aim() -> void:
	var direction := (target - camera.global_position).normalized()
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := asin(clampf(direction.y, -.98, .98))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(yaw - player._camera_yaw, -PI, PI) / player.mouse_sensitivity, -(pitch - player._camera_pitch) / player.mouse_sensitivity)
	player._unhandled_input(event)

func _process(_delta: float) -> bool:
	if tracking and not finished and is_instance_valid(player):
		player._free_mouse_look = true
		aim()
	return false

func bind_scene() -> bool:
	for i in 1200:
		game = current_scene
		if is_instance_valid(game) and game.get("preview_ready") == true:
			var hook := game.get_node_or_null("QuickControlsHook")
			if hook != null and hook.get("status") == "ready":
				controls = hook.controls
				lamps = controls.get("street_lamps")
				player = game._player
				weapons = game.preview_weapons
				camera = player.get_preview_camera()
				return is_instance_valid(lamps) and lamps.get("ready_for_play") == true
		await process_frame
	return false

func entry_for(id: String) -> Dictionary:
	for entry: Dictionary in lamps.entries:
		if str(entry.id) == id: return entry
	return {}

func broken_count() -> int:
	var count := 0
	for entry: Dictionary in lamps.entries:
		if entry.broken: count += 1
	return count

func hour(value: float) -> void:
	controls.day_clock.running = false
	controls.day_clock.set_hour(value)
	controls.day_night.apply_hour(value)
	lamps.apply_daylight(controls.day_night.daylight)

func root34_guards() -> void:
	check(game.get_node("QuickControlsHook").get_script().resource_path == "res://scripts/quick_controls/scene_hook.gd", "ordinary_integrated_hook")
	check(controls.get_script().resource_path == "res://scripts/quick_controls/quick_controls.gd", "ordinary_integrated_controls_no_external_overlay")
	check(lamps.get_script().resource_path == "res://scripts/quick_controls/street_lamps.gd", "ordinary_integrated_street_owner")
	check(lamps.sound.get_script().resource_path == "res://scripts/quick_controls/street_glass_sound.gd", "ordinary_integrated_glass_sound")
	check(controls.dashboard.get_script().resource_path == "res://scripts/quick_controls/car_dashboard.gd", "ordinary_integrated_dashboard")
	var lantern: Script = lamps.get_script().get_script_constant_map().get("Lantern")
	check(lantern != null and lantern.resource_path == "res://scripts/quick_controls/street_lamp_visual.gd", "ordinary_integrated_lantern_helper")
	var notes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	check(notes is Dictionary and notes.get("runtime_revision") == "s01-20260930-quality25a" and notes.get("items", []).size() == 5, "five_visible_notes_match_running_revision")
	check(notes is Dictionary and notes.get("items", []).size() > 0 and "фонар" in str(notes.items[0]).to_lower(), "first_visible_note_describes_street_lamps")
	check(controls.headlights.get_script().resource_path == "res://scripts/quick_controls/car_headlights.gd", "ordinary_integrated_headlights")
	check(controls.rear_lights.get_script().resource_path == "res://scripts/quick_controls/car_rear_lights.gd", "ordinary_integrated_rear_lights")
	check(controls.horn.get_script().resource_path == "res://scripts/quick_controls/car_horn.gd", "ordinary_integrated_horn")
	check(controls.day_night.get_script().resource_path == "res://scripts/quick_controls/day_night.gd", "ordinary_integrated_day_night")
	check(controls.day_clock.get_script().resource_path == "res://scripts/quick_controls/day_night_clock.gd", "ordinary_integrated_day_clock")
	check(FileAccess.get_sha256("res://audio/street_glass_break_01.bytes") == "6ce9ebf4036f856e42181a224d9a7a01e2783ca8a23b8f4fc51a510accaaaf56", "packed_audio_exact:audio/street_glass_break_01.bytes")
	check(FileAccess.get_sha256("res://audio/street_glass_break_02.bytes") == "9e92dafb70f165ac5b12581b65f95203b17ee66a43b9c5494b0af7585da71168", "packed_audio_exact:audio/street_glass_break_02.bytes")
	check(FileAccess.get_sha256("res://audio/street_glass_break_03.bytes") == "f05f418fb070369723b597a8a7d54a801b69aac007dcb650ee131e711b5ac22e", "packed_audio_exact:audio/street_glass_break_03.bytes")

func count_preserved() -> void:
	var expected := {}
	for record: Dictionary in game._block.decor: expected[str(record.id)] = record
	check(lamps.entries.size() == 8 and expected.size() == 8, "all_eight_existing_lamps_retained")
	var seen := {}
	for entry: Dictionary in lamps.entries:
		var id: String = str(entry.id)
		check(expected.has(id) and not seen.has(id), "unique_original_lamp_id:" + id)
		seen[id] = true
		check(entry.owner.get_meta("source_id", "") == id, "source_owner_identity:" + id)
		if not expected.has(id): continue
		var position_data: Array = expected[id].positionLocalM
		var at := Vector3(position_data[0], position_data[1], position_data[2])
		check(entry.owner.position.distance_to(at) < .0001, "original_world_placement:" + id)
		check(is_instance_valid(entry.glass_body) and entry.glass_body.get_child_count() == 4, "four_physical_glass_panes:" + id)
		check(is_instance_valid(entry.light) and not entry.light.shadow_enabled, "bounded_shadowless_light:" + id)
	check(game._block.buildings.size() == 8 and game.preview_population.hit_owners.size() == 3, "original_buildings_and_three_residents_retained")
	check(get_nodes_in_group("mafiozi_quick_controls").size() == 1, "single_controls_owner")
	check(is_instance_valid(controls.get("rear_lights")) and controls.rear_lights.ready_for_play, "rear_lights_preserved_in_combined_build")
	check(is_instance_valid(controls.headlights) and controls.day_night.enabled, "headlights_daynight_preserved")

func choose_fixture() -> bool:
	var capsule: CollisionShape3D = player.get_node("PlayerCapsule")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var attempts := []
	# Prefer the nearby south-facing pane; placement candidates use only queries.
	var ordered: Array = lamps.entries.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return player.global_position.distance_squared_to(a.owner.global_position) < player.global_position.distance_squared_to(b.owner.global_position))
	for entry: Dictionary in ordered:
		var head: Node3D = entry.visual.root
		for distance: float in [8.0, 10.0, 6.0]:
			for side: float in [0.0, 1.1, -1.1]:
				var base: Vector3 = head.global_position + Vector3(side, -head.global_position.y, distance)
				var floor_query := PhysicsRayQueryParameters3D.create(base + Vector3.UP * 2, base - Vector3.UP * 3, 1, [player.get_rid()])
				var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(floor_query)
				if floor_hit.is_empty() or floor_hit.normal.y < .9: continue
				var at: Vector3 = floor_hit.position + Vector3.UP * .03
				query.transform = Transform3D(player.global_basis, at) * capsule.transform
				if not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
				var wanted: Vector3 = head.to_global(Vector3(.07, -.015, .276))
				var eye: Vector3 = at + Vector3.UP * 1.6
				var ray_query := PhysicsRayQueryParameters3D.create(eye, wanted, 5 | 256, [player.get_rid()])
				var ray_hit := player.get_world_3d().direct_space_state.intersect_ray(ray_query)
				if not ray_hit.is_empty() and ray_hit.collider != entry.glass_body: continue
				selected = entry
				target = wanted
				player.global_position = at
				player.velocity = Vector3.ZERO
				report.fixture = {"lamp_id":entry.id, "player_position":str(at), "target":str(target), "scope":"One explicit clear-floor setup placement, residents and collision scene unchanged."}
				return true
	report.fixture_failed_attempts = attempts
	return false

func native_sight(wanted: Object) -> Dictionary:
	var ray: Dictionary = weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":100.0})
	var muzzle: Dictionary = weapons.presentation.current_muzzle()
	if not ray.has("point") or not muzzle.get("ok", false): return {"ok":false,"reason":"camera_or_muzzle"}
	var direction: Vector3 = (ray.point - muzzle.origin).normalized()
	var actual: Dictionary = weapons._projectile_ray({"origin":muzzle.origin,"direction":direction,"range":muzzle.origin.distance_to(ray.point) + .03})
	return {"ok":ray.get("collider") == wanted and actual.get("collider") == wanted,"camera_collider":str(ray.get("collider")),"muzzle_collider":str(actual.get("collider")),"point":str(actual.get("point"))}

func fire_once(label: String, wanted: Object, settle_frames: int = 32) -> bool:
	for i in 100:
		await step()
		if weapons.fire_state.cooldown <= 0 and native_sight(wanted).get("ok", false): break
	if not check(native_sight(wanted).get("ok", false), label + ":actual_camera_and_muzzle_reach_exact_surface:" + str(native_sight(wanted))): return false
	var ammo: int = weapons.fire_state.magazine
	var shot_count: int = weapons.shots_count
	var terminal_start := terminals.size()
	begin_phase(label)
	await step(2)
	button(MOUSE_BUTTON_LEFT, true)
	await step(2)
	button(MOUSE_BUTTON_LEFT, false)
	await step(settle_frames)
	end_phase()
	check(weapons.shots_count == shot_count + 1, label + ":one_accepted_native_shot")
	check(weapons.fire_state.magazine == ammo - 1, label + ":exactly_one_finite_round_spent")
	var matched := false
	for receipt: Dictionary in terminals.slice(terminal_start):
		if receipt.get("status") == "hit" and receipt.get("collider") == wanted: matched = true
	return check(matched, label + ":native_terminal_exact_surface")

func begin_phase(label: String) -> void:
	phase = label
	last_draw = 0
	frame_samples[label] = []

func end_phase() -> void:
	phase = ""
	last_draw = 0

func drawn() -> void:
	if phase.is_empty() or finished: return
	var now := Time.get_ticks_usec()
	if last_draw > 0:
		frame_samples[phase].append({"frame_ms":(now-last_draw)/1000.0,"broken":broken_count() if is_instance_valid(lamps) and lamps.ready_for_play else -1,"drawcalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
	last_draw = now

func capture(label: String) -> void:
	if not gpu: return
	end_phase()
	tracking = false
	if not is_instance_valid(observer):
		observer = Camera3D.new()
		observer.fov = 55
		game.add_child(observer)
	var head: Node3D = selected.visual.root
	observer.global_position = head.to_global(Vector3(2.1, -.7, 4.7))
	observer.look_at(head.global_position + Vector3.DOWN * .4, Vector3.UP)
	observer.make_current()
	await step(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(label + ".png")) == OK, "capture:" + label)
	await step(2)
	camera.make_current()
	tracking = true

func rejection_tests() -> void:
	var before: int = lamps.sound.stats().played
	var fake := {"shotId":"forged-unaccepted-lamp-shot", "weaponId":"tt_pistol", "projectileIndex":0,"projectileCount":1,"producerEpoch":weapons.effects.resolution_epoch(),"status":"hit","point":selected.visual.root.to_global(Vector3(0,0,.276)),"normal":Vector3.BACK,"direction":Vector3.FORWARD,"collider":selected.glass_body}
	weapons.effects.projectile_resolved.emit(fake)
	check(not selected.broken and lamps.sound.stats().played == before, "forged_unaccepted_terminal_does_not_break_or_sound")
	fake.point = Vector3(NAN,0,0)
	weapons.effects.projectile_resolved.emit(fake)
	check(not selected.broken, "nonfinite_forged_terminal_rejected")

func paired_feature_cost() -> void:
	if not gpu: return
	tracking = false
	var saved_id: String = selected.id
	var view_frame: Transform3D = selected.visual.root.global_transform
	observer = Camera3D.new()
	observer.fov = 55
	game.add_child(observer)
	observer.global_position = view_frame * Vector3(2.1,-.7,4.7)
	observer.look_at(view_frame.origin + Vector3.DOWN * .4,Vector3.UP)
	observer.make_current()
	var original: Node = lamps
	var script: Script = original.get_script()
	var host: Node = original.get_parent()
	var labels: Array[String] = ["paired_without_street_lamp_feature_before", "paired_with_street_lamp_feature_night", "paired_without_street_lamp_feature_after", "paired_with_street_lamp_feature_final"]
	for index in labels.size():
		var enabled := index % 2 == 1
		if enabled:
			var replacement: Node = script.new()
			host.add_child(replacement)
			if not check(replacement.configure(game), "whole_feature_restored_after_cost_baseline:" + labels[index]):
				replacement.queue_free()
				camera.make_current()
				tracking = true
				return
			controls.street_lamps = replacement
			lamps = replacement
			original.queue_free()
			original = replacement
			selected = entry_for(saved_id)
			hour(22)
		else:
			original.dispose()
		# Keep the same loaded world running in every phase. Repeated off/on
		# measurements expose temporal drift without removing residents.
		await step(60)
		if not enabled:
			check(original.entries.is_empty() and game.find_children("BelliniGlassLantern","Node3D",true,false).is_empty() and game.find_children("PooledStreetGlass","MultiMeshInstance3D",true,false).is_empty() and game.find_children("StreetGlassVoice*","AudioStreamPlayer3D",true,false).is_empty(), "whole_feature_removed_for_cost_baseline:" + labels[index])
		begin_phase(labels[index])
		await step(180)
		end_phase()
	report.paired_cost = "Same fixed close-up lantern camera, hour22, active residents/eight buildings and existing features retained. Order: without/with/without/with-final; each phase has 60 physics warmup frames followed by 180 measured physics frames. Without restores native Bell/Glow and removes added colliders/light/audio/debris. With reconfigures the whole feature using warmed resource caches. Residents remain active and are not reset, so repeated baselines expose temporal drift but do not guarantee identical simulation state. This close-up is not a full-quarter or full-city camera/performance acceptance, and excludes first-install shader cost."
	report.paired_cost_setup = {"camera_transform":str(observer.global_transform),"fov":observer.fov,"viewport_size":str(root.size),"physics_ticks_per_second":Engine.physics_ticks_per_second,"max_fps":Engine.max_fps,"vsync_mode":DisplayServer.window_get_vsync_mode(),"buildings":game._block.buildings.size(),"residents":game.preview_population.hit_owners.size(),"warmup_physics_frames_per_phase":60,"measured_physics_frames_per_phase":180,"order":labels}
	camera.make_current()
	tracking = true

func run() -> void:
	gpu = DisplayServer.get_name() != "headless"
	var run_id := "gpu01" if gpu else "headless01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-id="): run_id = arg.trim_prefix("--run-id=")
	out = get_script().resource_path.get_base_dir().path_join(run_id)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	create_timer(120.0).timeout.connect(func(): check(false,"bounded_120_second_watchdog"); finish())
	if gpu: RenderingServer.frame_post_draw.connect(drawn)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if not check(await bind_scene(), "combined_scene_street_lamps_ready"): finish(); return
	check(game.PREVIEW_RUNTIME_REVISION == "s01-20260930-quality25a", "integrated_quality25a_accepted31_base")
	root34_guards()
	count_preserved()
	hour(12)
	check(is_zero_approx(lamps.power), "no_lamp_power_at_noon")
	lamps.apply_daylight(.35)
	var transition_power: float = lamps.power
	lamps.apply_daylight(0.0)
	check(transition_power >= 0.0 and transition_power <= lamps.power and lamps.power > .9, "dusk_to_night_power_monotonic")
	hour(22)
	if not check(choose_fixture(), "clear_floor_native_shot_fixture"): finish(); return
	tracking = true
	player._free_mouse_look = true
	if not check(weapons.equip("tt_pistol").get("ok",false), "native_inventory_TT_equipped"): finish(); return
	weapons.shot_emitted.connect(func(shot: Dictionary, _muzzle: Dictionary, _from: Vector3, _dir: Vector3): shots.append(shot.duplicate(true)))
	weapons.effects.projectile_resolved.connect(func(receipt: Dictionary): terminals.append(receipt.duplicate()))
	button(MOUSE_BUTTON_RIGHT,true)
	await step(45)
	await paired_feature_cost()
	rejection_tests()
	hour(12)
	await capture("lamp_day_intact")
	hour(22)
	await capture("lamp_night_intact")
	begin_phase("night_intact_steady")
	await step(90)
	end_phase()
	var head: Node3D = selected.visual.root
	target = selected.owner.to_global(Vector3(0,3.53,0))
	var sound_before: int = lamps.sound.stats().played
	if not await fire_once("actual_TT_metal_pole",selected.pole_body): finish(); return
	check(not selected.broken and lamps.sound.stats().played == sound_before, "pole_hit_does_not_break_glass_or_play_break_sound")
	# Exercise source metal beyond the old radius-.15 cylinder and its
	# missing horizontal arm, through the same accepted-shot path.
	target = selected.owner.to_global(Vector3(.19,2.0,0))
	if not await fire_once("actual_TT_lower_pole_outer_flank",selected.pole_body): finish(); return
	check(not selected.broken and lamps.sound.stats().played == sound_before, "lower_pole_outer_flank_hit_preserves_glass_and_sound")
	target = selected.owner.to_global(Vector3(.55,6.05,0))
	if not await fire_once("actual_TT_horizontal_metal_arm",selected.pole_body): finish(); return
	check(not selected.broken and lamps.sound.stats().played == sound_before, "horizontal_metal_arm_hit_preserves_glass_and_sound")
	# Aim inside the sloped metal hood, above the pane's top (.245m).
	target = head.to_global(Vector3(0,.31,.28))
	if not await fire_once("actual_TT_metal_hood",selected.metal_body): finish(); return
	check(not selected.broken and lamps.sound.stats().played == sound_before, "metal_hit_does_not_break_glass_or_play_break_sound")
	target = head.to_global(Vector3(.07,-.015,.276))
	var glass: Variant = selected.glass_body
	# Observe the complete two-second debris lifetime and the 1.08-second
	# sound, including cleanup, inside the native break measurement.
	if not await fire_once("actual_TT_glass",glass,150): finish(); return
	check(selected.broken and broken_count() == 1, "one_native_glass_hit_breaks_only_target_lamp")
	check(not selected.light.visible or selected.light.light_energy == 0.0, "broken_lamp_light_immediately_off")
	check(not selected.visual.glass.visible and selected.visual.broken_glass.visible, "broken_glass_visually_replaces_intact_panes")
	check(lamps.sound.stats().played == sound_before + 1, "exactly_one_spatial_glass_break_sound")
	check(not lamps.is_processing() and not lamps._debris.visible, "native_break_debris_settled_and_idle_after_full_lifetime")
	check(lamps.sound.stats().active == 0, "native_break_sound_finished_after_full_lifetime")
	var duplicate: Dictionary = terminals[-1].duplicate()
	weapons.effects.projectile_resolved.emit(duplicate)
	check(broken_count() == 1 and lamps.sound.stats().played == sound_before + 1, "duplicate_terminal_no_repeat_damage_or_audio")
	var another: Dictionary = {}
	for entry: Dictionary in lamps.entries:
		if not entry.broken: another = entry; break
	duplicate.collider = another.glass_body
	duplicate.point = another.visual.root.to_global(Vector3(0,0,.276))
	weapons.effects.projectile_resolved.emit(duplicate)
	check(not another.broken and lamps.sound.stats().played == sound_before + 1, "replayed_terminal_cannot_break_different_lamp")
	hour(12)
	hour(22)
	check(selected.broken and not selected.light.visible, "day_night_cycle_does_not_resurrect_broken_lamp")
	await capture("lamp_night_broken")
	report.before_reload = {"lamp_id":selected.id,"sound":lamps.sound.stats(),"snapshot":lamps.snapshot(),"native_shots":shots.size(),"finite_ammo":weapons.fire_state.magazine}
	var broken_id: String = str(selected.id)
	tracking = false
	button(MOUSE_BUTTON_LEFT,false)
	button(MOUSE_BUTTON_RIGHT,false)
	check(reload_current_scene() == OK, "native_scene_reload_requested")
	await process_frame
	await process_frame
	if not check(await bind_scene(), "combined_scene_rebound_after_reload"): finish(); return
	selected = entry_for(broken_id)
	check(not selected.is_empty() and selected.broken and broken_count() == 1, "session_broken_identity_survives_reload")
	check(not selected.light.visible and not selected.visual.glass.visible, "reload_keeps_broken_light_and_panes_off")
	check(lamps.sound.stats().played == 0, "reload_does_not_replay_break_sound")
	check(get_nodes_in_group("mafiozi_quick_controls").size() == 1, "one_controls_owner_after_reload")
	check(is_instance_valid(controls.rear_lights) and controls.rear_lights.ready_for_play, "rear_lights_survive_combined_reload")
	# Reusing the same owner at the same night power must rebuild visible
	# lights while preserving the session's broken source ID.
	hour(22)
	var same_owner: Node = lamps
	lamps.dispose()
	await step(3)
	if not check(lamps.configure(game), "same_street_lamp_owner_reconfigures_after_dispose"):
		finish(); return
	hour(22)
	selected = entry_for(broken_id)
	var rebound: Dictionary = lamps.snapshot()
	check(lamps == same_owner and controls.street_lamps == same_owner, "same_street_lamp_owner_remains_bound_to_controls")
	check(rebound.lamps == 8 and rebound.broken == 1 and rebound.lit == 7, "same_hour_reconfigure_restores_seven_intact_lights")
	check(not selected.is_empty() and selected.broken and not selected.light.visible and not selected.visual.glass.visible, "same_owner_reconfigure_preserves_broken_source_identity")
	check(lamps.sound.stats().played == 0, "same_owner_reconfigure_does_not_replay_break_audio")
	check(get_nodes_in_group("mafiozi_street_lamps").size() == 1, "one_street_lamp_owner_after_same_instance_reconfigure")
	finish()

func finish() -> void:
	if finished: return
	finished = true
	tracking = false
	end_phase()
	var metrics := {}
	for label: String in frame_samples:
		var values: Array[float] = []
		for item: Dictionary in frame_samples[label]: values.append(item.frame_ms)
		values.sort()
		if values.is_empty(): continue
		metrics[label] = {"count":values.size(),"p50_ms":values[int(values.size()*.5)],"p95_ms":values[mini(values.size()-1,int(values.size()*.95))],"max_ms":values[-1],"samples":frame_samples[label]}
	report.frame_metrics = metrics
	report.frame_policy = "First interval of each phase excluded. Actual TT glass phase begins before input and continues for 150 physics frames after release, including the first break frame, full debris/audio lifetime and cleanup. PNG readback/capture and camera changes are outside measured phases. Repeated off/on samples use the same camera/settings with active residents; compare both baselines for drift before attributing a difference to the feature. Frame intervals are observed presentation cadence, not isolated CPU/GPU execution time. Headless is not graphics performance."
	var result := {"checks":checks,"failures":failures,"gpu":gpu,"report":report,"test_sha256":FileAccess.get_sha256(get_script().resource_path)}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STREET_LAMPS_RESULT ",checks," checks, ",failures.size()," failures: ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
