extends SceneTree
## Real Godot controller input/physics, synthetic events; no native mouse/FPS claim.
const Player = preload("res://scripts/preview_player.gd")
var _player: Player
var _world: Node3D
var _errors: Array[String] = []
var _checks: int = 0
var _source_sha: String
var _native_unverified: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_source_sha = FileAccess.get_sha256("res://scripts/preview_player.gd")
	_world = Node3D.new()
	root.add_child(_world)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	_player = Player.new()
	_world.add_child(_player)
	await _frames(20)
	_check(_player.is_on_floor(), "real capsule settles on physical floor")
	_check(bool(_player.get_preview_status().free_mouse_look), "free look enabled by default in headless controller")
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "right mouse not held")
	var yaw: float = _player.get("_camera_yaw")
	var pitch: float = _player.get("_camera_pitch")
	_motion(Vector2(100.0, -20.0))
	_check(_near(_player.get("_camera_yaw"), yaw - 0.3), "mouse motion rotates yaw without RMB")
	_check(_near(_player.get("_camera_pitch"), pitch + 0.06), "mouse motion rotates pitch without RMB")
	_check(_near(_player.get_node("CameraYaw").rotation.y, yaw - 0.3), "yaw reaches actual camera pivot")
	_motion(Vector2(0.0, 10000.0))
	_check(_near(_player.get("_camera_pitch"), -1.05), "lower pitch limit")
	_motion(Vector2(0.0, -10000.0))
	_check(_near(_player.get("_camera_pitch"), 0.45), "upper pitch limit")
	var initial_distance: float = _player.camera_distance
	_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
	_check(_near(_player.camera_distance, initial_distance * exp(-0.12)), "wheel up uses exponential 0.12 scaling")
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, 1.0)
	_check(_near(_player.camera_distance, initial_distance), "opposite wheel steps recover unclamped distance")
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.5)
	_check(_near(_player.camera_distance, initial_distance * exp(0.06)), "fractional wheel factor retained")
	var before: float = _player.camera_distance
	_wheel(MOUSE_BUTTON_WHEEL_UP, 0.0)
	_check(_near(_player.camera_distance, before * exp(-0.12)), "zero factor falls back to one step")
	before = _player.camera_distance
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, 1.0, false)
	_check(_near(_player.camera_distance, before), "wheel release does not zoom")
	_wheel(MOUSE_BUTTON_WHEEL_UP, 1000.0)
	_check(_near(_player.camera_distance, 3.0), "zoom minimum 3m")
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, 1000.0)
	_check(_near(_player.camera_distance, 16.0), "zoom maximum 16m")
	_check(_near(_player.get_node("CameraYaw/CameraSpringArm").spring_length, 16.0), "zoom updates real spring arm")
	_key(KEY_ESCAPE)
	_check(not bool(_player.get_preview_status().free_mouse_look), "Esc releases free look")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc sets visible mouse mode")
	yaw = _player.get("_camera_yaw")
	_motion(Vector2(40.0, 20.0))
	_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
	_check(_near(_player.get("_camera_yaw"), yaw) and _near(_player.camera_distance, 16.0), "released pointer cannot orbit or zoom")
	_key(KEY_TAB, true)
	_check(not bool(_player.get_preview_status().free_mouse_look), "echo Tab ignored")
	_key(KEY_TAB)
	_check(bool(_player.get_preview_status().free_mouse_look), "Tab regains free look")
	if DisplayServer.get_name() == "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_native_unverified.append("Headless does not retain MOUSE_MODE_CAPTURED: physical OS cursor capture/release needs native validation")
	else:
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Tab sets captured mouse mode")
	_key(KEY_TAB)
	_check(not bool(_player.get_preview_status().free_mouse_look), "second Tab releases free look semantic state")
	_click(false)
	_check(not bool(_player.get_preview_status().free_mouse_look), "left release does not regain capture")
	_click(true)
	_check(bool(_player.get_preview_status().free_mouse_look), "left press regains capture")
	# Explicit LineEdit and TextEdit focus checks invoke the actual handler too:
	# even events reaching unhandled input may not move camera while editing text.
	for multiline: bool in [false, true]:
		var editor: Control = TextEdit.new() if multiline else LineEdit.new()
		editor.position = Vector2(10, 10)
		editor.size = Vector2(200, 60)
		root.add_child(editor)
		editor.grab_focus()
		await process_frame
		_check(root.gui_get_focus_owner() == editor, "actual text control owns focus")
		yaw = _player.get("_camera_yaw")
		pitch = _player.get("_camera_pitch")
		before = _player.camera_distance
		_motion(Vector2(80.0, -40.0), true)
		_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, true, true)
		_key(KEY_TAB, false, true)
		_check(_near(_player.get("_camera_yaw"), yaw) and _near(_player.get("_camera_pitch"), pitch) and _near(_player.camera_distance, before), "text focus suppresses orbit/zoom")
		_check(bool(_player.get_preview_status().free_mouse_look), "text focus suppresses capture toggle")
		Input.action_press(&"preview_move_forward")
		Input.action_press(&"preview_jump")
		await _frames(20)
		_check(_player.velocity.length() < 0.01 and _player.is_on_floor(), "text focus suppresses WASD and jump")
		_release()
		_key(KEY_ESCAPE, false, true)
		_click(true, true)
		_check(not bool(_player.get_preview_status().free_mouse_look), "text focus suppresses left-click recapture")
		editor.release_focus()
		editor.queue_free()
		await process_frame
		_click(true)
		_check(bool(_player.get_preview_status().free_mouse_look), "click regains look after text focus ends")
	_wheel(MOUSE_BUTTON_RIGHT, 1.0)
	_check(bool(_player.get("_right_mouse_down")), "RMB compatibility latch receives press")
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not bool(_player.get_preview_status().free_mouse_look) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "application focus-out releases capture")
	_check(not bool(_player.get("_right_mouse_down")), "focus-out clears RMB latch")
	yaw = _player.get("_camera_yaw")
	_motion(Vector2(40.0, 0.0))
	_check(_near(_player.get("_camera_yaw"), yaw), "focus-out leaves no free-look motion")
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not bool(_player.get_preview_status().free_mouse_look), "focus-in alone does not recapture")
	_click(true)
	# Rotate by real input events, then check actual camera-relative physics.
	yaw = _player.get("_camera_yaw")
	_motion(Vector2((yaw - PI * 0.5) / _player.mouse_sensitivity, 0.0))
	_check(_near(_player.get("_camera_yaw"), PI * 0.5), "input turns camera by 90 degrees")
	var start: Vector3 = _player.global_position
	_movement_key(KEY_W, true)
	await _frames(45)
	_movement_key(KEY_W, false)
	await _frames(20)
	var displacement: Vector3 = _player.global_position - start
	_check(displacement.x < -1.8 and absf(displacement.z) < 0.02, "W follows rotated camera forward on actual floor")
	start = _player.global_position
	_movement_key(KEY_D, true)
	await _frames(45)
	_movement_key(KEY_D, false)
	await _frames(20)
	displacement = _player.global_position - start
	_check(displacement.z < -1.8 and absf(displacement.x) < 0.02, "D follows rotated camera right on actual floor")
	start = _player.global_position
	_movement_key(KEY_S, true)
	await _frames(45)
	_movement_key(KEY_S, false)
	await _frames(20)
	displacement = _player.global_position - start
	_check(displacement.x > 1.8 and absf(displacement.z) < 0.02, "physical S mapping moves camera-relative backward")
	start = _player.global_position
	_movement_key(KEY_A, true)
	await _frames(45)
	_movement_key(KEY_A, false)
	await _frames(20)
	displacement = _player.global_position - start
	_check(displacement.z > 1.8 and absf(displacement.x) < 0.02, "physical A mapping moves camera-relative left")
	# Put a real wall along the current behind-camera direction. Spring arm must
	# shorten the camera ray while keeping the user's desired zoom distance.
	var arm: SpringArm3D = _player.get_node("CameraYaw/CameraSpringArm") as SpringArm3D
	var pivot: Node3D = _player.get_node("CameraYaw") as Node3D
	var pitch_now: float = _player.get("_camera_pitch")
	_motion(Vector2(0.0, pitch_now / _player.mouse_sensitivity))
	var behind: Vector3 = pivot.global_basis * Vector3.BACK
	var wall: StaticBody3D = _box(_player.global_position + behind * 2.5 + Vector3.UP * 2.0, Vector3(0.3, 4.0, 6.0))
	await _frames(30)
	_check(arm.get_hit_length() > 0.1 and arm.get_hit_length() < 2.5, "actual wall retracts spring camera arm")
	_check(_near(_player.camera_distance, 16.0) and _near(arm.spring_length, 16.0), "wall does not overwrite desired zoom")
	wall.queue_free()
	await _frames(30)
	_check(arm.get_hit_length() > 15.0, "camera distance recovers when wall removed")
	_check(FileAccess.get_sha256("res://scripts/preview_player.gd") == _source_sha, "production source unchanged during test")
	_release()
	_player.set_mouse_captured(false)
	print(JSON.stringify({"passed": _errors.is_empty(), "checks": _checks, "errors": _errors, "production_sha256": _source_sha, "native_unverified": _native_unverified,
		"scope": "Actual Godot headless synthetic InputEvent/notification + controller physics and real spring collision; no native pointer or GPU/FPS acceptance"}))
	quit(0 if _errors.is_empty() else 1)

func _dispatch(event: InputEvent, direct: bool = false) -> void:
	if direct:
		_player.call("_unhandled_input", event)
	else:
		root.push_input(event, true)

func _motion(relative: Vector2, direct: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(400, 400)
	_dispatch(event, direct)

func _wheel(button: MouseButton, factor: float, pressed: bool = true, direct: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.factor = factor
	event.pressed = pressed
	event.position = Vector2(400, 400)
	_dispatch(event, direct)

func _key(code: Key, echo: bool = false, direct: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	_dispatch(event, direct)

func _click(pressed: bool, direct: bool = false) -> void:
	_wheel(MOUSE_BUTTON_LEFT, 1.0, pressed, direct)

func _movement_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _box(at: Vector3, size_value: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collider.shape = shape
	body.position = at
	body.add_child(collider)
	_world.add_child(body)
	return body

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func _release() -> void:
	for action: StringName in [&"preview_move_forward", &"preview_move_back", &"preview_move_left", &"preview_move_right", &"preview_jump"]:
		Input.action_release(action)

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_errors.append(label)

func _finalize() -> void:
	_release()
