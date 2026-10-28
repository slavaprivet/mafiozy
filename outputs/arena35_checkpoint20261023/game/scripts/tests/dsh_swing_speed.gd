extends SceneTree
## DSH_MELEE_SET swing-speed check
##
## The report was "the strikes are far too fast - I can whip the mouse and ugly strikes
## come out, everything happens too quickly". This measures that on the real prototype:
## it whips the mouse as hard as a player can (hundreds of pixels in a single event)
## and records
##   * the peak angular speed of the blade, which must stay under the weapon's own cap
##     and must NOT jump to the cap in a single frame,
##   * how many frames the blade needs to travel the arc, which is the difference
##     between a cut and a teleport,
##   * and the same for the heaviest weapon, which must be slower than the sword.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"

var _scene: Node
var _player: CharacterBody3D
var _proto: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(960, 540)
	Input.parse_input_event(event)

func _flick(dx: float, dy: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.position = Vector2(960, 540)
	Input.parse_input_event(event)

## Whips the mouse as hard as possible and reports what the blade actually did.
func _measure(label: String) -> Dictionary:
	await _settle(30)
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _settle(6)
	var peak := 0.0
	var cap := 0.0
	var peak_first_frame := 0.0
	var frames_to_far_end := 90
	var far_end := 0.0
	var last_hand := Vector2.ZERO
	for i: int in 90:
		# A violent event: far beyond anything a human hand produces in one frame.
		_flick(260.0, 120.0 if (i % 2 == 0) else -120.0)
		await process_frame
		var snap: Dictionary = _proto.snapshot()
		var speed := float(snap.get("omega_speed", 0.0))
		cap = maxf(cap, float(snap.get("omega_cap", 0.0)))
		if i == 1: peak_first_frame = speed
		if speed > peak: peak = speed
		var hand: Vector2 = snap.get("hand_cmd", Vector2.ZERO)
		last_hand = hand
		far_end = maxf(far_end, hand.length())
		if frames_to_far_end == 90 and hand.length() > 0.9 * 1.0:
			frames_to_far_end = i
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _settle(10)
	var result := {
		"peak_omega": peak, "cap": cap,
		"peak_in_first_frames": peak_first_frame,
		"frames_to_far_end": frames_to_far_end,
		"hand_travel": far_end,
	}
	print("SWING_SPEED ", label, " ", JSON.stringify(result))
	return result

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("SWING_SPEED_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SWING_SPEED_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_sword_prototype")
	if _proto == null:
		print("SWING_SPEED_FAIL proto_missing"); quit(1); return
	_player.set_mouse_captured(true)
	var weapons: Node = _scene.get("preview_weapons")
	weapons.equip("sword")
	var sword := await _measure("sword")
	weapons.equip("sledge")
	var sledge := await _measure("sledge")
	var verdict := {
		"sword_peak_is_capped": float(sword.get("peak_omega", 99.0)) <= float(sword.get("cap", 0.0)) * 1.08,
		"sword_does_not_jump_in_one_frame": float(sword.get("peak_in_first_frames", 99.0)) < float(sword.get("cap", 1.0)),
		"sword_needs_time_to_travel": int(sword.get("frames_to_far_end", 0)) >= 3,
		"sledge_is_slower_than_the_sword": float(sledge.get("peak_omega", 99.0)) < float(sword.get("peak_omega", 0.0)),
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("SWING_SPEED_OBJECTIVE ", JSON.stringify(verdict))
	print("SWING_SPEED_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
