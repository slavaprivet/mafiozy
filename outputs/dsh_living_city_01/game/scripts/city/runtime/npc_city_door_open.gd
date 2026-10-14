extends RefCounted
## DSH_DOORFREE / DSH_SITEPHYS: opt-in "the door is open, the entrance has no
## barrier" mode for the living city.
##
## Every consumer keeps its current behaviour unless the matching flag is passed:
##   --city-door-free-entry=1  (default 0) free entry: an open leaf stops being a
##                             barrier and the quarter-metre occupancy square is
##                             replaced by a real capsule sweep.
##   --city-site-door-physics=1 (default 0) hospital/bank door leaves are advanced
##                             with the current occupants instead of waiting for a
##                             sparse daily poll.
##
## This file only provides the flag parsing, the leaf parking primitive and the
## capsule query used by the two in-zone callers. It creates no node, writes no
## scene state by itself and is safe to preload from any script.

const DOOR_FREE_FLAG := "--city-door-free-entry="
const SITE_PHYSICS_FLAG := "--city-site-door-physics="
## Source corridor half width from ENTRY_GEOMETRY.json floorParameters.
const SOURCE_HALF_WIDTH_M := 0.8099999761581421
## Runtime widening requested for free entry (no re-export of ENTRY_GEOMETRY).
const FREE_HALF_WIDTH_M := 0.95
## Leaf angle above which the leaf counts as fully open.
const OPEN_EPSILON := 0.0001

static var _free_entry := -1
static var _site_physics := -1
static var _leaf_parks := 0
static var _leaf_unparks := 0

static func _flag(prefix: String) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return maxi(0, mini(1, int(argument.trim_prefix(prefix))))
	return 0

static func free_entry() -> bool:
	if _free_entry < 0:
		_free_entry = _flag(DOOR_FREE_FLAG)
	return _free_entry == 1

static func site_door_physics() -> bool:
	if _site_physics < 0:
		_site_physics = _flag(SITE_PHYSICS_FLAG)
	return _site_physics == 1

## Half width a consumer should use for the entry corridor. With free entry the
## source 0.81 m neck is widened at runtime; the source .738 m footprint itself is
## deliberately left alone (land/wall/occupant proofs keep using it).
static func half_width_m() -> float:
	return FREE_HALF_WIDTH_M if free_entry() else SOURCE_HALF_WIDTH_M

## Same smoothstep leaf pose the source door adapters use, so a park decision and
## the visible leaf can never disagree.
static func leaf_pose(base: Transform3D, angle: float, fraction: float) -> Transform3D:
	var eased: float = fraction * fraction * (3.0 - 2.0 * fraction)
	return base * Transform3D(Basis(Vector3.UP, angle * eased), Vector3.ZERO)

## Disable/enable every CollisionShape3D below one source door leaf body.
## Returns the number of shapes whose disabled flag actually changed.
static func park_leaf(body: Node, parked: bool) -> int:
	if not is_instance_valid(body):
		return 0
	var changed := 0
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child as CollisionShape3D
			var want: bool = parked
			if shape.disabled != want:
				shape.disabled = want
				changed += 1
	if parked:
		_leaf_parks += 1
	else:
		_leaf_unparks += 1
	return changed

## Real capsule sweep, used where the source quarter-metre square is too coarse a
## proxy for "an actor is standing in the doorway".
## Main thread only and not reentrant: the shape/query pair is cached between
## calls, so the opt-in free-entry path adds no per-call allocation.
static var _capsule: CapsuleShape3D
static var _capsule_key := ""
static var _capsule_query: PhysicsShapeQueryParameters3D

static func _capsule_for(radius: float, height: float) -> CapsuleShape3D:
	var key := str(radius) + ":" + str(height)
	if _capsule == null or _capsule_key != key:
		_capsule = CapsuleShape3D.new()
		_capsule.radius = radius
		_capsule.height = maxf(height, radius * 2.0 + 0.001)
		_capsule_key = key
	return _capsule

static func capsule_query(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float, height: float, mask: int, exclude: Array) -> Dictionary:
	if space == null or not from.is_finite() or not to.is_finite():
		return {"ok": false, "reason": "capsule_input"}
	if not is_finite(radius) or not is_finite(height) or radius <= 0.0 or height <= 0.0:
		return {"ok": false, "reason": "capsule_input"}
	var capsule := _capsule_for(radius, height)
	if _capsule_query == null:
		_capsule_query = PhysicsShapeQueryParameters3D.new()
	var query := _capsule_query
	query.shape = capsule
	query.collision_mask = mask
	query.margin = 0.001
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (capsule.height * 0.5))
	query.motion = Vector3.ZERO
	if not space.intersect_shape(query, 1).is_empty():
		return {"ok": false, "reason": "capsule_overlap"}
	query.motion = to - from
	var cast: PackedFloat32Array = space.cast_motion(query)
	if cast.size() != 2 or cast[0] < 0.99999:
		return {"ok": false, "reason": "capsule_sweep"}
	return {"ok": true, "reason": ""}

static func capsule_sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float, height: float, mask: int, exclude: Array) -> bool:
	return bool(capsule_query(space, from, to, radius, height, mask, exclude).get("ok", false))

static func stats() -> Dictionary:
	return {
		"free_entry": free_entry(),
		"site_door_physics": site_door_physics(),
		"half_width_m": half_width_m(),
		"leaf_parks": _leaf_parks,
		"leaf_unparks": _leaf_unparks,
	}
