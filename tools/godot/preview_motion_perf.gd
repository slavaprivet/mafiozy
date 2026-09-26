extends SceneTree
## One visible native window, exported content, bounded real input/physics runs.
## Never captures PNG or writes reports inside the measurement window.
var main: Node3D
var player: CharacterBody3D
var output := ""
var selftest := false
var errors: Array[String] = []
var observer: FrameObserver

class FrameObserver extends Node:
	var active := false
	var headless := false
	var last := 0
	var count := 0
	var input_seen := false
	var focus_lost := false
	var overflow := false
	var wall := PackedInt64Array()
	var calls := PackedInt64Array()
	var primitives := PackedInt64Array()
	func prepare() -> void:
		wall.resize(10000)
		calls.resize(10000)
		primitives.resize(10000)
		process_priority = 100
		set_process(false)
	func begin() -> void:
		last = 0
		active = true
		set_process(true)
	func _process(_dt: float) -> void:
		var now := Time.get_ticks_usec()
		if last == 0:
			last = now
			return
		if count >= wall.size():
			overflow = true
			return
		wall[count] = now-last
		calls[count] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives[count] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		count += 1
		last = now
		focus_lost = focus_lost or (not headless and not DisplayServer.window_is_focused())
	func _input(event: InputEvent) -> void:
		if active and (event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton):
			input_seen = true
	func finish() -> void:
		active = false
		set_process(false)
		wall.resize(count)
		calls.resize(count)
		primitives.resize(count)

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--motion-selftest":
			selftest = true
		elif arg.begins_with("--motion-output="):
			output = arg.trim_prefix("--motion-output=")
	if not output.is_absolute_path() or selftest != (DisplayServer.get_name() == "headless"):
		quit(2)
		return
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--fixed-fps") or arg.begins_with("--preview-capture") or arg == "--preview-perf":
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get("_player")
	player.set_mouse_captured(false)
	player.set_process_unhandled_input(false)
	await ticks(20)
	if not main.preview_ready or not player.is_on_floor():
		errors.append("Initial actual scene not supported/ready")
	var initial := player.global_position
	var yaw := choose_route(initial)
	if not is_finite(yaw):
		errors.append("No verified 6m dry flat route at authored preview start")
	else:
		player.set("_camera_yaw", yaw)
		player.call("_update_camera_rotation")
		await ticks(2 if selftest else 300)
		observer = FrameObserver.new()
		observer.headless = selftest
		root.add_child(observer)
		observer.prepare()
		var settings := {"camera_yaw": yaw, "camera_pitch": player.get("_camera_pitch"), "camera_distance": player.camera_distance,
			"viewport": str(root.size), "max_fps": Engine.max_fps, "vsync": DisplayServer.window_get_vsync_mode(),
			"msaa": root.msaa_3d, "render_scale": root.scaling_3d_scale, "physics_hz": Engine.physics_ticks_per_second}
		var episodes: Array[Dictionary] = []
		observer.begin()
		for episode in range(2 if selftest else 8):
			var direction: StringName = &"preview_move_forward" if episode % 2 == 0 else &"preview_move_back"
			var from := player.global_position
			await double_space(direction)
			var saw_dive := false
			var peak := player.global_position.y
			var air_at_09 := false
			for frame in range(132):
				await ticks(1)
				var jump: Dictionary = player.get_preview_status().get("source_jump", {})
				saw_dive = saw_dive or jump.get("mode") == "dive"
				peak = maxf(peak, player.global_position.y)
				if frame == 51:
					air_at_09 = not player.is_on_floor()
			episodes.append({"index": episode, "distance_m": Vector2(player.global_position.x-from.x,player.global_position.z-from.z).length(),
				"peak_y": peak, "dive": saw_dive, "airborne_at_about_09s": air_at_09, "grounded_after": player.is_on_floor(),
				"end_feet": str(player.global_position), "end_jump": player.get_preview_status().get("source_jump", {})})
			if not saw_dive or not player.is_on_floor():
				errors.append("Dive/landing incomplete in episode " + str(episode))
		observer.finish()
		if observer.input_seen or observer.focus_lost or observer.overflow:
			errors.append("Input/focus/capacity invalidated motion measurement")
		# A separate final dive creates a late-flight image after timing has stopped.
		await double_space(&"preview_move_forward")
		await ticks(53)
		if not selftest:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("late-flight.png"))
		var report := {"passed": errors.is_empty(), "errors": errors, "selftest": selftest, "settings": settings,
			"frame_us": stats(observer.wall), "draw_calls": stats(observer.calls), "primitives": stats(observer.primitives),
			"raw_frame_us": Array(observer.wall), "episodes": episodes, "input_seen": observer.input_seen, "focus_lost": observer.focus_lost,
			"qualification": "One small preview quarter, NPC0/vehicles0, actual synthetic input + native physics. Debug engine with exported PCK. Not whole-city or standalone release FPS.",
			"executable": OS.get_executable_path(), "engine": Engine.get_version_info()}
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
		file.close()
	# Always restore ordinary input at the requested actual printshop entrance.
	main.free()
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if not selftest:
		await ticks(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("restored-spawn.png"))
	print("MOTION_PERF_COMPLETE errors=", errors, " interactive_restored=", main.preview_ready)
	if selftest:
		quit(0 if errors.is_empty() else 1)

func double_space(direction: StringName) -> void:
	Input.action_press(direction)
	Input.action_press(&"preview_jump")
	await ticks(1)
	Input.action_release(&"preview_jump")
	await ticks(1)
	Input.action_press(&"preview_jump")
	await ticks(1)
	Input.action_release(&"preview_jump")
	Input.action_release(direction)

func choose_route(at: Vector3) -> float:
	var shape := CapsuleShape3D.new()
	shape.radius = .36
	shape.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * .97)
	var space := player.get_world_3d().direct_space_state
	for candidate in range(8):
		var yaw := candidate * PI / 4.0
		var direction := Vector3(-sin(yaw),0,-cos(yaw))
		query.motion = direction * 6.0
		var fractions := space.cast_motion(query)
		var clear := fractions.size() == 2 and fractions[0] >= .99999
		for step in range(51):
			var point := at + direction * float(step) * 6.0 / 50.0
			clear = clear and main.preview_jump_surface_allowed(point, .36)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.3,1,[player.get_rid()]))
			clear = clear and not hit.is_empty() and absf(float(hit.get("position", Vector3.INF).y)-at.y) < .05
		if clear:
			return yaw
	return INF

func stats(values: PackedInt64Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"count": sorted.size(), "p50": sorted[int(ceil(sorted.size()*.5))-1], "p95": sorted[int(ceil(sorted.size()*.95))-1], "max": sorted[-1]}
