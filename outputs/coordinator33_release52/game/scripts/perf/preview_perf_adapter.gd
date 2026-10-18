extends Node
## Opt-in capture adapter. Root attaches this node; OFF has no process callback.
const Recorder = preload("res://scripts/perf/frame_recorder.gd")
const MAX_JSON_JOBS := 2

class JsonJob extends RefCounted:
	var report: Dictionary
	var json := ""
	func run() -> void:
		# Own immutable DTO only: no node, rendering server, monitors or disk IO.
		json = JSON.stringify(report)
		report.clear()

var _recorder = Recorder.new()
var _capturing := false
var _json_jobs: Dictionary = {}

func _init() -> void:
	set_process(false)

func _ready() -> void:
	set_process(_capturing)

func begin_capture(config: Dictionary = {}) -> bool:
	var supplied_context: Variant = config.get("context", {})
	if typeof(supplied_context) != TYPE_DICTIONARY:
		return false
	var settings := config.duplicate(true)
	var context: Dictionary = supplied_context.duplicate(true)
	# Actual settings override caller guesses; scenario/population stay caller-owned.
	context["rendering_method"] = RenderingServer.get_current_rendering_method()
	context["physics_ticks_per_second"] = Engine.physics_ticks_per_second
	context["engine_max_fps"] = Engine.max_fps
	context["engine_time_scale"] = Engine.time_scale
	context["debug_build"] = OS.is_debug_build()
	context["display_server"] = DisplayServer.get_name()
	context["vsync_mode"] = null if DisplayServer.get_name() == "headless" else DisplayServer.window_get_vsync_mode()
	context["viewport_size_px"] = [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y] if is_inside_tree() else null
	settings["context"] = context
	if not _recorder.begin_capture(settings):
		return false
	_capturing = true
	# Anchor now so the first actual process interval and warmup start are known.
	_recorder.record_timestamp(Time.get_ticks_usec())
	set_process(true)
	return true

func _process(_delta: float) -> void:
	if _capturing:
		_recorder.record_timestamp(Time.get_ticks_usec())

func mark_event(label: String) -> void:
	_recorder.mark_event(label)

func snapshot() -> Dictionary:
	# Explicit diagnostic operation; never call for a HUD every frame.
	return _recorder.snapshot()

func finish_capture() -> Dictionary:
	_capturing = false
	set_process(false)
	return _recorder.finish_capture()

func is_capturing() -> bool:
	return _capturing

func finish_capture_json_async() -> int:
	# A busy queue must not stop or lose the current capture.
	if _json_jobs.size() >= MAX_JSON_JOBS:
		return -1
	var job := JsonJob.new()
	job.report = finish_capture()
	var task_id := WorkerThreadPool.add_task(job.run, false, "S01 report JSON")
	_json_jobs[task_id] = job
	return task_id

func is_json_ready(task_id: int) -> bool:
	return _json_jobs.has(task_id) and WorkerThreadPool.is_task_completed(task_id)

func take_json_result(task_id: int) -> Dictionary:
	if not _json_jobs.has(task_id):
		return {"ready": true, "error": "UNKNOWN_TASK", "json": ""}
	if not WorkerThreadPool.is_task_completed(task_id):
		return {"ready": false, "error": "", "json": ""}
	var completed := WorkerThreadPool.wait_for_task_completion(task_id)
	var job: JsonJob = _json_jobs[task_id]
	_json_jobs.erase(task_id)
	return {"ready": true, "error": "" if completed == OK else "WORKER_WAIT_FAILED", "json": job.json if completed == OK else ""}

func pending_json_count() -> int:
	return _json_jobs.size()

func _exit_tree() -> void:
	_capturing = false
	set_process(false)
	_recorder.stop()
	# Shutdown only: every Godot pool task must be joined to release its handle.
	# Normal result polling joins only a task already known to be complete.
	for task_id: int in _json_jobs.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
	_json_jobs.clear()
