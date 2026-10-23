extends RefCounted
## Pure source-axis port of vehicle_pair_impulse.mjs.
##
## Public body/contact dictionaries use source coordinates directly: +X/+Z is
## the planar world, yawRate is about +Y, and contact.normal points A -> B.
## This component never reads native contact J, converts axes, mutates bodies,
## applies forces, creates events, canonicalizes identities, or owns HP/damage.

const SOURCE_SHA256 := "544a6a3c0d3b406ada6f60d38084e3e9ace488e12e7b404e2d9ea75bbb2abbe1"
const DEFAULT_RESTITUTION := 0.12
const NORMAL_EPSILON := 1.0e-9

static func resolve_source(a_value: Variant, b_value: Variant,
		contact_value: Variant, options_value: Variant = {}) -> Dictionary:
	# Source JS would throw for non-object bodies/options. The native public
	# boundary is deliberately safe: malformed containers produce the same
	# finite unresolved result schema instead of an engine error.
	var a: Dictionary = a_value if a_value is Dictionary else {}
	var b: Dictionary = b_value if b_value is Dictionary else {}
	var av := _velocity(a)
	var bv := _velocity(b)
	var result := _base_result(av, bv)
	if not a_value is Dictionary or not b_value is Dictionary \
			or not contact_value is Dictionary or not options_value is Dictionary:
		return result
	var contact: Dictionary = contact_value
	var options: Dictionary = options_value
	var mass_a_value: Variant = a.get("mass")
	var mass_b_value: Variant = b.get("mass")
	if not _number_finite(mass_a_value) or float(mass_a_value) <= 0.0 \
			or not _number_finite(mass_b_value) or float(mass_b_value) <= 0.0:
		return result
	var normal_value: Variant = contact.get("normal")
	var point_value: Variant = contact.get("point")
	if not normal_value is Dictionary or not point_value is Dictionary:
		return result
	var normal: Dictionary = normal_value
	var point: Dictionary = point_value
	var required := [a.get("x"), a.get("z"), b.get("x"), b.get("z"),
		point.get("x"), point.get("z"), normal.get("x"), normal.get("z")]
	for value: Variant in required:
		if not _number_finite(value):
			return result

	var normal_x := float(normal.x)
	var normal_z := float(normal.z)
	var normal_length := _hypot(normal_x, normal_z)
	if normal_length < NORMAL_EPSILON:
		return result
	var nx := normal_x / normal_length
	var nz := normal_z / normal_length
	var mass_a := float(mass_a_value)
	var mass_b := float(mass_b_value)
	var inverse_mass_a := 1.0 / mass_a
	var inverse_mass_b := 1.0 / mass_b
	var angular_value: Variant = options.get("angular", true)
	var angular_enabled := _js_truthy(angular_value)
	var inverse_inertia_a := _inverse_inertia(a, mass_a, angular_enabled)
	var inverse_inertia_b := _inverse_inertia(b, mass_b, angular_enabled)
	var arm_a_x := float(point.x) - float(a.x)
	var arm_a_z := float(point.z) - float(a.z)
	var arm_b_x := float(point.x) - float(b.x)
	var arm_b_z := float(point.z) - float(b.z)
	var cross_a := arm_a_z * nx - arm_a_x * nz
	var cross_b := arm_b_z * nx - arm_b_x * nz
	var closing := (float(av.vx) - float(bv.vx)) * nx \
		+ (float(av.vz) - float(bv.vz)) * nz
	if inverse_inertia_a != 0.0:
		closing += float(av.yawRate) * cross_a
	if inverse_inertia_b != 0.0:
		closing -= float(bv.yawRate) * cross_b
	if not is_finite(closing):
		return result
	result.closingSpeed = maxf(0.0, closing)
	if closing <= 0.0:
		return result

	var denominator := inverse_mass_a + inverse_mass_b \
		+ cross_a * cross_a * inverse_inertia_a \
		+ cross_b * cross_b * inverse_inertia_b
	var restitution := clampf(_finite(options.get("restitution", DEFAULT_RESTITUTION),
		DEFAULT_RESTITUTION), 0.0, 1.0)
	var impulse := (1.0 + restitution) * closing / denominator
	var delta_v_a := impulse * inverse_mass_a
	var delta_v_b := impulse * inverse_mass_b
	var next_a := {"vx": float(av.vx) - delta_v_a * nx,
		"vz": float(av.vz) - delta_v_a * nz,
		"yawRate": float(av.yawRate) - impulse * cross_a * inverse_inertia_a}
	var next_b := {"vx": float(bv.vx) + delta_v_b * nx,
		"vz": float(bv.vz) + delta_v_b * nz,
		"yawRate": float(bv.yawRate) + impulse * cross_b * inverse_inertia_b}
	var outputs := [impulse, delta_v_a, delta_v_b, next_a.vx, next_a.vz,
		next_a.yawRate, next_b.vx, next_b.vz, next_b.yawRate]
	for value: Variant in outputs:
		if not _number_finite(value):
			# Source retains the already-computed finite closingSpeed here.
			return result
	return {"a": next_a, "b": next_b, "impulse": impulse,
		"impulseA": {"x": -impulse * nx, "z": -impulse * nz},
		"impulseB": {"x": impulse * nx, "z": impulse * nz},
		"deltaVA": delta_v_a, "deltaVB": delta_v_b,
		"closingSpeed": result.closingSpeed, "resolved": true}

static func propose(a_value: Variant, b_value: Variant,
		contact_value: Variant, options_value: Variant = {}) -> Dictionary:
	if not a_value is Dictionary or not b_value is Dictionary \
			or not contact_value is Dictionary or not options_value is Dictionary:
		return {"valid": false, "reason": "dictionary_inputs_required",
			"proposal_only": true, "server_admissible": false}
	return {"valid": true, "proposal_only": true, "server_admissible": false,
		"source_axes": {"plane": "+X/+Z", "yaw_axis": "+Y",
			"normal_direction": "A_to_B"},
		"source_result": resolve_source(a_value, b_value, contact_value, options_value)}

static func contract() -> Dictionary:
	return {"source_sha256": SOURCE_SHA256, "pure": true,
		"source_axes_public": true, "plane": "+X/+Z", "yaw_axis": "+Y",
		"normal_direction": "A_to_B", "mutates_inputs": false,
		"reads_native_reported_impulse": false, "applies_body_force": false,
		"owns_event_identity": false, "owns_peer_canonicalization": false,
		"owns_crash_or_damage": false, "owns_hp": false,
		"proposal_only": true, "server_admissible": false,
		"runtime_wired": false}

static func _velocity(body: Dictionary) -> Dictionary:
	return {"vx": _finite(body.get("vx"), 0.0),
		"vz": _finite(body.get("vz"), 0.0),
		"yawRate": _finite(body.get("yawRate"), 0.0)}

static func _base_result(av: Dictionary, bv: Dictionary) -> Dictionary:
	return {"a": av.duplicate(true), "b": bv.duplicate(true), "impulse": 0.0,
		"impulseA": {"x": 0.0, "z": 0.0},
		"impulseB": {"x": 0.0, "z": 0.0},
		"deltaVA": 0.0, "deltaVB": 0.0, "closingSpeed": 0.0,
		"resolved": false}

static func _inverse_inertia(body: Dictionary, mass: float, angular: bool) -> float:
	var half_width: Variant = body.get("halfWidth")
	var half_length: Variant = body.get("halfLength")
	if not angular or not _number_finite(half_width) or not _number_finite(half_length) \
			or float(half_width) <= 0.0 or float(half_length) <= 0.0:
		return 0.0
	return 3.0 / (mass * (float(half_width) * float(half_width)
		+ float(half_length) * float(half_length)))

static func _hypot(x: float, z: float) -> float:
	# Scaled hypot matches Math.hypot's protection against intermediate square
	# overflow for large but representable normals.
	var ax := absf(x)
	var az := absf(z)
	var scale := maxf(ax, az)
	if scale == 0.0:
		return 0.0
	return scale * sqrt((ax / scale) * (ax / scale) + (az / scale) * (az / scale))

static func _finite(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if _number_finite(value) else fallback

static func _number_finite(value: Variant) -> bool:
	# JavaScript Number.isFinite rejects null, bool, strings and numeric coercion.
	return (value is int or value is float) and not value is bool and is_finite(float(value))

static func _js_truthy(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0 and not is_nan(float(value))
	if value is String:
		return not value.is_empty()
	return true
