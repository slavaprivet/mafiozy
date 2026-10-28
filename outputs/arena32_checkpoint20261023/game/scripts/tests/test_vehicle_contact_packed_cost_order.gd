extends SceneTree

const PackedCollector = preload("res://scripts/vehicle_physics/vehicle_contact_packed_observation.gd")
const FrozenCollector = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")

class Probe:
	extends RigidBody3D
	var packed = PackedCollector.new()
	var frozen = FrozenCollector.new()
	var tick := 0
	var mismatches := 0
	var samples: Dictionary = {}
	var contact_rows := 0
	var cap_rows := 0
	var hold_position := false

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		tick += 1
		var self_ref := {"vehicle_id": "cost-order", "life_generation": 4}
		var frozen_first := tick % 2 == 0
		var raw: Dictionary
		var decoded: Dictionary
		if frozen_first:
			var begin := Time.get_ticks_usec()
			raw = frozen.collect(state, self_ref, tick)
			_record("frozen_first", Time.get_ticks_usec() - begin)
			begin = Time.get_ticks_usec()
			packed.collect_into(state, self_ref, tick)
			_record("packed_raw_second", Time.get_ticks_usec() - begin)
			begin = Time.get_ticks_usec()
			decoded = packed.decode_legacy()
			_record("packed_decode_second", Time.get_ticks_usec() - begin)
		else:
			var begin := Time.get_ticks_usec()
			packed.collect_into(state, self_ref, tick)
			_record("packed_raw_first", Time.get_ticks_usec() - begin)
			decoded = packed.decode_legacy()
			_record("packed_total_first", Time.get_ticks_usec() - begin)
			begin = Time.get_ticks_usec()
			raw = frozen.collect(state, self_ref, tick)
			_record("frozen_second", Time.get_ticks_usec() - begin)
		if raw != decoded:
			mismatches += 1
		contact_rows += decoded.rows.size()
		if bool(decoded.status.collection_cap_gap):
			cap_rows += 1
		if hold_position:
			state.transform = Transform3D.IDENTITY
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO

	func _record(key: String, elapsed: int) -> void:
		if not samples.has(key):
			samples[key] = []
		samples[key].append(elapsed)

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("run")

func make_box(parent: Node3D, at: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.transform = at
	body.set_meta("source_id", "cost-wall")
	body.set_meta("source_index", parent.get_child_count())
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func make_probe(parent: Node3D, at: Transform3D) -> Probe:
	var probe := Probe.new()
	probe.transform = at
	probe.gravity_scale = 0.0
	probe.mass = 1500.0
	probe.contact_monitor = true
	probe.max_contacts_reported = 8
	probe.can_sleep = false
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 1, 4)
	collider.shape = shape
	probe.add_child(collider)
	parent.add_child(probe)
	return probe

func summarize(samples: Dictionary) -> Dictionary:
	var result := {}
	for key in samples:
		var values: Array = samples[key].duplicate()
		values.sort()
		result[key] = {"n": values.size(),
			"p50_us": values[values.size() / 2],
			"p95_us": values[mini(values.size() - 1, int(ceil(values.size() * 0.95)) - 1)]}
	return result

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var yaw := 0.61
	var basis := Basis(Vector3.UP, yaw)
	var origin := Vector3(25, 5, -18)
	make_box(world, Transform3D(basis, origin), Vector3(20, 20, 0.5))
	var wall := make_probe(world, Transform3D(basis, origin + basis * Vector3.BACK * 7))
	for _i in 3:
		await physics_frame
	wall.linear_velocity = basis * Vector3.FORWARD * 12
	for _i in 120:
		await physics_frame
	var wall_result := {"ticks": wall.tick, "rows": wall.contact_rows,
		"mismatches": wall.mismatches, "cost": summarize(wall.samples)}
	world.queue_free()
	for _i in 4:
		await physics_frame
	var cap_world := Node3D.new()
	root.add_child(cap_world)
	var cap := make_probe(cap_world, Transform3D.IDENTITY)
	cap.hold_position = true
	for index in 8:
		var z := -1.75 + float(index % 4) * 1.17
		var x := -0.86 if index < 4 else 0.86
		make_box(cap_world, Transform3D(Basis.IDENTITY, Vector3(x, 0, z)),
			Vector3(0.32, 1.0, 0.32))
	for _i in 100:
		await physics_frame
	var cap_result := {"ticks": cap.tick, "rows": cap.contact_rows,
		"cap_ticks": cap.cap_rows, "mismatches": cap.mismatches,
		"cost": summarize(cap.samples)}
	var ok := int(wall_result.ticks) >= 100 and int(wall_result.rows) > 0 \
		and int(wall_result.mismatches) == 0 \
		and cap.tick >= 90 and cap.cap_rows > 0 and cap.mismatches == 0
	print("PACKED_COST_ORDER_REPORT ", JSON.stringify({"pass": ok,
		"wall": wall_result, "cap": cap_result}))
	cap_world.queue_free()
	quit(0 if ok else 1)
