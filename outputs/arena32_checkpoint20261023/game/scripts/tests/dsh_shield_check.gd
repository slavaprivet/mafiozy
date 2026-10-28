extends SceneTree
## DSH_MELEE_SET shield check
##
## Verifies the shield does what was asked, by numbers rather than by looking:
##   1. it is worn in the hand that is NOT carrying the weapon;
##   2. the right button RAISES it, and the raise animates rather than snapping;
##   3. a blow inside its coverage is STOPPED - the body takes no damage at all, and the
##      shield takes the wear instead;
##   4. a blow OUTSIDE its coverage is NOT stopped, so it is a shield and not a bubble;
##   5. its coverage SHRINKS as it is beaten down, and it finally fails.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"

var _scene: Node
var _player: CharacterBody3D
var _proto: Node3D
var _weapons: Node

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

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("SHIELD_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIELD_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_sword_prototype")
	_weapons = _scene.get("preview_weapons")
	if _proto == null or _weapons == null:
		print("SHIELD_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	# Sword in hand, shield in the other: the whole point of a shield.
	_weapons.equip("sword")
	await _settle(20)
	var equipped: Dictionary = _weapons.equip("shield")
	await _settle(40)
	var worn: Dictionary = _proto.snapshot().get("shield", {})
	var status: Dictionary = _proto.call("shield_status")
	print("SHIELD_WORN equip=", JSON.stringify(equipped),
		" worn=", status.get("worn", false), " hp=", status.get("hp", 0.0),
		" coverage_m=", status.get("coverage_m", 0.0),
		" centre=", status.get("centre", Vector3.ZERO))
	# 1. Raise it, and watch the raise animate.
	var raise_before := float(status.get("raise", 0.0))
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _settle(3)
	var raise_mid := float(_proto.call("shield_status").get("raise", 0.0))
	await _settle(30)
	var raised: Dictionary = _proto.call("shield_status")
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _settle(25)
	var lowered: Dictionary = _proto.call("shield_status")
	print("SHIELD_RAISE before=", raise_before, " after_3_frames=", raise_mid,
		" raised=", raised.get("raise", 0.0), " lowered_again=", lowered.get("raise", 0.0))
	# 2. A blow INSIDE the coverage must be stopped.
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _settle(30)
	var centre: Vector3 = _proto.call("shield_status").get("centre", Vector3.ZERO)
	var hp_before := float(_proto.call("shield_status").get("hp", 0.0))
	var player_hp_before: float = _proto.get("_sparring_hp")
	var inside := centre + Vector3(0.0, 0.05, 0.0)
	_proto.call("_apply_player_damage", 25.0, inside, Vector3.FORWARD)
	await _settle(3)
	var after_inside: Dictionary = _proto.call("shield_status")
	var player_hp_after: float = _proto.get("_sparring_hp")
	print("SHIELD_BLOCK_INSIDE hp_before=", hp_before, " hp_after=", after_inside.get("hp", 0.0),
		" player_before=", player_hp_before, " player_after=", player_hp_after,
		" blocks=", after_inside.get("blocks", 0))
	# 3. A blow FAR OUTSIDE must NOT be stopped.
	var far := centre + Vector3(0.0, 0.0, 6.0)
	var hp_before_far := float(after_inside.get("hp", 0.0))
	_proto.call("_apply_player_damage", 12.0, far, Vector3.FORWARD)
	await _settle(3)
	var after_far: Dictionary = _proto.call("shield_status")
	var player_hp_far: float = _proto.get("_sparring_hp")
	print("SHIELD_MISS_OUTSIDE hp_before=", hp_before_far, " hp_after=", after_far.get("hp", 0.0),
		" player_after=", player_hp_far)
	# 4. Beat it down and watch the coverage shrink, then fail.
	var coverage_full := float(after_far.get("coverage_m", 0.0))
	var coverage_mid := coverage_full
	for i: int in 3:
		_proto.call("_apply_player_damage", 15.0, _proto.call("shield_status").get("centre", Vector3.ZERO), Vector3.FORWARD)
		await _settle(2)
	coverage_mid = float(_proto.call("shield_status").get("coverage_m", 0.0))
	for i: int in 12:
		_proto.call("_apply_player_damage", 20.0, _proto.call("shield_status").get("centre", Vector3.ZERO), Vector3.FORWARD)
		await _settle(2)
	var broken: Dictionary = _proto.call("shield_status")
	print("SHIELD_WEAR coverage_full=", coverage_full, " coverage_after_blows=", coverage_mid,
		" hp_end=", broken.get("hp", 0.0), " broken=", broken.get("broken", false),
		" coverage_end=", broken.get("coverage_m", 0.0))
	var image: Image = get_root().get_texture().get_image()
	if image != null: print("SHIELD_SHOT ", image.save_png(OUT_DIR + "/shot_shield.png"))

	var verdict := {
		"shield_is_worn": bool(status.get("worn", false)),
		"right_button_raises_it": float(raised.get("raise", 0.0)) > 0.9,
		"the_raise_animates": raise_mid > raise_before and raise_mid < 0.9,
		"it_lowers_again": float(lowered.get("raise", 0.0)) < 0.2,
		"inside_coverage_is_stopped": is_equal_approx(player_hp_after, player_hp_before)
			and float(after_inside.get("hp", 0.0)) < hp_before,
		"outside_coverage_is_not_stopped": not is_equal_approx(player_hp_far, player_hp_after),
		"coverage_shrinks_as_it_wears": coverage_mid < coverage_full - 0.01,
		"it_fails_in_the_end": bool(broken.get("broken", false)),
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("SHIELD_OBJECTIVE ", JSON.stringify(verdict))
	print("SHIELD_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
