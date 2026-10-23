extends SceneTree
## Actual Node transcript, boundary and bounded-cost test for the pure source
## polygon contact + passive contactKinematics port.

const Geometry = preload("res://scripts/vehicle_physics/vehicle_contact_geometry_source.gd")
const GEOMETRY_PATH := "res://scripts/vehicle_physics/vehicle_contact_geometry_source.gd"
const EXPORTER_PATH := "res://scripts/tests/export_vehicle_contact_geometry_oracle.mjs"
const SOURCE_PATH := "res://../../assets/maps/city_rebuild_v1/vehicle_contact.mjs"
const SOURCE_SHA256 := "668e776961d474e6a2bceb62f6435027b859f926b819c0f77da5f4bb0afd4020"
const EXPECTED_CASES := 275
const COST_WARM_CALLS := 512
const COST_BLOCKS := 64
const COST_CALLS_PER_BLOCK := 128

var checks := 0
var failures: Array[String] = []
var numeric_oracle_comparisons := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256,
		"exact source vehicle_contact receipt")
	var oracle := node_oracle()
	check(not oracle.is_empty(), "actual Node source oracle exports transcript")
	if oracle.is_empty():
		finish({}, {})
		return
	check(oracle.source_sha256 == SOURCE_SHA256, "Node imported exact pinned source bytes")
	check((oracle.cases as Array).size() == EXPECTED_CASES,
		"oracle contains named boundaries plus 256 deterministic random pairs")
	var actual_by_id := {}
	var input_by_id := {}
	var finite_contact_count := 0
	for case_value: Variant in oracle.cases:
		var case_row: Dictionary = case_value
		var input: Dictionary = decode_tags(case_row.input)
		var expected_geometry: Variant = decode_tags(case_row.geometry)
		var expected_motion: Variant = decode_tags(case_row.motion)
		var actual_geometry: Variant = Geometry.polygon_vehicle_contact_source(
			input.car, input.obstacle)
		compare_recursive(actual_geometry, expected_geometry, "geometry/%s" % case_row.id)
		var actual_motion: Variant = null
		if input.has("speed") and actual_geometry is Dictionary:
			actual_motion = Geometry.contact_kinematics_source(actual_geometry,
				input.speed, input.travelYaw)
		compare_recursive(actual_motion, expected_motion, "motion/%s" % case_row.id)
		actual_by_id[case_row.id] = {"geometry": actual_geometry, "motion": actual_motion}
		input_by_id[case_row.id] = input
		if actual_geometry is Dictionary and finite_contact(actual_geometry):
			finite_contact_count += 1
			check_support_on_car(input.car, actual_geometry, "support/%s" % case_row.id)

	check(actual_by_id.separated.geometry == null,
		"strict negative separation returns null")
	check(actual_by_id.touching.geometry is Dictionary
		and is_zero_approx(float(actual_by_id.touching.geometry.depth)),
		"touching polygons produce exact zero-depth contact")
	var corner: Dictionary = actual_by_id.rotated_single_corner.geometry
	check(near(float(corner.point.x), sqrt(2.0)) and near(float(corner.point.z), 0.0),
		"support-face clipping places rotated single-support contact on the car corner")
	check(near(float(corner.point.y), 0.8), "contact point y=0.8 is preserved source fact")
	var tie_first: Dictionary = actual_by_id.tie_first_axis.geometry
	var tie_reordered: Dictionary = actual_by_id.tie_reordered.geometry
	check(absf(float(tie_first.normal.z)) > 0.99 and absf(float(tie_reordered.normal.x)) > 0.99,
		"strict overlap tie keeps first edge axis and changes with input start order")
	check(actual_by_id.zero_edge_duplicate.geometry is Dictionary,
		"edge shorter than 1e-8 is skipped without losing later valid axes")
	check(actual_by_id.nan_projection.geometry == null
		and actual_by_id.infinity_projection.geometry is Dictionary
		and is_nan(float(actual_by_id.infinity_projection.geometry.point.x))
		and is_nan(float(actual_by_id.infinity_projection.geometry.point.z))
		and near(float(actual_by_id.infinity_projection.geometry.depth), 2.0),
		"source distinguishes NaN rejection from Infinity-carried NaN contact point")
	check(actual_by_id.empty_car.geometry == null
		and actual_by_id.empty_obstacle.geometry == null
		and actual_by_id.all_degenerate.geometry == null,
		"empty and all-degenerate polygons return null")
	var basic_motion: Dictionary = actual_by_id.basic_side_overlap.motion
	check(near(float(basic_motion.impactSpeed), 10.0)
		and absf(float(basic_motion.slideSpeed)) < 1.0e-8,
		"passive linear kinematics resolves forward normal speed without yaw arm")
	var reverse_motion: Dictionary = actual_by_id.reverse_speed.motion
	check(is_zero_approx(float(reverse_motion.impactSpeed)),
		"reverse travel clamps passive impact speed to zero")
	check(near(float(basic_motion.velocity.x), 10.0)
		and absf(float(basic_motion.velocity.z)) < 1.0e-8
		and is_zero_approx(float(basic_motion.velocity.y)),
		"travelYaw maps source speed to vx=sin(yaw), vz=cos(yaw)")

	check_transform_invariance(input_by_id.basic_side_overlap)
	check_wrappers_and_purity(input_by_id.basic_side_overlap)
	var cost := benchmark(input_by_id.large_translation)
	check(bool(cost.valid) and float(cost.p95_us_per_call) < 500.0,
		"pure polygon source resolver p95 remains below bounded 500-us diagnostic ceiling")
	finish({"oracle_cases": (oracle.cases as Array).size(),
		"finite_contacts": finite_contact_count,
		"numeric_comparisons": numeric_oracle_comparisons}, cost)

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
	if expected == null:
		check(actual == null, "%s null source parity" % path)
		return
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
		numeric_oracle_comparisons += 1
		var numeric := actual is int or actual is float
		var same := numeric and ((is_nan(float(expected)) and is_nan(float(actual)))
			or (is_inf(float(expected)) and float(actual) == float(expected))
			or near(float(actual), float(expected)))
		check(same, "%s numeric source parity actual=%s expected=%s" % [
			path, actual, expected])
		return
	check(actual == expected, "%s exact source parity" % path)

func finite_contact(contact: Dictionary) -> bool:
	return is_finite(float(contact.depth)) and is_finite(float(contact.point.x)) \
		and is_finite(float(contact.point.z)) and is_finite(float(contact.normal.x)) \
		and is_finite(float(contact.normal.z))

func check_support_on_car(car: Array, contact: Dictionary, label: String) -> void:
	var nx := float(contact.normal.x)
	var nz := float(contact.normal.z)
	var support := -INF
	for vertex: Array in car:
		support = maxf(support, float(vertex[0]) * nx + float(vertex[1]) * nz)
	var point_projection := float(contact.point.x) * nx + float(contact.point.z) * nz
	check(near(point_projection, support), "%s point lies on car support plane" % label)

func check_transform_invariance(input: Dictionary) -> void:
	var base: Dictionary = Geometry.polygon_vehicle_contact_source(input.car, input.obstacle)
	var angle := 0.47
	var cosine := cos(angle)
	var sine := sin(angle)
	var shifted_car := transform_polygon(input.car, cosine, sine, 123.0, -77.0, 2.5)
	var shifted_obstacle := transform_polygon(input.obstacle, cosine, sine, 123.0, -77.0, 2.5)
	var transformed: Dictionary = Geometry.polygon_vehicle_contact_source(
		shifted_car, shifted_obstacle)
	var expected_x := 123.0 + 2.5 * (float(base.point.x) * cosine + float(base.point.z) * sine)
	var expected_z := -77.0 + 2.5 * (-float(base.point.x) * sine + float(base.point.z) * cosine)
	var expected_nx := float(base.normal.x) * cosine + float(base.normal.z) * sine
	var expected_nz := -float(base.normal.x) * sine + float(base.normal.z) * cosine
	check(near(float(transformed.point.x), expected_x)
		and near(float(transformed.point.z), expected_z),
		"translation/rotation/scale transforms source contact point")
	check(near(float(transformed.normal.x), expected_nx)
		and near(float(transformed.normal.z), expected_nz)
		and near(float(transformed.depth), float(base.depth) * 2.5),
		"rotation/scale transforms normal and penetration depth")

func transform_polygon(polygon: Array, cosine: float, sine: float,
		offset_x: float, offset_z: float, scale: float) -> Array:
	var result: Array = []
	for vertex: Array in polygon:
		result.append([offset_x + scale * (float(vertex[0]) * cosine + float(vertex[1]) * sine),
			offset_z + scale * (-float(vertex[0]) * sine + float(vertex[1]) * cosine)])
	return result

func check_wrappers_and_purity(input: Dictionary) -> void:
	var before := input.duplicate(true)
	var proposal := Geometry.propose_polygon(input.car, input.obstacle)
	check(input == before, "geometry resolver does not mutate caller polygons")
	check(bool(proposal.valid) and bool(proposal.proposal_only)
		and not bool(proposal.server_admissible)
		and not bool(proposal.collision_role_validated)
		and bool(proposal.valid_means_input_shape_only),
		"geometry wrapper is proposal-only and never infers collision role")
	check(proposal.source_axes.plane == "+X/+Z"
		and proposal.source_axes.normal_direction == "car_to_obstacle"
		and near(float(proposal.source_axes.point_y_m), 0.8),
		"geometry wrapper exposes source axes and y fact")
	var motion := Geometry.propose_kinematics(proposal.source_result, input.speed,
		input.travelYaw)
	check(bool(motion.valid) and motion.kinematics_semantics \
		== "passive_linear_speed_and_travel_yaw_only",
		"kinematics wrapper identifies passive linear source semantics")
	check(not Geometry.propose_polygon([], input.obstacle).valid
		and not Geometry.propose_polygon([[NAN, 0], [1, 0], [0, 1]], input.obstacle).valid,
		"strict public admission rejects empty and nonfinite polygons safely")
	check(not Geometry.propose_kinematics(proposal.source_result, NAN, 0.0).valid,
		"strict public kinematics admission rejects nonfinite speed")
	var contract := Geometry.contract()
	check(contract.source_sha256 == SOURCE_SHA256 and bool(contract.pure)
		and not bool(contract.uses_yaw_arm_velocity)
		and not bool(contract.uses_relative_peer_velocity)
		and not bool(contract.performs_raycast)
		and not bool(contract.replaces_native_collision)
		and not bool(contract.applies_body_force)
		and not bool(contract.collision_role_validated)
		and not bool(contract.owns_crash_or_damage)
		and bool(contract.strict_wrapper_rejects_nonfinite_before_source)
		and bool(contract.native_output_deep_copied)
		and not bool(contract.source_shallow_spread_aliasing_preserved),
		"contract pins pure passive source scope and authority exclusions")
	var exported: Dictionary = proposal.source_result
	exported.point.x = 999.0
	check(input == before, "mutating returned proposal cannot mutate caller input")

func benchmark(input: Dictionary) -> Dictionary:
	for _warm in COST_WARM_CALLS:
		Geometry.polygon_vehicle_contact_source(input.car, input.obstacle)
	var samples := PackedFloat64Array()
	samples.resize(COST_BLOCKS)
	for block in COST_BLOCKS:
		var started_us := Time.get_ticks_usec()
		for _call in COST_CALLS_PER_BLOCK:
			Geometry.polygon_vehicle_contact_source(input.car, input.obstacle)
		samples[block] = float(Time.get_ticks_usec() - started_us) / COST_CALLS_PER_BLOCK
	samples.sort()
	var last := samples.size() - 1
	return {"valid": is_finite(samples[last]), "warm_calls": COST_WARM_CALLS,
		"blocks": COST_BLOCKS, "calls_per_block": COST_CALLS_PER_BLOCK,
		"p50_us_per_call": samples[int(floor(last * 0.50))],
		"p95_us_per_call": samples[int(floor(last * 0.95))],
		"max_us_per_call": samples[last],
		"scope": "isolated pure polygon dictionary math wall latency; no FPS/aggregate CPU/LIVE claim"}

func near(actual: float, expected: float) -> bool:
	if actual == expected:
		return true
	if not is_finite(actual) or not is_finite(expected):
		return false
	# Godot JSON ingestion of the 1e9 translated transcript loses several edge
	# subtraction ulps relative to the pre-serialization Node calculation.
	return absf(actual - expected) <= 1.0e-7 * maxf(1.0, absf(expected))

func finish(oracle: Dictionary, cost: Dictionary) -> void:
	print("NATIVE_VEHICLE_CONTACT_GEOMETRY_SOURCE_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"source_sha256": FileAccess.get_sha256(SOURCE_PATH),
		"geometry_sha256": FileAccess.get_sha256(GEOMETRY_PATH),
		"oracle_exporter_sha256": FileAccess.get_sha256(EXPORTER_PATH),
		"oracle": oracle, "cost": cost, "runtime_wired": false,
		"qualification": "pure source-axis polygon contact and passive linear kinematics only; no native replacement, raycast, force, role, crash, authority, body/main, GPU, LIVE or FPS claim"
	}))
	quit(0 if failures.is_empty() else 1)
