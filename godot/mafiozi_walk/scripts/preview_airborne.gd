class_name PreviewAirborne
extends RefCounted
## Pure pose sampler: only the host's single pose owner applies the result.
## Source: hero_walk.mjs jumpPose(p, false, null), hero_jump.mjs .8/.45 timing.

const FLIGHT_SECONDS: float = 0.8
const RECOVERY_SECONDS: float = 0.45
const FLIGHT_PROGRESS: float = 0.64
const LAUNCH_BLEND_SECONDS: float = 0.175 # .14 * (.8 + .45)
const RETURN_BLEND_SECONDS: float = 0.28 # hero_pose_transition.mjs
const REQUIRED: PackedStringArray = ["chest", "thigh_l", "shin_l", "foot_l", "upperarm_l", "forearm_l", "thigh_r", "shin_r", "foot_r", "upperarm_r", "forearm_r"]

var _rest: Array[Transform3D] = []
var _rest_q: Array[Quaternion] = []
var _parents: PackedInt32Array = PackedInt32Array()
var _indices: PackedInt32Array = PackedInt32Array()
var _foot_bones: PackedInt32Array = PackedInt32Array()
var _foot_points: Array[PackedVector3Array] = []
var _global_poses: Array[Transform3D] = []
var _skeleton_in_parent: Transform3D
var _visual_rest: Vector3
var _rest_floor: float = 0.0
var _ready: bool = false
var _error: String = "Not bound"
var _epoch: int = -1
var _was_grounded: bool = true
var _mode: String = "idle"
var _air_age: float = 0.0
var _land_age: float = 0.0
var _launch_velocity: float = 0.0
var _progress: float = 0.0
var _land_start_progress: float = 0.0
var _takeoff: Array[Transform3D] = []
var _takeoff_offset: Vector3
var _land_from: Array[Transform3D] = []
var _last_pose: Array[Transform3D] = []
var _last_offset: Vector3
var _source_boot_count: int = 0
var _hull_count: int = 0


func bind(hero_root: Node3D, visual_motion: Node3D) -> bool:
	_ready = false
	_error = "Canonical skeleton/motion missing"
	_rest.clear()
	_rest_q.clear()
	_parents.clear()
	_indices.clear()
	_foot_bones.clear()
	_foot_points.clear()
	_global_poses.clear()
	_source_boot_count = 0
	_hull_count = 0
	reset()
	if hero_root == null or visual_motion == null:
		return false
	var candidates: Array[Node] = hero_root.find_children("*", "Skeleton3D", true, false)
	if candidates.size() != 1:
		return false
	var skeleton: Skeleton3D = candidates[0] as Skeleton3D
	var parent: Node3D = visual_motion.get_parent() as Node3D
	if parent == null:
		return false
	_visual_rest = visual_motion.position
	_skeleton_in_parent = parent.global_transform.affine_inverse() * skeleton.global_transform
	for bone: int in range(skeleton.get_bone_count()):
		var ancestor: int = skeleton.get_bone_parent(bone)
		if ancestor >= bone:
			_error = "Canonical parent-first skeleton order required"
			return false
		_rest.append(skeleton.get_bone_pose(bone))
		_rest_q.append(skeleton.get_bone_pose_rotation(bone))
		_parents.append(ancestor)
		_global_poses.append(Transform3D.IDENTITY)
	for name: String in REQUIRED:
		var bone: int = skeleton.find_bone(name)
		if bone < 0:
			_error = "Canonical jump bone missing: " + name
			return false
		_indices.append(bone)
	_foot_bones.append(skeleton.find_bone("foot_l"))
	_foot_bones.append(skeleton.find_bone("foot_r"))
	if not _cache_boots(hero_root, skeleton):
		_error = "Actual rigid boot geometry missing"
		return false
	_rest_floor = _minimum_sole(_rest)
	_ready = is_finite(_rest_floor)
	_error = "" if _ready else "Non-finite rest support"
	return _ready


func sample(delta: float, grounded: bool, vertical_velocity: float,
		base_poses: Array[Transform3D], base_visual_offset: Vector3,
		pose_authority: StringName, authority_epoch: int) -> Dictionary:
	if not _ready or not _valid_base(base_poses) or not base_visual_offset.is_finite() or not is_finite(delta) or delta < 0.0 or not is_finite(vertical_velocity):
		reset()
		return {"valid": false, "active": false, "reason": "Unbound or invalid pose/motion input"}
	if pose_authority != &"on_foot" or authority_epoch < 0:
		reset()
		return _result(false, base_poses, base_visual_offset, "external-owner")
	if authority_epoch != _epoch:
		reset()
		_epoch = authority_epoch
	if not grounded:
		if _was_grounded or _mode == "idle":
			# Carry the last host-approved grounded output, not a newly generated
			# airborne locomotion base whose release/bob could move the soles.
			_takeoff = _last_pose.duplicate() if _last_pose.size() == _rest.size() else base_poses.duplicate()
			_takeoff_offset = _last_offset if _last_pose.size() == _rest.size() else base_visual_offset
			_air_age = 0.0
			_launch_velocity = maxf(0.0, vertical_velocity)
		else:
			_air_age += delta
		_mode = "ascent" if vertical_velocity > 0.2 else ("fall" if vertical_velocity < -0.2 else "apex")
		_launch_velocity = maxf(_launch_velocity, vertical_velocity)
		var physical_fraction: float
		if _launch_velocity > 0.2:
			physical_fraction = clampf((1.0 - vertical_velocity / _launch_velocity) * 0.5, 0.0, 1.0)
		else:
			# Unsupported ledge drop: enter the ordinary-jump middle pose smoothly.
			# This is an adapter fallback, not a port of long-fall/ragdoll behaviour.
			physical_fraction = 0.5 + 0.5 * _smooth(_air_age / FLIGHT_SECONDS)
		_progress = physical_fraction * FLIGHT_PROGRESS
		var target: Array[Transform3D] = _canonical_pose(_progress)
		var entry: float = _smooth(_air_age / LAUNCH_BLEND_SECONDS)
		var pose: Array[Transform3D] = _blend(_takeoff, target, entry)
		var offset: Vector3 = _takeoff_offset if entry == 0.0 else _contact_offset(pose)
		_was_grounded = false
		return _result(true, pose, offset, _mode)
	if not _was_grounded:
		_mode = "landing"
		_land_age = 0.0
		_land_start_progress = _progress
		_land_from = _last_pose.duplicate()
		_was_grounded = true
		return _result(true, _land_from, _last_offset, "landing")
	if _mode == "landing":
		_land_age += delta # Full authoritative elapsed time; no .1-second clamp.
		if _land_age >= RECOVERY_SECONDS:
			_mode = "idle"
			_progress = 1.0
			return _result(false, base_poses, base_visual_offset, "idle")
		_progress = lerpf(_land_start_progress, 1.0, _land_age / RECOVERY_SECONDS)
		var target: Array[Transform3D] = _canonical_pose(_progress)
		var pose: Array[Transform3D] = _blend(_land_from, target, _smooth(_land_age / LAUNCH_BLEND_SECONDS))
		var return_weight: float = _smooth((_land_age - (RECOVERY_SECONDS - RETURN_BLEND_SECONDS)) / RETURN_BLEND_SECONDS)
		pose = _blend(pose, base_poses, return_weight)
		return _result(true, pose, _contact_offset(pose), "landing")
	return _result(false, base_poses, base_visual_offset, "idle")


func _canonical_pose(progress: float) -> Array[Transform3D]:
	var p: float = clampf(progress, 0.0, 1.0)
	var launch: float = _smooth(p / 0.14)
	var recover: float = _smooth((p - 0.64) / 0.36)
	var landing: float = _smooth((p - 0.5) / 0.14) * (1.0 - _smooth((p - 0.72) / 0.28))
	var air: float = launch * (1.0 - recover)
	var pose: Array[Transform3D] = _rest.duplicate()
	_set_rotation(pose, 0, landing * 0.35, 0.0)
	for side: int in range(2):
		var sign: float = 1.0 if side == 0 else -1.0
		var slot: int = 1 + side * 5
		_set_rotation(pose, slot, -air * 0.65 - landing * 0.8, 0.0)
		_set_rotation(pose, slot + 1, air * 0.8 + landing * 0.85, 0.0)
		_set_rotation(pose, slot + 2, -air * 0.14 - landing * 0.15, 0.0)
		_set_rotation(pose, slot + 3, -air * 0.65, sign * air * 0.15)
		_set_rotation(pose, slot + 4, -air * 0.8, 0.0)
	return pose


func _set_rotation(pose: Array[Transform3D], slot: int, x: float, z: float) -> void:
	var bone: int = _indices[slot]
	# Three.js default XYZ Euler: qX * qZ. Godot's default Euler is YXZ.
	var rotation: Quaternion = (_rest_q[bone] * Quaternion(Vector3.RIGHT, x) * Quaternion(Vector3.BACK, z)).normalized()
	pose[bone] = Transform3D(Basis(rotation) * Basis.from_scale(_rest[bone].basis.get_scale()), _rest[bone].origin)


func _blend(from: Array[Transform3D], to: Array[Transform3D], amount: float) -> Array[Transform3D]:
	if amount <= 0.0:
		return from.duplicate()
	if amount >= 1.0:
		return to.duplicate()
	var pose: Array[Transform3D] = []
	for bone: int in range(_rest.size()):
		var rotation: Quaternion = from[bone].basis.get_rotation_quaternion().slerp(to[bone].basis.get_rotation_quaternion(), amount)
		pose.append(Transform3D(Basis(rotation) * Basis.from_scale(_rest[bone].basis.get_scale()), _rest[bone].origin))
	return pose


func _minimum_sole(poses: Array[Transform3D]) -> float:
	for bone: int in range(poses.size()):
		_global_poses[bone] = poses[bone] if _parents[bone] < 0 else _global_poses[_parents[bone]] * poses[bone]
	var lowest: float = INF
	for side: int in range(2):
		var transform: Transform3D = _skeleton_in_parent * _global_poses[_foot_bones[side]]
		for point: Vector3 in _foot_points[side]:
			lowest = minf(lowest, (transform * point).y)
	return lowest


func _contact_offset(poses: Array[Transform3D]) -> Vector3:
	return _visual_rest + Vector3.UP * (_rest_floor - _minimum_sole(poses))


func _valid_base(poses: Array[Transform3D]) -> bool:
	if poses.size() != _rest.size():
		return false
	for bone: int in range(poses.size()):
		if not poses[bone].is_finite() or poses[bone].origin.distance_to(_rest[bone].origin) > 0.0001 or poses[bone].basis.get_scale().distance_to(_rest[bone].basis.get_scale()) > 0.0001:
			return false
	return true


func _result(active: bool, poses: Array[Transform3D], offset: Vector3, phase: String) -> Dictionary:
	_last_pose = poses.duplicate()
	_last_offset = offset
	return {"valid": true, "active": active, "poses": poses.duplicate(), "visual_offset": offset,
		"phase": phase, "progress": _progress, "airborne_age": _air_age, "landing_age": _land_age,
		"authority_epoch": _epoch, "scope": "ordinary unarmed jump; no dive/combat/vehicle pose"}


func reset() -> void:
	_epoch = -1
	_was_grounded = true
	_mode = "idle"
	_air_age = 0.0
	_land_age = 0.0
	_launch_velocity = 0.0
	_progress = 0.0
	_land_start_progress = 0.0
	_takeoff.clear()
	_takeoff_offset = Vector3.ZERO
	_land_from.clear()
	_last_pose.clear()
	_last_offset = Vector3.ZERO


func get_status() -> Dictionary:
	return {"ready": _ready, "error": _error, "phase": _mode, "progress": _progress,
		"source_boot_vertices": _source_boot_count, "support_hull_vertices": _hull_count,
		"contract": "pure sampler; host alone applies returned local poses and visual offset"}


func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _cache_boots(hero_root: Node3D, skeleton: Skeleton3D) -> bool:
	var points_by_side: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	for node: Node in hero_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin == null or mesh.mesh == null:
			continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or joints.is_empty() or joints.size() != weights.size():
				continue
			var influences: int = joints.size() / vertices.size()
			for vertex: int in range(vertices.size()):
				for influence: int in range(influences):
					var at: int = vertex * influences + influence
					if weights[at] < 0.9999:
						continue
					var bind_index: int = joints[at]
					var name: StringName = mesh.skin.get_bind_name(bind_index)
					var bone: int = skeleton.find_bone(str(name)) if not name.is_empty() else mesh.skin.get_bind_bone(bind_index)
					var side: int = _foot_bones.find(bone)
					if side >= 0:
						points_by_side[side].append(mesh.skin.get_bind_pose(bind_index) * vertices[vertex])
	for points: PackedVector3Array in points_by_side:
		if points.size() < 4:
			return false
		_source_boot_count += points.size()
		var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shape.points = points
		var hull_mesh: ArrayMesh = shape.get_debug_mesh()
		var unique: Dictionary = {}
		var hull: PackedVector3Array = PackedVector3Array()
		for surface: int in range(hull_mesh.get_surface_count()):
			var hull_vertices: PackedVector3Array = hull_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in hull_vertices:
				if not unique.has(point):
					unique[point] = true
					hull.append(point)
		if hull.is_empty():
			return false
		_hull_count += hull.size()
		_foot_points.append(hull)
	return true
