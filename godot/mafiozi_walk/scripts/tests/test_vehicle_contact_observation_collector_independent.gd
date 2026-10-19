extends SceneTree
## Independent negative-boundary review for the frozen coherent raw collector.

const Collector = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")
const COLLECTOR_PATH := "res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd"
const COLLECTOR_SHA256 := "d14946c97ecdb43105d6d760553a7de0151eda64b22e3254b285a94987c759f0"
const FROZEN_BRIDGE := "res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd"
const FROZEN_BRIDGE_SHA256 := "73843ce758381b7911aa432ade0e66cfb9ea96ebd05986f0e9f39bc64a1de1a7"
const FROZEN_MANIFOLD := "res://scripts/vehicle_physics/vehicle_contact_manifold.gd"
const FROZEN_MANIFOLD_SHA256 := "dfe706e678fd64a6ac2d67f27bd659733287ff9aba6e62c6b9343889ba3ed9dd"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const WALL_SOURCE_ID := "independent-coherent-wall"
const WALL_SOURCE_INDEX := 57
const MEASURE_TICKS := 120

class ObservationProbe:
	extends NativeVehicleBody
	var collector = Collector.new()
	var self_ref: Dictionary = {}
	var expected_runtime_id := 0
	var expected_normal_world := Vector3.ZERO
	var expect_bound_identity := false
	var observation_tick := 0
	var invalid_self_checked := false
	var invalid_tick_checked := false
	var invalid_self_failed_closed := false
	var invalid_tick_failed_closed := false
	var contact_envelopes := 0
	var complete_contact_envelopes := 0
	var identity_gap_envelopes := 0
	var invalid_rows := 0
	var frame_mismatches := 0
	var forbidden_field_rows := 0
	var first_contact_tick := -1
	var first_nonzero_impulse_tick := -1
	var first_row: Dictionary = {}
	var first_nonzero_row: Dictionary = {}
	var sibling_copy_checked := false
	var sibling_copy_isolated := false
	var later_export_unmutated := false

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		observation_tick += 1
		if not invalid_self_checked:
			invalid_self_checked = true
			var invalid_self: Dictionary = collector.collect(state,
				{"vehicle_id": "", "life_generation": 0}, observation_tick)
			invalid_self_failed_closed = not bool(invalid_self.get("valid", true)) \
				and not bool(invalid_self.get("complete", true)) \
				and (invalid_self.get("rows", []) as Array).is_empty() \
				and bool((invalid_self.get("status", {}) as Dictionary).get("collection_gap", false))
		if not invalid_tick_checked:
			invalid_tick_checked = true
			var invalid_tick: Dictionary = collector.collect(state, self_ref, -1)
			invalid_tick_failed_closed = not bool(invalid_tick.get("valid", true)) \
				and not bool(invalid_tick.get("complete", true)) \
				and (invalid_tick.get("rows", []) as Array).is_empty() \
				and bool((invalid_tick.get("status", {}) as Dictionary).get("collection_gap", false))

		var frame_at_collect := state.transform
		var envelope: Dictionary = collector.collect(state, self_ref, observation_tick)
		if not bool(envelope.get("valid", false)):
			return
		var rows: Array = envelope.get("rows", [])
		var matching_rows: Array[Dictionary] = []
		for row_value: Variant in rows:
			var row: Dictionary = row_value
			if int(row.get("counterpart_runtime_id", 0)) != expected_runtime_id:
				continue
			matching_rows.append(row)
			if row.get("target_root_frame_world") != frame_at_collect \
					or envelope.get("target_root_frame_world") != frame_at_collect:
				frame_mismatches += 1
			if row.has("impact_speed_mps") or row.has("event_id") \
					or row.has("impact_sequence") or row.has("energy_j") or row.has("hp"):
				forbidden_field_rows += 1
			if not bool(row.get("valid", false)):
				invalid_rows += 1
		if matching_rows.is_empty():
			return

		contact_envelopes += 1
		if bool(envelope.get("complete", false)):
			complete_contact_envelopes += 1
		var status: Dictionary = envelope.get("status", {})
		if bool(status.get("collection_identity_gap", false)):
			identity_gap_envelopes += 1
		if first_contact_tick < 0:
			first_contact_tick = observation_tick
			first_row = matching_rows[0].duplicate(true)
		if first_nonzero_impulse_tick < 0:
			for row: Dictionary in matching_rows:
				if (row.get("impulse_on_self_world_ns", Vector3.ZERO) as Vector3).length() > 0.000001:
					first_nonzero_impulse_tick = observation_tick
					first_nonzero_row = row.duplicate(true)
					break

		if expect_bound_identity and matching_rows.size() >= 2 and not sibling_copy_checked:
			sibling_copy_checked = true
			var first: Dictionary = matching_rows[0]
			var sibling: Dictionary = matching_rows[1]
			var sibling_point: Vector3 = sibling.point_on_self_world_m
			var captured_frame: Transform3D = first.target_root_frame_world
			first.self_identity.vehicle_id = "mutated-row"
			first.peer_identity.source_id = "mutated-peer"
			first.point_on_self_world_m = Vector3(999.0, 999.0, 999.0)
			envelope.self_identity.vehicle_id = "mutated-envelope"
			envelope.target_root_frame_world = Transform3D.IDENTITY
			sibling_copy_isolated = sibling.self_identity.vehicle_id == self_ref.vehicle_id \
				and sibling.peer_identity.source_id == WALL_SOURCE_ID \
				and sibling.point_on_self_world_m == sibling_point \
				and sibling.target_root_frame_world == captured_frame
		elif expect_bound_identity and sibling_copy_checked and not matching_rows.is_empty():
			var current: Dictionary = matching_rows[0]
			later_export_unmutated = current.self_identity.vehicle_id == self_ref.vehicle_id \
				and current.peer_identity.source_id == WALL_SOURCE_ID \
				and current.point_on_self_world_m != Vector3(999.0, 999.0, 999.0)

var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
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

func add_wall(world: Node3D, target_transform: Transform3D, bound_identity: bool) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.transform = target_transform
	if bound_identity:
		wall.set_meta("source_id", WALL_SOURCE_ID)
		wall.set_meta("source_index", WALL_SOURCE_INDEX)
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 20.0, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func add_probe(world: Node3D, descriptor: Dictionary, wall: StaticBody3D,
		wall_origin: Vector3, basis: Basis, bound_identity: bool) -> ObservationProbe:
	var probe := ObservationProbe.new()
	if not probe.configure(descriptor):
		probe.free()
		return null
	var expected_normal := (basis * Vector3.BACK).normalized()
	var approach := -expected_normal
	probe.transform = Transform3D(basis, wall_origin - approach * 8.0)
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	probe.self_ref = {"vehicle_id": descriptor.vehicle_id,
		"life_generation": descriptor.life_generation}
	probe.expected_runtime_id = wall.get_instance_id()
	probe.expected_normal_world = expected_normal
	probe.expect_bound_identity = bound_identity
	world.add_child(probe)
	return probe

func run() -> void:
	check(FileAccess.get_sha256(COLLECTOR_PATH) == COLLECTOR_SHA256,
		"exact frozen collector candidate")
	check(FileAccess.get_sha256(FROZEN_BRIDGE) == FROZEN_BRIDGE_SHA256,
		"frozen contact bridge unchanged")
	check(FileAccess.get_sha256(FROZEN_MANIFOLD) == FROZEN_MANIFOLD_SHA256,
		"frozen manifold unchanged")
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256,
		"frozen native body unchanged")
	var contract: Dictionary = Collector.new().contract()
	check(contract.point_capacity == 8 and bool(contract.raw_rows_not_aggregated),
		"collector remains bounded and raw")
	check(not bool(contract.owns_impact_speed) and not bool(contract.owns_event_identity)
		and not bool(contract.owns_peer_canonicalization) and not bool(contract.owns_cooldown)
		and not bool(contract.owns_crash_or_damage) and not bool(contract.owns_hp)
		and not bool(contract.server_admissible) and not bool(contract.runtime_wired),
		"collector contract owns no impact or authority semantics")
	check(not bool(contract.physics_tick_authoritative)
		and not bool(contract.self_identity_authoritative)
		and contract.closing_speed_semantics == "derived_same_row_point_kinematics_not_source_impact_speed",
		"caller tick/self labels and derived closing remain explicitly non-authoritative")

	var bound_descriptor := descriptor_for("independent-bound-probe", 13)
	var unbound_descriptor := descriptor_for("independent-unbound-probe", 17)
	check(not bound_descriptor.is_empty() and not unbound_descriptor.is_empty(),
		"independent descriptors available")
	if bound_descriptor.is_empty() or unbound_descriptor.is_empty():
		finish(null, null)
		return
	var world := Node3D.new()
	root.add_child(world)
	var bound_yaw := 0.73
	var bound_basis := Basis(Vector3.UP, bound_yaw)
	var bound_origin := Vector3(31.0, 5.0, -22.0)
	var bound_wall := add_wall(world, Transform3D(bound_basis, bound_origin), true)
	var unbound_yaw := -0.49
	var unbound_basis := Basis(Vector3.UP, unbound_yaw)
	var unbound_origin := Vector3(-37.0, 5.0, 26.0)
	var unbound_wall := add_wall(world, Transform3D(unbound_basis, unbound_origin), false)
	var bound_probe := add_probe(world, bound_descriptor, bound_wall, bound_origin, bound_basis, true)
	var unbound_probe := add_probe(world, unbound_descriptor, unbound_wall, unbound_origin,
		unbound_basis, false)
	check(bound_probe != null and unbound_probe != null, "independent actual probes configure")
	if bound_probe == null or unbound_probe == null:
		world.free()
		finish(bound_probe, unbound_probe)
		return
	for _tick in 4:
		await physics_frame
	bound_probe.linear_velocity = -bound_probe.expected_normal_world * 12.0
	unbound_probe.linear_velocity = -unbound_probe.expected_normal_world * 12.0
	for _tick in MEASURE_TICKS:
		await physics_frame

	for probe: ObservationProbe in [bound_probe, unbound_probe]:
		check(probe.invalid_self_failed_closed, "invalid self reference fails closed")
		check(probe.invalid_tick_failed_closed, "negative caller tick fails closed")
		check(probe.frame_mismatches == 0, "each row freezes same-callback target frame")
		check(probe.forbidden_field_rows == 0, "raw rows contain no impact/event/HP authority fields")
		check(probe.first_contact_tick >= 0 and not probe.first_row.is_empty(),
			"actual rotated translated contact observed")
	check(bound_probe.complete_contact_envelopes == bound_probe.contact_envelopes
		and bound_probe.identity_gap_envelopes == 0 and bound_probe.invalid_rows == 0,
		"bound wall observations remain complete and row-valid")
	check(bound_probe.first_row.peer_identity.valid
		and bound_probe.first_row.peer_identity.source_id == WALL_SOURCE_ID
		and bound_probe.first_row.peer_identity.source_index == WALL_SOURCE_INDEX,
		"bound wall carries exact copied static identity")
	check(bound_probe.first_row.normal_on_self_world.normalized().dot(
		bound_probe.expected_normal_world) > 0.95,
		"normal is world-oriented and points onto self")
	check(bound_probe.first_row.impulse_on_self_world_ns.length() <= 0.000001
		and bound_probe.first_row.closing_speed_along_normal_mps > 5.0,
		"same-index onset retains zero J and signed positive closing observation")
	check(bound_probe.first_nonzero_impulse_tick > bound_probe.first_contact_tick
		and not bound_probe.first_nonzero_row.is_empty()
		and bound_probe.first_nonzero_row.impulse_on_self_world_ns.dot(
			bound_probe.first_nonzero_row.normal_on_self_world.normalized()) >= 0.0
		and bound_probe.first_nonzero_row.closing_speed_along_normal_mps < 0.10,
		"later J is separate, points onto self, and cannot replace onset chronology")
	check(bound_probe.sibling_copy_checked and bound_probe.sibling_copy_isolated
		and bound_probe.later_export_unmutated,
		"sibling identities/frame and later exports are isolated from caller mutation")
	check(unbound_probe.identity_gap_envelopes > 0
		and unbound_probe.complete_contact_envelopes == 0
		and unbound_probe.invalid_rows > 0,
		"actual unbound static identity makes every contact envelope incomplete")
	check(not bool(unbound_probe.first_row.peer_identity.get("valid", true))
		and not bool(unbound_probe.first_row.get("valid", true)),
		"unbound actual row is retained only as explicitly invalid evidence")

	finish(bound_probe, unbound_probe)
	bound_probe.free()
	unbound_probe.free()
	bound_wall.free()
	unbound_wall.free()
	world.free()

func finish(bound_probe: ObservationProbe, unbound_probe: ObservationProbe) -> void:
	print("NATIVE_VEHICLE_CONTACT_OBSERVATION_INDEPENDENT_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"collector_sha256": FileAccess.get_sha256(COLLECTOR_PATH),
		"bound_first_tick": bound_probe.first_contact_tick if bound_probe != null else -1,
		"bound_first_nonzero_tick": bound_probe.first_nonzero_impulse_tick if bound_probe != null else -1,
		"unbound_identity_gap_envelopes": unbound_probe.identity_gap_envelopes if unbound_probe != null else 0,
		"runtime_wired": false,
		"qualification": "independent raw-observation admission only; no crash speed, J/m, HP, event authority, runtime, main, GPU or LIVE claim"
	}))
	quit(0 if failures.is_empty() else 1)
