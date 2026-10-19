extends Control
## Standalone provider-driven map. No roster, terrain scale or path planner.
const MapProjection = preload("res://addons/walk_minimap/map_projection.gd")
const WaypointState = preload("res://addons/walk_minimap/waypoint_state.gd")
const Catalog = preload("res://addons/walk_minimap/map_catalog.gd")
const ObjectIndex = preload("res://addons/walk_minimap/map_object_index.gd")
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
var _objects_snapshot_ready := false
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
var _sidebar: ScrollContainer
var _sidebar_title_row: BoxContainer
var _sidebar_margin: MarginContainer
var _places: VBoxContainer
var _legend: GridContainer
var _object_count: Label
var _filter_options: VBoxContainer
var _filter_checks: Dictionary = {}
var _help: Label
var _object_index = ObjectIndex.new()
var _pois: Array = []
var _poi_buttons_rebuilt := 0
var _world_atlas: SubViewport
var _atlas_surface: MapSurface
var _atlas_center := Vector2.ZERO
var _atlas_mpp := -1.0
var _atlas_dimensions := Vector2.ZERO
var _atlas_rebuilds := 0
var _atlas_valid := false
var _background: StyleBoxFlat
var _tooltip: Label
var _hover_pointer := Vector2.ZERO
var _hover_objects: Array = []
var _strong_font: SystemFont
var _footer_height := 40.0
var _help_height := 34.0
var _last_status_text := ""

class MapSurface extends Control:
	var map: Control
	var atlas := false
	func _draw() -> void:
		if is_instance_valid(map):
			if atlas:
				map.draw_base(self, MapProjection.new(map._atlas_center, size, map._atlas_mpp))
			else:
				map.draw_map(self)
	func _gui_input(event: InputEvent) -> void:
		if map.handle_map_event(event):
			accept_event()

class LegendGlyph extends Control:
	var kind := "object"
	func _draw() -> void:
		if kind in Catalog.BUILDING_MAP_KINDS:
			draw_rect(Rect2(Vector2.ZERO, Vector2(18, 18)), Catalog.kind_color(kind))
			Catalog.draw_building_icon(self, kind, Vector2(9, 9), 13)
		else:
			draw_rect(Rect2(Vector2(5, 5), Vector2(8, 8)), Catalog.kind_color(kind))

func _ready() -> void:
	_setup_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_surface = MapSurface.new()
	_surface.map = self
	_surface.clip_contents = true
	_surface.focus_mode = Control.FOCUS_ALL
	add_child(_surface)
	_surface.mouse_exited.connect(func(): _tooltip.visible = false if is_instance_valid(_tooltip) else false)
	_heading = Label.new()
	var heading_font := FontVariation.new()
	heading_font.base_font = _strong_font
	heading_font.spacing_glyph = 2
	_heading.add_theme_font_override("font", heading_font)
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_toggle = Button.new()
	_button_padding(_toggle, 3, 7)
	_toggle.pressed.connect(func(): set_expanded(not expanded))
	add_child(_toggle)
	_clear = Button.new()
	_button_padding(_clear, 2, 6)
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
	_build_sidebar()
	_help = Label.new()
	_help.text = "Нажмите на место, чтобы поставить метку · ПКМ по метке — убрать · Колесо — масштаб · Перетащите карту · M / Esc — закрыть"
	_help.add_theme_font_size_override("font_size", 11)
	_help.add_theme_color_override("font_color", Color("b7c5bd"))
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_help)
	_tooltip = Label.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip.add_theme_color_override("font_color", Color("f5e9cb"))
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color("102d30ee")
	tooltip_style.border_color = Color("c5b17b")
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_corner_radius_all(5)
	tooltip_style.set_content_margin_all(6)
	_tooltip.add_theme_stylebox_override("normal", tooltip_style)
	_surface.add_child(_tooltip)
	_world_atlas = SubViewport.new()
	_world_atlas.transparent_bg = false
	_world_atlas.disable_3d = true
	_world_atlas.gui_disable_input = true
	_world_atlas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_world_atlas)
	_atlas_surface = MapSurface.new()
	_atlas_surface.map = self
	_atlas_surface.atlas = true
	_atlas_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_atlas.add_child(_atlas_surface)
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
	if is_instance_valid(_atlas_surface):
		_atlas_surface.map = null

func set_world(data: Dictionary) -> bool:
	var bounds: Variant = data.get("bounds", _world.get("bounds"))
	if not MapProjection.valid_bounds(bounds):
		return false
	_world.merge(data.duplicate(true), true)
	_world.bounds = bounds.duplicate()
	var previous_objects: Array = _objects
	_objects = []
	for object in _world.get("buildings", []) + _world.get("objects", []):
		if MapProjection.valid_point(object):
			_objects.append(object)
	if not _objects_snapshot_ready or _objects != previous_objects:
		_object_index.configure(_objects)
		_rebuild_places()
		_objects_snapshot_ready = true
	_atlas_valid = false
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
	if is_instance_valid(_tooltip):
		_tooltip.visible = false
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
	if is_instance_valid(_tooltip):
		_tooltip.visible = false
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
			_hover_pointer = event.position
			_update_hover()
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
			var controls: Array[Control] = [_toggle, _surface]
			_collect_focusable(_tools, controls)
			_collect_focusable(_sidebar, controls)
			if _clear.is_visible_in_tree():
				controls.append(_clear)
			var index := controls.find(focus)
			controls[posmod(index + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
		return event.pressed
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

func draw_stats() -> Dictionary:
	return {"requests": _draw_requests, "frames": _draw_frames, "last_ms": _last_draw_at, "interval_ms": DRAW_INTERVAL_MS, "route_normalizations": _waypoints.normalizations, "route_distance_scans": _waypoints.distance_scans, "route_path_builds": _route_path_builds, "atlas_rebuilds": _atlas_rebuilds, "poi_rebuilds": _poi_buttons_rebuilt, "object_index": _object_index.stats()}

func _request_draw(force: bool, now_ms := -1.0) -> bool:
	if not is_instance_valid(_surface) or not visible:
		return false
	var now := float(Time.get_ticks_msec()) if now_ms < 0 else now_ms
	if not force and now - _last_draw_at < DRAW_INTERVAL_MS:
		return false
	_last_draw_at = now
	_dirty = false
	_draw_requests += 1
	var message: String = _waypoints.status_text(_position)
	if message != _last_status_text:
		_last_status_text = message
		_status.text = message
		var horizontal_padding := 30.0 if expanded else 20.0
		var width: float = maxf(40, size.x - horizontal_padding - (29 if get_waypoint() != null else 0))
		var text_size: Vector2 = _status.get_theme_default_font().get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, width, 12)
		var footer: float = maxf(42 if expanded else 40, ceilf(text_size.y) + (19 if expanded else 17))
		if footer != _footer_height:
			_footer_height = footer
			_layout_view()
			_layout_children()
	_clear.visible = get_waypoint() != null
	_status.size.x = maxf(40, size.x - (30 if expanded else 20) - (29 if _clear.visible else 0))
	_update_atlas()
	_surface.queue_redraw()
	queue_redraw()
	return true

func _layout_view() -> void:
	if not auto_layout or not is_inside_tree():
		return
	var viewport := get_viewport_rect().size
	if expanded:
		position = viewport * (0.03 if viewport.x < 700 else 0.06)
		size = viewport * (0.94 if viewport.x < 700 else 0.88)
	else:
		size = Vector2(192, 194 + _footer_height) if viewport.x < 700 else Vector2(232, 238 + _footer_height)
		position = viewport - size - (Vector2(8, 10) if viewport.x < 700 else Vector2(16, 16))

func _layout_children() -> void:
	if not is_instance_valid(_surface):
		return
	var sidebar_width := 135.0 if get_viewport_rect().size.x < 700 else 210.0
	_sidebar_title_row.vertical = get_viewport_rect().size.x < 700
	for side in ["left", "right", "top", "bottom"]:
		_sidebar_margin.add_theme_constant_override("margin_" + side, 8 if get_viewport_rect().size.x < 700 else 12)
	var help_font_size := 10 if get_viewport_rect().size.x < 700 else 11
	_help.add_theme_font_size_override("font_size", help_font_size)
	var help_text_size: Vector2 = _help.get_theme_default_font().get_multiline_string_size(_help.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(40, size.x - 28), help_font_size)
	_help_height = maxf(34, ceilf(help_text_size.y) + 18)
	var header_height := 54.0 if expanded else 44.0
	_surface.position = Vector2(1, header_height)
	_surface.size = Vector2(maxf(40, size.x - 2 - sidebar_width if expanded else size.x - 2), maxf(40, size.y - header_height - _help_height - _footer_height if expanded else size.y - 44 - _footer_height))
	_heading.position = Vector2(18, 14) if expanded else Vector2(10, 9)
	_heading.add_theme_font_size_override("font_size", 15 if expanded else 11)
	_heading.text = "КАРТА ГОРОДА" if expanded else "ОКРЕСТНОСТИ"
	for region in _world.get("districts", []) + _world.get("regions", []):
		if not expanded and region.get("name", "") and MapProjection.point_in_polygon(MapProjection.point(_position), region.get("polygon", region.get("points", []))):
			_heading.text = str(region.name).to_upper()
			break
	_toggle.text = "Закрыть ×" if expanded else "M ↗"
	_toggle.position = Vector2(size.x - 111 if expanded else size.x - 60, 11 if expanded else 4)
	_toggle.size = Vector2(93 if expanded else 50, 26)
	_status.position = Vector2(15 if expanded else 10, size.y - _footer_height + (9 if expanded else 8))
	_status.size = Vector2(maxf(40, size.x - (30 if expanded else 20) - (29 if get_waypoint() != null else 0)), _footer_height - (18 if expanded else 16))
	_clear.position = Vector2(size.x - (15 if expanded else 10) - 22, size.y - _footer_height + (_footer_height - 22) / 2)
	_clear.size = Vector2(22, 22)
	_tools.visible = expanded
	_tools.position = _surface.position + Vector2(maxf(0, _surface.size.x - 247), 12)
	_sidebar.visible = expanded
	_sidebar.position = Vector2(_surface.size.x + 1, header_height)
	_sidebar.size = Vector2(sidebar_width, _surface.size.y)
	_legend.columns = 1 if get_viewport_rect().size.x < 700 else 2
	_help.visible = expanded
	_help.position = Vector2(14, size.y - _footer_height - _help_height + 9)
	_help.size = Vector2(size.x - 28, _help_height - 18)
	_background.set_corner_radius_all(18 if expanded else 14)
	_background.bg_color = Color("142d30fa" if expanded else "152c2eed")
	_atlas_valid = false
	_dirty = true
	_last_status_text = ""
	_request_draw(true)

func _draw() -> void:
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(0, _surface.position.y - 1), Vector2(size.x, _surface.position.y - 1), Color("bba46d44"), 1)
	draw_line(Vector2(0, size.y - _footer_height), Vector2(size.x, size.y - _footer_height), Color("bba46d44"), 1)
	if expanded:
		draw_line(Vector2(_surface.size.x + 1, _surface.position.y), Vector2(_surface.size.x + 1, _surface.position.y + _surface.size.y), Color("bba46d44"), 1)

func draw_map(canvas: Control) -> void:
	_draw_frames += 1
	var projection = get_projection()
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("1c3639"))
	if not _world.has("bounds"):
		return
	if _atlas_valid and is_instance_valid(_world_atlas):
		var shift: Vector2 = (_atlas_center - projection.center) / projection.metres_per_pixel - Vector2(64, 64)
		canvas.draw_texture(_world_atlas.get_texture(), shift)
	var route: Variant = _draw_route
	if route != null and route.status == "ready" and _route_world_points.size() >= 2:
		for i in _route_world_points.size():
			_route_screen_points[i] = projection.to_screen(_route_world_points[i])
		canvas.draw_polyline(_route_screen_points, Color("493b24"), 5, true)
		canvas.draw_polyline(_route_screen_points, Color("f0c771"), 3, true)
	_draw_dynamic(canvas, projection)

func draw_base(canvas: Control, projection: RefCounted) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("1c3639"))
	if not _world.has("bounds"):
		return
	var bounds: Dictionary = _world.bounds
	var top_left: Vector2 = projection.to_screen(Vector2(bounds.minX, bounds.minZ))
	var bottom_right: Vector2 = projection.to_screen(Vector2(bounds.maxX, bounds.maxZ))
	canvas.draw_rect(Rect2(top_left, bottom_right - top_left), Color("61745b"))
	for region in _world.get("regions", []):
		_draw_polygon(canvas, region.get("polygon", region.get("points", [])), projection, Color(region.get("color", "847d65" if region.get("kind") == "mountain" else "41614b")))
	_draw_grid(canvas, projection)
	for water in _world.get("water", []):
		var points := MapProjection.polygon_points(water.get("polygon", water.get("points", [])))
		if points.size() >= 3:
			for i in points.size():
				points[i] = projection.to_screen(points[i])
			canvas.draw_colored_polygon(points, Color("376f78"))
			points.append(points[0])
			canvas.draw_polyline(points, Color("82b2ab"), 1.5, true)
	for field in ["roads", "trails", "railways"]:
		for line in _world.get(field, []):
			var points := MapProjection.polygon_points(line.get("points", line.get("polygon", [])))
			if points.size() < 2:
				continue
			var screen := PackedVector2Array()
			for point in points:
				screen.append(projection.to_screen(point))
			var width_m: float = float(line.get("width", 2.2 if field == "railways" else 2))
			if field == "trails":
				_draw_dashed_polyline(canvas, screen, Color("d2bd8a"), maxf(1, width_m / projection.metres_per_pixel), [4.0, 3.0])
			elif field == "railways":
				var rail_width: float = maxf(2.5, width_m / projection.metres_per_pixel)
				_draw_dashed_polyline(canvas, screen, Color("433f35"), rail_width + 3, [1.3, 4.0])
				canvas.draw_polyline(screen, Color("433f35"), rail_width, true)
				canvas.draw_polyline(screen, Color("c3b598"), maxf(1, rail_width - 1.7), true)
			else:
				canvas.draw_polyline(screen, Color("b3ac8f"), maxf(1, width_m / projection.metres_per_pixel), true)
	var lo: Vector2 = projection.to_world(Vector2.ZERO)
	var hi: Vector2 = projection.to_world(canvas.size)
	var query := {"minX": lo.x, "maxX": hi.x, "minZ": lo.y, "maxZ": hi.y}
	var draw_objects: Array = _object_index.query(query)
	for object in draw_objects:
		var color := _object_color(str(object.get("kind", "object")))
		var vertices := MapProjection.polygon_points(object.get("polygon", []))
		if vertices.size() >= 3 and object.get("kind") != "tree":
			for i in vertices.size():
				vertices[i] = projection.to_screen(vertices[i])
			canvas.draw_colored_polygon(vertices, color)
			if object.get("building", false) or object.get("kind") in Catalog.BUILDING_MAP_KINDS:
				vertices.append(vertices[0])
				canvas.draw_polyline(vertices, Color("615e51"), 0.85, true)
		elif is_kind_enabled(str(object.get("kind", "object"))):
			canvas.draw_circle(projection.to_screen(MapProjection.point(object)), maxf(0.7, float(object.get("radius", 1)) / projection.metres_per_pixel), color)
	var detail: bool = projection.metres_per_pixel < 1.1
	for object in draw_objects:
		if not is_kind_enabled(str(object.get("kind", "object"))):
			continue
		var at: Vector2 = projection.to_screen(MapProjection.point(object))
		if not Rect2(Vector2.ZERO, canvas.size).grow(12).has_point(at):
			continue
		var kind: String = str(object.get("kind", "object"))
		if kind in Catalog.BUILDING_MAP_KINDS:
			var icon_size := 13.0 if detail else 10.0
			_draw_marker(canvas, at, Catalog.kind_color(kind), icon_size * 0.7)
			Catalog.draw_building_icon(canvas, kind, at, icon_size)
		else:
			var symbol: String = str(Catalog.KINDS.get(kind, Catalog.KINDS.object).symbol)
			if symbol and (kind != "water" or expanded):
				_draw_marker(canvas, at, Catalog.kind_color(kind), 4)
				if detail:
					canvas.draw_string(canvas.get_theme_default_font(), at + Vector2(-3, 3), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("122c30"))

func _draw_dynamic(canvas: Control, projection: RefCounted) -> void:
	var route: Variant = _draw_route
	var target: Variant = get_waypoint()
	if target != null:
		if route == null:
			# Bearing indicator only; never returned as a navigable road route.
			canvas.draw_dashed_line(projection.to_screen(MapProjection.point(_position)), projection.to_screen(MapProjection.point(target)), Color("f0c771"), 1.5, 5)
		var marker: Vector2 = projection.marker_position(target)
		_draw_marker(canvas, marker, Color("f3ca73"), 7)
		canvas.draw_string(canvas.get_theme_default_font(), marker + Vector2(-4, 4), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("213739"))
	for own_squad in [false, true]:
		for actor in _actors:
			if (actor.get("ownSquad", false) == true) != own_squad or actor.get("hidden", false) or actor.get("active", true) == false or actor.get("kind") == "train":
				continue
			var location: Variant = actor.get("position", actor)
			if MapProjection.valid_point(location):
				var at: Vector2 = projection.to_screen(MapProjection.point(location))
				if Rect2(Vector2(3, 3), canvas.size - Vector2(6, 6)).has_point(at):
					_draw_marker(canvas, at, Color("32ed69" if own_squad else "7ec0ee" if actor.get("kind") == "police" else "cf746c" if actor.get("kind") == "boss" else "dfdab5"), 5.4 if own_squad else 4.0 if actor.get("kind") == "boss" else 2.6)
	for vehicle in _vehicles:
		_draw_vehicle(canvas, projection, vehicle, false)
	var seen: Dictionary = {}
	for train in _train_markers:
		var location: Variant = train.get("position", train)
		if not MapProjection.valid_point(location) or train.get("hidden", false) or train.get("active", true) == false or (train.get("id") and seen.has(train.id)):
			continue
		if train.get("id"):
			seen[train.id] = true
		_draw_vehicle(canvas, projection, train, true)
	var player: Vector2 = projection.to_screen(MapProjection.point(_position)).clamp(Vector2(9, 9), canvas.size - Vector2(9, 9))
	canvas.draw_set_transform(player, -_yaw)
	var arrow := PackedVector2Array([Vector2(0, 9), Vector2(-6, -6), Vector2(0, -3), Vector2(6, -6)])
	canvas.draw_colored_polygon(arrow, Color("e8fcf3"))
	arrow.append(arrow[0])
	canvas.draw_polyline(arrow, Color("133c3b"), 2, true)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_string(canvas.get_theme_default_font(), Vector2(10, 16), "↑ СЕВЕР", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f2dec2"))
	var scale_m := 200 if projection.metres_per_pixel > 3 else 100 if projection.metres_per_pixel > 1 else 50
	var pixels: float = minf(canvas.size.x * 0.4, scale_m / projection.metres_per_pixel)
	canvas.draw_line(Vector2(12, canvas.size.y - 8), Vector2(12 + pixels, canvas.size.y - 8), Color("ead8b3"), 2)
	canvas.draw_string(canvas.get_theme_default_font(), Vector2(12, canvas.size.y - 12), "%d м" % floori(minf(canvas.size.x * 0.4 * projection.metres_per_pixel, scale_m) + 0.5), HORIZONTAL_ALIGNMENT_CENTER, pixels, 9, Color("ead8b3"))
	if _surface.has_focus():
		canvas.draw_rect(Rect2(Vector2(2, 2), canvas.size - Vector2(4, 4)), Color("e5c57b"), false, 2)
	_layout_heading()

func _layout_heading() -> void:
	_heading.text = "КАРТА ГОРОДА" if expanded else "ОКРЕСТНОСТИ"
	if expanded:
		return
	for region in _world.get("districts", []) + _world.get("regions", []):
		if region.get("name", "") and MapProjection.point_in_polygon(MapProjection.point(_position), region.get("polygon", region.get("points", []))):
			_heading.text = str(region.name).to_upper()
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
	var at: Vector2 = projection.to_screen(MapProjection.point(location))
	if train and not Rect2(Vector2.ZERO, canvas.size).grow(10).has_point(at):
		return
	canvas.draw_set_transform(at, -float(value.get("yaw", 0)))
	var body := Rect2(Vector2(-4, -8) if train else Vector2(-3, -5), Vector2(8, 16) if train else Vector2(6, 10))
	canvas.draw_rect(body, Color("c8885c") if train else vehicle_color(value))
	canvas.draw_rect(body, Color("263b3e"), false, 2 if train else 1)
	if train:
		canvas.draw_rect(Rect2(Vector2(-2, 3), Vector2(4, 3)), Color("fff0c3"))
		canvas.draw_rect(Rect2(Vector2(-2, -6), Vector2(4, 5)), Color("4a5553"))
	else:
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
	return Catalog.kind_color(kind)

func _draw_marker(canvas: Control, at: Vector2, color: Color, radius: float) -> void:
	canvas.draw_circle(at, radius, color)
	canvas.draw_arc(at, radius, 0, TAU, 24, Color("142d30"), 2, true)

func _update_atlas() -> void:
	if not is_instance_valid(_world_atlas) or not _world.has("bounds"):
		return
	var projection = get_projection()
	var shift: Vector2 = Vector2(absf(_atlas_center.x - projection.center.x), absf(_atlas_center.y - projection.center.y)) / projection.metres_per_pixel
	if _atlas_valid and _atlas_dimensions == projection.viewport_size and absf(_atlas_mpp - projection.metres_per_pixel) < 1e-8 and shift.x <= 56 and shift.y <= 56:
		return
	_atlas_center = projection.center
	_atlas_mpp = projection.metres_per_pixel
	_atlas_dimensions = projection.viewport_size
	_world_atlas.size = Vector2i(projection.viewport_size.ceil()) + Vector2i(128, 128)
	_atlas_surface.size = Vector2(_world_atlas.size)
	_atlas_surface.queue_redraw()
	_world_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	_atlas_rebuilds += 1
	_atlas_valid = true

func _draw_grid(canvas: Control, projection: RefCounted) -> void:
	var grid: Variant = _world.get("grid")
	var cell_size: Variant = _world.get("cellSize")
	if not grid is Array or not MapProjection.finite_number(cell_size) or cell_size <= 0:
		return
	var lo: Vector2 = projection.to_world(Vector2.ZERO)
	var hi: Vector2 = projection.to_world(canvas.size)
	var colors := {0: "8e9180", 8: "718366", 9: "a9ad96", 14: "c7b98f", 16: "376b71", 19: "b59a75"}
	for row in range(maxi(0, floori(lo.y / cell_size)), mini(grid.size(), ceili(hi.y / cell_size))):
		if not grid[row] is Array:
			continue
		for column in range(maxi(0, floori(lo.x / cell_size)), mini(grid[row].size(), ceili(hi.x / cell_size))):
			var at: Vector2 = projection.to_screen(Vector2(column, row) * cell_size)
			canvas.draw_rect(Rect2(at, Vector2.ONE * (cell_size / projection.metres_per_pixel + 0.6)), Color(colors.get(grid[row][column], "718366")))

func _draw_dashed_polyline(canvas: Control, points: PackedVector2Array, color: Color, width: float, pattern: Array) -> void:
	var phase := 0
	var remaining: float = pattern[0]
	for i in range(1, points.size()):
		var offset := 0.0
		var distance := points[i - 1].distance_to(points[i])
		while offset < distance:
			var step: float = minf(remaining, distance - offset)
			if phase % 2 == 0:
				canvas.draw_line(points[i - 1].lerp(points[i], offset / distance), points[i - 1].lerp(points[i], (offset + step) / distance), color, width, true)
			offset += step
			remaining -= step
			if remaining <= 0.00001:
				phase = (phase + 1) % pattern.size()
				remaining = pattern[phase]

func _setup_theme() -> void:
	var map_theme := Theme.new()
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	map_theme.default_font = system_font
	_strong_font = SystemFont.new()
	_strong_font.font_names = system_font.font_names
	_strong_font.font_weight = 700
	map_theme.default_font_size = 12
	map_theme.set_color("font_color", "Label", Color("e7e0cf"))
	map_theme.set_color("font_color", "Button", Color("e7e0cf"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3c5658" if state == "hover" else "284044")
		style.border_color = Color("e5c57b" if state == "focus" else "bba46d55")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		map_theme.set_stylebox(state, "Button", style)
		map_theme.set_stylebox(state, "CheckBox", style)
	theme = map_theme
	_background = StyleBoxFlat.new()
	_background.bg_color = Color("152c2eed")
	_background.border_color = Color("bba46d88")
	_background.set_border_width_all(1)
	_background.set_corner_radius_all(14)
	_background.shadow_color = Color("00000055")
	_background.shadow_size = 12
	_background.shadow_offset = Vector2(0, 7)

func _button_padding(button: Button, vertical: float, horizontal: float) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = get_theme_stylebox(state, "Button").duplicate()
		style.content_margin_top = vertical
		style.content_margin_bottom = vertical
		style.content_margin_left = horizontal
		style.content_margin_right = horizontal
		button.add_theme_stylebox_override(state, style)

func _build_sidebar() -> void:
	_sidebar = ScrollContainer.new()
	_sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_sidebar)
	_sidebar_margin = MarginContainer.new()
	_sidebar_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		_sidebar_margin.add_theme_constant_override("margin_" + side, 12)
	_sidebar.add_child(_sidebar_margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	_sidebar_margin.add_child(contents)
	_sidebar_title_row = BoxContainer.new()
	_sidebar_title_row.vertical = get_viewport_rect().size.x < 700
	_sidebar_title_row.add_theme_constant_override("separation", 4)
	contents.add_child(_sidebar_title_row)
	var title := Label.new()
	title.text = "Места на карте"
	title.add_theme_font_override("font", _strong_font)
	title.add_theme_color_override("font_color", Color("d9c593"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_title_row.add_child(title)
	_places = VBoxContainer.new()
	_places.add_theme_constant_override("separation", 5)
	contents.add_child(_places)
	_legend = GridContainer.new()
	_legend.columns = 2
	_legend.add_theme_constant_override("h_separation", 7)
	_legend.add_theme_constant_override("v_separation", 7)
	contents.add_child(_legend)
	for kind: String in Catalog.KINDS:
		if kind in ["object", "lamp"]:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 18)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 3)
		var icon := LegendGlyph.new()
		icon.kind = kind
		icon.custom_minimum_size = Vector2(18, 18)
		row.add_child(icon)
		var label := Label.new()
		label.text = Catalog.kind_name(kind)
		label.add_theme_font_size_override("font_size", 10)
		label.custom_minimum_size = Vector2(0, 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		_legend.add_child(row)
	_object_count = Label.new()
	_object_count.add_theme_font_size_override("font_size", 10)
	_object_count.add_theme_color_override("font_color", Color("aabbaf"))
	_object_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(_object_count)
	var filter_toggle := Button.new()
	filter_toggle.text = "Фильтры"
	filter_toggle.tooltip_text = "Показать категории объектов"
	filter_toggle.add_theme_font_size_override("font_size", 10)
	var filter_button_style: StyleBoxFlat = get_theme_stylebox("normal", "Button").duplicate()
	filter_button_style.content_margin_left = 4
	filter_button_style.content_margin_right = 4
	filter_button_style.content_margin_top = 2
	filter_button_style.content_margin_bottom = 2
	filter_toggle.add_theme_stylebox_override("normal", filter_button_style)
	filter_toggle.add_theme_stylebox_override("pressed", filter_button_style)
	filter_toggle.add_theme_stylebox_override("hover", filter_button_style)
	filter_toggle.toggle_mode = true
	_sidebar_title_row.add_child(filter_toggle)
	_filter_options = VBoxContainer.new()
	_filter_options.visible = false
	contents.add_child(_filter_options)
	contents.move_child(_filter_options, 1)
	filter_toggle.toggled.connect(func(value): _filter_options.visible = value)
	var reset := Button.new()
	reset.text = "Показать все"
	reset.clip_text = true
	reset.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reset.tooltip_text = reset.text
	reset.pressed.connect(reset_filters)
	_filter_options.add_child(reset)
	for kind: String in Catalog.KINDS:
		# A CheckBox's built-in text sets an unwrapped minimum width. Keep the
		# focusable toggle, but put its complete name in a wrapping sibling label.
		var filter_row := HBoxContainer.new()
		filter_row.add_theme_constant_override("separation", 3)
		filter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_filter_options.add_child(filter_row)
		var checkbox := CheckBox.new()
		checkbox.tooltip_text = Catalog.kind_name(kind)
		checkbox.button_pressed = true
		checkbox.add_theme_font_size_override("font_size", 11)
		checkbox.toggled.connect(func(value): set_kind_enabled(kind, value))
		filter_row.add_child(checkbox)
		var filter_name := Label.new()
		filter_name.text = Catalog.kind_name(kind)
		filter_name.add_theme_font_size_override("font_size", 11)
		filter_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		filter_name.mouse_filter = Control.MOUSE_FILTER_STOP
		filter_name.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				checkbox.grab_focus()
				checkbox.button_pressed = not checkbox.button_pressed
				filter_name.accept_event()
		)
		filter_row.add_child(filter_name)
		_filter_checks[kind] = checkbox

func _rebuild_places() -> void:
	_hover_objects = _object_index.visible_objects()
	_pois = Catalog.select_pois(_hover_objects)
	if not is_instance_valid(_places):
		return
	for child in _places.get_children():
		_places.remove_child(child)
		child.queue_free()
	for object: Dictionary in _pois:
		var button := Button.new()
		button.text = str(object.name)
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = "%s\n%s" % [str(object.name), Catalog.kind_name(str(object.get("kind", "object")))]
		button.pressed.connect(func():
			set_waypoint(object)
			center = MapProjection.point(object)
			zoom = maxf(zoom, 2)
			_request_draw(true)
		)
		_places.add_child(button)
	_object_count.text = "%d объектов · наведите на значок для названия" % _objects.size() if _hover_objects.size() == _objects.size() else "%d из %d объектов · наведите на значок для названия" % [_hover_objects.size(), _objects.size()]
	_poi_buttons_rebuilt += 1
	_update_hover()

func set_kind_enabled(kind: String, value: bool) -> bool:
	var category: String = kind if Catalog.KINDS.has(kind) else "object"
	if not _object_index.set_kind_enabled(category, value):
		return false
	if _filter_checks.has(category):
		_filter_checks[category].set_pressed_no_signal(value)
	_rebuild_places()
	_atlas_valid = false
	_dirty = true
	_request_draw(true)
	return true

func is_kind_enabled(kind: String) -> bool:
	return _object_index.is_kind_enabled(kind if Catalog.KINDS.has(kind) else "object")

func reset_filters() -> bool:
	if not _object_index.reset_filters():
		return false
	for checkbox in _filter_checks.values():
		checkbox.set_pressed_no_signal(true)
	_rebuild_places()
	_atlas_valid = false
	_request_draw(true)
	return true

func visible_pois() -> Array:
	return _pois.duplicate()

func object_at(pointer: Vector2) -> Variant:
	return get_projection().object_at(pointer, _hover_objects)

func _update_hover() -> void:
	if not is_instance_valid(_tooltip) or not visible:
		return
	var squad_text := _squad_hover(_hover_pointer)
	var object: Variant = object_at(_hover_pointer) if not squad_text else null
	_tooltip.visible = object != null or not squad_text.is_empty()
	_tooltip.text = squad_text if squad_text else str(object.name) if object != null else ""
	_tooltip.reset_size()
	_tooltip.position = Vector2(clampf(_hover_pointer.x + 12, 5, maxf(5, _surface.size.x - _tooltip.size.x - 5)), clampf(_hover_pointer.y + 12, 5, maxf(5, _surface.size.y - _tooltip.size.y - 5)))

func _squad_hover(pointer: Vector2) -> String:
	if not expanded:
		return ""
	var nearest: Variant = null
	var distance := 10.0
	var projection = get_projection()
	for actor in _actors:
		var location: Variant = actor.get("position", actor)
		if actor.get("ownSquad", false) != true or actor.get("active", true) == false or actor.get("hidden", false) or not MapProjection.valid_point(location):
			continue
		var candidate: float = pointer.distance_to(projection.to_screen(MapProjection.point(location)))
		if candidate <= distance:
			nearest = actor
			distance = candidate
	if nearest == null:
		return ""
	var profession: String = {"medic": "Медик", "bruiser": "Громила", "safecracker": "Медвежатник", "engineer": "Электрик-резчик", "demolitions": "Подрывник"}.get(nearest.get("profession"), "Наёмник")
	var status: String = {"active": "Готов", "downed": "Нужна помощь", "hospital": "В больнице", "returning": "Возвращается", "defending": "Защищает отряд", "approach": "Идёт к цели", "working": "Выполняет приказ", "awaiting": "Ожидает подтверждения", "retreat": "Отходит", "countdown": "Ожидает взрыва"}.get(nearest.get("status"), "Готов")
	return "%s\nВаш отряд\n%s\n%s" % [nearest.get("name", "Боец"), profession, status]

func _collect_focusable(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled:
			controls.append(child)
		_collect_focusable(child, controls)
