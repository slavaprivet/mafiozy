extends Node
## Read-only full-city observer. Uses the engine's own script profiler.
var _ready_at := 0
var _measure_at := 0
var _next_sample := 0
var _out := ""
var _samples: Array = []
var _positions: Dictionary = {}
var _moved: Dictionary = {}
var _seconds := 60
var _finished := false

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--profile-seconds="): _seconds = clampi(int(arg.trim_prefix("--profile-seconds=")), 10, 90)
	process_physics_priority = 100

func _physics_process(_delta: float) -> void:
	if _finished: return
	var scene: Node = get_parent()
	var population: Variant = scene.get("preview_population")
	if not is_instance_valid(population) or not population.city_ready or population.daily == null: return
	var now: int = Time.get_ticks_msec()
	if _ready_at == 0:
		_ready_at = now
		print("PROFILE31_READY")
	if now - _ready_at < 30000: return
	if _measure_at == 0:
		if not EngineDebugger.is_active() or not EngineDebugger.has_profiler(&"scripts"):
			_finish(population, "native_script_profiler_unavailable"); return
		EngineDebugger.profiler_enable(&"scripts", false)
		print("PROFILE31_MEASURE_BEGIN")
		EngineDebugger.profiler_enable(&"scripts", true)
		_measure_at = now; _next_sample = now
		for id: String in population.daily._lives:
			var body: CharacterBody3D = population.daily._lives[id]._token.body
			_positions[id] = body.global_position; _moved[id] = 0.0
	if now >= _next_sample:
		_next_sample += 1000
		var sample := {"elapsed_s":(now-_measure_at)/1000.0,"physics_frame":Engine.get_physics_frames()}
		for label: String in ["TIME_PROCESS","TIME_PHYSICS_PROCESS","TIME_NAVIGATION_PROCESS","MEMORY_STATIC","OBJECT_COUNT","OBJECT_NODE_COUNT","PHYSICS_3D_COLLISION_PAIRS"]:
			if ClassDB.class_has_integer_constant("Performance", label):
				sample[label] = Performance.get_monitor(ClassDB.class_get_integer_constant("Performance", label))
		_samples.append(sample)
		for id: String in _positions:
			var life: Variant = population.daily._lives.get(id)
			if life != null and is_instance_valid(life._token.body):
				_moved[id] = maxf(float(_moved[id]), (life._token.body.global_position as Vector3).distance_to(_positions[id]))
	if now-_measure_at >= _seconds*1000: _finish(population, "complete")

func _finish(population: Variant, reason: String) -> void:
	_finished = true
	if EngineDebugger.has_profiler(&"scripts"):
		print("PROFILE31_ACCUMULATED_BEGIN")
		EngineDebugger.profiler_enable(&"scripts", false)
	print("PROFILE31_MEASURE_END")
	var passed: bool = reason == "complete" and population.daily._lives.size() == 10 and _samples.size() >= _seconds
	var evidence := {"passed":passed,"reason":reason,"samples":_samples,"moved_from_start_m":_moved,"residents":population.daily._lives.size(),"staff":get_parent().preview_venue_staff29._rows.size(),"native_profiler_active":EngineDebugger.is_active(),"warmup_s":30,"measure_s":(Time.get_ticks_msec()-_measure_at)/1000.0,"source_changes":false,"headless_fps_acceptance":false,"profile_overhead_present":true}
	var file := FileAccess.open(_out.path_join("NATIVE.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  ")); file.close()
	get_tree().quit(0 if passed else 1)
