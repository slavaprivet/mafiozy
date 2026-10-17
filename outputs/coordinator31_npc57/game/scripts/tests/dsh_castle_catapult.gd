extends SceneTree
## DSH_CASTLE: does a catapult stone bring the castle's masonry down?
## The machine is left where the map puts it, the player takes his place, and the shot is
## followed into the wall. The castle's own counters are the judge.

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
	await _settle(40)
	var cart: Dictionary = _catapult.call("snapshot")
	print("CSCAT_CART pos=", cart.get("cart", Vector3.ZERO),
		" spawn=", _player.global_position, " castle=", _castle.global_position)
	var before: int = int((_castle.call("get_stats") as Dictionary).get("detached", 0))
	# Take the stone, set it in the spoon, and fire at the wall.
	var stone: Vector3 = cart.get("stone", Vector3.ZERO)
	_player.global_position = stone + Vector3(0.0, 0.05, 0.6)
	await _settle(12)
	_catapult.call("_try_interact")
	await _settle(30)
	var spoon: Vector3 = _catapult.call("spoon_point")
	_player.global_position = spoon + Vector3(0.0, 0.05, 1.2)
	await _settle(12)
	_catapult.call("_try_interact")
	for i: int in 60:
		await process_frame
		if bool((_catapult.call("snapshot") as Dictionary).get("stone_on_spoon", false)): break
	# Stand at the frame and fire at the gate wall.
	_player.global_position = (_catapult.call("snapshot") as Dictionary).get("cart", Vector3.ZERO) + Vector3(0.0, 0.05, -1.6)
	await _settle(12)
	var aim: Vector3 = _castle.global_position + Vector3(14.0, 7.0, float(_castle.call("wall_half")))
	_catapult.call("aim_at", aim)
	await _settle(6)
	_catapult.call("_try_interact")
	var peak := 0.0
	for i: int in 240:
		await process_frame
		var snap: Dictionary = _catapult.call("snapshot")
		peak = maxf(peak, float(snap.get("fly_age", 0.0)))
		if not bool(snap.get("flying", false)) and peak > 0.05: break
	await _settle(30)
	var after: Dictionary = _castle.call("get_stats")
	var cat: Dictionary = _catapult.call("snapshot")
	print("CSCAT_SHOT delivered=", (cat.get("last_impact", {}) as Dictionary).get("ok", false),
		" impact=", cat.get("last_impact", {}))
	print("CSCAT_CASTLE before=", before, " detached=", after.get("detached", 0),
		" collapsed=", after.get("collapsed", 0), " falling=", after.get("falling", 0))
	var failed: Array[String] = []
	if int(after.get("detached", 0)) <= before: failed.append("castle_took_no_damage")
	print("CSCAT_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)