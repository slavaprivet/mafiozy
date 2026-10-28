extends SceneTree
const HelperPath := "res://scripts/npc_visual/npc_source_body_query.gd"
const Repo := "C:/Users/Слава/Desktop/Мафиози/"
const Out := Repo + "outputs/astra21_npc_source_body_tests/"
const ContextPath := Repo + "outputs/astra21_npc_full_startup_review/context.snapshot.json"
const OraclePath := Repo + "outputs/astra21_npc_source_body_oracle/ORACLE.json"
const StaticPath := Repo + "outputs/astra21_npc_source_body_oracle/STATIC_GEOMETRY.json"
const ContextSHA := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const SourceSHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const StaticSHA := "c5f57678912a0c18b51430ea0ef69ea2c84572d32392fa036b84c53f4933724b"
const OracleSHA := "4b650bc489cfd1f4cd929a70b2f889b2325062204eed8cf8467ddebac78e9d04"
const Phase := "AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER"
const Session := "godot-preview-new-session-20260927-01"
class ExpiredPrimitive extends Node:
	func point(_r: float, _c: float, _context: Dictionary) -> Dictionary:
		return {"known": false, "error": "fixture_not_expected_to_execute"}
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var helper: GDScript
var packet: Dictionary
var oracle: Dictionary
var source_bytes: PackedByteArray
var static_bytes: PackedByteArray
var trust: Dictionary
var baseline_snapshot: Dictionary
var fixture_reply: Dictionary = {}
var lease_bad := false
var placement_body: RefCounted
var reuse_counter := 0
var reused_value := {"blocked": false, "depth": 0.0, "surface": "land", "marker": 0}
var measure := true
var metric_helper_sha := ""
var callback_calls: Array = []
func point_fixture(_r: float, _c: float, context: Dictionary) -> Dictionary:
	callback_calls.append({"callback": "point", "r": _r, "c": _c, "object_key": context.object_key, "snapshot_id": context.snapshot_id, "revision": context.revision})
	if fixture_reply.get("known") == false: return {"known": false, "error": "source_bound_test_unknown"}
	var proof := {"source_world_sha256": SourceSHA, "session_id": Session, "snapshot_id": "stale" if lease_bad else context.snapshot_id, "revision": context.revision, "provider_id": "source-bound-fixture", "provider_version": "1"}
	return {"known": true, "defined": fixture_reply.get("defined", true), "value": fixture_reply.get("value"), "provenance": proof}
func water_unknown_fixture(_r: float, _c: float, _context: Dictionary) -> Dictionary:
	callback_calls.append({"callback": "water", "r": _r, "c": _c, "object_key": _context.object_key, "snapshot_id": _context.snapshot_id, "revision": _context.revision})
	return {"known": false, "error": "source_bound_test_unknown_water"}
func ped_clear_fixture(_r: float, _c: float, context: Dictionary) -> Dictionary:
	return {"known": true, "defined": true, "value": false, "provenance": {"source_world_sha256": SourceSHA, "session_id": Session, "snapshot_id": context.snapshot_id, "revision": context.revision, "provider_id": "source-bound-fixture", "provider_version": "1"}}
func reused_point_fixture(_r: float, _c: float, context: Dictionary) -> Dictionary:
	reuse_counter += 1
	reused_value.marker = reuse_counter
	return {"known": true, "defined": true, "value": reused_value, "provenance": {"source_world_sha256": SourceSHA, "session_id": Session, "snapshot_id": context.snapshot_id, "revision": context.revision, "provider_id": "source-bound-fixture", "provider_version": "1"}}
func configured(snapshot: Dictionary = {}, primitives: Dictionary = {}, receipts: Dictionary = {}) -> RefCounted:
	var instance: RefCounted = helper.new()
	var bound := trust.duplicate(true)
	bound.primitives = receipts
	var start := Time.get_ticks_usec()
	var report: Dictionary = instance.configure(source_bytes, bound, baseline_snapshot if snapshot.is_empty() else snapshot, primitives, static_bytes)
	if measure: metrics["last_configure_us"] = Time.get_ticks_usec() - start
	check(report.ok, "configure trusted source body " + str(report.get("error", "")))
	return instance
func compare_trace(actual: Array, expected: Array, label: String) -> void:
	check(actual.size() == expected.size(), "exact source trace count " + label)
	for i in mini(actual.size(), expected.size()):
		var a: Dictionary = actual[i]
		var b: Dictionary = expected[i]
		check(a.get("object_key") == b.object_key and a.get("name") == b.name and equivalent(a.get("r"), b.r) and equivalent(a.get("c"), b.c) and a.get("known") == b.known, "source ordered trace identity/point " + label + ":" + str(i))
		if b.known: check(equivalent(a.get("result"), b.result), "source returned trace value " + label + ":" + str(i))
		else: check(not str(a.get("error", "")).is_empty(), "native unknown trace explicit " + label)
func assert_lean(instance: RefCounted, row: Dictionary, raw: Dictionary, reference: Dictionary, label: String) -> void:
	var decision: Variant = instance.body_pass(row.object_key, row.kind, raw, row.r, row.c)
	check((decision is bool and decision == reference.pass) if reference.known else decision == null, "lean source branch parity " + label)
	var compact: Dictionary = instance.snapshot().last_report
	check(compact.known == reference.known and compact.error == reference.error and compact.get("diagnostics_recorded") == false and compact.trace.is_empty() and compact.primitive_trace.is_empty(), "lean branch current compact metadata " + label)
func placement_clock() -> float:
	return 0.0
func placement_pass(key: String, kind: String, raw: Dictionary, r: float, c: float) -> Variant:
	return placement_body.body_pass(key, kind, raw, r, c)
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value and not label in failures: failures.append(label)
func equivalent(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float): return absf(float(actual) - float(expected)) <= 0.0000000001
	if typeof(actual) != typeof(expected): return false
	if actual is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in expected:
			if not actual.has(key) or not equivalent(actual[key], expected[key]): return false
		return true
	if actual is Array:
		if actual.size() != expected.size(): return false
		for i in actual.size():
			if not equivalent(actual[i], expected[i]): return false
		return true
	return actual == expected
func row_by_key(key: String) -> Dictionary:
	for row: Dictionary in packet.context.objects:
		if row.object_key == key: return row.raw
	return {}
func finish() -> void:
	var result := {"status": "PASS_SOURCE_SEMANTICS_NATIVE_PHYSICAL_HOLD" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "helper_sha256": FileAccess.get_sha256(HelperPath), "test_sha256": FileAccess.get_sha256("res://scripts/tests/test_npc_source_body_query.gd"), "context_sha256": ContextSHA, "source_sha256": SourceSHA, "static_geometry_sha256": StaticSHA, "oracle_sha256": OracleSHA, "metrics": metrics, "metrics_helper_sha256": metric_helper_sha, "timing_performed_this_run": measure, "limits": ["Source oracle and this native author test share author; independent reviewer separate", "No actors, physical admission, native body geometry, GPU or FPS claim"]}
	DirAccess.make_dir_recursive_absolute(Out)
	var file := FileAccess.open(Out + "RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	measure = not OS.get_cmdline_user_args().has("--skip-bench")
	if not measure:
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Out + "historical_4989/RESULT.json"))
		metrics = previous.metrics.duplicate(true)
		metric_helper_sha = previous.helper_sha256
	else: metric_helper_sha = FileAccess.get_sha256(HelperPath)
	source_bytes = FileAccess.get_file_as_bytes(ContextPath)
	static_bytes = FileAccess.get_file_as_bytes(StaticPath)
	check(FileAccess.get_sha256(ContextPath) == ContextSHA and FileAccess.get_sha256(StaticPath) == StaticSHA and FileAccess.get_sha256(OraclePath) == OracleSHA, "all immutable input pins")
	packet = JSON.parse_string(source_bytes.get_string_from_utf8())
	oracle = JSON.parse_string(FileAccess.get_file_as_string(OraclePath))
	check(packet.context.objects.size() == 326 and oracle.rows.size() == 326 and oracle.ordered_queries.size() == 7902, "full326 and exact7902 source observations")
	helper = load(HelperPath) as GDScript
	if helper == null: check(false, "helper available"); finish(); return
	trust = {"context_sha256": ContextSHA, "source_world_sha256": SourceSHA, "static_geometry_sha256": StaticSHA, "session_id": Session, "phase": Phase, "primitives": {}}
	baseline_snapshot = {"source_world_sha256": SourceSHA, "session_id": Session, "snapshot_id": "offline-a05ad-baseline", "revision": 1, "native_nav_present": false, "water_present": false, "water_bypass": 0, "prison_enabled": true}
	var input_before := var_to_bytes([packet, trust, baseline_snapshot, source_bytes, static_bytes])
	var body := configured()
	var known_pass := 0
	var known_reject := 0
	var unknown := 0
	var observations := 0
	for row: Dictionary in oracle.rows:
		var raw := row_by_key(row.object_key)
		var raw_before := var_to_bytes(raw)
		var result: Dictionary = body.query(row.object_key, row.kind, raw, row.r, row.c)
		check(result.known == row.known and (not row.known or result.pass == row.pass), "all326 exact source BODY result " + row.object_key)
		check(result.physical_admission == false, "never physical admission " + row.object_key)
		check(result.get("diagnostics_recorded", false), "query diagnostic mode marked " + row.object_key)
		if result.known:
			if result.pass: known_pass += 1
			else: known_reject += 1
		else: unknown += 1
		var trace: Array = result.trace
		compare_trace(trace, oracle.ordered_queries.slice(int(row.trace_start), int(row.trace_end)), row.object_key)
		observations += trace.size()
		var saved_query := var_to_bytes(result)
		var decision: Variant = body.body_pass(row.object_key, row.kind, raw, row.r, row.c)
		check((decision is bool and decision == result.pass) if result.known else decision == null, "lean/full exact bool-null parity " + row.object_key)
		var lean: Dictionary = body.snapshot().last_report
		check(lean.get("known") == result.known and lean.get("error") == result.error and lean.get("physical_admission") == false and lean.get("diagnostics_recorded") == false, "compact current source report " + row.object_key)
		check(lean.get("trace") is Array and lean.trace.is_empty() and lean.get("primitive_trace") is Array and lean.primitive_trace.is_empty(), "lean does not retain stale query trace " + row.object_key)
		check(var_to_bytes(result) == saved_query, "previous full report remains owned " + row.object_key)
		var state_before := var_to_bytes(body.snapshot())
		lean.provenance.clear(); lean.trace.append({"foreign": true})
		check(var_to_bytes(body.snapshot()) == state_before, "compact snapshot arrays/provenance remain private " + row.object_key)
		check(var_to_bytes(raw) == raw_before, "source raw not mutated " + row.object_key)
	check(known_pass == 308 and known_reject == 6 and unknown == 12 and observations == 7902, "aggregate exact original source counts")
	check(var_to_bytes([packet, trust, baseline_snapshot, source_bytes, static_bytes]) == input_before, "all configure/query inputs immutable")
	var first: Dictionary = oracle.rows[0]
	var first_raw := row_by_key(first.object_key)
	var times: Array[int] = []
	var duplicate_times: Array[int] = []
	for i in 2050:
		var start := Time.get_ticks_usec()
		var result: Dictionary = body.query(first.object_key, first.kind, first_raw, first.r, first.c)
		if measure and i >= 50: times.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		var copy: Array = result.trace.duplicate(true)
		if measure and i >= 50: duplicate_times.append(Time.get_ticks_usec() - start)
		check(result.known and result.pass and copy.size() == result.trace.size(), "known repeated source query")
	if measure:
		times.sort(); duplicate_times.sort()
		metrics["known_body_2000"] = {"warmups": 50, "p50_us": times[1000], "p95_us": times[1900], "max_us": times[-1]}
		metrics["returned_trace_copy_2000"] = {"p50_us": duplicate_times[1000], "p95_us": duplicate_times[1900], "max_us": duplicate_times[-1]}
	var pass_times: Array[int] = []
	for i in 2050:
		var start := Time.get_ticks_usec()
		var decision: Variant = body.body_pass(first.object_key, first.kind, first_raw, first.r, first.c)
		if measure and i >= 50: pass_times.append(Time.get_ticks_usec() - start)
		check(decision is bool and decision, "known body_pass repeated exact boolean")
	if measure:
		pass_times.sort()
		metrics["known_body_pass_2000"] = {"warmups": 50, "p50_us": pass_times[1000], "p95_us": pass_times[1900], "max_us": pass_times[-1]}
	var configure_times: Array[int] = []
	for i in 25:
		var fresh: RefCounted = helper.new()
		var start := Time.get_ticks_usec()
		var result: Dictionary = fresh.configure(source_bytes, trust, baseline_snapshot, {}, static_bytes)
		if measure and i >= 5: configure_times.append(Time.get_ticks_usec() - start)
		check(result.ok, "repeated configure parsing")
	if measure:
		configure_times.sort()
		metrics["configure_20"] = {"warmups": 5, "p50_us": configure_times[10], "p95_us": configure_times[19], "max_us": configure_times[-1]}
	negative_cases(body, first, first_raw)
	branch_cases(first, first_raw)
	placement_body = configured()
	var placement: RefCounted = load("res://scripts/npc_visual/npc_initial_placement.gd").new()
	var placement_trust := {"context_sha256": ContextSHA, "source_world_sha256": SourceSHA, "session_id": Session, "phase": Phase, "provider": {"id": "source-body-test-only", "version": "1", "semantics": "ROLE_BODY_PASS", "sha256": FileAccess.get_sha256(HelperPath)}, "interior_state": {"source_world_sha256": SourceSHA, "_buildingInt": null, "_bankInt": null, "_majorInteriorObjectId": null}}
	check(placement.configure(source_bytes, placement_trust, placement_pass, placement_clock).ok, "isolated placement consumer configure")
	var placed: Dictionary = placement.step(128, 4)
	for i in 10:
		if not placed.ok or placed.done: break
		placed = placement.step()
	check(not placed.ok and placed.status == "FAULT" and placed.events.is_empty(), "unknown actual source BODY returns null and consumer FAULT")
	finish()
func negative_cases(body: RefCounted, first: Dictionary, raw: Dictionary) -> void:
	for key: String in ["context_sha256", "source_world_sha256", "static_geometry_sha256", "session_id", "phase"]:
		var bad := trust.duplicate(true)
		bad[key] = "wrong"
		check(not helper.new().configure(source_bytes, bad, baseline_snapshot, {}, static_bytes).ok, "reject wrong trusted pin " + key)
	var corrupt := static_bytes.duplicate(); corrupt[corrupt.size() - 1] ^= 1
	check(not helper.new().configure(source_bytes, trust, baseline_snapshot, {}, corrupt).ok, "reject tampered static bytes")
	corrupt = source_bytes.duplicate(); corrupt[corrupt.size() - 1] ^= 1
	check(not helper.new().configure(corrupt, trust, baseline_snapshot, {}, static_bytes).ok, "reject tampered context bytes")
	var wrong := raw.duplicate(true); wrong.id = "foreign"
	check(not body.query(first.object_key, first.kind, wrong, first.r, first.c).known, "reject raw identity mismatch")
	wrong = raw.duplicate(true); wrong._uniqueNpc = true
	check(not body.query(first.object_key, first.kind, wrong, first.r, first.c).known, "reject consumed source role mismatch")
	check(not body.query("unknown-key", first.kind, raw, first.r, first.c).known and not body.query(first.object_key, "police", raw, first.r, first.c).known, "reject objectkey/role mismatch")
	check(not body.query(first.object_key, first.kind, raw, NAN, first.c).known, "reject nonfinite coordinates")
	check(body.body_pass(first.object_key, first.kind, raw, NAN, first.c) == null and not body.snapshot().last_report.known, "lean invalid query null with current compact report")
	var bad_snapshot := baseline_snapshot.duplicate(true); bad_snapshot.erase("prison_enabled")
	check(not helper.new().configure(source_bytes, trust, bad_snapshot, {}, static_bytes).ok, "mandatory prison enabled flag proof")
	var result: Dictionary = body.query(first.object_key, first.kind, raw, first.r, first.c)
	var before := var_to_bytes(body.snapshot())
	result.trace.clear(); result.provenance.clear()
	check(var_to_bytes(body.snapshot()) == before, "returned source traces and provenance private copies")
	var owned_snapshot := baseline_snapshot.duplicate(true)
	var owned_trust := trust.duplicate(true)
	var owned: RefCounted = helper.new()
	check(owned.configure(source_bytes, owned_trust, owned_snapshot, {}, static_bytes).ok, "private configure copy setup")
	owned_snapshot.native_nav_present = true
	owned_snapshot.revision = 999
	owned_trust.source_world_sha256 = "mutated"
	check(owned.query(first.object_key, first.kind, raw, first.r, first.c).known, "caller snapshot/trust mutation cannot retarget configured helper")
func branch_cases(first: Dictionary, raw: Dictionary) -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(Repo + "outputs/astra21_npc_source_body_oracle/BRANCH_FIXTURES.json"))
	for fixture: Dictionary in fixtures:
		var snapshot := baseline_snapshot.duplicate(true); snapshot.native_nav_present = true
		var receipts := {"native_nav": {"id": "source-bound-fixture", "version": "1", "semantics": "_walkNpcNavigationResolver"}}
		var callbacks := {"native_nav": point_fixture}
		if fixture.input.has("water_unknown"):
			snapshot.water_present = true
			receipts["water"] = {"id": "source-bound-fixture", "version": "1", "semantics": "_walkNpcWaterResolver"}
			callbacks["water"] = water_unknown_fixture
		fixture_reply = {"known": false} if fixture.input.has("unknown") else {"known": true, "value": fixture.input.reply}
		var instance := configured(snapshot, callbacks, receipts)
		callback_calls.clear()
		var result: Dictionary = instance.query(first.object_key, first.kind, raw, first.r, first.c)
		var full_calls := var_to_bytes(callback_calls)
		check(result.known == fixture.result.known and (not result.known or result.pass == fixture.result.pass), "source-bound branch fixture " + fixture.name)
		compare_trace(result.trace, fixture.queries, fixture.name)
		callback_calls.clear()
		assert_lean(instance, first, raw, result, fixture.name)
		check(var_to_bytes(callback_calls) == full_calls, "lean preserves every primitive invocation/order " + fixture.name)
	fixture_reply = {"known": true, "value": {"blocked": false, "depth": 0, "surface": "land"}}
	var snapshot := baseline_snapshot.duplicate(true); snapshot.native_nav_present = true
	var receipts := {"native_nav": {"id": "source-bound-fixture", "version": "1", "semantics": "_walkNpcNavigationResolver"}}
	var leased := configured(snapshot, {"native_nav": point_fixture}, receipts)
	lease_bad = true
	check(not leased.query(first.object_key, first.kind, raw, first.r, first.c).known, "reject stale point lease snapshot identity")
	lease_bad = false
	var police: Dictionary = oracle.rows[308]
	var police_raw := row_by_key(police.object_key)
	var missing_alarm := configured(snapshot, {"native_nav": point_fixture}, receipts)
	check(not missing_alarm.query(police.object_key, "police", police_raw, 76.0, 89.5).known, "visited island branch requires alarm proof")
	snapshot.alarm_active = false
	var with_alarm := configured(snapshot, {"native_nav": point_fixture}, receipts)
	var floor: Dictionary = with_alarm.query(police.object_key, "police", police_raw, 76.0, 89.5)
	check(floor.known and floor.pass, "leased source alarm plus actual island corridor shape")
	var missing_gate := configured(snapshot, {"native_nav": point_fixture}, receipts)
	check(not missing_gate.query(police.object_key, "police", police_raw, 91.0, 89.5).known, "visited personal gate requires progress proof")
	snapshot.release_gate_progress = 0.0
	var locked := configured(snapshot, {"native_nav": point_fixture}, receipts)
	var locked_result: Dictionary = locked.query(police.object_key, "police", police_raw, 91.0, 89.5)
	check(locked_result.known and not locked_result.pass, "source gate lock threshold rejects")
	reuse_counter = 0
	var captured := configured(snapshot, {"native_nav": reused_point_fixture}, receipts)
	var captured_result: Dictionary = captured.query(first.object_key, first.kind, raw, first.r, first.c)
	check(captured_result.known and captured_result.pass, "reused callback response retains source reads")
	reused_value.marker = 999
	for i in captured_result.primitive_trace.size():
		check(captured_result.primitive_trace[i].value.marker == i + 1, "each visited primitive trace owns response value " + str(i))
	var ephemeral := ExpiredPrimitive.new()
	var expired := configured(snapshot, {"native_nav": ephemeral.point}, receipts)
	ephemeral.free()
	var expired_result: Dictionary = expired.query(first.object_key, first.kind, raw, first.r, first.c)
	check(not expired_result.known and expired_result.error == "primitive_unavailable:native_nav", "freed callback lease is unknown without runtime error")
	assert_lean(expired, first, raw, expired_result, "freed callback")
	var unique: Dictionary = {}
	for row: Dictionary in oracle.rows:
		if row_by_key(row.object_key).get("_uniqueNpc", false): unique = row; break
	fixture_reply = {"known": true, "value": {"blocked": false, "depth": "0xffffffffffffffff", "surface": "land"}}
	var hex := configured(snapshot, {"native_nav": point_fixture}, receipts)
	var hex_result: Dictionary = hex.query(unique.object_key, unique.kind, row_by_key(unique.object_key), unique.r, unique.c)
	check(hex_result.known and not hex_result.pass, "actual unique NPC source hexdepth comparison rejects without integer overflow")
	assert_lean(hex, unique, row_by_key(unique.object_key), hex_result, "actual unique hugehex")
	fixture_reply = {"known": true, "defined": false}
	var undefined_nav := configured(snapshot, {"native_nav": point_fixture}, receipts)
	check(undefined_nav.query(first.object_key, first.kind, raw, first.r, first.c).known, "known optional native undefined retains actual source fallback")
	var ped_receipts := {"ped_blocked": {"id": "source-bound-fixture", "version": "1", "semantics": "isBlockedPed"}}
	var bad_ped := configured(baseline_snapshot, {"ped_blocked": point_fixture}, ped_receipts)
	check(not bad_ped.query(police.object_key, police.kind, police_raw, police.r, police.c).known, "undefined direct pedestrian predicate cannot prove clear")
	ped_receipts["city_surface"] = {"id": "source-bound-fixture", "version": "1", "semantics": "_cityV3NextSurfaceAt"}
	var bad_city := configured(baseline_snapshot, {"ped_blocked": ped_clear_fixture, "city_surface": point_fixture}, ped_receipts)
	check(not bad_city.query(police.object_key, police.kind, police_raw, police.r, police.c).known, "undefined direct city surface cannot prove fallback")
	fixture_reply = {"known": true, "defined": true, "value": null}
	var null_ped := configured(baseline_snapshot, {"ped_blocked": point_fixture}, {"ped_blocked": ped_receipts.ped_blocked})
	check(not null_ped.query(police.object_key, police.kind, police_raw, police.r, police.c).known, "known null direct pedestrian predicate is invalid source return type")
	var null_city := configured(baseline_snapshot, {"ped_blocked": ped_clear_fixture, "city_surface": point_fixture}, ped_receipts)
	check(null_city.query(police.object_key, police.kind, police_raw, police.r, police.c).known, "known null direct city surface valid source fallback")
	fixture_reply = {"known": true, "defined": true, "value": false}
	var bool_city := configured(baseline_snapshot, {"ped_blocked": ped_clear_fixture, "city_surface": point_fixture}, ped_receipts)
	check(not bool_city.query(police.object_key, police.kind, police_raw, police.r, police.c).known, "direct city surface bool cannot masquerade as source null")
