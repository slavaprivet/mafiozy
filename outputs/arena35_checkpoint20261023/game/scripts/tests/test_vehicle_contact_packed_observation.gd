extends SceneTree

const PackedCollector = preload("res://scripts/vehicle_physics/vehicle_contact_packed_observation.gd")
const FrozenCollector = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")
const FROZEN_SHA := "d14946c97ecdb43105d6d760553a7de0151eda64b22e3254b285a94987c759f0"

class Probe:
	extends RigidBody3D
	var packed = PackedCollector.new()
	var frozen = FrozenCollector.new()
	var spare = PackedCollector.new()
	var tick := 0
	var compared := 0
	var mismatches := 0
	var cap_seen := 0
	var wall_seen := 0
	var identity_gap_seen := 0
	var wall_initial_identity_seen := 0
	var wall_mutated_identity_seen := 0
	var old_spare_tick := -1
	var old_spare_point := Vector3.ZERO
	var old_spare_identity := ""
	var old_decoded: Dictionary = {}
	var old_decoded_point := Vector3.ZERO
	var old_decoded_index := -1
	var callback_cost_packed: Array[int] = []
	var callback_cost_frozen: Array[int] = []
	var do_cap := false
	var do_mutate := false
	var wall_runtime_id := 0

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		tick += 1
		var self_ref := {"vehicle_id": "packed-test", "life_generation": 3}
		var start := Time.get_ticks_usec()
		var raw := frozen.collect(state, self_ref, tick)
		callback_cost_frozen.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		var admitted := packed.collect_into(state, self_ref, tick)
		callback_cost_packed.append(Time.get_ticks_usec() - start)
		var decoded := packed.decode_legacy()
		if not admitted or raw != decoded:
			mismatches += 1
		else:
			compared += 1
		if do_cap and bool(decoded.status.collection_cap_gap):
			cap_seen += 1
			if not bool(decoded.status.collection_identity_gap):
				identity_gap_seen += 1
		if wall_runtime_id > 0:
			for row_index in decoded.rows.size():
				var row: Dictionary = decoded.rows[row_index]
				if int(row.counterpart_runtime_id) == wall_runtime_id:
					wall_seen += 1
					if old_decoded.is_empty():
						old_decoded = decoded.duplicate(true)
						old_decoded_point = row.point_on_self_world_m
						old_decoded_index = row_index
					if row.peer_identity.get("source_id") == "packed-wall":
						wall_initial_identity_seen += 1
					elif row.peer_identity.get("source_id") == "packed-wall-mutated":
						wall_mutated_identity_seen += 1
			if tick == 1:
				spare.collect_into(state, self_ref, tick)
				old_spare_tick = spare.global_physics_tick
				old_spare_point = spare.points_self_world[0] if spare.retained_contact_count > 0 else Vector3.ZERO
				old_spare_identity = str(spare.self_identity.vehicle_id)
			elif old_spare_tick >= 0 and (spare.global_physics_tick != old_spare_tick \
					or str(spare.self_identity.vehicle_id) != old_spare_identity \
					or (spare.retained_contact_count > 0 and spare.points_self_world[0] != old_spare_point)):
				mismatches += 1
		if do_mutate and not decoded.rows.is_empty():
			decoded.rows[0].self_identity.vehicle_id = "bad"
			decoded.rows[0].peer_identity.source_id = "bad"
			decoded.rows[0].point_on_self_world_m = Vector3(999.0, 999.0, 999.0)
			if packed.decode_legacy().rows[0].self_identity.vehicle_id != "packed-test" \
					or packed.decode_legacy().rows[0].point_on_self_world_m.x == 999.0:
				mismatches += 1
		if not old_decoded.is_empty() \
				and old_decoded.rows[old_decoded_index].point_on_self_world_m != old_decoded_point:
			mismatches += 1
		if do_cap:
			state.transform = Transform3D.IDENTITY
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("run")

func make_box(parent: Node3D, at: Transform3D, size: Vector3, source_id: String,
		source_index: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = at
	if not source_id.is_empty():
		body.set_meta("source_id", source_id)
		body.set_meta("source_index", source_index)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func make_probe(parent: Node3D, at: Transform3D) -> Probe:
	var body := Probe.new()
	body.transform = at
	body.gravity_scale = 0.0
	body.mass = 1500.0
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.can_sleep = false
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.0, 4.0)
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func run() -> void:
	check(FileAccess.get_sha256(
		"res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd") == FROZEN_SHA,
		"frozen collector hash")
	var invalid = PackedCollector.new()
	check(not invalid.collect_into(null, {}, -1), "invalid input refused")
	check(invalid.decode_legacy() == FrozenCollector.new().collect(null, {}, -1),
		"invalid envelope byte-shape parity")
	var world := Node3D.new()
	root.add_child(world)
	var yaw := 0.61
	var basis := Basis(Vector3.UP, yaw)
	var origin := Vector3(25.0, 5.0, -18.0)
	var wall := make_box(world, Transform3D(basis, origin), Vector3(20, 20, 0.5),
		"packed-wall", 41)
	var probe := make_probe(world, Transform3D(basis, origin + basis * Vector3.BACK * 7.0))
	probe.wall_runtime_id = wall.get_instance_id()
	probe.do_mutate = true
	for _i in 3:
		await physics_frame
	probe.linear_velocity = basis * Vector3.FORWARD * 12.0
	for _i in 48:
		await physics_frame
	wall.set_meta("source_id", "packed-wall-mutated")
	for _i in 47:
		await physics_frame
	check(probe.compared > 80 and probe.mismatches == 0, "wall callback envelope exact parity")
	check(probe.wall_seen > 0, "rotated translated wall contact observed")
	check(probe.wall_initial_identity_seen > 0 and probe.wall_mutated_identity_seen > 0,
		"mid-contact authored peer identity mutation preserved with frozen parity")
	check(probe.spare.global_physics_tick == 1 and probe.old_spare_tick == 1,
		"second buffer retained first tick independently")
	var wall_callbacks := probe.compared
	var wall_contact_rows := probe.wall_seen
	var wall_identity_before := probe.wall_initial_identity_seen
	var wall_identity_after := probe.wall_mutated_identity_seen
	var wall_packed_p95 := percentile(probe.callback_cost_packed, 0.95)
	var wall_frozen_p95 := percentile(probe.callback_cost_frozen, 0.95)
	var wall_raw := probe.frozen.collect(null, {}, -1)
	check(wall_raw == invalid.decode_legacy(), "invalid decode remains stable")
	world.queue_free()
	for _i in 4:
		await physics_frame

	var cap_world := Node3D.new()
	root.add_child(cap_world)
	var cap := make_probe(cap_world, Transform3D.IDENTITY)
	cap.do_cap = true
	for index in 8:
		var z := -1.75 + float(index % 4) * 1.17
		var x := -0.86 if index < 4 else 0.86
		make_box(cap_world, Transform3D(Basis.IDENTITY, Vector3(x, 0, z)),
			Vector3(0.32, 1.0, 0.32), "packed-cap-%d" % index, index)
	for _i in 70:
		await physics_frame
	check(cap.compared > 50 and cap.mismatches == 0, "cap callback exact parity")
	check(cap.cap_seen > 0, "eight-contact cap gap observed")
	check(cap.packed.retained_contact_count <= 8, "never retains ninth point")
	check(cap.packed.collection_gap and not cap.packed.complete,
		"cap is incomplete, not silently admitted")
	check(cap.identity_gap_seen > 0, "authored peers admitted at cap")
	var report := {"checks": checks, "failures": failures, "wall_callbacks": wall_callbacks,
		"cap_callbacks": cap.compared,
		"wall_contact_rows": wall_contact_rows, "cap_ticks": cap.cap_seen,
		"wall_identity_before": wall_identity_before,
		"wall_identity_after": wall_identity_after,
		"wall_packed_us_p95": wall_packed_p95,
		"wall_frozen_us_p95": wall_frozen_p95,
		"cap_packed_us_p95": percentile(cap.callback_cost_packed, 0.95),
		"cap_frozen_us_p95": percentile(cap.callback_cost_frozen, 0.95)}
	print("PACKED_CONTACT_REPORT ", JSON.stringify(report))
	cap_world.queue_free()
	quit(1 if failures.size() > 0 else 0)

func percentile(values: Array[int], fraction: float) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(ceil(fraction * sorted.size())) - 1)]
