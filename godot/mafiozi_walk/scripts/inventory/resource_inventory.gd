extends CanvasLayer
## Mouse-driven castle resource inventory. Q remains exclusively weapon selection.

const ResourceItemIcon = preload("res://scripts/inventory/resource_item_icon.gd")
const ResourceItemCard = preload("res://scripts/inventory/resource_item_card.gd")
const ResourceDiscardIcon = preload("res://scripts/inventory/resource_discard_icon.gd")
const CATALOG := {
	"wood": {
		"title":"Древесина", "subtitle":"Брёвна", "category":"МАТЕРИАЛ",
		"description":"Прочные брёвна для строительства, ремонта укреплений и изготовления предметов. Добываются рубкой деревьев; каждое поднятое полено добавляет одну единицу.",
		"icon":"wood"
	}
}

var _counts := {"wood":0}
var _overlay: Control
var _window: PanelContainer
var _grid: GridContainer
var _detail_icon: Control
var _detail_title: Label
var _detail_category: Label
var _detail_count: Label
var _detail_description: Label
var _item_buttons: Dictionary = {}
var _selected := "wood"
var _player: CharacterBody3D
var _weapon_host: Node
var _drop_handler: Callable
var _drop_in_progress:=false
var _toast_root: Control
var _toast_panels: Array[PanelContainer] = []
var _toast_move_tweens: Dictionary = {}
var _toast_fade_tweens: Dictionary = {}
var _toast_panel: PanelContainer
var _toast_label: Label
var _discard_popup: PopupPanel
var _discard_button: Button
var _discard_slider: HSlider
var _discard_amount_label: Label
var _discard_resource := ""
var _ready_for_play := false

func install(player: CharacterBody3D = null, weapon_host: Node = null) -> Dictionary:
	if _ready_for_play: return snapshot()
	_player=player; _weapon_host=weapon_host; layer=28
	process_mode=Node.PROCESS_MODE_ALWAYS
	_build_window(); _ready_for_play=true; _refresh()
	return {"ok":true,"key":"B","resources":CATALOG.keys(),"modal":true}

func add_resource(id: String,amount: int) -> bool:
	if not _ready_for_play or not CATALOG.has(id) or amount<=0: return false
	_counts[id]=int(_counts.get(id,0))+amount; _refresh(); _show_toast("+%d %s" % [amount, CATALOG[id].title],true); return true

func bind_drop_handler(handler: Callable) -> bool:
	if not handler.is_valid(): return false
	_drop_handler=handler; return true

func count(id: String) -> int: return int(_counts.get(id,0))
func is_open() -> bool: return is_instance_valid(_overlay) and _overlay.visible
func snapshot() -> Dictionary: return {"ok":_ready_for_play,"open":is_open(),"wood":count("wood"),"selected":_selected}

func open_window() -> bool:
	if not _ready_for_play or is_open(): return false
	if is_instance_valid(_weapon_host):
		if _weapon_host.has_method("set_menu"): _weapon_host.call("set_menu",false)
		if _weapon_host.has_method("cancel_inputs"): _weapon_host.call("cancel_inputs")
	if is_instance_valid(_player):
		_player.velocity.x=0.0
		_player.velocity.z=0.0
	_overlay.visible=true; _select_item(_selected)
	if is_instance_valid(_player) and _player.has_method("set_mouse_captured"): _player.call("set_mouse_captured",false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var button: Button=_item_buttons.get(_selected)
	if is_instance_valid(button): button.grab_focus()
	return true

func close_window(capture_mouse: bool = true) -> bool:
	if not is_open(): return false
	_hide_discard_popup()
	_overlay.visible=false
	if is_instance_valid(_weapon_host) and _weapon_host.has_method("cancel_inputs"): _weapon_host.call("cancel_inputs")
	if capture_mouse and is_instance_valid(_player) and _player.has_method("set_mouse_captured"): _player.call("set_mouse_captured",true)
	return true

func window_input(event: InputEvent) -> bool:
	if not is_open(): return false
	if event is InputEventKey:
		var key:=event as InputEventKey
		if key.pressed and not key.echo:
			var code:=key.physical_keycode if key.physical_keycode!=0 else key.keycode
			if code == KEY_Q:
				_switch_to_weapons()
			elif code in [KEY_B,KEY_ESCAPE]: close_window(true)
		return true
	return event is InputEventMouseButton or event is InputEventMouseMotion

func _input(event: InputEvent) -> void:
	if not _ready_for_play or not event is InputEventKey: return
	var key:=event as InputEventKey
	if not key.pressed or key.echo: return
	var code:=key.physical_keycode if key.physical_keycode!=0 else key.keycode
	if code==KEY_Q and is_open():
		_switch_to_weapons()
		get_viewport().set_input_as_handled()
	elif code==KEY_B:
		if is_open(): close_window(true)
		else: open_window()
		get_viewport().set_input_as_handled()
	elif code==KEY_ESCAPE and is_open():
		close_window(true); get_viewport().set_input_as_handled()

func _build_window() -> void:
	_build_toast()
	_overlay=Control.new(); _overlay.name="ResourceInventoryOverlay"; _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter=Control.MOUSE_FILTER_STOP; _overlay.visible=false; add_child(_overlay)
	var shade:=ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color=Color(0.008,0.012,0.014,0.72); shade.mouse_filter=Control.MOUSE_FILTER_STOP; _overlay.add_child(shade)
	_window=PanelContainer.new(); _window.name="ResourceInventoryWindow"; _window.set_anchors_preset(Control.PRESET_CENTER); _window.position=Vector2(-455,-270); _window.custom_minimum_size=Vector2(910,540); _window.add_theme_stylebox_override("panel",_style(Color("151b1c"),Color("bd934e"),14,2)); _overlay.add_child(_window)
	var outer:=VBoxContainer.new(); outer.add_theme_constant_override("separation",12); _window.add_child(outer)
	var header:=HBoxContainer.new(); outer.add_child(header)
	var heading:=VBoxContainer.new(); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(heading)
	var title:=Label.new(); title.text="ИНВЕНТАРЬ"; title.add_theme_font_size_override("font_size",29); title.modulate=Color("f0d188"); heading.add_child(title)
	var subtitle:=Label.new(); subtitle.text="РЕСУРСЫ И МАТЕРИАЛЫ"; subtitle.add_theme_font_size_override("font_size",13); subtitle.modulate=Color("879592"); heading.add_child(subtitle)
	var close:=Button.new(); close.name="CloseButton"; close.text="×"; close.tooltip_text="Закрыть"; close.custom_minimum_size=Vector2(46,46); close.add_theme_font_size_override("font_size",28); close.pressed.connect(close_window.bind(true)); header.add_child(close)
	outer.add_child(HSeparator.new())
	var body:=HBoxContainer.new(); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",18); outer.add_child(body)
	var left:=VBoxContainer.new(); left.custom_minimum_size=Vector2(525,0); left.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_child(left)
	var section:=Label.new(); section.text="МАТЕРИАЛЫ"; section.add_theme_font_size_override("font_size",15); section.modulate=Color("aab6b2"); left.add_child(section)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; left.add_child(scroll)
	_grid=GridContainer.new(); _grid.columns=3; _grid.add_theme_constant_override("h_separation",12); _grid.add_theme_constant_override("v_separation",12); scroll.add_child(_grid)
	for id: String in CATALOG.keys(): _add_item_card(id)
	for empty_index in 5: _add_empty_slot()
	body.add_child(VSeparator.new())
	var detail:=VBoxContainer.new(); detail.custom_minimum_size=Vector2(290,0); detail.add_theme_constant_override("separation",10); body.add_child(detail)
	var icon_frame:=PanelContainer.new(); icon_frame.custom_minimum_size=Vector2(0,176); icon_frame.add_theme_stylebox_override("panel",_style(Color("202728"),Color("53605d"),10,1)); detail.add_child(icon_frame)
	_detail_icon=ResourceItemIcon.new(); _detail_icon.custom_minimum_size=Vector2(220,150); icon_frame.add_child(_detail_icon)
	_detail_category=Label.new(); _detail_category.add_theme_font_size_override("font_size",12); _detail_category.modulate=Color("bd934e"); detail.add_child(_detail_category)
	_detail_title=Label.new(); _detail_title.add_theme_font_size_override("font_size",24); _detail_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.add_child(_detail_title)
	_detail_count=Label.new(); _detail_count.add_theme_font_size_override("font_size",18); _detail_count.modulate=Color("e8ca82"); detail.add_child(_detail_count)
	_detail_description=Label.new(); _detail_description.add_theme_font_size_override("font_size",15); _detail_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _detail_description.size_flags_vertical=Control.SIZE_EXPAND_FILL; _detail_description.modulate=Color("bdc7c3"); detail.add_child(_detail_description)
	var hint:=Label.new(); hint.text="ПКМ — выбросить   •   Q — оружие   •   B / Esc — закрыть"; hint.add_theme_font_size_override("font_size",14); hint.modulate=Color("899592"); outer.add_child(hint)
	_build_discard_popup()

func _add_item_card(id: String) -> void:
	var item: Dictionary=CATALOG[id]
	var card:=ResourceItemCard.new(); card.configure(id,_window); card.name="Item_%s"%id; card.toggle_mode=true; card.custom_minimum_size=Vector2(162,178); card.text="\n\n\n%s\n× %d"%[str(item.title),count(id)]; card.alignment=HORIZONTAL_ALIGNMENT_CENTER; card.add_theme_font_size_override("font_size",17); card.add_theme_stylebox_override("normal",_style(Color("202829"),Color("485552"),9,1)); card.add_theme_stylebox_override("hover",_style(Color("293333"),Color("d0a65b"),9,2)); card.add_theme_stylebox_override("pressed",_style(Color("2c3431"),Color("e4bd6b"),9,2)); card.add_theme_stylebox_override("focus",_style(Color("293333"),Color("e4bd6b"),9,2)); card.pressed.connect(_select_item.bind(id)); card.drop_outside.connect(_drop_resource); card.context_requested.connect(_show_discard_popup); _grid.add_child(card)
	var icon:=ResourceItemIcon.new(); icon.position=Vector2(18,8); icon.size=Vector2(126,92); icon.set_kind(str(item.icon)); card.add_child(icon); _item_buttons[id]=card

func _add_empty_slot() -> void:
	var slot:=PanelContainer.new(); slot.custom_minimum_size=Vector2(162,178); slot.mouse_filter=Control.MOUSE_FILTER_IGNORE; slot.add_theme_stylebox_override("panel",_style(Color("121718"),Color("303938"),9,1)); _grid.add_child(slot)
	var label:=Label.new(); label.text="ПУСТО"; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.modulate=Color("414c49"); slot.add_child(label)

func _select_item(id: String) -> void:
	if not CATALOG.has(id): return
	_selected=id; var item: Dictionary=CATALOG[id]
	_detail_icon.set_kind(str(item.icon)); _detail_category.text=str(item.category); _detail_title.text="%s · %s"%[str(item.title),str(item.subtitle)]; _detail_count.text="В наличии: %d"%count(id); _detail_description.text=str(item.description)
	for key: String in _item_buttons:
		var button: Button=_item_buttons[key]; button.button_pressed=key==id

func _refresh() -> void:
	for id: String in _item_buttons:
		var item: Dictionary=CATALOG[id]; var card: Button=_item_buttons[id]; card.text="\n\n\n%s\n× %d"%[str(item.title),count(id)]; card.call("set_available",count(id))
	if CATALOG.has(_selected): _select_item(_selected)

func _drop_resource(id: String,drag_amount: int) -> bool:
	if _drop_in_progress or not is_open() or drag_amount<=0 or drag_amount>count(id): return false
	if not _drop_handler.is_valid() or not is_instance_valid(_player): return false
	_drop_in_progress=true
	var forward:=-_player.global_basis.z
	var visual: Variant=_player.get("_visual")
	if is_instance_valid(visual): forward=-(visual as Node3D).global_basis.z
	forward.y=0.0
	if forward.length_squared()<0.01: forward=Vector3.FORWARD
	var result: Variant=_drop_handler.call(id,drag_amount,_player.global_position,forward.normalized())
	var success:=result is Dictionary and bool(result.get("ok",false)) and int(result.get("accepted",0))==drag_amount
	if success:
		_counts[id]=count(id)-drag_amount; _refresh(); _show_toast("−%d  ВЫБРОШЕНО"%drag_amount,false)
	_drop_in_progress=false
	return success

func _build_discard_popup() -> void:
	_discard_popup = PopupPanel.new()
	_discard_popup.name = "ResourceContextMenu"
	_discard_popup.transparent_bg = true
	_discard_popup.popup_hide.connect(_discard_popup_closed)
	_discard_popup.add_theme_stylebox_override("panel", _style(Color("171d1deb"), Color("b9914f"), 7, 1))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_discard_popup.add_child(content)
	_discard_amount_label = Label.new()
	_discard_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_amount_label.add_theme_font_size_override("font_size", 12)
	_discard_amount_label.modulate = Color("b9c2bd")
	content.add_child(_discard_amount_label)
	_discard_slider = HSlider.new()
	_discard_slider.min_value = 1
	_discard_slider.step = 1
	_discard_slider.rounded = true
	_discard_slider.custom_minimum_size = Vector2(188, 20)
	_discard_slider.value_changed.connect(_update_discard_amount)
	content.add_child(_discard_slider)
	_discard_button = Button.new()
	_discard_button.name = "DiscardOne"
	_discard_button.text = "      Выбросить"
	_discard_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_discard_button.custom_minimum_size = Vector2(188, 34)
	_discard_button.add_theme_font_size_override("font_size", 14)
	_discard_button.add_theme_color_override("font_color", Color("ead9ad"))
	_discard_button.add_theme_color_override("font_hover_color", Color("fff0bd"))
	_discard_button.add_theme_stylebox_override("normal", _style(Color("171d1d"), Color("3f4946"), 6, 0))
	_discard_button.add_theme_stylebox_override("hover", _style(Color("28302e"), Color("c69b51"), 6, 1))
	_discard_button.pressed.connect(_discard_one)
	content.add_child(_discard_button)
	var icon := ResourceDiscardIcon.new()
	icon.position = Vector2(11, 9)
	_discard_button.add_child(icon)
	add_child(_discard_popup)

func _show_discard_popup(id: String, screen_position: Vector2) -> void:
	if not is_open() or not CATALOG.has(id) or count(id) <= 0: return
	_select_item(id)
	_discard_resource = id
	var viewport_size := get_viewport().get_visible_rect().size
	_discard_slider.max_value = count(id)
	_discard_slider.value = 1
	_update_discard_amount(1)
	var menu_size := Vector2(212, 104)
	var position := screen_position + Vector2(8, 6)
	position.x = clampf(position.x, 6.0, viewport_size.x - menu_size.x - 6.0)
	position.y = clampf(position.y, 6.0, viewport_size.y - menu_size.y - 6.0)
	_discard_popup.popup(Rect2i(Vector2i(position), Vector2i(menu_size)))
	_discard_button.grab_focus()

func _hide_discard_popup() -> void:
	_discard_resource = ""
	if is_instance_valid(_discard_popup): _discard_popup.hide()

func _discard_one() -> void:
	var id := _discard_resource
	var amount := mini(count(id), roundi(_discard_slider.value)) if is_instance_valid(_discard_slider) else 1
	if id.is_empty() or amount <= 0: return
	_discard_button.disabled = true
	var accepted := _drop_resource(id, amount)
	_discard_button.disabled = false
	if accepted: _hide_discard_popup()

func _update_discard_amount(value: float) -> void:
	if not is_instance_valid(_discard_button): return
	var amount := maxi(1, roundi(value))
	_discard_amount_label.text = "Количество  %d / %d" % [amount, count(_discard_resource)]
	_discard_button.text = "      Выбросить ×%d" % amount

func _discard_popup_closed() -> void:
	# PopupPanel can deliver popup_hide on the following frame.  If the player
	# already reopened the same menu, do not erase the new live selection.
	if not is_instance_valid(_discard_popup) or not _discard_popup.visible:
		_discard_resource = ""

func _switch_to_weapons() -> void:
	if not is_open(): return
	close_window(false)
	if is_instance_valid(_weapon_host) and _weapon_host.has_method("set_menu"):
		_weapon_host.call("set_menu", true)

func _build_toast() -> void:
	_toast_root = Control.new()
	_toast_root.name = "ResourceToasts"
	_toast_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_root)

func _show_toast(text: String, positive: bool) -> void:
	if not is_instance_valid(_toast_root): return
	for existing: PanelContainer in _toast_panels:
		if is_instance_valid(existing):
			var key := existing.get_instance_id()
			var previous_move: Tween = _toast_move_tweens.get(key)
			if previous_move != null and previous_move.is_valid(): previous_move.kill()
			var target_y := float(existing.get_meta("target_y", existing.position.y)) - 24.0
			existing.set_meta("target_y", target_y)
			var move := create_tween().bind_node(existing)
			move.tween_property(existing, "position:y", target_y, 0.12).set_trans(Tween.TRANS_SINE)
			_toast_move_tweens[key] = move
	while _toast_panels.size() >= 5:
		var oldest: PanelContainer = _toast_panels.pop_front()
		if is_instance_valid(oldest):
			_clear_toast_tweens(oldest, true)
			oldest.queue_free()
	var panel := PanelContainer.new()
	panel.name = "ResourceToast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -65
	panel.offset_right = 65
	panel.offset_top = -125
	panel.offset_bottom = -103
	var frame := _style(Color("151b1ce8"), Color("70825e") if positive else Color("98744e"), 5, 1)
	frame.content_margin_left = 8
	frame.content_margin_right = 8
	frame.content_margin_top = 2
	frame.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", frame)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color("d8e9c5") if positive else Color("f0d1a6")
	panel.add_child(label)
	_toast_root.add_child(panel)
	panel.set_meta("target_y", panel.position.y)
	_toast_panels.append(panel)
	_toast_panel = panel
	_toast_label = label
	var tween := create_tween().bind_node(panel)
	tween.tween_property(panel, "modulate:a", 0.0, 0.40).set_delay(0.82)
	tween.tween_callback(_finish_toast.bind(panel))
	_toast_fade_tweens[panel.get_instance_id()] = tween

func _finish_toast(panel: PanelContainer) -> void:
	_toast_panels.erase(panel)
	if is_instance_valid(panel):
		_clear_toast_tweens(panel)
		panel.queue_free()

func _clear_toast_tweens(panel: PanelContainer, kill_fade := false) -> void:
	var key := panel.get_instance_id()
	var move: Tween = _toast_move_tweens.get(key)
	if move != null and move.is_valid(): move.kill()
	var fade: Tween = _toast_fade_tweens.get(key)
	if kill_fade and fade != null and fade.is_valid(): fade.kill()
	_toast_move_tweens.erase(key)
	_toast_fade_tweens.erase(key)

func _style(background: Color,border: Color,radius: int,width: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=background; style.border_color=border; style.set_border_width_all(width); style.set_corner_radius_all(radius); style.content_margin_left=18; style.content_margin_right=18; style.content_margin_top=14; style.content_margin_bottom=14; return style
