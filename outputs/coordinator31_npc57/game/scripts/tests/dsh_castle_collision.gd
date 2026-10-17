extends SceneTree
## DSH_CASTLE: is the wall solid, and is the gate actually open to walk through?
## Rays are cast from inside the courtyard towards each wall, and through the gate.

var _scene: Node
var _castle: Node3D

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("COLL_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null: print("COLL_FAIL no_castle"); quit(1); return
	for i: int in 30:
		await process_frame
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	var report: Dictionary = {}
	# Into each wall: from two metres inside towards the masonry.
	var probes := {
		"north": Vector3(0.0, 3.0, -half + 2.0),
		"south_east_of_gate": Vector3(20.0, 3.0, half - 2.0),
		"east": Vector3(half - 2.0, 3.0, 0.0),
		"west": Vector3(-half + 2.0, 3.0, 0.0),
	}
	for key: String in probes.keys():
		var from: Vector3 = base + (probes[key] as Vector3)
		var to: Vector3 = from + (from - base).normalized() * 6.0
		var query := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit: Dictionary = space.intersect_ray(query)
		report[key] = not hit.is_empty()
	# With the gate SHUT it must block the way; then it is opened and must let a man through.
	var shut_query := PhysicsRayQueryParameters3D.create(base + Vector3(0.0, 3.0, half - 4.0),
		base + Vector3(0.0, 3.0, half + 10.0), 1)
	report["shut_gate_blocks"] = not space.intersect_ray(shut_query).is_empty()
	_castle.call("set_gate", true)
	for i: int in 200:
		_castle.call("_advance_gate", 0.05)
		if float(_castle.call("gate_angle")) >= 0.95: break
	await process_frame
	await process_frame
	# Through the middle of the gate: from the courtyard out to the road. It must NOT hit
	# a wall, or the gate cannot be walked through.
	var gate_query := PhysicsRayQueryParameters3D.create(base + Vector3(0.0, 3.0, half - 4.0),
		base + Vector3(0.0, 3.0, half + 10.0), 1)
	var gate_hit: Dictionary = space.intersect_ray(gate_query)
	report["gate_passable"] = gate_hit.is_empty()
	print("COLL_REPORT ", JSON.stringify(report))
	var failed: Array[String] = []
	for key: String in report.keys():
		if key == "shut_gate_blocks":
			if not bool(report[key]): failed.append("shut_gate_lets_you_through")
		elif key == "gate_passable":
			if not bool(report[key]): failed.append("gate_blocked")
		elif not bool(report[key]): failed.append(key + "_open")
	print("COLL_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)