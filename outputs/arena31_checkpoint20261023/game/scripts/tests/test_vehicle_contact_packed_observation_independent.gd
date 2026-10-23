extends SceneTree

const Candidate = preload("res://scripts/vehicle_physics/vehicle_contact_packed_observation.gd")
const Frozen = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")

class ContactCar:
	extends RigidBody3D
	var candidate = Candidate.new()
	var reference = Frozen.new()
	var retained = Candidate.new()
	var ticks := 0
	var equal_envelopes := 0
	var inequality_count := 0
	var valid_complete_count := 0
	var valid_incomplete_count := 0
	var cap_count := 0
	var identity_gap_count := 0
	var peer_source_before := 0
	var peer_source_after := 0
	var first_decoded: Dictionary = {}
	var first_tick := -1
	var first_point := Vector3.ZERO
	var first_peer_source := ""
	var old_buffer_tick := -1
	var late_mutation_count := 0
	var invalid_self_count := 0
	var invalid_tick_count := 0
	var different_life_count := 0
	var lifecycle_check_count := 0
	var peer_runtime_id := 0
	var cap_case := false

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		ticks += 1
		var identity := {"vehicle_id": "independent-car", "life_generation": 7}
		var expected := reference.collect(state, identity, ticks)
		candidate.collect_into(state, identity, ticks)
		var actual := candidate.decode_legacy()
		if actual == expected:
			equal_envelopes += 1
		else:
			inequality_count += 1
		if actual.valid and actual.complete:
			valid_complete_count += 1
		if actual.valid and not actual.complete:
			valid_incomplete_count += 1
		if actual.valid and actual.status.collection_cap_gap:
			cap_count += 1
		if actual.valid and actual.status.collection_identity_gap:
			identity_gap_count += 1
		if actual.valid and actual.global_physics_tick == ticks \
				and actual.target_root_frame_world == state.transform \
				and actual.self_identity.vehicle_id == "independent-car" \
				and actual.self_identity.life_generation == 7:
			lifecycle_check_count += 1
		for row in actual.rows:
			if row.counterpart_runtime_id == peer_runtime_id:
				if row.peer_identity.get("source_id") == "independent-wall":
					peer_source_before += 1
				if row.peer_identity.get("source_id") == "independent-wall-updated":
					peer_source_after += 1
				if first_decoded.is_empty():
					first_decoded = actual.duplicate(true)
					first_tick = ticks
					first_point = row.point_on_self_world_m
					first_peer_source = str(row.peer_identity.get("source_id", ""))
		if ticks == 1:
			retained.collect_into(state, identity, ticks)
			old_buffer_tick = retained.global_physics_tick
		if ticks == 10:
			var rejected := Candidate.new()
			if not rejected.collect_into(state, {"vehicle_id": "", "life_generation": 0}, ticks) \
					and rejected.decode_legacy() == reference.collect(state,
					{"vehicle_id": "", "life_generation": 0}, ticks):
				invalid_self_count += 1
			if not rejected.collect_into(state, identity, -1) \
					and rejected.decode_legacy() == reference.collect(state, identity, -1):
				invalid_tick_count += 1
			var other_life := Candidate.new()
			if other_life.collect_into(state,
					{"vehicle_id": "independent-car", "life_generation": 8}, ticks) \
					and other_life.decode_legacy().self_identity.life_generation == 8 \
					and candidate.decode_legacy().self_identity.life_generation == 7:
				different_life_count += 1
		if not actual.rows.is_empty():
			actual.rows[0].self_identity.vehicle_id = "external-corruption"
			actual.rows[0].peer_identity["source_id"] = "external-corruption"
			if candidate.decode_legacy().rows[0].self_identity.vehicle_id == "independent-car" \
					and candidate.decode_legacy().rows[0].peer_identity.get("source_id") \
					!= "external-corruption":
				late_mutation_count += 1
		if cap_case:
			state.transform = Transform3D.IDENTITY
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO

var checks := 0
var failures: Array[String] = []

func check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures.append(name)

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("run")

func add_box(parent: Node3D, position: Vector3, dimensions: Vector3,
		source_id: String, index: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.set_meta("source_id", source_id)
	body.set_meta("source_index", index)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func add_car(parent: Node3D, position: Vector3) -> ContactCar:
	var body := ContactCar.new()
	body.position = position
	body.gravity_scale = 0.0
	body.mass = 1500.0
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.can_sleep = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 1, 4)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func run() -> void:
	var empty := Candidate.new()
	check(not empty.collect_into(null, {}, -1), "null state and negative tick rejected")
	check(not empty.valid and not empty.complete and empty.collection_gap,
		"invalid header fail closed")
	check(empty.decode_legacy() == Frozen.new().collect(null, {}, -1),
		"invalid envelope keyset parity")
	check(not empty.contract().server_admissible and not empty.contract().runtime_wired,
		"proposal only contract")
	var phase_a := Node3D.new()
	root.add_child(phase_a)
	var wall := add_box(phase_a, Vector3(0, 0, -5), Vector3(20, 20, 0.5),
		"independent-wall", 11)
	var car := add_car(phase_a, Vector3(0, 0, 1))
	car.peer_runtime_id = wall.get_instance_id()
	for _i in 3:
		await physics_frame
	car.linear_velocity = Vector3(0, 0, -12)
	for _i in 46:
		await physics_frame
	wall.set_meta("source_id", "independent-wall-updated")
	for _i in 42:
		await physics_frame
	check(car.ticks >= 85 and car.inequality_count == 0
		and car.equal_envelopes == car.ticks, "all wall callbacks exact envelope parity")
	check(car.valid_complete_count > 0, "valid complete noncap callback")
	check(car.lifecycle_check_count == car.ticks, "tick frame self identity same callback")
	check(car.peer_source_before > 0 and car.peer_source_after > 0,
		"live peer identity mutation observed")
	check(car.invalid_self_count == 1, "invalid self identity rejected in callback")
	check(car.invalid_tick_count == 1, "negative tick rejected in callback")
	check(car.different_life_count == 1, "independent life generation preserved")
	check(car.first_tick > 0 and car.first_decoded.global_physics_tick == car.first_tick,
		"first detached decoded tick retained")
	check(car.first_decoded.rows[0].point_on_self_world_m == car.first_point,
		"first detached point retained after reuse")
	check(car.first_decoded.rows[0].peer_identity.source_id == car.first_peer_source,
		"first detached peer metadata retained after mutation")
	check(car.retained.global_physics_tick == 1 and car.old_buffer_tick == 1,
		"second buffer unchanged while first reused")
	check(car.late_mutation_count > 0, "decoded dictionaries cannot mutate candidate")
	var wall_ticks := car.ticks
	var peer_before := car.peer_source_before
	var peer_after := car.peer_source_after
	phase_a.queue_free()
	for _i in 3:
		await physics_frame
	var phase_b := Node3D.new()
	root.add_child(phase_b)
	var cap_car := add_car(phase_b, Vector3.ZERO)
	cap_car.cap_case = true
	for index in 8:
		var x := -0.86 if index < 4 else 0.86
		var z := -1.75 + float(index % 4) * 1.17
		add_box(phase_b, Vector3(x, 0, z), Vector3(0.32, 1, 0.32),
			"independent-obstacle-%d" % index, index)
	for _i in 40:
		await physics_frame
	check(cap_car.inequality_count == 0 and cap_car.equal_envelopes >= 35,
		"cap callback parity")
	check(cap_car.cap_count > 0 and cap_car.valid_incomplete_count > 0,
		"eight contacts conservatively incomplete")
	check(cap_car.candidate.raw_state_contact_count == 8
		and cap_car.candidate.retained_contact_count == 8,
		"eighth retained, ninth not invented")
	check(cap_car.identity_gap_count == 0
		and cap_car.candidate.unique_counterpart_count >= 1
		and cap_car.candidate.unique_counterpart_count <= 8,
		"eight contact rows retain valid authored peer identities")
	check(cap_car.candidate.collection_gap and not cap_car.candidate.complete,
		"cap gap cannot be admitted")
	print("PACKED_CONTACT_INDEPENDENT_REPORT ", JSON.stringify({"checks": checks,
		"failures": failures, "wall_ticks": wall_ticks,
		"cap_ticks": cap_car.ticks, "wall_pre": peer_before,
		"wall_post": peer_after,
		"cap_unique_peers": cap_car.candidate.unique_counterpart_count,
		"cap_identity_gap": cap_car.candidate.collection_identity_gap}))
	phase_b.queue_free()
	quit(1 if failures.size() > 0 else 0)
