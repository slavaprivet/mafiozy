extends RefCounted

const PROVIDER := "GODOT_PHYSICS_SPACE_V1"
const FLOOR_SKIN := .01
const EXIT_SEAT_FLOOR_CORRECTION_MAX := .05

var _space: PhysicsDirectSpaceState3D
var _collision_mask := 1
var _capsule: CapsuleShape3D
var _shape_query: PhysicsShapeQueryParameters3D
var _capsule_radius := -1.0
var _capsule_height := -1.0

func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1) -> void:
	_space = space
	_collision_mask = collision_mask

func probe_access(actor_ref: Dictionary, vehicle_ref: Dictionary, door_id: String, action: String, source_clock: int, from_feet: Vector3, to_feet: Vector3, exclude: Array[RID] = [], radius: float = .36, height: float = 1.9) -> Dictionary:
	var query_from := _normalized_exit_start(from_feet, exclude) if action == "EXIT" else from_feet
	var receipt := {
		"provider": PROVIDER, "action": action, "source_clock": source_clock,
		"actor_id": actor_ref.get("actor_id", ""), "actor_generation": actor_ref.get("life_generation", 0),
		"vehicle_id": vehicle_ref.get("vehicle_id", ""), "vehicle_generation": vehicle_ref.get("life_generation", 0),
		"door_id": door_id, "from_m": _dict(from_feet), "physics_from_m": _dict(query_from), "to_m": _dict(to_feet),
		"start_floor_correction_m": query_from.y - from_feet.y,
		"reachable": false, "start_clear": false, "path_clear": false, "destination_clear": false, "support_clear": false,
		"distance_to_target_m": from_feet.distance_to(to_feet), "arrival_ready": from_feet.distance_to(to_feet) <= .25,
	}
	if _space == null or source_clock < 1 or action not in ["BOARD", "EXIT"] or not is_finite(radius) or not is_finite(height) or radius <= 0 or height < radius * 2:
		return receipt
	if _capsule == null or radius != _capsule_radius or height != _capsule_height:
		var fresh := CapsuleShape3D.new()
		if radius > fresh.radius:
			fresh.height = height; fresh.radius = radius
		else:
			fresh.radius = radius; fresh.height = height
		_capsule = fresh
		_capsule_radius = radius; _capsule_height = height
	if _shape_query == null: _shape_query = PhysicsShapeQueryParameters3D.new()
	var query := _shape_query
	query.shape = _capsule; query.collision_mask = _collision_mask; query.exclude = exclude
	query.collide_with_bodies = true; query.collide_with_areas = true
	query.transform = Transform3D(Basis.IDENTITY, query_from + Vector3.UP * (height * .5 + FLOOR_SKIN))
	query.motion = Vector3.ZERO
	var start_clear := _space.intersect_shape(query, 1).is_empty()
	query.motion = to_feet - query_from
	var cast := _space.cast_motion(query)
	var path_clear := cast.size() >= 2 and float(cast[0]) >= .99999
	query.transform.origin = to_feet + Vector3.UP * (height * .5 + FLOOR_SKIN); query.motion = Vector3.ZERO
	var destination_clear := _space.intersect_shape(query, 1).is_empty()
	var support_clear := _support_clear(to_feet, radius, exclude)
	receipt.start_clear = start_clear; receipt.path_clear = path_clear; receipt.destination_clear = destination_clear; receipt.support_clear = support_clear
	receipt.reachable = start_clear and path_clear and destination_clear and support_clear
	if cast.size() >= 2:
		receipt["safe_fraction"] = float(cast[0]); receipt["unsafe_fraction"] = float(cast[1])
	return receipt

func _normalized_exit_start(feet: Vector3, exclude: Array[RID]) -> Vector3:
	if _space == null: return feet
	# A visually seated root follows the authored anchor exactly and may sit a
	# few centimetres below a nearby support plane while the vehicle pitches.
	# Normalize only that bounded
	# seat/floor seam for the admission query. Walls, destinations and the full
	# sweep are still tested with the unchanged collision volume.
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .05, feet + Vector3.DOWN * EXIT_SEAT_FLOOR_CORRECTION_MAX, _collision_mask, exclude)
	query.collide_with_areas = false; query.collide_with_bodies = true
	var hit := _space.intersect_ray(query)
	if hit.is_empty() or float((hit.normal as Vector3).y) < cos(deg_to_rad(45.0)): return feet
	var collider: Object = hit.get("collider")
	if collider != null and (collider.get_meta("surface_kind", "") == "water" or bool(collider.get_meta("transport_exit_blocked", false))): return feet
	var support_y := float((hit.position as Vector3).y); var correction := support_y - feet.y
	if correction < 0.0 or correction > EXIT_SEAT_FLOOR_CORRECTION_MAX: return feet
	return Vector3(feet.x, support_y, feet.z)

func _support_clear(feet: Vector3, radius: float, exclude: Array[RID]) -> bool:
	for offset in [Vector3.ZERO, Vector3(radius * .7, 0, 0), Vector3(-radius * .7, 0, 0), Vector3(0, 0, radius * .7), Vector3(0, 0, -radius * .7)]:
		var query := PhysicsRayQueryParameters3D.create(feet + offset + Vector3.UP * .34, feet + offset + Vector3.DOWN * .36, _collision_mask, exclude)
		# Areas may be access blockers, but they cannot physically support a
		# CharacterBody3D.  Counting a sensor as floor would approve a fall.
		query.collide_with_areas = false; query.collide_with_bodies = true
		var hit := _space.intersect_ray(query)
		if hit.is_empty() or float((hit.normal as Vector3).y) < cos(deg_to_rad(45.0)): return false
		var collider: Object = hit.get("collider")
		if collider != null and (collider.get_meta("surface_kind", "") == "water" or bool(collider.get_meta("transport_exit_blocked", false))): return false
		if absf(float((hit.position as Vector3).y) - feet.y) > .34: return false
	return true

func _dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
