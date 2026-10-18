extends SceneTree
## DSH_CASTLE: can a man actually climb to the wall-walk?
## The player is placed at the foot of the stair and walks straight up it; his height is
## watched frame by frame. If the stair stops him, his height stops too.

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
	if packed == null: print("STAIRS_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	if _player == null or _castle == null: print("STAIRS_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(20)
	var base: Vector3 = _castle.global_position
	# The east flight runs up towards -Z from z = +29. Put him at its foot and turn the
	# camera so that FORWARD means up the stairs.
	_player.global_position = base + Vector3(-16.6, 1.2, 30.5)
	_player.velocity = Vector3.ZERO
	# The camera yaw is what defines forward, and forward is the camera's -Z: yaw 0
	# looks towards -Z, which is up the stair. With yaw PI he walked into the wall and
	# the stair was never touched - the first test was measuring the wrong thing.
	_player.set("_camera_yaw", 0.0)
	await _settle(10)
	var start_y := _player.global_position.y
	Input.action_press(_player.ACTION_FORWARD)
	var best := start_y
	var trace: Array[float] = []
	for i: int in 320:
		await process_frame
		best = maxf(best, _player.global_position.y)
		if i % 40 == 0: trace.append(snappedf(_player.global_position.y, 0.01))
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(20)
	var end_y := _player.global_position.y
	print("STAIRS_CLIMB start_y=", start_y, " best_y=", best, " end_y=", end_y,
		" trace=", str(trace), " pos=", _player.global_position)
	var failed: Array[String] = []
	if best < 8.0: failed.append("did_not_climb")
	print("STAIRS_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)