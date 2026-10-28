extends RefCounted
## Pure source-axis port of polygonVehicleContact + contactKinematics.
##
## Polygons are arrays of [x,z] vertices in source world metres. Output y=0.8
## and the +X/+Z normal are source facts. The normal points from the first
## polygon (car) toward the second polygon (obstacle). No collision role,
## raycast, native replacement, response, crash or authority is inferred.

const SOURCE_SHA256 := "668e776961d474e6a2bceb62f6435027b859f926b819c0f77da5f4bb0afd4020"
const EDGE_EPSILON := 1.0e-8
const SUPPORT_FACE_EPSILON := 1.0e-6

static func polygon_vehicle_contact_source(car_value: Variant,
		obstacle_value: Variant) -> Variant:
	# The JS source expects array-like polygons and can throw for malformed nested
	# containers. This native exact-result entry point stays nonthrowing; strict
	# public admission is available separately through propose_polygon().
	if not car_value is Array or not obstacle_value is Array:
		return null
	var car: Array = car_value
	var obstacle: Array = obstacle_value
	var depth := INF
	var has_normal := false
	var nx := 0.0
	var nz := 0.0
	var center_a_x := 0.0
	var center_a_z := 0.0
	var center_b_x := 0.0
	var center_b_z := 0.0
	# Preserve source summation: divide each vertex component before addition.
	for index in car.size():
		center_a_x += _coord(car[index], 0) / car.size()
		center_a_z += _coord(car[index], 1) / car.size()
	for index in obstacle.size():
		center_b_x += _coord(obstacle[index], 0) / obstacle.size()
		center_b_z += _coord(obstacle[index], 1) / obstacle.size()

	# Source order is all car edges, followed by all obstacle edges. Strict < on
	# depth means the first axis wins an exact overlap tie.
	for source in 2:
		var polygon: Array = obstacle if source != 0 else car
		for index in polygon.size():
			var next := (index + 1) % polygon.size()
			var dx := _coord(polygon[next], 0) - _coord(polygon[index], 0)
			var dz := _coord(polygon[next], 1) - _coord(polygon[index], 1)
			var edge_length := _hypot(dx, dz)
			if edge_length < EDGE_EPSILON:
				continue
			var axis_x := -dz / edge_length
			var axis_z := dx / edge_length
			var car_range := _project(car, axis_x, axis_z)
			var obstacle_range := _project(obstacle, axis_x, axis_z)
			var overlap := _js_min(float(car_range.maximum), float(obstacle_range.maximum)) \
				- _js_max(float(car_range.minimum), float(obstacle_range.minimum))
			if overlap < 0.0:
				return null
			if overlap < depth:
				if (center_b_x - center_a_x) * axis_x \
						+ (center_b_z - center_a_z) * axis_z < 0.0:
					axis_x = -axis_x
					axis_z = -axis_z
				depth = overlap
				nx = axis_x
				nz = axis_z
				has_normal = true
	if not has_normal:
		return null

	var tangent_x := -nz
	var tangent_z := nx
	var car_tangent := _project(car, tangent_x, tangent_z)
	var obstacle_tangent := _project(obstacle, tangent_x, tangent_z)
	var tangent_mid := (_js_max(float(car_tangent.minimum),
		float(obstacle_tangent.minimum)) + _js_min(float(car_tangent.maximum),
		float(obstacle_tangent.maximum))) / 2.0
	var support := -INF
	for vertex: Variant in car:
		var value := _coord(vertex, 0) * nx + _coord(vertex, 1) * nz
		if is_nan(value):
			support = NAN
			break
		if value > support:
			support = value
	var face_min := INF
	var face_max := -INF
	for vertex: Variant in car:
		if support - (_coord(vertex, 0) * nx + _coord(vertex, 1) * nz) \
				< SUPPORT_FACE_EPSILON:
			var value := _coord(vertex, 0) * tangent_x + _coord(vertex, 1) * tangent_z
			if is_nan(value):
				face_min = NAN
				face_max = NAN
				break
			if value > face_max:
				face_max = value
			if value < face_min:
				face_min = value
	var tangent := _js_max(face_min, _js_min(face_max, tangent_mid))
	return {"point": {"x": nx * support + tangent_x * tangent,
		"y": 0.8, "z": nz * support + tangent_z * tangent},
		"normal": {"x": nx, "y": 0.0, "z": nz}, "depth": depth}

static func contact_kinematics_source(contact_value: Variant, speed_value: Variant,
		travel_yaw_value: Variant) -> Dictionary:
	if not contact_value is Dictionary:
		return {}
	var contact: Dictionary = contact_value
	var normal_value: Variant = contact.get("normal")
	if not normal_value is Dictionary:
		return contact.duplicate(true)
	var normal: Dictionary = normal_value
	var speed := _js_number(speed_value)
	var travel_yaw := _js_number(travel_yaw_value)
	var velocity_x := sin(travel_yaw) * speed
	var velocity_z := cos(travel_yaw) * speed
	var normal_x := _coord_dictionary(normal, "x")
	var normal_z := _coord_dictionary(normal, "z")
	var normal_speed := _js_max(0.0, velocity_x * normal_x + velocity_z * normal_z)
	var result := contact.duplicate(true)
	result.impactSpeed = normal_speed
	result.slideSpeed = absf(velocity_x * normal_z - velocity_z * normal_x)
	result.velocity = {"x": velocity_x, "y": 0.0, "z": velocity_z}
	return result

static func propose_polygon(car_value: Variant, obstacle_value: Variant) -> Dictionary:
	if not _strict_polygon(car_value) or not _strict_polygon(obstacle_value):
		return {"valid": false, "reason": "finite_polygon_vertices_required",
			"proposal_only": true, "server_admissible": false,
			"collision_role_validated": false}
	return {"valid": true, "proposal_only": true, "server_admissible": false,
		"collision_role_validated": false,
		"valid_means_input_shape_only": true,
		"source_axes": {"plane": "+X/+Z", "normal_direction": "car_to_obstacle",
			"point_y_m": 0.8},
		"source_result": polygon_vehicle_contact_source(car_value, obstacle_value)}

static func propose_kinematics(contact_value: Variant, speed_value: Variant,
		travel_yaw_value: Variant) -> Dictionary:
	if not _strict_contact(contact_value) or not _finite_number(speed_value) \
			or not _finite_number(travel_yaw_value):
		return {"valid": false, "reason": "finite_contact_speed_yaw_required",
			"proposal_only": true, "server_admissible": false,
			"collision_role_validated": false}
	return {"valid": true, "proposal_only": true, "server_admissible": false,
		"collision_role_validated": false,
		"valid_means_input_shape_only": true,
		"kinematics_semantics": "passive_linear_speed_and_travel_yaw_only",
		"source_result": contact_kinematics_source(contact_value, speed_value,
			travel_yaw_value)}

static func contract() -> Dictionary:
	return {"source_sha256": SOURCE_SHA256, "pure": true,
		"source_axes_public": true, "plane": "+X/+Z",
		"normal_direction": "car_to_obstacle", "point_y_m": 0.8,
		"kinematics_semantics": "passive_linear_speed_and_travel_yaw_only",
		"uses_yaw_arm_velocity": false, "uses_relative_peer_velocity": false,
		"strict_wrapper_rejects_nonfinite_before_source": true,
		"native_output_deep_copied": true,
		"source_shallow_spread_aliasing_preserved": false,
		"mutates_inputs": false, "performs_raycast": false,
		"replaces_native_collision": false, "applies_body_force": false,
		"collision_role_validated": false, "owns_event_identity": false,
		"owns_crash_or_damage": false, "owns_hp": false,
		"proposal_only": true, "server_admissible": false,
		"runtime_wired": false}

static func _project(polygon: Array, axis_x: float, axis_z: float) -> Dictionary:
	var minimum := INF
	var maximum := -INF
	for vertex: Variant in polygon:
		var value := _coord(vertex, 0) * axis_x + _coord(vertex, 1) * axis_z
		if is_nan(value):
			minimum = NAN
			maximum = NAN
			break
		if value > maximum:
			maximum = value
		if value < minimum:
			minimum = value
	return {"minimum": minimum, "maximum": maximum}

static func _strict_polygon(value: Variant) -> bool:
	if not value is Array or value.size() < 3:
		return false
	for vertex: Variant in value:
		if not vertex is Array or vertex.size() < 2 \
				or not _finite_number(vertex[0]) or not _finite_number(vertex[1]):
			return false
	return true

static func _strict_contact(value: Variant) -> bool:
	if not value is Dictionary or not value.get("point") is Dictionary \
			or not value.get("normal") is Dictionary or not _finite_number(value.get("depth")):
		return false
	var point: Dictionary = value.point
	var normal: Dictionary = value.normal
	return _finite_number(point.get("x")) and _finite_number(point.get("y")) \
		and _finite_number(point.get("z")) and _finite_number(normal.get("x")) \
		and _finite_number(normal.get("y")) and _finite_number(normal.get("z"))

static func _coord(vertex: Variant, index: int) -> float:
	if not vertex is Array or index < 0 or index >= vertex.size():
		return NAN
	return _js_number(vertex[index])

static func _coord_dictionary(value: Dictionary, key: String) -> float:
	return _js_number(value.get(key))

static func _hypot(x: float, z: float) -> float:
	# Math.hypot returns Infinity when any argument is infinite, even if another
	# argument is NaN. Keep that precedence before the NaN branch.
	if is_inf(x) or is_inf(z):
		return INF
	if is_nan(x) or is_nan(z):
		return NAN
	var ax := absf(x)
	var az := absf(z)
	var scale := maxf(ax, az)
	if scale == 0.0:
		return 0.0
	return scale * sqrt((ax / scale) * (ax / scale) + (az / scale) * (az / scale))

static func _js_min(a: float, b: float) -> float:
	return NAN if is_nan(a) or is_nan(b) else minf(a, b)

static func _js_max(a: float, b: float) -> float:
	return NAN if is_nan(a) or is_nan(b) else maxf(a, b)

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and not value is bool and is_finite(float(value))

static func _js_number(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is bool:
		return 1.0 if value else 0.0
	if value is int or value is float:
		return float(value)
	if value is String:
		var text: String = String(value).strip_edges()
		if text.is_empty():
			return 0.0
		return text.to_float() if text.is_valid_float() else NAN
	return NAN
