extends Control
## Source visual system: assets/maps/city_rebuild_v1/weapon_hud.mjs:6-20, 65-91.
## Root-owned proposal. UI never mutates inventory, ammo, cargo or item identity.
var host: Node
var menu: PanelContainer
var launcher: Button
var title: Label
var ammo: Label
var count: Label
var grid: GridContainer
var scroll: ScrollContainer
var crosshair: Label
var photo: TextureRect
var choices: Dictionary = {}
var textures: Dictionary = {}
var _normal: StyleBoxFlat
var _selected: StyleBoxFlat
var _last_size := Vector2.ZERO
var _hud_signature := ""
var _menu_signature := ""
var _inventory_revision := 0
var _previous_id := ""
const FAMILIES := {"none":"УБРАТЬ ОРУЖИЕ","nagan":"РЕВОЛЬВЕР","tt_pistol":"ПИСТОЛЕТ","revolver":"РЕВОЛЬВЕР","deagle":"ТЯЖЁЛЫЙ ПИСТОЛЕТ","golden_colt":"ПИСТОЛЕТ","sawn_off":"ДРОБОВИК","shotgun":"ДРОБОВИК","uzi":"ПИСТОЛЕТ-ПУЛЕМЁТ","golden_uzi":"ПИСТОЛЕТ-ПУЛЕМЁТ","ak74":"АВТОМАТ","m16":"АВТОМАТ","tommy_gun":"ПИСТОЛЕТ-ПУЛЕМЁТ","sniper":"ВИНТОВКА","rpg":"ГРАНАТОМЁТ"}

static func panel_style(background: String, border: String, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background); style.border_color = Color(border)
	style.set_border_width_all(1); style.set_corner_radius_all(radius)
	style.shadow_color = Color(0,0,0,.42); style.shadow_size = 5; style.shadow_offset = Vector2(0,3)
	return style

static func label(value: String, pixels: int, color: String = "eeeae0") -> Label:
	var result := Label.new(); result.text = value
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", Color(color))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func margins(amount: int) -> MarginContainer:
	var result := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: result.add_theme_constant_override("margin_"+side, amount)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func keycap(key: String, gold: bool = false) -> PanelContainer:
	var result := PanelContainer.new(); result.custom_minimum_size = Vector2(30,30)
	result.add_theme_stylebox_override("panel",panel_style("bd8735" if gold else "30373c", "ffe29a" if gold else "858582",4))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := label(key,16 if gold else 13,"241707" if gold else "eeeae0")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result.add_child(text)
	return result

static func picture(height: float) -> TextureRect:
	var result := TextureRect.new(); result.custom_minimum_size = Vector2(0,height)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func configure(weapon_host: Node, baked_textures: Dictionary = {}) -> void:
	host = weapon_host; textures = baked_textures
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_normal = panel_style("252e35","4f595f",5); _selected = panel_style("3b3e37","c9ac6b",5)
	launcher = Button.new(); launcher.focus_mode = Control.FOCUS_NONE
	launcher.add_theme_stylebox_override("normal",panel_style("252b2f","78746a"))
	launcher.add_theme_stylebox_override("hover",panel_style("343c41","d1b77d"))
	launcher.add_theme_stylebox_override("pressed",_selected)
	launcher.pressed.connect(_launcher_pressed); add_child(launcher)
	var padding := margins(10); padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); launcher.add_child(padding)
	var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation",12); padding.add_child(row)
	photo = picture(58); photo.custom_minimum_size.x = 112; row.add_child(photo)
	var copy := VBoxContainer.new(); copy.mouse_filter = Control.MOUSE_FILTER_IGNORE; copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(copy)
	title = label("Без оружия",14); copy.add_child(title)
	ammo = label("ОРУЖИЕ УБРАНО",12,"b8c5cd"); copy.add_child(ammo)
	row.add_child(keycap("Q"))
	menu = PanelContainer.new(); menu.visible = false; add_child(menu)
	menu.add_theme_stylebox_override("panel",panel_style("1d2429fc","77766f",8))
	var menu_margin := margins(15); menu.add_child(menu_margin)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",10); menu_margin.add_child(column)
	var heading := HBoxContainer.new(); column.add_child(heading)
	var heading_copy := VBoxContainer.new(); heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(heading_copy)
	heading_copy.add_child(label("А Р С Е Н А Л",18))
	count = label("",11,"a9b1b5"); heading_copy.add_child(count)
	var close := Button.new(); close.text = "×"; close.custom_minimum_size = Vector2(30,30); close.pressed.connect(func(): host.set_menu(false)); heading.add_child(close)
	scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	grid = GridContainer.new(); grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); scroll.add_child(grid)
	for id: String in FAMILIES:
		var choice := Button.new(); choice.custom_minimum_size = Vector2(190,139); choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_theme_stylebox_override("normal",_normal); choice.add_theme_stylebox_override("hover",panel_style("343f46","d1b77d",5)); choice.add_theme_stylebox_override("focus",panel_style("343f46","d1b77d",5))
		choice.pressed.connect(func(): host.equip(id)); grid.add_child(choice)
		var inner := margins(10); inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); choice.add_child(inner)
		var content := VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; inner.add_child(content)
		var image := picture(79); image.texture = textures.get(id); content.add_child(image)
		var name_label := label(host.LABELS[id],12); content.add_child(name_label)
		var detail := label("",10,"9eafb9"); content.add_child(detail)
		choices[id] = {"button":choice,"image":image,"detail":detail,"selected":false}
	column.add_child(label("Q  арсенал     G  выбросить     E  подобрать рядом",11,"aeb7bc"))
	crosshair = label("·",34); add_child(crosshair)
	refresh()

func set_thumbnail(id: String, texture: Texture2D) -> void:
	if not choices.has(id) or texture == null: return
	textures[id] = texture; choices[id].image.texture = texture
	if host.fire_state.get("weaponId","none") == id: photo.texture = texture

func invalidate_inventory() -> void:
	_inventory_revision += 1

func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	if view == _last_size: return
	_last_size = view
	var narrow := view.x <= 760
	var width := minf(360 if narrow else 430,view.x-36)
	launcher.position = Vector2(18,view.y-96); launcher.size = Vector2(width,78)
	var menu_width := minf(540 if narrow else 690,view.x-36)
	var menu_height := minf(view.y*.58 if narrow else view.y*.74,700)
	menu.position = Vector2(18,view.y-108-menu_height); menu.size = Vector2(menu_width,menu_height)
	grid.columns = 2 if narrow else 3
	for id: String in choices: choices[id].button.custom_minimum_size.x = (menu_width-55)/grid.columns-10
	crosshair.position = view*.5-Vector2(5,23)

func refresh() -> void:
	if not is_instance_valid(host): return
	var state: Dictionary = host.fire_state
	var id: String = str(state.get("weaponId","none"))
	var reload := float(state.get("reloadRemaining",0))
	var magazine := int(state.get("magazine",0)); var reserve := int(state.get("reserveAmmo",0))
	var hud_signature := "%s:%d:%d:%.1f" % [id,magazine,reserve,reload]
	if hud_signature != _hud_signature:
		_hud_signature = hud_signature
		if id != _previous_id:
			_previous_id=id; title.text=host.LABELS.get(id,id); photo.texture=textures.get(id)
		ammo.text = "ОРУЖИЕ УБРАНО" if id == "none" else ("ПЕРЕЗАРЯДКА · %.1f С" % reload if reload > 0 else ("ПУСТО · 0 / %d" % reserve if magazine == 0 else "%d / %d" % [magazine,reserve]))
		ammo.add_theme_color_override("font_color",Color("e3c780" if reload>0 else ("f29b91" if id!="none" and magazine==0 else "b8c5cd")))
	if menu.visible != host.menu_open: menu.visible = host.menu_open
	var show_reticle: bool = not (host.aim_camera!=null and host.aim_camera.scoped()) and (host.armed() or host.cargo_reticle_requested) and not host.menu_open and host.player._free_mouse_look
	if crosshair.visible != show_reticle: crosshair.visible = show_reticle
	if not host.menu_open:
		_menu_signature=""
		return
	var owned: Array = host.inventory.get_owned_ids()
	var menu_signature := "%s|%s|%d" % [",".join(owned),hud_signature,_inventory_revision]
	if menu_signature == _menu_signature: return
	_menu_signature=menu_signature
	var count_text := "ПРИ СЕБЕ: %d · ВЫБЕРИТЕ ОРУЖИЕ" % owned.size()
	if count.text != count_text: count.text=count_text
	for key: String in choices:
		var choice: Dictionary = choices[key]; var selected := key == id
		var available := key == "none" or owned.has(key)
		if choice.button.visible != available:
			choice.button.visible=available; choice.button.disabled=not available
		if choice.selected != selected:
			choice.selected=selected
			choice.button.add_theme_stylebox_override("normal",_selected if selected else _normal)
			choice.detail.add_theme_color_override("font_color",Color("e0c58b" if selected else "9eafb9"))
		if not available: continue
		var rounds: Variant = state if selected else host.inventory.get_fire_state(key)
		var detail: String = ("РУКИ СВОБОДНЫ" if selected else "УБРАТЬ ОРУЖИЕ") if key=="none" else ("В РУКАХ" if selected else FAMILIES[key])
		if key != "none" and rounds is Dictionary: detail += " · %d / %d" % [int(rounds.magazine),int(rounds.reserveAmmo)]
		if choice.detail.text != detail: choice.detail.text = detail

func _launcher_pressed() -> void:
	if not is_instance_valid(host) or not host._owner_current(): return
	if host.player._pose_authority != &"on_foot" or not host.player._jump.is_empty() or bool(host.scene.get("preview_dead")) or bool(host.scene.get("preview_physics_fault")): return
	# Clicking the visible launcher explicitly starts an interaction. A free
	# cursor can open the arsenal without a separate click in the 3D world.
	if not host.player._free_mouse_look: host.player.set_mouse_captured(true)
	host.set_menu(not host.menu_open)
