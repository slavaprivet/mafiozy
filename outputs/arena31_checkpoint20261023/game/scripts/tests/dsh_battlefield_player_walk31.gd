extends SceneTree
## Moves the REAL PlayerController through the battlefield using its normal input,
## CharacterBody3D physics and collisions. No direct per-frame position assignment.

const STEP := 4.0
const Z0 := 80.0
const MIN_X := -20
const MAX_X := 20
const MIN_Z := 0
const MAX_Z := 42

var _scene: Node
var _castle: Node3D
var _field: Node3D
var _player: CharacterBody3D
var _capsule := CapsuleShape3D.new()
var _open: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _has_property(object: Object, name: String) -> bool:
	for item: Dictionary in object.get_property_list():
		if String(item.get("name", "")) == name:
			return true
	return false

func _install_if_needed() -> bool:
	if _has_property(_scene, "preview_battlefield"):
		_field = _scene.get("preview_battlefield") as Node3D
	if _field != null:
		return true
	var site_script: GDScript = load("res://scripts/city/battlefield_site.gd") as GDScript
	if site_script == null:
		return false
	_field = site_script.new() as Node3D
	var site_result: Dictionary = _field.call("install", _scene, _castle)
	if not bool(site_result.get("ok", true)):
		print("BATTLEFIELD_PLAYER_SITE_FAIL ", JSON.stringify(site_result))
		return false
	var props_script: GDScript = load("res://scripts/city/battlefield_props.gd") as GDScript
	if props_script != null:
		var props: Node3D = props_script.new() as Node3D
		_field.add_child(props)
		var props_result: Dictionary = props.call("install", _castle)
		if not bool(props_result.get("ok", true)):
			print("BATTLEFIELD_PLAYER_PROPS_FAIL ", JSON.stringify(props_result))
			return false
	return true

func _local(key: Vector2i) -> Vector2:
	return Vector2(float(key.x) * STEP, Z0 + float(key.y) * STEP)

func _height(x: float, z: float) -> float:
	return maxf(0.02, float(_field.call("terrain_height", x, z)))

func _clear_at(x: float, z: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = 1
	query.transform = Transform3D(Basis(), _castle.global_position + Vector3(x, _height(x, z) + 0.93, z))
	return root.world_3d.direct_space_state.intersect_shape(query, 1).is_empty()

func _clear(key: Vector2i) -> bool:
	if not _open.has(key):
		var point := _local(key)
		_open[key] = _clear_at(point.x, point.y)
	return bool(_open[key])

func _find_route(start: Vector2i, goal: Vector2i) -> Array[Vector2]:
	var queue: Array[Vector2i] = [start]
	var parent: Dictionary = {start: start}
	var index := 0
	var directions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		if current == goal:
			break
		for offset: Vector2i in directions:
			var next := current + offset
			if next.x < MIN_X or next.x > MAX_X or next.y < MIN_Z or next.y > MAX_Z:
				continue
			if parent.has(next) or not _clear(next):
				continue
			parent[next] = current
			queue.append(next)
	if not parent.has(goal):
		return []
	var reversed: Array[Vector2] = []
	var current: Vector2i = goal
	while current != start:
		reversed.append(_local(current))
		current = parent[current]
	var raw: Array[Vector2] = []
	for i: int in range(reversed.size() - 1, -1, -1):
		raw.append(reversed[i])
	return _smooth_route(_local(start), raw)

func _line_clear(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var samples := maxi(1, ceili(distance / 1.0))
	for sample: int in range(1, samples + 1):
		var at := from.lerp(to, float(sample) / float(samples))
		if not _clear_at(at.x, at.y):
			return false
	return true

func _smooth_route(start: Vector2, raw: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var cursor := start
	var index := 0
	while index < raw.size():
		var far := index
		for candidate: int in range(raw.size() - 1, index, -1):
			if _line_clear(cursor, raw[candidate]):
				far = candidate
				break
		result.append(raw[far])
		cursor = raw[far]
		index = far + 1
	return result

func _walk(label: String, goal: Vector2i, start: Vector2i = Vector2i(0, 4)) -> Dictionary:
	var points := _find_route(start, goal)
	if points.is_empty():
		return {"pass": false, "reason": "no_capsule_route", "goal": goal}
	var start_at := _local(start)
	_player.global_position = _castle.global_position + Vector3(start_at.x, 1.0, start_at.y)
	_player.velocity = Vector3.ZERO
	for frame: int in 45:
		await physics_frame
	var start_grounded := _player.is_on_floor()
	var start_actual: Vector3 = _player.global_position - _castle.global_position
	if absf(start_actual.x - start_at.x) > 1.0 or absf(start_actual.z - start_at.y) > 1.0:
		return {"pass": false, "route": label, "reason": "spawn_override_after_ready",
			"start_requested": start_at, "start_actual": start_actual,
			"catapult_placed": _scene.get("_catapult_at_castle"),
			"spawn_frames": _scene.get("_castle_spawn_frames")}
	var frames := 0
	var off_floor := 0
	var max_off_floor := 0
	var current_off_floor := 0
	var max_feet_error := 0.0
	var min_feet_error := 1000.0
	var max_vertical_tick := 0.0
	var stalls := 0
	var failures: Array[String] = []
	var former_y: float = _player.global_position.y
	Input.action_press(_player.ACTION_FORWARD)
	for target: Vector2 in points:
		var target_world := _castle.global_position + Vector3(target.x, 0.0, target.y)
		var last_distance := 1000.0
		var no_progress := 0
		for frame: int in 3600:
			var delta := target_world - _player.global_position
			var horizontal := Vector2(delta.x, delta.z)
			if horizontal.length() < 0.8:
				break
			_player.set("_camera_yaw", atan2(-delta.x, -delta.z))
			await physics_frame
			frames += 1
			var current: Vector3 = _player.global_position
			var local := current - _castle.global_position
			var expected := _height(local.x, local.z)
			var error := local.y - expected
			max_feet_error = maxf(max_feet_error, error)
			min_feet_error = minf(min_feet_error, error)
			max_vertical_tick = maxf(max_vertical_tick, absf(current.y - former_y))
			former_y = current.y
			if _player.is_on_floor():
				current_off_floor = 0
			else:
				off_floor += 1
				current_off_floor += 1
				max_off_floor = maxi(max_off_floor, current_off_floor)
			var distance := Vector2(target_world.x - current.x, target_world.z - current.z).length()
			if distance < last_distance - 0.01:
				no_progress = 0
			else:
				no_progress += 1
			last_distance = distance
			if no_progress > 120:
				stalls += 1
				failures.append("stalled_at_%s" % current)
				break
		if Vector2(target_world.x - _player.global_position.x,
				target_world.z - _player.global_position.z).length() >= 0.8:
			failures.append("missed_waypoint_%s" % target)
			break
	Input.action_release(_player.ACTION_FORWARD)
	var ending: Vector3 = _player.global_position - _castle.global_position
	var goal_at := _local(goal)
	if Vector2(ending.x, ending.z).distance_to(goal_at) > 1.4:
		failures.append("goal_not_reached")
	if not start_grounded:
		failures.append("spawn_not_grounded")
	if frames == 0 or float(off_floor) / float(maxi(1, frames)) > 0.07 or max_off_floor > 12:
		failures.append("airborne_too_long")
	if min_feet_error < -0.20 or max_feet_error > 0.55:
		failures.append("feet_mismatch")
	if max_vertical_tick > 0.30:
		failures.append("abrupt_vertical_step")
	return {"pass": failures.is_empty(), "route": label, "start": start_at,
		"start_actual": start_actual,
		"goal": goal_at, "end": ending, "waypoints": points.size(),
		"frames": frames, "start_grounded": start_grounded,
		"off_floor_frames": off_floor, "max_off_floor_chain": max_off_floor,
		"max_feet_error": max_feet_error, "min_feet_error": min_feet_error,
		"max_vertical_tick": max_vertical_tick, "stalls": stalls,
		"failures": failures}

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_PLAYER_WALK_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_castle = _scene.get("preview_castle") as Node3D
	_player = _scene.get("_player") as CharacterBody3D
	if _castle == null or _player == null or not _install_if_needed():
		print("BATTLEFIELD_PLAYER_WALK_FAIL missing_scene_parts")
		quit(1)
		return
	_capsule.radius = 0.38
	_capsule.height = 1.72
	# Main may place the catapult and reassert its spawn AFTER preview_ready.
	# Wait for that one-time placement before test-directed starting positions.
	var catapult: Variant = _scene.get("preview_catapult")
	if is_instance_valid(catapult):
		var placement_deadline := Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < placement_deadline and _scene.get("_catapult_at_castle") != true:
			await physics_frame
		if _scene.get("_catapult_at_castle") != true:
			print("BATTLEFIELD_PLAYER_WALK_FAIL catapult_placement_timeout")
			quit(1)
			return
	# Main's first 400 frames protect the normal catapult spawn. This fixture
	# deliberately places the actor at the distant battle road after placement.
	_scene.set("_castle_spawn_frames", 0)
	_player.set_mouse_captured(true)
	for frame: int in 5:
		await physics_frame
	var reports: Array[Dictionary] = []
	if OS.get_environment("DSH_BATTLEFIELD_WALK_BERM_ONLY") != "1":
		reports.append(await _walk("central_road", Vector2i(0, 36))) # x=0, z=224
		reports.append(await _walk("left_flank", Vector2i(-12, 19))) # x=-48, z=156
		reports.append(await _walk("right_flank", Vector2i(12, 19))) # x=48, z=156
	reports.append(await _walk("berm_off_lane", Vector2i(5, 15), Vector2i(5, 8))) # x=20, z=112..140
	var passed := true
	for report: Dictionary in reports:
		passed = passed and bool(report.get("pass", false))
	print("BATTLEFIELD_PLAYER_WALK ", JSON.stringify({"pass": passed,
		"real_player": true, "reports": reports}))
	quit(0 if passed else 1)
