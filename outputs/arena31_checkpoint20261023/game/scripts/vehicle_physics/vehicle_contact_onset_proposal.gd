extends RefCounted
## Bounded observation-only onset latch. Own one instance per target vehicle body.
## It neither authenticates source obstacles nor allocates crash/event authority.

const CAPACITY := 8
const MIN_CLOSING_MPS := 2.0
const REARM_BELOW_MPS := 0.5
## Math.round((speed / 4.1)^2 * 1.4) first reaches one at this speed.
## These are observation milestones, never source damage/crash admission.
const DAMAGE_ROUNDING_BOUNDARY_MPS := 2.45021864913551
const STRUCTURAL_CRASH_FLOOR_MPS := 2.5
const BRANCH_ACTIVE_STATIC := "active_static"
const BRANCH_PASSIVE_STATIC := "passive_static"
const BRANCH_PEER := "peer"

var _target_vehicle_id := ""
var _target_life := -1
var _last_tick := -1
var _needs_rebaseline := false
var _ids := PackedInt64Array()
var _identities: Array[Dictionary] = []
var _seen := PackedByteArray()
var _armed := PackedByteArray()
var _damage_boundary_seen := PackedByteArray()
var _structural_floor_seen := PackedByteArray()
var _best_rows := PackedInt32Array()
var _best_closing := PackedFloat64Array()
var _count := 0

func _init() -> void:
	_ids.resize(CAPACITY)
	_identities.resize(CAPACITY)
	_seen.resize(CAPACITY)
	_armed.resize(CAPACITY)
	_damage_boundary_seen.resize(CAPACITY)
	_structural_floor_seen.resize(CAPACITY)
	_best_rows.resize(CAPACITY)
	_best_closing.resize(CAPACITY)

## Returns null when no new onset; only a qualifying onset allocates a result.
func scan(observation: RefCounted, branch: String) -> Variant:
	if not _envelope_valid(observation, branch):
		_invalidate_continuity()
		return null
	var tick: int = observation.global_physics_tick
	var vehicle_id: String = observation.self_identity.vehicle_id
	var life: int = observation.self_identity.life_generation
	if vehicle_id != _target_vehicle_id or life != _target_life:
		_clear()
		_target_vehicle_id = vehicle_id
		_target_life = life
	elif _last_tick >= 0 and tick != _last_tick + 1:
		_invalidate_continuity()
		_needs_rebaseline = true
	_last_tick = tick
	_prune_absent(observation)
	for slot in _count:
		_seen[slot] = 0
		_best_rows[slot] = -1
		_best_closing[slot] = 0.0
	for row in observation.retained_contact_count:
		var runtime_id: int = observation.counterpart_runtime_ids[row]
		var peer: Dictionary = observation.peer_identities[row]
		var slot := -1
		for known in _count:
			if _ids[known] == runtime_id and _identities[known] == peer:
				slot = known
				break
		if slot < 0:
			if _count >= CAPACITY:
				_invalidate_continuity()
				return null
			slot = _count
			_count += 1
			_ids[slot] = runtime_id
			_identities[slot] = peer.duplicate(true)
			_armed[slot] = 1
			_damage_boundary_seen[slot] = 0
			_structural_floor_seen[slot] = 0
		_seen[slot] = 1
		var closing: float = observation.closing_speeds_mps[row]
		if _best_rows[slot] < 0 or closing > _best_closing[slot] or (closing == _best_closing[slot] and observation.raw_indices[row] < observation.raw_indices[_best_rows[slot]]):
			_best_rows[slot] = row
			_best_closing[slot] = closing
	var winner := -1
	for slot in _count:
		if _seen[slot] == 0:
			_armed[slot] = 1
			continue
		var closing: float = _best_closing[slot]
		if closing < REARM_BELOW_MPS:
			_armed[slot] = 1
			_damage_boundary_seen[slot] = 0
			_structural_floor_seen[slot] = 0
		elif closing >= MIN_CLOSING_MPS:
			var static_peer: bool = _identities[slot].get("kind") == "static"
			var crossed_damage: bool = static_peer and _damage_boundary_seen[slot] == 0 and closing >= DAMAGE_ROUNDING_BOUNDARY_MPS
			var crossed_structure: bool = static_peer and _structural_floor_seen[slot] == 0 and closing >= STRUCTURAL_CRASH_FLOOR_MPS
			if not _needs_rebaseline and (_armed[slot] != 0 or crossed_damage or crossed_structure):
				if winner < 0 or closing > _best_closing[winner] or (closing == _best_closing[winner] and _ids[slot] < _ids[winner]) or (closing == _best_closing[winner] and _ids[slot] == _ids[winner] and observation.raw_indices[_best_rows[slot]] < observation.raw_indices[_best_rows[winner]]):
					winner = slot
			_armed[slot] = 0
			if static_peer and closing >= DAMAGE_ROUNDING_BOUNDARY_MPS:
				_damage_boundary_seen[slot] = 1
			if static_peer and closing >= STRUCTURAL_CRASH_FLOOR_MPS:
				_structural_floor_seen[slot] = 1
	_needs_rebaseline = false
	if winner < 0:
		return null
	var row: int = _best_rows[winner]
	var frame: Transform3D = observation.target_root_frame_world
	var outward: Vector3 = -observation.normals_on_self_world[row].normalized()
	var result := {
		"valid": true, "proposal_only": true, "server_admissible": false,
		"physics_tick_authoritative": false, "self_identity_authoritative": false,
		"owns_event_identity": false, "owns_cooldown": false, "owns_damage": false,
		"source_branch": branch, "source_obstacle_role_verified": false,
		"global_physics_tick": tick, "raw_contact_index": observation.raw_indices[row],
		"self_identity": observation.self_identity.duplicate(true),
		"peer_identity": observation.peer_identities[row].duplicate(true),
		"counterpart_runtime_id": observation.counterpart_runtime_ids[row],
		"point_on_self_world_m": observation.points_self_world[row],
		"normal_on_self_world": observation.normals_on_self_world[row],
		"source_outward_world": outward,
		"target_root_frame_at_onset_world": frame,
		"point_target_root_local_m": frame.affine_inverse() * observation.points_self_world[row],
		"outward_target_root_local": (frame.basis.inverse() * outward).normalized(),
		"relative_velocity_world_mps": observation.relative_velocities_world[row],
		"closing_speed_along_normal_mps": observation.closing_speeds_mps[row],
		"impulse_on_self_world_ns_at_onset": observation.impulses_on_self_world_ns[row]
	}
	if branch == BRANCH_ACTIVE_STATIC:
		result["tentative_active_static_impact_speed_mps"] = observation.closing_speeds_mps[row]
	return result

func _envelope_valid(o: RefCounted, branch: String) -> bool:
	if o == null or not o.valid or not o.complete or o.collection_gap or o.collection_cap_gap or o.collection_identity_gap or o.collection_nonfinite_gap or o.collection_duplicate_index_gap or o.collection_counterpart_overflow_gap:
		return false
	if branch != BRANCH_ACTIVE_STATIC and branch != BRANCH_PASSIVE_STATIC and branch != BRANCH_PEER:
		return false
	var n: int = o.retained_contact_count
	if n < 0 or n >= CAPACITY or n != o.raw_state_contact_count or o.global_physics_tick < 0 or not o.target_root_frame_world.is_finite() or absf(o.target_root_frame_world.basis.determinant()) < 0.000001:
		return false
	var self_id: Dictionary = o.self_identity
	if not bool(self_id.get("valid", false)) or self_id.get("kind") != "vehicle" or not self_id.get("vehicle_id") is String or String(self_id.vehicle_id).strip_edges().is_empty() or not self_id.get("life_generation") is int or int(self_id.life_generation) < 1:
		return false
	if o.raw_indices.size() < n or o.counterpart_runtime_ids.size() < n or o.points_self_world.size() < n or o.normals_on_self_world.size() < n or o.velocities_self_world.size() < n or o.velocities_counterpart_world.size() < n or o.relative_velocities_world.size() < n or o.closing_speeds_mps.size() < n or o.impulses_on_self_world_ns.size() < n or o.row_valid.size() < n or o.peer_identities.size() < n:
		return false
	for row in n:
		var peer: Dictionary = o.peer_identities[row]
		var kind: String = "vehicle" if branch == BRANCH_PEER else "static"
		if o.row_valid[row] == 0 or o.raw_indices[row] != row or o.counterpart_runtime_ids[row] <= 0 or not bool(peer.get("valid", false)) or peer.get("kind") != kind or int(peer.get("counterpart_runtime_id", 0)) != o.counterpart_runtime_ids[row]:
			return false
		if kind == "vehicle":
			if not peer.get("vehicle_id") is String or String(peer.vehicle_id).strip_edges().is_empty() or not peer.get("life_generation") is int or int(peer.life_generation) < 1:
				return false
		else:
			if not peer.get("source_id") is String or String(peer.source_id).strip_edges().is_empty() or not peer.get("source_index") is int or int(peer.source_index) < 0:
				return false
		var normal: Vector3 = o.normals_on_self_world[row]
		var relative: Vector3 = o.relative_velocities_world[row]
		var closing: float = o.closing_speeds_mps[row]
		if not o.points_self_world[row].is_finite() or not normal.is_finite() or normal.length_squared() < 0.000001 or not o.velocities_self_world[row].is_finite() or not o.velocities_counterpart_world[row].is_finite() or not relative.is_finite() or not o.impulses_on_self_world_ns[row].is_finite() or not is_finite(closing):
			return false
		if relative.distance_to(o.velocities_self_world[row] - o.velocities_counterpart_world[row]) > 0.0001 or absf(closing - maxf(0.0, -relative.dot(normal.normalized()))) > 0.0001:
			return false
		for prior in row:
			if o.counterpart_runtime_ids[prior] == o.counterpart_runtime_ids[row] and o.peer_identities[prior] != peer:
				return false
	return true

func _invalidate_continuity() -> void:
	_clear()
	_needs_rebaseline = true

func _prune_absent(o: RefCounted) -> void:
	var slot := 0
	while slot < _count:
		var present := false
		for row in o.retained_contact_count:
			if _ids[slot] == o.counterpart_runtime_ids[row] and _identities[slot] == o.peer_identities[row]:
				present = true
				break
		if present:
			slot += 1
			continue
		_count -= 1
		_ids[slot] = _ids[_count]
		_identities[slot] = _identities[_count]
		_armed[slot] = _armed[_count]
		_damage_boundary_seen[slot] = _damage_boundary_seen[_count]
		_structural_floor_seen[slot] = _structural_floor_seen[_count]
		_ids[_count] = 0
		# The stale Dictionary remains outside [0, _count) until a new peer replaces it.

func _clear() -> void:
	_count = 0
	_last_tick = -1
	for slot in CAPACITY:
		_ids[slot] = 0
		_seen[slot] = 0
		_armed[slot] = 0
		_damage_boundary_seen[slot] = 0
		_structural_floor_seen[slot] = 0
		_best_rows[slot] = -1
