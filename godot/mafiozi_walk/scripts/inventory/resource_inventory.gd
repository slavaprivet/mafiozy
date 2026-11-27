extends CanvasLayer
## Castle resource inventory.  Weapon selection remains exclusively on Q.

var _counts := {"wood": 0}
var _panel: PanelContainer
var _wood: Label
var _ready_for_play := false

func install() -> Dictionary:
	if _ready_for_play: return snapshot()
	layer = 28
	_build_panel()
	_ready_for_play = true
	return {"ok":true,"key":"B","resources":["wood"]}

func add_resource(id: String, amount: int) -> bool:
	if not _ready_for_play or id != "wood" or amount <= 0: return false
	_counts[id] = int(_counts.get(id,0)) + amount
	_refresh()
	return true

func count(id: String) -> int:
	return int(_counts.get(id,0))

func is_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible

func snapshot() -> Dictionary:
	return {"ok":_ready_for_play,"open":is_open(),"wood":count("wood")}

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ResourceInventoryPanel"
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-205,-124)
	_panel.custom_minimum_size = Vector2(410,248)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035,0.043,0.045,0.965)
	frame.border_color = Color("b88d48")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(11)
	frame.content_margin_left = 24
	frame.content_margin_right = 24
	frame.content_margin_top = 20
	frame.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel",frame)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.add_theme_font_size_override("font_size",25)
	title.modulate = Color("ebcc79")
	column.add_child(title)
	column.add_child(HSeparator.new())
	var section := Label.new()
	section.text = "РЕСУРСЫ"
	section.add_theme_font_size_override("font_size",15)
	section.modulate = Color("97a39f")
	column.add_child(section)
	_wood = Label.new()
	_wood.add_theme_font_size_override("font_size",21)
	column.add_child(_wood)
	var hint := Label.new()
	hint.text = "B — закрыть  ·  Брёвна подбираются на E"
	hint.add_theme_font_size_override("font_size",15)
	hint.modulate = Color("aab5b2")
	column.add_child(hint)
	_refresh()

func _refresh() -> void:
	if is_instance_valid(_wood): _wood.text = "▰  Древесина (брёвна)          %d" % count("wood")

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_play or not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == KEY_B:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()
	elif code == KEY_ESCAPE and _panel.visible:
		_panel.visible = false
		get_viewport().set_input_as_handled()
