extends RefCounted
## Bounded PhysicsDirectBodyState3D -> directed manifold proposal bridge.
## Contact coordinates/normals are consumed exactly as world-space values.
## Identity authority, fleet pair canonicalization, ledgers and damage are owners.
## Consumers must require valid && complete; valid only means the collection
## inputs/lifetime were admitted, while complete is false for every partial gap.

const Identity = preload("res://scripts/vehicle_physics/vehicle_contact_identity.gd")
const Manifold = preload("res://scripts/vehicle_physics/vehicle_contact_manifold.gd")
const POINT_CAPACITY := 8
const COUNTERPART_CAPACITY := 8
const CACHE_CAPACITY := 8
const KIND_NONE := 0
const KIND_STATIC := 1
const KIND_VEHICLE := 2

var _manifold = Manifold.new(COUNTERPART_CAPACITY)
var _cache_runtime_ids := PackedInt64Array()
var _cache_admitted := PackedByteArray()
var _cache_kinds := PackedByteArray()
var _cache_source_ids := PackedStringArray()
var _cache_source_indices := PackedInt32Array()
var _cache_vehicle_ids := PackedStringArray()
var _cache_life_generations := PackedInt32Array()
var _cache_used := 0
var _cache_replace_cursor := 0
var _bound_self_vehicle_id := ""
var _bound_self_life_generation := 0

var cache_hit_total := 0
var cache_miss_total := 0
var cache_eviction_total := 0
var identity_rejected_point_total := 0
var self_identity_rejected_point_total := 0
var identity_mutation_total := 0
var runtime_mismatch_total := 0
var collect_invalid_total := 0
var collection_cap_gap := false
var collection_identity_gap := false
var collection_manifold_gap := false
var raw_state_contact_count := 0
var processed_point_count := 0
var admitted_point_count := 0
var proposal_count := 0

func _init() -> void:
	_cache_runtime_ids.resize(CACHE_CAPACITY)
	_cache_admitted.resize(CACHE_CAPACITY)
	_cache_kinds.resize(CACHE_CAPACITY)
	_cache_source_ids.resize(CACHE_CAPACITY)
	_cache_source_indices.resize(CACHE_CAPACITY)
	_cache_vehicle_ids.resize(CACHE_CAPACITY)
	_cache_life_generations.resize(CACHE_CAPACITY)
	_clear_cache()

func collect(state: PhysicsDirectBodyState3D, self_ref: Dictionary, global_tick: int,
		body_frame: Transform3D, com_world: Vector3) -> Dictionary:
	_begin_collection_status()
	# Validate the frame before committing an unbound self lifetime. A malformed
	# first call must not pin a false identity into the bridge.
	if not is_instance_valid(state) or global_tick < 0 \
			or not body_frame.is_finite() or absf(body_frame.basis.determinant()) < 0.000001 \
			or not com_world.is_finite():
		collect_invalid_total += 1
		return _result(false, "invalid_collection_frame", [])
	if not _valid_self_ref(self_ref):
		collect_invalid_total += 1
		return _result(false, "invalid_self_ref", [])
	if not _self_ref_matches_or_unbound(self_ref):
		collect_invalid_total += 1
		return _result(false, "self_lifetime_requires_reset", [])
	if not _manifold.begin_tick(global_tick):
		collect_invalid_total += 1
		return _result(false, "nonmonotonic_global_tick", [])
	if _bound_self_vehicle_id.is_empty():
		_bound_self_vehicle_id = self_ref.vehicle_id
		_bound_self_life_generation = self_ref.life_generation

	_expire_rejected_cache_slots()
	raw_state_contact_count = state.get_contact_count()
	collection_cap_gap = raw_state_contact_count >= POINT_CAPACITY
	var point_count := mini(raw_state_contact_count, POINT_CAPACITY)
	for index in point_count:
		processed_point_count += 1
		var collider := state.get_contact_collider_object(index)
		if not is_instance_valid(collider):
			collection_identity_gap = true
			identity_rejected_point_total += 1
			continue
		var runtime_id := collider.get_instance_id()
		if runtime_id <= 0 or runtime_id != state.get_contact_collider_id(index):
			collection_identity_gap = true
			runtime_mismatch_total += 1
			continue
		var cache_slot := _identity_slot(collider, runtime_id)
		if cache_slot < 0 or _cache_admitted[cache_slot] == 0:
			collection_identity_gap = true
			identity_rejected_point_total += 1
			continue
		# Physics should not report self-contact, but a duplicate/impostor body can
		# carry the same wire identity. Never emit that degenerate directed pair.
		if _cache_kinds[cache_slot] == KIND_VEHICLE \
				and _cache_vehicle_ids[cache_slot] == _bound_self_vehicle_id \
				and _cache_life_generations[cache_slot] == _bound_self_life_generation:
			collection_identity_gap = true
			identity_rejected_point_total += 1
			self_identity_rejected_point_total += 1
			continue
		# These five direct-state contact values are already in world space.
		var point_self_world := state.get_contact_local_position(index)
		var point_other_world := state.get_contact_collider_position(index)
		var normal_on_self_world := state.get_contact_local_normal(index)
		var impulse_on_self_world_ns := state.get_contact_impulse(index)
		# Closing is sourced from the paired point velocities, never from
		# state.linear_velocity, whose solver chronology is not aligned with J.
		var velocity_self_world_mps := state.get_contact_local_velocity_at_position(index)
		var velocity_other_world_mps := state.get_contact_collider_velocity_at_position(index)
		if _manifold.observe(runtime_id, point_self_world, point_other_world,
				normal_on_self_world, impulse_on_self_world_ns,
				velocity_self_world_mps, velocity_other_world_mps, com_world):
			admitted_point_count += 1
		else:
			collection_manifold_gap = true

	var proposals: Array[Dictionary] = []
	for slot in _manifold.count:
		var row: Dictionary = _manifold.snapshot(slot, body_frame)
		if not bool(row.get("valid", false)):
			collection_manifold_gap = true
			continue
		var runtime_id := int(row.counterpart_runtime_id)
		var cache_slot := _find_cache_slot(runtime_id)
		if cache_slot < 0 or _cache_admitted[cache_slot] == 0:
			collection_identity_gap = true
			continue
		row.self_vehicle_id = _bound_self_vehicle_id
		row.self_life_generation = _bound_self_life_generation
		row.counterpart_wire = _wire_snapshot(cache_slot)
		row.directed = true
		row.fleet_canonical = false
		row.engine_authoritative = false
		row.temporal_alignment = "contact_api_observation_only"
		row.collection_cap_gap = collection_cap_gap
		row.collection_identity_gap = collection_identity_gap
		row.collection_gap = bool(row.collection_gap) or collection_cap_gap \
			or collection_identity_gap or collection_manifold_gap
		proposals.append(row)
	# A late snapshot/cache failure must mark every row from this collection,
	# including rows exported before that failure was observed.
	var final_collection_gap := collection_cap_gap or collection_identity_gap or collection_manifold_gap
	for row: Dictionary in proposals:
		row.collection_cap_gap = collection_cap_gap
		row.collection_identity_gap = collection_identity_gap
		row.collection_gap = bool(row.collection_gap) or final_collection_gap
	proposal_count = proposals.size()
	return _result(true, "", proposals)

func reset_lifetime() -> void:
	_manifold.reset_lifetime()
	_bound_self_vehicle_id = ""
	_bound_self_life_generation = 0
	cache_hit_total = 0
	cache_miss_total = 0
	cache_eviction_total = 0
	identity_rejected_point_total = 0
	self_identity_rejected_point_total = 0
	identity_mutation_total = 0
	runtime_mismatch_total = 0
	collect_invalid_total = 0
	_begin_collection_status()
	_clear_cache()

func cache_entry_count() -> int:
	var active := 0
	for slot in _cache_used:
		if _cache_runtime_ids[slot] != 0:
			active += 1
	return active

func clipped_normal_total() -> int:
	return _manifold.clipped_normal_total

func _valid_self_ref(self_ref: Dictionary) -> bool:
	var vehicle_id: Variant = self_ref.get("vehicle_id")
	var life_generation: Variant = self_ref.get("life_generation")
	if not vehicle_id is String or vehicle_id.strip_edges().is_empty() \
			or not life_generation is int or life_generation < 1:
		return false
	return true

func _self_ref_matches_or_unbound(self_ref: Dictionary) -> bool:
	if _bound_self_vehicle_id.is_empty():
		return true
	var vehicle_id: String = self_ref.vehicle_id
	var life_generation: int = self_ref.life_generation
	return vehicle_id == _bound_self_vehicle_id and life_generation == _bound_self_life_generation

func _identity_slot(collider: Object, runtime_id: int) -> int:
	var existing := _find_cache_slot(runtime_id)
	if existing >= 0:
		cache_hit_total += 1
		if _cache_admitted[existing] != 0 and not _cached_identity_matches(collider, existing):
			_cache_admitted[existing] = 0
			identity_mutation_total += 1
		return existing
	cache_miss_total += 1
	var slot := -1
	for reusable in _cache_used:
		if _cache_runtime_ids[reusable] == 0:
			slot = reusable
			break
	if slot < 0 and _cache_used < CACHE_CAPACITY:
		slot = _cache_used
		_cache_used += 1
	elif slot < 0:
		slot = _cache_replace_cursor
		_cache_replace_cursor = (_cache_replace_cursor + 1) % CACHE_CAPACITY
		cache_eviction_total += 1
	_clear_cache_slot(slot)
	_cache_runtime_ids[slot] = runtime_id
	var identity: Dictionary = Identity.describe(collider)
	if not bool(identity.get("valid", false)):
		return slot
	var kind := str(identity.get("kind", ""))
	if kind == "static":
		var source_id: Variant = identity.get("source_id")
		var source_index: Variant = identity.get("source_index")
		if not source_id is String or source_id.strip_edges().is_empty() \
				or not source_index is int or source_index < 0:
			return slot
		_cache_kinds[slot] = KIND_STATIC
		_cache_source_ids[slot] = source_id
		_cache_source_indices[slot] = source_index
	elif kind == "vehicle":
		var vehicle_id: Variant = identity.get("vehicle_id")
		var life_generation: Variant = identity.get("life_generation")
		if not vehicle_id is String or vehicle_id.strip_edges().is_empty() \
				or not life_generation is int or life_generation < 1:
			return slot
		_cache_kinds[slot] = KIND_VEHICLE
		_cache_vehicle_ids[slot] = vehicle_id
		_cache_life_generations[slot] = life_generation
	else:
		return slot
	_cache_admitted[slot] = 1
	return slot

func _find_cache_slot(runtime_id: int) -> int:
	for index in _cache_used:
		if _cache_runtime_ids[index] == runtime_id:
			return index
	return -1

func _cached_identity_matches(collider: Object, slot: int) -> bool:
	if _cache_kinds[slot] == KIND_STATIC:
		if not collider is StaticBody3D or not collider.has_meta("source_id") \
				or not collider.has_meta("source_index"):
			return false
		var source_id: Variant = collider.get_meta("source_id")
		var source_index: Variant = collider.get_meta("source_index")
		return source_id is String and not source_id.strip_edges().is_empty() \
			and source_index is int and source_index >= 0 \
			and source_id == _cache_source_ids[slot] \
			and source_index == _cache_source_indices[slot]
	if _cache_kinds[slot] == KIND_VEHICLE:
		if not collider is RigidBody3D or not collider.has_meta("vehicle_id") \
				or not collider.has_meta("life_generation"):
			return false
		var vehicle_id: Variant = collider.get_meta("vehicle_id")
		var life_generation: Variant = collider.get_meta("life_generation")
		return vehicle_id is String and not vehicle_id.strip_edges().is_empty() \
			and life_generation is int and life_generation >= 1 \
			and vehicle_id == _cache_vehicle_ids[slot] \
			and life_generation == _cache_life_generations[slot]
	return false

func _wire_snapshot(slot: int) -> Dictionary:
	if _cache_kinds[slot] == KIND_STATIC:
		return {"kind": "static", "source_id": _cache_source_ids[slot],
			"source_index": _cache_source_indices[slot], "proposal_only": true,
			"server_admissible": false}
	if _cache_kinds[slot] == KIND_VEHICLE:
		return {"kind": "vehicle", "vehicle_id": _cache_vehicle_ids[slot],
			"life_generation": _cache_life_generations[slot], "proposal_only": true,
			"server_admissible": false}
	return {"kind": "invalid", "proposal_only": true, "server_admissible": false}

func _begin_collection_status() -> void:
	collection_cap_gap = false
	collection_identity_gap = false
	collection_manifold_gap = false
	raw_state_contact_count = 0
	processed_point_count = 0
	admitted_point_count = 0
	proposal_count = 0

func _result(valid: bool, reason: String, proposals: Array[Dictionary]) -> Dictionary:
	var complete := valid and not (collection_cap_gap or collection_identity_gap or collection_manifold_gap)
	return {"valid": valid, "complete": complete, "reason": reason, "proposals": proposals,
		"status": {"raw_state_contact_count": raw_state_contact_count,
			"processed_point_count": processed_point_count,
			"admitted_point_count": admitted_point_count,
			"proposal_count": proposal_count,
			"point_capacity": POINT_CAPACITY,
			"counterpart_capacity": COUNTERPART_CAPACITY,
			"collection_cap_gap": collection_cap_gap,
			"collection_identity_gap": collection_identity_gap,
			"collection_manifold_gap": collection_manifold_gap,
			"collection_gap": collection_cap_gap or collection_identity_gap or collection_manifold_gap,
			"cache_used": cache_entry_count(),
			"cache_hit_total": cache_hit_total,
			"cache_miss_total": cache_miss_total,
			"cache_eviction_total": cache_eviction_total,
			"identity_rejected_point_total": identity_rejected_point_total,
			"self_identity_rejected_point_total": self_identity_rejected_point_total,
			"identity_mutation_total": identity_mutation_total,
			"runtime_mismatch_total": runtime_mismatch_total,
			"collect_invalid_total": collect_invalid_total,
			"clipped_normal_total": _manifold.clipped_normal_total,
			"clipped_normal_ns": _manifold.clipped_normal_ns,
			"runtime_wired": false,
			"temporal_alignment": "contact_api_observation_only"}}

func _clear_cache() -> void:
	_cache_used = 0
	_cache_replace_cursor = 0
	for slot in CACHE_CAPACITY:
		_clear_cache_slot(slot)

func _expire_rejected_cache_slots() -> void:
	# Invalid identity is cached only within one collection to avoid repeated
	# adapter allocations for a multi-point manifold. Retry next tick so a cold
	# metadata bind can recover; the slot is immediately reusable.
	for slot in _cache_used:
		if _cache_admitted[slot] == 0:
			_clear_cache_slot(slot)

func _clear_cache_slot(slot: int) -> void:
	_cache_runtime_ids[slot] = 0
	_cache_admitted[slot] = 0
	_cache_kinds[slot] = KIND_NONE
	_cache_source_ids[slot] = ""
	_cache_source_indices[slot] = -1
	_cache_vehicle_ids[slot] = ""
	_cache_life_generations[slot] = 0
