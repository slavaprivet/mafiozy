extends SceneTree
## Independent analytic/invariant review of source polygon contact and passive
## linear contact kinematics. No native collision or authority is exercised.

const Geometry = preload("res://scripts/vehicle_physics/vehicle_contact_geometry_source.gd")
const GEOMETRY_PATH := "res://scripts/vehicle_physics/vehicle_contact_geometry_source.gd"
const GEOMETRY_SHA256 := "9cdc97825a072b14410b75e1dd3813aef6855e1e380b1a4f7c89ece36636fc9c"
const SOURCE_PATH := "res://../../assets/maps/city_rebuild_v1/vehicle_contact.mjs"
const SOURCE_SHA256 := "668e776961d474e6a2bceb62f6435027b859f926b819c0f77da5f4bb0afd4020"
const RANDOM_CASES := 192

var checks := 0
var failures: Array[String] = []
var seed := 0x47524D31
var random_contact_count := 0

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

func run() -> void:
	check(FileAccess.get_sha256(GEOMETRY_PATH) == GEOMETRY_SHA256,
		"exact frozen geometry candidate")
	check(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256,
		"exact source vehicle_contact bytes")
	check_contract()
	check_basic_and_touching()
	check_ties_corner_and_zero_edge()
	check_malformed_boundaries()
	check_passive_kinematics()
	check_purity_and_wrappers()
	check_random_support_invariants()
	check(random_contact_count > 90,
		"deterministic matrix includes many finite overlapping contacts")
	print("NATIVE_VEHICLE_CONTACT_GEOMETRY_SOURCE_INDEPENDENT_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"geometry_sha256": FileAccess.get_sha256(GEOMETRY_PATH),
		"random_cases": RANDOM_CASES, "random_contacts": random_contact_count,
		"runtime_wired": false,
		"qualification": "independent pure source polygon/passive linear kinematics only; no native contact, role, event, crash, HP, body/main, GPU or LIVE claim"
	}))
	quit(0 if failures.is_empty() else 1)

func check_contract() -> void:
	var value: Dictionary = Geometry.contract()
	check(value.source_sha256 == SOURCE_SHA256 and bool(value.pure),
		"contract pins exact source and purity")
	check(value.plane == "+X/+Z" and value.normal_direction == "car_to_obstacle"
		and near(float(value.point_y_m), 0.8),
		"contract exposes source plane, normal direction, and authored y")
	check(value.kinematics_semantics == "passive_linear_speed_and_travel_yaw_only"
		and not bool(value.uses_yaw_arm_velocity)
		and not bool(value.uses_relative_peer_velocity),
		"kinematics contract excludes yaw-arm and peer-relative semantics")
	check(not bool(value.performs_raycast) and not bool(value.replaces_native_collision)
		and not bool(value.applies_body_force) and not bool(value.collision_role_validated)
		and not bool(value.owns_event_identity) and not bool(value.owns_crash_or_damage)
		and not bool(value.owns_hp) and not bool(value.server_admissible)
		and not bool(value.runtime_wired),
		"contract excludes collision role, native replacement, and authority")

func check_basic_and_touching() -> void:
	var car := [[-1.0, -2.0], [1.0, -2.0], [1.0, 2.0], [-1.0, 2.0]]
	var obstacle := [[0.9, -0.5], [2.0, -0.5], [2.0, 0.5], [0.9, 0.5]]
	var result: Dictionary = Geometry.polygon_vehicle_contact_source(car, obstacle)
	check(near(float(result.depth), 0.1) and near(float(result.normal.x), 1.0)
		and near(float(result.normal.z), 0.0),
		"basic overlap has analytic depth and car-to-obstacle +X normal")
	check(near(float(result.point.x), 1.0) and near(float(result.point.y), 0.8)
		and near(float(result.point.z), 0.0),
		"basic contact is the clipped midpoint on the car support face")
	check_support(car, result, "basic")
	var touching: Dictionary = Geometry.polygon_vehicle_contact_source(car,
		[[1.0, -3.0], [3.0, -3.0], [3.0, 3.0], [1.0, 3.0]])
	check(touching is Dictionary and near(float(touching.depth), 0.0),
		"exactly touching polygons return a zero-depth contact")
	var separated: Variant = Geometry.polygon_vehicle_contact_source(car,
		[[1.000001, -3.0], [3.0, -3.0], [3.0, 3.0], [1.000001, 3.0]])
	check(separated == null, "strict negative separation returns null")

func check_ties_corner_and_zero_edge() -> void:
	var square := [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]
	var obstacle := [[-0.5, -0.5], [1.5, -0.5], [1.5, 1.5], [-0.5, 1.5]]
	var first: Dictionary = Geometry.polygon_vehicle_contact_source(square, obstacle)
	var reordered := [square[1], square[2], square[3], square[0]]
	var second: Dictionary = Geometry.polygon_vehicle_contact_source(reordered, obstacle)
	check(absf(float(first.normal.z)) > 0.999999
		and absf(float(second.normal.x)) > 0.999999,
		"strict equal-depth tie retains the first input edge axis")
	var root2 := sqrt(2.0)
	var diamond := [[0.0, -root2], [root2, 0.0], [0.0, root2], [-root2, 0.0]]
	var wall := [[1.3, -10.0], [3.0, -10.0], [3.0, 10.0], [1.3, 10.0]]
	var corner: Dictionary = Geometry.polygon_vehicle_contact_source(diamond, wall)
	check(near(float(corner.point.x), root2) and near(float(corner.point.z), 0.0),
		"single support vertex clips to the rotated car corner")
	check_support(diamond, corner, "rotated_corner")
	var duplicate := [[-1.0, -1.0], [1.0, -1.0], [1.0, -1.0],
		[1.0, 1.0], [-1.0, 1.0]]
	var duplicate_hit: Variant = Geometry.polygon_vehicle_contact_source(duplicate,
		[[0.5, -1.0], [2.5, -1.0], [2.5, 1.0], [0.5, 1.0]])
	check(duplicate_hit is Dictionary,
		"zero-length edge is skipped while later valid axes remain")

func check_malformed_boundaries() -> void:
	var square := [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]
	check(Geometry.polygon_vehicle_contact_source([], square) == null
		and Geometry.polygon_vehicle_contact_source(square, []) == null,
		"empty polygon boundaries return null")
	check(Geometry.polygon_vehicle_contact_source([[0.0, 0.0]], [[0.0, 0.0]]) == null
		and Geometry.polygon_vehicle_contact_source(
			[[1.0, 1.0], [1.0, 1.0], [1.0, 1.0]],
			[[1.0, 1.0], [1.0, 1.0], [1.0, 1.0]]) == null,
		"single-point and all-degenerate polygons have no SAT normal")
	var nan_car := [[-1.0, -1.0], [1.0, -1.0], [NAN, 1.0], [-1.0, 1.0]]
	check(Geometry.polygon_vehicle_contact_source(nan_car, square) == null,
		"NaN projection follows source null result")
	var infinity_car := [[-1.0, -1.0], [1.0, -1.0], [INF, 1.0], [-1.0, 1.0]]
	var infinity_hit: Variant = Geometry.polygon_vehicle_contact_source(infinity_car,
		[[ -0.5, -1.0], [1.5, -1.0], [1.5, 1.0], [-0.5, 1.0]])
	check(infinity_hit is Dictionary
		and is_nan(float(infinity_hit.point.x)) and is_nan(float(infinity_hit.point.z)),
		"low-level source result preserves Infinity-carried NaN point")
	check(not bool(Geometry.propose_polygon(nan_car, square).valid)
		and not bool(Geometry.propose_polygon(infinity_car, square).valid)
		and not bool(Geometry.propose_polygon([], square).valid),
		"strict proposal boundary rejects nonfinite and undersized polygons")

func check_passive_kinematics() -> void:
	var base_contact := {"point": {"x": 1.0, "y": 0.8, "z": 0.0},
		"normal": {"x": 1.0, "y": 0.0, "z": 0.0}, "depth": 0.1}
	var forward: Dictionary = Geometry.contact_kinematics_source(base_contact, 10.0, PI / 2.0)
	check(near(float(forward.velocity.x), 10.0) and absf(float(forward.velocity.z)) < 1.0e-9
		and near(float(forward.impactSpeed), 10.0)
		and absf(float(forward.slideSpeed)) < 1.0e-9,
		"passive yaw/speed maps to linear velocity and normal impact")
	var reverse: Dictionary = Geometry.contact_kinematics_source(base_contact, -8.0, PI / 2.0)
	check(near(float(reverse.velocity.x), -8.0)
		and near(float(reverse.impactSpeed), 0.0),
		"negative source speed reverses velocity and clamps separating impact")
	var diagonal: Dictionary = base_contact.duplicate(true)
	diagonal.normal = {"x": 0.6, "y": 0.0, "z": 0.8}
	var diagonal_motion: Dictionary = Geometry.contact_kinematics_source(diagonal, 10.0, 0.0)
	check(near(float(diagonal_motion.impactSpeed), 8.0)
		and near(float(diagonal_motion.slideSpeed), 6.0),
		"passive normal and slide projections use linear velocity only")
	var scaled: Dictionary = diagonal.duplicate(true)
	scaled.normal = {"x": 1.2, "y": 0.0, "z": 1.6}
	var scaled_motion: Dictionary = Geometry.contact_kinematics_source(scaled, 10.0, 0.0)
	check(near(float(scaled_motion.impactSpeed), 16.0)
		and near(float(scaled_motion.slideSpeed), 12.0),
		"source passive helper does not secretly normalize caller normal")
	var proposal: Dictionary = Geometry.propose_kinematics(base_contact, 10.0, PI / 2.0)
	check(bool(proposal.valid)
		and proposal.kinematics_semantics == "passive_linear_speed_and_travel_yaw_only"
		and not bool(proposal.collision_role_validated)
		and not bool(proposal.server_admissible),
		"passive kinematics wrapper is labelled and non-authoritative")
	check(not bool(Geometry.propose_kinematics(base_contact, NAN, 0.0).valid)
		and not bool(Geometry.propose_kinematics(base_contact, 1.0, INF).valid),
		"strict passive wrapper rejects nonfinite speed/yaw")

func check_purity_and_wrappers() -> void:
	var car := [[-1.0, -2.0], [1.0, -2.0], [1.0, 2.0], [-1.0, 2.0]]
	var obstacle := [[0.9, -0.5], [2.0, -0.5], [2.0, 0.5], [0.9, 0.5]]
	var before_car := car.duplicate(true)
	var before_obstacle := obstacle.duplicate(true)
	var proposal: Dictionary = Geometry.propose_polygon(car, obstacle)
	check(car == before_car and obstacle == before_obstacle,
		"geometry call does not mutate polygon inputs")
	check(bool(proposal.valid) and bool(proposal.proposal_only)
		and not bool(proposal.server_admissible)
		and not bool(proposal.collision_role_validated),
		"finite polygon proposal remains role-free and proposal-only")
	check(proposal.source_axes.plane == "+X/+Z"
		and proposal.source_axes.normal_direction == "car_to_obstacle",
		"proposal repeats explicit source-axis contract")
	proposal.source_result.point.x = 999.0
	check(car == before_car and obstacle == before_obstacle,
		"mutating result cannot mutate polygon inputs")
	var separated := Geometry.propose_polygon(car,
		[[10.0, -1.0], [12.0, -1.0], [12.0, 1.0], [10.0, 1.0]])
	check(bool(separated.valid) and separated.source_result == null,
		"proposal validity means finite containers, not collision or role admission")

func check_random_support_invariants() -> void:
	for index in RANDOM_CASES:
		var yaw := random_range(-PI, PI)
		var car := rectangle(random_range(-30.0, 30.0), random_range(-30.0, 30.0),
			random_range(0.5, 2.5), random_range(1.0, 5.5), yaw, index % 4)
		var car_center := polygon_center(car)
		var obstacle := rectangle(car_center.x + random_range(-2.0, 2.0),
			car_center.y + random_range(-2.0, 2.0), random_range(0.5, 2.8),
			random_range(0.8, 5.0), random_range(-PI, PI), index % 3)
		var result: Variant = Geometry.polygon_vehicle_contact_source(car, obstacle)
		if result == null:
			continue
		var hit: Dictionary = result
		random_contact_count += 1
		check(is_finite(float(hit.depth)) and float(hit.depth) >= 0.0,
			"random contact depth is finite/nonnegative %d" % index)
		check(near(Vector2(float(hit.normal.x), float(hit.normal.z)).length(), 1.0,
			2.0e-6),
			"random contact normal is unit length %d" % index)
		check(near(float(hit.point.y), 0.8),
			"random contact retains y=0.8 %d" % index)
		check_support(car, hit, "random_%d" % index)
		var obstacle_center := polygon_center(obstacle)
		var toward := Vector2(obstacle_center.x - car_center.x,
			obstacle_center.y - car_center.y)
		check(Vector2(float(hit.normal.x), float(hit.normal.z)).dot(toward) >= -1.0e-8,
			"random contact normal points car-to-obstacle %d" % index)

func check_support(car: Array, hit: Dictionary, label: String) -> void:
	var normal := Vector2(float(hit.normal.x), float(hit.normal.z))
	var support := -INF
	for vertex: Array in car:
		support = maxf(support, Vector2(float(vertex[0]), float(vertex[1])).dot(normal))
	var projection := Vector2(float(hit.point.x), float(hit.point.z)).dot(normal)
	# This independent invariant recomputes the dot product through Vector2;
	# tolerate accumulated float error at world coordinates up to 30 m. Exact
	# source parity is covered separately by the binary64 transcript oracle.
	check(absf(projection - support) <= 2.0e-5,
		"%s point lies on car support plane" % label)

func rectangle(cx: float, cz: float, half_x: float, half_z: float,
		yaw: float, start: int) -> Array:
	var cosine := cos(yaw)
	var sine := sin(yaw)
	var base := [[-half_x, -half_z], [half_x, -half_z],
		[half_x, half_z], [-half_x, half_z]]
	var vertices: Array = []
	for vertex: Array in base:
		vertices.append([cx + float(vertex[0]) * cosine + float(vertex[1]) * sine,
			cz - float(vertex[0]) * sine + float(vertex[1]) * cosine])
	return vertices.slice(start) + vertices.slice(0, start)

func polygon_center(polygon: Array) -> Vector2:
	var result := Vector2.ZERO
	for vertex: Array in polygon:
		result += Vector2(float(vertex[0]), float(vertex[1])) / polygon.size()
	return result

func random_range(low: float, high: float) -> float:
	seed = int((seed * 1664525 + 1013904223) & 0xffffffff)
	return low + (high - low) * float(seed) / 4294967296.0
