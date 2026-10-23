extends SceneTree
## Standalone exact-subclass math-preservation runner.
## Usage:
##   godot --headless --path <project> --script res://scripts/tests/test_vehicle_crash_solver_candidate_math.gd -- \
##     --candidate-path=res://scripts/vehicle_physics/<candidate>.gd --candidate-sha256=<sha256>
## This compares source-verified frozen behavior only; it makes no performance,
## scheduling, FPS, GPU, body, main, authority, visual, debris or LIVE claim.

const Base = preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const BASE_PATH := "res://scripts/vehicle_physics/vehicle_crash_solver.gd"
const BASE_SHA256 := "3896afa6c14845c84835f1fd8221d1b0927947d716008cc2e6422991afc01129"
const BASE_ORACLE_TEST := "res://scripts/tests/test_vehicle_crash_solver.gd"
const BASE_ORACLE_TEST_SHA256 := "615c0d605e4bd6ef6cdd28676203c058e7c57dfa489d2f4cdf70067b3ced142f"
const BASE_ORACLE_CHECKS := 7020
const SOURCE := "res://../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs"
const SOURCE_SHA256 := "3faeed3b6bea790396c7676958100bd5520105d452a61a14c45977d38095a166"
const MANIFEST := "res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const MAX_SETTLE_STEPS := 2000
const MAX_REPORTED_MISMATCHES := 64

var checks := 0
var failures: Array[String] = []
var invariant_checks := 0
var invariant_mismatches := 0
var identity_sequence := 0
var candidate_path := ""
var candidate_sha256 := ""
var candidate_script: GDScript
var profile_reports: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func parse_interface() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate-path="):
			candidate_path = argument.trim_prefix("--candidate-path=")
		elif argument.begins_with("--candidate-sha256="):
			candidate_sha256 = argument.trim_prefix("--candidate-sha256=").to_lower()
	if candidate_path.is_empty() or candidate_sha256.length() != 64:
		return false
	if not candidate_path.begins_with("res://") or not FileAccess.file_exists(candidate_path):
		return false
	if FileAccess.get_sha256(candidate_path).to_lower() != candidate_sha256:
		return false
	var loaded: Resource = load(candidate_path)
	if not loaded is GDScript:
		return false
	candidate_script = loaded
	return true

func profiles() -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var result: Array[Dictionary] = []
	if not parsed is Dictionary:
		return result
	for entry_value: Variant in (parsed as Dictionary).get("entries", []):
		if not entry_value is Dictionary:
			continue
		for node_value: Variant in (entry_value as Dictionary).get("nodes", []):
			if not node_value is Dictionary or not node_value.get("source_metadata") is Dictionary:
				continue
			var metadata: Dictionary = node_value.source_metadata
			if metadata.get("vehicleProfile") is Dictionary:
				result.append(metadata.vehicleProfile)
				break
	return result

func pair(profile: Dictionary, tag: String) -> Array:
	identity_sequence += 1
	var vehicle_id := "%s-%s-%d" % [tag, profile.id, identity_sequence]
	var base: RefCounted = Base.new()
	var candidate: RefCounted = candidate_script.new()
	var base_ok: bool = base.configure(vehicle_id, 1, profile.id, MANIFEST_SHA256, profile)
	var candidate_ok: bool = candidate.configure(vehicle_id, 1, profile.id, MANIFEST_SHA256, profile)
	check(base_ok and candidate_ok, "%s %s pair configures" % [profile.id, tag])
	return [base, candidate, vehicle_id]

func contact(profile: Dictionary, vehicle_id: String, kind: int, sequence: int) -> Dictionary:
	var point_source: Vector3
	var normal_source: Vector3
	var speed: float
	match kind:
		0:
			point_source = Vector3(0.0, 0.8, float(profile.halfLength))
			normal_source = Vector3(0.0, 0.0, 1.0)
			speed = 60.0
		1:
			point_source = Vector3(float(profile.halfWidth), 0.9, 0.25)
			normal_source = Vector3(1.0, 0.0, 0.0)
			speed = 48.0
		2:
			var wheel: Dictionary = profile.wheelPositions.front_left
			point_source = Vector3(wheel.x, wheel.y, wheel.z)
			normal_source = Vector3(1.0, 0.0, 0.0)
			speed = 72.0
		_:
			point_source = Vector3(-float(profile.halfWidth) * 0.45, 0.7,
				-float(profile.halfLength))
			normal_source = Vector3(0.0, 0.0, -1.0)
			speed = 58.0
	return {"vehicle_id": vehicle_id, "life_generation": 1,
		"physics_tick": sequence / 2, "impact_sequence": sequence,
		"event_id": "%s-impact-%d" % [vehicle_id, sequence],
		"point_native_m": Base.source_local_to_native(point_source),
		"normal_native": Base.source_local_to_native(normal_source),
		"impact_speed_mps": speed}

func mismatch(path: String, actual: Variant, expected: Variant) -> void:
	invariant_mismatches += 1
	if failures.size() < MAX_REPORTED_MISMATCHES:
		failures.append("%s actual=%s expected=%s" % [path, str(actual), str(expected)])

func compare_full(actual: Variant, expected: Variant, path: String) -> void:
	invariant_checks += 1
	if typeof(actual) != typeof(expected):
		mismatch(path + " type", typeof(actual), typeof(expected))
		return
	if actual is Dictionary:
		var actual_dictionary: Dictionary = actual
		var expected_dictionary: Dictionary = expected
		invariant_checks += 1
		if actual_dictionary.size() != expected_dictionary.size():
			mismatch(path + " dictionary size", actual_dictionary.size(), expected_dictionary.size())
		for key: Variant in expected_dictionary:
			invariant_checks += 1
			if not actual_dictionary.has(key):
				mismatch(path + " missing key", key, "present")
				continue
			compare_full(actual_dictionary[key], expected_dictionary[key], path + "." + str(key))
		return
	if actual is Array:
		var actual_array: Array = actual
		var expected_array: Array = expected
		invariant_checks += 1
		if actual_array.size() != expected_array.size():
			mismatch(path + " array size", actual_array.size(), expected_array.size())
		var shared := mini(actual_array.size(), expected_array.size())
		for index in shared:
			compare_full(actual_array[index], expected_array[index], "%s[%d]" % [path, index])
		return
	if actual != expected:
		mismatch(path, actual, expected)

func broken_beam_count(snapshot: Dictionary) -> int:
	var result := 0
	for beam: Dictionary in snapshot.get("beams", []):
		if bool(beam.get("broken", false)):
			result += 1
	return result

func run_profile(profile: Dictionary) -> void:
	var configured := pair(profile, "full")
	var base: RefCounted = configured[0]
	var candidate: RefCounted = configured[1]
	var vehicle_id: String = configured[2]
	compare_full(candidate.runtime_contract(), base.runtime_contract(), profile.id + ".initial.contract")
	compare_full(candidate.snapshot_source(), base.snapshot_source(), profile.id + ".initial.state")
	for impact_index in 4:
		var row := contact(profile, vehicle_id, impact_index, impact_index)
		compare_full(candidate.apply_impact_native(row), base.apply_impact_native(row),
			"%s.impact[%d].result" % [profile.id, impact_index])
		compare_full(candidate.snapshot_source(), base.snapshot_source(),
			"%s.impact[%d].state" % [profile.id, impact_index])
	var impact_broken := broken_beam_count(base.snapshot_source())
	var synthetic_broken_fixture := impact_broken == 0
	if synthetic_broken_fixture:
		# The long city-bus beams do not cross source break strain under the
		# shared bounded impacts. Mark one beam identically so its fixed-step
		# skip branch is still compared without claiming an impact-caused break.
		base._beam_broken[0] = 1
		candidate._beam_broken[0] = 1
	var exercised_broken := broken_beam_count(base.snapshot_source())
	compare_full(candidate.snapshot_source(), base.snapshot_source(),
		profile.id + ".broken_beam_fixture.state")
	check(exercised_broken > 0, "%s reaches broken-beam fixed-step skip path" % profile.id)

	var tick := 1
	var base_zero: Dictionary = base.step(0.0, 0.0, 0.0, tick)
	var candidate_zero: Dictionary = candidate.step(0.0, 0.0, 0.0, tick)
	compare_full(candidate_zero, base_zero, profile.id + ".zero_delta.result")
	compare_full(candidate.snapshot_source(), base.snapshot_source(), profile.id + ".zero_delta.state")
	check(base_zero.accepted and not base_zero.changed and base_zero.substeps == 0,
		"%s zero delta preserves source no-work semantics" % profile.id)

	var operations := [
		{"dt": 0.001, "speed": 0.0, "throttle": 1.0},
		{"dt": 1.0 / 120.0, "speed": 4.0, "throttle": 0.7},
		{"dt": 1.0 / 60.0, "speed": 8.0, "throttle": 1.0},
		{"dt": 0.08, "speed": 0.0, "throttle": 1.0},
		{"dt": 0.25, "speed": 0.0, "throttle": 1.0},
	]
	for operation_index in operations.size():
		tick += 1
		var operation: Dictionary = operations[operation_index]
		compare_full(candidate.step(operation.dt, operation.speed, operation.throttle, tick),
			base.step(operation.dt, operation.speed, operation.throttle, tick),
			"%s.prestep[%d].result" % [profile.id, operation_index])
		compare_full(candidate.snapshot_source(), base.snapshot_source(),
			"%s.prestep[%d].state" % [profile.id, operation_index])

	var settle_steps := 0
	var checkpoint_steps := {1: true, 2: true, 4: true, 8: true, 16: true,
		32: true, 64: true, 128: true, 256: true, 512: true, 1024: true}
	while (bool(base.snapshot_source().active) or bool(candidate.snapshot_source().active)) \
			and settle_steps < MAX_SETTLE_STEPS:
		settle_steps += 1
		tick += 1
		var speed := 8.0 if settle_steps % 2 == 0 else 0.0
		compare_full(candidate.step(0.1, speed, 1.0, tick),
			base.step(0.1, speed, 1.0, tick),
			"%s.settle[%d].result" % [profile.id, settle_steps])
		if checkpoint_steps.has(settle_steps):
			compare_full(candidate.snapshot_source(), base.snapshot_source(),
				"%s.settle[%d].state" % [profile.id, settle_steps])
	var base_final: Dictionary = base.snapshot_source()
	var candidate_final: Dictionary = candidate.snapshot_source()
	compare_full(candidate_final, base_final, profile.id + ".settled.state")
	compare_full(candidate.deformation_snapshot_native(), base.deformation_snapshot_native(),
		profile.id + ".settled.deformation_native")
	compare_full(candidate.mechanical_snapshot(), base.mechanical_snapshot(),
		profile.id + ".settled.mechanical")
	check(settle_steps < MAX_SETTLE_STEPS and not bool(base_final.active)
		and not bool(candidate_final.active), "%s reaches identical inactive settling" % profile.id)
	profile_reports.append({"profile_id": profile.id,
		"impact_broken_beams": impact_broken,
		"exercised_broken_beams": exercised_broken,
		"synthetic_broken_fixture": synthetic_broken_fixture,
		"settle_steps": settle_steps, "final_revision": base_final.revision,
		"simulation_time": base_final.simulationTime})

func run_threshold(profile: Dictionary, speed: float, label: String) -> void:
	var configured := pair(profile, "threshold-" + label)
	var base: RefCounted = configured[0]
	var candidate: RefCounted = configured[1]
	for index in Base.NODE_COUNT:
		base._position[index] = base._plastic[index]
		candidate._position[index] = candidate._plastic[index]
		base._velocity[index] = Vector3.ZERO
		candidate._velocity[index] = Vector3.ZERO
	base._velocity[0] = Vector3(speed, 0.0, 0.0)
	candidate._velocity[0] = Vector3(speed, 0.0, 0.0)
	var base_moving: bool = base._fixed_step(0.0)
	var candidate_moving: bool = candidate._fixed_step(0.0)
	compare_full(candidate_moving, base_moving, profile.id + ".threshold." + label + ".moving")
	compare_full(candidate.snapshot_source(), base.snapshot_source(),
		profile.id + ".threshold." + label + ".state")
	var represented_speed := Vector3(speed, 0.0, 0.0).length()
	check(base_moving == (represented_speed > 0.0008),
		"%s threshold %s preserves strict >0.0008 source predicate" % [profile.id, label])

func run() -> void:
	var started_msec := Time.get_ticks_msec()
	check(parse_interface(), "exact candidate path and SHA interface admits a GDScript")
	check(FileAccess.get_sha256(BASE_PATH) == BASE_SHA256, "frozen base 3896 receipt")
	check(FileAccess.get_sha256(BASE_ORACLE_TEST) == BASE_ORACLE_TEST_SHA256,
		"frozen 7020-check source-oracle test receipt")
	check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA256, "exact source helper receipt")
	check(FileAccess.get_sha256(MANIFEST) == MANIFEST_SHA256, "exact 13-profile manifest receipt")
	if candidate_script == null:
		finish(started_msec)
		return
	var all_profiles := profiles()
	check(all_profiles.size() == 13, "all 13 source-authored profiles resolve")
	for profile: Dictionary in all_profiles:
		run_profile(profile)
		for threshold: Dictionary in [
			{"speed": 0.0008 - 0.0000001, "label": "below"},
			{"speed": 0.0008, "label": "equal"},
			{"speed": 0.0008 + 0.0000001, "label": "above"},
		]:
			run_threshold(profile, threshold.speed, threshold.label)
	check(invariant_checks >= 1400,
		"candidate comparison executes at least 1400 source-equivalence invariants")
	check(invariant_mismatches == 0, "candidate has zero source-equivalence mismatches")
	finish(started_msec)

func finish(started_msec: int) -> void:
	var report := {"passed": failures.is_empty(), "checks": checks,
		"failure_count": failures.size(), "failures": failures,
		"source_equivalence_invariants": invariant_checks,
		"source_equivalence_mismatches": invariant_mismatches,
		"base_sha256": FileAccess.get_sha256(BASE_PATH),
		"base_oracle_test_sha256": FileAccess.get_sha256(BASE_ORACLE_TEST),
		"base_oracle_checks": BASE_ORACLE_CHECKS,
		"candidate_path": candidate_path,
		"candidate_sha256": FileAccess.get_sha256(candidate_path) if FileAccess.file_exists(candidate_path) else "",
		"profiles": profile_reports,
		"runtime_seconds": (Time.get_ticks_msec() - started_msec) / 1000.0,
		"scope": "exact candidate/base math preservation over impacts, broken beams, zero delta, 0.0008 boundary and settling; no perf scheduling FPS GPU body main authority visual debris LIVE claim"}
	print("NATIVE_VEHICLE_CRASH_SOLVER_CANDIDATE_MATH_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
