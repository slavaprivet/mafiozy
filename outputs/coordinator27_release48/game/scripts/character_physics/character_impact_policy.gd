extends RefCounted
## Pure single-target reaction proposal. The caller owns event validation,
## occlusion, damage, lifecycle, rig selection and the one physical impulse write.
const HISTORY_CAPACITY := 64
const MAX_ID_LENGTH := 256
const MAX_WORLD_COORDINATE_M := 10000000.0
const MAX_IMPULSE_NS := 100000000.0
const STANCES := ["standing", "crouched", "prone", "airborne", "seated"]
const KINDS := ["bullet", "blast", "contact", "fall", "melee"]
const EVENT_FIELDS := ["actor_id", "life_generation", "session_id", "event_id", "kind", "world_point", "impulse_ns", "stance", "authoritative_knockdown", "dead"]
var _actor_id := ""
var _generation := 0
var _session_id := ""
var _mass_kg := 0.0
var _max_impulse_ns := 0.0
var _thresholds := {}
var _seen := {}
var _ring := PackedStringArray()
var _cursor := 0
var _binding_revision := 0
var _disposed := false

static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= MAX_ID_LENGTH

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _world_point(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and absf(value.x) <= MAX_WORLD_COORDINATE_M and absf(value.y) <= MAX_WORLD_COORDINATE_M and absf(value.z) <= MAX_WORLD_COORDINATE_M

static func _profile(profile: Dictionary) -> Dictionary:
	if profile.size() != 3 or not _number(profile.get("mass_kg"), .01, 1000000.0) or not _number(profile.get("max_impulse_ns"), .000001, MAX_IMPULSE_NS): return {}
	var thresholds: Variant = profile.get("stance_thresholds_mps")
	if not thresholds is Dictionary or thresholds.is_empty() or thresholds.size() > STANCES.size(): return {}
	for stance: Variant in thresholds:
		if not stance is String or stance not in STANCES or not _number(thresholds[stance], .000001, 1000000.0): return {}
	return {"mass_kg": float(profile.mass_kg), "max_impulse_ns": float(profile.max_impulse_ns), "stance_thresholds_mps": thresholds.duplicate()}

func configure(actor_id: String, life_generation: int, session_id: String, profile: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _binding_revision != 0: return {"ok": false, "error": "lifetime"}
	return _bind(actor_id, life_generation, session_id, profile)

func reset_life(actor_id: String, life_generation: int, session_id: String, profile: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _binding_revision == 0: return {"ok": false, "error": "lifetime"}
	# Only the owning host calls reset; an event cannot reset its target binding.
	# Same-session actor replacement requires a new adapter, never an ID alias.
	if session_id == _session_id and (actor_id != _actor_id or life_generation <= _generation): return {"ok": false, "error": "not_new_life"}
	return _bind(actor_id, life_generation, session_id, profile)

func _bind(actor_id: String, life_generation: int, session_id: String, profile: Dictionary) -> Dictionary:
	if not _text(actor_id) or not _text(session_id) or life_generation < 1 or life_generation > 2147483647: return {"ok": false, "error": "target_identity"}
	var checked := _profile(profile)
	if checked.is_empty(): return {"ok": false, "error": "profile"}
	_actor_id = actor_id; _generation = life_generation; _session_id = session_id
	_mass_kg = checked.mass_kg; _max_impulse_ns = checked.max_impulse_ns; _thresholds = checked.stance_thresholds_mps
	_seen.clear(); _ring.resize(HISTORY_CAPACITY); _ring.fill(""); _cursor = 0
	_binding_revision += 1
	return {"ok": true, "binding_revision": _binding_revision}

func consume(event: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _binding_revision == 0: return {"ok": false, "error": "lifetime"}
	if event.size() < 8 or event.size() > EVENT_FIELDS.size(): return {"ok": false, "error": "event_schema"}
	for key: Variant in event:
		# Native Dictionary dot writes add StringName keys; JSON uses String.
		if not (key is String or key is StringName) or str(key) not in EVENT_FIELDS: return {"ok": false, "error": "event_schema"}
	if not event.get("actor_id") is String or not event.get("session_id") is String or not event.get("life_generation") is int or event.actor_id != _actor_id or event.session_id != _session_id or event.life_generation != _generation: return {"ok": false, "error": "stale_target"}
	if not _text(event.get("event_id")): return {"ok": false, "error": "event_identity"}
	if _seen.has(event.event_id): return {"ok": false, "error": "duplicate_event"}
	if not event.get("kind") is String or event.kind not in KINDS: return {"ok": false, "error": "kind"}
	if not event.get("stance") is String or not _thresholds.has(event.stance): return {"ok": false, "error": "stance"}
	if not _world_point(event.get("world_point")): return {"ok": false, "error": "world_point"}
	if not event.get("impulse_ns") is Vector3 or not event.impulse_ns.is_finite(): return {"ok": false, "error": "impulse"}
	# Component precheck prevents length overflow before the configured bound.
	var impulse: Vector3 = event.impulse_ns
	if absf(impulse.x) > _max_impulse_ns or absf(impulse.y) > _max_impulse_ns or absf(impulse.z) > _max_impulse_ns: return {"ok": false, "error": "excess_impulse"}
	var magnitude: float = sqrt(float(impulse.x) * impulse.x + float(impulse.y) * impulse.y + float(impulse.z) * impulse.z)
	if magnitude > _max_impulse_ns: return {"ok": false, "error": "excess_impulse"}
	for field: String in ["authoritative_knockdown", "dead"]:
		if event.has(field) and not event[field] is bool: return {"ok": false, "error": "authority_flag"}
	var explicit_knockdown: bool = event.get("authoritative_knockdown", false)
	var dead: bool = event.get("dead", false)
	var delta_v_mps := magnitude / _mass_kg
	var threshold: float = _thresholds[event.stance]
	var reaction := "none"
	var reason := "zero_impulse"
	if dead or explicit_knockdown:
		reaction = "knockdown"; reason = "authoritative_dead" if dead else "authoritative_knockdown"
	elif delta_v_mps >= threshold:
		reaction = "knockdown"; reason = "impulse_threshold"
	elif magnitude > 0:
		reaction = "local"; reason = "localized_impulse"
	# Accepted zero impulses are also remembered: replay cannot turn a blocked
	# blast into a later positive hit. Invalid input never poisons this window.
	if not _ring[_cursor].is_empty(): _seen.erase(_ring[_cursor])
	_ring[_cursor] = event.event_id; _seen[event.event_id] = true
	_cursor = (_cursor + 1) % HISTORY_CAPACITY
	return {"ok": true, "reaction": reaction, "reason": reason,
		"request_physical_knockdown": reaction == "knockdown", "proposal_only": true,
		"actor_id": _actor_id, "life_generation": _generation, "session_id": _session_id,
		"binding_revision": _binding_revision, "event_id": event.event_id, "kind": event.kind,
		"stance": event.stance, "world_point": event.world_point, "impulse_ns": impulse,
		"delta_velocity_mps": impulse / _mass_kg, "delta_speed_mps": delta_v_mps,
		"mass_kg": _mass_kg, "threshold_mps": threshold,
		"authoritative_knockdown": explicit_knockdown, "dead": dead}

func state() -> Dictionary:
	if not Thread.is_main_thread(): return {"error": "thread"}
	return {"actor_id": _actor_id, "life_generation": _generation, "session_id": _session_id,
		"binding_revision": _binding_revision, "remembered_events": _seen.size(),
		"capacity": HISTORY_CAPACITY, "disposed": _disposed}

func dispose() -> void:
	if not Thread.is_main_thread() or _disposed: return
	_disposed = true; _seen.clear(); _ring.clear(); _thresholds.clear()
