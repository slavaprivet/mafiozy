extends Node
## Driver presentation only. Never reads input or writes transport controls.
## NativeVehicleBody publishes linear_velocity in metres/second; no map scale.
const SAMPLE_INTERVAL := 0.1
const PANEL_SIZE := Vector2(284.0, 176.0)
const EDGE_MARGIN := 16.0
const IVORY := Color("f1e8d6")
const BRASS := Color("dfb968")
const MUTED := Color("99aaa9")
const BRAKE_COLOR := Color("e4a17f")

var ready_for_play := false
var _world: Node3D
var _player: CharacterBody3D
var _transport: Node
var _headlights: Node
var _body: RigidBody3D
var _generation := -1
var _layer: CanvasLayer
var _panel: Panel
var _speed_label: Label
var _direction_label: Label
var _light_state: Label
var _brake_state: Label
var _light_key: Panel
var _brake_key: Panel
var _key_idle: StyleBoxFlat
var _key_lit: StyleBoxFlat
var _key_braked: StyleBoxFlat
var _elapsed := 0.0
var _visible := false
var _have_sample := false
var _headlights_on := false
var _handbrake_on := false
var _sampled_linear_velocity := Vector3.ZERO
var _sampled_speed_mps := 0.0
var _speed_kmh := 0.0
var _sampled_at_msec := 0
var _update_count := 0
var _text_update_count := 0

func _init() -> void:
	name = "CarDashboardOwner"
	process_priority = 110
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

func configure(game: Node3D, actor: CharacterBody3D, transport: Node, headlights: Node) -> bool:
	if ready_for_play or not is_inside_tree(): return false
	if not is_instance_valid(game) or not game.is_inside_tree() or game.is_queued_for_deletion(): return false
	if not is_instance_valid(actor) or not actor.is_inside_tree() or not is_instance_valid(transport) or not is_instance_valid(headlights): return false
	if not transport.is_inside_tree() or not headlights.is_inside_tree(): return false
	var body: RigidBody3D = transport.get("body") as RigidBody3D
	if body == null or not body.is_inside_tree() or not body.has_method("submit_authoritative_control"): return false
	for existing: Node in get_tree().get_nodes_in_group("mafiozi_car_dashboard"):
		if existing != self and existing.get("_world") == game: return false
	_world = game
	_player = actor
	_transport = transport
	_headlights = headlights
	_body = body
	_generation = int(body.get_meta("life_generation", -1))
	_elapsed = 0.0
	_visible = false
	_have_sample = false
	_update_count = 0
	_text_update_count = 0
	_build_panel()
	add_to_group("mafiozi_car_dashboard")
	_world.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	ready_for_play = true
	update()
	set_process(true)
	return true

func _build_panel() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CarDashboardLayer"
	_layer.layer = 3
	add_child(_layer)
	_panel = Panel.new()
	_panel.name = "CarDashboard"
	_passive(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -PANEL_SIZE.x - EDGE_MARGIN
	_panel.offset_top = -PANEL_SIZE.y - EDGE_MARGIN
	_panel.offset_right = -EDGE_MARGIN
	_panel.offset_bottom = -EDGE_MARGIN
	_panel.visible = false
	var face := _style(Color(0.035, 0.055, 0.065, 0.93), Color(0.53, 0.47, 0.34, 0.55), 1)
	face.border_width_top = 2
	face.border_color = Color("b49a64")
	face.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	face.shadow_size = 5
	_panel.add_theme_stylebox_override("panel", face)
	_layer.add_child(_panel)
	_label(_panel, "DashboardTitle", "ЗА РУЛЁМ", Vector2(16, 11), Vector2(185, 17), 11, BRASS)
	_line(Vector2(235, 19), Vector2(32, 1), Color(0.87, 0.73, 0.41, 0.65))
	_speed_label = _label(_panel, "SpeedValue", "00", Vector2(14, 26), Vector2(139, 64), 50, IVORY)
	_speed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_speed_label.add_theme_constant_override("shadow_offset_y", 2)
	_direction_label = _label(_panel, "SpeedDirection", "СКОРОСТЬ", Vector2(158, 39), Vector2(109, 17), 10, MUTED)
	_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var units := _label(_panel, "SpeedUnit", "км/ч", Vector2(191, 60), Vector2(76, 23), 16, IVORY)
	units.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line(Vector2(16, 96), Vector2(252, 1), Color(0.87, 0.73, 0.41, 0.35))
	_key_idle = _style(Color(0.13, 0.17, 0.18, 0.85), Color(0.48, 0.54, 0.53, 0.5), 1)
	_key_lit = _style(Color(0.28, 0.24, 0.14, 0.95), BRASS, 1)
	_key_braked = _style(Color(0.28, 0.17, 0.13, 0.95), BRAKE_COLOR, 1)
	_light_key = _key("HeadlightKey", "F", Vector2(16, 108), 13)
	_brake_key = _key("HandbrakeKey", "ПРОБЕЛ", Vector2(16, 139), 10)
	_label(_panel, "HeadlightCaption", "Фары", Vector2(94, 110), Vector2(76, 21), 13, IVORY)
	_label(_panel, "HandbrakeCaption", "Ручник", Vector2(94, 141), Vector2(76, 21), 13, IVORY)
	_light_state = _label(_panel, "HeadlightState", "ВЫКЛ", Vector2(176, 111), Vector2(91, 19), 11, MUTED)
	_brake_state = _label(_panel, "HandbrakeState", "ОТПУЩЕН", Vector2(176, 142), Vector2(91, 19), 10, MUTED)
	_light_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_brake_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style

func _passive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE

func _label(parent: Control, label_name: String, text: String, position: Vector2, box: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.position = position
	label.size = box
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_passive(label)
	parent.add_child(label)
	return label

func _key(key_name: String, text: String, position: Vector2, font_size: int) -> Panel:
	var key := Panel.new()
	key.name = key_name
	key.position = position
	key.size = Vector2(66, 23)
	key.add_theme_stylebox_override("panel", _key_idle)
	_passive(key)
	_panel.add_child(key)
	var label := _label(key, "KeyCaption", text, Vector2.ZERO, key.size, font_size, IVORY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return key

func _line(position: Vector2, box: Vector2, color: Color) -> void:
	var line := ColorRect.new()
	line.position = position
	line.size = box
	line.color = color
	_passive(line)
	_panel.add_child(line)

func _driver_current() -> bool:
	if not ready_for_play or not is_instance_valid(_world) or not _world.is_inside_tree() or _world.is_queued_for_deletion(): return false
	if not is_instance_valid(_player) or not _player.is_inside_tree() or _player.is_queued_for_deletion(): return false
	if not is_instance_valid(_transport) or not _transport.is_inside_tree() or _transport.is_queued_for_deletion() or not is_instance_valid(_headlights): return false
	if not _headlights.is_inside_tree() or _headlights.is_queued_for_deletion(): return false
	if not is_instance_valid(_body) or not _body.is_inside_tree() or _body.is_queued_for_deletion(): return false
	if _transport.get("body") != _body or int(_body.get_meta("life_generation", -1)) != _generation: return false
	if bool(_world.get("preview_dead")) or bool(_world.get("preview_physics_fault")): return false
	return bool(_transport.get("ready_for_play")) and _transport.get("phase") == "SEATED" and _transport.get("active_seat") == "front_left" and _player.get("_pose_authority") == &"vehicle"

func _set_visible(value: bool) -> void:
	if value == _visible: return
	_visible = value
	if is_instance_valid(_panel): _panel.visible = value

func _set_text(label: Label, value: String) -> void:
	if label.text == value: return
	label.text = value
	_text_update_count += 1

func update() -> void:
	if not _driver_current():
		_set_visible(false)
		return
	var velocity: Vector3 = _body.linear_velocity
	if not velocity.is_finite():
		_set_visible(false)
		return
	_sampled_linear_velocity = velocity
	# Horizontal road speed also includes sideways sliding, without counting a fall.
	_sampled_speed_mps = Vector2(velocity.x, velocity.z).length()
	_speed_kmh = _sampled_speed_mps * 3.6
	_sampled_at_msec = Time.get_ticks_msec()
	_update_count += 1
	_set_text(_speed_label, "%02d" % roundi(_speed_kmh))
	var signed_speed: float = velocity.dot(-_body.global_basis.z.normalized())
	_set_text(_direction_label, "ЗАДНИЙ ХОД" if signed_speed < -0.15 else "СКОРОСТЬ")
	var next_lights := bool(_headlights.get("enabled"))
	# _handbrake changes only after NativeVehicleBody accepts a control sequence.
	var next_brake := bool(_body.get("_handbrake"))
	if not _have_sample or next_lights != _headlights_on:
		_headlights_on = next_lights
		_set_text(_light_state, "ВКЛ" if next_lights else "ВЫКЛ")
		_light_state.add_theme_color_override("font_color", BRASS if next_lights else MUTED)
		_light_key.add_theme_stylebox_override("panel", _key_lit if next_lights else _key_idle)
	if not _have_sample or next_brake != _handbrake_on:
		_handbrake_on = next_brake
		_set_text(_brake_state, "ЗАТЯНУТ" if next_brake else "ОТПУЩЕН")
		_brake_state.add_theme_color_override("font_color", BRAKE_COLOR if next_brake else MUTED)
		_brake_key.add_theme_stylebox_override("panel", _key_braked if next_brake else _key_idle)
	_have_sample = true
	_set_visible(true)

func _process(delta: float) -> void:
	if not ready_for_play or not is_finite(delta) or delta <= 0.0: return
	_elapsed += delta
	if _elapsed < SAMPLE_INTERVAL: return
	_elapsed = fmod(_elapsed, SAMPLE_INTERVAL)
	update()

func snapshot() -> Dictionary:
	return {"ready": ready_for_play, "visible": _visible, "driving": _driver_current(),
		"speed_kmh": _speed_kmh, "speed_text": _speed_label.text if is_instance_valid(_speed_label) else "",
		"sampled_speed_mps": _sampled_speed_mps, "sampled_linear_velocity": _sampled_linear_velocity,
		"sampled_at_msec": _sampled_at_msec, "headlights_on": _headlights_on, "handbrake_on": _handbrake_on,
		"update_count": _update_count, "text_update_count": _text_update_count,
		"panel_rect": Rect2(_panel.global_position, _panel.size) if is_instance_valid(_panel) else Rect2()}

func dispose() -> void:
	ready_for_play = false
	set_process(false)
	_set_visible(false)
	if is_instance_valid(_world) and _world.tree_exiting.is_connected(dispose): _world.tree_exiting.disconnect(dispose)
	if is_instance_valid(_layer):
		_layer.hide()
		_layer.queue_free()
	_layer = null
	_panel = null
	_speed_label = null
	_direction_label = null
	_light_state = null
	_brake_state = null
	_light_key = null
	_brake_key = null
	_key_idle = null
	_key_lit = null
	_key_braked = null
	_world = null
	_player = null
	_transport = null
	_headlights = null
	_body = null
	_have_sample = false
	if is_inside_tree() and is_in_group("mafiozi_car_dashboard"): remove_from_group("mafiozi_car_dashboard")

func _exit_tree() -> void:
	dispose()
