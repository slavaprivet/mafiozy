extends "res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd"
## Candidate-only D149 copy elision.
##
## Identity.describe and every locally constructed invalid identity return a
## fresh dictionary owned by this call. Store that fresh dictionary directly in
## the fixed cold slot, then retain D149's final deep copy into every exported
## row. No caller-owned dictionary is retained, no identity cache is introduced,
## and all raw/contact/gap/trust semantics remain the frozen baseline contract.

func collect(state: PhysicsDirectBodyState3D, self_ref: Dictionary,
		global_physics_tick: int) -> Dictionary:
	if not is_instance_valid(state) or global_physics_tick < 0:
		return _invalid_envelope("invalid_state_or_tick")
	var self_identity := _self_identity(self_ref)
	if not bool(self_identity.get("valid", false)):
		return _invalid_envelope("invalid_self_identity")
	var target_root_frame_world := state.transform
	if not target_root_frame_world.is_finite() \
			or absf(target_root_frame_world.basis.determinant()) < 0.000001:
		return _invalid_envelope("invalid_target_root_frame")

	var raw_contact_count := state.get_contact_count()
	var retained_count := mini(raw_contact_count, POINT_CAPACITY)
	var cap_gap := raw_contact_count >= POINT_CAPACITY
	var identity_gap := false
	var nonfinite_gap := false
	var duplicate_index_gap := false
	var counterpart_overflow_gap := false
	var unique_counterpart_count := 0
	for slot in POINT_CAPACITY:
		_unique_counterparts[slot] = 0

	for index in retained_count:
		_raw_indices[index] = index
		var point_self_world := state.get_contact_local_position(index)
		var point_counterpart_world := state.get_contact_collider_position(index)
		var normal_on_self_world := state.get_contact_local_normal(index)
		var velocity_self_world := state.get_contact_local_velocity_at_position(index)
		var velocity_counterpart_world := state.get_contact_collider_velocity_at_position(index)
		var relative_velocity_world := velocity_self_world - velocity_counterpart_world
		var impulse_on_self_world_ns := state.get_contact_impulse(index)
		var raw_finite := point_self_world.is_finite() \
			and point_counterpart_world.is_finite() and normal_on_self_world.is_finite() \
			and velocity_self_world.is_finite() and velocity_counterpart_world.is_finite() \
			and relative_velocity_world.is_finite() and impulse_on_self_world_ns.is_finite() \
			and normal_on_self_world.length_squared() >= 0.000001
		var closing_speed_mps := 0.0
		if raw_finite:
			closing_speed_mps = maxf(0.0,
				-relative_velocity_world.dot(normal_on_self_world.normalized()))
			raw_finite = is_finite(closing_speed_mps)
		if not raw_finite:
			nonfinite_gap = true

		var collider := state.get_contact_collider_object(index)
		var reported_runtime_id := state.get_contact_collider_id(index)
		var peer_identity: Dictionary
		var identity_valid := is_instance_valid(collider) \
			and reported_runtime_id > 0 \
			and collider.get_instance_id() == reported_runtime_id
		if identity_valid:
			peer_identity = Identity.describe(collider)
			identity_valid = bool(peer_identity.get("valid", false)) \
				and int(peer_identity.get("counterpart_runtime_id", 0)) == reported_runtime_id
		else:
			peer_identity = {"valid": false, "reason": "missing_or_mismatched_counterpart",
				"counterpart_runtime_id": reported_runtime_id,
				"proposal_only": true, "server_admissible": false}
		if identity_valid and peer_identity.get("kind") == "vehicle" \
				and peer_identity.get("vehicle_id") == self_identity.vehicle_id \
				and peer_identity.get("life_generation") == self_identity.life_generation:
			identity_valid = false
			peer_identity = {"valid": false, "reason": "self_identity_collision",
				"counterpart_runtime_id": reported_runtime_id,
				"proposal_only": true, "server_admissible": false}
		if not identity_valid:
			identity_gap = true

		var already_seen := false
		if reported_runtime_id > 0:
			for unique_index in unique_counterpart_count:
				if _unique_counterparts[unique_index] == reported_runtime_id:
					already_seen = true
					break
			if not already_seen:
				if unique_counterpart_count >= POINT_CAPACITY:
					counterpart_overflow_gap = true
				else:
					_unique_counterparts[unique_counterpart_count] = reported_runtime_id
					unique_counterpart_count += 1

		_points_self_world[index] = point_self_world
		_points_counterpart_world[index] = point_counterpart_world
		_normals_on_self_world[index] = normal_on_self_world
		_velocities_self_world[index] = velocity_self_world
		_velocities_counterpart_world[index] = velocity_counterpart_world
		_relative_velocities_world[index] = relative_velocity_world
		_closing_speeds_mps[index] = closing_speed_mps
		_impulses_on_self_world_ns[index] = impulse_on_self_world_ns
		_counterpart_runtime_ids[index] = reported_runtime_id
		_row_valid[index] = 1 if raw_finite and identity_valid else 0
		# The only baseline difference: peer_identity is already fresh and owned.
		# The final exported row still receives a deep copy below.
		_peer_identities[index] = peer_identity

	for index in retained_count:
		if _raw_indices[index] != index:
			duplicate_index_gap = true

	var rows: Array[Dictionary] = []
	rows.resize(retained_count)
	for index in retained_count:
		rows[index] = {"valid": _row_valid[index] != 0,
			"raw_contact_index": _raw_indices[index],
			"global_physics_tick": global_physics_tick,
			"physics_tick_authoritative": false,
			"target_root_frame_world": target_root_frame_world,
			"self_identity": self_identity.duplicate(true),
			"self_identity_authoritative": false,
			"peer_identity": _peer_identities[index].duplicate(true),
			"counterpart_runtime_id": _counterpart_runtime_ids[index],
			"point_on_self_world_m": _points_self_world[index],
			"point_on_counterpart_world_m": _points_counterpart_world[index],
			"normal_on_self_world": _normals_on_self_world[index],
			"velocity_on_self_world_mps": _velocities_self_world[index],
			"velocity_on_counterpart_world_mps": _velocities_counterpart_world[index],
			"relative_velocity_world_mps": _relative_velocities_world[index],
			"closing_speed_along_normal_mps": _closing_speeds_mps[index],
			"closing_speed_semantics": "derived_same_row_point_kinematics_not_source_impact_speed",
			"impulse_on_self_world_ns": _impulses_on_self_world_ns[index],
			"proposal_only": true, "server_admissible": false}

	var collection_gap := cap_gap or identity_gap or nonfinite_gap \
		or duplicate_index_gap or counterpart_overflow_gap
	return {"valid": true, "complete": not collection_gap, "reason": "",
		"global_physics_tick": global_physics_tick,
		"physics_tick_authoritative": false,
		"target_root_frame_world": target_root_frame_world,
		"target_frame_source": "PhysicsDirectBodyState3D.transform_at_collect",
		"target_frame_is_center_of_mass": false,
		"contact_accessors_are_world_space": true,
		"self_identity": self_identity.duplicate(true),
		"self_identity_authoritative": false,
		"closing_speed_semantics": "derived_same_row_point_kinematics_not_source_impact_speed",
		"rows": rows,
		"status": {"raw_state_contact_count": raw_contact_count,
			"retained_contact_count": retained_count, "point_capacity": POINT_CAPACITY,
			"unique_counterpart_count": unique_counterpart_count,
			"collection_cap_gap": cap_gap,
			"collection_identity_gap": identity_gap,
			"collection_nonfinite_gap": nonfinite_gap,
			"collection_duplicate_index_gap": duplicate_index_gap,
			"collection_counterpart_overflow_gap": counterpart_overflow_gap,
			"collection_gap": collection_gap,
			"runtime_wired": false,
			"authority": "raw_observation_only"}}

func candidate_contract() -> Dictionary:
	return {"candidate_only": true, "baseline_sha256":
		"d14946c97ecdb43105d6d760553a7de0151eda64b22e3254b285a94987c759f0",
		"elided_operation": "cold_intermediate_peer_identity_deep_copy",
		"identity_describe_returns_fresh_owned_dictionary": true,
		"retains_caller_owned_data": false,
		"final_row_identity_deep_copy_retained": true,
		"metadata_cache": false, "filters_contacts": false,
		"runtime_wired": false, "owns_authority": false}
