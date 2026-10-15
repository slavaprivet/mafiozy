extends RefCounted
## Pure bounded admission ledger. No nodes, movement, money or medical authority.
## One life key owns at most one request/lease. FIFO among compatible candidates.
const MAX_REQUESTS := 512
const MAX_CANDIDATES := 16
const WAIT_MS := 120000
const OFFER_MS := 15000
var venues: Dictionary = {}
var requests: Dictionary = {}
var _portals: Dictionary = {}
var _sequence := 0
var _next_prune := 0

func register(venue: String, kind: String, capacity: int) -> void:
	if venue.is_empty() or capacity <= 0: return
	if venues.has(venue): return # Existing live leases must never be resized away.
	venues[venue] = {"kind":kind,"capacity":clampi(capacity, 1, 32),"slots":{},"concurrent_portal31":false}

func unregister(venue: String, now: int) -> void:
	if not venues.has(venue): return
	venues.erase(venue)
	_portals.erase(venue)
	for key: Variant in requests.keys():
		var row: Dictionary = requests[key]
		if str(row.get("venue", "")) == venue:
			requests.erase(key) # Lost building never means exited/completed.
	_promote(now)

func request(key: String, kind: String, candidates: Array, now: int) -> Dictionary:
	maintain(now)
	if requests.has(key):
		if str(requests[key].kind) != kind: return {"state":"rejected","reason":"other_service_owned"}
		return poll(key, now)
	if key.is_empty() or requests.size() >= MAX_REQUESTS: return {"state":"rejected","reason":"request_bound"}
	var eligible: Array = []
	var seen: Dictionary = {}
	for item: Variant in candidates:
		if not item is Dictionary: continue
		var venue: String = str(item.get("venue", ""))
		var cost: float = float(item.get("cost", INF))
		if seen.has(venue) or not venues.has(venue) or venues[venue].kind != kind or not is_finite(cost) or cost < 0.0: continue
		seen[venue] = true; eligible.append({"venue":venue,"cost":cost})
		if eligible.size() >= MAX_CANDIDATES: break
	if eligible.is_empty(): return {"state":"rejected","reason":"no_eligible_signed_venue"}
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
	_sequence += 1
	requests[key] = {"state":"waiting","kind":kind,"sequence":_sequence,"candidates":eligible,"queued":now,"deadline":now + WAIT_MS,"venue":"","slot":-1,"confirmed":false,"inside":false,"heartbeat":now}
	_promote(now)
	return poll(key, now)

func _promote(now: int) -> void:
	# Dictionary insertion order is enqueue order, never poll order. A blocked old
	# request does not stall a different building; it wins the first shared slot.
	for key: Variant in requests:
		var row: Dictionary = requests[key]
		if row.state != "waiting" or now >= int(row.deadline): continue
		for item: Dictionary in row.candidates:
			var venue: String = str(item.venue)
			if not venues.has(venue): continue
			var site: Dictionary = venues[venue]
			for slot: int in range(int(site.capacity)):
				if site.slots.has(slot): continue
				site.slots[slot] = key
				row.state = "reserved"; row.venue = venue; row.slot = slot
				row.offer_deadline = now + OFFER_MS; row.heartbeat = now
				break
			if row.state == "reserved": break

func poll(key: String, now: int) -> Dictionary:
	maintain(now)
	if not requests.has(key): return {"state":"lost","reason":"request_retired"}
	var row: Dictionary = requests[key]
	return {"state":row.state,"kind":row.kind,"sequence":row.sequence,"venue":row.venue,"slot":row.slot,"inside":row.inside,"wait_ms":maxi(0, now - int(row.queued))}

func touch(key: String, now: int, inside: bool = false) -> bool:
	if not requests.has(key) or requests[key].state != "reserved": return false
	var row: Dictionary = requests[key]
	row.confirmed = true; row.heartbeat = now; row.inside = bool(row.inside) or inside
	return true

func release(key: String, now: int, _reason: String = "cancel") -> void:
	if not requests.has(key): return
	var row: Dictionary = requests[key]
	var venue: String = str(row.venue)
	portal_release(key, venue)
	if venues.has(venue) and venues[venue].slots.get(row.slot) == key: venues[venue].slots.erase(row.slot)
	requests.erase(key)
	_promote(now)

func set_concurrent_portal31(venue: String, supported: bool) -> void:
	if venues.has(venue): venues[venue].concurrent_portal31 = supported

func portal_owner31(key: String, venue: String) -> bool:
	if not venues.has(venue) or not requests.has(key) or requests[key].state != "reserved" or str(requests[key].venue) != venue: return false
	var queue: Array = _portals.get(venue, [])
	return queue.has(key) if bool(venues[venue].concurrent_portal31) else (not queue.is_empty() and str(queue[0]) == key)

func portal_request(key: String, venue: String) -> bool:
	if not venues.has(venue) or not requests.has(key) or requests[key].state != "reserved" or str(requests[key].venue) != venue: return false
	if not _portals.has(venue): _portals[venue] = []
	var queue: Array = _portals[venue]
	if not queue.has(key): queue.append(key)
	return portal_owner31(key, venue)

func portal_release(key: String, venue: String) -> void:
	if not _portals.has(venue): return
	var queue: Array = _portals[venue]
	queue.erase(key)
	if queue.is_empty(): _portals.erase(venue)

func maintain(now: int) -> void:
	if now < _next_prune: return
	_next_prune = now + 1000
	var expired: Array = []
	for key: Variant in requests:
		var row: Dictionary = requests[key]
		if row.state == "waiting" and now >= int(row.deadline): expired.append(key)
		elif row.state == "reserved" and not row.confirmed and now >= int(row.offer_deadline): expired.append(key)
	# Confirmed living occupants are never silently expired: physical exit or an
	# explicit lifecycle cancellation releases them. The registry reaps dead owners.
	for key: Variant in expired: release(str(key), now, "bounded_wait_or_offer")
	_promote(now)

func snapshot() -> Dictionary:
	var sites: Dictionary = {}
	for venue: Variant in venues:
		var row: Dictionary = venues[venue]
		sites[venue] = {"kind":row.kind,"capacity":row.capacity,"occupied_or_enroute":row.slots.size()}
	var waiting := 0
	for row: Dictionary in requests.values():
		if row.state == "waiting": waiting += 1
	return {"sites":sites,"requests":requests.size(),"waiting":waiting,"max_requests":MAX_REQUESTS,"last_sequence":_sequence}
