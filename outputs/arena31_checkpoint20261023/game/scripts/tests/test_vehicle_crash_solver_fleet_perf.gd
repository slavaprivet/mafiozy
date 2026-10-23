extends SceneTree
## Measured native fleet batch cost for damaged active versus source-settled
## crash mechanics. CPU-only call cost; not FPS, rendering or loaded-city proof.

const Solver = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const SOLVER := "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
const SOLVER_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const PROFILE_ID := "compact_sedan"
const HZ := 60
const DELTA := 1.0 / HZ
const SUBSTEPS_PER_ACTIVE_CAR := 240 / HZ
const WARMUP_BATCHES := 32
const MEASURED_BATCHES := 96
# A 240-batch calibration on this same host took 53.528 seconds because every
# active sample intentionally rebuilds/re-arms its entire fleet outside timing.
# The bounded receipt therefore retains the identical timed workload at 96
# independent samples per case rather than presenting a >30-second run as valid.
const CALIBRATION_240_RUNTIME_SECONDS := 53.528
const FLEET_SIZES := [16, 72]

var checks := 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var identity_sequence := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _profile() -> Dictionary:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not document is Dictionary:
		return {}
	for entry_value: Variant in document.get("entries", []):
		if not entry_value is Dictionary or entry_value.get("profile_id") != PROFILE_ID:
			continue
		for node_value: Variant in entry_value.get("nodes", []):
			if node_value is Dictionary and node_value.get("source_metadata") is Dictionary:
				var metadata: Dictionary = node_value.source_metadata
				if metadata.get("vehicleProfile") is Dictionary:
					return metadata.vehicleProfile
	return {}

func _new_active(profile: Dictionary, tag: String) -> RefCounted:
	identity_sequence += 1
	var vehicle_id := tag + "-" + str(identity_sequence)
	var solver := Solver.new()
	if not solver.configure(vehicle_id, 1, PROFILE_ID, MANIFEST_SHA256, profile):
		return null
	var source_point := Vector3(0.0, 0.8, float(profile.halfLength))
	var source_normal := Vector3(0.0, 0.0, 1.0)
	var result: Dictionary = solver.apply_impact_native({"vehicle_id": vehicle_id,
		"life_generation": 1, "physics_tick": 0, "impact_sequence": 0,
		"event_id": "fleet-perf-arm", "point_native_m": Solver.source_local_to_native(source_point),
		"normal_native": Solver.source_local_to_native(source_normal),
		"impact_speed_mps": 60.0})
	if not result.applied or not solver.snapshot_source().active:
		return null
	return solver

func _active_fleet(profile: Dictionary, size: int, tag: String) -> Array:
	var fleet: Array = []
	fleet.resize(size)
	for index in size:
		fleet[index] = _new_active(profile, tag + "-" + str(index))
	return fleet

func _valid_fleet(fleet: Array, expected_active: bool) -> bool:
	for solver: Variant in fleet:
		if solver == null or bool(solver.snapshot_source().active) != expected_active:
			return false
	return true

func _step_batch(fleet: Array, tick: int, expected_substeps: int,
		measure: bool) -> Dictionary:
	var accepted := true
	var substeps := 0
	var started := Time.get_ticks_usec() if measure else 0
	for solver: Variant in fleet:
		var result: Dictionary = solver.step(DELTA, 8.0, 1.0, tick)
		accepted = accepted and result.accepted
		substeps += int(result.substeps)
	var elapsed := Time.get_ticks_usec() - started if measure else 0
	return {"accepted": accepted, "substeps": substeps,
		"expected_substeps": expected_substeps, "elapsed_usec": elapsed}

func _settled_fleet(profile: Dictionary, size: int, tag: String) -> Dictionary:
	var fleet := _active_fleet(profile, size, tag)
	if not _valid_fleet(fleet, true):
		return {"fleet": fleet, "tick": 0, "settle_steps": 0}
	var tick := 0
	var settle_steps := 0
	while settle_steps < 2000:
		var all_settled := true
		for solver: Variant in fleet:
			if solver.snapshot_source().active:
				all_settled = false
				tick += 1
				solver.step(0.1, 0.0, 0.0, tick)
		if all_settled:
			break
		settle_steps += 1
	# The identical fleet may have received different monotonically increasing
	# ticks, so subsequent callers use each solver's own last admitted tick.
	return {"fleet": fleet, "tick": tick, "settle_steps": settle_steps}

func _step_settled_batch(fleet: Array, measure: bool) -> Dictionary:
	var accepted := true
	var substeps := 0
	var started := Time.get_ticks_usec() if measure else 0
	for solver: Variant in fleet:
		var next_tick: int = solver.runtime_contract().last_step_physics_tick + 1
		var result: Dictionary = solver.step(DELTA, 0.0, 0.0, next_tick)
		accepted = accepted and result.accepted
		substeps += int(result.substeps)
	var elapsed := Time.get_ticks_usec() - started if measure else 0
	return {"accepted": accepted, "substeps": substeps, "elapsed_usec": elapsed}

func _percentile(sorted_samples: Array[int], fraction: float) -> int:
	return sorted_samples[mini(sorted_samples.size() - 1,
		maxi(0, int(ceil(fraction * sorted_samples.size())) - 1))]

func _metrics(samples: Array[int]) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"samples": samples.size(), "p50_usec": _percentile(ordered, 0.50),
		"p95_usec": _percentile(ordered, 0.95),
		"p99_usec": _percentile(ordered, 0.99), "max_usec": ordered[-1]}

func _measure_active(profile: Dictionary, size: int) -> Dictionary:
	for warm_index in WARMUP_BATCHES:
		var fleet := _active_fleet(profile, size,
			"warm-active-" + str(size) + "-" + str(warm_index))
		_check(_valid_fleet(fleet, true), "warm active fleet re-arms outside timer")
		var result := _step_batch(fleet, 1, size * SUBSTEPS_PER_ACTIVE_CAR, false)
		_check(result.accepted and result.substeps == result.expected_substeps,
			"warm active batch exact source substeps")
	var samples: Array[int] = []
	var total_substeps := 0
	for sample_index in MEASURED_BATCHES:
		var fleet := _active_fleet(profile, size,
			"measured-active-" + str(size) + "-" + str(sample_index))
		_check(_valid_fleet(fleet, true), "measured active fleet re-arms outside timer")
		var result := _step_batch(fleet, 1, size * SUBSTEPS_PER_ACTIVE_CAR, true)
		samples.append(result.elapsed_usec)
		total_substeps += int(result.substeps)
		_check(result.accepted and result.substeps == result.expected_substeps,
			"measured active batch exact source substeps")
	_check(total_substeps == MEASURED_BATCHES * size * SUBSTEPS_PER_ACTIVE_CAR,
		"active fleet measured total is exact 240 structural steps per car-second")
	return {"state": "all-active-damaged", "fleet_size": size,
		"total_structural_substeps": total_substeps, "timing": _metrics(samples)}

func _measure_settled(profile: Dictionary, size: int) -> Dictionary:
	var prepared := _settled_fleet(profile, size, "settled-" + str(size))
	var fleet: Array = prepared.fleet
	_check(_valid_fleet(fleet, false) and int(prepared.settle_steps) < 2000,
		"damaged fleet reaches exact source inactive settled condition")
	for warm_index in WARMUP_BATCHES:
		var result := _step_settled_batch(fleet, false)
		_check(result.accepted and result.substeps == 0,
			"warm settled batch has zero structural substeps")
	var samples: Array[int] = []
	for sample_index in MEASURED_BATCHES:
		var result := _step_settled_batch(fleet, true)
		samples.append(result.elapsed_usec)
		_check(result.accepted and result.substeps == 0,
			"measured settled batch has zero structural substeps")
	return {"state": "source-settled-damaged", "fleet_size": size,
		"settle_calls": prepared.settle_steps, "total_structural_substeps": 0,
		"timing": _metrics(samples)}

func _run() -> void:
	var suite_started := Time.get_ticks_msec()
	_check(FileAccess.get_sha256(SOLVER) == SOLVER_SHA256, "frozen solver receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "exact manifest receipt")
	var profile := _profile()
	_check(not profile.is_empty(), "compact profile resolves")
	for size in FLEET_SIZES:
		rows.append(_measure_active(profile, size))
		rows.append(_measure_settled(profile, size))
	var runtime_seconds := (Time.get_ticks_msec() - suite_started) / 1000.0
	_check(runtime_seconds < 30.0, "bounded fleet receipt completes under 30 seconds")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"solver_sha256": FileAccess.get_sha256(SOLVER),
		"manifest_sha256": FileAccess.get_sha256(MANIFEST),
		"hz": HZ, "warmup_batches_per_case": WARMUP_BATCHES,
		"measured_batches_per_case": MEASURED_BATCHES, "rows": rows,
		"sample_selection": {"requested_if_under_30_seconds": 240,
			"calibration_240_runtime_seconds": CALIBRATION_240_RUNTIME_SECONDS,
			"bounded_selected_batches": MEASURED_BATCHES},
		"runtime_seconds": runtime_seconds,
		"host": {"os": OS.get_name(), "cpu": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(), "process_id": OS.get_process_id(),
			"engine": Engine.get_version_info().string},
		"scope": "measured complete native solver step batches at fixed 60Hz; active re-arm excluded; CPU call cost only, no FPS GPU loaded city visuals body main LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_FLEET_PERF_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
