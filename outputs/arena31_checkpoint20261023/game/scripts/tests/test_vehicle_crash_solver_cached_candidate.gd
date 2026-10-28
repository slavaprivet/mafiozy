extends SceneTree
## Differential source-fidelity and bounded CPU evidence for the candidate
## fixed-step override. No production solver, body, main, rendering or GPU use.

const Frozen = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const Candidate = preload("res://scripts/vehicle_physics/vehicle_crash_solver_cached_candidate.gd")
const FROZEN_PATH := "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
const FROZEN_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const WARMUP_BATCHES := 8
const MEASURED_BATCHES := 32
const PERF_SIZES := [1, 16, 72]
const HZ := 60
const DELTA := 1.0 / HZ
const SUBSTEPS_PER_CAR := 240 / HZ

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

func _configure_pair(profile: Dictionary, tag: String) -> Array:
	identity_sequence += 1
	var vehicle_id := tag + "-" + str(identity_sequence)
	var frozen := Frozen.new()
	var candidate := Candidate.new()
	var ok_a := frozen.configure(vehicle_id, 1, profile.id, MANIFEST_SHA256, profile)
	var ok_b := candidate.configure(vehicle_id, 1, profile.id, MANIFEST_SHA256, profile)
	_check(ok_a and ok_b, tag + " pair configures")
	return [frozen, candidate, vehicle_id]

func _contact(profile: Dictionary, vehicle_id: String, kind: int,
		sequence: int) -> Dictionary:
	var point: Vector3
	var normal: Vector3
	var speed: float
	match kind:
		0:
			point = Vector3(0.0, 0.8, float(profile.halfLength))
			normal = Vector3(0.0, 0.0, 1.0)
			speed = 32.0
		1:
			point = Vector3(float(profile.halfWidth), 0.9, 0.35)
			normal = Vector3(1.0, 0.0, 0.0)
			speed = 17.0
		_:
			var wheel: Dictionary = profile.wheelPositions.front_left
			point = Vector3(wheel.x, wheel.y, wheel.z)
			normal = Vector3(1.0, 0.0, 0.0)
			speed = 28.0
	return {"vehicle_id": vehicle_id, "life_generation": 1, "physics_tick": 0,
		"impact_sequence": sequence, "event_id": "parity-" + str(sequence),
		"point_native_m": Frozen.source_local_to_native(point),
		"normal_native": Frozen.source_local_to_native(normal), "impact_speed_mps": speed}

func _step_parity_all_profiles(profiles: Array[Dictionary]) -> void:
	var operations := [
		{"dt": 0.0, "speed": 0.0, "throttle": 0.0},
		{"dt": 0.001, "speed": 0.0, "throttle": 1.0},
		{"dt": 1.0 / 120.0, "speed": 4.0, "throttle": 0.7},
		{"dt": 1.0 / 60.0, "speed": 8.0, "throttle": 1.0},
		{"dt": 0.08, "speed": 0.0, "throttle": 1.0},
		{"dt": 0.25, "speed": 0.0, "throttle": 1.0},
	]
	for index in 32:
		operations.append({"dt": 0.1, "speed": 8.0 if index % 2 == 0 else 0.0,
			"throttle": 1.0})
	for profile: Dictionary in profiles:
		var pair := _configure_pair(profile, "parity-" + str(profile.id))
		var frozen: RefCounted = pair[0]
		var candidate: RefCounted = pair[1]
		var vehicle_id: String = pair[2]
		_check(frozen.snapshot_source() == candidate.snapshot_source(),
			profile.id + " identical initial state")
		for impact_index in 3:
			var row := _contact(profile, vehicle_id, impact_index, impact_index)
			var frozen_result: Dictionary = frozen.apply_impact_native(row)
			var candidate_result: Dictionary = candidate.apply_impact_native(row)
			_check(frozen_result == candidate_result,
				profile.id + " impact result " + str(impact_index))
			_check(frozen.snapshot_source() == candidate.snapshot_source(),
				profile.id + " full state after impact " + str(impact_index))
		for operation_index in operations.size():
			var operation: Dictionary = operations[operation_index]
			var frozen_result: Dictionary = frozen.step(operation.dt, operation.speed,
				operation.throttle, operation_index + 1)
			var candidate_result: Dictionary = candidate.step(operation.dt, operation.speed,
				operation.throttle, operation_index + 1)
			_check(frozen_result == candidate_result,
				profile.id + " step result " + str(operation_index))
			_check(frozen.snapshot_source() == candidate.snapshot_source(),
				profile.id + " every state after step " + str(operation_index))

func _moving_threshold_regression(profile: Dictionary) -> void:
	for speed in [0.0008 - 0.000000000001, 0.0008, 0.0008 + 0.000000000001]:
		var pair := _configure_pair(profile, "threshold-" + str(speed))
		var frozen: RefCounted = pair[0]
		var candidate: RefCounted = pair[1]
		for index in Frozen.NODE_COUNT:
			frozen._position[index] = frozen._plastic[index]
			candidate._position[index] = candidate._plastic[index]
			frozen._velocity[index] = Vector3.ZERO
			candidate._velocity[index] = Vector3.ZERO
		frozen._velocity[0] = Vector3(speed, 0.0, 0.0)
		candidate._velocity[0] = Vector3(speed, 0.0, 0.0)
		var frozen_moving: bool = frozen._fixed_step(0.0)
		var candidate_moving: bool = candidate._fixed_step(0.0)
		_check(frozen_moving == candidate_moving,
			"length-squared boundary matches sqrt at " + str(speed))
		_check(frozen.snapshot_source() == candidate.snapshot_source(),
			"threshold probe preserves identical full state at " + str(speed))

func _new_active(script: GDScript, profile: Dictionary, tag: String) -> RefCounted:
	identity_sequence += 1
	var vehicle_id := tag + "-" + str(identity_sequence)
	var solver: RefCounted = script.new()
	if not solver.configure(vehicle_id, 1, profile.id, MANIFEST_SHA256, profile):
		return null
	var row := _contact(profile, vehicle_id, 0, 0)
	row.impact_speed_mps = 60.0
	var result: Dictionary = solver.apply_impact_native(row)
	return solver if result.applied and solver.snapshot_source().active else null

func _fleet(script: GDScript, profile: Dictionary, size: int, tag: String) -> Array:
	var fleet: Array = []
	fleet.resize(size)
	for index in size:
		fleet[index] = _new_active(script, profile, tag + "-" + str(index))
	return fleet

func _timed_batch(fleet: Array, measure: bool) -> Dictionary:
	var accepted := true
	var substeps := 0
	var started := Time.get_ticks_usec() if measure else 0
	for solver: Variant in fleet:
		if solver == null:
			accepted = false
			continue
		var result: Dictionary = solver.step(DELTA, 8.0, 1.0, 1)
		accepted = accepted and result.accepted
		substeps += int(result.substeps)
	return {"accepted": accepted, "substeps": substeps,
		"elapsed_usec": Time.get_ticks_usec() - started if measure else 0}

func _percentile(sorted_samples: Array[int], fraction: float) -> int:
	return sorted_samples[mini(sorted_samples.size() - 1,
		maxi(0, int(ceil(fraction * sorted_samples.size())) - 1))]

func _metrics(samples: Array[int]) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"samples": samples.size(), "p50_usec": _percentile(ordered, 0.50),
		"p95_usec": _percentile(ordered, 0.95),
		"p99_usec": _percentile(ordered, 0.99), "max_usec": ordered[-1]}

func _measure_size(profile: Dictionary, size: int) -> void:
	for warm_index in WARMUP_BATCHES:
		for script in [Frozen, Candidate]:
			var result := _timed_batch(_fleet(script, profile, size,
				"warm-" + str(size) + "-" + str(warm_index)), false)
			_check(result.accepted and result.substeps == size * SUBSTEPS_PER_CAR,
				"warm batch exact source work")
	var frozen_samples: Array[int] = []
	var candidate_samples: Array[int] = []
	for sample_index in MEASURED_BATCHES:
		var first_script: GDScript = Frozen if sample_index % 2 == 0 else Candidate
		var second_script: GDScript = Candidate if sample_index % 2 == 0 else Frozen
		for script in [first_script, second_script]:
			var fleet := _fleet(script, profile, size,
				"measured-" + str(size) + "-" + str(sample_index))
			var result := _timed_batch(fleet, true)
			_check(result.accepted and result.substeps == size * SUBSTEPS_PER_CAR,
				"measured batch exact source work")
			if script == Frozen:
				frozen_samples.append(result.elapsed_usec)
			else:
				candidate_samples.append(result.elapsed_usec)
	var frozen_metrics := _metrics(frozen_samples)
	var candidate_metrics := _metrics(candidate_samples)
	perf_rows.append({"fleet_size": size, "frozen": frozen_metrics,
		"candidate": candidate_metrics,
		"speedup_p50": float(frozen_metrics.p50_usec) / maxf(1.0, candidate_metrics.p50_usec),
		"speedup_p95": float(frozen_metrics.p95_usec) / maxf(1.0, candidate_metrics.p95_usec)})

func _run() -> void:
	var suite_started := Time.get_ticks_msec()
	_check(FileAccess.get_sha256(FROZEN_PATH) == FROZEN_SHA256, "frozen parent receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "pinned manifest receipt")
	var profiles := _profiles(_manifest())
	_check(profiles.size() == 13, "all 13 actual manifest profiles resolve")
	_step_parity_all_profiles(profiles)
	_moving_threshold_regression(profiles[1])
	for size in PERF_SIZES:
		_measure_size(profiles[1], size)
	var runtime_seconds := (Time.get_ticks_msec() - suite_started) / 1000.0
	_check(runtime_seconds < 30.0, "candidate differential and perf receipt stays under 30 seconds")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"frozen_sha256": FileAccess.get_sha256(FROZEN_PATH),
		"candidate_sha256": FileAccess.get_sha256(
			"res://scripts/vehicle_physics/vehicle_crash_solver_cached_candidate.gd"),
		"manifest_sha256": FileAccess.get_sha256(MANIFEST), "profiles": profiles.size(),
		"parity_steps_per_profile": 38, "warmup_batches": WARMUP_BATCHES,
		"measured_batches": MEASURED_BATCHES, "hz": HZ, "perf": perf_rows,
		"runtime_seconds": runtime_seconds,
		"host": {"os": OS.get_name(), "cpu": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(), "process_id": OS.get_process_id(),
			"engine": Engine.get_version_info().string},
		"scope": "candidate subclass differential against source-verified frozen solver plus native CPU batch call cost; no FPS timestep reduction culling authority body main GPU LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_CACHED_CANDIDATE_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
