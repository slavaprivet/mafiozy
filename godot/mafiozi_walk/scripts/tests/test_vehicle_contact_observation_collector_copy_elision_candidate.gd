extends SceneTree
## Functional parity is the test exit criterion. Repeated alternating timing is
## reported as a separate noisy qualification and never changes test success.

const Baseline = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")
const Candidate = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector_copy_elision_candidate.gd")
const BASELINE_PATH := "res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd"
const BASELINE_SHA256 := "d14946c97ecdb43105d6d760553a7de0151eda64b22e3254b285a94987c759f0"
const CANDIDATE_PATH := "res://scripts/vehicle_physics/vehicle_contact_observation_collector_copy_elision_candidate.gd"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const FIXED_TICKS_PER_SECOND := 60
const PERF_EPOCHS := 6
const PERF_TICKS_PER_EPOCH := 90

class WallProbe:
	extends NativeVehicleBody
	var baseline = Baseline.new()
	var candidate = Candidate.new()
	var tick := 0
	var wall_runtime_id := 0
	var parity_failures := 0
	var first_contact_tick := -1
	var first_nonzero_tick := -1
	var first_closing := 0.0
	var first_impulse := Vector3.ZERO
	var later_impulse := Vector3.ZERO

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		tick += 1
		var self_ref := {"vehicle_id": "copy-wall-probe", "life_generation": 2}
		var base := baseline.collect(state, self_ref, tick)
		var copy := candidate.collect(state, self_ref, tick)
		if base != copy:
			parity_failures += 1
		for row: Dictionary in copy.rows:
			if int(row.counterpart_runtime_id) != wall_runtime_id:
				continue
			if first_contact_tick < 0:
				first_contact_tick = tick
				first_closing = row.closing_speed_along_normal_mps
				first_impulse = row.impulse_on_self_world_ns
			if first_nonzero_tick < 0 and row.impulse_on_self_world_ns.length() > 0.000001:
				first_nonzero_tick = tick
				later_impulse = row.impulse_on_self_world_ns

class CapProbe:
	extends NativeVehicleBody
	var baseline = Baseline.new()
	var candidate = Candidate.new()
	var tick := 0
	var pinned_transform := Transform3D.IDENTITY
	var parity_failures := 0
	var cap_ticks := 0
	var complete_cap_ticks := 0
	var current_epoch := -1
	var baseline_epochs: Array = []
	var candidate_epochs: Array = []
	var mutation_export_done := false
	var sibling_isolation_ok := false
	var post_mutation_all_indices_ok := false
	var metadata_phase := false
	var metadata_all_indices_seen := false
	var expected_metadata_ids: Array[String] = []

	func begin_epoch(epoch: int) -> void:
		current_epoch = epoch
		baseline_epochs.append([])
		candidate_epochs.append([])

	func end_epoch() -> void:
		current_epoch = -1

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		tick += 1
		var self_ref := {"vehicle_id": "copy-cap-probe", "life_generation": 4}
		var base: Dictionary
		var copy: Dictionary
		var started_us: int
		var base_us := 0
		var copy_us := 0
		if tick % 2 == 0:
			started_us = Time.get_ticks_usec()
			base = baseline.collect(state, self_ref, tick)
			base_us = Time.get_ticks_usec() - started_us
			started_us = Time.get_ticks_usec()
			copy = candidate.collect(state, self_ref, tick)
			copy_us = Time.get_ticks_usec() - started_us
		else:
			started_us = Time.get_ticks_usec()
			copy = candidate.collect(state, self_ref, tick)
			copy_us = Time.get_ticks_usec() - started_us
			started_us = Time.get_ticks_usec()
			base = baseline.collect(state, self_ref, tick)
			base_us = Time.get_ticks_usec() - started_us
		if current_epoch >= 0:
			(baseline_epochs[current_epoch] as Array).append(base_us)
			(candidate_epochs[current_epoch] as Array).append(copy_us)
		if base != copy:
			parity_failures += 1
		if bool(copy.status.collection_cap_gap):
			cap_ticks += 1
			if bool(copy.complete):
				complete_cap_ticks += 1

		if (copy.rows as Array).size() == 8 and not mutation_export_done:
			var sibling_before: String = copy.rows[1].peer_identity.source_id
			copy.rows[0].peer_identity.source_id = "caller-mutated-zero"
			sibling_isolation_ok = copy.rows[1].peer_identity.source_id == sibling_before
			for index in 8:
				copy.rows[index].peer_identity.source_id = "caller-mutated-%d" % index
				copy.rows[index].self_identity.vehicle_id = "caller-mutated-self"
				copy.rows[index].point_on_self_world_m = Vector3(999.0, 999.0, 999.0)
			copy.self_identity.vehicle_id = "caller-mutated-envelope"
			mutation_export_done = true
		elif mutation_export_done and not post_mutation_all_indices_ok \
				and (copy.rows as Array).size() == 8:
			var restored: bool = copy.self_identity.vehicle_id == "copy-cap-probe"
			for row: Dictionary in copy.rows:
				restored = restored and row.self_identity.vehicle_id == "copy-cap-probe" \
					and not String(row.peer_identity.source_id).begins_with("caller-mutated") \
					and row.point_on_self_world_m != Vector3(999.0, 999.0, 999.0)
			post_mutation_all_indices_ok = restored
		if metadata_phase and (copy.rows as Array).size() == 8:
			var seen := {}
			for row: Dictionary in copy.rows:
				seen[row.peer_identity.source_id] = true
			var all_seen := true
			for expected: String in expected_metadata_ids:
				all_seen = all_seen and seen.has(expected)
			metadata_all_indices_seen = metadata_all_indices_seen or all_seen

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

func descriptor_for(vehicle_id: String, life: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	if not parsed is Dictionary:
		return {}
	for candidate: Dictionary in (parsed as Dictionary).get("profiles", []):
		if str(candidate.get("profile_id", "")) != "compact_sedan":
			continue
		var row := candidate.duplicate(true)
		row.vehicle_id = vehicle_id
		row.source_id = "compact_sedan"
		row.life_generation = life
		row.source_clock = 1
		return row
	return {}

func add_wall(world: Node3D, value: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.transform = value
	wall.set_meta("source_id", "copy-elision-wall")
	wall.set_meta("source_index", 61)
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
	body.set_meta("source_id", "copy-cap-%d" % index)
	body.set_meta("source_index", index)
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func run() -> void:
	check(FileAccess.get_sha256(BASELINE_PATH) == BASELINE_SHA256,
		"frozen D149 baseline remains byte exact")
	check(FileAccess.get_sha256(PRODUCTION_BODY) == PRODUCTION_BODY_SHA256,
		"frozen production native body remains byte exact")
	var contract: Dictionary = Candidate.new().candidate_contract()
	check(contract.baseline_sha256 == BASELINE_SHA256
		and contract.elided_operation == "cold_intermediate_peer_identity_deep_copy"
		and bool(contract.identity_describe_returns_fresh_owned_dictionary),
		"candidate declares exactly one owned cold-copy elision")
	check(not bool(contract.retains_caller_owned_data)
		and bool(contract.final_row_identity_deep_copy_retained)
		and not bool(contract.metadata_cache) and not bool(contract.filters_contacts),
		"candidate retains final isolation with no cache or content filter")
	check(not bool(contract.runtime_wired) and not bool(contract.owns_authority),
		"candidate remains unwired and non-authoritative")
	var wall := await run_wall_fixture()
	var cap := await run_cap_fixture()
	finish(wall, cap)

func run_wall_fixture() -> Dictionary:
	var descriptor := descriptor_for("copy-wall-probe", 2)
	check(not descriptor.is_empty(), "wall descriptor available")
	var yaw := 0.61
	var basis := Basis(Vector3.UP, yaw)
	var wall_origin := Vector3(25.0, 5.0, -18.0)
	var normal := (basis * Vector3.BACK).normalized()
	var approach := -normal
	var world := Node3D.new()
	root.add_child(world)
	var wall := add_wall(world, Transform3D(basis, wall_origin))
	var probe := WallProbe.new()
	check(probe.configure(descriptor), "actual dual wall probe configures")
	probe.transform = Transform3D(basis, wall_origin - approach * 8.0)
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	probe.wall_runtime_id = wall.get_instance_id()
	world.add_child(probe)
	for _tick in 4:
		await physics_frame
	probe.linear_velocity = approach * 12.0
	for _tick in 120:
		await physics_frame
	check(probe.parity_failures == 0,
		"copy-elision candidate exactly matches D149 on every actual wall callback")
	check(probe.first_contact_tick >= 0 and probe.first_nonzero_tick > probe.first_contact_tick,
		"zero-J onset remains distinct from later nonzero-J callback")
	check(probe.first_impulse.length() <= 0.000001 and probe.first_closing > 5.0
		and probe.later_impulse.length() > 1.0,
		"same-row onset closing and later impulse are preserved")
	var evidence := {"parity_failures": probe.parity_failures,
		"first_contact_tick": probe.first_contact_tick,
		"first_nonzero_tick": probe.first_nonzero_tick,
		"first_closing_mps": probe.first_closing,
		"first_impulse_ns": probe.first_impulse, "later_impulse_ns": probe.later_impulse}
	probe.free()
	wall.free()
	world.free()
	return evidence

func run_cap_fixture() -> Dictionary:
	var descriptor := descriptor_for("copy-cap-probe", 4)
	check(not descriptor.is_empty(), "cap descriptor available")
	var world := Node3D.new()
	root.add_child(world)
	var probe := CapProbe.new()
	check(probe.configure(descriptor), "actual dual cap probe configures")
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	world.add_child(probe)
	var centers := PackedVector3Array([
		Vector3(-1.32, 1.00, -1.55), Vector3(-1.32, 1.00, 1.55),
		Vector3(1.32, 1.00, -1.55), Vector3(1.32, 1.00, 1.55),
		Vector3(-0.68, 1.00, -2.58), Vector3(0.68, 1.00, -2.58),
		Vector3(-0.68, 1.00, 2.58), Vector3(0.68, 1.00, 2.58)])
	var statics: Array[StaticBody3D] = []
	for index in centers.size():
		statics.append(add_cap_sphere(world, index, centers[index]))
	for _tick in 20:
		await physics_frame
	for epoch in PERF_EPOCHS:
		probe.begin_epoch(epoch)
		for _tick in PERF_TICKS_PER_EPOCH:
			await physics_frame
		probe.end_epoch()
	# Change every authored identity after the measured epochs. Both collectors
	# must observe all eight immediately; no intermediate dictionary may persist.
	probe.expected_metadata_ids.clear()
	for index in statics.size():
		var next_id := "copy-cap-updated-%d" % index
		probe.expected_metadata_ids.append(next_id)
		statics[index].set_meta("source_id", next_id)
	probe.metadata_phase = true
	for _tick in 20:
		await physics_frame

	check(probe.parity_failures == 0,
		"copy-elision candidate exactly matches D149 on cap and all identity changes")
	check(probe.cap_ticks > 0 and probe.complete_cap_ticks == 0,
		"actual count-at-eight remains conservatively incomplete")
	check(probe.mutation_export_done and probe.sibling_isolation_ok
		and probe.post_mutation_all_indices_ok,
		"caller mutation is isolated across siblings and all eight later exports")
	check(probe.metadata_all_indices_seen,
		"all eight changed authored identities appear without retained intermediate data")
	var performance := performance_decision(probe.baseline_epochs, probe.candidate_epochs)
	var evidence := {"parity_failures": probe.parity_failures,
		"cap_ticks": probe.cap_ticks, "complete_cap_ticks": probe.complete_cap_ticks,
		"mutation_export_done": probe.mutation_export_done,
		"sibling_isolation_ok": probe.sibling_isolation_ok,
		"post_mutation_all_indices_ok": probe.post_mutation_all_indices_ok,
		"metadata_all_indices_seen": probe.metadata_all_indices_seen,
		"performance": performance}
	probe.free()
	for body: StaticBody3D in statics:
		body.free()
	world.free()
	return evidence

func performance_decision(baseline_epochs: Array, candidate_epochs: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var speedups := PackedFloat64Array()
	speedups.resize(PERF_EPOCHS)
	var faster_epochs := 0
	for epoch in PERF_EPOCHS:
		var baseline := summarize(baseline_epochs[epoch])
		var candidate := summarize(candidate_epochs[epoch])
		var speedup := float(baseline.p50_us) / maxf(1.0, float(candidate.p50_us))
		speedups[epoch] = speedup
		if float(candidate.p50_us) < float(baseline.p50_us):
			faster_epochs += 1
		rows.append({"epoch": epoch, "baseline": baseline,
			"candidate": candidate, "p50_speedup": speedup})
	var sorted_speedups := speedups.duplicate()
	sorted_speedups.sort()
	var median_speedup := sorted_speedups[int(floor((PERF_EPOCHS - 1) * 0.50))]
	var material := faster_epochs >= 5 and median_speedup >= 1.05
	return {"decision": "ACCEPT_MATERIAL_GAIN" if material else "REJECT_NO_REPEATABLE_MATERIAL_GAIN",
		"material_gain": material, "required_faster_epochs": 5,
		"required_median_p50_speedup": 1.05, "faster_epochs": faster_epochs,
		"median_p50_speedup": median_speedup, "epochs": rows,
		"qualification": "repeated alternating actual callback wall latency; performance decision does not affect functional test exit; no FPS/aggregate CPU/LIVE claim"}

func summarize(values_value: Variant) -> Dictionary:
	var values: Array = values_value
	if values.is_empty():
		return {"valid": false}
	var sorted := values.duplicate()
	sorted.sort()
	var last := sorted.size() - 1
	return {"valid": true, "samples": sorted.size(),
		"p50_us": sorted[int(floor(last * 0.50))],
		"p95_us": sorted[int(floor(last * 0.95))], "max_us": sorted[last]}

func finish(wall: Dictionary, cap: Dictionary) -> void:
	print("NATIVE_VEHICLE_CONTACT_OBSERVATION_COPY_ELISION_CANDIDATE_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "functional_checks": checks,
		"functional_failure_count": failures.size(), "functional_failures": failures,
		"baseline_sha256": FileAccess.get_sha256(BASELINE_PATH),
		"candidate_sha256": FileAccess.get_sha256(CANDIDATE_PATH),
		"wall": wall, "cap": cap, "runtime_wired": false,
		"qualification": "functional parity and mutation isolation determine exit; repeated performance stats are a separate adoption gate, no content drop, authority, body/main, GPU, LIVE or FPS claim"
	}))
	quit(0 if failures.is_empty() else 1)
