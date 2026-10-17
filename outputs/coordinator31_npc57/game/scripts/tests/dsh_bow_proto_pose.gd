extends SceneTree
## DSH_BOW_PROTO quick pose probe
##
## Boots the real scene, equips the bow and simply REPORTS the archer geometry:
## where the hands actually are relative to the body, how far the string is pulled,
## and where the quiver sits. It takes seconds instead of minutes, so it can be run
## without holding the machine while the game is being played.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"

var _scene: Node
var _player: CharacterBody3D
var _proto: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("BOW_POSE_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("BOW_POSE_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_bow_prototype")
	if _proto == null:
		print("BOW_POSE_FAIL proto_missing"); quit(1); return
	_player.set_mouse_captured(true)
	var weapons: Node = _scene.get("preview_weapons")
	if weapons != null: weapons.equip("bow")
	await _settle(90)
	var rest: Dictionary = _proto.snapshot()
	print("BOW_POSE_REST aiming=", rest.get("aiming", false), " drawing=", rest.get("drawing", false),
		" nocked=", rest.get("nocked", false),
		" draw_hand_forward_m=", rest.get("draw_hand_forward", 0.0),
		" bow_hand_forward_m=", rest.get("bow_hand_forward", 0.0),
		" string_pull_m=", rest.get("string_pull_m", 0.0),
		" string_visible=", rest.get("string_visible", false),
		" hand_clearance=", rest.get("hand_clearance", 0.0),
		" elbow_clearance=", rest.get("elbow_clearance", 0.0),
		" quiver_offset_m=", rest.get("quiver_offset_m", 0.0))
	print("BOW_POSE_REPORT ", JSON.stringify(_proto.call("pose_report")))
	print("BOW_POSE_GRIP bow_grip_error_m=", rest.get("bow_grip_error", -1.0),
		" string_grip_error_m=", rest.get("string_grip_error", -1.0),
		" string_reach_error_m=", rest.get("string_reach_error", -1.0),
		" bow_reach_error_m=", rest.get("bow_reach_error", -1.0),
		" nocked_arrow_visible=", rest.get("nocked_arrow_visible", false),
		" string_pull_m=", rest.get("string_pull_m", 0.0))
	# Hold the RIGHT button: the targeting aid, no arrow spent.
	var shots_before: int = int(_proto.snapshot().shots)
	var arrows_before: int = int(_proto.snapshot().arrows_left)
	var aim_event := InputEventMouseButton.new()
	aim_event.button_index = MOUSE_BUTTON_RIGHT
	aim_event.pressed = true
	aim_event.position = Vector2(960, 540)
	Input.parse_input_event(aim_event)
	await _settle(45)
	var aiming: Dictionary = _proto.snapshot()
	print("BOW_POSE_AIM aiming=", aiming.get("aiming", false), " aim_dots=", aiming.get("aim_dots", 0),
		" shots=", aiming.get("shots", 0), " shots_before=", shots_before,
		" arrows=", aiming.get("arrows_left", 0), " arrows_before=", arrows_before,
		" zoom_scale=", aiming.get("zoom_scale", 1.0))
	aim_event = InputEventMouseButton.new()
	aim_event.button_index = MOUSE_BUTTON_RIGHT
	aim_event.pressed = false
	aim_event.position = Vector2(960, 540)
	Input.parse_input_event(aim_event)
	await _settle(20)
	var image: Image = get_root().get_texture().get_image()
	if image != null:
		print("BOW_POSE_SHOT ", image.save_png(OUT_DIR + "/shot_bow_pose.png"))
	var verdict := {
		"hands_are_in_front": float(rest.get("draw_hand_forward", -9.0)) > 0.0
			and float(rest.get("bow_hand_forward", -9.0)) > 0.0,
		"bow_is_in_the_bow_hand": float(rest.get("bow_grip_error", 99.0)) < 0.05,
		"string_is_in_the_string_hand": float(rest.get("string_grip_error", 99.0)) < 0.06,
		"both_arms_reach_their_targets": float(rest.get("string_reach_error", 99.0)) < 0.06
			and float(rest.get("bow_reach_error", 99.0)) < 0.06,
		"string_is_visible": bool(rest.get("string_visible", false)),
		"arm_clear_of_body": float(rest.get("hand_clearance", 0.0)) > 0.24
			and float(rest.get("elbow_clearance", 0.0)) > 0.10,
		"quiver_on_the_back": float(rest.get("quiver_offset_m", 0.0)) > 0.135
			and float(rest.get("quiver_offset_m", 9.0)) < 0.26,
		"rmb_aims_without_firing": bool(aiming.get("aiming", false))
			and int(aiming.get("aim_dots", 0)) > 3
			and int(aiming.get("shots", 0)) == shots_before
			and int(aiming.get("arrows_left", 0)) == arrows_before,
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("BOW_POSE_OBJECTIVE ", JSON.stringify(verdict))
	print("BOW_POSE_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
