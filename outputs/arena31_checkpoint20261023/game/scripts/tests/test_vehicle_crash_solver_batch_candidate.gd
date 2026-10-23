extends SceneTree
## Independent-state WorkerThreadPool batch candidate: source parity, lifecycle,
## poisoning and measured serial/parallel complete-batch CPU cost.

const Solver = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const Batch = preload("res://scripts/vehicle_physics/vehicle_crash_solver_batch_candidate.gd")
const SOLVER := "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
const SOLVER_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const PERF_SIZES := [1, 16, 72]
const PERF_WORKERS := [2, 4, 8]
const PERF_SAMPLES := 32
const PERF_WARMUP := 4
const DELTA := 1.0 / 60.0

class RejectingSolver extends NativeVehicleCrashSolver:
	func step(_delta_value: Variant, _speed_value: Variant, _throttle_value: Variant,
			_physics_tick_value: Variant) -> Dictionary:
		return {"accepted": false, "changed": false, "substeps": 0}

class OffMainProbe extends RefCounted:
	var configure_target: RefCounted
	var bound_target: RefCounted
	var rows: Array
	var results: Dictionary = {}
	func run() -> void:
		results = {"configure": configure_target.configure("off-main", 1, 1),
			"bind": bound_target.bind_states(rows),
			"begin": bound_target.begin_step_batch(1.0 / 60.0, 0.0, 0.0, 1),
			"finish": bound_target.finish_step_batch(-1),
			"step": bound_target.step_batch(1.0 / 60.0, 0.0, 0.0, 1),
			"reset": bound_target.reset_session_wait("off-main-reset"),
			"retire": bound_target.retire_wait(), "contract": bound_target.contract()}

var checks := 0
var failures: Array[String] = []
var perf_rows: Array[Dictionary] = []
var identity_sequence := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed if parsed is Dictionary else {}

func _profiles(document: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value: Variant in document.get("entries", []):
		if not entry_value is Dictionary:
			continue
		for node_value: Variant in entry_value.get("nodes", []):
			if node_value is Dictionary and node_value.get("source_metadata") is Dictionary:
				var metadata: Dictionary = node_value.source_metadata
				if metadata.get("vehicleProfile") is Dictionary:
					result.append(metadata.vehicleProfile)
					break
	return result

func _new_solver(profile: Dictionary, vehicle_id: String, life := 1) -> RefCounted:
	var solver := Solver.new()
	return solver if solver.configure(vehicle_id, life, profile.id,
		MANIFEST_SHA256, profile) else null

func _rows(solvers: Array, ids: Array[String], life := 1) -> Array:
	var result: Array = []
	result.resize(solvers.size())
	for index in solvers.size():
		result[index] = {"solver": solvers[index], "vehicle_id": ids[index],
			"life_generation": life}
	return result

func _fleet(profile: Dictionary, size: int, tag: String, life := 1) -> Dictionary:
	var solvers: Array = []
	var ids: Array[String] = []
	solvers.resize(size)
	ids.resize(size)
	for index in size:
		identity_sequence += 1
		var id := tag + "-" + str(identity_sequence)
		ids[index] = id
		solvers[index] = _new_solver(profile, id, life)
	return {"solvers": solvers, "ids": ids, "rows": _rows(solvers, ids, life)}

func _impact_row(profile: Dictionary, vehicle_id: String, tick: int,
		sequence: int, speed := 10.0) -> Dictionary:
	var phase := sequence % 4
	var source_point: Vector3
	var source_normal: Vector3
	match phase:
		0:
			source_point = Vector3(0.0, 0.8, float(profile.halfLength))
			source_normal = Vector3(0.0, 0.0, 1.0)
		1:
			source_point = Vector3(float(profile.halfWidth), 0.9, 0.0)
			source_normal = Vector3(1.0, 0.0, 0.0)
		2:
			source_point = Vector3(0.0, 0.8, -float(profile.halfLength))
			source_normal = Vector3(0.0, 0.0, -1.0)
		_:
			source_point = Vector3(-float(profile.halfWidth), 0.9, 0.0)
			source_normal = Vector3(-1.0, 0.0, 0.0)
	return {"vehicle_id": vehicle_id, "life_generation": 1, "physics_tick": tick,
		"impact_sequence": sequence, "event_id": "batch-rearm-" + str(sequence),
		"point_native_m": Solver.source_local_to_native(source_point),
		"normal_native": Solver.source_local_to_native(source_normal),
		"impact_speed_mps": speed}

func _rearm(solvers: Array, ids: Array[String], profile: Dictionary,
		tick: int, sequence: int, speed := 10.0) -> bool:
	for index in solvers.size():
		var solver: RefCounted = solvers[index]
		var result: Dictionary = solver.apply_impact_native(
			_impact_row(profile, ids[index], tick, sequence, speed))
		if not result.applied or not solver.snapshot_source().active:
			return false
	return true

func _serial_step_publish(solvers: Array, ids: Array[String], life: int,
		tick: int, measure: bool) -> Dictionary:
	var published: Array = []
	published.resize(solvers.size())
	var started := Time.get_ticks_usec() if measure else 0
	for index in solvers.size():
		var solver: RefCounted = solvers[index]
		var step: Dictionary = solver.step(DELTA, 8.0, 1.0, tick)
		published[index] = {"vehicle_id": ids[index], "life_generation": life,
			"step": step.duplicate(true), "mechanical": solver.mechanical_snapshot(),
			"deformation": solver.deformation_snapshot_native()}
	return {"accepted": published.all(func(row: Dictionary) -> bool:
		return row.step.accepted), "states": published,
		"elapsed_usec": Time.get_ticks_usec() - started if measure else 0}

func _parallel_step_publish(batch: RefCounted, tick: int, measure: bool) -> Dictionary:
	var started := Time.get_ticks_usec() if measure else 0
	var result: Dictionary = batch.step_batch(DELTA, 8.0, 1.0, tick)
	result.elapsed_usec = Time.get_ticks_usec() - started if measure else 0
	return result

func _parity_13(profiles: Array[Dictionary], workers: int) -> void:
	var serial_solvers: Array = []
	var parallel_solvers: Array = []
	var ids: Array[String] = []
	serial_solvers.resize(profiles.size())
	parallel_solvers.resize(profiles.size())
	ids.resize(profiles.size())
	for index in profiles.size():
		identity_sequence += 1
		var id := "parity-" + str(workers) + "-" + str(identity_sequence)
		ids[index] = id
		serial_solvers[index] = _new_solver(profiles[index], id)
		parallel_solvers[index] = _new_solver(profiles[index], id)
	var batch := Batch.new()
	_check(batch.configure("parity-session-" + str(workers), 16, workers),
		"worker " + str(workers) + " configures")
	_check(batch.bind_states(_rows(parallel_solvers, ids)),
		"worker " + str(workers) + " binds 13 independent source states")
	for tick in 1 + 8:
		for index in profiles.size():
			var speed := 17.0 if tick == 0 else 3.0
			var row := _impact_row(profiles[index], ids[index], tick, tick, speed)
			var serial_impact: Dictionary = serial_solvers[index].apply_impact_native(row)
			var parallel_impact: Dictionary = parallel_solvers[index].apply_impact_native(row)
			_check(serial_impact == parallel_impact,
				"worker " + str(workers) + " impact parity " + str(index) + ":" + str(tick))
		var serial := _serial_step_publish(serial_solvers, ids, 1, tick + 1, false)
		var parallel := _parallel_step_publish(batch, tick + 1, false)
		_check(serial.accepted and parallel.accepted and serial.states == parallel.states,
			"worker " + str(workers) + " repeated deterministic full snapshot batch " + str(tick))
	_check(batch.retire_wait(), "worker " + str(workers) + " parity batch retires")

func _lifecycle(profile: Dictionary) -> void:
	var fleet := _fleet(profile, 2, "lifecycle")
	var batch := Batch.new()
	_check(batch.configure("lifecycle-a", 2, 2) and batch.bind_states(fleet.rows),
		"lifecycle binds two independent states")
	_check(_rearm(fleet.solvers, fleet.ids, profile, 0, 0), "lifecycle states active")
	var begun := batch.begin_step_batch(DELTA, 8.0, 1.0, 1)
	_check(begun.accepted and batch.contract().in_flight, "begin exposes one in-flight group")
	_check(not batch.begin_step_batch(DELTA, 8.0, 1.0, 1).accepted
		and not batch.bind_states(fleet.rows), "second begin and bind reject while in flight")
	_check(not batch.finish_step_batch(int(begun.task_id) + 1).accepted,
		"finish requires exact task id")
	var finished := batch.finish_step_batch(begun.task_id)
	_check(finished.accepted and finished.states.size() == 2
		and not batch.finish_step_batch(begun.task_id).accepted,
		"joined group publishes once")
	var before_stale := [fleet.solvers[0].snapshot_source(), fleet.solvers[1].snapshot_source()]
	_check(not batch.begin_step_batch(DELTA, 8.0, 1.0, 1).accepted
		and fleet.solvers[0].snapshot_source() == before_stale[0]
		and fleet.solvers[1].snapshot_source() == before_stale[1],
		"main preflight stale tick prevents partial fleet advance")
	_check(_rearm(fleet.solvers, fleet.ids, profile, 1, 1), "reset-wait states rearm")
	begun = batch.begin_step_batch(DELTA, 8.0, 1.0, 2)
	_check(begun.accepted and batch.reset_session_wait("lifecycle-b")
		and batch.contract().bound_states == 0 and not batch.contract().in_flight,
		"session reset joins discards and clears old-life bindings")
	var next_fleet := _fleet(profile, 2, "lifecycle-next", 2)
	_check(batch.bind_states(next_fleet.rows), "new session requires new-life solver refs")
	_check(_rearm_life(next_fleet.solvers, next_fleet.ids, profile, 2, 0, 0),
		"new-life states active")
	begun = batch.begin_step_batch(DELTA, 8.0, 1.0, 1)
	_check(begun.accepted and batch.retire_wait() and batch.contract().retired
		and batch.contract().bound_states == 0
		and not batch.begin_step_batch(DELTA, 8.0, 1.0, 2).accepted,
		"retire joins discards clears and permanently rejects")
	var poison := Batch.new()
	var rejector := RejectingSolver.new()
	_check(rejector.configure("rejector", 1, profile.id, MANIFEST_SHA256, profile)
		and poison.configure("poison", 1, 1)
		and poison.bind_states([{"solver": rejector, "vehicle_id": "rejector",
			"life_generation": 1}]), "rejecting fixture binds")
	var poisoned_result := poison.step_batch(DELTA, 0.0, 0.0, 0)
	_check(not poisoned_result.accepted and poisoned_result.poisoned
		and poison.contract().poisoned and not poisoned_result.has("states")
		and not poison.begin_step_batch(DELTA, 0.0, 0.0, 1).accepted,
		"unexpected worker rejection poisons and publishes no snapshots")
	_check(poison.reset_session_wait("poison-recovered") and not poison.contract().poisoned
		and poison.contract().bound_states == 0, "reset clears poisoned bindings")

func _admission_and_thread_gates(profile: Dictionary) -> void:
	var malformed := Batch.new()
	_check(malformed.configure("malformed", 1, 1)
		and not malformed.bind_states([{"solver": RefCounted.new(),
			"vehicle_id": "malformed", "life_generation": 1}])
		and malformed.contract().bound_states == 0,
		"malformed RefCounted fails closed before method calls")
	var duplicate_a := _new_solver(profile, "duplicate-owner")
	var duplicate_b := _new_solver(profile, "duplicate-owner")
	var duplicate := Batch.new()
	_check(duplicate.configure("duplicate", 2, 1)
		and not duplicate.bind_states([
			{"solver": duplicate_a, "vehicle_id": "duplicate-owner", "life_generation": 1},
			{"solver": duplicate_b, "vehicle_id": "duplicate-owner", "life_generation": 1},
		]) and duplicate.contract().bound_states == 0,
		"distinct solver refs cannot share a vehicle-life wire identity")
	var shared_solver := _new_solver(profile, "cross-executor-owner")
	var shared_rows := [{"solver": shared_solver, "vehicle_id": "cross-executor-owner",
		"life_generation": 1}]
	var first_owner := Batch.new()
	var second_owner := Batch.new()
	_check(first_owner.configure("first-owner", 1, 1)
		and second_owner.configure("second-owner", 1, 1)
		and first_owner.bind_states(shared_rows)
		and not second_owner.bind_states(shared_rows),
		"cross-executor claim rejects the same solver ref")
	_check(first_owner.reset_session_wait("first-owner-released")
		and second_owner.bind_states(shared_rows),
		"reset releases claim for a different executor to bind")
	_check(second_owner.retire_wait(), "retire releases cross-executor claim")
	var fleet := _fleet(profile, 1, "thread-gate")
	var configure_target := Batch.new()
	var bound_target := Batch.new()
	_check(bound_target.configure("thread-gate-bound", 1, 1)
		and bound_target.bind_states(fleet.rows), "thread gate fixture binds on main")
	var before := bound_target.contract().duplicate(true)
	var probe := OffMainProbe.new()
	probe.configure_target = configure_target
	probe.bound_target = bound_target
	probe.rows = fleet.rows
	var thread := Thread.new()
	_check(thread.start(probe.run) == OK, "adversarial consumer thread starts")
	thread.wait_to_finish()
	_check(probe.results.configure == false and probe.results.bind == false
		and probe.results.begin.accepted == false
		and probe.results.begin.reason == "main-thread-required"
		and probe.results.finish.accepted == false
		and probe.results.finish.reason == "main-thread-required"
		and probe.results.step.accepted == false
		and probe.results.step.reason == "main-thread-required"
		and probe.results.reset == false and probe.results.retire == false
		and probe.results.contract.is_empty(),
		"every public consumer API fails closed off main thread")
	_check(configure_target.contract().configured == false
		and bound_target.contract() == before,
		"off-main adversarial calls mutate neither unconfigured nor bound executor")
	_check(bound_target.retire_wait(), "thread gate fixture retires on main")

func _rearm_life(solvers: Array, ids: Array[String], profile: Dictionary,
		life: int, tick: int, sequence: int) -> bool:
	for index in solvers.size():
		var row := _impact_row(profile, ids[index], tick, sequence, 10.0)
		row.life_generation = life
		var result: Dictionary = solvers[index].apply_impact_native(row)
		if not result.applied or not solvers[index].snapshot_source().active:
			return false
	return true

func _percentile(sorted_samples: Array[int], fraction: float) -> int:
	return sorted_samples[mini(sorted_samples.size() - 1,
		maxi(0, int(ceil(fraction * sorted_samples.size())) - 1))]

func _metrics(samples: Array[int]) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"samples": samples.size(), "p50_usec": _percentile(ordered, 0.50),
		"p95_usec": _percentile(ordered, 0.95),
		"p99_usec": _percentile(ordered, 0.99), "max_usec": ordered[-1]}

func _benchmark(profile: Dictionary, size: int, workers: int) -> void:
	var serial_fleet := _fleet(profile, size, "bench-serial-" + str(size) + "-" + str(workers))
	var parallel_solvers: Array = []
	parallel_solvers.resize(size)
	for index in size:
		parallel_solvers[index] = _new_solver(profile, serial_fleet.ids[index])
	var parallel_fleet := {"solvers": parallel_solvers, "ids": serial_fleet.ids.duplicate(),
		"rows": _rows(parallel_solvers, serial_fleet.ids)}
	var batch := Batch.new()
	_check(batch.configure("bench-" + str(size) + "-" + str(workers), size, workers)
		and batch.bind_states(parallel_fleet.rows), "benchmark executor configures and binds")
	var serial_samples: Array[int] = []
	var parallel_samples: Array[int] = []
	for sample_index in PERF_WARMUP + PERF_SAMPLES:
		var speed := 3.0
		_check(_rearm(serial_fleet.solvers, serial_fleet.ids, profile,
			sample_index, sample_index, speed)
			and _rearm(parallel_fleet.solvers, parallel_fleet.ids, profile,
				sample_index, sample_index, speed), "benchmark identical fleets rearm outside timer")
		var serial: Dictionary
		var parallel: Dictionary
		if sample_index % 2 == 0:
			serial = _serial_step_publish(serial_fleet.solvers, serial_fleet.ids, 1,
				sample_index + 1, sample_index >= PERF_WARMUP)
			parallel = _parallel_step_publish(batch, sample_index + 1,
				sample_index >= PERF_WARMUP)
		else:
			parallel = _parallel_step_publish(batch, sample_index + 1,
				sample_index >= PERF_WARMUP)
			serial = _serial_step_publish(serial_fleet.solvers, serial_fleet.ids, 1,
				sample_index + 1, sample_index >= PERF_WARMUP)
		_check(serial.accepted and parallel.accepted and serial.states == parallel.states,
			"benchmark serial/parallel complete snapshots exact")
		if sample_index >= PERF_WARMUP:
			serial_samples.append(serial.elapsed_usec)
			parallel_samples.append(parallel.elapsed_usec)
	var serial_metrics := _metrics(serial_samples)
	var parallel_metrics := _metrics(parallel_samples)
	perf_rows.append({"fleet_size": size, "worker_limit": workers,
		"serial": serial_metrics, "parallel": parallel_metrics,
		"speedup_p50": float(serial_metrics.p50_usec) / maxf(1.0, parallel_metrics.p50_usec),
		"speedup_p95": float(serial_metrics.p95_usec) / maxf(1.0, parallel_metrics.p95_usec)})
	_check(batch.retire_wait(), "benchmark executor retires")

func _run() -> void:
	var suite_started := Time.get_ticks_msec()
	_check(FileAccess.get_sha256(SOLVER) == SOLVER_SHA256, "frozen solver receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "manifest receipt")
	var profiles := _profiles(_manifest())
	_check(profiles.size() == 13, "all 13 source profiles resolve")
	for workers in [1, 2, 4, 8]:
		_parity_13(profiles, workers)
	_lifecycle(profiles[1])
	_admission_and_thread_gates(profiles[1])
	for size in PERF_SIZES:
		for workers in PERF_WORKERS:
			_benchmark(profiles[1], size, workers)
	var runtime_seconds := (Time.get_ticks_msec() - suite_started) / 1000.0
	_check(runtime_seconds < 30.0, "thread candidate proof and benchmark stays under 30 seconds")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"solver_sha256": FileAccess.get_sha256(SOLVER),
		"candidate_sha256": FileAccess.get_sha256(
			"res://scripts/vehicle_physics/vehicle_crash_solver_batch_candidate.gd"),
		"manifest_sha256": FileAccess.get_sha256(MANIFEST), "profiles": profiles.size(),
		"parity_worker_limits": [1, 2, 4, 8], "perf_worker_limits": PERF_WORKERS,
		"perf_sizes": PERF_SIZES, "warmup_batches": PERF_WARMUP,
		"measured_batches": PERF_SAMPLES, "perf": perf_rows,
		"runtime_seconds": runtime_seconds,
		"host": {"os": OS.get_name(), "cpu": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(), "process_id": OS.get_process_id(),
			"engine": Engine.get_version_info().string},
		"scope": "isolated independent RefCounted solver group tasks and joined main-thread publication; complete batch CPU cost not FPS; no Scene Resource server HP authority body main GPU LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_BATCH_CANDIDATE_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
