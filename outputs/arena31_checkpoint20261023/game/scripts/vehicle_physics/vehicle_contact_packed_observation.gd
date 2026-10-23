extends RefCounted
## Caller-owned, bounded raw contact observations. No scene, event or damage authority.
## Reusing one buffer overwrites its previous observation; retain a second buffer
## until the first has been consumed. decode_legacy() returns detached dictionaries.

const Identity = preload("res://scripts/vehicle_physics/vehicle_contact_identity.gd")
const CAPACITY := 8
const CLOSING_SEMANTICS := "derived_same_row_point_kinematics_not_source_impact_speed"

var valid := false
var complete := false
var reason := ""
var global_physics_tick := -1
var target_root_frame_world := Transform3D.IDENTITY
var self_identity: Dictionary = {}
var raw_state_contact_count := 0
var retained_contact_count := 0
var unique_counterpart_count := 0
var collection_cap_gap := false
var collection_identity_gap := false
var collection_nonfinite_gap := false
var collection_duplicate_index_gap := false
var collection_counterpart_overflow_gap := false
var collection_gap := true

var raw_indices := PackedInt32Array()
var counterpart_runtime_ids := PackedInt64Array()
var points_self_world := PackedVector3Array()
var points_counterpart_world := PackedVector3Array()
var normals_on_self_world := PackedVector3Array()
var velocities_self_world := PackedVector3Array()
var velocities_counterpart_world := PackedVector3Array()
var relative_velocities_world := PackedVector3Array()
var closing_speeds_mps := PackedFloat64Array()
var impulses_on_self_world_ns := PackedVector3Array()
var row_valid := PackedByteArray()
var peer_identities: Array[Dictionary] = []
var unique_counterparts := PackedInt64Array()

func _init() -> void:
	raw_indices.resize(CAPACITY)
	counterpart_runtime_ids.resize(CAPACITY)
	points_self_world.resize(CAPACITY)
	points_counterpart_world.resize(CAPACITY)
	normals_on_self_world.resize(CAPACITY)
	velocities_self_world.resize(CAPACITY)
	velocities_counterpart_world.resize(CAPACITY)
	relative_velocities_world.resize(CAPACITY)
	closing_speeds_mps.resize(CAPACITY)
	impulses_on_self_world_ns.resize(CAPACITY)
	row_valid.resize(CAPACITY)
	peer_identities.resize(CAPACITY)
	unique_counterparts.resize(CAPACITY)

func collect_into(state: PhysicsDirectBodyState3D, self_ref: Dictionary,
		tick: int) -> bool:
	_reset_header()
	if not is_instance_valid(state) or tick < 0:
		reason = "invalid_state_or_tick"
		return false
	var vehicle_id: Variant = self_ref.get("vehicle_id")
	var life: Variant = self_ref.get("life_generation")
	if not vehicle_id is String or vehicle_id.strip_edges().is_empty() \
			or not life is int or int(life) < 1:
		reason = "invalid_self_identity"
		return false
	self_identity = {"valid": true, "kind": "vehicle", "vehicle_id": String(vehicle_id),
		"life_generation": int(life), "proposal_only": true, "server_admissible": false}
	target_root_frame_world = state.transform
	if not target_root_frame_world.is_finite() \
			or absf(target_root_frame_world.basis.determinant()) < 0.000001:
		reason = "invalid_target_root_frame"
		return false
	valid = true
	global_physics_tick = tick
	raw_state_contact_count = state.get_contact_count()
	retained_contact_count = mini(raw_state_contact_count, CAPACITY)
	collection_cap_gap = raw_state_contact_count >= CAPACITY
	for slot in CAPACITY:
		unique_counterparts[slot] = 0
	for index in retained_contact_count:
		raw_indices[index] = index
		var self_point := state.get_contact_local_position(index)
		var peer_point := state.get_contact_collider_position(index)
		var normal := state.get_contact_local_normal(index)
		var self_velocity := state.get_contact_local_velocity_at_position(index)
		var peer_velocity := state.get_contact_collider_velocity_at_position(index)
		var relative_velocity := self_velocity - peer_velocity
		var impulse := state.get_contact_impulse(index)
		var raw_finite := self_point.is_finite() and peer_point.is_finite() \
			and normal.is_finite() and self_velocity.is_finite() \
			and peer_velocity.is_finite() and relative_velocity.is_finite() \
			and impulse.is_finite() and normal.length_squared() >= 0.000001
		var closing := 0.0
		if raw_finite:
			closing = maxf(0.0, -relative_velocity.dot(normal.normalized()))
			raw_finite = is_finite(closing)
		if not raw_finite:
			collection_nonfinite_gap = true
		var collider := state.get_contact_collider_object(index)
		var runtime_id := state.get_contact_collider_id(index)
		var identity_valid := is_instance_valid(collider) and runtime_id > 0 \
			and collider.get_instance_id() == runtime_id
		var peer_identity: Dictionary
		if identity_valid:
			peer_identity = Identity.describe(collider)
			identity_valid = bool(peer_identity.get("valid", false)) \
				and int(peer_identity.get("counterpart_runtime_id", 0)) == runtime_id
		else:
			peer_identity = {"valid": false, "reason": "missing_or_mismatched_counterpart",
				"counterpart_runtime_id": runtime_id, "proposal_only": true,
				"server_admissible": false}
		if identity_valid and peer_identity.get("kind") == "vehicle" \
				and peer_identity.get("vehicle_id") == self_identity.vehicle_id \
				and peer_identity.get("life_generation") == self_identity.life_generation:
			identity_valid = false
			peer_identity = {"valid": false, "reason": "self_identity_collision",
				"counterpart_runtime_id": runtime_id, "proposal_only": true,
				"server_admissible": false}
		if not identity_valid:
			collection_identity_gap = true
		var already_seen := false
		if runtime_id > 0:
			for unique_index in unique_counterpart_count:
				if unique_counterparts[unique_index] == runtime_id:
					already_seen = true
					break
			if not already_seen:
				if unique_counterpart_count >= CAPACITY:
					collection_counterpart_overflow_gap = true
				else:
					unique_counterparts[unique_counterpart_count] = runtime_id
					unique_counterpart_count += 1
		points_self_world[index] = self_point
		points_counterpart_world[index] = peer_point
		normals_on_self_world[index] = normal
		velocities_self_world[index] = self_velocity
		velocities_counterpart_world[index] = peer_velocity
		relative_velocities_world[index] = relative_velocity
		closing_speeds_mps[index] = closing
		impulses_on_self_world_ns[index] = impulse
		counterpart_runtime_ids[index] = runtime_id
		row_valid[index] = 1 if raw_finite and identity_valid else 0
		peer_identities[index] = peer_identity.duplicate(true)
	for index in retained_contact_count:
		if raw_indices[index] != index:
			collection_duplicate_index_gap = true
	collection_gap = collection_cap_gap or collection_identity_gap \
		or collection_nonfinite_gap or collection_duplicate_index_gap \
		or collection_counterpart_overflow_gap
	complete = not collection_gap
	return true

func decode_legacy() -> Dictionary:
	if not valid:
		return {"valid": false, "complete": false, "reason": reason, "rows": [],
			"status": {"raw_state_contact_count": 0, "retained_contact_count": 0,
				"point_capacity": CAPACITY, "collection_cap_gap": false,
				"collection_identity_gap": false, "collection_nonfinite_gap": false,
				"collection_duplicate_index_gap": false,
				"collection_counterpart_overflow_gap": false,
				"collection_gap": true, "runtime_wired": false,
				"authority": "raw_observation_only"}}
	var rows: Array[Dictionary] = []
	rows.resize(retained_contact_count)
	for index in retained_contact_count:
		rows[index] = {"valid": row_valid[index] != 0,
			"raw_contact_index": raw_indices[index],
			"global_physics_tick": global_physics_tick,
			"physics_tick_authoritative": false,
			"target_root_frame_world": target_root_frame_world,
			"self_identity": self_identity.duplicate(true),
			"self_identity_authoritative": false,
			"peer_identity": peer_identities[index].duplicate(true),
			"counterpart_runtime_id": counterpart_runtime_ids[index],
			"point_on_self_world_m": points_self_world[index],
			"point_on_counterpart_world_m": points_counterpart_world[index],
			"normal_on_self_world": normals_on_self_world[index],
			"velocity_on_self_world_mps": velocities_self_world[index],
			"velocity_on_counterpart_world_mps": velocities_counterpart_world[index],
			"relative_velocity_world_mps": relative_velocities_world[index],
			"closing_speed_along_normal_mps": closing_speeds_mps[index],
			"closing_speed_semantics": CLOSING_SEMANTICS,
			"impulse_on_self_world_ns": impulses_on_self_world_ns[index],
			"proposal_only": true, "server_admissible": false}
	return {"valid": true, "complete": complete, "reason": "",
		"global_physics_tick": global_physics_tick,
		"physics_tick_authoritative": false,
		"target_root_frame_world": target_root_frame_world,
		"target_frame_source": "PhysicsDirectBodyState3D.transform_at_collect",
		"target_frame_is_center_of_mass": false,
		"contact_accessors_are_world_space": true,
		"self_identity": self_identity.duplicate(true),
		"self_identity_authoritative": false,
		"closing_speed_semantics": CLOSING_SEMANTICS,
		"rows": rows,
		"status": {"raw_state_contact_count": raw_state_contact_count,
			"retained_contact_count": retained_contact_count,
			"point_capacity": CAPACITY,
			"unique_counterpart_count": unique_counterpart_count,
			"collection_cap_gap": collection_cap_gap,
			"collection_identity_gap": collection_identity_gap,
			"collection_nonfinite_gap": collection_nonfinite_gap,
			"collection_duplicate_index_gap": collection_duplicate_index_gap,
			"collection_counterpart_overflow_gap": collection_counterpart_overflow_gap,
			"collection_gap": collection_gap,
			"runtime_wired": false, "authority": "raw_observation_only"}}

func contract() -> Dictionary:
	return {"point_capacity": CAPACITY, "raw_rows_not_aggregated": true,
		"caller_owned_reusable_buffer": true, "decode_returns_detached_dictionaries": true,
		"contact_accessors_are_world_space": true,
		"target_frame_source": "PhysicsDirectBodyState3D.transform_at_collect",
		"physics_tick_authoritative": false, "self_identity_authoritative": false,
		"closing_speed_semantics": CLOSING_SEMANTICS,
		"owns_impact_speed": false, "owns_event_identity": false,
		"owns_peer_canonicalization": false, "owns_cooldown": false,
		"owns_crash_or_damage": false, "owns_hp": false,
		"server_admissible": false, "runtime_wired": false}

func _reset_header() -> void:
	valid = false
	complete = false
	reason = ""
	global_physics_tick = -1
	target_root_frame_world = Transform3D.IDENTITY
	self_identity = {}
	raw_state_contact_count = 0
	retained_contact_count = 0
	unique_counterpart_count = 0
	collection_cap_gap = false
	collection_identity_gap = false
	collection_nonfinite_gap = false
	collection_duplicate_index_gap = false
	collection_counterpart_overflow_gap = false
	collection_gap = true
