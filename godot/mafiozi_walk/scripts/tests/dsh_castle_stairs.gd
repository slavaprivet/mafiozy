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
	# Castle startup keeps moving the hero back to the gate until the catapult and
	# ship finish installing. Wait for that boot phase before testing the stair.
	while not bool(_scene.get("_catapult_at_castle")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_scene.set("_castle_spawn_frames", 0)
	_player.set_mouse_captured(true)
	await _settle(20)
	var base: Vector3 = _castle.global_position
	# South flight: its 74 treads run from z=39.16 to z=65.8 at x=-28.56.
	var half: float = float(_castle.call("wall_half"))
	var stair_x := -half * 0.42
	_player.global_position = base + Vector3(stair_x, 0.25, half - 30.5)
	_player.velocity = Vector3.ZERO
	# Camera forward is -Z; PI faces +Z, up the south flight.
	_player.set("_camera_yaw", PI)
	await _settle(10)
	var start_y := _player.global_position.y
	Input.action_press(_player.ACTION_FORWARD)
	var best := start_y
	var trace: Array[float] = []
	for i: int in 1800:
		await process_frame
		best = maxf(best, _player.global_position.y)
		if i % 150 == 0: trace.append(snappedf(_player.global_position.y, 0.01))
		if best >= 18.9 and _player.global_position.z >= base.z + half - 1.2:
			break
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(20)
	var end_y := _player.global_position.y
	var crest_pos := _player.global_position
	# Leave the landing and move along the widened wall walk.
	var start_x := _player.global_position.x
	var lowest_walk_y := end_y
	_player.set("_camera_yaw", -PI * 0.5)
	Input.action_press(_player.ACTION_FORWARD)
	for i: int in 250:
		await process_frame
		lowest_walk_y = minf(lowest_walk_y, _player.global_position.y)
	Input.action_release(_player.ACTION_FORWARD)
	var walk_dx := _player.global_position.x - start_x
	print("STAIRS_CLIMB start_y=", start_y, " best_y=", best, " end_y=", end_y,
		" crest_pos=", crest_pos, " walk_dx=", walk_dx, " lowest_walk_y=", lowest_walk_y,
		" trace=", str(trace), " pos=", _player.global_position)
	var failed: Array[String] = []
	if best < 18.5 or end_y < 18.5: failed.append("did_not_reach_wall_walk")
	if walk_dx < 1.5 or lowest_walk_y < 18.3: failed.append("walk_along_wall_blocked")
	print("STAIRS_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)
