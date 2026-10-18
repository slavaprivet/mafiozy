extends Node
## One local owner for the six medieval display weapons, the player's castle
## gear, and the separate chest slots. Each ID exists in exactly one place.
const MEDIEVAL := ["sword", "mace", "axe", "sledge", "spear", "bow", "shield"]
const CARD_NAMES := {"sword": "Меч", "mace": "Булава", "axe": "Топор", "sledge": "Кувалда", "spear": "Копьё", "bow": "Лук", "shield": "Щит"}
const TWO_HANDED := ["axe", "sledge", "spear", "bow"]
const MeleeModels = preload("res://scripts/weapons/sword_prototype.gd")
const BowModel = preload("res://scripts/weapons/bow_prototype.gd")
const ModelFinish = preload("res://scripts/weapons/weapon_model_finish31.gd")
const CAPACITY := 8
const CARRY_CAPACITY := 4
var castle: Node3D
var weapons: Node
var window_open := false
var _busy := false
var _rack: Dictionary = {}
var _carried: Dictionary = {}
var _hand_weapon := ""
var _external_sword_model31: Node3D
var _hand_shield := false
var _back_bow := false
var _bow_active := false
var _fallen: Dictionary = {}
var _slots: Array[Dictionary] = []
var _revision := 0
var _rack_points: Array[Vector3] = []
var _chest_point := Vector3.ZERO
var _chest_group := "armour_chest"
var _panel: PanelContainer
var _grid: GridContainer
var _status: Label
var _held: Label
var _store: Button
var _store_shield: Button
var _store_bow: Button
var _modal: Control
var _feedback := ""
var _notice := ""
var _notice_until := 0
var _hint: Label
var _hint_clock := 0.0
var _displays: Array[Node3D] = []
var _display_models: Array[Node3D] = []
var _display_tags: Array[Label3D] = []
var _icons: Dictionary = {}
var _fallen_bodies: Dictionary = {}
var _fallen_age: Dictionary = {}
var _hovered_slot := -1
var _melee_model_factory: Node3D
var _bow_model_factory: Node3D

func configure(site: Node3D, arsenal: Node, rack_points: Array[Vector3], chest_point: Vector3) -> void:
	castle = site; weapons = arsenal; _rack_points = rack_points; _chest_point = chest_point
	for id: String in MEDIEVAL: _rack[id] = true
	weapons.castle_storage_owner = self
	_load_icons()
	_build_ui()
	_build_displays()

func _load_icons() -> void:
	for id: String in MEDIEVAL:
		var path: String = "res://assets/weapon_thumbnails/%s.png" % id
		var source: Texture2D = load(path) as Texture2D
		if source == null: continue
		var image: Image = source.get_image()
		image.resize(148, 74, Image.INTERPOLATE_LANCZOS)
		_icons[id] = ImageTexture.create_from_image(image)

func allows_equip(id: String) -> bool:
	if id not in MEDIEVAL: return true
	if not _carried.has(id): return false
	if _busy: return true
	return true

func carried_slots() -> int:
	var used := 0
	for id: String in _carried: used += 2 if id in TWO_HANDED else 1
	return used

func select_carried(id: String) -> Dictionary:
	if _busy or not _usable() or not _carried.has(id): return {"ok": false, "reason": "castle_weapon_not_carried"}
	if id == "bow":
		if _bow_active: return {"ok": true, "weaponId": id}
		var bow_selected := toggle_bow_selection()
		if bow_selected: weapons.set_menu(false)
		return {"ok": bow_selected, "weaponId": id}
	_busy = true
	var result: Dictionary = _activate_item(id)
	if bool(result.get("ok", false)): _revision += 1
	_busy = false
	if bool(result.get("ok", false)): weapons.set_menu(false)
	return result

## Castle test arsenal: clicking a Q card transfers the one real rack item to
## the player's loadout. The rack display disappears through _claim_display(),
## so this cannot duplicate a weapon or bypass the carried slot limit.
func acquire_or_select(id: String) -> Dictionary:
	if _carried.has(id): return select_carried(id)
	if id in MEDIEVAL and _rack.has(id) and _rack_alive(MEDIEVAL.find(id)):
		return _claim_display(id, false)
	return {"ok": false, "reason": "castle_weapon_not_available"}

func selected_none() -> void:
	_hand_weapon = ""
	if _bow_active:
		_bow_active = false; _set_bow_back(true)
	_revision += 1

func hand_has_shield() -> bool: return _hand_shield

func has_back_bow() -> bool: return _back_bow

func _hand_reason(id: String) -> String:
	if _carried.has(id): return "Уже при себе"
	if carried_slots() + (2 if id in TWO_HANDED else 1) > CARRY_CAPACITY: return "Нет места при себе"
	return "Рука занята" if id == "shield" and _hand_weapon in TWO_HANDED else ""

## The melee host owns dropped world models; this ledger owns carried slots and
## the HUD. A thrown weapon leaves a free hand but can still be marked carried
## until its first ground interaction, so count it as departing before adoption.
func can_adopt_ground_melee31(id: String, previous_id: String, previous_empty: bool) -> Dictionary:
	if _busy or window_open or not _usable() or id not in MEDIEVAL or id in ["bow", "shield"]:
		return {"ok": false, "reason": "inactive"}
	if _hand_shield and id in TWO_HANDED: return {"ok": false, "reason": "shield_occupies_right_hand"}
	if _carried.has(id):
		return {"ok": previous_empty and _hand_weapon == id, "reason": "duplicate_item"}
	var departed := previous_empty and previous_id == _hand_weapon and _carried.has(previous_id)
	var slots := carried_slots() - (2 if previous_id in TWO_HANDED else 1) if departed else carried_slots()
	if slots + (2 if id in TWO_HANDED else 1) > CARRY_CAPACITY:
		return {"ok": false, "reason": "carry_capacity"}
	return {"ok": true, "departed": departed}

func adopt_ground_melee31(id: String, previous_id: String, previous_empty: bool,
		foreign_sword: bool, actual_model: Node3D) -> Dictionary:
	var check := can_adopt_ground_melee31(id, previous_id, previous_empty)
	if not bool(check.get("ok", false)): return check
	var old_hand := _hand_weapon
	var old_external := _external_sword_model31
	var added := not _carried.has(id)
	var departed: bool = bool(check.get("departed", false))
	_busy = true
	if departed:
		_carried.erase(previous_id)
		_hand_weapon = ""
	if added: _carried[id] = true
	var result: Dictionary = _activate_item(id)
	if not bool(result.get("ok", false)):
		if added: _carried.erase(id)
		if departed: _carried[previous_id] = true
		_hand_weapon = old_hand
		_external_sword_model31 = old_external
		_busy = false
		return result
	if foreign_sword: _external_sword_model31 = actual_model
	_revision += 1
	_busy = false
	_refresh_ui()
	return {"ok": true, "weaponId": id, "slots": carried_slots()}

func _show_notice(message: String) -> void:
	_notice = message
	_notice_until = Time.get_ticks_msec() + 1800

func _usable() -> bool:
	return is_instance_valid(castle) and is_instance_valid(weapons) and weapons._owner_current() \
		and weapons.get("_catapult_stone_carry") != true \
		and weapons.player._pose_authority == &"on_foot" and not bool(weapons.scene.get("preview_dead")) \
		and not bool(weapons.scene.get("preview_physics_fault"))

func _chest_alive() -> bool:
	if not is_instance_valid(castle): return false
	for index: Variant in castle._furniture_cells.get(_chest_group, []):
		if bool(castle._cells[int(index)].get("alive", false)): return true
	return false

func _nearest_rack(local_player: Vector3) -> int:
	var best := -1; var distance := 2.4
	for index: int in _rack_points.size():
		var delta := local_player - _rack_points[index]
		var measured := Vector2(delta.x, delta.z).length()
		if absf(delta.y) < 2.0 and measured < distance and _rack_alive(index):
			best = index; distance = measured
	return best

func _nearest_fallen(local_player: Vector3) -> String:
	var best := ""; var distance := 1.8
	for id: String in _fallen:
		var at: Vector3 = _fallen[id]
		var measured := Vector2(local_player.x - at.x, local_player.z - at.z).length()
		if absf(local_player.y - at.y) < 2.0 and measured < distance:
			best = id; distance = measured
	return best

func _rack_alive(index: int) -> bool:
	if not is_instance_valid(castle): return false
	if index == 6:
		for value: Variant in castle._furniture_cells.get("armour_shield_mount", []):
			if bool(castle._cells[int(value)].get("alive", false)): return true
		return false
	var roots: Array = castle._furniture_cells.get("armour_rack", [])
	var section: int = floori(float(index) / 2.0)
	return section < roots.size() and bool(castle._cells[int(roots[section])].get("alive", false))

func chest_focused() -> bool:
	if not _usable() or window_open or not _chest_alive(): return false
	var local_player: Vector3 = castle.to_local(weapons.player.global_position)
	if Vector2(local_player.x - _chest_point.x, local_player.z - _chest_point.z).length() > 2.6 \
			or absf(local_player.y - _chest_point.y) > 2.0:
		return false
	var camera: Camera3D = weapons.player.get_preview_camera()
	if not is_instance_valid(camera): return false
	var target: Vector3 = castle.to_global(_chest_point + Vector3.UP * 0.85)
	var direction: Vector3 = target - camera.global_position
	return direction.length_squared() > 0.01 and direction.normalized().dot(-camera.global_basis.z) > 0.72

func chest_hint_position() -> Vector3:
	return castle.to_global(_chest_point + Vector3.UP * 1.75)

func interaction_label() -> String:
	if not _usable() or window_open: return ""
	if Time.get_ticks_msec() < _notice_until: return _notice
	var local_player: Vector3 = castle.to_local(weapons.player.global_position)
	var fallen := _nearest_fallen(local_player)
	if not fallen.is_empty(): return "E — поднять: %s" % weapons.LABELS.get(fallen, fallen)
	if chest_focused(): return ""
	var rack := _nearest_rack(local_player)
	if rack >= 0:
		var id: String = MEDIEVAL[rack]
		return "E — взять: %s" % weapons.LABELS.get(id, id) if _rack.has(id) else "Стойка пуста"
	return ""

func interact() -> bool:
	if not _usable() or window_open: return false
	var local_player: Vector3 = castle.to_local(weapons.player.global_position)
	if chest_focused():
		open_window(); return true
	if _hand_weapon.is_empty() and is_instance_valid(weapons.scene):
		var melee_host: Node = weapons.scene.get("preview_sword_prototype")
		if is_instance_valid(melee_host) and melee_host.has_method("try_pickup_sword") \
				and not (melee_host.call("_nearest_ground_sword") as Dictionary).is_empty():
			if melee_host.try_pickup_sword(true): return true
	var fallen := _nearest_fallen(local_player)
	if not fallen.is_empty():
		_claim_display(fallen, true)
		return true
	var rack := _nearest_rack(local_player)
	if rack < 0: return false
	var id: String = MEDIEVAL[rack]
	if _busy or not _rack.has(id): return true
	_claim_display(id, false)
	return true

func _claim_display(id: String, fallen: bool) -> Dictionary:
	if _busy or _carried.has(id) or not (_fallen.has(id) if fallen else _rack.has(id)):
		return {"ok": false, "reason": "missing_item"}
	var hand_reason := _hand_reason(id)
	if not hand_reason.is_empty():
		_show_notice(hand_reason)
		return {"ok": false, "reason": "hand_occupied"}
	_busy = true
	# Temporarily admit only this ID while the real playable model is equipped.
	_carried[id] = true
	var result: Dictionary = _activate_item(id)
	if bool(result.get("ok", false)):
		if fallen:
			_remove_fallen_body(id)
			_fallen.erase(id)
		else: _rack.erase(id)
		var display_index: int = MEDIEVAL.find(id)
		if display_index >= 0: _displays[display_index].visible = false
		_revision += 1
	else: _carried.erase(id)
	_busy = false
	return result

func _bow_host() -> Node:
	if not is_instance_valid(weapons.scene): return null
	return weapons.scene.get("preview_bow_prototype")

func _set_bow_back(stowed: bool) -> void:
	var host: Node = _bow_host()
	if is_instance_valid(host) and host.has_method("set_stowed_on_back31"):
		host.set_stowed_on_back31(stowed)

func _activate_item(id: String) -> Dictionary:
	if id == "bow":
		if not _hand_weapon.is_empty() or _hand_shield:
			if not weapons._ensure_medieval_host("preview_sword_prototype", "_install_sword_prototype") \
					or not weapons._ensure_medieval_host("preview_bow_prototype", "_install_bow_prototype"):
				return {"ok": false, "reason": "no_prototype"}
			_back_bow = true; _bow_active = false; _set_bow_back(true)
			return {"ok": true, "weaponId": "bow", "stowed": true}
		var bow_result: Dictionary = weapons.equip("bow")
		if bool(bow_result.get("ok", false)):
			_back_bow = true; _bow_active = true; _set_bow_back(false)
		return bow_result
	if _bow_active and id == "shield":
		var away: Dictionary = weapons.equip("none")
		if not bool(away.get("ok", false)): return away
		_bow_active = false; _set_bow_back(true)
	var result: Dictionary = weapons.equip(id)
	if bool(result.get("ok", false)):
		if id == "shield": _hand_shield = true
		else: _hand_weapon = id
		if _bow_active:
			_bow_active = false; _set_bow_back(true)
			if _hand_shield: weapons.equip("shield")
	return result

func toggle_bow_selection() -> bool:
	if not _usable() or window_open or not _back_bow or _busy: return false
	_busy = true
	var result: Dictionary
	if _bow_active:
		result = weapons.equip(_hand_weapon if not _hand_weapon.is_empty() else "none")
		if bool(result.get("ok", false)):
			_bow_active = false; _set_bow_back(true)
			if _hand_shield: weapons.equip("shield")
	else:
		if _hand_shield: weapons.stow_castle_shield()
		result = weapons.equip("bow")
		if bool(result.get("ok", false)):
			_bow_active = true; _set_bow_back(false)
		elif _hand_shield: weapons.equip("shield")
	_busy = false
	return bool(result.get("ok", false))

func _build_ui() -> void:
	if not is_instance_valid(weapons._layer): return
	_modal = Control.new(); _modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP; _modal.visible = false
	weapons._layer.add_child(_modal)
	_panel = PanelContainer.new(); _panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(770, 620); _panel.position = Vector2(-385, -310)
	_panel.add_theme_stylebox_override("panel", _chest_style(Color("dcc5a0"), Color("76502f"), 4, 16))
	_modal.add_child(_panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 9); _panel.add_child(box)
	var title := Label.new(); title.text = "ОРУЖЕЙНЫЙ СУНДУК · %d СЛОТОВ" % CAPACITY
	title.add_theme_color_override("font_color", Color("50311e"))
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	_status = Label.new(); _status.add_theme_color_override("font_color", Color("6b452b")); box.add_child(_status)
	_grid = GridContainer.new(); _grid.columns = 4; _grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8); _grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	_held = Label.new(); _held.add_theme_color_override("font_color", Color("42291b")); box.add_child(_held)
	_store = Button.new(); _store.text = "Положить оружие в сундук"; _store.pressed.connect(store_held)
	_style_chest_button(_store)
	box.add_child(_store)
	_store_shield = Button.new(); _store_shield.text = "Положить щит в сундук"
	_store_shield.pressed.connect(func() -> void: store_held("shield"))
	_style_chest_button(_store_shield)
	box.add_child(_store_shield)
	_store_bow = Button.new(); _store_bow.text = "Положить лук и колчан в сундук"
	_store_bow.pressed.connect(func() -> void: store_held("bow"))
	_style_chest_button(_store_bow)
	box.add_child(_store_bow)
	var instructions := Label.new()
	instructions.text = "E — взять   G — оружие   H — щит   B — лук   Q / Esc — закрыть"
	instructions.add_theme_color_override("font_color", Color("76502f"))
	box.add_child(instructions)
	var close := Button.new(); close.text = "Закрыть · Q / Esc"; close.pressed.connect(close_window)
	_style_chest_button(close)
	box.add_child(close)
	_hint = Label.new(); _hint.text = ""; _hint.visible = false
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-225, -104); _hint.custom_minimum_size = Vector2(450, 36)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapons._layer.add_child(_hint)

func _chest_style(fill: Color, edge: Color, width: int = 2, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill; style.border_color = edge
	style.set_border_width_all(width); style.set_corner_radius_all(radius)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 7; style.content_margin_bottom = 7
	return style

func _style_chest_button(button: Button, slot: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _chest_style(Color("f1dfbb") if slot else Color("a87849"), Color("875d37")))
	var hover_style := _chest_style(Color("fff0c3") if slot else Color("d9ab62"), Color("d99027"), 3)
	hover_style.shadow_color = Color(0.78, 0.43, 0.08, 0.65)
	hover_style.shadow_size = 9
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", _chest_style(Color("d7b989"), Color("76502f")))
	button.add_theme_stylebox_override("disabled", _chest_style(Color("c6ad88"), Color("9b8060")))
	button.add_theme_color_override("font_color", Color("402719"))
	button.add_theme_color_override("font_hover_color", Color("402719"))
	button.add_theme_color_override("font_pressed_color", Color("402719"))
	button.add_theme_color_override("font_disabled_color", Color("725a41"))
	button.add_theme_color_override("icon_hover_color", Color(1.25, 1.10, 0.66))
	button.add_theme_color_override("icon_focus_color", Color(1.25, 1.10, 0.66))

func _build_displays() -> void:
	# These are the same model builders the playable melee and bow hosts use.
	# They are called once at map build; no duplicate gameplay hosts are started.
	_melee_model_factory = MeleeModels.new()
	_bow_model_factory = BowModel.new()
	_bow_model_factory._build_materials()
	for index: int in MEDIEVAL.size():
		var id: String = MEDIEVAL[index]
		var holder := Node3D.new(); holder.name = "Display_" + id
		holder.position = _rack_points[index] + Vector3(1.15, 0, 0)
		castle.add_child(holder); _displays.append(holder)
		var model: Node3D = _bow_model_factory._build_bow(holder) if id == "bow" else \
			_melee_model_factory._build_shield_model(holder) if id == "shield" else \
			_melee_model_factory._build_weapon_model(holder, id)
		model.visible = true
		var size: float = _display_scale(id)
		# The rack faces into the room along -X. Turn each broad weapon face
		# toward that view after raising its gameplay +X axis vertically.
		var basis: Basis = Basis.IDENTITY if id == "bow" else Basis(Vector3.UP, PI * 0.5) \
			if id == "shield" else Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
		model.transform = ModelFinish.resting_transform(model, basis.scaled(Vector3.ONE * size),
			Vector3(0, 0.95 if id == "shield" else 0.692, 0))
		_display_models.append(model)
		var tag := Label3D.new(); tag.text = weapons.LABELS.get(id, id)
		tag.font_size = 22; tag.pixel_size = 0.0048
		tag.outline_size = 5
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(-0.3, 2.34, 0); holder.add_child(tag)
		_display_tags.append(tag)

func _exit_tree() -> void:
	if is_instance_valid(weapons) and weapons.castle_storage_owner == self:
		weapons.castle_storage_owner = null
	if is_instance_valid(_melee_model_factory): _melee_model_factory.free()
	if is_instance_valid(_bow_model_factory): _bow_model_factory.free()

func _display_scale(id: String) -> float:
	match id:
		"mace": return 1.65
		"bow": return 1.42
		"sword": return 1.25
		"spear": return 1.18
		"shield": return 1.35
		_: return 1.38

func _refresh_ui() -> void:
	if not is_instance_valid(_grid): return
	_hovered_slot = -1
	for child: Node in _grid.get_children(): child.queue_free()
	for index: int in CAPACITY:
		var button := Button.new(); button.custom_minimum_size = Vector2(170, 108)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_chest_button(button, true)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("separation", 0)
		button.add_child(content)
		if index < _slots.size():
			var item: Dictionary = _slots[index]
			var blocked: String = _hand_reason(str(item.id))
			var full_name: String = weapons.LABELS.get(item.id, item.id)
			button.tooltip_text = "%d · %s\n%s" % [index + 1, full_name,
				"Взять" if blocked.is_empty() else blocked]
			var image := TextureRect.new()
			image.texture = _icons.get(str(item.id))
			image.custom_minimum_size = Vector2(0, 63)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(image)
			button.mouse_entered.connect(_set_chest_icon_hover.bind(image, true))
			button.mouse_exited.connect(_set_chest_icon_hover.bind(image, false))
			content.add_child(_chest_card_label("%d · %s" % [index + 1, CARD_NAMES.get(str(item.id), full_name)], 12))
			content.add_child(_chest_card_label("Взять" if blocked.is_empty() else blocked, 11))
			button.pressed.connect(_take_slot.bind(index, _revision))
			button.mouse_entered.connect(_set_hovered_slot.bind(index))
			button.mouse_exited.connect(_clear_hovered_slot.bind(index))
		else:
			button.disabled = true
			content.add_child(_chest_card_label("%d · пусто" % (index + 1), 12))
		_grid.add_child(button)
	_status.text = "Занято: %d / %d   %s" % [_slots.size(), CAPACITY, _feedback]
	var left: String = weapons.LABELS.get(_hand_weapon, _hand_weapon) if not _hand_weapon.is_empty() else "Пусто"
	var right: String = "Щит" if _hand_shield else "Пусто"
	if _hand_weapon in TWO_HANDED: right = weapons.LABELS.get(_hand_weapon, _hand_weapon)
	if _bow_active: left = "Лук"; right = "Лук"
	_held.text = "Левая: %s    Правая: %s    За спиной: %s" % [left, right,
		"Лук + колчан" if _back_bow and not _bow_active else "Пусто"]
	_store.disabled = _hand_weapon.is_empty() or _slots.size() >= CAPACITY
	_store_shield.disabled = not _hand_shield or _slots.size() >= CAPACITY
	_store_bow.disabled = not _back_bow or _slots.size() >= CAPACITY

func _chest_card_label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("402719"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _set_chest_icon_hover(image: TextureRect, hovered: bool) -> void:
	if is_instance_valid(image):
		image.modulate = Color(1.25, 1.12, 0.70) if hovered else Color.WHITE

func _set_hovered_slot(index: int) -> void: _hovered_slot = index
func _clear_hovered_slot(index: int) -> void:
	if _hovered_slot == index: _hovered_slot = -1

func open_window() -> bool:
	if not _usable() or not _chest_alive() or window_open: return false
	weapons.cancel_inputs(); weapons.set_menu(false)
	window_open = true; _feedback = ""; _modal.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_ui()
	return true

func close_window() -> void:
	if not window_open: return
	window_open = false; _modal.visible = false
	weapons.cancel_inputs()
	if is_instance_valid(weapons.player):
		if DisplayServer.get_name() == "headless" or get_window().has_focus():
			weapons.player.set_mouse_captured(true)

func window_input(event: InputEvent) -> bool:
	if not window_open: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in [KEY_ESCAPE, KEY_Q]: close_window()
		elif code == KEY_E and _hovered_slot >= 0:
			_take_slot(_hovered_slot, _revision)
		elif code == KEY_G: store_held()
		elif code == KEY_H: store_held("shield")
		elif code == KEY_B: store_held("bow")
	return true

func _physics_process(delta: float) -> void:
	_update_fallen_bodies(delta)
	_hint_clock += delta
	if _hint_clock >= 0.14:
		_hint_clock = 0.0
		if _hand_shield and is_instance_valid(weapons.scene):
			var shield_host: Node = weapons.scene.get("preview_sword_prototype")
			if is_instance_valid(shield_host) and bool(shield_host.shield_status().get("broken", false)):
				_hand_shield = false; _carried.erase("shield"); _revision += 1
		_drop_broken_storage()
		if is_instance_valid(_hint):
			_hint.text = interaction_label(); _hint.visible = not _hint.text.is_empty()
		for index: int in _displays.size():
			var id: String = MEDIEVAL[index]
			_displays[index].visible = (_rack.has(id) and _rack_alive(index)) or _fallen.has(id)
	if window_open and (not _usable() or not _chest_alive() or weapons.player.global_position.distance_to(castle.to_global(_chest_point)) > 4.0):
		close_window()

func _spawn_fallen_display(index: int, at: Vector3) -> void:
	var id: String = MEDIEVAL[index]
	if _fallen_bodies.has(id): return
	var holder: Node3D = _displays[index]
	var body := RigidBody3D.new()
	body.name = "DroppedCastleWeapon_" + id
	body.mass = 1.2 if id == "sledge" else 0.65
	body.collision_layer = 1; body.collision_mask = 1
	body.continuous_cd = true
	castle.add_child(body)
	body.position = at + Vector3(0, 1.15, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.78, 0.16, 0.68) if id == "shield" else \
		Vector3(1.35 if id == "spear" else 0.9, 0.16, 0.2)
	shape.shape = box; shape.position.y = 0.09
	body.add_child(shape)
	holder.reparent(body, false)
	holder.position = Vector3.ZERO; holder.rotation = Vector3.ZERO
	_display_tags[index].visible = false
	var flat: Basis = Basis(Vector3.BACK, PI * 0.5) if id == "bow" else \
		Basis(Vector3.RIGHT, PI * 0.5) if id == "shield" else Basis.IDENTITY
	_display_models[index].transform = ModelFinish.resting_transform(_display_models[index],
		flat.scaled(Vector3.ONE * _display_scale(id)), Vector3.ZERO)
	body.linear_velocity = Vector3(0.5 if index % 2 == 0 else -0.5, 0.8, 0.4)
	body.angular_velocity = Vector3(1.7, 0.9, -1.1)
	_fallen_bodies[id] = body
	_fallen_age[id] = 0.0

func _update_fallen_bodies(delta: float) -> void:
	for id: String in _fallen_bodies.keys():
		var body: RigidBody3D = _fallen_bodies[id]
		if not is_instance_valid(body): continue
		_fallen[id] = body.position
		var age: float = float(_fallen_age.get(id, 0.0)) + delta
		_fallen_age[id] = age
		if not body.freeze and age > 1.0 and body.linear_velocity.length() < 0.25 \
				and body.angular_velocity.length() < 0.5:
			body.freeze = true

func _remove_fallen_body(id: String) -> void:
	var body: RigidBody3D = _fallen_bodies.get(id)
	if is_instance_valid(body):
		var holder: Node3D = _displays[MEDIEVAL.find(id)]
		holder.reparent(castle, true)
		body.collision_layer = 0; body.collision_mask = 0
		body.queue_free()
	_fallen_bodies.erase(id)
	_fallen_age.erase(id)

func _drop_broken_storage() -> void:
	if not _chest_alive() and not _slots.is_empty():
		for slot: Dictionary in _slots:
			var id: String = str(slot.id)
			var at: Vector3 = _chest_point + Vector3(-0.6 + _fallen.size() * 0.28, 0, 0.1)
			_fallen[id] = at
			_spawn_fallen_display(MEDIEVAL.find(id), at)
		_slots.clear(); _revision += 1
	for index: int in MEDIEVAL.size():
		var id: String = MEDIEVAL[index]
		if _rack.has(id) and not _rack_alive(index):
			_rack.erase(id)
			var at: Vector3 = _rack_points[index] + Vector3(0.8, 0, 0)
			_fallen[id] = at
			_spawn_fallen_display(index, at)
			_revision += 1

func _remove_equipped_item(id: String) -> Dictionary:
	if id == "bow":
		if _bow_active:
			var result: Dictionary = weapons.equip(_hand_weapon if not _hand_weapon.is_empty() else "none")
			if not bool(result.get("ok", false)): return result
			_bow_active = false
			if _hand_shield: weapons.equip("shield")
		_back_bow = false; _set_bow_back(false)
		return {"ok": true}
	if id == "shield":
		if not _bow_active and not weapons.stow_castle_shield(): return {"ok": false}
		_hand_shield = false
		return {"ok": true}
	if id == _hand_weapon:
		if not _bow_active:
			var result: Dictionary = weapons.equip("none")
			if not bool(result.get("ok", false)): return result
		_hand_weapon = ""
		return {"ok": true}
	return {"ok": false, "reason": "not_equipped"}

func _chosen_item(choice: Variant) -> String:
	if (choice is bool and choice) or str(choice) == "shield": return "shield"
	if str(choice) == "bow": return "bow"
	if not _hand_weapon.is_empty(): return _hand_weapon
	if _bow_active: return "bow"
	return "shield"

func store_held(choice: Variant = "") -> Dictionary:
	if _busy or not window_open or not _usable() or not _chest_alive(): return {"ok": false, "reason": "inactive"}
	if _slots.size() >= CAPACITY: return {"ok": false, "reason": "full"}
	var id: String = _chosen_item(choice)
	if not _carried.has(id): return {"ok": false, "reason": "empty_hand"}
	_busy = true
	var result: Dictionary = _remove_equipped_item(id)
	if bool(result.get("ok", false)):
		_slots.append({"id": id, "uid": "castle-medieval-" + id})
		_carried.erase(id)
		_revision += 1
	_feedback = "Оружие положено" if bool(result.get("ok", false)) else "Не удалось положить"
	_busy = false; _refresh_ui()
	return result

func drop_held(prefer_shield: bool = false) -> Dictionary:
	if _busy or window_open or not _usable(): return {"ok": false, "reason": "inactive"}
	var id: String = "bow" if _bow_active else \
		"shield" if prefer_shield or _hand_weapon.is_empty() else _hand_weapon
	if not _carried.has(id): return {"ok": false, "reason": "empty_hand"}
	if id == "sword" and is_instance_valid(_external_sword_model31) and is_instance_valid(weapons.scene):
		var sword_host: Node = weapons.scene.get("preview_sword_prototype")
		if is_instance_valid(sword_host) and sword_host.get("_sword") == _external_sword_model31:
			_busy = true
			if not sword_host.drop_sword_to_ground():
				_busy = false
				return {"ok": false, "reason": "physical_drop_failed"}
			var stowed: Dictionary = weapons.equip("none")
			if not bool(stowed.get("ok", false)):
				sword_host.cancel_ground_drop31()
				_busy = false
				return stowed
			_carried.erase(id)
			_hand_weapon = ""
			_revision += 1
			_busy = false
			_refresh_ui()
			return {"ok": true, "physical_model": true}
	_busy = true
	var result: Dictionary = _remove_equipped_item(id)
	if bool(result.get("ok", false)):
		_carried.erase(id)
		var forward: Vector3 = weapons.player._visual.global_basis.z
		forward.y = 0.0
		var at: Vector3 = castle.to_local(weapons.player.global_position + forward.normalized() * 0.8)
		_fallen[id] = at
		_spawn_fallen_display(MEDIEVAL.find(id), at)
		_revision += 1
	_busy = false
	return result

func _take_slot(index: int, expected_revision: int) -> Dictionary:
	if _busy or not window_open or not _usable() or not _chest_alive() or expected_revision != _revision \
			or index < 0 or index >= _slots.size(): return {"ok": false, "reason": "stale_slot"}
	_busy = true
	var slot: Dictionary = _slots[index]
	var id: String = str(slot.id)
	var result: Dictionary = {"ok": false}
	var hand_reason: String = _hand_reason(id)
	if not hand_reason.is_empty():
		_feedback = hand_reason
		_busy = false; _refresh_ui()
		return {"ok": false, "reason": "hand_occupied"}
	if id in MEDIEVAL and not _carried.has(id):
		_carried[id] = true
		result = _activate_item(id)
		if not bool(result.get("ok", false)): _carried.erase(id)
	if bool(result.get("ok", false)):
		_slots.remove_at(index); _revision += 1
	_feedback = "Оружие взято" if bool(result.get("ok", false)) else "Оружие уже недоступно"
	_busy = false; _refresh_ui()
	if bool(result.get("ok", false)): close_window()
	return result

func snapshot() -> Dictionary:
	return {"revision": _revision, "rack": _rack.duplicate(), "carried": _carried.duplicate(),
		"fallen": _fallen.duplicate(), "slots": _slots.duplicate(true), "chest_alive": _chest_alive(),
		"hand_weapon": _hand_weapon, "hand_shield": _hand_shield,
		"back_bow": _back_bow, "bow_active": _bow_active}
