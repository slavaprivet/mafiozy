extends SceneTree

const Map = preload("res://addons/walk_minimap/minimap_control.gd")
var failures: Array[String] = []
var checks := 0
var states: Array = []
var capture_dir := ""
var receipt_path := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--receipt="):
			receipt_path = argument.trim_prefix("--receipt=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func settle() -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw

func descendants(node: Node, result: Array) -> void:
	for child in node.get_children():
		result.append(child)
		descendants(child, result)

func capture(name: String) -> void:
	if not capture_dir.is_empty():
		var error: int = root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
		expect(error == OK, "capture " + name)

func measure(map: Control, name: String) -> void:
	var sidebar: Control = map.get("_sidebar")
	var bounds := sidebar.get_global_rect()
	var controls: Array = []
	descendants(sidebar, controls)
	var widest := bounds.end.x
	for child in controls:
		if child is Control and child.is_visible_in_tree() and not child is ScrollBar:
			var rectangle: Rect2 = child.get_global_rect()
			widest = maxf(widest, rectangle.end.x)
			expect(rectangle.end.x <= bounds.end.x + 0.1, name + " child fits " + str(child.get_class()) + " " + str(child.name))
	var viewport := root.size
	expect(bounds.end.x <= map.get_global_rect().end.x + 0.1, name + " sidebar inside map")
	expect(bounds.end.x <= viewport.x + 0.1, name + " sidebar inside viewport")
	expect(absf(bounds.size.x - (135 if viewport.x < 700 else 210)) < 0.1, name + " source aside width")
	var help: Label = map.get("_help")
	var help_text_size: Vector2 = help.get_theme_default_font().get_multiline_string_size(help.text, HORIZONTAL_ALIGNMENT_LEFT, help.size.x, help.get_theme_font_size("font_size"))
	expect(help_text_size.y <= help.size.y + 0.1, name + " full help text fits")
	expect(help.get_global_rect().end.y <= map.get_global_rect().end.y - float(map.get("_footer_height")) + 0.1, name + " help above status")
	states.append({"name": name, "viewport": [viewport.x, viewport.y], "sidebar": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "widest_child_right": widest, "map_right": map.get_global_rect().end.x})
	capture(name)

func run() -> void:
	await create_timer(2).timeout
	var map := Map.new()
	root.add_child(map)
	var long_name := "Большой городской магазин на центральной площади у старой станции"
	map.set_world({"bounds": {"minX": -120, "maxX": 120, "minZ": -90, "maxZ": 90}, "objects": [{"id": "long-shop", "name": long_name, "kind": "shop", "x": 80, "z": 40}, {"id": "bank", "name": "Банк", "kind": "bank", "x": -40, "z": -30}], "buildings": [{"kind": "shop", "x": 80, "z": 40, "radius": 10}]})
	map.update_state({"position": {"x": 0, "z": 0}, "yaw": 0.0})
	map.set_waypoint({"id": "long-shop", "name": long_name, "kind": "shop", "x": 80, "z": 40})
	map.set_route({"status": "ready", "points": [{"x": 0, "z": 0}, {"x": 0, "z": 40}, {"x": 80, "z": 40}]})
	var target: Variant = map.get_waypoint()
	var route: Variant = map.get_route()
	for dimensions: Vector2i in [Vector2i(640, 480), Vector2i(1100, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		map.set_expanded(true)
		var filters: Control = map.get("_filter_options")
		filters.visible = false
		await settle()
		measure(map, "places_" + str(dimensions.x))
		var places: Node = map.get("_places")
		expect(places.get_child_count() == 2, "long POI retained " + str(dimensions.x))
		var full_text_retained := false
		for button in places.get_children():
			full_text_retained = full_text_retained or button.text == long_name
		expect(full_text_retained, "long full text retained " + str(dimensions.x))
		filters.visible = true
		await settle()
		measure(map, "filters_" + str(dimensions.x))
		var boxes: Dictionary = map.get("_filter_checks")
		expect(boxes.size() == 27, "all filters retained " + str(dimensions.x))
		var civic: BaseButton = boxes["civic"]
		civic.grab_focus()
		var down := InputEventKey.new()
		down.keycode = KEY_SPACE
		down.pressed = true
		Input.parse_input_event(down)
		var up := InputEventKey.new()
		up.keycode = KEY_SPACE
		Input.parse_input_event(up)
		await settle()
		expect(not map.is_kind_enabled("civic"), "keyboard wrapped checkbox toggles " + str(dimensions.x))
		map.reset_filters()
		var filter_label: Label = civic.get_parent().get_child(1)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		filter_label.gui_input.emit(click)
		expect(not map.is_kind_enabled("civic") and civic.has_focus(), "wrapped filter name click toggles and focuses " + str(dimensions.x))
		map.reset_filters()
		map.set_kind_enabled("shop", false)
		await settle()
		expect(map.visible_pois().size() == 1, "long POI hides " + str(dimensions.x))
		expect(map.get_waypoint() == target and map.get_route() == route, "target/route unchanged " + str(dimensions.x))
		map.reset_filters()
		map.set_expanded(false)
		await settle()
		var surface: Control = map.get("_surface")
		expect(absf(surface.size.x - (190 if dimensions.x < 700 else 230)) < 0.1, "source collapsed canvas width " + str(dimensions.x))
		capture("small_" + str(dimensions.x))
	var result := {"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "states": states, "scope": "Native responsive component, actual Camera-free UI render; no city/performance acceptance"}
	if not receipt_path.is_empty():
		var file := FileAccess.open(receipt_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	map.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
