extends CanvasLayer
## Mouse-driven castle resource inventory. Q remains exclusively weapon selection.

const ResourceItemIcon = preload("res://scripts/inventory/resource_item_icon.gd")
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
var _ready_for_play := false

func install(player: CharacterBody3D = null, weapon_host: Node = null) -> Dictionary:
	if _ready_for_play: return snapshot()
	_player=player; _weapon_host=weapon_host; layer=28
	process_mode=Node.PROCESS_MODE_ALWAYS
	_build_window(); _ready_for_play=true; _refresh()
	return {"ok":true,"key":"B","resources":CATALOG.keys(),"modal":true}

func add_resource(id: String,amount: int) -> bool:
	if not _ready_for_play or not CATALOG.has(id) or amount<=0: return false
	_counts[id]=int(_counts.get(id,0))+amount; _refresh(); return true

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
			if code in [KEY_B,KEY_ESCAPE]: close_window(true)
		return true
	return event is InputEventMouseButton or event is InputEventMouseMotion

func _input(event: InputEvent) -> void:
	if not _ready_for_play or not event is InputEventKey: return
	var key:=event as InputEventKey
	if not key.pressed or key.echo: return
	var code:=key.physical_keycode if key.physical_keycode!=0 else key.keycode
	if code==KEY_B:
		if is_open(): close_window(true)
		else: open_window()
		get_viewport().set_input_as_handled()
	elif code==KEY_ESCAPE and is_open():
		close_window(true); get_viewport().set_input_as_handled()

func _build_window() -> void:
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
	var hint:=Label.new(); hint.text="B / Esc — закрыть   •   E — поднять одно полено"; hint.add_theme_font_size_override("font_size",14); hint.modulate=Color("899592"); outer.add_child(hint)

func _add_item_card(id: String) -> void:
	var item: Dictionary=CATALOG[id]
	var card:=Button.new(); card.name="Item_%s"%id; card.toggle_mode=true; card.custom_minimum_size=Vector2(162,178); card.text="\n\n\n%s\n× %d"%[str(item.title),count(id)]; card.alignment=HORIZONTAL_ALIGNMENT_CENTER; card.add_theme_font_size_override("font_size",17); card.add_theme_stylebox_override("normal",_style(Color("202829"),Color("485552"),9,1)); card.add_theme_stylebox_override("hover",_style(Color("293333"),Color("d0a65b"),9,2)); card.add_theme_stylebox_override("pressed",_style(Color("2c3431"),Color("e4bd6b"),9,2)); card.add_theme_stylebox_override("focus",_style(Color("293333"),Color("e4bd6b"),9,2)); card.pressed.connect(_select_item.bind(id)); _grid.add_child(card)
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
		var item: Dictionary=CATALOG[id]; var card: Button=_item_buttons[id]; card.text="\n\n\n%s\n× %d"%[str(item.title),count(id)]
	if CATALOG.has(_selected): _select_item(_selected)

func _style(background: Color,border: Color,radius: int,width: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=background; style.border_color=border; style.set_border_width_all(width); style.set_corner_radius_all(radius); style.content_margin_left=18; style.content_margin_right=18; style.content_margin_top=14; style.content_margin_bottom=14; return style
