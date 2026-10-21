extends RefCounted
## Planning registry only. Caller owns source eligibility/access before reserve.
## Entries never grant a seat, driver control, route or network authority.
const LIMIT := 16
var _session := ""
var _generation := 0
var _incarnation := 0
var _trips: Dictionary = {}
var _actors: Dictionary = {}
var _vehicles: Dictionary = {}

func begin_session(id: String, generation: int) -> bool:
	if id.is_empty() or generation < 1: return false
	if id == _session and generation < _generation: return false
	if id == _session and generation == _generation: return true
	clear()
	_session = id
	_generation = generation
	return true

func reserve(session_id: String, session_generation: int, token: String, actor: Dictionary, vehicle: Dictionary) -> String:
	if _session.is_empty() or session_id != _session or session_generation != _generation: return "STALE_SESSION"
	var ak := _key(actor, "actor_id")
	var vk := _key(vehicle, "vehicle_id")
	if token.is_empty() or ak.is_empty() or vk.is_empty(): return "INVALID_REFERENCE"
	if _trips.has(token):
		return "RESERVED" if _trips[token].actor_key == ak and _trips[token].vehicle_key == vk else "TOKEN_CONFLICT"
	if _actors.has(ak): return "ACTOR_CONFLICT"
	if _vehicles.has(vk): return "VEHICLE_CONFLICT"
	if _trips.size() >= LIMIT: return "LIMIT"
	_incarnation += 1
	_trips[token] = {"incarnation": _incarnation, "actor_key": ak, "vehicle_key": vk, "actor": actor.duplicate(true), "vehicle": vehicle.duplicate(true), "phase": "planning"}
	_actors[ak] = token
	_vehicles[vk] = token
	return "RESERVED"

func release(token: String, incarnation: int) -> bool:
	if not _trips.has(token) or _trips[token].incarnation != incarnation: return false
	var trip: Dictionary = _trips[token]
	if _actors.get(trip.actor_key) == token: _actors.erase(trip.actor_key)
	if _vehicles.get(trip.vehicle_key) == token: _vehicles.erase(trip.vehicle_key)
	_trips.erase(token)
	return true

func trip(token: String) -> Dictionary:
	return _trips.get(token, {}).duplicate(true)

func count() -> int:
	return _trips.size()

## Only call with complete current same-session admitted roster, not a crop.
## Interrupted/dead owners must already be excluded by their actual owner.
func reconcile(session_id: String, session_generation: int, actors: Array, vehicles: Array) -> Array[String]:
	var removed: Array[String] = []
	if session_id != _session or session_generation != _generation: return removed
	var live_a: Dictionary = {}
	var live_v: Dictionary = {}
	for ref in actors:
		var key := _key(ref, "actor_id")
		if not key.is_empty(): live_a[key] = true
	for ref in vehicles:
		var key := _key(ref, "vehicle_id")
		if not key.is_empty(): live_v[key] = true
	for token in _trips.keys():
		var row: Dictionary = _trips[token]
		if not live_a.has(row.actor_key) or not live_v.has(row.vehicle_key):
			release(token, row.incarnation)
			removed.append(token)
	return removed

func clear() -> void:
	_trips.clear()
	_actors.clear()
	_vehicles.clear()
	_session = ""
	_generation = 0

func _key(ref: Variant, field: String) -> String:
	if not ref is Dictionary: return ""
	var id: Variant = ref.get(field)
	var life: Variant = ref.get("life_generation")
	if not id is String or id.is_empty() or not life is int or life < 1: return ""
	# JSON encoding prevents delimiters in source IDs from aliasing another life.
	return JSON.stringify([id, life])

