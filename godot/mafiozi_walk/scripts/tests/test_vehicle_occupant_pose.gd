extends SceneTree
const Pose = preload("res://scripts/vehicle_visual/vehicle_occupant_pose.gd")
const Player = preload("res://scripts/preview_player.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 30: failures.append(label)
func vec(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])
func quat(a: Array) -> Quaternion: return Quaternion(a[0], a[1], a[2], a[3]).normalized()
func q_error(a: Quaternion, b: Quaternion) -> float:
	return minf(Vector4(a.x-b.x,a.y-b.y,a.z-b.z,a.w-b.w).length(), Vector4(a.x+b.x,a.y+b.y,a.z+b.z,a.w+b.w).length())
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/vehicle_occupant_pose_oracle.json"))
	var player := Player.new(); root.add_child(player); player.set_physics_process(false)
	var rig: Skeleton3D = player.get("_pose_skeleton"); var motion: Node3D = player.get("_pose_motion")
	var rest: Array[Transform3D] = player.get("_locomotion").get("_rest_poses")
	var component := Pose.new()
	check(component.configure(rig, motion, rest, player.get("_model_scale")), "actual imported player rest configured")
	var maximum_rotation := 0.0; var maximum_offset := 0.0; var maximum_head := 0.0
	var timing: Array = []; var epoch := 0
	var original_player_position := player.position
	var latest: Dictionary = {}
	for trace: Dictionary in data.traces:
		epoch += 1
		for frame: Dictionary in trace.frames:
			var input: Dictionary = frame.input.duplicate(true)
			for key: String in ["doorGrip", "steering_left", "steering_right"]:
				if input.has(key): input[key] = vec(input[key])
			var started := Time.get_ticks_usec()
			var selected: Dictionary = component.sample(trace.seat, input, Transform3D.IDENTITY, epoch)
			timing.append(Time.get_ticks_usec() - started)
			check(selected.get("valid", false), "valid " + trace.seat.id + ":" + input.label)
			if not selected.get("valid", false): continue
			latest = selected
			maximum_head = maxf(maximum_head, absf(selected.head_yaw - frame.head_yaw))
			check(absf(selected.head_yaw - frame.head_yaw) < .000001, "source steering smoothing call count")
			for name: String in frame.rotations:
				var bone := rig.find_bone(name)
				var actual: Transform3D = selected.poses[bone]
				var error := q_error(actual.basis.get_rotation_quaternion(), quat(frame.rotations[name]))
				maximum_rotation = maxf(maximum_rotation, error)
				check(error < .0003, "JS rotation " + trace.seat.id + ":" + input.label + ":" + name + " error=" + str(error))
				check(actual.origin.distance_to(rest[bone].origin) < .000001 and actual.basis.get_scale().distance_to(rest[bone].basis.get_scale()) < .00001, "bone rest position/scale preserved")
			var offset_error: float = selected.visual_offset.distance_to(vec(frame.visual_offset))
			maximum_offset = maxf(maximum_offset, offset_error)
			check(offset_error < .00005 and q_error(selected.visual_rotation, quat(frame.visual_rotation)) < .000001, "source hip pivot/recline")
			check(component.apply(selected), "native skeleton apply")
	check(player.position == original_player_position, "pose never changes physical actor position")
	check(not component.sample({}, {}).get("valid", false), "missing seat denied")
	check(not component.sample(data.traces[0].seat, {"fold": NAN}).get("valid", false), "nonfinite pose denied")
	check(not component.sample(data.traces[0].seat, {"pose": "wrong"}).get("valid", false), "malformed transition denied")
	check(not component.sample(data.traces[0].seat, {}, "wrong").get("valid", false), "malformed root frame denied")
	check(not component.sample(data.traces[0].seat, {"steering_left": Vector3.INF}).get("valid", false), "nonfinite grip denied")
	check(not component.sample(data.traces[0].seat, {"recline": 100}).get("valid", false), "oversized recline denied")
	var bad: Dictionary = latest.duplicate(true)
	var bad_poses: Array = []
	for pose: Transform3D in latest.poses: bad_poses.append(pose)
	bad_poses[0] = "bad"; bad.poses = bad_poses
	check(not component.apply(bad), "bad output rejected atomically before native writes")
	component.reset(500)
	check(not component.apply(latest), "old lifetime pose refused")
	# Repeat actual seated IK workload; no render/GPU measurement claim.
	var full: Dictionary = data.traces[0].frames[12].input.duplicate(true)
	for key: String in ["steering_left", "steering_right"]: full[key] = vec(full[key])
	var steady: Array = []
	for i in range(600):
		var started := Time.get_ticks_usec()
		var selected: Dictionary = component.sample(data.traces[0].seat, full, Transform3D.IDENTITY, 500)
		component.apply(selected)
		if i >= 100: steady.append(Time.get_ticks_usec() - started)
	steady.sort(); timing.sort()
	component.dispose(); check(not component.apply(latest), "disposed pose refused")
	player.free()
	print(JSON.stringify({"checks": checks, "failures": failures, "source_frames": 56, "max_quaternion_error": maximum_rotation, "max_pivot_metres": maximum_offset, "max_head_yaw": maximum_head, "source_pose_us": {"p50": timing[timing.size()/2], "p95": timing[int(timing.size()*.95)], "max": timing[-1]}, "seated_sample_apply_us": {"n": steady.size(), "p50": steady[steady.size()/2], "p95": steady[int(steady.size()*.95)], "max": steady[-1]}, "scope": "actual imported skeleton + unmodified JS factory oracle, headless CPU only"}))
	quit(0 if failures.is_empty() else 1)
func _initialize() -> void: run.call_deferred()
