extends RefCounted
## Pinned offline SOURCE fallback predicates. No native physical admission,
## population, source clock, access, life, HP, server or resolver registration.
const CONTEXT_SHA := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const SOURCE_SHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const GEOMETRY_SHA := "c5f57678912a0c18b51430ea0ef69ea2c84572d32392fa036b84c53f4933724b"
# Final exporter pin is set only after source geometry transport freeze.
const PRIMITIVES_SHA := "85a551406815a6dbc3d056030a0de120a66f4ede0e329a00bad8dc04e7a5e342"
const SESSION := "godot-preview-new-session-20260927-01"
const PHASE := "AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER"
const PROVIDER_ID := "mafiozi.source-placement-primitives.offline-v1"
const PROVIDER_VERSION := "1"
const SEMANTICS := {"ped_blocked":"isBlockedPed", "city_surface":"_cityV3NextSurfaceAt"}
var _configured := false
var _busy := false
var _fault := ""
var _error := ""
var _state: Dictionary = {}
var _data: Dictionary = {}
var _geometry: Dictionary = {}
var _actors: Dictionary = {}
var _rects: Dictionary = {}
var _queries := 0

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _text(value: Variant, expected: String) -> bool:
	return value is String and value == expected

func configure(context_bytes: PackedByteArray, primitives_bytes: PackedByteArray, prison_geometry_bytes: PackedByteArray, trust: Dictionary, source_snapshot: Dictionary) -> Dictionary:
	if _busy: invalidate("reentrancy"); return {"ok":false,"error":_fault}
	if _configured or not _fault.is_empty(): return {"ok":false,"error":"already_configured_or_fault"}
	if not Thread.is_main_thread(): return {"ok":false,"error":"thread"}
	for key in ["context_sha256","source_world_sha256","static_geometry_sha256","primitives_sha256","session_id","phase"]:
		if not trust.get(key) is String: return {"ok":false,"error":"trust_fields"}
	if trust.context_sha256 != CONTEXT_SHA or trust.source_world_sha256 != SOURCE_SHA or trust.static_geometry_sha256 != GEOMETRY_SHA or trust.primitives_sha256 != PRIMITIVES_SHA or trust.session_id != SESSION or trust.phase != PHASE:
		return {"ok":false,"error":"trust_binding"}
	if _hash(context_bytes) != CONTEXT_SHA or _hash(primitives_bytes) != PRIMITIVES_SHA or _hash(prison_geometry_bytes) != GEOMETRY_SHA:
		return {"ok":false,"error":"byte_binding"}
	for key in ["source_world_sha256","session_id","snapshot_id"]:
		if not source_snapshot.get(key) is String or source_snapshot[key].is_empty(): return {"ok":false,"error":"snapshot_fields"}
	if source_snapshot.source_world_sha256 != SOURCE_SHA or source_snapshot.session_id != SESSION or not source_snapshot.get("revision") is int or source_snapshot.revision < 0:
		return {"ok":false,"error":"snapshot_binding"}
	for key in ["native_nav_present","water_present","prison_enabled"]:
		if not source_snapshot.get(key) is bool: return {"ok":false,"error":"snapshot_phase_fields"}
	if source_snapshot.native_nav_present or source_snapshot.water_present or not source_snapshot.prison_enabled or not source_snapshot.get("water_bypass") is int or source_snapshot.water_bypass != 0:
		return {"ok":false,"error":"unsupported_phase"}
	# Dynamic fields may be absent. Invalid optional fields are UNKNOWN only if
	# visited, but cannot retain caller-owned containers/resources.
	for key in ["release_gate_progress","alarm_active"]:
		if source_snapshot.has(key) and (source_snapshot[key] is Object or source_snapshot[key] is Dictionary or source_snapshot[key] is Array): return {"ok":false,"error":"snapshot_container"}
	var parsed := JSON.new(); var context_parsed := JSON.new(); var geometry_parsed := JSON.new()
	if parsed.parse(primitives_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary or context_parsed.parse(context_bytes.get_string_from_utf8()) != OK or not context_parsed.data is Dictionary or geometry_parsed.parse(prison_geometry_bytes.get_string_from_utf8()) != OK or not geometry_parsed.data is Dictionary:
		return {"ok":false,"error":"json"}
	var packet: Dictionary = parsed.data; var context_packet: Dictionary = context_parsed.data
	if not _text(packet.get("schema"),"mafiozi.npc-source-placement-primitives/v1") or not _text(packet.get("source_world_sha256"),SOURCE_SHA) or not _text(packet.get("context_sha256"),CONTEXT_SHA) or not _text(packet.get("session_id"),SESSION) or not _text(packet.get("phase"),PHASE) or not packet.get("data") is Dictionary:
		return {"ok":false,"error":"data_binding"}
	var data: Dictionary = packet.data
	# Godot JSON decimal ingestion alone is not a bit-exact source transport.
	# Overlay every source noninteger scalar from the pinned little-endian data.
	if not packet.get("data_float64") is Array or packet.data_float64.size() != 1208 or not _overlay(data,packet.data_float64): return {"ok":false,"error":"float64_transport"}
	var geometry: Dictionary = data.prison_static_dependency.decoded_data
	if data.prison_static_dependency.bytes_utf8 != prison_geometry_bytes.get_string_from_utf8() or not geometry.prison_enabled:
		return {"ok":false,"error":"static_dependency"}
	# Exact pinned phase proves absence; no fabricated generic clear providers.
	var registries: Dictionary = data.registries
	if not registries.next_entries.is_empty() or not registries.accepted_entries.is_empty() or not registries.decor_entries.is_empty() or registries.civic != null or registries.glass != null or registries.rail != null:
		return {"ok":false,"error":"unsupported_registry_phase"}
	var actors := {}; var objects := {}; var full: Dictionary = context_packet.context
	for item: Dictionary in full.objects: objects[item.object_key] = item.raw
	for pool in ["NPCS","cityCops","worldCops"]:
		for key: String in full.pools[pool]:
			if not actors.has(key): actors[key] = {"raw":objects[key],"kind":"resident" if pool == "NPCS" else "police"}
	var rects := {}
	for entry: Array in data.building_cache.resolved_entries: rects[entry[0]] = entry[1]
	if actors.size() != 326 or rects.size() != 360 or data.building_cache.historical_entries.size() != 204:
		return {"ok":false,"error":"population_or_cache_receipt"}
	_data = data; _geometry = geometry; _actors = actors; _rects = rects
	_state = {"source_world_sha256":SOURCE_SHA,"session_id":SESSION,"snapshot_id":source_snapshot.snapshot_id,"revision":source_snapshot.revision,"native_nav_present":false,"water_present":false,"prison_enabled":true,"water_bypass":0}
	for key in ["release_gate_progress","alarm_active"]:
		if source_snapshot.has(key): _state[key] = source_snapshot[key]
	_configured = true
	return {"ok":true,"physical_admission":false}

static func _overlay(data: Dictionary, overlays: Array) -> bool:
	var seen := {}
	for row: Variant in overlays:
		if not row is Dictionary or not row.get("path") is Array or row.path.is_empty() or not row.get("bytes_le") is Array or row.bytes_le.size() != 8: return false
		var path: Array = row.path; var signature := JSON.stringify(path)
		if seen.has(signature): return false
		seen[signature] = true
		var bytes := PackedByteArray()
		for value: Variant in row.bytes_le:
			if not _finite(value) or float(value) != floor(float(value)) or value < 0 or value > 255: return false
			bytes.append(int(value))
		var decoded := bytes.decode_double(0)
		if not is_finite(decoded): return false
		var cursor: Variant = data
		for i in path.size():
			var key: Variant = path[i]
			if cursor is Dictionary:
				if not key is String or not cursor.has(key): return false
			elif cursor is Array:
				if not _finite(key) or float(key) != floor(float(key)) or key < 0 or key >= cursor.size(): return false
				key = int(key)
			else: return false
			if i == path.size()-1:
				if not _finite(cursor[key]): return false
				cursor[key] = decoded
			else: cursor = cursor[key]
	return true

func bundle() -> Dictionary:
	if not _configured or not _fault.is_empty(): return {"ok":false,"error":_fault if not _fault.is_empty() else "unconfigured"}
	var receipts := {}
	for name: String in SEMANTICS: receipts[name] = {"id":PROVIDER_ID,"version":PROVIDER_VERSION,"semantics":SEMANTICS[name]}
	return {"ok":true,"callbacks":{"ped_blocked":Callable(self,"ped_blocked"),"city_surface":Callable(self,"city_surface")},"primitive_trust":receipts,"source_snapshot":_state.duplicate(true),"physical_admission":false}

func invalidate(reason: String = "invalidated") -> void:
	if _fault.is_empty(): _fault = reason if not reason.is_empty() else "invalidated"

func snapshot() -> Dictionary:
	return {"configured":_configured,"fault":_fault,"queries":_queries,"source_snapshot":_state.duplicate(true),"physical_admission":false,"primitives_sha256":PRIMITIVES_SHA}

func _proof() -> Dictionary:
	return {"source_world_sha256":SOURCE_SHA,"session_id":SESSION,"snapshot_id":_state.get("snapshot_id"),"revision":_state.get("revision"),"provider_id":PROVIDER_ID,"provider_version":PROVIDER_VERSION}

func _unknown(reason: String) -> Dictionary:
	return {"known":false,"defined":false,"error":reason,"provenance":_proof(),"physical_admission":false}

func _query(name: String, r: float, c: float, context: Dictionary) -> Dictionary:
	if _busy: invalidate("reentrancy"); return _unknown(_fault)
	if not Thread.is_main_thread(): return _unknown("thread")
	if not _configured or not _fault.is_empty(): return _unknown(_fault if not _fault.is_empty() else "unconfigured")
	for key in ["source_world_sha256","session_id","snapshot_id"]:
		if not context.get(key) is String or context[key] != _state[key]: invalidate("stale_query_lease"); return _unknown(_fault)
	if not context.get("revision") is int or context.revision != _state.revision: invalidate("stale_query_revision"); return _unknown(_fault)
	if not is_finite(r) or not is_finite(c) or absf(r) > 1000000000 or absf(c) > 1000000000: return _unknown("coordinates")
	if not context.get("object_key") is String or not _actors.has(context.object_key) or not context.get("raw") is Dictionary or not _text(context.get("kind"),_actors[context.object_key].kind): return _unknown("source_identity")
	var raw: Dictionary = context.raw; var expected: Dictionary = _actors[context.object_key].raw
	if typeof(raw.get("id")) != typeof(expected.get("id")) or raw.get("id") != expected.get("id"): return _unknown("source_identity")
	for key in ["_uniqueNpc","_said","_beach","_allowBeach"]:
		if raw.has(key) != expected.has(key) or raw.has(key) and (typeof(raw[key]) != typeof(expected[key]) or raw[key] != expected[key]): return _unknown("source_role")
	if not context.get("physical_admission") is bool or context.physical_admission: return _unknown("physical_admission_not_supported")
	_busy = true; _error = ""; _queries += 1
	var value: Variant = _ped(r,c) if name == "ped_blocked" else null
	_busy = false
	if not _error.is_empty(): return _unknown(_error)
	if not _fault.is_empty(): return _unknown(_fault)
	return {"known":true,"defined":true,"value":value,"provenance":_proof(),"physical_admission":false}

func ped_blocked(r: float, c: float, context: Dictionary) -> Dictionary:
	return _query("ped_blocked",r,c,context)

func city_surface(r: float, c: float, context: Dictionary) -> Dictionary:
	# Actual _cityV3NextActive is empty at this pinned source boundary.
	return _query("city_surface",r,c,context)

func _ped(r: float, c: float) -> bool:
	# Source order: decor(false), bridge(.04), rail(false), isBlocked,
	# race edge, business. Empty stages are proven by the pinned data receipts.
	var b: Dictionary = _data.bridge; var pad := .04
	if r >= b.r0 + .34 + pad and r <= b.r1 - .34 - pad and c >= b.canal_c0 - 1.75 - pad and c <= b.canal_c1 + 1.75 + pad: return false
	if _blocked(r,c) or not _error.is_empty(): return true
	if _race(r,c): return true
	return _business(r,c)

func _blocked(r: float, c: float) -> bool:
	var ri := int(floor(r)); var ci := int(floor(c))
	if ri < 0 or ri >= _data.map_rows or ci < 0 or ci >= _data.map_cols: return true
	var prison: Variant = _prison(r,c)
	if not _error.is_empty(): return true
	if prison != null: return prison
	# Civic/next/glass/accepted are absent at this exact source phase.
	for q: Dictionary in _data.port_containers:
		if absf(r-q.r) <= q.h+.04 and absf(c-q.c) <= q.w+.04: return true
	if _data.whole_building_collisions_enabled:
		var key := str(int(floor(r/_data.block_size))*int(_data.block_size))+":"+str(int(floor(c/_data.block_size))*int(_data.block_size))
		if not _rects.has(key): _error = "cache_key_unavailable"; return true
		for q: Dictionary in _rects[key]:
			if r >= q.minR and r < q.maxR+1 and c >= q.minC and c < q.maxC+1: return true
	return not _data.passable_tiles.has(_data.map[ri][ci])

func _prison(r: float, c: float) -> Variant:
	var q: Dictionary = _geometry.prison_layout; var intake: Dictionary = q.intake
	if absf(c-q.centerC) <= intake.gateHalfC and r >= intake.north-.42 and r <= intake.north+.42:
		if not _finite(_state.get("release_gate_progress")) or _state.release_gate_progress < 0 or _state.release_gate_progress > 1: _error = "release_gate_progress_unknown"; return null
		return _state.release_gate_progress < .82
	if r >= intake.north and r <= intake.south and c >= intake.west and c <= intake.east:
		return r >= intake.south-intake.wallBand or c <= intake.west+intake.wallBand or c >= intake.east-intake.wallBand or (r <= intake.north+intake.wallBand and absf(c-q.centerC)>intake.gateHalfC)
	if r >= q.north and r <= q.south and c >= q.west and c <= q.east:
		if not _state.get("alarm_active") is bool: _error = "alarm_active_unknown"; return null
		var north: bool = r <= q.north+q.wallBand and absf(c-q.centerC)>q.northGateHalfC
		var lockdown: bool = _state.alarm_active and c <= q.west+q.wallBand and absf(r-q.vehicleGateR)<=q.vehicleGateHalfR
		var west: bool = c <= q.west+q.wallBand and (lockdown or absf(r-q.vehicleGateR)>q.vehicleGateHalfR)
		var blocked: bool = north or west or r >= q.south-q.wallBand or c >= q.east-q.wallBand
		# Source evaluates solidRects.find even when perimeter is true.
		for rect: Dictionary in q.solidRects:
			if r >= rect.minR and r <= rect.maxR and c >= rect.minC and c <= rect.maxC: return true
		return blocked
	var west: bool = absf(r-q.vehicleGateR)<=q.westCausewayHalfR and c>=q.westCausewayMinC and c<q.west
	var north: bool = absf(c-q.centerC)<=q.northCausewayHalfC and r>=q.northCausewayMinR and r<q.north
	return false if west or north else null

static func _segment(r: float, c: float, ar: float, ac: float, br: float, bc: float) -> float:
	return sqrt(_segment_d2(r,c,ar,ac,br,bc))

static func _segment_d2(r: float, c: float, ar: float, ac: float, br: float, bc: float) -> float:
	var vr := br-ar; var vc := bc-ac; var length2 := vr*vr+vc*vc
	if length2 == 0.0: length2 = 1e-9
	var t := clampf(((r-ar)*vr+(c-ac)*vc)/length2,0.0,1.0)
	var dr := r-(ar+vr*t); var dc := c-(ac+vc*t)
	return dr*dr+dc*dc

func _race(r: float, c: float) -> bool:
	var race: Dictionary = _data.race; var ri := int(floor(r)); var ci := int(floor(c))
	if r < race.beach_r1 or ri < 0 or ri >= _data.map_rows or ci < 0 or ci >= _data.map_cols or _data.map[ri][ci] != 18: return false
	var pit: Dictionary = race.pit
	if r >= pit.r0 and r <= pit.r1:
		for segment: Dictionary in pit.segments:
			if _segment(r,c,segment.a.r,segment.a.c,segment.b.r,segment.b.c) <= segment.radius: return false
	var best := 1e9
	for i in race.path_points.size():
		var a: Array = race.path_points[i]; var b: Array = race.path_points[(i+1)%race.path_points.size()]
		var distance2 := _segment_d2(r,c,a[0],a[1],b[0],b[1])
		best = minf(best,distance2)
	return sqrt(best) > race.half_width-.15

func _business(r: float, c: float) -> bool:
	if not _data.business.enabled: return false
	for exterior: Dictionary in _data.business.entries:
		if absf(r-exterior.center.r)>exterior.halfDepth or absf(c-exterior.center.c)>exterior.halfWidth: continue
		var a: Dictionary = exterior.corridorStart; var b: Dictionary = exterior.anchor
		var dr: float = b.r-a.r; var dc: float = b.c-a.c; var length2 := dr*dr+dc*dc
		if length2 == 0.0: length2 = 1.0
		var t := clampf(((r-a.r)*dr+(c-a.c)*dc)/length2,0.0,1.0)
		var rr: float = r-(a.r+dr*t); var cc: float = c-(a.c+dc*t)
		if sqrt(rr*rr+cc*cc) <= exterior.corridorHalfWidth: return false
		return true
	return false
