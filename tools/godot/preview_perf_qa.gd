extends SceneTree
## Coordinator-only single-window OFF/ON/ON/OFF runner; never auto-quits native.
## --headless ... --script <absolute this file> -- --protocol-selftest
const Player = preload("res://scripts/preview_player.gd")
const CAPACITY: int = 60000
const ACTIONS: Array[StringName] = [&"preview_move_forward", &"preview_move_back", &"preview_move_left", &"preview_move_right", &"preview_run", &"preview_jump"]
const ORDER: Array[bool] = [false, true, true, false]
const SOURCES: Array[String] = ["res://project.godot", "res://scenes/main.tscn", "res://scripts/main.gd", "res://scripts/preview_player.gd", "res://scripts/preview_locomotion.gd", "res://scripts/preview_airborne.gd", "res://scripts/perf/frame_recorder.gd", "res://scripts/perf/preview_perf_adapter.gd", "res://data/block.json", "res://data/printshop_interior.json"]

class WindowDriver extends Node:
	signal completed
	var player: CharacterBody3D
	var adapter: Node
	var action: StringName
	var enabled: bool = false
	var headless: bool = false
	var active: bool = false
	var tick: int = 0
	var total_ticks: int = 600
	var walk_at: int = 30
	var run_at: int = 120
	var stop_at: int = 180
	var jump_at: int = 210
	var count: int = 0
	var fault: String = ""
	var origin: Vector3
	var start_us: int = 0
	var anchor_us: int = 0
	var peak_y: float = 0.0
	var saw_air: bool = false
	var saw_land: bool = false
	var stamps: PackedInt64Array = PackedInt64Array()
	var ticks: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector3Array = PackedVector3Array()
	var flags: PackedByteArray = PackedByteArray()
	var events: PackedInt64Array = PackedInt64Array()
	func prepare() -> void:
		process_priority = 100 # Independent observer runs after normal scene/adapter callbacks.
		process_physics_priority = -100 # Input for this physics tick precedes the player.
		stamps.resize(CAPACITY)
		ticks.resize(CAPACITY)
		positions.resize(CAPACITY)
		flags.resize(CAPACITY)
		events.resize(6)
		events.fill(0)
		set_process(false)
		set_physics_process(false)
		set_process_input(true)
	func begin() -> void:
		origin = player.global_position
		peak_y = origin.y
		anchor_us = 0 # First observer callback anchors; exclude a partial start frame.
		start_us = Time.get_ticks_usec()
		active = true
		set_process(true)
		set_physics_process(true)
	func _input(event: InputEvent) -> void:
		if active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventJoypadButton or event is InputEventJoypadMotion):
			fault = "External device input during measurement"
	func _physics_process(_delta: float) -> void:
		if not active or tick >= total_ticks:
			return
		if tick == walk_at:
			Input.action_press(action)
			_event(0, "walk")
		if tick == run_at:
			Input.action_press(&"preview_run")
			_event(1, "run")
		if tick == stop_at:
			Input.action_release(action)
			Input.action_release(&"preview_run")
			_event(2, "stop")
		if tick == jump_at:
			if not player.is_on_floor():
				fault = "Jump schedule reached without physical support"
			Input.action_press(&"preview_jump")
			_event(3, "jump")
		if tick == jump_at + 1:
			Input.action_release(&"preview_jump")
			_event(4, "jump_release")
		tick += 1
	func _event(index: int, label: String) -> void:
		events[index] = Time.get_ticks_usec()
		if enabled:
			adapter.mark_event(label)
	func _process(_delta: float) -> void:
		if not active:
			return
		var now: int = Time.get_ticks_usec()
		if anchor_us == 0:
			anchor_us = now
			return
		var focused: bool = headless or DisplayServer.window_is_focused()
		if not append_raw(now, tick, player.global_position, (1 if player.is_on_floor() else 0) | (2 if focused else 0)):
			fault = "Independent trace capacity exhausted; no overwrite permitted"
		if not focused:
			fault = "Window lost focus during measurement"
		if adapter.is_processing() != enabled or adapter.is_capturing() != enabled:
			fault = "Adapter process/capture state differs from assigned OFF/ON window"
		if Engine.time_scale != 1.0 or get_tree().paused:
			fault = "Time scale or pause changed during measurement"
		if not player.global_position.is_finite() or player.global_position.y < origin.y - 0.15:
			fault = "Route left dry supported scene"
		if tick < jump_at and not player.is_on_floor():
			fault = "Unexpected airborne state before scheduled jump"
		if tick >= jump_at:
			peak_y = maxf(peak_y, player.global_position.y)
			if not player.is_on_floor():
				saw_air = true
			elif saw_air:
				saw_land = true
		if now - start_us > 60000000:
			fault = "Window wall timeout; intervals were not clamped"
		if tick >= total_ticks or not fault.is_empty():
			active = false
			set_process(false)
			set_physics_process(false)
			completed.emit()
	func append_raw(stamp: int, physics_tick: int, position_value: Vector3, flag: int) -> bool:
		if count >= stamps.size():
			return false
		stamps[count] = stamp
		ticks[count] = physics_tick
		positions[count] = position_value
		flags[count] = flag
		count += 1
		return true

var _main: Node3D
var _player: Player
var _adapter: Node
var _driver: WindowDriver
var _selftest: bool = false
var _warmup_us: int = 5000000
var _errors: Array[String] = []
var _checks: int = 0
var _output_dir: String
var _capture_after: String = ""
var _run_id: String
var _report: Dictionary = {}
var _windows: Array[Dictionary] = []
var _initial: Transform3D
var _heading: float
var _camera_yaw: float
var _camera_pitch: float
var _direction: StringName
var _metadata_reference: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_id = Time.get_datetime_string_from_system(true).replace(":", "-") + "-" + str(OS.get_process_id())
	_output_dir = ProjectSettings.globalize_path("res://../../outputs/godot_perf_qa").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--protocol-selftest":
			_selftest = true
		elif arg.begins_with("--perf-output-dir="):
			_output_dir = arg.trim_prefix("--perf-output-dir=").simplify_path()
		elif arg.begins_with("--perf-capture-after="):
			_capture_after = arg.trim_prefix("--perf-capture-after=").simplify_path()
	_report = {"schema": "mafiozi.s01.perf-off-on-on-off/v1", "run_id": _run_id,
		"mode": "protocol_selftest" if _selftest else "native_measurement",
		"live_acceptance": false, "performance_acceptance": false,
		"qualification": "Protocol completion is not LIVE/performance approval; independent wall intervals, not GPU duration or presentation latency",
		"order": ["OFF", "ON", "ON", "OFF"], "engine": Engine.get_version_info(),
		"started_utc": Time.get_datetime_string_from_system(true), "sources": _hashes(),
		"input_source": "Deterministic Godot Input actions at physics ticks; no physical keyboard replay",
		"population": {"npc": 0, "vehicles": 0, "scope": "Current small main preview only"}}
	if not _output_dir.is_absolute_path() or (not _capture_after.is_empty() and not _capture_after.is_absolute_path()):
		_errors.append("Output and optional PNG paths must be absolute")
		_finish()
		return
	if DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		_errors.append("Cannot create output directory")
		_finish()
		return
	if _selftest != (DisplayServer.get_name() == "headless"):
		_errors.append("Selftest requires headless; native measurement requires a visible display")
		_finish()
		return
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--fixed-fps") or arg.begins_with("--preview-capture") or arg == "--preview-perf":
			_errors.append("Rejected fixed-fps, screenshot capture or pre-enabled collector launch argument")
	if Engine.time_scale != 1.0 or Engine.physics_ticks_per_second != 60:
		_errors.append("Protocol requires time_scale=1 and 60Hz physics; does not silently change settings")
	if not _errors.is_empty():
		_finish()
		return
	if _selftest:
		_warmup_us = 250000
		_buffer_selftest()
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_errors.append("Actual main PackedScene unavailable")
		_finish()
		return
	_main = scene.instantiate() as Node3D
	root.add_child(_main)
	current_scene = _main
	var deadline: int = Time.get_ticks_usec() + 30000000
	while not bool(_main.get("preview_ready")):
		if Time.get_ticks_usec() > deadline or not (_main.get("validation_errors") as PackedStringArray).is_empty():
			_errors.append("Actual main scene failed readiness")
			_finish()
			return
		await process_frame
	_player = _main.get("_player") as Player
	_adapter = _main.get("preview_perf") as Node
	if _player == null or _adapter == null or _adapter.is_processing() or _adapter.is_capturing() or _adapter.pending_json_count() != 0:
		_errors.append("Expected actual player and default-OFF idle/drained main adapter")
		_finish()
		return
	_release_inputs()
	_player.set_mouse_captured(false)
	if not await _settle():
		_errors.append("Initial physical floor settle failed")
		_finish()
		return
	_initial = _player.global_transform
	_heading = _player.get("_heading")
	_camera_yaw = _player.get("_camera_yaw")
	_camera_pitch = _player.get("_camera_pitch")
	if not _clearance():
		_errors.append("No dry capsule-clear corridor including jump headroom; no route executed")
		_finish()
		return
	_metadata_reference = _metadata()
	for index: int in range(4):
		if not await _window(index, ORDER[index]):
			break
	if _errors.is_empty() and not _capture_after.is_empty():
		if _selftest:
			_report["optional_capture"] = {"skipped": "headless protocol selftest"}
		else:
			var started: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var result: Error = root.get_texture().get_image().save_png(_capture_after)
			_report["optional_capture"] = {"path": _capture_after, "error": result, "wall_us": Time.get_ticks_usec() - started, "after_all_windows_and_worker_drain": true}
			if result != OK:
				_errors.append("Optional after-window PNG failed")
	_report["sources_at_end"] = _hashes()
	_check(_report.sources_at_end == _report.sources, "source hashes unchanged across protocol")
	_finish()

func _window(index: int, enabled: bool) -> bool:
	# Reset only outside measurement, then settle and a complete fresh warmup.
	_release_inputs()
	if _adapter.pending_json_count() != 0 or _adapter.is_capturing() or _adapter.is_processing():
		_errors.append("Previous collector/worker not drained")
		return false
	_player.global_transform = _initial
	_player.velocity = Vector3.ZERO
	_player.set("_heading", _heading)
	_player.set("_camera_yaw", _camera_yaw)
	_player.set("_camera_pitch", _camera_pitch)
	_player.get_node("VisualHeading").rotation.y = _heading + deg_to_rad(_player.visual_yaw_degrees)
	_player.call("_update_camera_rotation")
	_player.set_preview_pose_authority(&"on_foot", true)
	if not await _settle():
		_errors.append("Between-window floor reset failed")
		return false
	var start_meta: Dictionary = _metadata()
	if start_meta != _metadata_reference:
		_errors.append("Renderer/settings/camera/population changed before window")
		return false
	_driver = WindowDriver.new()
	_driver.player = _player
	_driver.adapter = _adapter
	_driver.action = _direction
	_driver.enabled = enabled
	_driver.headless = _selftest
	if _selftest:
		_driver.total_ticks = 150
		_driver.walk_at = 6
		_driver.run_at = 21
		_driver.stop_at = 33
		_driver.jump_at = 42
	root.add_child(_driver)
	_driver.prepare()
	var row: Dictionary = {"index": index, "collector": "ON" if enabled else "OFF", "metadata_start": start_meta, "warmup_target_us": _warmup_us,
		"measurement_contains": "identical bounded independent observer + actual deterministic input route; ON also runs production collector and 5 event markers",
		"route_ticks": {"walk": _driver.walk_at, "run": _driver.run_at, "stop": _driver.stop_at, "jump": _driver.jump_at, "jump_release": _driver.jump_at + 1, "end": _driver.total_ticks}}
	var started: int = Time.get_ticks_usec()
	if enabled and not _main.begin_preview_perf_capture({"capacity": CAPACITY, "event_capacity": 32, "warmup_us": _warmup_us, "context": {"protocol": _report.schema, "window": index, "route": row.route_ticks}}):
		_errors.append("Main refused explicit collector capture")
		_driver.queue_free()
		return false
	row["begin_capture_main_us"] = Time.get_ticks_usec() - started if enabled else null
	started = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < _warmup_us:
		await process_frame
	row["warmup_actual_us"] = Time.get_ticks_usec() - started
	if _metadata() != start_meta or (not _selftest and not DisplayServer.window_is_focused()):
		_errors.append("Settings or focus changed during warmup")
		if enabled:
			_adapter.finish_capture()
		_driver.queue_free()
		return false
	# No JSON, disk, reports, snapshots, console, PNG or scene scans until completed.
	_driver.begin()
	await _driver.completed
	_release_inputs()
	var end_us: int = Time.get_ticks_usec()
	row["measurement_start_us"] = _driver.anchor_us
	row["measurement_end_us"] = _driver.stamps[_driver.count - 1] if _driver.count else end_us
	if not _driver.fault.is_empty():
		_errors.append(_driver.fault)
	if not _driver.saw_air or not _driver.saw_land or _driver.peak_y - _driver.origin.y < 1.0:
		_errors.append("Scheduled route did not complete the real grounded jump/landing")
	row["route_result"] = {"ticks": _driver.tick, "saw_air": _driver.saw_air, "saw_land": _driver.saw_land, "peak_height_m": _driver.peak_y - _driver.origin.y, "end_position": _v3(_player.global_position)}
	_check(_driver.tick == _driver.total_ticks, "fixed physics route completed")
	if not _windows.is_empty():
		var first: Dictionary = _windows[0].route_result
		var endpoint: Vector3 = Vector3(first.end_position[0], first.end_position[1], first.end_position[2])
		_check(endpoint.distance_to(_player.global_position) < 0.02 and absf(float(first.peak_height_m) - float(row.route_result.peak_height_m)) < 0.02, "same endpoint and jump height within 2cm across windows")
	row["counters_at_window_end"] = {"draw_calls_last_frame": null if _selftest else Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_primitives_last_frame": null if _selftest else Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"gpu_frame_ms": null, "unique_scene_triangles": null, "limit": "Post-window snapshot, may lag up to one second; not whole-run peaks or unique triangles"}
	row["metadata_end"] = _metadata()
	if row.metadata_end != start_meta:
		_errors.append("Settings or camera parameters changed during measurement")
	if enabled:
		started = Time.get_ticks_usec()
		var job: int = _adapter.finish_capture_json_async()
		row["finish_report_and_dispatch_main_us"] = Time.get_ticks_usec() - started
		if job < 0:
			_errors.append("Unexpected full worker queue at finish")
			_adapter.finish_capture()
		else:
			var wait_start: int = Time.get_ticks_usec()
			while not _adapter.is_json_ready(job):
				await process_frame
			row["worker_ready_observed_wait_us"] = Time.get_ticks_usec() - wait_start
			row["worker_timing_limit"] = "Completion polling wall latency includes scheduler/frame pacing; not worker CPU serialization time"
			started = Time.get_ticks_usec()
			var result: Dictionary = _adapter.take_json_result(job)
			row["take_completed_main_us"] = Time.get_ticks_usec() - started
			if not str(result.error).is_empty():
				_errors.append("JSON worker result error")
			row["collector_report"] = JSON.parse_string(str(result.json))
			var report: Dictionary = row.collector_report if row.collector_report is Dictionary else {}
			_check(not report.is_empty() and int(report.get("overwritten_count", -1)) == 0 and int(report.get("events_overwritten_count", -1)) == 0, "ON collector retained all frames/events")
			_check(int(report.get("events_total", 0)) == 5, "ON exact five scheduled markers")
	_check(not _adapter.is_processing() and not _adapter.is_capturing() and _adapter.pending_json_count() == 0, "collector OFF and workers drained before next reset/warmup")
	started = Time.get_ticks_usec()
	row["independent"] = _independent_report(_driver)
	row["independent_report_main_us"] = Time.get_ticks_usec() - started
	row["errors_so_far"] = _errors.duplicate()
	var path: String = _output_dir.path_join(_run_id + "-window-" + str(index) + ".json")
	var write_result: Dictionary = _atomic_json(path, row)
	_windows.append({"index": index, "collector": row.collector, "path": path, "independent_summary": row.independent.summary,
		"file_write": write_result, "route_result": row.route_result, "warmup_actual_us": row.warmup_actual_us,
		"begin_capture_main_us": row.begin_capture_main_us, "finish_report_and_dispatch_main_us": row.get("finish_report_and_dispatch_main_us")})
	_driver.queue_free()
	_driver = null
	return _errors.is_empty()

func _independent_report(driver: WindowDriver) -> Dictionary:
	var intervals: Array[int] = []
	var stamps: Array[int] = []
	var ticks: Array[int] = []
	var positions: Array = []
	var flags: Array[int] = []
	var previous: int = driver.anchor_us
	var spikes: int = 0
	for i: int in range(driver.count):
		var interval: int = driver.stamps[i] - previous
		intervals.append(interval)
		stamps.append(driver.stamps[i])
		ticks.append(driver.ticks[i])
		positions.append(_v3(driver.positions[i]))
		flags.append(driver.flags[i])
		if interval > 50000:
			spikes += 1
		previous = driver.stamps[i]
	var sorted: Array[int] = intervals.duplicate()
	sorted.sort()
	return {"summary": {"count": driver.count, "capacity": CAPACITY, "overwritten": 0, "p50_us": _rank(sorted, 0.5), "p95_us": _rank(sorted, 0.95), "p99_us": _rank(sorted, 0.99), "spikes_gt_50ms": spikes},
		"anchor_us": driver.anchor_us, "stamps_us": stamps, "intervals_us": intervals, "physics_ticks": ticks, "positions_m": positions, "flags": flags,
		"flag_bits": {"grounded": 1, "focused_or_headless": 2}, "event_stamps_us": Array(driver.events).slice(0, 5),
		"collector_alignment": "Independent callback and collector callback have different intra-frame timestamp positions. Use independent windows for OFF/ON comparison; collector raw may contain boundary frames after warmup/before finish."}

func _rank(values: Array[int], fraction: float) -> Variant:
	return values[maxi(0, int(ceil(values.size() * fraction)) - 1)] if not values.is_empty() else null

func _settle() -> bool:
	var stable: int = 0
	var deadline: int = Time.get_ticks_usec() + 10000000
	while Time.get_ticks_usec() < deadline:
		await physics_frame
		await process_frame
		stable = stable + 1 if _player.is_on_floor() and _player.velocity.length() < 0.01 else 0
		if stable >= 12:
			return true
	return false

func _clearance() -> bool:
	var actions: Array[StringName] = [&"preview_move_forward", &"preview_move_right", &"preview_move_left", &"preview_move_back"]
	var directions: Array[Vector3] = [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK]
	var capsule: CapsuleShape3D = (_player.get_node("PlayerCapsule") as CollisionShape3D).shape as CapsuleShape3D
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var candidates: Array[Dictionary] = []
	for i: int in range(4):
		var direction: Vector3 = Basis(Vector3.UP, _camera_yaw) * directions[i]
		var clear: bool = true
		var checked: float = 0.0
		for step: int in range(53):
			var at: Vector3 = _initial.origin + direction * (step * 0.25)
			if not _dry(at):
				clear = false
				break
			var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at - Vector3.UP * 0.5, 1, [_player.get_rid()])
			var hit: Dictionary = space.intersect_ray(ray)
			if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) < 0.98 or absf((hit.position as Vector3).y - _initial.origin.y) > 0.1:
				clear = false
				break
			# Continuous capsule sweep between samples and through full jump headroom.
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (capsule.height * 0.5 + 0.04))
			query.collision_mask = 1
			query.exclude = [_player.get_rid()]
			if not space.intersect_shape(query, 1).is_empty():
				clear = false
				break
			query.motion = direction * 0.25
			if space.cast_motion(query)[0] < 0.9999:
				clear = false
				break
			query.motion = Vector3.UP * 1.5
			if space.cast_motion(query)[0] < 0.9999:
				clear = false
				break
			checked = step * 0.25
		candidates.append({"action": str(actions[i]), "clear": clear, "checked_m": checked})
		if clear:
			_direction = actions[i]
			_report["clearance"] = {"accepted": true, "action": str(_direction), "corridor_m": 13.0, "sample_spacing_m": 0.25, "jump_headroom_m": 1.5, "capsule_radius": capsule.radius, "capsule_height": capsule.height, "candidates": candidates, "origin": _v3(_initial.origin), "read_only_before_all_runs": true}
			return true
	_report["clearance"] = {"accepted": false, "candidates": candidates}
	return false

func _dry(at: Vector3) -> bool:
	var block: Dictionary = _main.get("_block")
	var surface: Dictionary = block.surface
	var source: Vector3 = at + (_main.get("_origin") as Vector3)
	var col: int = int(floor(source.x / float(surface.cellSize))) - int(surface.startCol)
	var row: int = int(floor(source.z / float(surface.cellSize))) - int(surface.startRow)
	if row < 0 or row >= int(surface.rows) or col < 0 or col >= int(surface.cols):
		return false
	var tile: int = int(surface.grid[row][col])
	return tile != 16 and bool(surface.palette[str(tile)].solid)

func _metadata() -> Dictionary:
	var camera: Camera3D = _player.get_preview_camera()
	return {"renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "viewport": [root.size.x, root.size.y],
		"vsync": null if _selftest else DisplayServer.window_get_vsync_mode(), "time_scale": Engine.time_scale, "physics_hz": Engine.physics_ticks_per_second, "max_fps": Engine.max_fps,
		"focus_policy": "abort on any unfocused measured frame; samples retain focus bit", "focused": null if _selftest else DisplayServer.window_is_focused(),
		"camera": {"yaw": _player.get("_camera_yaw"), "pitch": _player.get("_camera_pitch"), "fov": camera.fov, "near": camera.near, "far": camera.far, "distance": _player.camera_distance},
		"viewport_render": {"msaa_3d": root.msaa_3d, "screen_space_aa": root.screen_space_aa, "scaling_3d_mode": root.scaling_3d_mode, "scaling_3d_scale": root.scaling_3d_scale},
		"population": {"npc": 0, "vehicles": 0}, "scene_counts": (_main.get("_block") as Dictionary).counts,
		"printshop_status": _main.get("printshop_status"), "debug_build": OS.is_debug_build()}

func _hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in SOURCES:
		hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else null
	hashes["harness"] = FileAccess.get_sha256(get_script().resource_path)
	return hashes

func _atomic_json(path: String, data: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var json: String = JSON.stringify(data)
	var encoded_us: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var temp: String = path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		_errors.append("Cannot open atomic report temporary file")
		return {"ok": false}
	file.store_string(json)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(temp, path)
	if result != OK:
		_errors.append("Atomic report write/rename failed: " + str(result))
	return {"ok": result == OK, "json_main_us": encoded_us, "file_flush_rename_us": Time.get_ticks_usec() - started, "bytes": json.to_utf8_buffer().size()}

func _buffer_selftest() -> void:
	var driver := WindowDriver.new()
	driver.stamps.resize(2)
	driver.ticks.resize(2)
	driver.positions.resize(2)
	driver.flags.resize(2)
	_check(driver.append_raw(100, 1, Vector3.ZERO, 3), "bounded trace first append")
	_check(driver.append_raw(200, 2, Vector3.ONE, 3), "bounded trace second append")
	_check(not driver.append_raw(300, 3, Vector3.UP, 3) and driver.count == 2 and driver.stamps[0] == 100, "capacity fails closed without overwrite")
	var samples: Array[int] = [10, 20, 30, 100]
	_check(_rank(samples, 0.5) == 20 and _rank(samples, 0.95) == 100, "independent nearest rank")
	driver.free()

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_errors.append(label)

func _release_inputs() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)

func _finish() -> void:
	_release_inputs()
	if is_instance_valid(_player):
		_player.set_mouse_captured(false)
	_report["windows"] = _windows
	_report["errors"] = _errors.duplicate()
	_report["protocol_checks"] = _checks
	_report["completed_four_windows"] = _windows.size() == 4 and _errors.is_empty()
	_report["status"] = ("protocol_selftest_completed" if _selftest else "measurement_completed_review_required") if _report.completed_four_windows else "failed"
	_report["interactive_window_left_open"] = not _selftest and DisplayServer.get_name() != "headless"
	_report["finished_utc"] = Time.get_datetime_string_from_system(true)
	var path: String = _output_dir.path_join(_run_id + "-result.json")
	var saved: Dictionary = _atomic_json(path, _report) if not _output_dir.is_empty() and _output_dir.is_absolute_path() else {"ok": false}
	print("S01_PERF_QA ", JSON.stringify({"status": _report.status, "windows": _windows.size(), "checks": _checks, "errors": _errors, "report": path, "saved": saved, "live_acceptance": false, "performance_acceptance": false}))
	if DisplayServer.get_name() == "headless":
		quit(0 if _errors.is_empty() and _windows.size() == 4 and bool(saved.ok) else 1)
	# Native always leaves the same game window interactive, including failure.

func _finalize() -> void:
	_release_inputs()

func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
