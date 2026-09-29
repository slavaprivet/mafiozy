extends SceneTree
## Root-only single-window harness. Reads actual main; never sets transforms/speeds.
const OWNED := "coordinator22_braking_owned"
const HASH_FILES := ["res://scripts/main.gd", "res://scripts/preview_player.gd", "res://scripts/preview_transport.gd", "res://scripts/vehicle_physics/vehicle_native_body.gd", "res://scripts/transport/transport_actor_transition.gd", "res://scripts/character_physics/ragdoll_actor_transition.gd", "res://scripts/character_physics/character_physics_driver.gd", "res://project.godot"]
var main: Node3D
var transport: Node3D
var player: CharacterBody3D
var out := ""
var mode := "baseline"
var selftest := false
var pack_file := ""
var pack_sha := ""
var observing := false
var cancelled := false
var finishing := false
var finished := false
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var metrics: Dictionary = {}
var begin_hashes: Dictionary = {}
var begin_memory: Dictionary = {}
var section := "warmup"
var last_stamp := 0
var skip_frames := 3
var episode_origin := Vector3.ZERO
var last_car := Vector3.ZERO
var episode_distance := 0.0
var episode := 0
var focus_seen := false
var result_values: Dictionary = {}
var seen_ragdoll := false
var seen_recovery := false
var pose_writer: Callable
var collision_invalidated := false
var ragdoll_pose_ticks := 0
var midfall_captured := false

class Observer extends Node:
	var qa: SceneTree
	func _input(event: InputEvent) -> void:
		if not qa.observing or event.get_meta("coordinator22_braking_owned", false): return
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion or (event is InputEventMouseMotion and event.relative.length() > 1.0):
			qa.cancelled = true
			qa.failures.append("unowned_input")
			get_viewport().set_input_as_handled()

func _initialize() -> void:
	call_deferred("run")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.set_meta(OWNED, true)
	Input.parse_input_event(event)

func release() -> void:
	for code: Key in [KEY_E, KEY_W, KEY_SPACE]: key(code, false)
	for action: String in ["preview_move_forward", "preview_move_back", "preview_move_left", "preview_move_right"]:
		if InputMap.has_action(action): Input.action_release(action)

func hashes() -> Dictionary:
	var found: Dictionary = {}
	found["harness"] = FileAccess.get_sha256(get_script().resource_path)
	for path: String in HASH_FILES:
		# Exported text may be remapped to compiled resources; PCK identity is authoritative there.
		found[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "COMPILED_OR_ABSENT"
	if not pack_file.is_empty(): found["pack"] = FileAccess.get_sha256(pack_file)
	return found

func memory() -> Dictionary:
	var found := {"engine_static_bytes": OS.get_static_memory_usage(), "engine_static_peak_bytes": OS.get_static_memory_peak_usage()}
	if OS.get_name() == "Windows":
		var output: Array = []
		var command := "[Diagnostics.Process]::GetProcessById(%d).WorkingSet64" % OS.get_process_id()
		var code := OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", command], output, false, false)
		if code == 0 and output.size() > 0 and str(output[0]).strip_edges().is_valid_int():
			found["process_working_set_bytes"] = str(output[0]).strip_edges().to_int()
		else: found["process_working_set_unavailable"] = code
	return found

func speed() -> float:
	return transport.body.linear_velocity.slide(Vector3.UP).length()

func driver_attached() -> bool:
	return not transport.runtime.host.driver(transport._vehicle_ref).is_empty()

func tap(state: Dictionary, seat: String, body: RigidBody3D, visual: RefCounted) -> void:
	pose_writer.call(state, seat, body, visual)
	if state.get("source_phase", "") == "exit_ragdoll":
		seen_ragdoll = true
		ragdoll_pose_ticks += 1
	if transport.character_physics != null and str(transport.character_physics.mode) in ["GETTING_UP", "DONE"]: seen_recovery = true

func tick() -> bool:
	await process_frame
	if finishing or finished or cancelled or collision_invalidated: return false
	if not selftest:
		if root.has_focus(): focus_seen = true
		elif focus_seen:
			cancelled = true
			failures.append("focus_lost")
			return false
	if not is_instance_valid(transport) or not is_instance_valid(transport.body):
		failures.append("runtime_missing")
		return false
	var car: Vector3 = transport.body.global_position
	if section in ["accelerate", "handbrake_with_W", "reaccelerate", "exit_accelerate"]:
		var collisions: Array[Node3D] = transport.body.get_colliding_bodies()
		if not collisions.is_empty():
			var identities: Array[String] = []
			for collision: Node3D in collisions: identities.append(str(collision.get_path()))
			events.append({"kind": "body_collision", "section": section, "physics_frame": Engine.get_physics_frames(), "colliders": identities})
			failures.append("body_collision_invalidates_free_drive:" + section)
			return false
	if section == "handbrake_with_W" and (not driver_attached() or not Input.is_physical_key_pressed(KEY_W) or not Input.is_physical_key_pressed(KEY_SPACE)):
		failures.append("brake_control_or_driver_dropped")
		return false
	episode_distance += car.distance_to(last_car)
	last_car = car
	if car.distance_to(episode_origin) > 45.0 or episode_distance > 60.0 or car.y < episode_origin.y - 5.0:
		failures.append("crop_safety_bound")
		return false
	var now := Time.get_ticks_usec()
	if not metrics.has(section): metrics[section] = {"frame_ms": [], "draw_calls": [], "render_primitives": []}
	if last_stamp > 0 and skip_frames == 0:
		metrics[section].frame_ms.append(float(now - last_stamp) / 1000.0)
		metrics[section].draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		metrics[section].render_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	last_stamp = now
	if skip_frames > 0: skip_frames -= 1
	if rows.size() < 10000:
		rows.append({"episode": episode, "section": section, "physics_frame": Engine.get_physics_frames(), "wall_us": now, "phase": transport.phase, "speed_mps": speed(), "car": [car.x, car.y, car.z], "distance_m": episode_distance, "driver": driver_attached(), "physical_w": Input.is_physical_key_pressed(KEY_W), "forward_action": Input.get_action_strength("preview_move_forward"), "physical_space": Input.is_physical_key_pressed(KEY_SPACE), "body_throttle": transport.body._throttle, "body_handbrake": transport.body._handbrake, "ragdoll_mode": str(transport.character_physics.mode) if transport.character_physics != null else "absent", "camera_yaw": player._camera_yaw, "camera_pitch": player._camera_pitch})
	if ragdoll_pose_ticks >= 10 and not midfall_captured:
		midfall_captured = true
		await capture("03-mid-fall")
	return not cancelled and not finishing and not finished

func seconds(duration: float) -> bool:
	var until := Engine.get_physics_frames() + int(ceil(duration * Engine.physics_ticks_per_second))
	while Engine.get_physics_frames() < until:
		if not await tick(): return false
	return true

func phase(wanted: String, duration: float) -> bool:
	var until := Engine.get_physics_frames() + int(ceil(duration * Engine.physics_ticks_per_second))
	while Engine.get_physics_frames() < until:
		if not await tick(): return false
		if transport.phase == wanted: return true
	failures.append("phase_timeout:" + wanted + ":" + str(transport.phase) + ":" + str(transport.error))
	return false

func capture(label: String) -> void:
	# Readback/write and next three rendered frames never enter frame distributions.
	skip_frames = 3
	if not selftest:
		await RenderingServer.frame_post_draw
		if cancelled or finishing or finished: return
		if root.get_texture().get_image().save_png(out.path_join(label + ".png")) != OK: failures.append("capture:" + label)
	last_stamp = Time.get_ticks_usec()

func fresh() -> bool:
	observing = false
	release()
	if is_instance_valid(main): main.free()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	transport = main.preview_transport
	player = main._player
	if transport == null or main.transport_status != "ready" or not main.preview_ready:
		failures.append("main_not_ready")
		return false
	pose_writer = transport.pose_writer
	transport.pose_writer = Callable(self, "tap")
	transport.body.body_entered.connect(body_contact)
	episode += 1
	episode_origin = transport.body.global_position
	last_car = episode_origin
	episode_distance = 0.0
	section = "warmup%d" % episode
	skip_frames = 3
	last_stamp = 0
	observing = true
	return await seconds(1.2)

func body_contact(other: Node) -> void:
	if section not in ["accelerate", "handbrake_with_W", "reaccelerate", "exit_accelerate"] or finishing or finished: return
	collision_invalidated = true
	events.append({"kind": "body_entered", "section": section, "physics_frame": Engine.get_physics_frames(), "collider": str(other.get_path())})
	failures.append("body_collision_invalidates_free_drive:" + section)

func board() -> bool:
	section = "boarding%d" % episode
	key(KEY_E, true)
	if not await phase("SEATED", 4.5): return false
	key(KEY_E, false)
	if not driver_attached(): failures.append("driver_missing_after_board"); return false
	return await seconds(0.5)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest": selftest = true
		elif arg.begins_with("--braking-output="): out = arg.trim_prefix("--braking-output=")
		elif arg.begins_with("--braking-mode="): mode = arg.trim_prefix("--braking-mode=")
		elif arg.begins_with("--braking-pack="): pack_file = arg.trim_prefix("--braking-pack=")
		elif arg.begins_with("--braking-pack-sha="): pack_sha = arg.trim_prefix("--braking-pack-sha=")
	if not out.is_absolute_path() or mode not in ["baseline", "after"] or selftest != (DisplayServer.get_name() == "headless"):
		push_error("Require absolute --braking-output, baseline|after mode and matching --headless --selftest")
		quit(2); return
	if (not selftest or not pack_file.is_empty()) and (not pack_file.is_absolute_path() or pack_sha.length() != 64 or FileAccess.get_sha256(pack_file) != pack_sha):
		push_error("Native/pack runs require verified absolute --braking-pack and exact --braking-pack-sha")
		quit(2); return
	# Godot removes --main-pack from get_cmdline_args; the external launch receipt
	# must bind this exact PCK to the engine invocation. Never infer that binding.
	DirAccess.make_dir_recursive_absolute(out)
	begin_hashes = hashes()
	begin_memory = memory()
	create_timer(75.0, true, false, true).timeout.connect(watchdog)
	var observer := Observer.new()
	observer.qa = self
	root.add_child(observer)
	if not await fresh() or not await board(): await finish(); return
	await capture("01-seated")
	section = "accelerate"
	key(KEY_W, true)
	if not await seconds(1.5): await finish(); return
	if not Input.is_physical_key_pressed(KEY_W) or Input.get_action_strength("preview_move_forward") < .99 or transport.body._throttle < .99:
		failures.append("physical_W_route_failed")
	result_values["brake_entry_speed_mps"] = speed()
	if speed() < 3.0: failures.append("actual_drive_acceleration_failed")
	var brake_position: Vector3 = transport.body.global_position
	var brake_distance := episode_distance
	section = "handbrake_with_W"
	key(KEY_SPACE, true)
	if not await seconds(3.2): await finish(); return
	result_values["brake_end_speed_mps"] = speed()
	result_values["brake_path_m"] = episode_distance - brake_distance
	result_values["brake_displacement_m"] = transport.body.global_position.distance_to(brake_position)
	result_values["brake_route_valid"] = Input.is_physical_key_pressed(KEY_SPACE) and Input.is_physical_key_pressed(KEY_W) and transport.body._handbrake and transport.body._throttle > .99
	result_values["brake_stopped"] = speed() < .35
	var brake_tail_max := 0.0
	var tail_first := Engine.get_physics_frames() - int(Engine.physics_ticks_per_second * .25)
	for row: Dictionary in rows:
		if row.section == "handbrake_with_W" and int(row.physics_frame) >= tail_first: brake_tail_max = maxf(brake_tail_max, float(row.speed_mps))
	result_values["brake_tail_quarter_second_max_mps"] = brake_tail_max
	result_values["brake_stopped"] = bool(result_values.brake_stopped) and brake_tail_max < .35
	if not result_values.brake_route_valid: failures.append("physical_space_with_W_route_failed")
	if not driver_attached() or transport.phase != "SEATED": failures.append("driver_lost_during_brake")
	if mode == "after" and not result_values.brake_stopped: failures.append("handbrake_did_not_stop_with_throttle")
	key(KEY_SPACE, false)
	section = "reaccelerate"
	var release_speed := speed()
	if not await seconds(.6): await finish(); return
	result_values["reaccelerate_speed_mps"] = speed()
	if mode == "after" and speed() < release_speed + .6: failures.append("release_did_not_reaccelerate")
	key(KEY_W, false)
	await capture("02-brake-episode-end")
	# Reset actual main rather than drive beyond the tiny source crop. Original spawn is retained.
	if not await fresh() or not await board(): await finish(); return
	section = "exit_accelerate"
	key(KEY_W, true)
	if not await seconds(2.0): await finish(); return
	result_values["exit_entry_speed_mps"] = speed()
	if speed() <= 15.0 / 3.6: failures.append("exit_tumble_threshold_not_reached")
	section = "moving_exit"
	key(KEY_E, true)
	if not await phase("EXITING", 1.2): await finish(); return
	key(KEY_W, false)
	key(KEY_E, false)
	if not await phase("ON_FOOT", 9.0): await finish(); return
	section = "recovered"
	if not await seconds(.5): await finish(); return
	result_values["seen_exit_ragdoll"] = seen_ragdoll
	result_values["seen_recovery"] = seen_recovery
	result_values["driver_released"] = not driver_attached()
	result_values["recovered_grounded"] = player.is_on_floor()
	if not seen_ragdoll: failures.append("actual_ragdoll_exit_not_observed")
	if not seen_recovery: failures.append("actual_recovery_not_observed")
	if driver_attached(): failures.append("driver_not_released")
	if not player.is_on_floor(): failures.append("recovered_not_grounded")
	await capture("04-recovered")
	await finish()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	var sorted := values.duplicate()
	sorted.sort()
	return {"count": sorted.size(), "p50": sorted[int(floor((sorted.size() - 1) * .5))], "p95": sorted[int(floor((sorted.size() - 1) * .95))], "max": sorted[-1]}

func finish() -> void:
	if finishing or finished: return
	finishing = true
	observing = false
	release()
	var end_hashes := hashes()
	if begin_hashes != end_hashes: failures.append("source_or_pack_changed")
	var end_memory := memory()
	var timings: Dictionary = {}
	for name: String in metrics:
		timings[name] = {}
		for metric: String in metrics[name]: timings[name][metric] = stats(metrics[name][metric])
	if is_instance_valid(main): main.free()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var restored: bool = main.preview_ready and main.transport_status == "ready"
	if not restored: failures.append("fresh_interactive_restore_failed")
	var report := {"passed": failures.is_empty() and not cancelled and restored, "mode": mode, "selftest": selftest, "native": not selftest, "cancelled": cancelled, "restored_interactive": restored, "failures": failures, "results": result_values, "timings": timings, "samples": rows, "events": events, "begin_hashes": begin_hashes, "end_hashes": end_hashes, "begin_memory": begin_memory, "end_memory": end_memory, "physics_ticks_per_second": Engine.physics_ticks_per_second, "viewport": str(root.size), "qualification": "Actual main physical E/W/Space, no pose/velocity injection; 2 original-spawn episodes; screenshot readback/write and next 3 frames excluded; process memory collected outside measured windows. Rendering primitives are reported as primitives, not guaranteed triangle count. Headless is behavior validation only, never GPU/city FPS. Baseline accepts known brake failure but reports speeds. Native returns fresh interactive main."}
	var file := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	else: push_error("Cannot write braking report")
	print("BRAKING_LIVE_QA ", JSON.stringify({"passed": report.passed, "results": result_values, "failures": failures, "report": out.path_join("report.json")}))
	finished = true
	if selftest: quit(0 if report.passed else 1)

func watchdog() -> void:
	if finishing or finished: return
	cancelled = true
	failures.append("watchdog_75s")
	await finish()
