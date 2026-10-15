extends Control
## Inventory window of the local player: the same card language as the Q arsenal
## and the shop (badge, name, detail line, state), but it lists what the player
## already owns — guns, vests with their armor points and the backpack counts.
## The window owns no state: it renders the host's stock and asks for one action.
signal close_requested
signal equip_requested(item_id: String)
signal unequip_requested
const ShopTheme = preload("res://scripts/shop/player_shop_theme.gd")
const COLUMNS := 2
const MODAL_MAX := Vector2(900, 720)
const BADGE_HEIGHT := 64.0
var _catalog: RefCounted
var _textures: Dictionary = {}
var _modal: PanelContainer
var _title: Label
var _summary: Label
var _sections: VBoxContainer
var _status: Label
var _cards: Dictionary = {}
var _order: Array = []
var _worn := ""
var _open := false
var _last_view := Vector2.ZERO

func build(catalog: RefCounted, textures: Dictionary) -> void:
	name = "PlayerInventoryWindow"
	_catalog = catalog
	_textures = textures
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_modal = PanelContainer.new()
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_theme_stylebox_override("panel", ShopTheme.panel_style(ShopTheme.PANEL_BG, ShopTheme.PANEL_BORDER, 10))
	add_child(_modal)
	var padding := ShopTheme.margins(14)
	_modal.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	padding.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var icon := ShopTheme.label("🎒", 22)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(copy)
	_title = ShopTheme.label("ИНВЕНТАРЬ", 18, ShopTheme.GOLD)
	copy.add_child(_title)
	_summary = ShopTheme.label("", 11, ShopTheme.DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_summary)
	var close := ShopTheme.button("×", 15)
	close.custom_minimum_size = Vector2(34, 34)
	close.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 10)
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sections)
	_status = ShopTheme.label("", 12, ShopTheme.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_build_cards()
	gui_input.connect(_on_backdrop)

func _build_cards() -> void:
	for section: Variant in [
		{"kind": "weapon", "label": "ОРУЖИЕ"},
		{"kind": "ammo", "label": "ПАТРОНЫ"},
		{"kind": "armor", "label": "БРОНЯ"},
		{"kind": "consumable", "label": "РЮКЗАК"}
	]:
		var kind := str((section as Dictionary).get("kind", ""))
		var cards: Array = _catalog.items_of(kind)
		if cards.is_empty():
			continue
		var title := ShopTheme.label(str((section as Dictionary).get("label", kind)), 13, ShopTheme.GOLD)
		_sections.add_child(title)
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 9)
		grid.add_theme_constant_override("v_separation", 9)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sections.add_child(grid)
		for value: Variant in cards:
			var item: Dictionary = value
			var id := str(item.get("id", ""))
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(392, 0)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_theme_stylebox_override("panel", ShopTheme.panel_style("101820", ShopTheme.SLOT_BORDER, 8))
			grid.add_child(card)
			var padding := ShopTheme.margins(9)
			card.add_child(padding)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 9)
			padding.add_child(row)
			var badge: Control
			if kind == "weapon":
				var image := ShopTheme.picture(BADGE_HEIGHT)
				image.custom_minimum_size.x = 96
				image.texture = _textures.get(id)
				badge = image
			else:
				var frame := PanelContainer.new()
				frame.custom_minimum_size = Vector2(52, BADGE_HEIGHT)
				frame.add_theme_stylebox_override("panel", ShopTheme.slot_style("161e26", _tint(id), 1, 6))
				badge = frame
				var glyph := ShopTheme.label(_catalog.icon(id), 24)
				glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				frame.add_child(glyph)
			row.add_child(badge)
			var body := VBoxContainer.new()
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_theme_constant_override("separation", 2)
			body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(body)
			body.add_child(ShopTheme.label(_catalog.display_name(id), 13, ShopTheme.TEXT))
			var detail := ShopTheme.label("", 11, ShopTheme.DIM)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(detail)
			var action := ShopTheme.button("Надеть", 12)
			action.custom_minimum_size = Vector2(104, 30)
			action.visible = false
			action.pressed.connect(func() -> void: _on_card_action(id))
			row.add_child(action)
			_cards[id] = {"card": card, "detail": detail, "action": action, "kind": kind}
			_order.append(id)

## Renders the real stock: owned guns, vest state and backpack counts.
func refresh(stock: Dictionary, status_text: String = "", status_color: String = "") -> void:
	if _modal == null:
		return
	var weapons: Array = stock.get("weapons", [])
	var armor: Dictionary = stock.get("armor", {})
	var consumables: Dictionary = stock.get("consumables", {})
	_worn = str(stock.get("worn", ""))
	var bag_parts := PackedStringArray()
	bag_parts.append("оружие: %d" % weapons.size())
	var armor_text := "нет"
	if not _worn.is_empty():
		var worn_row: Dictionary = armor.get(_worn, {})
		armor_text = "%s %d/%d" % [_catalog.display_name(_worn), int(worn_row.get("ap", 0)), int(worn_row.get("max", 0))]
	bag_parts.append("броня: " + armor_text)
	var carried := 0
	for card: Variant in _catalog.items_of("consumable"):
		carried += int(consumables.get(str((card as Dictionary).get("id", "")), 0))
	bag_parts.append("расход: %d" % carried)
	_summary.text = " · ".join(bag_parts)
	for id: String in _cards:
		var entry: Dictionary = _cards[id]
		var detail := entry.detail as Label
		var action := entry.action as Button
		var has := false
		var label_text := ""
		action.visible = false
		if str(entry.kind) == "weapon":
			has = weapons.has(id)
			var reserve := int((stock.get("reserves", {}) as Dictionary).get(id, 0))
			label_text = "В АРСЕНАЛЕ · патроны %s · Q — взять в руки" % _thousands(reserve) if has else "не куплено"
		elif str(entry.kind) == "ammo":
			var ammo_row: Dictionary = (stock.get("ammo", {}) as Dictionary).get(id, {})
			has = int(ammo_row.get("owned_guns", 0)) > 0
			if has:
				label_text = "в стволах %s патронов" % _thousands(int(ammo_row.get("total", 0)))
			else:
				label_text = "нет ствола под калибр"
		elif str(entry.kind) == "armor":
			var row: Dictionary = armor.get(id, {})
			has = not row.is_empty()
			if row.is_empty():
				label_text = "не куплено"
			elif bool(row.get("broken", false)):
				label_text = "РАЗБИТА 0/%d · купи новую в лавке" % int(row.get("max", 0))
			elif _worn == id:
				label_text = "НАДЕТО %d/%d брони" % [int(row.get("ap", 0)), int(row.get("max", 0))]
				action.text = "Снять"
				action.visible = true
			else:
				label_text = "в запасе %d/%d брони" % [int(row.get("ap", 0)), int(row.get("max", 0))]
				action.text = "Надеть"
				action.visible = true
		else:
			var count := int(consumables.get(id, 0))
			has = count > 0
			label_text = "%d шт. из %d" % [count, _catalog.limit(id)]
		detail.text = label_text
		detail.add_theme_color_override("font_color", Color(ShopTheme.GOOD if has else ShopTheme.DISABLED_TEXT))
		(entry.card as PanelContainer).add_theme_stylebox_override("panel", ShopTheme.slot_style("101820", ShopTheme.SLOT_OWNED_BORDER if has else ShopTheme.SLOT_BORDER, 2 if has else 1, 8))
	set_status(status_text, status_color)

func open_inventory() -> void:
	if _modal == null:
		return
	_open = true
	visible = true
	_apply_layout(get_viewport_rect().size)

func close_inventory() -> void:
	_open = false
	visible = false

func is_open() -> bool:
	return _open

func set_status(text: String, color: String = "") -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", Color(color if not color.is_empty() else ShopTheme.DIM))

func _on_card_action(item_id: String) -> void:
	if _catalog.kind(item_id) != "armor":
		return
	if _worn == item_id:
		unequip_requested.emit()
		return
	equip_requested.emit(item_id)

func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	if view != _last_view:
		_apply_layout(view)

func _apply_layout(view: Vector2) -> void:
	if _modal == null or view.x <= 0.0 or view.y <= 0.0:
		return
	_last_view = view
	var width: float = minf(MODAL_MAX.x, view.x - 32.0)
	var height: float = minf(MODAL_MAX.y, view.y - 32.0)
	_modal.size = Vector2(width, height)
	_modal.position = Vector2((view.x - width) * 0.5, (view.y - height) * 0.5)
	var columns: int = 1 if width < 820.0 else COLUMNS
	for id: String in _cards:
		var card: PanelContainer = _cards[id].card
		card.custom_minimum_size.x = (width - 60.0 - float(columns - 1) * 9.0) / float(columns)
		var grid: GridContainer = card.get_parent() as GridContainer
		if grid != null:
			grid.columns = columns

func _on_backdrop(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_requested.emit()

func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = " " + grouped
	return ("-" if value < 0 else "") + grouped

func _tint(id: String) -> String:
	if _catalog.kind(id) == "armor":
		return _catalog.armor_color(id)
	return ShopTheme.SLOT_BORDER
