extends "res://scripts/vehicle_physics/vehicle_contact_observation_collector.gd"
## Candidate-only identity cache for the frozen coherent raw collector.
##
## The collected envelope/row schema is byte-for-byte field compatible with
## the D149 baseline. Only counterpart identity lookup changes: a per-instance
## eight-slot round-robin cache keeps scalar wire fields only. Every
## callback validates the live object class and metadata; a mutation, removal,
## recovered object, or instance mismatch refreshes through Identity.describe.
## No Node is held strongly and no contact is filtered or aggregated.

const CACHE_CAPACITY := 8
const CACHE_KIND_NONE := 0
const CACHE_KIND_STATIC := 1
const CACHE_KIND_VEHICLE := 2

var _cache_runtime_ids := PackedInt64Array()
var _cache_admitted := PackedByteArray()
var _cache_kinds := PackedByteArray()
var _cache_source_ids := PackedStringArray()
var _cache_source_indices := PackedInt32Array()
var _cache_vehicle_ids := PackedStringArray()
var _cache_life_generations := PackedInt32Array()
var _cache_identity_snapshots: Array[Dictionary] = []
var _cache_invalid_identities: Array[Dictionary] = []
var _cache_slot_by_runtime_id := {}
var _cache_used := 0
var _cache_replace_cursor := 0
var _cache_hit_total := 0
var _cache_miss_total := 0
var _cache_refresh_total := 0
var _cache_eviction_total := 0

func _init() -> void:
	super()
	_cache_runtime_ids.resize(CACHE_CAPACITY)
	_cache_admitted.resize(CACHE_CAPACITY)
	_cache_kinds.resize(CACHE_CAPACITY)
	_cache_source_ids.resize(CACHE_CAPACITY)
	_cache_source_indices.resize(CACHE_CAPACITY)
	_cache_vehicle_ids.resize(CACHE_CAPACITY)
	_cache_life_generations.resize(CACHE_CAPACITY)
	_cache_identity_snapshots.resize(CACHE_CAPACITY)
	_cache_invalid_identities.resize(CACHE_CAPACITY)
	_clear_identity_cache(false)

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
			peer_identity = _cached_identity(collider, reported_runtime_id)
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

func cache_contract() -> Dictionary:
	return {"candidate_only": true, "baseline_schema_exact": true,
		"capacity": CACHE_CAPACITY, "replacement": "round_robin",
		"retains_strong_node_refs": false, "retains_any_object_refs": false,
		"validates_live_class_and_metadata_each_callback": true,
		"refreshes_mutation_removal_or_recovered_object": true,
		"filters_contacts": false, "runtime_wired": false,
		"owns_authority": false}

func cache_status() -> Dictionary:
	var admitted := 0
	for slot in _cache_used:
		if _cache_admitted[slot] != 0:
			admitted += 1
	return {"used": _cache_used, "admitted": admitted,
		"retained_object_refs": 0, "capacity": CACHE_CAPACITY,
		"replace_cursor": _cache_replace_cursor, "hit_total": _cache_hit_total,
		"miss_total": _cache_miss_total, "refresh_total": _cache_refresh_total,
		"eviction_total": _cache_eviction_total}

func reset_cache() -> void:
	_clear_identity_cache(true)

func _cached_identity(collider: Object, runtime_id: int) -> Dictionary:
	var slot := _find_cache_slot(runtime_id)
	if slot >= 0:
		if _cache_admitted[slot] != 0 \
				and _live_metadata_matches(collider, slot):
			_cache_hit_total += 1
			return _cache_identity_snapshots[slot]
		_cache_refresh_total += 1
		return _refresh_cache_slot(slot, collider, runtime_id)
	_cache_miss_total += 1
	slot = _allocate_cache_slot()
	return _refresh_cache_slot(slot, collider, runtime_id)

func _refresh_cache_slot(slot: int, collider: Object, runtime_id: int) -> Dictionary:
	_clear_cache_slot(slot)
	_cache_runtime_ids[slot] = runtime_id
	_cache_slot_by_runtime_id[runtime_id] = slot
	var identity: Dictionary = Identity.describe(collider)
	var admitted := bool(identity.get("valid", false)) \
		and int(identity.get("counterpart_runtime_id", 0)) == runtime_id
	if admitted and identity.get("kind") == "static":
		_cache_kinds[slot] = CACHE_KIND_STATIC
		_cache_source_ids[slot] = identity.source_id
		_cache_source_indices[slot] = identity.source_index
	elif admitted and identity.get("kind") == "vehicle":
		_cache_kinds[slot] = CACHE_KIND_VEHICLE
		_cache_vehicle_ids[slot] = identity.vehicle_id
		_cache_life_generations[slot] = identity.life_generation
	else:
		admitted = false
		_cache_invalid_identities[slot] = identity.duplicate(true)
	_cache_admitted[slot] = 1 if admitted else 0
	_cache_identity_snapshots[slot] = identity.duplicate(true) if admitted else {}
	return _cache_identity_snapshots[slot] if admitted \
		else _cache_invalid_identities[slot]

func _live_metadata_matches(collider: Object, slot: int) -> bool:
	if _cache_kinds[slot] == CACHE_KIND_STATIC:
		if not collider is StaticBody3D or not collider.has_meta("source_id") \
				or not collider.has_meta("source_index"):
			return false
		var source_id: Variant = collider.get_meta("source_id")
		var source_index: Variant = collider.get_meta("source_index")
		return source_id is String and not source_id.strip_edges().is_empty() \
			and source_index is int and int(source_index) >= 0 \
			and source_id == _cache_source_ids[slot] \
			and int(source_index) == _cache_source_indices[slot]
	if _cache_kinds[slot] == CACHE_KIND_VEHICLE:
		if not collider is RigidBody3D or not collider.has_meta("vehicle_id") \
				or not collider.has_meta("life_generation"):
			return false
		var vehicle_id: Variant = collider.get_meta("vehicle_id")
		var life_generation: Variant = collider.get_meta("life_generation")
		return vehicle_id is String and not vehicle_id.strip_edges().is_empty() \
			and life_generation is int and int(life_generation) >= 1 \
			and vehicle_id == _cache_vehicle_ids[slot] \
			and int(life_generation) == _cache_life_generations[slot]
	return false

func _find_cache_slot(runtime_id: int) -> int:
	return int(_cache_slot_by_runtime_id.get(runtime_id, -1))

func _allocate_cache_slot() -> int:
	if _cache_used < CACHE_CAPACITY:
		var fresh := _cache_used
		_cache_used += 1
		return fresh
	var replaced := _cache_replace_cursor
	_cache_replace_cursor = (_cache_replace_cursor + 1) % CACHE_CAPACITY
	_cache_eviction_total += 1
	return replaced

func _clear_identity_cache(reset_metrics: bool) -> void:
	_cache_used = 0
	_cache_replace_cursor = 0
	_cache_slot_by_runtime_id.clear()
	for slot in CACHE_CAPACITY:
		_clear_cache_slot(slot)
	if reset_metrics:
		_cache_hit_total = 0
		_cache_miss_total = 0
		_cache_refresh_total = 0
		_cache_eviction_total = 0

func _clear_cache_slot(slot: int) -> void:
	var previous_runtime_id := _cache_runtime_ids[slot]
	if previous_runtime_id != 0 \
			and int(_cache_slot_by_runtime_id.get(previous_runtime_id, -1)) == slot:
		_cache_slot_by_runtime_id.erase(previous_runtime_id)
	_cache_runtime_ids[slot] = 0
	_cache_admitted[slot] = 0
	_cache_kinds[slot] = CACHE_KIND_NONE
	_cache_source_ids[slot] = ""
	_cache_source_indices[slot] = -1
	_cache_vehicle_ids[slot] = ""
	_cache_life_generations[slot] = 0
	_cache_identity_snapshots[slot] = {}
	_cache_invalid_identities[slot] = {}
