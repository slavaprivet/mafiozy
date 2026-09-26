extends SceneTree
const Pose = preload("res://scripts/vehicle_visual/vehicle_exit_pose.gd")
const Player = preload("res://scripts/preview_player.gd")
var checks := 0
var failures: Array[String] = []
var floor_id := "flat"
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25: failures.append(label)
func support(x: float, z: float) -> float:
	if floor_id == "slope": return .3 * x + .18 * z
	if floor_id == "step": return .23 if x > 13.17 else 0.0
	return 0.0
func invalid_support(_x: float, _z: float) -> float: return NAN
func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func quat(a: Array) -> Quaternion: return Quaternion(a[0],a[1],a[2],a[3]).normalized()
func qerror(a: Quaternion,b: Quaternion) -> float: return minf(Vector4(a.x-b.x,a.y-b.y,a.z-b.z,a.w-b.w).length(),Vector4(a.x+b.x,a.y+b.y,a.z+b.z,a.w+b.w).length())
func run() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/vehicle_exit_pose_oracle.json"))
	var player := Player.new(); root.add_child(player); player.set_physics_process(false)
	var rig: Skeleton3D = player._pose_skeleton
	var component := Pose.new(); var started := Time.get_ticks_usec()
	check(component.configure(rig,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._pose_motion),"actual canonical rig/skin configured")
	var bind_us := Time.get_ticks_usec()-started
	var maximum_offset := 0.0;var maximum_rotation := 0.0;var maximum_height := 0.0;var maximum_floor_calls := 0
	var timings: Array = [];var flat_times: Array = []
	var original_position := player.position
	for frame: Dictionary in oracle.frames:
		floor_id = frame.floor_id
		var world := Transform3D(Basis(Vector3.UP,frame.root_yaw),vec(frame.root_position))
		started = Time.get_ticks_usec()
		var selected: Dictionary = component.sample(frame.progress,frame.rolls,Callable() if floor_id=="none" else support,world,1)
		var cost := Time.get_ticks_usec()-started
		if floor_id == "none": flat_times.append(cost)
		else: timings.append(cost)
		check(selected.get("valid",false),"source frame valid "+str(frame.progress)+":"+floor_id)
		if not selected.get("valid",false): continue
		var offset_error: float = selected.visual_offset.distance_to(vec(frame.visual_offset))
		maximum_offset=maxf(maximum_offset,offset_error)
		check(offset_error < .00015,"source combined scaled/pivot grounding "+str(frame.progress)+":"+floor_id+" err="+str(offset_error))
		check(qerror(selected.visual_rotation,quat(frame.visual_rotation))<.000001,"source tumble rotation")
		var height_error: float = absf(selected.skin_height-frame.skin_height)
		maximum_height=maxf(maximum_height,height_error)
		check(height_error < .0001,"actual skin height")
		maximum_floor_calls=maxi(maximum_floor_calls,selected.floor_calls)
		check(selected.floor_calls<=289,"bounded actual floor provider queries")
		for name: String in frame.rotations:
			var index := rig.find_bone(name);var pose: Transform3D=selected.poses[index]
			var error := qerror(pose.basis.get_rotation_quaternion(),quat(frame.rotations[name]));maximum_rotation=maxf(maximum_rotation,error)
			check(error<.00001,"source tuck local bone "+name)
			check(pose.origin.distance_to(player._locomotion._rest_poses[index].origin)<.000001,"bone translations preserved")
		player._apply_selected_pose(selected)
		if frame.progress == .3: check(selected.skin_height < 1.6,"mid-roll is actually tucked/low, not standing spin")
	check(player.position==original_position,"pose never teleports physical root")
	check(not component.sample(NAN).get("valid",false),"nonfinite progress rejected")
	check(not component.sample(.3,100).get("valid",false),"unbounded rolls rejected")
	check(not component.sample(.3,1,invalid_support).get("valid",false),"unavailable floor rejected")
	for trace: Dictionary in oracle.timelines:
		check(trace.rows[-1].done and is_equal_approx(trace.rows[-1].elapsed,1.7),"actual source tumble timeline1.7 seconds")
		check(trace.rows[0].rolls==(2 if trace.speed>14 else 1),"source speed selects one/two rolls")
	timings.sort();flat_times.sort()
	var report := {"checks":checks,"failures":failures,"source_frames":oracle.frames.size(),"maximum_offset_metres":maximum_offset,"maximum_quaternion_error":maximum_rotation,"maximum_height_error":maximum_height,"maximum_floor_calls":maximum_floor_calls,"bind_us":bind_us,"skin":component.diagnostics(),"full_floor_sample_us":{"p50":timings[timings.size()/2],"p95":timings[int(timings.size()*.95)],"max":timings[-1]},"root_plane_only_sample_us":{"p50":flat_times[flat_times.size()/2],"p95":flat_times[int(flat_times.size()*.95)],"max":flat_times[-1]}}
	component.dispose();player.free();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _initialize() -> void: run.call_deferred()
