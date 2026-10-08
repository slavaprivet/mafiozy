extends Control
## Standalone provider-driven map. No roster, terrain scale or path planner.
const MapProjection = preload("res://addons/walk_minimap/map_projection.gd")
const WaypointState = preload("res://addons/walk_minimap/waypoint_state.gd")
signal waypoint_changed(value: Variant)
signal expanded_changed(value: bool)
const DRAW_INTERVAL_MS := 80
var auto_layout := true
var expanded := false
var zoom := 1.0
var center := Vector2.ZERO
var _position := {"x": 0.0, "z": 0.0}
var _yaw := 0.0
var _world: Dictionary = {}
var _objects: Array = []
var _actors: Array = []
var _vehicles: Array = []
var _trains: Array = []
var _waypoints = WaypointState.new()
var _draw_route: Variant = null
var _route_world_points := PackedVector2Array()
var _route_screen_points := PackedVector2Array()
var _route_path_builds := 0
var _train_markers: Array = []
var _position_provider := Callable()
var _bounds_provider := Callable()
var _objects_provider := Callable()
var _provider_at := -INF
var _last_draw_at := -INF
var _dirty := true
var _draw_requests := 0
var _draw_frames := 0
var _drag: Variant = null
var _prior_focus: WeakRef
var _surface: MapSurface
var _heading: Label
var _status: Label
var _toggle: Button
var _clear: Button
var _tools: HBoxContainer

class MapSurface extends Control:
	var map: Control
	func _draw() -> void:
		if is_instance_valid(map):
			map.draw_map(self)
	func _gui_input(event: InputEvent) -> void:
		if map.handle_map_event(event):
			accept_event()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_surface = MapSurface.new()
	_surface.map = self
	_surface.clip_contents = true
	_surface.focus_mode = Control.FOCUS_ALL
	add_child(_surface)
	_heading = Label.new()
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	_toggle = Button.new()
	_toggle.pressed.connect(func(): set_expanded(not expanded))
	add_child(_toggle)
	_clear = Button.new()
	_clear.text = "×"
	_clear.tooltip_text = "Убрать метку"
	_clear.pressed.connect(func(): set_waypoint(null))
	add_child(_clear)
	_tools = HBoxContainer.new()
	for item in [["+", "Приблизить", func(): zoom_by(1.4)], ["−", "Отдалить", func(): zoom_by(1.0 / 1.4)], ["Я", "Показать персонажа", focus_player], ["Весь мир", "Весь мир", fit]]:
		var button := Button.new()
		button.text = item[0]
		button.tooltip_text = item[1]
		button.pressed.connect(item[2])
		_tools.add_child(button)
	add_child(_tools)
	resized.connect(_layout_children)
	get_viewport().size_changed.connect(_layout_view)
	_layout_view()
	_layout_children()
	_request_draw(true)

func _exit_tree() -> void:
	_position_provider = Callable()
	_bounds_provider = Callable()
	_objects_provider = Callable()
	if is_instance_valid(_surface):
		_surface.map = null

func set_world(data: Dictionary) -> bool:
	var bounds: Variant = data.get("bounds", _world.get("bounds"))
	if not MapProjection.valid_bounds(bounds):
		return false
	_world.merge(data.duplicate(true), true)
	_world.bounds = bounds.duplicate()
	_objects = []
	for object in _world.get("buildings", []) + _world.get("objects", []):
		if MapProjection.valid_point(object):
			_objects.append(object)
	if expanded:
		fit()
	_dirty = true
	_request_draw(true)
	return true

func set_providers(position_provider: Callable, bounds_provider: Callable, objects_provider: Callable) -> bool:
	_position_provider = position_provider
	_bounds_provider = bounds_provider
	_objects_provider = objects_provider
	return refresh_world()

func refresh_world() -> bool:
	if not _bounds_provider.is_valid() or not _objects_provider.is_valid():
		return false
	var bounds: Variant = _bounds_provider.call()
	var objects: Variant = _objects_provider.call()
	if not objects is Array:
		return false
	return set_world({"bounds": bounds, "objects": objects})

func update_state(state: Dictionary = {}, now_ms := -1.0) -> void:
	var changed := false
	var train_snapshot_changed := false
	if MapProjection.valid_point(state.get("position")):
		if state.position.x != _position.x or state.position.z != _position.z:
			_position = {"x": state.position.x, "z": state.position.z}
			changed = true
	if MapProjection.finite_number(state.get("yaw")) and state.yaw != _yaw:
		_yaw = state.yaw
		changed = true
	for field in ["actors", "vehicles", "trains"]:
		if state.get(field) is Array:
			var values: Array = state[field]
			if field == "actors" and values != _actors:
				_actors = values.duplicate(true)
				changed = true
				train_snapshot_changed = true
			elif field == "vehicles" and values != _vehicles:
				_vehicles = values.duplicate(true)
				changed = true
			elif field == "trains" and values != _trains:
				_trains = values.duplicate(true)
				changed = true
				train_snapshot_changed = true
	if train_snapshot_changed:
		_train_markers = _trains.duplicate()
		for actor in _actors:
			if actor.get("kind") == "train":
				_train_markers.append(actor)
	_dirty = _dirty or changed
	if _dirty:
		_request_draw(false, now_ms)

func _process(_delta: float) -> void:
	if not visible:
		return
	var now := float(Time.get_ticks_msec())
	if _position_provider.is_valid() and now - _provider_at >= DRAW_INTERVAL_MS:
		_provider_at = now
		var state: Variant = _position_provider.call()
		if state is Dictionary:
			update_state(state, now)
	if _dirty:
		_request_draw(false, now)

func set_waypoint(value: Variant) -> Variant:
	if not _world.has("bounds"):
		return null
	var result: Variant = _waypoints.set_waypoint(value, _world.bounds)
	_draw_route = null
	_route_world_points.clear()
	_route_screen_points.clear()
	waypoint_changed.emit(result.duplicate(true) if result != null else null)
	_dirty = true
	_request_draw(true)
	return result

func get_waypoint() -> Variant:
	return _waypoints.get_waypoint()

func set_route(value: Variant) -> Variant:
	var result: Variant = _waypoints.set_route(value)
	if is_same(result, _draw_route):
		return result
	var next_points := PackedVector2Array()
	if result != null and result.status == "ready":
		for point in result.points:
			next_points.append(MapProjection.point(point))
	if next_points != _route_world_points:
		_route_world_points = next_points
		_route_screen_points.resize(next_points.size())
		_route_path_builds += 1
	_draw_route = result
	_dirty = true
	_request_draw(true)
	return result

func get_route() -> Variant:
	return _waypoints.get_route()

func waypoint_info() -> Variant:
	return _waypoints.info(_position, _yaw)

func set_expanded(value: bool) -> void:
	if value == expanded:
		return
	expanded = value
	_drag = null
	if expanded:
		_prior_focus = weakref(get_viewport().gui_get_focus_owner())
		fit()
		if is_instance_valid(_surface):
			_surface.grab_focus()
	else:
		if is_instance_valid(_surface):
			_surface.release_focus()
		var prior: Variant = _prior_focus.get_ref() if _prior_focus != null else null
		if is_instance_valid(prior) and prior is Control and not is_ancestor_of(prior):
			prior.grab_focus()
	_layout_view()
	_layout_children()
	expanded_changed.emit(expanded)
	_dirty = true
	_request_draw(true)

func set_visible_map(value: bool) -> void:
	if visible == value:
		return
	visible = value
	if value:
		_layout_view()
		_request_draw(true)

func fit() -> void:
	if not _world.has("bounds"):
		return
	var bounds: Dictionary = _world.bounds
	center = Vector2((bounds.minX + bounds.maxX) / 2.0, (bounds.minZ + bounds.maxZ) / 2.0)
	zoom = 1.0
	_dirty = true
	_request_draw(true)

func focus_player() -> void:
	center = MapProjection.point(_position)
	zoom = maxf(zoom, 3)
	_dirty = true
	_request_draw(true)

func get_projection() -> RefCounted:
	var dimensions := _surface.size if is_instance_valid(_surface) else Vector2(230, 194)
	var scale_m := 180.0 / maxf(1, dimensions.x)
	if expanded and _world.has("bounds"):
		var bounds: Dictionary = _world.bounds
		scale_m = maxf((bounds.maxX - bounds.minX) / dimensions.x, (bounds.maxZ - bounds.minZ) / dimensions.y) * 1.08 / zoom
	return MapProjection.new(center if expanded else MapProjection.point(_position), dimensions, scale_m)

func zoom_by(factor: float, anchor: Variant = null) -> void:
	var before: Variant = get_projection().to_world(anchor) if anchor is Vector2 else null
	zoom = clampf(zoom * factor, 0.6, 12)
	if before != null:
		center += before - get_projection().to_world(anchor)
	_dirty = true
	_request_draw(true)

func handle_map_event(event: InputEvent) -> bool:
	if not visible or not _world.has("bounds"):
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if get_projection().marker_hit(event.position, get_waypoint()):
				set_waypoint(null)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if expanded and event.pressed:
				zoom_by(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.position)
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag = {"start": event.position, "last": event.position, "moved": false}
				_surface.grab_focus()
			elif _drag != null:
				if not _drag.moved:
					var point: Vector2 = get_projection().to_world(event.position)
					set_waypoint({"x": point.x, "z": point.y})
				_drag = null
				if not expanded:
					_surface.release_focus()
			return true
	if event is InputEventMouseMotion:
		if _drag != null:
			var delta: Vector2 = event.position - _drag.last
			_drag.moved = _drag.moved or event.position.distance_to(_drag.start) > 5
			if expanded and _drag.moved:
				center -= delta * get_projection().metres_per_pixel
				_dirty = true
				_request_draw(true)
			_drag.last = event.position
		else:
			var object: Variant = get_projection().object_at(event.position, _objects)
			_surface.tooltip_text = str(object.name) if object != null else ""
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and handle_key_event(event):
		get_viewport().set_input_as_handled()

func handle_key_event(event: InputEventKey) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or not visible:
		return false
	var code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return expanded
	if code == KEY_M or (expanded and code == KEY_ESCAPE):
		if event.pressed and not event.echo:
			set_expanded(not expanded)
		return expanded or event.pressed
	if not expanded:
		return false
	if code == KEY_TAB:
		if event.pressed:
			_cycle_map_focus(event.shift_pressed)
		return true
	if focus is Button and is_ancestor_of(focus) and code in [KEY_ENTER, KEY_SPACE]:
		return false
	if event.pressed:
		if code in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			zoom_by(1.2)
		elif code in [KEY_MINUS, KEY_KP_SUBTRACT]:
			zoom_by(1.0 / 1.2)
		elif code == KEY_ENTER and focus == _surface:
			set_waypoint({"x": center.x, "z": center.y})
		elif code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var step: float = 50 * get_projection().metres_per_pixel
			center += Vector2(-step if code == KEY_LEFT else step if code == KEY_RIGHT else 0, -step if code == KEY_UP else step if code == KEY_DOWN else 0)
			_dirty = true
			_request_draw(true)
	return true

func _cycle_map_focus(backwards: bool) -> void:
	var controls: Array[Control] = []
	_collect_map_focus(self, controls)
	# Match Walk DOM order: header toggle, canvas, tools, then status clear.
	if controls.has(_toggle):
		controls.erase(_toggle)
		controls.push_front(_toggle)
	if controls.has(_clear):
		controls.erase(_clear)
		controls.append(_clear)
	if controls.is_empty():
		return
	var current := controls.find(get_viewport().gui_get_focus_owner())
	var next := (current + (-1 if backwards else 1) + controls.size()) % controls.size()
	if current < 0:
		next = controls.size() - 1 if backwards else 0
	controls[next].grab_focus()

func _collect_map_focus(parent: Node, controls: Array[Control]) -> void:
	for child in parent.get_children():
		if child is Control and child.is_visible_in_tree() and child.focus_mode != Control.FOCUS_NONE:
			if not child is BaseButton or not child.disabled:
				controls.append(child)
		_collect_map_focus(child, controls)

func draw_stats() -> Dictionary:
	return {"requests": _draw_requests, "frames": _draw_frames, "last_ms": _last_draw_at, "interval_ms": DRAW_INTERVAL_MS, "route_normalizations": _waypoints.normalizations, "route_distance_scans": _waypoints.distance_scans, "route_path_builds": _route_path_builds}

func _request_draw(force: bool, now_ms := -1.0) -> bool:
	if not is_instance_valid(_surface) or not visible:
		return false
	var now := float(Time.get_ticks_msec()) if now_ms < 0 else now_ms
	if not force and now - _last_draw_at < DRAW_INTERVAL_MS:
		return false
	_last_draw_at = now
	_dirty = false
	_draw_requests += 1
	_status.text = _waypoints.status_text(_position)
	_clear.visible = get_waypoint() != null
	_surface.queue_redraw()
	queue_redraw()
	return true

func _layout_view() -> void:
	if not auto_layout or not is_inside_tree():
		return
	var viewport := get_viewport_rect().size
	if expanded:
		position = viewport * 0.06
		size = viewport * 0.88
	else:
		size = Vector2(230, 266)
		position = viewport - size - Vector2(16, 16)

func _layout_children() -> void:
	if not is_instance_valid(_surface):
		return
	_surface.position = Vector2(0, 34)
	_surface.size = Vector2(maxf(40, size.x), maxf(40, size.y - 72))
	_heading.position = Vector2(10, 6)
	_heading.text = "Карта города" if expanded else "Окрестности"
	for region in _world.get("districts", []) + _world.get("regions", []):
		if not expanded and region.get("name", "") and MapProjection.point_in_polygon(MapProjection.point(_position), region.get("polygon", region.get("points", []))):
			_heading.text = region.name
			break
	_toggle.text = "Закрыть ×" if expanded else "M ↗"
	_toggle.position = Vector2(size.x - 100 if expanded else size.x - 64, 2)
	_toggle.size = Vector2(98 if expanded else 62, 30)
	_status.position = Vector2(10, size.y - 33)
	_status.size = Vector2(maxf(40, size.x - 52), 28)
	_clear.position = Vector2(size.x - 32, size.y - 33)
	_clear.size = Vector2(28, 28)
	_tools.visible = expanded
	_tools.position = Vector2(maxf(0, size.x - 255), 40)
	_dirty = true
	_request_draw(true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("152c2e"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("bba46d"), false, 1)

func draw_map(canvas: Control) -> void:
	_draw_frames += 1
	var projection = get_projection()
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("1c3639"))
	if not _world.has("bounds"):
		return
	var bounds: Dictionary = _world.bounds
	var top_left: Vector2 = projection.to_screen(Vector2(bounds.minX, bounds.minZ))
	var bottom_right: Vector2 = projection.to_screen(Vector2(bounds.maxX, bounds.maxZ))
	canvas.draw_rect(Rect2(top_left, bottom_right - top_left), Color("61745b"))
	for region in _world.get("regions", []) + _world.get("water", []):
		_draw_polygon(canvas, region.get("polygon", region.get("points", [])), projection, Color(region.get("color", "376f78" if region.get("kind") == "water" else "41614b")))
	for field in ["roads", "trails", "railways"]:
		for line in _world.get(field, []):
			var points := MapProjection.polygon_points(line.get("points", line.get("polygon", [])))
			if points.size() < 2:
				continue
			var screen := PackedVector2Array()
			for point in points:
				screen.append(projection.to_screen(point))
			canvas.draw_polyline(screen, Color("b3ac8f" if field == "roads" else "d2bd8a" if field == "trails" else "514e43"), maxf(1, float(line.get("width", 2)) / projection.metres_per_pixel), true)
	for object in _objects:
		var color := _object_color(str(object.get("kind", "object")))
		_draw_polygon(canvas, object.get("polygon", []), projection, color)
		var at: Vector2 = projection.to_screen(MapProjection.point(object))
		if Rect2(Vector2.ZERO, canvas.size).grow(12).has_point(at):
			canvas.draw_circle(at, 4, color)
			if expanded and object.get("name", ""):
				canvas.draw_string(ThemeDB.fallback_font, at + Vector2(8, -6), str(object.name), HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color("e7e0cf"))
	var route: Variant = _draw_route
	if route != null and route.status == "ready" and _route_world_points.size() >= 2:
		for i in _route_world_points.size():
			_route_screen_points[i] = projection.to_screen(_route_world_points[i])
		canvas.draw_polyline(_route_screen_points, Color("493b24"), 5, true)
		canvas.draw_polyline(_route_screen_points, Color("f0c771"), 3, true)
	var target: Variant = get_waypoint()
	if target != null:
		if route == null:
			# Bearing indicator only; never returned as a navigable road route.
			canvas.draw_dashed_line(projection.to_screen(MapProjection.point(_position)), projection.to_screen(MapProjection.point(target)), Color("f0c771"), 1.5, 5)
		var marker: Vector2 = projection.marker_position(target)
		canvas.draw_circle(marker, 7, Color("f3ca73"))
		canvas.draw_circle(marker, 3, Color("213739"))
	for own_squad in [false, true]:
		for actor in _actors:
			if (actor.get("ownSquad", false) == true) != own_squad or actor.get("hidden", false) or actor.get("active", true) == false or actor.get("kind") == "train":
				continue
			var location: Variant = actor.get("position", actor)
			if MapProjection.valid_point(location):
				var at: Vector2 = projection.to_screen(MapProjection.point(location))
				if Rect2(Vector2(3, 3), canvas.size - Vector2(6, 6)).has_point(at):
					canvas.draw_circle(at, 5.4 if own_squad else 4.0 if actor.get("kind") == "boss" else 2.6, Color("32ed69" if own_squad else "7ec0ee" if actor.get("kind") == "police" else "cf746c" if actor.get("kind") == "boss" else "dfdab5"))
	for vehicle in _vehicles:
		_draw_vehicle(canvas, projection, vehicle, false)
	var seen: Dictionary = {}
	for train in _train_markers:
		var location: Variant = train.get("position", train)
		if not MapProjection.valid_point(location):
			continue
		if train.get("hidden", false) or train.get("active", true) == false or (train.get("id") and seen.has(train.id)):
			continue
		if train.get("id"):
			seen[train.id] = true
		_draw_vehicle(canvas, projection, train, true)
	var player: Vector2 = projection.to_screen(MapProjection.point(_position)).clamp(Vector2(9, 9), canvas.size - Vector2(9, 9))
	canvas.draw_set_transform(player, -_yaw)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 9), Vector2(-6, -6), Vector2(0, -3), Vector2(6, -6)]), Color("e8fcf3"))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(10, 18), "↑ СЕВЕР", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2dec2"))
	var scale_m := 200 if projection.metres_per_pixel > 3 else 100 if projection.metres_per_pixel > 1 else 50
	var pixels: float = minf(canvas.size.x * 0.4, scale_m / projection.metres_per_pixel)
	canvas.draw_line(Vector2(12, canvas.size.y - 8), Vector2(12 + pixels, canvas.size.y - 8), Color("ead8b3"), 2)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(12, canvas.size.y - 12), "%d м" % floori(minf(canvas.size.x * 0.4 * projection.metres_per_pixel, scale_m) + 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ead8b3"))
	_layout_heading()

func _layout_heading() -> void:
	_heading.text = "Карта города" if expanded else "Окрестности"
	if expanded:
		return
	for region in _world.get("districts", []) + _world.get("regions", []):
		if region.get("name", "") and MapProjection.point_in_polygon(MapProjection.point(_position), region.get("polygon", region.get("points", []))):
			_heading.text = region.name
			return

func _draw_polygon(canvas: Control, points: Array, projection: RefCounted, color: Color) -> void:
	var vertices := MapProjection.polygon_points(points)
	if vertices.size() < 3:
		return
	for i in vertices.size():
		vertices[i] = projection.to_screen(vertices[i])
	canvas.draw_colored_polygon(vertices, color)

func _draw_vehicle(canvas: Control, projection: RefCounted, value: Dictionary, train: bool) -> void:
	var location: Variant = value.get("position", value)
	if not MapProjection.valid_point(location):
		return
	canvas.draw_set_transform(projection.to_screen(MapProjection.point(location)), -float(value.get("yaw", 0)))
	canvas.draw_rect(Rect2(Vector2(-4, -8) if train else Vector2(-3, -5), Vector2(8, 16) if train else Vector2(6, 10)), Color("c8885c") if train else vehicle_color(value))
	canvas.draw_rect(Rect2(Vector2(-2, 1), Vector2(4, 2)), Color("bfe4df"))
	canvas.draw_set_transform(Vector2.ZERO)

static func vehicle_color(vehicle: Dictionary) -> Color:
	var value: Variant = vehicle.get("color", vehicle.get("skinColor"))
	if value is int and value >= 0 and value <= 0xffffff:
		return Color("#%06x" % value)
	if value is String and value.begins_with("#") and value.length() in [4, 7] and value.substr(1).is_valid_hex_number(false):
		return Color(value)
	return Color("f2c48a")

static func _object_color(kind: String) -> Color:
	return Color({"bank": "bd9c59", "police": "70a0b0", "hospital": "d9ece1", "shop": "c8ae83", "gunshop": "bb957d", "tree": "426958", "forest": "6e8d68", "water": "69afb5", "mountain": "baa88a", "station": "f0c77d", "parking": "76a4c1"}.get(kind, "c9bea7"))
