extends SceneTree
## DSH_CASTLE: the map builds, the bricks are there, and a blast takes bricks out of the
## wall and brings the courses above them down.

var _scene: Node
var _castle: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("CASTLE_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("CASTLE_FAIL not_ready"); quit(1); return
	_castle = _scene.get("preview_castle")
	if _castle == null:
		print("CASTLE_FAIL no_castle status=", str(_scene.get("castle_status")))
		quit(1); return
	var player: CharacterBody3D = _scene.get("_player")
	await _settle(20)
	var start: Dictionary = _castle.call("get_stats")
	print("CASTLE_BUILT ", JSON.stringify(start))
	print("CASTLE_SPAWN player=", player.global_position, " castle_at=", _castle.global_position)
	# Fire a heavy stone at the south wall, a little above the ground, and watch it open.
	var wall := _castle.global_position + Vector3(13.0, 5.0, 32.0)
	var before := int(start.get("detached", 0))
	var result: Dictionary = _castle.call("apply_explosion", {
		"position": wall, "radius": 4.5, "power": 220.0,
		"direction": Vector3(0.0, -0.2, -1.0), "event_id": "castle_test:1",
	})
	print("CASTLE_BLAST ", JSON.stringify(result))
	await _settle(4)
	var mid: Dictionary = _castle.call("get_stats")
	print("CASTLE_AFTER_BLAST ", JSON.stringify(mid))
	await _settle(70)
	var after: Dictionary = _castle.call("get_stats")
	print("CASTLE_AFTER_CASCADE ", JSON.stringify(after))
	var failed: Array[String] = []
	if int(start.get("bricks", 0)) < 2000: failed.append("too_few_bricks")
	if int(start.get("gates", 0)) != 2: failed.append("gates")
	if not bool(result.get("ok", false)): failed.append("blast_refused")
	if int(mid.get("detached", 0)) <= before: failed.append("nothing_detached")
	if int(after.get("falling", 0)) <= 0: failed.append("no_falling_bodies")
	# A breach must GROW: bricks above the hole come down after the hit.
	if int(after.get("detached", 0)) <= int(mid.get("detached", 0)): failed.append("breach_does_not_climb")
	print("CASTLE_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)