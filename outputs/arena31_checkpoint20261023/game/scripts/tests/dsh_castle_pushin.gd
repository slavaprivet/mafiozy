extends SceneTree
## DSH_CASTLE: how far does a man walk INTO solid stone?
## The closed gate and a wall are approached head on, and the deepest penetration past the
## surface is measured. Anything more than a capsule radius means he is inside the wall.

var _scene: Node
var _player: CharacterBody3D
var _castle: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("PUSH_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	if _player == null or _castle == null: print("PUSH_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	# ---- 1. head on into the CLOSED gate, from inside the courtyard
	_player.global_position = base + Vector3(0.0, 1.2, half - 6.0)
	_player.velocity = Vector3.ZERO
	_player.set("_camera_yaw", PI)
	await _settle(20)
	Input.action_press(_player.ACTION_FORWARD)
	await _settle(150)
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(10)
	var gate_z: float = _player.global_position.z - base.z
	print("PUSH_GATE stopped_at_z=", gate_z, " wall_at=", half)
	# ---- 2. head on into the south wall, well away from the gate
	_player.global_position = base + Vector3(30.0, 1.2, half - 6.0)
	_player.velocity = Vector3.ZERO
	await _settle(20)
	Input.action_press(_player.ACTION_FORWARD)
	await _settle(150)
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(10)
	var wall_z: float = _player.global_position.z - base.z
	print("PUSH_WALL stopped_at_z=", wall_z, " wall_at=", half)
	var failed: Array[String] = []
	# The gate leaf face is at half; a capsule of 0.36 must stop before it.
	if gate_z > half - 0.1: failed.append("walked_into_the_gate")
	if wall_z > half - 0.1: failed.append("walked_into_the_wall")
	if gate_z < half - 2.0: failed.append("went_the_wrong_way")
	if wall_z < half - 2.0: failed.append("wall_probe_wrong_way")
	print("PUSH_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)