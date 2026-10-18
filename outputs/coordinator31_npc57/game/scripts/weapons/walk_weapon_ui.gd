extends Control
const Crosshair = preload("res://scripts/weapons/walk_weapon_crosshair.gd")
## Source visual system: assets/maps/city_rebuild_v1/weapon_hud.mjs:6-20, 65-91.
## Root-owned proposal. UI never mutates inventory, ammo, cargo or item identity.
var host: Node
var menu: PanelContainer
var launcher: Button
var _arsenal_status: Label
var title: Label
var ammo: Label
var count: Label
var grid: GridContainer
var scroll: ScrollContainer
var crosshair: Control
var photo: TextureRect
var choices: Dictionary = {}
var textures: Dictionary = {}
var _normal: StyleBoxFlat
var _selected: StyleBoxFlat
var _icon_material: ShaderMaterial
var _last_size := Vector2.ZERO
var _hud_signature := ""
var _menu_signature := ""
var _inventory_revision := 0
var _previous_id := ""
const FAMILIES := {"none":"УБРАТЬ ОРУЖИЕ","sword":"МЕЧ · БЛИЖНИЙ БОЙ","mace":"БУЛАВА · ОДНОРУЧНОЕ","axe":"ТОПОР · ДВУРУЧНОЕ","sledge":"КУВАЛДА · ДВУРУЧНОЕ","spear":"КОПЬЁ · КОЛЮЩЕЕ","bow":"ЛУК · ДАЛЬНИЙ БОЙ","shield":"ЩИТ · БЛОК (ПКМ)","nagan":"РЕВОЛЬВЕР","tt_pistol":"ПИСТОЛЕТ","revolver":"РЕВОЛЬВЕР","deagle":"ТЯЖЁЛЫЙ ПИСТОЛЕТ","golden_colt":"ПИСТОЛЕТ","sawn_off":"ДРОБОВИК","shotgun":"ДРОБОВИК","uzi":"ПИСТОЛЕТ-ПУЛЕМЁТ","golden_uzi":"ПИСТОЛЕТ-ПУЛЕМЁТ","ak74":"АВТОМАТ","m16":"АВТОМАТ","tommy_gun":"ПИСТОЛЕТ-ПУЛЕМЁТ","sniper":"ВИНТОВКА","rpg":"ГРАНАТОМЁТ"}
## DSH_SWORD_PROTO: the prototype sword is always available in the arsenal menu.
const SWORD_ID := "sword"
## DSH_BOW_PROTO: the test bow, shown with its quiver count on the weapon card.
const BOW_ID := "bow"
## DSH_MELEE_SET: every melee weapon of the set, shown with its own category.
const MELEE_IDS := {"shield":"ЩИТ · БЛОК (ПКМ)", "sword":"МЕЧ · БЛИЖНИЙ БОЙ", "mace":"БУЛАВА · ОДНОРУЧНОЕ", "axe":"ТОПОР · ДВУРУЧНОЕ", "sledge":"КУВАЛДА · ДВУРУЧНОЕ", "spear":"КОПЬЁ · КОЛЮЩЕЕ"}
const TWO_SLOT_IDS := ["axe", "sledge", "spear", "bow", "sawn_off", "shotgun", "ak74", "m16", "tommy_gun", "sniper", "rpg"]
const CARD_NAMES := {"none":"Свободные руки", "sword":"Меч", "mace":"Булава", "axe":"Двуручный топор", "sledge":"Кувалда", "spear":"Копьё", "bow":"Лук", "shield":"Щит"}

static func panel_style(background: String, border: String, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background); style.border_color = Color(border)
	style.set_border_width_all(1); style.set_corner_radius_all(radius)
	style.shadow_color = Color(0,0,0,.42); style.shadow_size = 5; style.shadow_offset = Vector2(0,3)
	return style

static func label(value: String, pixels: int, color: String = "d6d7d2") -> Label:
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
	result.add_theme_stylebox_override("panel",panel_style("9c8155" if gold else "30373c", "bba783" if gold else "69706f",4))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := label(key,16 if gold else 13,"211d17" if gold else "d6d7d2")
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
	_normal = panel_style("e9dcc0","a48b62",7); _selected = panel_style("f6e7bd","bd8337",7)
	_icon_material = ShaderMaterial.new()
	var icon_shader := Shader.new()
	# The game renders its model thumbnails with transparent backgrounds. Keep dark
	# leather and bowstring visible, and reveal a warm edge around the hovered item.
	icon_shader.code = """shader_type canvas_item;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = TEXTURE_PIXEL_SIZE * 3.0;
	float near_alpha = max(max(texture(TEXTURE, UV + vec2(d.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(d.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, d.y)).a,
		texture(TEXTURE, UV - vec2(0.0, d.y)).a));
	float rim = glow * max(near_alpha - c.a, 0.0) * 0.8;
	vec3 colour = c.rgb * (1.0 + glow * 0.28) + vec3(0.23, 0.13, 0.025) * glow * c.a;
	COLOR = vec4(colour + vec3(1.0, 0.69, 0.24) * rim, max(c.a, rim));
}"""
	_icon_material.shader = icon_shader
	launcher = Button.new(); launcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; launcher.focus_mode = Control.FOCUS_NONE
	launcher.add_theme_stylebox_override("normal",panel_style("252b2f","5b605f"))
	launcher.add_theme_stylebox_override("hover",panel_style("30383d","b09a74"))
	launcher.add_theme_stylebox_override("pressed",_selected)
	launcher.pressed.connect(_launcher_pressed); add_child(launcher)
	var padding := margins(10); padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); launcher.add_child(padding)
	var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation",12); padding.add_child(row)
	photo = picture(58); photo.custom_minimum_size.x = 112; row.add_child(photo)
	var copy := VBoxContainer.new(); copy.mouse_filter = Control.MOUSE_FILTER_IGNORE; copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(copy)
	title = label("Без оружия",14); copy.add_child(title)
	ammo = label("ОРУЖИЕ УБРАНО",12,"adb8be"); copy.add_child(ammo)
	row.add_child(keycap("Q"))
	menu = PanelContainer.new(); menu.visible = false; add_child(menu)
	menu.add_theme_stylebox_override("panel",panel_style("e7d5adf8","8d6942",9))
	var menu_margin := margins(15); menu.add_child(menu_margin)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",10); menu_margin.add_child(column)
	var heading := HBoxContainer.new(); column.add_child(heading)
	var heading_copy := VBoxContainer.new(); heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(heading_copy)
	heading_copy.add_child(label("А Р С Е Н А Л",18,"382b1f"))
	count = label("",11,"66533c"); heading_copy.add_child(count)
	_arsenal_status = label("",10,"765f42"); heading_copy.add_child(_arsenal_status)
	var close := Button.new(); close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; close.text = "×"; close.custom_minimum_size = Vector2(30,30); close.pressed.connect(func(): host.set_menu(false)); heading.add_child(close)
	scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	grid = GridContainer.new(); grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); scroll.add_child(grid)
	for id: String in FAMILIES:
		var choice := Button.new(); choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; choice.custom_minimum_size = Vector2(190,139); choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_theme_stylebox_override("normal",_normal)
		var hover_style := panel_style("fff1cb","d99027",7)
		hover_style.set_border_width_all(2)
		hover_style.shadow_color = Color(0.83, 0.47, 0.10, 0.65)
		hover_style.shadow_size = 10
		choice.add_theme_stylebox_override("hover",hover_style)
		choice.add_theme_stylebox_override("focus",hover_style)
		choice.add_theme_stylebox_override("disabled",panel_style("d9c9aa","a59678",7))
		choice.pressed.connect(func(): host.equip(id)); grid.add_child(choice)
		var inner := margins(10); inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); choice.add_child(inner)
		var content := VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; inner.add_child(content)
		var image := picture(79); image.texture = textures.get(id)
		image.material = _icon_material.duplicate()
		content.add_child(image)
		choice.mouse_entered.connect(_set_icon_hover.bind(image, true))
		choice.mouse_exited.connect(_set_icon_hover.bind(image, false))
		var name_label := label(CARD_NAMES.get(id, host.LABELS[id]),12,"34281d"); content.add_child(name_label)
		var detail := label("",10,"67533c"); content.add_child(detail)
		choices[id] = {"button":choice,"image":image,"detail":detail,"selected":false}
	column.add_child(label("ЛКМ  выбрать или взять     Q  закрыть     G  выбросить",11,"66533c"))
	crosshair = Crosshair.new(); add_child(crosshair)
	refresh()

func _set_icon_hover(image: TextureRect, hovered: bool) -> void:
	if not is_instance_valid(image): return
	var material := image.material as ShaderMaterial
	if material != null: material.set_shader_parameter("glow", 1.0 if hovered else 0.0)

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
	crosshair.position = view*.5

func refresh() -> void:
	if not is_instance_valid(host): return
	var state: Dictionary = host.fire_state
	var id: String = str(state.get("weaponId","none"))
	var reload := float(state.get("reloadRemaining",0))
	var magazine := int(state.get("magazine",0)); var reserve := int(state.get("reserveAmmo",0))
	var hud_signature := "%s:%d:%d:%.1f" % [id,magazine,reserve,reload]
	# DSH_BOW_PROTO: the bow has no magazine, so its signature must carry the quiver
	# count - without it the card froze at the first reading while the arrows fell.
	var bow_now: Dictionary = {}
	if id == BOW_ID:
		var bow_node: Node = host.scene.get("preview_bow_prototype") if is_instance_valid(host.scene) else null
		if is_instance_valid(bow_node): bow_now = bow_node.call("snapshot")
		hud_signature = "%s:%d:%s" % [id, int(bow_now.get("arrows_left", 0)), str(bow_now.get("quiver_worn", false))]
	if hud_signature != _hud_signature:
		_hud_signature = hud_signature
		if id != _previous_id:
			_previous_id=id; title.text=host.LABELS.get(id,id); photo.texture=textures.get(id)
		if MELEE_IDS.has(id):
			ammo.text = str(MELEE_IDS[id])
		elif id == BOW_ID:
			# DSH_BOW_PROTO: the quiver is the bow's ammunition, so the card shows the
			# arrows left instead of a meaningless empty magazine.
			if bool(bow_now.get("quiver_worn", false)):
				ammo.text = "СТРЕЛ %d / 20" % int(bow_now.get("arrows_left", 0))
			else:
				ammo.text = "БЕЗ КОЛЧАНА · 0 СТРЕЛ"
		elif id == "none":
			ammo.text = "ОРУЖИЕ УБРАНО"
		else:
			ammo.text = "ПЕРЕЗАРЯДКА · %.1f С" % reload if reload > 0 else ("ПУСТО · 0 / %d" % reserve if magazine == 0 else "%d / %d" % [magazine,reserve])
		ammo.add_theme_color_override("font_color",Color("bda879" if reload>0 else ("d99b94" if id!="none" and not MELEE_IDS.has(id) and id!=BOW_ID and magazine==0 else "adb8be")))
	if menu.visible != host.menu_open: menu.visible = host.menu_open
	if is_instance_valid(_arsenal_status):
		var arsenal_state: Dictionary = host.fire_state
		_arsenal_status.text = "выбрано: %s%s" % [str(arsenal_state.get("weaponId", "none")),
			"" if host.menu_open else "  ·  меню закрыто"]
	var scoped:bool=host.aim_camera!=null and host.aim_camera.scoped()
	var allowed:bool=host._combat_allowed() and not host.controls_blocked() and not host.player._text_control_focused()
	# Walk shows ordinary crosshair only while aiming or holding the trigger.
	var firearm_reticle:bool=allowed and host.armed() and (host._aiming or host._held) and not scoped
	var show_reticle:bool=firearm_reticle or (allowed and host.cargo_reticle_requested and not scoped)
	if crosshair.visible != show_reticle: crosshair.visible = show_reticle
	if show_reticle:
		var value:float=host._posture_view.get("value",0.0)
		var moving:bool=Vector2(host.player.velocity.x,host.player.velocity.z).length_squared()>.01
		var input:Dictionary={"aiming":host._aiming,"posture":"prone" if value>=1.95 else "crouch" if value>=.95 else "stand","moving":moving,"running":moving and Input.is_action_pressed(host.player.ACTION_RUN)}
		crosshair.present(state,input,get_viewport_rect().size.y,host.player.get_preview_camera().fov,firearm_reticle)
	if not host.menu_open:
		_menu_signature=""
		return
	var owned: Array = host.inventory.get_owned_ids()
	var castle_storage: Node = host.castle_storage_owner
	var castle_bag: Dictionary = castle_storage.snapshot() if is_instance_valid(castle_storage) else {}
	var carried: Dictionary = castle_bag.get("carried", {})
	var rack: Dictionary = castle_bag.get("rack", {})
	var menu_signature := "%s|%s|%d|%d" % [",".join(owned),hud_signature,_inventory_revision,int(castle_bag.get("revision", -1))]
	if menu_signature == _menu_signature: return
	_menu_signature=menu_signature
	var used_slots: int = int(castle_storage.carried_slots()) if is_instance_valid(castle_storage) else owned.size()
	var count_text := "ПРИ СЕБЕ: %d / 4 СЛОТА · НАЖМИТЕ НА ОРУЖИЕ" % used_slots if is_instance_valid(castle_storage) and carried.is_empty() else \
		"ПРИ СЕБЕ: %d / 4 СЛОТА · ВЫБЕРИТЕ ОРУЖИЕ" % used_slots if is_instance_valid(castle_storage) else \
		"ПРИ СЕБЕ: %d · ВЫБЕРИТЕ ОРУЖИЕ" % owned.size()
	if count.text != count_text: count.text=count_text
	for key: String in choices:
		var choice: Dictionary = choices[key]; var selected := key == id
		var medieval := MELEE_IDS.has(key) or key == BOW_ID
		var on_rack: bool = is_instance_valid(castle_storage) and medieval and rack.has(key)
		var slot_cost := 2 if key in TWO_SLOT_IDS else 1
		var room_for_item := used_slots + slot_cost <= int(castle_storage.CARRY_CAPACITY) if is_instance_valid(castle_storage) else true
		var available := key == "none" or ((carried.has(key) or (on_rack and room_for_item)) if is_instance_valid(castle_storage) and medieval else medieval or owned.has(key))
		# Show items still on the rack so their slot cost and pickup requirement are clear.
		var shown := (key == "none" or medieval) if is_instance_valid(castle_storage) else available
		if choice.button.visible != shown: choice.button.visible = shown
		if choice.button.disabled == available: choice.button.disabled = not available
		if choice.selected != selected:
			choice.selected=selected
			choice.button.add_theme_stylebox_override("normal",_selected if selected else _normal)
			choice.detail.add_theme_color_override("font_color",Color("86551e" if selected else "67533c"))
		if not available:
			if medieval and shown:
				choice.detail.text = ("НЕТ МЕСТА" if on_rack and not room_for_item else "НЕТ В АРСЕНАЛЕ") + " · %d %s" % [slot_cost, "СЛОТА" if slot_cost == 2 else "СЛОТ"]
			continue
		var rounds: Variant = state if selected else host.inventory.get_fire_state(key)
		var detail: String = ("РУКИ СВОБОДНЫ" if selected else "УБРАТЬ ОРУЖИЕ") if key=="none" else ("В РУКАХ" if selected else FAMILIES[key])
		if medieval:
			var slots := 2 if key in TWO_SLOT_IDS else 1
			var status := "В РУКАХ" if selected else "ЛКМ ВЗЯТЬ" if on_rack else "ПРИ СЕБЕ"
			detail = "%s · %d %s" % [status, slots, "СЛОТА" if slots == 2 else "СЛОТ"]
		elif key != "none" and rounds is Dictionary:
			detail += " · %d / %d" % [int(rounds.magazine),int(rounds.reserveAmmo)]
		if choice.detail.text != detail: choice.detail.text = detail

func _launcher_pressed() -> void:
	if not is_instance_valid(host) or not host._owner_current(): return
	if host.player._pose_authority != &"on_foot" or not host.player._jump.is_empty() or bool(host.scene.get("preview_dead")) or bool(host.scene.get("preview_physics_fault")): return
	# Clicking the visible launcher explicitly starts an interaction. A free
	# cursor can open the arsenal without a separate click in the 3D world.
	if not host.player._free_mouse_look: host.player.set_mouse_captured(true)
	host.set_menu(not host.menu_open)
