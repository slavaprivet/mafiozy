extends SceneTree
## Candidate-only braking regression. It compiles exact candidate bytes after
## removing only the duplicate global class_name declaration in memory.

const CANDIDATE := "res://../../outputs/vehicle_native_body_candidate_braking.gd"
const CANDIDATE_SHA256 := "ae4d67e7f931e33e3cf65404af665579498986cb307418a45989dba5e0dfe5d5"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const PREVIOUS_CANDIDATE := "res://../../outputs/vehicle_native_body_candidate_handbrake.gd"
const PREVIOUS_CANDIDATE_SHA256 := "67da32426d7b503eee0f92294f7e57c0406a857a17ee1f6e91a2eabf34cc4c0d"
const SOURCE_DYNAMICS := "res://../../assets/maps/city_rebuild_v1/vehicle_dynamics.mjs"
const SOURCE_DYNAMICS_SHA256 := "105cce8bf2cac63136e1c5e48f38465c4bf8e448a271702136b7c014e3396faf"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PROFILE_ID := "compact_sedan"
const START_SPEED_MPS := 10.0
const STOP_SPEED_MPS := 0.25
const STOP_HOLD_TICKS := 30
const SETTLE_TICKS := 180
const MEASURE_TICKS := 360
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
	floor.set_meta("vehicle_surface_id", "dry_asphalt")
	var shape := BoxShape3D.new()
	shape.size = Vector3(160.0, 0.5, 1000.0)
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

func signed_forward_speed(body: RigidBody3D) -> float:
	return body.linear_velocity.dot(-body.global_basis.z.normalized())

func planar_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()

func run() -> void:
	check(FileAccess.get_sha256(CANDIDATE) == CANDIDATE_SHA256, "exact braking candidate receipt")
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256, "frozen production body remains untouched")
	check(FileAccess.get_sha256(PREVIOUS_CANDIDATE) == PREVIOUS_CANDIDATE_SHA256, "previous candidate remains untouched")
	check(FileAccess.get_sha256(SOURCE_DYNAMICS) == SOURCE_DYNAMICS_SHA256, "exact source dynamics receipt")
	var source := FileAccess.get_file_as_string(SOURCE_DYNAMICS)
	check(source.contains("serviceDeceleration:11") and source.contains("handbrakeDeceleration:12"),
		"source service and handbrake deceleration constants remain exact")
	check(source.contains("braking=handbrake||!!(pedal&&speed*pedal<0);"),
		"source opposite-pedal braking predicate remains exact")
	Body = load_candidate_without_duplicate_global_name()
	check(Body != null, "candidate compiles after stripping only class_name")
	if Body == null:
		print_result({})
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary, "transport descriptors parse")
	if not parsed is Dictionary:
		print_result({})
		return
	var rows: Array = (parsed as Dictionary).get("profiles", [])
	var ids := ["opposite-pedal", "service-brake", "neutral-handbrake", "throttle-handbrake"]
	var descriptors: Array[Dictionary] = []
	for id: String in ids:
		descriptors.append(descriptor_for(rows, id))
	check(descriptors.all(func(row: Dictionary): return not row.is_empty()), "four compact sedan descriptors available")

	var world := Node3D.new()
	root.add_child(world)
	add_floor(world)
	var opposite = add_candidate(world, descriptors[0], Vector3(-30.0, 1.15, 200.0))
	var service = add_candidate(world, descriptors[1], Vector3(-10.0, 1.15, 200.0))
	var handbrake_neutral = add_candidate(world, descriptors[2], Vector3(10.0, 1.15, 200.0))
	var handbrake_throttle = add_candidate(world, descriptors[3], Vector3(30.0, 1.15, 200.0))
	var bodies := [opposite, service, handbrake_neutral, handbrake_throttle]
	check(bodies.all(func(body): return body != null), "candidate comparison bodies configure")
	if bodies.any(func(body): return body == null):
		world.free()
		print_result({})
		return

	for _tick in SETTLE_TICKS:
		await physics_frame
	for body: RigidBody3D in bodies:
		check(int(body.snapshot_state().grounded_wheel_mask) == 0b1111, "%s settles on four probes" % body.get_meta("vehicle_id"))
		body.linear_velocity = Vector3(0.0, 0.0, -START_SPEED_MPS)
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

	var starts := [opposite.global_position, service.global_position,
		handbrake_neutral.global_position, handbrake_throttle.global_position]
	check(opposite.submit_control(-1.0, 0.0, 0.0, false, 1), "opposite pedal control admitted")
	check(service.submit_control(0.0, 0.0, 1.0, false, 1), "explicit service brake control admitted")
	check(handbrake_neutral.submit_control(0.0, 0.0, 0.0, true, 1), "neutral handbrake control admitted")
	check(handbrake_throttle.submit_control(1.0, 0.0, 0.0, true, 1), "throttle handbrake control admitted")

	var opposite_stop_tick := -1
	var service_stop_tick := -1
	var opposite_stop_distance := -1.0
	var service_stop_distance := -1.0
	var reverse_transition_tick := -1
	var braking_max_speed_delta := 0.0
	var braking_max_position_delta := 0.0
	var handbrake_neutral_below := 0
	var handbrake_throttle_below := 0
	var handbrake_neutral_stop_tick := -1
	var handbrake_throttle_stop_tick := -1
	var handbrake_neutral_stop_distance := -1.0
	var handbrake_throttle_stop_distance := -1.0
	var handbrake_max_speed_delta := 0.0
	var handbrake_max_position_delta := 0.0
	var handbrake_peak_speed := START_SPEED_MPS
	for tick in MEASURE_TICKS:
		await physics_frame
		var opposite_speed := signed_forward_speed(opposite)
		var service_speed := signed_forward_speed(service)
		if opposite_stop_tick < 0 and service_stop_tick < 0:
			braking_max_speed_delta = maxf(braking_max_speed_delta, absf(opposite_speed - service_speed))
			braking_max_position_delta = maxf(braking_max_position_delta,
				absf(planar_distance(starts[0], opposite.global_position) - planar_distance(starts[1], service.global_position)))
		if opposite_stop_tick < 0 and opposite_speed <= STOP_SPEED_MPS:
			opposite_stop_tick = tick + 1
			opposite_stop_distance = planar_distance(starts[0], opposite.global_position)
		if service_stop_tick < 0 and service_speed <= STOP_SPEED_MPS:
			service_stop_tick = tick + 1
			service_stop_distance = planar_distance(starts[1], service.global_position)
		if opposite_stop_tick >= 0 and reverse_transition_tick < 0 and opposite_speed <= -0.5:
			reverse_transition_tick = tick + 1

		var neutral_speed := absf(signed_forward_speed(handbrake_neutral))
		var throttle_speed := absf(signed_forward_speed(handbrake_throttle))
		handbrake_peak_speed = maxf(handbrake_peak_speed, throttle_speed)
		handbrake_max_speed_delta = maxf(handbrake_max_speed_delta, absf(neutral_speed - throttle_speed))
		handbrake_max_position_delta = maxf(handbrake_max_position_delta,
			absf(planar_distance(starts[2], handbrake_neutral.global_position) - planar_distance(starts[3], handbrake_throttle.global_position)))
		if handbrake_neutral_stop_tick < 0:
			handbrake_neutral_below = handbrake_neutral_below + 1 if neutral_speed <= STOP_SPEED_MPS else 0
			if handbrake_neutral_below >= STOP_HOLD_TICKS:
				handbrake_neutral_stop_tick = tick + 2 - STOP_HOLD_TICKS
				handbrake_neutral_stop_distance = planar_distance(starts[2], handbrake_neutral.global_position)
		if handbrake_throttle_stop_tick < 0:
			handbrake_throttle_below = handbrake_throttle_below + 1 if throttle_speed <= STOP_SPEED_MPS else 0
			if handbrake_throttle_below >= STOP_HOLD_TICKS:
				handbrake_throttle_stop_tick = tick + 2 - STOP_HOLD_TICKS
				handbrake_throttle_stop_distance = planar_distance(starts[3], handbrake_throttle.global_position)

	var metrics := {
		"opposite_stop_time_s": float(opposite_stop_tick) / FIXED_TICKS_PER_SECOND if opposite_stop_tick >= 0 else null,
		"service_stop_time_s": float(service_stop_tick) / FIXED_TICKS_PER_SECOND if service_stop_tick >= 0 else null,
		"opposite_stop_distance_m": opposite_stop_distance if opposite_stop_tick >= 0 else null,
		"service_stop_distance_m": service_stop_distance if service_stop_tick >= 0 else null,
		"braking_max_speed_delta_mps": braking_max_speed_delta,
		"braking_max_position_delta_m": braking_max_position_delta,
		"reverse_transition_time_s": float(reverse_transition_tick) / FIXED_TICKS_PER_SECOND if reverse_transition_tick >= 0 else null,
		"opposite_final_signed_speed_mps": signed_forward_speed(opposite),
		"service_final_signed_speed_mps": signed_forward_speed(service),
		"handbrake_neutral_stop_time_s": float(handbrake_neutral_stop_tick) / FIXED_TICKS_PER_SECOND if handbrake_neutral_stop_tick >= 0 else null,
		"handbrake_throttle_stop_time_s": float(handbrake_throttle_stop_tick) / FIXED_TICKS_PER_SECOND if handbrake_throttle_stop_tick >= 0 else null,
		"handbrake_neutral_stop_distance_m": handbrake_neutral_stop_distance if handbrake_neutral_stop_tick >= 0 else null,
		"handbrake_throttle_stop_distance_m": handbrake_throttle_stop_distance if handbrake_throttle_stop_tick >= 0 else null,
		"handbrake_max_speed_delta_mps": handbrake_max_speed_delta,
		"handbrake_max_position_delta_m": handbrake_max_position_delta,
		"handbrake_peak_speed_mps": handbrake_peak_speed,
	}
	check(opposite_stop_tick >= 0 and service_stop_tick >= 0, "opposite pedal and service brake both reach transition band")
	if opposite_stop_tick >= 0 and service_stop_tick >= 0:
		check(absi(opposite_stop_tick - service_stop_tick) <= 1, "opposite pedal matches explicit service brake stop time")
		check(absf(opposite_stop_distance - service_stop_distance) <= 0.10, "opposite pedal matches explicit service brake stop distance")
	check(braking_max_speed_delta <= 0.10 and braking_max_position_delta <= 0.10,
		"opposite pedal follows explicit service brake trajectory before transition")
	check(reverse_transition_tick >= 0 and reverse_transition_tick - opposite_stop_tick <= 120,
		"opposite pedal transitions to reverse drive within two seconds of near-zero")
	check(absf(signed_forward_speed(service)) <= 0.10, "explicit service brake remains stopped")
	check(handbrake_neutral_stop_tick >= 0 and handbrake_neutral_stop_tick <= 4 * FIXED_TICKS_PER_SECOND,
		"neutral handbrake stops from 10 mps within four seconds")
	check(handbrake_throttle_stop_tick >= 0 and handbrake_throttle_stop_tick <= 4 * FIXED_TICKS_PER_SECOND,
		"throttle handbrake stops from 10 mps within four seconds")
	if handbrake_neutral_stop_tick >= 0 and handbrake_throttle_stop_tick >= 0:
		check(absi(handbrake_neutral_stop_tick - handbrake_throttle_stop_tick) <= 1,
			"held throttle does not change handbrake stop time")
		check(absf(handbrake_neutral_stop_distance - handbrake_throttle_stop_distance) <= 0.10,
			"held throttle does not change handbrake stop distance")
	check(handbrake_max_speed_delta <= 0.05 and handbrake_max_position_delta <= 0.05,
		"neutral and throttle handbrake trajectories match")
	check(handbrake_peak_speed <= START_SPEED_MPS + 0.05, "handbrake suppresses propulsion")

	for body: RigidBody3D in bodies:
		body.free()
	world.free()
	print_result(metrics)

func print_result(metrics: Dictionary) -> void:
	print("NATIVE_VEHICLE_BRAKING_CANDIDATE_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failure_count": failures.size(),
		"failures": failures,
		"candidate_sha256": FileAccess.get_sha256(CANDIDATE),
		"production_sha256": FileAccess.get_sha256(PRODUCTION_BODY),
		"previous_candidate_sha256": FileAccess.get_sha256(PREVIOUS_CANDIDATE),
		"source_dynamics_sha256": FileAccess.get_sha256(SOURCE_DYNAMICS),
		"limits": {
			"opposite_service_stop_tick_delta_max": 1,
			"opposite_service_distance_delta_m_max": 0.10,
			"opposite_service_trajectory_delta_max": 0.10,
			"opposite_reverse_transition_ticks_max": 120,
			"handbrake_stop_time_s_max": 4.0,
			"handbrake_match_delta_max": 0.05,
		},
		"metrics": metrics,
		"qualification": "CANDIDATE ONLY: fixed-60 headless native body, exact source receipts, no factory, visual, GPU, main, LIVE, production or Git mutation",
	}))
	quit(0 if failures.is_empty() else 1)
