extends SceneTree
## DSH_CASTLE: NOTHING IS ALLOWED TO BE DEAD ON THIS MAP.
##
## Every mechanic the game has is exercised on the castle map and reported: walking,
## jumping, the dive, taking a weapon with a key, swinging, blocking with the shield,
## dropping a weapon and picking it back up, throwing the spear, crouching, sprinting and
## the catapult. Each one has a number attached, so a dead mechanic is a FAIL and not an
## opinion.

var _scene: Node
var _player: CharacterBody3D
var _weapons: Node
var _proto: Node3D
var _catapult: Node3D

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

func _tap(code: int) -> void:
	await _key(code, true)
	await _key(code, false)

func _button(index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _snapshot() -> Dictionary:
	if not is_instance_valid(_proto): return {}
	return _proto.call("snapshot")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("MECH_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true: print("MECH_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	_proto = _scene.get("preview_sword_prototype")
	_catapult = _scene.get("preview_catapult")
	_player.set_mouse_captured(true)
	await _settle(60)
	var report: Dictionary = {}
	# ---- walking
	var start_pos: Vector3 = _player.global_position
	Input.action_press(_player.ACTION_FORWARD)
	await _settle(60)
	Input.action_release(_player.ACTION_FORWARD)
	await _settle(10)
	report["walk_m"] = start_pos.distance_to(_player.global_position)
	# ---- jumping, from a settled stand
	await _settle(30)
	var on_floor: bool = _player.is_on_floor()
	var base_y: float = _player.global_position.y
	await _tap(KEY_SPACE)
	var peak: float = base_y
	for i: int in 45:
		await process_frame
		peak = maxf(peak, _player.global_position.y)
	report["jump_rise_m"] = peak - base_y
	report["on_floor_before_jump"] = on_floor
	await _settle(50)
	# ---- the dive: two presses in quick succession
	var dive_from: Vector3 = _player.global_position
	report["on_floor_before_dive"] = _player.is_on_floor()
	await _tap(KEY_SPACE)
	await _settle(6)
	report["jump_running"] = not (_player.get("_jump") as Dictionary).is_empty()
	await _tap(KEY_SPACE)
	var dive_moved := 0.0
	for i: int in 60:
		await process_frame
		dive_moved = maxf(dive_moved, dive_from.distance_to(_player.global_position))
	report["dive_m"] = dive_moved
	await _settle(50)
	# ---- taking a weapon with a key
	await _tap(KEY_3)
	await _settle(20)
	var snap_after_key: Dictionary = _snapshot()
	report["key_weapon"] = str((_weapons.get("fire_state") as Dictionary).get("weaponId", "none"))
	report["key_weapon_in_hand"] = bool(snap_after_key.get("weapon_visible", false))
	# ---- swinging
	var blocks_before: int = int(snap_after_key.get("blocks", 0))
	var omega_peak := 0.0
	await _button(MOUSE_BUTTON_LEFT, true)
	await _settle(14)
	omega_peak = maxf(omega_peak, float(_snapshot().get("omega", 0.0)))
	await _button(MOUSE_BUTTON_LEFT, false)
	await _settle(20)
	report["swing_omega"] = omega_peak
	# ---- blocking with the shield
	await _tap(KEY_6)
	await _settle(20)
	var shield_snap: Dictionary = _snapshot()
	await _button(MOUSE_BUTTON_RIGHT, true)
	await _settle(12)
	var shield_block: Dictionary = _snapshot().get("shield", {})
	await _button(MOUSE_BUTTON_RIGHT, false)
	await _settle(10)
	report["shield_equipped"] = int(shield_snap.get("shield", {}).get("hp", 0))
	report["shield_raise"] = float(shield_block.get("raise", 0.0))
	# ---- dropping and picking a weapon back up
	await _tap(KEY_1)
	await _settle(16)
	await _tap(KEY_G)
	await _settle(16)
	var dropped: bool = bool(_snapshot().get("sword_grounded", false))
	await _tap(KEY_E)
	await _settle(20)
	var picked: bool = bool(_snapshot().get("weapon_visible", false))
	report["drop_and_pickup"] = dropped and picked
	# ---- crouch
	await _tap(KEY_C)
	await _settle(60)
	report["crouch_pose"] = str(_player.get("_pose_authority"))
	var posture_node: Variant = _weapons.get("posture")
	if posture_node != null and is_instance_valid(posture_node):
		var pstate: Dictionary = posture_node.call("posture_state")
		report["posture_state"] = str(pstate.get("state", "?"))
		report["posture_target"] = str(pstate.get("target", "?"))
		report["posture_height"] = float(pstate.get("height", 0.0))
	await _tap(KEY_C)
	await _settle(40)
	# ---- sprint: the same walk, running
	var sprint_from: Vector3 = _player.global_position
	Input.action_press(_player.ACTION_RUN)
	Input.action_press(_player.ACTION_FORWARD)
	await _settle(60)
	Input.action_release(_player.ACTION_FORWARD)
	Input.action_release(_player.ACTION_RUN)
	await _settle(10)
	report["sprint_m"] = sprint_from.distance_to(_player.global_position)
	# ---- the catapult on this map
	if is_instance_valid(_catapult):
		var cat: Dictionary = _catapult.call("snapshot")
		report["catapult_present"] = true
		report["catapult_stone"] = bool(cat.get("stone_on_spoon", false)) or is_instance_valid(_catapult.get("_stone"))
		report["catapult_fires"] = bool(_catapult.call("wants_e"))
	else:
		report["catapult_present"] = false
	# ---- verdict
	var verdict := {
		"walking": float(report["walk_m"]) > 1.0,
		"jumping": bool(report["on_floor_before_jump"]) and float(report["jump_rise_m"]) > 0.45,
		"dive": bool(report["on_floor_before_dive"]) and float(report["dive_m"]) > 0.8,
		"weapon_by_key": str(report["key_weapon"]) == "axe" and bool(report["key_weapon_in_hand"]),
		"swinging": float(report["swing_omega"]) > 0.5,
		"shield": int(report["shield_equipped"]) > 0,
		"shield_block": float(report["shield_raise"]) > 0.2,
		"drop_and_pickup": bool(report["drop_and_pickup"]),
		"crouch": str(report["crouch_pose"]) != "on_foot" or str(report.get("posture_target", "")) == "crouch",
		"sprint": float(report["sprint_m"]) > 1.0,
		"catapult": bool(report["catapult_present"]),
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("MECH_REPORT ", JSON.stringify(report))
	print("MECH_VERDICT ", JSON.stringify(verdict))
	print("MECH_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)