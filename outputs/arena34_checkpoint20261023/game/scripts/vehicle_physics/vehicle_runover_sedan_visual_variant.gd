extends "res://scripts/vehicle_physics/vehicle_runover_tunnel_variant.gd"
## TEST_ONLY compact-sedan collision silhouette against the emitted LOD0 mesh.
## This is intentionally not selected by production vehicle creation.

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid() or profile.profile_id != &"compact_sedan":
		return
	var half: Vector3 = profile.chassis_half_extents_m()
	var underside: float = profile.wheel_radius_m + 0.31
	var upper: float = profile.ground_clearance_m + 2.0 * half.y
	var middle_z: float = minf(profile.wheelbase_m * 0.30, half.z * 0.70)
	var body_half_width := 0.9405 # Emitted LOD0 Body_sill exterior, middle section.
	var points := PackedVector3Array()
	for z in [-half.z, -middle_z, middle_z, half.z]:
		var bottom: float = underside if absf(z) < half.z - 0.001 else underside + 0.12
		for x in [-body_half_width, body_half_width]:
			points.append(Vector3(x, bottom, z))
			points.append(Vector3(x, upper, z))
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	get_node("NativeVehicleCollision").shape = hull
	for sign_x in [-1.0, 1.0]:
		var sill_name := "NativeChassisSillLeft" if sign_x < 0.0 else "NativeChassisSillRight"
		var sill: CollisionShape3D = get_node(sill_name)
		var box := BoxShape3D.new()
		box.size = Vector3(0.115, underside - profile.ground_clearance_m, 2.0 * half.z)
		sill.shape = box
		sill.position = Vector3(sign_x * 0.883, profile.ground_clearance_m + box.size.y * 0.5, 0.0)
	# The visible upright tire has a 0.33m rolling radius and 0.18m axial
	# width. A ball extends 27cm outside that tire. Axle-oriented cylinders
	# maintain physical wheel contacts without invisible lateral reach.
	for i in 4:
		var wheel: CollisionShape3D = get_node("NativePhysicalWheel%d" % i)
		var tire := CylinderShape3D.new()
		tire.radius = profile.wheel_radius_m
		tire.height = 0.18
		wheel.shape = tire
		wheel.position.x = -0.918 if i % 2 == 0 else 0.918
		wheel.rotation_degrees.z = 90.0
