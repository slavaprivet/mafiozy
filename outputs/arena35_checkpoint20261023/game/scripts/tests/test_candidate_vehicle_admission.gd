extends SceneTree
## Candidate-only bounded physics admission. The current production body is never loaded or modified.

const CANDIDATE := "res://../../outputs/vehicle_native_body_candidate_braking.gd"
const CANDIDATE_SHA256 := "ae4d67e7f931e33e3cf65404af665579498986cb307418a45989dba5e0dfe5d5"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const EXPECTED_PROFILES := 12
const SETTLE_MIN_TICKS := 180
const SETTLE_MAX_TICKS := 600
const STABLE_TICKS := 60

var CandidateBody: GDScript
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func load_exact_candidate() -> GDScript:
	if FileAccess.get_sha256(CANDIDATE) != CANDIDATE_SHA256:
		return null
	var source := FileAccess.get_file_as_string(CANDIDATE)
	# The artifact retains production's global class_name. Remove only that
	# registry declaration in memory so both scripts are not registered together.
	if source.begins_with("class_name NativeVehicleBody\r\n"):
		source = source.trim_prefix("class_name NativeVehicleBody\r\n")
	elif source.begins_with("class_name NativeVehicleBody\n"):
		source = source.trim_prefix("class_name NativeVehicleBody\n")
	else:
		return null
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return null
	return script

func profile_row(rows: Array, profile_id: String) -> Dictionary:
	for value: Variant in rows:
		if value is Dictionary and str(value.get("profile_id", "")) == profile_id:
			return (value as Dictionary).duplicate(true)
	return {}

func admitted_descriptor(row: Dictionary, vehicle_id: String, generation := 1, clock := 1) -> Dictionary:
	var descriptor := row.duplicate(true)
	descriptor.vehicle_id = vehicle_id
	descriptor.source_id = str(row.get("profile_id", ""))
	descriptor.life_generation = generation
	descriptor.source_clock = clock
	return descriptor

func new_body(descriptor: Dictionary) -> RigidBody3D:
	var body: RigidBody3D = CandidateBody.new()
	if not body.configure(descriptor):
		body.free()
		return null
	return body

func make_floor(size := Vector3(90.0, 0.5, 90.0), surface_id := "candidate_floor") -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.set_meta("vehicle_surface_id", surface_id)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = Vector3(0.0, -size.y * 0.5, 0.0)
	floor.add_child(collision)
	return floor

func ray_count(body: Node) -> int:
	var count := 0
	for child: Node in body.get_children():
		if child is RayCast3D:
			count += 1
	return count

func tilt_rad(body: Node3D) -> float:
	var up := body.global_basis.y
	if not up.is_finite() or up.length_squared() < 0.000001:
		return INF
	return acos(clampf(up.normalized().dot(Vector3.UP), -1.0, 1.0))

func collider_base_world_y(body: Node3D) -> float:
	var minimum := INF
	for child: Node in body.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or not collision.shape is BoxShape3D:
			continue
		var half := (collision.shape as BoxShape3D).size * 0.5
		for corner in 8:
			var local := Vector3(half.x if (corner & 1) != 0 else -half.x,
				half.y if (corner & 2) != 0 else -half.y,
				half.z if (corner & 4) != 0 else -half.z)
			minimum = minf(minimum, (collision.global_transform * local).y)
	return minimum

func finite_state(body: RigidBody3D, state: Dictionary) -> bool:
	if not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite():
		return false
	for key: String in ["wheel_load_n", "wheel_slip", "wheel_longitudinal_mps"]:
		var values: Variant = state.get(key)
		if not values is PackedFloat32Array:
			return false
		for value: float in values:
			if not is_finite(value):
				return false
	return true

func history_jitter(points: Array) -> float:
	if points.size() < STABLE_TICKS:
		return INF
	var result := 0.0
	for index in range(1, points.size()):
		result = maxf(result, (points[index - 1] as Vector3).distance_to(points[index] as Vector3))
	return result

func run() -> void:
	check(FileAccess.get_sha256(CANDIDATE) == CANDIDATE_SHA256, "stable candidate receipt")
	CandidateBody = load_exact_candidate()
	check(CandidateBody != null, "exact candidate compiles after duplicate class registry removal")
	if CandidateBody == null:
		finish({})
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary, "descriptor document parses")
	if not parsed is Dictionary:
		finish({})
		return
	var document := parsed as Dictionary
	var rows: Variant = document.get("profiles")
	check(document.get("schema") == "mafiozi.transport.descriptors.v1", "descriptor schema")
	check(rows is Array and rows.size() == EXPECTED_PROFILES, "all twelve profiles admitted for review")
	if not rows is Array or rows.size() != EXPECTED_PROFILES:
		finish({})
		return
	var profiles := rows as Array
	var hatch := profile_row(profiles, "city_hatchback")
	var compact := profile_row(profiles, "compact_sedan")
	check(not hatch.is_empty() and not compact.is_empty(), "representative descriptors available")

	var static_receipt := test_static_admission_and_lifetime(compact)
	var impulse_receipt := await test_airborne_impulse_conservation(hatch)
	var wall_receipt := await test_vertical_wall_rejection(compact)
	var tangent_receipt := await test_supported_normal_tangent(compact)
	var steering_receipt := await test_signed_steering(hatch)
	var settle_receipt := await test_all_profile_equilibrium(profiles)
	finish({"static_admission":static_receipt, "airborne_impulse":impulse_receipt,
		"vertical_wall":wall_receipt, "supported_tangent":tangent_receipt,
		"signed_steering":steering_receipt, "all_profile_equilibrium":settle_receipt})

func test_static_admission_and_lifetime(row: Dictionary) -> Dictionary:
	var f30: int = CandidateBody.force_substeps(1.0 / 30.0)
	var f60: int = CandidateBody.force_substeps(1.0 / 60.0)
	var f120: int = CandidateBody.force_substeps(1.0 / 120.0)
	var fslow: int = CandidateBody.force_substeps(0.2)
	check(f30 == 4 and f60 == 2 and f120 == 1 and fslow == 12, "exact bounded 120Hz force partition")
	check(CandidateBody.force_substeps(NAN) == 0 and CandidateBody.force_substeps(0.0) == 0,
		"invalid force step fails closed")
	var body := new_body(admitted_descriptor(row, "candidate-life", 1, 100))
	check(body != null, "candidate profile admission")
	if body == null:
		return {}
	check(body.submit_authoritative_control(0.8, 0.5, 0.0, true, 7, "candidate-life", 1, 100),
		"matching lifetime control accepted")
	var next_life := admitted_descriptor(row, "candidate-life", 2, 200)
	check(body.configure(next_life), "next lifetime configures")
	var reset: Dictionary = body.snapshot_state()
	check(int(reset.control_sequence) == -1 and int(reset.control_source_clock) == -1,
		"lifetime transition resets accepted control state")
	check(not body.submit_authoritative_control(1.0, 0.0, 0.0, false, 8, "candidate-life", 1, 201),
		"stale generation control rejected")
	check(not body.submit_authoritative_control(1.0, 0.0, 0.0, false, 8, "candidate-life", 2, 199),
		"stale source clock rejected")
	check(body.submit_authoritative_control(-1.0, -1.0, 0.0, false, 1, "candidate-life", 2, 200),
		"new lifetime sequence restarts from one")
	var malformed := next_life.duplicate(true)
	malformed.mass_kg = NAN
	var invalid: RigidBody3D = CandidateBody.new()
	check(not invalid.configure(malformed), "nonfinite admission fails closed")
	invalid.free()
	body.free()
	return {"force_substeps":[f30, f60, f120, fslow], "reset_sequence":reset.control_sequence}

func test_airborne_impulse_conservation(row: Dictionary) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var body := new_body(admitted_descriptor(row, "candidate-airborne"))
	check(body != null, "airborne body configures")
	if body == null:
		world.free()
		return {}
	body.gravity_scale = 0.0
	body.position = Vector3(0.0, 30.0, 0.0)
	world.add_child(body)
	await physics_frame
	var before := Vector3(1.0, 2.0, 3.0)
	body.linear_velocity = before
	body.angular_velocity = Vector3.ZERO
	var impulse := Vector3(body.mass * 0.25, body.mass * -0.5, body.mass * 1.0)
	body.apply_central_impulse(impulse)
	await physics_frame
	var after := body.linear_velocity
	var expected := before + impulse / body.mass
	var momentum_error := (body.mass * (after - before) - impulse).length()
	var state: Dictionary = body.snapshot_state()
	check(int(state.grounded_wheel_mask) == 0, "airborne impulse fixture has no support")
	check(after.distance_to(expected) <= 0.0001 and momentum_error <= 0.1,
		"no-floor central impulse conserves linear momentum")
	check(absf(after.y - expected.y) <= 0.0001, "no-floor integration preserves vertical impulse")
	world.free()
	return {"before_mps":before, "impulse_ns":impulse, "after_mps":after,
		"expected_mps":expected, "momentum_error_ns":momentum_error}

func make_wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.set_meta("vehicle_surface_id", "candidate_vertical_wall")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 20.0, 30.0)
	collision.shape = shape
	wall.position = Vector3(0.1, 5.0, 0.0)
	wall.add_child(collision)
	return wall

func chassis_max_x(body: RigidBody3D, basis: Basis) -> float:
	var center: Vector3 = basis * body.profile.chassis_center_local_m()
	var half: Vector3 = body.profile.chassis_half_extents_m()
	return center.x + absf(basis.x.x) * half.x + absf(basis.y.x) * half.y + absf(basis.z.x) * half.z

func test_vertical_wall_rejection(row: Dictionary) -> Dictionary:
	var world := Node3D.new()
	world.add_child(make_wall())
	root.add_child(world)
	var body := new_body(admitted_descriptor(row, "candidate-wall"))
	check(body != null, "wall body configures")
	if body == null:
		world.free()
		return {}
	var basis := Basis(Vector3.BACK, deg_to_rad(80.0))
	var origin_x := -0.12 - chassis_max_x(body, basis)
	body.transform = Transform3D(basis, Vector3(origin_x, 5.0, 0.0))
	world.add_child(body)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.submit_control(0.0, 0.0, 0.0, false, 1)
	var raw_wall_mask := 0
	var grounded_mask := 0
	var false_support_mask := 0
	var maximum_rejected_load := 0.0
	for _tick in 12:
		await physics_frame
		var state: Dictionary = body.snapshot_state()
		grounded_mask |= int(state.grounded_wheel_mask)
		var loads: PackedFloat32Array = state.wheel_load_n
		for wheel_index in 4:
			var ray := body.get_node_or_null("WheelProbe" + str(wheel_index)) as RayCast3D
			if ray == null or not ray.is_colliding():
				continue
			var normal := ray.get_collision_normal().normalized()
			if normal.dot(Vector3.UP) <= 0.05:
				raw_wall_mask |= 1 << wheel_index
				maximum_rejected_load = maxf(maximum_rejected_load, float(loads[wheel_index]))
				if (int(state.grounded_wheel_mask) & (1 << wheel_index)) != 0 or loads[wheel_index] > 1.0:
					false_support_mask |= 1 << wheel_index
	check(raw_wall_mask != 0, "vertical wall remains visible to raw wheel probes")
	check(grounded_mask == 0 and false_support_mask == 0 and maximum_rejected_load <= 1.0,
		"vertical normals are rejected from suspension support")
	world.free()
	return {"raw_wall_mask":raw_wall_mask, "grounded_mask":grounded_mask,
		"false_support_mask":false_support_mask, "maximum_rejected_load_n":maximum_rejected_load}

func test_supported_normal_tangent(row: Dictionary) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var slope := make_floor(Vector3(50.0, 0.5, 70.0), "candidate_slope")
	var slope_basis := Basis(Vector3.RIGHT, deg_to_rad(10.0))
	slope.transform = Transform3D(slope_basis, Vector3.ZERO)
	world.add_child(slope)
	var body := new_body(admitted_descriptor(row, "candidate-tangent"))
	check(body != null, "slope tangent body configures")
	if body == null:
		world.free()
		return {}
	body.transform = Transform3D(slope_basis, slope_basis * Vector3(0.0, 0.75, 0.0))
	world.add_child(body)
	body.submit_control(0.0, 0.0, 1.0, false, 1)
	for _tick in 180:
		await physics_frame
	check(int(body.snapshot_state().grounded_wheel_mask) == 15, "sloped support admits four road normals")
	body.gravity_scale = 0.0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.clear_control(2)
	await physics_frame
	var reference_ray := body.get_node("WheelProbe0") as RayCast3D
	var reference_normal := reference_ray.get_collision_normal().normalized()
	var reference_forward := -body.global_basis.z.normalized()
	var reference_tangent := (reference_forward - reference_normal * reference_forward.dot(reference_normal)).normalized()
	body.linear_velocity = reference_tangent * 4.0
	await physics_frame
	var state: Dictionary = body.snapshot_state()
	var maximum_normal_dot := 0.0
	var maximum_longitudinal_error := 0.0
	var valid_tangents := 0
	for wheel_index in 4:
		var ray := body.get_node("WheelProbe" + str(wheel_index)) as RayCast3D
		if not ray.is_colliding():
			continue
		var normal := ray.get_collision_normal().normalized()
		var steered_forward := -body.global_basis.z.normalized()
		var tangent := steered_forward - normal * steered_forward.dot(normal)
		if not tangent.is_finite() or tangent.length_squared() < 0.000001:
			continue
		tangent = tangent.normalized()
		maximum_normal_dot = maxf(maximum_normal_dot, absf(tangent.dot(normal)))
		maximum_longitudinal_error = maxf(maximum_longitudinal_error,
			absf(float(state.wheel_longitudinal_mps[wheel_index]) - body.linear_velocity.dot(tangent)))
		valid_tangents += 1
	check(valid_tangents == 4 and maximum_normal_dot <= 0.00001,
		"wheel forward axes are finite tangents of accepted support normals")
	check(maximum_longitudinal_error <= 0.05, "reported wheel longitudinal speed follows support tangent")
	world.free()
	return {"valid_tangents":valid_tangents, "maximum_normal_dot":maximum_normal_dot,
		"maximum_longitudinal_error_mps":maximum_longitudinal_error}

func test_signed_steering(row: Dictionary) -> Dictionary:
	var world := Node3D.new()
	world.add_child(make_floor(Vector3(70.0, 0.5, 90.0), "candidate_steering_floor"))
	root.add_child(world)
	var bodies: Array[RigidBody3D] = []
	var starts: Array[Vector3] = []
	for index in 2:
		var steer := 1.0 if index == 0 else -1.0
		var body := new_body(admitted_descriptor(row, "candidate-steer-" + str(index)))
		check(body != null, "signed steering body configures " + str(steer))
		if body == null:
			continue
		body.position = Vector3(-8.0 if index == 0 else 8.0, 0.75, 25.0)
		world.add_child(body)
		bodies.append(body)
	for _tick in 180:
		await physics_frame
	for index in bodies.size():
		var body := bodies[index]
		body.linear_velocity = -body.global_basis.z.normalized() * 5.0
		body.angular_velocity = Vector3.ZERO
		starts.append(body.global_position)
		body.submit_control(0.7, 1.0 if index == 0 else -1.0, 0.0, false, 1)
	for _tick in 90:
		await physics_frame
	var results: Array[Dictionary] = []
	for index in bodies.size():
		var body := bodies[index]
		var steer := 1.0 if index == 0 else -1.0
		var displacement := body.global_position - starts[index]
		check(body.rotation.y * steer > 0.05, "signed steering yaw follows input " + str(steer))
		check(displacement.x * steer < -0.10, "signed steering lateral displacement follows authored axis " + str(steer))
		results.append({"steer":steer, "yaw_rad":body.rotation.y, "displacement_m":displacement,
			"grounded_mask":int(body.snapshot_state().grounded_wheel_mask)})
	world.free()
	return {"cases":results}

func test_all_profile_equilibrium(rows: Array) -> Dictionary:
	var world := Node3D.new()
	world.add_child(make_floor(Vector3(80.0, 0.5, 70.0), "candidate_all_profiles_floor"))
	root.add_child(world)
	var bodies: Array[RigidBody3D] = []
	var histories: Array[Array] = []
	for index in rows.size():
		var row := rows[index] as Dictionary
		var profile_id := str(row.profile_id)
		var body := new_body(admitted_descriptor(row, "candidate-settle-" + profile_id))
		check(body != null, "candidate equilibrium admission " + profile_id)
		if body == null:
			continue
		var column := index % 4
		var grid_row := index / 4
		body.position = Vector3((float(column) - 1.5) * 14.0, 0.75, (float(grid_row) - 1.0) * 18.0)
		world.add_child(body)
		bodies.append(body)
		histories.append([])
	check(bodies.size() == EXPECTED_PROFILES, "all twelve candidate bodies instantiate")
	var ticks_run := 0
	var stable_streak := 0
	while ticks_run < SETTLE_MAX_TICKS and stable_streak < STABLE_TICKS:
		await physics_frame
		ticks_run += 1
		for index in bodies.size():
			var points: Array = histories[index]
			points.append(bodies[index].global_position)
			if points.size() > STABLE_TICKS:
				points.pop_front()
		if ticks_run < SETTLE_MIN_TICKS:
			continue
		var all_stable := true
		for index in bodies.size():
			var body := bodies[index]
			var state: Dictionary = body.snapshot_state()
			var stable := finite_state(body, state) and ray_count(body) == 4 and int(state.grounded_wheel_mask) == 15 \
				and body.linear_velocity.length() <= 0.03 and tilt_rad(body) <= 0.035 \
				and absf(body.global_position.y) <= 0.03 and history_jitter(histories[index]) <= 0.005 \
				and collider_base_world_y(body) >= -0.005
			if not stable:
				all_stable = false
				break
		stable_streak = stable_streak + 1 if all_stable else 0
	var results: Array[Dictionary] = []
	for index in bodies.size():
		var body := bodies[index]
		var state: Dictionary = body.snapshot_state()
		var profile_id := str(body.profile.profile_id)
		var result := {"profile_id":profile_id, "finite":finite_state(body, state),
			"ray_count":ray_count(body), "grounded_mask":int(state.grounded_wheel_mask),
			"speed_mps":body.linear_velocity.length(), "tilt_rad":tilt_rad(body),
			"root_y_m":body.global_position.y, "jitter_m":history_jitter(histories[index]),
			"collider_base_y_m":collider_base_world_y(body)}
		results.append(result)
		check(bool(result.finite), profile_id + " finite equilibrium")
		check(int(result.ray_count) == 4 and int(result.grounded_mask) == 15, profile_id + " four supported probes")
		check(float(result.speed_mps) <= 0.03 and float(result.tilt_rad) <= 0.035, profile_id + " velocity and tilt settle")
		check(absf(float(result.root_y_m)) <= 0.03 and float(result.jitter_m) <= 0.005, profile_id + " root and jitter settle")
		check(float(result.collider_base_y_m) >= -0.005, profile_id + " collider base nonpenetration")
	check(ticks_run >= SETTLE_MIN_TICKS and ticks_run <= SETTLE_MAX_TICKS and stable_streak >= STABLE_TICKS,
		"all profiles sustain bounded sixty-tick equilibrium")
	world.free()
	return {"ticks_run":ticks_run, "stable_streak":stable_streak, "profiles":results}

func finish(receipt: Dictionary) -> void:
	print("CANDIDATE_VEHICLE_ADMISSION_TEST ", JSON.stringify({"passed":failures.is_empty(),
		"checks":checks, "failure_count":failures.size(), "failures":failures,
		"candidate_path":CANDIDATE, "candidate_sha256":FileAccess.get_sha256(CANDIDATE),
		"descriptor_sha256":FileAccess.get_sha256(DESCRIPTORS), "receipt":receipt,
		"qualification":"CANDIDATE ONLY; exact source except duplicate class_name registry declaration removed in memory; no production body, visual, GPU, main, LIVE or server authority"}))
	quit(0 if failures.is_empty() else 1)
