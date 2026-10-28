extends SceneTree
## Candidate-only handbrake regression. The frozen production body is never loaded
## through the factory and remains the root LIVE authority.

const CANDIDATE := "res://../../outputs/vehicle_native_body_candidate_handbrake.gd"
const CANDIDATE_SHA256 := "67da32426d7b503eee0f92294f7e57c0406a857a17ee1f6e91a2eabf34cc4c0d"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const SOURCE_DYNAMICS := "res://../../assets/maps/city_rebuild_v1/vehicle_dynamics.mjs"
const SOURCE_DYNAMICS_SHA256 := "105cce8bf2cac63136e1c5e48f38465c4bf8e448a271702136b7c014e3396faf"
const PROFILE_ID := "compact_sedan"
const START_SPEED_MPS := 10.0
const STOP_SPEED_MPS := 0.25
const STOP_HOLD_TICKS := 30
const SETTLE_TICKS := 180
const MEASURE_TICKS := 900
const FIXED_TICKS_PER_SECOND := 60

var checks := 0
var failures: Array[String] = []
var Body: GDScript

func _initialize() -> void:
	Engine.physics_ticks_per_second = FIXED_TICKS_PER_SECOND
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func load_candidate_without_duplicate_global_name() -> GDScript:
	# Loading the candidate's production class_name beside the registered frozen
	# body is a Godot compile error. Remove only that declaration in memory.
	var source := FileAccess.get_file_as_string(CANDIDATE)
	if source.begins_with("class_name NativeVehicleBody\n"):
		source = source.trim_prefix("class_name NativeVehicleBody\n")
	elif source.begins_with("class_name NativeVehicleBody\r\n"):
		source = source.trim_prefix("class_name NativeVehicleBody\r\n")
	else:
		return null
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return null
	return script

func descriptor_for(rows: Array, vehicle_id: String) -> Dictionary:
	for candidate: Dictionary in rows:
		if str(candidate.get("profile_id", "")) != PROFILE_ID:
			continue
		var descriptor := candidate.duplicate(true)
		descriptor.vehicle_id = vehicle_id
		descriptor.source_id = PROFILE_ID
		descriptor.life_generation = 1
		descriptor.source_clock = 1
		return descriptor
	return {}

func add_floor(world: Node3D) -> void:
	var floor := StaticBody3D.new()
	floor.name = "CandidateHandbrakeFloor"
	floor.set_meta("vehicle_surface_id", "dry_asphalt")
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 0.5, 1000.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.25
	floor.add_child(collision)
	world.add_child(floor)

func add_candidate(world: Node3D, descriptor: Dictionary, position: Vector3):
	var body: RigidBody3D = Body.new()
	if not body.configure(descriptor):
		body.free()
		return null
	body.position = position
	world.add_child(body)
	return body

func planar_speed(body: RigidBody3D) -> float:
	return Vector2(body.linear_velocity.x, body.linear_velocity.z).length()

func planar_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()

func run() -> void:
	check(FileAccess.get_sha256(CANDIDATE) == CANDIDATE_SHA256, "exact handbrake candidate receipt")
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256, "frozen production body remains untouched")
	check(FileAccess.get_sha256(SOURCE_DYNAMICS) == SOURCE_DYNAMICS_SHA256, "exact source dynamics receipt")
	var source := FileAccess.get_file_as_string(SOURCE_DYNAMICS)
	check(source.contains("braking=handbrake||") and source.contains("if(!braking&&pedal"),
		"source contract suppresses propulsion whenever handbrake marks braking")
	Body = load_candidate_without_duplicate_global_name()
	check(Body != null, "candidate compiles after removing only duplicate class_name declaration")
	if Body == null:
		print_result([])
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary, "transport descriptors parse")
	if not parsed is Dictionary:
		print_result([])
		return
	var rows: Array = (parsed as Dictionary).get("profiles", [])
	var neutral_descriptor := descriptor_for(rows, "candidate-neutral-handbrake")
	var powered_descriptor := descriptor_for(rows, "candidate-throttle-handbrake")
	check(not neutral_descriptor.is_empty() and not powered_descriptor.is_empty(), "compact sedan descriptors available")

	var world := Node3D.new()
	root.add_child(world)
	add_floor(world)
	var neutral = add_candidate(world, neutral_descriptor, Vector3(-12.0, 1.15, 200.0))
	var powered = add_candidate(world, powered_descriptor, Vector3(12.0, 1.15, 200.0))
	check(neutral != null and powered != null, "candidate comparison bodies configure")
	if neutral == null or powered == null:
		world.free()
		print_result([])
		return

	for _tick in SETTLE_TICKS:
		await physics_frame
	check(int(neutral.snapshot_state().grounded_wheel_mask) == 0b1111, "neutral handbrake fixture settles on four probes")
	check(int(powered.snapshot_state().grounded_wheel_mask) == 0b1111, "powered handbrake fixture settles on four probes")
	neutral.linear_velocity = Vector3(0.0, 0.0, -START_SPEED_MPS)
	powered.linear_velocity = Vector3(0.0, 0.0, -START_SPEED_MPS)
	neutral.angular_velocity = Vector3.ZERO
	powered.angular_velocity = Vector3.ZERO
	neutral.sleeping = false
	powered.sleeping = false
	var neutral_start: Vector3 = neutral.global_position
	var powered_start: Vector3 = powered.global_position
	check(neutral.submit_control(0.0, 0.0, 0.0, true, 1), "neutral handbrake control admitted")
	check(powered.submit_control(1.0, 0.0, 0.0, true, 1), "throttle plus handbrake control admitted")

	var probes := [
		{"id": "neutral_handbrake", "body": neutral, "start": neutral_start, "below": 0,
			"stop_tick": -1, "stop_distance_m": -1.0, "maximum_speed_mps": START_SPEED_MPS,
			"rear_load_sum_n": 0.0, "rear_slip_sum": 0.0, "rear_samples": 0},
		{"id": "throttle_handbrake", "body": powered, "start": powered_start, "below": 0,
			"stop_tick": -1, "stop_distance_m": -1.0, "maximum_speed_mps": START_SPEED_MPS,
			"rear_load_sum_n": 0.0, "rear_slip_sum": 0.0, "rear_samples": 0},
	]
	for tick in MEASURE_TICKS:
		await physics_frame
		for probe: Dictionary in probes:
			var body: RigidBody3D = probe.body
			var speed := planar_speed(body)
			probe.maximum_speed_mps = maxf(float(probe.maximum_speed_mps), speed)
			if int(probe.stop_tick) < 0:
				probe.below = int(probe.below) + 1 if speed <= STOP_SPEED_MPS else 0
				if int(probe.below) >= STOP_HOLD_TICKS:
					probe.stop_tick = tick + 2 - STOP_HOLD_TICKS
					probe.stop_distance_m = planar_distance(probe.start, body.global_position)
			var state: Dictionary = body.snapshot_state()
			for rear_index in [2, 3]:
				probe.rear_load_sum_n = float(probe.rear_load_sum_n) + float(state.wheel_load_n[rear_index])
				probe.rear_slip_sum = float(probe.rear_slip_sum) + float(state.wheel_slip[rear_index])
				probe.rear_samples = int(probe.rear_samples) + 1

	var results: Array[Dictionary] = []
	for probe: Dictionary in probes:
		var body: RigidBody3D = probe.body
		var samples := maxi(1, int(probe.rear_samples))
		results.append({
			"id": probe.id,
			"stop_time_s": float(probe.stop_tick) / float(FIXED_TICKS_PER_SECOND) if int(probe.stop_tick) >= 0 else null,
			"stop_distance_m": probe.stop_distance_m if int(probe.stop_tick) >= 0 else null,
			"distance_after_15s_m": planar_distance(probe.start, body.global_position),
			"final_speed_mps": planar_speed(body),
			"maximum_speed_mps": probe.maximum_speed_mps,
			"mean_rear_load_n": float(probe.rear_load_sum_n) / float(samples),
			"mean_rear_slip": float(probe.rear_slip_sum) / float(samples),
		})

	var neutral_result: Dictionary = results[0]
	var powered_result: Dictionary = results[1]
	check(neutral_result.stop_time_s != null and powered_result.stop_time_s != null,
		"both handbrake inputs stop from 10 mps within 15 seconds")
	if neutral_result.stop_time_s != null and powered_result.stop_time_s != null:
		check(absf(float(neutral_result.stop_time_s) - float(powered_result.stop_time_s)) <= 0.10,
			"held throttle does not change handbrake stop time")
		check(absf(float(neutral_result.stop_distance_m) - float(powered_result.stop_distance_m)) <= 0.25,
			"held throttle does not change handbrake stop distance")
	check(float(powered_result.maximum_speed_mps) <= START_SPEED_MPS + 0.05,
		"handbrake suppresses propulsion before wheel-force distribution")
	check(absf(float(neutral_result.final_speed_mps) - float(powered_result.final_speed_mps)) <= 0.05,
		"neutral and throttle handbrake retain equivalent final speed")
	check(absf(float(neutral_result.mean_rear_load_n) - float(powered_result.mean_rear_load_n)) <= 100.0,
		"propulsion suppression preserves comparable rear suspension load")
	check(absf(float(neutral_result.mean_rear_slip) - float(powered_result.mean_rear_slip)) <= 0.05,
		"propulsion suppression preserves comparable rear handbrake slip")

	neutral.free()
	powered.free()
	world.free()
	print_result(results)

func print_result(results: Array[Dictionary]) -> void:
	print("NATIVE_VEHICLE_HANDBRAKE_CANDIDATE_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failure_count": failures.size(),
		"failures": failures,
		"candidate_path": CANDIDATE,
		"candidate_sha256": FileAccess.get_sha256(CANDIDATE),
		"production_sha256": FileAccess.get_sha256(PRODUCTION_BODY),
		"source_dynamics_sha256": FileAccess.get_sha256(SOURCE_DYNAMICS),
		"candidate_load": "exact candidate source with only duplicate class_name registry declaration removed in memory",
		"ticks": {"settle": SETTLE_TICKS, "measure": MEASURE_TICKS},
		"results": results,
		"qualification": "CANDIDATE ONLY: headless fixed-60 NativeVehicleBody candidate; not current a382 runtime acceptance; no factory, visual, GPU, main, LIVE, production or Git mutation",
	}))
	quit(0 if failures.is_empty() else 1)
