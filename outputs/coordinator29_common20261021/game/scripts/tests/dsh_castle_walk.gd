extends SceneTree
## DSH_CASTLE: can a man actually get UP to the battlements and WALK along them?
## He is put at the foot of a flight and told to climb; then he is put on the wall-walk and
## told to walk its length. Both are measured.

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
	if packed == null: print("WALK_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	if _player == null or _castle == null: print("WALK_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	# ---- 1. climb the south flight: its foot is deep in the courtyard at lateral 0.42
	# The flight is laid at MINUS 0.42 of the wall half: the lateral axis comes from the
	# wall normal, so it runs the other way.
	var lateral: float = -half * 0.42
	_player.global_position = base + Vector3(lateral, 1.2, half - 2.2 - 27.0)
	# The south flight: its top is at the wall head, its foot twenty-seven metres back.
	_player.velocity = Vector3.ZERO
	_player.set("_camera_yaw", PI)
	await _settle(12)
	# What is above the foot of the flight? A ray straight down tells whether the wedge
	# exists at all.
	var probe_from: Vector3 = base + Vector3(lateral, 22.0, half - 2.2 - 12.0)
	var probe_hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(probe_from, probe_from - Vector3.UP * 24.0, 1))
	print("WALK_PROBE from=", probe_from, " hit=", probe_hit.get("position", "none"),
		" collider=", (probe_hit.get("collider") as Node).name if probe_hit.get("collider") else "none")
	var start_y := _player.global_position.y
	Input.action_press(_player.ACTION_FORWARD)
	var best := start_y
	for i: int in 2400:
		await process_frame
		best = maxf(best, _player.global_position.y)
		if best > 18.4: break
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(20)
	print("WALK_CLIMB start_y=", start_y, " best_y=", best, " now=", _player.global_position)
	# ---- 2. walk along the wall head
	# A clear stretch of the south wall, far from the gatehouse and the stair heads.
	_player.global_position = base + Vector3(-44.0, 19.6, half - 0.6)
	_player.velocity = Vector3.ZERO
	_player.set("_camera_yaw", PI * 0.5)
	await _settle(25)
	var along_from: Vector3 = _player.global_position
	Input.action_press(_player.ACTION_FORWARD)
	await _settle(200)
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(10)
	var walked: float = along_from.distance_to(_player.global_position)
	var still_up: float = _player.global_position.y - base.y
	print("WALK_ALONG walked=", walked, " height=", still_up, " pos=", _player.global_position)
	var failed: Array[String] = []
	if best < 17.0: failed.append("cannot_reach_the_wall")
	if walked < 2.0: failed.append("cannot_walk_the_wall")
	if still_up < 17.0: failed.append("fell_off")
	print("WALK_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)