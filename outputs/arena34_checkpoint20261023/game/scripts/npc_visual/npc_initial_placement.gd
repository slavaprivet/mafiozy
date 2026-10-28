extends RefCounted
## Source world9f5 initial placement only, after the pinned full startup context.
## Provider is trusted IN-PROCESS full role/body policy; its labels are NOT proof.
## Source-cell r/c use GDScript float64, never Vector2. No birth/HP/authority writes.
const CONTEXT_SHA := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const SOURCE_SHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const SESSION := "godot-preview-new-session-20260927-01"
const PHASE := "AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER"
const EXCLUDED := ["dead", "_residentIndoors", "_interiorId", "interior_id", "_insideBuilding", "_civilianTrip", "_civilianTripRiding", "_responseVehicleId", "vehicleId", "vehicle_id", "_inVehicle", "_inCar", "_carriedByAmbulance", "_evacuated", "_civilianSeat", "_uniqueNpc", "_said", "_empireBoss", "_empireCrew", "_gang", "gang", "_guard", "_clientOfBiz", "_owner"]
var _configured := false
var _busy := false
var _fault := ""
var _rows: Array[Dictionary] = []
var _queue: Array[int] = []
var _provenance: Dictionary = {}
var _body_pass: Callable
var _clock: Callable
var _last_ms := -INF
var _initial_step_pending := true
var _stats := {"attempted": false, "checked": 0, "moved": 0, "unresolved": 0, "skipped": 0, "searchChecks": 0, "pending": 0, "exhausted": 0, "slices": 0}

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _hash(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	return digest.finish().hex_encode()

static func _hash_string(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true

static func _truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return value != 0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	# JavaScript objects and arrays are truthy, including empty containers.
	return true

static func _eligible(raw: Dictionary) -> bool:
	if not raw.has("id"): return false # null id is present; undefined is absent.
	if raw.get("alive") is bool and raw.alive == false: return false
	for flag: String in EXCLUDED:
		if _truthy(raw.get(flag)): return false
	return true

static func _js_number(value: Variant, present: bool = true) -> float:
	# Spacing uses Math.hypot subtraction coercion, unlike setup Number.isFinite.
	if not present: return NAN
	if value == null: return 0.0
	if value is bool: return 1.0 if value else 0.0
	if value is int or value is float: return float(value)
	if value is String:
		var text: String = value.strip_edges()
		if text.is_empty(): return 0.0
		return text.to_float() if text.is_valid_float() else NAN
	if value is Array:
		if value.is_empty(): return 0.0
		if value.size() == 1 and (value[0] == null or value[0] is String or value[0] is int or value[0] is float): return _js_number("" if value[0] == null else str(value[0]))
	return NAN

func configure(context_bytes: PackedByteArray, trust: Dictionary, source_body_pass: Callable, clock_ms: Callable) -> Dictionary:
	if _busy:
		_fault = "reentrancy"; return _failure(_fault)
	if _configured: return _failure("already_configured")
	if context_bytes.size() > 1048576 or _hash(context_bytes) != CONTEXT_SHA: return _failure("context_hash")
	for key: String in ["context_sha256", "source_world_sha256", "session_id", "phase"]:
		if not trust.get(key) is String: return _failure("trust_fields")
	if trust.context_sha256 != CONTEXT_SHA or trust.source_world_sha256 != SOURCE_SHA or trust.session_id != SESSION or trust.phase != PHASE: return _failure("trust_binding")
	if not trust.get("provider") is Dictionary: return _failure("provider_receipt")
	var provider: Dictionary = trust.provider
	for key: String in ["id", "version"]:
		if not provider.get(key) is String or provider[key].is_empty() or provider[key].length() > 128: return _failure("provider_receipt")
	if not provider.get("semantics") is String or provider.semantics != "ROLE_BODY_PASS" or not _hash_string(provider.get("sha256")): return _failure("provider_receipt")
	if not trust.get("interior_state") is Dictionary: return _failure("interior_unknown")
	var interior: Dictionary = trust.interior_state
	if not interior.get("source_world_sha256") is String or interior.source_world_sha256 != SOURCE_SHA: return _failure("interior_provenance")
	for key: String in ["_buildingInt", "_bankInt", "_majorInteriorObjectId"]:
		if not interior.has(key): return _failure("interior_unknown")
	if not source_body_pass.is_valid() or not clock_ms.is_valid(): return _failure("provider_callable")
	var parsed := JSON.new()
	if parsed.parse(context_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary: return _failure("context_json")
	var packet: Dictionary = parsed.data
	if packet.get("schema") != "mafiozi.npc-full-offline-startup-context/v1" or packet.get("source_world_sha256") != SOURCE_SHA or not packet.get("boundary") is Dictionary: return _failure("context_schema")
	if packet.boundary.get("session_id") != SESSION or packet.boundary.get("phase") != PHASE or not packet.get("context") is Dictionary: return _failure("context_boundary")
	var context: Dictionary = packet.context
	if not context.get("objects") is Array or not context.get("pools") is Dictionary or not context.get("MAP") is Array or context.get("source_resolver_registered") != false: return _failure("context_fields")
	if context.objects.size() != 326 or context.MAP.size() != 200: return _failure("context_count")
	for map_row: Variant in context.MAP:
		if not map_row is Array or map_row.size() != 180: return _failure("context_map")
	var objects := {}
	for item: Variant in context.objects:
		if not item is Dictionary or not item.get("object_key") is String or item.object_key.is_empty() or not item.get("raw") is Dictionary or objects.has(item.object_key): return _failure("context_object")
		# Fresh parsed JSON is already private; no caller Dictionary is admitted.
		objects[item.object_key] = item.raw
	var rows: Array[Dictionary] = []; var queue: Array[int] = []; var seen := {}
	for pool: String in ["NPCS", "cityCops", "worldCops"]:
		if not context.pools.get(pool) is Array: return _failure("context_pool")
		for key: Variant in context.pools[pool]:
			if not key is String or not objects.has(key): return _failure("context_alias")
			if seen.has(key): continue
			seen[key] = true
			var raw: Dictionary = objects[key]
			var kind := "resident" if pool == "NPCS" else "police"
			var xy := kind == "police" and _finite_number(raw.get("y")) and _finite_number(raw.get("x"))
			rows.append({"object_key": key, "n": raw, "kind": kind, "xy": xy, "r": raw.get("y" if xy else "r"), "c": raw.get("x" if xy else "c")})
	var stats := {"attempted": true, "checked": 0, "moved": 0, "unresolved": 0, "skipped": 0, "searchChecks": 0, "pending": 0, "exhausted": 0, "slices": 0}
	var interior_active := _truthy(interior._buildingInt) or _truthy(interior._bankInt) or _truthy(interior._majorInteriorObjectId)
	if interior_active: rows.clear() # Original early return precedes row collection.
	else:
		for i in range(rows.size()):
			var row: Dictionary = rows[i]
			if not _eligible(row.n) or not _finite_number(row.r) or not _finite_number(row.c):
				stats.skipped += 1; continue
			row.n._npcInitialPlacementPending = true; row.n.walking = false
			row.radius = .25; row.index = 0; row.maxRadius = sqrt(200.0 * 200.0 + 180.0 * 180.0)
			queue.append(i)
	# Atomic configure: no provider/clock call or state commit occurs above this point.
	_rows = rows; _queue = queue; _stats = stats
	_provenance = {"context_sha256": CONTEXT_SHA, "source_world_sha256": SOURCE_SHA, "session_id": SESSION, "phase": PHASE, "provider": provider.duplicate(true), "interior_state": interior.duplicate(true)}
	_body_pass = source_body_pass; _clock = clock_ms; _configured = true
	return {"ok": true, "initial_step_pending": true, "stats": _stats.duplicate(true)}

func _now() -> float:
	if not _clock.is_valid(): _fault = "clock_unavailable"; return NAN
	var value: Variant = _clock.call()
	if not _clock.is_valid(): _fault = "clock_unavailable"; return NAN
	if not _fault.is_empty(): return NAN
	if not _finite_number(value): _fault = "clock_nonfinite"; return NAN
	if float(value) < _last_ms: _fault = "clock_nonmonotonic"; return NAN
	_last_ms = float(value)
	return _last_ms

func _pass(row: Dictionary, r: float, c: float) -> bool:
	if not _body_pass.is_valid(): _fault = "body_provider_unavailable"; return false
	var value: Variant = _body_pass.call(row.object_key, row.kind, row.n.duplicate(true), r, c)
	if not _body_pass.is_valid(): _fault = "body_provider_unavailable"; return false
	if not _fault.is_empty(): return false
	if not value is bool: _fault = "body_provider_result"; return false
	return value

func _spacing(row_index: int, r: float, c: float) -> bool:
	for i in range(_rows.size()):
		if i == row_index: continue
		var other: Dictionary = _rows[i]
		if _truthy(other.n.get("dead")): continue
		var rkey := "y" if other.xy else "r"; var ckey := "x" if other.xy else "c"
		var dr := _js_number(other.n.get(rkey), other.n.has(rkey)) - r
		var dc := _js_number(other.n.get(ckey), other.n.has(ckey)) - c
		if sqrt(dr * dr + dc * dc) < .55: return false
	return true

func _event(row: Dictionary, status: String, commands: Array[String]) -> Dictionary:
	var event := {"status": status, "object_key": row.object_key, "raw_id": row.n.get("id"), "kind": row.kind, "r": row.r, "c": row.c, "physical_admission": false, "commands": commands.duplicate()}
	for key: String in ["context_sha256", "source_world_sha256", "session_id", "phase", "provider"]: event[key] = _provenance[key].duplicate(true) if _provenance[key] is Dictionary else _provenance[key]
	return event

func _moved(row: Dictionary, r: float, c: float) -> Array[String]:
	var commands: Array[String] = []
	var raw: Dictionary = row.n
	if row.xy: raw.y = r; raw.x = c; raw.ty = r; raw.tx = c
	else:
		raw.r = r; raw.c = c; raw.tr = r; raw.tc = c
		raw._npcWanderSearch = null; raw._route = null; raw._routeIndex = 0
		raw._routeGoalR = null; raw._routeGoalC = null; raw._routeBlockedAt = 0
		commands.append("_clearNpcRoute")
	if row.kind == "police":
		raw._policeFootRoute = null; raw._policeFootRouteIndex = 0; raw._policeFootRouteUntil = 0; raw._policeFootRouteRetryAt = 0
		commands.append("_clearPoliceFootRoute")
	row.r = r; row.c = c; raw.walking = false; raw.walkPhase = 0
	raw._waterEscapeTarget = null; raw._waterEscapeSearch = null; raw._waterEscapeRetryAt = 0
	raw.erase("_npcInitialPlacementPending")
	return commands

func step(max_checks: int = 96, max_ms: float = 2.0) -> Dictionary:
	if _busy:
		_fault = "reentrancy"; return _failure(_fault)
	if not _configured: return _failure("unconfigured")
	if not _fault.is_empty(): return _result([])
	if max_checks < 1 or max_checks > 128 or not is_finite(max_ms) or max_ms <= 0 or max_ms > 4: return _failure("step_budget")
	if _initial_step_pending and (max_checks != 128 or max_ms != 4.0): return _failure("initial_step_budget")
	_initial_step_pending = false
	if _queue.is_empty(): return _result([])
	_busy = true
	var deadline := _now() + max_ms; var checks := 0; var events: Array[Dictionary] = []
	_stats.slices += 1
	while not _queue.is_empty() and checks < max_checks and _fault.is_empty() and _now() < deadline:
		if not _fault.is_empty(): break
		var row_index: int = _queue.pop_front(); var row: Dictionary = _rows[row_index]
		if not _eligible(row.n):
			row.n.erase("_npcInitialPlacementPending"); _stats.skipped += 1; continue
		if not row.get("checked", false):
			row.checked = true; _stats.checked += 1; checks += 1
			if _pass(row, float(row.r), float(row.c)):
				row.n.erase("_npcInitialPlacementPending"); events.append(_event(row, "original", [])); continue
		var chosen := false; var chosen_r := 0.0; var chosen_c := 0.0; var local := 0
		while local < 16 and checks < max_checks and _fault.is_empty() and _now() < deadline and row.radius <= row.maxRadius:
			if not _fault.is_empty(): break
			local += 1
			var spokes := mini(64, maxi(8, int(ceil(float(row.radius) * 10.0))))
			var angle := float(row.index) * PI * 2.0 / float(spokes)
			var r := float(row.r) + sin(angle) * float(row.radius); var c := float(row.c) + cos(angle) * float(row.radius)
			row.index += 1
			if row.index >= spokes:
				row.index = 0; row.radius += .25 if row.radius < 6 else .5 if row.radius < 24 else 1.0
			checks += 1; _stats.searchChecks += 1
			if not _pass(row, r, c) or not _spacing(row_index, r, c): continue
			chosen = true; chosen_r = r; chosen_c = c; break
		if not _fault.is_empty(): break
		if chosen:
			var commands := _moved(row, chosen_r, chosen_c)
			_stats.moved += 1; events.append(_event(row, "relocated", commands))
		elif row.radius <= row.maxRadius: _queue.append(row_index)
		else: _stats.exhausted += 1 # Pending flag remains true; never admitted.
	_busy = false
	_stats.pending = _queue.size(); _stats.unresolved = _stats.pending + _stats.exhausted
	# Faults permanently stop this instance. Progress diagnostics remain truthful,
	# but ALL events from the failing step are suppressed, with no resume API.
	return _result(events if _fault.is_empty() else [])

func _result(events: Array) -> Dictionary:
	var status := "FAULT" if not _fault.is_empty() else "PENDING" if not _queue.is_empty() else "UNRESOLVED" if _stats.exhausted > 0 else "COMPLETE"
	return {"ok": _fault.is_empty(), "error": _fault, "status": status, "done": status == "COMPLETE", "events": events.duplicate(true), "stats": _stats.duplicate(true)}

func snapshot() -> Dictionary:
	var queue: Array[String] = []
	for i in _queue: queue.append(_rows[i].object_key)
	return {"configured": _configured, "fault": _fault, "rows": _rows.duplicate(true), "queue": queue, "stats": _stats.duplicate(true), "provenance": _provenance.duplicate(true), "initial_step_pending": _initial_step_pending}
