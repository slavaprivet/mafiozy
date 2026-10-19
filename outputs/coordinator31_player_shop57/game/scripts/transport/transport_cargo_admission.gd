extends RefCounted

# Source trunk acceptsItem geometry only. Callers supply actual cargo floor and
# current posed lid bounds; success never creates/transfers an inventory item.
static func accepts(bounds: AABB, item_center: Vector3, item_half: Vector3, amount: float, detached: bool, has_floor: bool, mode: String, lid_visible: bool, lid_bounds: AABB, available: bool = true) -> bool:
	if not available or mode not in ["trunk", "hatch", "tailgate"]: return false
	if not _box_valid(bounds) or not item_center.is_finite() or not item_half.is_finite() or item_half.x < 0 or item_half.y < 0 or item_half.z < 0 or not is_finite(amount): return false
	if not has_floor or (not detached and amount < .85): return false
	var item_min := item_center - item_half; var item_max := item_center + item_half
	for axis in 3:
		if item_min[axis] < bounds.position[axis] - .0000001 or item_max[axis] > bounds.end[axis] + .0000001: return false
	if not detached and lid_visible:
		if mode not in ["trunk", "hatch", "tailgate"] or not _box_valid(lid_bounds): return false
		# Native Z is source -Z: source min cover Z becomes native max Z.
		var span := bounds.end.z - maxf(bounds.position.z, lid_bounds.end.z) if mode == "trunk" else (minf(bounds.end.y, lid_bounds.position.y) - bounds.position.y if mode == "hatch" else bounds.end.y - maxf(bounds.position.y, lid_bounds.end.y))
		if (item_half.z * 2.0 if mode == "trunk" else item_half.y * 2.0) > span + .001: return false
	return true

static func world_item_local_bounds(vehicle_transform: Transform3D, world_center: Vector3, world_half: Vector3) -> Dictionary:
	if not world_center.is_finite() or not world_half.is_finite() or world_half.x < 0 or world_half.y < 0 or world_half.z < 0: return {}
	var b := vehicle_transform.basis
	if not vehicle_transform.origin.is_finite() or not b.x.is_finite() or not b.y.is_finite() or not b.z.is_finite() or absf(b.determinant()) < .000001: return {}
	var inverse := vehicle_transform.affine_inverse()
	var lo := Vector3(INF,INF,INF); var hi := Vector3(-INF,-INF,-INF)
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var p := inverse * (world_center + world_half * Vector3(x,y,z))
				lo = lo.min(p); hi = hi.max(p)
	return {"center":(lo+hi)*.5,"half":(hi-lo)*.5}

static func _box_valid(box: AABB) -> bool:
	return box.position.is_finite() and box.size.is_finite() and box.size.x > 0 and box.size.y > 0 and box.size.z > 0
