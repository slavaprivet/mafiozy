extends Node
const Horn = preload("car_horn.gd")
const Headlights = preload("car_headlights.gd")
var world: Node3D
var player: CharacterBody3D
var transport: Node
var horn: Node
var headlights: Node
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
	return true

func _refresh_hint() -> void:
	_hint.text = "B — взгляд назад · H — гудок · F — фары: " + ("ВКЛ" if headlights.enabled else "ВЫКЛ")

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
	set_process(held)
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
	elif looking_back and (event is InputEventMouseMotion or event is InputEventMouseButton):
		# Preserve the forward view and avoid shooting in a temporary rear view.
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if not ready_for_play: return
	horn.update_allowed()
	if looking_back:
		if allowed(): _apply_look()
		else: set_look_back(false)

func _process(_delta: float) -> void:
	if looking_back:
		if allowed(): _apply_look()
		else: set_look_back(false)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_PAUSED]:
		set_look_back(false)
		if is_instance_valid(horn): horn.request(false)

func _exit_tree() -> void:
	set_look_back(false)
	if is_instance_valid(horn): horn.request(false)
