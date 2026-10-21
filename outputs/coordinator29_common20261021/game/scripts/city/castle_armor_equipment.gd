extends Node3D
## Castle-only owner of physical armour items and the five equipment slots.
## Each item ID has exactly one location: ground or an equipped slot.

signal equipped_changed(slot: String, old_id: String, new_id: String)

const SLOTS := ["head", "torso", "hands", "legs", "feet"]
const TIERS := ["light", "medium", "heavy"]
const SLOT_NAMES := {"head": "шлем", "torso": "нагрудник", "hands": "перчатки", "legs": "штаны", "feet": "сапоги"}
const TIER_NAMES := {"light": "Лёгкий", "medium": "Средний", "heavy": "Тяжёлый"}
const TIER_NAMES_PLURAL := {"light": "Лёгкие", "medium": "Средние", "heavy": "Тяжёлые"}
const ArmorDamage31 = preload("res://scripts/combat/armor_damage31.gd")
const DISPLAY_SCALE := 1.65
var _stands: Dictionary = {}
static var _stand_mesh_cache: Dictionary = {}
static var _stand_material_cache: Dictionary = {}

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
var _hint_clock := 0.0
var _revision := 0
var _mobility := 1.0

func configure(castle_site: Node3D, arsenal: Node, armor_visual: Node = null) -> void:
	site = castle_site
	weapons = arsenal
	player = weapons.player as CharacterBody3D
	visual = armor_visual
	global_transform = site.global_transform
	_build_ui()
	add_to_group("castle_armor_displays")
	_create_armor_stand("medium", Transform3D(Basis.IDENTITY, Vector3(7.1, 0.32, -19.15)))
	_create_armor_stand("heavy", Transform3D(Basis.IDENTITY, Vector3(9.5, 0.32, -19.15)))
	var field: Node = weapons.scene.get("preview_battlefield")
	var props: Node = field.get_node_or_null("BattlefieldProps") if is_instance_valid(field) else null
	var tent: Node3D = props.get_node_or_null("Cover_tent_5") if is_instance_valid(props) else null
	if is_instance_valid(tent):
		var frame := global_transform.affine_inverse() * tent.global_transform
		_create_armor_stand("light", frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.0, 0.08, 0)))
	else:
		# Keep the only copy available in fixtures without a siege camp.
		_create_armor_stand("light", Transform3D(Basis.IDENTITY, Vector3(6.0, 0.10, -10.0)))
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
	return _mobility

func _update_mobility() -> void:
	_mobility = ArmorDamage31.movement_multiplier(equipped_by_slot)

func _spawn_ground(id: String, local_at: Vector3, display: bool = true) -> bool:
	if not _valid_id(id) or ground_items.has(id) or equipped_by_slot.values().has(id): return false
	var holder := Node3D.new()
	holder.name = "GroundArmor_" + id
	holder.position = local_at
	holder.set_meta("display", display)
	add_child(holder)
	var model: Node3D = null
	if is_instance_valid(visual) and visual.has_method("make_ground_preview"):
		model = visual.make_ground_preview(id)
	if is_instance_valid(model):
		model.position.y = 0.31 if display else 0.03
		model.scale = Vector3.ONE * DISPLAY_SCALE
		holder.add_child(model)
	else:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(0.8, 0.45, 0.65)
		mesh.mesh = box
		mesh.position.y = 0.50 if display else 0.25
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.30, 0.43, 0.33) if id.begins_with("light_") else Color(0.47, 0.49, 0.50) if id.begins_with("medium_") else Color(0.25, 0.27, 0.29)
		mesh.material_override = mat
		holder.add_child(mesh)
	var label := Label3D.new()
	label.text = item_name(id)
	label.font_size = 42
	label.pixel_size = 0.0038
	label.outline_size = 8
	label.modulate = Color(1.0, 0.92, 0.76)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.29 if display else 0.93, 0)
	label.visible = not display
	holder.add_child(label)
	ground_items[id] = holder
	return true

func _create_armor_stand(tier: String, frame: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ArmorCross_" + tier
	body.transform = frame
	body.set_meta("castle_furnishing", true)
	body.set_meta("surface", "wood")
	body.set_meta("armor_stand", tier)
	add_child(body)
	_stands[tier] = {"body": body, "frame": frame, "hp": 2.5, "broken": false}
	_stand_part(body, "upright", Vector3(0, 1.1, -0.10), Vector3(0.14, 2.2, 0.16))
	_stand_part(body, "shoulders", Vector3(0, 1.65, -0.10), Vector3(1.90, 0.14, 0.16))
	_stand_part(body, "base_cross", Vector3(0, 0.08, 0), Vector3(1.05, 0.16, 0.18))
	_stand_part(body, "base_rail", Vector3(0, 0.10, 0), Vector3(0.18, 0.20, 0.88))
	_stand_part(body, "peg", Vector3(-0.726, 1.66, 0.04), Vector3(0.07, 0.10, 0.30))
	_stand_part(body, "peg", Vector3(0.726, 1.66, 0.04), Vector3(0.07, 0.10, 0.30))
	for side: float in [-1.0, 1.0]:
		_stand_part(body, "glove_hanger", Vector3(side * .726, 1.55, .16), Vector3(.055, .25, .04))
	for slot: String in SLOTS:
		var id := tier + "_" + slot
		_spawn_ground(id, frame.origin)
		_mount_item(id, tier)

func _stand_part(body: StaticBody3D, key: String, at: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _stand_mesh(key, size)
	mesh.material_override = _stand_material("wood")
	mesh.position = at
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)

func _mount_item(id: String, stand_key: String) -> void:
	if not ground_items.has(id) or not _stands.has(stand_key): return
	var stand: Dictionary = _stands[stand_key]
	if stand.broken: return
	var holder: Node3D = ground_items[id]
	var slot := _slot_for(id)
	var offsets := {"feet": Vector3(0, 0.12, 0.10), "legs": Vector3(0, 0.40, 0.10),
		"torso": Vector3(0, 1.02, 0.10), "head": Vector3(0, 1.76, 0.10),
		"hands": Vector3(0.0, 1.0, 0.16)}
	var focus := {"feet": 0.16, "legs": 0.48, "torso": 0.45, "head": 0.30, "hands": 0.30}
	holder.transform = stand.frame * Transform3D(Basis.IDENTITY, offsets[slot])
	holder.set_meta("stand_key", stand_key)
	holder.set_meta("focus_offset", Vector3(0, focus[slot], 0.12))
	for child: Node in holder.get_children():
		if child is Node3D and not child is Label3D:
			child.position.y = 0.52 if slot == "hands" else 0.0
			child.rotation.x = PI if slot == "hands" else 0.0
	if slot == "hands":
		holder.set_meta("focus_offset", Vector3(.726,.26,.0))
		holder.set_meta("focus_offsets", [Vector3(.726,.26,0),Vector3(-.726,.26,0)])

func _floor_at(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(to_global(at + Vector3.UP * 0.6), to_global(at - Vector3.UP * 6.0))
	var excluded: Array[RID] = [player.get_rid()]
	for stand: Dictionary in _stands.values():
		if is_instance_valid(stand.body): excluded.append(stand.body.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return to_local(hit.position) + Vector3.UP * 0.04 if not hit.is_empty() else at

func apply_melee_hit(collider: Node, point: Vector3, speed: float, impulse: Vector3) -> Dictionary:
	if not is_instance_valid(collider) or collider.get_parent() != self or speed < 1.5: return {"ok": false}
	var key: String = str(collider.get_meta("armor_stand", ""))
	if not _stands.has(key) or _stands[key].broken: return {"ok": false}
	_stands[key].hp -= clampf(speed / 5.0, 0.5, 1.5)
	if _stands[key].hp <= 0: _break_stand(key, impulse)
	return {"ok": true, "broken": _stands[key].broken, "point": point}

func receive_castle_explosion(source: Node3D, event: Dictionary) -> void:
	if source != site: return
	var at: Vector3 = event.get("position", Vector3.ZERO)
	var radius := maxf(1.0, float(event.get("radius", 3.0)))
	for key: String in _stands:
		var stand: Dictionary = _stands[key]
		if stand.broken: continue
		var body: Node3D = stand.body
		var p := body.to_local(at)
		var nearest := Vector3(clampf(p.x, -0.67, 0.67), clampf(p.y, 0, 2.2), clampf(p.z, -0.44, 0.44))
		if p.distance_to(nearest) <= radius: _break_stand(key, Vector3(0.8, 2, 0.4))

func _break_stand(key: String, impulse: Vector3) -> void:
	var stand: Dictionary = _stands[key]
	if stand.broken: return
	stand.broken = true
	var body: StaticBody3D = stand.body
	body.collision_layer = 0
	body.collision_mask = 0
	body.hide()
	# Only four short-lived bodies per destroyed stand; intact displays have no physics tick.
	for i: int in 4:
		var fragment := RigidBody3D.new()
		fragment.mass = 0.6
		fragment.collision_layer = 0
		fragment.collision_mask = 1
		add_child(fragment)
		fragment.global_position = body.to_global(Vector3((i % 2 - 0.5) * 0.4, 0.4 + i * 0.4, 0))
		var mesh := MeshInstance3D.new()
		mesh.mesh = _stand_mesh("splinter", Vector3(0.12, 0.42, 0.13))
		mesh.material_override = _stand_material("wood")
		fragment.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new(); box.size = Vector3(0.12, 0.42, 0.13)
		shape.shape = box; fragment.add_child(shape)
		fragment.linear_velocity = impulse.limit_length(3.0) + Vector3((i % 2 - 0.5) * 2, 1, 0)
		fragment.angular_velocity = Vector3(i + 1, 2, -1)
		get_tree().create_timer(5.0).timeout.connect(fragment.queue_free)
	var n := 0
	for id: String in ground_items.keys():
		var holder: Node3D = ground_items[id]
		if str(holder.get_meta("stand_key", "")) != key: continue
		var at: Vector3 = stand.frame * Vector3((n % 3 - 1) * 0.62, 0.3, 0.55 + (n / 3) * 0.65)
		at = _floor_at(at)
		ground_items.erase(id)
		holder.queue_free()
		_spawn_ground(id, at, false)
		n += 1
	body.queue_free()

func _stand_mesh(key: String, size: Vector3) -> BoxMesh:
	if not _stand_mesh_cache.has(key):
		var mesh := BoxMesh.new(); mesh.size = size
		_stand_mesh_cache[key] = mesh
	return _stand_mesh_cache[key] as BoxMesh

func _stand_material(key: String) -> StandardMaterial3D:
	if not _stand_material_cache.has(key):
		var material := StandardMaterial3D.new()
		if key == "wood":
			material.albedo_color = Color(0.29, 0.19, 0.12); material.roughness = 0.83
		else:
			material.albedo_color = Color(0.53, 0.38, 0.20) if key == "light" else Color(0.48, 0.52, 0.53) if key == "medium" else Color(0.29, 0.33, 0.38)
			material.metallic = 0.52; material.roughness = 0.43
		_stand_material_cache[key] = material
	return _stand_material_cache[key] as StandardMaterial3D

func _ground_local_near_player() -> Vector3:
	var local: Vector3 = site.to_local(player.global_position)
	return _floor_at(local + Vector3(0.65, 0.0, -0.2))

func equip_ground(id: String) -> Dictionary:
	if not _usable() or not ground_items.has(id): return {"ok": false, "reason": "unavailable"}
	var slot := _slot_for(id)
	if slot.is_empty(): return {"ok": false, "reason": "invalid_item"}
	var old_id := get_equipped_armor(slot)
	var holder: Node3D = ground_items[id]
	var drop_at: Vector3 = holder.position
	var display: bool = bool(holder.get_meta("display", true))
	var stand_key: String = str(holder.get_meta("stand_key", ""))
	# Commit the transfer together. No copy is created if a previous piece is swapped out.
	ground_items.erase(id)
	holder.queue_free()
	equipped_by_slot[slot] = id
	if not old_id.is_empty():
		_spawn_ground(old_id, drop_at, display)
		if not stand_key.is_empty(): _mount_item(old_id, stand_key)
	_update_mobility()
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
	if not _spawn_ground(id, _ground_local_near_player(), false):
		equipped_by_slot[slot] = id
		return {"ok": false, "reason": "drop_failed"}
	_update_mobility()
	_revision += 1
	_apply_visual(slot, "")
	equipped_changed.emit(slot, id, "")
	_refresh_menu()
	return {"ok": true, "item_id": id, "revision": _revision}

func _apply_visual(slot: String, id: String) -> void:
	if is_instance_valid(visual) and visual.has_method("set_armor"):
		visual.set_armor(slot, id)

## Reconnect the unchanged inventory after the actor/rig is replaced on respawn.
## The new visual owner must already have been configured for its new rig.
func bind_visual(new_visual: Node) -> Dictionary:
	if not is_instance_valid(new_visual) or not new_visual.has_method("set_armor"):
		return {"ok": false, "reason": "visual_unavailable"}
	if is_instance_valid(visual) and visual != new_visual and is_instance_valid(visual.get("_rig")):
		for slot: String in SLOTS: visual.set_armor(slot, "")
	visual = new_visual
	if visual.has_method("reset_severed"): visual.reset_severed()
	var failed: Array[String] = []
	for slot: String in SLOTS:
		var id := get_equipped_armor(slot)
		if id.is_empty(): continue
		var result: Dictionary = visual.set_armor(slot, id)
		if not bool(result.get("ok", false)): failed.append(slot)
	return {"ok": failed.is_empty(), "failed": failed, "equipped": equipped_snapshot()}

func bind_actor(new_player: CharacterBody3D, new_visual: Node) -> Dictionary:
	if not is_instance_valid(new_player): return {"ok": false, "reason": "player_unavailable"}
	if not is_instance_valid(weapons) or weapons.player != new_player:
		return {"ok": false, "reason": "arsenal_player_mismatch"}
	if _menu_open:
		_menu_open = false
		_menu.visible = false
	player = new_player
	return bind_visual(new_visual)

func _exit_tree() -> void:
	if is_instance_valid(visual) and visual.has_method("set_armor") and is_instance_valid(visual.get("_rig")):
		for slot: String in SLOTS: visual.set_armor(slot, "")

func _usable() -> bool:
	if not is_instance_valid(site) or not is_instance_valid(weapons) or not is_instance_valid(player): return false
	if not weapons._owner_current() or not (bool(player.get("_free_mouse_look")) or _menu_open): return false
	if weapons.has_method("controls_blocked") and weapons.controls_blocked(): return false
	if bool(weapons.get("_catapult_stone_carry")) or bool(weapons.get("_ship_climb")): return false
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
	var best_t := origin.distance_to(player.global_position) + 2.6
	for id: String in ground_items:
		var holder: Node3D = ground_items[id]
		if not is_instance_valid(holder): continue
		for offset: Vector3 in holder.get_meta("focus_offsets", [holder.get_meta("focus_offset", Vector3.UP * .35)]):
			var target: Vector3 = holder.to_global(offset)
			if player.global_position.distance_to(target) > 2.6: continue
			var t := (target - origin).dot(forward)
			if t < 0.20: continue
			var aim_error := (target - (origin + forward * t)).length()
			if aim_error > 0.34 or aim_error >= best_t: continue
			var query := PhysicsRayQueryParameters3D.create(origin, target)
			var excluded: Array[RID] = [player.get_rid()]
			var stand_key: String = str(holder.get_meta("stand_key", ""))
			if _stands.has(stand_key) and is_instance_valid(_stands[stand_key].body):
				excluded.append(_stands[stand_key].body.get_rid())
			query.exclude = excluded
			var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			# A third-person camera can see the item through the owner's combat hitboxes.
			# Skip only this player's bone shapes; walls and other actors still block focus.
			for own_shape in 16:
				var collider: Node = obstruction.get("collider") as Node
				if not is_instance_valid(collider) or not player.is_ancestor_of(collider): break
				if not collider is CollisionObject3D or not collider.has_meta("sword_player_part50"): break
				excluded.append((collider as CollisionObject3D).get_rid())
				query.exclude = excluded
				obstruction = get_world_3d().direct_space_state.intersect_ray(query)
			if not obstruction.is_empty() and origin.distance_to(obstruction.position) < origin.distance_to(target) - 0.08: continue
			best = id; best_t = aim_error
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
	elif code == KEY_E:
		if is_instance_valid(weapons) and is_instance_valid(weapons.scene) and weapons.scene.has_method("_current_door_action"):
			var primary: Dictionary = weapons.scene.call("_current_door_action")
			if str(primary.get("key", "F")) == "E": return
		if interact(): get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(_hint): return
	_hint_clock += delta
	if _hint_clock < 0.08: return
	_hint_clock = 0.0
	_focus = focused_item_id()
	if not _focus.is_empty() and is_instance_valid(weapons) and is_instance_valid(weapons.scene) and weapons.scene.has_method("_current_door_action"):
		var primary: Dictionary = weapons.scene.call("_current_door_action")
		if str(primary.get("key", "F")) == "E": _focus = ""
	var next_text: String = "E — надеть %s" % item_name(_focus) if not _focus.is_empty() else "U — снять броню" if not equipped_by_slot.is_empty() and _usable() else ""
	if _hint.text != next_text:
		_hint.text = next_text
		_hint.visible = not next_text.is_empty()

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
