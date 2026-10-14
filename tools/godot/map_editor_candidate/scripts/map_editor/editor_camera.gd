extends Camera3D
## Independent editor camera. The host calls motion/input only while editing.

var active := false
var mode := "fly"
var fly_speed := 25.0
var look_sensitivity := 0.003
var _previous_camera: Camera3D
var _previous_mouse_mode: int
var _right_down := false
var _right_distance := 0.0
var _keys: Dictionary = {}
var _fly_transform := Transform3D.IDENTITY
var _fly_far := 4000.0

func activate_from(game_camera: Camera3D) -> void:
	if active:
		return
	_previous_camera = game_camera
	_previous_mouse_mode = Input.mouse_mode
	if is_instance_valid(game_camera):
		global_transform = game_camera.global_transform
		fov = game_camera.fov
		near = game_camera.near
		far = game_camera.far
		keep_aspect = game_camera.keep_aspect
		cull_mask = game_camera.cull_mask
	active = true
	mode = "fly"
	projection = Camera3D.PROJECTION_PERSPECTIVE
	_fly_transform = global_transform
	_fly_far = far
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	make_current()

func deactivate_to(game_camera: Camera3D = null) -> void:
	if not active:
		return
	active = false
	_keys.clear()
	_right_down = false
	_right_distance = 0.0
	clear_current(false)
	var restore := _previous_camera if is_instance_valid(_previous_camera) else game_camera
	if is_instance_valid(restore):
		restore.make_current()
	Input.mouse_mode = _previous_mouse_mode

func set_view(view: String) -> void:
	if not active or view == mode or view not in ["top", "fly"]:
		return
	if view == "top":
		_fly_transform = global_transform
		_fly_far = far
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = 80.0
		global_position.y = maxf(global_position.y + 60.0, 80.0)
		far = maxf(far, 10000.0)
		rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	else:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		far = _fly_far
		global_transform = _fly_transform
	mode = view
	_right_down = false
	_right_distance = 0.0

func input_handle(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_SHIFT]:
			_keys[code] = event.pressed
			return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_right_down = event.pressed
			if event.pressed:
				_right_distance = 0.0
			return false # The host also observes click duration/distance for deletion.
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			if mode == "top":
				size = clampf(size * factor, 4.0, 2000.0)
			else:
				fly_speed = clampf(fly_speed / factor, 1.0, 500.0)
			return true
	if event is InputEventMouseMotion and _right_down:
		_right_distance += event.relative.length()
		if _right_distance > 4.0 and mode == "fly":
			rotation.y -= event.relative.x * look_sensitivity
			rotation.x = clampf(rotation.x - event.relative.y * look_sensitivity, -1.55, 1.55)
			rotation.z = 0.0
			return true
	return false

func process_motion(delta: float) -> void:
	if not active:
		return
	var horizontal := Vector3(float(_keys.get(KEY_D, false)) - float(_keys.get(KEY_A, false)), 0.0,
		float(_keys.get(KEY_S, false)) - float(_keys.get(KEY_W, false)))
	var movement: Vector3
	if mode == "top":
		movement = horizontal
	else:
		movement = global_basis * horizontal
	movement += Vector3.UP * (float(_keys.get(KEY_E, false)) - float(_keys.get(KEY_Q, false)))
	if movement.length_squared() > 0.0:
		global_position += movement.normalized() * fly_speed * (3.0 if _keys.get(KEY_SHIFT, false) else 1.0) * maxf(delta, 0.0)

func clear_motion() -> void:
	_keys.clear()
	_right_down = false
	_right_distance = 0.0

func focus_lost() -> void:
	clear_motion()

