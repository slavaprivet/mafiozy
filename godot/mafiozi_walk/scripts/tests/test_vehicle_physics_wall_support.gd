extends SceneTree
## Isolated diagnosis for suspension rays treating a vertical wall as road support.
## Real NativeVehicleBody only: no floor, visual, GPU, main scene or LIVE authority.

const Body = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PROFILE_ID := "compact_sedan"
const FROZEN_BODY_SHA256 := "efb84ee90547ae4aa2129d83d12b6f7899503a20dfd14542f88a4f2ec2606864"
const ROLL_DEGREES := [70.0, 80.0, 90.0]
const WALL_FACE_X := 0.0
const INITIAL_CHASSIS_GAP_M := 0.12
const SAMPLE_TICKS := 12
const ROAD_NORMAL_DOT_MIN := 0.05
const LOAD_EPSILON_N := 1.0

var checks := 0
var failures: Array[String] = []

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
			return row.duplicate(true)
	return {}

func _build_wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "VerticalWallOnly"
	wall.set_meta("vehicle_surface_id", "vertical_wall")
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.20, 20.0, 40.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.position = Vector3(WALL_FACE_X + shape.size.x * 0.5, 5.0, 0.0)
	wall.add_child(collision)
	return wall

func _chassis_max_x_in_body_frame(body: RigidBody3D, basis: Basis) -> float:
	var center: Vector3 = basis * body.profile.chassis_center_local_m()
	var half: Vector3 = body.profile.chassis_half_extents_m()
	return center.x + absf(basis.x.x) * half.x + absf(basis.y.x) * half.y + absf(basis.z.x) * half.z

func _run() -> void:
	_check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd") == FROZEN_BODY_SHA256,
		"production native body remains at the frozen diagnosis SHA")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(parsed is Dictionary, "transport descriptors parse")
	if not parsed is Dictionary:
		_finish([])
		return
	var source_profile := _profile(parsed as Dictionary)
	_check(not source_profile.is_empty(), "compact sedan descriptor exists")
	if source_profile.is_empty():
		_finish([])
		return

	var world := Node3D.new()
	world.name = "WallSupportDiagnosis"
	world.add_child(_build_wall())
	root.add_child(world)
	var bodies: Array[RigidBody3D] = []
	var evidence: Array[Dictionary] = []
	for case_index in ROLL_DEGREES.size():
		var roll_degrees := float(ROLL_DEGREES[case_index])
		var descriptor := source_profile.duplicate(true)
		descriptor.vehicle_id = "wall-support-" + str(int(roll_degrees))
		descriptor.source_id = PROFILE_ID
		descriptor.life_generation = 1
		descriptor.source_clock = 1
		var body := Body.new()
		_check(body.configure(descriptor), "native body configures at roll " + str(roll_degrees))
		var basis := Basis(Vector3.BACK, deg_to_rad(roll_degrees))
		var chassis_max_x := _chassis_max_x_in_body_frame(body, basis)
		var origin_x := WALL_FACE_X - INITIAL_CHASSIS_GAP_M - chassis_max_x
		body.transform = Transform3D(basis, Vector3(origin_x, 5.0, float(case_index - 1) * 8.0))
		world.add_child(body)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		_check(body.submit_control(0.0, 0.0, 0.0, false, 1), "zero control admitted at roll " + str(roll_degrees))
		var initial_box_max_x := origin_x + chassis_max_x
		_check(initial_box_max_x <= WALL_FACE_X - INITIAL_CHASSIS_GAP_M + 0.00001,
			"chassis starts separated from wall at roll " + str(roll_degrees))
		bodies.append(body)
		evidence.append({
			"roll_degrees": roll_degrees,
			"initial_chassis_max_x_m": initial_box_max_x,
			"initial_chassis_gap_m": WALL_FACE_X - initial_box_max_x,
			"first_wall_ray_tick": -1,
			"wall_ray_hit_mask": 0,
			"observed_grounded_mask": 0,
			"false_support_mask": 0,
			"maximum_wall_ray_load_n": 0.0,
			"normal_dot_world_up_by_wheel": [null, null, null, null],
		})

	for tick in SAMPLE_TICKS:
		await physics_frame
		for case_index in bodies.size():
			var body := bodies[case_index]
			var state: Dictionary = body.snapshot_state()
			var grounded_mask := int(state.get("grounded_wheel_mask", 0))
			var loads: PackedFloat32Array = state.get("wheel_load_n", PackedFloat32Array())
			var record: Dictionary = evidence[case_index]
			var false_mask := int(record.false_support_mask)
			var wall_ray_mask := int(record.wall_ray_hit_mask)
			var dots: Array = record.normal_dot_world_up_by_wheel
			for wheel_index in 4:
				var ray := body.get_node_or_null("WheelProbe" + str(wheel_index)) as RayCast3D
				if ray == null or not ray.is_colliding():
					continue
				var normal := ray.get_collision_normal().normalized()
				var up_dot := normal.dot(Vector3.UP)
				dots[wheel_index] = up_dot
				var load_n := float(loads[wheel_index]) if wheel_index < loads.size() else 0.0
				if up_dot < ROAD_NORMAL_DOT_MIN:
					wall_ray_mask |= 1 << wheel_index
					record.maximum_wall_ray_load_n = maxf(float(record.maximum_wall_ray_load_n), load_n)
					if (grounded_mask & (1 << wheel_index)) != 0 or load_n > LOAD_EPSILON_N:
						false_mask |= 1 << wheel_index
			record.observed_grounded_mask = int(record.observed_grounded_mask) | grounded_mask
			record.false_support_mask = false_mask
			record.wall_ray_hit_mask = wall_ray_mask
			record.normal_dot_world_up_by_wheel = dots
			if int(record.first_wall_ray_tick) < 0 and wall_ray_mask != 0:
				record.first_wall_ray_tick = tick + 1
			evidence[case_index] = record

	for record: Dictionary in evidence:
		var label := "roll " + str(record.roll_degrees)
		_check(int(record.wall_ray_hit_mask) != 0, label + " fixture retains actual vertical-wall ray hits")
		_check(int(record.first_wall_ray_tick) > 0, label + " wall ray hit occurs in bounded fixed ticks")
		_check(int(record.observed_grounded_mask) == 0, label + " wall rays are not admitted as grounded")
		_check(int(record.false_support_mask) == 0 and float(record.maximum_wall_ray_load_n) <= LOAD_EPSILON_N,
			label + " rejected wall normals carry no suspension load")

	for body: RigidBody3D in bodies:
		body.free()
	world.free()
	_finish(evidence)

func _finish(evidence: Array[Dictionary]) -> void:
	print("NATIVE_VEHICLE_WALL_SUPPORT_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"body_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"sample_ticks": SAMPLE_TICKS,
		"road_normal_dot_min": ROAD_NORMAL_DOT_MIN,
		"cases": evidence,
		"diagnosis": "vertical-wall ray hits remain observable but are rejected from grounded suspension support",
		"qualification": "isolated real NativeVehicleBody, vertical wall only, zero control, headless fixed-step; no floor, visual, GPU, production mutation, inferred fix or LIVE authority",
	}))
	quit(0 if failures.is_empty() else 1)
