extends SceneTree
## Actual direct-state parity and alternating cost evidence for the candidate
## identity cache. The frozen D149 baseline and production body are not edited.

const Baseline = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd")
const Candidate = preload("res://scripts/vehicle_physics/vehicle_contact_observation_collector_cached_candidate.gd")
const BASELINE_PATH := "res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd"
const BASELINE_SHA256 := "d14946c97ecdb43105d6d760553a7de0151eda64b22e3254b285a94987c759f0"
const CANDIDATE_PATH := "res://scripts/vehicle_physics/vehicle_contact_observation_collector_cached_candidate.gd"
const PRODUCTION_BODY := "res://scripts/vehicle_physics/vehicle_native_body.gd"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const FIXED_TICKS_PER_SECOND := 60
const WALL_TICKS := 120
const CAP_MEASURE_TICKS := 160
const PHASE_TICKS := 20

class DualWallProbe:
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
		var self_ref := {"vehicle_id": "cached-wall-probe", "life_generation": 3}
		var base: Dictionary
		var cached: Dictionary
		if tick % 2 == 0:
			base = baseline.collect(state, self_ref, tick)
			cached = candidate.collect(state, self_ref, tick)
		else:
			cached = candidate.collect(state, self_ref, tick)
			base = baseline.collect(state, self_ref, tick)
		if base != cached:
			parity_failures += 1
		for row_value: Variant in cached.rows:
			var row: Dictionary = row_value
			if int(row.counterpart_runtime_id) != wall_runtime_id:
				continue
			if first_contact_tick < 0:
				first_contact_tick = tick
				first_closing = row.closing_speed_along_normal_mps
				first_impulse = row.impulse_on_self_world_ns
			if first_nonzero_tick < 0 and row.impulse_on_self_world_ns.length() > 0.000001:
				first_nonzero_tick = tick
				later_impulse = row.impulse_on_self_world_ns

class DualCapProbe:
	extends NativeVehicleBody
	var baseline = Baseline.new()
	var candidate = Candidate.new()
	var tick := 0
	var pinned_transform := Transform3D.IDENTITY
	var parity_failures := 0
	var cap_ticks := 0
	var complete_cap_ticks := 0
	var phase := 0
	var phase_mutated_seen := 0
	var phase_removed_gap_seen := 0
	var phase_recovered_seen := 0
	var expected_mutated_source_id := "cached-cap-mutated"
	var measurement_enabled := false
	var baseline_us: Array[int] = []
	var candidate_us: Array[int] = []

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		tick += 1
		var self_ref := {"vehicle_id": "cached-cap-probe", "life_generation": 5}
		var base: Dictionary
		var cached: Dictionary
		var started_us: int
		var elapsed_base := 0
		var elapsed_cached := 0
		if tick % 2 == 0:
			started_us = Time.get_ticks_usec()
			base = baseline.collect(state, self_ref, tick)
			elapsed_base = Time.get_ticks_usec() - started_us
			started_us = Time.get_ticks_usec()
			cached = candidate.collect(state, self_ref, tick)
			elapsed_cached = Time.get_ticks_usec() - started_us
		else:
			started_us = Time.get_ticks_usec()
			cached = candidate.collect(state, self_ref, tick)
			elapsed_cached = Time.get_ticks_usec() - started_us
			started_us = Time.get_ticks_usec()
			base = baseline.collect(state, self_ref, tick)
			elapsed_base = Time.get_ticks_usec() - started_us
		if measurement_enabled:
			baseline_us.append(elapsed_base)
			candidate_us.append(elapsed_cached)
		if base != cached:
			parity_failures += 1
		if bool(cached.status.collection_cap_gap):
			cap_ticks += 1
			if bool(cached.complete):
				complete_cap_ticks += 1
		if phase == 1:
			for row: Dictionary in cached.rows:
				if row.peer_identity.get("source_id") == expected_mutated_source_id:
					phase_mutated_seen += 1
					break
		elif phase == 2 and bool(cached.status.collection_identity_gap):
			phase_removed_gap_seen += 1
		elif phase == 3:
			for row: Dictionary in cached.rows:
				if row.peer_identity.get("source_id") == expected_mutated_source_id:
					phase_recovered_seen += 1
					break
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

func add_wall(world: Node3D, transform_value: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.transform = transform_value
	wall.set_meta("source_id", "cached-rotated-wall")
	wall.set_meta("source_index", 71)
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
	body.set_meta("source_id", "cached-cap-%d" % index)
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
	var cache_contract: Dictionary = Candidate.new().cache_contract()
	check(cache_contract.capacity == 8 and cache_contract.replacement == "round_robin"
		and bool(cache_contract.baseline_schema_exact),
		"candidate declares fixed eight-slot round-robin baseline schema")
	check(not bool(cache_contract.retains_any_object_refs)
		and bool(cache_contract.validates_live_class_and_metadata_each_callback)
		and bool(cache_contract.refreshes_mutation_removal_or_recovered_object),
		"cache retains no Object refs and validates live authored metadata")
	check(not bool(cache_contract.filters_contacts) and not bool(cache_contract.owns_authority)
		and not bool(cache_contract.runtime_wired),
		"candidate filters no content and owns no runtime authority")

	var wall := await run_wall_fixture()
	var cap := await run_cap_fixture()
	var cache_unit := run_cache_unit()
	finish(wall, cap, cache_unit)

func run_wall_fixture() -> Dictionary:
	var descriptor := descriptor_for("cached-wall-probe", 3)
	check(not descriptor.is_empty(), "wall descriptor available")
	var yaw := 0.61
	var basis := Basis(Vector3.UP, yaw)
	var wall_origin := Vector3(25.0, 5.0, -18.0)
	var normal := (basis * Vector3.BACK).normalized()
	var approach := -normal
	var world := Node3D.new()
	root.add_child(world)
	var wall_body := add_wall(world, Transform3D(basis, wall_origin))
	var probe := DualWallProbe.new()
	check(probe.configure(descriptor), "actual dual wall probe configures")
	probe.transform = Transform3D(basis, wall_origin - approach * 8.0)
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	probe.wall_runtime_id = wall_body.get_instance_id()
	world.add_child(probe)
	for _tick in 4:
		await physics_frame
	probe.linear_velocity = approach * 12.0
	for _tick in WALL_TICKS:
		await physics_frame
	check(probe.parity_failures == 0,
		"candidate exactly matches baseline on every actual rotated-wall callback")
	check(probe.first_contact_tick >= 0 and probe.first_nonzero_tick > probe.first_contact_tick,
		"candidate preserves zero-J onset then later-J chronology")
	check(probe.first_impulse.length() <= 0.000001 and probe.first_closing > 5.0
		and probe.later_impulse.length() > 1.0,
		"candidate retains coherent onset closing and distinct later impulse")
	var status := probe.candidate.cache_status()
	check(int(status.hit_total) > 0 and int(status.retained_object_refs) == 0,
		"actual wall reaches cache hits without retained Object refs")
	var evidence := {"parity_failures": probe.parity_failures,
		"first_contact_tick": probe.first_contact_tick,
		"first_nonzero_tick": probe.first_nonzero_tick,
		"first_closing_mps": probe.first_closing,
		"first_impulse_ns": probe.first_impulse,
		"later_impulse_ns": probe.later_impulse, "cache": status}
	probe.free()
	wall_body.free()
	world.free()
	return evidence

func run_cap_fixture() -> Dictionary:
	var descriptor := descriptor_for("cached-cap-probe", 5)
	check(not descriptor.is_empty(), "cap descriptor available")
	var world := Node3D.new()
	root.add_child(world)
	var probe := DualCapProbe.new()
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
	probe.measurement_enabled = true
	for _tick in CAP_MEASURE_TICKS:
		await physics_frame
	probe.measurement_enabled = false
	probe.phase = 1
	statics[0].set_meta("source_id", probe.expected_mutated_source_id)
	for _tick in PHASE_TICKS:
		await physics_frame
	probe.phase = 2
	statics[0].remove_meta("source_id")
	for _tick in PHASE_TICKS:
		await physics_frame
	probe.phase = 3
	statics[0].set_meta("source_id", probe.expected_mutated_source_id)
	for _tick in PHASE_TICKS:
		await physics_frame

	var base_cost := summarize(probe.baseline_us)
	var candidate_cost := summarize(probe.candidate_us)
	check(probe.parity_failures == 0,
		"candidate exactly matches baseline through cap, mutation, removal and recovery")
	check(probe.cap_ticks > 0 and probe.complete_cap_ticks == 0,
		"actual count-at-eight remains conservatively incomplete")
	check(probe.phase_mutated_seen > 0 and probe.phase_removed_gap_seen > 0
		and probe.phase_recovered_seen > 0,
		"live identity mutation, metadata removal and recovery refresh without stale output")
	check(bool(base_cost.valid) and bool(candidate_cost.valid)
		and float(candidate_cost.p50_us) < float(base_cost.p50_us),
		"candidate actual eight-contact alternating p50 is faster than frozen baseline")
	var status := probe.candidate.cache_status()
	check(int(status.hit_total) > int(status.refresh_total)
		and int(status.retained_object_refs) == 0,
		"steady actual cap uses hits while retaining no Object references")
	var evidence := {"parity_failures": probe.parity_failures,
		"cap_ticks": probe.cap_ticks, "complete_cap_ticks": probe.complete_cap_ticks,
		"mutated_seen": probe.phase_mutated_seen,
		"removed_gap_seen": probe.phase_removed_gap_seen,
		"recovered_seen": probe.phase_recovered_seen,
		"baseline_cost": base_cost, "candidate_cost": candidate_cost,
		"cache": status}
	probe.free()
	for body: StaticBody3D in statics:
		body.free()
	world.free()
	return evidence

func run_cache_unit() -> Dictionary:
	var candidate = Candidate.new()
	var bodies: Array[StaticBody3D] = []
	for index in 9:
		var body := StaticBody3D.new()
		body.set_meta("source_id", "round-robin-%d" % index)
		body.set_meta("source_index", index)
		bodies.append(body)
		var admitted: Dictionary = candidate._cached_identity(body, body.get_instance_id())
		check(bool(admitted.valid) and admitted.source_index == index,
			"round-robin cache admits scalar identity %d" % index)
	var after_nine := candidate.cache_status()
	check(after_nine.used == 8 and after_nine.eviction_total == 1
		and after_nine.replace_cursor == 1,
		"ninth distinct identity evicts deterministic round-robin slot zero")
	var first_again: Dictionary = candidate._cached_identity(bodies[0], bodies[0].get_instance_id())
	var after_first_again := candidate.cache_status()
	check(bool(first_again.valid) and first_again.source_index == 0
		and after_first_again.eviction_total == 2 and after_first_again.replace_cursor == 2,
		"evicted identity refreshes without stale data and advances round-robin")
	bodies[0].set_meta("source_id", "round-robin-mutated")
	var mutated: Dictionary = candidate._cached_identity(bodies[0], bodies[0].get_instance_id())
	check(mutated.source_id == "round-robin-mutated",
		"live source-id mutation refreshes cached scalar identity")
	bodies[0].remove_meta("source_id")
	var removed: Dictionary = candidate._cached_identity(bodies[0], bodies[0].get_instance_id())
	check(not bool(removed.valid) and removed.reason == "unbound_static_source",
		"metadata removal cannot replay stale admitted identity")
	bodies[0].set_meta("source_id", "round-robin-restored")
	var restored: Dictionary = candidate._cached_identity(bodies[0], bodies[0].get_instance_id())
	check(bool(restored.valid) and restored.source_id == "round-robin-restored",
		"removed metadata can recover through fresh Identity.describe")
	var vehicle := RigidBody3D.new()
	vehicle.set_meta("vehicle_id", "cached-peer")
	vehicle.set_meta("life_generation", 1)
	var vehicle_first: Dictionary = candidate._cached_identity(vehicle, vehicle.get_instance_id())
	vehicle.set_meta("life_generation", 2)
	var vehicle_next: Dictionary = candidate._cached_identity(vehicle, vehicle.get_instance_id())
	check(vehicle_first.life_generation == 1 and vehicle_next.life_generation == 2,
		"vehicle life mutation refreshes and never replays old life")
	var before_reset := candidate.cache_status()
	candidate.reset_cache()
	var after_reset := candidate.cache_status()
	check(after_reset.used == 0 and after_reset.hit_total == 0
		and after_reset.miss_total == 0 and after_reset.retained_object_refs == 0,
		"explicit cache lifecycle reset clears slots and metrics")
	for body: StaticBody3D in bodies:
		body.free()
	vehicle.free()
	return {"before_reset": before_reset, "after_reset": after_reset}

func summarize(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {"valid": false}
	var sorted := values.duplicate()
	sorted.sort()
	var last := sorted.size() - 1
	return {"valid": true, "samples": sorted.size(),
		"p50_us": sorted[int(floor(last * 0.50))],
		"p95_us": sorted[int(floor(last * 0.95))],
		"max_us": sorted[last],
		"scope": "alternating actual callback wall latency; no FPS/aggregate CPU/LIVE claim"}

func finish(wall: Dictionary, cap: Dictionary, cache_unit: Dictionary) -> void:
	print("NATIVE_VEHICLE_CONTACT_OBSERVATION_CACHED_CANDIDATE_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"baseline_sha256": FileAccess.get_sha256(BASELINE_PATH),
		"candidate_sha256": FileAccess.get_sha256(CANDIDATE_PATH),
		"wall": wall, "cap": cap, "cache_unit": cache_unit,
		"runtime_wired": false,
		"qualification": "candidate-only exact raw collector schema with live scalar identity cache; alternating callback wall latency only, no content drop, authority, body/main, GPU, LIVE or FPS claim"
	}))
	quit(0 if failures.is_empty() else 1)
