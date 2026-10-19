extends SceneTree
const MapProjection = preload("res://addons/walk_minimap/map_projection.gd")
const Waypoint = preload("res://addons/walk_minimap/waypoint_state.gd")
const Minimap = preload("res://addons/walk_minimap/minimap_control.gd")
var checks := 0
var failures: Array = []
var changes: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("CHECK FAILED: ", label)

func near(a: float, b: float, label: String) -> void:
	check(absf(a - b) < 0.00001, label)

func key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func mouse(button: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	return event

func run() -> void:
	# Keep the owned child alive for scheduler identity registration.
	await create_timer(2.0).timeout
	var projection = MapProjection.new(Vector2(-120, 30), Vector2(230, 194), 0.75)
	check(projection.is_valid(), "projection valid")
	for x in [-250.0, -1.0, 0.0, 120.0]:
		for z in [-210.0, 0.0, 300.0]:
			check(projection.to_world(projection.to_screen(Vector2(x, z))).distance_to(Vector2(x, z)) < 0.0001, "roundtrip (Godot Vector2 float32)")
	check(projection.to_screen(Vector2(-120, 29)).y < 97, "north up")
	check(not MapProjection.valid_bounds({"minX": 1, "maxX": 1, "minZ": 0, "maxZ": 2}), "no zero width bounds")
	var bounds := {"minX": -100, "maxX": 100, "minZ": -80, "maxZ": 80}
	var state = Waypoint.new()
	state.set_waypoint({"x": 200, "z": -200, "name": "Банк", "id": "bank", "kind": "bank", "buildingId": null, "lotId": 7, "ignored": true}, bounds)
	check(state.get_waypoint() == {"x": 100.0, "z": -80.0, "name": "Банк", "id": "bank", "kind": "bank", "buildingId": null, "lotId": 7}, "clamp metadata whitelist")
	var copy: Dictionary = state.get_waypoint()
	copy.x = 0
	check(state.get_waypoint().x == 100, "external mutation isolated")
	state.set_waypoint({"x": 0, "z": 0}, bounds)
	check(state.info({"x": 4.999, "z": 0}).arrived, "4.999 arrived")
	check(not state.info({"x": 5, "z": 0}).arrived, "5 not arrived")
	check(state.get_waypoint() != null, "arrival info never clears")
	check(Waypoint.reached_waypoint({"x": 1.15, "y": 0.9, "z": 0}, {"x": 0, "y": 0, "z": 0}), "physical boundary inclusive")
	check(not Waypoint.can_auto_remove({"x": 0, "y": 0, "z": 0}, {"x": 0, "y": 0, "z": 0}, {"walking": true, "jump": true}), "host jump gates removal")
	state.set_route({"status": "ready", "points": [{"x": 0, "z": 0}, {"x": 3, "z": 4}]})
	near(state.get_route().distance, 5, "route measured")
	state.set_route({"status": "ready", "points": [{"x": 0, "z": 0}, {"x": NAN, "z": 4}, {"x": 3, "z": 4}]})
	check(state.get_route().status == "blocked" and state.get_route().points.is_empty(), "invalid segment never joined")
	state.set_route({"status": "pending"})
	check(state.status_text({"x": 0, "z": 0}) == "Строю маршрут…", "pending text")
	state.set_waypoint({"x": 0, "z": 0}, bounds)
	check(state.get_route() == null, "same target invalidates route")
	var map = Minimap.new()
	map.auto_layout = false
	map.size = Vector2(230, 266)
	root.add_child(map)
	map.set_process(false)
	map.waypoint_changed.connect(func(value): changes.append(value))
	check(map.set_world({"bounds": bounds, "objects": []}), "explicit bounds")
	check(not map.set_world({"bounds": {}}), "bad provider bounds rejected")
	var stats: Dictionary = map.draw_stats()
	var now: float = stats.last_ms
	map.update_state({"position": {"x": 1, "z": 0}}, now + 79)
	check(map.draw_stats().requests == stats.requests, "79 ms capped")
	map.update_state({}, now + 80)
	check(map.draw_stats().requests == stats.requests + 1, "80 ms dirty draws")
	map.update_state({}, now + 160)
	check(map.draw_stats().requests == stats.requests + 1, "unchanged idle")
	map.handle_map_event(mouse(MOUSE_BUTTON_LEFT, true, Vector2(115, 97)))
	check(map.get_waypoint() == null, "left down does not place")
	map.handle_map_event(mouse(MOUSE_BUTTON_LEFT, false, Vector2(115, 97)))
	check(map.get_waypoint() != null and changes.size() == 1, "left up places once")
	map.set_waypoint({"x": 100, "z": 80})
	var marker: Vector2 = map.get_projection().marker_position(map.get_waypoint())
	map.handle_map_event(mouse(MOUSE_BUTTON_RIGHT, true, marker + Vector2(-13, 0)))
	check(map.get_waypoint() != null, "13 px preserves clipped marker")
	map.handle_map_event(mouse(MOUSE_BUTTON_RIGHT, true, marker + Vector2(-12, 0)))
	check(map.get_waypoint() == null, "12 px removes clipped marker")
	map.set_waypoint({"x": 50, "z": 50})
	var road := {"status": "ready", "points": [{"x": 0, "z": 0}, {"x": 3, "z": 4}]}
	map.set_route(road)
	var before_repeat: Dictionary = map.draw_stats()
	var route_start := Time.get_ticks_usec()
	for i in range(100):
		map.set_route(road.duplicate(true))
	var equal_route_cpu_us := Time.get_ticks_usec() - route_start
	check(map.draw_stats().requests == before_repeat.requests, "equal route no forced redraw")
	check(map.draw_stats().route_path_builds == before_repeat.route_path_builds, "equal route geometry reused")
	var same_value: Variant = map.get_waypoint()
	map.set_waypoint(same_value)
	check(map.get_route() == null, "same waypoint clears cached route")
	map.set_waypoint(null)
	check(not map.handle_key_event(key(KEY_ESCAPE)) and not map.expanded, "Esc collapsed does nothing")
	map.handle_key_event(key(KEY_M, true, true))
	check(not map.expanded, "M repeat ignored")
	map.handle_key_event(key(KEY_M))
	check(map.expanded, "M expands")
	var control := key(KEY_M)
	control.ctrl_pressed = true
	map.handle_key_event(control)
	check(map.expanded, "modifier M ignored")
	var anchor := Vector2(61, 72)
	var before: Vector2 = map.get_projection().to_world(anchor)
	map.zoom_by(1.2, anchor)
	check(before.distance_to(map.get_projection().to_world(anchor)) < 0.00001, "cursor anchored zoom")
	map.set_waypoint(null)
	map.handle_map_event(mouse(MOUSE_BUTTON_LEFT, true, Vector2(50, 50)))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(56, 50)
	map.handle_map_event(motion)
	map.handle_map_event(mouse(MOUSE_BUTTON_LEFT, false, Vector2(56, 50)))
	check(map.get_waypoint() == null, "drag over5 no marker")
	map.handle_key_event(key(KEY_ESCAPE))
	check(not map.expanded, "Esc closes")
	check(Minimap.vehicle_color({"color": 0x005522}) == Color("005522"), "vehicle numeric paint")
	check(Minimap.vehicle_color({"color": "bad"}) == Color("f2c48a"), "vehicle paint fallback")
	await process_frame
	map.queue_free()
	await process_frame
	await process_frame
	var receipt := {"schema": "mafiozi.minimap.smoke/v1", "checks": checks, "failures": failures, "passed": failures.is_empty(), "engine": Engine.get_version_info().string, "cost_scope": {"equal_route_calls": 100, "cpu_us": equal_route_cpu_us, "additional_draw_requests": 0, "additional_geometry_builds": 0}, "full_city": "NOT_RUN", "performance": "NOT_RUN"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="):
			var file := FileAccess.open(arg.trim_prefix("--receipt="), FileAccess.WRITE)
			file.store_string(JSON.stringify(receipt, "\t"))
	print(JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
