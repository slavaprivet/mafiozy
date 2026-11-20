extends CanvasLayer
## Compact, event-driven hero vitals. The combat owner supplies the state; this
## layer only presents it and never changes health or wounds.

class BodyDiagram extends Control:
	var segments: Dictionary = {}
	var body_split := false
	const KEYS := ["head", "chest", "pelvis", "upperarm_l", "forearm_l", "hand_l",
		"upperarm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l",
		"thigh_r", "shin_r", "foot_r"]

	func _init() -> void:
		custom_minimum_size = Vector2(72.0, 104.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(next_segments: Dictionary, next_split: bool) -> void:
		if segments == next_segments and body_split == next_split:
			return
		segments = next_segments.duplicate(true)
		body_split = next_split
		queue_redraw()

	func _part_status(key: String) -> String:
		var value: Variant = segments.get(key, "healthy")
		if value is Dictionary:
			if bool(value.get("severed", false)):
				return "severed"
			if bool(value.get("disabled", false)):
				return "disabled"
			var health := clampf(float(value.get("health", 1.0)), 0.0, 1.0)
			if health <= 0.3:
				return "critical"
			if health < 0.85:
				return "injured"
			return "healthy"
		return str(value)

	func _color(key: String) -> Color:
		match _part_status(key):
			"severed": return Color(0.35, 0.34, 0.32)
			"disabled": return Color(0.47, 0.50, 0.55)
			"critical": return Color(0.69, 0.17, 0.15)
			"injured": return Color(0.77, 0.47, 0.23)
			_: return Color(0.68, 0.72, 0.62)

	func _shape(points: PackedVector2Array, key: String) -> void:
		draw_colored_polygon(points, _color(key))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(0.14, 0.16, 0.16), 1.5, true)

	func _mark_severed(key: String, at: Vector2) -> void:
		if _part_status(key) != "severed":
			return
		var red := Color(0.88, 0.28, 0.22)
		draw_line(at + Vector2(-4.0, -4.0), at + Vector2(4.0, 4.0), red, 1.8, true)
		draw_line(at + Vector2(4.0, -4.0), at + Vector2(-4.0, 4.0), red, 1.8, true)

	func _draw() -> void:
		_shape(PackedVector2Array([Vector2(23, 29), Vector2(49, 29), Vector2(48, 52), Vector2(24, 52)]), "chest")
		_shape(PackedVector2Array([Vector2(24, 53), Vector2(48, 53), Vector2(47, 63), Vector2(25, 63)]), "pelvis")
		_shape(PackedVector2Array([Vector2(22, 30), Vector2(15, 34), Vector2(13, 44), Vector2(20, 46), Vector2(29, 38)]), "upperarm_l")
		_shape(PackedVector2Array([Vector2(13, 45), Vector2(20, 47), Vector2(17, 58), Vector2(10, 57)]), "forearm_l")
		_shape(PackedVector2Array([Vector2(10, 58), Vector2(17, 59), Vector2(16, 66), Vector2(9, 65)]), "hand_l")
		_shape(PackedVector2Array([Vector2(50, 30), Vector2(57, 34), Vector2(59, 44), Vector2(52, 46), Vector2(43, 38)]), "upperarm_r")
		_shape(PackedVector2Array([Vector2(59, 45), Vector2(52, 47), Vector2(55, 58), Vector2(62, 57)]), "forearm_r")
		_shape(PackedVector2Array([Vector2(62, 58), Vector2(55, 59), Vector2(56, 66), Vector2(63, 65)]), "hand_r")
		_shape(PackedVector2Array([Vector2(25, 63), Vector2(36, 63), Vector2(34, 77), Vector2(24, 77)]), "thigh_l")
		_shape(PackedVector2Array([Vector2(24, 78), Vector2(34, 78), Vector2(33, 91), Vector2(23, 91)]), "shin_l")
		_shape(PackedVector2Array([Vector2(23, 92), Vector2(33, 92), Vector2(34, 98), Vector2(20, 98)]), "foot_l")
		_shape(PackedVector2Array([Vector2(36, 63), Vector2(47, 63), Vector2(48, 77), Vector2(38, 77)]), "thigh_r")
		_shape(PackedVector2Array([Vector2(38, 78), Vector2(48, 78), Vector2(49, 91), Vector2(39, 91)]), "shin_r")
		_shape(PackedVector2Array([Vector2(39, 92), Vector2(49, 92), Vector2(52, 98), Vector2(38, 98)]), "foot_r")
		draw_circle(Vector2(36, 17), 10.5, _color("head"))
		draw_arc(Vector2(36, 17), 10.5, 0.0, TAU, 20, Color(0.14, 0.16, 0.16), 1.5, true)
		if body_split:
			draw_line(Vector2(22, 52), Vector2(50, 52), Color(0.95, 0.24, 0.18), 2.0, true)
		for key: String in KEYS:
			_mark_severed(key, _position(key))
			var part: Dictionary = segments.get(key, {})
			if not bool(part.get("bleeding", false)):
				continue
			var at := _position(key)
			at.x += 5.0 if key in ["head", "chest", "pelvis", "thigh_l", "shin_l", "foot_l"] else -5.0
			draw_circle(at, 2.5, Color(0.96, 0.23, 0.18))
			draw_arc(at, 2.5, 0.0, TAU, 12, Color(0.98, 0.78, 0.55), 1.0, true)

	func _position(key: String) -> Vector2:
		match key:
			"head": return Vector2(36, 17)
			"chest": return Vector2(36, 40)
			"pelvis": return Vector2(36, 58)
			"upperarm_l": return Vector2(20, 38)
			"forearm_l": return Vector2(15, 52)
			"hand_l": return Vector2(13, 62)
			"upperarm_r": return Vector2(52, 38)
			"forearm_r": return Vector2(57, 52)
			"hand_r": return Vector2(59, 62)
			"thigh_l": return Vector2(29, 70)
			"shin_l": return Vector2(29, 84)
			"foot_l": return Vector2(27, 95)
			"thigh_r": return Vector2(43, 70)
			"shin_r": return Vector2(43, 84)
			_: return Vector2(45, 95)

var _panel: PanelContainer
var _hp_label: Label
var _hp_fill: Panel
var _hp_fill_style: StyleBoxFlat
var _bleed_label: Label
var _rate_label: Label
var _sites_label: Label
var _lost_label: Label
var _burn_label: Label
var _diagram: BodyDiagram
var _last_state: Dictionary = {}
const BAR_WIDTH := 153.0

func configure(scene: Node) -> void:
	if is_instance_valid(_panel) or not is_instance_valid(scene):
		return
	layer = 14
	name = "HeroVitalsHud"
	scene.add_child(self)
	_panel = PanelContainer.new()
	_panel.name = "VitalsPanel"
	_panel.position = Vector2(16.0, 86.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.067, 0.073, 0.91)
	style.border_color = Color(0.57, 0.43, 0.25, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	style.content_margin_left = 9
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	_panel.add_child(row)
	_diagram = BodyDiagram.new()
	row.add_child(_diagram)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_hp_label = _label(column, "ГЕРОЙ 100 / 100", 13, Color("ead7ad"))
	var track := Panel.new()
	track.custom_minimum_size = Vector2(BAR_WIDTH, 9)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.11, 0.10, 0.09)
	track_style.set_corner_radius_all(4)
	track.add_theme_stylebox_override("panel", track_style)
	column.add_child(track)
	_hp_fill = Panel.new()
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.size = Vector2(BAR_WIDTH, 9)
	_hp_fill_style = StyleBoxFlat.new()
	_hp_fill_style.bg_color = Color(0.68, 0.16, 0.13)
	_hp_fill_style.set_corner_radius_all(4)
	_hp_fill.add_theme_stylebox_override("panel", _hp_fill_style)
	track.add_child(_hp_fill)
	_bleed_label = _label(column, "●  Кровотечение 0%", 12, Color("d9c7a9"))
	_rate_label = _label(column, "0.0 HP/с", 11, Color("c4b8a4"))
	_sites_label = _label(column, "Ран нет", 11, Color("c4b8a4"))
	_sites_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sites_label.custom_minimum_size.x = BAR_WIDTH
	_lost_label = _label(column, "", 11, Color("ec6850"))
	_lost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_burn_label = _label(column, "", 11, Color("f3aa55"))
	render_state({"hp": 100.0, "max_hp": 100.0, "parts": {}, "bleed_percent": 0.0,
		"segments": {}, "severed_labels": [], "body_split": false, "burning": false,
		"bleed_hp_per_second": 0.0, "bleed_sites": []})

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func render_state(state: Dictionary) -> void:
	if not is_instance_valid(_panel) or state == _last_state:
		return
	_last_state = state.duplicate(true)
	var maximum := maxf(1.0, float(state.get("max_hp", 100.0)))
	var hp := clampf(float(state.get("hp", maximum)), 0.0, maximum)
	var percent := clampf(float(state.get("bleed_percent", 0.0)), 0.0, 100.0)
	var rate := maxf(0.0, float(state.get("bleed_hp_per_second", 0.0)))
	_hp_label.text = "ГЕРОЙ  %d / %d" % [int(ceil(hp)), int(ceil(maximum))]
	_hp_fill.size.x = BAR_WIDTH * hp / maximum
	_hp_fill_style.bg_color = Color(0.68, 0.16, 0.13) if hp > maximum * 0.3 else Color(0.82, 0.32, 0.10)
	_bleed_label.text = "●  Кровотечение %d%%" % int(round(percent))
	_bleed_label.add_theme_color_override("font_color", Color("ec6850") if percent > 0.0 else Color("d9c7a9"))
	_rate_label.text = "−%.1f HP/с" % rate if rate > 0.0 else "0.0 HP/с"
	var sites: Array = state.get("bleed_sites", [])
	var names: Array[String] = []
	for site: Variant in sites:
		var title := str(site)
		if not title.is_empty() and not names.has(title):
			names.append(title)
	var lost: Array = state.get("severed_labels", [])
	var burning := bool(state.get("burning", false))
	var split := bool(state.get("body_split", false))
	var active_bleed := percent > 0.0 or rate > 0.0
	var segments: Dictionary = state.get("segments", {})
	var injured := false
	for segment: Dictionary in segments.values():
		if float(segment.get("health", 1.0)) < 0.98:
			injured = true
			break
	if not names.is_empty():
		_sites_label.text = ", ".join(names)
	elif active_bleed:
		_sites_label.text = "Место раны не указано"
	else:
		_sites_label.text = "Ран нет" if lost.is_empty() and not burning and not split and not injured else "Нет активного кровотечения"
	var lost_text := ", ".join(lost)
	if split:
		lost_text = "разделён корпус" if lost_text.is_empty() else lost_text + ", разделён корпус"
	_lost_label.text = "Отсечено: " + lost_text if not lost_text.is_empty() else ""
	_burn_label.text = "●  Ожог / горение" if burning else ""
	_diagram.set_state(segments, split)

func snapshot() -> Dictionary:
	return _last_state.duplicate(true)
