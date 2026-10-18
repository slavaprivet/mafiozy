extends SceneTree
## DSH_CASTLE: the gate is a door, and the lever works it.
## The player is put by the lever, E is pressed, and the two leaves must swing open, then
## close again. Angles are measured from the hinges themselves.

var _scene: Node
var _player: CharacterBody3D
var _castle: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _tap(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("GATE_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	if _player == null or _castle == null: print("GATE_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	var lever: Vector3 = _castle.call("lever_position")
	_player.global_position = lever + Vector3(0.0, 0.2, -1.4)
	_player.velocity = Vector3.ZERO
	await _settle(20)
	var wants: bool = bool(_castle.call("wants_e"))
	print("GATE_LEVER pos=", lever, " player=", _player.global_position, " wants_e=", wants)
	# Driven directly as well: if the mechanism works when called and not when the key is
	# pressed, the fault is in the input path and not in the gate.
	_castle.call("set_gate", true)
	_castle.call("_advance_gate", 0.8)
	print("GATE_DIRECT angle=", _castle.call("gate_angle"))
	_castle.call("set_gate", false)
	_castle.call("_advance_gate", 2.0)
	print("GATE_DIRECT_CLOSED angle=", _castle.call("gate_angle"))
	await _tap(KEY_E)
	var opened := 0.0
	for i: int in 120:
		await process_frame
		opened = maxf(opened, float(_castle.call("gate_angle")))
	print("GATE_OPENED angle=", opened, " state=", bool(_castle.call("gate_open")))
	await _tap(KEY_E)
	var closed_at := 9.0
	for i: int in 150:
		await process_frame
		closed_at = float(_castle.call("gate_angle"))
	print("GATE_CLOSED angle=", closed_at, " state=", bool(_castle.call("gate_open")))
	var failed: Array[String] = []
	if not wants: failed.append("lever_not_reachable")
	# The swing is 1.6 s of real time; the headless run gets fewer physics steps in, so the
	# test asks that it is clearly OPENING, not that it finished.
	if opened < 0.35: failed.append("gate_did_not_open")
	if closed_at > 0.2: failed.append("gate_did_not_close")
	print("GATE_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)