extends SceneTree
## Production factory regression: physical braking and unsupported momentum.
## Run headless with --fixed-fps 60. No frozen candidate or source-file hash pins.
const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const ProductionBody = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const START_SPEED := 10.0
const STOP_SPEED := 0.25
const HOLD_TICKS := 30
var checks := 0
var failures: Array[String] = []
var profile: Dictionary

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func spawn(world: Node3D, id: String, position: Vector3) -> RigidBody3D:
	var factory := Factory.new()
	var body: RigidBody3D = factory.spawn_from_descriptor({"vehicle_id":id,
		"profile_id":"compact_sedan", "life_generation":1, "source_clock":1,
		"position_m":position, "yaw_rad":0.0, "active":true}, profile)
	check(body != null, "production factory admission: " + id)
	if body != null:
		check(body.get_script() == ProductionBody, "factory uses current production body: " + id)
		world.add_child(body)
	return body

func control(body: RigidBody3D, throttle: float, brake: float, hand: bool) -> bool:
	return body.submit_authoritative_control(throttle, 0.0, brake, hand, 1,
		str(body.get_meta("vehicle_id")), 1, 1)

func speed(body: RigidBody3D) -> float:
	return body.linear_velocity.dot(-body.global_basis.z.normalized())

func distance(body: RigidBody3D, start: Vector3) -> float:
	return Vector2(body.global_position.x-start.x, body.global_position.z-start.z).length()

func run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary and parsed.get("profiles") is Array, "production profile catalogue")
	if parsed is Dictionary and parsed.get("profiles") is Array:
		for row: Dictionary in parsed.profiles:
			if row.get("profile_id") == "compact_sedan": profile = row.duplicate(true)
	check(not profile.is_empty(), "compact sedan profile present")
	if profile.is_empty():
		finish({})
		return
	var braking: Dictionary = await test_braking()
	var airborne: Dictionary = await test_unsupported_momentum()
	finish({"braking":braking, "unsupported":airborne})

func test_braking() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.set_meta("vehicle_surface_id", "dry_asphalt")
	var shape := BoxShape3D.new()
	shape.size = Vector3(160.0, 0.5, 1000.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.25
	floor.add_child(collision)
	world.add_child(floor)
	var bodies: Array[RigidBody3D] = []
	var names := ["opposite", "service", "handbrake", "throttle_handbrake"]
	for index in names.size():
		var body := spawn(world, "braking-" + names[index], Vector3(-30+index*20, 1.15, 200))
		if body == null:
			world.free()
			return {}
		bodies.append(body)
	for tick in 180: await physics_frame
	var starts: Array[Vector3] = []
	for index in bodies.size():
		var body := bodies[index]
		check(body.snapshot_state().grounded_wheel_mask == 15, names[index] + " starts supported")
		starts.append(body.global_position)
		body.linear_velocity = Vector3(0, 0, -START_SPEED)
		body.angular_velocity = Vector3.ZERO
	check(control(bodies[0], -1, 0, false), "opposite pedal admitted")
	check(control(bodies[1], 0, 1, false), "service brake admitted")
	check(control(bodies[2], 0, 0, true), "neutral handbrake admitted")
	check(control(bodies[3], 1, 0, true), "throttle with handbrake admitted")
	var stops := PackedInt32Array([-1,-1,-1,-1])
	var stop_distances := PackedFloat64Array([-1,-1,-1,-1])
	var streaks := PackedInt32Array([0,0,0,0])
	var reverse_tick := -1
	var service_speed_error := 0.0
	var service_distance_error := 0.0
	var hand_speed_error := 0.0
	var hand_distance_error := 0.0
	var hand_peak := START_SPEED
	for tick in 360:
		await physics_frame
		var speeds := [speed(bodies[0]),speed(bodies[1]),speed(bodies[2]),speed(bodies[3])]
		if stops[0] < 0 and stops[1] < 0:
			service_speed_error = maxf(service_speed_error, absf(speeds[0]-speeds[1]))
			service_distance_error = maxf(service_distance_error, absf(distance(bodies[0],starts[0])-distance(bodies[1],starts[1])))
		for index in 4:
			if stops[index] >= 0: continue
			streaks[index] = streaks[index]+1 if absf(speeds[index]) <= STOP_SPEED else 0
			var hold := HOLD_TICKS if index >= 2 else 1
			if streaks[index] >= hold:
				stops[index] = tick+2-hold
				stop_distances[index] = distance(bodies[index],starts[index])
		if stops[0] >= 0 and reverse_tick < 0 and speeds[0] <= -0.5: reverse_tick = tick+1
		hand_speed_error = maxf(hand_speed_error, absf(speeds[2]-speeds[3]))
		hand_distance_error = maxf(hand_distance_error, absf(distance(bodies[2],starts[2])-distance(bodies[3],starts[3])))
		hand_peak = maxf(hand_peak, absf(speeds[3]))
	check(stops[0] > 0 and stops[1] > 0, "opposite and service both reach zero transition band")
	check(stops[0] > 0 and stops[1] > 0 and absi(stops[0]-stops[1]) <= 1, "opposite matches service stop time")
	check(stops[0] > 0 and stops[1] > 0 and absf(stop_distances[0]-stop_distances[1]) <= .1, "opposite matches service stop distance")
	check(service_speed_error <= .1 and service_distance_error <= .1, "opposite follows service trajectory before zero")
	check(reverse_tick > stops[0] and stops[0] > 0 and reverse_tick-stops[0] <= 120, "reverse engages only after stop and within two seconds")
	check(absf(speed(bodies[1])) <= .1, "held service brake remains stopped")
	check(stops[2] > 0 and stops[2] <= 240 and stops[3] > 0 and stops[3] <= 240, "both handbrakes sustain stop within four seconds")
	check(stops[2] > 0 and stops[3] > 0 and absi(stops[2]-stops[3]) <= 1, "throttle does not change handbrake stop time")
	check(hand_speed_error <= .05 and hand_distance_error <= .05, "throttle and neutral handbrake trajectories agree")
	check(hand_peak <= START_SPEED+.05, "handbrake suppresses propulsion")
	var metrics := {"stop_ticks":Array(stops), "stop_distances_m":Array(stop_distances),
		"reverse_tick":reverse_tick, "service_speed_error_mps":service_speed_error,
		"service_distance_error_m":service_distance_error, "hand_speed_error_mps":hand_speed_error,
		"hand_distance_error_m":hand_distance_error, "hand_peak_mps":hand_peak}
	world.free()
	return metrics

func test_unsupported_momentum() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var body := spawn(world, "braking-unsupported", Vector3(1000,30,0))
	if body == null:
		world.free()
		return {}
	body.gravity_scale = 0.0
	await physics_frame
	var initial := Vector3(3,2,-10)
	var impulse := Vector3(.25,-.5,1)*body.mass
	body.linear_velocity = initial
	body.angular_velocity = Vector3.ZERO
	body.apply_central_impulse(impulse)
	check(control(body,1,1,true), "unsupported controls admitted")
	var expected := initial+impulse/body.mass
	var error := 0.0
	var support_mask := 0
	for tick in 120:
		await physics_frame
		error = maxf(error,body.linear_velocity.distance_to(expected))
		support_mask |= int(body.snapshot_state().grounded_wheel_mask)
	check(support_mask == 0, "unsupported body has no wheel contacts")
	check(error <= .0001, "no airborne coast/damping/drive/brake changes momentum over two seconds")
	var metrics := {"max_velocity_error_mps":error,"support_mask":support_mask,"ticks":120}
	world.free()
	return metrics

func finish(metrics: Dictionary) -> void:
	print("VEHICLE_BRAKING_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"metrics":metrics,"scope":"Current production factory/body, fixed60 headless CPU physics; no LIVE/FPS/GPU claim"}))
	quit(0 if failures.is_empty() else 1)
