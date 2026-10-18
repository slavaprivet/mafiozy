extends SceneTree
## DSH_CASTLE: can he jump on this map, and does the dive still work?
## Feet in the floor and a dead jump are the same class of fault: the man is not standing
## on the surface the map thinks it gave him.

var _scene: Node
var _player: CharacterBody3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("JUMP_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	if _player == null: print("JUMP_FAIL player"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(40)
	var standing := _player.global_position
	var on_floor: bool = _player.is_on_floor()
	var feet_y: float = standing.y
	print("JUMP_STANDING pos=", standing, " on_floor=", on_floor,
		" feet_y=", feet_y, " camera_yaw=", _player.get("_camera_yaw"))
	# A plain jump.
	var base_y := _player.global_position.y
	await _key(KEY_SPACE, true)
	await _key(KEY_SPACE, false)
	var peak := base_y
	for i: int in 40:
		await process_frame
		peak = maxf(peak, _player.global_position.y)
	print("JUMP_SINGLE base_y=", base_y, " peak_y=", peak, " rise=", peak - base_y)
	await _settle(40)
	# The dive: two presses in quick succession.
	var dive_start := _player.global_position
	await _key(KEY_SPACE, true)
	await _key(KEY_SPACE, false)
	await _settle(3)
	await _key(KEY_SPACE, true)
	await _key(KEY_SPACE, false)
	var dive_peak := _player.global_position.y
	var dive_moved := 0.0
	for i: int in 50:
		await process_frame
		dive_peak = maxf(dive_peak, _player.global_position.y)
		dive_moved = maxf(dive_moved, dive_start.distance_to(_player.global_position))
	var pose: String = str(_player.get("_pose_authority"))
	print("JUMP_DIVE start_y=", dive_start.y, " peak_y=", dive_peak, " moved=", dive_moved, " pose=", pose)
	var failed: Array[String] = []
	if not on_floor: failed.append("not_standing")
	if peak - base_y < 0.45: failed.append("jump_dead")
	if dive_moved < 0.8: failed.append("dive_dead")
	print("JUMP_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)