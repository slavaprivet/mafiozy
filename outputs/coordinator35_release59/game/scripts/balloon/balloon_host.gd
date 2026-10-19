extends Node3D
## DSH_BALLOON: the siege balloon in the camp, its E prompt and the flight HUD.
##
## E next to the basket boards; E again leaves (and if the balloon is airborne,
## the player simply falls). The balloon itself owns the flight model; this host
## owns suspension of the walking controller, the camera and the top-centre plates.

const BalloonScript = preload("res://scripts/balloon/siege_balloon.gd")
const BOARD_RANGE := 3.8
const BOARD_ALTITUDE := 3.2
const RIDING_CAMERA_DISTANCE := 4.6

var balloon: CharacterBody3D
var player: CharacterBody3D
var status := "idle"
var error := ""

var _aboard := false
var _spawn_spot := Vector3.ZERO
var _spawn_yaw := 0.0
var _pop_timer := 0.0
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
var _panel: PanelContainer
var _altitude_label: Label
var _heat_label: Label
var _heat_fill: ColorRect
var _cargo_label: Label
var _hint: Label
var _viewport_size := Vector2(1280, 720)
var _heat_track_width := 188.0

func install(world: Node3D, existing_player: CharacterBody3D) -> Dictionary:
	if is_instance_valid(balloon):
		return {"ok": false, "reason": "already_installed"}
	if not is_instance_valid(world) or existing_player == null or not existing_player.is_inside_tree():
		return {"ok": false, "reason": "no_world"}
	player = existing_player
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
	if code != KEY_E:
		return
	if not bool(player.get("_free_mouse_look")):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if _aboard:
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
	if not is_instance_valid(balloon) or not is_instance_valid(player):
		return
	if bool(balloon.get("popped")):
		if _aboard:
			leave_now()
		_pop_timer += _delta
		if _pop_timer > 7.0 and (float(balloon.call("altitude")) < 0.6 or _pop_timer > 15.0):
			_pop_timer = 0.0
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
	_hint.text = "WASD — смещать вес по корзине · Space — подъём · E — выйти"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.66, 0.62, 0.54))
	column.add_child(_hint)
	_panel.visible = false

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
	var altitude := float(balloon.call("altitude"))
	var lift := bool(balloon.get("lift_on"))
	var gust := bool(balloon.get("gust_active"))
	var wind: Vector3 = balloon.call("wind_now")
	var wind_speed := Vector2(wind.x, wind.z).length()
	var text := ""
	if _aboard:
		text = "Покинуть корзину"
	elif wants_e():
		text = "Сесть в корзину"
	var state := 0 if text.is_empty() else (1 if _aboard else 2)
	if state != _banner_state:
		_banner_state = state
		if text.is_empty():
			_banner.visible = false
		else:
			_banner_label.text = text
			_banner.visible = true
			_banner.reset_size()
			_layout_top_center(_banner, 26.0)
	_panel.visible = _aboard
	if not _aboard:
		return
	_altitude_label.text = "Высота %d м / макс %d м · Ветер %s %.1f м/с" % [
		int(round(altitude)), int(round(float(balloon.get("max_altitude")))),
		_wind_arrow(wind), wind_speed]
	_heat_label.text = "Перегрев %d%% · %s" % [int(round(float(balloon.get("heat")) * 100.0)),
		"ПОДЪЁМ" if lift else "планирование"]
	_heat_fill.size = Vector2(maxf(0.0, _heat_track_width * clampf(float(balloon.get("heat")), 0.0, 1.0)), 7.0)
	_heat_fill.visible = float(balloon.get("heat")) > 0.004
	_heat_fill.color = Color(0.85, 0.46, 0.12) if float(balloon.get("heat")) < 0.82 else Color(0.92, 0.18, 0.10)
	var crew := int(balloon.get("crew")) + (1 if _aboard else 0)
	var total_weight := int(round(float(balloon.get("weight"))))
	if gust:
		_cargo_label.text = "Экипаж %d · %d кг · ПОРЫВ ВЕТРА %s %.1f м/с" % [
			crew, total_weight, _wind_arrow(wind), wind_speed]
		_cargo_label.add_theme_color_override("font_color", Color(0.95, 0.52, 0.24))
	else:
		_cargo_label.text = "Экипаж %d · %d кг" % [crew, total_weight]
		_cargo_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.64))
	_layout_top_center(_panel, 70.0)

func _wind_arrow(wind: Vector3) -> String:
	if wind.length_squared() < 0.01:
		return "—"
	var angle := atan2(wind.x, wind.z)
	var directions := ["Ю", "ЮВ", "В", "СВ", "С", "СЗ", "З", "ЮЗ"]
	var index := int(round(fposmod(angle, TAU) / (TAU / 8.0))) % 8
	return directions[index]

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
		"balloon": balloon_snapshot, "wants_e": wants_e()}

func dispose() -> void:
	if _aboard:
		leave_now()
