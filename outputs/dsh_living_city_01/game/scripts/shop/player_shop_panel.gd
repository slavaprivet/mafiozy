extends Control
## Goods window of the shop: tabs (оружие / броня / расход), a slot grid on the
## left and the card of the chosen good on the right — the same card language the
## Q arsenal already uses (thumbnail, name, detail line, state). The window never
## spends money: it asks the host for one action and then renders the answer.
signal close_requested
signal purchase_requested(item_id: String)
signal equip_requested(item_id: String)
signal unequip_requested
const ShopTheme = preload("res://scripts/shop/player_shop_theme.gd")
const KIND_WEAPON := "weapon"
const KIND_AMMO := "ammo"
const KIND_ARMOR := "armor"
const KIND_CONSUMABLE := "consumable"
const COLUMNS_WIDE := 3
const COLUMNS_NARROW := 2
const MODAL_MAX := Vector2(1060, 748)
const CARD_IMAGE_HEIGHT := 104.0
const SLOT_IMAGE_HEIGHT := 82.0
var _catalog: RefCounted
var _textures: Dictionary = {}
var _modal: PanelContainer
var _title: Label
var _cash: Label
var _backpack: Label
var _tabs: HBoxContainer
var _tab_buttons: Dictionary = {}
var _grid: GridContainer
var _scroll: ScrollContainer
var _card_picture: TextureRect
var _card_badge: PanelContainer
var _card_badge_text: Label
var _card_name: Label
var _card_desc: Label
var _card_stats: Label
var _card_price: Label
var _card_note: Label
var _buy: Button
var _status: Label
var _slots: Dictionary = {}
var _order: Array = []
var _selected := ""
var _tab := ""
var _worn := ""
var _primary_action := "buy"
## Last answer of the owner. Selecting another slot re-renders the card from it,
## so the buy button can never show the price of the previously selected good.
var _wallet_cache: RefCounted
var _stock_cache: Dictionary = {}
var _open := false
var _last_view := Vector2.ZERO

func build(catalog: RefCounted, textures: Dictionary) -> void:
	name = "PlayerShopWindow"
	_catalog = catalog
	_textures = textures
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
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
	column.add_child(_build_header())
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	column.add_child(_tabs)
	_build_tabs()
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS_WIDE
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 9)
	_grid.add_theme_constant_override("v_separation", 9)
	_scroll.add_child(_grid)
	body.add_child(_build_card())
	_status = ShopTheme.label("", 12, ShopTheme.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_build_slots()
	gui_input.connect(_on_backdrop)
	var tabs: Array = _catalog.tabs()
	_tab = str((tabs[0] as Dictionary).get("kind", "")) if not tabs.is_empty() else ""
	_apply_tab()

func _build_header() -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var icon := ShopTheme.label("🔫", 22)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(copy)
	_title = ShopTheme.label("", 18, ShopTheme.GOLD)
	copy.add_child(_title)
	_cash = ShopTheme.label("", 12, ShopTheme.MONEY)
	copy.add_child(_cash)
	_backpack = ShopTheme.label("", 11, ShopTheme.DIM)
	_backpack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_backpack)
	var close := ShopTheme.button("×", 15)
	close.custom_minimum_size = Vector2(34, 34)
	close.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close)
	return head

func _build_tabs() -> void:
	for tab: Variant in _catalog.tabs():
		var kind := str((tab as Dictionary).get("kind", ""))
		var button := ShopTheme.button(str((tab as Dictionary).get("label", kind)), 12)
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: select_tab(kind))
		_tabs.add_child(button)
		_tab_buttons[kind] = button

func _build_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(312, 0)
	card.add_theme_stylebox_override("panel", ShopTheme.panel_style("101820", ShopTheme.SLOT_BORDER, 8))
	var padding := ShopTheme.margins(12)
	card.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	padding.add_child(column)
	_card_picture = ShopTheme.picture(CARD_IMAGE_HEIGHT)
	column.add_child(_card_picture)
	_card_badge = PanelContainer.new()
	_card_badge.custom_minimum_size = Vector2(0, CARD_IMAGE_HEIGHT)
	_card_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_badge.visible = false
	_card_badge.add_theme_stylebox_override("panel", ShopTheme.slot_style("161e26", ShopTheme.SLOT_BORDER, 1, 6))
	column.add_child(_card_badge)
	_card_badge_text = ShopTheme.label("", 40)
	_card_badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_badge.add_child(_card_badge_text)
	_card_name = ShopTheme.label("", 16, ShopTheme.GOLD)
	_card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_card_name)
	_card_desc = ShopTheme.label("", 12, ShopTheme.TEXT)
	_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_desc.custom_minimum_size = Vector2(0, 48)
	column.add_child(_card_desc)
	_card_stats = ShopTheme.label("", 11, ShopTheme.DIM)
	_card_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_stats.custom_minimum_size = Vector2(0, 46)
	column.add_child(_card_stats)
	_card_price = ShopTheme.label("", 16, ShopTheme.MONEY)
	column.add_child(_card_price)
	_buy = ShopTheme.button("Купить", 14)
	_buy.custom_minimum_size = Vector2(0, 42)
	_buy.add_theme_stylebox_override("normal", ShopTheme.primary_style())
	_buy.pressed.connect(_on_primary_pressed)
	column.add_child(_buy)
	_card_note = ShopTheme.label("", 11, ShopTheme.DIM)
	_card_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_card_note)
	return card

func _build_slots() -> void:
	for value: Variant in _catalog.items():
		var item: Dictionary = value
		var id := str(item.get("id", ""))
		var kind := str(item.get("kind", ""))
		var slot := ShopTheme.button("", 12)
		slot.custom_minimum_size = Vector2(198, 154)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.pressed.connect(func() -> void: select(id))
		_grid.add_child(slot)
		var inner := ShopTheme.margins(9)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(inner)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(content)
		var image: TextureRect = null
		var badge: PanelContainer = null
		var badge_text: Label = null
		if kind == KIND_WEAPON:
			image = ShopTheme.picture(SLOT_IMAGE_HEIGHT)
			image.texture = _textures.get(id)
			content.add_child(image)
		else:
			badge = PanelContainer.new()
			badge.custom_minimum_size = Vector2(0, SLOT_IMAGE_HEIGHT)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_stylebox_override("panel", ShopTheme.slot_style("161e26", ShopTheme.SLOT_BORDER, 1, 6))
			content.add_child(badge)
			badge_text = ShopTheme.label(_catalog.icon(id), 34)
			badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(badge_text)
		var caption := ShopTheme.label(_catalog.display_name(id), 12, ShopTheme.TEXT)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size = Vector2(0, 30)
		content.add_child(caption)
		var state := ShopTheme.label("", 12, ShopTheme.MONEY)
		content.add_child(state)
		_slots[id] = {
			"button": slot, "image": image, "badge": badge, "badge_text": badge_text,
			"name": caption, "state": state, "kind": kind
		}
		_order.append(id)

func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	if view == _last_view:
		return
	_apply_layout(view)

## The window is centred and re-flowed from the real viewport size, so it fits a
## 1280x720 sandbox window and a narrow one alike.
func _apply_layout(view: Vector2) -> void:
	if _modal == null or view.x <= 0.0 or view.y <= 0.0:
		return
	_last_view = view
	var width: float = minf(MODAL_MAX.x, view.x - 32.0)
	var height: float = minf(MODAL_MAX.y, view.y - 32.0)
	_modal.size = Vector2(width, height)
	_modal.position = Vector2((view.x - width) * 0.5, (view.y - height) * 0.5)
	var columns: int = COLUMNS_NARROW if width < 840.0 else COLUMNS_WIDE
	_grid.columns = columns
	var slot_width: float = maxf(140.0, (width - 372.0 - float(columns - 1) * 9.0) / float(columns))
	for id: String in _slots:
		(_slots[id].button as Button).custom_minimum_size.x = slot_width

func open_shop() -> void:
	if _modal == null:
		return
	_open = true
	visible = true
	_apply_layout(get_viewport_rect().size)
	_title.text = _catalog.title()
	if not _selected.is_empty() and _slots.has(_selected):
		select(_selected)
	else:
		var first := _first_visible()
		if not first.is_empty():
			select(first)
	_focus_selected()

func close_shop() -> void:
	_open = false
	visible = false

func is_open() -> bool:
	return _open

func selected_id() -> String:
	return _selected

func current_tab() -> String:
	return _tab

func select_tab(kind: String) -> void:
	if kind.is_empty():
		return
	_tab = kind
	_apply_tab()

func _apply_tab() -> void:
	for kind: String in _tab_buttons:
		var button: Button = _tab_buttons[kind]
		var active: bool = kind == _tab
		button.add_theme_stylebox_override("normal", ShopTheme.slot_style(
			"3a1838" if active else ShopTheme.SLOT_BG,
			ShopTheme.PANEL_BORDER if active else ShopTheme.SLOT_BORDER, 1, 5))
		button.add_theme_color_override("font_color", Color(ShopTheme.TEXT if active else ShopTheme.DIM))
	for id: String in _slots:
		var slot: Dictionary = _slots[id]
		(slot.button as Button).visible = str(slot.kind) == _tab
	var current_kind := str(_slots[_selected].kind) if _slots.has(_selected) else ""
	if current_kind != _tab:
		var first := _first_visible()
		if not first.is_empty():
			select(first)

func _first_visible() -> String:
	for id: String in _order:
		if str(_slots[id].kind) == _tab:
			return id
	return ""

func select(id: String) -> void:
	if not _slots.has(id):
		return
	if str(_slots[id].kind) != _tab:
		select_tab(str(_slots[id].kind))
	_selected = id
	var item: Dictionary = _catalog.item(id)
	var kind := str(item.get("kind", ""))
	_card_name.text = _catalog.display_name(id)
	_card_desc.text = _catalog.desc(id)
	_card_stats.text = _catalog.stats(id)
	_card_price.text = "%d $" % int(item.get("price", 0))
	if kind == KIND_WEAPON:
		_card_picture.visible = true
		_card_picture.texture = _textures.get(id)
		_card_badge.visible = false
	else:
		_card_picture.visible = false
		_card_badge.visible = true
		_card_badge_text.text = _catalog.icon(id)
		var tint := Color(_catalog.armor_color(id)) if kind == KIND_ARMOR else Color(ShopTheme.MONEY)
		_card_badge.add_theme_stylebox_override("panel", ShopTheme.slot_style("161e26", tint.to_html(false), 2, 6))
	(_slots[id].button as Button).add_theme_stylebox_override("normal", ShopTheme.slot_style(ShopTheme.SLOT_HOVER_BG, ShopTheme.PANEL_BORDER, 2, 5))
	# The button state belongs to the last owner answer; without this the price of
	# the previously selected good would stay on the button.
	if _wallet_cache != null:
		_refresh_card(_wallet_cache, _stock_cache)

## Arrow keys move the highlight; the host forwards keys the GUI does not own, so
## keyboard and mouse always select the same slot.
func move_selection(step: int) -> void:
	_move_by(step)

func move_selection_row(step: int) -> void:
	if _order.is_empty():
		return
	var columns: int = _grid.columns if _grid != null else COLUMNS_WIDE
	_move_by(step * columns)

func _move_by(step: int) -> void:
	if step == 0:
		return
	var visible_ids: Array = []
	for id: String in _order:
		if str(_slots[id].kind) == _tab:
			visible_ids.append(id)
	if visible_ids.is_empty():
		return
	var index: int = visible_ids.find(_selected)
	if index < 0:
		index = 0
	var next: int = clampi(index + step, 0, visible_ids.size() - 1)
	select(str(visible_ids[next]))
	_focus_selected()

func activate_selected() -> void:
	if _buy != null and not _buy.disabled:
		_on_primary_pressed()

func set_status(text: String, color: String = "") -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", Color(color if not color.is_empty() else ShopTheme.DIM))

## Renders one answer of the owner. `stock` is the real state: the arsenal list for
## guns, the backpack for armor and consumables. A bought good can therefore never
## stay "for sale" in the window.
func refresh(wallet: RefCounted, stock: Dictionary, status_text: String = "", status_color: String = "") -> void:
	if _modal == null:
		return
	var weapons: Array = stock.get("weapons", [])
	var armor: Dictionary = stock.get("armor", {})
	var consumables: Dictionary = stock.get("consumables", {})
	_wallet_cache = wallet
	_stock_cache = stock
	_worn = str(stock.get("worn", ""))
	_cash.text = "💰 %s $ · %d товаров" % [_thousands(wallet.cash()), _catalog.item_count()]
	_backpack.text = _backpack_line(stock)
	for id: String in _slots:
		var slot: Dictionary = _slots[id]
		var kind := str(slot.kind)
		var price: int = _catalog.price(id)
		var affordable: bool = wallet.cash() >= price
		var state := slot.state as Label
		var marked := false
		if kind == KIND_WEAPON:
			marked = weapons.has(id)
			if marked:
				state.text = "КУПЛЕНО"
				state.add_theme_color_override("font_color", Color(ShopTheme.GOOD))
			elif affordable:
				state.text = "%s $" % _thousands(price)
				state.add_theme_color_override("font_color", Color(ShopTheme.MONEY))
			else:
				state.text = "%s $ · не хватает" % _thousands(price)
				state.add_theme_color_override("font_color", Color(ShopTheme.BAD))
		elif kind == KIND_AMMO:
			var ammo_row: Dictionary = (stock.get("ammo", {}) as Dictionary).get(id, {})
			var owned_guns := int(ammo_row.get("owned_guns", 0))
			marked = owned_guns > 0 and int(ammo_row.get("total", 0)) > 0
			if owned_guns <= 0:
				state.text = "нет ствола под калибр"
				state.add_theme_color_override("font_color", Color(ShopTheme.BAD))
			elif bool(ammo_row.get("full", false)):
				state.text = "полный запас"
				state.add_theme_color_override("font_color", Color(ShopTheme.DIM))
			else:
				state.text = "в стволах: %s" % _thousands(int(ammo_row.get("total", 0)))
				state.add_theme_color_override("font_color", Color(ShopTheme.MONEY if affordable else ShopTheme.BAD))
		elif kind == KIND_ARMOR:
			var row: Dictionary = armor.get(id, {})
			var worn: bool = _worn == id
			if row.is_empty():
				marked = false
				state.text = "%s $" % _thousands(price) if affordable else "%s $ · не хватает" % _thousands(price)
				state.add_theme_color_override("font_color", Color(ShopTheme.MONEY if affordable else ShopTheme.BAD))
			elif bool(row.get("broken", false)):
				marked = false
				state.text = "РАЗБИТА 0/%d" % int(row.get("max", 0))
				state.add_theme_color_override("font_color", Color(ShopTheme.BAD))
			elif worn:
				marked = true
				state.text = "НАДЕТО %d/%d" % [int(row.get("ap", 0)), int(row.get("max", 0))]
				state.add_theme_color_override("font_color", Color(ShopTheme.GOOD))
			else:
				marked = true
				state.text = "В ЗАПАСЕ %d/%d" % [int(row.get("ap", 0)), int(row.get("max", 0))]
				state.add_theme_color_override("font_color", Color(ShopTheme.DIM))
		else:
			var count_now := int(consumables.get(id, 0))
			var cap: Variant = _catalog.limit(id)
			marked = count_now >= cap
			state.text = "В РЮКЗАКЕ: %d/%d" % [count_now, cap]
			state.add_theme_color_override("font_color", Color(ShopTheme.GOOD if count_now > 0 else ShopTheme.DIM))
		var border := ShopTheme.SLOT_OWNED_BORDER if marked else (ShopTheme.PANEL_BORDER if id == _selected else ShopTheme.SLOT_BORDER)
		var width := 2 if id == _selected else 1
		(slot.button as Button).add_theme_stylebox_override("normal", ShopTheme.slot_style(ShopTheme.SLOT_OWNED_BG if marked else ShopTheme.SLOT_BG, border, width, 5))
	_refresh_card(wallet, stock)
	set_status(status_text, status_color)

func _backpack_line(stock: Dictionary) -> String:
	var parts := PackedStringArray()
	var armor: Dictionary = stock.get("armor", {})
	if not _worn.is_empty() and armor.has(_worn):
		var row: Dictionary = armor[_worn]
		parts.append("🦺 %s %d/%d%s" % [
			_catalog.display_name(_worn),
			int(row.get("ap", 0)),
			int(row.get("max", 0)),
			" (разбита)" if bool(row.get("broken", false)) else ""
		])
	else:
		parts.append("🦺 без брони")
	var consumables: Dictionary = stock.get("consumables", {})
	for card: Variant in _catalog.items_of(KIND_CONSUMABLE):
		var id := str((card as Dictionary).get("id", ""))
		var count_now := int(consumables.get(id, 0))
		if count_now > 0:
			parts.append("%s %d" % [_catalog.icon(id), count_now])
	return "Рюкзак: " + " · ".join(parts)

func _refresh_card(wallet: RefCounted, stock: Dictionary) -> void:
	_primary_action = "buy"
	if not _slots.has(_selected):
		_buy.disabled = true
		_buy.text = "Выбери товар"
		_card_note.text = ""
		return
	var id := _selected
	var kind: Variant = _catalog.kind(id)
	var price: int = _catalog.price(id)
	var affordable: bool = wallet.cash() >= price
	if kind == KIND_WEAPON:
		var owned: bool = (stock.get("weapons", []) as Array).has(id)
		_buy.disabled = owned or not affordable
		if owned:
			_buy.text = "Уже в арсенале"
			_card_note.text = "Ствол лежит в арсенале: клавиша Q — выбрать оружие в руки."
		elif affordable:
			_buy.text = "Купить · %s $" % _thousands(price)
			_card_note.text = "После покупки останется %s $." % _thousands(wallet.cash() - price)
		else:
			_buy.text = "Не хватает %s $" % _thousands(price - wallet.cash())
			_card_note.text = "Цена %s $, у тебя %s $." % [_thousands(price), _thousands(wallet.cash())]
		return
	if kind == KIND_AMMO:
		var ammo_row: Dictionary = (stock.get("ammo", {}) as Dictionary).get(id, {})
		var owned_guns := int(ammo_row.get("owned_guns", 0))
		var full := bool(ammo_row.get("full", false))
		if owned_guns <= 0:
			_buy.disabled = true
			_buy.text = "Нет ствола под калибр"
			_card_note.text = "Патроны лягут в стволы: %s. Сначала купи оружие." % _gun_names(id)
		elif full:
			_buy.disabled = true
			_buy.text = "Полный запас"
			_card_note.text = "В стволах уже %s патронов этого калибра." % _thousands(int(ammo_row.get("total", 0)))
		elif not affordable:
			_buy.disabled = true
			_buy.text = "Не хватает %s $" % _thousands(price - wallet.cash())
			_card_note.text = "Цена %s $, у тебя %s $." % [_thousands(price), _thousands(wallet.cash())]
		else:
			_buy.disabled = false
			_buy.text = "Купить · %s $" % _thousands(price)
			_card_note.text = "В стволы: %s. Сейчас %s патронов." % [_gun_names(id), _thousands(int(ammo_row.get("total", 0)))]
		return
	if kind == KIND_ARMOR:
		var row: Dictionary = (stock.get("armor", {}) as Dictionary).get(id, {})
		if row.is_empty():
			_buy.disabled = not affordable
			_buy.text = "Купить · %s $" % _thousands(price) if affordable else "Не хватает %s $" % _thousands(price - wallet.cash())
			_card_note.text = "Броня надевается поверх одежды и первой принимает урон."
		elif bool(row.get("broken", false)):
			_buy.disabled = not affordable
			_buy.text = "Купить заново · %s $" % _thousands(price) if affordable else "Не хватает %s $" % _thousands(price - wallet.cash())
			_card_note.text = "Жилет разбит (0/%d). Новая покупка восстановит защиту." % int(row.get("max", 0))
		elif _worn == id:
			_buy.disabled = false
			_buy.text = "Снять"
			_primary_action = "unequip"
			_card_note.text = "Надет: %d/%d брони. Жилет виден поверх одежды." % [int(row.get("ap", 0)), int(row.get("max", 0))]
		else:
			_buy.disabled = false
			_buy.text = "Надеть"
			_primary_action = "equip"
			_card_note.text = "В запасе: %d/%d брони." % [int(row.get("ap", 0)), int(row.get("max", 0))]
		return
	var count_now := int((stock.get("consumables", {}) as Dictionary).get(id, 0))
	var cap: Variant = _catalog.limit(id)
	if count_now >= cap:
		_buy.disabled = true
		_buy.text = "Полный рюкзак"
		_card_note.text = "Больше %d шт. не унести." % cap
	elif not affordable:
		_buy.disabled = true
		_buy.text = "Не хватает %s $" % _thousands(price - wallet.cash())
		_card_note.text = "Цена %s $, у тебя %s $." % [_thousands(price), _thousands(wallet.cash())]
	else:
		_buy.disabled = false
		_buy.text = "Купить · %s $" % _thousands(price)
		_card_note.text = "В рюкзаке станет %d из %d." % [count_now + 1, cap]

## Readable list of the guns a box of ammo feeds, for the card note.
func _gun_names(item_id: String) -> String:
	var names := PackedStringArray()
	for gun: String in _catalog.ammo_weapons(item_id):
		names.append(_catalog.display_name(gun))
	return ", ".join(names)

func _on_primary_pressed() -> void:
	if _selected.is_empty():
		return
	match _primary_action:
		"equip":
			equip_requested.emit(_selected)
		"unequip":
			unequip_requested.emit()
		_:
			purchase_requested.emit(_selected)

func _focus_selected() -> void:
	if _slots.has(_selected):
		(_slots[_selected].button as Button).grab_focus()

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
