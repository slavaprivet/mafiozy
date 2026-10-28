extends "res://scripts/vehicle_physics/vehicle_native_body.gd"
## Isolated compound collision candidate. Suspension still uses the production rays.
## Ragdoll bodies remain normal rigid colliders; their layer 256 is outside the
## production wheel support ray mask 1, so a body cannot become road support.

static var measured_npc_wheel_contacts := 0
static var measured_npc_chassis_contacts := 0
static var measured_npc_sill_contacts := 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	for i in state.get_contact_count():
		var other := state.get_contact_collider_object(i)
		if not other is RigidBody3D or other.collision_layer & 256 == 0:
			continue
		var local_index := state.get_contact_local_shape(i)
		if local_index < 0 or local_index >= get_shape_owners().size():
			continue
		var owner := shape_owner_get_owner(shape_find_owner(local_index))
		if owner is CollisionShape3D:
			if owner.name.begins_with("NativePhysicalWheel"):
				measured_npc_wheel_contacts += 1
			elif owner.name.begins_with("NativeChassisSill"):
				measured_npc_sill_contacts += 1
			elif owner.name == "NativeVehicleCollision":
				measured_npc_chassis_contacts += 1

func _rebuild_physical_body() -> void:
	super._rebuild_physical_body()
	if profile == null or not profile.is_valid():
		return
	var contact_material := PhysicsMaterial.new()
	contact_material.friction = 0.05
	contact_material.bounce = 0.0
	physics_material_override = contact_material
	var chassis: CollisionShape3D = get_node("NativeVehicleCollision")
	var half: Vector3 = profile.chassis_half_extents_m()
	var underside: float = maxf(profile.ground_clearance_m, profile.wheel_radius_m + 0.15)
	var upper: float = profile.ground_clearance_m + 2.0 * half.y
	var middle_z: float = minf(profile.wheelbase_m * 0.30, half.z * 0.70)
	var outer_bottom: float = underside + 0.12
	var points := PackedVector3Array()
	for z in [-half.z, -middle_z, middle_z, half.z]:
		var bottom: float = underside if absf(z) < half.z - 0.001 else outer_bottom
		for x in [-half.x, half.x]:
			points.append(Vector3(x, bottom, z))
			points.append(Vector3(x, upper, z))
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	chassis.position = Vector3.ZERO
	chassis.shape = hull
	# Side sills retain the source profile's minimum physical ground clearance.
	# The higher central floor forms a tunnel for a prone articulated body.
	for sign_x in [-1.0, 1.0]:
		var sill := CollisionShape3D.new()
		sill.name = "NativeChassisSillLeft" if sign_x < 0.0 else "NativeChassisSillRight"
		sill.set_meta("native_vehicle_owned", true)
		var sill_box := BoxShape3D.new()
		sill_box.size = Vector3(0.16, underside - profile.ground_clearance_m, 2.0 * half.z)
		sill.shape = sill_box
		sill.position = Vector3(sign_x * (half.x - 0.08), profile.ground_clearance_m + sill_box.size.y * 0.5, 0.0)
		add_child(sill)
	var positions: PackedVector3Array = profile.wheel_local_positions()
	for i in 4:
		var wheel := CollisionShape3D.new()
		wheel.name = "NativePhysicalWheel%d" % i
		wheel.set_meta("native_vehicle_owned", true)
		var sphere := SphereShape3D.new()
		sphere.radius = profile.wheel_radius_m
		wheel.shape = sphere
		wheel.position = Vector3(positions[i].x, profile.wheel_radius_m, positions[i].z)
		add_child(wheel)

func body_sweep(target_transform: Transform3D, margin := 0.04, additional_contact_mask := 256) -> Dictionary:
	if profile == null or not is_inside_tree() or not is_finite(margin):
		return {"valid": false, "safe_fraction": 0.0, "unsafe_fraction": 0.0}
	var q0 := global_basis.get_rotation_quaternion()
	var q1 := target_transform.basis.get_rotation_quaternion()
	if 1.0 - absf(q0.dot(q1)) > 0.0000005:
		return {"valid": false, "reason": "rotation_sweep_unsupported", "safe_fraction": 0.0, "unsafe_fraction": 0.0}
	var safe := 1.0
	var unsafe := 1.0
	var motion := target_transform.origin - global_transform.origin
	for child: Node in get_children():
		if not child is CollisionShape3D or not child.has_meta("native_vehicle_owned"):
			continue
		var shape_node := child as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.motion = motion
		query.margin = clampf(margin, 0.001, 0.25)
		# NPC ragdolls live on layer 256 and collide with the vehicle through
		# their own mask. Shape casts are one-sided, so the car's mask alone
		# would miss those bodies even though the physics solver contacts them.
		# This does not change the suspension rays' ground-only mask.
		query.collision_mask = collision_mask | additional_contact_mask
		query.exclude = [get_rid()]
		var cast := get_world_3d().direct_space_state.cast_motion(query)
		if cast.size() != 2:
			return {"valid": false, "safe_fraction": 0.0, "unsafe_fraction": 0.0}
		safe = minf(safe, cast[0])
		unsafe = minf(unsafe, cast[1])
	return {"valid": true, "safe_fraction": safe, "unsafe_fraction": unsafe}
