extends SceneTree

const PlayerController = preload("res://scripts/preview_player.gd")
const Locomotion = preload("res://scripts/preview_locomotion.gd")
const Airborne = preload("res://scripts/preview_airborne.gd")
var _player: PlayerController
var _motion: Node3D
var _hero: Node3D
var _skeleton: Skeleton3D
var _locomotion: Locomotion
var _air: Airborne
var _rest: Array[Transform3D] = []
var _meshes: Array[Dictionary] = []
var _errors: Array[String] = []
var _last_skin: PackedVector3Array = PackedVector3Array()
var _floor_min: float = INF
var _floor_max: float = -INF
var _max_skin_step: float = 0.0
var _max_first_landing_step: float = 0.0
var _all_finite: bool = true
var _pure: bool = true
var _proportions: bool = true
var _costs: Array[int] = []
var _samples: int = 0
var _cycles: int = 0
var _rest_offset: Vector3
var _minimum_state: Dictionary = {}
var _maximum_state: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_player = PlayerController.new()
	_player.position = Vector3(5.0, 1.0, 7.0)
	_player.rotation.y = 0.8
	root.add_child(_player)
	_player.set_physics_process(false)
	_motion = _player.get_node("VisualHeading/LocomotionOffset") as Node3D
	_hero = _motion.get_child(0).get_child(0) as Node3D
	_skeleton = _player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_locomotion = _player.get("_locomotion") as Locomotion
	_rest = _capture()
	_rest_offset = _motion.position
	_air = Airborne.new()
	_check(_air.bind(_hero, _motion), "actual rig binds")
	_check(_same(_rest, _capture()) and _motion.position == _rest_offset, "bind is read-only")
	_collect_meshes()
	var original_root: Transform3D = _player.transform
	var source_vertices: int = 0
	for mesh: Dictionary in _meshes:
		source_vertices += (mesh["vertices"] as PackedVector3Array).size()
	_check(source_vertices == 8338, "all authored skinned colour vertices are tested")
	var endpoint_zero: Array[Transform3D] = _air.call("_canonical_pose", 0.0)
	var endpoint_one: Array[Transform3D] = _air.call("_canonical_pose", 1.0)
	_check(_same(_rest, endpoint_zero) and _same(_rest, endpoint_one), "ordinary jump source endpoints are rest")
	var source_middle: Array[Transform3D] = _air.call("_canonical_pose", 0.32)
	var thigh: int = _skeleton.find_bone("thigh_l")
	var upperarm: int = _skeleton.find_bone("upperarm_l")
	var expected_thigh: Quaternion = _rest[thigh].basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -0.65)
	var expected_arm: Quaternion = _rest[upperarm].basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -0.65) * Quaternion(Vector3.BACK, 0.15)
	_check(source_middle[thigh].basis.get_rotation_quaternion().angle_to(expected_thigh) < 0.0001, "source apex thigh coefficient -0.65 retained")
	_check(source_middle[upperarm].basis.get_rotation_quaternion().angle_to(expected_arm) < 0.0001, "source XYZ arm rotation and spread retained")
	var cycle_count: int = 2 if OS.get_cmdline_user_args().has("--quick") else 20
	for cycle: int in range(cycle_count):
		var speed: float = 3.2 if cycle % 2 == 0 else 5.8
		for _frame: int in range(24):
			_step(1.0 / 60.0, true, 0.0, speed)
		for frame: int in range(64):
			_step(1.0 / 60.0, false, 5.2 - 9.8 * float(frame) / 60.0, speed)
		for _frame: int in range(32):
			_step(1.0 / 60.0, true, 0.0, speed)
		for _frame: int in range(80):
			_step(1.0 / 60.0, true, 0.0, 0.0)
		_check(_same(_rest, _capture()), "cycle " + str(cycle) + " returns to exact idle bone pose")
		_check(_motion.position.distance_to(_rest_offset) < 0.00001, "cycle " + str(cycle) + " restores idle visual offset")
		_cycles += 1
	_check(_all_finite, "all actual skin points and bones remain finite")
	_check(_proportions, "bone translations/scales and root remain unchanged")
	_check(_pure, "sampler never changes live skeleton or visual offset")
	_check(_player.transform == original_root, "body transform untouched")
	_check(_floor_min > -0.001 and _floor_max < 0.001, "whole actual skin has continuous sole contact relative to body foot plane")
	_check(_max_first_landing_step < 0.0001, "first physical landing frame exactly carries air pose")
	_check(_max_skin_step < 0.13, "walk-air-land actual skin has no discontinuous frame jump")
	_test_authority_and_time()
	_test_rest_offset()
	_costs.sort()
	print(JSON.stringify({"passed": _errors.is_empty(), "cycles": _cycles, "skin_samples": _samples,
		"vertices_per_sample": source_vertices, "minimum_skin_y_m": _floor_min, "maximum_lowest_skin_y_m": _floor_max,
		"max_frame_skin_step_m": _max_skin_step, "first_landing_skin_step_m": _max_first_landing_step,
		"sample_cpu_p50_us": _costs[_costs.size() / 2], "sample_cpu_p95_us": _costs[int(_costs.size() * 0.95)],
		"binding": _air.get_status(), "scope": "headless actual skin sampler; no runtime hook or LIVE/FPS acceptance"}))
	print(JSON.stringify({"minimum_state": _minimum_state, "maximum_state": _maximum_state}))
	for error: String in _errors:
		push_error(error)
	quit(0 if _errors.is_empty() else 1)


func _step(dt: float, grounded: bool, vy: float, speed: float) -> void:
	# A single test owner constructs a fresh locomotion target, samples airborne,
	# then applies exactly one final result. Never sample from the last air pose.
	_apply(_rest, _rest_offset)
	_locomotion.update_pose(dt, Vector3(speed, 0.0, 0.0), grounded)
	var base: Array[Transform3D] = _capture()
	var offset: Vector3 = _motion.position
	var before_mode: String = str(_air.get_status().get("phase"))
	var begin: int = Time.get_ticks_usec()
	var result: Dictionary = _air.sample(dt, grounded, vy, base, offset, &"on_foot", 7)
	_costs.append(Time.get_ticks_usec() - begin)
	_pure = _pure and _same(base, _capture()) and _motion.position == offset
	if not bool(result.get("valid", false)):
		_errors.append("valid actual base rejected")
		return
	_apply(result["poses"], result["visual_offset"])
	for bone: int in range(_rest.size()):
		var pose: Transform3D = _skeleton.get_bone_pose(bone)
		_all_finite = _all_finite and pose.is_finite()
		_proportions = _proportions and pose.origin.distance_to(_rest[bone].origin) < 0.00001 and pose.basis.get_scale().distance_to(_rest[bone].basis.get_scale()) < 0.00001
	var skin: PackedVector3Array = _skin()
	var low: float = INF
	var low_vertex: int = -1
	var step_distance: float = 0.0
	for vertex: int in range(skin.size()):
		_all_finite = _all_finite and skin[vertex].is_finite()
		if skin[vertex].y < low:
			low = skin[vertex].y
			low_vertex = vertex
		if _last_skin.size() == skin.size():
			step_distance = maxf(step_distance, skin[vertex].distance_to(_last_skin[vertex]))
	if low < _floor_min:
		_minimum_state = {"phase": result.get("phase"), "progress": result.get("progress"), "air_age": result.get("airborne_age"), "vertex": low_vertex, "height": low, "offset": str(_motion.position)}
		_floor_min = low
	if low > _floor_max:
		_maximum_state = {"phase": result.get("phase"), "progress": result.get("progress"), "air_age": result.get("airborne_age"), "vertex": low_vertex, "height": low, "offset": str(_motion.position)}
		_floor_max = low
	_max_skin_step = maxf(_max_skin_step, step_distance)
	if grounded and before_mode in ["ascent", "apex", "fall"]:
		_max_first_landing_step = maxf(_max_first_landing_step, step_distance)
	_last_skin = skin
	_samples += 1


func _test_authority_and_time() -> void:
	_apply(_rest, _rest_offset)
	_air.reset()
	_air.sample(0.0, false, 5.2, _rest, _rest_offset, &"on_foot", 9)
	var after_large_dt: Dictionary = _air.sample(0.25, false, 2.75, _rest, _rest_offset, &"on_foot", 9)
	_check(absf(float(after_large_dt["airborne_age"]) - 0.25) < 0.00001, "elapsed time above .1 seconds is not truncated")
	var repeated: Dictionary = _air.sample(0.0, false, 2.75, _rest, _rest_offset, &"on_foot", 9)
	_check(_same(after_large_dt["poses"], repeated["poses"]), "zero delta with identical physical state is pose-idempotent")
	_air.sample(0.0, true, 0.0, _rest, _rest_offset, &"on_foot", 9)
	var recovered: Dictionary = _air.sample(0.6, true, 0.0, _rest, _rest_offset, &"on_foot", 9)
	_check(not bool(recovered["active"]) and _same(recovered["poses"], _rest), "large grounded delta completes recovery without sticky crouch")
	_air.sample(0.1, false, 4.0, _rest, _rest_offset, &"on_foot", 9)
	var external: Array[Transform3D] = _rest.duplicate()
	var chest: int = _skeleton.find_bone("chest")
	external[chest] = Transform3D(Basis(_rest[chest].basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, 0.4)) * Basis.from_scale(_rest[chest].basis.get_scale()), _rest[chest].origin)
	var external_offset: Vector3 = Vector3(0.03, 0.06, -0.02)
	var blocked: Dictionary = _air.sample(0.1, false, 2.0, external, external_offset, &"vehicle", 9)
	_check(not bool(blocked["active"]) and _same(blocked["poses"], external) and blocked["visual_offset"] == external_offset, "external authority passes its pose through unchanged")
	var fresh: Dictionary = _air.sample(0.0, true, 0.0, _rest, _rest_offset, &"on_foot", 10)
	_check(not bool(fresh["active"]) and _same(fresh["poses"], _rest), "new authority epoch cannot resurrect an old landing")
	var invalid: Dictionary = _air.sample(NAN, false, INF, _rest, _rest_offset, &"on_foot", 10)
	_check(not bool(invalid.get("valid", true)) and _same(_capture(), _rest), "non-finite input fails closed without writing live rig")
	_air.reset()
	_check(_same(_capture(), _rest) and _motion.position == _rest_offset, "reset changes state only; host owns final pose")


func _test_rest_offset() -> void:
	var authored_offset: Vector3 = Vector3(0.07, 0.11, -0.03)
	_apply(_rest, authored_offset)
	var shifted: Airborne = Airborne.new()
	_check(shifted.bind(_hero, _motion), "actual rig binds with a nonzero authored visual offset")
	shifted.sample(0.0, false, 5.2, _rest, authored_offset, &"on_foot", 1)
	var pose: Dictionary = shifted.sample(0.3, false, 2.0, _rest, authored_offset, &"on_foot", 1)
	_apply(pose["poses"], pose["visual_offset"])
	var minimum: float = INF
	for point: Vector3 in _skin():
		minimum = minf(minimum, point.y)
	_check(absf(minimum - authored_offset.y) < 0.001, "nonzero authored foot-plane offset is preserved")
	shifted.reset()
	var idle: Dictionary = shifted.sample(0.0, true, 0.0, _rest, authored_offset, &"on_foot", 2)
	_check(idle["visual_offset"] == authored_offset and _same(idle["poses"], _rest), "rest visual offset and every bone recover exactly")
	_apply(_rest, _rest_offset)


func _capture() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone: int in range(_skeleton.get_bone_count()):
		result.append(_skeleton.get_bone_pose(bone))
	return result


func _apply(poses: Array[Transform3D], offset: Vector3) -> void:
	for bone: int in range(poses.size()):
		_skeleton.set_bone_pose(bone, poses[bone])
	_motion.position = offset


func _same(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
	if a.size() != b.size():
		return false
	for bone: int in range(a.size()):
		if not a[bone].is_equal_approx(b[bone]):
			return false
	return true


func _collect_meshes() -> void:
	for node: Node in _hero.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin == null:
			continue
		var bone_ids: PackedInt32Array = PackedInt32Array()
		var binds: Array[Transform3D] = []
		for bind: int in range(mesh.skin.get_bind_count()):
			bone_ids.append(_skeleton.find_bone(str(mesh.skin.get_bind_name(bind))))
			binds.append(mesh.skin.get_bind_pose(bind))
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			_meshes.append({"vertices": arrays[Mesh.ARRAY_VERTEX], "joints": arrays[Mesh.ARRAY_BONES], "weights": arrays[Mesh.ARRAY_WEIGHTS], "bone_ids": bone_ids, "binds": binds})


func _skin() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var to_body: Transform3D = _player.global_transform.affine_inverse() * _skeleton.global_transform
	for mesh: Dictionary in _meshes:
		var ids: PackedInt32Array = mesh["bone_ids"]
		var binds: Array[Transform3D] = mesh["binds"]
		var transforms: Array[Transform3D] = []
		for bind: int in range(ids.size()):
			transforms.append(to_body * _skeleton.get_bone_global_pose(ids[bind]) * binds[bind])
		var vertices: PackedVector3Array = mesh["vertices"]
		var joints: PackedInt32Array = mesh["joints"]
		var weights: PackedFloat32Array = mesh["weights"]
		var count: int = joints.size() / vertices.size()
		for vertex: int in range(vertices.size()):
			var point: Vector3 = Vector3.ZERO
			for influence: int in range(count):
				var at: int = vertex * count + influence
				if weights[at] > 0.0:
					point += (transforms[joints[at]] * vertices[vertex]) * weights[at]
			points.append(point)
	return points


func _check(passed: bool, message: String) -> void:
	if not passed:
		_errors.append(message)
