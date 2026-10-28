extends RefCounted
## Bounded directed contact aggregation. One instance per body, one global tick.
## Inputs are world-space direct-state values; output remains a local proposal.
## Fleet pair canonicalization and server admission are separate consumers.

const NORMAL_IMPULSE_NOISE_TOLERANCE_NS := 0.0001

var capacity: int
var tick := -1
var count := 0
var overflow_total := 0
var invalid_total := 0
## Lifetime count. Cleared only by reset_lifetime(), not begin_tick().
var clipped_normal_total := 0
## Sum of removed negative normal impulse magnitudes for the current tick.
var clipped_normal_ns := 0.0
var gap := false
var invalid_gap := false
var overflow_gap := false
var _runtime_ids := PackedInt64Array()
var _point_counts := PackedInt32Array()
var _impulses := PackedVector3Array()
var _angular_impulses := PackedVector3Array()
var _point_sums := PackedVector3Array()
var _normal_sums := PackedVector3Array()
var _relative_at_peak := PackedVector3Array()
var _weights := PackedFloat64Array()
var _peak_closing := PackedFloat64Array()

func _init(slot_capacity := 8) -> void:
	capacity = clampi(slot_capacity, 1, 32)
	_runtime_ids.resize(capacity)
	_point_counts.resize(capacity)
	_impulses.resize(capacity)
	_angular_impulses.resize(capacity)
	_point_sums.resize(capacity)
	_normal_sums.resize(capacity)
	_relative_at_peak.resize(capacity)
	_weights.resize(capacity)
	_peak_closing.resize(capacity)

func begin_tick(global_tick: int) -> bool:
	if global_tick < 0 or global_tick <= tick:
		return false
	tick = global_tick
	count = 0
	gap = false
	invalid_gap = false
	overflow_gap = false
	clipped_normal_ns = 0.0
	return true

func observe(runtime_id: int, point_self_world: Vector3, point_other_world: Vector3,
		normal_on_self: Vector3, impulse_on_self_ns: Vector3,
		velocity_self_mps: Vector3, velocity_other_mps: Vector3, com_world: Vector3) -> bool:
	if tick < 0 or runtime_id <= 0 or not point_self_world.is_finite() \
		or not point_other_world.is_finite() or not normal_on_self.is_finite() \
		or normal_on_self.length_squared() < 0.000001 or not impulse_on_self_ns.is_finite() \
		or not velocity_self_mps.is_finite() or not velocity_other_mps.is_finite() or not com_world.is_finite():
		invalid_total += 1
		gap = true
		invalid_gap = true
		return false
	var normal := normal_on_self.normalized()
	var normal_impulse := impulse_on_self_ns.dot(normal)
	if not is_finite(normal_impulse) or normal_impulse < -NORMAL_IMPULSE_NOISE_TOLERANCE_NS:
		invalid_total += 1
		gap = true
		invalid_gap = true
		return false
	var admitted_impulse := impulse_on_self_ns
	var clipped_magnitude_ns := 0.0
	if normal_impulse < 0.0:
		# Preserve the measured tangent exactly; remove only solver-scale negative
		# normal jitter before conservation sums and COM moments are accumulated.
		admitted_impulse -= normal * normal_impulse
		clipped_magnitude_ns = -normal_impulse
		normal_impulse = 0.0
	var relative := velocity_self_mps - velocity_other_mps
	var angular := (point_self_world - com_world).cross(admitted_impulse)
	var closing := maxf(0.0, -relative.dot(normal))
	if not relative.is_finite() or not angular.is_finite() or not is_finite(closing):
		invalid_total += 1
		gap = true
		invalid_gap = true
		return false
	var slot := -1
	for index in count:
		if _runtime_ids[index] == runtime_id:
			slot = index
			break
	if slot < 0:
		if count == capacity:
			overflow_total += 1
			gap = true
			overflow_gap = true
			return false
		slot = count
		count += 1
		_runtime_ids[slot] = runtime_id
		_point_counts[slot] = 0
		_impulses[slot] = Vector3.ZERO
		_angular_impulses[slot] = Vector3.ZERO
		_point_sums[slot] = Vector3.ZERO
		_normal_sums[slot] = Vector3.ZERO
		_relative_at_peak[slot] = Vector3.ZERO
		_weights[slot] = 0.0
		_peak_closing[slot] = 0.0
	if clipped_magnitude_ns > 0.0:
		clipped_normal_total += 1
		clipped_normal_ns += clipped_magnitude_ns
	# Keep zero-impulse onset observations for the later pair lifecycle reducer.
	var weight := maxf(normal_impulse, 0.000001)
	_point_counts[slot] += 1
	_impulses[slot] += admitted_impulse
	_angular_impulses[slot] += angular
	_point_sums[slot] += (point_self_world + point_other_world) * (0.5 * weight)
	_normal_sums[slot] += normal * weight
	_weights[slot] += weight
	if closing > _peak_closing[slot]:
		_peak_closing[slot] = closing
		_relative_at_peak[slot] = relative
	return true

func reset_lifetime() -> void:
	# Slot storage stays allocated and is overwritten on the next admitted tick.
	tick = -1
	count = 0
	overflow_total = 0
	invalid_total = 0
	clipped_normal_total = 0
	clipped_normal_ns = 0.0
	gap = false
	invalid_gap = false
	overflow_gap = false

func snapshot(slot: int, body_frame: Transform3D) -> Dictionary:
	# Allocating export API: call after collection, never for each raw point.
	if slot < 0 or slot >= count or not body_frame.is_finite() or absf(body_frame.basis.determinant()) < 0.000001:
		return {"valid": false}
	var inverse_basis := body_frame.basis.orthonormalized().transposed()
	var normal_valid := _normal_sums[slot].length_squared() > 0.000001 * _weights[slot] * _weights[slot]
	if not _impulses[slot].is_finite() or not _angular_impulses[slot].is_finite() \
		or not _point_sums[slot].is_finite() or not _normal_sums[slot].is_finite() or not is_finite(_weights[slot]):
		return {"valid": false, "collection_gap": true}
	return {"valid": true, "proposal_only": true, "physics_tick": tick,
		"counterpart_runtime_id": _runtime_ids[slot], "raw_contact_count": _point_counts[slot],
		"point_world_m": _point_sums[slot] / _weights[slot],
		"normal_on_self_world": _normal_sums[slot].normalized(),
		"aggregate_normal_valid": normal_valid,
		"body_impulse_world_ns": _impulses[slot],
		"body_impulse_local_ns": inverse_basis * _impulses[slot],
		"body_angular_impulse_world_nms": _angular_impulses[slot],
		"body_angular_impulse_local_nms": inverse_basis * _angular_impulses[slot],
		"peak_closing_speed_mps": _peak_closing[slot],
		"relative_velocity_at_peak_world_mps": _relative_at_peak[slot],
		"collection_gap": gap, "overflow_gap": overflow_gap,
		"invalid_gap": invalid_gap, "clipped_normal_total": clipped_normal_total,
		"clipped_normal_ns": clipped_normal_ns, "server_admissible": false}
