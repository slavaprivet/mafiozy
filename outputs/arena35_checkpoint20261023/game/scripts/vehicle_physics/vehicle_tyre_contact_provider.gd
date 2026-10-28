class_name NativeVehicleTyreContactProvider
extends RefCounted
## Presentation-only adapter from an actual NativeVehicleBody's four existing
## suspension rays to NativeVehicleTyreTracks. No new casts or damage authority.

const WHEEL_COUNT := 4
const TRACK_SURFACES := {"road": true, "sidewalk": true, "bridge": true}

static func collect_into(vehicle: NativeVehicleBody, expected_tick: int,
		out: Array[Dictionary]) -> bool:
	out.clear()
	if vehicle == null or not is_instance_valid(vehicle) or not vehicle.is_inside_tree() \
			or vehicle.profile == null or expected_tick <= 0:
		return false
	var state: Dictionary = vehicle.snapshot_state()
	if state.get("physics_tick") != expected_tick \
			or state.get("vehicle_id") != str(vehicle.profile.vehicle_id) \
			or state.get("life_generation") != vehicle.profile.life_generation:
		return false
	for index in WHEEL_COUNT:
		var wheel: Dictionary = vehicle.wheel_visual_state(index)
		if not wheel.get("valid", false) or not wheel.get("grounded", false) \
				or not TRACK_SURFACES.has(str(wheel.get("surface_id", ""))):
			continue
		var slip: float = float(wheel.get("slip", NAN))
		if not is_finite(slip) or slip < NativeVehicleTyreTracks.MIN_SLIP:
			continue
		var ray := vehicle.get_node_or_null("WheelProbe%d" % index) as RayCast3D
		if ray == null or not ray.is_colliding():
			out.clear()
			return false
		var point: Vector3 = ray.get_collision_point()
		var normal: Vector3 = ray.get_collision_normal()
		if not point.is_finite() or not normal.is_finite() \
				or normal.length_squared() < 0.000001:
			out.clear()
			return false
		out.append({"vehicle_id": str(vehicle.profile.vehicle_id),
			"life_generation": vehicle.profile.life_generation,
			"physics_tick": expected_tick, "wheel_index": index,
			"grounded": true, "surface_id": str(wheel.surface_id),
			"slip": slip, "point_world_m": point,
			"normal_world": normal.normalized()})
	return true
