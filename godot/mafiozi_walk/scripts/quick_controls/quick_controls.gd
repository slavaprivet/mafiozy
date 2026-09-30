extends Node
const Horn = preload("car_horn.gd")
const Headlights = preload("car_headlights.gd")
const RearLights = preload("car_rear_lights.gd")
const DayNight = preload("day_night.gd")
const DayClock = preload("day_night_clock.gd")
var world: Node3D
var player: CharacterBody3D
var transport: Node
var horn: Node
var headlights: Node
var rear_lights: Node
var day_night: Node
var day_clock: RefCounted
var _light_elapsed := 0.0
var _hint_elapsed := 0.0
var _last_clock_tick := 0
var _jump_elapsed := -1.0
var _jump_from := 0.0
var _jump_span := 0.0
var looking_back := false
var ready_for_play := false
var _hint: Label

func _init() -> void:
	process_priority = 100
	process_physics_priority = 100
	set_process(false)
	set_physics_process(false)
	set_process_input(false)

func configure(game: Node3D) -> bool:
	if ready_for_play or not is_instance_valid(game): return false
	world = game
	player = world.get("_player")
	transport = world.get("preview_transport")
	if not is_instance_valid(player): return false
	for existing in get_tree().get_nodes_in_group("mafiozi_quick_controls"):
		if existing != self and existing.get("world") == world: return false
	add_to_group("mafiozi_quick_controls")
	horn = Horn.new()
	add_child(horn)
	horn.configure(world, player, transport)
	headlights = Headlights.new()
	add_child(headlights)
	headlights.configure(world, player, transport)
	rear_lights = RearLights.new()
	add_child(rear_lights)
	rear_lights.configure(world, transport)
	day_night = DayNight.new()
	add_child(day_night)
	day_night.configure(world)
	var saved_clock: Variant = get_tree().root.get_meta("mafiozi_visual_clock") if get_tree().root.has_meta("mafiozi_visual_clock") else null
	day_clock = saved_clock if saved_clock is RefCounted and saved_clock.get_script() == DayClock else DayClock.new()
	get_tree().root.set_meta("mafiozi_visual_clock", day_clock)
	day_night.apply_hour(day_clock.hour)
	headlights.set_daylight(day_night.daylight)
	_last_clock_tick = Time.get_ticks_usec()
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hint = Label.new()
	_refresh_hint()
	_hint.position = Vector2(16, 164)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color("ebc77f"))
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)
	ready_for_play = true
	set_process_input(true)
	set_physics_process(true)
	set_process(true)
	return true

func _refresh_hint() -> void:
	_hint.text = "B — взгляд назад · H — гудок · F — фары: " + ("ВКЛ" if headlights.enabled else "ВЫКЛ")
	if is_instance_valid(day_night) and day_night.enabled:
		_hint.text += "\n" + day_clock.label() + " · " + ("Время идёт" if day_clock.running else "Время на паузе") + " · N — день/ночь · T — пауза времени"

func jump_day_night() -> void:
	_jump_from = day_clock.hour
	var target := 22.0 if day_clock.hour >= 6.0 and day_clock.hour < 18.0 else 12.0
	_jump_span = fposmod(target - _jump_from, 24.0)
	_jump_elapsed = 0.0

func _advance_day(real_seconds: float) -> void:
	if not day_night.enabled or not is_finite(real_seconds) or real_seconds <= 0.0: return
	if _jump_elapsed >= 0.0:
		_jump_elapsed = minf(2.0, _jump_elapsed + real_seconds)
		var weight := smoothstep(0.0, 2.0, _jump_elapsed)
		day_clock.set_hour(_jump_from + _jump_span * weight)
		if _jump_elapsed >= 2.0: _jump_elapsed = -1.0
	else:
		day_clock.advance(real_seconds)
	_light_elapsed += real_seconds
	_hint_elapsed += real_seconds
	var interval := 1.0 / 30.0 if _jump_elapsed >= 0.0 else 0.25
	if _light_elapsed >= interval:
		_light_elapsed = 0.0
		day_night.apply_hour(day_clock.hour)
		headlights.set_daylight(day_night.daylight)
	if _hint_elapsed >= 0.5:
		_hint_elapsed = 0.0
		_refresh_hint()

func allowed() -> bool:
	if not ready_for_play or not is_instance_valid(world) or not is_instance_valid(player): return false
	if get_tree().paused: return false
	if DisplayServer.get_name() != "headless" and (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not get_window().has_focus()): return false
	if world.get("preview_dead") or world.get("preview_physics_fault") or not player._free_mouse_look: return false
	if player._text_control_focused(): return false
	var w: Node = player.get("_weapon_host")
	if is_instance_valid(w) and (w.controls_blocked() or w.get("_aiming") or w.get("_held")): return false
	if player._pose_authority == &"on_foot": return true
	return player._pose_authority == &"vehicle" and is_instance_valid(transport) and transport.phase == "SEATED"

func set_look_back(held: bool) -> bool:
	if held and not allowed(): return false
	looking_back = held
	if is_instance_valid(player) and player.is_inside_tree() and is_instance_valid(player._yaw_pivot) and player._yaw_pivot.is_inside_tree():
		if held: _apply_look()
		else: player._update_camera_rotation()
	return true

func _apply_look() -> void:
	# Presentation only: movement/steering continue using the original yaw.
	var rear_yaw: float = player._camera_yaw + PI
	if player._pose_authority == &"vehicle" and is_instance_valid(transport) and is_instance_valid(transport.body):
		var rear: Vector3 = transport.body.global_basis.z
		rear_yaw = atan2(rear.x, rear.z) + PI
	player._yaw_pivot.global_basis = Basis(Vector3.UP, rear_yaw)

func _input(event: InputEvent) -> void:
	if not ready_for_play: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_B and not event.echo:
			if not event.pressed or allowed():
				set_look_back(event.pressed)
				get_viewport().set_input_as_handled()
		elif code == KEY_H and not event.echo:
			horn.request(event.pressed)
			if not event.pressed or allowed(): get_viewport().set_input_as_handled()
		elif code == KEY_F and headlights.allowed():
			if event.pressed and not event.echo:
				headlights.toggle()
				_refresh_hint()
			get_viewport().set_input_as_handled()
		elif code in [KEY_N, KEY_T] and day_night.enabled and allowed():
			if event.pressed and not event.echo:
				if code == KEY_N: jump_day_night()
				else:
					day_clock.toggle_running()
					if not day_clock.running: _jump_elapsed = -1.0
				_refresh_hint()
			get_viewport().set_input_as_handled()
	elif looking_back and (event is InputEventMouseMotion or event is InputEventMouseButton):
		# Preserve the forward view and avoid shooting in a temporary rear view.
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if not ready_for_play: return
	horn.update_allowed()
	rear_lights.update_lights(headlights.enabled)
	if looking_back:
		if allowed(): _apply_look()
		else: set_look_back(false)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if ready_for_play:
		_advance_day(float(now - _last_clock_tick) / 1000000.0)
	_last_clock_tick = now
	if looking_back:
		if allowed(): _apply_look()
		else: set_look_back(false)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_PAUSED]:
		set_look_back(false)
		if is_instance_valid(horn): horn.request(false)
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED]:
		_last_clock_tick = Time.get_ticks_usec()

func _exit_tree() -> void:
	set_look_back(false)
	if is_instance_valid(horn): horn.request(false)
