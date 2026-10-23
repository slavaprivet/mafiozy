extends SceneTree
const Manifold = preload("res://scripts/vehicle_physics/vehicle_contact_manifold.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var aggregate := Manifold.new(2)
	check(aggregate.begin_tick(100), "global tick admitted")
	check(not aggregate.begin_tick(100), "same tick cannot reset collected contacts")
	# A symmetric two-point frontal manifold preserves translation and cancels yaw.
	for side in [-1.0, 1.0]:
		check(aggregate.observe(7, Vector3(side, 0, -2), Vector3(side, 0, -2),
			Vector3.BACK, Vector3(0, 0, 100), Vector3(0, 0, -12), Vector3.ZERO, Vector3.ZERO), "frontal point accepted")
	var row := aggregate.snapshot(0, Transform3D.IDENTITY)
	check(aggregate.count == 1 and row.raw_contact_count == 2, "manifold reduces to one counterpart")
	check(row.body_impulse_world_ns == Vector3(0, 0, 200), "summed vector impulse conserved")
	check(row.body_angular_impulse_world_nms == Vector3.ZERO, "symmetric yaw impulses cancel")
	check(is_equal_approx(row.peak_closing_speed_mps, 12.0), "point closing speed retained")
	check(row.proposal_only and not row.server_admissible, "runtime identity does not become authority")
	# Equal and opposite forces form a pure torque: centroid cross total J loses it.
	check(aggregate.begin_tick(101), "next global tick admitted")
	aggregate.observe(7, Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.BACK * 100, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	aggregate.observe(7, Vector3.LEFT, Vector3.LEFT, Vector3.FORWARD, Vector3.FORWARD * 100, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	row = aggregate.snapshot(0, Transform3D.IDENTITY)
	check(row.body_impulse_world_ns == Vector3.ZERO, "pure torque has zero translation")
	check(row.body_angular_impulse_world_nms == Vector3(0, -200, 0), "per-point moment preserves pure torque")
	check(not row.aggregate_normal_valid, "opposite normal cancellation is explicit")
	check(aggregate.begin_tick(102), "zero impulse onset tick")
	aggregate.observe(7, Vector3.ZERO, Vector3.ZERO, Vector3.BACK, Vector3.ZERO, Vector3(0, 0, -9), Vector3.ZERO, Vector3.ZERO)
	row = aggregate.snapshot(0, Transform3D.IDENTITY)
	check(row.raw_contact_count == 1 and row.peak_closing_speed_mps == 9.0, "zero impulse onset does not lose kinematics")
	check(row.aggregate_normal_valid and row.normal_on_self_world == Vector3.BACK, "zero impulse onset retains valid normal")
	aggregate.observe(8, Vector3.ZERO, Vector3.ZERO, Vector3.UP, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	check(not aggregate.observe(9, Vector3.ZERO, Vector3.ZERO, Vector3.UP, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), "capacity overflow refuses extra counterpart")
	check(aggregate.gap and aggregate.overflow_total == 1 and aggregate.count == 2, "overflow is explicit without overwrite")
	check(not aggregate.observe(7, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), "invalid normal rejected")
	check(not aggregate.snapshot(2, Transform3D.IDENTITY).valid, "out-of-range export rejected")
	check(not aggregate.snapshot(0, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)).valid, "singular local frame rejected")
	aggregate.begin_tick(103)
	aggregate.observe(7, Vector3(3,0,0), Vector3(3,0,0), Vector3.BACK, Vector3.BACK * 10, Vector3.ZERO, Vector3.ZERO, Vector3(2,0,0))
	row = aggregate.snapshot(0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	check(row.body_angular_impulse_world_nms == Vector3(0,-10,0), "displaced COM moment uses actual lever arm")
	check((row.body_impulse_local_ns as Vector3).is_equal_approx(Vector3(-10,0,0)), "rotated body maps world impulse to local axes")
	check(not aggregate.observe(7, Vector3.ZERO, Vector3.ZERO, Vector3.BACK, Vector3.FORWARD, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), "opposing impulse sign rejected")
	row = aggregate.snapshot(0, Transform3D.IDENTITY)
	check(row.invalid_gap and not row.overflow_gap and row.collection_gap, "invalid input gap distinguished from overflow")
	# Solver-scale negative normal noise is projected to the tangent at the
	# inclusive threshold; a physically opposing impulse remains invalid.
	check(aggregate.begin_tick(104), "normal noise threshold tick admitted")
	var noisy_impulse := Vector3(3.0, 4.0, -Manifold.NORMAL_IMPULSE_NOISE_TOLERANCE_NS)
	check(aggregate.observe(7, Vector3.ZERO, Vector3.ZERO, Vector3.BACK, noisy_impulse,
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), "inclusive negative normal tolerance admitted")
	row = aggregate.snapshot(0, Transform3D.IDENTITY)
	var expected_tangent := Vector3(3.0, 4.0, 0.0)
	check((row.body_impulse_world_ns as Vector3).is_equal_approx(expected_tangent)
		and ((row.body_impulse_world_ns as Vector3) - noisy_impulse).is_equal_approx(
			Vector3.BACK * Manifold.NORMAL_IMPULSE_NOISE_TOLERANCE_NS),
		"only negative normal noise is removed and correction magnitude is conserved")
	check(row.clipped_normal_total == 1 and is_equal_approx(row.clipped_normal_ns,
		Manifold.NORMAL_IMPULSE_NOISE_TOLERANCE_NS), "clip count and per-tick correction are explicit")
	check(aggregate.observe(7, Vector3.ZERO, Vector3.ZERO, Vector3.BACK,
		Vector3.BACK * Manifold.NORMAL_IMPULSE_NOISE_TOLERANCE_NS,
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		and aggregate.clipped_normal_total == 1
		and is_equal_approx(aggregate.clipped_normal_ns, Manifold.NORMAL_IMPULSE_NOISE_TOLERANCE_NS),
		"positive normal threshold is admitted without clipping")
	var invalid_before_strict := aggregate.invalid_total
	check(not aggregate.observe(8, Vector3.ZERO, Vector3.ZERO, Vector3.BACK,
		Vector3(3.0, 4.0, -Manifold.NORMAL_IMPULSE_NOISE_TOLERANCE_NS - 0.0000001),
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		and aggregate.invalid_total == invalid_before_strict + 1,
		"impulse below negative normal tolerance remains strict rejection")
	check(aggregate.begin_tick(105) and aggregate.clipped_normal_total == 1
		and aggregate.clipped_normal_ns == 0.0,
		"begin tick preserves lifetime clip count and clears per-tick magnitude")
	aggregate.reset_lifetime()
	check(aggregate.tick == -1 and aggregate.count == 0 and aggregate.overflow_total == 0
		and aggregate.invalid_total == 0 and aggregate.clipped_normal_total == 0
		and aggregate.clipped_normal_ns == 0.0 and not aggregate.gap,
		"lifetime reset clears totals and tick state without reallocating slots")
	var reverse := Manifold.new(2)
	reverse.begin_tick(100)
	for side in [1.0, -1.0]:
		reverse.observe(7, Vector3(side, 0, -2), Vector3(side, 0, -2), Vector3.BACK,
			Vector3(0, 0, 100), Vector3(0, 0, -12), Vector3.ZERO, Vector3.ZERO)
	var reordered := reverse.snapshot(0, Transform3D.IDENTITY)
	check(reordered.body_impulse_world_ns == Vector3(0, 0, 200) and reordered.body_angular_impulse_world_nms == Vector3.ZERO, "point permutation preserves total impulse and torque")
	# Measure a warmed, isolated 72-body / 8-point workload; no snapshots in loop.
	var collectors: Array[RefCounted] = []
	collectors.resize(72)
	for index in 72: collectors[index] = Manifold.new(8)
	var costs := PackedInt64Array()
	costs.resize(16)
	var global_tick := 0
	for round_index in 20:
		var started := Time.get_ticks_usec()
		for batch_tick in 64:
			global_tick += 1
			for collector: RefCounted in collectors:
				collector.begin_tick(global_tick)
				for point_index in 8:
					collector.observe(7, Vector3(point_index * 0.1, 0, -2), Vector3.ZERO,
						Vector3.BACK, Vector3.BACK * 10, Vector3.FORWARD * 12, Vector3.ZERO, Vector3.ZERO)
		var elapsed := Time.get_ticks_usec() - started
		if round_index >= 4: costs[round_index - 4] = elapsed / 64
	costs.sort()
	var peer_costs := PackedInt64Array()
	peer_costs.resize(16)
	for round_index in 20:
		var started := Time.get_ticks_usec()
		for batch_tick in 64:
			global_tick += 1
			for collector: RefCounted in collectors:
				collector.begin_tick(global_tick)
				for peer_index in 8:
					collector.observe(peer_index + 1, Vector3(peer_index * 0.1, 0, -2), Vector3.ZERO,
						Vector3.BACK, Vector3.BACK * 10, Vector3.FORWARD * 12, Vector3.ZERO, Vector3.ZERO)
		var elapsed := Time.get_ticks_usec() - started
		if round_index >= 4: peer_costs[round_index - 4] = elapsed / 64
	peer_costs.sort()
	print("NATIVE_CONTACT_MANIFOLD_TEST ", JSON.stringify({"checks":checks,"failures":failures,
		"passed":failures.is_empty(),"runtime_wired":false,"cpu_72x8points_1peer_p50_us":costs[8],
		"cpu_72x8points_1peer_p95_us":costs[15],"cpu_72x8peers_p50_us":peer_costs[8],
		"cpu_72x8peers_p95_us":peer_costs[15],"qualification":"isolated warmed directed aggregation CPU; no physics callbacks, rendering or FPS"}))
	quit(0 if failures.is_empty() else 1)
