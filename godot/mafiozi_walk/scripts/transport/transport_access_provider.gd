extends RefCounted

const PROVIDER := "GODOT_PHYSICS_SPACE_V1"

var _space: PhysicsDirectSpaceState3D
var _collision_mask := 1

func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1) -> void:
	_space = space
	_collision_mask = collision_mask

func probe_access(actor_ref: Dictionary, vehicle_ref: Dictionary, door_id: String, action: String, source_clock: int, from_feet: Vector3, to_feet: Vector3, exclude: Array[RID] = [], radius: float = .36, height: float = 1.9) -> Dictionary:
	var receipt := {
		"provider": PROVIDER, "action": action, "source_clock": source_clock,
		"actor_id": actor_ref.get("actor_id", ""), "actor_generation": actor_ref.get("life_generation", 0),
		"vehicle_id": vehicle_ref.get("vehicle_id", ""), "vehicle_generation": vehicle_ref.get("life_generation", 0),
		"door_id": door_id, "from_m": _dict(from_feet), "to_m": _dict(to_feet),
		"reachable": false, "path_clear": false, "destination_clear": false,
	}
	if _space == null or source_clock < 1 or action not in ["BOARD", "EXIT"] or radius <= 0 or height < radius * 2:
		return receipt
	var capsule := CapsuleShape3D.new(); capsule.radius = radius; capsule.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule; query.collision_mask = _collision_mask; query.exclude = exclude
	query.collide_with_bodies = true; query.collide_with_areas = true
	query.transform = Transform3D(Basis.IDENTITY, from_feet + Vector3.UP * height * .5)
	query.motion = to_feet - from_feet
	var cast := _space.cast_motion(query)
	var path_clear := cast.size() >= 2 and float(cast[0]) >= .99999
	query.transform.origin = to_feet + Vector3.UP * height * .5; query.motion = Vector3.ZERO
	var destination_clear := _space.intersect_shape(query, 1).is_empty()
	receipt.path_clear = path_clear; receipt.destination_clear = destination_clear
	receipt.reachable = path_clear and destination_clear
	if cast.size() >= 2:
		receipt["safe_fraction"] = float(cast[0]); receipt["unsafe_fraction"] = float(cast[1])
	return receipt

func _dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
