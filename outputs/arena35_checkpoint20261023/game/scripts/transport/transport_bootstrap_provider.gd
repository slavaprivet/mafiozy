extends RefCounted

const SCHEMA := "mafiozi.transport.bootstrap-factory.v1"

var error := ""
var _catalog: RefCounted
var _factory: Dictionary = {}
var _slots: Dictionary = {}
var _issued: Dictionary = {}

func configure(catalog: RefCounted, path: String = "res://data/transport/transport_bootstrap_factory.v1.json") -> bool:
	error = ""; _catalog = catalog; _factory.clear(); _slots.clear(); _issued.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: error = "OPEN_FAILED"; return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema", "") != SCHEMA:
		error = "SCHEMA"; return false
	var authority: Dictionary = parsed.get("authority", {})
	if String(authority.get("source_id", "")).is_empty() or String(authority.get("source_sha256", "")).length() != 64:
		error = "AUTHORITY"; return false
	for value in parsed.get("factory_slots", []):
		if not value is Dictionary: error = "SLOT"; return false
		var slot: Dictionary = value; var id := String(slot.get("factory_slot_id", "")); var profile_id := String(slot.get("profile_id", ""))
		if id.is_empty() or _slots.has(id) or _catalog.profile(profile_id).is_empty(): error = "SLOT:%s" % id; return false
		_slots[id] = slot.duplicate(true)
	_factory = parsed
	return not _slots.is_empty()

func new_session(request: Dictionary) -> Dictionary:
	if _factory.is_empty(): return _result("NOT_READY", {"error": error})
	var session_id := String(request.get("session_id", "")); var session_generation := int(request.get("session_generation", 0))
	var session_clock := int(request.get("session_source_clock", 0)); var roster_clock := int(request.get("roster_source_clock", 0))
	var slot_id := String(request.get("factory_slot_id", "")); var parking_id := String(request.get("parking_id", ""))
	var origin_data: Variant = request.get("origin_m", {"x": 0.0, "y": 0.0, "z": 0.0})
	if not _finite_vector(origin_data): return _result("ORIGIN")
	var origin: Dictionary = origin_data; var source_position: Dictionary
	if not _valid_id(session_id) or session_generation < 1 or session_clock < 1 or roster_clock <= session_clock: return _result("INVALID_SESSION")
	if not _slots.has(slot_id): return _result("FACTORY_SLOT")
	var parking: Dictionary = _catalog.parking_bay(parking_id)
	if parking.is_empty(): return _result("PARKING")
	source_position = parking.position_m
	var local_position := {"x": float(source_position.x) - float(origin.x), "y": float(source_position.y) - float(origin.y), "z": float(source_position.z) - float(origin.z)}
	var request_key := JSON.stringify([session_id, session_generation, session_clock, roster_clock, slot_id, parking_id, [float(origin.x), float(origin.y), float(origin.z)]])
	var session_key := "%s@%d" % [session_id, session_generation]
	if _issued.has(session_key):
		var previous: Dictionary = _issued[session_key]
		return _result("DUPLICATE", {"packet": previous.packet.duplicate(true)}) if previous.request_key == request_key else _result("ALREADY_ISSUED")
	var slot: Dictionary = _slots[slot_id]; var authority: Dictionary = _factory.authority
	var vehicle := {
		"vehicle_id": "local_vehicle_1", "life_generation": 1, "profile_id": slot.profile_id,
		"active": true, "position_m": local_position, "yaw_rad": parking.yaw_rad,
		"source_clock": roster_clock, "parking_id": parking_id, "seats": {},
		"birth": {"kind": "SOURCE_NEW_SESSION_FACTORY", "source_id": authority.source_id, "source_sha256": authority.source_sha256, "parking_id": parking_id, "factory_slot_id": slot_id, "source_model_id": slot.source_model_id, "source_world_position_m": source_position.duplicate(true), "origin_m": origin.duplicate(true)},
	}
	var provenance := {"kind": authority.kind, "source_id": authority.source_id, "source_sha256": authority.source_sha256, "factory_slot_id": slot_id, "parking_id": parking_id, "origin_m": origin.duplicate(true), "position_frame": "godot_local=source_world-origin_m"}
	var session := {"session_id": session_id, "session_generation": session_generation, "mode": "NEW_SESSION_BOOTSTRAP", "source_clock": session_clock, "provenance": provenance}
	var roster := {"session_id": session_id, "session_generation": session_generation, "source_clock": roster_clock, "roster_revision": 1, "actors": [], "vehicles": [vehicle]}
	var packet := {"schema": "mafiozi.transport.bootstrap.v1", "session": session, "roster": roster,
		"physics_births": [{"vehicle_record": vehicle.duplicate(true), "profile_descriptor": _catalog.profile(slot.profile_id)}]}
	_issued[session_key] = {"request_key": request_key, "packet": packet.duplicate(true)}
	return _result("OK", {"packet": packet})

func import_existing(session: Dictionary, roster: Dictionary) -> Dictionary:
	if session.get("mode", "") != "IMPORTED_EXISTING": return _result("MODE")
	if not _valid_id(String(session.get("session_id", ""))) or int(session.get("session_generation", 0)) < 1: return _result("INVALID_SESSION")
	if roster.get("session_id", "") != session.get("session_id", "") or int(roster.get("session_generation", 0)) != int(session.get("session_generation", 0)): return _result("SESSION_MISMATCH")
	if int(roster.get("source_clock", 0)) <= int(session.get("source_clock", 0)): return _result("STALE_CLOCK")
	return _result("OK", {"packet": {"schema": "mafiozi.transport.import.v1", "session": session.duplicate(true), "roster": roster.duplicate(true), "physics_births": []}})

func factory_slots() -> Array:
	return _slots.values().map(func(value: Dictionary) -> Dictionary: return value.duplicate(true))

func _valid_id(value: String) -> bool:
	return not value.is_empty() and value.length() <= 128 and value.strip_edges() == value and not " " in value

func _finite_vector(value: Variant) -> bool:
	if not value is Dictionary: return false
	for axis in ["x", "y", "z"]:
		var number: Variant = value.get(axis)
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

func _result(code: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"code": code}; result.merge(extra); return result
