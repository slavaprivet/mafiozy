extends SceneTree
## CPU call-cost receipt for the frozen crash solver. This is not FPS, render,
## loaded-scene, GPU or production integration evidence.

const Solver = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const SOLVER := "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
const SOLVER_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const SOURCE := "res://../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs"
const SOURCE_SHA256 := "3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const PROFILE_ID := "compact_sedan"
const SAMPLES := 240
const WARMUP := 32
const NODE_THERMAL_ORACLE := """
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const [sourcePath,manifestPath]=process.argv.slice(1);
const {createCrashMechanicsState,applyCrashMechanicsImpact,stepCrashMechanics}=await import(pathToFileURL(sourcePath).href);
const manifest=JSON.parse(readFileSync(manifestPath,'utf8'));
const entry=manifest.entries.find(row=>row.profile_id==='compact_sedan');
const profile=entry.nodes.find(node=>node?.source_metadata?.vehicleProfile).source_metadata.vehicleProfile;
const state=createCrashMechanicsState(profile),point={...profile.componentPoints.radiator};
const sign=Math.sign(point.z||1),contact={eventId:'thermal-radiator',point,normal:{x:0,y:0,z:sign},impactSpeed:10};
const impact=applyCrashMechanicsImpact(state,contact);
let settleSteps=0;while(state.active&&settleSteps<2000){stepCrashMechanics(state,.1,{speed:0,throttle:0});settleSteps++;}
const before={engine:state.engine,radiator:state.radiator,steering:state.steering,brakes:state.brakes,temperature:state.temperature,revision:state.revision,active:state.active};
let heatSteps=0;while(heatSteps<2400&&!(state.engine<before.engine&&state.temperature>before.temperature)){stepCrashMechanics(state,.1,{speed:0,throttle:1});heatSteps++;}
const after={engine:state.engine,radiator:state.radiator,steering:state.steering,brakes:state.brakes,temperature:state.temperature,revision:state.revision,active:state.active};
console.log(JSON.stringify({profile,contact,impact,settleSteps,heatSteps,before,after,revisionStable:before.revision===after.revision}));
"""

var checks := 0
var failures: Array[String] = []
var timing_rows: Array[Dictionary] = []
var thermal_oracle_sha256 := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _close(a: float, b: float, tolerance := 0.00002) -> bool:
	return absf(a - b) <= tolerance

func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

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

func _native_contact(source_contact: Dictionary, vehicle_id: String) -> Dictionary:
	var point := Vector3(source_contact.point.x, source_contact.point.y, source_contact.point.z)
	var normal := Vector3(source_contact.normal.x, source_contact.normal.y, source_contact.normal.z)
	return {"vehicle_id": vehicle_id, "life_generation": 1, "physics_tick": 0,
		"impact_sequence": 0, "event_id": source_contact.eventId,
		"point_native_m": Solver.source_local_to_native(point),
		"normal_native": Solver.source_local_to_native(normal),
		"impact_speed_mps": source_contact.impactSpeed}

func _active_solver(profile: Dictionary, label: String) -> RefCounted:
	var solver := Solver.new()
	_check(solver.configure(label, 1, PROFILE_ID, MANIFEST_SHA256, profile),
		label + " configures outside timed region")
	var source_contact := {"eventId": "perf-arm", "point": {"x": 0.0, "y": 0.8,
		"z": float(profile.halfLength)}, "normal": {"x": 0.0, "y": 0.0, "z": 1.0},
		"impactSpeed": 60.0}
	var impact := solver.apply_impact_native(_native_contact(source_contact, label))
	_check(impact.applied and solver.snapshot_source().active,
		label + " identical source impact admits active structural work")
	return solver

func _percentile(sorted_samples: Array[int], fraction: float) -> int:
	return sorted_samples[mini(sorted_samples.size() - 1,
		maxi(0, int(ceil(fraction * sorted_samples.size())) - 1))]

func _metrics(samples: Array[int]) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"samples": samples.size(), "p50_usec": _percentile(ordered, 0.50),
		"p95_usec": _percentile(ordered, 0.95),
		"p99_usec": _percentile(ordered, 0.99), "max_usec": ordered[-1]}

func _measure_rate(profile: Dictionary, hz: int) -> void:
	var delta := 1.0 / hz
	var expected_substeps := 240 / hz
	# Warm active code/data caches. Configure and re-arm stay outside the timed call.
	for index in WARMUP:
		var warm := _active_solver(profile, "warm-active-" + str(hz) + "-" + str(index))
		var result: Dictionary = warm.step(delta, 8.0, 1.0, 1)
		_check(result.accepted and result.substeps == expected_substeps,
			"warm active exact 240Hz substeps")
	var active_samples: Array[int] = []
	var active_total_substeps := 0
	for index in SAMPLES:
		var solver := _active_solver(profile, "measured-active-" + str(hz) + "-" + str(index))
		var started := Time.get_ticks_usec()
		var result: Dictionary = solver.step(delta, 8.0, 1.0, 1)
		var elapsed := Time.get_ticks_usec() - started
		active_samples.append(elapsed)
		active_total_substeps += int(result.substeps)
		_check(result.accepted and result.substeps == expected_substeps,
			"measured active " + str(hz) + "Hz exact 240Hz substeps " + str(index))
	var idle := Solver.new()
	_check(idle.configure("measured-idle-" + str(hz), 1, PROFILE_ID,
		MANIFEST_SHA256, profile), "idle " + str(hz) + "Hz configures")
	var idle_tick := 0
	for index in WARMUP:
		idle_tick += 1
		var result := idle.step(delta, 0.0, 0.0, idle_tick)
		_check(result.accepted and result.substeps == 0,
			"warm idle has zero structural substeps")
	var idle_samples: Array[int] = []
	for index in SAMPLES:
		idle_tick += 1
		var started := Time.get_ticks_usec()
		var result := idle.step(delta, 0.0, 0.0, idle_tick)
		var elapsed := Time.get_ticks_usec() - started
		idle_samples.append(elapsed)
		_check(result.accepted and result.substeps == 0,
			"measured idle " + str(hz) + "Hz zero structural substeps " + str(index))
	_check(active_total_substeps == SAMPLES * expected_substeps,
		str(hz) + "Hz measured calls execute exact 240 structural steps per simulated second")
	timing_rows.append({"hz": hz, "simulated_delta_seconds": delta,
		"expected_substeps_per_call": expected_substeps,
		"active_total_substeps": active_total_substeps,
		"active": _metrics(active_samples), "idle": _metrics(idle_samples)})

func _thermal_oracle() -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute("node", PackedStringArray([
		"--input-type=module", "--eval", NODE_THERMAL_ORACLE,
		ProjectSettings.globalize_path(SOURCE), ProjectSettings.globalize_path(MANIFEST),
	]), output, true)
	_check(exit_code == 0 and output.size() == 1, "actual Node thermal oracle executes")
	if exit_code != 0 or output.is_empty():
		return {}
	var raw := str(output[0]).strip_edges()
	thermal_oracle_sha256 = _sha256_text(raw)
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Dictionary, "actual Node thermal oracle returns JSON")
	return parsed if parsed is Dictionary else {}

func _mechanical_oracle(profile: Dictionary) -> void:
	var oracle := _thermal_oracle()
	_check(not oracle.is_empty() and oracle.impact.applied,
		"source radiator impact admits thermal scenario")
	if oracle.is_empty():
		return
	var vehicle_id := "thermal-mechanical-oracle"
	var solver := Solver.new()
	_check(solver.configure(vehicle_id, 1, PROFILE_ID, MANIFEST_SHA256, profile),
		"thermal solver configures")
	var impact := solver.apply_impact_native(_native_contact(oracle.contact, vehicle_id))
	_check(impact.applied == oracle.impact.applied,
		"native radiator impact matches source admission")
	var tick := 0
	for index in int(oracle.settleSteps):
		tick += 1
		solver.step(0.1, 0.0, 0.0, tick)
	var before := solver.mechanical_snapshot()
	_check(not solver.snapshot_source().active and oracle.before.active == false,
		"source and native structural mechanics settle before thermal-only phase")
	for index in int(oracle.heatSteps):
		tick += 1
		var result := solver.step(0.1, 0.0, 1.0, tick)
		_check(result.accepted and not result.changed,
			"thermal-only step leaves structural changed false")
	var after := solver.mechanical_snapshot()
	for key in ["engine", "radiator", "steering", "brakes", "temperature"]:
		_check(_close(before[key], oracle.before[key]), "thermal before source parity " + key)
		_check(_close(after[key], oracle.after[key]), "thermal after source parity " + key)
	_check(oracle.revisionStable and before.revision == after.revision
		and after.engine < before.engine and after.temperature > before.temperature,
		"temperature and engine change while structural revision remains stable")
	var isolated := solver.mechanical_snapshot()
	isolated.wheels.front_left.health = -1.0
	_check(solver.mechanical_snapshot().wheels.front_left.health >= 0.0,
		"post-thermal mechanical wheel snapshot remains isolated")

func _run() -> void:
	_check(FileAccess.get_sha256(SOLVER) == SOLVER_SHA256, "frozen solver receipt")
	_check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA256, "exact mechanics source receipt")
	_check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "exact manifest receipt")
	var profile := _profile()
	_check(not profile.is_empty(), "compact profile resolves from pinned manifest")
	for hz in [120, 60, 30]:
		_measure_rate(profile, hz)
	_mechanical_oracle(profile)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"solver_sha256": FileAccess.get_sha256(SOLVER),
		"source_sha256": FileAccess.get_sha256(SOURCE),
		"manifest_sha256": FileAccess.get_sha256(MANIFEST),
		"thermal_node_oracle_sha256": thermal_oracle_sha256,
		"warmup_calls_per_case": WARMUP, "measured_calls_per_case": SAMPLES,
		"timings": timing_rows,
		"host": {"os": OS.get_name(), "cpu": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(), "process_id": OS.get_process_id(),
			"engine": Engine.get_version_info().string},
		"scope": "single-process headless CPU solver step call cost; re-arm/configure excluded; no FPS GPU loaded scene body main LIVE"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_PERF_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
