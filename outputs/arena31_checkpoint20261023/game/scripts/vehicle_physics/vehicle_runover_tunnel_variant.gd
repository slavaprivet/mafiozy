extends "res://scripts/vehicle_physics/vehicle_runover_shape_candidate.gd"
## Second isolated geometry variant; no runtime owner uses this script.

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid():
		return
	physics_material_override.friction = 0.0
	var half: Vector3 = profile.chassis_half_extents_m()
	var underside: float = profile.wheel_radius_m + 0.31
	var upper: float = profile.ground_clearance_m + 2.0 * half.y
	var middle_z: float = minf(profile.wheelbase_m * 0.30, half.z * 0.70)
	var points := PackedVector3Array()
	for z in [-half.z, -middle_z, middle_z, half.z]:
		var bottom: float = underside if absf(z) < half.z - 0.001 else underside + 0.12
		for x in [-half.x, half.x]:
			points.append(Vector3(x, bottom, z))
			points.append(Vector3(x, upper, z))
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	get_node("NativeVehicleCollision").shape = hull
	for side in ["NativeChassisSillLeft", "NativeChassisSillRight"]:
		var sill: CollisionShape3D = get_node(side)
		var box := BoxShape3D.new()
		box.size = Vector3(0.16, underside - profile.ground_clearance_m, 2.0 * half.z)
		sill.shape = box
		sill.position.y = profile.ground_clearance_m + box.size.y * 0.5
