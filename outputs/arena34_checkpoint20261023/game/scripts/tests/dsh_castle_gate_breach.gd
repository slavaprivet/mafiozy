extends SceneTree
## DSH_CASTLE: the gates can be BROKEN, not only opened.
## A blast is placed on the gate itself; the leaves must come off their hinges and planks
## must be thrown out where the door stood.

var _scene: Node
var _castle: Node3D

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("BREACH_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null: print("BREACH_FAIL castle"); quit(1); return
	for i: int in 30:
		await process_frame
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	var before: Dictionary = _castle.call("get_stats")
	var result: Dictionary = _castle.call("apply_explosion", {
		"position": base + Vector3(0.0, 5.0, half),
		"radius": 4.0, "power": 260.0,
		"direction": Vector3(0.0, 0.0, -1.0), "event_id": "gate_breach:1",
	})
	for i: int in 30:
		await process_frame
	var after: Dictionary = _castle.call("get_stats")
	print("BREACH_BEFORE gates_detached=", before.get("gate_leaves_detached", -1))
	print("BREACH_RESULT_DICT ", JSON.stringify(result))
	print("BREACH_AFTER gates_detached=", after.get("gate_leaves_detached", -1),
		" falling=", after.get("falling", 0), " detached_bricks=", after.get("detached", 0))
	var failed: Array[String] = []
	if int(result.get("ok", 0)) == 0: failed.append("blast_refused")
	if int(after.get("gate_leaves_detached", 0)) < 2: failed.append("gates_did_not_break")
	if int(after.get("falling", 0)) <= 0: failed.append("no_planks_thrown")
	print("BREACH_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)