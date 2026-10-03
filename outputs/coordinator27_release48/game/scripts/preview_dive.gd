extends RefCounted
## Pure unarmed source dive sampler. No live rig writes and no body movement.
## The host must apply returned visual_rotation AND poses, then physical motion
## separately through its swept CharacterBody3D contract. Not wired into player.
const FLIGHT := 0.8
const RECOVERY := 0.45
const SPEED := 4.2
const NORMAL_SPEED := 3.5
const HEIGHT := 1.05
const DIVE_HEIGHT := 0.42
const DOUBLE_PRESS_MS := 500.0
const DIVE_BLEND_SECONDS := 0.24
const CINEMATIC_FLIGHT := 1.25
const CINEMATIC_HEIGHT := 0.82
const CINEMATIC_PROFILE := "cinematic_user_20260927"
const REQUIRED := ["chest", "neck", "head", "thigh_l", "shin_l", "foot_l", "upperarm_l", "forearm_l", "thigh_r", "shin_r", "foot_r", "upperarm_r", "forearm_r"]
var _rest: Array[Transform3D] = []
var _parents: PackedInt32Array = []
var _names: Dictionary = {}
var _global: Array[Transform3D] = []
var _meshes: Array[Dictionary] = []
var _rigid_hulls: Dictionary = {}
var _mixed_bones := PackedInt32Array()
var _mixed_points := PackedVector3Array()
var _mixed_weights := PackedFloat32Array()
var _mixed_ends := PackedInt32Array()
var _skin_axes := PackedVector3Array()
var _skin_origins := PackedFloat32Array()
var _rigid_bones := PackedInt32Array()
var _rigid_points: Array[PackedVector3Array] = []
var _to_motion: Transform3D
var _head_rest: Quaternion
var _ready := false
var _epoch := -1
var _source_vertices := 0
var _weighted_count := 0
var _weighted_support_count := 0
var _weighted_group_count := 0

static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func frame_steps(delta: float, visible: bool = true) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	if not visible or not is_finite(delta) or delta <= 0.0 or delta > 1.0:
		return result
	var remaining := minf(delta, 0.25)
	for i in range(7):
		if remaining <= 0.000000001:
			break
		var step := minf(remaining, 0.04)
		result.append(step)
		remaining -= step
	return result

## Source trajectory proposal only. Host must sweep displacement and resolve
## floor/ceiling/water per substep before committing elapsed/contact state.
static func proposal(state: Dictionary, delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or not state.has("elapsed") or not is_finite(float(state.elapsed)) or float(state.elapsed) < 0.0 or not is_finite(float(state.get("diveStartElapsed", 0.0))):
		return {"valid": false}
	if bool(state.get("done", false)):
		return {"valid": true, "elapsed": state.elapsed, "progress": state.get("progress", float(state.elapsed) / (FLIGHT + RECOVERY)), "travel": 0.0, "arc_y": state.get("y", 0.0), "diveBlend": state.get("diveBlend", 0.0), "done": true}
	var elapsed := minf(FLIGHT + RECOVERY, float(state.elapsed) + minf(delta, 0.1))
	var dive: bool = str(state.get("mode", "normal")) == "dive"
	var travel := maxf(0.0, minf(elapsed, FLIGHT) - minf(float(state.elapsed), FLIGHT)) * (SPEED if dive else NORMAL_SPEED)
	var blend := smooth((elapsed - float(state.get("diveStartElapsed", elapsed))) / DIVE_BLEND_SECONDS) if dive else 0.0
	var p := minf(1.0, elapsed / FLIGHT)
	return {"valid": true, "elapsed": elapsed, "progress": elapsed / (FLIGHT + RECOVERY), "travel": travel,
		"arc_y": 4.0 * lerpf(HEIGHT, DIVE_HEIGHT, blend) * p * (1.0 - p), "diveBlend": blend, "done": elapsed >= FLIGHT + RECOVERY}

static func upgrade(state: Dictionary, direction: Vector2, now_ms: float) -> Dictionary:
	if not state.has("startedAt") or not state.has("elapsed") or not is_finite(now_ms) or not direction.is_finite() or not is_finite(direction.length()) or not is_finite(float(state.startedAt)) or not is_finite(float(state.elapsed)):
		return state.duplicate(true)
	var age := now_ms - float(state.startedAt)
	if str(state.get("mode", "normal")) != "normal" or bool(state.get("done", false)) or bool(state.get("falling", false)) or bool(state.get("ceilingHit", false)) or age < 0.0 or age > DOUBLE_PRESS_MS or float(state.elapsed) >= FLIGHT or direction.length_squared() <= 0.0:
		return state.duplicate(true)
	var result := state.duplicate(true)
	result.mode = "dive"
	result.diveStartElapsed = state.elapsed
	result.diveBlend = 0.0
	result.direction = direction.normalized()
	return result

## Explicit user tuning; source proposal/upgrade remain unchanged oracle APIs.
## The continuation is C1: position and instantaneous vertical velocity agree
## at upgrade and at apex. It never injects a second upward impulse.
static func cinematic_upgrade(state: Dictionary, direction: Vector2, now_ms: float, current_height: float) -> Dictionary:
	var result := upgrade(state, direction, now_ms)
	if str(state.get("mode", "normal")) != "normal" or str(result.get("mode", "normal")) != "dive" or not is_finite(current_height):
		return state.duplicate(true)
	var elapsed := float(state.elapsed)
	var initial_velocity := 4.0 * HEIGHT / FLIGHT * (1.0 - 2.0 * elapsed / FLIGHT)
	var peak := maxf(current_height, lerpf(CINEMATIC_HEIGHT, HEIGHT, smooth(elapsed / 0.2)))
	var ascent := 3.0 * maxf(0.0, peak - current_height) / initial_velocity if initial_velocity > 0.000001 else 0.0
	result.profile = CINEMATIC_PROFILE
	result.curve_y = current_height
	result.curve_velocity = initial_velocity
	result.curve_apex = peak if ascent > 0.0 else current_height
	result.curve_ascent = ascent
	result.contact_elapsed = -1.0
	return result

static func cinematic_proposal(state: Dictionary, delta: float) -> Dictionary:
	if state.get("profile", "") != CINEMATIC_PROFILE:
		return proposal(state, delta)
	if not is_finite(delta) or delta < 0.0:
		return {"valid": false}
	var previous := float(state.elapsed)
	var elapsed := previous + minf(delta, 0.1)
	var age := elapsed - float(state.diveStartElapsed)
	var ascent := float(state.curve_ascent)
	var height := float(state.curve_y)
	var vertical_velocity := float(state.curve_velocity)
	if ascent > 0.0 and age < ascent:
		var u := clampf(age / ascent, 0.0, 1.0)
		height += vertical_velocity * ascent * (u - u * u + u * u * u / 3.0)
		vertical_velocity *= (1.0 - u) * (1.0 - u)
	else:
		var duration := CINEMATIC_FLIGHT - float(state.diveStartElapsed) - ascent
		var u := clampf((age - ascent) / duration, 0.0, 1.0)
		var start_height := float(state.curve_apex)
		var start_velocity := 0.0 if ascent > 0.0 else minf(0.0, vertical_velocity)
		# Cubic Hermite descent: starts at retained height/velocity, ends at
		# ground with zero velocity. Monotonic over all admitted upgrade times.
		height = start_height * (2.0*u*u*u - 3.0*u*u + 1.0) + start_velocity * duration * (u*u*u - 2.0*u*u + u)
		vertical_velocity = start_height * (6.0*u*u - 6.0*u) / duration + start_velocity * (3.0*u*u - 4.0*u + 1.0)
	var contact := float(state.get("contact_elapsed", -1.0))
	var progress := minf(0.72, elapsed / (FLIGHT + RECOVERY))
	if contact >= 0.0:
		progress = lerpf(0.72, 1.0, clampf((elapsed - contact) / RECOVERY, 0.0, 1.0))
	return {"valid": true, "elapsed": elapsed, "progress": progress,
		"travel": maxf(0.0, minf(elapsed, CINEMATIC_FLIGHT) - minf(previous, CINEMATIC_FLIGHT)) * SPEED if contact < 0.0 else 0.0,
		"arc_y": height, "arc_velocity": vertical_velocity,
		"diveBlend": smooth(age / DIVE_BLEND_SECONDS), "done": contact >= 0.0 and elapsed - contact >= RECOVERY}

func bind(hero: Node3D, motion: Node3D) -> bool:
	_ready = false
	reset()
	_rest.clear()
	_parents.clear()
	_names.clear()
	_global.clear()
	_meshes.clear()
	_rigid_hulls.clear()
	_mixed_bones.clear()
	_mixed_points.clear()
	_mixed_weights.clear()
	_mixed_ends.clear()
	_rigid_bones.clear()
	_rigid_points.clear()
	_source_vertices = 0
	_weighted_count = 0
	_weighted_support_count = 0
	_weighted_group_count = 0
	if hero == null or motion == null or not motion.transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var rigs := hero.find_children("*", "Skeleton3D", true, false)
	if rigs.size() != 1:
		return false
	var rig: Skeleton3D = rigs[0]
	_to_motion = motion.global_transform.affine_inverse() * rig.global_transform
	for i in range(rig.get_bone_count()):
		if rig.get_bone_parent(i) >= i:
			return false
		_rest.append(rig.get_bone_pose(i))
		_parents.append(rig.get_bone_parent(i))
		_names[rig.get_bone_name(i)] = i
		_global.append(Transform3D.IDENTITY)
	for name: String in REQUIRED:
		if not _names.has(name):
			return false
	_compose(_rest)
	_head_rest = (_to_motion * _global[_names.head]).basis.get_rotation_quaternion()
	for node: Node in hero.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.mesh == null or mesh.skin == null:
			return false # This first exact package admits only the canonical skin.
		var ids := PackedInt32Array()
		var binds: Array[Transform3D] = []
		for at in range(mesh.skin.get_bind_count()):
			var bone := rig.find_bone(str(mesh.skin.get_bind_name(at)))
			if bone < 0:
				return false
			ids.append(bone)
			binds.append(mesh.skin.get_bind_pose(at))
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or joints.size() != vertices.size() * 4 or weights.size() != joints.size():
				return false
			_source_vertices += vertices.size()
			var mixed_vertices := PackedVector3Array()
			var mixed_joints := PackedInt32Array()
			var mixed_weights := PackedFloat32Array()
			for v in range(vertices.size()):
				var rigid := -1
				var count := 0
				for influence in range(4):
					var at := v * 4 + influence
					if weights[at] > 0.0:
						count += 1
						if weights[at] == 1.0:
							rigid = joints[at]
				if count == 1 and rigid >= 0:
					var id: int = ids[rigid]
					if not _rigid_hulls.has(id):
						_rigid_hulls[id] = PackedVector3Array()
					_rigid_hulls[id].append(binds[rigid] * vertices[v])
				else:
					mixed_vertices.append(vertices[v])
					for influence in range(4):
						mixed_joints.append(joints[v * 4 + influence])
						mixed_weights.append(weights[v * 4 + influence])
			if not mixed_vertices.is_empty():
				var groups: Dictionary = {}
				for v in range(mixed_vertices.size()):
					var signature: Array = []
					for influence in range(4):
						if mixed_weights[v * 4 + influence] > 0.0:
							signature.append(mixed_joints[v * 4 + influence])
							signature.append(mixed_weights[v * 4 + influence])
					if not groups.has(signature):
						groups[signature] = {"signature": signature, "points": PackedVector3Array()}
					groups[signature].points.append(mixed_vertices[v])
				for group: Dictionary in groups.values():
					group.points = _support_hull(group.points)
				_meshes.append({"groups": groups.values(), "ids": ids, "binds": binds, "source_count": mixed_vertices.size()})
	# Min of an affine projection over rigid vertices equals min over their
	# convex hull. Keep genuinely weighted vertices exact; never use boot-only
	# support for a sideways dive where head, arm or cloth may be lowest.
	for bone: int in _rigid_hulls:
		_rigid_hulls[bone] = _support_hull(_rigid_hulls[bone])
		_rigid_bones.append(bone)
		_rigid_points.append(_rigid_hulls[bone])
	# Pack each unique weighted support vertex in bone-local coordinates. Most
	# cloth weights are unique, so a Dictionary per signature in the hot loop
	# costs more than four dot products. Bind-time duplicates are safe to remove.
	var unique_weighted: Dictionary = {}
	for mesh: Dictionary in _meshes:
		_weighted_count += mesh.source_count
		_weighted_group_count += mesh.groups.size()
		for group: Dictionary in mesh.groups:
			_weighted_support_count += group.points.size()
			var signature: Array = group.signature
			for point: Vector3 in group.points:
				var key: Array = []
				for at in range(0, signature.size(), 2):
					var bind: int = signature[at]
					key.append(mesh.ids[bind])
					key.append((mesh.binds[bind] as Transform3D) * point)
					key.append(signature[at + 1])
				if unique_weighted.has(key):
					continue
				unique_weighted[key] = true
				for at in range(0, key.size(), 3):
					_mixed_bones.append(key[at])
					_mixed_points.append(key[at + 1] * key[at + 2])
					_mixed_weights.append(key[at + 2])
				_mixed_ends.append(_mixed_bones.size())
	_skin_axes.resize(_rest.size())
	_skin_origins.resize(_rest.size())
	_meshes.clear() # Retain only packed runtime support, release preparation DTOs.
	_rigid_hulls.clear()
	_ready = _source_vertices == 8338
	return _ready

func sample(progress: float, dive_blend: float, root_yaw: float, aim_yaw: float, aim_pitch: float, travel_yaw: float, authority: StringName, epoch: int) -> Dictionary:
	if not _ready or not is_finite(progress) or not is_finite(dive_blend) or not is_finite(root_yaw) or not is_finite(aim_yaw) or not is_finite(aim_pitch) or not is_finite(travel_yaw):
		reset()
		return {"valid": false, "active": false, "reason": "invalid-or-unbound"}
	if authority != &"on_foot" or epoch < 0:
		reset()
		return {"valid": true, "active": false, "reason": "external-owner"}
	if epoch != _epoch:
		reset()
		_epoch = epoch
	var p := clampf(progress, 0.0, 1.0)
	var dive := clampf(dive_blend, 0.0, 1.0)
	var launch := smooth(p / 0.14)
	var normal_recover := smooth((p - 0.64) / 0.36)
	var dive_recover := smooth((p - 0.72) / 0.28)
	var air := launch * (1.0 - lerpf(normal_recover, dive_recover, dive))
	var landing := smooth((p - 0.5) / 0.14) * (1.0 - smooth((p - 0.72) / 0.28))
	var relative := travel_yaw - aim_yaw
	var tilt := dive * launch * (1.0 - dive_recover) * (1.2 + 0.33 * smooth((p - 0.46) / 0.18))
	var rotation := Quaternion(Vector3.UP, aim_yaw - root_yaw) * Quaternion(Vector3(cos(relative), 0.0, -sin(relative)), tilt)
	var pose: Array[Transform3D] = _rest.duplicate()
	_rotate(pose, "neck", -cos(relative) * dive * air * 0.82, sin(relative) * dive * air * 0.82)
	_rotate(pose, "head", -cos(relative) * dive * air * 0.38, sin(relative) * dive * air * 0.38)
	_rotate(pose, "chest", landing * (0.35 - 0.13 * dive))
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		_rotate(pose, "thigh_" + side, -air * (0.65 - 0.45 * dive) - landing * (0.8 - 0.58 * dive))
		_rotate(pose, "shin_" + side, air * (0.8 - 0.4 * dive) + landing * (0.85 - 0.55 * dive))
		_rotate(pose, "foot_" + side, -air * 0.14 - landing * 0.15)
		_rotate(pose, "upperarm_" + side, -air * (0.65 + 0.8 * dive), sign * air * 0.15)
		_rotate(pose, "forearm_" + side, -air * (0.8 - 0.45 * dive))
	_compose(pose)
	# Source performs first support solve before gaze, then again after gaze
	# whenever diveBlend>0. Head is aimed independently of body travel/banking.
	# Gaze changes rotation only, so the source's pre-gaze floor translation
	# cannot affect the final solve. Avoid that redundant scan for a real dive.
	var offset := -_minimum_skin(rotation) if dive <= 0.0 else 0.0
	var head: int = _names.head
	var parent_q := (Basis(rotation) * (_to_motion * _global[_parents[head]]).basis).get_rotation_quaternion()
	var desired := Quaternion(Vector3.UP, aim_yaw - root_yaw) * Quaternion(Vector3.RIGHT, -clampf(aim_pitch, -1.28, 1.28)) * _head_rest
	pose[head].basis = Basis((parent_q.inverse() * desired).normalized()) * Basis.from_scale(_rest[head].basis.get_scale())
	_compose(pose)
	if dive > 0.0:
		offset = -_minimum_skin(rotation)
	return {"valid": true, "active": true, "poses": pose, "visual_rotation": rotation.normalized(), "visual_offset": Vector3(0.0, offset, 0.0),
		"progress": p, "dive_blend": dive, "authority_epoch": _epoch, "qualification": "unarmed source pose only; host owns physical sweeps/contact, weapon IK absent"}

func _rotate(pose: Array[Transform3D], name: String, x: float, z: float = 0.0) -> void:
	var id: int = _names[name]
	var q := _rest[id].basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, x) * Quaternion(Vector3.BACK, z)
	pose[id].basis = Basis(q.normalized()) * Basis.from_scale(_rest[id].basis.get_scale())

func _compose(pose: Array[Transform3D]) -> void:
	for i in range(pose.size()):
		_global[i] = pose[i] if _parents[i] < 0 else _global[_parents[i]] * pose[i]

func _minimum_skin(rotation: Quaternion) -> float:
	var lowest := INF
	var frame := Transform3D(Basis(rotation), Vector3.ZERO) * _to_motion
	for bone in range(_rest.size()):
		var transform := frame * _global[bone]
		_skin_axes[bone] = Vector3(transform.basis.x.y, transform.basis.y.y, transform.basis.z.y)
		_skin_origins[bone] = transform.origin.y
	for group in range(_rigid_bones.size()):
		var bone := _rigid_bones[group]
		var axis := _skin_axes[bone]
		var origin := _skin_origins[bone]
		for point: Vector3 in _rigid_points[group]:
			lowest = minf(lowest, axis.dot(point) + origin)
	var first := 0
	for end: int in _mixed_ends:
		var y := 0.0
		for at in range(first, end):
			var bone := _mixed_bones[at]
			y += _skin_axes[bone].dot(_mixed_points[at]) + _skin_origins[bone] * _mixed_weights[at]
		lowest = minf(lowest, y)
		first = end
	return lowest

func _support_hull(points: PackedVector3Array) -> PackedVector3Array:
	# Small/coplanar groups retain exact points. AABB volume avoids degenerate
	# physics hull requests; the input itself is always a valid support set.
	if points.size() < 12:
		return points
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		bounds = bounds.expand(point)
	if bounds.size.x * bounds.size.y * bounds.size.z < 0.000000001:
		return points
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var hull_mesh := shape.get_debug_mesh()
	var unique: Dictionary = {}
	var hull := PackedVector3Array()
	for surface in range(hull_mesh.get_surface_count()):
		var hull_points: PackedVector3Array = hull_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in hull_points:
			if not unique.has(point):
				unique[point] = true
				hull.append(point)
	return hull if not hull.is_empty() else points

func reset() -> void:
	_epoch = -1

func get_status() -> Dictionary:
	var support_points := 0
	for points: PackedVector3Array in _rigid_points:
		support_points += points.size()
	return {"ready": _ready, "authority_epoch": _epoch, "source_vertices": _source_vertices, "rigid_hull_points": support_points, "weighted_vertices": _weighted_count, "weighted_support_points": _weighted_support_count, "weighted_groups": _weighted_group_count, "unique_weighted_vertices": _mixed_ends.size(), "packed_influences": _mixed_bones.size(), "runtime_integrated": false}
