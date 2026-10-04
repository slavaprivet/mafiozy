class_name PreviewLocomotion
extends RefCounted
## Canonical unarmed standing gait from hero_walk.mjs, presentation only.

const BONE_NAMES: PackedStringArray = ["chest", "thigh_l", "shin_l", "foot_l", "upperarm_l", "forearm_l", "thigh_r", "shin_r", "foot_r", "upperarm_r", "forearm_r"]
const RADIANS_PER_METRE: float = 2.3

var _skeleton: Skeleton3D
var _motion: Node3D
var _motion_rest: Vector3
var _rest_poses: Array[Transform3D] = []
var _rest_rotations: Array[Quaternion] = []
var _bone_indices: PackedInt32Array = PackedInt32Array()
var _foot_points: Array[PackedVector3Array] = []
var _foot_bones: PackedInt32Array = PackedInt32Array()
var _ready: bool = false
var _error: String = "Not bound"
var _phase: float = 0.0
var _gait: float = 0.0
var _speed: float = 0.0
var _contact_offset: float = 0.0
var _pose_active: bool = false
# DSH_WALKPOSE: per-instance gait calibration and the support-foot probe.
# _radians_per_metre is an INSTANCE copy of RADIANS_PER_METRE - the const stays, and
# is what every uncalibrated instance keeps using, because this same class drives the
# player and the transport (preview_player._locomotion).
# _dsh_support_side/_dsh_support_xz are published by _support_minimum_y() on every
# grounded pose build and consumed once by the resident host's DSH_WALK slip metric.
var _dsh_walk_pose := -1
var _dsh_gait_step_value := ""
var _dsh_walk_calibrate := false
var _radians_per_metre: float = RADIANS_PER_METRE
var _dsh_leg_m := -1.0
var _dsh_support_serial := 0
var _dsh_support_side := -1
var _dsh_support_xz := Vector2.ZERO
var _support_source_count: int = 0
var _support_hull_count: int = 0
var _parents: PackedInt32Array = PackedInt32Array()
var _global_poses: Array[Transform3D] = []
var _skeleton_in_parent: Transform3D


func bind(hero_root: Node3D, visual_motion: Node3D, walk_pose_calibrate: bool = false) -> bool:
	# DSH_WALKPOSE: the third argument is the opt-in. Default false keeps every other
	# caller (the player binds with two arguments) on today's RADIANS_PER_METRE.
	_dsh_walk_calibrate = walk_pose_calibrate
	if _ready:
		reset_pose()
	_ready = false
	_error = "Canonical skeleton or motion node missing"
	if hero_root == null or visual_motion == null:
		return false
	var skeletons: Array[Node] = hero_root.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		return false
	_skeleton = skeletons[0] as Skeleton3D
	_motion = visual_motion
	_motion_rest = visual_motion.position
	_rest_poses.clear()
	_parents.clear()
	_global_poses.clear()
	_skeleton_in_parent = visual_motion.get_parent().global_transform.affine_inverse() * _skeleton.global_transform
	_rest_rotations.clear()
	_bone_indices.clear()
	_foot_points.clear()
	_foot_bones.clear()
	_support_source_count = 0
	_support_hull_count = 0
	for bone: int in range(_skeleton.get_bone_count()):
		if _skeleton.get_bone_parent(bone) >= bone:
			_error = "Canonical parent-first skeleton order required"
			return false
		_parents.append(_skeleton.get_bone_parent(bone))
		_global_poses.append(Transform3D.IDENTITY)
		_rest_poses.append(_skeleton.get_bone_pose(bone))
		_rest_rotations.append(_skeleton.get_bone_pose_rotation(bone))
	for bone_name: String in BONE_NAMES:
		var bone: int = _skeleton.find_bone(bone_name)
		if bone < 0:
			_error = "Canonical gait bone missing: " + bone_name
			return false
		_bone_indices.append(bone)
	_foot_bones.append(_skeleton.find_bone("foot_l"))
	_foot_bones.append(_skeleton.find_bone("foot_r"))
	if not _cache_actual_boot_hulls(hero_root):
		_error = "Canonical rigid boot support geometry missing"
		return false
	_ready = true
	_error = ""
	reset_pose()
	_dsh_calibrate()  # DSH_WALKPOSE: one measurement per instance; an unprovable rig keeps 2.3
	return true


func update_pose(delta: float, horizontal_velocity: Vector3, grounded: bool) -> void:
	# Compatibility owner for standalone gait callers. The player uses sample().
	var result: Dictionary = sample(delta, horizontal_velocity, grounded)
	if not bool(result.get("valid", false)):
		return
	var poses: Array[Transform3D] = result["poses"]
	for bone: int in range(poses.size()):
		_skeleton.set_bone_pose(bone, poses[bone])
	_motion.position = result["visual_offset"]


func sample(delta: float, horizontal_velocity: Vector3, grounded: bool) -> Dictionary:
	# Always construct from canonical rest; never read last frame's air blend.
	if not _ready or not is_instance_valid(_skeleton) or not is_instance_valid(_motion):
		return {"valid": false}
	if not is_finite(delta) or delta <= 0.0:
		return {"valid": false}
	if _dsh_walk_calibrate and _dsh_leg_m <= 0.0: _dsh_calibrate()  # DSH_WALKPOSE
	var poses: Array[Transform3D] = _rest_poses.duplicate()
	var offset: Vector3 = _motion_rest
	var dt: float = minf(delta, 0.1)
	_speed = Vector2(horizontal_velocity.x, horizontal_velocity.z).length() if horizontal_velocity.is_finite() else 0.0
	var moving: bool = grounded and _speed > 0.02
	var target_gait: float = 1.0 if moving else 0.0
	_gait += (target_gait - _gait) * (1.0 - exp(-10.0 * dt))
	if not moving and _gait < 0.0001:
		_gait = 0.0
	_phase = fposmod(_phase + dt * (_speed * _radians_per_metre if moving else 3.0), TAU)  # DSH_WALKPOSE: instance value
	if _gait == 0.0:
		_contact_offset = 0.0
		_pose_active = false
		return {"valid": true, "poses": poses, "visual_offset": offset}
	_pose_active = true
	var wave: float = sin(_phase)
	_rotate(poses, 0, Vector3.BACK, wave * _gait * 0.018)
	for side: int in range(2):
		var step: float = wave * _gait * (1.0 if side == 0 else -1.0)
		var base: int = 1 + side * 5
		_rotate(poses, base, Vector3.RIGHT, step * 0.56)
		_rotate(poses, base + 1, Vector3.RIGHT, maxf(0.0, -step) * 0.52)
		_rotate(poses, base + 2, Vector3.RIGHT, -step * 0.22)
		_rotate(poses, base + 3, Vector3.RIGHT, -step * 0.38)
		_rotate(poses, base + 4, Vector3.RIGHT, -maxf(0.0, step) * 0.12)
	var bob: float = absf(wave) * _gait * 0.026
	if grounded:
		# Exact lower support of the actual rigid boots, not a guessed ankle box.
		# Presentation shift only: capsule, body position and gravity are untouched.
		var minimum_y: float = _support_minimum_y(poses)
		_contact_offset = -minimum_y if is_finite(minimum_y) else 0.0
		offset.y += _contact_offset
	else:
		_contact_offset = move_toward(_contact_offset, 0.0, dt * 0.6)
		offset.y += _contact_offset + bob
	return {"valid": true, "poses": poses, "visual_offset": offset}


func _rotate(poses: Array[Transform3D], slot: int, axis: Vector3, angle: float) -> void:
	var bone: int = _bone_indices[slot]
	var rotation: Quaternion = (_rest_rotations[bone] * Quaternion(axis, angle)).normalized()
	poses[bone] = Transform3D(Basis(rotation) * Basis.from_scale(_rest_poses[bone].basis.get_scale()), _rest_poses[bone].origin)


func _restore_rest() -> void:
	for bone: int in range(_rest_poses.size()):
		_skeleton.set_bone_pose(bone, _rest_poses[bone])
	_motion.position = _motion_rest
	_contact_offset = 0.0
	_pose_active = false


func reset_state() -> void:
	_phase = 0.0
	_gait = 0.0
	_speed = 0.0
	_contact_offset = 0.0
	_pose_active = false


func reset_pose() -> void:
	reset_state()
	if _ready and is_instance_valid(_skeleton) and is_instance_valid(_motion):
		_restore_rest()

# DSH_WALKPOSE: --city-walk-pose=1 (default) enables the far-pose path in the resident
# host and lets an opted-in instance calibrate its own step length; 0 keeps today's
# constant and today's pose code.
func _dsh_walk_pose_flag() -> int:
	if _dsh_walk_pose < 0:
		_dsh_walk_pose = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-walk-pose="):
				_dsh_walk_pose = maxi(0, int(argument.trim_prefix("--city-walk-pose=")))
	return _dsh_walk_pose

# DSH_WALKPOSE: --city-gait-step=auto (default) derives this instance's
# radians-per-metre from its own rig; any number (today's 2.3) is used verbatim.
func _dsh_gait_step() -> String:
	if _dsh_gait_step_value.is_empty():
		_dsh_gait_step_value = "auto"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-gait-step="):
				_dsh_gait_step_value = argument.trim_prefix("--city-gait-step=")
	return _dsh_gait_step_value

# DSH_WALKPOSE: the ground one full gait cycle may cover for this instance. The foot
# travel sample()'s own rotation set can express, as a fraction of hip->ankle, is
# 0.9285 (thigh +/-0.56 rad, knee 0.52*max(0,-step) on the back swing only, foot
# 0.22*step). One step is half a cycle, hence TAU / (2 * ratio * leg).
const DSH_FOOT_TRAVEL_RATIO: float = 0.9285

# DSH_WALKPOSE: one measurement per instance, residents only. hip->ankle comes from the
# rest poses bind() already read (_rest_poses through _parents), converted to world
# metres with the skeleton's global scale. Anything unprovable (not opted in, not in
# the tree, leg outside 0.20..2.50 m, non-finite) leaves _radians_per_metre at
# RADIANS_PER_METRE: today's behaviour, never a guess. At --city-walk-pose=0 the
# measurement is still taken for DSH_WALK but the calibrated value is NOT applied.
func _dsh_calibrate() -> void:
	if not _dsh_walk_calibrate or _dsh_leg_m > 0.0 or not _ready: return
	if not is_instance_valid(_skeleton) or not _skeleton.is_inside_tree(): return
	var dsh_thigh_slot: int = BONE_NAMES.find("thigh_l")
	var dsh_foot_slot: int = BONE_NAMES.find("foot_l")
	if dsh_thigh_slot < 0 or dsh_foot_slot < 0 or dsh_thigh_slot >= _bone_indices.size() or dsh_foot_slot >= _bone_indices.size(): return
	var dsh_leg: float = (_dsh_global_rest(_bone_indices[dsh_thigh_slot]) - _dsh_global_rest(_bone_indices[dsh_foot_slot])).length() * absf(_skeleton.global_basis.get_scale().y)
	if not is_finite(dsh_leg) or dsh_leg < 0.20 or dsh_leg > 2.50: return
	_dsh_leg_m = dsh_leg
	if _dsh_walk_pose_flag() == 0: return
	var dsh_setting: String = _dsh_gait_step()
	if dsh_setting == "auto":
		_radians_per_metre = TAU / (2.0 * DSH_FOOT_TRAVEL_RATIO * dsh_leg)
	elif dsh_setting.is_valid_float():
		_radians_per_metre = maxf(0.05, dsh_setting.to_float())

# DSH_WALKPOSE: rest position of a bone in the skeleton's own space, from the rest
# poses this instance already holds - the same product _support_minimum_y() builds.
func _dsh_global_rest(bone: int) -> Vector3:
	var dsh_transform: Transform3D = _rest_poses[bone]
	var dsh_parent: int = _parents[bone]
	while dsh_parent >= 0:
		dsh_transform = _rest_poses[dsh_parent] * dsh_transform
		dsh_parent = _parents[dsh_parent]
	return dsh_transform.origin

# DSH_WALKPOSE: O(1) phase/amplitude update for a record whose pose is NOT committed
# this step (the far animation band). No _rest_poses.duplicate(), no boot-hull scan,
# no set_bone_pose: ~0.2 us instead of the whole pose build. `metres` is the ground the
# body actually moved since the last commit (0.0 on a deferred step, where it did not
# move); `speed_hint` is the record's speed, used only as the amplitude blend time, so
# a zero-distance step changes nothing but keeps the amplitude alive.
func advance_distance(metres: float, grounded: bool, speed_hint: float = -1.0) -> void:
	if not _ready or not is_instance_valid(_skeleton) or not is_instance_valid(_motion): return
	if not is_finite(metres) or metres < 0.0: return
	if _dsh_walk_calibrate and _dsh_leg_m <= 0.0: _dsh_calibrate()
	var dsh_speed: float = speed_hint if is_finite(speed_hint) and speed_hint > 0.05 else _speed
	if dsh_speed > 0.0: _speed = dsh_speed
	var dsh_dt: float = minf(metres / dsh_speed, 0.1) if dsh_speed > 0.05 else 0.0
	var moving: bool = grounded and (metres > 0.0001 or dsh_speed > 0.02)
	var target_gait: float = 1.0 if moving else 0.0
	if dsh_dt > 0.0: _gait += (target_gait - _gait) * (1.0 - exp(-10.0 * dsh_dt))
	if not moving and _gait < 0.0001: _gait = 0.0
	# Same rule as sample(): distance-locked while moving, the idle sway otherwise (an
	# airborne far record keeps the 3 rad/s of the pose owner instead of a stride).
	_phase = fposmod(_phase + (metres * _radians_per_metre if moving else 3.0 * dsh_dt), TAU)
	_pose_active = _gait > 0.0

# DSH_WALKPOSE: true when the amplitude has fully decayed, i.e. the committed pose is
# the standing one and a far record can stop paying for further builds until it moves.
func settled() -> bool:
	return _gait <= 0.0001


func _cache_actual_boot_hulls(hero_root: Node3D) -> bool:
	var source_points: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	for node: Node in hero_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin == null or mesh.mesh == null:
			continue
		var skin: Skin = mesh.skin
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or joints.is_empty() or weights.size() != joints.size():
				continue
			var influences: int = joints.size() / vertices.size()
			for vertex: int in range(vertices.size()):
				for influence: int in range(influences):
					var offset: int = vertex * influences + influence
					if weights[offset] < 0.9999:
						continue
					var bind_index: int = joints[offset]
					var bind_name: StringName = skin.get_bind_name(bind_index)
					var bone: int = _skeleton.find_bone(str(bind_name)) if not bind_name.is_empty() else skin.get_bind_bone(bind_index)
					var side: int = _foot_bones.find(bone)
					if side < 0:
						continue
					source_points[side].append(skin.get_bind_pose(bind_index) * vertices[vertex])
	for points: PackedVector3Array in source_points:
		if points.size() < 4:
			return false
		_support_source_count += points.size()
		# The native convex hull retains exact support extrema while removing
		# interior/coplanar boot vertices. It is built once, never in the tick.
		var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shape.points = points
		var debug_mesh: ArrayMesh = shape.get_debug_mesh()
		var hull: PackedVector3Array = PackedVector3Array()
		var seen: Dictionary = {}
		for surface: int in range(debug_mesh.get_surface_count()):
			var arrays: Array = debug_mesh.surface_get_arrays(surface)
			var hull_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point: Vector3 in hull_vertices:
				if not seen.has(point):
					seen[point] = true
					hull.append(point)
		if hull.is_empty():
			return false
		_support_hull_count += hull.size()
		_foot_points.append(hull)
	return true


func _support_minimum_y(poses: Array[Transform3D]) -> float:
	for bone: int in range(poses.size()):
		_global_poses[bone] = poses[bone] if _parents[bone] < 0 else _global_poses[_parents[bone]] * poses[bone]
	var minimum_y: float = INF
	# DSH_WALKPOSE: the same scan also publishes which boot is the support and where its
	# lowest point sits (_dsh_support_side/_dsh_support_xz, one serial per build), so the
	# host can measure how far the planted foot slides over the ground between two
	# commits without a second pose build. Two extra ops per hull point, no allocation.
	var dsh_low: Vector3 = Vector3.ZERO
	var dsh_low_side: int = -1
	for side: int in range(2):
		var bone_transform: Transform3D = _skeleton_in_parent * _global_poses[_foot_bones[side]]
		for point: Vector3 in _foot_points[side]:
			var dsh_world: Vector3 = bone_transform * point
			if dsh_world.y < minimum_y:
				minimum_y = dsh_world.y; dsh_low = dsh_world; dsh_low_side = side
	_dsh_support_serial += 1
	_dsh_support_side = dsh_low_side
	_dsh_support_xz = Vector2(dsh_low.x, dsh_low.z)
	return minimum_y


func get_status() -> Dictionary:
	return {"ready": _ready, "error": _error, "phase": _phase, "gait": _gait,
		"speed_mps": _speed, "contact_offset_m": _contact_offset,
		"support_source_vertices": _support_source_count, "support_hull_vertices": _support_hull_count,
		"scope": "Canonical unarmed idle/walk/run; jump/combat animation not migrated",
		"walk_pose": _dsh_walk_pose_flag(), "radians_per_metre": _radians_per_metre,
		"leg_m": _dsh_leg_m, "walk_calibrate": _dsh_walk_calibrate}
