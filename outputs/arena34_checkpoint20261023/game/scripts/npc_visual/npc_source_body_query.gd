extends RefCounted
## Exact source BODY policy, not native physical admission or authority.
## Unknown primitive proof is never an invented false/clear source decision.
const CONTEXT_SHA := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const SOURCE_SHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const GEOMETRY_SHA := "c5f57678912a0c18b51430ea0ef69ea2c84572d32392fa036b84c53f4933724b"
const SESSION := "godot-preview-new-session-20260927-01"
const PHASE := "AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER"
const SEMANTICS := {"native_nav": "_walkNpcNavigationResolver", "water": "_walkNpcWaterResolver", "ped_blocked": "isBlockedPed", "city_surface": "_cityV3NextSurfaceAt"}
# Exact midpoint above source Double(.025). That double is even, so the tie
# rounds to .025. Proof: THRESHOLD_PROOF.json, original source literal/IEEE bits.
const UNIQUE_DEPTH_MIDPOINT_DIGITS := "2500000000000000312250225675825276994146406650543212890625"
var _configured := false
var _busy := false
var _fault := ""
var _error := ""
var _map: Array = []
var _actors := {}
var _geometry := {}
var _state := {}
var _providers := {}
var _callbacks := {}
var _provenance := {}
var _trace: Array[Dictionary] = []
var _primitive_trace: Array[Dictionary] = []
var _context := {}
var _last_report := {}
var _diagnostics := true

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
	return h.finish().hex_encode()

static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return value != 0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true # JS empty arrays/objects are truthy.

static func _string_is(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _array_string(value: Array) -> String:
	var parts: PackedStringArray = []
	for item: Variant in value:
		if item == null: parts.append("")
		elif item is Array: parts.append(_array_string(item))
		elif item is Dictionary: parts.append("[object Object]")
		elif item is bool: parts.append("true" if item else "false")
		elif (item is float or item is int) and is_inf(float(item)): parts.append("Infinity" if item > 0 else "-Infinity")
		elif (item is float or item is int) and is_nan(float(item)): parts.append("NaN")
		else: parts.append(str(item))
	return ",".join(parts)

static func _js_whitespace(code: int) -> bool:
	# ECMAScript WhiteSpace + LineTerminator; other controls are NOT trimmed.
	return code in [0x0009, 0x000b, 0x000c, 0x0020, 0x00a0, 0x1680, 0x202f, 0x205f, 0x3000, 0xfeff, 0x000a, 0x000d, 0x2028, 0x2029] or (code >= 0x2000 and code <= 0x200a)

static func _js_trim(text: String) -> String:
	var first := 0
	var last := text.length()
	while first < last and _js_whitespace(text.unicode_at(first)): first += 1
	while last > first and _js_whitespace(text.unicode_at(last - 1)): last -= 1
	return text.substr(first, last - first)

static func _ascii_digit(text: String, index: int) -> bool:
	return index < text.length() and text.unicode_at(index) >= 48 and text.unicode_at(index) <= 57

static func _decimal_string(text: String) -> bool:
	# Validate the ENTIRE JS decimal grammar before the native float parser.
	# Native whitespace/partial-number acceptance must not change NaN fallback.
	var i := 0
	if text.is_empty(): return false
	if text[i] == "+" or text[i] == "-": i += 1
	var digits := 0
	while _ascii_digit(text, i): i += 1; digits += 1
	if i < text.length() and text[i] == ".":
		i += 1
		while _ascii_digit(text, i): i += 1; digits += 1
	if digits == 0: return false
	if i < text.length() and (text[i] == "e" or text[i] == "E"):
		i += 1
		if i < text.length() and (text[i] == "+" or text[i] == "-"): i += 1
		var exponent_start := i
		while _ascii_digit(text, i): i += 1
		if i == exponent_start: return false
	return i == text.length()

static func _decimal_parts(text: String) -> Dictionary:
	var negative := text.begins_with("-")
	var unsigned := text.substr(1) if text.begins_with("+") or negative else text
	var exponent_at := unsigned.find("e")
	if exponent_at < 0: exponent_at = unsigned.find("E")
	var mantissa := unsigned.substr(0, exponent_at) if exponent_at >= 0 else unsigned
	var point := mantissa.find(".")
	var before_point := point if point >= 0 else mantissa.length()
	var digits := mantissa.replace(".", "")
	var first := 0
	while first < digits.length() and digits[first] == "0": first += 1
	if first == digits.length(): return {"negative": negative, "zero": true, "exponent": 0, "digits": ""}
	var exponent := 0
	if exponent_at >= 0:
		var tail := unsigned.substr(exponent_at + 1)
		var exponent_negative := tail.begins_with("-")
		if tail.begins_with("+") or exponent_negative: tail = tail.substr(1)
		var limit := text.length() + 400
		for character in tail:
			exponent = mini(limit, exponent * 10 + "0123456789".find(character))
		if exponent_negative: exponent = -exponent
	exponent += before_point - first - 1
	return {"negative": negative, "zero": false, "exponent": exponent, "digits": digits.substr(first)}

static func _decimal_number(text: String) -> float:
	# Diagnostic approximation, NOT a generic JS Number polyfill. Production
	# uses the exact comparison predicate below; subnormal rounding may differ.
	var parts := _decimal_parts(text)
	var negative: bool = parts.negative
	if parts.zero: return -0.0 if negative else 0.0
	var exponent: int = parts.exponent
	if exponent > 308: return -INF if negative else INF
	if exponent < -324: return -0.0 if negative else 0.0
	var significant: String = parts.digits
	var coefficient := significant[0] + ("." + significant.substr(1) if significant.length() > 1 else "")
	var result: float
	if exponent >= -290:
		result = (coefficient + "e" + str(exponent)).to_float()
	else:
		# Keep both scale factors finite, including the subnormal range.
		result = (coefficient.to_float() * pow(10.0, exponent + 308)) * 1e-308
	return -result if negative else result

static func _depth_exceeds(value: Variant, present: bool = true) -> bool:
	# Exact original JS predicate Number(value) > .025 for admitted data.
	# Avoid native decimal double-rounding at the source threshold midpoint.
	if not present or value == null: return false
	if value is bool: return value
	if value is float or value is int: return value > .025
	if value is Array:
		if value.size() != 1: return false
		var item: Variant = value[0]
		if item is bool or item is Dictionary: return false
		return _depth_exceeds(item)
	if not value is String: return false
	var text := _js_trim(value)
	if text == "Infinity" or text == "+Infinity": return true
	if text.is_empty() or text.begins_with("-"): return false
	if text.begins_with("0x") or text.begins_with("0X") or text.begins_with("0b") or text.begins_with("0B") or text.begins_with("0o") or text.begins_with("0O"):
		var prefix := text.substr(1, 1).to_lower()
		var radix := 16 if prefix == "x" else 2 if prefix == "b" else 8
		if text.length() < 3: return false
		var nonzero := false
		for character in text.substr(2).to_lower():
			var digit := "0123456789abcdef".find(character)
			if digit < 0 or digit >= radix: return false
			nonzero = nonzero or digit != 0
		return nonzero # Valid positive radix integers are zero or >=1.
	if not _decimal_string(text): return false
	var parts := _decimal_parts(text)
	if parts.zero: return false
	if parts.exponent != -2: return parts.exponent > -2
	var digits: String = parts.digits
	for index in maxi(digits.length(), UNIQUE_DEPTH_MIDPOINT_DIGITS.length()):
		var actual := digits.unicode_at(index) if index < digits.length() else 48
		var boundary := UNIQUE_DEPTH_MIDPOINT_DIGITS.unicode_at(index) if index < UNIQUE_DEPTH_MIDPOINT_DIGITS.length() else 48
		if actual != boundary: return actual > boundary
	return false # Exact midpoint ties to the even source .025, not its successor.

static func _number(value: Variant, present: bool = true) -> float:
	# JS comparison coercion is used only where the original uses >, never for
	# Number.isFinite depth selection. Missing and null remain distinct here.
	if not present: return NAN
	if value == null: return 0.0
	if value is bool: return 1.0 if value else 0.0
	if value is int or value is float: return float(value)
	if value is Array:
		# JS Array.toString joins elements. A singleton numeric leaf round-trips
		# its existing Number exactly; native str(float) would lose its ULPs.
		if value.is_empty(): return 0.0
		if value.size() != 1: return NAN # Every join contains a comma.
		var item: Variant = value[0]
		if item == null: return 0.0
		if item is bool or item is Dictionary: return NAN
		if item is float or item is int: return 0.0 if item == 0 else float(item)
		return _number(item) if item is Array or item is String else NAN
	if value is String:
		var text: String = _js_trim(value)
		if text.is_empty(): return 0.0
		if text == "Infinity" or text == "+Infinity": return INF
		if text == "-Infinity": return -INF
		if text.begins_with("0x") or text.begins_with("0X") or text.begins_with("0b") or text.begins_with("0B") or text.begins_with("0o") or text.begins_with("0O"):
			var prefix := text.substr(1, 1).to_lower()
			var radix := 16 if prefix == "x" else 2 if prefix == "b" else 8
			var result := 0.0
			if text.length() < 3: return NAN
			for character in text.substr(2).to_lower():
				var digit := "0123456789abcdef".find(character)
				if digit < 0 or digit >= radix: return NAN
				# Source Number() yields a floating number, not an int64 parse.
				result = result * radix + digit
			return result
		return _decimal_number(text) if _decimal_string(text) else NAN
	return NAN

static func _prop(value: Variant, name: String) -> Variant:
	return value.get(name) if value is Dictionary else null

static func _has(value: Variant, name: String) -> bool:
	return value is Dictionary and value.has(name)

static func _json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 16: return false
	if value == null or value is bool or value is String or value is int or value is float: return true
	if value is Array:
		if value.size() > 128: return false
		for item: Variant in value:
			if not _json_value(item, depth + 1): return false
		return true
	if value is Dictionary:
		if value.size() > 128: return false
		for key: Variant in value:
			if not key is String or not _json_value(value[key], depth + 1): return false
		return true
	return false

func configure(context_bytes: PackedByteArray, trust: Dictionary, source_snapshot: Dictionary, primitivecallbacks: Dictionary, static_geometry_bytes: PackedByteArray) -> Dictionary:
	if _busy: _fault = "reentrancy"; return _fail(_fault)
	if _configured: return _fail("already_configured")
	if context_bytes.size() > 1048576 or _hash(context_bytes) != CONTEXT_SHA: return _fail("context_hash")
	if static_geometry_bytes.size() > 65536 or _hash(static_geometry_bytes) != GEOMETRY_SHA: return _fail("static_geometry_hash")
	for key: String in ["context_sha256", "source_world_sha256", "static_geometry_sha256", "session_id", "phase"]:
		if not trust.get(key) is String: return _fail("trust_fields")
	if trust.context_sha256 != CONTEXT_SHA or trust.source_world_sha256 != SOURCE_SHA or trust.static_geometry_sha256 != GEOMETRY_SHA or trust.session_id != SESSION or trust.phase != PHASE: return _fail("trust_binding")
	for key: String in ["source_world_sha256", "session_id", "snapshot_id"]:
		if not source_snapshot.get(key) is String or source_snapshot[key].is_empty(): return _fail("snapshot_fields")
	if source_snapshot.source_world_sha256 != SOURCE_SHA or source_snapshot.session_id != SESSION: return _fail("snapshot_binding")
	if not source_snapshot.get("revision") is int or source_snapshot.revision < 0: return _fail("snapshot_revision")
	for key: String in ["native_nav_present", "water_present", "prison_enabled"]:
		if not source_snapshot.get(key) is bool: return _fail("snapshot_fields")
	if not source_snapshot.get("water_bypass") is int or source_snapshot.water_bypass < 0: return _fail("snapshot_fields")
	if not trust.get("primitives") is Dictionary: return _fail("primitive_trust")
	for name: Variant in trust.primitives:
		if not name is String or not SEMANTICS.has(name) or not trust.primitives[name] is Dictionary: return _fail("primitive_trust")
		var receipt: Dictionary = trust.primitives[name]
		for key: String in ["id", "version", "semantics"]:
			if not receipt.get(key) is String or receipt[key].is_empty() or receipt[key].length() > 128: return _fail("primitive_trust")
		if receipt.semantics != SEMANTICS[name]: return _fail("primitive_semantics")
	for key: Variant in primitivecallbacks:
		if not key is String or not SEMANTICS.has(key) or not primitivecallbacks[key] is Callable: return _fail("primitive_callbacks")
	var parsed := JSON.new(); var static_parsed := JSON.new()
	if parsed.parse(context_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary: return _fail("context_json")
	if static_parsed.parse(static_geometry_bytes.get_string_from_utf8()) != OK or not static_parsed.data is Dictionary: return _fail("geometry_json")
	var packet: Dictionary = parsed.data; var geometry_packet: Dictionary = static_parsed.data
	if not _string_is(geometry_packet.get("schema"), "mafiozi.npc-source-body-static-geometry/v1") or geometry_packet.get("source_world_sha256") != SOURCE_SHA or geometry_packet.get("context_sha256") != CONTEXT_SHA or not geometry_packet.get("data") is Dictionary: return _fail("geometry_binding")
	var data: Dictionary = geometry_packet.data
	if source_snapshot.prison_enabled != data.prison_enabled: return _fail("prison_source_flag")
	if not packet.get("context") is Dictionary or packet.get("source_world_sha256") != SOURCE_SHA: return _fail("context_binding")
	var context: Dictionary = packet.context
	var objects := {}; var actors := {}
	for item: Dictionary in context.objects: objects[item.object_key] = item.raw
	for pool: String in ["NPCS", "cityCops", "worldCops"]:
		for key: String in context.pools[pool]:
			if actors.has(key): continue
			actors[key] = {"kind": "resident" if pool == "NPCS" else "police", "raw": objects[key]}
	# Only fresh parsed JSON/internal copies are retained; no caller-owned data.
	_map = context.MAP; _actors = actors; _geometry = data
	_state = source_snapshot.duplicate(true); _providers = trust.primitives.duplicate(true); _callbacks = primitivecallbacks.duplicate()
	_provenance = {"context_sha256": CONTEXT_SHA, "source_world_sha256": SOURCE_SHA, "static_geometry_sha256": GEOMETRY_SHA, "session_id": SESSION, "snapshot_id": _state.snapshot_id, "revision": _state.revision, "physical_admission": false}
	_configured = true
	return {"ok": true, "provenance": _provenance.duplicate(true)}

func _unknown(reason: String, permanent: bool = false) -> void:
	if _error.is_empty(): _error = reason
	if permanent and _fault.is_empty(): _fault = reason

func _known() -> bool:
	return _error.is_empty() and _fault.is_empty()

func _primitive(name: String, r: float, c: float) -> Variant:
	if not _known(): return null
	if not _providers.has(name): _unknown("primitive_proof_missing:" + name); return null
	var callback: Variant = _callbacks.get(name)
	if not callback is Callable or not callback.is_valid(): _unknown("primitive_unavailable:" + name, true); return null
	var response: Variant = callback.call(r, c, _context.duplicate(true))
	if not callback.is_valid(): _unknown("primitive_unavailable:" + name, true); return null
	if not _known(): return null
	if not response is Dictionary or not response.get("known") is bool: _unknown("primitive_result:" + name); return null
	if not response.known:
		_unknown("primitive_unknown:" + name + (":" + response.error if response.get("error") is String else "")); return null
	if not response.get("provenance") is Dictionary: _unknown("primitive_lease:" + name); return null
	var proof: Dictionary = response.provenance; var provider: Dictionary = _providers[name]
	for key: String in ["source_world_sha256", "session_id", "snapshot_id"]:
		if not proof.get(key) is String or proof[key] != _provenance[key]: _unknown("primitive_lease:" + name); return null
	if not proof.get("revision") is int or proof.revision != _state.revision or not proof.get("provider_id") is String or proof.provider_id != provider.id or not proof.get("provider_version") is String or proof.provider_version != provider.version: _unknown("primitive_lease:" + name); return null
	if not response.get("defined") is bool or response.defined and not response.has("value"): _unknown("primitive_value:" + name); return null
	# These are direct source functions with proven non-optional returns.
	# Resolver undefined/null semantics do not grant their missing dependencies.
	if name == "ped_blocked" and (not response.defined or not response.value is bool): _unknown("primitive_value:" + name); return null
	if name == "city_surface" and (not response.defined or response.value != null and not response.value is Dictionary): _unknown("primitive_value:" + name); return null
	if response.defined and not _json_value(response.value): _unknown("primitive_value:" + name); return null
	# Capture a provider's borrowed JSON-like container once. Later callback
	# reuse/mutation cannot rewrite this decision or earlier diagnostic receipts.
	# Do not serialize: NaN/Infinity depths retain original finite/fallback rules.
	var captured: Variant = response.value if response.defined else null
	if captured is Dictionary or captured is Array: captured = captured.duplicate(true)
	if _diagnostics:
		_primitive_trace.append({"name": name, "r": r, "c": c, "defined": response.defined, "value": captured, "provenance": proof.duplicate(true)})
	return captured

func _observe(name: String, r: float, c: float, result: Variant) -> Variant:
	if not _diagnostics: return result
	var row := {"ordinal": _trace.size(), "object_key": _context.get("object_key"), "name": name, "r": r, "c": c, "known": _known()}
	if _known(): row.result = result
	else: row.error = _fault if not _fault.is_empty() else _error
	_trace.append(row)
	return result

func _tile(r: int, c: int) -> Variant:
	return _map[r][c] if r >= 0 and r < _map.size() and c >= 0 and c < _map[0].size() else null

func _native(r: float, c: float) -> Variant:
	return _primitive("native_nav", r, c) if _state.native_nav_present else null

func _navigation(r: float, c: float) -> Dictionary:
	var native: Variant = _native(r, c); var water: Variant = null
	if _known():
		if _finite(_prop(native, "depth")): water = native
		elif _state.water_present: water = _primitive("water", r, c)
	var depth := maxf(0.0, float(_prop(water, "depth"))) if _finite(_prop(water, "depth")) else 1.0 if _tile(int(floor(r)), int(floor(c))) == 16 else 0.0
	var blocked: Variant = _prop(native, "blocked")
	var value := {"blocked": blocked is bool and blocked, "depth": depth}
	_observe("_npcNavigationAt", r, c, value)
	return value

func _route_blocked(r: float, c: float) -> bool:
	var navigation := _navigation(r, c)
	var result: bool = bool(navigation.blocked) or (_state.water_bypass == 0 and navigation.depth > .025)
	_observe("_npcRouteWalkBlocked", r, c, result)
	return result

func _restricted(r: float, c: float, margin: float = .35) -> bool:
	if not _state.prison_enabled: return false
	var q: Dictionary = _geometry.prison_layout; var intake: Dictionary = q.intake
	return (r >= intake.north - margin and r <= intake.south + margin and c >= intake.west - margin and c <= intake.east + margin) or (r >= q.north - margin and r <= q.south + margin and c >= q.west - margin and c <= q.east + margin) or (absf(r - q.vehicleGateR) <= q.westCausewayHalfR + margin and c >= q.westCausewayMinC - margin and c < q.west + margin) or (absf(c - q.centerC) <= q.northCausewayHalfC + margin and r >= q.northCausewayMinR - margin and r < q.north + margin)

func _arena(r: int, c: int) -> bool:
	var a: Dictionary = _geometry.arena
	return r >= a.r0 and r <= a.r1 and c >= a.c0 and c <= a.c1

func _lair(r: int, c: int) -> bool:
	var a: Dictionary = _geometry.lair
	return sqrt((r - a.r) * (r - a.r) + (c - a.c) * (c - a.c)) <= a.radius

func _pit(r: float, c: float) -> bool:
	var pit: Dictionary = _geometry.pit
	if r < pit.r0 or r > pit.r1: return false
	for line: Dictionary in pit.segments:
		var vr: float = line.b.r - line.a.r; var vc: float = line.b.c - line.a.c
		var len2 := vr * vr + vc * vc
		if len2 == 0.0: len2 = .000000001
		var k := clampf(((r - line.a.r) * vr + (c - line.a.c) * vc) / len2, 0.0, 1.0)
		var dr: float = r - (line.a.r + vr * k); var dc: float = c - (line.a.c + vc * k)
		if sqrt(dr * dr + dc * dc) <= line.radius: return true
	return false

func _prison_collision(r: float, c: float) -> Variant:
	var result: Variant = _prison_collision_core(r, c)
	return _observe("_prisonIslandCollisionAt", r, c, result)

func _prison_collision_core(r: float, c: float) -> Variant:
	if not _state.prison_enabled: return null
	var q: Dictionary = _geometry.prison_layout; var intake: Dictionary = q.intake
	if absf(c - q.centerC) <= intake.gateHalfC and r >= intake.north - .42 and r <= intake.north + .42:
		if not _finite(_state.get("release_gate_progress")) or _state.release_gate_progress < 0 or _state.release_gate_progress > 1: _unknown("release_gate_progress_unknown"); return null
		var locked: bool = _state.release_gate_progress < .82
		return {"surface": "intake", "blocked": locked, "kind": "personal-release-gate-locked" if locked else "personal-release-gate-open"}
	if r >= intake.north and r <= intake.south and c >= intake.west and c <= intake.east:
		var perimeter: bool = r >= intake.south - intake.wallBand or c <= intake.west + intake.wallBand or c >= intake.east - intake.wallBand or (r <= intake.north + intake.wallBand and absf(c - q.centerC) > intake.gateHalfC)
		return {"surface": "intake", "blocked": perimeter, "kind": "intake-wall" if perimeter else "holding-room-floor"}
	if r >= q.north and r <= q.south and c >= q.west and c <= q.east:
		# Original evaluates alarm FIRST on every onIsland point, before west test.
		if not _state.get("alarm_active") is bool: _unknown("alarm_active_unknown"); return null
		var north_wall: bool = r <= q.north + q.wallBand and absf(c - q.centerC) > q.northGateHalfC
		var lockdown: bool = _state.alarm_active and c <= q.west + q.wallBand and absf(r - q.vehicleGateR) <= q.vehicleGateHalfR
		var west_wall: bool = c <= q.west + q.wallBand and (lockdown or absf(r - q.vehicleGateR) > q.vehicleGateHalfR)
		var perimeter: bool = north_wall or west_wall or r >= q.south - q.wallBand or c >= q.east - q.wallBand
		var solid: Variant = null
		for rect: Dictionary in q.solidRects:
			if r >= rect.minR and r <= rect.maxR and c >= rect.minC and c <= rect.maxC: solid = rect; break
		return {"surface": "island", "blocked": perimeter or solid != null, "kind": "vehicle-gate-lockdown" if lockdown else "perimeter" if perimeter else solid.kind if solid != null else "floor"}
	var west: bool = absf(r - q.vehicleGateR) <= q.westCausewayHalfR and c >= q.westCausewayMinC and c < q.west
	var north: bool = absf(c - q.centerC) <= q.northCausewayHalfC and r >= q.northCausewayMinR and r < q.north
	return {"surface": "causeway", "blocked": false, "kind": "north-bridge" if north else "west-checkpoint"} if west or north else null

func _unique(r: float, c: float) -> bool:
	var native: Variant = _native(r, c) # Source invokes native BEFORE bounds.
	var ri := int(floor(r)); var ci := int(floor(c)); var result := false
	if _known() and ri > 0 and ri < mini(int(_geometry.beach_r0), _map.size() - 1) and ci > 0 and ci < _map[0].size() - 1 and not _restricted(r, c) and not _arena(ri, ci) and not _lair(ri, ci):
		if _truthy(_prop(native, "surface")):
			result = not _truthy(_prop(native, "blocked")) and not _depth_exceeds(_prop(native, "depth"), _has(native, "depth")) and not _string_is(_prop(native, "surface"), "road")
		else: result = _tile(ri, ci) == 8 or _tile(ri, ci) == 9
	_observe("_uniqueNpcCityPassable", r, c, result)
	return result

func _waypoint(raw: Dictionary, r: float, c: float) -> bool:
	var result := _waypoint_core(raw, r, c)
	_observe("npcWaypointOk", r, c, result)
	return result

func _waypoint_core(raw: Dictionary, r: float, c: float) -> bool:
	var ri := int(floor(r)); var ci := int(floor(c))
	if ri < 1 or ri >= _map.size() - 1 or ci < 1 or ci >= _map[0].size() - 1: return false
	if _restricted(r, c) or _arena(ri, ci) or _lair(ri, ci): return false
	var tile: Variant = _tile(ri, ci)
	if _route_blocked(r, c) or not _known(): return false
	if _truthy(raw.get("_uniqueNpc")) or _truthy(raw.get("_said")): return _unique(r, c)
	if tile == 14 and _pit(ri + .5, ci + .5): return false
	var native: Variant = _native(r, c)
	if not _known(): return false
	var surface: Variant = _prop(native, "surface")
	if _string_is(surface, "land") or _string_is(surface, "road"): return not _string_is(surface, "road")
	if _truthy(raw.get("_beach")): return tile == 14 and ri >= 138 and ri <= 168
	if tile == 14: return _truthy(raw.get("_allowBeach"))
	return tile == 9 or tile == 8

func _snitch(r: float, c: float) -> bool:
	var result := _snitch_core(r, c)
	_observe("npcPassableForSnitch", r, c, result)
	return result

func _snitch_core(r: float, c: float) -> bool:
	if _route_blocked(r, c) or not _known(): return false
	var ri := int(floor(r)); var ci := int(floor(c))
	if ri < 1 or ri >= _map.size() - 1 or ci < 1 or ci >= _map[0].size() - 1: return false
	if _restricted(r, c) or _arena(ri, ci) or _lair(ri, ci): return false
	var native: Variant = _native(r, c)
	if not _known(): return false
	var surface: Variant = _prop(native, "surface"); var tile: Variant = _tile(ri, ci)
	if _string_is(surface, "land") or _string_is(surface, "road"): return not (tile == 14 and _pit(ri + .5, ci + .5))
	var blocked: Variant = _primitive("ped_blocked", r, c)
	if not _known() or _truthy(blocked): return false
	var city: Variant = _primitive("city_surface", r, c)
	if not _known(): return false
	if _truthy(city): return true
	if tile == 14 and _pit(ri + .5, ci + .5): return false
	return tile == 0 or tile == 9 or tile == 8 or tile == 14

func _police(r: float, c: float) -> bool:
	var result := _police_core(r, c)
	_observe("_policeCrewPassable", r, c, result)
	return result

func _police_core(r: float, c: float) -> bool:
	if _route_blocked(r, c) or not _known(): return false
	var prison: Variant = _prison_collision(r, c)
	if not _known(): return false
	if _truthy(prison): return not _truthy(_prop(prison, "blocked"))
	if not _snitch(r, c) or not _known(): return false
	var native: Variant = _native(r, c)
	if not _known(): return false
	if _truthy(_prop(native, "surface")): return true
	var blocked: Variant = _primitive("ped_blocked", r, c)
	return _known() and not _truthy(blocked)

func _evaluate(object_key: String, kind: String, raw: Dictionary, r: float, c: float, diagnostics: bool) -> Dictionary:
	if _busy:
		_fault = "reentrancy"
		return {"known": false, "pass": false, "error": _fault, "physical_admission": false}
	_diagnostics = diagnostics; _error = ""; _trace = []; _primitive_trace = []
	if not _configured: _unknown("unconfigured")
	elif not _fault.is_empty(): _unknown(_fault)
	elif not is_finite(r) or not is_finite(c) or absf(r) > 1000000000 or absf(c) > 1000000000: _unknown("coordinates")
	elif not _actors.has(object_key) or kind != _actors[object_key].kind: _unknown("source_identity")
	else:
		var expected: Dictionary = _actors[object_key].raw
		if not raw.has("id") or typeof(raw.id) != typeof(expected.get("id")) or raw.id != expected.get("id"): _unknown("source_identity")
		for flag: String in ["_uniqueNpc", "_said", "_beach", "_allowBeach"]:
			if raw.has(flag) != expected.has(flag) or raw.has(flag) and (typeof(raw[flag]) != typeof(expected[flag]) or raw[flag] != expected[flag]): _unknown("source_role")
	_context = {"source_world_sha256": SOURCE_SHA, "session_id": SESSION, "snapshot_id": _state.get("snapshot_id"), "revision": _state.get("revision"), "object_key": object_key, "kind": kind, "raw": raw.duplicate(true), "physical_admission": false}
	var passable := false
	if _known():
		_busy = true
		var pad := .18 if kind == "resident" else .24
		var probes: Array = [[r, c], [r - pad, c - pad], [r - pad, c + pad], [r + pad, c - pad], [r + pad, c + pad]]
		passable = true
		if kind == "resident":
			for point: Array in probes:
				if _route_blocked(point[0], point[1]) or not _known(): passable = false; break
		if passable:
			for point: Array in probes:
				var accepted := _waypoint(raw, point[0], point[1]) if kind == "resident" else _police(point[0], point[1])
				if not _known() or not accepted: passable = false; break
		_busy = false
	# Internal trace arrays are fresh per evaluation, contain private captures,
	# and are never mutated after completion. Public query/snapshot clone them.
	_last_report = {"known": _known(), "pass": passable if _known() else false, "error": _fault if not _fault.is_empty() else _error, "provenance": _provenance.duplicate(true), "physical_admission": false, "diagnostics_recorded": diagnostics, "trace": _trace, "primitive_trace": _primitive_trace}
	return _last_report

func query(object_key: String, kind: String, raw: Dictionary, r: float, c: float) -> Dictionary:
	return _evaluate(object_key, kind, raw, r, c, true).duplicate(true)

func body_pass(object_key: String, kind: String, raw: Dictionary, r: float, c: float) -> Variant:
	# Same policy/proof/capture core, without per-probe diagnostic allocation or
	# a public report copy. A compact NEW last_report replaces any earlier trace.
	var report := _evaluate(object_key, kind, raw, r, c, false)
	return report.pass if report.known else null

func snapshot() -> Dictionary:
	return {"configured": _configured, "fault": _fault, "provenance": _provenance.duplicate(true), "source_snapshot": _state.duplicate(true), "last_report": _last_report.duplicate(true)}
