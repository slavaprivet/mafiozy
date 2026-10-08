extends Node2D
const Minimap = preload("res://addons/walk_minimap/minimap_control.gd")
var map: Control
var _player := Vector2.ZERO
var _yaw := 0.0
var _held_input := Vector2.ZERO
var _input_blocked := false
var _bounds := {"minX": -120.0, "maxX": 120.0, "minZ": -90.0, "maxZ": 90.0}
var _objects: Array = [
	{"id": "demo-shop", "name": "Магазин", "kind": "shop", "buildingId": "shop-building", "x": 80.0, "z": 40.0, "polygon": [[70, 32], [90, 32], [90, 48], [70, 48]]},
	{"id": "demo-hospital", "name": "Больница", "kind": "hospital", "x": -70.0, "z": -40.0, "polygon": [[-84, -50], [-56, -50], [-56, -30], [-84, -30]]},
	{"id": "demo-bank", "name": "Банк", "kind": "bank", "x": 65.0, "z": -40.0, "polygon": [[53, -50], [77, -50], [77, -30], [53, -30]]},
	{"id": "demo-tree", "name": "Дерево", "kind": "tree", "x": -46.0, "z": 26.0},
]
var _detail: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(32, 26)
	panel.add_theme_constant_override("separation", 12)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "МАФИОЗИ / МИНИКАРТА"
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)
	var help := Label.new()
	help.text = "Автономный модуль · учебная карта в метрах\nWASD — движение · M — большая карта\nЛКМ — метка · ПКМ по метке — убрать\nБольшая карта: перетаскивание, стрелки, колесо, Esc"
	help.add_theme_color_override("font_color", Color("b9c9bf"))
	panel.add_child(help)
	var buttons := HBoxContainer.new()
	for item in [["Метка магазина", _place_shop], ["Маршрут: готов", _ready_route], ["Ожидание", func(): map.set_route({"status": "pending"})], ["Нет пути", func(): map.set_route({"status": "blocked"})]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		buttons.add_child(button)
	panel.add_child(buttons)
	_detail = Label.new()
	_detail.add_theme_color_override("font_color", Color("d5be87"))
	panel.add_child(_detail)
	map = Minimap.new()
	layer.add_child(map)
	map.expanded_changed.connect(func(value):
		_input_blocked = value
		_held_input = Vector2.ZERO
	)
	map.set_providers(_position_state, func(): return _bounds, func(): return _objects)
	map.set_world({"bounds": _bounds, "objects": _objects,
		"roads": [{"points": [[-120, 0], [120, 0]], "width": 7}, {"points": [[0, -90], [0, 90]], "width": 7}, {"points": [[0, 40], [100, 40]], "width": 7}],
		"districts": [{"id": "demo-district", "name": "Учебный квартал", "polygon": [[-120, -90], [120, -90], [120, 90], [-120, 90]]}]})
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture(arg.trim_prefix("--capture="))

func _position_state() -> Dictionary:
	return {"position": {"x": _player.x, "z": _player.y}, "yaw": _yaw,
		"vehicles": [{"id": "demo-car", "x": -25.0, "z": 0.0, "yaw": PI / 2, "color": "#8c293e"}]}

func _process(delta: float) -> void:
	_held_input = Vector2.ZERO
	if not _input_blocked:
		_held_input = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	if _held_input != Vector2.ZERO:
		_player += _held_input * delta * 12.0
		_player = _player.clamp(Vector2(_bounds.minX, _bounds.minZ), Vector2(_bounds.maxX, _bounds.maxZ))
		_yaw = atan2(_held_input.x, _held_input.y)
		queue_redraw()
	var detail := "Позиция: %.1f, %.1f м\n%s" % [_player.x, _player.y, "Обзор карты · движение приостановлено" if _input_blocked else "Метка задаёт направление; управление персонажем остаётся ручным"]
	if _detail.text != detail:
		_detail.text = detail

func _place_shop() -> void:
	map.set_waypoint(_objects[0])

func _ready_route() -> void:
	_place_shop()
	# Authored example follows the demo roads; not a path planner result.
	map.set_route({"status": "ready", "points": [{"x": 0, "z": 0}, {"x": 0, "z": 40}, {"x": 80, "z": 40}]})

func _draw() -> void:
	var viewport := get_viewport_rect().size
	var origin := Vector2(viewport.x * 0.42, viewport.y * 0.62)
	var scale_m := 2.1
	draw_rect(Rect2(origin + Vector2(-120, -90) * scale_m, Vector2(240, 180) * scale_m), Color("233e38"))
	for line in [[Vector2(-120, 0), Vector2(120, 0)], [Vector2(0, -90), Vector2(0, 90)], [Vector2(0, 40), Vector2(100, 40)]]:
		draw_line(origin + line[0] * scale_m, origin + line[1] * scale_m, Color("667269"), 14)
	for object in _objects:
		var point := origin + Vector2(object.x, object.z) * scale_m
		draw_circle(point, 11, Minimap._object_color(object.kind))
		draw_string(ThemeDB.fallback_font, point + Vector2(15, 4), object.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c2cabc"))
	draw_circle(origin + _player * scale_m, 6, Color("e8fcf3"))

func _capture(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	_ready_route()
	map.set_expanded(true)
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("DEMO_CAPTURE ", error)
	get_tree().quit(0 if error == OK else 1)
