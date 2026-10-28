extends RefCounted
## Artist14 reaction-state projection of completed source transactions.
## No HP writes, damage, death decisions, physical impulse, Nodes or rig writes.
## The callback is an integration dependency, NOT supplied by static spawn rows.
const RECEIPT_LIMIT := 512
const MAX_RECEIPT_AGE_MS := 15000.0
const IDENTITY_FIELDS := ["session_id", "source_id", "render_id", "life_generation", "rig_epoch"]
const DURATIONS := {"hit": 0.48, "block": 0.30, "fall": 2.7}
var _binding: Dictionary = {}
var _authority := Callable()
var _fault := ""
var _busy := false
var _time := 0.0
var _revision := -1
var _source_state: Dictionary = {}
var _reaction: Dictionary = {"kind": "idle", "at": 0.0, "side": 1, "zone": null}
var _source_death_key: Variant = null
var _source_death_at: Variant = null
var _death_visual_bias := 0.0
var _death_visual_side := 1.0
var _receipts: Dictionary = {}
var _receipt_order: Array[String] = []

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _text(value: Variant, maximum: int = 256) -> bool:
	return value is String and not value.is_empty() and value.length() <= maximum

static func _identity(value: Variant) -> bool:
	return value is int and value >= 0 or _text(value, 128)

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b

static func _point(value: Variant) -> bool:
	return value is Dictionary and _number(value.get("x")) and _number(value.get("y")) and _number(value.get("z"))

static func _ease(value: float, lo: float, hi: float) -> float:
	var t := clampf((value - lo) / (hi - lo), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _fall_age(weight: float) -> float:
	if weight <= 0.0: return 0.0
	if weight >= 1.0: return 0.62
	var lo := 0.03
	var hi := 0.62
	for i in 24:
		var mid := (lo + hi) / 2.0
		if _ease(mid, 0.03, 0.62) < weight: lo = mid
		else: hi = mid
	return (lo + hi) / 2.0

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "known": false, "reason": reason, "presentation_only": true, "damage_authority": false, "physical_impulse": false}

func bind_current(binding: Dictionary, current_authority: Callable) -> Dictionary:
	if not Thread.is_main_thread(): return _failure("thread")
	if _busy: invalidate("reentrant"); return _failure(_fault)
	if not _binding.is_empty() or not _fault.is_empty(): return _failure("already_bound_or_retired")
	if not _text(binding.get("session_id"), 128) or not _text(binding.get("render_id"), 128): return _failure("binding_text")
	for key: String in ["source_id", "life_generation", "rig_epoch"]:
		if not _identity(binding.get(key)): return _failure("binding_identity")
	if not current_authority.is_valid(): return _failure("authority_missing")
	_binding = {}
	for key: String in IDENTITY_FIELDS: _binding[key] = binding[key]
	_authority = current_authority
	return {"ok": true, "presentation_only": true, "damage_authority": false, "physical_impulse": false}

func invalidate(reason: String = "retired") -> void:
	if Thread.is_main_thread() and _fault.is_empty(): _fault = reason if not reason.is_empty() else "retired"

func _owner_valid(owner: Variant) -> bool:
	return _authority.is_valid() and is_instance_valid(owner) and not (owner is Node and owner.is_queued_for_deletion())

func _fetch(mode: String, event_id: String = "") -> Dictionary:
	if _binding.is_empty() or not _fault.is_empty(): return _failure(_fault if not _fault.is_empty() else "unbound")
	if not _authority.is_valid(): invalidate("authority_lost"); return _failure(_fault)
	var owner: Variant = _authority.get_object()
	if not _owner_valid(owner): invalidate("authority_lost"); return _failure(_fault)
	var request := {"mode": mode, "binding": _binding.duplicate(true), "event_id": event_id}
	_busy = true
	var raw: Variant = _authority.call(request)
	_busy = false
	if not _owner_valid(owner) or not _fault.is_empty(): invalidate("authority_lost"); return _failure(_fault)
	if not raw is Dictionary: return _failure("authority_reply")
	var reply: Dictionary = raw.duplicate(true)
	if reply.get("known") != true or not reply.get("known") is bool or reply.get("completed") != true or not reply.get("completed") is bool: return _failure("authority_pending")
	if not reply.get("binding") is Dictionary: return _failure("authority_binding")
	for key: String in IDENTITY_FIELDS:
		if not _same(reply.binding.get(key), _binding[key]): invalidate("authority_binding"); return _failure(_fault)
	if not reply.get("revision") is int or reply.revision < 0 or reply.revision < _revision: return _failure("authority_revision")
	if not _number(reply.get("source_now_ms")): return _failure("authority_clock")
	var life: Variant = reply.get("lifecycle")
	if not life is Dictionary or not life.get("dead") is bool or not life.get("explicitAlive") is bool or not _number(life.get("side")) or (life.side != -1 and life.side != 1): return _failure("lifecycle_shape")
	if life.dead:
		if not _text(life.get("key")) or life.explicitAlive: return _failure("lifecycle_epoch")
	elif life.get("key") != null: return _failure("lifecycle_epoch")
	if life.has("age") and (not _number(life.age) or life.age < 0.0): return _failure("lifecycle_age")
	if life.has("fromDowned") and not life.fromDowned is bool: return _failure("lifecycle_shape")
	if reply.has("hp") and not _number(reply.hp): return _failure("hp_mirror_shape")
	# Same revision cannot describe different completed source state. The source
	# clock can advance independently; age is also a projection of that clock.
	var state := {"dead": life.dead, "explicitAlive": life.explicitAlive, "key": life.get("key"), "side": life.side, "fromDowned": life.get("fromDowned", false), "hp_known": reply.has("hp"), "hp": reply.get("hp")}
	if reply.revision == _revision and state != _source_state: return _failure("authority_revision_content")
	reply["_state"] = state
	reply["ok"] = true
	return reply

func _sync(life: Dictionary, at_time: float) -> void:
	# Source npc_actor.syncSourceLifecycle: sparse/nonfatal snapshots never revive
	# an established corpse; late timestamp hydration never restarts its fall.
	var new_epoch: bool = life.dead and _source_death_key != null and _source_death_key != "dead" and life.key != "dead" and _source_death_key != life.key
	if _source_death_key != null and (life.explicitAlive or new_epoch):
		_reaction = {"kind": "idle", "at": at_time, "side": 1, "zone": null}
		_source_death_key = null
		_source_death_at = null
		_death_visual_bias = 0.0
		_death_visual_side = 1.0
	if not life.dead: return
	var already_dead: bool = _reaction.kind == "dead"
	if not already_dead:
		var old_age: float = maxf(0.0, at_time - _reaction.at)
		var weight: float = _ease(old_age, 0.03, 0.62) * (1.0 - _ease(old_age, 1.55, 2.7)) if _reaction.kind == "fall" else 0.0
		_death_visual_bias = 0.62 if life.get("fromDowned", false) else _fall_age(weight)
		_death_visual_side = float(_reaction.side) if weight > 0.0 else float(life.side)
		_reaction = {"kind": "dead", "at": at_time, "side": life.side, "zone": null}
	if _source_death_at == null:
		_source_death_at = at_time - (float(life.age) if life.has("age") else maxf(0.0, at_time - _reaction.at) if already_dead else 0.0)
	elif life.has("age") and life.age > maxf(0.0, at_time - float(_source_death_at)):
		_source_death_at = at_time - float(life.age)
	_source_death_key = life.key

func _commit_source(reply: Dictionary, at_time: float) -> void:
	_revision = reply.revision
	_source_state = reply._state.duplicate(true)
	_time = at_time
	_sync(reply.lifecycle, at_time)

func _snapshot() -> Dictionary:
	var age: float = maxf(0.0, _time - float(_source_death_at)) if _reaction.kind == "dead" and _source_death_at != null else maxf(0.0, _time - _reaction.at)
	var result := {"ok": true, "known": true, "binding": _binding.duplicate(true), "revision": _revision, "reaction": {"kind": _reaction.kind, "age": age, "at": _reaction.at, "side": _reaction.side, "zone": _reaction.zone}, "death_key": _source_death_key, "hp_known": _source_state.get("hp_known", false), "hp": _source_state.get("hp"), "presentation_only": true, "damage_authority": false, "physical_impulse": false}
	result["presentation_event"] = {"hit": "flinch", "block": "block", "fall": "down", "dead": "final_dead"}.get(_reaction.kind, "idle")
	if _reaction.kind in ["fall", "dead"]:
		var visual_age := age + (_death_visual_bias if _reaction.kind == "dead" else 0.0)
		result["visual"] = {"age": visual_age, "weight": _ease(visual_age, 0.03, 0.62) * (1.0 if _reaction.kind == "dead" else 1.0 - _ease(visual_age, 1.55, 2.7)), "side": _death_visual_side + (float(_reaction.side) - _death_visual_side) * _ease(age, 0.0, 0.3) if _reaction.kind == "dead" else float(_reaction.side)}
	return result

func sample(presentation_time: float) -> Dictionary:
	if not Thread.is_main_thread(): return _failure("thread")
	if _busy: invalidate("reentrant"); return _failure(_fault)
	if not is_finite(presentation_time) or presentation_time < _time: return _failure("presentation_clock")
	var reply := _fetch("current")
	if not reply.get("ok", false): return reply
	if reply.lifecycle.has("age") and not is_finite(presentation_time - float(reply.lifecycle.age)): return _failure("lifecycle_age")
	_commit_source(reply, presentation_time)
	if DURATIONS.has(_reaction.kind) and _time - _reaction.at >= DURATIONS[_reaction.kind]: _reaction = {"kind": "idle", "at": _time, "side": 1, "zone": null}
	return _snapshot()

func consume(event_id: String, presentation_time: float) -> Dictionary:
	if not Thread.is_main_thread(): return _failure("thread")
	if _busy: invalidate("reentrant"); return _failure(_fault)
	if not _text(event_id, 128) or not is_finite(presentation_time) or presentation_time < _time: return _failure("event_or_clock")
	var reply := _fetch("receipt", event_id)
	if not reply.get("ok", false): return reply
	var receipt: Variant = reply.get("receipt")
	if reply.get("accepted") != true or not reply.get("accepted") is bool or not receipt is Dictionary: return _failure("receipt_pending")
	if receipt.get("confirmed") != true or not receipt.get("confirmed") is bool or receipt.get("id") != event_id or receipt.get("targetId") != _binding.render_id: return _failure("receipt_identity")
	if receipt.get("kind") not in ["melee", "bullet", "dropkick"] or not _number(receipt.get("damage")) or receipt.damage <= 0.0: return _failure("receipt_damage_evidence")
	if not _number(receipt.get("at")) or reply.source_now_ms < receipt.at or reply.source_now_ms - receipt.at > MAX_RECEIPT_AGE_MS: return _failure("receipt_age")
	var contact: Variant = reply.get("contact")
	if not contact is Dictionary or contact.get("validated") != true or not contact.get("validated") is bool or contact.get("space") != "source_walk_metres": return _failure("contact_unvalidated")
	for key: String in ["pose_revision", "geometry_revision"]:
		if not _identity(reply.get(key)) or not _same(contact.get(key), reply[key]): return _failure("contact_epoch")
	if not _point(receipt.get("point")) or not _point(receipt.get("normal")): return _failure("contact_shape")
	if receipt.normal.x == 0.0 and receipt.normal.y == 0.0 and receipt.normal.z == 0.0: return _failure("contact_normal")
	for key: String in ["blocked", "knockdown", "heavy", "projectile"]:
		if receipt.has(key) and not receipt[key] is bool: return _failure("receipt_flags")
	if receipt.get("zone") != null and not _text(receipt.zone, 128): return _failure("receipt_zone")
	if reply.lifecycle.has("age") and not is_finite(presentation_time - float(reply.lifecycle.age)): return _failure("lifecycle_age")
	if _receipts.has(event_id): return _failure("duplicate")
	_commit_source(reply, presentation_time)
	_receipts[event_id] = true
	_receipt_order.append(event_id)
	if _receipt_order.size() > RECEIPT_LIMIT: _receipts.erase(_receipt_order.pop_front())
	# Original Artist14 reaction precedence. Early source receipt.fatal/dead are
	# deliberately NOT input to final death; only completed lifecycle controls it.
	var blocked: bool = receipt.get("blocked", false)
	var already_down: bool = _reaction.kind == "fall" and _time - _reaction.at < 2.7
	var knockdown: bool = receipt.get("knockdown") == true or (receipt.get("knockdown") != false and (receipt.get("heavy") == true or receipt.kind == "dropkick"))
	if _reaction.kind != "dead":
		var next_kind: String = "fall" if already_down else "block" if blocked else "fall" if knockdown else "hit"
		_reaction = {"kind": next_kind, "at": _reaction.at if already_down else _time, "side": -1 if _number(receipt.get("side")) and receipt.side == -1 else 1, "zone": receipt.get("zone")}
	var result := _snapshot()
	result["event_id"] = event_id
	result["contact_effects_allowed"] = not blocked
	result["point_source_metres"] = receipt.point.duplicate(true)
	result["normal_source"] = receipt.normal.duplicate(true)
	result["contact"] = contact.duplicate(true)
	# Source surface.receive: requests only; a wound/bleed emitter still needs
	# the host's actual current skin/bone binding, never an invented world anchor.
	result["blood_cue"] = {"emit": not blocked, "count": 0 if blocked else 32 if receipt.get("heavy", false) else 20, "point": receipt.point.duplicate(true), "normal": receipt.normal.duplicate(true), "bleed_binding_requested": not blocked, "bullet_wound_binding_requested": not blocked and (receipt.kind == "bullet" or receipt.get("projectile", false)), "binding_established": false}
	return result

static func blood_burst(cue: Dictionary, surface_unit: float, source_cursor: int) -> Dictionary:
	# Exact initial non-water/non-drip surface.emit recipe. Caller owns the
	# shared 112-slot cursor (also used by water/drips) and actual rig scale.
	# This cosmetic velocity is NOT an NPC body impulse J.
	if not is_finite(surface_unit) or surface_unit <= 0.0 or source_cursor < 0 or source_cursor > 9007199254740960: return _failure("blood_context")
	if cue.get("emit") != true or not cue.get("emit") is bool or not _number(cue.get("count")) or (cue.count != 20 and cue.count != 32) or not _point(cue.get("point")) or not _point(cue.get("normal")): return _failure("blood_cue")
	var n: Dictionary = cue.normal
	var length: float = sqrt(float(n.x) * n.x + float(n.y) * n.y + float(n.z) * n.z)
	if not is_finite(length) or length <= 0.0: return _failure("blood_normal")
	var particles: Array = []
	for i in int(cue.count):
		var cursor := source_cursor + i + 1
		var angle := float(cursor) * 2.399963
		particles.append({"slot": (cursor - 1) % 112, "life": 0.35 + float(i % 5) * 0.07, "point": cue.point.duplicate(true), "velocity": {"x": (sin(angle) * 1.5 + float(n.x) / length * 0.6) * surface_unit, "y": (1.1 + float(i % 4) * 0.4 + float(n.y) / length * 0.6) * surface_unit, "z": (cos(angle) * 1.3 + float(n.z) / length * 0.6) * surface_unit}})
	return {"ok": true, "particles": particles, "cursor": source_cursor + int(cue.count), "presentation_only": true, "physical_impulse": false}
