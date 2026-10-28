extends RefCounted
## Bounded raw PhysicsDirectBodyState3D contact observation collector.
##
## Every exported row preserves fields from one direct-state contact index and
## the target root frame from that same callback. The API names reflect Godot
## meaning: despite "local" accessor names, points, normals and point velocities
## are world-space values in the audited Godot backend. `state.transform` is the
## target root frame; it is not a COM frame and must not be applied to the raw
## contact values again.
##
## This component does not aggregate contacts or own impact speed, event,
## cooldown, crash, damage, HP, server admission, or peer canonicalization.

const Identity = preload("res://scripts/vehicle_physics/vehicle_contact_identity.gd")
const POINT_CAPACITY := 8

var _raw_indices := PackedInt32Array()
var _counterpart_runtime_ids := PackedInt64Array()
var _points_self_world := PackedVector3Array()
var _points_counterpart_world := PackedVector3Array()
var _normals_on_self_world := PackedVector3Array()
var _velocities_self_world := PackedVector3Array()
var _velocities_counterpart_world := PackedVector3Array()
var _relative_velocities_world := PackedVector3Array()
var _closing_speeds_mps := PackedFloat64Array()
var _impulses_on_self_world_ns := PackedVector3Array()
var _row_valid := PackedByteArray()
var _peer_identities: Array[Dictionary] = []
var _unique_counterparts := PackedInt64Array()

func _init() -> void:
	_raw_indices.resize(POINT_CAPACITY)
	_counterpart_runtime_ids.resize(POINT_CAPACITY)
	_points_self_world.resize(POINT_CAPACITY)
	_points_counterpart_world.resize(POINT_CAPACITY)
	_normals_on_self_world.resize(POINT_CAPACITY)
	_velocities_self_world.resize(POINT_CAPACITY)
	_velocities_counterpart_world.resize(POINT_CAPACITY)
	_relative_velocities_world.resize(POINT_CAPACITY)
	_closing_speeds_mps.resize(POINT_CAPACITY)
	_impulses_on_self_world_ns.resize(POINT_CAPACITY)
	_row_valid.resize(POINT_CAPACITY)
	_peer_identities.resize(POINT_CAPACITY)
	_unique_counterparts.resize(POINT_CAPACITY)

func collect(state: PhysicsDirectBodyState3D, self_ref: Dictionary,
		global_physics_tick: int) -> Dictionary:
	if not is_instance_valid(state) or global_physics_tick < 0:
		return _invalid_envelope("invalid_state_or_tick")
	var self_identity := _self_identity(self_ref)
	if not bool(self_identity.get("valid", false)):
		return _invalid_envelope("invalid_self_identity")
	# Capture the root transform once, in the same callback as every raw row.
	var target_root_frame_world := state.transform
	if not target_root_frame_world.is_finite() \
			or absf(target_root_frame_world.basis.determinant()) < 0.000001:
		return _invalid_envelope("invalid_target_root_frame")

	var raw_contact_count := state.get_contact_count()
	var retained_count := mini(raw_contact_count, POINT_CAPACITY)
	# Count-at-cap is conservatively incomplete because the engine report itself
	# is bounded and cannot prove there was no ninth contact.
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
		_peer_identities[index] = peer_identity.duplicate(true)

	# The direct-state API supplies indices in a dense [0,count) range. Keep an
	# explicit check and status field so any backend violation fails closed.
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

func contract() -> Dictionary:
	return {"point_capacity": POINT_CAPACITY, "raw_rows_not_aggregated": true,
		"target_frame_source": "PhysicsDirectBodyState3D.transform_at_collect",
		"contact_accessors_are_world_space": true,
		"physics_tick_authoritative": false, "self_identity_authoritative": false,
		"closing_speed_semantics": "derived_same_row_point_kinematics_not_source_impact_speed",
		"owns_impact_speed": false, "owns_event_identity": false,
		"owns_peer_canonicalization": false, "owns_cooldown": false,
		"owns_crash_or_damage": false, "owns_hp": false,
		"server_admissible": false, "runtime_wired": false}

func _self_identity(self_ref: Dictionary) -> Dictionary:
	var vehicle_id: Variant = self_ref.get("vehicle_id")
	var life_generation: Variant = self_ref.get("life_generation")
	if not vehicle_id is String or vehicle_id.strip_edges().is_empty() \
			or not life_generation is int or int(life_generation) < 1:
		return {"valid": false}
	return {"valid": true, "kind": "vehicle", "vehicle_id": String(vehicle_id),
		"life_generation": int(life_generation), "proposal_only": true,
		"server_admissible": false}

func _invalid_envelope(reason: String) -> Dictionary:
	return {"valid": false, "complete": false, "reason": reason, "rows": [],
		"status": {"raw_state_contact_count": 0, "retained_contact_count": 0,
			"point_capacity": POINT_CAPACITY, "collection_cap_gap": false,
			"collection_identity_gap": false, "collection_nonfinite_gap": false,
			"collection_duplicate_index_gap": false,
			"collection_counterpart_overflow_gap": false,
			"collection_gap": true, "runtime_wired": false,
			"authority": "raw_observation_only"}}
