extends SceneTree
## Observational loaded-scene GPU collector. Same fixture for v3 and v4.
## Explicit actor placement is test setup, not traversal/door behavior evidence.
## After idle: restore input and aim via the owner fixture's native mouse route;
## four real viewport E toggles measure dispatch and full .5s motion (+.15s tail).
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 600
const DEADLINE_MS := 35000
const FIELDS := ["frame_ms", "process_ms", "physics_ms", "draw_calls", "primitives", "static_bytes"]
const MOTION_SAMPLE_CAP := 4096
const MOTION_WINDOW_US := 650000
var output: String = "user://door_perf43"
var game: Node3D
var player: CharacterBody3D
var camera: Camera3D
var host: Node
var started: int = 0
var done: bool = false
var errors: Array[String] = []
var phases: Array[Dictionary] = []
var evidence: Dictionary = {}
var phase_name: String = "startup"
var door_actions: Array[Dictionary] = []
var player_input_before: bool = false
var game_input_before: bool = false
var e_held: bool = false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa43-out="): output = arg.trim_prefix("--qa43-out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_marker()
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - started >= DEADLINE_MS:
		errors.append("35_second_deadline_in_" + phase_name)
		_finish()
	return false

func _write(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(output.path_join(path), FileAccess.WRITE)
	if file == null: errors.append("write_failed:" + path); return
	file.store_string(JSON.stringify(data, "\t")); file.close()

func _marker() -> void:
	_write("door_perf43_active.json", {"pid": OS.get_process_id(), "phase": phase_name, "finished": done, "unix_seconds": Time.get_unix_time_from_system(), "ticks_ms": Time.get_ticks_msec()})

func _require(ok: bool, reason: String) -> bool:
	if not ok: errors.append(reason)
	return ok

func _pins() -> Dictionary:
	var pins: Dictionary = {}
	var pending: Array[String] = ["res://scripts", "res://scenes"]
	while not pending.is_empty():
		var folder: String = pending.pop_back()
		var directory: DirAccess = DirAccess.open(folder)
		if directory == null: errors.append("pin_directory_missing:" + folder); continue
		for file: String in directory.get_files():
			if file.get_extension() in ["gd", "tscn", "gdshader"]:
				pins[folder.path_join(file)] = FileAccess.get_sha256(folder.path_join(file))
		for child: String in directory.get_directories(): pending.append(folder.path_join(child))
	for path: String in ["res://project.godot", "res://data/block.json", "res://data/preview_water.json", "res://data/palazzo_binding.json"]:
		pins[path] = FileAccess.get_sha256(path)
	return pins

func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _transform(value: Transform3D) -> Dictionary:
	return {"origin": _v(value.origin), "basis_x": _v(value.basis.x), "basis_y": _v(value.basis.y), "basis_z": _v(value.basis.z)}

func _settings() -> Dictionary:
	var result: Dictionary = {}
	for item: Dictionary in ProjectSettings.get_property_list():
		var name: String = str(item.name)
		if name.begins_with("rendering/") or name.begins_with("display/window/") or name.begins_with("physics/common/") or name.begins_with("application/run/"):
			result[name] = ProjectSettings.get_setting(name)
	result["actual_renderer"] = RenderingServer.get_current_rendering_method()
	result["actual_vsync"] = DisplayServer.window_get_vsync_mode()
	result["actual_window_size"] = str(DisplayServer.window_get_size())
	result["actual_viewport_size"] = str(root.get_visible_rect().size)
	result["actual_max_fps"] = Engine.max_fps
	result["actual_time_scale"] = Engine.time_scale
	result["actual_physics_ticks_per_second"] = Engine.physics_ticks_per_second
	return result

func _content() -> Dictionary:
	var population: RefCounted = game.get("preview_population")
	var rows: Array = []
	var hp_count: int = 0
	var live_hp: int = 0
	if population != null:
		if population.get("residents") != null: rows = population.residents.snapshot().get("rows", [])
		var owners: Array = population.get("hit_owners")
		hp_count = owners.size()
		for owner: RefCounted in owners:
			if not owner._current(owner.get("_binding")).is_empty(): live_hp += 1
	var ids: Array[String] = []
	var actors: Array[Dictionary] = []
	for row: Dictionary in rows:
		ids.append(str(row.source_id))
		actors.append({"id": row.source_id, "position": _v(row.position) if row.position is Vector3 else null, "generation": row.life_generation, "status": row.status})
	ids.sort()
	var block: Dictionary = game.get("_block")
	var ok: bool = ids.size() == 3 and ids.has("resident_72") and ids.has("resident_169") and ids.has("resident_252") and hp_count == 3 and live_hp == 3 and block.buildings.is_empty() and block.decor.size() == 8
	return {"ok": ok, "npc_ids": ids, "actors": actors, "hp_owners": hp_count, "live_hp_owners": live_hp, "legacy_buildings": block.buildings.size(), "decor": block.decor.size(), "palazzo": host.snapshot(), "water_status": game.get("water_status")}

func _lighting() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in game.get_children():
		if node is DirectionalLight3D:
			result.append({"name": str(node.name), "transform": _transform(node.global_transform), "color": str(node.light_color), "energy": node.light_energy, "shadows": node.shadow_enabled})
	return result

func _run() -> void:
	if not _require(DisplayServer.get_name() != "headless", "gpu_required_no_headless_perf_acceptance"): _finish(); return
	evidence["engine"] = Engine.get_version_info()
	evidence["project"] = ProjectSettings.globalize_path("res://")
	evidence["fixture_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	evidence["source_pins"] = _pins()
	evidence["settings"] = _settings()
	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _require(packed != null, "main_scene_load"): _finish(); return
	game = packed.instantiate() as Node3D
	root.add_child(game); current_scene = game
	for frame in 1200:
		if done: return
		if bool(game.get("preview_ready")): break
		await process_frame
	if not _require(bool(game.get("preview_ready")), "main_not_ready"): _finish(); return
	player = game.get("_player")
	host = game.get("preview_palazzo")
	if not _require(is_instance_valid(player) and is_instance_valid(host) and host.get("status") == "ready", "player_palazzo_not_ready"): _finish(); return
	camera = player.get_preview_camera()
	if not _require(camera == root.get_camera_3d(), "real_player_camera_not_current"): _finish(); return
	evidence["revision"] = game.get_script().get_script_constant_map().get("PREVIEW_RUNTIME_REVISION", "")
	evidence["lighting"] = _lighting()
	evidence["startup_content"] = _content()
	if not _require(evidence.startup_content.ok, "startup_content_mismatch"): _finish(); return
	# Only user input callbacks are disabled; physics/animation/NPC/render work
	# keeps running. Input polling is monitored through actor/camera drift.
	player_input_before = player.is_processing_unhandled_input()
	game_input_before = game.is_processing_unhandled_input()
	player.set_process_unhandled_input(false)
	game.set_process_unhandled_input(false)
	player.set_mouse_captured(true)
	for action: StringName in InputMap.get_actions(): Input.action_release(action)
	for view: Dictionary in [{"name": "inside_closed", "local": Vector3(1, .31, .4), "yaw": PI}]:
		await _phase(view)
		if done: return
	player.set_process_unhandled_input(player_input_before)
	game.set_process_unhandled_input(game_input_before)
	if not _require(player_input_before and game_input_before, "original_door_input_routes_required"): _finish(); return
	await _aim_door()
	if done: return
	for index in 4:
		await _door_action(index, index % 2 == 0)
		if done: return
	_finish()

func _phase(view: Dictionary) -> void:
	phase_name = str(view.name) + ":warmup"
	_marker()
	player.global_position = host.site.to_global(view.local)
	player.velocity = Vector3.ZERO
	player._camera_yaw = float(view.yaw) + host.site.global_rotation.y
	player._camera_pitch = -.08
	player._heading = player._camera_yaw
	player._visual.rotation.y = player._heading + PI - player.global_rotation.y
	player._update_camera_rotation()
	for frame in WARMUP_FRAMES:
		await process_frame
		if done: return
	var start_player: Vector3 = player.global_position
	var start_camera: Transform3D = camera.global_transform
	var initial_content: Dictionary = _content()
	_require(initial_content.ok, str(view.name) + ":content_before")
	_require(not bool(host.site.get("_door_open")) and absf(float(host.site.get("_door_angle"))) < .001, str(view.name) + ":closed_door_required")
	var samples: Dictionary = {}
	for field: String in FIELDS:
		var values: PackedFloat64Array = PackedFloat64Array(); values.resize(SAMPLE_FRAMES)
		samples[field] = values
	var record: Dictionary = {"name": view.name, "requested_local_actor": _v(view.local), "requested_local_yaw": view.yaw, "warmup_frames": WARMUP_FRAMES, "requested_samples": SAMPLE_FRAMES, "actual_samples": 0, "content_before": initial_content, "actor_start": _v(start_player), "actor_local_start": _v(host.site.to_local(start_player)), "camera_start": _transform(start_camera), "camera_fov": camera.fov, "camera_near": camera.near, "camera_far": camera.far, "door_action": game._current_door_action(), "samples": samples}
	phases.append(record)
	phase_name = str(view.name) + ":sample"
	_marker()
	var last: int = Time.get_ticks_usec()
	var max_player_drift: float = 0.0
	var max_camera_drift: float = 0.0
	var max_camera_rotation: float = 0.0
	for index in SAMPLE_FRAMES:
		await process_frame
		if done: return
		var now: int = Time.get_ticks_usec()
		samples.frame_ms[index] = float(now - last) / 1000.0
		samples.process_ms[index] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		samples.physics_ms[index] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		samples.draw_calls[index] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		samples.primitives[index] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		samples.static_bytes[index] = Performance.get_monitor(Performance.MEMORY_STATIC)
		last = now
		record.actual_samples = index + 1
		max_player_drift = maxf(max_player_drift, player.global_position.distance_to(start_player))
		max_camera_drift = maxf(max_camera_drift, camera.global_position.distance_to(start_camera.origin))
		max_camera_rotation = maxf(max_camera_rotation, camera.global_basis.get_rotation_quaternion().angle_to(start_camera.basis.get_rotation_quaternion()))
	var final_content: Dictionary = _content()
	record.content_after = final_content
	record.actor_end = _v(player.global_position)
	record.camera_end = _transform(camera.global_transform)
	record.max_actor_drift_m = max_player_drift
	record.max_camera_drift_m = max_camera_drift
	record.max_camera_rotation_rad = max_camera_rotation
	_require(final_content.ok, str(view.name) + ":content_after")
	_require(camera == root.get_camera_3d() and max_player_drift < .01 and max_camera_drift < .01 and max_camera_rotation < .001, str(view.name) + ":fixed_actor_and_camera")
	_require(not bool(host.site.get("_door_open")) and absf(float(host.site.get("_door_angle"))) < .001, str(view.name) + ":door_changed_during_sample")
	record.summary = _summary(samples, int(record.actual_samples))
	_require(float(record.summary.frame_ms.p50) > 0.0 and float(record.summary.draw_calls.p50) > 0.0, str(view.name) + ":nonzero_real_frame_and_render_samples")
	phase_name = str(view.name) + ":complete"
	_marker()
	print("DOOR_PERF43_PHASE ", view.name, " ", JSON.stringify(record.summary))

func _aim_door() -> void:
	phase_name = "door_native_mouse_aim"
	_marker()
	for index in 70:
		var direction: Vector3 = (host.site.to_global(Vector3(1, 1.57, 3)) - camera.global_position).normalized()
		var yaw: float = atan2(-direction.x, -direction.z)
		var pitch: float = asin(clampf(direction.y, -.98, .98))
		var event: InputEventMouseMotion = InputEventMouseMotion.new()
		event.position = root.get_visible_rect().get_center()
		event.global_position = event.position
		event.relative = Vector2(-clampf(wrapf(yaw - player._camera_yaw, -PI, PI) * .35, -.045, .045) / player.mouse_sensitivity, -clampf((pitch - player._camera_pitch) * .35, -.045, .045) / player.mouse_sensitivity)
		root.push_input(event, true)
		await physics_frame
		if done: return
		await process_frame
		if done: return
	for frame in 6:
		await physics_frame
		if done: return
		await process_frame
		if done: return

func _key_e(pressed: bool) -> int:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = pressed
	e_held = pressed
	var before: int = Time.get_ticks_usec()
	root.push_input(event, true)
	return Time.get_ticks_usec() - before

func _door_busy() -> bool:
	var tween: Tween = host.site.get("_door_tween") as Tween
	return is_instance_valid(tween) and tween.is_running()

func _door_action(index: int, opening: bool) -> void:
	var label: String = "toggle_%d_%s" % [index + 1, "open" if opening else "close"]
	phase_name = label + ":motion"
	_marker()
	var action: Dictionary = game._current_door_action()
	if not _require(action.get("owner") == "palazzo" and not _door_busy() and bool(host.site.get("_door_open")) != opening, label + ":native_target_and_prior_state"):
		return
	var first_actor: Vector3 = player.global_position
	var first_camera: Transform3D = camera.global_transform
	var first_content: Dictionary = _content()
	_require(first_content.ok, label + ":content_before")
	var samples: Dictionary = {}
	for field: String in FIELDS:
		var values: PackedFloat64Array = PackedFloat64Array()
		values.resize(MOTION_SAMPLE_CAP)
		samples[field] = values
	var physics_ticks: PackedInt64Array = PackedInt64Array()
	physics_ticks.resize(MOTION_SAMPLE_CAP)
	var record: Dictionary = {"name": label, "opening": opening, "input_route": "Viewport.push_input(local=true)", "target_before": action, "actor_start": _v(first_actor), "actor_local_start": _v(host.site.to_local(first_actor)), "camera_start": _transform(first_camera), "camera_fov": camera.fov, "content_before": first_content, "actual_samples": 0, "samples": samples, "physics_frames": physics_ticks, "motion_window_us": MOTION_WINDOW_US, "completed": false}
	door_actions.append(record)
	var initial_tick: int = Engine.get_physics_frames()
	var begin: int = Time.get_ticks_usec()
	record.press_dispatch_us = _key_e(true)
	record.native_motion_started = bool(host.site.get("_door_target_open")) == opening and _door_busy()
	_require(record.native_motion_started, label + ":actual_E_started_motion")
	var last: int = begin # First interval includes synchronous E admission.
	var max_actor_drift: float = 0.0
	var max_camera_drift: float = 0.0
	var max_camera_rotation: float = 0.0
	var index_sample: int = 0
	var finished_at_us: int = -1
	while Time.get_ticks_usec() - begin < MOTION_WINDOW_US and index_sample < MOTION_SAMPLE_CAP:
		await process_frame
		if done: return
		var now: int = Time.get_ticks_usec()
		samples.frame_ms[index_sample] = float(now - last) / 1000.0
		samples.process_ms[index_sample] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		samples.physics_ms[index_sample] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		samples.draw_calls[index_sample] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		samples.primitives[index_sample] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		samples.static_bytes[index_sample] = Performance.get_monitor(Performance.MEMORY_STATIC)
		physics_ticks[index_sample] = Engine.get_physics_frames()
		index_sample += 1
		record.actual_samples = index_sample
		last = now
		if e_held and Engine.get_physics_frames() > initial_tick: record.release_dispatch_us = _key_e(false)
		if finished_at_us < 0 and not _door_busy(): finished_at_us = now - begin
		max_actor_drift = maxf(max_actor_drift, player.global_position.distance_to(first_actor))
		max_camera_drift = maxf(max_camera_drift, camera.global_position.distance_to(first_camera.origin))
		max_camera_rotation = maxf(max_camera_rotation, camera.global_basis.get_rotation_quaternion().angle_to(first_camera.basis.get_rotation_quaternion()))
	if e_held: record.release_dispatch_us = _key_e(false)
	var target_angle: float = PI * .5 if opening else 0.0
	var final_angle: float = float(host.site.get("_door_angle"))
	record.finished_at_us = finished_at_us
	record.observed_window_us = Time.get_ticks_usec() - begin
	record.final_open = bool(host.site.get("_door_open"))
	record.final_angle = final_angle
	record.final_busy = _door_busy()
	record.actor_end = _v(player.global_position)
	record.camera_end = _transform(camera.global_transform)
	record.max_actor_drift_m = max_actor_drift
	record.max_camera_drift_m = max_camera_drift
	record.max_camera_rotation_rad = max_camera_rotation
	record.content_after = _content()
	record.physics_frames = physics_ticks.slice(0, index_sample)
	record.summary = _summary(samples, index_sample)
	_require(index_sample > 0 and index_sample < MOTION_SAMPLE_CAP and int(record.observed_window_us) >= MOTION_WINDOW_US, label + ":complete_bounded_motion_window")
	_require(bool(record.final_open) == opening and absf(final_angle - target_angle) < .001 and not bool(record.final_busy), label + ":intended_final_pose")
	_require(camera == root.get_camera_3d() and max_actor_drift < .01 and max_camera_drift < .01 and max_camera_rotation < .001, label + ":no_actor_camera_drift")
	_require(record.content_after.ok, label + ":content_after")
	record.completed = true
	print("DOOR_PERF43_ACTION ", label, " dispatch_us=", record.press_dispatch_us, " ", JSON.stringify(record.summary))

func _summary(samples: Dictionary, count: int) -> Dictionary:
	var result: Dictionary = {}
	if count == 0: return result
	for field: String in FIELDS:
		var values: PackedFloat64Array = samples[field].slice(0, count)
		values.sort()
		result[field] = {"p50": values[maxi(0, ceili(count * .50) - 1)], "p95": values[maxi(0, ceili(count * .95) - 1)], "max": values[count - 1]}
	return result

func _finish() -> void:
	if done: return
	if e_held: _key_e(false)
	done = true
	var complete: bool = phases.size() == 1
	for phase: Dictionary in phases:
		var count: int = int(phase.actual_samples)
		complete = complete and count == SAMPLE_FRAMES
		phase.summary = _summary(phase.samples, count)
		for field: String in FIELDS: phase.samples[field] = phase.samples[field].slice(0, count)
	if not complete: errors.append("incomplete_fixed_pose_samples")
	var actions_complete: bool = door_actions.size() == 4
	for action: Dictionary in door_actions:
		var count: int = int(action.actual_samples)
		actions_complete = actions_complete and bool(action.get("completed", false))
		action.summary = _summary(action.samples, count)
		for field: String in FIELDS: action.samples[field] = action.samples[field].slice(0, count)
		action.physics_frames = action.physics_frames.slice(0, count)
	if not actions_complete: errors.append("incomplete_four_real_E_actions")
	evidence["status"] = "MEASUREMENT_COMPLETE_COMPARE_REQUIRED" if errors.is_empty() else "UNVERIFIED"
	evidence["performance_accepted"] = false
	evidence["failures"] = errors
	evidence["pid"] = OS.get_process_id()
	evidence["phases"] = phases
	evidence["door_actions"] = door_actions
	evidence["action_scope"] = "safe inside actor 2.6m from plane; actual E open/close/open/close; dispatch microseconds and .65s process/physics-monitor windows cover full .5s native motion; original player input restored; no actor teleport between idle and actions; not occupied-sweep behavior acceptance"
	evidence["elapsed_ms"] = Time.get_ticks_msec() - started
	evidence["rss"] = "EXTERNAL_SIDECAR_REQUIRED; static_bytes is engine allocation, not process RSS"
	evidence["scope"] = "loaded onlyPalazzo scene; real player/camera; one fixed inside closed-door idle view and four actual safe-point E transactions; fixture placement; 3 NPC remain active; comparison required; no full-city perf claim"
	_write("door_perf43.json", evidence)
	phase_name = "finished"
	_marker()
	print("DOOR_PERF43_FINISHED ", evidence.status, " ", ProjectSettings.globalize_path(output.path_join("door_perf43.json")))
	quit(0 if errors.is_empty() else 1)
