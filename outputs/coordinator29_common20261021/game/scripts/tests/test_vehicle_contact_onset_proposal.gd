extends SceneTree

const Packed = preload("res://scripts/vehicle_physics/vehicle_contact_packed_observation.gd")
const Frozen = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")
const Onset = preload("res://scripts/vehicle_physics/vehicle_contact_onset_proposal.gd")

class Probe:
	extends RigidBody3D
	var packed = Packed.new()
	var frozen = Frozen.new()
	var onset = Onset.new()
	var tick := 0
	var onset_rows: Array[Dictionary] = []
	var packed_total_us: Array[int] = []
	var frozen_reference_us: Array[int] = []
	var cap_proposals := 0
	var cap_ticks := 0
	var hold_position := false

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		tick += 1
		var self_ref := {"vehicle_id": "onset-probe", "life_generation": 2}
		var begin := Time.get_ticks_usec()
		packed.collect_into(state, self_ref, tick)
		var proposal: Variant = onset.scan(packed, Onset.BRANCH_ACTIVE_STATIC)
		packed_total_us.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		var legacy: Dictionary = frozen.collect(state, self_ref, tick)
		var reference_peak := 0.0
		if legacy.valid and legacy.complete:
			for row in legacy.rows:
				reference_peak = maxf(reference_peak, row.closing_speed_along_normal_mps)
		frozen_reference_us.append(Time.get_ticks_usec() - begin)
		if proposal != null:
			onset_rows.append(proposal)
			if packed.collection_cap_gap:
				cap_proposals += 1
		if packed.collection_cap_gap:
			cap_ticks += 1
		if hold_position:
			state.transform = Transform3D.IDENTITY
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func fixture(tick: int, closing: float, life: int = 2) -> RefCounted:
	var o = Packed.new()
	o.valid = true
	o.complete = true
	o.collection_gap = false
	o.global_physics_tick = tick
	o.raw_state_contact_count = 1
	o.retained_contact_count = 1
	o.self_identity = {"valid": true, "kind": "vehicle", "vehicle_id": "test-car", "life_generation": life}
	o.target_root_frame_world = Transform3D(Basis(Vector3.UP, 0.61), Vector3(25, 5, -18))
	o.raw_indices[0] = 0
	o.counterpart_runtime_ids[0] = 42
	o.peer_identities[0] = {"valid": true, "kind": "static", "source_id": "wall", "source_index": 3, "counterpart_runtime_id": 42}
	o.points_self_world[0] = o.target_root_frame_world * Vector3(0.5, 0, -2)
	o.normals_on_self_world[0] = o.target_root_frame_world.basis * Vector3.BACK
	o.velocities_self_world[0] = -o.normals_on_self_world[0] * closing
	o.velocities_counterpart_world[0] = Vector3.ZERO
	o.relative_velocities_world[0] = o.velocities_self_world[0]
	o.closing_speeds_mps[0] = closing
	o.impulses_on_self_world_ns[0] = Vector3.ZERO
	o.row_valid[0] = 1
	return o

func make_box(parent: Node3D, at: Transform3D, size: Vector3, index: int) -> void:
	var body := StaticBody3D.new()
	body.transform = at
	body.set_meta("source_id", "onset-wall")
	body.set_meta("source_index", index)
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

func percentile(samples: Array[int], fraction: float) -> int:
	if samples.is_empty():
		return 0
	var ordered := samples.duplicate()
	ordered.sort()
	return ordered[mini(ordered.size() - 1, int(ceil(float(ordered.size()) * fraction)) - 1)]

func run() -> void:
	var latch = Onset.new()
	var first := fixture(1, 7.5)
	var emitted: Dictionary = latch.scan(first, Onset.BRANCH_ACTIVE_STATIC)
	check(emitted != null and emitted.impulse_on_self_world_ns_at_onset == Vector3.ZERO and absf(float(emitted.tentative_active_static_impact_speed_mps) - 7.5) < 0.001, "zero-J onset captured")
	check(emitted.point_target_root_local_m.distance_to(Vector3(0.5, 0, -2)) < 0.0001 and emitted.outward_target_root_local.distance_to(Vector3.FORWARD) < 0.0001, "rotated root-local self point and outward normal")
	check(latch.scan(fixture(2, 7.0), Onset.BRANCH_ACTIVE_STATIC) == null, "resting episode does not replay")
	check(latch.scan(fixture(3, 0.0), Onset.BRANCH_ACTIVE_STATIC) == null, "low closing rearms")
	check(latch.scan(fixture(4, 5.0), Onset.BRANCH_ACTIVE_STATIC) != null, "second genuine closing emits")
	var capped := fixture(5, 6.0)
	capped.raw_state_contact_count = 8
	capped.retained_contact_count = 8
	capped.collection_cap_gap = true
	capped.collection_gap = true
	capped.complete = false
	check(latch.scan(capped, Onset.BRANCH_ACTIVE_STATIC) == null, "cap fails closed")
	check(latch.scan(fixture(6, 6.0), Onset.BRANCH_ACTIVE_STATIC) == null, "post-gap first complete callback rebases")
	check(latch.scan(fixture(7, 0.0), Onset.BRANCH_ACTIVE_STATIC) == null, "post-gap low closing rearms")
	check(latch.scan(fixture(8, 6.0), Onset.BRANCH_ACTIVE_STATIC) != null, "post-gap re-impact")
	var stale := fixture(9, 8.0)
	stale.retained_contact_count = 0
	stale.raw_state_contact_count = 0
	check(latch.scan(stale, Onset.BRANCH_ACTIVE_STATIC) == null, "stale unused slot ignored")
	check(latch.scan(fixture(10, 6.0), Onset.BRANCH_ACTIVE_STATIC) != null, "return after absent callback is new episode")
	var malformed := fixture(11, 6.0)
	malformed.relative_velocities_world[0] = Vector3.ZERO
	check(latch.scan(malformed, Onset.BRANCH_ACTIVE_STATIC) == null, "incoherent same-row kinematics rejected")
	check(latch.scan(fixture(12, 6.0), Onset.BRANCH_ACTIVE_STATIC) == null, "malformed row forces rebaseline")
	var passive = Onset.new().scan(fixture(1, 6.0), Onset.BRANCH_PASSIVE_STATIC)
	check(passive != null and not passive.has("tentative_active_static_impact_speed_mps") and not passive.has("impactSpeed"), "passive cannot claim impact speed")
	var peer_row := fixture(1, 6.0)
	peer_row.peer_identities[0] = {"valid": true, "kind": "vehicle", "vehicle_id": "other", "life_generation": 8, "counterpart_runtime_id": 42}
	var peer = Onset.new().scan(peer_row, Onset.BRANCH_PEER)
	check(peer != null and not peer.has("tentative_active_static_impact_speed_mps") and not peer.has("impactSpeed"), "peer cannot claim impact speed")
	check(Onset.new().scan(peer_row, Onset.BRANCH_ACTIVE_STATIC) == null, "branch/peer mismatch rejected")
	check(Onset.new().scan(fixture(1, 6.0, 3), Onset.BRANCH_ACTIVE_STATIC) != null, "new target life starts distinct latch")
	var tied := fixture(1, 6.0)
	tied.raw_state_contact_count = 2
	tied.retained_contact_count = 2
	tied.raw_indices[1] = 1
	tied.counterpart_runtime_ids[1] = 41
	tied.peer_identities[1] = {"valid": true, "kind": "static", "source_id": "second-wall", "source_index": 4, "counterpart_runtime_id": 41}
	tied.points_self_world[1] = tied.points_self_world[0]
	tied.normals_on_self_world[1] = tied.normals_on_self_world[0]
	tied.velocities_self_world[1] = tied.velocities_self_world[0]
	tied.velocities_counterpart_world[1] = tied.velocities_counterpart_world[0]
	tied.relative_velocities_world[1] = tied.relative_velocities_world[0]
	tied.closing_speeds_mps[1] = tied.closing_speeds_mps[0]
	tied.impulses_on_self_world_ns[1] = Vector3.ZERO
	tied.row_valid[1] = 1
	var tie_winner: Dictionary = Onset.new().scan(tied, Onset.BRANCH_ACTIVE_STATIC)
	check(tie_winner != null and tie_winner.counterpart_runtime_id == 41, "equal-speed tie uses smallest peer runtime ID")
	tied.counterpart_runtime_ids[1] = 42
	tied.peer_identities[1].counterpart_runtime_id = 42
	check(Onset.new().scan(tied, Onset.BRANCH_ACTIVE_STATIC) == null, "conflicting same-runtime peer identity rejected")
	var milestone = Onset.new()
	check(milestone.scan(fixture(1, 2.1), Onset.BRANCH_ACTIVE_STATIC) != null, "weak raw onset remains observable")
	check(milestone.scan(fixture(2, 3.0), Onset.BRANCH_ACTIVE_STATIC) != null, "same-contact structural floor crossing is not swallowed")
	check(milestone.scan(fixture(3, 3.2), Onset.BRANCH_ACTIVE_STATIC) == null, "structural floor does not replay")
	var passive_milestone = Onset.new()
	check(passive_milestone.scan(fixture(1, 2.1), Onset.BRANCH_PASSIVE_STATIC) != null, "passive weak onset observed")
	check(passive_milestone.scan(fixture(2, 2.46), Onset.BRANCH_PASSIVE_STATIC) != null, "passive derived-speed damage rounding milestone observed")
	var passive_escalation: Variant = passive_milestone.scan(fixture(3, 2.6), Onset.BRANCH_PASSIVE_STATIC)
	check(passive_escalation != null and not passive_escalation.has("impactSpeed") and not passive_escalation.has("tentative_active_static_impact_speed_mps"), "passive structural milestone retains no source impact-speed claim")
	check(passive_milestone.scan(fixture(4, 2.8), Onset.BRANCH_PASSIVE_STATIC) == null, "passive milestones do not replay")
	var peer_milestone = Onset.new()
	var peer_first := fixture(1, 2.1)
	peer_first.peer_identities[0] = {"valid": true, "kind": "vehicle", "vehicle_id": "other", "life_generation": 1, "counterpart_runtime_id": 42}
	var peer_later := fixture(2, 3.0)
	peer_later.peer_identities[0] = peer_first.peer_identities[0].duplicate(true)
	check(peer_milestone.scan(peer_first, Onset.BRANCH_PEER) != null and peer_milestone.scan(peer_later, Onset.BRANCH_PEER) == null, "peer has no invented source-speed threshold escalation")
	var world := Node3D.new()
	root.add_child(world)
	var basis := Basis(Vector3.UP, 0.61)
	var origin := Vector3(25, 5, -18)
	make_box(world, Transform3D(basis, origin), Vector3(20, 20, 0.5), 1)
	var wall := make_probe(world, Transform3D(basis, origin + basis * Vector3.BACK * 7))
	for _i in 3:
		await physics_frame
	wall.linear_velocity = basis * Vector3.FORWARD * 12
	for _i in 115:
		await physics_frame
	check(wall.onset_rows.size() > 0, "actual rotated Godot callback yielded onset")
	var actual_zero_j := false
	for row in wall.onset_rows:
		if row.impulse_on_self_world_ns_at_onset == Vector3.ZERO and row.closing_speed_along_normal_mps > 2.0:
			actual_zero_j = true
	check(actual_zero_j, "actual first closing onset had zero impulse")
	var wall_onset_count := wall.onset_rows.size()
	var wall_cost := {"n": wall.packed_total_us.size(), "packed_selector_p50_us": percentile(wall.packed_total_us, 0.5), "packed_selector_p95_us": percentile(wall.packed_total_us, 0.95), "frozen_reference_p50_us": percentile(wall.frozen_reference_us, 0.5), "frozen_reference_p95_us": percentile(wall.frozen_reference_us, 0.95)}
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
		make_box(cap_world, Transform3D(Basis.IDENTITY, Vector3(x, 0, z)), Vector3(0.32, 1, 0.32), index)
	for _i in 75:
		await physics_frame
	check(cap.cap_ticks > 0 and cap.cap_proposals == 0, "actual eight-contact cap emits nothing")
	print("CONTACT_ONSET_REPORT ", JSON.stringify({"checks": checks, "failures": failures, "wall_onsets": wall_onset_count, "wall_cost": wall_cost, "cap_ticks": cap.cap_ticks, "cap_cost": {"packed_selector_p50_us": percentile(cap.packed_total_us, 0.5), "packed_selector_p95_us": percentile(cap.packed_total_us, 0.95), "frozen_reference_p50_us": percentile(cap.frozen_reference_us, 0.5), "frozen_reference_p95_us": percentile(cap.frozen_reference_us, 0.95)}}))
	cap_world.queue_free()
	quit(0 if failures.is_empty() else 1)
