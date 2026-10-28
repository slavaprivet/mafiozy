extends SceneTree
## Actual direct-state bridge diagnostic: one source-tagged rotated building wall
## and one source-typed frozen RigidBody vehicle peer.

const Bridge = preload("res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd")
const BRIDGE_SHA256 := "73843ce758381b7911aa432ade0e66cfb9ea96ebd05986f0e9f39bc64a1de1a7"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const MANIFOLD_SHA256 := "dfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd"
const IDENTITY_SHA256 := "eb6ad8ba8b5bf1a14fb1a1a75cbbee8b25f09145909dd448f2ba97a2e6bec256"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PROFILE_ID := "compact_sedan"
const FIXED_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 4
const MEASURE_TICKS := 120
const START_SPEED_MPS := 12.0
const WALL_SOURCE_ID := "building-original-42"
const WALL_SOURCE_INDEX := 14
const PEER_VEHICLE_ID := "bridge-peer-vehicle"
const PEER_LIFE_GENERATION := 2

class ContactBridgeProbeBody:
	extends NativeVehicleBody
	var bridge = Bridge.new()
	var bridge_tick := 0
	var self_ref: Dictionary
	var expected_runtime_id := 0
	var expected_normal_world := Vector3.ZERO
	var expected_kind := ""
	var invalid_collect_count := 0
	var cap_status_mismatch_count := 0
	var identity_gap_tick_count := 0
	var manifold_gap_tick_count := 0
	var collection_gap_tick_count := 0
	var raw_point_total := 0
	var admitted_point_total := 0
	var proposal_tick_count := 0
	var maximum_raw_points := 0
	var wrong_counterpart_count := 0
	var wrong_kind_count := 0
	var nonfinite_row_count := 0
	var minimum_normal_world_dot := INF
	var minimum_impulse_normal_dot := INF
	var first_proposal_tick := -1
	var first_proposal: Dictionary = {}
	var first_nonzero_tick := -1
	var first_nonzero_proposal: Dictionary = {}
	var cap_gap_seen := false
	var last_result_valid := false
	var last_result_complete := false
	var last_proposal_count := 0
	var last_identity_gap := false
	var last_counterpart_wire: Dictionary = {}
	var inject_invalid_first_frame := false

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		bridge_tick += 1
		var com_world := state.transform * state.center_of_mass_local
		var collect_self_ref := self_ref
		var collect_frame := state.transform
		if inject_invalid_first_frame and bridge_tick == 1:
			collect_self_ref = {"vehicle_id": "must-not-bind", "life_generation": 99}
			collect_frame = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), state.transform.origin)
		var result: Dictionary = bridge.collect(state, collect_self_ref, bridge_tick, collect_frame, com_world)
		last_result_valid = bool(result.valid)
		last_result_complete = bool(result.get("complete", false))
		last_proposal_count = 0
		last_identity_gap = false
		last_counterpart_wire = {}
		if not bool(result.valid):
			invalid_collect_count += 1
			return
		var status: Dictionary = result.status
		last_proposal_count = (result.proposals as Array).size()
		last_identity_gap = bool(status.collection_identity_gap)
		if last_proposal_count > 0:
			last_counterpart_wire = (result.proposals as Array)[0].counterpart_wire.duplicate(true)
		var raw_count := int(status.raw_state_contact_count)
		raw_point_total += int(status.processed_point_count)
		admitted_point_total += int(status.admitted_point_count)
		maximum_raw_points = maxi(maximum_raw_points, raw_count)
		var cap_gap := bool(status.collection_cap_gap)
		cap_gap_seen = cap_gap_seen or cap_gap
		if cap_gap != (raw_count >= Bridge.POINT_CAPACITY):
			cap_status_mismatch_count += 1
		if bool(status.collection_identity_gap):
			identity_gap_tick_count += 1
		if bool(status.collection_manifold_gap):
			manifold_gap_tick_count += 1
		if bool(status.collection_gap):
			collection_gap_tick_count += 1
		for row: Dictionary in result.proposals:
			proposal_tick_count += 1
			if int(row.counterpart_runtime_id) != expected_runtime_id:
				wrong_counterpart_count += 1
			var wire: Dictionary = row.counterpart_wire
			if str(wire.get("kind", "")) != expected_kind:
				wrong_kind_count += 1
			var point: Vector3 = row.point_world_m
			var normal: Vector3 = row.normal_on_self_world
			var impulse: Vector3 = row.body_impulse_world_ns
			var relative: Vector3 = row.relative_velocity_at_peak_world_mps
			if not point.is_finite() or not normal.is_finite() or not impulse.is_finite() or not relative.is_finite():
				nonfinite_row_count += 1
				continue
			minimum_normal_world_dot = minf(minimum_normal_world_dot, normal.dot(expected_normal_world))
			minimum_impulse_normal_dot = minf(minimum_impulse_normal_dot, impulse.dot(normal))
			if first_proposal_tick < 0:
				first_proposal_tick = bridge_tick
				first_proposal = row.duplicate(true)
			if first_nonzero_tick < 0 and impulse.length() > 0.000001:
				first_nonzero_tick = bridge_tick
				first_nonzero_proposal = row.duplicate(true)

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	Engine.physics_ticks_per_second = FIXED_TICKS_PER_SECOND
	call_deferred("run")

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

func add_wall(world: Node3D, target_transform: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.transform = target_transform
	wall.set_meta("source_id", WALL_SOURCE_ID)
	wall.set_meta("source_index", WALL_SOURCE_INDEX)
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 20.0, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func add_vehicle_peer(world: Node3D, target_transform: Transform3D) -> RigidBody3D:
	return add_vehicle_peer_identity(world, target_transform, PEER_VEHICLE_ID, PEER_LIFE_GENERATION)

func add_vehicle_peer_identity(world: Node3D, target_transform: Transform3D,
		vehicle_id: String, life_generation: int) -> RigidBody3D:
	var peer := RigidBody3D.new()
	peer.transform = target_transform
	peer.freeze = true
	peer.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	peer.set_meta("vehicle_id", vehicle_id)
	peer.set_meta("life_generation", life_generation)
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 8.0, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	peer.add_child(collision)
	world.add_child(peer)
	return peer

func add_unbound_wall(world: Node3D, target_transform: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.transform = target_transform
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 20.0, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func add_probe(world: Node3D, descriptor: Dictionary, target_origin: Vector3, basis: Basis,
		target_runtime_id: int, expected_kind: String) -> ContactBridgeProbeBody:
	var body := ContactBridgeProbeBody.new()
	if not body.configure(descriptor):
		body.free()
		return null
	var expected_normal := (basis * Vector3.BACK).normalized()
	var approach_forward := -expected_normal
	body.transform = Transform3D(basis, target_origin - approach_forward * 8.0)
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.self_ref = {"vehicle_id": descriptor.vehicle_id, "life_generation": descriptor.life_generation}
	body.expected_runtime_id = target_runtime_id
	body.expected_normal_world = expected_normal
	body.expected_kind = expected_kind
	world.add_child(body)
	return body

func check_common_probe(body: ContactBridgeProbeBody, label: String) -> void:
	check(body.invalid_collect_count == 0, "%s bridge calls valid" % label)
	check(body.last_result_valid and body.last_result_complete,
		"%s valid complete result is safe for proposal consumption" % label)
	check(body.raw_point_total > 0 and body.admitted_point_total == body.raw_point_total,
		"%s admits every bounded raw point" % label)
	check(body.maximum_raw_points > 0 and body.maximum_raw_points <= Bridge.POINT_CAPACITY,
		"%s raw point count bounded to eight" % label)
	check(body.cap_status_mismatch_count == 0,
		"%s conservative cap gap exactly follows contact_count >= capacity" % label)
	check(body.identity_gap_tick_count == 0 and body.manifold_gap_tick_count == 0,
		"%s has no identity or manifold collection gap" % label)
	check(body.wrong_counterpart_count == 0 and body.wrong_kind_count == 0,
		"%s runtime lookup and wire kind remain separate and exact" % label)
	check(body.nonfinite_row_count == 0 and body.minimum_normal_world_dot > 0.95,
		"%s proposal coordinates and normal-on-self are finite world values" % label)
	check(body.first_proposal_tick >= 0 and not body.first_proposal.is_empty(),
		"%s emits at least one directed proposal" % label)
	if body.first_proposal.is_empty():
		return
	check((body.first_proposal.get("body_impulse_world_ns", Vector3.INF) as Vector3).length() <= 0.000001
		and float(body.first_proposal.get("peak_closing_speed_mps", 0.0)) > 5.0,
		"%s preserves zero-J onset closing from paired contact velocities" % label)
	var later_impulse: Vector3 = body.first_nonzero_proposal.get("body_impulse_world_ns", Vector3.ZERO)
	var later_normal: Vector3 = body.first_nonzero_proposal.get("normal_on_self_world", Vector3.ZERO)
	check(body.first_nonzero_tick > body.first_proposal_tick and later_normal.length_squared() > 0.0
		and later_impulse.dot(later_normal) >= 0.0,
		"%s later impulse is directed along normal-on-self" % label)
	var first: Dictionary = body.first_proposal
	check(bool(first.get("directed", false)) and not bool(first.get("fleet_canonical", true))
		and bool(first.get("proposal_only", false)) and not bool(first.get("server_admissible", true))
		and not bool(first.get("engine_authoritative", true)),
		"%s row remains directed proposal without engine authority" % label)
	check(first.get("temporal_alignment") == "contact_api_observation_only"
		and not first.has("energy_j") and not first.has("mass_delta_velocity_ns"),
		"%s row makes no energy or full momentum chronology claim" % label)
	var wire: Dictionary = first.get("counterpart_wire", {})
	check(not wire.has("runtime_id") and not wire.has("counterpart_runtime_id"),
		"%s wire identity excludes runtime object id" % label)
	check(body.bridge.cache_miss_total == 1 and body.bridge.cache_hit_total == body.raw_point_total - 1,
		"%s fixed cold identity cache resolves once then hits" % label)

func run() -> void:
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd") == BRIDGE_SHA256,
		"exact bridge source receipt")
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256, "frozen production body receipt")
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_manifold.gd") == MANIFOLD_SHA256,
		"exact owned manifold receipt")
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_identity.gd") == IDENTITY_SHA256,
		"exact strict identity adapter receipt")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	check(parsed is Dictionary, "transport descriptors parse")
	if not parsed is Dictionary:
		print_result({}, {})
		return
	var rows: Array = (parsed as Dictionary).get("profiles", [])
	var wall_descriptor := descriptor_for(rows, "bridge-wall-probe")
	var peer_descriptor := descriptor_for(rows, "bridge-peer-probe")
	var invalid_descriptor := descriptor_for(rows, "bridge-invalid-probe")
	var spoof_descriptor := descriptor_for(rows, "bridge-spoof-probe")
	check(not wall_descriptor.is_empty() and not peer_descriptor.is_empty()
		and not invalid_descriptor.is_empty() and not spoof_descriptor.is_empty(),
		"probe descriptors available")

	var world := Node3D.new()
	root.add_child(world)
	var wall_yaw := 0.61
	var wall_basis := Basis(Vector3.UP, wall_yaw)
	var wall_origin := Vector3(25.0, 5.0, -18.0)
	var wall := add_wall(world, Transform3D(wall_basis, wall_origin))
	var peer_yaw := -0.43
	var peer_basis := Basis(Vector3.UP, peer_yaw)
	var peer_origin := Vector3(-35.0, 5.0, 28.0)
	var peer := add_vehicle_peer(world, Transform3D(peer_basis, peer_origin))
	var invalid_yaw := 0.19
	var invalid_basis := Basis(Vector3.UP, invalid_yaw)
	var invalid_origin := Vector3(65.0, 5.0, 32.0)
	var unbound_wall := add_unbound_wall(world, Transform3D(invalid_basis, invalid_origin))
	var spoof_yaw := -0.27
	var spoof_basis := Basis(Vector3.UP, spoof_yaw)
	var spoof_origin := Vector3(85.0, 5.0, -34.0)
	var spoof_peer := add_vehicle_peer_identity(world, Transform3D(spoof_basis, spoof_origin),
		"bridge-spoof-probe", 1)
	var wall_probe := add_probe(world, wall_descriptor, wall_origin, wall_basis,
		wall.get_instance_id(), "static")
	var peer_probe := add_probe(world, peer_descriptor, peer_origin, peer_basis,
		peer.get_instance_id(), "vehicle")
	var invalid_probe := add_probe(world, invalid_descriptor, invalid_origin, invalid_basis,
		unbound_wall.get_instance_id(), "static")
	var spoof_probe := add_probe(world, spoof_descriptor, spoof_origin, spoof_basis,
		spoof_peer.get_instance_id(), "vehicle")
	if invalid_probe != null:
		invalid_probe.inject_invalid_first_frame = true
	check(wall_probe != null and peer_probe != null and invalid_probe != null and spoof_probe != null,
		"actual native probe bodies configure")
	if wall_probe == null or peer_probe == null or invalid_probe == null or spoof_probe == null:
		world.free()
		print_result({}, {})
		return
	for _tick in SETTLE_TICKS:
		await physics_frame
	wall_probe.linear_velocity = -wall_probe.expected_normal_world * START_SPEED_MPS
	peer_probe.linear_velocity = -peer_probe.expected_normal_world * START_SPEED_MPS
	invalid_probe.linear_velocity = -invalid_probe.expected_normal_world * START_SPEED_MPS
	spoof_probe.linear_velocity = -spoof_probe.expected_normal_world * START_SPEED_MPS
	wall_probe.angular_velocity = Vector3.ZERO
	peer_probe.angular_velocity = Vector3.ZERO
	invalid_probe.angular_velocity = Vector3.ZERO
	spoof_probe.angular_velocity = Vector3.ZERO
	for _tick in MEASURE_TICKS:
		await physics_frame

	check_common_probe(wall_probe, "static wall")
	check_common_probe(peer_probe, "vehicle peer")
	var wall_wire: Dictionary = wall_probe.first_proposal.get("counterpart_wire", {})
	check(wall_wire.get("kind") == "static" and wall_wire.get("source_id") == WALL_SOURCE_ID
		and wall_wire.get("source_index") == WALL_SOURCE_INDEX,
		"static wire identity preserves strict source id and index")
	var peer_wire: Dictionary = peer_probe.first_proposal.get("counterpart_wire", {})
	check(peer_wire.get("kind") == "vehicle" and peer_wire.get("vehicle_id") == PEER_VEHICLE_ID
		and peer_wire.get("life_generation") == PEER_LIFE_GENERATION,
		"vehicle wire identity preserves vehicle id and life generation")
	check(wall_probe.raw_point_total == 311,
		"rotated static wall retains reviewed 311-point actual contact trace")
	check(invalid_probe.raw_point_total > 0 and invalid_probe.admitted_point_total == 0
		and invalid_probe.proposal_tick_count == 0,
		"unbound static collider fails closed without a proposal")
	check(invalid_probe.identity_gap_tick_count > 0 and invalid_probe.collection_gap_tick_count > 0
		and invalid_probe.bridge.identity_rejected_point_total == invalid_probe.raw_point_total,
		"unbound static points report explicit identity collection gaps")
	check(invalid_probe.bridge.cache_miss_total == invalid_probe.identity_gap_tick_count
		and invalid_probe.bridge.cache_hit_total == invalid_probe.raw_point_total
			- invalid_probe.identity_gap_tick_count,
		"rejected identity is cached within a manifold tick and retried on the next tick")
	check(spoof_probe.raw_point_total > 0 and spoof_probe.admitted_point_total == 0
		and spoof_probe.proposal_tick_count == 0,
		"same vehicle id and life peer is rejected before manifold observation")
	check(spoof_probe.identity_gap_tick_count > 0 and spoof_probe.collection_gap_tick_count > 0
		and spoof_probe.bridge.self_identity_rejected_point_total == spoof_probe.raw_point_total
		and spoof_probe.bridge.identity_rejected_point_total == spoof_probe.raw_point_total,
		"self-identity impostor reports an explicit identity gap for every point")
	check(spoof_probe.last_result_valid and not spoof_probe.last_result_complete,
		"valid inputs with identity gap return complete false")
	check(invalid_probe.invalid_collect_count == 1 and invalid_probe.bridge.collect_invalid_total == 1,
		"invalid first frame does not bind its supplied false self identity")
	check(wall_probe.drain_contact_receipts().is_empty(),
		"production collector still drops static source contact; bridge remains separate")
	var wall_metrics := probe_metrics(wall_probe)
	var peer_metrics := probe_metrics(peer_probe)
	var invalid_metrics := probe_metrics(invalid_probe)
	peer.set_meta("life_generation", 3)
	await physics_frame
	check(peer_probe.last_result_valid and peer_probe.last_identity_gap
		and peer_probe.last_proposal_count == 0 and peer_probe.bridge.identity_mutation_total == 1,
		"same runtime vehicle life mutation fails closed without stale wire metadata")
	await physics_frame
	check(peer_probe.last_proposal_count > 0
		and peer_probe.last_counterpart_wire.get("life_generation") == 3
		and peer_probe.bridge.cache_miss_total == 2,
		"vehicle life mutation refreshes as a new typed cold-cache snapshot")
	peer.set_meta("vehicle_id", "bridge-peer-vehicle-v2")
	await physics_frame
	check(peer_probe.last_identity_gap and peer_probe.last_proposal_count == 0
		and peer_probe.bridge.identity_mutation_total == 2,
		"same runtime vehicle id mutation also fails closed")
	await physics_frame
	check(peer_probe.last_proposal_count > 0
		and peer_probe.last_counterpart_wire.get("vehicle_id") == "bridge-peer-vehicle-v2"
		and peer_probe.bridge.cache_miss_total == 3,
		"vehicle id mutation cold-refreshes without emitting stale wire id")
	wall.set_meta("source_index", WALL_SOURCE_INDEX + 1)
	await physics_frame
	check(wall_probe.last_identity_gap and wall_probe.last_proposal_count == 0
		and wall_probe.bridge.identity_mutation_total == 1,
		"same runtime static source mutation invalidates immutable cached identity")
	await physics_frame
	check(wall_probe.last_proposal_count > 0
		and wall_probe.last_counterpart_wire.get("source_index") == WALL_SOURCE_INDEX + 1
		and wall_probe.bridge.cache_miss_total == 2,
		"static source mutation requires a fresh typed cold-cache snapshot")
	var wall_invalid_before_life_change := wall_probe.invalid_collect_count
	wall_probe.self_ref = {"vehicle_id": "bridge-wall-probe", "life_generation": 2}
	await physics_frame
	check(wall_probe.invalid_collect_count == wall_invalid_before_life_change + 1
		and wall_probe.bridge.collect_invalid_total == 1,
		"self lifetime change fails closed until explicit bridge reset")
	wall_probe.bridge.reset_lifetime()
	await physics_frame
	check(wall_probe.invalid_collect_count == wall_invalid_before_life_change + 1
		and wall_probe.bridge.collect_invalid_total == 0
		and wall_probe.bridge.cache_miss_total == 1,
		"explicit lifetime reset admits new self life and rebuilds cold identity cache")
	wall_probe.bridge.reset_lifetime()
	peer_probe.bridge.reset_lifetime()
	invalid_probe.bridge.reset_lifetime()
	spoof_probe.bridge.reset_lifetime()
	check(wall_probe.bridge.cache_entry_count() == 0 and wall_probe.bridge.cache_hit_total == 0
		and wall_probe.bridge.cache_miss_total == 0,
		"wall bridge lifetime reset invalidates cold identity cache and totals")
	check(peer_probe.bridge.cache_entry_count() == 0 and peer_probe.bridge.cache_hit_total == 0
		and peer_probe.bridge.cache_miss_total == 0,
		"peer bridge lifetime reset invalidates cold identity cache and totals")
	check(invalid_probe.bridge.cache_entry_count() == 0
		and invalid_probe.bridge.identity_rejected_point_total == 0,
		"rejected identity cache is reusable and cleared by lifetime reset")
	check(spoof_probe.bridge.cache_entry_count() == 0
		and spoof_probe.bridge.self_identity_rejected_point_total == 0,
		"self-identity rejection totals and cache clear on lifetime reset")
	check_cold_cache_bounds()

	wall_probe.free()
	peer_probe.free()
	invalid_probe.free()
	spoof_probe.free()
	wall.free()
	peer.free()
	unbound_wall.free()
	spoof_peer.free()
	world.free()
	print_result(wall_metrics, peer_metrics, invalid_metrics)

func check_cold_cache_bounds() -> void:
	var cache_bridge = Bridge.new()
	var identities: Array[StaticBody3D] = []
	for index in Bridge.CACHE_CAPACITY + 1:
		var body := StaticBody3D.new()
		body.set_meta("source_id", "cache-source-%d" % index)
		body.set_meta("source_index", index)
		identities.append(body)
		var slot: int = cache_bridge._identity_slot(body, body.get_instance_id())
		check(slot >= 0, "cold cache identity %d receives a bounded slot" % index)
		if index < Bridge.CACHE_CAPACITY:
			check(cache_bridge.cache_entry_count() == index + 1
				and cache_bridge.cache_eviction_total == 0,
				"cold cache retains distinct identity %d without eviction" % index)
	check(cache_bridge.cache_entry_count() == Bridge.CACHE_CAPACITY
		and cache_bridge.cache_eviction_total == 1,
		"ninth distinct identity evicts exactly one of eight fixed slots")
	for body: StaticBody3D in identities:
		body.free()

	var reuse_bridge = Bridge.new()
	var invalid := StaticBody3D.new()
	var invalid_slot: int = reuse_bridge._identity_slot(invalid, invalid.get_instance_id())
	check(invalid_slot == 0 and reuse_bridge.cache_entry_count() == 1
		and reuse_bridge.cache_eviction_total == 0,
		"rejected cold identity occupies one bounded within-collection slot")
	reuse_bridge._expire_rejected_cache_slots()
	check(reuse_bridge.cache_entry_count() == 0,
		"expired rejected identity releases its slot for next collection")
	var replacement := StaticBody3D.new()
	replacement.set_meta("source_id", "cache-replacement")
	replacement.set_meta("source_index", 99)
	var replacement_slot: int = reuse_bridge._identity_slot(replacement, replacement.get_instance_id())
	check(replacement_slot == invalid_slot and reuse_bridge.cache_entry_count() == 1
		and reuse_bridge.cache_eviction_total == 0,
		"released cache slot is reused without eviction or capacity growth")
	invalid.free()
	replacement.free()

func probe_metrics(body: ContactBridgeProbeBody) -> Dictionary:
	return {"raw_point_total": body.raw_point_total,
		"admitted_point_total": body.admitted_point_total,
		"maximum_raw_points": body.maximum_raw_points,
		"proposal_tick_count": body.proposal_tick_count,
		"first_proposal_tick": body.first_proposal_tick,
		"first_nonzero_tick": body.first_nonzero_tick,
		"first_peak_closing_speed_mps": body.first_proposal.get("peak_closing_speed_mps"),
		"first_impulse_world_ns": body.first_proposal.get("body_impulse_world_ns"),
		"first_nonzero_impulse_world_ns": body.first_nonzero_proposal.get("body_impulse_world_ns"),
		"minimum_normal_world_dot": body.minimum_normal_world_dot,
		"minimum_impulse_normal_dot": body.minimum_impulse_normal_dot,
		"cap_gap_seen": body.cap_gap_seen,
		"collection_gap_tick_count": body.collection_gap_tick_count,
		"nonfinite_row_count": body.nonfinite_row_count,
		"wrong_counterpart_count": body.wrong_counterpart_count,
		"wrong_kind_count": body.wrong_kind_count,
		"cache_hit_total": body.bridge.cache_hit_total,
		"cache_miss_total": body.bridge.cache_miss_total,
		"clipped_normal_total": body.bridge.clipped_normal_total()}

func print_result(wall_metrics: Dictionary, peer_metrics: Dictionary,
		invalid_metrics: Dictionary = {}) -> void:
	print("NATIVE_VEHICLE_CONTACT_STATE_BRIDGE_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failure_count": failures.size(),
		"failures": failures,
		"bridge_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd"),
		"production_sha256": FileAccess.get_sha256(PRODUCTION_BODY),
		"point_capacity": Bridge.POINT_CAPACITY,
		"counterpart_capacity": Bridge.COUNTERPART_CAPACITY,
		"cap8_actual_coverage": "NOT_TESTED_actual_fixture_max_4",
		"wall": wall_metrics,
		"vehicle_peer": peer_metrics,
		"unbound_static": invalid_metrics,
		"runtime_wired": false,
		"qualification": "component-only actual direct-state bridge; directed proposals, no ledger/dedup, fleet canonicalization, HP, visual, main, GPU, LIVE or Git mutation",
	}))
	quit(0 if failures.is_empty() else 1)
