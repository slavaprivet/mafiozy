extends SceneTree
## Independent analytic/invariant review of the pure source-axis pair resolver.

const Resolver = preload("res://scripts/vehicle_physics/vehicle_pair_impulse_resolver.gd")
const RESOLVER_PATH := "res://scripts/vehicle_physics/vehicle_pair_impulse_resolver.gd"
const RESOLVER_SHA256 := "840cb2ea2977c43f22efb3936f653ccf1c492264f6f02cb640d80d254034cd18"
const SOURCE_PATH := "res://../../assets/maps/city_rebuild_v1/vehicle_pair_impulse.mjs"
const SOURCE_SHA256 := "544a6a3c0d3b406ada6f60d38084e3e9ace488e12e7b404e2d9ea75bbb2abbe1"
const RANDOM_CASES := 512

var checks := 0
var failures: Array[String] = []
var seed := 0x6E624EB7
var resolved_random_cases := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func near(actual: float, expected: float, tolerance := 1.0e-9) -> bool:
	if actual == expected:
		return true
	if not is_finite(actual) or not is_finite(expected):
		return false
	return absf(actual - expected) <= tolerance * maxf(1.0, absf(expected))

func _initialize() -> void:
	call_deferred("run")

func body(x: float, z: float, vx: float, vz: float, mass: float,
		half_width := 1.0, half_length := 2.0, yaw_rate := 0.0) -> Dictionary:
	return {"x": x, "z": z, "vx": vx, "vz": vz, "mass": mass,
		"halfWidth": half_width, "halfLength": half_length, "yawRate": yaw_rate}

func contact(x: float, z: float, nx: float, nz: float) -> Dictionary:
	return {"point": {"x": x, "z": z}, "normal": {"x": nx, "z": nz}}

func run() -> void:
	check(FileAccess.get_sha256(RESOLVER_PATH) == RESOLVER_SHA256,
		"exact frozen resolver candidate")
	check(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256,
		"exact source pair impulse bytes")
	check_contract()
	check_centered_analytic()
	check_source_axis_yaw_sign()
	check_unequal_and_swap()
	check_invalid_and_purity()
	check_random_invariants()
	check(resolved_random_cases > 150,
		"deterministic matrix contains many independently resolved contacts")
	print("NATIVE_VEHICLE_PAIR_IMPULSE_RESOLVER_INDEPENDENT_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"resolver_sha256": FileAccess.get_sha256(RESOLVER_PATH),
		"random_cases": RANDOM_CASES, "resolved_random_cases": resolved_random_cases,
		"runtime_wired": false,
		"qualification": "independent pure source-axis pair math only; no native J, force, event, authority, HP, body/main, GPU or LIVE claim"
	}))
	quit(0 if failures.is_empty() else 1)

func check_contract() -> void:
	var contract_value: Dictionary = Resolver.contract()
	check(contract_value.source_sha256 == SOURCE_SHA256 and bool(contract_value.pure),
		"contract pins exact source and pure implementation")
	check(contract_value.plane == "+X/+Z" and contract_value.yaw_axis == "+Y"
		and contract_value.normal_direction == "A_to_B",
		"contract exposes source plane, yaw axis, and A-to-B normal")
	check(not bool(contract_value.reads_native_reported_impulse)
		and not bool(contract_value.applies_body_force)
		and not bool(contract_value.owns_event_identity)
		and not bool(contract_value.owns_peer_canonicalization)
		and not bool(contract_value.owns_crash_or_damage)
		and not bool(contract_value.owns_hp)
		and not bool(contract_value.server_admissible)
		and not bool(contract_value.runtime_wired),
		"contract excludes native impulse, runtime, event, HP, and server authority")

func check_centered_analytic() -> void:
	var a := body(-1.0, 0.0, 10.0, 0.0, 1000.0)
	var b := body(1.0, 0.0, 0.0, 0.0, 1000.0)
	var hit := contact(0.0, 0.0, 1.0, 0.0)
	var result: Dictionary = Resolver.resolve_source(a, b, hit)
	check(bool(result.resolved), "centered equal-mass contact resolves")
	check(near(float(result.closingSpeed), 10.0)
		and near(float(result.impulse), 5600.0)
		and near(float(result.deltaVA), 5.6)
		and near(float(result.deltaVB), 5.6),
		"centered default-restitution solution has exact analytic J and delta-V")
	check(near(float(result.a.vx), 4.4) and near(float(result.b.vx), 5.6)
		and near(float(result.a.vz), 0.0) and near(float(result.b.vz), 0.0),
		"A subtracts and B adds impulse along A-to-B normal")
	check(near(float(result.impulseA.x), -5600.0)
		and near(float(result.impulseB.x), 5600.0)
		and near(float(result.impulseA.z), 0.0)
		and near(float(result.impulseB.z), 0.0),
		"directed impulse vectors are equal, opposite, and source-axis signed")

func check_source_axis_yaw_sign() -> void:
	# +Z normal with a +X contact arm has cross=-1. A subtracts J*cross/I,
	# therefore its yaw response is positive around source +Y.
	var a := body(0.0, 0.0, 0.0, 12.0, 1500.0, 1.0, 2.5, 0.0)
	var b := body(0.0, 4.0, 0.0, 0.0, 1800.0, 1.2, 2.8, 0.0)
	var hit := contact(1.0, 2.0, 0.0, 1.0)
	var result: Dictionary = Resolver.resolve_source(a, b, hit,
		{"restitution": 0.25, "angular": true})
	check(bool(result.resolved) and float(result.impulseA.z) < 0.0
		and float(result.impulseB.z) > 0.0,
		"+Z A-to-B normal gives -Z impulse on A and +Z impulse on B")
	check(float(result.a.yawRate) > 0.0 and float(result.b.yawRate) < 0.0,
		"off-centre +Z contact produces reviewed opposite +Y yaw signs")
	var before_closing := contact_closing(a, b, hit, a, b, true)
	var after_closing := contact_closing(a, b, hit, result.a, result.b, true)
	check(near(after_closing, -0.25 * before_closing),
		"post-contact point velocity satisfies restitution at the shared contact")
	check_conservation(a, b, result, 0.25, "source_axis_off_center")

func check_unequal_and_swap() -> void:
	var a := body(-2.0, 1.0, 16.0, -2.0, 1200.0, 0.9, 2.1, 0.6)
	var b := body(3.0, -1.0, -1.0, 3.0, 9600.0, 1.5, 4.5, -0.2)
	var hit := contact(0.4, 0.8, 3.0, 1.0)
	var options := {"restitution": 0.37, "angular": true}
	var result: Dictionary = Resolver.resolve_source(a, b, hit, options)
	check(bool(result.resolved)
		and near(float(result.deltaVA) / float(result.deltaVB), 8.0),
		"directed delta-V ratio is inverse mass ratio, not shared closing speed")
	var reverse_hit: Dictionary = hit.duplicate(true)
	reverse_hit.normal.x = -float(hit.normal.x)
	reverse_hit.normal.z = -float(hit.normal.z)
	var swapped: Dictionary = Resolver.resolve_source(b, a, reverse_hit, options)
	check(bool(swapped.resolved) and near(float(result.impulse), float(swapped.impulse))
		and near(float(result.deltaVA), float(swapped.deltaVB))
		and near(float(result.deltaVB), float(swapped.deltaVA)),
		"swapping bodies and reversing normal exchanges directed results")
	for key: String in ["vx", "vz", "yawRate"]:
		check(near(float(result.a[key]), float(swapped.b[key]))
			and near(float(result.b[key]), float(swapped.a[key])),
			"swap symmetry preserves next %s" % key)
	check_conservation(a, b, result, 0.37, "unequal_swap")

func check_invalid_and_purity() -> void:
	var a := body(0.0, 0.0, 8.0, 1.0, 1300.0, 1.0, 2.4, 0.3)
	var b := body(3.0, 0.0, -1.0, 0.0, 1700.0, 1.2, 2.8, -0.1)
	var hit := contact(1.0, 0.4, 1.0, 0.2)
	var before := {"a": a.duplicate(true), "b": b.duplicate(true),
		"contact": hit.duplicate(true)}
	var proposal: Dictionary = Resolver.propose(a, b, hit)
	check(a == before.a and b == before.b and hit == before.contact,
		"resolve/propose leave all caller dictionaries unchanged")
	check(bool(proposal.valid) and bool(proposal.proposal_only)
		and not bool(proposal.server_admissible)
		and not proposal.has("event_id") and not proposal.has("hp")
		and not proposal.has("damage") and not proposal.has("impactSpeed"),
		"proposal carries source result without event, impact-speed, HP, or damage authority")
	var separating: Dictionary = Resolver.resolve_source(
		body(0.0, 0.0, -4.0, 0.0, 1000.0),
		body(2.0, 0.0, 3.0, 0.0, 1000.0), contact(1.0, 0.0, 1.0, 0.0))
	check(not bool(separating.resolved) and near(float(separating.closingSpeed), 0.0)
		and near(float(separating.impulse), 0.0),
		"separating contact remains finite and unresolved")
	var fallback: Dictionary = Resolver.resolve_source(
		{"x": 0.0, "z": 0.0, "mass": -1.0,
			"vx": NAN, "vz": INF, "yawRate": -INF,
			"halfWidth": 1.0, "halfLength": 2.0},
		body(2.0, 0.0, -2.0, 0.0, 1000.0), contact(1.0, 0.0, 1.0, 0.0))
	check(float(fallback.a.vx) == 0.0 and float(fallback.a.vz) == 0.0
		and float(fallback.a.yawRate) == 0.0,
		"nonfinite source velocity fields use exact zero fallback")
	for invalid: Variant in [null, [], "body"]:
		var malformed: Dictionary = Resolver.propose(invalid, b, hit)
		check(not bool(malformed.valid) and bool(malformed.proposal_only)
			and not bool(malformed.server_admissible),
			"malformed container fails closed: %s" % typeof(invalid))

func check_random_invariants() -> void:
	for index in RANDOM_CASES:
		var a := random_body()
		var b := random_body()
		var angle := random_range(-PI, PI)
		var hit := contact(random_range(-20.0, 20.0), random_range(-20.0, 20.0),
			cos(angle) * random_range(0.1, 4.0), sin(angle) * random_range(0.1, 4.0))
		var restitution := random_range(0.0, 1.0)
		var angular := index % 7 != 0
		var result: Dictionary = Resolver.resolve_source(a, b, hit,
			{"restitution": restitution, "angular": angular})
		if not bool(result.resolved):
			check(float(result.closingSpeed) >= 0.0 and is_finite(float(result.closingSpeed)),
				"random unresolved result remains finite/nonnegative %d" % index)
			continue
		resolved_random_cases += 1
		check_conservation(a, b, result, restitution, "random_%d" % index, angular)
		var before_closing := contact_closing(a, b, hit, a, b, angular)
		var after_closing := contact_closing(a, b, hit, result.a, result.b, angular)
		check(before_closing > 0.0 and near(float(result.closingSpeed), before_closing),
			"random resolved closing is independently reproduced %d" % index)
		check(near(after_closing, -restitution * before_closing),
			"random contact-point restitution is exact %d" % index)
		check(near(float(result.impulseA.x) + float(result.impulseB.x), 0.0)
			and near(float(result.impulseA.z) + float(result.impulseB.z), 0.0),
			"random pair impulses are equal and opposite %d" % index)
		check(near(float(result.deltaVA) * float(a.mass), float(result.impulse))
			and near(float(result.deltaVB) * float(b.mass), float(result.impulse)),
			"random directed delta-V values equal J/m %d" % index)

func check_conservation(a: Dictionary, b: Dictionary, result: Dictionary,
		restitution: float, label: String, angular := true) -> void:
	var before_px := float(a.mass) * float(a.vx) + float(b.mass) * float(b.vx)
	var before_pz := float(a.mass) * float(a.vz) + float(b.mass) * float(b.vz)
	var after_px := float(a.mass) * float(result.a.vx) + float(b.mass) * float(result.b.vx)
	var after_pz := float(a.mass) * float(result.a.vz) + float(b.mass) * float(result.b.vz)
	check(near(after_px, before_px) and near(after_pz, before_pz),
		"%s conserves planar linear momentum" % label)
	var inertia_a := inertia(a) if angular else 0.0
	var inertia_b := inertia(b) if angular else 0.0
	if angular:
		var before_l := angular_momentum(a, a, inertia_a) + angular_momentum(b, b, inertia_b)
		var after_l := angular_momentum(a, result.a, inertia_a) \
			+ angular_momentum(b, result.b, inertia_b)
		check(near(after_l, before_l, 2.0e-9),
			"%s conserves world-origin +Y angular momentum" % label)
	var before_energy := energy(a, a, inertia_a) + energy(b, b, inertia_b)
	var after_energy := energy(a, result.a, inertia_a) + energy(b, result.b, inertia_b)
	check(after_energy <= before_energy + maxf(1.0, before_energy) * 2.0e-10,
		"%s restitution %.6f does not grow kinetic energy" % [label, restitution])

func contact_closing(a: Dictionary, b: Dictionary, hit: Dictionary,
		velocity_a: Dictionary, velocity_b: Dictionary, angular: bool) -> float:
	var nx := float(hit.normal.x)
	var nz := float(hit.normal.z)
	var length: float = sqrt(nx * nx + nz * nz)
	nx /= length
	nz /= length
	var arm_a_x := float(hit.point.x) - float(a.x)
	var arm_a_z := float(hit.point.z) - float(a.z)
	var arm_b_x := float(hit.point.x) - float(b.x)
	var arm_b_z := float(hit.point.z) - float(b.z)
	var cross_a := arm_a_z * nx - arm_a_x * nz
	var cross_b := arm_b_z * nx - arm_b_x * nz
	return (float(velocity_a.vx) - float(velocity_b.vx)) * nx \
		+ (float(velocity_a.vz) - float(velocity_b.vz)) * nz \
		+ ((float(velocity_a.yawRate) * cross_a
			- float(velocity_b.yawRate) * cross_b) if angular else 0.0)

func inertia(value: Dictionary) -> float:
	return float(value.mass) * (float(value.halfWidth) * float(value.halfWidth)
		+ float(value.halfLength) * float(value.halfLength)) / 3.0

func angular_momentum(body_value: Dictionary, velocity: Dictionary, body_inertia: float) -> float:
	return float(body_value.z) * float(body_value.mass) * float(velocity.vx) \
		- float(body_value.x) * float(body_value.mass) * float(velocity.vz) \
		+ body_inertia * float(velocity.yawRate)

func energy(body_value: Dictionary, velocity: Dictionary, body_inertia: float) -> float:
	return 0.5 * float(body_value.mass) * (float(velocity.vx) * float(velocity.vx)
		+ float(velocity.vz) * float(velocity.vz)) \
		+ 0.5 * body_inertia * float(velocity.yawRate) * float(velocity.yawRate)

func random_body() -> Dictionary:
	return body(random_range(-18.0, 18.0), random_range(-18.0, 18.0),
		random_range(-32.0, 32.0), random_range(-32.0, 32.0),
		random_range(500.0, 15000.0), random_range(0.6, 2.1),
		random_range(1.2, 6.0), random_range(-4.0, 4.0))

func random_range(low: float, high: float) -> float:
	seed = int((seed * 1664525 + 1013904223) & 0xffffffff)
	return low + (high - low) * (float(seed) / 4294967296.0)
