extends RefCounted

const SESSION_MODES := ["NEW_SESSION_BOOTSTRAP", "IMPORTED_EXISTING"]
const HOLD_DURATION_US := 300000
const MAX_HOLD_GAP_US := 120000
const ACCESS_PROVIDER := "GODOT_PHYSICS_SPACE_V1"

var _catalog: RefCounted
var _session: Dictionary = {}
var _vehicles: Dictionary = {}
var _actors: Dictionary = {}
var _claims: Dictionary = {}
var _actor_claim: Dictionary = {}
var _last_clock := 0
var _roster_revision := 0
var _sequence := 0

func configure(catalog: RefCounted) -> void:
	_catalog = catalog

func begin_session(packet: Dictionary) -> Dictionary:
	var id := String(packet.get("session_id", "")); var mode := String(packet.get("mode", ""))
	var generation := int(packet.get("session_generation", 0)); var clock := int(packet.get("source_clock", 0))
	if id.is_empty() or mode not in SESSION_MODES or generation < 1 or clock < 1: return _result("INVALID_SESSION")
	_session = {"session_id": id, "mode": mode, "session_generation": generation}
	_vehicles.clear(); _actors.clear(); _claims.clear(); _actor_claim.clear()
	_last_clock = clock; _roster_revision = 0; _sequence = 0
	return _result("OK", {"session": _session.duplicate(true)})

func publish_roster(snapshot: Dictionary) -> Dictionary:
	if _session.is_empty(): return _result("NO_SESSION")
	if not _session_matches(snapshot): return _result("SESSION_MISMATCH")
	var clock := int(snapshot.get("source_clock", 0)); var revision := int(snapshot.get("roster_revision", 0))
	if clock <= _last_clock: return _result("STALE_CLOCK")
	if revision <= _roster_revision: return _result("STALE_ROSTER")
	var next_actors: Dictionary = {}; var next_vehicles: Dictionary = {}; var occupied: Dictionary = {}
	for value in snapshot.get("actors", []):
		if not value is Dictionary: return _result("ACTOR_RECORD")
		var actor: Dictionary = value.duplicate(true); var key := _actor_key(actor)
		if key.is_empty() or next_actors.has(key) or not bool(actor.get("active", false)): return _result("ACTOR_IDENTITY")
		next_actors[key] = actor
	for value in snapshot.get("vehicles", []):
		if not value is Dictionary: return _result("VEHICLE_RECORD")
		var vehicle: Dictionary = value.duplicate(true); var key := _vehicle_key(vehicle)
		var profile_id := String(vehicle.get("profile_id", ""))
		if key.is_empty() or next_vehicles.has(key) or not bool(vehicle.get("active", false)) or _catalog.profile(profile_id).is_empty(): return _result("VEHICLE_IDENTITY")
		if not _finite_pose(vehicle): return _result("VEHICLE_POSE")
		var seats: Dictionary = {}; var supplied: Dictionary = vehicle.get("seats", {})
		for descriptor in _catalog.profile(profile_id).get("seats", []):
			var seat_id := String(descriptor.get("id", "")); var occupant: Variant = supplied.get(seat_id)
			if occupant != null:
				if not occupant is Dictionary: return _result("OCCUPANT_REF")
				var actor_key := _actor_key(occupant)
				if not next_actors.has(actor_key) or occupied.has(actor_key): return _result("OCCUPANT_IDENTITY")
				occupied[actor_key] = "%s/%s" % [key, seat_id]
				seats[seat_id] = (occupant as Dictionary).duplicate(true)
			else: seats[seat_id] = null
		for supplied_id in supplied:
			if not seats.has(supplied_id): return _result("UNKNOWN_SEAT")
		vehicle["seats"] = seats; next_vehicles[key] = vehicle
	_actors = next_actors; _vehicles = next_vehicles; _last_clock = clock; _roster_revision = revision
	_reconcile_claims()
	return _result("OK", {"actors": _actors.size(), "vehicles": _vehicles.size(), "roster_revision": revision})

func begin_board(actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, receipt: Dictionary) -> Dictionary:
	var actor_key := _actor_key(actor_ref); var vehicle_key := _vehicle_key(vehicle_ref)
	if not _advance_clock(source_clock): return _result("STALE_CLOCK")
	if not _actors.has(actor_key): return _result("ACTOR")
	if not _vehicles.has(vehicle_key): return _result("VEHICLE")
	if _actor_claim.has(actor_key) or _occupied_seat(actor_key).size() > 0: return _result("ACTOR_BUSY")
	var vehicle: Dictionary = _vehicles[vehicle_key]; var seats: Dictionary = vehicle.seats
	if not seats.has(seat_id): return _result("SEAT")
	if seats[seat_id] != null or _seat_claimed(vehicle_key, seat_id): return _result("OCCUPIED")
	if not _receipt_valid(receipt, "BOARD", actor_ref, vehicle_ref, seat_id, source_clock): return _result("UNSAFE_ACCESS")
	return _create_claim("BOARD", actor_ref, vehicle_ref, seat_id, source_clock)

func begin_exit(actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, source_clock: int, receipt: Dictionary) -> Dictionary:
	var actor_key := _actor_key(actor_ref); var vehicle_key := _vehicle_key(vehicle_ref)
	if not _advance_clock(source_clock): return _result("STALE_CLOCK")
	if not _actors.has(actor_key) or not _vehicles.has(vehicle_key): return _result("IDENTITY")
	if _actor_claim.has(actor_key): return _result("ACTOR_BUSY")
	var seats: Dictionary = _vehicles[vehicle_key].seats
	if not seats.has(seat_id) or not _same_ref(seats[seat_id], actor_ref): return _result("NOT_OCCUPANT")
	if not _receipt_valid(receipt, "EXIT", actor_ref, vehicle_ref, seat_id, source_clock): return _result("UNSAFE_EXIT")
	return _create_claim("EXIT", actor_ref, vehicle_ref, seat_id, source_clock)

func advance_hold(token: String, pressed: bool, source_clock: int, receipt: Dictionary) -> Dictionary:
	if not _advance_clock(source_clock): return _result("STALE_CLOCK")
	if not _claims.has(token): return _result("LEASE")
	var claim: Dictionary = _claims[token]
	if source_clock - int(claim.last_clock) > MAX_HOLD_GAP_US:
		_cancel(token); return _result("CONTINUITY_LOST")
	if not pressed:
		_cancel(token); return _result("RELEASED")
	if not _receipt_valid(receipt, claim.action, claim.actor, claim.vehicle, claim.seat_id, source_clock):
		_cancel(token); return _result("UNSAFE_ACCESS" if claim.action == "BOARD" else "UNSAFE_EXIT")
	claim.last_clock = source_clock; _claims[token] = claim
	var elapsed := source_clock - int(claim.started_clock)
	if elapsed < HOLD_DURATION_US: return _result("HOLDING", {"token": token, "held_us": elapsed, "remaining_us": HOLD_DURATION_US - elapsed})
	return _complete(token)

func cancel(token: String) -> Dictionary:
	if not _claims.has(token): return _result("LEASE")
	_cancel(token); return _result("CANCELLED")

func seat_world_pose(vehicle_ref: Dictionary, seat_id: String) -> Dictionary:
	return _world_anchor(vehicle_ref, seat_id, "anchor_local_m")

func approach_world_pose(vehicle_ref: Dictionary, seat_id: String) -> Dictionary:
	return _world_anchor(vehicle_ref, seat_id, "approach_local_m")

func driver(vehicle_ref: Dictionary) -> Dictionary:
	var vehicle: Dictionary = _vehicles.get(_vehicle_key(vehicle_ref), {})
	var value: Variant = (vehicle.get("seats", {}) as Dictionary).get("front_left")
	return value.duplicate(true) if value is Dictionary else {}

func diagnostics() -> Dictionary:
	return {"session": _session.duplicate(true), "source_clock": _last_clock, "roster_revision": _roster_revision, "actors": _actors.size(), "vehicles": _vehicles.size(), "leases": _claims.size()}

func lease(token: String) -> Dictionary:
	return (_claims.get(token, {}) as Dictionary).duplicate(true)

func _create_claim(action: String, actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, clock: int) -> Dictionary:
	_sequence += 1
	var token := "%s:%d:%d" % [_session.session_id, _session.session_generation, _sequence]
	var claim := {"token": token, "action": action, "actor": actor_ref.duplicate(true), "vehicle": vehicle_ref.duplicate(true), "seat_id": seat_id, "started_clock": clock, "last_clock": clock, "phase": "HOLDING"}
	_claims[token] = claim; _actor_claim[_actor_key(actor_ref)] = token
	return _result("HOLDING", {"token": token, "remaining_us": HOLD_DURATION_US})

func _complete(token: String) -> Dictionary:
	var claim: Dictionary = _claims[token]; var vehicle_key := _vehicle_key(claim.vehicle); var actor_key := _actor_key(claim.actor)
	if not _vehicles.has(vehicle_key) or not _actors.has(actor_key): _cancel(token); return _result("LIFETIME_ENDED")
	var vehicle: Dictionary = _vehicles[vehicle_key]; var seats: Dictionary = vehicle.seats
	if _session.mode == "IMPORTED_EXISTING":
		claim.phase = "AWAITING_SOURCE"; _claims[token] = claim
		return _result("AWAITING_SOURCE", {"token": token, "command": {"command_id": token, "action": claim.action, "actor": claim.actor.duplicate(true), "vehicle": claim.vehicle.duplicate(true), "seat_id": claim.seat_id, "source_clock": _last_clock}})
	if claim.action == "BOARD":
		if seats.get(claim.seat_id) != null: _cancel(token); return _result("OCCUPIED")
		seats[claim.seat_id] = claim.actor.duplicate(true)
	else:
		if not _same_ref(seats.get(claim.seat_id), claim.actor): _cancel(token); return _result("NOT_OCCUPANT")
		seats[claim.seat_id] = null
	vehicle.seats = seats; _vehicles[vehicle_key] = vehicle; _cancel(token)
	return _result("BOARDED" if claim.action == "BOARD" else "EXITED", {"seat_id": claim.seat_id, "vehicle": claim.vehicle.duplicate(true), "actor": claim.actor.duplicate(true)})

func _reconcile_claims() -> void:
	for token in _claims.keys():
		var claim: Dictionary = _claims[token]; var vehicle: Dictionary = _vehicles.get(_vehicle_key(claim.vehicle), {})
		if vehicle.is_empty() or not _actors.has(_actor_key(claim.actor)):
			_cancel(token); continue
		var occupant: Variant = (vehicle.seats as Dictionary).get(claim.seat_id)
		if claim.phase == "AWAITING_SOURCE":
			var confirmed := _same_ref(occupant, claim.actor) if claim.action == "BOARD" else occupant == null
			if confirmed: _cancel(token)
		elif claim.action == "BOARD" and occupant != null:
			_cancel(token)

func _receipt_valid(receipt: Dictionary, action: String, actor_ref: Dictionary, vehicle_ref: Dictionary, seat_id: String, clock: int) -> bool:
	return receipt.get("provider", "") == ACCESS_PROVIDER and receipt.get("action", "") == action and int(receipt.get("source_clock", 0)) == clock \
		and receipt.get("door_id", "") == seat_id and receipt.get("actor_id", "") == actor_ref.get("actor_id", "") and int(receipt.get("actor_generation", 0)) == int(actor_ref.get("life_generation", -1)) \
		and receipt.get("vehicle_id", "") == vehicle_ref.get("vehicle_id", "") and int(receipt.get("vehicle_generation", 0)) == int(vehicle_ref.get("life_generation", -1)) \
		and bool(receipt.get("reachable", false)) and bool(receipt.get("path_clear", false)) and bool(receipt.get("destination_clear", false))

func _world_anchor(vehicle_ref: Dictionary, seat_id: String, field: String) -> Dictionary:
	var vehicle: Dictionary = _vehicles.get(_vehicle_key(vehicle_ref), {})
	if vehicle.is_empty(): return {}
	var descriptor: Dictionary = _catalog.seat(vehicle.profile_id, seat_id)
	if descriptor.is_empty(): return {}
	var local_data: Dictionary = descriptor[field]; var position_data: Dictionary = vehicle.position_m
	var local := Vector3(float(local_data.x), float(local_data.y), float(local_data.z))
	var origin := Vector3(float(position_data.x), float(position_data.y), float(position_data.z))
	var world := origin + Basis(Vector3.UP, float(vehicle.yaw_rad)) * local
	return {"position_m": {"x": world.x, "y": world.y, "z": world.z}, "yaw_rad": float(vehicle.yaw_rad), "seat_id": seat_id, "door_id": descriptor.door_id}

func _occupied_seat(actor_key: String) -> Dictionary:
	for vehicle_key in _vehicles:
		var seats: Dictionary = _vehicles[vehicle_key].seats
		for seat_id in seats:
			if _actor_key(seats[seat_id]) == actor_key: return {"vehicle_key": vehicle_key, "seat_id": seat_id}
	return {}

func _seat_claimed(vehicle_key: String, seat_id: String) -> bool:
	for claim in _claims.values():
		if _vehicle_key(claim.vehicle) == vehicle_key and claim.seat_id == seat_id: return true
	return false

func _cancel(token: String) -> void:
	var claim: Dictionary = _claims.get(token, {})
	if not claim.is_empty(): _actor_claim.erase(_actor_key(claim.actor))
	_claims.erase(token)

func _advance_clock(clock: int) -> bool:
	if clock <= _last_clock: return false
	_last_clock = clock; return true

func _session_matches(packet: Dictionary) -> bool:
	return packet.get("session_id", "") == _session.session_id and int(packet.get("session_generation", 0)) == int(_session.session_generation)

func _actor_key(ref: Variant) -> String:
	if not ref is Dictionary: return ""
	var id := String(ref.get("actor_id", "")); var generation := int(ref.get("life_generation", 0))
	return "%s@%d" % [id, generation] if not id.is_empty() and generation > 0 else ""

func _vehicle_key(ref: Variant) -> String:
	if not ref is Dictionary: return ""
	var id := String(ref.get("vehicle_id", "")); var generation := int(ref.get("life_generation", 0))
	return "%s@%d" % [id, generation] if not id.is_empty() and generation > 0 else ""

func _same_ref(a: Variant, b: Variant) -> bool:
	return not _actor_key(a).is_empty() and _actor_key(a) == _actor_key(b)

func _finite_pose(vehicle: Dictionary) -> bool:
	var p: Variant = vehicle.get("position_m")
	if not p is Dictionary: return false
	return is_finite(float(p.get("x", NAN))) and is_finite(float(p.get("y", NAN))) and is_finite(float(p.get("z", NAN))) and is_finite(float(vehicle.get("yaw_rad", NAN)))

func _result(code: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"code": code}; out.merge(extra); return out
