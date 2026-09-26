extends SceneTree
## Native programmatic-input QA. Only the coordinator launches this with GPU.
## Godot --path godot/mafiozi_walk --script ../../tools/godot/preview_motion_qa.gd
## Optional user arg: -- --motion-output-dir=C:/absolute/output/directory
## No --fixed-fps: frame intervals use the real wall clock. No automatic quit.

const PlayerController = preload("res://scripts/preview_player.gd")
const WARMUP_FRAMES: int = 240
const MEASURE_FRAMES: int = 240
const BONE_NAMES: PackedStringArray = ["pelvis", "head", "chest", "thigh_l", "shin_l", "foot_l", "upperarm_l", "forearm_l", "thigh_r", "shin_r", "foot_r", "upperarm_r", "forearm_r"]
const INPUT_ACTIONS: Array[StringName] = [&"preview_move_forward", &"preview_move_back", &"preview_move_left", &"preview_move_right", &"preview_run", &"preview_jump"]

var _main: Node3D
var _player: PlayerController
var _skeleton: Skeleton3D
var _bone_indices: PackedInt32Array = PackedInt32Array()
var _output_dir: String
var _phase: String = "startup"
var _report: Dictionary = {}
var _traces: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _errors: Array[String] = []
var _started_usec: int = 0
var _last_trace_usec: int = 0
var _last_position: Vector3
var _initial_position: Vector3
var _distance: float = 0.0
var _direction_action: StringName = &"preview_move_forward"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	_output_dir = ProjectSettings.globalize_path("res://../../outputs/godot_motion26").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--motion-output-dir="):
			_output_dir = ProjectSettings.globalize_path(argument.trim_prefix("--motion-output-dir=")).simplify_path()
	_report = {"schema": "mafiozi.godot.programmatic-motion-qa/v1", "status": "running",
		"input_source": "Godot Input.action_press/action_release; not physical keyboard or desktop automation",
		"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(),
		"started_utc": Time.get_datetime_string_from_system(true), "screenshots_outside_baseline": true,
		"scope": "Actual small preview scene, no NPC/traffic; not full-city FPS or full animation acceptance"}
	if DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		_fail("Cannot create output directory: " + _output_dir)
		_finish(false)
		return
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Actual main scene could not be loaded")
		_finish(false)
		return
	_main = scene.instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	var deadline: int = Time.get_ticks_usec() + 30000000
	while not bool(_main.get("preview_ready")):
		var validation_errors: PackedStringArray = _main.get("validation_errors")
		if not validation_errors.is_empty() or Time.get_ticks_usec() > deadline:
			_fail("Preview readiness failed: " + "; ".join(validation_errors))
			_finish(false)
			return
		await process_frame
	_player = _main.get("_player") as PlayerController
	if _player == null:
		_fail("Actual main did not expose its existing preview player")
		_finish(false)
		return
	_release_inputs()
	_player.set_mouse_captured(false)
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--fixed-fps"):
		_fail("Native wall-clock QA requires a visible renderer and no --fixed-fps")
		_finish(false)
		return
	var skeletons: Array[Node] = _player.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		_fail("Actual player must contain one canonical Skeleton3D")
		_finish(false)
		return
	_skeleton = skeletons[0] as Skeleton3D
	for bone_name: String in BONE_NAMES:
		var bone: int = _skeleton.find_bone(bone_name)
		if bone < 0:
			_fail("Required trace bone missing: " + bone_name)
			_finish(false)
			return
		_bone_indices.append(bone)
	if not await _wait_for_floor(30, 10.0):
		_fail("Player did not settle on the original scene's physical floor")
		_finish(false)
		return
	_initial_position = _player.global_position
	_last_position = _initial_position
	_report["original_spawn_position_m"] = _v3(_initial_position)
	_report["viewport_size"] = [root.size.x, root.size.y]
	_report["baseline_before_state"] = _state()
	_set_phase("stationary_warmup")
	for _frame: int in range(WARMUP_FRAMES):
		await process_frame
	_set_phase("stationary_wallclock_240")
	# No screenshots, bone tracing, console output or disk writes in this window.
	var intervals: Array[float] = []
	var previous_usec: int = Time.get_ticks_usec()
	var measure_start: int = previous_usec
	for _frame: int in range(MEASURE_FRAMES):
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append(float(now - previous_usec) / 1000.0)
		previous_usec = now
	var baseline: Dictionary = _interval_summary(intervals)
	baseline["wallclock_elapsed_ms"] = float(previous_usec - measure_start) / 1000.0
	baseline["warmup_frames"] = WARMUP_FRAMES
	baseline["stationary_distance_m"] = _player.global_position.distance_to(_initial_position)
	baseline["draw_calls_last_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	baseline["primitives_last_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	baseline["qualification"] = "Native small-scene stationary wall-clock intervals; no bone tracing/PNG in interval"
	_report["stationary_before"] = baseline
	_report["baseline_after_state"] = _state()
	_set_phase("before_motion")
	_record_trace()
	await _capture("01_idle_before")
	if not _select_clear_direction():
		_fail("No dry, physically clear straight corridor for the requested walk/run distance; body not relocated")
		_finish(false)
		return
	Input.action_press(_direction_action)
	if not await _phase_for("walk", 1.5):
		_finish(false)
		return
	await _capture("02_walk")
	Input.action_press(&"preview_run")
	if not await _phase_for("run", 1.0):
		_finish(false)
		return
	await _capture("03_run")
	_release_inputs()
	if not await _phase_for("idle_recovery", 2.0):
		_finish(false)
		return
	await _capture("04_idle_after")
	if not _player.is_on_floor():
		_fail("Jump phase refused because the actual player is not grounded")
		_finish(false)
		return
	_set_phase("jump")
	var jump_floor_y: float = _player.global_position.y
	var jump_peak_y: float = jump_floor_y
	var saw_airborne: bool = false
	var apex_captured: bool = false
	Input.action_press(&"preview_jump")
	await physics_frame
	await process_frame
	_record_trace()
	Input.action_release(&"preview_jump")
	var jump_deadline: int = Time.get_ticks_usec() + 8000000
	while Time.get_ticks_usec() < jump_deadline:
		await process_frame
		_record_trace()
		jump_peak_y = maxf(jump_peak_y, _player.global_position.y)
		if not _player.is_on_floor():
			saw_airborne = true
			if _player.velocity.y <= 0.0 and not apex_captured:
				apex_captured = true
				await _capture("05_jump_apex")
		elif saw_airborne:
			break
	_report["jump"] = {"became_airborne": saw_airborne, "apex_captured": apex_captured,
		"height_m": jump_peak_y - jump_floor_y, "landed": _player.is_on_floor(),
		"animation_limit": "Physical jump only; airborne combat/dive animation is not migrated"}
	_release_inputs()
	if not saw_airborne or not _player.is_on_floor():
		_fail("Programmatic jump did not produce a complete airborne/landing cycle")
		_finish(false)
		return
	if not await _phase_for("landed_settle", 0.6):
		_finish(false)
		return
	await _capture("06_landed")
	_finish(_errors.is_empty())


func _wait_for_floor(stable_frames: int, seconds: float) -> bool:
	var stable: int = 0
	var deadline: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await physics_frame
		await process_frame
		stable = stable + 1 if _player.is_on_floor() and _player.velocity.length() < 0.02 else 0
		if stable >= stable_frames:
			return true
	return false


func _select_clear_direction() -> bool:
	# Read-only clearance query; no body movement or scene/collision mutation.
	var actions: Array[StringName] = [&"preview_move_forward", &"preview_move_right", &"preview_move_left", &"preview_move_back"]
	var directions: Array[Vector3] = [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK]
	var collider: CollisionShape3D = _player.get_node("PlayerCapsule") as CollisionShape3D
	var capsule: CapsuleShape3D = collider.shape as CapsuleShape3D
	var world: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var origin: Vector3 = _player.global_position
	var candidates: Array[Dictionary] = []
	for index: int in range(actions.size()):
		var clear: float = 0.0
		for step: int in range(1, 27):
			var distance: float = float(step) * 0.5
			var at: Vector3 = origin + directions[index] * distance
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at - Vector3.UP * 0.5, 1, [_player.get_rid()])
			var hit: Dictionary = world.intersect_ray(ray)
			if hit.is_empty() or (hit["normal"] as Vector3).dot(Vector3.UP) < 0.98 or absf((hit["position"] as Vector3).y - origin.y) > 0.1:
				break
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, (hit["position"] as Vector3) + Vector3.UP * (capsule.height * 0.5 + 0.04))
			query.collision_mask = 1
			query.exclude = [_player.get_rid()]
			if not world.intersect_shape(query, 1).is_empty():
				break
			clear = distance
		candidates.append({"action": str(actions[index]), "direction": _v3(directions[index]), "clear_metres": clear})
		if clear >= 12.0:
			_direction_action = actions[index]
			_report["route"] = {"action": str(_direction_action), "clear_metres": clear, "candidates_checked": candidates,
				"source": "Original main spawn, read-only floor/capsule tests; no teleport or rotation write"}
			return true
	_report["route"] = {"accepted": false, "candidates_checked": candidates}
	return false


func _phase_for(label: String, seconds: float) -> bool:
	_set_phase(label)
	var deadline: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
		_record_trace()
		if not _errors.is_empty():
			_release_inputs()
			return false
		if not _player.global_position.is_finite() or _player.global_position.y < _initial_position.y - 0.25:
			_fail("Unexpected loss of dry ground during " + label)
			_release_inputs()
			return false
		if (label == "walk" or label == "run") and not _player.is_on_floor():
			_fail("Unexpected airborne movement during " + label + "; input released")
			_release_inputs()
			return false
	return true


func _set_phase(label: String) -> void:
	_phase = label
	_events.append({"type": "phase", "phase": label, "wallclock_ms": _elapsed_ms()})
	_last_trace_usec = 0
	if is_instance_valid(_player):
		_last_position = _player.global_position


func _record_trace() -> void:
	var now: int = Time.get_ticks_usec()
	var state: Dictionary = _state()
	var movement: Vector3 = _player.global_position - _last_position
	if _last_trace_usec != 0:
		var interval_seconds: float = float(now - _last_trace_usec) / 1000000.0
		if movement.length() > maxf(0.75, interval_seconds * 8.0 + 0.2):
			_fail("Unexpected body displacement/possible scene respawn; no motion acceptance")
	_distance += Vector2(movement.x, movement.z).length()
	state["wallclock_ms"] = float(now - _started_usec) / 1000.0
	state["frame_interval_ms"] = float(now - _last_trace_usec) / 1000.0 if _last_trace_usec != 0 else null
	state["phase"] = _phase
	state["render_frame"] = Engine.get_process_frames()
	state["physics_frame"] = Engine.get_physics_frames()
	state["horizontal_distance_m"] = _distance
	_traces.append(state)
	_last_trace_usec = now
	_last_position = _player.global_position


func _state() -> Dictionary:
	var bones: Dictionary = {}
	var actions: Dictionary = {}
	for action: StringName in INPUT_ACTIONS:
		actions[str(action)] = Input.is_action_pressed(action)
	if is_instance_valid(_skeleton):
		var skeleton_to_body: Transform3D = _player.global_transform.affine_inverse() * _skeleton.global_transform
		for index: int in range(_bone_indices.size()):
			var bone: int = _bone_indices[index]
			var rotation: Quaternion = _skeleton.get_bone_pose_rotation(bone)
			bones[BONE_NAMES[index]] = {"local_rotation_xyzw": [rotation.x, rotation.y, rotation.z, rotation.w],
				"posed_position_body_m": _v3((skeleton_to_body * _skeleton.get_bone_global_pose(bone)).origin)}
	return {"position_m": _v3(_player.global_position), "actual_velocity_mps": _v3(_player.get_real_velocity()),
		"controller_velocity_mps": _v3(_player.velocity), "grounded": _player.is_on_floor(),
		"player": _player.get_preview_status(), "actual_skeleton_bones": bones, "input_actions": actions}


func _capture(label: String) -> void:
	_events.append({"type": "capture_begin", "label": label, "wallclock_ms": _elapsed_ms()})
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path: String = _output_dir.path_join(label + ".png")
	var result: Error = frame.save_png(path)
	var state: Dictionary = _state()
	_captures.append({"label": label, "path": path, "result": result, "wallclock_ms": _elapsed_ms(), "state": state})
	_events.append({"type": "capture_end", "label": label, "wallclock_ms": _elapsed_ms()})
	if result != OK:
		_fail("PNG save failed: " + path + " error=" + str(result))
		_release_inputs()
	# PNG stalls are explicitly outside the measured baseline and labelled in trace.
	_record_trace()
	_last_trace_usec = 0


func _interval_summary(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in samples:
		total += value
	return {"frames": samples.size(), "interval_ms": samples,
		"p50_ms": sorted[maxi(0, int(ceil(samples.size() * 0.50)) - 1)],
		"p95_ms": sorted[maxi(0, int(ceil(samples.size() * 0.95)) - 1)],
		"p99_ms": sorted[maxi(0, int(ceil(samples.size() * 0.99)) - 1)],
		"mean_ms": total / float(samples.size()), "fps_from_wallclock": 1000.0 * float(samples.size()) / total}


func _release_inputs() -> void:
	for action: StringName in INPUT_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)


func _fail(message: String) -> void:
	_errors.append(message)
	push_error("MOTION_QA: " + message)


func _finish(passed: bool) -> void:
	_release_inputs()
	if is_instance_valid(_player):
		_player.set_mouse_captured(false)
		_report["final_state"] = _state()
	_report["status"] = "completed" if passed else "failed"
	_report["passed"] = passed
	_report["errors"] = _errors
	_report["captures"] = _captures
	_report["events"] = _events
	_report["frame_trace"] = _traces
	_report["distance_m"] = _distance
	_report["finished_utc"] = Time.get_datetime_string_from_system(true)
	_report["interactive_window_left_open"] = DisplayServer.get_name() != "headless"
	_report["motion_interval_limit"] = "Per-frame bone tracing and marked PNG stalls instrument motion; do not treat these intervals as an uninstrumented FPS benchmark"
	var report_path: String = _output_dir.path_join("motion_qa.json")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	else:
		push_error("MOTION_QA report could not be saved: " + report_path)
		passed = false
		_errors.append("Final JSON could not be saved")
	_phase = "interactive"
	print("MAFIOZI_MOTION_QA ", JSON.stringify({"passed": passed, "report": report_path, "captures": _captures.size(),
		"distance_m": _distance, "errors": _errors, "interactive": true,
		"input_source": "programmatic Input actions, not physical keyboard"}))
	# Deliberately no quit(), position write, physics disable or scene teardown.


func _finalize() -> void:
	_release_inputs()


func _elapsed_ms() -> float:
	return float(Time.get_ticks_usec() - _started_usec) / 1000.0


func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
