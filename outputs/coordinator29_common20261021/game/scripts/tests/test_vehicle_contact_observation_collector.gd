extends SceneTree
## Isolated actual-direct-state verification for raw coherent contact snapshots.

const Collector = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")
const COLLECTOR_PATH := "res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd"
const FROZEN_BRIDGE := "res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd"
const FROZEN_BRIDGE_SHA256 := "73843ce758381b7911aa432ade0e66cfb9ea96ebd05986f0e9f39bc64a1de1a7"
const FROZEN_MANIFOLD := "res://scripts/vehicle_physics/vehicle_contact_manifold.gd"
const FROZEN_MANIFOLD_SHA256 := "dfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const FIXED_TICKS_PER_SECOND := 60
const WALL_TICKS := 120
const CAP_TICKS := 90
const WALL_SOURCE_ID := "collector-rotated-wall"

class WallProbe:
	extends NativeVehicleBody
	var collector = Collector.new()
	var observation_tick := 0
	var expected_wall_runtime_id := 0
	var expected_normal_on_self_world := Vector3.ZERO
	var collection_invalid_count := 0
	var frame_mismatch_count := 0
	var first_contact_tick := -1
	var first_nonzero_impulse_tick := -1
	var first_row: Dictionary = {}
	var first_nonzero_row: Dictionary = {}
	var later_row_after_mutation: Dictionary = {}
	var first_world_point_pair_distance_m := INF
	var first_false_local_hypothesis_distance_m := INF
	var observed_root_origin := Vector3.ZERO
	var observed_root_basis := Basis.IDENTITY
	var timings_us: Array[int] = []
	var mutated_first_export := false

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		observation_tick += 1
		var started_us := Time.get_ticks_usec()
		var envelope: Dictionary = collector.collect(state,
			{"vehicle_id": "coherent-wall-probe", "life_generation": 7}, observation_tick)
		timings_us.append(Time.get_ticks_usec() - started_us)
		if not bool(envelope.get("valid", false)):
			collection_invalid_count += 1
			return
		if envelope.target_root_frame_world != state.transform:
			frame_mismatch_count += 1
		for row_value: Variant in envelope.rows:
			var row: Dictionary = row_value
			if int(row.get("counterpart_runtime_id", 0)) != expected_wall_runtime_id:
				continue
			if row.target_root_frame_world != state.transform \
					or int(row.global_physics_tick) != observation_tick:
				frame_mismatch_count += 1
			if first_contact_tick < 0:
				first_contact_tick = observation_tick
				first_row = row.duplicate(true)
				observed_root_origin = state.transform.origin
				observed_root_basis = state.transform.basis
				first_world_point_pair_distance_m = row.point_on_self_world_m.distance_to(
					row.point_on_counterpart_world_m)
				first_false_local_hypothesis_distance_m = (state.transform \
					* row.point_on_self_world_m).distance_to(row.point_on_counterpart_world_m)
				# Caller mutation must not leak into the collector's fixed storage, the
				# envelope identity, or any later export.
				row.point_on_self_world_m = Vector3(999.0, 999.0, 999.0)
				row.self_identity.vehicle_id = "mutated"
				row.peer_identity.source_id = "mutated"
				envelope.self_identity.vehicle_id = "mutated-envelope"
				mutated_first_export = true
			elif later_row_after_mutation.is_empty():
				later_row_after_mutation = row.duplicate(true)
			if first_nonzero_impulse_tick < 0 \
					and row.impulse_on_self_world_ns.length() > 0.000001:
				first_nonzero_impulse_tick = observation_tick
				first_nonzero_row = row.duplicate(true)

class CapProbe:
	extends NativeVehicleBody
	var collector = Collector.new()
	var observation_tick := 0
	var pinned_transform := Transform3D.IDENTITY
	var invalid_count := 0
	var cap_count := 0
	var incomplete_cap_count := 0
	var identity_gap_count := 0
	var nonfinite_gap_count := 0
	var maximum_rows := 0
	var dense_index_failures := 0
	var timings_us: Array[int] = []

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		observation_tick += 1
		var started_us := Time.get_ticks_usec()
		var envelope: Dictionary = collector.collect(state,
			{"vehicle_id": "coherent-cap-probe", "life_generation": 11}, observation_tick)
		var elapsed_us := Time.get_ticks_usec() - started_us
		if observation_tick > 10:
			timings_us.append(elapsed_us)
		if not bool(envelope.get("valid", false)):
			invalid_count += 1
		else:
			var status: Dictionary = envelope.status
			maximum_rows = maxi(maximum_rows, (envelope.rows as Array).size())
			if bool(status.collection_cap_gap):
				cap_count += 1
				if not bool(envelope.complete):
					incomplete_cap_count += 1
				if bool(status.collection_identity_gap):
					identity_gap_count += 1
				if bool(status.collection_nonfinite_gap):
					nonfinite_gap_count += 1
				for index in (envelope.rows as Array).size():
					if int(envelope.rows[index].raw_contact_index) != index:
						dense_index_failures += 1
		state.transform = pinned_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	Engine.physics_ticks_per_second = FIXED_TICKS_PER_SECOND
	call_deferred("run")

func descriptor_for(vehicle_id: String, life_generation: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	if not parsed is Dictionary:
		return {}
	for candidate: Dictionary in (parsed as Dictionary).get("profiles", []):
		if str(candidate.get("profile_id", "")) != "compact_sedan":
			continue
		var row := candidate.duplicate(true)
		row.vehicle_id = vehicle_id
		row.source_id = "compact_sedan"
		row.life_generation = life_generation
		row.source_clock = 1
		return row
	return {}

func add_wall(world: Node3D, wall_transform: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.transform = wall_transform
	wall.set_meta("source_id", WALL_SOURCE_ID)
	wall.set_meta("source_index", 41)
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 20.0, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func add_cap_sphere(world: Node3D, index: int, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.set_meta("source_id", "collector-cap-%d" % index)
	body.set_meta("source_index", index)
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func run() -> void:
	check(FileAccess.get_sha256(FROZEN_BRIDGE) == FROZEN_BRIDGE_SHA256,
		"frozen state bridge remains byte exact")
	check(FileAccess.get_sha256(FROZEN_MANIFOLD) == FROZEN_MANIFOLD_SHA256,
		"frozen manifold remains byte exact")
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256,
		"frozen production native body remains byte exact")
	var contract: Dictionary = Collector.new().contract()
	check(contract.point_capacity == 8 and bool(contract.raw_rows_not_aggregated),
		"collector contract is bounded eight and never aggregates raw rows")
	check(not bool(contract.owns_impact_speed) and not bool(contract.owns_crash_or_damage)
		and not bool(contract.owns_hp) and not bool(contract.server_admissible),
		"collector owns no crash, damage, HP, impact-speed, or admission authority")
	check(contract.target_frame_source == "PhysicsDirectBodyState3D.transform_at_collect"
		and bool(contract.contact_accessors_are_world_space),
		"contract pins direct-state root transform and audited world-space accessors")
	check(not bool(contract.physics_tick_authoritative)
		and not bool(contract.self_identity_authoritative)
		and contract.closing_speed_semantics == "derived_same_row_point_kinematics_not_source_impact_speed",
		"contract exposes caller tick/identity trust gap and non-impact closing semantics")

	var wall_evidence := await run_wall_fixture()
	var cap_evidence := await run_cap_fixture()
	finish(wall_evidence, cap_evidence)

func run_wall_fixture() -> Dictionary:
	var descriptor := descriptor_for("coherent-wall-probe", 7)
	check(not descriptor.is_empty(), "wall compact descriptor available")
	if descriptor.is_empty():
		return {}
	var yaw := 0.61
	var basis := Basis(Vector3.UP, yaw)
	var wall_origin := Vector3(25.0, 5.0, -18.0)
	var expected_normal := (basis * Vector3.BACK).normalized()
	var approach := -expected_normal
	var world := Node3D.new()
	root.add_child(world)
	var wall := add_wall(world, Transform3D(basis, wall_origin))
	var probe := WallProbe.new()
	check(probe.configure(descriptor), "actual native wall probe configures")
	probe.transform = Transform3D(basis, wall_origin - approach * 8.0)
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	probe.expected_wall_runtime_id = wall.get_instance_id()
	probe.expected_normal_on_self_world = expected_normal
	world.add_child(probe)
	for _tick in 4:
		await physics_frame
	probe.linear_velocity = approach * 12.0
	probe.angular_velocity = Vector3.ZERO
	for _tick in WALL_TICKS:
		await physics_frame

	check(probe.collection_invalid_count == 0, "all actual wall envelopes admit collection inputs")
	check(probe.frame_mismatch_count == 0, "envelope and rows freeze exact same-callback state.transform")
	check(probe.first_contact_tick >= 0 and not probe.first_row.is_empty(),
		"actual translated rotated wall contact observed")
	check(probe.first_row.raw_contact_index >= 0
		and probe.first_row.global_physics_tick == probe.first_contact_tick
		and not bool(probe.first_row.physics_tick_authoritative),
		"raw contact index and global tick remain coherent")
	check(probe.first_row.self_identity.vehicle_id == "coherent-wall-probe"
		and probe.first_row.self_identity.life_generation == 7
		and not bool(probe.first_row.self_identity_authoritative),
		"row freezes exact self vehicle and life identity")
	check(probe.first_row.peer_identity.valid
		and probe.first_row.peer_identity.kind == "static"
		and probe.first_row.peer_identity.source_id == WALL_SOURCE_ID
		and probe.first_row.peer_identity.source_index == 41,
		"row freezes exact authored static peer identity")
	check(probe.first_world_point_pair_distance_m < 0.10,
		"self and counterpart API points are already reciprocal world points")
	check(probe.first_world_point_pair_distance_m * 10.0
		< probe.first_false_local_hypothesis_distance_m,
		"applying captured root transform to raw self point is rejected")
	check(probe.first_row.normal_on_self_world.normalized().dot(expected_normal) > 0.95,
		"raw normal is world-oriented normal on self")
	check(probe.first_row.impulse_on_self_world_ns.length() <= 0.000001
		and probe.first_row.closing_speed_along_normal_mps > 5.0
		and probe.first_row.closing_speed_semantics \
		== "derived_same_row_point_kinematics_not_source_impact_speed",
		"actual onset preserves same-index zero J and positive closing")
	check(probe.first_nonzero_impulse_tick > probe.first_contact_tick,
		"later nonzero J remains a distinct raw observation tick")
	check(probe.first_nonzero_row.impulse_on_self_world_ns.dot(
		probe.first_nonzero_row.normal_on_self_world.normalized()) >= 0.0,
		"later J and normal both point onto self")
	check(probe.first_nonzero_row.closing_speed_along_normal_mps < 0.10,
		"later J row does not overwrite zero-J onset closing chronology")
	check(probe.observed_root_origin.distance_to(Vector3.ZERO) > 10.0
		and (probe.observed_root_basis * Vector3.FORWARD).dot(Vector3.FORWARD) < 0.95,
		"captured target root frame is materially translated and rotated")
	check(probe.mutated_first_export and not probe.later_row_after_mutation.is_empty()
		and probe.later_row_after_mutation.self_identity.vehicle_id == "coherent-wall-probe"
		and probe.later_row_after_mutation.peer_identity.source_id == WALL_SOURCE_ID
		and probe.later_row_after_mutation.point_on_self_world_m != Vector3(999.0, 999.0, 999.0),
		"caller mutation cannot alter later exported rows or identities")
	var cost := summarize_cost(probe.timings_us)
	check(bool(cost.valid) and float(cost.p95_us) < 5000.0,
		"actual wall collector p95 remains below bounded five-millisecond diagnostic ceiling")
	var evidence := {"first_contact_tick": probe.first_contact_tick,
		"first_nonzero_impulse_tick": probe.first_nonzero_impulse_tick,
		"first_closing_speed_mps": probe.first_row.get("closing_speed_along_normal_mps", -1.0),
		"first_impulse_ns": probe.first_row.get("impulse_on_self_world_ns", Vector3.ZERO),
		"later_impulse_ns": probe.first_nonzero_row.get("impulse_on_self_world_ns", Vector3.ZERO),
		"point_pair_distance_m": probe.first_world_point_pair_distance_m,
		"false_local_hypothesis_distance_m": probe.first_false_local_hypothesis_distance_m,
		"root_origin": probe.observed_root_origin, "cost": cost}
	probe.free()
	wall.free()
	world.free()
	return evidence

func run_cap_fixture() -> Dictionary:
	var descriptor := descriptor_for("coherent-cap-probe", 11)
	check(not descriptor.is_empty(), "cap compact descriptor available")
	if descriptor.is_empty():
		return {}
	var world := Node3D.new()
	root.add_child(world)
	var probe := CapProbe.new()
	check(probe.configure(descriptor), "actual native cap probe configures")
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	probe.pinned_transform = Transform3D.IDENTITY
	world.add_child(probe)
	var statics: Array[StaticBody3D] = []
	var centers := PackedVector3Array([
		Vector3(-1.32, 1.00, -1.55), Vector3(-1.32, 1.00, 1.55),
		Vector3(1.32, 1.00, -1.55), Vector3(1.32, 1.00, 1.55),
		Vector3(-0.68, 1.00, -2.58), Vector3(0.68, 1.00, -2.58),
		Vector3(-0.68, 1.00, 2.58), Vector3(0.68, 1.00, 2.58)])
	for index in centers.size():
		statics.append(add_cap_sphere(world, index, centers[index]))
	for _tick in CAP_TICKS:
		await physics_frame

	check(probe.invalid_count == 0, "all cap fixture collection envelopes are valid")
	check(probe.maximum_rows == Collector.POINT_CAPACITY,
		"actual fixture reaches but never exceeds eight retained raw rows")
	check(probe.cap_count > 0 and probe.incomplete_cap_count == probe.cap_count,
		"count-at-eight actual envelopes always fail closed as incomplete")
	check(probe.identity_gap_count == 0 and probe.nonfinite_gap_count == 0,
		"all eight actual identities and raw numeric rows remain valid")
	check(probe.dense_index_failures == 0, "all retained rows preserve exact dense raw indices")
	var cost := summarize_cost(probe.timings_us)
	check(bool(cost.valid) and float(cost.p95_us) < 5000.0,
		"actual eight-row collector p95 remains below bounded five-millisecond diagnostic ceiling")
	var evidence := {"cap_tick_count": probe.cap_count,
		"incomplete_cap_tick_count": probe.incomplete_cap_count,
		"maximum_rows": probe.maximum_rows, "cost": cost}
	probe.free()
	for body: StaticBody3D in statics:
		body.free()
	world.free()
	return evidence

func summarize_cost(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {"valid": false}
	var sorted := values.duplicate()
	sorted.sort()
	var last := sorted.size() - 1
	return {"valid": true, "samples": sorted.size(),
		"p50_us": sorted[int(floor(last * 0.50))],
		"p95_us": sorted[int(floor(last * 0.95))],
		"max_us": sorted[last], "scope": "actual callback wall latency; no FPS or aggregate CPU claim"}

func finish(wall_evidence: Dictionary, cap_evidence: Dictionary) -> void:
	print("NATIVE_VEHICLE_CONTACT_OBSERVATION_COLLECTOR_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"collector_sha256": FileAccess.get_sha256(COLLECTOR_PATH),
		"frozen_bridge_sha256": FileAccess.get_sha256(FROZEN_BRIDGE),
		"frozen_manifold_sha256": FileAccess.get_sha256(FROZEN_MANIFOLD),
		"wall": wall_evidence, "cap": cap_evidence,
		"runtime_wired": false,
		"qualification": "isolated raw direct-state observation evidence; no crash adapter, authority, body/main, GPU, LIVE, FPS or server claim"
	}))
	quit(0 if failures.is_empty() else 1)
