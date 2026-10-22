extends SceneTree
## DSH_ANIM stance check
##
## Reported: "when walking, the legs are together". The body animation layer writes the
## pelvis, spine, chest and both legs, so it can narrow the stance if it is wrong. This
## measures the distance between the two feet while the player walks, in three states -
## no weapon, sword carried, sword with the swing held - and reports the smallest and
## largest stance in each. A stance that collapses is a bug; one that stays near the
## walking animation's own width is not.

var _scene: Node
var _player: CharacterBody3D
var _proto: Node3D
var _weapons: Node

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _foot_gap() -> float:
	if not is_instance_valid(_player): return 0.0
	var rig: Skeleton3D = _player.get("_rig") if _player.get("_rig") != null else null
	if rig == null:
		var rigs: Array[Node] = _player._visual.find_children("*", "Skeleton3D", true, false)
		if rigs.is_empty(): return 0.0
		rig = rigs[0] as Skeleton3D
	var left := rig.find_bone("foot_l")
	var right := rig.find_bone("foot_r")
	if left < 0 or right < 0: return 0.0
	var a: Vector3 = rig.global_transform * rig.get_bone_global_pose(left).origin
	var b: Vector3 = rig.global_transform * rig.get_bone_global_pose(right).origin
	return a.distance_to(b)

func _walk_sample(label: String) -> Dictionary:
	await _settle(6)
	var gap_min := 99.0
	var gap_max := 0.0
	var action: StringName = _player.ACTION_FORWARD
	if InputMap.has_action(action): Input.action_press(action)
	for i: int in 50:
		await process_frame
		var gap := _foot_gap()
		gap_min = minf(gap_min, gap)
		gap_max = maxf(gap_max, gap)
	if InputMap.has_action(action): Input.action_release(action)
	await _settle(4)
	var result := {"gap_min": gap_min, "gap_max": gap_max}
	print("STANCE ", label, " ", JSON.stringify(result))
	return result

## Standing still, through a full breathing cycle: the legs must not move at all now
## that the pelvis belongs to the walk animation.
func _idle_sample(label: String) -> Dictionary:
	# Let him come to a complete stand first: a walk-to-idle transition moves the feet
	# far more than any idle sway, and measuring through it would blame the idle.
	await _settle(70)
	var gap_min := 99.0
	var gap_max := 0.0
	for i: int in 320:
		await process_frame
		var gap := _foot_gap()
		gap_min = minf(gap_min, gap)
		gap_max = maxf(gap_max, gap)
	var result := {"gap_min": gap_min, "gap_max": gap_max, "swing": gap_max - gap_min}
	print("STANCE_IDLE ", label, " ", JSON.stringify(result))
	return result

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("STANCE_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("STANCE_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_sword_prototype")
	_weapons = _scene.get("preview_weapons")
	_player.set_mouse_captured(true)
	var boot: Vector3 = _player.global_position
	await _settle(20)
	# 1. No prototype weapon at all: the walking animation's own stance.
	var plain := await _walk_sample("no_weapon")
	# 2. Sword carried, just walking.
	_weapons.call("equip", "sword")
	_player.global_position = boot
	_player.velocity = Vector3.ZERO
	await _settle(10)
	var carried := await _walk_sample("sword_carried")
	# 3. Sword carried with the swing held: the legs brace as well.
	_player.global_position = boot
	_player.velocity = Vector3.ZERO
	await _settle(6)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(960, 540)
	Input.parse_input_event(press)
	var swinging := await _walk_sample("sword_swinging")
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	press.position = Vector2(960, 540)
	Input.parse_input_event(press)
	await _settle(6)

	var idle_plain := await _idle_sample("no_weapon")
	_weapons.call("equip", "sword")
	await _settle(10)
	var idle_sword := await _idle_sample("sword_idle")
	var base_gap := float(plain.get("gap_max", 0.0))
	var carried_min := float(carried.get("gap_min", 0.0))
	var swinging_min := float(swinging.get("gap_min", 0.0))
	var verdict := {
		"stance_survives_the_weapon": carried_min > base_gap * 0.55,
		"stance_survives_the_swing": swinging_min > base_gap * 0.40,
		# Standing still, the feet must not drift at all: any drift is the body layer
		# moving the legs, which is what "the legs open and close" looked like.
		"legs_are_still_while_idle": float(idle_sword.get("swing", 9.0)) < 0.02,
		"idle_matches_the_baseline": absf(float(idle_sword.get("gap_max", 0.0)) - float(idle_plain.get("gap_max", 0.0))) < 0.02,
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("STANCE_BASELINE ", base_gap, " carried_min=", carried_min, " swinging_min=", swinging_min)
	print("STANCE_OBJECTIVE ", JSON.stringify(verdict))
	print("STANCE_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
