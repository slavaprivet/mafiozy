extends SceneTree
## DSH_MELEE_SET: the direct hotkeys 1..6, without the arsenal window at all.
## If these put a weapon in the hands, a fault in taking a weapon is in the menu; if they
## do not, it is in the presentation.

var _scene: Node
var _player: CharacterBody3D
var _weapons: Node
var _proto: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("KEYS_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("KEYS_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	_proto = _scene.get("preview_sword_prototype")
	if _weapons == null or _proto == null:
		print("KEYS_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(20)
	var plan := {KEY_1: "sword", KEY_2: "mace", KEY_3: "axe", KEY_4: "sledge", KEY_5: "spear"}
	var report: Dictionary = {}
	for code: int in plan.keys():
		var want: String = plan[code]
		await _key(code)
		await _settle(10)
		var snap: Dictionary = _proto.call("snapshot")
		var state: Dictionary = _weapons.get("fire_state")
		report[want] = {
			"equipped": str(state.get("weaponId", "")),
			"proto_weapon": str(snap.get("weapon", "")),
			"in_hand": bool(snap.get("weapon_visible", false)),
			"grip_error": float(snap.get("grip_hand_error", 99.0)),
		}
		print("KEYS_CARD ", want, " ", JSON.stringify(report[want]))
	var failed: Array[String] = []
	for want: String in report.keys():
		var line: Dictionary = report[want]
		if str(line.get("equipped", "")) != want: failed.append(want + ":not_equipped")
		elif not bool(line.get("in_hand", false)): failed.append(want + ":not_in_hand")
	print("KEYS_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)