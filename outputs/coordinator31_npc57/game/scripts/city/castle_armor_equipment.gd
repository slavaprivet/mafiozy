extends Node3D
## Castle-only owner of physical armour items and the five equipment slots.
## Each item ID has exactly one location: ground or an equipped slot.

signal equipped_changed(slot: String, old_id: String, new_id: String)

const SLOTS := ["head", "torso", "hands", "legs", "feet"]
const TIERS := ["light", "medium", "heavy"]
const SLOT_NAMES := {"head": "шлем", "torso": "нагрудник", "hands": "перчатки", "legs": "штаны", "feet": "сапоги"}
const TIER_NAMES := {"light": "Лёгкий", "medium": "Средний", "heavy": "Тяжёлый"}
const TIER_NAMES_PLURAL := {"light": "Лёгкие", "medium": "Средние", "heavy": "Тяжёлые"}

var site: Node3D
var weapons: Node
var player: CharacterBody3D
var equipped_by_slot: Dictionary = {}
var ground_items: Dictionary = {} # item ID -> Node3D, never a second copy
var visual: Node
var _hint: Label
var _menu: PanelContainer
var _menu_rows: Dictionary = {}
var _menu_open := false
var _focus := ""
var _revision := 0

func configure(castle_site: Node3D, arsenal: Node, armor_visual: Node = null) -> void:
	site = castle_site
	weapons = arsenal
	player = weapons.player as CharacterBody3D
	visual = armor_visual
	global_transform = site.global_transform
	_build_ui()
	# Fifteen individual pieces lie in three rows in the castle courtyard.
	# They are placed away from the existing armory, chest, gate lever and catapult.
	for tier_index: int in TIERS.size():
		for slot_index: int in SLOTS.size():
			var id: String = "%s_%s" % [TIERS[tier_index], SLOTS[slot_index]]
			var at := Vector3(-5.0 + float(slot_index) * 1.55, 0.15, 4.0 + float(tier_index) * 1.65)
			_spawn_ground(id, at)
	set_process(true)

func _valid_id(id: String) -> bool:
	var parts := id.split("_")
	return parts.size() == 2 and parts[0] in TIERS and parts[1] in SLOTS

func _slot_for(id: String) -> String:
	return id.get_slice("_", 1) if _valid_id(id) else ""

func item_name(id: String) -> String:
	if not _valid_id(id): return id
	var tier: String = id.get_slice("_", 0)
	var slot: String = id.get_slice("_", 1)
	return "%s %s" % [TIER_NAMES_PLURAL[tier] if slot in ["hands", "legs", "feet"] else TIER_NAMES[tier], SLOT_NAMES[slot]]

func get_equipped_armor(slot: String) -> String:
	return str(equipped_by_slot.get(slot, ""))

func equipped_snapshot() -> Dictionary:
	return equipped_by_slot.duplicate()

func speed_multiplier() -> float:
	if equipped_by_slot.is_empty(): return 1.0
	var penalty := 0.0
	for slot: String in SLOTS:
		var id := get_equipped_armor(slot)
		if id.begins_with("light_"): penalty += 0.012
		elif id.begins_with("medium_"): penalty += 0.038
		elif id.begins_with("heavy_"): penalty += 0.075
	return clampf(1.08 - penalty, 0.68, 1.08)

func _spawn_ground(id: String, local_at: Vector3) -> bool:
	if not _valid_id(id) or ground_items.has(id) or equipped_by_slot.values().has(id): return false
	var holder := Node3D.new()
	holder.name = "GroundArmor_" + id
	holder.position = local_at
	add_child(holder)
	var model: Node3D = null
	if is_instance_valid(visual) and visual.has_method("make_ground_preview"):
		model = visual.make_ground_preview(id)
	if is_instance_valid(model):
		holder.add_child(model)
	else:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(0.55, 0.15, 0.45)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.30, 0.43, 0.33) if id.begins_with("light_") else Color(0.47, 0.49, 0.50) if id.begins_with("medium_") else Color(0.25, 0.27, 0.29)
		mesh.material_override = mat
		holder.add_child(mesh)
	var label := Label3D.new()
	label.text = item_name(id)
	label.font_size = 18
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.36, 0)
	holder.add_child(label)
	ground_items[id] = holder
	return true

func _ground_local_near_player() -> Vector3:
	var local: Vector3 = site.to_local(player.global_position)
	return Vector3(local.x + 0.65, 0.15, local.z - 0.2)

func equip_ground(id: String) -> Dictionary:
	if not _usable() or not ground_items.has(id): return {"ok": false, "reason": "unavailable"}
	var slot := _slot_for(id)
	if slot.is_empty(): return {"ok": false, "reason": "invalid_item"}
	var old_id := get_equipped_armor(slot)
	var holder: Node3D = ground_items[id]
	var drop_at: Vector3 = holder.position
	# Commit the transfer together. No copy is created if a previous piece is swapped out.
	ground_items.erase(id)
	holder.queue_free()
	equipped_by_slot[slot] = id
	if not old_id.is_empty(): _spawn_ground(old_id, drop_at)
	_revision += 1
	_apply_visual(slot, id)
	equipped_changed.emit(slot, old_id, id)
	_refresh_menu()
	return {"ok": true, "slot": slot, "old_id": old_id, "item_id": id, "revision": _revision}

func remove(slot: String) -> Dictionary:
	if slot not in SLOTS or not _usable(): return {"ok": false, "reason": "unavailable"}
	var id := get_equipped_armor(slot)
	if id.is_empty(): return {"ok": false, "reason": "empty_slot"}
	equipped_by_slot.erase(slot)
	if not _spawn_ground(id, _ground_local_near_player()):
		equipped_by_slot[slot] = id
		return {"ok": false, "reason": "drop_failed"}
	_revision += 1
	_apply_visual(slot, "")
	equipped_changed.emit(slot, id, "")
	_refresh_menu()
	return {"ok": true, "item_id": id, "revision": _revision}

func _apply_visual(slot: String, id: String) -> void:
	if is_instance_valid(visual) and visual.has_method("set_armor"):
		visual.set_armor(slot, id)

func _usable() -> bool:
	if not is_instance_valid(site) or not is_instance_valid(weapons) or not is_instance_valid(player): return false
	if not weapons._owner_current() or not (bool(player.get("_free_mouse_look")) or _menu_open): return false
	if weapons.has_method("controls_blocked") and weapons.controls_blocked(): return false
	if bool(weapons.get("_catapult_stone_carry")): return false
	if player.get("_pose_authority") != &"on_foot" or bool(weapons.scene.get("preview_dead")): return false
	if bool(weapons.scene.get("preview_physics_fault")): return false
	if is_instance_valid(site.get("armory_storage")) and bool(site.armory_storage.window_open): return false
	return true

func focused_item_id() -> String:
	if not _usable() or _menu_open: return ""
	var camera: Camera3D = player.get_preview_camera()
	if not is_instance_valid(camera): return ""
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var best := ""
	var best_t := 3.4
	for id: String in ground_items:
		var holder: Node3D = ground_items[id]
		if not is_instance_valid(holder): continue
		var target := holder.global_position + Vector3.UP * 0.18
		if player.global_position.distance_to(target) > 2.6: continue
		var t := (target - origin).dot(forward)
		if t < 0.20 or t >= best_t: continue
		if (target - (origin + forward * t)).length() > 0.42: continue
		var query := PhysicsRayQueryParameters3D.create(origin, target)
		query.exclude = [player.get_rid()]
		var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and origin.distance_to(obstruction.position) < origin.distance_to(target) - 0.08: continue
		best = id; best_t = t
	return best

func interact() -> bool:
	var id := focused_item_id()
	if id.is_empty(): return false
	return bool(equip_ground(id).get("ok", false))

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_U:
		if _menu_open: _close_menu()
		elif _usable(): _open_menu()
		get_viewport().set_input_as_handled()
	elif code == KEY_ESCAPE and _menu_open:
		_close_menu(); get_viewport().set_input_as_handled()
	elif code == KEY_E and interact():
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(_hint): return
	_focus = focused_item_id()
	_hint.text = "E — надеть %s" % item_name(_focus) if not _focus.is_empty() else "U — снять броню" if not equipped_by_slot.is_empty() and _usable() else ""
	_hint.visible = not _hint.text.is_empty()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.name = "CastleArmorUI"; layer.layer = 30
	add_child(layer)
	_hint = Label.new(); _hint.name = "ArmorHint"
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-180, -128)
	_hint.custom_minimum_size = Vector2(360, 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	layer.add_child(_hint)
	_menu = PanelContainer.new(); _menu.name = "ArmorEquipment"; _menu.visible = false
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.position = Vector2(-180, -185)
	_menu.custom_minimum_size = Vector2(360, 370)
	layer.add_child(_menu)
	var column := VBoxContainer.new(); _menu.add_child(column)
	var title := Label.new(); title.text = "Броня — снять предмет"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for slot: String in SLOTS:
		var button := Button.new(); button.custom_minimum_size = Vector2(0, 50)
		button.pressed.connect(_on_remove_pressed.bind(slot))
		column.add_child(button); _menu_rows[slot] = button
	var close := Button.new(); close.text = "Закрыть (U)"; close.pressed.connect(_close_menu)
	column.add_child(close)
	_refresh_menu()

func _on_remove_pressed(slot: String) -> void:
	remove(slot)

func _refresh_menu() -> void:
	for slot: String in SLOTS:
		if not _menu_rows.has(slot): continue
		var id := get_equipped_armor(slot)
		var button: Button = _menu_rows[slot]
		button.text = "%s: %s" % [SLOT_NAMES[slot].capitalize(), item_name(id) if not id.is_empty() else "пусто"]
		button.disabled = id.is_empty()

func _open_menu() -> void:
	_menu_open = true; _menu.visible = true
	if player.has_method("set_mouse_captured"): player.set_mouse_captured(false)
	_refresh_menu()

func _close_menu() -> void:
	_menu_open = false; _menu.visible = false
	if is_instance_valid(player) and player.has_method("set_mouse_captured"): player.set_mouse_captured(true)
