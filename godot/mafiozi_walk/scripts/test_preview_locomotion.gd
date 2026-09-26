extends SceneTree

const PlayerController = preload("res://scripts/preview_player.gd")
const LocomotionPose = preload("res://scripts/preview_locomotion.gd")
var _failures: Array[String] = []
var _boots: Array[Dictionary] = []
var _rest: Array[Transform3D] = []
var _skeleton: Skeleton3D
var _player: PlayerController
var _pose: LocomotionPose
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_player = PlayerController.new()
	_player.position = Vector3(13.0, 2.0, 7.0)
	_player.rotation.y = 0.6
	root.add_child(_player)
	_player.set_physics_process(false)
	_pose = _player.get("_locomotion") as LocomotionPose
	_skeleton = _player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var original_root: Transform3D = _player.transform
	var pose_status: Dictionary = _pose.get_status()
	_check(bool(pose_status.get("ready", false)), "actual canonical skeleton binds")
	_check(int(pose_status.get("support_source_vertices", 0)) == 734, "actual 734 rigid boot vertices found")
	_check(int(pose_status.get("support_hull_vertices", 0)) * 2 < int(pose_status.get("support_source_vertices", 0)), "cached boot hull retains fewer than half of the source points")
	for bone: int in range(_skeleton.get_bone_count()):
		_rest.append(_skeleton.get_bone_pose(bone))
	_collect_full_boot_geometry()
	var idle_head_y: float = _skeleton.get_bone_global_pose(_skeleton.find_bone("head")).origin.y
	var min_floor: float = INF
	var max_floor: float = -INF
	var max_contact_step: float = 0.0
	var last_contact: float = 0.0
	var max_skin_step: float = 0.0
	var last_samples: PackedVector3Array = PackedVector3Array()
	var finite_bones: bool = true
	var unchanged_bone_size: bool = true
	var costs: Array[int] = []
	for frame: int in range(720):
		var speed: float = 3.2 if frame < 360 else 5.8
		var started: int = Time.get_ticks_usec()
		_pose.update_pose(1.0 / 60.0, Vector3(0.0, 0.0, -speed), true)
		costs.append(Time.get_ticks_usec() - started)
		var samples: PackedVector3Array = _skin_all_boot_vertices()
		var floor_y: float = INF
		for vertex: int in range(samples.size()):
			floor_y = minf(floor_y, samples[vertex].y)
			if last_samples.size() == samples.size():
				max_skin_step = maxf(max_skin_step, samples[vertex].distance_to(last_samples[vertex]))
		last_samples = samples
		min_floor = minf(min_floor, floor_y)
		max_floor = maxf(max_floor, floor_y)
		var contact: float = float(_pose.get_status().get("contact_offset_m", 0.0))
		max_contact_step = maxf(max_contact_step, absf(contact - last_contact))
		last_contact = contact
		for bone: int in range(_rest.size()):
			var local_pose: Transform3D = _skeleton.get_bone_pose(bone)
			finite_bones = finite_bones and local_pose.is_finite()
			unchanged_bone_size = unchanged_bone_size and local_pose.origin.distance_to(_rest[bone].origin) < 0.00001
			unchanged_bone_size = unchanged_bone_size and local_pose.basis.get_scale().distance_to(_rest[bone].basis.get_scale()) < 0.00001
	_check(min_floor > -0.001 and max_floor < 0.001, "full actual skinned soles stay on flat ground")
	_check(max_skin_step < 0.10, "real boot skin moves continuously across walk/run phases")
	_check(max_contact_step < 0.05, "visual ground correction has no frame-sized jump")
	_check(finite_bones, "all animated bone poses remain finite")
	_check(unchanged_bone_size, "no bone translation or scale distortion")
	_check(_player.transform == original_root, "pose leaves physics root position and heading unchanged")
	_check(not _skeleton.get_bone_pose(_skeleton.find_bone("thigh_l")).is_equal_approx(_rest[_skeleton.find_bone("thigh_l")]), "actual thigh animates")
	_check(not _skeleton.get_bone_pose(_skeleton.find_bone("upperarm_r")).is_equal_approx(_rest[_skeleton.find_bone("upperarm_r")]), "actual arm counter-swings")
	for _frame: int in range(180):
		_pose.update_pose(1.0 / 60.0, Vector3.ZERO, true)
	_check(float(_pose.get_status().get("gait", -1.0)) == 0.0, "stopped motion returns gait exactly to zero")
	_check(_matches_rest(), "idle restores every actual rest pose without accumulated bend")
	_check(absf(_skeleton.get_bone_global_pose(_skeleton.find_bone("head")).origin.y - idle_head_y) < 0.00001, "idle head height has no persistent crouch")
	for rate: int in [30, 60, 120]:
		for speed: float in [3.2, 5.8]:
			_pose.reset_pose()
			for _frame: int in range(rate):
				_pose.update_pose(1.0 / float(rate), Vector3(speed, 0.0, 0.0), true)
			var expected_phase: float = fposmod(speed * 2.3, TAU)
			_check(absf(float(_pose.get_status().get("phase", -1.0)) - expected_phase) < 0.00001, "phase follows actual distance at " + str(rate) + " Hz / " + str(speed) + " mps")
	_pose.reset_pose()
	for _frame: int in range(120):
		_pose.update_pose(1.0 / 60.0, Vector3(5.8, 0.0, 0.0), false)
	_check(_matches_rest(), "airborne horizontal speed cannot start ground walking")
	_pose.update_pose(0.1, Vector3(3.2, 0.0, 0.0), true)
	_pose.update_pose(0.1, Vector3(NAN, 0.0, INF), true)
	_check(is_finite(float(_pose.get_status().get("phase", NAN))), "invalid movement sample cannot poison phase")
	_pose.reset_pose()
	_check(_matches_rest(), "explicit reset restores all bones")
	costs.sort()
	print(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks,
		"source_boot_vertices": pose_status.get("support_source_vertices"),
		"cached_hull_vertices": pose_status.get("support_hull_vertices"),
		"full_skin_floor_min_m": min_floor, "full_skin_floor_max_m": max_floor,
		"max_skin_step_m_at_60hz": max_skin_step, "max_contact_step_m": max_contact_step,
		"update_cpu_p50_us": costs[costs.size() / 2], "update_cpu_p95_us": costs[int(costs.size() * 0.95)],
		"qualification": "headless CPU/physics/actual-skin checks; LIVE and FPS still separate"}))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _collect_full_boot_geometry() -> void:
	for node: Node in _player.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin == null:
			continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count: int = joints.size() / positions.size()
			for vertex: int in range(positions.size()):
				for influence: int in range(count):
					var at: int = vertex * count + influence
					if weights[at] < 0.9999:
						continue
					var bind_index: int = joints[at]
					var bone: int = _skeleton.find_bone(str(mesh.skin.get_bind_name(bind_index)))
					if _skeleton.get_bone_name(bone) not in ["foot_l", "foot_r"]:
						continue
					_boots.append({"bone": bone, "bind_pose": mesh.skin.get_bind_pose(bind_index), "point": positions[vertex]})


func _skin_all_boot_vertices() -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var skeleton_to_body: Transform3D = _player.global_transform.affine_inverse() * _skeleton.global_transform
	for row: Dictionary in _boots:
		var transform: Transform3D = skeleton_to_body * _skeleton.get_bone_global_pose(int(row["bone"])) * (row["bind_pose"] as Transform3D)
		result.append(transform * (row["point"] as Vector3))
	return result


func _matches_rest() -> bool:
	for bone: int in range(_rest.size()):
		if not _skeleton.get_bone_pose(bone).is_equal_approx(_rest[bone]):
			return false
	return true


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
