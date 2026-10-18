extends SceneTree
## The flow exactly as a player does it: NOTHING is set up first. Q opens the arsenal, a
## card is clicked, and then the state is read: what the host thinks is equipped, whether
## the prototype is installed and selected, whether it considers itself active, and
## whether the model is visible. Hands staying empty must show up in one of those.

var _scene: Node
var _player: CharacterBody3D
var _weapons: Node

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	Input.parse_input_event(move)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await process_frame

func _report(label: String) -> void:
	var snap: Dictionary = {}
	var proto: Variant = _scene.get("preview_sword_prototype")
	if proto != null: snap = proto.call("snapshot")
	var state: Dictionary = _weapons.get("fire_state") if is_instance_valid(_weapons) else {}
	print("FLOW ", label,
		" host_weapon=", str(state.get("weaponId", "?")),
		" proto_installed=", proto != null,
		" proto_weapon=", str(snap.get("weapon", "?")),
		" selected=", bool(snap.get("selected", false)),
		" active=", bool(snap.get("weapon_active", false)),
		" visible=", bool(snap.get("weapon_visible", false)),
		" free_look=", bool(_player.get("_free_mouse_look")),
		" pose=", str(_player.get("_pose_authority")),
		" menu=", bool(_weapons.get("menu_open")) if is_instance_valid(_weapons) else "?")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("FLOW_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("FLOW_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	await _settle(30)
	_report("start")
	# Exactly what a player does: press Q, then click the sword's card.
	await _key(KEY_Q)
	await _settle(20)
	_report("after_Q")
	var ui: Node = _weapons.get("_walk_ui")
	var choices: Dictionary = ui.get("choices") if ui != null else {}
	if choices.has("sword"):
		var button: Button = (choices["sword"] as Dictionary).get("button")
		var centre: Vector2 = button.get_global_rect().get_center()
		await _click(centre)
		await _settle(20)
		_report("after_click_sword")
	# Then the hotkey path, with no menu.
	await _key(KEY_3)
	await _settle(20)
	_report("after_key_3")
	quit(0)