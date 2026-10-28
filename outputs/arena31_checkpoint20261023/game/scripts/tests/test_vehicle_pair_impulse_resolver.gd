extends SceneTree
## Source transcript, invariants, purity and bounded CPU evidence for the pure
## planar vehicle-pair impulse candidate. No scene/physics server is used.

const Resolver = preload("res://scripts/vehicle_physics/vehicle_pair_impulse_resolver.gd")
const RESOLVER_PATH := "res://scripts/vehicle_physics/vehicle_pair_impulse_resolver.gd"
const EXPORTER_PATH := "res://scripts/tests/export_vehicle_pair_impulse_oracle.mjs"
const SOURCE_PATH := "res://../../assets/maps/city_rebuild_v1/vehicle_pair_impulse.mjs"
const SOURCE_SHA256 := "544a6a3c0d3b406ada6f60d38084e3e9ace488e12e7b404e2d9ea75bbb2abbe1"
const EXPECTED_ORACLE_CASES := 278
const COST_WARM_CALLS := 1024
const COST_BLOCKS := 64
const COST_CALLS_PER_BLOCK := 256

var checks := 0
var failures: Array[String] = []
var scalar_oracle_comparisons := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256, "exact source pair-impulse receipt")
	var oracle := node_oracle()
	check(not oracle.is_empty(), "actual Node source oracle exports JSON transcript")
	if oracle.is_empty():
		finish({}, {})
		return
	check(oracle.source_sha256 == SOURCE_SHA256, "Node imported exact pinned source bytes")
	check((oracle.cases as Array).size() == EXPECTED_ORACLE_CASES,
		"oracle includes named boundaries plus 256 deterministic randomized cases")

	var actual_by_id := {}
	var input_by_id := {}
	for case_value: Variant in oracle.cases:
		var case_row: Dictionary = case_value
		var input: Dictionary = decode_tags(case_row.input)
		var expected: Dictionary = decode_tags(case_row.expected)
		var actual: Dictionary = Resolver.resolve_source(input.a, input.b, input.contact,
			input.get("options", {}))
		compare_recursive(actual, expected, "oracle/%s" % case_row.id)
		actual_by_id[case_row.id] = actual
		input_by_id[case_row.id] = input

	check(bool(actual_by_id.equal_centered.resolved)
		and is_equal_approx(float(actual_by_id.equal_centered.deltaVA),
			float(actual_by_id.equal_centered.deltaVB)),
		"equal masses receive equal directed delta-V")
	check(float(actual_by_id.light_into_heavy.deltaVA)
		> float(actual_by_id.light_into_heavy.deltaVB),
		"light target receives larger directed delta-V")
	check(not bool(actual_by_id.separating.resolved)
		and is_zero_approx(float(actual_by_id.separating.closingSpeed)),
		"separating contact remains unresolved")
	check(not bool(actual_by_id.degenerate_normal.resolved)
		and not bool(actual_by_id.nonfinite_contact.resolved)
		and not bool(actual_by_id.invalid_mass.resolved),
		"degenerate, nonfinite and invalid-mass inputs fail finite and unresolved")
	var fallback_result := Resolver.resolve_source(
		{"x": 0.0, "z": 0.0, "mass": -1.0, "vx": NAN, "vz": INF, "yawRate": -INF},
		input_by_id.nonfinite_velocity_fallback.b,
		input_by_id.nonfinite_velocity_fallback.contact, {})
	check(float(fallback_result.a.vx) == 0.0 and float(fallback_result.a.vz) == 0.0
		and float(fallback_result.a.yawRate) == 0.0,
		"nonfinite body velocity fields use exact source zero fallback")
	check(not bool(actual_by_id.extreme_impulse_overflow.resolved)
		and is_finite(float(actual_by_id.extreme_impulse_overflow.closingSpeed))
		and float(actual_by_id.extreme_impulse_overflow.closingSpeed) > 1.0e307,
		"post-closing overflow returns unresolved while retaining finite closingSpeed")
	check(bool(actual_by_id.robust_hypot_normal.resolved),
		"scaled hypot admits an extreme but normalizable source normal")
	check(near(float(actual_by_id.restitution_null_fallback.impulse),
		float(actual_by_id.options_missing_defaults.impulse)),
		"null restitution uses source default rather than numeric coercion")
	check(float(actual_by_id.restitution_low_clamp.impulse)
		< float(actual_by_id.restitution_high_clamp.impulse),
		"restitution clamps to distinct zero and one endpoints")
	check(float(actual_by_id.angular_false.a.yawRate)
		== float(input_by_id.angular_false.a.yawRate)
		and float(actual_by_id.angular_false.b.yawRate)
		== float(input_by_id.angular_false.b.yawRate),
		"angular false disables rotational response exactly")

	check_swap_and_conservation(input_by_id.offset_yaw)
	check_origin_and_normal_scale_invariance(input_by_id.offset_yaw)
	check_wrapper_and_purity(input_by_id.offset_yaw)
	var cost := benchmark(input_by_id.offset_yaw)
	check(bool(cost.valid) and float(cost.p95_us_per_call) < 250.0,
		"pure resolver p95 remains below bounded 250-us diagnostic ceiling")
	finish({"oracle_cases": (oracle.cases as Array).size(),
		"scalar_comparisons": scalar_oracle_comparisons}, cost)

func node_oracle() -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute("node", PackedStringArray([
		ProjectSettings.globalize_path(EXPORTER_PATH),
		ProjectSettings.globalize_path(SOURCE_PATH)]), output, true)
	check(exit_code == 0, "Node oracle exporter exits zero")
	if exit_code != 0 or output.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str(output[0]))
	check(parsed is Dictionary, "Node oracle transcript parses")
	return parsed if parsed is Dictionary else {}

func decode_tags(value: Variant) -> Variant:
	if value is Array:
		var decoded: Array = []
		decoded.resize(value.size())
		for index in value.size():
			decoded[index] = decode_tags(value[index])
		return decoded
	if value is Dictionary:
		if value.size() == 1 and value.has("$number"):
			match str(value["$number"]):
				"NaN": return NAN
				"Infinity": return INF
				"-Infinity": return -INF
		var decoded := {}
		for key: Variant in value:
			decoded[key] = decode_tags(value[key])
		return decoded
	return value

func compare_recursive(actual: Variant, expected: Variant, path: String) -> void:
	if expected is Dictionary:
		if not actual is Dictionary:
			check(false, "%s expected Dictionary" % path)
			return
		check(actual.size() == expected.size(), "%s dictionary key count" % path)
		for key: Variant in expected:
			check(actual.has(key), "%s missing key %s" % [path, key])
			if actual.has(key):
				compare_recursive(actual[key], expected[key], "%s/%s" % [path, key])
		return
	if expected is Array:
		if not actual is Array:
			check(false, "%s expected Array" % path)
			return
		check(actual.size() == expected.size(), "%s array size" % path)
		for index in mini(actual.size(), expected.size()):
			compare_recursive(actual[index], expected[index], "%s/%d" % [path, index])
		return
	if expected is int or expected is float:
		scalar_oracle_comparisons += 1
		check((actual is int or actual is float) and near(float(actual), float(expected)),
			"%s numeric source parity" % path)
		return
	check(actual == expected, "%s exact source parity" % path)

func check_swap_and_conservation(input: Dictionary) -> void:
	var a: Dictionary = input.a
	var b: Dictionary = input.b
	var contact: Dictionary = input.contact
	var options: Dictionary = input.options
	var result := Resolver.resolve_source(a, b, contact, options)
	var swapped_contact := contact.duplicate(true)
	swapped_contact.normal.x = -float(contact.normal.x)
	swapped_contact.normal.z = -float(contact.normal.z)
	var swapped := Resolver.resolve_source(b, a, swapped_contact, options)
	check(bool(result.resolved) and bool(swapped.resolved), "swap invariant case resolves both directions")
	check(near(float(result.impulse), float(swapped.impulse))
		and near(float(result.deltaVA), float(swapped.deltaVB))
		and near(float(result.deltaVB), float(swapped.deltaVA)),
		"swap with reversed normal preserves J and exchanges directed delta-V")
	compare_recursive(result.a, swapped.b, "swap/a_to_b")
	compare_recursive(result.b, swapped.a, "swap/b_to_a")

	var before_px := float(a.mass) * float(a.vx) + float(b.mass) * float(b.vx)
	var before_pz := float(a.mass) * float(a.vz) + float(b.mass) * float(b.vz)
	var after_px := float(a.mass) * float(result.a.vx) + float(b.mass) * float(result.b.vx)
	var after_pz := float(a.mass) * float(result.a.vz) + float(b.mass) * float(result.b.vz)
	check(near(before_px, after_px) and near(before_pz, after_pz),
		"resolved pair conserves planar linear momentum")
	var inertia_a := float(a.mass) * (float(a.halfWidth) * float(a.halfWidth)
		+ float(a.halfLength) * float(a.halfLength)) / 3.0
	var inertia_b := float(b.mass) * (float(b.halfWidth) * float(b.halfWidth)
		+ float(b.halfLength) * float(b.halfLength)) / 3.0
	var before_l := float(a.z) * float(a.mass) * float(a.vx) \
		- float(a.x) * float(a.mass) * float(a.vz) + inertia_a * float(a.yawRate) \
		+ float(b.z) * float(b.mass) * float(b.vx) \
		- float(b.x) * float(b.mass) * float(b.vz) + inertia_b * float(b.yawRate)
	var after_l := float(a.z) * float(a.mass) * float(result.a.vx) \
		- float(a.x) * float(a.mass) * float(result.a.vz) + inertia_a * float(result.a.yawRate) \
		+ float(b.z) * float(b.mass) * float(result.b.vx) \
		- float(b.x) * float(b.mass) * float(result.b.vz) + inertia_b * float(result.b.yawRate)
	check(near(before_l, after_l), "resolved pair conserves world-origin angular momentum")
	var before_energy := kinetic_energy(a, a, inertia_a) + kinetic_energy(b, b, inertia_b)
	var after_energy := kinetic_energy(a, result.a, inertia_a) + kinetic_energy(b, result.b, inertia_b)
	check(after_energy <= before_energy + maxf(1.0, before_energy) * 1.0e-11,
		"restitution within zero-to-one clamp does not grow kinetic energy")

func check_origin_and_normal_scale_invariance(input: Dictionary) -> void:
	var base := Resolver.resolve_source(input.a, input.b, input.contact, input.options)
	var shifted_a: Dictionary = input.a.duplicate(true)
	var shifted_b: Dictionary = input.b.duplicate(true)
	var shifted_contact: Dictionary = input.contact.duplicate(true)
	for row: Dictionary in [shifted_a, shifted_b, shifted_contact.point]:
		row.x = float(row.x) + 12345.0
		row.z = float(row.z) - 54321.0
	var shifted := Resolver.resolve_source(shifted_a, shifted_b, shifted_contact, input.options)
	compare_recursive(shifted, base, "world_origin_shift")
	var scaled_contact: Dictionary = input.contact.duplicate(true)
	scaled_contact.normal.x = float(scaled_contact.normal.x) * 73.0
	scaled_contact.normal.z = float(scaled_contact.normal.z) * 73.0
	var scaled := Resolver.resolve_source(input.a, input.b, scaled_contact, input.options)
	compare_recursive(scaled, base, "normal_scale")

func check_wrapper_and_purity(input: Dictionary) -> void:
	var before := input.duplicate(true)
	var proposal := Resolver.propose(input.a, input.b, input.contact, input.options)
	check(input == before, "resolver and wrapper do not mutate caller dictionaries")
	check(bool(proposal.valid) and bool(proposal.proposal_only)
		and not bool(proposal.server_admissible), "wrapper is explicitly proposal-only")
	check(proposal.source_axes.plane == "+X/+Z" and proposal.source_axes.yaw_axis == "+Y"
		and proposal.source_axes.normal_direction == "A_to_B",
		"wrapper exposes source axes without hidden native conversion")
	check(not proposal.has("event_id") and not proposal.has("impactSpeed")
		and not proposal.has("hp") and not proposal.has("damage"),
		"wrapper fabricates no event, impact speed, HP or damage authority")
	var malformed := Resolver.propose(null, input.b, input.contact, input.options)
	check(not bool(malformed.valid) and bool(malformed.proposal_only)
		and not bool(malformed.server_admissible), "malformed public containers fail closed")
	var contract := Resolver.contract()
	check(contract.source_sha256 == SOURCE_SHA256 and bool(contract.pure)
		and not bool(contract.mutates_inputs) and not bool(contract.applies_body_force)
		and not bool(contract.reads_native_reported_impulse)
		and not bool(contract.owns_event_identity) and not bool(contract.owns_hp),
		"contract pins source purity and authority exclusions")
	var result_copy: Dictionary = proposal.source_result
	result_copy.a.vx = 999.0
	result_copy.impulseA.x = 888.0
	check(input == before, "mutating proposal result cannot mutate caller input")

func kinetic_energy(body: Dictionary, velocity: Dictionary, inertia: float) -> float:
	return 0.5 * float(body.mass) * (float(velocity.vx) * float(velocity.vx)
		+ float(velocity.vz) * float(velocity.vz)) \
		+ 0.5 * inertia * float(velocity.yawRate) * float(velocity.yawRate)

func benchmark(input: Dictionary) -> Dictionary:
	for _warm in COST_WARM_CALLS:
		Resolver.resolve_source(input.a, input.b, input.contact, input.options)
	var samples := PackedFloat64Array()
	samples.resize(COST_BLOCKS)
	for block in COST_BLOCKS:
		var started_us := Time.get_ticks_usec()
		for _call in COST_CALLS_PER_BLOCK:
			Resolver.resolve_source(input.a, input.b, input.contact, input.options)
		samples[block] = float(Time.get_ticks_usec() - started_us) / COST_CALLS_PER_BLOCK
	samples.sort()
	var last := samples.size() - 1
	return {"valid": is_finite(samples[last]), "warm_calls": COST_WARM_CALLS,
		"blocks": COST_BLOCKS, "calls_per_block": COST_CALLS_PER_BLOCK,
		"p50_us_per_call": samples[int(floor(last * 0.50))],
		"p95_us_per_call": samples[int(floor(last * 0.95))],
		"max_us_per_call": samples[last],
		"scope": "isolated pure dictionary math wall latency; no FPS/aggregate CPU/LIVE claim"}

func near(actual: float, expected: float) -> bool:
	if actual == expected:
		return true
	if not is_finite(actual) or not is_finite(expected):
		return false
	return absf(actual - expected) <= 1.0e-11 * maxf(1.0, absf(expected))

func finish(oracle: Dictionary, cost: Dictionary) -> void:
	print("NATIVE_VEHICLE_PAIR_IMPULSE_RESOLVER_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"source_sha256": FileAccess.get_sha256(SOURCE_PATH),
		"resolver_sha256": FileAccess.get_sha256(RESOLVER_PATH),
		"oracle_exporter_sha256": FileAccess.get_sha256(EXPORTER_PATH),
		"oracle": oracle, "cost": cost, "runtime_wired": false,
		"qualification": "pure source-axis planar pair proposal only; no native force, event, crash, HP, server, body/main, GPU, LIVE or FPS claim"
	}))
	quit(0 if failures.is_empty() else 1)
