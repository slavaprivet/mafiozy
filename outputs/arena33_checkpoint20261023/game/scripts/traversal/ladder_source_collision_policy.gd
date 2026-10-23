class_name NativeLadderSourceCollisionPolicy
extends RefCounted
## Source Walk permits only the ladder's own entry bodies near its authored path.
## No RID ownership or mutation: host binds exact exported indices, manages leases,
## and restores physical filters outside this corridor. Support queries stay intact.

const NEAR_PATH_RADIUS_M := .33 + .18

static func near_path(feet: Vector3, descriptor: Dictionary) -> bool:
	if not feet.is_finite() or str(descriptor.get("id", "")).is_empty():
		return false
	var path: Array = descriptor.get("path", [])
	if path.size() < 2:
		return false
	var best := INF
	for i in range(1, path.size()):
		if not path[i-1] is Vector3 or not path[i] is Vector3:
			return false
		var a: Vector3 = path[i-1]
		var b: Vector3 = path[i]
		if not a.is_finite() or not b.is_finite():
			return false
		var delta := b-a
		var t := clampf((feet-a).dot(delta)/delta.length_squared(),0.0,1.0) if delta.length_squared()>0.0 else 0.0
		best = minf(best,feet.distance_to(a+delta*t))
	return best <= NEAR_PATH_RADIUS_M

static func excludes(feet: Vector3, descriptor: Dictionary, current_bodies: Array) -> Array[RID]:
	if not near_path(feet,descriptor):
		return []
	return bind_current(descriptor,current_bodies)

static func bind_current(descriptor: Dictionary, current_bodies: Array) -> Array[RID]:
	var result: Array[RID] = []
	if str(descriptor.get("id", "")).is_empty():
		return result
	for record: Variant in current_bodies:
		if not record is Dictionary or str(record.get("building_entry_id", "")) != str(descriptor.id):
			continue
		if str(record.get("storey_part", "")).begins_with("Roof_Ladder_Rail_Collision"):
			continue
		var rid: Variant = record.get("rid")
		if rid is RID and rid.is_valid() and not result.has(rid):
			result.append(rid)
	return result

static func excludes_bound(feet: Vector3, descriptor: Dictionary, current_bound_rids: Array[RID]) -> Array[RID]:
	# Caller must lease/rebind these RIDs when an entry is rebuilt or removed.
	return current_bound_rids if near_path(feet,descriptor) else []
