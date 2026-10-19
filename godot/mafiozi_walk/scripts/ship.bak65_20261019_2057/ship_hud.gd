extends CanvasLayer
## SHIP61 HUD (agent E).
##
## The panel speaks the same visual language as the balloon HUD: dark translucent
## plates, brass/gold accents, compact rows, Russian labels. Everything is built in
## code so no new asset (font, texture, scene) is required.
##
## Public API from the contract:
##   install(host) -> Dictionary
##   update_state(state)
##   message(text, seconds)
##   set_cannon(state)
##   dispose()
##
## The HUD never reads the tree per frame: it only reacts to host calls and keeps
## one _process timer for fading messages.

const MPS_TO_KNOTS := 1.944

## The aiming reticle is a private drawing helper of this file: the contract allows
## only ship_hud.gd in the HUD zone, so no separate scene/script is created for it.
class Reticle extends Control:
	var pitch_deg := 0.0
	var yaw_deg := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_aim(new_pitch: float, new_yaw: float) -> void:
		pitch_deg = new_pitch
		yaw_deg = new_yaw
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var centre := Vector2(size.x * 0.5, size.y * 0.5)
		var gold := Color(0.95, 0.80, 0.34, 0.95)
		var soft := Color(0.95, 0.85, 0.55, 0.55)
		var shadow := Color(0.0, 0.0, 0.0, 0.55)
		var gap := 8.0
		var arm := 26.0
		# Crosshair: four arms with a gap, drawn twice for a readable dark outline.
		for pass_index in 2:
			var colour := shadow if pass_index == 0 else gold
			var width := 4.0 if pass_index == 0 else 2.0
			draw_line(centre + Vector2(-gap - arm, 0.0), centre + Vector2(-gap, 0.0), colour, width)
			draw_line(centre + Vector2(gap, 0.0), centre + Vector2(gap + arm, 0.0), colour, width)
			draw_line(centre + Vector2(0.0, -gap - arm), centre + Vector2(0.0, -gap), colour, width)
			draw_line(centre + Vector2(0.0, gap), centre + Vector2(0.0, gap + arm), colour, width)
		draw_circle(centre, 2.2, gold)
		draw_arc(centre, 42.0, 0.0, TAU, 48, soft, 1.0, true)
		# Vertical elevation scale: -8 deg at the bottom, +30 deg at the top.
		var scale_x := centre.x + 92.0
		var top := centre.y - 104.0
		var bottom := centre.y + 88.0
		var span := bottom - top
		draw_line(Vector2(scale_x, top - 10.0), Vector2(scale_x, bottom + 10.0), shadow, 3.0)
		draw_line(Vector2(scale_x, top - 10.0), Vector2(scale_x, bottom + 10.0), Color(0.95, 0.80, 0.34, 0.5), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(scale_x - 8.0, top - 20.0), "УГОЛ",
			HORIZONTAL_ALIGNMENT_LEFT, 50.0, 10, Color(0.90, 0.84, 0.68, 0.75))
		var step := -5.0
		while step <= 30.0:
			var y := bottom - ((step + 8.0) / 38.0) * span
			var major := int(round(step)) % 10 == 0
			var tick := 11.0 if major else 6.0
			draw_line(Vector2(scale_x, y), Vector2(scale_x + tick, y), gold if major else soft, 1.5)
			if major:
				draw_string(ThemeDB.fallback_font, Vector2(scale_x + tick + 5.0, y + 4.0), "%d°" % int(step),
					HORIZONTAL_ALIGNMENT_LEFT, 40.0, 12, Color(0.96, 0.89, 0.70, 0.95))
			step += 5.0
		var marker_y := bottom - ((clampf(pitch_deg, -8.0, 30.0) + 8.0) / 38.0) * span
		var marker := PackedVector2Array([
			Vector2(scale_x - 8.0, marker_y - 5.0),
			Vector2(scale_x - 8.0, marker_y + 5.0),
			Vector2(scale_x - 1.0, marker_y),
		])
		draw_colored_polygon(marker, gold)
		draw_string(ThemeDB.fallback_font, Vector2(scale_x - 58.0, marker_y + 4.0), "%+d°" % int(round(pitch_deg)),
			HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 12, Color(0.96, 0.90, 0.74, 1.0))
		# A small heading notch: shows which way the barrel is turned off the beam.
		var yaw_offset := clampf(yaw_deg, -32.0, 32.0) / 32.0 * 70.0
		draw_line(centre + Vector2(yaw_offset, 56.0), centre + Vector2(yaw_offset, 68.0), gold, 2.0)

var _host: Node = null
var _root: Control = null
var _panel: PanelContainer = null
var _retitle: Label = null
var _speed_value: Label = null
var _sails_value: Label = null
var _hull_value: Label = null
var _flood_value: Label = null
var _hull_fill: ColorRect = null
var _flood_fill: ColorRect = null
var _balls_value: Label = null
var _boards_value: Label = null
var _footer: Label = null

var _cannon_panel: PanelContainer = null
var _cannon_title: Label = null
var _cannon_side: Label = null
var _cannon_status: Label = null
var _cannon_angle: Label = null
var _cannon_ammo: Label = null
var _cannon_hint: Label = null
var _reticle: Control = null

var _message_root: VBoxContainer = null
var _messages: Array[Dictionary] = []

var _installed := false
var _disposed := false
var _cannon_visible := false
var _last_state: Dictionary = {}
var _last_cannon: Dictionary = {}

var _col_gold := Color(0.94, 0.78, 0.29)
var _col_gold_soft := Color(0.95, 0.83, 0.52)
var _col_text := Color(0.91, 0.88, 0.80)
var _col_muted := Color(0.64, 0.66, 0.66)
var _col_green := Color(0.55, 0.78, 0.48)
var _col_red := Color(0.86, 0.36, 0.29)
var _col_amber := Color(0.92, 0.65, 0.24)

## ---------------------------------------------------------------- lifecycle

func install(host: Node) -> Dictionary:
	if _disposed:
		return {"ok": false, "reason": "disposed"}
	_host = host
	_ensure_built()
	_installed = true
	var host_name := ""
	if is_instance_valid(_host):
		host_name = str(_host.name)
		# A first state is optional: a host that is not ready yet must not break install.
		if _host.has_method("snapshot"):
			var first: Variant = _host.call("snapshot")
			if first is Dictionary:
				update_state(first)
	_visible_root(true)
	return {"ok": true, "layer": layer, "host": host_name}

func dispose() -> void:
	_disposed = true
	_installed = false
	_cannon_visible = false
	_host = null
	_clear_messages()
	if is_instance_valid(_root):
		_root.visible = false
	set_process(false)

func is_installed() -> bool:
	return _installed and not _disposed

## ---------------------------------------------------------------- public API

func update_state(state: Dictionary) -> void:
	if _disposed or state == null:
		return
	_ensure_built()
	if state.is_empty():
		return
	_last_state = state
	var ship: Dictionary = _sub(state, ["ship", "boat", "vessel"])
	if ship.is_empty():
		ship = state
	var hud: Dictionary = _sub(state, ["hud", "cargo", "inventory", "resources"])
	if hud.is_empty():
		hud = state

	var speed := _num(_first(ship, ["speed", "speed_mps", "speed_mps_current"], 0.0), 0.0)
	if speed < 0.0:
		speed = -speed
	var sails := _sails_open(ship, state)
	var integrity := _ratio(_first(ship, ["integrity", "hull_integrity", "hull", "hull_percent"], 1.0), 1.0)
	var flooding := _ratio(_first(ship, ["flooding", "flood", "water_inside", "flood_percent"], 0.0), 0.0)
	var balls := int(_num(_first(hud, ["balls", "cannonballs", "ammo", "ammo_count", "cannon_balls"], 0), 0.0))
	var boards := int(_num(_first(hud, ["boards", "planks", "repair_boards", "wood"], 0), 0.0))
	if balls == 0 and not hud.has("balls"):
		balls = int(_num(_first(ship, ["balls", "cannonballs", "ammo"], 0), 0.0))

	_speed_value.text = "%.1f уз" % (speed * MPS_TO_KNOTS)
	_sails_value.text = "РАСКРЫТЫ" if sails else "СВЁРНУТЫ"
	_sails_value.add_theme_color_override("font_color", _col_gold_soft if sails else _col_muted)
	_hull_value.text = "%d %%" % int(round(integrity * 100.0))
	_hull_value.add_theme_color_override("font_color", _health_colour(integrity))
	_flood_value.text = "%d %%" % int(round(flooding * 100.0))
	_flood_value.add_theme_color_override("font_color", _flood_colour(flooding))
	_fill_bar(_hull_fill, integrity, _health_colour(integrity))
	_fill_bar(_flood_fill, flooding, _flood_colour(flooding))
	_balls_value.text = str(balls)
	_boards_value.text = str(boards)
	if is_instance_valid(_balls_value):
		_balls_value.add_theme_color_override("font_color", _col_gold_soft if balls > 0 else _col_red)
	if is_instance_valid(_boards_value):
		_boards_value.add_theme_color_override("font_color", _col_gold_soft if boards > 0 else _col_muted)
	if is_instance_valid(_cannon_ammo):
		_cannon_ammo.text = "В ЯЩИКЕ: %d ЯДЕР · %d ДОСОК" % [balls, boards]
		_cannon_ammo.add_theme_color_override("font_color", _col_muted if balls > 0 else _col_red)

	var sunk := bool(_first(ship, ["sunk", "is_sunk"], false))
	var status := "ЗАТОНУЛ" if sunk else ("ТОНЕТ" if flooding >= 0.75 else "НА ХОДУ" if sails else "ДРЕЙФ")
	var water: Dictionary = _sub(state, ["water", "basin", "sea"])
	var depth := _num(_first(water, ["depth", "depth_at_ship", "depth_bay", "depth_at"], 0.0), 0.0)
	if is_instance_valid(_footer):
		_footer.text = "%s · ГЛУБИНА %.1f м" % [status, depth]
		_footer.add_theme_color_override("font_color", _col_red if sunk or flooding >= 0.75 else _col_muted)

	if state.has("cannons") or state.has("cannon"):
		var cannon_state: Dictionary = _sub(state, ["cannons", "cannon", "guns", "cannon_state"])
		# A host that reports the mounted gun in the same snapshot keeps the overlay synced.
		if not cannon_state.is_empty():
			_sync_cannon_quiet(cannon_state)

func message(text: String, seconds: float = 2.5) -> void:
	if _disposed:
		return
	_ensure_built()
	if text.is_empty():
		return
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_stylebox_override("panel", _message_style(text))
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", _message_colour(text))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(label)
	_message_root.add_child(row)
	var life: float = maxf(0.4, seconds if seconds > 0.0 else 2.5)
	_messages.append({"row": row, "remaining": life, "total": life})
	while _messages.size() > 4:
		var stale: Dictionary = _messages.pop_front()
		var stale_row: Variant = stale.get("row")
		if is_instance_valid(stale_row):
			(stale_row as Node).queue_free()

func set_cannon(state: Dictionary) -> void:
	if _disposed:
		return
	_ensure_built()
	_last_cannon = state if state != null else {}
	var mounted := _cannon_mounted(_last_cannon)
	_cannon_visible = mounted
	if is_instance_valid(_reticle):
		# SHIP64: the iron-sight reticle was removed; aim with the barrel itself.
		_reticle.visible = false
	if is_instance_valid(_cannon_panel):
		_cannon_panel.visible = mounted
	if not mounted:
		return
	var index := int(_num(_first(_last_cannon, ["index", "manning_index", "cannon_index"], 0), 0.0))
	var side := _side_text(_first(_last_cannon, ["side", "board", "side_name"], ""))
	var title := "ПУШКА %d" % (index + 1)
	_cannon_title.text = title
	_cannon_side.text = side
	var loaded := _loaded(_last_cannon)
	_cannon_status.text = "ЗАРЯЖЕНО" if loaded else "РАЗРЯЖЕНО"
	_cannon_status.add_theme_color_override("font_color", _col_green if loaded else _col_red)
	var pitch := _angle_deg(_last_cannon, ["pitch", "pitch_deg", "aim_pitch", "elevation", "angle", "pitch_rad"], 0.0)
	var yaw := _angle_deg(_last_cannon, ["yaw", "yaw_deg", "aim_yaw", "yaw_rad"], 0.0)
	if is_instance_valid(_reticle) and _reticle.has_method("set_aim"):
		_reticle.call("set_aim", pitch, yaw)
	_cannon_angle.text = "УГОЛ %+d° · %s" % [int(round(pitch)), _pitch_word(pitch)]
	var ammo := int(_num(_first(_last_cannon, ["balls", "ammo", "balls_left"], -1), -1.0))
	var hint: String = str(_first(_last_cannon, ["hint", "hints", "controls"], ""))
	if hint.is_empty():
		hint = "F — ВСТАТЬ/ПОКИНУТЬ · E — ЗАРЯДИТЬ · ЛКМ — ВЫСТРЕЛ"
		if ammo >= 0:
			hint = "ЯДРА %d · %s" % [ammo, hint]
	_cannon_hint.text = hint

## ---------------------------------------------------------------- build

func _ensure_built() -> void:
	if is_instance_valid(_root):
		return
	_build()

func _build() -> void:
	name = "ShipHud61"
	layer = 14
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_reticle()
	_build_ship_panel()
	_build_cannon_panel()
	_build_messages()
	set_process(true)
	_visible_root(true)

func _build_reticle() -> void:
	_reticle = Reticle.new()
	_reticle.name = "Reticle"
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.visible = false
	_root.add_child(_reticle)

func _build_ship_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ShipPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.05, 0.062, 0.87), 8.0, 3))
	_root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 20.0
	_panel.offset_top = -310.0
	_panel.offset_right = 352.0
	_panel.offset_bottom = -92.0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	_retitle = _label(title_row, "КОРАБЛЬ «МАФИОЗИ»", 14, _col_gold)
	_retitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var class_label := _label(title_row, "ФРЕГАТ", 10, Color(0.62, 0.58, 0.47))
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var line := StyleBoxLine.new()
	line.color = Color(0.94, 0.78, 0.29, 0.35)
	line.thickness = 1
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.add_theme_stylebox_override("separator", line)
	column.add_child(separator)

	_speed_value = _row(column, "СКОРОСТЬ", _col_gold_soft)
	_sails_value = _row(column, "ПАРУСА", _col_muted)
	var hull_head := _bar_head(column, "КОРПУС")
	_hull_value = hull_head
	_hull_fill = _bar(column)
	var flood_head := _bar_head(column, "ТЕЧЬ")
	_flood_value = flood_head
	_flood_fill = _bar(column)

	var cargo := HBoxContainer.new()
	cargo.add_theme_constant_override("separation", 6)
	cargo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cargo)
	var balls_caption := _label(cargo, "ЯДРА", 11, _col_muted)
	balls_caption.custom_minimum_size.x = 42.0
	_balls_value = _label(cargo, "0", 14, _col_gold_soft)
	_balls_value.custom_minimum_size.x = 34.0
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargo.add_child(gap)
	var boards_caption := _label(cargo, "ДОСКИ", 11, _col_muted)
	boards_caption.custom_minimum_size.x = 48.0
	_boards_value = _label(cargo, "0", 14, _col_gold_soft)
	_boards_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boards_value.custom_minimum_size.x = 32.0

	_footer = _label(column, "ДРЕЙФ · ГЛУБИНА 0.0 м", 10, _col_muted)

func _build_cannon_panel() -> void:
	_cannon_panel = PanelContainer.new()
	_cannon_panel.name = "CannonPanel"
	_cannon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cannon_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.05, 0.062, 0.88), 8.0, 3))
	_root.add_child(_cannon_panel)
	_cannon_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cannon_panel.offset_left = -352.0
	_cannon_panel.offset_top = -164.0
	_cannon_panel.offset_right = -20.0
	_cannon_panel.offset_bottom = -20.0
	_cannon_panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cannon_panel.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	_cannon_title = _label(title_row, "ПУШКА 1", 14, _col_gold)
	_cannon_side = _label(title_row, "ЛЕВЫЙ БОРТ", 11, _col_muted)
	_cannon_side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cannon_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := StyleBoxLine.new()
	line.color = Color(0.94, 0.78, 0.29, 0.35)
	line.thickness = 1
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.add_theme_stylebox_override("separator", line)
	column.add_child(separator)
	_cannon_status = _label(column, "РАЗРЯЖЕНО", 20, _col_red)
	_cannon_angle = _label(column, "УГОЛ 0° · ПРЯМО", 12, _col_text)
	_cannon_ammo = _label(column, "В ЯЩИКЕ: 0 ЯДЕР · 0 ДОСОК", 11, _col_muted)
	_cannon_hint = _label(column, "F — ВСТАТЬ/ПОКИНУТЬ · E — ЗАРЯДИТЬ · ЛКМ — ВЫСТРЕЛ", 10, _col_muted)

func _build_messages() -> void:
	_message_root = VBoxContainer.new()
	_message_root.name = "Messages"
	_message_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_root.alignment = BoxContainer.ALIGNMENT_BEGIN
	_message_root.add_theme_constant_override("separation", 5)
	_root.add_child(_message_root)
	_message_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message_root.offset_left = -300.0
	_message_root.offset_right = 300.0
	_message_root.offset_top = 132.0
	_message_root.offset_bottom = 132.0

## ---------------------------------------------------------------- widgets

func _label(parent: Node, text_value: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _row(parent: Node, caption: String, colour: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left := _label(row, caption, 11, _col_muted)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := _label(row, "—", 13, colour)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return right

func _bar_head(parent: Node, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left := _label(row, caption, 11, _col_muted)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := _label(row, "100 %", 12, _col_text)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return right

func _bar(parent: Node) -> ColorRect:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(0.0, 10.0)
	frame.add_theme_stylebox_override("panel", _track_style())
	parent.add_child(frame)
	var track := Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(track)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.075, 0.95)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(background)
	var fill := ColorRect.new()
	fill.color = _col_green
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 1.0
	fill.offset_right = 0.0
	track.add_child(fill)
	return fill

func _panel_style(colour: Color, radius: float, border_left: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 4
	if border_left > 0:
		style.border_width_left = border_left
		style.border_color = _col_gold
	return style

func _track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.11, 0.9)
	style.set_corner_radius_all(2)
	style.set_border_width_all(1)
	style.border_color = Color(0.94, 0.78, 0.29, 0.22)
	style.content_margin_left = 1.0
	style.content_margin_right = 1.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	return style

func _message_style(text_value: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.062, 0.9)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.border_width_left = 2
	style.border_width_right = 2
	var accent := _message_colour(text_value)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	return style

## ---------------------------------------------------------------- helpers

## Keep the overlay fresh when the host reports the mounted gun inside snapshot(),
## but never pop it open on its own: set_cannon() is the explicit show/hide signal.
func _sync_cannon_quiet(state_value: Dictionary) -> void:
	if not _cannon_visible:
		return
	set_cannon(state_value)

func _visible_root(value: bool) -> void:
	if is_instance_valid(_root):
		_root.visible = value

func _process(delta: float) -> void:
	if _disposed or _messages.is_empty():
		return
	for index in range(_messages.size() - 1, -1, -1):
		var entry: Dictionary = _messages[index]
		var remaining := float(entry.get("remaining", 0.0)) - delta
		entry["remaining"] = remaining
		var row: Variant = entry.get("row")
		if remaining <= 0.0 or not is_instance_valid(row):
			if is_instance_valid(row):
				(row as Node).queue_free()
			_messages.remove_at(index)
			continue
		(row as CanvasItem).modulate.a = clampf(remaining / 0.7, 0.0, 1.0)

func _clear_messages() -> void:
	for entry: Dictionary in _messages:
		var row: Variant = entry.get("row")
		if is_instance_valid(row):
			(row as Node).queue_free()
	_messages.clear()

func _fill_bar(fill: ColorRect, ratio: float, colour: Color) -> void:
	if not is_instance_valid(fill):
		return
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_right = 0.0
	fill.color = colour

func _health_colour(ratio: float) -> Color:
	if ratio >= 0.6:
		return _col_green
	if ratio >= 0.3:
		return _col_amber
	return _col_red

func _flood_colour(ratio: float) -> Color:
	var red := clampf(0.25 + ratio * 0.7, 0.0, 1.0)
	return Color(red, 0.10 + (1.0 - ratio) * 0.05, 0.09, 1.0)

func _message_colour(text_value: String) -> Color:
	var lowered := text_value.to_lower()
	if lowered.contains("тонет") or lowered.contains("пробоин") or lowered.contains("пожар") or lowered.contains("разруш"):
		return Color(0.95, 0.42, 0.32)
	if lowered.contains("раскрыт") or lowered.contains("заряж") or lowered.contains("загруж") or lowered.contains("почин") or lowered.contains("готов"):
		return _col_gold_soft
	return _col_text

func _pitch_word(pitch: float) -> String:
	if pitch > 6.0:
		return "ВВЕРХ"
	if pitch < -2.0:
		return "ВНИЗ"
	return "ПРЯМО"

func _side_text(side_value: Variant) -> String:
	if side_value is String:
		var side := str(side_value)
		match side.to_lower():
			"port", "left":
				return "ЛЕВЫЙ БОРТ"
			"starboard", "right":
				return "ПРАВЫЙ БОРТ"
			"":
				return "БОРТ"
			_:
				return side.to_upper()
	return "ЛЕВЫЙ БОРТ"

func _sails_open(ship: Dictionary, state: Dictionary) -> bool:
	var value: Variant = _first(ship, ["sails_open", "sails", "sail_open", "sail_amount", "sails_amount"], null)
	if value == null:
		value = _first(state, ["sails_open", "sails"], null)
	if value is bool:
		return value
	if value is String:
		return str(value).to_lower() in ["open", "opened", "true", "1", "раскрыты", "подняты"]
	if value is float or value is int:
		return float(value) > 0.5
	if ship.has("sail"):
		return bool(ship.get("sail"))
	return false

func _cannon_mounted(state_value: Dictionary) -> bool:
	if state_value.is_empty():
		return false
	if state_value.has("visible") and not bool(state_value.get("visible")):
		return false
	var mounted: Variant = _first(state_value, ["manning", "manned", "active", "aiming", "mounted"], null)
	if mounted is bool:
		return mounted
	var index := int(_num(_first(state_value, ["index", "manning_index", "cannon_index"], -1), -1.0))
	return index >= 0

func _loaded(state_value: Dictionary) -> bool:
	var loaded: Variant = _first(state_value, ["loaded", "is_loaded", "charged", "rammed"], false)
	if loaded is bool:
		return loaded
	if loaded is float or loaded is int:
		return float(loaded) > 0.5
	return false

func _angle_deg(state_value: Dictionary, keys: Array, fallback: float) -> float:
	for key: String in keys:
		if state_value.has(key):
			var value := _num(state_value.get(key), fallback)
			return rad_to_deg(value) if key.ends_with("_rad") else value
	return fallback

func _num(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	if value is String and str(value).is_valid_float():
		return str(value).to_float()
	return fallback

func _first(source: Dictionary, keys: Array, fallback: Variant) -> Variant:
	for key: String in keys:
		if source.has(key) and source[key] != null:
			return source[key]
	return fallback

func _sub(source: Dictionary, keys: Array) -> Dictionary:
	for key: String in keys:
		var value: Variant = source.get(key)
		if value is Dictionary:
			return value
	return {}

func _ratio(value: Variant, fallback: float) -> float:
	var number := _num(value, fallback)
	if number > 1.5:
		number /= 100.0
	return clampf(number, 0.0, 1.0)

## ---------------------------------------------------------------- QA helpers

func message_count() -> int:
	return _messages.size()

func panel_visible() -> bool:
	return is_instance_valid(_panel) and _panel.visible

func cannon_visible() -> bool:
	return _cannon_visible

func last_state() -> Dictionary:
	return _last_state
