extends SceneTree
## Bounded headless settle proof for every source transport profile.
## Uses only native physics bodies and one actual Godot floor; no visuals or main runtime.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const EXPECTED_PROFILE_COUNT := 12
const MIN_TICKS := 180
const MAX_TICKS := 600
const STABLE_TICKS := 60
const MAX_LINEAR_SPEED_MPS := 0.03
const MAX_TILT_RAD := 0.035
const MAX_ROOT_OFFSET_M := 0.03
const MAX_JITTER_M := 0.005
const COLLIDER_PENETRATION_TOLERANCE_M := 0.005
const SPAWN_HEIGHT_M := 0.75

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _finite_array(values: Variant) -> bool:
	if not values is Array and not values is PackedFloat32Array and not values is PackedFloat64Array:
		return false
	for value: Variant in values:
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	return true

func _finite_body_state(body: RigidBody3D, state: Dictionary) -> bool:
	var basis := body.global_basis
	return body.global_position.is_finite() and basis.x.is_finite() and basis.y.is_finite() and basis.z.is_finite() \
		and body.linear_velocity.is_finite() and body.angular_velocity.is_finite() \
		and _finite_array(state.get("wheel_load_n")) and _finite_array(state.get("wheel_slip")) \
		and _finite_array(state.get("wheel_longitudinal_mps"))

func _ray_count(body: Node) -> int:
	var count := 0
	for child: Node in body.get_children():
		if child is RayCast3D:
			count += 1
	return count

func _tilt_rad(body: Node3D) -> float:
	var up := body.global_basis.y
	if not up.is_finite() or up.length_squared() < 0.000001:
		return INF
	return acos(clampf(up.normalized().dot(Vector3.UP), -1.0, 1.0))

func _collider_base_world_y(body: Node3D) -> float:
	var minimum := INF
	var found := false
	for child: Node in body.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or not collision.shape is BoxShape3D:
			continue
		var half := (collision.shape as BoxShape3D).size * 0.5
		for corner in 8:
			var local := Vector3(
				half.x if (corner & 1) != 0 else -half.x,
				half.y if (corner & 2) != 0 else -half.y,
				half.z if (corner & 4) != 0 else -half.z)
			var world := collision.global_transform * local
			minimum = minf(minimum, world.y)
			found = true
	return minimum if found else NAN

func _append_history(histories: Dictionary, key: String, position: Vector3) -> void:
	var points: Array = histories.get(key, [])
	points.append(position)
	if points.size() > STABLE_TICKS:
		points.pop_front()
	histories[key] = points

func _jitter_m(points: Array) -> float:
	if points.size() < STABLE_TICKS:
		return INF
	var maximum_step := 0.0
	var previous: Vector3 = points[0]
	if not previous.is_finite():
		return INF
	for index in range(1, points.size()):
		var value: Variant = points[index]
		if not value is Vector3 or not (value as Vector3).is_finite():
			return INF
		maximum_step = maxf(maximum_step, previous.distance_to(value as Vector3))
		previous = value as Vector3
	return maximum_step

func _instant_metrics(body: RigidBody3D, histories: Dictionary, profile_id: String) -> Dictionary:
	var state: Dictionary = body.snapshot_state()
	var collider_base := _collider_base_world_y(body)
	var jitter := _jitter_m(histories.get(profile_id, []))
	var ray_count := _ray_count(body)
	var grounded_mask := int(state.get("grounded_wheel_mask", 0))
	var tilt := _tilt_rad(body)
	var speed := body.linear_velocity.length()
	var finite := _finite_body_state(body, state) and is_finite(collider_base) and is_finite(jitter) \
		and is_finite(tilt) and is_finite(speed)
	return {
		"finite": finite,
		"ray_count": ray_count,
		"grounded_wheel_mask": grounded_mask,
		"speed_mps": speed,
		"angular_speed_radps": body.angular_velocity.length(),
		"tilt_rad": tilt,
		"root_y_m": body.global_position.y,
		"jitter_m": jitter,
		"collider_base_world_y_m": collider_base,
		"stable": finite and ray_count == 4 and grounded_mask == 15 \
			and speed <= MAX_LINEAR_SPEED_MPS and tilt <= MAX_TILT_RAD \
			and absf(body.global_position.y) <= MAX_ROOT_OFFSET_M and jitter <= MAX_JITTER_M \
			and collider_base >= -COLLIDER_PENETRATION_TOLERANCE_M,
	}

func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "AllProfilesSettleFloor"
	floor.set_meta("vehicle_surface_id", "all_profiles_flat_floor")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 0.5, 70.0)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.25, 0.0)
	floor.add_child(collision)
	return floor

func _grid_position(index: int) -> Vector3:
	var column := index % 4
	var row := index / 4
	return Vector3((float(column) - 1.5) * 14.0, SPAWN_HEIGHT_M, (float(row) - 1.0) * 18.0)

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(parsed is Dictionary, "transport descriptor parses")
	if not parsed is Dictionary:
		_finish(0, 0, [])
		return
	var document := parsed as Dictionary
	var profile_rows: Variant = document.get("profiles")
	_check(document.get("schema") == "mafiozi.transport.descriptors.v1", "transport descriptor schema")
	_check(profile_rows is Array and profile_rows.size() == EXPECTED_PROFILE_COUNT, "exactly twelve source profiles")
	if not profile_rows is Array or profile_rows.size() != EXPECTED_PROFILE_COUNT:
		_finish(0, 0, [])
		return

	var floor := _make_floor()
	root.add_child(floor)
	var factory := Factory.new()
	var bodies: Array[RigidBody3D] = []
	var profile_ids: Array[String] = []
	var histories: Dictionary = {}
	var seen: Dictionary = {}
	for index in profile_rows.size():
		var row: Variant = profile_rows[index]
		_check(row is Dictionary, "profile row type " + str(index))
		if not row is Dictionary:
			continue
		var profile_id := str(row.get("profile_id", ""))
		_check(not profile_id.is_empty() and not seen.has(profile_id), "unique profile identity " + profile_id)
		seen[profile_id] = true
		var body := factory.spawn_from_descriptor({
			"vehicle_id": "all-profiles-" + profile_id,
			"life_generation": 1,
			"profile_id": profile_id,
			"active": true,
			"position_m": _grid_position(index),
			"yaw_rad": 0.0,
			"source_clock": 1,
		}, row)
		_check(body != null, "spawn profile " + profile_id + ":" + factory.last_error)
		if body == null:
			continue
		body.name = "Settle_" + profile_id
		root.add_child(body)
		bodies.append(body)
		profile_ids.append(profile_id)
		histories[profile_id] = []
	_check(bodies.size() == EXPECTED_PROFILE_COUNT, "all twelve bodies spawned")
	if bodies.size() != EXPECTED_PROFILE_COUNT:
		floor.free()
		for body: RigidBody3D in bodies:
			body.free()
		_finish(0, 0, [])
		return

	var stable_streak := 0
	var ticks_run := 0
	while ticks_run < MAX_TICKS and stable_streak < STABLE_TICKS:
		await physics_frame
		ticks_run += 1
		for index in bodies.size():
			_append_history(histories, profile_ids[index], bodies[index].global_position)
		if ticks_run < MIN_TICKS:
			continue
		var all_stable := true
		for index in bodies.size():
			var metrics := _instant_metrics(bodies[index], histories, profile_ids[index])
			if not bool(metrics.stable):
				all_stable = false
				break
		stable_streak = stable_streak + 1 if all_stable else 0

	var results: Array[Dictionary] = []
	for index in bodies.size():
		var profile_id := profile_ids[index]
		var body := bodies[index]
		var metrics := _instant_metrics(body, histories, profile_id)
		metrics["profile_id"] = profile_id
		results.append(metrics)
		_check(bool(metrics.finite), profile_id + " finite physics state")
		_check(int(metrics.ray_count) == 4, profile_id + " has four actual wheel rays")
		_check(int(metrics.grounded_wheel_mask) == 15, profile_id + " has four grounded rays")
		_check(float(metrics.speed_mps) <= MAX_LINEAR_SPEED_MPS, profile_id + " linear velocity settled")
		_check(float(metrics.tilt_rad) <= MAX_TILT_RAD, profile_id + " chassis tilt settled")
		_check(absf(float(metrics.root_y_m)) <= MAX_ROOT_OFFSET_M, profile_id + " source-ground root aligned")
		_check(float(metrics.jitter_m) <= MAX_JITTER_M, profile_id + " bounded peak frame-to-frame jitter")
		_check(float(metrics.collider_base_world_y_m) >= -COLLIDER_PENETRATION_TOLERANCE_M, profile_id + " collider base does not penetrate floor")
	_check(ticks_run >= MIN_TICKS and ticks_run <= MAX_TICKS, "bounded settle tick count")
	_check(stable_streak >= STABLE_TICKS, "all twelve profiles sustain sixty stable ticks")

	for body: RigidBody3D in bodies:
		body.free()
	floor.free()
	_finish(ticks_run, stable_streak, results)

func _finish(ticks_run: int, stable_streak: int, profiles: Array) -> void:
	print("NATIVE_VEHICLE_ALL_PROFILES_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failure_count": failures.size(),
		"failures": failures,
		"descriptor_sha256": FileAccess.get_sha256(DESCRIPTORS),
		"profile_count": profiles.size(),
		"ticks_run": ticks_run,
		"stable_streak": stable_streak,
		"limits": {
			"min_ticks": MIN_TICKS,
			"max_ticks": MAX_TICKS,
			"required_stable_ticks": STABLE_TICKS,
			"max_linear_speed_mps": MAX_LINEAR_SPEED_MPS,
			"max_tilt_rad": MAX_TILT_RAD,
			"max_root_offset_m": MAX_ROOT_OFFSET_M,
			"max_jitter_m": MAX_JITTER_M,
			"jitter_definition": "maximum 3D root displacement between consecutive frames in the trailing sixty physics ticks",
			"collider_penetration_tolerance_m": COLLIDER_PENETRATION_TOLERANCE_M,
		},
		"profiles": profiles,
		"qualification": "headless Godot 3D physics; one flat floor, twelve isolated native bodies; no visual, GPU, main or LIVE",
	}))
	quit(0 if failures.is_empty() else 1)
