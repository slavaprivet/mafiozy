extends SceneTree
## Heterogeneous per-vehicle input parity and single-state fast-path wall latency.

const Solver = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const BatchRows = preload("res://scripts/vehicle_physics/vehicle_crash_solver_batch_inputs_candidate.gd")
const SOLVER := "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
const SOLVER_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const PARENT := "res://scripts/vehicle_physics/vehicle_crash_solver_batch_candidate.gd"
const PARENT_SHA256 := "ac553088e34defc70969c79e97d7b92c50231566e0b2c7e25384c97148aea2bd"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const PERF_WARMUP := 8
const PERF_SAMPLES := 64

class OffMainRowsProbe extends RefCounted:
	var target: RefCounted
	var rows: Array
	var results := {}
	func run() -> void:
		results = {"begin": target.begin_step_batch_rows(rows),
			"step": target.step_batch_rows(rows), "contract": target.input_contract()}

var checks := 0
var failures: Array[String] = []
var identity_sequence := 0
var perf := {}

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _profiles() -> Array[Dictionary]:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var result: Array[Dictionary] = []
	if not document is Dictionary:
		return result
	for entry_value: Variant in document.entries:
		if not entry_value is Dictionary:
			continue
		for node_value: Variant in entry_value.nodes:
			if node_value is Dictionary and node_value.get("source_metadata") is Dictionary \
					and node_value.source_metadata.get("vehicleProfile") is Dictionary:
				result.append(node_value.source_metadata.vehicleProfile)
				break
	return result

func _new_solver(profile: Dictionary, id: String) -> RefCounted:
	var solver := Solver.new()
	return solver if solver.configure(id, 1, profile.id, MANIFEST_SHA256, profile) else null

func _impact(profile: Dictionary, solver: RefCounted, id: String, tick: int,
		sequence: int, speed := 10.0) -> bool:
	var side := sequence % 4
	var point: Vector3
	var normal: Vector3
	match side:
		0:
			point = Vector3(0.0, 0.8, float(profile.halfLength))
			normal = Vector3(0.0, 0.0, 1.0)
		1:
			point = Vector3(float(profile.halfWidth), 0.9, 0.0)
			normal = Vector3(1.0, 0.0, 0.0)
		2:
			point = Vector3(0.0, 0.8, -float(profile.halfLength))
			normal = Vector3(0.0, 0.0, -1.0)
		_:
			point = Vector3(-float(profile.halfWidth), 0.9, 0.0)
			normal = Vector3(-1.0, 0.0, 0.0)
	var result: Dictionary = solver.apply_impact_native({"vehicle_id": id,
		"life_generation": 1, "physics_tick": tick, "impact_sequence": sequence,
		"event_id": "heterogeneous-impact-" + str(sequence),
		"point_native_m": Solver.source_local_to_native(point),
		"normal_native": Solver.source_local_to_native(normal),
		"impact_speed_mps": speed})
	return result.applied

func _publish_serial(solvers: Array, ids: Array[String], rows: Array,
		measure := false) -> Dictionary:
	var by_identity := {}
	for row: Dictionary in rows:
		by_identity[JSON.stringify([row.vehicle_id, row.life_generation])] = row
	var states: Array = []
	states.resize(solvers.size())
	var started := Time.get_ticks_usec() if measure else 0
	for index in solvers.size():
		var solver: RefCounted = solvers[index]
		var row: Dictionary = by_identity[JSON.stringify([ids[index], 1])]
		var step: Dictionary = solver.step(row.delta, row.speed, row.throttle,
			row.physics_tick)
		states[index] = {"vehicle_id": ids[index], "life_generation": 1,
			"step": step.duplicate(true), "mechanical": solver.mechanical_snapshot(),
			"deformation": solver.deformation_snapshot_native()}
	return {"accepted": states.all(func(state: Dictionary) -> bool:
		return state.step.accepted), "states": states,
		"elapsed_usec": Time.get_ticks_usec() - started if measure else 0}

func _heterogeneous_rows(ids: Array[String], tick: int) -> Array:
	var deltas := [0.0, 0.001, 1.0 / 120.0, 1.0 / 60.0, 0.08, 0.1]
	var rows: Array = []
	rows.resize(ids.size())
	for index in ids.size():
		rows[index] = {"vehicle_id": ids[index], "life_generation": 1,
			"physics_tick": tick, "delta": deltas[(index + tick) % deltas.size()],
			"speed": float((index * 7 + tick * 3) % 29) - 8.5,
			"throttle": float((index + tick) % 9) / 4.0 - 1.0}
	rows.reverse()
	return rows

func _heterogeneous_parity(profiles: Array[Dictionary]) -> void:
	var serial_solvers: Array = []
	var parallel_solvers: Array = []
	var ids: Array[String] = []
	serial_solvers.resize(profiles.size())
	parallel_solvers.resize(profiles.size())
	ids.resize(profiles.size())
	var bind_rows: Array = []
	bind_rows.resize(profiles.size())
	for index in profiles.size():
		identity_sequence += 1
		var id := "heterogeneous-" + str(identity_sequence)
		ids[index] = id
		serial_solvers[index] = _new_solver(profiles[index], id)
		parallel_solvers[index] = _new_solver(profiles[index], id)
		bind_rows[index] = {"solver": parallel_solvers[index], "vehicle_id": id,
			"life_generation": 1}
		_check(_impact(profiles[index], serial_solvers[index], id, 0, 0)
			and _impact(profiles[index], parallel_solvers[index], id, 0, 0),
			"all-profile initial impact " + str(index))
	var batch := BatchRows.new()
	_check(batch.configure("heterogeneous-all13", 16, 4) and batch.bind_states(bind_rows),
		"heterogeneous executor binds all13")
	for tick in 1 + 24:
		var rows := _heterogeneous_rows(ids, tick + 1)
		var serial := _publish_serial(serial_solvers, ids, rows)
		var parallel: Dictionary = batch.step_batch_rows(rows)
		_check(serial.accepted and parallel.accepted and parallel.fast_path == false
			and serial.states == parallel.states,
			"all13 heterogeneous source parity batch " + str(tick))
	# Begin copies every scalar before workers start; mutate all caller dictionaries
	# after submit and compare with serial states produced from a deep original copy.
	var copied_input := _heterogeneous_rows(ids, 26)
	var original := copied_input.duplicate(true)
	var serial := _publish_serial(serial_solvers, ids, original)
	var begun: Dictionary = batch.begin_step_batch_rows(copied_input)
	for row: Dictionary in copied_input:
		row.speed = NAN
		row.throttle = NAN
		row.physics_tick = -1
	var parallel: Dictionary = batch.finish_step_batch(begun.task_id)
	_check(begun.accepted and serial.states == parallel.states,
		"caller mutation after begin cannot alter copied worker inputs")
	var before: Array = []
	for solver: RefCounted in parallel_solvers:
		before.append(solver.snapshot_source())
	var valid_next := _heterogeneous_rows(ids, 27)
	var malformed_cases := []
	var missing := valid_next.duplicate(true)
	missing.pop_back()
	malformed_cases.append(missing)
	var duplicate := valid_next.duplicate(true)
	duplicate[0] = duplicate[1].duplicate(true)
	malformed_cases.append(duplicate)
	var nonfinite := valid_next.duplicate(true)
	nonfinite[0].speed = NAN
	malformed_cases.append(nonfinite)
	var wrong_life := valid_next.duplicate(true)
	wrong_life[0].life_generation = 2
	malformed_cases.append(wrong_life)
	var stale := valid_next.duplicate(true)
	stale[0].physics_tick = 26
	malformed_cases.append(stale)
	for case_index in malformed_cases.size():
		var result: Dictionary = batch.begin_step_batch_rows(malformed_cases[case_index])
		var unchanged := true
		for index in parallel_solvers.size():
			unchanged = unchanged and parallel_solvers[index].snapshot_source() == before[index]
		_check(not result.accepted and not batch.contract().in_flight and unchanged,
			"malformed heterogeneous row set rejects without partial submit " + str(case_index))
	var probe := OffMainRowsProbe.new()
	probe.target = batch
	probe.rows = valid_next
	var contract_before := batch.contract().duplicate(true)
	var thread := Thread.new()
	_check(thread.start(probe.run) == OK, "heterogeneous off-main probe starts")
	thread.wait_to_finish()
	_check(not probe.results.begin.accepted and probe.results.begin.reason == "main-thread-required"
		and not probe.results.step.accepted and probe.results.step.reason == "main-thread-required"
		and probe.results.contract.is_empty() and batch.contract() == contract_before,
		"new heterogeneous public APIs are main-thread-only without mutation")
	_check(batch.retire_wait(), "heterogeneous executor retires")

func _percentile(sorted_samples: Array[int], fraction: float) -> int:
	return sorted_samples[mini(sorted_samples.size() - 1,
		maxi(0, int(ceil(fraction * sorted_samples.size())) - 1))]

func _metrics(samples: Array[int]) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"samples": samples.size(), "p50_usec": _percentile(ordered, 0.50),
		"p95_usec": _percentile(ordered, 0.95),
		"p99_usec": _percentile(ordered, 0.99), "max_usec": ordered[-1]}

func _single_fast_path(profile: Dictionary) -> void:
	var id := "single-fast-path"
	var direct := _new_solver(profile, id)
	var fast_solver := _new_solver(profile, id)
	var group_solver := _new_solver(profile, id)
	var fast := BatchRows.new()
	var group := BatchRows.new()
	_check(fast.configure("single-fast", 1, 2)
		and fast.bind_states([{"solver": fast_solver, "vehicle_id": id,
			"life_generation": 1}]) and group.configure("single-group", 1, 2)
		and group.bind_states([{"solver": group_solver, "vehicle_id": id,
			"life_generation": 1}]), "single-state fast and group fixtures bind")
	var direct_samples: Array[int] = []
	var fast_samples: Array[int] = []
	var group_samples: Array[int] = []
	for sample_index in PERF_WARMUP + PERF_SAMPLES:
		var speed := 3.0
		_check(_impact(profile, direct, id, sample_index, sample_index, speed)
			and _impact(profile, fast_solver, id, sample_index, sample_index, speed)
			and _impact(profile, group_solver, id, sample_index, sample_index, speed),
			"single-state fixtures rearm outside measured region")
		var rows := [{"vehicle_id": id, "life_generation": 1,
			"physics_tick": sample_index + 1, "delta": 1.0 / 60.0,
			"speed": float(sample_index % 17),
			"throttle": float(sample_index % 5) / 2.0 - 1.0}]
		var direct_result := _publish_serial([direct], [id], rows,
			sample_index >= PERF_WARMUP)
		var fast_started := Time.get_ticks_usec() if sample_index >= PERF_WARMUP else 0
		var fast_result: Dictionary = fast.step_batch_rows(rows)
		var fast_elapsed := Time.get_ticks_usec() - fast_started \
			if sample_index >= PERF_WARMUP else 0
		var group_started := Time.get_ticks_usec() if sample_index >= PERF_WARMUP else 0
		var begun: Dictionary = group.begin_step_batch_rows(rows)
		var group_result: Dictionary = group.finish_step_batch(begun.task_id)
		var group_elapsed := Time.get_ticks_usec() - group_started \
			if sample_index >= PERF_WARMUP else 0
		_check(direct_result.states == fast_result.states
			and direct_result.states == group_result.states and fast_result.fast_path,
			"single-state direct fast and group paths are source-identical")
		if sample_index >= PERF_WARMUP:
			direct_samples.append(direct_result.elapsed_usec)
			fast_samples.append(fast_elapsed)
			group_samples.append(group_elapsed)
	perf = {"direct_serial": _metrics(direct_samples),
		"candidate_fast_path": _metrics(fast_samples),
		"candidate_group_path": _metrics(group_samples)}
	_check(fast.retire_wait() and group.retire_wait(), "single-state fixtures retire")

func _run() -> void:
	var suite_started := Time.get_ticks_msec()
	_check(FileAccess.get_sha256(SOLVER) == SOLVER_SHA256, "frozen solver receipt")
	_check(FileAccess.get_sha256(PARENT) == PARENT_SHA256, "frozen batch parent receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "manifest receipt")
	var profiles := _profiles()
	_check(profiles.size() == 13, "all13 profiles resolve")
	_heterogeneous_parity(profiles)
	_single_fast_path(profiles[1])
	var runtime_seconds := (Time.get_ticks_msec() - suite_started) / 1000.0
	_check(runtime_seconds < 30.0, "heterogeneous candidate proof remains bounded")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"solver_sha256": FileAccess.get_sha256(SOLVER),
		"parent_sha256": FileAccess.get_sha256(PARENT),
		"candidate_sha256": FileAccess.get_sha256(
			"res://scripts/vehicle_physics/vehicle_crash_solver_batch_inputs_candidate.gd"),
		"manifest_sha256": FileAccess.get_sha256(MANIFEST), "profiles": profiles.size(),
		"heterogeneous_batches": 26, "single_fast_path_warmup": PERF_WARMUP,
		"single_fast_path_samples": PERF_SAMPLES, "single_state_wall_latency": perf,
		"runtime_seconds": runtime_seconds,
		"host": {"os": OS.get_name(), "cpu": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(), "process_id": OS.get_process_id(),
			"engine": Engine.get_version_info().string},
		"scope": "per-state copied drive/thermal inputs and complete-batch wall latency; not aggregate CPU or FPS; no production main body HP authority GPU LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_BATCH_INPUTS_CANDIDATE_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
