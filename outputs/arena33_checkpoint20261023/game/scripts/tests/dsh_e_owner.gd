extends SceneTree
## DSH_CATAPULT / DSH_SWORD_PROTO: who owns E?
##
## The report was "the stone has to be in my hands, lifted" while a sword was lying on
## the ground. Both prototypes listen for E, and the dropped sword was taking the key
## first, so the stone could never be picked up. This reproduces that exact situation:
## the sword is DROPPED on the ground, the player walks to the stone and presses E, and
## the stone must end up in his hands.

var _scene: Node
var _player: CharacterBody3D
var _catapult: Node3D
var _weapons: Node

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

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("E_OWNER_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("E_OWNER_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_catapult = _scene.get("preview_catapult")
	_weapons = _scene.get("preview_weapons")
	if _catapult == null:
		print("E_OWNER_FAIL no_catapult"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(20)
	# Put a sword in his hand, then DROP it so it lies on the ground: the exact state in
	# which the sword used to steal E.
	_weapons.call("equip", "sword")
	await _settle(12)
	var sword: Node = _scene.get("preview_sword_prototype")
	_key(KEY_G, true); await _settle(2); _key(KEY_G, false)
	await _settle(10)
	var grounded: bool = bool(sword.get("_sword_grounded"))
	print("E_OWNER_SWORD_DROPPED grounded=", grounded)
	# Walk to the stone and press E.
	var stone: Vector3 = _catapult.call("snapshot").get("stone", Vector3.ZERO)
	_player.global_position = stone + Vector3(0.8, 0.05, 0.0)
	_player.velocity = Vector3.ZERO
	await _settle(12)
	var wants: bool = bool(_catapult.call("wants_e"))
	_key(KEY_E, true); await _settle(2); _key(KEY_E, false)
	await _settle(12)
	var carried: bool = bool(_catapult.call("snapshot").get("carrying", false))
	var stone_position: Vector3 = _catapult.call("snapshot").get("stone", Vector3.ZERO)
	var hand_gap: float = _player.global_position.distance_to(stone_position)
	print("E_OWNER_RESULT wants_e=", wants, " grounded=", grounded,
		" carried=", carried, " stone_in_hands_gap_m=", hand_gap)
	var verdict := {
		"the_catapult_claims_e": wants,
		"the_sword_was_really_on_the_ground": grounded,
		"the_stone_is_in_his_hands": carried,
		"the_stone_moved_to_him": hand_gap < 2.0,
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("E_OWNER_OBJECTIVE ", JSON.stringify(verdict))
	print("E_OWNER_VERDICT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
