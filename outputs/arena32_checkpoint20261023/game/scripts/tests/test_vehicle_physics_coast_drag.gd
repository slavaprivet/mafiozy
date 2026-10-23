extends SceneTree

const CANDIDATE := "res://../../outputs/vehicle_native_body_candidate_873976.gd"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const SOURCE_COAST_DECEL_MPS2 := 0.75
const SOURCE_AERO_DECEL_PER_SPEED_SQUARED := 0.012
const SOURCE_SUBSTEP_SECONDS := 1.0 / 120.0
const FIXED_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 180
const DRIVE_TICKS := 600

var checks := 0
var failures: Array[String] = []
var Body: GDScript

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func source_coast_speed(initial_speed_mps: float, seconds: float) -> float:
	var speed := initial_speed_mps
	var steps := int(round(seconds / SOURCE_SUBSTEP_SECONDS))
	for _step in steps:
		var deceleration := SOURCE_COAST_DECEL_MPS2 + SOURCE_AERO_DECEL_PER_SPEED_SQUARED * speed * speed
		speed = maxf(0.0, speed - deceleration * SOURCE_SUBSTEP_SECONDS)
	return speed

func descriptor_for(rows: Array, profile_id: String, vehicle_id: String) -> Dictionary:
	for candidate: Dictionary in rows:
		if str(candidate.get("profile_id", "")) != profile_id:
			continue
		var descriptor := candidate.duplicate(true)
		descriptor.vehicle_id = vehicle_id
		descriptor.source_id = profile_id
		descriptor.life_generation = 1
		descriptor.source_clock = 1
		return descriptor
	return {}

func add_floor(world: Node3D) -> void:
	var floor := StaticBody3D.new()
	floor.name = "CoastDragAuditFloor"
	floor.set_meta("vehicle_surface_id", "dry_asphalt")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 0.2, 900.0)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.1, 0.0)
	floor.add_child(collision)
	world.add_child(floor)

func add_ground_vehicle(world: Node3D, descriptor: Dictionary, position: Vector3):
	var body: RigidBody3D = Body.new()
	if not body.configure(descriptor):
		return null
	body.position = position
	world.add_child(body)
	return body

func horizontal_speed(body: RigidBody3D) -> float:
	return Vector2(body.linear_velocity.x, body.linear_velocity.z).length()

func load_candidate_without_duplicate_global_name() -> GDScript:
	# The candidate is intentionally outside res:// and retains production's
	# class_name. Loading both registrations in one project is a Godot compile
	# error, so remove only that registry declaration from the in-memory copy.
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

func run() -> void:
	Body = load_candidate_without_duplicate_global_name()
	check(Body != null, "candidate source compiles after removing only duplicate global registry declaration")
	if Body == null:
		print_result({})
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary, "transport descriptors parse")
	if not (parsed is Dictionary):
		print_result({})
		return
	var rows: Array = parsed.get("profiles", [])
	var world := Node3D.new()
	root.add_child(world)
	add_floor(world)

	var hatch_descriptor := descriptor_for(rows, "city_hatchback", "coast-audit-hatch")
	var compact_descriptor := descriptor_for(rows, "compact_sedan", "coast-audit-compact")
	var brake_descriptor := descriptor_for(rows, "city_hatchback", "coast-audit-brake")
	var coast_descriptor := descriptor_for(rows, "city_hatchback", "coast-audit-road")
	var airborne_descriptor := descriptor_for(rows, "city_hatchback", "coast-audit-airborne")
	check(not hatch_descriptor.is_empty() and not compact_descriptor.is_empty(), "actual source profiles available")

	var hatch = add_ground_vehicle(world, hatch_descriptor, Vector3(-18.0, 1.15, 350.0))
	var compact = add_ground_vehicle(world, compact_descriptor, Vector3(-6.0, 1.15, 350.0))
	var coast = add_ground_vehicle(world, coast_descriptor, Vector3(6.0, 1.15, 350.0))
	var brake = add_ground_vehicle(world, brake_descriptor, Vector3(18.0, 1.15, 350.0))
	check(hatch != null and compact != null and coast != null and brake != null, "ground scenarios configure")
	if hatch == null or compact == null or coast == null or brake == null:
		print_result({})
		return

	for _tick in SETTLE_TICKS:
		await physics_frame
	for body in [hatch, compact, coast, brake]:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

	check(int(hatch.snapshot_state().grounded_wheel_mask) == 0b1111, "hatch settles on four probes")
	check(int(compact.snapshot_state().grounded_wheel_mask) == 0b1111, "compact settles on four probes")
	check(int(coast.snapshot_state().grounded_wheel_mask) == 0b1111, "road coast fixture settles on four probes")
	check(int(brake.snapshot_state().grounded_wheel_mask) == 0b1111, "brake fixture settles on four probes")
	check(hatch.submit_control(1.0, 0.0, 0.0, false, 1), "hatch throttle accepted")
	check(compact.submit_control(1.0, 0.0, 0.0, false, 1), "compact throttle accepted")
	coast.linear_velocity = Vector3(0.0, 0.0, -10.0)
	check(coast.submit_control(0.0, 0.0, 0.0, false, 1), "zero-pedal road coast accepted")
	brake.linear_velocity = -brake.global_basis.z.normalized() * 10.0
	check(brake.submit_control(0.0, 0.0, 1.0, false, 1), "service brake accepted separately from coast")

	var airborne: RigidBody3D = Body.new()
	check(airborne.configure(airborne_descriptor), "airborne coast fixture configures")
	airborne.gravity_scale = 0.0
	airborne.position = Vector3(36.0, 80.0, 350.0)
	world.add_child(airborne)
	await physics_frame
	airborne.linear_velocity = Vector3(0.0, 3.0, -10.0)
	airborne.angular_velocity = Vector3.ZERO
	check(airborne.submit_control(0.0, 0.0, 0.0, false, 1), "zero-pedal airborne control accepted")

	var road_coast_speed_after_one_second := NAN
	var airborne_horizontal_after_one_second := NAN
	var coast_vertical_after_one_second := NAN
	var brake_speed_after_one_second := NAN
	for tick in DRIVE_TICKS:
		await physics_frame
		if tick + 1 == FIXED_TICKS_PER_SECOND:
			road_coast_speed_after_one_second = horizontal_speed(coast)
			airborne_horizontal_after_one_second = horizontal_speed(airborne)
			coast_vertical_after_one_second = airborne.linear_velocity.y
			brake_speed_after_one_second = horizontal_speed(brake)

	var hatch_speed := horizontal_speed(hatch)
	var compact_speed := horizontal_speed(compact)
	var hatch_cap := float(hatch_descriptor.max_forward_speed_mps)
	var compact_cap := float(compact_descriptor.max_forward_speed_mps)
	var expected_coast_speed := source_coast_speed(10.0, 1.0)
	check(is_finite(hatch_speed) and hatch_speed >= hatch_cap * 0.95 and hatch_speed <= hatch_cap + 1.0,
		"hatch reaches source cap after 10s actual=" + str(hatch_speed) + " cap=" + str(hatch_cap))
	check(is_finite(compact_speed) and compact_speed >= compact_cap * 0.95 and compact_speed <= compact_cap + 1.0,
		"compact reaches source cap after 10s actual=" + str(compact_speed) + " cap=" + str(compact_cap))
	check(int(hatch.snapshot_state().grounded_wheel_mask) == 0b1111 and int(compact.snapshot_state().grounded_wheel_mask) == 0b1111,
		"driven profiles remain four-probe grounded")
	check(int(airborne.snapshot_state().grounded_wheel_mask) == 0, "coast oracle remains isolated from ground")
	check(is_finite(road_coast_speed_after_one_second) and absf(road_coast_speed_after_one_second - expected_coast_speed) <= 0.04,
		"supported road coast matches source constant-plus-aero deceleration actual=" + str(road_coast_speed_after_one_second) + " expected=" + str(expected_coast_speed))
	check(is_finite(airborne_horizontal_after_one_second) and absf(airborne_horizontal_after_one_second - 10.0) <= 0.01,
		"road rolling rule does not damp airborne horizontal velocity actual=" + str(airborne_horizontal_after_one_second))
	check(is_finite(coast_vertical_after_one_second) and absf(coast_vertical_after_one_second - 3.0) <= 0.01,
		"road rolling rule does not damp airborne vertical velocity actual=" + str(coast_vertical_after_one_second))
	check(is_finite(brake_speed_after_one_second) and brake_speed_after_one_second < expected_coast_speed - 1.0,
		"service brake remains stronger than coast and uses its separate input path actual=" + str(brake_speed_after_one_second))

	print_result({"qualification":"CANDIDATE ONLY: headless fixed-60 candidate NativeVehicleBody; not current a382 runtime acceptance; no visual, GPU, main, or LIVE authority",
		"candidate_path":CANDIDATE, "candidate_sha256":FileAccess.get_sha256(CANDIDATE),
		"candidate_load":"exact candidate source with only duplicate class_name registry declaration removed in memory",
		"authority_boundary":"engine-disabled coast branch unavailable through current public control API",
		"ticks":{"settle":SETTLE_TICKS, "drive":DRIVE_TICKS},
		"full_throttle_10s_mps":{"city_hatchback":hatch_speed, "compact_sedan":compact_speed},
		"source_caps_mps":{"city_hatchback":hatch_cap, "compact_sedan":compact_cap},
		"road_coast_1s_mps":{"actual":road_coast_speed_after_one_second, "expected":expected_coast_speed},
		"airborne_horizontal_1s_mps":airborne_horizontal_after_one_second,
		"airborne_vertical_1s_mps":coast_vertical_after_one_second,
		"service_brake_1s_mps":brake_speed_after_one_second})
	world.free()

func print_result(receipt: Dictionary) -> void:
	print("NATIVE_VEHICLE_COAST_DRAG_CANDIDATE_TEST ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failure_count":failures.size(), "failures":failures, "receipt":receipt}))
	quit(0 if failures.is_empty() else 1)
