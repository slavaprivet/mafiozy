extends RefCounted
## Source response values only. Contact, eligibility, kinematics and current
## actor/car lifetime remain host-authorized. No HP or physical mutation.
const SOURCE_SHA := "2358d2953ac670671c8b4cb7328d901eb63888fc4c764bda380e07010035e3f8"
const COOLDOWN_MS := 900.0
const MAX_PAIRS := 256
var _pairs: Dictionary = {}
var _last_tick: int = -1
var _last_now: float = -1.0
var _session: String = ""

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128

static func _reject(reason: String) -> Dictionary:
	return {"accepted":false,"reason":reason,"response":{},"apply_damage":false,"apply_impulse":false,"physical_admission":false}

static func source_impact(speed_mps: float) -> Dictionary:
	if not is_finite(speed_mps) or speed_mps < 0.45: return {}
	var speed := clampf(speed_mps,0.0,42.0)
	var severity := clampf((speed-0.45)/17.55,0.0,1.0)
	var falling := speed >= 1.65
	return {"speedMps":speed,"severity":severity,"damage":int(floor(clampf((speed-1.45)*3.6,1.0,105.0)+0.5)) if falling else 0,
		"falling":falling,"fallMs":int(floor(620.0+minf(1600.0,speed*70.0)+0.5)) if falling else 0,
		"launchMps":clampf(speed*0.72,2.2,14.5) if falling else clampf(speed*0.32,0.3,1.2),
		"liftMps":clampf(0.35+(speed-1.65)*0.22,0.35,4.2) if falling else 0.0,
		"carSpeedRetention":clampf(0.94-severity*0.3,0.58,0.94),
		"tier":"severe" if speed >= 12.0 else "hard" if speed >= 5.5 else "fall" if falling else "shove"}

func evaluate(event: Dictionary, current: Dictionary) -> Dictionary:
	# Current is an independently maintained host receipt, not copied from event.
	for key: String in ["contact_confirmed","can_hit_confirmed","source_kinematics_confirmed"]:
		if not current.get(key) is bool or not current[key]: return _reject("confirmation_required:"+key)
	if not current.get("source_sha256") is String or current.source_sha256 != SOURCE_SHA: return _reject("source_binding")
	for key: String in ["session_id","actor_source_id","car_source_id"]:
		if not _id(event.get(key)) or not _id(current.get(key)) or event[key] != current[key]: return _reject("identity_binding:"+key)
	for key: String in ["actor_generation","car_generation","tick"]:
		if not event.get(key) is int or not current.get(key) is int or event[key] != current[key] or event[key] < (0 if key == "tick" else 1): return _reject("lifetime_binding:"+key)
	for key: String in ["now_ms","speed_mps"]:
		if not _finite(event.get(key)) or not _finite(current.get(key)) or event[key] != current[key] or event[key] < 0: return _reject("kinematics_binding:"+key)
	if event.tick < _last_tick or event.now_ms < _last_now: return _reject("stale_clock")
	if not _session.is_empty() and event.session_id != _session: return _reject("session_changed")
	_session = event.session_id; _last_tick = event.tick; _last_now = event.now_ms
	var response := source_impact(float(event.speed_mps))
	if response.is_empty(): return _reject("below_source_speed")
	var key := JSON.stringify([event.session_id,event.car_source_id,event.car_generation,event.actor_source_id,event.actor_generation])
	if _pairs.has(key):
		var prior: Dictionary = _pairs[key]
		if event.tick <= prior.tick: return _reject("duplicate_pair_tick")
		# Deliberately source-faithful: timestamp zero is falsy in JS's ||.
		if prior.now_ms != 0.0 and event.now_ms-prior.now_ms < COOLDOWN_MS: return _reject("source_pair_cooldown")
	if not _pairs.has(key) and _pairs.size() >= MAX_PAIRS:
		# Expire only entries which cannot suppress an event at this clock.
		var expired: Array = []
		for existing: String in _pairs:
			var prior: Dictionary = _pairs[existing]
			if prior.tick < event.tick and (prior.now_ms == 0.0 or event.now_ms-prior.now_ms >= COOLDOWN_MS): expired.append(existing)
		for existing: String in expired: _pairs.erase(existing)
		if _pairs.size() >= MAX_PAIRS: return _reject("ledger_capacity_hold")
	_pairs[key] = {"session_id":event.session_id,"car_source_id":event.car_source_id,"car_generation":event.car_generation,"actor_source_id":event.actor_source_id,"actor_generation":event.actor_generation,"tick":event.tick,"now_ms":event.now_ms}
	_last_tick = event.tick; _last_now = event.now_ms
	return {"accepted":true,"reason":"source_response","response":response,"session_id":event.session_id,"actor_source_id":event.actor_source_id,"car_source_id":event.car_source_id,"actor_generation":event.actor_generation,"car_generation":event.car_generation,"tick":event.tick,"now_ms":event.now_ms,"apply_damage":false,"apply_impulse":false,"physical_admission":false}

func retire_actor(session_id: String, source_id: String, generation: int) -> int:
	return _retire(session_id,source_id,generation,"actor")

func retire_car(session_id: String, source_id: String, generation: int) -> int:
	return _retire(session_id,source_id,generation,"car")

func _retire(session_id: String, source_id: String, generation: int, kind: String) -> int:
	# Call only after that exact lifetime is no longer current; stale events must
	# still fail the independently maintained current receipt.
	var removed := 0
	for key: String in _pairs.keys():
		var row: Dictionary = _pairs[key]
		if row.session_id == session_id and row[kind+"_source_id"] == source_id and row[kind+"_generation"] == generation:
			_pairs.erase(key); removed += 1
	return removed

func status() -> Dictionary:
	return {"pairs":_pairs.size(),"max_pairs":MAX_PAIRS,"last_tick":_last_tick,"last_now_ms":_last_now,"source_sha256":SOURCE_SHA}
