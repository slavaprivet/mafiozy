extends SceneTree
## Actual native-body diagnosis for handbrake propulsion suppression.
## Intentionally fails against the frozen production body until source parity is restored.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const SOURCE_DYNAMICS := "res://../../assets/maps/city_rebuild_v1/vehicle_dynamics.mjs"
const PROFILE_ID := "compact_sedan"
const FROZEN_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const SOURCE_DYNAMICS_SHA256 := "105cce8bf2cac63136e1c5e48f38465c4bf8e448a271702136b7c014e3396faf"
const START_SPEED_MPS := 10.0
const STOP_SPEED_MPS := 0.25
const STOP_HOLD_TICKS := 30
const MEASURE_TICKS := 900

var checks := 0
var failures: Array[String] = []
var force_model: Dictionary = {}

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _profile(document: Dictionary) -> Dictionary:
	for row: Dictionary in document.get("profiles", []):
		if str(row.get("profile_id", "")) == PROFILE_ID:
			return row
	return {}

func _planar_speed(body: RigidBody3D) -> float:
	return Vector2(body.linear_velocity.x, body.linear_velocity.z).length()

func _planar_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()

func _run() -> void:
	var body_sha := FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd")
	_check(body_sha == FROZEN_BODY_SHA256, "native body remains at root LIVE frozen SHA")
	_check(FileAccess.get_sha256(SOURCE_DYNAMICS) == SOURCE_DYNAMICS_SHA256, "source dynamics receipt remains frozen")
	var source := FileAccess.get_file_as_string(SOURCE_DYNAMICS)
	_check(source.contains("braking=handbrake||") and source.contains("if(!braking&&pedal"),
		"source rule marks handbrake as braking and suppresses propulsion while braking")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(parsed is Dictionary, "transport descriptors parse")
	if not parsed is Dictionary:
		_finish([])
		return
	var profile := _profile(parsed as Dictionary)
	_check(not profile.is_empty(), "compact sedan profile exists")
	if profile.is_empty():
		_finish([])
		return

	var floor := StaticBody3D.new()
	floor.name = "HandbrakeFlatFloor"
	floor.set_meta("vehicle_surface_id", "dry_asphalt")
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(600.0, 0.5, 1000.0)
	var floor_collision := CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)
	root.add_child(floor)

	var scenarios := [
		{"id": "coast", "throttle": 0.0, "handbrake": false, "x": -20.0},
		{"id": "neutral_handbrake", "throttle": 0.0, "handbrake": true, "x": 0.0},
		{"id": "throttle_handbrake", "throttle": 1.0, "handbrake": true, "x": 20.0},
	]
	var cases: Array[Dictionary] = []
	for scenario: Dictionary in scenarios:
		var body = Factory.new().spawn_from_descriptor({
			"vehicle_id": "handbrake-" + str(scenario.id),
			"life_generation": 1,
			"profile_id": PROFILE_ID,
			"source_clock": 1,
			"active": true,
			"position_m": Vector3(float(scenario.x), 0.0, 200.0),
			"yaw_rad": 0.0,
		}, profile)
		_check(body != null, "spawn " + str(scenario.id))
		if body == null:
			continue
		root.add_child(body)
		cases.append({
			"id": scenario.id,
			"body": body,
			"throttle": scenario.throttle,
			"handbrake": scenario.handbrake,
			"start_position": Vector3.ZERO,
			"below_stop_ticks": 0,
			"stop_tick": -1,
			"stop_distance_m": -1.0,
			"minimum_speed_mps": START_SPEED_MPS,
			"maximum_speed_mps": START_SPEED_MPS,
			"rear_load_sum_n": 0.0,
			"rear_load_peak_n": 0.0,
			"rear_slip_sum": 0.0,
			"rear_slip_peak": 0.0,
			"rear_samples": 0,
			"grounded_mask_union": 0,
		})

	for tick in 180:
		await physics_frame
	if not cases.is_empty():
		var native_profile = (cases[0].body as RigidBody3D).profile
		force_model = {
			"mass_kg": native_profile.mass_kg,
			"engine_accel_mps2": native_profile.engine_accel_mps2,
			"brake_decel_mps2": native_profile.brake_decel_mps2,
			"handbrake_rear_grip": native_profile.handbrake_rear_grip,
			"front_drive_request_per_wheel_n": native_profile.engine_accel_mps2 * native_profile.mass_kg / 4.0,
			"rear_brake_request_per_wheel_n": native_profile.brake_decel_mps2 * native_profile.mass_kg / 4.0,
			"nominal_rear_handbrake_grip_cap_per_wheel_n": native_profile.mass_kg * 9.81 * native_profile.handbrake_rear_grip / 4.0,
		}
	for record: Dictionary in cases:
		var body: RigidBody3D = record.body
		_check(int(body.snapshot_state().grounded_wheel_mask) == 15, str(record.id) + " settles on four wheel rays")
		body.linear_velocity = Vector3(0.0, 0.0, -START_SPEED_MPS)
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		record.start_position = body.global_position
		_check(body.submit_control(float(record.throttle), 0.0, 0.0, bool(record.handbrake), 1),
			"control admitted " + str(record.id))

	for tick in MEASURE_TICKS:
		await physics_frame
		for record: Dictionary in cases:
			var body: RigidBody3D = record.body
			var speed := _planar_speed(body)
			record.minimum_speed_mps = minf(float(record.minimum_speed_mps), speed)
			record.maximum_speed_mps = maxf(float(record.maximum_speed_mps), speed)
			if int(record.stop_tick) < 0:
				record.below_stop_ticks = int(record.below_stop_ticks) + 1 if speed <= STOP_SPEED_MPS else 0
				if int(record.below_stop_ticks) >= STOP_HOLD_TICKS:
					record.stop_tick = tick + 2 - STOP_HOLD_TICKS
					record.stop_distance_m = _planar_distance(record.start_position, body.global_position)
			var state: Dictionary = body.snapshot_state()
			record.grounded_mask_union = int(record.grounded_mask_union) | int(state.grounded_wheel_mask)
			var loads: PackedFloat32Array = state.wheel_load_n
			var slips: PackedFloat32Array = state.wheel_slip
			for rear_index in [2, 3]:
				var load_n := float(loads[rear_index])
				var slip := float(slips[rear_index])
				record.rear_load_sum_n = float(record.rear_load_sum_n) + load_n
				record.rear_load_peak_n = maxf(float(record.rear_load_peak_n), load_n)
				record.rear_slip_sum = float(record.rear_slip_sum) + slip
				record.rear_slip_peak = maxf(float(record.rear_slip_peak), slip)
				record.rear_samples = int(record.rear_samples) + 1

	var results: Array[Dictionary] = []
	var by_id: Dictionary = {}
	for record: Dictionary in cases:
		var body: RigidBody3D = record.body
		var state: Dictionary = body.snapshot_state()
		var samples := maxi(1, int(record.rear_samples))
		var result := {
			"id": record.id,
			"throttle": record.throttle,
			"handbrake": record.handbrake,
			"start_speed_mps": START_SPEED_MPS,
			"stop_time_s": float(record.stop_tick) / 60.0 if int(record.stop_tick) >= 0 else null,
			"stop_distance_m": record.stop_distance_m if int(record.stop_tick) >= 0 else null,
			"distance_after_15s_m": _planar_distance(record.start_position, body.global_position),
			"final_speed_mps": _planar_speed(body),
			"minimum_speed_mps": record.minimum_speed_mps,
			"maximum_speed_mps": record.maximum_speed_mps,
			"mean_rear_load_n": float(record.rear_load_sum_n) / float(samples),
			"peak_rear_load_n": record.rear_load_peak_n,
			"mean_rear_slip": float(record.rear_slip_sum) / float(samples),
			"peak_rear_slip": record.rear_slip_peak,
			"final_rear_load_n": [float(state.wheel_load_n[2]), float(state.wheel_load_n[3])],
			"final_rear_slip": [float(state.wheel_slip[2]), float(state.wheel_slip[3])],
			"grounded_mask_union": record.grounded_mask_union,
		}
		results.append(result)
		by_id[record.id] = result

	if by_id.has("neutral_handbrake") and by_id.has("throttle_handbrake") and by_id.has("coast"):
		var neutral: Dictionary = by_id.neutral_handbrake
		var powered: Dictionary = by_id.throttle_handbrake
		var coast: Dictionary = by_id.coast
		_check(neutral.stop_time_s != null, "neutral handbrake stops from 10 mps within 15 seconds")
		_check(float(neutral.distance_after_15s_m) < float(coast.distance_after_15s_m),
			"neutral handbrake travels less distance than coast")
		# Expected to fail on frozen production: front-wheel propulsion remains active
		# while the rear handbrake is grip-limited.
		_check(powered.stop_time_s != null, "source parity: throttle plus handbrake still stops")
		_check(float(powered.final_speed_mps) <= float(neutral.final_speed_mps) + 0.25,
			"source parity: braking suppresses propulsion before tyre-force distribution")

	for record: Dictionary in cases:
		(record.body as RigidBody3D).free()
	floor.free()
	_finish(results)

func _finish(results: Array[Dictionary]) -> void:
	print("NATIVE_VEHICLE_HANDBRAKE_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"body_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"source_dynamics_sha256": FileAccess.get_sha256(SOURCE_DYNAMICS),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"measure_seconds": float(MEASURE_TICKS) / 60.0,
		"force_model": force_model,
		"results": results,
		"proposed_exact_fix": "In _apply_wheel_step set braking_request = (_brake > CONTROL_DEADZONE or _handbrake), then requested_drive = 0.0 when braking_request before distributing longitudinal force; keep rear-only handbrake and existing grip/brake calibration unchanged.",
		"qualification": "actual frozen NativeVehicleBody on flat dry asphalt; headless fixed-step diagnosis, intentionally failing source-parity regression; no body, main, GPU, LIVE or Git mutation",
	}))
	quit(0 if failures.is_empty() else 1)
