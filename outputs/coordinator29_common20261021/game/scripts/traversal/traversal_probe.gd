class_name NativeTraversalProbe
extends RefCounted
## Read-only traversal admission against the current Godot physics space.
## The result is a proposal. This class never moves an actor or a support body.

const PROVIDER := "GODOT_TRAVERSAL_PHYSICS_V1"
const STANDING_HEIGHT_M := 1.9
const CARRY_HEIGHT_M := 1.1
const ACTOR_RADIUS_M := .36
const REACH_M := .9
const SHORE_REACH_M := 2.2
const MAX_RISE_M := 1.65
const VEHICLE_MAX_RISE_M := 2.05
const SHORE_MAX_RISE_M := 1.9
const MAX_WIDTH_M := 2.0
const CLEARANCE_M := .14
const PROBE_STEP_M := .06
const SWEEP_STEP_M := .04
const SUPPORT_RADIUS_M := .22
const SUPPORT_SKIN_M := .005
const FLOOR_SKIN_M := .012
const EDGE_RISE_M := .24
const DESTINATION_DROP_M := .45
const SUPPORT_HEIGHT_TOLERANCE_M := .16
const MAX_VEHICLE_SPEED_MPS := .08
const MAX_VEHICLE_YAW_RATE_RADPS := .03
const PARKED_AWAKE_SPEED_MPS := .02
const PARKED_AWAKE_ANGULAR_RADPS := .01
const VEHICLE_STABLE_SECONDS := .3
const MIN_WALKABLE_UP_DOT := .69465837 # cos(46 degrees), matching the player.

var _space: PhysicsDirectSpaceState3D
var _collision_mask := 1
var _actor_rid := RID()
var _standing_shape := CapsuleShape3D.new()
var _carry_shape := CapsuleShape3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()
var _surface_ray := PhysicsRayQueryParameters3D.new()
var _vehicle_stable_since: Dictionary = {}


func _init() -> void:
	_standing_shape.radius = ACTOR_RADIUS_M
	_standing_shape.height = STANDING_HEIGHT_M
	_carry_shape.radius = ACTOR_RADIUS_M
	_carry_shape.height = CARRY_HEIGHT_M
	_shape_query.collide_with_bodies = true
	_shape_query.collide_with_areas = false
	_shape_query.margin = .001
	_surface_ray.collide_with_bodies = true
	_surface_ray.collide_with_areas = false


func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1, actor_rid: RID = RID()) -> void:
	_space = space
	_collision_mask = collision_mask
	_actor_rid = actor_rid
	_shape_query.collision_mask = collision_mask
	_surface_ray.collision_mask = collision_mask
	_apply_excludes([])


func probe(from_feet: Vector3, direction: Vector3, options: Dictionary = {}) -> Dictionary:
	var receipt := _empty_receipt(from_feet)
	if _space == null:
		receipt.reason = "space_unavailable"
		return receipt
	if not _finite_vector(from_feet) or not _finite_vector(direction):
		receipt.reason = "invalid_input"
		return receipt
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() < .000001:
		receipt.reason = "direction_required"
		return receipt
	horizontal = horizontal.normalized()
	var swimming := bool(options.get("swimming", false))
	var reach := SHORE_REACH_M if swimming else REACH_M
	var max_rise := SHORE_MAX_RISE_M if swimming else VEHICLE_MAX_RISE_M
	var excludes: Array[RID] = _normalized_excludes(options.get("exclude", []))
	_apply_excludes(excludes)
	receipt.start_clear = _capsule_clear(from_feet, STANDING_HEIGHT_M)
	if not receipt.start_clear:
		receipt.reason = "start_occupied"
		return receipt
	var start_surface := _surface_at(from_feet, from_feet.y, max_rise)
	if start_surface.is_empty() and not swimming:
		receipt.reason = "start_unsupported"
		return receipt
	var baseline_y := from_feet.y
	var first_obstacle_distance := -1.0
	var obstacle_last_distance := -1.0
	var highest_y := baseline_y
	var first_support: Dictionary = {}
	var top_candidate: Dictionary = {}
	var scan_limit := reach + MAX_WIDTH_M + .5
	var sample_count := int(ceil(scan_limit / PROBE_STEP_M))
	for index in range(1, sample_count + 1):
		var distance := minf(float(index) * PROBE_STEP_M, scan_limit)
		var at := from_feet + horizontal * distance
		var surface := _surface_at(at, baseline_y, max_rise)
		if surface.is_empty():
			continue
		var surface_y := float(surface.position.y)
		var rise := surface_y - baseline_y
		highest_y = maxf(highest_y, surface_y)
		var dry := _water_depth(at, options) <= 0.0
		var standing_blocked := not _capsule_clear(Vector3(at.x, baseline_y, at.z), STANDING_HEIGHT_M)
		var obstacle := (dry and rise >= -.4) if swimming else (rise > EDGE_RISE_M or standing_blocked)
		if first_obstacle_distance < 0.0:
			if not obstacle:
				continue
			if distance > reach + PROBE_STEP_M:
				receipt.reason = "obstacle_out_of_reach"
				return receipt
			first_obstacle_distance = distance
			first_support = surface
			obstacle_last_distance = distance
			var support_limit := _support_rise_limit(surface, swimming)
			if rise > support_limit:
				receipt.reason = "obstacle_too_high"
				return receipt
			continue
		obstacle_last_distance = distance if obstacle else obstacle_last_distance
		if obstacle and rise > EDGE_RISE_M and (first_support.is_empty() or surface_y > float(first_support.get("position", Vector3(0, -INF, 0)).y)):
			first_support = surface
		if obstacle and rise > _support_rise_limit(surface, swimming):
			receipt.reason = "obstacle_too_high"
			return receipt
		if distance - first_obstacle_distance > MAX_WIDTH_M + .45:
			receipt.reason = "obstacle_too_wide"
			return receipt
		if not dry:
			continue
		var candidate_feet := Vector3(at.x, surface_y, at.z)
		if rise < -DESTINATION_DROP_M or not _capsule_clear(candidate_feet, STANDING_HEIGHT_M):
			continue
		var support := _support_at(candidate_feet, options)
		if not bool(support.get("clear", false)):
			continue
		var support_kind := str(support.get("kind", "static"))
		var candidate_limit := SHORE_MAX_RISE_M if swimming else (VEHICLE_MAX_RISE_M if support_kind == "vehicle" else MAX_RISE_M)
		if rise > candidate_limit:
			continue
		var candidate := {"feet": candidate_feet, "surface": surface, "support": support, "distance": distance, "rise": rise}
		if rise > EDGE_RISE_M:
			if support_kind == "vehicle" and rise <= 1.1:
				continue # Source behavior: low bonnet is crossed, not used as a perch.
			if top_candidate.is_empty():
				top_candidate = candidate
			if support_kind == "vehicle" and rise > 1.1:
				return _admit(receipt, from_feet, horizontal, candidate, first_support, highest_y, first_obstacle_distance, obstacle_last_distance, "mantle", options)
			continue
		var kind := "shore" if swimming else "vault"
		return _admit(receipt, from_feet, horizontal, candidate, first_support, highest_y, first_obstacle_distance, obstacle_last_distance, kind, options)
	if not top_candidate.is_empty():
		return _admit(receipt, from_feet, horizontal, top_candidate, first_support, highest_y, first_obstacle_distance, obstacle_last_distance, "shore" if swimming else "mantle", options)
	receipt.reason = "no_supported_destination" if first_obstacle_distance >= 0.0 else "no_traversal_edge"
	return receipt


func _admit(receipt: Dictionary, from_feet: Vector3, direction: Vector3, candidate: Dictionary,
		first_support: Dictionary, highest_y: float, first_distance: float, last_distance: float,
		kind: String, options: Dictionary) -> Dictionary:
	var destination: Vector3 = candidate.feet
	var support: Dictionary = candidate.support
	var clearance_y := maxf(highest_y, maxf(from_feet.y, destination.y)) + CLEARANCE_M
	receipt.kind = kind
	receipt.destination_feet = destination
	receipt.rise_m = destination.y - from_feet.y
	receipt.obstacle_width_m = maxf(PROBE_STEP_M, last_distance - first_distance)
	receipt.clearance_y_m = clearance_y
	receipt.duration_s = clampf(.76 + maxf(0.0, receipt.rise_m) * .15 + from_feet.distance_to(destination) * .07, .85, 1.25)
	receipt.destination_clear = true
	receipt.support_clear = true
	receipt.support_kind = support.kind
	receipt.support_id = support.id
	receipt.support_rid = support.rid
	receipt.support_transform = support.transform
	receipt.destination_support_local = support.local_anchor
	receipt.support_instance_id = support.instance_id
	receipt.support_revision = support.revision
	receipt.edge_position = first_support.get("position", from_feet + direction * first_distance)
	receipt.path_clear = _trajectory_clear(from_feet, destination, clearance_y)
	if not receipt.path_clear:
		receipt.reason = "trajectory_blocked"
		return receipt
	receipt.admitted = true
	receipt.reason = "admitted"
	return receipt


func validate_support(receipt: Dictionary, options: Dictionary = {}) -> Dictionary:
	var instance_id := int(receipt.get("support_instance_id", 0))
	if instance_id <= 0:
		return {"valid": false, "reason": "support_identity_missing"}
	var collider: Object = instance_from_id(instance_id)
	if collider == null or not is_instance_valid(collider):
		return {"valid": false, "reason": "support_disappeared"}
	var expected_id := str(receipt.get("support_id", ""))
	if expected_id.is_empty() or _support_id(collider, RID()) != expected_id:
		return {"valid": false, "reason": "support_identity_changed"}
	var expected_revision := int(receipt.get("support_revision", 0))
	if _support_revision(collider) != expected_revision:
		return {"valid": false, "reason": "support_revision_changed"}
	if _support_kind(collider) == "vehicle" and not _vehicle_is_stable(collider, options):
		return {"valid": false, "reason": "vehicle_support_unstable"}
	if collider is Node3D:
		var current := (collider as Node3D).global_transform
		var admitted: Transform3D = receipt.get("support_transform", Transform3D.IDENTITY)
		if current.origin.distance_to(admitted.origin) > .03 or current.basis.get_rotation_quaternion().angle_to(admitted.basis.get_rotation_quaternion()) > .02:
			return {"valid": false, "reason": "support_transform_changed", "transform": current}
		return {"valid": true, "reason": "stable", "transform": current}
	return {"valid": true, "reason": "stable", "transform": Transform3D.IDENTITY}


func inspect_sweep_samples(samples: Array, options: Dictionary = {}) -> Dictionary:
	var excludes: Array[RID] = _normalized_excludes(options.get("exclude", []))
	_apply_excludes(excludes)
	for index in samples.size():
		var sample: Variant = samples[index]
		if not sample is Dictionary:
			return {"accepted_samples": index, "clear": false, "reason": "invalid_sweep_sample"}
		var feet: Variant = sample.get("root_position")
		var height := float(sample.get("collision_height_m", NAN))
		if not feet is Vector3 or not (feet as Vector3).is_finite() or not is_finite(height) or height < ACTOR_RADIUS_M * 2.0:
			return {"accepted_samples": index, "clear": false, "reason": "invalid_sweep_sample"}
		if not _capsule_clear(feet, height):
			return {"accepted_samples": index, "clear": false, "reason": "dynamic_blocked"}
	return {"accepted_samples": samples.size(), "clear": true, "reason": "clear"}


func _trajectory_clear(from_feet: Vector3, destination: Vector3, clearance_y: float) -> bool:
	var lift := Vector3(from_feet.x, clearance_y, from_feet.z)
	var carry := Vector3(destination.x, clearance_y, destination.z)
	for segment: Array in [[from_feet, lift], [lift, carry], [carry, destination]]:
		var segment_from: Vector3 = segment[0]
		var segment_to: Vector3 = segment[1]
		var distance := segment_from.distance_to(segment_to)
		var steps := maxi(1, int(ceil(distance / SWEEP_STEP_M)))
		for i in range(steps + 1):
			var feet := segment_from.lerp(segment_to, float(i) / float(steps))
			if not _capsule_clear(feet, CARRY_HEIGHT_M):
				return false
	return true


func _surface_at(at: Vector3, baseline_y: float, max_rise: float) -> Dictionary:
	_surface_ray.from = Vector3(at.x, baseline_y + max_rise + .5, at.z)
	_surface_ray.to = Vector3(at.x, baseline_y - DESTINATION_DROP_M - .12, at.z)
	var hit := _space.intersect_ray(_surface_ray)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if normal.y < MIN_WALKABLE_UP_DOT:
		return {}
	return hit


func _support_at(feet: Vector3, options: Dictionary) -> Dictionary:
	var selected_collider: Object
	var selected_rid := RID()
	var selected_position := feet
	var footprint := SUPPORT_RADIUS_M + SUPPORT_SKIN_M
	for offset: Vector3 in [Vector3.ZERO, Vector3(footprint, 0, 0), Vector3(-footprint, 0, 0), Vector3(0, 0, footprint), Vector3(0, 0, -footprint)]:
		_surface_ray.from = feet + offset + Vector3.UP * .34
		_surface_ray.to = feet + offset + Vector3.DOWN * .36
		var hit := _space.intersect_ray(_surface_ray)
		if hit.is_empty():
			return {"clear": false}
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var position: Vector3 = hit.get("position", feet)
		if normal.y < MIN_WALKABLE_UP_DOT or absf(position.y - feet.y) > SUPPORT_HEIGHT_TOLERANCE_M:
			return {"clear": false}
		var collider: Object = hit.get("collider")
		if collider != null and (str(collider.get_meta("surface_kind", "")) == "water" or bool(collider.get_meta("traversal_blocked", false))):
			return {"clear": false}
		if selected_collider == null:
			selected_collider = collider
			selected_rid = hit.get("rid", RID())
			selected_position = position
		elif collider != selected_collider:
			# Source support requires five compatible dry heights, not one static
			# object identity. Keep strict identity for moving supports only.
			if not (selected_collider is StaticBody3D and collider is StaticBody3D):
				return {"clear": false}
	if selected_collider == null:
		return {"clear": false}
	var kind := _support_kind(selected_collider)
	if kind == "vehicle" and not _vehicle_is_stable(selected_collider, options):
		return {"clear": false}
	var support_id := _support_id(selected_collider, selected_rid)
	var transform := Transform3D.IDENTITY
	var local_anchor := selected_position
	if selected_collider is Node3D:
		var node := selected_collider as Node3D
		transform = node.global_transform
		local_anchor = node.to_local(feet)
	return {"clear": true, "kind": kind, "id": support_id, "rid": selected_rid,
		"transform": transform, "local_anchor": local_anchor, "collider": selected_collider,
		"instance_id": selected_collider.get_instance_id(), "revision": _support_revision(selected_collider)}


func _support_kind(collider: Object) -> String:
	if collider == null:
		return "static"
	if str(collider.get_meta("traversal_support_kind", "")) == "vehicle":
		return "vehicle"
	if collider is Node and (collider as Node).is_in_group("native_vehicle_body"):
		return "vehicle"
	if collider.has_meta("vehicle_id"):
		return "vehicle"
	return "static"


func _support_id(collider: Object, rid: RID) -> String:
	if collider != null:
		for key: String in ["traversal_support_id", "vehicle_id", "surface_id"]:
			var value := str(collider.get_meta(key, ""))
			if not value.is_empty():
				return value
		if collider is Node:
			return "%s:%d" % [(collider as Node).name, collider.get_instance_id()]
	return "rid:%s" % str(rid.get_id())


func _support_revision(collider: Object) -> int:
	if collider == null:
		return 0
	for key: String in ["traversal_support_revision", "geometry_version", "source_clock"]:
		if collider.has_meta(key):
			return int(collider.get_meta(key))
	return 0


func _vehicle_is_stable(collider: Object, options: Dictionary) -> bool:
	if collider == null or bool(collider.get_meta("traversal_vehicle_blocked", false)):
		return false
	var body := collider as RigidBody3D
	if body == null:
		return true # Authored static vehicle shell.
	var linear_speed := body.linear_velocity.length()
	var angular_speed := body.angular_velocity.length()
	if linear_speed > MAX_VEHICLE_SPEED_MPS:
		_vehicle_stable_since.erase(body.get_instance_id())
		return false
	if absf(body.angular_velocity.y) > MAX_VEHICLE_YAW_RATE_RADPS or angular_speed > MAX_VEHICLE_YAW_RATE_RADPS * 1.5:
		_vehicle_stable_since.erase(body.get_instance_id())
		return false
	if body.has_method("is_upright"):
		if not bool(body.call("is_upright", .78)):
			_vehicle_stable_since.erase(body.get_instance_id())
			return false
	elif body.global_basis.y.normalized().dot(Vector3.UP) < .78:
		_vehicle_stable_since.erase(body.get_instance_id())
		return false
	# NativeVehicleBody receives an authoritative zero-control packet every
	# physics tick, which intentionally keeps it awake. Treat an all-wheel-
	# grounded body with only solver jitter as parked; retain stricter sleeping
	# semantics for generic rigid bodies and reject even slow deliberate drift.
	if not body.freeze and not body.sleeping:
		var fully_grounded := false
		if body.has_method("snapshot_state"):
			var state: Variant = body.call("snapshot_state")
			fully_grounded = state is Dictionary and int((state as Dictionary).get("grounded_wheel_mask", 0)) == 0b1111
		if not fully_grounded or linear_speed > PARKED_AWAKE_SPEED_MPS or angular_speed > PARKED_AWAKE_ANGULAR_RADPS:
			_vehicle_stable_since.erase(body.get_instance_id())
			return false
		_vehicle_stable_since[body.get_instance_id()] = float(options.get("now_s", Time.get_ticks_msec() * .001)) - VEHICLE_STABLE_SECONDS
		return true
	var now_s := float(options.get("now_s", Time.get_ticks_msec() * .001))
	if collider.has_meta("traversal_stable_since_s"):
		return now_s - float(collider.get_meta("traversal_stable_since_s")) >= VEHICLE_STABLE_SECONDS
	var id := body.get_instance_id()
	if body.freeze or body.sleeping:
		_vehicle_stable_since[id] = now_s - VEHICLE_STABLE_SECONDS
	if not _vehicle_stable_since.has(id):
		_vehicle_stable_since[id] = now_s
	return now_s - float(_vehicle_stable_since[id]) >= VEHICLE_STABLE_SECONDS


func _support_rise_limit(surface: Dictionary, swimming: bool) -> float:
	if swimming:
		return SHORE_MAX_RISE_M
	return VEHICLE_MAX_RISE_M if _support_kind(surface.get("collider")) == "vehicle" else MAX_RISE_M


func _capsule_clear(feet: Vector3, height: float) -> bool:
	if is_equal_approx(height, STANDING_HEIGHT_M):
		_shape_query.shape = _standing_shape
	else:
		_carry_shape.height = maxf(height, ACTOR_RADIUS_M * 2.0)
		_shape_query.shape = _carry_shape
	_shape_query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * .5 + FLOOR_SKIN_M))
	_shape_query.motion = Vector3.ZERO
	return _space.intersect_shape(_shape_query, 1).is_empty()


func _water_depth(at: Vector3, options: Dictionary) -> float:
	var provider: Variant = options.get("water_depth_at")
	if provider is Callable and (provider as Callable).is_valid():
		var value: Variant = (provider as Callable).call(at)
		if value is float or value is int:
			return float(value)
	return 0.0


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
	_shape_query.exclude = excludes
	_surface_ray.exclude = excludes


func _empty_receipt(from_feet: Vector3) -> Dictionary:
	return {"provider": PROVIDER, "admitted": false, "reason": "not_probed", "kind": "",
		"from_feet": from_feet, "destination_feet": from_feet, "edge_position": from_feet,
		"rise_m": 0.0, "obstacle_width_m": 0.0, "clearance_y_m": from_feet.y,
		"duration_s": 0.0, "start_clear": false, "path_clear": false,
		"destination_clear": false, "support_clear": false, "support_kind": "",
		"support_id": "", "support_rid": RID(), "support_transform": Transform3D.IDENTITY,
		"destination_support_local": Vector3.ZERO, "support_instance_id": 0, "support_revision": 0}


static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
