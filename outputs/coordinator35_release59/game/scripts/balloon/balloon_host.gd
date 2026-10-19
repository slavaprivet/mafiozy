extends Node3D
## DSH_BALLOON: the siege balloon in the camp, its E prompt and the flight HUD.
##
## E next to the basket boards; E again leaves (and if the balloon is airborne,
## the player simply falls). The balloon itself owns the flight model; this host
## owns suspension of the walking controller, the camera and the top-centre plates.

const BalloonScript = preload("res://scripts/balloon/siege_balloon.gd")
const MAX_CARGO := 8
const BOARD_RANGE := 3.8
const BOARD_ALTITUDE := 3.2
const RIDING_CAMERA_DISTANCE := 4.6

var balloon: CharacterBody3D
var player: CharacterBody3D
var status := "idle"
var error := ""

var world: Node3D
var _aboard := false
var _cargo := 0
var _cargo_models: Array[Node3D] = []
var _spawn_spot := Vector3.ZERO
var _spawn_yaw := 0.0
var _pop_timer := 0.0
var player_hp := 100
var _hp_label: Label
var _death_layer: CanvasLayer
var _dead := false
var _fall_active := false
var _fall_start_y := 0.0
var _fall_last_y := 0.0
var _fall_max_speed := 0.0
var _fall_timer := 0.0
var _fall_airborne := false
var _crash_handled := false
var _walking_layer := 0
var _walking_mask := 0
var _walking_camera_distance := 0.0
var _walking_camera_pitch := 0.0
var _walking_pivot_y := 0.0
var _camera_distance_owned := false
var _board_key := false

var _hud: CanvasLayer
var _banner: PanelContainer
var _banner_label: Label
var _banner_state := -1
var _banner_tween: Tween
var _panel: PanelContainer
var _altitude_label: Label
var _heat_label: Label
var _heat_fill: ColorRect
var _cargo_label: Label
var _hint: Label
var _viewport_size := Vector2(1280, 720)
var _heat_track_width := 188.0

func install(world_in: Node3D, existing_player: CharacterBody3D) -> Dictionary:
	if is_instance_valid(balloon):
		return {"ok": false, "reason": "already_installed"}
	if not is_instance_valid(world_in) or existing_player == null or not existing_player.is_inside_tree():
		return {"ok": false, "reason": "no_world"}
	player = existing_player
	self.world = world_in
	var heading := float(player.get("_heading"))
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))
	var spot: Vector3 = _choose_spot(forward, right)
	var body: CharacterBody3D = BalloonScript.new()
	body.name = "SiegeBalloon"
	add_child(body)
	if not body.setup(spot, heading):
		body.queue_free()
		return {"ok": false, "reason": "balloon_setup_failed"}
	balloon = body
	_spawn_spot = spot
	_spawn_yaw = heading
	_build_hud()
	status = "ready"
	print("DSH_BALLOON_STATUS ready at=", spot)
	return {"ok": true, "balloon": balloon, "position": spot, "status": status}

func is_aboard() -> bool:
	return _aboard and is_instance_valid(balloon)

## Try a few open camp directions, with a 3.2 m sphere probe so the envelope does
## not spawn inside a wall or the gate.
func _choose_spot(forward: Vector3, right: Vector3) -> Vector3:
	var candidates: Array[Vector3] = [
		player.global_position + forward * 2.0 + right * 9.5,
		player.global_position + forward * 2.0 - right * 9.5,
		player.global_position - forward * 7.0 + right * 9.0,
		player.global_position - forward * 7.0 - right * 9.0,
	]
	for candidate: Vector3 in candidates:
		var at := candidate
		at.y = _ground_height(at)
		if _clear_spot(at):
			return at
	var fallback: Vector3 = candidates[0]
	fallback.y = _ground_height(fallback)
	return fallback

func _clear_spot(at: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return true
	var shape := SphereShape3D.new()
	shape.radius = 4.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), at + Vector3.UP * 3.5)
	query.collision_mask = 1
	query.exclude = [player.get_rid()] if is_instance_valid(player) else []
	return world.direct_space_state.intersect_shape(query, 1).is_empty()

func wants_e() -> bool:
	if not is_instance_valid(balloon) or not is_instance_valid(player):
		return false
	if _aboard:
		return true
	if bool(balloon.get("popped")):
		return false
	if bool(player.get("_mount_mode")):
		return false
	if float(balloon.call("altitude")) > BOARD_ALTITUDE:
		return false
	return player.global_position.distance_to(balloon.global_position) <= BOARD_RANGE

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(balloon) or not is_instance_valid(player):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_G:
		var barrels_g: Variant = self.world.get("preview_power_barrels") if is_instance_valid(self.world) else null
		var holding: bool = is_instance_valid(barrels_g) and bool(barrels_g.get("carrying"))
		if _aboard and _cargo > 0 and not holding:
			drop_cargo()
			get_viewport().set_input_as_handled()
		return
	if code != KEY_E:
		return
	if not bool(player.get("_free_mouse_look")):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if _aboard:
		var barrels_e: Variant = self.world.get("preview_power_barrels") if is_instance_valid(self.world) else null
		if is_instance_valid(barrels_e) and bool(barrels_e.get("carrying")):
			return
		if take_slot_barrel():
			get_viewport().set_input_as_handled()
			return
		if leave_now():
			get_viewport().set_input_as_handled()
		return
	if not wants_e():
		return
	if board_now():
		get_viewport().set_input_as_handled()

func board_now() -> bool:
	if _aboard or not is_instance_valid(balloon) or not is_instance_valid(player):
		return false
	if bool(player.get("_mount_mode")):
		error = "horse_mounted"
		return false
	if float(balloon.call("altitude")) > BOARD_ALTITUDE:
		error = "balloon_airborne"
		return false
	if player.global_position.distance_to(balloon.global_position) > BOARD_RANGE:
		error = "too_far"
		return false
	_walking_layer = player.collision_layer
	_walking_mask = player.collision_mask
	_walking_camera_distance = float(player.get("camera_distance"))
	_walking_camera_pitch = float(player.get("_camera_pitch"))
	_camera_distance_owned = true
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	player.call("set_vehicle_hold", true)
	balloon.set("rider", player)
	balloon.set("pilot_inside", true)
	var barrels: Variant = self.world.get("preview_power_barrels") if is_instance_valid(self.world) else null
	if is_instance_valid(barrels) and barrels.has_method("take_carried") and bool(barrels.call("take_carried")):
		load_barrel(barrels)
	var arm: SpringArm3D = player.get("_spring_arm") as SpringArm3D
	if is_instance_valid(arm):
		arm.add_excluded_object(balloon.get_rid())
		arm.spring_length = RIDING_CAMERA_DISTANCE
	var pivot: Node3D = player.get("_yaw_pivot") as Node3D
	if is_instance_valid(pivot):
		_walking_pivot_y = pivot.position.y
		pivot.position.y = float(player.get("model_target_height")) * 0.79 + 1.15
	player.set("camera_distance", RIDING_CAMERA_DISTANCE)
	player.set("_camera_pitch", -0.18)
	player.call("_update_camera_rotation")
	player.set_preview_pose_authority(&"on_foot", true)
	_aboard = true
	_banner_state = -1
	status = "aboard"
	print("DSH_BALLOON_BOARD player=", player.global_position, " balloon=", balloon.global_position)
	return true

func leave_now() -> bool:
	if not _aboard or not is_instance_valid(balloon) or not is_instance_valid(player):
		return false
	var balloon_altitude := float(balloon.call("altitude"))
	balloon.set("rider", null)
	balloon.set("pilot_inside", false)
	_aboard = false
	player.set_physics_process(true)
	player.call("set_vehicle_hold", false)
	player.collision_layer = _walking_layer
	player.collision_mask = _walking_mask
	player.velocity = Vector3.ZERO
	var arm: SpringArm3D = player.get("_spring_arm") as SpringArm3D
	if is_instance_valid(arm):
		arm.remove_excluded_object(balloon.get_rid())
		if _camera_distance_owned:
			arm.spring_length = _walking_camera_distance
	_camera_distance_owned = false
	player.set("camera_distance", _walking_camera_distance)
	player.set("_camera_pitch", _walking_camera_pitch)
	var pivot: Node3D = player.get("_yaw_pivot") as Node3D
	if is_instance_valid(pivot):
		pivot.position.y = _walking_pivot_y
	player.call("_update_camera_rotation")
	var spot := _leave_spot(balloon_altitude)
	player.global_transform = Transform3D(Basis(), spot)
	if balloon_altitude > 2.0:
		_start_fall()
	var yaw := float(balloon.rotation.y)
	player._heading = yaw
	var visual: Node3D = player.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = yaw + deg_to_rad(float(player.get("visual_yaw_degrees")))
	player.set_preview_pose_authority(&"on_foot", true)
	_banner_state = -1
	status = "ready"
	print("DSH_BALLOON_LEAVE at=", spot, " balloon_altitude=", balloon_altitude)
	return true

func _leave_spot(altitude: float) -> Vector3:
	var around := Vector3(cos(float(balloon.rotation.y)), 0.0, -sin(float(balloon.rotation.y)))
	var at := balloon.global_position + around * 1.9
	if altitude > 1.8:
		# Airborne bail-out: step out of the basket and let the normal fall happen.
		at = balloon.global_position + around * 1.3 + Vector3.UP * 0.7
		return at
	at.y = _ground_height(at)
	return at

func _physics_process(_delta: float) -> void:
	_place_world_prompt()
	if not is_instance_valid(balloon) or not is_instance_valid(player):
		return
	_update_fall(_delta)
	if bool(balloon.get("crash_done")):
		if not _crash_handled:
			_crash_handled = true
			print("DSH_BALLOON_BASKET_CRASH at=", balloon.global_position)
		if _aboard:
			leave_now()
	if bool(balloon.get("popped")):
		if _aboard:
			leave_now()
		_pop_timer += _delta
		if _pop_timer > 7.0 and (float(balloon.call("altitude")) < 0.6 or _pop_timer > 15.0):
			_pop_timer = 0.0
			_crash_handled = false
			balloon.call("respawn", _spawn_spot, _spawn_yaw)
		_update_hud()
		return
	if _aboard and not is_instance_valid(balloon.get("rider")):
		# Something removed the rider (respawn/teleport): restore the walker.
		leave_now()
	_update_hud()

func _ground_height(at: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return at.y
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, at.y + 6.0, at.z), Vector3(at.x, at.y - 30.0, at.z), 1)
	ray.exclude = [player.get_rid()] if is_instance_valid(player) else []
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	return float(hit.position.y) + 0.02 if not hit.is_empty() else at.y

## ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "BalloonHud"
	_hud.layer = 13
	add_child(_hud)
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.06, 0.85), 10.0))
	_hud.add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_banner.add_child(row)
	var keycap := PanelContainer.new()
	keycap.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.78, 0.22), 6.0))
	row.add_child(keycap)
	var key_label := Label.new()
	key_label.text = "E"
	key_label.add_theme_font_size_override("font_size", 18)
	key_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
	keycap.add_child(key_label)
	_banner_label = Label.new()
	_banner_label.add_theme_font_size_override("font_size", 18)
	_banner_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	row.add_child(_banner_label)
	_banner.visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.06, 0.84), 10.0))
	_hud.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "ВОЗДУШНЫЙ ШАР"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	column.add_child(title)
	_altitude_label = Label.new()
	_altitude_label.add_theme_font_size_override("font_size", 13)
	_altitude_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	column.add_child(_altitude_label)
	var heat_track := ColorRect.new()
	heat_track.color = Color(0.10, 0.09, 0.08)
	heat_track.custom_minimum_size = Vector2(_heat_track_width, 7)
	heat_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heat_track)
	_heat_fill = ColorRect.new()
	_heat_fill.color = Color(0.85, 0.46, 0.12)
	_heat_fill.size = Vector2(0, 7)
	_heat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_track.add_child(_heat_fill)
	_heat_label = Label.new()
	_heat_label.add_theme_font_size_override("font_size", 12)
	_heat_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.64))
	column.add_child(_heat_label)
	_cargo_label = Label.new()
	_cargo_label.add_theme_font_size_override("font_size", 12)
	_cargo_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.64))
	column.add_child(_cargo_label)
	_hint = Label.new()
	_hint.text = "WASD — смещать вес по корзине · Space — подъём · G — сбросить бочку · E — выйти"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.66, 0.62, 0.54))
	column.add_child(_hint)
	_panel.visible = false
	_hp_label = Label.new()
	_hp_label.name = "PlayerHp"
	_hp_label.position = Vector2(24.0, 72.0)
	_hp_label.add_theme_font_size_override("font_size", 15)
	_hp_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.76))
	_hp_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03))
	_hp_label.add_theme_constant_override("outline_size", 5)
	_hp_label.text = "Здоровье 100"
	_hud.add_child(_hp_label)
	_death_layer = CanvasLayer.new()
	_death_layer.name = "BalloonDeath"
	_death_layer.layer = 100
	_death_layer.visible = false
	add_child(_death_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.025, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_layer.add_child(shade)
	var death_label := Label.new()
	death_label.text = "ВЫ ПОГИБЛИ\nРазбились при падении\n\nR — начать заново"
	death_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 30)
	death_label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	_death_layer.add_child(death_label)

func _panel_style(colour: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

func _update_hud() -> void:
	_update_hp_label()
	var altitude := float(balloon.call("altitude"))
	var lift := bool(balloon.get("lift_on"))
	var gust := bool(balloon.get("gust_active"))
	var wind: Vector3 = balloon.call("wind_now")
	var wind_speed := Vector2(wind.x, wind.z).length()
	var text := ""
	if _aboard:
		var barrels_hud: Variant = self.world.get("preview_power_barrels") if is_instance_valid(self.world) else null
		if is_instance_valid(barrels_hud) and bool(barrels_hud.get("carrying")):
			text = ""
		elif _slot_barrel_near() != null:
			text = "Взять бочку"
		else:
			text = "Покинуть"
	elif wants_e():
		var barrels_hold: Variant = self.world.get("preview_power_barrels") if is_instance_valid(self.world) else null
		if is_instance_valid(barrels_hold) and bool(barrels_hold.get("carrying")):
			text = ""
		else:
			text = "Сесть"
	var state := 0 if text.is_empty() else (1 if _aboard else 2)
	if state != _banner_state:
		_banner_state = state
		if text.is_empty():
			_animate_banner(false)
		else:
			_banner_label.text = text
			_banner.visible = true
			_banner.reset_size()
			_place_world_prompt()
			_animate_banner(true)
	_panel.visible = _aboard
	if not _aboard:
		return
	_altitude_label.text = "Высота %d м · Ветер %s %.1f м/с" % [
		int(round(altitude)), _wind_arrow(wind), wind_speed]
	_heat_label.text = "Перегрев %d%% · %s" % [int(round(float(balloon.get("heat")) * 100.0)),
		"ПОДЪЁМ" if lift else "планирование"]
	_heat_fill.size = Vector2(maxf(0.0, _heat_track_width * clampf(float(balloon.get("heat")), 0.0, 1.0)), 7.0)
	_heat_fill.visible = float(balloon.get("heat")) > 0.004
	_heat_fill.color = Color(0.85, 0.46, 0.12) if float(balloon.get("heat")) < 0.82 else Color(0.92, 0.18, 0.10)
	var crew := int(balloon.get("crew")) + (1 if _aboard else 0)
	var total_weight := int(round(float(balloon.get("weight"))))
	var cargo_text := (" · Бочки %d/%d" % [_cargo, MAX_CARGO]) if _cargo > 0 else ""
	var holes := int(balloon.get("holes"))
	if holes > 0:
		cargo_text += " · Дыры %d/4" % holes
	if gust:
		_cargo_label.text = "Экипаж %d · %d кг%s · ПОРЫВ ВЕТРА %s %.1f м/с" % [
			crew, total_weight, cargo_text, _wind_arrow(wind), wind_speed]
		_cargo_label.add_theme_color_override("font_color", Color(0.95, 0.52, 0.24))
	else:
		_cargo_label.text = "Экипаж %d · %d кг%s" % [crew, total_weight, cargo_text]
		_cargo_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.64))
	_layout_top_center(_panel, 70.0)

func _wind_arrow(wind: Vector3) -> String:
	if wind.length_squared() < 0.01:
		return "—"
	var angle := atan2(wind.x, wind.z)
	var directions := ["Ю", "ЮВ", "В", "СВ", "С", "СЗ", "З", "ЮЗ"]
	var index := int(round(fposmod(angle, TAU) / (TAU / 8.0))) % 8
	return directions[index]

func _animate_banner(show: bool) -> void:
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.pivot_offset = _banner.size * 0.5
	if show:
		_banner.visible = true
		_banner.modulate.a = 0.0
		_banner.scale = Vector2(0.86, 0.86)
		_banner_tween = create_tween().set_parallel(true)
		_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.16)
		_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_banner_tween = create_tween().set_parallel(true)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.12)
		_banner_tween.tween_property(_banner, "scale", Vector2(0.92, 0.92), 0.12)
		_banner_tween.chain().tween_callback(func() -> void: _banner.visible = false)

func _place_world_prompt() -> void:
	if not is_instance_valid(_banner) or not _banner.visible or not is_instance_valid(balloon):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := balloon.global_position + Vector3.UP * 2.8
	if camera.is_position_behind(at):
		return
	var screen := camera.unproject_position(at)
	var view := get_viewport().get_visible_rect().size
	_banner.reset_size()
	_banner.position = Vector2(
		clampf(screen.x - _banner.size.x * 0.5, 12.0, maxf(12.0, view.x - _banner.size.x - 12.0)),
		clampf(screen.y - _banner.size.y - 12.0, 12.0, maxf(12.0, view.y - _banner.size.y - 12.0)))

func _layout_top_center(control: Control, top: float) -> void:
	var viewport := get_viewport()
	if viewport != null:
		_viewport_size = viewport.get_visible_rect().size
	var size := control.size
	if size.x <= 0.0:
		control.reset_size()
		size = control.size
	control.position = Vector2((_viewport_size.x - size.x) * 0.5, top)

func snapshot() -> Dictionary:
	var balloon_snapshot: Dictionary = balloon.snapshot() if is_instance_valid(balloon) else {}
	return {"status": status, "aboard": _aboard, "error": error,
		"player": player.global_position if is_instance_valid(player) else Vector3.ZERO,
		"player_layer": player.collision_layer if is_instance_valid(player) else -1,
		"player_mask": player.collision_mask if is_instance_valid(player) else -1,
		"banner": _banner_label.text if is_instance_valid(_banner) and _banner.visible else "",
		"cargo": _cargo,
		"balloon": balloon_snapshot, "wants_e": wants_e()}

func dispose() -> void:
	if _aboard and is_instance_valid(balloon) and is_instance_valid(player) and is_inside_tree() and balloon.is_inside_tree():
		leave_now()
	_aboard = false

func drop_cargo() -> bool:
	if not _aboard or _cargo <= 0 or not is_instance_valid(balloon) or not is_instance_valid(world):
		return false
	var barrels: Variant = world.get("preview_power_barrels")
	if not is_instance_valid(barrels):
		return false
	var forward := -balloon.global_transform.basis.z
	var right := balloon.global_transform.basis.x
	var origin := player.global_position + forward * 1.0 + Vector3.UP * 0.4
	var velocity := forward * 2.6 + Vector3.UP * 1.0 + right * 0.1
	barrels.call("throw_barrel", origin, velocity)
	_cargo -= 1
	_remove_cargo_visual()
	return true

func _add_cargo_visual(barrels: Node) -> void:
	if not is_instance_valid(balloon):
		return
	var basket: Node3D = balloon.get("_basket_node") as Node3D
	if not is_instance_valid(basket) or not barrels.has_method("_barrel_model"):
		return
	var model: Node3D = barrels.call("_barrel_model", basket, false)
	if not is_instance_valid(model):
		return
	var index := _cargo_models.size()
	var slots: Array[Vector3] = [
		Vector3(-0.95, 0.12, -1.0), Vector3(0.95, 0.12, -1.0),
		Vector3(-0.95, 0.12, 1.05), Vector3(0.95, 0.12, 1.05),
		Vector3(-0.55, 0.12, -1.2), Vector3(0.55, 0.12, -1.2),
		Vector3(-0.55, 0.12, 0.35), Vector3(0.55, 0.12, 0.35),
	]
	model.position = slots[mini(index, slots.size() - 1)]
	_cargo_models.append(model)

func load_barrel(barrels: Node) -> bool:
	if _cargo >= MAX_CARGO:
		return false
	_cargo += 1
	_add_cargo_visual(barrels)
	return true

func _slot_barrel_near(reach: float = 1.25) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for model: Node3D in _cargo_models:
		if not is_instance_valid(model):
			continue
		var distance := player.global_position.distance_to(model.global_position)
		if distance < best_distance:
			best_distance = distance
			best = model
	return best

func take_slot_barrel() -> bool:
	if _cargo <= 0:
		return false
	var model: Node3D = _slot_barrel_near()
	if model == null:
		return false
	var barrels: Variant = self.world.get("preview_power_barrels") if is_instance_valid(self.world) else null
	if not is_instance_valid(barrels) or not barrels.has_method("carry_from_slot"):
		return false
	_cargo_models.erase(model)
	_cargo = maxi(0, _cargo - 1)
	_panel.visible = _aboard
	_update_hud()
	return bool(barrels.call("carry_from_slot", model))

func _remove_cargo_visual() -> void:
	if _cargo_models.is_empty():
		return
	var model: Node3D = _cargo_models.pop_back()
	if is_instance_valid(model):
		model.queue_free()


func _start_fall() -> void:
	_fall_active = true
	_fall_airborne = false
	_fall_start_y = player.global_position.y
	_fall_last_y = player.global_position.y
	_fall_max_speed = 0.0
	_fall_timer = 0.0

func _update_fall(delta: float) -> void:
	if not _fall_active or not is_instance_valid(player) or _dead:
		return
	if not _fall_airborne:
		if not player.is_on_floor() or player.global_position.y < _fall_start_y - 0.6:
			_fall_airborne = true
			_fall_last_y = player.global_position.y
		return
	_fall_start_y = maxf(_fall_start_y, player.global_position.y)
	var step := _fall_last_y - player.global_position.y
	if step > 0.0:
		_fall_max_speed = minf(60.0, maxf(_fall_max_speed, step / maxf(delta, 0.001)))
	_fall_last_y = player.global_position.y
	_fall_max_speed = minf(60.0, maxf(_fall_max_speed, maxf(0.0, -player.velocity.y)))
	_fall_timer += delta
	if player.is_on_floor() or _fall_timer > 6.0:
		var height := maxf(0.0, _fall_start_y - player.global_position.y)
		var speed := _fall_max_speed
		_fall_active = false
		var damage := int(maxf(0.0, height - 2.0) * 7.0 + maxf(0.0, speed - 8.0) * 5.0)
		if damage > 0:
			player_hp = maxi(0, player_hp - damage)
			_update_hp_label()
			print("DSH_BALLOON_FALL height=", height, " speed=", speed, " damage=", damage, " hp=", player_hp)
			if player_hp <= 0:
				_die()

func _update_hp_label() -> void:
	if is_instance_valid(_hp_label):
		_hp_label.text = "Здоровье %d" % player_hp

func _die() -> void:
	if _dead:
		return
	_dead = true
	if is_instance_valid(world):
		world.set("preview_dead", true)
	if is_instance_valid(player):
		player.set_physics_process(false)
	if is_instance_valid(_death_layer):
		_death_layer.visible = true
