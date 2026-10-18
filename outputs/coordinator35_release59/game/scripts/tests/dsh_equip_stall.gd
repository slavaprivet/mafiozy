extends SceneTree
## DSH_MELEE_SET equip-stall check
##
## Reproduces the report "there is a lag when choosing a weapon and then the character
## does not walk", and separates the two halves of it:
##   * STALL - how long each equip takes, and the worst frame right after it, so a hitch
##     can be attributed instead of guessed at;
##   * WALKING - after the equip, a forward key is held and the player's position must
##     actually change. A free cursor, a stolen mouse capture or a stuck input all show
##     up here as "did not move".

var _scene: Node
var _player: CharacterBody3D
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

## Holds a forward key for a while and reports how far the player actually went.
func _walk_check(label: String) -> Dictionary:
	await _settle(6)
	var from: Vector3 = _player.global_position
	var action: StringName = _player.ACTION_FORWARD
	if InputMap.has_action(action): Input.action_press(action)
	await _settle(40)
	if InputMap.has_action(action): Input.action_release(action)
	var moved: float = _player.global_position.distance_to(from)
	var result := {
		"moved_m": moved,
		"velocity": _player.velocity,
		"on_floor": _player.is_on_floor(),
		"sword_lock": _player.get("_sword_lock"),
		"pose_authority": str(_player.get("_pose_authority")),
		"dead": bool(_scene.get("preview_dead")),
		"fault": bool(_scene.get("preview_physics_fault")),
		"controls_blocked": _weapons.call("controls_blocked"),
		"menu_open": bool(_weapons.get("menu_open")),
		"cargo_active": bool(_weapons.call("cargo_menu_active")),
		"text_focused": bool(_player.call("_text_control_focused")),
		"jump_pending": (_player.get("_jump") as Dictionary).size() if _player.get("_jump") is Dictionary else -1,
		"source_falling": bool(_player.get("_source_falling")),
		"axes_live": Input.get_vector(_player.ACTION_LEFT, _player.ACTION_RIGHT, _player.ACTION_FORWARD, _player.ACTION_BACK),
		"free_mouse_look": bool(_player.get("_free_mouse_look")),
		"mouse_mode": Input.mouse_mode,
		"action_forward": Input.is_action_pressed(action) if InputMap.has_action(action) else false,
	}
	print("EQUIP_WALK ", label, " ", JSON.stringify(result))
	return result

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("EQUIP_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("EQUIP_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	if _player == null or _weapons == null:
		print("EQUIP_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(20)
	var boot_position: Vector3 = _player.global_position
	var baseline := await _walk_check("baseline")
	var results: Dictionary = {}
	for id: String in ["sword", "mace", "axe", "sledge", "spear", "shield"]:
		# Open the arsenal the way a player does, then press that weapon's own card.
		_weapons.call("set_menu", true)
		await _settle(8)
		var ui: Node = _weapons.get("_walk_ui")
		var choices: Dictionary = ui.get("choices") if ui != null else {}
		var started := Time.get_ticks_usec()
		if choices.has(id):
			var button: Button = (choices[id] as Dictionary).get("button")
			if is_instance_valid(button): button.pressed.emit()
		else:
			_weapons.call("equip", id)
		var equip_us := Time.get_ticks_usec() - started
		# Worst frame in the twenty after the equip: a hitch is a long first frame.
		var worst_ms := 0.0
		for i: int in 20:
			var t0 := Time.get_ticks_usec()
			await process_frame
			worst_ms = maxf(worst_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
		if bool(_weapons.get("menu_open")):
			_weapons.call("set_menu", false)
			await _settle(4)
		# Back to the start line, so a wall found by the previous run cannot be mistaken
		# for a weapon that stops the player.
		_player.global_position = boot_position + Vector3(0.0, 0.05, 0.0)
		_player.velocity = Vector3.ZERO
		await _settle(6)
		var walk := await _walk_check(id)
		results[id] = {
			"equip_ms": float(equip_us) / 1000.0,
			"worst_frame_ms": worst_ms,
			"walked_m": walk.get("moved_m", 0.0),
			"free_mouse_look": walk.get("free_mouse_look", false),
		}
	# EQUIP THE AXE A SECOND TIME. If the hitch is a one-time pipeline compile it must
	# be gone now, which separates "the model is expensive" from "the first draw is".
	if bool(_weapons.get("menu_open")): _weapons.call("set_menu", false)
	await _settle(10)
	_weapons.call("equip", "sledge")
	await _settle(20)
	var repeat_start := Time.get_ticks_usec()
	_weapons.call("equip", "axe")
	var repeat_equip_ms := float(Time.get_ticks_usec() - repeat_start) / 1000.0
	var repeat_worst := 0.0
	for i: int in 20:
		var t0 := Time.get_ticks_usec()
		await process_frame
		repeat_worst = maxf(repeat_worst, float(Time.get_ticks_usec() - t0) / 1000.0)
	print("EQUIP_REPEAT axe_again_equip_ms=", repeat_equip_ms, " worst_frame_ms=", repeat_worst)
	# Put the sword back so the session is left in a sane state.
	_weapons.call("equip", "sword")
	var failed: Array[String] = []
	var slowest := 0.0
	for id: String in results.keys():
		var line: Dictionary = results[id]
		slowest = maxf(slowest, float(line.get("equip_ms", 0.0)))
		if float(line.get("equip_ms", 0.0)) > 120.0: failed.append(id + ":stall")
		if float(line.get("worst_frame_ms", 0.0)) > 120.0: failed.append(id + ":hitch")
		if float(line.get("walked_m", 0.0)) < 0.10: failed.append(id + ":cannot_walk")
	print("EQUIP_SLOWEST_MS ", slowest)
	print("EQUIP_OBJECTIVE ", JSON.stringify(results))
	print("EQUIP_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
