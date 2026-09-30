extends SceneTree
## Loaded native scene acceptance. GPU evidence is optional; never launches a second process.
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {"limitations": []}
var game: Node3D
var p: CharacterBody3D
var t: Node3D
var controls: Node
var rear: Node
var camera: Camera3D
var gpu := false
var evidence_dir := ""
var finished := false
var _last_observed_usec := 0
var _first_activation_seen: Dictionary = {}
var _activation_windows: Dictionary = {}
var _capture_busy := false
var _capture_excluded_frames := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func step(count: int = 1) -> void:
	for tick in count:
		await physics_frame
		await process_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_keys() -> void:
	for code: Key in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_E, KEY_F, KEY_B, KEY_H, KEY_SPACE]:
		key(code, false)
	for action: StringName in [&"preview_move_forward", &"preview_move_back", &"preview_move_left", &"preview_move_right", &"preview_jump"]:
		if InputMap.has_action(action): Input.action_release(action)

func acquire_input() -> void:
	if gpu: root.grab_focus()
	await step(3)
	p.set_mouse_captured(true)
	await step(2)

func signed_speed() -> float:
	return t.body.linear_velocity.dot(-t.body.global_basis.z.normalized())

func state() -> Dictionary:
	return {"phase": t.phase, "seat": t.active_seat, "speed_mps": signed_speed(),
		"accepted_throttle": t.body._throttle, "accepted_brake": t.body._brake,
		"accepted_handbrake": t.body._handbrake, "braking": rear.braking,
		"reversing": rear.reversing, "tail_on": rear.tail_on,
		"reverse_beam_visible": rear.reverse_beam.visible, "capture": p._free_mouse_look}

func mark(label: String) -> void:
	report[label] = state()
	print("REAR_LIGHT_STATE ", label, " ", JSON.stringify(report[label]))

func lens_energy() -> float:
	var total := 0.0
	for entry: Variant in rear.lenses:
		if not entry is MeshInstance3D: continue
		var material := entry.get_active_material(0) as BaseMaterial3D
		if material != null and material.emission_enabled:
			total += material.emission_energy_multiplier
	return total

func bind_scene() -> bool:
	for tick in 1200:
		game = current_scene
		if is_instance_valid(game) and game.get("preview_ready") == true:
			var hook := game.get_node_or_null("QuickControlsHook")
			if hook != null and hook.get("status") == "ready":
				controls = hook.controls
				p = game._player
				t = game.preview_transport
				rear = controls.get("rear_lights")
				return is_instance_valid(rear) and rear.get("ready_for_play") == true
		await process_frame
	return false

func board() -> bool:
	release_keys()
	p.global_position = t.approach("front_left") + Vector3.UP * 0.03
	p.velocity = Vector3.ZERO
	await step(30)
	await acquire_input()
	key(KEY_E, true)
	for tick in 360:
		await step()
		if t.phase == "SEATED": break
	key(KEY_E, false)
	await step(2)
	return t.phase == "SEATED" and t.active_seat == "front_left"

func position_camera() -> void:
	if not gpu: return
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.name = "RearLightsEvidenceCamera"
		camera.fov = 55.0
		game.add_child(camera)
	camera.global_position = t.body.to_global(Vector3(3.3, 2.4, 8.0))
	camera.look_at(t.body.to_global(Vector3(0.0, 0.7, 2.8)), Vector3.UP)
	camera.make_current()

func capture(label: String, reposition: bool = true) -> Dictionary:
	if not gpu: return {}
	# Let the activation's first rendered frames reach the observer before any
	# readback. PNG encoding and its following frame are not shader timings.
	await process_frame
	await process_frame
	_capture_busy = true
	if reposition: position_camera()
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(evidence_dir.path_join(label + ".png"))
	var luma := 0.0
	var samples := 0
	for z: float in [3.5, 4.5, 5.5, 6.5]:
		for x: float in [-0.55, 0.0, 0.55]:
			var point: Vector3 = t.body.to_global(Vector3(x, 0.0, z))
			point.y = 0.04
			if camera.is_position_behind(point): continue
			var pixel := Vector2i(camera.unproject_position(point))
			if pixel.x < 300 or pixel.x >= 960 or pixel.y < 210 or pixel.y >= 610: continue
			var color := frame.get_pixelv(pixel)
			luma += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			samples += 1
	await process_frame
	_last_observed_usec = Time.get_ticks_usec()
	_capture_busy = false
	return {"road_samples": samples, "road_luma": luma / maxi(samples, 1)}

func frames(count: int = 180) -> Dictionary:
	var values: Array[float] = []
	var last := Time.get_ticks_usec()
	for frame in count:
		await process_frame
		var now := Time.get_ticks_usec()
		values.append(float(now - last) / 1000.0)
		last = now
	values.sort()
	return {"frames": count, "p50_ms": values[count / 2], "p95_ms": values[int(count * 0.95)],
		"max_ms": values[-1], "drawcalls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"triangles": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}

func observe_activation_frames() -> void:
	var now := Time.get_ticks_usec()
	var elapsed_ms := float(now - _last_observed_usec) / 1000.0 if _last_observed_usec != 0 else 0.0
	_last_observed_usec = now
	if _capture_busy:
		_capture_excluded_frames += 1
		return
	if not is_instance_valid(rear) or elapsed_ms <= 0.0: return
	var active := {"tail_emission": rear.tail_on, "brake_emission": rear.braking, "reverse_emission_and_beam": rear.reversing}
	for label: String in active:
		if active[label] and not _first_activation_seen.has(label):
			_first_activation_seen[label] = true
			_activation_windows[label] = []
		if not _activation_windows.has(label): continue
		var samples: Array = _activation_windows[label]
		if samples.size() >= 30: continue
		samples.append(elapsed_ms)
		if samples.size() == 30:
			var ordered: Array = samples.duplicate()
			ordered.sort()
			if not report.has("first_activation_frames"): report.first_activation_frames = {}
			report.first_activation_frames[label] = {"frames": 30, "activation_frame_ms": samples[0],
				"next_frames_ms": samples.slice(1, 8), "p95_ms": ordered[28], "max_ms": ordered[-1]}

func native_fixture(throttle: float, brake: float, handbrake: bool) -> bool:
	# Only used when the headless backend cannot synthesize a physical Space key.
	# This is native accepted-control coverage, not proof of real keyboard delivery.
	var sequence: int = maxi(t._sequence, t.body._control_sequence) + 1
	var clock_value: int = maxi(t._clock, t.body._control_source_clock) + 1
	var ok: bool = t.body.submit_authoritative_control(throttle, 0.0, brake, handbrake,
		sequence, str(t.body.get_meta("vehicle_id")), int(t.body.get_meta("life_generation")), clock_value)
	t._sequence = sequence
	t._clock = clock_value
	return ok

func paired_gpu() -> void:
	if not gpu: return
	release_keys()
	await acquire_input()
	if controls.headlights.enabled:
		key(KEY_F, true)
		key(KEY_F, false)
	# The car alone is held at a fixed pose for this lighting comparison. All
	# residents, geometry, collision resources and the rest of the scene remain.
	# Native moving-car input/lighting behavior is exercised separately above.
	var was_frozen: bool = t.body.freeze
	t.body.freeze = true
	t.body.linear_velocity = Vector3.ZERO
	t.body.angular_velocity = Vector3.ZERO
	position_camera()
	report.gpu_comparison = {"fixture": "same camera/car pose, frozen vehicle only; complete scene remains active", "hour": controls.day_clock.hour}
	# Remove only this new module's lenses/beam, preserving every original node.
	# This records the complete new feature's cost as well as beam-on increment.
	rear._clear()
	await step(45)
	report.gpu_comparison.without_rear_lamps = await frames()
	check(rear.configure(game, t), "rear feature restores after complete-cost baseline")
	await step(45)
	report.gpu_comparison.off_before = await frames()
	report.gpu_comparison.off_image = await capture("paired_reverse_off", false)
	await acquire_input()
	key(KEY_S, true)
	await step(45)
	mark("paired_reverse_selected")
	report.paired_reverse_selected.merge({"world_dead": game.preview_dead, "world_fault": game.preview_physics_fault, "ready": rear.ready_for_play, "focus": root.has_focus()})
	check(rear.reversing and rear.reverse_beam.visible, "stationary accepted reverse selection lights road")
	report.gpu_comparison.reverse_on = await frames()
	report.gpu_comparison.on_image = await capture("paired_reverse_on", false)
	key(KEY_S, false)
	await step(45)
	report.gpu_comparison.off_after = await frames()
	var off: Dictionary = report.gpu_comparison.off_image
	var on: Dictionary = report.gpu_comparison.on_image
	check(off.road_samples > 0 and off.road_samples == on.road_samples, "same nonempty rear-road pixels sampled")
	check(on.road_luma > off.road_luma + 0.002, "reverse beam visibly brightens rear road")
	var baseline_p95: float = (report.gpu_comparison.off_before.p95_ms + report.gpu_comparison.off_after.p95_ms) * 0.5
	report.gpu_comparison.p95_delta_ms = report.gpu_comparison.reverse_on.p95_ms - baseline_p95
	report.gpu_comparison.feature_on_p95_delta_ms = report.gpu_comparison.reverse_on.p95_ms - report.gpu_comparison.without_rear_lamps.p95_ms
	t.body.freeze = was_frozen
	await step(3)

func finish() -> void:
	if finished: return
	finished = true
	release_keys()
	if gpu:
		report.activation_capture_exclusions = {"frames": _capture_excluded_frames,
			"rule": "readback/PNG and following frame excluded; first two clean rendered frames precede each capture"}
	var result := {"checks": checks, "failures": failures, "gpu": gpu, "report": report}
	FileAccess.open(evidence_dir.path_join("RESULT.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("REAR_LIGHTS_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func exit_before_fixture() -> bool:
	report.native_exit_attempts = []
	for attempt in 2:
		release_keys()
		await acquire_input()
		key(KEY_E, true)
		for tick in 420:
			await step()
			if t.phase == "ON_FOOT": break
		key(KEY_E, false)
		await step(3)
		var details := state()
		details.merge({"attempt": attempt + 1, "error": t.error,
			"blocked_transition": t._blocked_transition, "token": t.token,
			"body_frozen": t.body.freeze, "player_pose": str(p._pose_authority),
			"physical_e": Input.is_physical_key_pressed(KEY_E)})
		report.native_exit_attempts.append(details)
		print("REAR_LIGHT_EXIT ", JSON.stringify(details))
		if t.phase == "ON_FOOT": return true
		if not t._blocked_transition and not str(t.error).contains("BLOCKED"): break
		# Native exit keeps its authority while blocked. Let the actual residents
		# move clear; never force ON_FOOT or remove colliders to make this pass.
		await step(90)
		if t.phase == "ON_FOOT": return true
	return false

func run() -> void:
	gpu = DisplayServer.get_name() != "headless"
	if gpu: quit(2); return # Root owns separate GPU acceptance
	var run_id := "gpu01" if gpu else "headless01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-id="): run_id = arg.trim_prefix("--run-id=")
	evidence_dir = get_script().resource_path.get_base_dir().path_join(run_id)
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	create_timer(60.0).timeout.connect(func(): check(false, "bounded 60-second watchdog"); finish())
	root.size = Vector2i(1280, 720)
	if gpu: process_frame.connect(observe_activation_frames)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var bound := await bind_scene()
	check(bound, "native combined24f scene and rear lamps ready")
	if not bound:
		finish()
		return
	check(game.PREVIEW_RUNTIME_REVISION == "s01-20260930-quality24f", "combined24f revision retained")
	check(get_nodes_in_group("mafiozi_quick_controls").size() == 1, "single controls owner before driving")
	check(game._block.buildings.size() == 8 and game.preview_population.hit_owners.size() == 3 and game.preview_modular30.status == "ready", "full combined8buildings3NPC and modular owner retained")
	check(p.collision_layer == 2 and p.collision_mask == 1025, "accepted corpse28 movement mask retained")
	check(game.find_child("PreviewUpdates", true, false).get_status().notes.items.size() == 5, "all five current24f notes displayed")
	check(rear.lenses.size() == 2 and rear.reverse_lenses.size() == 2, "two native-anchor red lenses and reverse lenses")
	check(is_instance_valid(rear.reverse_beam) and not rear.reverse_beam.shadow_enabled, "single reverse beam without shadow pass")
	check(not rear.braking and not rear.reversing and not rear.reverse_beam.visible, "on foot brake and reverse initially off")
	controls.day_clock.running = false
	controls.day_clock.set_hour(22.0)
	controls.day_night.apply_hour(22.0)
	controls._refresh_hint()
	await acquire_input()
	var boarded := await board()
	check(boarded, "native E boards actual driver seat")
	if not boarded:
		mark("boarding_failed")
		finish()
		return
	position_camera()
	await step(5)
	mark("idle_off")
	await capture("night_rear_off")
	key(KEY_F, true)
	key(KEY_F, false)
	await step(3)
	check(controls.headlights.enabled and rear.tail_on, "F enables front headlights and red tail lamps")
	var tail_energy := lens_energy()
	report.tail_emission_energy = tail_energy
	await capture("night_tail_on")
	key(KEY_W, true)
	for tick in 180:
		await step()
		if signed_speed() > 1.1: break
	check(t.body._throttle > 0.5 and signed_speed() > 0.35, "mapped W drives native body forward")
	check(not rear.braking and not rear.reversing, "forward throttle does not light stops or reverse")
	mark("forward")
	key(KEY_W, false)
	key(KEY_S, true)
	await step()
	check(t.body._throttle < -0.5 and signed_speed() > 0.02 and rear.braking and not rear.reversing, "S first brakes while still moving forward")
	check(rear.tail_on, "brake preserves F tail state")
	var brake_energy := lens_energy()
	report.brake_emission_energy = brake_energy
	check(brake_energy > tail_energy, "red brake lenses brighter than tail lamps")
	mark("forward_braking")
	await capture("night_braking")
	for tick in 240:
		await step()
		if signed_speed() < -0.35: break
	check(signed_speed() < -0.15 and rear.reversing and not rear.braking, "held S transitions through stop into actual reverse")
	check(rear.reverse_beam.visible, "reverse road beam on while reversing")
	mark("reverse")
	await capture("night_reversing")
	key(KEY_S, false)
	await step(3)
	check(not rear.reversing and not rear.reverse_beam.visible and not rear.braking, "release S clears lamps while coasting")
	mark("reverse_coast")
	key(KEY_W, true)
	await step()
	check(signed_speed() < -0.02 and t.body._throttle > 0.5 and rear.braking and not rear.reversing, "W brakes a reversing car without reverse lamps")
	mark("reverse_braking")
	key(KEY_W, false)
	key(KEY_SPACE, true)
	await step(3)
	report.space_input = "real Input.parse_input_event Space; no transport-control fixture"
	check(t.body._handbrake and rear.braking, "actual Space accepted by transport and lights red stops")
	for tick in 180:
		await step()
		if absf(signed_speed()) < 0.04: break
	key(KEY_SPACE, false)
	await step(3)
	check(not rear.braking and rear.tail_on, "release brake restores red tail intensity")
	check(is_equal_approx(lens_energy(), tail_energy), "tail emission restored after braking")
	key(KEY_S, true)
	await step(5)
	check(rear.reversing, "reverse armed before focus-loss check")
	p.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await step(3)
	check(not rear.reversing and not rear.reverse_beam.visible, "focus loss clears stuck reverse without key-up")
	mark("focus_lost")
	key(KEY_S, false)
	await acquire_input()
	var exited := await exit_before_fixture()
	check(exited, "native E exits after rear-light checks before any fixed-car fixture")
	check(t.phase == "ON_FOOT" and not rear.braking and not rear.reversing and not rear.reverse_beam.visible, "on foot disables brake and reverse despite parked body control")
	if gpu and exited:
		var reboarded := await board()
		check(reboarded, "native E reboards before separate GPU fixture")
		if reboarded: await paired_gpu()
	var old_rear: WeakRef = weakref(rear)
	var old_beam: WeakRef = weakref(rear.reverse_beam)
	check(reload_current_scene() == OK, "native scene reload accepted")
	await process_frame
	bound = await bind_scene()
	check(bound, "rear module restored after native reload")
	if bound:
		check(old_rear.get_ref() == null and old_beam.get_ref() == null, "old rear module and beam freed on reload")
		check(get_nodes_in_group("mafiozi_quick_controls").size() == 1, "native reload retains exactly one controls owner")
		check(rear.lenses.size() == 2 and rear.reverse_lenses.size() == 2, "reload does not duplicate lens geometry")
		check(not rear.braking and not rear.reversing and not rear.reverse_beam.visible, "fresh on-foot reload has no stuck lamps")
	finish()
