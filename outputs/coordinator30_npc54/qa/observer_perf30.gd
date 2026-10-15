extends Node
## Measurement only: ordinary actor, ordinary decisions, no task/HP/position writes.
var _out := ""
var _duration := 180.0
var _started := 0
var _ready_at := 0
var _last_tick := 0
var _last_sample := 0
var _frames: Array[float] = []
var _samples: Array[Dictionary] = []

func _ready() -> void:
	_started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-duration="): _duration = float(arg.trim_prefix("--qa-duration="))

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var scene: Node3D = get_tree().current_scene
	var pop: RefCounted = scene.get("preview_population")
	if _ready_at == 0:
		if pop != null and pop.get("city_ready") == true:
			_ready_at = now; _last_tick = Time.get_ticks_usec()
		elif now - _started > 100000: _finish("bootstrap_timeout")
		return
	var tick: int = Time.get_ticks_usec()
	if now - _ready_at >= 20000: _frames.append(float(tick-_last_tick)/1000.0)
	_last_tick = tick
	if now - _last_sample >= 1000:
		_last_sample = now
		var point: Variant = null
		var health: Dictionary = {}
		var life: RefCounted = pop.daily._lives.get("resident_1")
		if life != null:
			var body: Node3D = life._token.get("body")
			if is_instance_valid(body): point = body.global_position
			health = life._health.snapshot()
		_samples.append({"elapsed_ms":now-_ready_at,"frame":Engine.get_physics_frames(),
			"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),
			"object_count":Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"process_ms":1000.0*Performance.get_monitor(Performance.TIME_PROCESS),
			"physics_ms":1000.0*Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			"residents":pop.hit_owners.size(),"lives":pop.daily._lives.size(),
			"resident_position":point,"health":health,"phase":life._phase if life != null else "none"})
	if now - _ready_at >= int(_duration * 1000.0): _finish("")

func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty(): return 0.0
	return values[mini(values.size()-1,int(float(values.size()-1)*fraction))]

func _finish(reason: String) -> void:
	_frames.sort()
	var result: Dictionary = {"ok":reason.is_empty(),"reason":reason,"warmup_seconds":20,
		"duration_seconds":_duration,"frame_count":_frames.size(),
		"frame_ms_p50":_percentile(_frames,.5),"frame_ms_p95":_percentile(_frames,.95),
		"frame_ms_p99":_percentile(_frames,.99),"samples":_samples,
		"performance_acceptance_requires_exclusive_scheduler_receipt":true,
		"memory_scope":"Godot static allocations, objects and nodes; excludes full OS/GPU footprint"}
	if not _out.is_empty():
		var file := FileAccess.open(_out.path_join("PERF30.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t")); file.close()
	print("PERF30 ",JSON.stringify({"ok":result.ok,"p50":result.frame_ms_p50,"p95":result.frame_ms_p95,"frames":_frames.size()}))
	get_tree().quit(0 if reason.is_empty() else 1)
