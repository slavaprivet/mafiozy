extends SceneTree
## Independent heterogeneous per-state tick regression for the additive batch candidate.
## Candidate and production sources remain frozen; this file is test-only.

const Solver = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const BatchRows = preload("res://scripts/vehicle_physics/vehicle_crash_solver_batch_inputs_candidate.gd")
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const SOLVER_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const PARENT_SHA256 := "ac553088e34defc70969c79e97d7b92c50231566e0b2c7e25384c97148aea2bd"
const CANDIDATE_SHA256 := "08262b2870ce6662afba1454a76e2afd02d281552de5edf165ca75aad69d5cf9"
const PROFILE_IDS := ["city_hatchback", "compact_sedan", "city_bus"]
const VEHICLE_IDS := ["tick-hatch", "tick-compact", "tick-bus"]
const LIFE_GENERATIONS := [2, 5, 9]

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _manifest_profiles() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary:
		return {}
	var result := {}
	for entry_value: Variant in parsed.get("entries", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if not PROFILE_IDS.has(entry.get("profile_id")):
			continue
		for node_value: Variant in entry.get("nodes", []):
			if node_value is Dictionary and node_value.get("source_metadata") is Dictionary:
				var metadata: Dictionary = node_value.source_metadata
				if metadata.get("vehicleProfile") is Dictionary:
					result[entry.profile_id] = metadata.vehicleProfile
					break
	return result

func _new_solver(profile: Dictionary, vehicle_id: String, life_generation: int) -> RefCounted:
	var solver := Solver.new()
	_check(solver.configure(vehicle_id, life_generation, profile.id, MANIFEST_SHA256, profile),
		vehicle_id + " configures")
	return solver

func _impact(solver: RefCounted, profile: Dictionary, vehicle_id: String,
		life_generation: int, speed: float) -> void:
	var source_point := Vector3(0.0, 0.8, float(profile.halfLength))
	var source_normal := Vector3(0.0, 0.0, 1.0)
	var result: Dictionary = solver.apply_impact_native({
		"vehicle_id": vehicle_id, "life_generation": life_generation,
		"physics_tick": 0, "impact_sequence": 0,
		"event_id": "tick-impact-" + vehicle_id,
		"point_native_m": Solver.source_local_to_native(source_point),
		"normal_native": Solver.source_local_to_native(source_normal),
		"impact_speed_mps": speed,
	})
	_check(result.get("applied") == true, vehicle_id + " impact arms structural work")

func _publish_serial(solvers: Array, rows: Array) -> Dictionary:
	var by_identity := {}
	for row_value: Variant in rows:
		var row: Dictionary = row_value
		by_identity[JSON.stringify([row.vehicle_id, row.life_generation])] = row
	var states: Array = []
	states.resize(solvers.size())
	for index in solvers.size():
		var row: Dictionary = by_identity[JSON.stringify([
			VEHICLE_IDS[index], LIFE_GENERATIONS[index]])]
		var solver: RefCounted = solvers[index]
		var step_result: Dictionary = solver.step(row.delta, row.speed, row.throttle,
			row.physics_tick)
		states[index] = {"vehicle_id": VEHICLE_IDS[index],
			"life_generation": LIFE_GENERATIONS[index],
			"step": step_result.duplicate(true),
			"mechanical": solver.mechanical_snapshot(),
			"deformation": solver.deformation_snapshot_native()}
	return {"accepted": states.all(func(state: Dictionary) -> bool:
		return state.step.get("accepted") == true), "states": states}

func _batch_one_rows() -> Array:
	# Deliberately reverse bound order and use three independent future ticks.
	return [
		{"vehicle_id": VEHICLE_IDS[2], "life_generation": LIFE_GENERATIONS[2],
			"delta": 1.0 / 30.0, "speed": 13.0, "throttle": -0.25, "physics_tick": 3},
		{"vehicle_id": VEHICLE_IDS[1], "life_generation": LIFE_GENERATIONS[1],
			"delta": 0.001, "speed": -2.0, "throttle": 0.75, "physics_tick": 7},
		{"vehicle_id": VEHICLE_IDS[0], "life_generation": LIFE_GENERATIONS[0],
			"delta": 1.0 / 120.0, "speed": 5.0, "throttle": 0.2, "physics_tick": 2},
	]

func _batch_two_rows() -> Array:
	return [
		{"vehicle_id": VEHICLE_IDS[2], "life_generation": LIFE_GENERATIONS[2],
			"delta": 0.08, "speed": 0.0, "throttle": 1.0, "physics_tick": 11},
		{"vehicle_id": VEHICLE_IDS[1], "life_generation": LIFE_GENERATIONS[1],
			"delta": 1.0 / 60.0, "speed": 22.0, "throttle": 0.0, "physics_tick": 8},
		{"vehicle_id": VEHICLE_IDS[0], "life_generation": LIFE_GENERATIONS[0],
			"delta": 0.0, "speed": -4.0, "throttle": -1.0, "physics_tick": 6},
	]

func _run() -> void:
	_check(FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
		== SOLVER_SHA256, "frozen solver receipt")
	_check(FileAccess.get_sha256(
		"res://scripts/vehicle_physics/vehicle_crash_solver_batch_candidate.gd")
		== PARENT_SHA256, "frozen parent executor receipt")
	_check(FileAccess.get_sha256(
		"res://scripts/vehicle_physics/vehicle_crash_solver_batch_inputs_candidate.gd")
		== CANDIDATE_SHA256, "frozen additive candidate receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "frozen manifest receipt")
	var profiles := _manifest_profiles()
	_check(profiles.size() == PROFILE_IDS.size(), "three heterogeneous profiles resolve")
	var serial_solvers: Array = []
	var batch_solvers: Array = []
	var bind_rows: Array = []
	for index in PROFILE_IDS.size():
		var profile: Dictionary = profiles[PROFILE_IDS[index]]
		var serial := _new_solver(profile, VEHICLE_IDS[index], LIFE_GENERATIONS[index])
		var parallel := _new_solver(profile, VEHICLE_IDS[index], LIFE_GENERATIONS[index])
		_impact(serial, profile, VEHICLE_IDS[index], LIFE_GENERATIONS[index], 18.0 + index * 4.0)
		_impact(parallel, profile, VEHICLE_IDS[index], LIFE_GENERATIONS[index], 18.0 + index * 4.0)
		serial_solvers.append(serial)
		batch_solvers.append(parallel)
		bind_rows.append({"solver": parallel, "vehicle_id": VEHICLE_IDS[index],
			"life_generation": LIFE_GENERATIONS[index]})
	var batch := BatchRows.new()
	_check(batch.configure("heterogeneous-tick-regression", 3, 2)
		and batch.bind_states(bind_rows), "three states bind in canonical slot order")

	for rows in [_batch_one_rows(), _batch_two_rows()]:
		var serial: Dictionary = _publish_serial(serial_solvers, rows)
		var parallel: Dictionary = batch.step_batch_rows(rows)
		_check(serial.accepted and parallel.get("accepted") == true,
			"heterogeneous tick batch accepts")
		_check(parallel.states.map(func(state: Dictionary) -> String:
			return state.vehicle_id) == VEHICLE_IDS,
			"reversed input publishes bound-slot output order")
		_check(parallel.states == serial.states,
			"heterogeneous tick batch exactly matches serial snapshots")

	var before: Array = []
	for solver: RefCounted in batch_solvers:
		before.append(solver.snapshot_source())
	var stale_rows := _batch_two_rows()
	stale_rows[0].physics_tick = 12
	stale_rows[1].physics_tick = 8 # Equal to compact's last tick: stale.
	stale_rows[2].physics_tick = 7
	var rejected: Dictionary = batch.begin_step_batch_rows(stale_rows)
	_check(not rejected.get("accepted", false) and rejected.get("reason") == "stale-state-tick"
		and not batch.contract().in_flight, "one stale row rejects the complete fleet")
	var unchanged := true
	for index in batch_solvers.size():
		unchanged = unchanged and batch_solvers[index].snapshot_source() == before[index]
	_check(unchanged, "stale fleet rejection advances no solver")
	_check(batch.retire_wait(), "executor retires and releases claims")

	var report := {"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "candidate_sha256": FileAccess.get_sha256(
			"res://scripts/vehicle_physics/vehicle_crash_solver_batch_inputs_candidate.gd"),
		"profiles": PROFILE_IDS.size(), "batches": 2,
		"scope": "test-only heterogeneous per-state ticks; no production main body GPU LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_BATCH_INPUTS_TICKS_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
