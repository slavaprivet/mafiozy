extends SceneTree
## Verifies the severed-hand weapon rules on the real castle player host:
##  * losing the sword arm does not let a weapon sit in the stump;
##  * a one-handed sword can be picked up and held in the surviving hand;
##  * a two-handed weapon is refused with one hand gone;
##  * with both hands gone no weapon can be picked up or selected.

var _scene: Node3D
var _host: Node
var _player: CharacterBody3D
var _fails: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _settle(frames: int) -> void:
	for i: int in frames:
		await physics_frame

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		print("SEVER_HAND_PASS ", label, " ", detail)
	else:
		print("SEVER_HAND_FAIL ", label, " ", detail)
		_fails.append(label)

func _sever(bone: String) -> void:
	var at := _player.global_position + Vector3.UP * 1.2
	_host.call("_player_take_blade", 999.0, at, Vector3.RIGHT, true, bone, 2.0)
	await _settle(4)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_player = _scene.get("_player") as CharacterBody3D
	_host = _scene.get("preview_sword_prototype") as Node
	if not is_instance_valid(_host):
		print("SEVER_HAND_FAIL no_host"); quit(1); return
	_host.call("set_selected", true)
	await _settle(30)
	var start: Dictionary = _host.snapshot()
	var carry := str(start.get("carry_side", "right"))
	print("SEVER_HAND_START carry=", carry, " active=", start.get("hand_side"), " sword=", start.get("has_sword"))

	# The sword is in the visible carry hand. The rig is mirrored: visible right is
	# the "_l" bone, visible left is "_r".
	var sword_bone := "hand_l" if carry == "right" else "hand_r"
	await _sever(sword_bone)
	var after: Dictionary = _host.snapshot()
	var lost_side := "right" if sword_bone.ends_with("_l") else "left"
	var intact_side := "left" if lost_side == "right" else "right"
	print("SEVER_HAND_AFTER_CUT ", JSON.stringify({"severed": after.get("player_severed"),
		"disarmed": after.get("player_disarmed"), "carry": after.get("carry_side"),
		"active": after.get("hand_side"), "sword": after.get("has_sword")}))
	var severed_list: Array = after.get("player_severed", [])
	_check(severed_list.has(sword_bone), "sword_hand_severed", "bone=" + sword_bone)
	# The sword may transfer or fall out of the cut hand; either is legal, but it
	# must never remain assigned to the severed side.
	_check(str(after.get("carry_side")) != lost_side, "carry_side_not_severed",
		"carry=" + str(after.get("carry_side")))

	# Put the sword on the ground and take it back with the surviving hand.
	if bool(after.get("has_sword", false)) and not bool(after.get("sword_grounded", false)):
		_host.call("drop_sword_to_ground")
		await _settle(8)
	var dropped: Dictionary = _host.snapshot()
	var ground: Dictionary = _host.call("ground_sword_info")
	print("SEVER_HAND_DROPPED ", JSON.stringify({"sword": dropped.get("has_sword"),
		"grounded": dropped.get("sword_grounded"), "ground": ground}))
	_check(bool(dropped.get("sword_grounded", false)) or int(ground.get("count", 0)) > 0, "sword_on_ground")
	var picked := bool(_host.call("try_pickup_sword", true))
	await _settle(18)
	var held: Dictionary = _host.snapshot()
	print("SEVER_HAND_PICKED ", JSON.stringify({"ok": picked, "sword": held.get("has_sword"),
		"grounded": held.get("sword_grounded"), "carry": held.get("carry_side"),
		"active": held.get("hand_side"), "grip_error": held.get("grip_hand_error")}))
	_check(picked and bool(held.get("has_sword", false)), "one_handed_sword_picked_up")
	_check(str(held.get("carry_side")) == intact_side or str(held.get("hand_side")) == intact_side,
		"held_in_intact_hand", "carry=%s active=%s" % [held.get("carry_side"), held.get("hand_side")])
	_check(str(held.get("hand_side")) != lost_side, "not_held_by_stump")

	# A two-handed weapon must be refused while one hand is gone.
	var sledge_ok := bool(_host.call("set_weapon", "sledge"))
	await _settle(4)
	var after_sledge: Dictionary = _host.snapshot()
	print("SEVER_HAND_SLEDGE ", JSON.stringify({"ok": sledge_ok, "weapon": after_sledge.get("weapon")}))
	_check(not sledge_ok and str(after_sledge.get("weapon")) != "sledge", "two_handed_refused_one_hand")

	# Sever the surviving hand too. Nothing may be picked up or selected now.
	var other_bone := "hand_r" if sword_bone == "hand_l" else "hand_l"
	await _sever(other_bone)
	await _settle(8)
	var both: Dictionary = _host.snapshot()
	print("SEVER_HAND_BOTH ", JSON.stringify({"severed": both.get("player_severed"),
		"sword": both.get("has_sword"), "grounded": both.get("sword_grounded"),
		"disarmed": both.get("player_disarmed")}))
	_check(bool(both.get("player_disarmed", false)) or not bool(both.get("has_sword", false)),
		"no_sword_with_no_hands")
	var any_pickup := bool(_host.call("try_pickup_sword", true))
	var any_select := bool(_host.call("set_weapon", "sword"))
	print("SEVER_HAND_NONE ", JSON.stringify({"pickup": any_pickup, "select": any_select}))
	_check(not any_pickup, "no_pickup_with_no_hands")
	_check(not any_select, "no_weapon_select_with_no_hands")

	print("SEVER_HAND_DONE ", "PASS" if _fails.is_empty() else "FAIL", " fails=", _fails)
	quit(0 if _fails.is_empty() else 1)
