extends RefCounted
## Full original 78-entry initial support, scalar Float64 recipes captured from
## actual source templates. No NPC creation, current-door or physical admission.
const DATA_SHA := "dd304db781ee18da12cb3111a3f8126b89658a2562dee38ccd9c2567c9a3ca15"
const VALUES_SHA := "1a05e2bd1d05ffb48634991c1047fc4c1e7fff873f4a0c1fa08d3cb4792a6b88"
const PHASE := "OFFLINE_NEW_SESSION_SOURCE_REFRESH_INITIAL_DOORS_UPDATE_ZERO_BEFORE_NATIVE_REGISTRATION"
var _entries: Array = []
var _sample_rows: Dictionary = {}
var _configured := false
var _decode_error := false
var _fault := ""

static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
	return h.finish().hex_encode()

func _decode(value: Variant, values: PackedByteArray, depth: int = 0) -> Variant:
	if depth > 48: _decode_error = true; return null
	if value is Dictionary:
		if value.has("$f64"):
			var index: Variant = value["$f64"]
			if value.size() != 1 or not (index is float or index is int) or not is_finite(float(index)) or index < 0 or index != floor(float(index)) or index >= values.size() / 8:
				_decode_error = true; return null
			var number := values.decode_double(int(index) * 8)
			if not is_finite(number): _decode_error = true
			return number
		var result := {}
		for key: String in value: result[key] = _decode(value[key], values, depth + 1)
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_decode(item, values, depth + 1))
		return result
	return value

func configure(data_bytes: PackedByteArray, value_bytes: PackedByteArray) -> Dictionary:
	if _configured: return {"ok": false, "error": "already_configured"}
	if data_bytes.size() > 12582912 or value_bytes.size() > 4194304 or value_bytes.size() % 8 != 0 or _hash(data_bytes) != DATA_SHA or _hash(value_bytes) != VALUES_SHA: return {"ok": false, "error": "source_bytes"}
	var parsed := JSON.new()
	if parsed.parse(data_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary: return {"ok": false, "error": "source_json"}
	_decode_error = false
	var packet: Dictionary = _decode(parsed.data, value_bytes)
	if _decode_error or packet.get("schema") != "mafiozi.npc-registered-building-support/v1" or packet.get("phase") != PHASE or packet.get("metres_per_cell") != 4.1 or not packet.get("entries") is Array or packet.entries.size() != 78 or packet.get("source_order") != "75buildings_then3detention" or packet.get("matrix_layout") != "THREE_COLUMN_MAJOR_16_FLOAT64": return {"ok": false, "error": "source_packet"}
	var ids := {}
	for i in 78:
		var entry: Variant = packet.entries[i]
		if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id) or not entry.get("floor_layers") is Array or not entry.get("collision_bodies") is Array: return {"ok": false, "error": "source_entry"}
		ids[entry.id] = true
		for layer: Dictionary in entry.floor_layers:
			if layer.get("kind") not in ["profile", "legacy", "storeys", "hospital", "detention"]: return {"ok": false, "error": "source_layer"}
	var sample_rows := {}
	# Exact createWalkCollisionIndex([entry sampleBounds polygons], 4). Keep
	# the source two divisions and insertion order at cell boundaries.
	for i in packet.entries.size():
		var bounds: Dictionary = packet.entries[i].sample_bounds
		var r0 := int(floor((bounds.min[2] / 4.1) / 4.0))
		var r1 := int(floor((bounds.max[2] / 4.1) / 4.0))
		var c0 := int(floor((bounds.min[0] / 4.1) / 4.0))
		var c1 := int(floor((bounds.max[0] / 4.1) / 4.0))
		for r in range(r0, r1 + 1):
			if not sample_rows.has(r): sample_rows[r] = {}
			for c in range(c0, c1 + 1):
				if not sample_rows[r].has(c): sample_rows[r][c] = []
				sample_rows[r][c].append(i)
	_entries = packet.entries; _sample_rows = sample_rows; _configured = true
	return {"ok": true, "entries": 78, "data_sha256": DATA_SHA, "values_sha256": VALUES_SHA, "phase": PHASE, "combined_ground": false, "physical_admission": false}

func invalidate(reason: String) -> void:
	if _fault.is_empty(): _fault = reason if not reason.is_empty() else "invalidated"

func floor_at(x: float, z: float, reference_y: float = 0.0) -> Dictionary:
	if not _configured or not _fault.is_empty(): return {"known": false, "error": _fault if _configured else "unconfigured"}
	if not is_finite(x) or not is_finite(z) or not is_finite(reference_y) or absf(x) > 1e6 or absf(z) > 1e6 or absf(reference_y) > 1e6: return {"known": false, "error": "coordinates"}
	# Original ordered sampledBuildingEntries chooses the first non-null floor.
	var row: Dictionary = _sample_rows.get(int(floor((z / 4.1) / 4.0)), {})
	var candidates: Array = row.get(int(floor((x / 4.1) / 4.0)), [])
	for index: int in candidates:
		var entry: Dictionary = _entries[index]
		var value: Variant = _layer(entry.floor_layers, entry.floor_layers.size() - 1, x, z, reference_y)
		if value != null: return {"known": true, "value": value, "entry_id": entry.id, "combined_ground": false, "physical_admission": false}
	return {"known": true, "value": null, "combined_ground": false, "physical_admission": false}

func entry_floor(index: int, x: float, z: float, reference_y: float = 0.0) -> Dictionary:
	if not _configured or not _fault.is_empty() or index < 0 or index >= _entries.size() or not is_finite(x) or not is_finite(z) or not is_finite(reference_y): return {"known": false, "error": "entry_query"}
	var entry: Dictionary = _entries[index]
	return {"known": true, "value": _layer(entry.floor_layers, entry.floor_layers.size() - 1, x, z, reference_y), "combined_ground": false, "physical_admission": false}

func collision_collections() -> Dictionary:
	if not _configured or not _fault.is_empty(): return {"known": false, "error": "snapshot_unavailable"}
	var collections: Array = []
	for entry: Dictionary in _entries: collections.append({"entry_id": entry.id, "bodies": entry.collision_bodies.duplicate(true)})
	return {"known": true, "collections": collections, "phase": PHASE, "physical_admission": false}

static func _transform(e: Array, x: float, y: float, z: float) -> Array:
	var w: float = 1.0 / (e[3] * x + e[7] * y + e[11] * z + e[15])
	return [(e[0] * x + e[4] * y + e[8] * z + e[12]) * w, (e[1] * x + e[5] * y + e[9] * z + e[13]) * w, (e[2] * x + e[6] * y + e[10] * z + e[14]) * w]

static func _rect(x: float, z: float, rect: Array, pad: float = 0.0) -> bool:
	return x >= rect[0] - pad and x <= rect[2] + pad and z >= rect[1] - pad and z <= rect[3] + pad

static func _inside(bounds: Dictionary, x: float, z: float, pad: float = 0.0) -> bool:
	return x >= bounds.min[0] - pad and x <= bounds.max[0] + pad and z >= bounds.min[2] - pad and z <= bounds.max[2] + pad

static func _triangles(recipe: Dictionary, x: float, z: float) -> Variant:
	var height: Variant = null
	for t: Dictionary in recipe.triangles:
		if x < t.minX - 1e-6 or x > t.maxX + 1e-6 or z < t.minZ - 1e-6 or z > t.maxZ + 1e-6: continue
		var a: Array = t.a; var b: Array = t.b; var c: Array = t.c
		var u: float = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / t.denominator
		var v: float = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / t.denominator
		var w := 1.0 - u - v
		if u >= -1e-6 and v >= -1e-6 and w >= -1e-6:
			var y: float = u * a[1] + v * b[1] + w * c[1]
			height = y if height == null else maxf(height, y)
	return height

static func _stair(s: Dictionary, x: float, z: float, ref: float) -> Variant:
	if s.kind == "front": return _stair(s.child, 2.0 * s.cx - x, 2.0 * s.cz - z, ref)
	if s.kind == "fitted": return _stair(s.child, -z if s.rotated else x, x if s.rotated else z, ref)
	if not _rect(x, z, s.footprint, 1e-7) or s.floors == 1.0: return null
	var height: Variant = null
	for f: Dictionary in s.flights:
		if _rect(x, z, f.rect, 1e-7):
			var y: float = f.base + s.halfRise * clampf((z - s.za) / s.run if f.direction == 1.0 else (s.zb - z) / s.run, 0.0, 1.0)
			if y <= ref + .28 + 1e-6: height = y if height == null else maxf(height, y)
	for landing: Dictionary in s.landings:
		if _rect(x, z, landing.rect, 1e-7) and landing.y <= ref + .28 + 1e-6: height = landing.y if height == null else maxf(height, landing.y)
	return height

static func _layer(layers: Array, index: int, x: float, z: float, ref: float) -> Variant:
	if index < 0: return null
	var s: Dictionary = layers[index]
	match s.kind:
		"profile":
			if s.flatPlacement and not _inside(s.sampleBounds, x, z): return null
			var p := _transform(s.inverse, x, s.baseWorldY, z)
			if _rect(p[0], p[2], [s.roomMinX, s.roomMinZ, s.roomMaxX, s.roomMaxZ], 1e-6) or absf(p[0]) <= s.halfWidth + 1e-6 and p[2] >= s.corridorRect[1] - 1e-6 and p[2] <= 1e-6: return s.baseWorldY
			if absf(p[0]) <= s.halfWidth + 1e-6 and p[2] >= -1e-6 and p[2] <= s.rampLength + 1e-6: return s.baseWorldY * clampf(1.0 - p[2] / s.rampLength, 0.0, 1.0)
			return null
		"legacy":
			var p := _transform(s.inverse, x, 0.0, z); var room: Dictionary = s.profile.room
			if absf(p[0]) <= 1.450001 and p[2] >= 5.1 - 1e-6 and p[2] <= 7.4 + 1e-6: return _transform(s.matrix, p[0], .44 * clampf((7.4 - p[2]) / 2.3, 0.0, 1.0), p[2])[1]
			if _rect(p[0], p[2], [room.minX, room.minZ, room.maxX, room.maxZ]): return _transform(s.matrix, p[0], .45, p[2])[1]
			var y: Variant = _triangles(s.platform, p[0], p[2])
			return null if y == null else _transform(s.matrix, p[0], y, p[2])[1]
		"storeys":
			if not _inside(s.bounds, x, z): return null
			var p := _transform(s.inverse, x, ref, z); var values: Array = []
			for f: Dictionary in s.floors:
				if not _rect(p[0], p[2], f.rect): continue
				var hole: Variant = null
				for stair: Dictionary in s.stairs:
					if stair.upperLevel == f.level: hole = stair.holeRect; break
				if hole == null or not _rect(p[0], p[2], hole): values.append(f.y)
			for stair: Dictionary in s.stairs:
				var y: Variant = _stair(stair.recipe, p[0], p[2], p[1])
				if y != null: values.append(y)
			for f: Dictionary in s.ladderApproachFloors:
				if _rect(p[0], p[2], f.rect): values.append(f.y)
			if s.roof != null and _rect(p[0], p[2], s.roof.rect, .001): values.append(s.roof.y)
			var height: Variant = null
			for y: float in values:
				if y <= p[1] + .28 + 1e-6: height = y if height == null else maxf(height, y)
			return s.baseY + height if height != null else _layer(layers, index - 1, x, z, ref)
		"hospital":
			var existing: Variant = _layer(layers, index - 1, x, z, ref); var support: Variant = null
			if _inside(s.bounds, x, z, 1e-6):
				if _inside(s.rampBounds, x, z, 1e-6): support = _triangles(s.ramp, x, z)
				if _inside(s.publicBounds, x, z, 1e-6):
					for floor_source: Dictionary in s.floorSources:
						if not _inside(floor_source.bounds, x, z, 1e-6): continue
						var y: Variant = _triangles(floor_source.recipe, x, z)
						if y != null: support = y if support == null else maxf(support, y)
			return existing if support == null else support if existing == null else maxf(existing, support)
		"detention":
			if not _inside(s.sampleBounds, x, z, s.EPS): return null
			var p := _transform(s.inverse, x, 0.0, z)
			if _rect(p[0], p[2], [s.rx0, s.rampStart, s.rx1, s.endZ], s.EPS): return _transform(s.matrix, 0.0, .33 * (s.endZ - p[2]) / s.rampLength, 0.0)[1]
			for f: Dictionary in s.floors:
				if _rect(p[0], p[2], f.rect, s.EPS): return _transform(s.matrix, 0.0, f.y, 0.0)[1]
			if _rect(p[0], p[2], [-9.0, 8.5, -1.0, 10.8 if s.compactSite else 16.5], s.EPS) or _rect(p[0], p[2], [-6.3, 7.7, -2.1, 10.7], s.EPS): return _transform(s.matrix, 0.0, .33, 0.0)[1]
	return null # Unsupported kinds are rejected before installation.
