extends SceneTree
## Actual PhysicsDirectBodyState3D capacity stress plus isolated cache CPU evidence.
## This does not fake direct state and makes no FPS or runtime-wiring claim.

const Bridge = preload("res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd")
const BRIDGE_SHA256 := "73843ce758381b7911aa432ade0e66cfb9ea96ebd05986f0e9f39bc64a1de1a7"
const PRODUCTION_BODY_SHA256 := "a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const FIXED_TICKS_PER_SECOND := 60
const MEASURE_TICKS := 120
const CACHE_WARM_TICKS := 240
const CACHE_SAMPLE_BLOCKS := 128
const CACHE_TICKS_PER_BLOCK := 64

class CapProbe:
	extends NativeVehicleBody
	var bridge = Bridge.new()
	var bridge_tick := 0
	var self_ref := {"vehicle_id": "bridge-cap-probe", "life_generation": 1}
	var pinned_transform := Transform3D.IDENTITY
	var invalid_result_count := 0
	var maximum_raw_contacts := 0
	var cap_tick_count := 0
	var incomplete_cap_tick_count := 0
	var complete_cap_tick_count := 0
	var cap_proposal_maximum := 0
	var cap_admitted_maximum := 0
	var cap_identity_gap_count := 0
	var cap_manifold_gap_count := 0

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super(state)
		bridge_tick += 1
		var com_world := state.transform * state.center_of_mass_local
		var result: Dictionary = bridge.collect(state, self_ref, bridge_tick,
			state.transform, com_world)
		if not bool(result.valid):
			invalid_result_count += 1
		else:
			var status: Dictionary = result.status
			var raw_count := int(status.raw_state_contact_count)
			maximum_raw_contacts = maxi(maximum_raw_contacts, raw_count)
			if bool(status.collection_cap_gap):
				cap_tick_count += 1
				cap_proposal_maximum = maxi(cap_proposal_maximum, (result.proposals as Array).size())
				cap_admitted_maximum = maxi(cap_admitted_maximum, int(status.admitted_point_count))
				if bool(result.complete):
					complete_cap_tick_count += 1
				else:
					incomplete_cap_tick_count += 1
				if bool(status.collection_identity_gap):
					cap_identity_gap_count += 1
				if bool(status.collection_manifold_gap):
					cap_manifold_gap_count += 1
		# Re-establish the same enclosed stress pose each integration. Contact data
		# above is the actual solver state delivered for this tick.
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

func descriptor() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	if not parsed is Dictionary:
		return {}
	for candidate: Dictionary in (parsed as Dictionary).get("profiles", []):
		if str(candidate.get("profile_id", "")) != "compact_sedan":
			continue
		var row := candidate.duplicate(true)
		row.vehicle_id = "bridge-cap-probe"
		row.source_id = "compact_sedan"
		row.life_generation = 1
		row.source_clock = 1
		return row
	return {}

func add_contact_sphere(world: Node3D, index: int, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.set_meta("source_id", "bridge-cap-static-%d" % index)
	body.set_meta("source_index", index)
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func run() -> void:
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd") == BRIDGE_SHA256,
		"frozen bridge receipt")
	check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd") == PRODUCTION_BODY_SHA256,
		"frozen production body receipt")
	var row := descriptor()
	check(not row.is_empty(), "compact sedan descriptor available")
	if row.is_empty():
		finish({}, {})
		return

	var world := Node3D.new()
	root.add_child(world)
	var probe := CapProbe.new()
	check(probe.configure(row), "native rigid cap probe configures")
	probe.gravity_scale = 0.0
	probe.can_sleep = false
	probe.pinned_transform = Transform3D.IDENTITY
	world.add_child(probe)
	var statics: Array[StaticBody3D] = []
	var centers := PackedVector3Array([
		Vector3(-1.32, 1.00, -1.55), Vector3(-1.32, 1.00, 1.55),
		Vector3(1.32, 1.00, -1.55), Vector3(1.32, 1.00, 1.55),
		Vector3(-0.68, 1.00, -2.58), Vector3(0.68, 1.00, -2.58),
		Vector3(-0.68, 1.00, 2.58), Vector3(0.68, 1.00, 2.58),
	])
	for index in centers.size():
		statics.append(add_contact_sphere(world, index, centers[index]))
	for _tick in MEASURE_TICKS:
		await physics_frame

	check(probe.invalid_result_count == 0, "all actual direct-state collections admit inputs")
	check(probe.maximum_raw_contacts == Bridge.POINT_CAPACITY,
		"actual native rigid fixture reaches exactly eight reported contacts")
	check(probe.cap_tick_count > 0 and probe.incomplete_cap_tick_count == probe.cap_tick_count,
		"every actual count-at-cap collection is conservatively incomplete")
	check(probe.complete_cap_tick_count == 0,
		"no actual count-at-cap collection is exposed as complete")
	check(probe.cap_identity_gap_count == 0 and probe.cap_manifold_gap_count == 0,
		"eight distinct tagged counterparts fit identity and manifold bounds")
	check(probe.cap_admitted_maximum == Bridge.POINT_CAPACITY
		and probe.cap_proposal_maximum == Bridge.COUNTERPART_CAPACITY,
		"all eight bounded points and counterparts remain observable proposals")

	var hot_metrics := benchmark_cache(false)
	var cold_metrics := benchmark_cache(true)
	check(bool(hot_metrics.get("valid", false)) and bool(cold_metrics.get("valid", false)),
		"hot and synthetic-cold cache CPU samples are finite")
	check(float(hot_metrics.get("p95_us_per_8_identity_tick", -1.0)) >=
		float(hot_metrics.get("p50_us_per_8_identity_tick", 0.0)),
		"hot cache CPU p95 is ordered after p50")
	check(float(cold_metrics.get("p95_us_per_8_identity_tick", -1.0)) >=
		float(cold_metrics.get("p50_us_per_8_identity_tick", 0.0)),
		"synthetic-cold cache CPU p95 is ordered after p50")

	var actual := {"maximum_raw_contacts": probe.maximum_raw_contacts,
		"cap_tick_count": probe.cap_tick_count,
		"incomplete_cap_tick_count": probe.incomplete_cap_tick_count,
		"cap_proposal_maximum": probe.cap_proposal_maximum,
		"cap_admitted_maximum": probe.cap_admitted_maximum,
		"cap_identity_gap_count": probe.cap_identity_gap_count,
		"cap_manifold_gap_count": probe.cap_manifold_gap_count}
	probe.free()
	for body: StaticBody3D in statics:
		body.free()
	world.free()
	finish(actual, {"hot": hot_metrics, "synthetic_cold": cold_metrics})

func benchmark_cache(synthetic_cold: bool) -> Dictionary:
	var bridge = Bridge.new()
	var identities: Array[StaticBody3D] = []
	for index in Bridge.CACHE_CAPACITY:
		var body := StaticBody3D.new()
		body.set_meta("source_id", "cpu-cache-%d" % index)
		body.set_meta("source_index", index)
		identities.append(body)
	for _warm_tick in CACHE_WARM_TICKS:
		if synthetic_cold:
			bridge.reset_lifetime()
		for body: StaticBody3D in identities:
			bridge._identity_slot(body, body.get_instance_id())
	var samples := PackedFloat64Array()
	samples.resize(CACHE_SAMPLE_BLOCKS)
	for sample_index in CACHE_SAMPLE_BLOCKS:
		var started_us := Time.get_ticks_usec()
		for _tick in CACHE_TICKS_PER_BLOCK:
			if synthetic_cold:
				bridge.reset_lifetime()
			for body: StaticBody3D in identities:
				bridge._identity_slot(body, body.get_instance_id())
		var elapsed_us := Time.get_ticks_usec() - started_us
		samples[sample_index] = float(elapsed_us) / float(CACHE_TICKS_PER_BLOCK)
	samples.sort()
	var p50 := samples[int(floor((CACHE_SAMPLE_BLOCKS - 1) * 0.50))]
	var p95 := samples[int(floor((CACHE_SAMPLE_BLOCKS - 1) * 0.95))]
	for body: StaticBody3D in identities:
		body.free()
	return {"valid": is_finite(p50) and is_finite(p95),
		"warm_ticks": CACHE_WARM_TICKS,
		"sample_blocks": CACHE_SAMPLE_BLOCKS,
		"ticks_per_block": CACHE_TICKS_PER_BLOCK,
		"identities_per_tick": Bridge.CACHE_CAPACITY,
		"p50_us_per_8_identity_tick": p50,
		"p95_us_per_8_identity_tick": p95,
		"scope": "isolated CPU cache path; no FPS claim"}

func finish(actual: Dictionary, cpu: Dictionary) -> void:
	print("NATIVE_VEHICLE_CONTACT_STATE_BRIDGE_CAP_STRESS_TEST ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"failure_count": failures.size(),
		"failures": failures,
		"bridge_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_contact_state_bridge.gd"),
		"production_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"actual_direct_state": actual,
		"cache_cpu": cpu,
		"runtime_wired": false,
		"qualification": "actual PhysicsDirectBodyState3D capacity stress; isolated CPU cache evidence, no FPS/GPU/LIVE/main/Git claim",
	}))
	quit(0 if failures.is_empty() else 1)
