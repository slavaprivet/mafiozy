extends SceneTree

const Frozen = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks.gd")
const Candidate = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd")
const ID := "paged-proposal"
const LIFE := 17
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _row(tick: int, z: float, x := 0.0, slip := 1.0) -> Dictionary:
	return {"vehicle_id": ID, "life_generation": LIFE, "physics_tick": tick,
		"wheel_index": 2, "grounded": true, "surface_id": "road", "slip": slip,
		"point_world_m": Vector3(x, 0.0, z), "normal_world": Vector3.UP}

func _pair(a: Variant, b: Variant, dt: float, tick: int, contacts: Array,
		speed := 12.0, deep := false) -> void:
	_check(a.step(dt, tick, speed, contacts) == b.step(dt, tick, speed, contacts),
		"admission %d" % tick)
	_check(a.stats().count == b.stats().count and a.stats().active == b.stats().active
		and a.stats().cursor == b.stats().cursor, "ring %d" % tick)
	if deep:
		for slot in Frozen.MAX_SEGMENTS:
			_check(a._active[slot] == b._active[slot], "active %d" % slot)
			if a._active[slot] != 0:
				_check(a._segment_transforms[slot].is_equal_approx(
					b._segment_transforms[slot]), "geometry %d" % slot)
				_check(absf(a._opacities[slot] - b.opacity_at(slot)) < 0.00002,
					"opacity %d" % slot)

func _pages(b: Variant, label: String) -> void:
	for p in Candidate.PAGE_COUNT:
		var highest := -1
		var expected := AABB()
		var valid := false
		for local in Candidate.PAGE_SIZE:
			var slot := p * Candidate.PAGE_SIZE + local
			if b._active[slot] == 0:
				continue
			highest = local
			var transform: Transform3D = b._segment_transforms[slot]
			var half_length := transform.basis.z * 0.5
			var part := AABB(transform.origin - half_length, Vector3.ZERO)
			part = part.expand(transform.origin + half_length)
			part = part.grow(Frozen.WIDTH_M + Frozen.SURFACE_LIFT_M)
			expected = expected.merge(part) if valid else part
			valid = true
		_check(b._pages[p].instance_count == Candidate.PAGE_SIZE and
			b._pages[p].visible_instance_count == highest + 1,
			"page prefix %s/%d" % [label, p])
		_check(b._pages[p].custom_aabb.is_equal_approx(expected if valid else Candidate.EMPTY_BOUNDS),
			"live bounds %s/%d" % [label, p])
		_check(b._page_nodes[p].multimesh == b._pages[p] and
			b._pages[p].mesh.surface_get_material(0) == b._track_material,
			"shared material %s/%d" % [label, p])

func _percentile(values: PackedInt64Array, fraction: float) -> int:
	values.sort()
	return values[clampi(int(ceil(values.size() * fraction)) - 1, 0, values.size() - 1)]

func _run() -> void:
	var a := Frozen.new()
	var b := Candidate.new()
	root.add_child(a)
	root.add_child(b)
	_check(a.configure(ID, LIFE) and b.configure(ID, LIFE), "configure")
	_check(b._pages.size() == 12 and b.get_child_count() == 11, "page nodes")
	_pages(b, "empty")
	_pair(a, b, 0.0, 1, [_row(1, 0.0)])
	_pair(a, b, 0.0, 2, [_row(2, 0.5)])
	_pages(b, "one")
	_pair(a, b, 5.5, 3, [], 0.0, true)
	_pair(a, b, 4.5, 4, [], 0.0, true)
	_pages(b, "expired")
	# A distant mark must not pin old page bounds after it dies.
	a.clear()
	b.clear()
	_pair(a, b, 0.0, 10, [_row(10, 0.0, 10000.0)])
	_pair(a, b, 0.0, 11, [_row(11, 0.5, 10000.0)])
	_check(b._pages[0].custom_aabb.position.x > 9999.0, "distant bound")
	_pair(a, b, 10.0, 12, [], 0.0)
	_pages(b, "distant expired")
	_check(b._pages[0].custom_aabb.position.x < 1.0, "distant bound shrinks")
	# Old low offsets expire while newer high offsets in the same page stay live.
	a.clear()
	b.clear()
	_pair(a, b, 0.0, 100, [_row(100, 0.0)])
	for i in 50:
		_pair(a, b, 0.0, 101 + i, [_row(101 + i, float(i + 1) * 0.5)])
	_pair(a, b, 5.0, 151, [], 0.0)
	for i in 50:
		_pair(a, b, 0.0, 152 + i, [_row(152 + i, float(i + 51) * 0.5)])
	_pair(a, b, 5.0, 202, [], 0.0, true)
	_pages(b, "sparse partial expiry")
	_check(b._pages[0].visible_instance_count == 99 and
		b._pages[0].custom_aabb.position.z > 24.0,
		"sparse high offsets visible with old bounds removed %d %s" % [
			b._pages[0].visible_instance_count, str(b._pages[0].custom_aabb)])
	# Fill and wrap the exact source ring; geometry remains untouched.
	a.clear()
	b.clear()
	_pair(a, b, 0.0, 20, [_row(20, 0.0)])
	for i in Frozen.MAX_SEGMENTS + 25:
		_pair(a, b, 0.0, 21 + i, [_row(21 + i, float(i + 1) * 0.5)])
	_pair(a, b, 0.0, 1247, [], 0.0, true)
	_pages(b, "wrapped full")
	var a_first := PackedInt64Array()
	var b_second := PackedInt64Array()
	var b_first := PackedInt64Array()
	var a_second := PackedInt64Array()
	var a_emitting := PackedInt64Array()
	var b_emitting := PackedInt64Array()
	var tick := 1300
	for sample in 400:
		tick += 1
		var start := Time.get_ticks_usec()
		if sample % 2 == 0:
			a.step(0.0, tick, 0.0, [])
			a_first.append(Time.get_ticks_usec() - start)
			start = Time.get_ticks_usec()
			b.step(0.0, tick, 0.0, [])
			b_second.append(Time.get_ticks_usec() - start)
		else:
			b.step(0.0, tick, 0.0, [])
			b_first.append(Time.get_ticks_usec() - start)
			start = Time.get_ticks_usec()
			a.step(0.0, tick, 0.0, [])
			a_second.append(Time.get_ticks_usec() - start)
	_check(a.stats().active == 1200 and b.stats().active == 1200, "full cost fixture")
	for sample in 240:
		tick += 1
		var contacts := [_row(tick, float(1226 + sample) * 0.5)]
		var start := Time.get_ticks_usec()
		if sample % 2 == 0:
			a.step(0.0, tick, 12.0, contacts)
			a_emitting.append(Time.get_ticks_usec() - start)
			start = Time.get_ticks_usec()
			b.step(0.0, tick, 12.0, contacts)
			b_emitting.append(Time.get_ticks_usec() - start)
		else:
			b.step(0.0, tick, 12.0, contacts)
			b_emitting.append(Time.get_ticks_usec() - start)
			start = Time.get_ticks_usec()
			a.step(0.0, tick, 12.0, contacts)
			a_emitting.append(Time.get_ticks_usec() - start)
	_pair(a, b, 0.0, tick + 1, [], 0.0, true)
	_pages(b, "emitting wrapped")
	_pair(a, b, 10.0, tick + 2, [], 0.0, true)
	_pages(b, "full expired")
	_pair(a, b, 64.0, tick + 3, [], 0.0)
	_check(b._pages[0].get_instance_custom_data(0).r == 0.0,
		"no old mark after clock wraps")
	a.clear()
	b.clear()
	_pair(a, b, 31.5, tick + 4, [], 0.0)
	_pair(a, b, 0.0, tick + 5, [_row(tick + 5, 0.0)])
	_pair(a, b, 0.0, tick + 6, [_row(tick + 6, 0.5)])
	_pair(a, b, 2.0, tick + 7, [], 0.0, true)
	_check(absf(float(b._track_material.get_shader_parameter("elapsed_clock_s")) - 1.5) < 0.001,
		"shared shader clock wraps with live mark")
	_pages(b, "live clock wrap")
	var report := {"passed": failures.is_empty(), "checks": checks,
		"failures": failures,
		"frozen_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks.gd"),
		"candidate_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd"),
		"cpu_us_full_1200": {"frozen_first_p50": _percentile(a_first, 0.5),
			"frozen_first_p95": _percentile(a_first, 0.95),
			"candidate_second_p50": _percentile(b_second, 0.5),
			"candidate_second_p95": _percentile(b_second, 0.95),
			"candidate_first_p50": _percentile(b_first, 0.5),
			"candidate_first_p95": _percentile(b_first, 0.95),
			"frozen_second_p50": _percentile(a_second, 0.5),
			"frozen_second_p95": _percentile(a_second, 0.95),
			"frozen_emitting_p50": _percentile(a_emitting, 0.5),
			"frozen_emitting_p95": _percentile(a_emitting, 0.95),
			"candidate_emitting_p50": _percentile(b_emitting, 0.5),
			"candidate_emitting_p95": _percentile(b_emitting, 0.95)}}
	print("NATIVE_VEHICLE_TYRE_TRACKS_PAGED_TEST ", JSON.stringify(report))
	a.dispose()
	b.dispose()
	quit(0 if failures.is_empty() else 1)
