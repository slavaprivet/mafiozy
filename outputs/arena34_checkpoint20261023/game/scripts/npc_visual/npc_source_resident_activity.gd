extends RefCounted
## Pure original agenda prefix. Caller owns admitted mutable logic, effects and
## current leases. This component never selects a destination or spawns/moves NPCs.
const WORLD_SHA := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const AGENDA_SHA := "acf8a3a5a83bd85203cd47fcccfe9460592c45eb775dfefae95dd8ec1de3ef5c"
const COHORT_SHA := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const SESSION := "godot-preview-new-session-20260927-01"
const SOURCE_IDS := ["resident_72", "resident_169", "resident_252"]
const KINDS := ["shop", "walk", "bench", "walk", "drive", "walk"]
const RESP_FLAGS := ["_stationaryService", "_medicalCrewVehicleId", "_civilianTrip", "_said", "_invulnerable", "_guard", "_cashier", "_empireCrew", "_policeCriminal", "_clientOfBiz", "_botCorpse", "_transientCorpseId"]
const INTERRUPT_FLAGS := ["dead", "_medicalDowned", "_forcedCrawl", "_policeCuffed", "_evacuated", "_carriedByAmbulance", "_hostile", "_fighting", "_fightingMelee", "snitching", "_playerConversationOpen", "_vehicleHijackControlled", "_corpsePhoneCall", "_hijackReaction"]
const TIME_FLAGS := ["panicUntil", "_knockedUntil", "_meleeStunnedUntil", "_npcSurrenderUntil", "_npcHelpingUntil", "_alertUntil", "_playerConversationUntil", "_talking"]
const BASE_FLAGS := ["_npcInitialPlacementPending", "_uniqueNpc", "_said", "_invulnerable", "_empireBoss", "_empireCrew", "_gang", "gang", "police", "isPolice", "_guard", "_cashier", "_clientOfBiz", "_medicalCrewVehicleId", "_policeCriminal", "_botCorpse", "_transientCorpseId", "_beach"]

static func _truth(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return value != 0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true # JS empty object/array are truthy.

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _finite(value) and value >= 0 and value <= 9007199254740991.0 and floor(float(value)) == float(value)

static func _json(value: Variant, depth: int = 0) -> bool:
	if depth > 16: return false
	if value == null or value is bool: return true
	if value is String: return value.length() <= 4096
	if value is int or value is float: return _finite(value)
	if value is Array:
		if value.size() > 4096: return false
		for item: Variant in value:
			if not _json(item, depth + 1): return false
		return true
	if value is Dictionary:
		if value.size() > 256: return false
		for key: Variant in value:
			if not key is String or not _json(value[key], depth + 1): return false
		return true
	return false

static func initial_agenda(source_id: String) -> Dictionary:
	# JS for-of iterates codepoints, charCodeAt(0) uses the leading UTF16 unit.
	var h: int = 2166136261
	for i in source_id.length():
		var code: int = source_id.unicode_at(i)
		if code > 65535: code = 55296 + ((code - 65536) >> 10)
		h = ((h ^ code) * 16777619) & 0xffffffff
	var queue: Array = []
	for i in KINDS.size(): queue.append(KINDS[(h % KINDS.size() + i) % KINDS.size()])
	return {"queue":queue, "index":0, "current":queue[0], "started":false, "completed":0, "lastResult":null}

static func _agenda_valid(value: Variant, source_id: String) -> bool:
	if not value is Dictionary: return false
	if not value.get("queue") is Array or not value.get("current") is String: return false
	if value.get("queue") != initial_agenda(source_id).queue: return false
	if not _integer(value.get("index")) or value.index >= 6 or value.get("current") != value.queue[int(value.index)]: return false
	if not value.get("started") is bool or not _integer(value.get("completed")): return false
	var last: Variant = value.get("lastResult")
	return value.has("lastResult") and (last == null or last is Dictionary and last.get("kind") in KINDS and last.get("reason") is String)

static func _guard(state: Dictionary, now: float, trust: Dictionary) -> String:
	if not _json(state) or not is_finite(now) or now < 0: return "state_or_clock_shape"
	for key: String in ["world_sha256", "agenda_sha256", "cohort_sha256", "session_id", "source_id", "decision_site"]:
		if trust.has(key) and not trust[key] is String: return "trust_shape:" + key
	if not trust.get("known") is bool or trust.known != true or not trust.get("state_complete") is bool or trust.state_complete != true: return "current_source_snapshot_required"
	if trust.get("world_sha256") != WORLD_SHA or trust.get("agenda_sha256") != AGENDA_SHA or trust.get("cohort_sha256") != COHORT_SHA or trust.get("session_id") != SESSION: return "source_binding"
	if not state.get("id") is String or state.id not in SOURCE_IDS or trust.get("source_id") != state.id: return "source_identity"
	for key: String in ["life_generation", "expected_life_generation", "state_revision", "expected_state_revision"]:
		if not trust.get(key) is int or trust[key] < 0: return "generation_shape"
	if trust.life_generation < 1 or trust.life_generation != trust.expected_life_generation or trust.state_revision != trust.expected_state_revision: return "stale_generation_or_revision"
	if not _finite(trust.get("source_now_ms")) or trust.source_now_ms != now: return "source_clock_binding"
	for key: String in ["placement_admitted", "native_navigation_present", "renderer_active"]:
		if not trust.get(key) is bool: return "permission_unknown:" + key
	for key: String in TIME_FLAGS:
		if state.has(key) and state[key] != null and not _finite(state[key]): return "unsupported_timer:" + key
	for key: String in ["_arcKey", "_routeKind", "_routeSearchKind"]:
		if state.get(key) != null and not state[key] is String: return "unsupported_kind:" + key
	if _truth(state.get("_npcAgenda")) and not _agenda_valid(state._npcAgenda, state.id): return "agenda_shape"
	if state.get("_civilianPlan") != null and not state._civilianPlan is Dictionary: return "plan_shape"
	if state.get("_route") != null and not state._route is Array: return "route_shape"
	return ""

static func _unknown(reason: String) -> Dictionary:
	return {"known":false,"status":"UNKNOWN","reason":reason,"patch":{},"source_decision":null,"request_walk_ready":false,"physical_admission":false,"rng_draws":0}

static func _some(state: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if _truth(state.get(key)): return true
	return false

static func _later(state: Dictionary, key: String, now: float) -> bool:
	var value: Variant = state.get(key)
	return value != null and _finite(value) and value > now

static func _interrupted(state: Dictionary, now: float) -> bool:
	if _some(state, INTERRUPT_FLAGS): return true
	if state.get("alive") is bool and not state.alive: return true
	if _finite(state.get("hp")) and state.hp <= 0: return true
	for key: String in TIME_FLAGS:
		if key != "_talking" and _later(state, key, now): return true
	return _later(state, "_talking", now) and not _truth(state.get("_civilianActivity"))

static func _base(state: Dictionary, now: float, trust: Dictionary) -> bool:
	return trust.native_navigation_present and trust.renderer_active and not _interrupted(state, now) and not _some(state, BASE_FLAGS) and state.get("_arcKey") != "bandit" and (_truth(state.get("_civilianTrip")) or not _some(state, RESP_FLAGS))

static func _plan_eligible(state: Dictionary) -> bool:
	return not _some(state, ["_civilianActivity", "_corpsePhoneCall", "_hijackReaction", "_residentNativeVisit", "_ambientTrafficDriver", "_npcInitialPlacementPending", "_said", "_invulnerable", "_guard", "_cashier", "_policeCriminal", "_botCorpse", "_transientCorpseId", "_beach", "_empireBoss", "_empireCrew", "_gang"]) and state.id.begins_with("resident_") and not _some(state, RESP_FLAGS) and state.get("_arcKey") != "bandit"

static func _ensure(state: Dictionary) -> Dictionary:
	if not _truth(state.get("_npcAgenda")): state._npcAgenda = initial_agenda(state.id)
	return state._npcAgenda

static func _adopt(state: Dictionary, kind: String) -> void:
	var a := _ensure(state)
	if a.current != kind: a.index = a.queue.find(kind); a.current = kind
	a.started = true

static func _finish(before: Dictionary, state: Dictionary, decision: Variant, status: String, trust: Dictionary, effect: Dictionary = {}) -> Dictionary:
	var patch: Dictionary = {}
	for key: String in ["_npcAgenda", "_civilianPlan"]:
		if state.has(key) and (not before.has(key) or before[key] != state[key]): patch[key] = state[key].duplicate(true) if state[key] is Dictionary else state[key]
	return {"known":status != "OWNER_REQUIRED", "status":status, "patch":patch, "source_decision":decision, "effect":effect,
		"source_id":state.id, "session_id":trust.session_id, "life_generation":trust.life_generation, "state_revision":trust.state_revision,
		"request_walk_ready":false, "physical_admission":false, "rng_draws":0}

static func _owner(before: Dictionary, state: Dictionary, kind: String, function_name: String, trust: Dictionary) -> Dictionary:
	return _finish(before, state, null, "OWNER_REQUIRED", trust, {"kind":kind,"availability":"UNKNOWN", "frontier":kind.to_upper() + "_OWNER_REQUIRED", "source_function":function_name, "retained_search":_truth(state.get("_routeSearchPending"))})

static func _decision(before: Dictionary, state: Dictionary, decision: Variant, trust: Dictionary) -> Dictionary:
	var effect: Dictionary = {}
	if decision is String and decision == "walk": effect = {"kind":"wander", "availability":"UNKNOWN", "frontier":"WANDER_OWNER_REQUIRED", "source_function":"pickNpcWaypoint retained native wander", "full_reservation_roster_required":true}
	return _finish(before, state, decision, "PENDING" if decision is String and decision == "pending" else "SOURCE_DECISION", trust, effect)

static func pick(state: Dictionary, now_ms: float, trust: Dictionary) -> Dictionary:
	var error := _guard(state, now_ms, trust)
	if not error.is_empty(): return _unknown(error)
	if not _base(state, now_ms, trust): return _decision(state, state, null, trust)
	if not trust.placement_admitted: return _unknown("placement_admission_required")
	if trust.get("decision_site") != "PICK_AFTER_SOURCE_ROAD_EGRESS_NULL": return _unknown("road_egress_or_calm_owner_not_proven")
	var work := state.duplicate(true)
	if _some(work, ["_civilianTrip", "_civilianTripRiding", "_ambientTrafficDriver"]): _adopt(work, "drive"); return _decision(state, work, "ready", trust)
	if _some(work, ["_residentNativeVisit", "_residentIndoors"]):
		if not _truth(work.get("_residentRespawn")): _adopt(work, "shop")
		return _decision(state, work, "ready", trust)
	if _truth(work.get("_civilianSeat")): _adopt(work, "bench"); return _decision(state, work, "ready", trust)
	if _truth(work.get("_civilianActivity")): return _decision(state, work, "ready", trust)
	var plan: Dictionary = work.get("_civilianPlan", {}) if work.get("_civilianPlan") != null else {}
	var has_route: bool = work.get("_route") is Array and not work._route.is_empty()
	if _truth(plan.get("tripDestination")):
		_adopt(work, "shop")
		if work.get("_routeKind") == "building_entry" and has_route: return _decision(state, work, "ready", trust)
		return _owner(state, work, "shop", "_maybePlanResidentBuildingVisit", trust)
	if _truth(work.get("_routeSearchPending")):
		var kind: String = "shop" if work.get("_routeSearchKind") == "building_entry" else "bench" if work.get("_routeSearchKind") == "civilian_bench" else ""
		if not kind.is_empty():
			_adopt(work, kind)
			return _owner(state, work, kind, "_maybePlanResidentBuildingVisit" if kind == "shop" else "_civilianPlanNext", trust)
		return _decision(state, work, "pending", trust)
	if _truth(work.get("_npcWanderSearch")): return _decision(state, work, "walk", trust)
	if not _plan_eligible(work): return _decision(state, work, null, trust)
	var agenda := _ensure(work)
	if not agenda.started and has_route and work.get("_routeKind") in ["walk", "building_entry", "civilian_bench"]:
		var kind: String = "walk" if work._routeKind == "walk" else "shop" if work._routeKind == "building_entry" else "bench"
		_adopt(work, kind)
		return _decision(state, work, "walk" if kind == "walk" else "ready", trust)
	var kind: String = agenda.current
	if kind == "walk": agenda.started = true; return _decision(state, work, "walk", trust)
	if not agenda.started:
		agenda.started = true
		if kind == "shop" or kind == "bench":
			plan = plan.duplicate(true)
			plan.merge({"phase":"seek_shop" if kind == "shop" else "walk_to_bench", "cycle":plan.get("cycle") if _truth(plan.get("cycle")) else 0, "retryAt":0, "since":now_ms, "doorId":null, "benchId":null, "tripDestination":false}, true)
			work._civilianPlan = plan
	return _owner(state, work, kind, "_maybePlanResidentBuildingVisit" if kind == "shop" else "_civilianPlanNext" if kind == "bench" else "_npcAgendaTryDrive", trust)

static func complete(state: Dictionary, kind: String, reason: String, now_ms: float, trust: Dictionary) -> Dictionary:
	var error := _guard(state, now_ms, trust)
	if not error.is_empty(): return _unknown(error)
	var ticket: Variant = trust.get("authority_ticket")
	if ticket is Dictionary:
		for key: String in ["issuer", "kind", "reason"]:
			if not ticket.get(key) is String: return _unknown("completion_ticket_shape")
	if not ticket is Dictionary or not ticket.get("accepted") is bool or ticket.accepted != true or ticket.get("issuer") != "SOURCE_ACTIVITY_OWNER" or not ticket.get("ticket_id") is String or ticket.ticket_id.is_empty(): return _unknown("completion_authority_required")
	for key: String in ["session_id", "source_id", "life_generation", "state_revision"]:
		if not ticket.has(key) or typeof(ticket[key]) != typeof(trust[key]) or ticket[key] != trust[key]: return _unknown("stale_completion_ticket")
	if ticket.get("kind") != kind or ticket.get("reason") != reason or reason.length() > 128: return _unknown("completion_action_binding")
	if not _truth(state.get("_npcAgenda")) or state._npcAgenda.current != kind: return _decision(state, state, false, trust)
	var work := state.duplicate(true)
	var a: Dictionary = work._npcAgenda
	a.lastResult = {"kind":kind, "reason":reason}; a.completed += 1; a.index = (int(a.index) + 1) % a.queue.size(); a.current = a.queue[int(a.index)]; a.started = false
	return _decision(state, work, true, trust)
