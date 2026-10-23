extends RefCounted
## Same-callback native vehicle -> NPC contact receipt. Never applies an impulse.
## The current NativeVehicleBody owns one chassis box; its wheel RayCast3D nodes
## are suspension probes, not collision shapes and cannot prove a wheel impact.

const MAX_REPORTED_CONTACTS := 8
const MAX_PROPOSED_NPC_DELTA_V_MPS := 20.0

static func observe(state: PhysicsDirectBodyState3D, vehicle: RigidBody3D,
		contact_index: int, expected_npc: CollisionObject3D) -> Dictionary:
	if not is_instance_valid(state) or not is_instance_valid(vehicle) \
			or not is_instance_valid(expected_npc):
		return _reject("missing_state_or_body")
	var count := state.get_contact_count()
	if count >= MAX_REPORTED_CONTACTS or contact_index < 0 or contact_index >= count:
		return _reject("contact_cap_or_index")
	if state.get_contact_collider_object(contact_index) != expected_npc \
			or state.get_contact_collider_id(contact_index) != expected_npc.get_instance_id():
		return _reject("counterpart_mismatch")
	var shape_index := state.get_contact_local_shape(contact_index)
	if shape_index < 0 or shape_index >= vehicle.get_shape_owners().size():
		return _reject("unknown_local_shape")
	var owner_id := vehicle.shape_find_owner(shape_index)
	var shape_node := vehicle.shape_owner_get_owner(owner_id)
	if not shape_node is CollisionShape3D or shape_node.name != "NativeVehicleCollision" \
			or not shape_node.has_meta("native_vehicle_owned") \
			or vehicle.get_shape_owners().size() != 1:
		return _reject("unproved_chassis_shape")
	var point := state.get_contact_local_position(contact_index)
	var peer_point := state.get_contact_collider_position(contact_index)
	var normal_on_vehicle := state.get_contact_local_normal(contact_index)
	var vehicle_point_velocity := state.get_contact_local_velocity_at_position(contact_index)
	var npc_point_velocity := state.get_contact_collider_velocity_at_position(contact_index)
	var impulse_on_vehicle := state.get_contact_impulse(contact_index)
	var velocity := state.linear_velocity
	var mass := vehicle.mass
	if not point.is_finite() or not peer_point.is_finite() \
			or not normal_on_vehicle.is_finite() or normal_on_vehicle.length_squared() < 0.000001 \
			or not vehicle_point_velocity.is_finite() or not npc_point_velocity.is_finite() \
			or not impulse_on_vehicle.is_finite() or not velocity.is_finite() \
			or not is_finite(mass) or mass < 100.0:
		return _reject("invalid_contact_kinematics")
	var npc_mass := NAN
	if expected_npc is RigidBody3D:
		npc_mass = expected_npc.mass
	var measured_delta_v := Vector3.ZERO
	var has_measured_delta_v := is_finite(npc_mass) and npc_mass > 0.0
	if has_measured_delta_v:
		measured_delta_v = -impulse_on_vehicle / npc_mass
		if not measured_delta_v.is_finite():
			return _reject("invalid_npc_delta_v")
	var relative_velocity := vehicle_point_velocity - npc_point_velocity
	var normal := normal_on_vehicle.normalized()
	var closing := maxf(0.0, -relative_velocity.dot(normal))
	if not is_finite(closing):
		return _reject("invalid_closing_speed")
	return {"valid": true, "contact_index": contact_index,
		"vehicle_runtime_id": vehicle.get_instance_id(),
		"npc_runtime_id": expected_npc.get_instance_id(),
		"collision_part": "chassis", "collision_shape_index": shape_index,
		"point_on_vehicle_world_m": point, "point_on_npc_world_m": peer_point,
		"normal_on_vehicle_world": normal, "vehicle_linear_velocity_world_mps": velocity,
		"vehicle_speed_mps": velocity.length(), "vehicle_mass_kg": mass,
		"vehicle_point_velocity_world_mps": vehicle_point_velocity,
		"npc_point_velocity_world_mps": npc_point_velocity,
		"closing_speed_mps": closing,
		"impulse_on_vehicle_ns": impulse_on_vehicle,
		"impulse_on_npc_ns": -impulse_on_vehicle,
		"npc_mass_kg": npc_mass, "measured_npc_delta_v_available": has_measured_delta_v,
		"measured_npc_delta_v_mps": measured_delta_v,
		"bounded_npc_delta_v_mps": measured_delta_v.limit_length(MAX_PROPOSED_NPC_DELTA_V_MPS),
		"delta_v_was_capped": measured_delta_v.length() > MAX_PROPOSED_NPC_DELTA_V_MPS,
		"already_solved_by_godot": true, "apply_again": false,
		"wheel_collision_proved": false, "proposal_only": true, "authority": false}

static func _reject(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason, "proposal_only": true,
		"authority": false, "apply_again": false}
