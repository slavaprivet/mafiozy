extends SceneTree
## DSH_CASTLE: can a man walk all the way round the outside of the castle?
## He is put on the ring road at one corner and walks; the distance covered and the
## height he keeps are the evidence.

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
	if packed == null: print("RING_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	if _player == null or _castle == null: print("RING_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	# On the ring, beside the east wall, walking north along it.
	var ring: float = half + 6.5
	_player.global_position = base + Vector3(ring, 1.2, 0.0)
	_player.velocity = Vector3.ZERO
	_player.set("_camera_yaw", 0.0)
	await _settle(25)
	var from: Vector3 = _player.global_position
	Input.action_press(_player.ACTION_FORWARD)
	var worst_y := 999.0
	for i: int in 420:
		await process_frame
		worst_y = minf(worst_y, _player.global_position.y)
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(15)
	var walked: float = from.distance_to(_player.global_position)
	print("RING_WALK from=", from, " to=", _player.global_position,
		" walked=", walked, " lowest_y=", worst_y)
	var failed: Array[String] = []
	if walked < 15.0: failed.append("could_not_walk_round")
	if worst_y < -0.5: failed.append("fell_through_the_ground")
	print("RING_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)