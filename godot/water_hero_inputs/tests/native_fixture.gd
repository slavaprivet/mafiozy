extends Node3D
const Sampler = preload("res://hero_water_input_sampler.gd")
var checks := 0
var failures: Array[String] = []
var bounds_calls := 0

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func bounds() -> Dictionary:
	bounds_calls += 1
	return {"sourceBounds": {"min": [-0.6, 0, -0.3], "max": [0.6, 2, 0.3]}}

func _ready() -> void:
	# Give the scheduler time to register this short-lived child; excluded from cost.
	await get_tree().create_timer(1.5).timeout
	var sampler = Sampler.new()
	var parent := Node3D.new()
	add_child(parent)
	parent.position = Vector3(7, 1, 9)
	var hero := Node3D.new()
	parent.add_child(hero)
	hero.rotation.y = 0.4
	var state := {"diagnostics": Callable(self, "bounds"), "source_scale": 0.95}
	var transform_before := hero.global_transform
	var row: Dictionary = sampler.sample(hero, 0.1, state)
	expect(row.teleport and not row.has("velocity"), "first sample cannot create impact velocity")
	expect(row.position == Vector3(7, 1, 9), "actual transformed feet position")
	expect(is_equal_approx(row.footprint.width, 1.14), "source scaled width")
	expect(row.contactOffsetY == 0.0 and is_equal_approx(row.yaw, 0.4), "source feet/yaw")
	expect(hero.global_transform == transform_before, "sampler never mutates transform")
	hero.position = Vector3(0.1, -1, 0)
	state.vertical_velocity = -7.0
	row = sampler.sample(hero, 0.1, state)
	expect(not row.teleport and row.velocity.is_equal_approx(Vector3(1, -7, 0)), "landing vertical owner override")
	expect(bounds_calls == 1, "bounds called once per hero lifetime")
	state.occupied_seat = true
	row = sampler.sample(hero, 0.1, state)
	expect(not row.enabled and row.teleport and not row.has("velocity"), "seat entry reseeds")
	state.occupied_seat = false
	row = sampler.sample(hero, 0.1, state)
	expect(row.enabled and row.teleport, "seat exit cannot splash from seat displacement")
	state.transition = true
	expect(sampler.sample(hero, 0.1, state).teleport, "transition start reseeds")
	state.transition = false
	expect(sampler.sample(hero, 0.1, state).teleport, "transition finish reseeds")
	state.transition = {}
	expect(not sampler.sample(hero, 0.1, state).enabled, "JS empty transition object is truthy")
	state.transition = null
	expect(sampler.sample(hero, 0.1, state).teleport, "empty transition release reseeds")
	for invalid_dt in [0.0, -0.1, 0.25001, NAN, INF]:
		row = sampler.sample(hero, invalid_dt, state)
		expect(row.teleport and not row.has("velocity"), "invalid delta reseeds")
	expect(not sampler.sample(hero, 0.25, state).teleport, "dt boundary .25 accepted")
	hero.position.x += 12.0
	expect(not sampler.sample(hero, 0.1, state).teleport, "12m boundary accepted")
	hero.position.x += 12.01
	expect(sampler.sample(hero, 0.1, state).teleport, "over12m displacement suppresses impact")
	state.teleport = true
	expect(sampler.sample(hero, 0.1, state).teleport, "explicit teleport")
	state.teleport = false
	sampler.reset()
	expect(sampler.sample(hero, 0.1, state).teleport and bounds_calls == 1, "reset history keeps immutable bounds")
	expect(sampler.sample(null, 0.1).is_empty(), "missing hero emits no input")
	expect(sampler.sample(hero, 0.1, state).teleport, "missing hero prunes previous identity")
	var replacement := Node3D.new()
	parent.add_child(replacement)
	replacement.global_position = hero.global_position
	expect(sampler.sample(replacement, 0.1, state).teleport, "replacement body same position reseeds")
	replacement.set_meta("massKg", 80.0)
	expect(sampler.sample(replacement, 0.1, state).massKg == 80.0, "metadata mass")
	state.mass_kg = 75.0
	expect(sampler.sample(replacement, 0.1, state).massKg == 75.0, "explicit mass precedence")
	var held := hero.global_transform
	for i in 200: sampler.sample(hero, 0.016, state)
	expect(hero.global_transform == held and bounds_calls == 2, "repeated samples read-only and cached")
	state.vertical_velocity = 0.0
	expect(sampler.sample(hero, 0.1, state).velocity.y == 0.0, "finite zero vertical override")
	var wrapper := RefCounted.new()
	state.hero_owner = wrapper
	sampler.sample(hero, 0.1, state)
	var cached_calls := bounds_calls
	sampler.sample(replacement, 0.1, state)
	expect(bounds_calls == cached_calls, "same wrapper replaces node without re-reading width")
	# Bounded steady-state component CPU and object allocation evidence.
	var object_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var samples: Array[float] = []
	for batch in 25:
		var started := Time.get_ticks_usec()
		for i in 400: sampler.sample(replacement, 0.016, state)
		samples.append(float(Time.get_ticks_usec() - started) / 400.0)
	samples.sort()
	var object_after := Performance.get_monitor(Performance.OBJECT_COUNT)
	var cost_callback_delta := bounds_calls - cached_calls
	expect(object_before == object_after and bounds_calls == cached_calls, "steady 10000 samples no persistent Object growth or bounds calls")
	var oracle_sampler = Sampler.new()
	var oracle_owner := RefCounted.new()
	var oracle_hero := Node3D.new()
	add_child(oracle_hero)
	oracle_hero.rotation.y = 0.4
	var oracle_cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/oracle_cases.json"))
	var oracle_rows: Array = []
	for entry: Dictionary in oracle_cases:
		if entry.get("reset", false): oracle_sampler.reset()
		if entry.get("replacement", false):
			oracle_hero.queue_free()
			oracle_hero = Node3D.new()
			add_child(oracle_hero)
		if entry.has("p"): oracle_hero.global_position = Vector3(entry.p[0], entry.p[1], entry.p[2])
		var options: Dictionary = entry.duplicate()
		options.hero_owner = oracle_owner
		options.diagnostics = Callable(self, "bounds")
		options.source_scale = 0.95
		var input: Dictionary = oracle_sampler.sample(null if entry.get("missing", false) else oracle_hero, entry.dt, options)
		if input.is_empty(): oracle_rows.append(null)
		else:
			var speed: Variant = input.get("velocity", null)
			oracle_rows.append({"enabled":input.enabled,"teleport":input.teleport,"p":[input.position.x,input.position.y,input.position.z],"v":[speed.x,speed.y,speed.z] if speed != null else null,"width":input.footprint.width})
	print("SOURCE_PARITY_TRACE=" + JSON.stringify(oracle_rows))
	print(JSON.stringify({"component_cost": {"samples": 10000, "batch_mean_us_p50": samples[12], "batch_mean_us_p95": samples[23], "persistent_object_delta": object_after-object_before, "bounds_callback_delta": cost_callback_delta}, "limits": "Dictionary/Variant transient allocations not counted; headless component cost, no city/GPU FPS acceptance"}))
	print(JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "scope": "Actual Node3D sampler component; no full water/swim/city integration"}))
	get_tree().quit(0 if failures.is_empty() else 1)
