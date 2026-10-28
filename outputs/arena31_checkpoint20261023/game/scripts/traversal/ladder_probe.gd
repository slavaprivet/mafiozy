class_name NativeLadderProbe
extends RefCounted
## Real-physics admission and ordered capsule sweep inspection. It never moves a body.

const BODY_HEIGHT_M := 1.9
const BODY_RADIUS_M := .33
const FLOOR_SKIN_M := .012
const SWEEP_STEP_M := .04
const LOWER_REACH_M := 1.35
const UPPER_REACH_M := .95
const UPPER_APPROACH_DROP_M := 1.15
const SUPPORT_RADIUS_M := .22
const SUPPORT_HEIGHT_TOLERANCE_M := .08
const MIN_WALKABLE_UP_DOT := .69465837

var _space: PhysicsDirectSpaceState3D
var _collision_mask := 1
var _actor_rid := RID()
var _capsule := CapsuleShape3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()
var _support_ray := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	_capsule.radius = BODY_RADIUS_M
	_capsule.height = BODY_HEIGHT_M
	_shape_query.shape = _capsule
	_shape_query.collide_with_bodies = true
	_shape_query.collide_with_areas = false
	_shape_query.margin = .001
	_support_ray.collide_with_bodies = true
	_support_ray.collide_with_areas = false


func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1, actor_rid: RID = RID()) -> void:
	_space = space
	_collision_mask = collision_mask
	_actor_rid = actor_rid
	_shape_query.collision_mask = collision_mask
	_support_ray.collision_mask = collision_mask


func nearest_prompt(feet: Vector3, descriptors: Array) -> Variant:
	if _space == null or not feet.is_finite():
		return null
	var best: Dictionary = {}
	for item: Variant in descriptors:
		if not item is Dictionary or not bool(item.get("valid", false)):
			continue
		var descriptor: Dictionary = item
		for end: String in ["lower", "upper"]:
			var endpoint: Vector3 = descriptor[end]
			var distance := feet.distance_to(endpoint)
			var admitted := distance <= LOWER_REACH_M if end == "lower" else feet.y >= endpoint.y - UPPER_APPROACH_DROP_M and distance <= UPPER_REACH_M
			if admitted and (best.is_empty() or distance < float(best.distance)):
				best = {"provider":"GODOT_LADDER_PROBE_V1", "descriptor":descriptor, "ladder_id":descriptor.id,
					"end":end, "distance":distance, "input_action":&"interact",
					"text":"E — подняться на крышу" if end == "lower" else "E — спуститься по лестнице"}
	return null if best.is_empty() else best


func validate_candidate(feet: Vector3, candidate: Dictionary) -> Dictionary:
	if not feet.is_finite() or not candidate.has("descriptor") or not candidate.descriptor is Dictionary:
		return {"valid":false, "reason":"invalid_candidate"}
	var descriptor: Dictionary = candidate.descriptor
	var end := str(candidate.get("end", ""))
	if end not in ["lower", "upper"] or not bool(descriptor.get("valid", false)):
		return {"valid":false, "reason":"invalid_candidate"}
	var endpoint: Vector3 = descriptor[end]
	var distance := feet.distance_to(endpoint)
	if end == "lower" and distance > LOWER_REACH_M:
		return {"valid":false, "reason":"candidate_out_of_reach"}
	if end == "upper" and (feet.y < endpoint.y - UPPER_APPROACH_DROP_M or distance > UPPER_REACH_M):
		return {"valid":false, "reason":"candidate_out_of_reach"}
	return {"valid":true, "reason":"valid", "distance":distance}


func inspect_route(points: Array, descriptor: Dictionary, landing_end: String, options: Dictionary = {}) -> Dictionary:
	if _space == null or points.size() < 2:
		return {"clear":false, "reason":"invalid_route", "accepted_samples":0}
	var accepted := 0
	for index in range(1, points.size()):
		var a: Variant = points[index - 1]
		var b: Variant = points[index]
		if not a is Vector3 or not b is Vector3 or not (a as Vector3).is_finite() or not (b as Vector3).is_finite():
			return {"clear":false, "reason":"invalid_route_point", "accepted_samples":accepted}
		var distance := (a as Vector3).distance_to(b)
		var count := maxi(1, int(ceil(distance / SWEEP_STEP_M)))
		for step in range(count + 1):
			var feet: Vector3 = (a as Vector3).lerp(b, float(step) / float(count))
			if not _capsule_clear(feet, descriptor, options):
				return {"clear":false, "reason":"route_blocked", "accepted_samples":accepted, "blocked_position":feet}
			accepted += 1
	var landing: Vector3 = points[points.size() - 1]
	if not _landing_supported(landing, options):
		return {"clear":false, "reason":"landing_unsupported", "accepted_samples":accepted, "landing_end":landing_end}
	return {"clear":true, "reason":"clear", "accepted_samples":accepted, "landing_end":landing_end}


func inspect_sweep_samples(samples: Array, descriptor: Dictionary, options: Dictionary = {}) -> Dictionary:
	if _space == null:
		return {"clear":false, "reason":"space_unavailable", "accepted_samples":0}
	for index in samples.size():
		var sample: Variant = samples[index]
		if not sample is Dictionary or not sample.get("root_position") is Vector3:
			return {"clear":false, "reason":"invalid_sweep_sample", "accepted_samples":index}
		if not _capsule_clear(sample.root_position, descriptor, options):
			return {"clear":false, "reason":"dynamic_blocked", "accepted_samples":index}
	return {"clear":true, "reason":"clear", "accepted_samples":samples.size()}


func landing_supported(feet: Vector3, options: Dictionary = {}) -> bool:
	return _landing_supported(feet, options)


func _capsule_clear(feet: Vector3, descriptor: Dictionary, options: Dictionary) -> bool:
	var excludes := _excludes(options.get("exclude", []))
	for rid: RID in descriptor.get("route_exclude_rids", []):
		if rid.is_valid() and not excludes.has(rid):
			excludes.append(rid)
	_shape_query.exclude = excludes
	_shape_query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (BODY_HEIGHT_M * .5 + FLOOR_SKIN_M))
	_shape_query.motion = Vector3.ZERO
	return _space.intersect_shape(_shape_query, 1).is_empty()


func _landing_supported(feet: Vector3, options: Dictionary) -> bool:
	if not feet.is_finite():
		return false
	_support_ray.exclude = _excludes(options.get("exclude", []))
	for offset: Vector3 in [Vector3.ZERO, Vector3(SUPPORT_RADIUS_M,0,0), Vector3(-SUPPORT_RADIUS_M,0,0), Vector3(0,0,SUPPORT_RADIUS_M), Vector3(0,0,-SUPPORT_RADIUS_M)]:
		_support_ray.from = feet + offset + Vector3.UP * .24
		_support_ray.to = feet + offset + Vector3.DOWN * .28
		var hit := _space.intersect_ray(_support_ray)
		if hit.is_empty():
			return false
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var position: Vector3 = hit.get("position", feet)
		if normal.y < MIN_WALKABLE_UP_DOT or absf(position.y - feet.y) > SUPPORT_HEIGHT_TOLERANCE_M:
			return false
	return true


func _excludes(value: Variant) -> Array[RID]:
	var result: Array[RID] = []
	if _actor_rid.is_valid():
		result.append(_actor_rid)
	if value is Array:
		for item: Variant in value:
			if item is RID and (item as RID).is_valid() and not result.has(item):
				result.append(item)
	return result
