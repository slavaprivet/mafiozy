extends SceneTree
## DSH_CASTLE: is there a hole in the castle's collision?
## Rays are fired from outside toward the centre at many angles and two heights. A ray that
## reaches the middle has gone THROUGH the wall, and its angle is printed.

var _scene: Node
var _castle: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("CAGE_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null: print("CAGE_FAIL castle"); quit(1); return
	await _settle(30)
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	var space: PhysicsDirectSpaceState3D = _castle.get_world_3d().direct_space_state
	var holes: Array[String] = []
	for height: float in [1.4, 6.0, 12.0]:
		for step: int in 96:
			var angle: float = TAU * float(step) / 96.0
			var dir := Vector3(cos(angle), 0.0, sin(angle))
			# A SQUARE wall: at 45 degrees the band is at half * sqrt(2), not at half. Using
			# "half" for every angle made the rays miss the corners entirely and invented 84
			# holes that were not there.
			var reach: float = half / maxf(absf(dir.x), absf(dir.z))
			var from: Vector3 = base + dir * (reach + 8.0) + Vector3.UP * height
			var to: Vector3 = base + dir * (reach - 3.0) + Vector3.UP * height
			var query := PhysicsRayQueryParameters3D.create(from, to)
			query.collision_mask = 1
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				holes.append("h=%.1f a=%.0f°" % [height, rad_to_deg(angle)])
	print("CAGE_HOLES count=", holes.size(), " at=", holes.slice(0, 12))
	var failed: Array[String] = []
	if holes.size() > 0: failed.append("wall_has_holes")
	print("CAGE_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)