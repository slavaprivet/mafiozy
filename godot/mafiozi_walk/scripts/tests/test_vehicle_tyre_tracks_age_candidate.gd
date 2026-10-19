extends SceneTree
## Proposal-only parity and alternating-order headless CPU test.

const Frozen = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks.gd")
const Candidate = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_age_candidate.gd")
const ID := "tyre-age-proposal"
const LIFE := 9
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _row(tick: int, z: float, slip := 1.0) -> Dictionary:
	return {"vehicle_id": ID, "life_generation": LIFE, "physics_tick": tick,
		"wheel_index": 2, "grounded": true, "surface_id": "road",
		"point_world_m": Vector3(-0.92, 0.0, z),
		"normal_world": Vector3.UP, "slip": slip}

func _step_pair(frozen: Variant, candidate: Variant, dt: float, tick: int,
		contacts: Array, speed := 12.0) -> void:
	_check(frozen.step(dt, tick, speed, contacts) ==
		candidate.step(dt, tick, speed, contacts), "step admission " + str(tick))
	_check(frozen.stats().count == candidate.stats().count and
		frozen.stats().active == candidate.stats().active and
		frozen.stats().cursor == candidate.stats().cursor,
		"ring counts " + str(tick))
	for slot in Frozen.MAX_SEGMENTS:
		if frozen._active[slot] != candidate._active[slot]:
			_check(false, "active slot " + str(tick) + "/" + str(slot))
			continue
		if frozen._active[slot] != 0:
			_check(absf(frozen._opacities[slot] - candidate.opacity_at(slot)) < 0.00002,
				"opacity " + str(tick) + "/" + str(slot))
			_check(frozen._segment_transforms[slot].is_equal_approx(
				candidate._segment_transforms[slot]), "geometry " + str(tick) + "/" + str(slot))

func _percentile(samples: PackedInt64Array, fraction: float) -> int:
	samples.sort()
	return int(samples[clampi(int(ceil(samples.size() * fraction)) - 1, 0, samples.size() - 1)])

func _run() -> void:
	var frozen := Frozen.new()
	var candidate := Candidate.new()
	root.add_child(frozen)
	root.add_child(candidate)
	_check(frozen.configure(ID, LIFE) and candidate.configure(ID, LIFE), "configure")
	var shader: ShaderMaterial = candidate.multimesh.mesh.surface_get_material(0)
	_check(shader.shader.code.contains("elapsed_clock_s") and
		shader.shader.code.contains("INSTANCE_CUSTOM.y"), "shader uses explicit bounded clock")
	_step_pair(frozen, candidate, 0.0, 1, [_row(1, 0.0)])
	_step_pair(frozen, candidate, 0.0, 2, [_row(2, 0.5)])
	_step_pair(frozen, candidate, 5.5, 3, [], 0.0)
	_step_pair(frozen, candidate, 2.25, 4, [], 0.0)
	_step_pair(frozen, candidate, 2.25, 5, [], 0.0)
	_check(candidate.stats().active == 0 and candidate.opacity_at(0) == 0.0,
		"expired mark cleared before clock wraps")
	frozen.clear()
	candidate.clear()
	_step_pair(frozen, candidate, 0.0, 10, [_row(10, 0.0)])
	for i in Frozen.MAX_SEGMENTS + 25:
		var tick := 11 + i
		# Four rows are allowed, but one long slip is enough to fill the exact ring.
		var contacts := [_row(tick, float(i + 1) * 0.5)]
		frozen.step(0.0, tick, 12.0, contacts)
		candidate.step(0.0, tick, 12.0, contacts)
	_check(frozen.stats().active == 1200 and candidate.stats().active == 1200,
		"full 1200-mark ring")
	_check(frozen.stats().cursor == candidate.stats().cursor and
		frozen._segment_transforms[25].is_equal_approx(candidate._segment_transforms[25]),
		"overwritten ring geometry")
	var frozen_first := PackedInt64Array()
	var candidate_second := PackedInt64Array()
	var candidate_first := PackedInt64Array()
	var frozen_second := PackedInt64Array()
	var frozen_emitting := PackedInt64Array()
	var candidate_emitting := PackedInt64Array()
	var tick := 1300
	for sample in 400:
		tick += 1
		var started := Time.get_ticks_usec()
		if sample % 2 == 0:
			frozen.step(0.0, tick, 0.0, [])
			frozen_first.append(Time.get_ticks_usec() - started)
			started = Time.get_ticks_usec()
			candidate.step(0.0, tick, 0.0, [])
			candidate_second.append(Time.get_ticks_usec() - started)
		else:
			candidate.step(0.0, tick, 0.0, [])
			candidate_first.append(Time.get_ticks_usec() - started)
			started = Time.get_ticks_usec()
			frozen.step(0.0, tick, 0.0, [])
			frozen_second.append(Time.get_ticks_usec() - started)
	_check(candidate.stats().active == 1200 and frozen.stats().active == 1200,
		"cost loop retains all marks")
	# Measure the complete presentation step, including one new transform and
	# custom-data upload at cap. Alternate order in the same paired fixture.
	for sample in 240:
		tick += 1
		var contacts := [_row(tick, float(1226 + sample) * 0.5)]
		var started := Time.get_ticks_usec()
		if sample % 2 == 0:
			frozen.step(0.0, tick, 12.0, contacts)
			frozen_emitting.append(Time.get_ticks_usec() - started)
			started = Time.get_ticks_usec()
			candidate.step(0.0, tick, 12.0, contacts)
			candidate_emitting.append(Time.get_ticks_usec() - started)
		else:
			candidate.step(0.0, tick, 12.0, contacts)
			candidate_emitting.append(Time.get_ticks_usec() - started)
			started = Time.get_ticks_usec()
			frozen.step(0.0, tick, 12.0, contacts)
			frozen_emitting.append(Time.get_ticks_usec() - started)
	_check(candidate.stats().active == 1200 and frozen.stats().active == 1200 and
		candidate.stats().cursor == frozen.stats().cursor,
		"emission cost loop retains exact cap and cursor")
	for slot in Frozen.MAX_SEGMENTS:
		_check(frozen._active[slot] == candidate._active[slot] and
			frozen._segment_transforms[slot].is_equal_approx(candidate._segment_transforms[slot]) and
			absf(frozen._opacities[slot] - candidate.opacity_at(slot)) < 0.00002,
			"full-ring overwrite parity " + str(slot))
	_step_pair(frozen, candidate, 10.0, tick + 1, [], 0.0)
	_check(candidate.stats().active == 0, "FIFO expiration drains full ring")
	# A shader clock wrap cannot resurrect expired custom data.
	_step_pair(frozen, candidate, 64.0, tick + 2, [], 0.0)
	_check(candidate._strengths[0] == 0.0 and candidate._active[0] == 0,
		"expired GPU strength remains zero after two clock aliases")
	frozen.clear()
	candidate.clear()
	_step_pair(frozen, candidate, 31.5, tick + 3, [], 0.0)
	_step_pair(frozen, candidate, 0.0, tick + 4, [_row(tick + 4, 0.0)])
	_step_pair(frozen, candidate, 0.0, tick + 5, [_row(tick + 5, 0.5)])
	_step_pair(frozen, candidate, 2.0, tick + 6, [], 0.0)
	_check(absf(candidate.opacity_at(0) - frozen._opacities[0]) < 0.00002 and
		candidate._track_material.get_shader_parameter("elapsed_clock_s") < 2.0,
		"live mark retains alpha across 32-second shader clock wrap")
	_step_pair(frozen, candidate, 8.0, tick + 7, [], 0.0)
	_check(candidate._strengths[0] == 0.0 and candidate._active[0] == 0,
		"wrapped mark expires and cannot reappear")
	var report := {"passed": failures.is_empty(), "checks": checks,
		"failures": failures,
		"frozen_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks.gd"),
		"candidate_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_age_candidate.gd"),
		"cpu_us_1200_active": {
			"frozen_first": {"p50": _percentile(frozen_first, 0.50), "p95": _percentile(frozen_first, 0.95)},
			"candidate_second": {"p50": _percentile(candidate_second, 0.50), "p95": _percentile(candidate_second, 0.95)},
			"candidate_first": {"p50": _percentile(candidate_first, 0.50), "p95": _percentile(candidate_first, 0.95)},
			"frozen_second": {"p50": _percentile(frozen_second, 0.50), "p95": _percentile(frozen_second, 0.95)},
			"frozen_emitting": {"p50": _percentile(frozen_emitting, 0.50), "p95": _percentile(frozen_emitting, 0.95)},
			"candidate_emitting": {"p50": _percentile(candidate_emitting, 0.50), "p95": _percentile(candidate_emitting, 0.95)}},
		"qualification": "headless CPU step only; no GPU, provider, main or LIVE"}
	print("NATIVE_VEHICLE_TYRE_TRACKS_AGE_TEST ", JSON.stringify(report))
	frozen.dispose()
	candidate.dispose()
	quit(0 if failures.is_empty() else 1)
