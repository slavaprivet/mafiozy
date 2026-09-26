extends SceneTree
## Run by coordinator in the sole visible window with --main-pack candidate.pck.
## Static shoreline render comparison; explicitly not loaded-city gameplay FPS.
const ORDER := [false, true, true, false]
var _main: Node3D
var _measuring := false
var _input_seen := false
var _selftest := false
var _gameplay := false
var _out := ""
var _errors: Array[String] = []

class InputObserver extends Node:
	var owner_tree: SceneTree
	func _input(event: InputEvent) -> void:
		if owner_tree.get("_measuring") and (event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton):
			owner_tree.set("_input_seen", true)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--water-qa-selftest":
			_selftest = true
		elif arg == "--water-qa-gameplay":
			_gameplay = true
		elif arg.begins_with("--water-qa-output="):
			_out = arg.trim_prefix("--water-qa-output=")
	if not _out.is_absolute_path() or _selftest != (DisplayServer.get_name() == "headless"):
		push_error("Absolute output path and matching native/selftest mode required")
		quit(2)
		return
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--fixed-fps") or arg.begins_with("--preview-capture") or arg == "--preview-perf" or arg == "--preview-water-off":
			push_error("Conflicting measurement argument: " + arg)
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(_out)
	var observer := InputObserver.new()
	observer.owner_tree = self
	root.add_child(observer)
	var rows: Array[Dictionary] = []
	var reference_settings: Dictionary = {}
	var warmup_us: int = 20000 if _selftest else 5000000
	var frame_count: int = 12 if _selftest else 600
	for index in range(ORDER.size()):
		if _main != null:
			_main.free()
			await process_frame
		_main = load("res://scenes/main.tscn").instantiate()
		_main.preview_water_detail_enabled = ORDER[index]
		root.add_child(_main)
		if not _main.preview_ready or _main.water_status != ("detail_ready" if ORDER[index] else "baseline_disabled"):
			_errors.append("Water/main admission failed in window " + str(index))
			break
		var player: Node = _main.get("_player")
		player.set_mouse_captured(false)
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		# Fixed source-world viewpoint aimed at actual native water near the bank.
		var origin: Vector3 = _main.get("_origin")
		var camera := Camera3D.new()
		_main.add_child(camera)
		camera.global_position = Vector3(353.0, 12.0, 31.0) - origin
		camera.look_at(Vector3(374.0, -0.18, 24.0) - origin)
		camera.fov = 65.0
		camera.make_current()
		var settings := {"camera": str(camera.global_transform), "fov": camera.fov,
			"viewport": str(root.size), "msaa": root.msaa_3d, "scale": root.scaling_3d_scale,
			"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
			"physics_ticks": Engine.physics_ticks_per_second}
		if index == 0:
			reference_settings = settings.duplicate(true)
		elif settings != reference_settings:
			_errors.append("Camera/render settings differ between windows")
		var until := Time.get_ticks_usec() + warmup_us
		while Time.get_ticks_usec() < until:
			await process_frame
		var stamps := PackedInt64Array()
		var calls := PackedInt64Array()
		var triangles := PackedInt64Array()
		stamps.resize(frame_count)
		calls.resize(frame_count)
		triangles.resize(frame_count)
		_input_seen = false
		var focus_lost := false
		var settings_changed := false
		await process_frame # Discard allocation/boundary partial frame.
		var before := Time.get_ticks_usec()
		_measuring = true
		for frame in range(frame_count):
			await process_frame
			var now := Time.get_ticks_usec()
			stamps[frame] = now - before
			before = now
			calls[frame] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			triangles[frame] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			focus_lost = focus_lost or (not _selftest and not DisplayServer.window_is_focused())
			settings_changed = settings_changed or Engine.time_scale != 1.0 or paused
		_measuring = false
		var row := {"index": index, "water_detail": ORDER[index], "status": _main.water_status,
			"camera_transform": str(camera.global_transform), "fov": camera.fov,
			"settings": settings,
			"viewport": str(root.size), "warmup_us": warmup_us, "frames": frame_count,
			"frame_us": summarize(stamps), "draw_calls": summarize(calls), "primitives": summarize(triangles),
			"input_seen": _input_seen, "focus_lost": focus_lost, "settings_changed": settings_changed,
			"raw_frame_us": Array(stamps)}
		if _input_seen or focus_lost or settings_changed:
			_errors.append("Window %d affected by input/focus/settings" % index)
		if index < 2 and not _selftest:
			await RenderingServer.frame_post_draw
			var capture_path := _out.path_join("water-%s.png" % ("on" if ORDER[index] else "off"))
			row["capture_error"] = root.get_texture().get_image().save_png(capture_path)
			row["capture"] = capture_path
		rows.append(row)
	# Return the same sole window to ordinary interactive play, even after failure.
	if _main != null:
		_main.free()
		await process_frame
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	if not _main.preview_ready:
		_errors.append("Interactive scene restore failed")
	var gameplay: Dictionary = {}
	if _gameplay and _main.preview_ready:
		gameplay = await capture_gameplay()
		_main.free()
		await process_frame
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	var report := {"passed": _errors.is_empty() and rows.size() == 4, "errors": _errors,
		"headless_selftest": _selftest, "engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(), "executable": OS.get_executable_path(),
		"qualification": "Debug engine with exported content; static small-quarter shoreline. Wall frame intervals, not GPU timestamps or full gameplay FPS. Source water phase advances naturally.",
		"npc": 0, "vehicles": 0, "windows": rows, "interactive_restored": _main.preview_ready,
		"sources": source_receipts(), "gameplay": gameplay}
	var file := FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write water QA report")
	else:
		file.store_string(JSON.stringify(report))
		file.close()
	print("WATER_RENDER_QA_COMPLETE passed=", report.passed, " interactive_restored=", _main.preview_ready)
	if _selftest:
		quit(0 if report.passed else 1)

func summarize(values: PackedInt64Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	return {"p50": sorted[int(ceil(sorted.size() * 0.5)) - 1],
		"p95": sorted[int(ceil(sorted.size() * 0.95)) - 1], "max": sorted[-1]}

func source_receipts() -> Dictionary:
	var receipts := {}
	for path: String in ["res://data/block.json", "res://data/preview_water.json", "res://data/printshop_interior.json"]:
		receipts[path] = FileAccess.get_sha256(path)
	return receipts

func capture_gameplay() -> Dictionary:
	# Runs only after measurement. Synthetic game actions, never OS input.
	var player: CharacterBody3D = _main.get("_player")
	player.set_mouse_captured(false)
	player.set_process_unhandled_input(false)
	for i in range(30):
		await physics_frame
		await process_frame
	var shape := CapsuleShape3D.new()
	shape.radius = .36
	shape.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP * .97)
	var space := player.get_world_3d().direct_space_state
	var selected := -1
	for candidate in range(8):
		var yaw := candidate * PI / 4.0
		var direction := Vector3(-sin(yaw), 0, -cos(yaw))
		query.motion = direction * 3.5
		var fractions := space.cast_motion(query)
		var clear: bool = fractions.size() == 2 and fractions[0] >= .99999
		for step in range(31):
			var point := player.global_position + direction * float(step) * 3.5 / 30.0
			clear = clear and _main.preview_jump_surface_allowed(point, .36)
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .3, point - Vector3.UP * .3, 1, [player.get_rid()])
			var hit := space.intersect_ray(ray)
			clear = clear and not hit.is_empty() and absf(float(hit.get("position", Vector3.INF).y) - player.global_position.y) < .05
		if clear:
			selected = candidate
			break
	if selected < 0:
		_errors.append("No verified flat dry 3.5m dive route at current source spawn")
		return {"dive": "route_unavailable"}
	player.set("_camera_yaw", selected * PI / 4.0)
	player.call("_update_camera_rotation")
	Input.action_press(&"preview_move_forward")
	Input.action_press(&"preview_jump")
	await physics_frame
	await process_frame
	Input.action_release(&"preview_jump")
	await physics_frame
	await process_frame
	Input.action_press(&"preview_jump")
	await physics_frame
	await process_frame
	Input.action_release(&"preview_jump")
	Input.action_release(&"preview_move_forward")
	var captures: Array[Dictionary] = []
	for frame in range(140):
		await physics_frame
		await process_frame
		var status: Dictionary = player.get_preview_status()
		var jump: Dictionary = status.get("source_jump", {})
		if not jump.is_empty() and jump.get("mode") == "dive" and captures.size() < 2:
			var target_elapsed: float = .4 if captures.is_empty() else .85
			if float(jump.elapsed) >= target_elapsed:
				var path := _out.path_join("dive-%d.png" % captures.size())
				if not _selftest:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(path)
				captures.append({"path": path, "headless": _selftest, "jump": player.get_preview_status().get("source_jump", {}), "feet": str(player.global_position)})
	if captures.size() != 2 or not player.is_on_floor() or not player.get_preview_status().get("source_jump", {}).is_empty():
		_errors.append("Actual scene dive/landing capture incomplete")
	var interior: Node3D = _main.get("_printshop")
	var camera := Camera3D.new()
	_main.add_child(camera)
	camera.global_position = interior.anchor("publicInside") + Vector3.UP * 1.5
	camera.look_at(interior.anchor("work") + Vector3.UP * 1.0)
	camera.make_current()
	for i in range(10):
		await process_frame
	var interior_path := _out.path_join("printshop-finish.png")
	if not _selftest:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(interior_path)
	return {"dive_captures": captures, "route_yaw": selected * PI / 4.0, "grounded_after": player.is_on_floor(), "interior_capture": interior_path}
