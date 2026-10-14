extends "res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd"
## TEST_ONLY frozen reconstruction of DFDE's eight-shape geometry. Not the
## original file/SHA; independent of subsequent mutable bumper experiments.

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid() or profile.profile_id != &"compact_sedan":
		return
	var original_half: Vector3 = profile.chassis_half_extents_m()
	var third_mass: float = profile.mass_kg / 3.0
	inertia = Vector3(
		third_mass * (original_half.y * original_half.y + original_half.z * original_half.z),
		third_mass * (original_half.x * original_half.x + original_half.z * original_half.z),
		third_mass * (original_half.x * original_half.x + original_half.y * original_half.y))
	var low := ConvexPolygonShape3D.new()
	var low_points := PackedVector3Array()
	for y in [0.64, 0.91]:
		for x in [-0.90, 0.90]:
			for z in [-2.15, 2.10]:
				low_points.append(Vector3(x, y, z))
	low.points = low_points
	get_node("NativeVehicleCollision").shape = low
	var cabin := CollisionShape3D.new()
	cabin.name = "NativeCabinCollision"
	cabin.set_meta("native_vehicle_owned", true)
	var cabin_hull := ConvexPolygonShape3D.new()
	var cabin_points := PackedVector3Array()
	for x in [-0.91, 0.91]:
		for z in [-1.30, 1.37]:
			cabin_points.append(Vector3(x, 0.90, z))
	for x in [-0.88, 0.88]:
		for z in [-0.94, 1.38]:
			cabin_points.append(Vector3(x, 1.95, z))
	cabin_hull.points = cabin_points
	cabin.shape = cabin_hull
	add_child(cabin)
	for sign_x in [-1.0, 1.0]:
		var sill_name := "NativeChassisSillLeft" if sign_x < 0.0 else "NativeChassisSillRight"
		var sill: CollisionShape3D = get_node(sill_name)
		var sill_box := BoxShape3D.new()
		sill_box.size = Vector3(0.115, 0.13, 1.997776)
		sill.shape = sill_box
		sill.position = Vector3(sign_x * 0.883, 0.2626, 0.0)
		var lower_side := CollisionShape3D.new()
		lower_side.name = "NativeLowerBodySideLeft" if sign_x < 0.0 else "NativeLowerBodySideRight"
		lower_side.set_meta("native_vehicle_owned", true)
		var side_box := BoxShape3D.new()
		side_box.size = Vector3(0.05, 0.27, 1.997776)
		lower_side.shape = side_box
		lower_side.position = Vector3(sign_x * 0.87, 0.505, 0.0)
		add_child(lower_side)
