extends CanvasLayer
## DSH_NET — маленькая плашка состояния сети в углу экрана.
## Показывает роль, свой id, число игроков, пинг и частоту снапшотов.
## Видна только когда сеть включена; одиночную игру не трогает.

const Protocol = preload("res://scripts/net/net_protocol.gd")

var _panel: PanelContainer
var _label: Label
var _clock: float = 0.0
var _last_snapshots: int = 0
var _snapshot_rate: int = 0


func _ready() -> void:
	layer = 128
	_panel = PanelContainer.new()
	_panel.name = "NetStatusPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_panel.add_theme_stylebox_override("panel", style)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.offset_left = -8.0
	anchor.offset_right = -8.0
	anchor.offset_top = 8.0
	anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor.grow_vertical = Control.GROW_DIRECTION_END
	anchor.add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	_panel.add_child(_label)
	add_child(anchor)
	_refresh()


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.25:
		return
	var picked: int = Net.snapshots_received + Net.snapshots_sent
	_snapshot_rate = int(round(float(picked - _last_snapshots) / _clock))
	_last_snapshots = picked
	_clock = 0.0
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	var role_text: String = "offline"
	if Net.is_host():
		role_text = "хост"
	elif Net.is_client():
		role_text = "гость"
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s · id %d · игроков %d · %d мс" % [role_text, Net.local_id,
		maxi(Net.players.size(), 1), Net.rtt_ms])
	lines.append("снапшоты %d/с · события %d/%d" % [_snapshot_rate,
		Net.events_sent, Net.events_received])
	if not Net.last_error.is_empty():
		lines.append(Net.last_error)
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key: int = (event as InputEventKey).keycode
		if key == KEY_F10:
			visible = not visible
			get_viewport().set_input_as_handled()
