class_name NativeVehicleBodyFactory
extends RefCounted

const Body = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
var last_error := ""

func spawn_from_descriptor(vehicle_record: Dictionary, profile_descriptor: Dictionary) -> RigidBody3D:
	last_error = ""
	var vehicle_id := str(vehicle_record.get("vehicle_id", ""))
	var profile_id := str(vehicle_record.get("profile_id", ""))
	var life_generation := int(vehicle_record.get("life_generation", 0))
	var source_clock := int(vehicle_record.get("source_clock", -1))
	if vehicle_id.is_empty() or profile_id.is_empty() or life_generation < 1 or source_clock < 0:
		last_error = "invalid_vehicle_identity"
		return null
	if str(profile_descriptor.get("profile_id", "")) != profile_id:
		last_error = "profile_identity_mismatch"
		return null
	var position := _vector3(vehicle_record.get("position_m"))
	var yaw := float(vehicle_record.get("yaw_rad", NAN))
	if not _finite_vector(position) or not is_finite(yaw):
		last_error = "invalid_vehicle_pose"
		return null
	var descriptor := profile_descriptor.duplicate(true)
	descriptor.vehicle_id = vehicle_id
	descriptor.source_id = str(vehicle_record.get("source_id", profile_id))
	descriptor.life_generation = life_generation
	descriptor.source_clock = source_clock
	var body := Body.new()
	if not body.configure(descriptor):
		last_error = "physics_profile_rejected"
		body.free()
		return null
	body.position = position
	body.rotation.y = yaw
	body.freeze = not bool(vehicle_record.get("active", true))
	body.set_meta("vehicle_id", vehicle_id)
	body.set_meta("life_generation", life_generation)
	body.set_meta("profile_id", profile_id)
	body.set_meta("source_clock", source_clock)
	return body

static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", NAN)), float(value.get("y", NAN)), float(value.get("z", NAN)))
	return Vector3(NAN, NAN, NAN)

static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
