extends SceneTree
## DSH_MELEE_SET: does the weapon go through the man holding it?
##
## Reported: "the spear stabs me in the backside". Every weapon is measured for how far
## its model reaches BEHIND its own grip, which is the part that can enter the body. The
## arm reaches about 0.5 m from the shoulder and the body is about 0.3 m half-width, so a
## weapon reaching back much more than that is inside the man.

var _scene: Node
var _player: CharacterBody3D
var _weapons: Node
var _proto: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("WEAPON_BODY_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("WEAPON_BODY_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	_proto = _scene.get("preview_sword_prototype")
	if _weapons == null or _proto == null:
		print("WEAPON_BODY_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(20)
	var report: Dictionary = {}
	for id: String in ["sword", "mace", "axe", "sledge", "spear"]:
		_weapons.call("equip", id)
		await _settle(14)
		var snap: Dictionary = _proto.call("snapshot")
		var rear: float = float(snap.get("weapon_rear_m", 99.0))
		# How far the model's rear end actually is from the player's body axis.
		var visual: Node3D = _player._visual
		var hand: Vector3 = snap.get("sword_origin", Vector3.ZERO)
		var axis_clearance: float = Vector2(hand.x - _player.global_position.x,
			hand.z - _player.global_position.z).length()
		report[id] = {"rear_m": rear, "hand_from_axis_m": axis_clearance,
			"in_hand": bool(snap.get("weapon_visible", false))}
		print("WEAPON_BODY ", id, " ", JSON.stringify(report[id]))
	var failed: Array[String] = []
	for id: String in report.keys():
		var line: Dictionary = report[id]
		if not bool(line.get("in_hand", false)): failed.append(id + ":not_in_hand")
		if float(line.get("rear_m", 99.0)) > 0.55: failed.append(id + ":reaches_back")
	print("WEAPON_BODY_OBJECTIVE ", JSON.stringify(report))
	print("WEAPON_BODY_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)