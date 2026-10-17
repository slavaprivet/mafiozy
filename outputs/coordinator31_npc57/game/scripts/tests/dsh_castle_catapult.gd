extends SceneTree
## DSH_CASTLE: does a catapult stone bring the castle's masonry down?
## The machine's own path is used - stone on the spoon, aim at the wall, fire - and the
## castle's counters are the judge. No hand-made impact calls.

var _scene: Node
var _player: CharacterBody3D
var _castle: Node3D
var _catapult: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("CSCAT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_castle = _scene.get("preview_castle")
	_catapult = _scene.get("preview_catapult")
	if _player == null or _castle == null or _catapult == null:
		print("CSCAT_FAIL missing player=", _player != null, " castle=", _castle != null,
			" catapult=", _catapult != null); quit(1); return
	_player.set_mouse_captured(true)
	# The boot order is not guaranteed; the test puts the machine at the gate itself so the
	# damage path is what is being measured, not the boot order.
	if _catapult.has_method("place_near_castle"):
		_catapult.call("place_near_castle", _castle)
	await _settle(40)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	var before: Dictionary = _castle.call("get_stats")
	print("CSCAT_START cart=", (_catapult.call("snapshot") as Dictionary).get("cart", Vector3.ZERO),
		" stone=", (_catapult.call("snapshot") as Dictionary).get("stone", Vector3.ZERO),
		" wall=", base + Vector3(0.0, 0.0, half))
	# Put the stone on the spoon the way a player would, then aim and fire.
	_catapult.call("_set_stone_on_spoon")
	for i: int in 60:
		await process_frame
		if bool((_catapult.call("snapshot") as Dictionary).get("stone_on_spoon", false)): break
	print("CSCAT_LOADED on_spoon=", (_catapult.call("snapshot") as Dictionary).get("stone_on_spoon", false))
	_catapult.call("aim_at", base + Vector3(6.0, 8.0, half))
	await _settle(4)
	var aimed: Dictionary = _catapult.call("snapshot")
	print("CSCAT_AIM yaw=", aimed.get("yaw", 0.0), " elevation=", aimed.get("elevation", 0.0))
	_catapult.call("_fire")
	var fired := false
	for i: int in 400:
		await process_frame
		var snap: Dictionary = _catapult.call("snapshot")
		if bool(snap.get("flying", false)): fired = true
		if fired and not bool(snap.get("flying", false)): break
	await _settle(40)
	var after: Dictionary = _castle.call("get_stats")
	var snap2: Dictionary = _catapult.call("snapshot")
	print("CSCAT_RESULT_SHOT fired=", fired, " last_impact=", JSON.stringify(snap2.get("last_impact", {})))
	print("CSCAT_CASTLE before=", before.get("detached", 0), " after=", after.get("detached", 0),
		" collapsed=", after.get("collapsed", 0), " falling=", after.get("falling", 0))
	var failed: Array[String] = []
	if not fired: failed.append("never_fired")
	if int(after.get("detached", 0)) <= int(before.get("detached", 0)): failed.append("castle_took_no_damage")
	print("CSCAT_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)