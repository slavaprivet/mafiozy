class_name NativeVehicleTyreContactProviderFastCandidate
extends RefCounted
## TEST_ONLY lower-allocation twin of NativeVehicleTyreContactProvider.
## Reads AE4D body publication fields directly; parity must be proven before use.

const WHEEL_COUNT := 4
const TRACK_SURFACES := {"road": true, "sidewalk": true, "bridge": true}

static func collect_into(vehicle: NativeVehicleBody, expected_tick: int,
		out: Array[Dictionary]) -> bool:
	out.clear()
	if vehicle == null or not is_instance_valid(vehicle) or not vehicle.is_inside_tree() \
			or vehicle.profile == null or expected_tick <= 0 \
			or vehicle._physics_tick != expected_tick:
		return false
	var profile = vehicle.profile
	if vehicle._wheel_rays.size() != WHEEL_COUNT or vehicle._wheel_surface_ids.size() != WHEEL_COUNT \
			or vehicle._wheel_slip.size() != WHEEL_COUNT:
		return false
	for index in WHEEL_COUNT:
		if (vehicle._grounded_wheel_mask & (1 << index)) == 0:
			continue
		var surface: String = vehicle._wheel_surface_ids[index]
		if not TRACK_SURFACES.has(surface):
			continue
		var slip: float = vehicle._wheel_slip[index]
		if not is_finite(slip) or slip < NativeVehicleTyreTracks.MIN_SLIP:
			continue
		var ray: RayCast3D = vehicle._wheel_rays[index]
		if ray == null or not ray.is_colliding():
			out.clear()
			return false
		var point: Vector3 = ray.get_collision_point()
		var normal: Vector3 = ray.get_collision_normal()
		if not point.is_finite() or not normal.is_finite() \
				or normal.length_squared() < 0.000001:
			out.clear()
			return false
		out.append({"vehicle_id": str(profile.vehicle_id),
			"life_generation": profile.life_generation,
			"physics_tick": expected_tick, "wheel_index": index,
			"grounded": true, "surface_id": surface,
			"slip": slip, "point_world_m": point,
			"normal_world": normal.normalized()})
	return true
