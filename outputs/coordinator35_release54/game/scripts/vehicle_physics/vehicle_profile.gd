class_name NativeVehicleProfile
extends RefCounted

const REQUIRED_ID_FIELDS := [&"vehicle_id", &"profile_id"]
const MIN_HALF_EXTENT_M := 0.1
const STATIC_SUSPENSION_LENGTH_RATIO := 0.55

var vehicle_id: StringName
var source_id: StringName
var profile_id: StringName
var life_generation := 1
var source_clock := 0
var mass_kg := 1320.0
var body_half_extents_m := Vector3(1.152, 0.50, 2.454)
var ground_clearance_m := 0.16
var center_of_mass_local_m := Vector3(0.0, -0.16, 0.0)
var wheelbase_m := 2.7404
var track_width_m := 1.476
var wheel_radius_m := 0.33
var suspension_rest_length_m := 0.22
var steering_limit_rad := 0.56
var engine_accel_mps2 := 7.0
var brake_decel_mps2 := 11.0
var reverse_accel_mps2 := 4.5
var max_forward_speed_mps := 31.0
var max_reverse_speed_mps := 6.0
var linear_drag := 0.12
var angular_drag := 0.8
var tyre_grip := 1.0
var handbrake_rear_grip := 0.20
var source_receipt := ""
var native_default_fields := PackedStringArray()

static func from_dictionary(row: Dictionary):
	var profile := NativeVehicleProfile.new()
	return profile if profile.load_dictionary(row) else null

func load_dictionary(row: Dictionary) -> bool:
	for field: StringName in REQUIRED_ID_FIELDS:
		if str(row.get(field, "")).strip_edges().is_empty():
			return false
	vehicle_id = StringName(str(row.vehicle_id))
	source_id = StringName(str(row.get("source_id", row.profile_id)))
	profile_id = StringName(str(row.profile_id))
	life_generation = int(row.get("life_generation", 1))
	source_clock = int(row.get("source_clock", 0))
	mass_kg = _number(row, "mass_kg", mass_kg)
	body_half_extents_m = _vector3(row.get("body_half_extents_m", body_half_extents_m), body_half_extents_m)
	wheelbase_m = _number(row, "wheelbase_m", wheelbase_m)
	wheel_radius_m = _number(row, "wheel_radius_m", wheel_radius_m)
	ground_clearance_m = _native_number(row, "ground_clearance_m", clampf(wheel_radius_m * 0.55, 0.13, 0.28))
	# Walk does not author track/COM/suspension. These defaults remain explicit
	# native engineering values and must not be reported as source measurements.
	var nominal_width := maxf(0.8, (body_half_extents_m.x - 0.18) / 0.54)
	track_width_m = _native_number(row, "track_width_m", nominal_width * 1.02)
	suspension_rest_length_m = _native_number(row, "suspension_rest_length_m", wheel_radius_m * 0.55)
	var default_com := Vector3(0.0, body_half_extents_m.y * 0.84, 0.0)
	if row.get("center_of_mass_local_m") == null:
		center_of_mass_local_m = default_com
		native_default_fields.append("center_of_mass_local_m")
	else:
		center_of_mass_local_m = _vector3(row.get("center_of_mass_local_m"), default_com)
	steering_limit_rad = _number(row, "steering_limit_rad", steering_limit_rad)
	engine_accel_mps2 = _number(row, "engine_accel_mps2", _number(row, "acceleration_mps2", engine_accel_mps2))
	brake_decel_mps2 = _number(row, "brake_decel_mps2", brake_decel_mps2)
	reverse_accel_mps2 = _number(row, "reverse_accel_mps2", reverse_accel_mps2)
	max_forward_speed_mps = _number(row, "max_forward_speed_mps", max_forward_speed_mps)
	max_reverse_speed_mps = _number(row, "max_reverse_speed_mps", max_reverse_speed_mps)
	linear_drag = _number(row, "linear_drag", linear_drag)
	angular_drag = _native_number(row, "angular_drag", 1.2)
	tyre_grip = _number(row, "tyre_grip", tyre_grip)
	handbrake_rear_grip = _number(row, "handbrake_rear_grip", handbrake_rear_grip)
	source_receipt = str(row.get("source_receipt", ""))
	return is_valid()

func is_valid() -> bool:
	if vehicle_id.is_empty() or profile_id.is_empty() or life_generation < 1:
		return false
	var values := [mass_kg, body_half_extents_m.x, body_half_extents_m.y, body_half_extents_m.z,
		ground_clearance_m, wheelbase_m, track_width_m, wheel_radius_m,
		suspension_rest_length_m, steering_limit_rad, engine_accel_mps2,
		brake_decel_mps2, reverse_accel_mps2, max_forward_speed_mps,
		max_reverse_speed_mps, linear_drag, angular_drag, tyre_grip, handbrake_rear_grip]
	for value: float in values:
		if not is_finite(value):
			return false
	if not center_of_mass_local_m.is_finite():
		return false
	return mass_kg >= 100.0 and body_half_extents_m.x >= MIN_HALF_EXTENT_M \
		and body_half_extents_m.y >= MIN_HALF_EXTENT_M and body_half_extents_m.z >= MIN_HALF_EXTENT_M \
		and wheelbase_m > 0.5 and wheelbase_m <= body_half_extents_m.z * 2.0 \
		and track_width_m > 0.5 and track_width_m <= body_half_extents_m.x * 2.0 \
		and wheel_radius_m > 0.1 and suspension_rest_length_m > 0.05 and ground_clearance_m >= 0.0 \
		and steering_limit_rad > 0.05 and engine_accel_mps2 >= 0.0 and brake_decel_mps2 > 0.0 \
		and reverse_accel_mps2 >= 0.0 and max_forward_speed_mps > 0.5 \
		and max_reverse_speed_mps > 0.1 and tyre_grip > 0.0 \
		and linear_drag >= 0.0 and angular_drag >= 0.0 \
		and handbrake_rear_grip > 0.01 and handbrake_rear_grip <= tyre_grip

func wheel_local_positions() -> PackedVector3Array:
	var half_track := track_width_m * 0.5
	var half_base := wheelbase_m * 0.5
	# The ray begins at the suspension mount, not at the rendered wheel centre.
	# STATIC_SUSPENSION_LENGTH_RATIO is the loaded residual travel used by the
	# matching spring-rate equation in NativeVehicleBody. Keeping the shared
	# constant explicit preserves the source ground-root at static equilibrium.
	var mount_y := wheel_radius_m + suspension_rest_length_m * STATIC_SUSPENSION_LENGTH_RATIO
	return PackedVector3Array([
		Vector3(-half_track, mount_y, -half_base),
		Vector3(half_track, mount_y, -half_base),
		Vector3(-half_track, mount_y, half_base),
		Vector3(half_track, mount_y, half_base),
	])

func chassis_half_extents_m() -> Vector3:
	return Vector3(body_half_extents_m.x, maxf(MIN_HALF_EXTENT_M, body_half_extents_m.y - ground_clearance_m * 0.5), body_half_extents_m.z)

func chassis_center_local_m() -> Vector3:
	return Vector3(0.0, ground_clearance_m + chassis_half_extents_m().y, 0.0)

func descriptor() -> Dictionary:
	return {
		"vehicle_id": str(vehicle_id), "source_id": str(source_id), "profile_id": str(profile_id),
		"life_generation": life_generation, "source_clock": source_clock, "mass_kg": mass_kg,
		"body_half_extents_m": body_half_extents_m, "ground_clearance_m": ground_clearance_m,
		"center_of_mass_local_m": center_of_mass_local_m, "wheelbase_m": wheelbase_m,
		"track_width_m": track_width_m, "wheel_radius_m": wheel_radius_m,
		"suspension_rest_length_m": suspension_rest_length_m, "steering_limit_rad": steering_limit_rad,
		"engine_accel_mps2": engine_accel_mps2, "brake_decel_mps2": brake_decel_mps2,
		"reverse_accel_mps2": reverse_accel_mps2, "max_forward_speed_mps": max_forward_speed_mps,
		"max_reverse_speed_mps": max_reverse_speed_mps, "source_receipt": source_receipt,
		"native_default_fields": native_default_fields.duplicate(),
	}

func _native_number(row: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = row.get(key)
	if value == null:
		native_default_fields.append(key)
		return fallback
	return _number(row, key, fallback)

static func _number(row: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = row.get(key)
	if value is int or value is float:
		var number := float(value)
		return number
	return fallback

static func _vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		if (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and (value[2] is int or value[2] is float):
			return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		if value.has("x") and value.has("y") and value.has("z") and (value.x is int or value.x is float) and (value.y is int or value.y is float) and (value.z is int or value.z is float):
			return Vector3(float(value.x), float(value.y), float(value.z))
	return Vector3(NAN, NAN, NAN)
