extends Control
## Talk panel of the shopkeeper: "Поговорить" -> seller name, a line and the
## choice "Товар". The panel owns no money and no goods; it only reports which
## button the player pressed. Opening it releases the game mouse through the host.
signal goods_requested
signal dismissed
const ShopTheme = preload("res://scripts/shop/player_shop_theme.gd")
var _panel: PanelContainer
var _name: Label
var _line: Label
var _sold: Label
var _goods: Button
var _leave: Button
var _open := false

func build() -> void:
	name = "ShopTalkPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", ShopTheme.panel_style(ShopTheme.MODAL_BG, ShopTheme.PANEL_BORDER, 8))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 24
	_panel.offset_top = -228
	_panel.offset_right = 544
	_panel.offset_bottom = -24
	add_child(_panel)
	var padding := ShopTheme.margins(16)
	_panel.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	padding.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", ShopTheme.panel_style("1b242c", ShopTheme.SLOT_BORDER, 6))
	head.add_child(badge)
	var icon := ShopTheme.label("🔫", 22)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(copy)
	_name = ShopTheme.label("", 17, ShopTheme.GOLD)
	copy.add_child(_name)
	_sold = ShopTheme.label("", 11, ShopTheme.DIM)
	copy.add_child(_sold)
	_line = ShopTheme.label("", 13, ShopTheme.TEXT)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 54)
	column.add_child(_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_goods = ShopTheme.button("Товар", 14)
	_goods.custom_minimum_size = Vector2(210, 40)
	_goods.add_theme_stylebox_override("normal", ShopTheme.primary_style())
	_goods.pressed.connect(func() -> void: goods_requested.emit())
	row.add_child(_goods)
	_leave = ShopTheme.button("Уйти", 14)
	_leave.custom_minimum_size = Vector2(120, 40)
	_leave.pressed.connect(func() -> void: close_talk())
	row.add_child(_leave)
	gui_input.connect(_on_backdrop)

func open_talk(seller: Dictionary, sold_line: String = "") -> void:
	if _panel == null:
		return
	_name.text = str(seller.get("name", "Продавец"))
	_line.text = str(seller.get("line", ""))
	_sold.text = sold_line
	_sold.visible = not sold_line.is_empty()
	_goods.text = str(seller.get("goods", "Товар"))
	_leave.text = str(seller.get("leave", "Уйти"))
	_open = true
	visible = true
	_goods.grab_focus()

func set_sold_line(text: String) -> void:
	if _sold == null:
		return
	_sold.text = text
	_sold.visible = not text.is_empty()

func close_talk() -> void:
	if not _open:
		return
	_open = false
	visible = false
	dismissed.emit()

func is_open() -> bool:
	return _open

func focus_primary() -> void:
	if _goods != null and _open:
		_goods.grab_focus()

func _on_backdrop(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_talk()
