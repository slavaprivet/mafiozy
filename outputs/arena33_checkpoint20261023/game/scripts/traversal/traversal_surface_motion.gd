class_name NativePedestrianSurfaceMotion
extends RefCounted
## Shared player/NPC proposal for kerbs, thresholds, slopes and ledges.
## It samples real Godot support and capsule occupancy but never moves an actor.

const PROVIDER := "GODOT_PEDESTRIAN_SURFACE_V1"
const STEP_HEIGHT_M := .34
const WALK_SLOPE := .95
const SCRAMBLE_SLOPE := 2.35
const SCRAMBLE_STEP_RISE_M := .18
const PROBE_SPACING_M := .055
const BODY_HEIGHT_M := 1.9
const ACTOR_RADIUS_M := .30 # The actual preview CharacterBody capsule.
const SCRAMBLE_SPEED_SCALE := .48
const FLOOR_SKIN_M := .012
const STEP_PHASE_THRESHOLD_M := .04
const DROP_PROBE_M := 20.0

var _space: PhysicsDirectSpaceState3D
var _collision_mask := 1
var _actor_rid := RID()
var _capsule := CapsuleShape3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _base_excludes: Array[RID] = []


func _init() -> void:
	_capsule.radius = ACTOR_RADIUS_M
	_capsule.height = BODY_HEIGHT_M
	_shape_query.shape = _capsule
	_shape_query.collide_with_bodies = true
	_shape_query.collide_with_areas = false
	_shape_query.margin = .001
	_ray.collide_with_bodies = true
	_ray.collide_with_areas = false


func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1, actor_rid: RID = RID()) -> void:
	_space = space
	_collision_mask = collision_mask
	_actor_rid = actor_rid
	_shape_query.collision_mask = collision_mask
	_ray.collision_mask = collision_mask
	_apply_excludes([])


func route(from_feet: Vector3, target_xz: Vector3, options: Dictionary = {}) -> Dictionary:
	var out := _empty_result(from_feet)
	if _space == null or not from_feet.is_finite() or not target_xz.is_finite():
		out.reason = "invalid"
		return out
	if str(options.get("actor_kind", "pedestrian")) != "pedestrian":
		out.reason = "pedestrian_only"
		return out
	var excludes: Array[RID] = _normalized_excludes(options.get("exclude", []))
	_apply_excludes(excludes)
	var delta := Vector3(target_xz.x - from_feet.x, 0.0, target_xz.z - from_feet.z)
	var distance := delta.length()
	var direction := delta.normalized() if distance > .0000001 else Vector3.ZERO
	var support := _support(from_feet, from_feet.y)
	if support.is_empty():
		out.reason = "unsupported"
		return out
	var current_support_y := float(support.position.y)
	var current_base := Vector3(from_feet.x, current_support_y, from_feet.z)
	var current := _find_clear_root(current_base, _clearance_budget(support))
	var execution_current := from_feet
	out.position = current
	if not current.is_finite():
		out.reason = "collision"
		return out
	if distance < .0000001:
		out.position = current
		out.reason = "still"
		return out
	var previous_support: Dictionary = support
	var steps := maxi(1, int(ceil(distance / PROBE_SPACING_M)))
	var points: Array[Vector3] = []
	for index in range(1, steps + 1):
		var t := float(index) / float(steps)
		var x := lerpf(from_feet.x, target_xz.x, t)
		var z := lerpf(from_feet.z, target_xz.z, t)
		var next_support := _support(Vector3(x, current_support_y, z), current_support_y)
		if next_support.is_empty():
			return _ledge(out, execution_current, points, options, NAN)
		var next_y := float(next_support.position.y)
		var next_base := Vector3(x, next_y, z)
		var rise := next_y - current_support_y
		var drop := maxf(0.0, -rise)
		var horizontal := Vector2(x-current.x, z-current.z).length()
		var slope := _surface_slope(next_support, rise / maxf(horizontal, .000001))
		var terrain := _is_terrain(next_support)
		var vehicle := _is_vehicle(next_support.collider)
		if drop > STEP_HEIGHT_M + .000001:
			return _ledge(out, execution_current, points, options, next_y)
		if vehicle and (rise > .05 or slope > .01):
			return _blocked(out, execution_current, points, "vehicle", true)
		var next := _find_clear_root(next_base, _clearance_budget(next_support))
		if not next.is_finite():
			var carrying_clearance := current.y > current_support_y + .02 or rise < -.02
			var leading := _support(Vector3(x, current_support_y, z) + direction * (ACTOR_RADIUS_M + PROBE_SPACING_M), current_support_y, STEP_HEIGHT_M + ACTOR_RADIUS_M)
			if not leading.is_empty():
				var leading_rise := float(leading.position.y) - current_support_y
				if _is_vehicle(leading.collider) and leading_rise > .05:
					return _blocked(out, execution_current, points, "vehicle", true)
				if leading_rise > STEP_HEIGHT_M + .000001:
					return _blocked(out, execution_current, points, "rise", true)
				if not _is_terrain(leading) and leading_rise > .02 and leading_rise <= STEP_HEIGHT_M + .000001:
					next_support = leading
					next_y = float(leading.position.y)
					rise = next_y - current_support_y
					drop = 0.0
					terrain = false
					vehicle = false
					var lift_base := Vector3(current.x, next_y, current.z)
					var lifted_current := _find_clear_root(lift_base, STEP_HEIGHT_M + ACTOR_RADIUS_M)
					next = _find_clear_root(Vector3(x, next_y, z), STEP_HEIGHT_M + ACTOR_RADIUS_M)
					if lifted_current.is_finite() and next.is_finite():
						if lifted_current.distance_to(current) > .000001:
							execution_current = _append_execution_points(points, execution_current, lifted_current, true)
					else:
						return _blocked(out, execution_current, points, "headroom", true)
			if not next.is_finite():
				# A low sill may still be behind the root. Preserve physical clearance
				# until the complete capsule has crossed it, then settle to support.
				next = _find_clear_root(next_base, STEP_HEIGHT_M + ACTOR_RADIUS_M) if carrying_clearance else Vector3(NAN,NAN,NAN)
				if not next.is_finite():
					return _blocked(out, execution_current, points, "collision", true)
		if terrain:
			out.slope = maxf(out.slope, slope)
			if rise > 0.0 and (slope > WALK_SLOPE + .000001):
				if slope > SCRAMBLE_SLOPE + .000001 or rise > SCRAMBLE_STEP_RISE_M + .000001:
					return _blocked(out, execution_current, points, "terrain_face", true)
				out.ascent_mode = "scramble"
				out.speed_scale = SCRAMBLE_SPEED_SCALE
			elif rise < 0.0 and slope > WALK_SLOPE + .000001:
				if slope > SCRAMBLE_SLOPE + .000001:
					return _blocked(out, execution_current, points, "terrain_face", true)
				out.ascent_mode = "scramble"
				out.speed_scale = SCRAMBLE_SPEED_SCALE
		elif rise > .0:
			if vehicle and rise > .05:
				return _blocked(out, execution_current, points, "vehicle", true)
			if rise > STEP_HEIGHT_M + .000001:
				return _blocked(out, execution_current, points, "rise", true)
			out.step_rise_m = maxf(out.step_rise_m, rise)
			out.auto_step = true
		if bool(options.get("swimming", false)) and rise > STEP_HEIGHT_M + .000001:
			return _blocked(out, execution_current, points, "shore", true)
		out.max_rise_m = maxf(out.max_rise_m, next.y - from_feet.y)
		out.descent_step_m = maxf(out.descent_step_m, drop)
		out.foot_lift_m = maxf(out.foot_lift_m, maxf(maxf(0.0, next.y - next_y), maxf(0.0, rise)))
		execution_current = _append_execution_points(points, execution_current, next, not terrain)
		current = next
		current_support_y = next_y
		previous_support = next_support
	out.moved = true
	out.reason = "clear"
	out.position = execution_current
	out.path_points = points
	out.support_kind = _support_kind(previous_support.collider)
	return out


func _support(point: Vector3, reference_y: float, max_up: float = STEP_HEIGHT_M) -> Dictionary:
	_ray.from = Vector3(point.x, reference_y + maxf(STEP_HEIGHT_M, max_up) + .01, point.z)
	_ray.to = Vector3(point.x, reference_y - DROP_PROBE_M, point.z)
	var hit := _space.intersect_ray(_ray)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if normal.y <= .0:
		return {}
	return hit


func _capsule_clear(feet: Vector3) -> bool:
	_shape_query.exclude = _base_excludes
	_shape_query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (BODY_HEIGHT_M * .5 + FLOOR_SKIN_M))
	_shape_query.motion = Vector3.ZERO
	return _space.intersect_shape(_shape_query, 1).is_empty()


func _sweep_fraction(from_feet: Vector3, to_feet: Vector3) -> PackedFloat32Array:
	_shape_query.exclude = _base_excludes
	_shape_query.transform = Transform3D(Basis.IDENTITY, from_feet + Vector3.UP * (BODY_HEIGHT_M * .5 + FLOOR_SKIN_M))
	_shape_query.motion = to_feet - from_feet
	return _space.cast_motion(_shape_query)


func _append_execution_points(points: Array[Vector3], current: Vector3, logical_target: Vector3, split_step: bool) -> Vector3:
	# A real CharacterBody needs a tiny floor skin while following an admitted
	# support. Explicit steps are world-up first and horizontal second; a
	# diagonal capsule sweep otherwise catches the vertical kerb face.
	var target := logical_target + Vector3.UP * FLOOR_SKIN_M
	if split_step and target.y - current.y > STEP_PHASE_THRESHOLD_M:
		var lifted := Vector3(current.x, target.y, current.z)
		if lifted.distance_squared_to(current) > .0000000001:
			points.append(lifted)
		current = lifted
	if target.distance_squared_to(current) > .0000000001:
		points.append(target)
	return target


func _find_clear_root(base: Vector3, max_lift: float) -> Vector3:
	if _capsule_clear(base):
		return base
	var lower := 0.0
	var upper := .04
	while upper <= max_lift + .000001:
		var candidate := base + Vector3.UP * upper
		if _capsule_clear(candidate):
			for iteration in 5:
				var middle := (lower + upper) * .5
				if _capsule_clear(base + Vector3.UP * middle):
					upper = middle
				else:
					lower = middle
			return base + Vector3.UP * (upper + .002)
		lower = upper
		upper += .04
	return Vector3(NAN, NAN, NAN)


func _clearance_budget(support: Dictionary) -> float:
	if _is_terrain(support):
		var normal: Vector3 = support.get("normal", Vector3.UP)
		var slope := Vector2(normal.x, normal.z).length() / maxf(normal.y, .000001)
		return clampf(slope * ACTOR_RADIUS_M + .05, .05, SCRAMBLE_SLOPE * ACTOR_RADIUS_M + .05)
	return ACTOR_RADIUS_M + .05


func _surface_slope(support: Dictionary, grade: float) -> float:
	var normal: Vector3 = support.get("normal", Vector3.UP)
	var normal_slope := Vector2(normal.x, normal.z).length() / maxf(normal.y, .000001)
	return normal_slope if _is_terrain(support) else absf(grade)


func _is_terrain(support: Dictionary) -> bool:
	var collider: Object = support.get("collider")
	if _is_vehicle(collider):
		return false
	var kind := str(collider.get_meta("pedestrian_surface_kind", collider.get_meta("surface_kind", ""))) if collider != null else ""
	if kind in ["terrain", "ground", "road", "sidewalk"]:
		return true
	var normal: Vector3 = support.get("normal", Vector3.UP)
	return normal.y < .999


func _is_vehicle(collider: Object) -> bool:
	if collider == null:
		return false
	if collider.has_meta("vehicle_id") or str(collider.get_meta("traversal_support_kind", "")) == "vehicle":
		return true
	return collider is Node and (collider as Node).is_in_group("native_vehicle_body")


func _support_kind(collider: Object) -> String:
	return "vehicle" if _is_vehicle(collider) else "terrain"


func _blocked(out: Dictionary, current: Vector3, points: Array[Vector3], reason: String, traversal_requested: bool) -> Dictionary:
	out.moved = false
	out.reason = reason
	out.position = current
	out.path_points = points
	out.traversal_requested = traversal_requested
	return out


func _ledge(out: Dictionary, current: Vector3, points: Array[Vector3], options: Dictionary, ground_y: float) -> Dictionary:
	var known := is_finite(ground_y)
	var drop := current.y - ground_y if known else DROP_PROBE_M
	var edge := current
	if str(options.get("ledge_policy", "block")) == "free-fall":
		out.moved = true
		out.reason = "free_fall"
		out.position = edge
		out.path_points = points
		out.vertical_transition = {"kind":"free-fall", "edge":edge, "ground_known":known,
			"ground_y":ground_y if known else NAN, "fall_distance":drop}
		return out
	out.vertical_transition = {"kind":"free-fall", "edge":edge, "ground_known":known,
		"ground_y":ground_y if known else NAN, "fall_distance":drop}
	return _blocked(out, current, points, "ledge_drop", false)


func _normalized_excludes(value: Variant) -> Array[RID]:
	var result: Array[RID] = []
	if _actor_rid.is_valid():
		result.append(_actor_rid)
	if value is Array:
		for item: Variant in value:
			if item is RID and (item as RID).is_valid() and not result.has(item):
				result.append(item)
	return result


func _apply_excludes(excludes: Array[RID]) -> void:
	_base_excludes = excludes.duplicate()
	_shape_query.exclude = excludes
	_ray.exclude = excludes


func _empty_result(from_feet: Vector3) -> Dictionary:
	return {"provider":PROVIDER, "moved":false, "reason":"not_routed", "position":from_feet,
		"path_points":[], "max_rise_m":0.0, "step_rise_m":0.0, "descent_step_m":0.0,
		"auto_step":false, "foot_lift_m":0.0, "slope":0.0, "ascent_mode":"walk",
		"speed_scale":1.0, "traversal_requested":false, "support_kind":"",
		"vertical_transition":{}}
