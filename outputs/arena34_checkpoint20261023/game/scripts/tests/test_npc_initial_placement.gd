extends SceneTree
## Full frozen source context; replay providers are TEST_ONLY, never physical proof.
const Resolver = preload("res://scripts/npc_visual/npc_initial_placement.gd")
const BASE = "C:/Users/Слава/Desktop/Мафиози/"
const CONTEXT = "outputs/astra21_npc_full_startup/d3d0596340658f9e5238977e99d2c900ff7cdbbe40d09c4f3096aa46089880a8/context.json"
const CONTEXT_SHA = "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const WORLD_SHA = "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
var checks := 0
var failures: Array[String] = []
var trace: Array = []
var mode := "blocked"
var clock_value := 0.0
var replay: Array = []
var replay_index := 0
var current_resolver: RefCounted
var oracle: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _trust() -> Dictionary:
	return {"context_sha256": CONTEXT_SHA, "source_world_sha256": WORLD_SHA,
		"session_id": "godot-preview-new-session-20260927-01",
		"phase": "AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER",
		"provider": {"id": "TEST_ONLY_FROZEN_BODY_REPLAY", "version": "1", "semantics": "ROLE_BODY_PASS", "sha256": WORLD_SHA},
		"interior_state": {"source_world_sha256": WORLD_SHA, "_buildingInt": null, "_bankInt": null, "_majorInteriorObjectId": null}}

func _clock() -> float:
	return clock_value

func _pass(key: String, kind: String, raw: Dictionary, r: float, c: float) -> Variant:
	var result := false
	if mode == "pass": result = true
	if mode == "invalid": return "true"
	if mode == "replay":
		_check(replay_index < replay.size(), "replay query in range")
		if replay_index >= replay.size(): return null
		var expected: Dictionary = replay[replay_index]
		_check(expected.object_key == key and expected.kind == kind, "replay ordered object role")
		_check(absf(float(expected.r) - r) < 1e-10 and absf(float(expected.c) - c) < 1e-10, "replay float64 source coordinates")
		result = expected.result
		replay_index += 1
	trace.append({"object_key": key, "kind": kind, "r": r, "c": c, "result": result})
	# Callback cannot mutate the resolver's identity, HP or future spacing state.
	raw["hp"] = -99999
	raw["id"] = "TEST_ONLY_MUTATED_CALLBACK_COPY"
	return result

func _new(bytes: PackedByteArray) -> RefCounted:
	var resolver := Resolver.new()
	_check(resolver.configure(bytes, _trust(), _pass, _clock).get("ok", false), "configure frozen326")
	return resolver

func _compare(actual: Variant, expected: Variant, label: String) -> void:
	if (actual is int or actual is float) and (expected is int or expected is float):
		_check(is_finite(float(actual)) and absf(float(actual) - float(expected)) <= 1e-9, label)
	elif actual is Dictionary and expected is Dictionary:
		_check(actual.size() == expected.size(), label + " dictionary shape")
		for key: Variant in expected:
			_check(actual.has(key), label + " key " + str(key))
			if actual.has(key): _compare(actual[key], expected[key], label + "/" + str(key))
	elif actual is Array and expected is Array:
		_check(actual.size() == expected.size(), label + " array size")
		for index in mini(actual.size(), expected.size()): _compare(actual[index], expected[index], label + "/" + str(index))
	else: _check(actual == expected, label)

func _state(resolver: RefCounted, expected: Dictionary, label: String) -> void:
	var actual: Dictionary = resolver.snapshot()
	_compare(actual.stats, expected.stats, label + " stats")
	_compare(actual.queue, expected.queue, label + " queue order")
	_check(actual.rows.size() == expected.rows.size(), label + " all326 rows")
	var original_objects := {}
	for entry: Dictionary in expected.objects: original_objects[entry.object_key] = entry.raw
	for index in mini(actual.rows.size(), expected.rows.size()):
		var row: Dictionary = actual.rows[index]
		var source: Dictionary = expected.rows[index]
		for key: String in source: _compare(row.get(key), source[key], label + " row " + str(index) + " " + key)
		_compare(row.n, original_objects[row.object_key], label + " raw " + str(index))

func _run() -> void:
	var bytes := FileAccess.get_file_as_bytes(BASE + CONTEXT)
	_check(_hash(bytes) == CONTEXT_SHA, "immutable input hash")
	oracle = JSON.parse_string(FileAccess.get_file_as_string(BASE + "outputs/astra21_npc_placement_oracle/ORACLE.json"))
	_check(oracle.provenance.context_sha256 == CONTEXT_SHA, "oracle context")
	mode = "blocked"; trace.clear()
	var blocked := _new(bytes)
	var first: Dictionary = blocked.step(128, 4)
	_check(first.ok and first.events.is_empty(), "blocked initial no candidate admission")
	_state(blocked, oracle.blocked.initial, "first128")
	_check(trace.size() == 128, "initial128 BODY not corner queries")
	var second: Dictionary = blocked.step(96, 2)
	_check(second.ok and second.events.is_empty(), "blocked second no events")
	_state(blocked, oracle.blocked.second, "second96")
	_check(trace.size() == 224, "total224 BODY checks")
	for index in trace.size():
		var expected: Dictionary = oracle.blocked.queries[index]
		for key: String in trace[index]: _compare(trace[index][key], expected[key], "blocked query " + str(index) + " " + key)
	var snapshot: Dictionary = blocked.snapshot()
	snapshot.rows[0].n.id = "mutated snapshot"
	_check(blocked.snapshot().rows[0].n.id != "mutated snapshot", "snapshot private")
	mode = "pass"; trace.clear()
	var passing := _new(bytes)
	var events: Array = []
	var passed: Dictionary = passing.step(128, 4)
	events.append_array(passed.events)
	while not passed.done and passing.snapshot().stats.slices < 10:
		passed = passing.step(96, 2); events.append_array(passed.events)
	_check(passed.ok and passed.done, "passing original done")
	_check(passed.stats.moved == 0 and passed.stats.searchChecks == 0 and passed.stats.checked == 306, "original point bypass spacing306")
	_check(events.size() == 306 and trace.size() == 306, "306 original events and checks")
	for event: Dictionary in events:
		_check(event.status == "original" and event.physical_admission == false, "candidate not physical admitted")
		_check(event.context_sha256 == CONTEXT_SHA and event.source_world_sha256 == WORLD_SHA, "candidate provenance")
	_check(_hash(bytes) == CONTEXT_SHA, "input bytes after callbacks")
	mode = "replay"; trace.clear(); replay_index = 0
	var search: Dictionary = oracle.synthetic_search_and_spacing
	replay = search.queries
	var searching := _new(bytes)
	var search_events: Array = []
	for slice: Dictionary in search.slices:
		var searched: Dictionary = searching.step(int(slice.max_checks), float(slice.max_ms))
		_check(searched.ok, "source search slice valid")
		search_events.append_array(searched.events)
		_state(searching, slice.state, "ordered full search slice " + str(searching.snapshot().stats.slices))
		_check(replay_index == int(slice.query_end), "exact source query slice budget")
	_check(replay_index == replay.size() and replay.size() == 765, "all765 ordered BODY queries consumed")
	_check(searching.snapshot().stats.moved == 306 and search_events.size() == 306, "all306 eligible relocated not new births")
	for event: Dictionary in search_events: _check(event.status == "relocated" and not event.physical_admission, "relocation candidate not collision proof")
	mode = "invalid"
	var invalid := _new(bytes)
	var rejected: Dictionary = invalid.step(128, 4)
	_check(not rejected.ok and rejected.events.is_empty(), "strict bool provider fail closed")
	_check(not invalid.step(96, 2).ok, "fault cannot resume")
	for bad_key: String in ["context_sha256", "source_world_sha256", "session_id", "phase"]:
		var trust := _trust(); trust[bad_key] = "wrong"
		var failed := Resolver.new()
		_check(not failed.configure(bytes, trust, _pass, _clock).ok, "bad trust " + bad_key)
	var changed := bytes.duplicate(); changed.append(32)
	_check(not Resolver.new().configure(changed, _trust(), _pass, _clock).ok, "changed actual bytes rejected")
	mode = "blocked"
	var timings: Array[int] = []
	for iteration in 25:
		var profiled := _new(bytes)
		trace.clear()
		var start := Time.get_ticks_usec()
		profiled.step(128, 4)
		var elapsed := Time.get_ticks_usec() - start
		if iteration >= 5: timings.append(elapsed)
	timings.sort()
	var output := {"checks": checks, "failures": failures, "context_sha256": CONTEXT_SHA,
		"helper_sha256": _hash(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_initial_placement.gd")),
		"synthetic_body_provider": true, "native_physical_admission": false,
		"cpu_initial128_us": {"p50": timings[10], "p95": timings[18], "max": timings[19], "samples": 20, "warmup": 5},
		"limits": ["Pure algorithm/context parity, no real navigation/collision provider", "Scripted frozen clock0, elapsed CPU measured separately", "No GPU/FPS/runtime scene/HP/authority updates"]}
	DirAccess.make_dir_recursive_absolute(BASE + "outputs/astra21_npc_placement_tests")
	var file := FileAccess.open(BASE + "outputs/astra21_npc_placement_tests/RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t") + "\n"); file.close()
	print(JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
