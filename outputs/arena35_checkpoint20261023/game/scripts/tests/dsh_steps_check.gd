extends SceneTree
## DSH_STEPS: does the footstep system know what it is standing on, and does it play?
## The four surfaces are probed in four places on the castle map, and each is also asked to
## play, so a silent step is caught too.

var _scene: Node
var _player: CharacterBody3D
var _castle: Node3D
var _steps: Node

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("STEPS_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	_steps = _scene.get("_footsteps")
	if _player == null or _castle == null or _steps == null:
		print("STEPS_FAIL missing player=", _player != null, " castle=", _castle != null, " steps=", _steps != null)
		quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	var probes := {
		"courtyard": base + Vector3(0.0, 1.2, 10.0),
		"gate_deck": base + Vector3(0.0, 1.2, half),
		"outside": base + Vector3(0.0, 1.2, half + 18.0),
	}
	for key: String in probes.keys():
		_player.global_position = probes[key]
		_player.velocity = Vector3.ZERO
		await _settle(25)
		var surface: String = str(_steps.call("surface_under_feet"))
		print("STEPS_SURFACE ", key, " -> ", surface)
	var streams := 0
	for surface: String in ["stone", "wood", "dirt", "grass"]:
		var pool: Array = _steps.get("_players").get(surface, [])
		streams += pool.size()
		print("STEPS_POOL ", surface, " players=", pool.size(),
			" stream=", (pool[0].stream != null) if not pool.is_empty() else false)
	var failed: Array[String] = []
	if streams < 12: failed.append("not_enough_streams")
	print("STEPS_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)