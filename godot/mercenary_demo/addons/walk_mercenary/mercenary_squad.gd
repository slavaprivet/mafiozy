extends RefCounted
## Source: assets/maps/city_rebuild_v1/mercenary_core.mjs:createMercenarySquad.
## All positions are dictionaries in world metres; clocks/durations are seconds.
## Adapters own HP, money, actors, navigation and effects. This core owns commands.

const PROFESSIONS: Dictionary = {
	"medic": {"name": "Медик", "hpMultiplier": 1.0, "meleeMultiplier": 1.0, "skills": ["medicine", "fitness"], "actions": ["revive"]},
	"bruiser": {"name": "Громила", "hpMultiplier": 1.65, "meleeMultiplier": 1.8, "skills": ["intimidation", "melee", "fitness"], "actions": ["intimidate", "breach_door"]},
	"safecracker": {"name": "Медвежатник", "hpMultiplier": 1.0, "meleeMultiplier": 1.0, "skills": ["lockpicking", "fitness"], "actions": ["unlock_safe", "unlock_door"]},
	"engineer": {"name": "Электрик-резчик", "hpMultiplier": 1.0, "meleeMultiplier": 1.0, "skills": ["cutting", "fitness"], "actions": ["cut_fence", "disable_power"]},
	"demolitions": {"name": "Подрывник", "hpMultiplier": 1.1, "meleeMultiplier": 1.0, "skills": ["explosives", "fitness"], "actions": ["plant_bomb"]},
}
const ACTIONS: Dictionary = {
	"revive": {"profession": "medic", "skill": "medicine", "duration": 4.0, "range": 1.6, "cooldown": 12.0},
	"intimidate": {"profession": "bruiser", "skill": "intimidation", "duration": 2.5, "range": 2.0, "cooldown": 8.0},
	"breach_door": {"profession": "bruiser", "skill": "melee", "duration": 2.5, "range": 1.5, "cooldown": 3.0, "noiseRadius": 12.0},
	"unlock_safe": {"profession": "safecracker", "skill": "lockpicking", "duration": 8.0, "range": 1.5, "cooldown": 2.0},
	"unlock_door": {"profession": "safecracker", "skill": "lockpicking", "duration": 5.0, "range": 1.5, "cooldown": 2.0},
	"cut_fence": {"profession": "engineer", "skill": "cutting", "duration": 6.0, "range": 1.5, "cooldown": 2.0},
	"disable_power": {"profession": "engineer", "skill": "cutting", "duration": 5.0, "range": 1.5, "cooldown": 2.0},
	"plant_bomb": {"profession": "demolitions", "skill": "explosives", "duration": 4.0, "range": 2.0, "cooldown": 20.0, "noiseRadius": 40.0},
}
const DEFAULT_BALANCE: Dictionary = {"maxMembers": 5, "maxQueued": 8, "approachTimeout": 40.0, "blockedTimeout": 10.0, "bombFuse": 6.0, "retreatDistance": 8.0, "autoMedicInterval": 0.5, "hospitalDuration": 300.0, "reviveGrace": 20.0}
const MAX_SAFE_INTEGER: int = 9007199254740991

## Explicit native substitute for a Promise returned by performEffect.
## Dispatch is deferred, including settle-before-subscribe, so awaiting is stored
## and published before an acknowledgement can finish the action.
class PendingEffect extends RefCounted:
	var _settled: bool = false
	var _receipt: Variant = null
	var _subscribers: Array[Callable] = []
	func settle(value: Variant) -> void:
		if _settled:
			return
		_settled = true
		_receipt = value.duplicate(true) if value is Dictionary or value is Array else value
		for callback: Callable in _subscribers:
			if callback.is_valid():
				callback.call_deferred(_receipt.duplicate(true) if _receipt is Dictionary or _receipt is Array else _receipt)
		_subscribers.clear()
	func subscribe(callback: Callable) -> void:
		if not callback.is_valid():
			return
		if _settled:
			callback.call_deferred(_receipt.duplicate(true) if _receipt is Dictionary or _receipt is Array else _receipt)
		else:
			_subscribers.append(callback)

var _get_member: Callable
var _get_target: Callable
var _move_member: Callable
var _perform_effect: Callable
var _now: Callable
var _on_action: Callable
var _scan_revive_targets: Callable
var _can_auto_revive: Callable
var _can_start_queued: Callable
var _allow_qa_patient_reset: Callable
var _balance: Dictionary = {}
var _roster: Dictionary = {}
var _actions: Dictionary = {}
var _settled_ids: Dictionary = {}
var _last_scan: float = -INF
var _sequence: int = 0

func _init(options: Dictionary = {}) -> void:
	_get_member = _option(options, "getMember", func(_id: Variant) -> Variant: return null)
	_get_target = _option(options, "getTarget", func(_id: Variant) -> Variant: return null)
	_move_member = _option(options, "moveMember", func(_id: Variant, _target: Variant, _state: Dictionary) -> void: pass)
	_perform_effect = _option(options, "performEffect", func(_request: Dictionary) -> bool: return false)
	_now = _option(options, "now", func() -> float: return Time.get_unix_time_from_system())
	_on_action = _option(options, "onAction", func(_id: Variant, _state: Dictionary) -> void: pass)
	_scan_revive_targets = _option(options, "scanReviveTargets", func() -> Array: return [])
	_can_auto_revive = _option(options, "canAutoRevive", func(_id: Variant) -> bool: return true)
	_can_start_queued = _option(options, "canStartQueued", func(_id: Variant) -> bool: return true)
	_allow_qa_patient_reset = _option(options, "allowQaPatientReset", func() -> bool: return false)
	_balance = DEFAULT_BALANCE.duplicate(true)
	if options.get("balance") is Dictionary:
		_balance.merge(options.balance.duplicate(true), true)

static func _option(options: Dictionary, key: String, fallback: Callable) -> Callable:
	var value: Variant = options.get(key)
	return value if value is Callable and value.is_valid() else fallback

static func _field(value: Variant, key: Variant, fallback: Variant = null) -> Variant:
	return value.get(key, fallback) if value is Dictionary else fallback

static func _finite(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

static func _is_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _true(value: Variant) -> bool:
	return value is bool and value

static func _false(value: Variant) -> bool:
	return value is bool and not value

static func _truth(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0 and not is_nan(float(value))
	if value is String:
		return not value.is_empty()
	return true # JavaScript empty objects and arrays are truthy.

static func _number(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is bool:
		return 1.0 if value else 0.0
	if value is int or value is float:
		return float(value)
	if value is String:
		var text: String = value.strip_edges()
		if text.is_empty():
			return 0.0
		if text == "Infinity" or text == "+Infinity":
			return INF
		if text == "-Infinity":
			return -INF
		return text.to_float() if text.is_valid_float() else NAN
	return NAN

static func _or(value: Variant, fallback: Variant) -> Variant:
	return value if _truth(value) else fallback

static func _string(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if value else "false"
	if value is Dictionary:
		return "[object Object]"
	if value is Array:
		var parts: PackedStringArray = []
		for item: Variant in value:
			parts.append("" if item == null else _string(item))
		return ",".join(parts)
	return str(value)

## JavaScript String.slice counts UTF-16 code units, including a split surrogate.
## Godot stores Unicode scalars: its String.chr rejects unpaired surrogates. Only
## that unrepresentable terminal half is normalized to U+FFFD, explicitly tested.
static func _utf16_prefix(value: String, limit: int) -> String:
	var result: String = ""
	var remaining: int = limit
	for index: int in range(value.length()):
		if remaining <= 0:
			break
		var code: int = value.unicode_at(index)
		if code > 0xFFFF:
			if remaining == 1:
				result += String.chr(0xFFFD)
				break
			remaining -= 2
		else:
			remaining -= 1
		result += value[index]
	return result

static func _utf16_length(value: String) -> int:
	var units: int = 0
	for index: int in range(value.length()):
		units += 2 if value.unicode_at(index) > 0xFFFF else 1
	return units

static func _copy(value: Variant) -> Variant:
	if value is Dictionary:
		var copied: Dictionary = {}
		for key: Variant in value:
			copied[_string(key)] = _copy(value[key])
		return copied
	if value is Array:
		var copied: Array = []
		for item: Variant in value:
			copied.append(_copy(item))
		return copied
	if value is float and not is_finite(value):
		return null
	return value if value == null or value is bool or value is String or value is int or value is float else null

static func _safe_integer(value: Variant) -> bool:
	return _is_finite(value) and absf(float(value)) <= MAX_SAFE_INTEGER and floorf(float(value)) == float(value)

static func _result(ok: bool, reason: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": ok, "reason": reason}
	result.merge(extra, true)
	return result

func _time() -> float:
	return _number(_now.call())

static func _point(entity: Variant) -> Variant:
	return _field(entity, "position")

static func _distance(first: Variant, second: Variant) -> float:
	var a: Variant = _point(first)
	var b: Variant = _point(second)
	if not _truth(a) or not _truth(b):
		return INF
	var dx: float = _number(_field(a, "x", NAN)) - _number(_field(b, "x", NAN))
	var dy: float = _number(_or(_field(a, "y"), 0)) - _number(_or(_field(b, "y"), 0))
	var dz: float = _number(_field(a, "z", NAN)) - _number(_field(b, "z", NAN))
	return sqrt(dx * dx + dy * dy + dz * dz)

static func _alive(member: Variant) -> bool:
	return _truth(member) and not _false(_field(member, "available")) and not _truth(_field(member, "dead")) and not _truth(_field(member, "downed")) and _number(_field(member, "hp", NAN)) > 0

static func _acknowledged(value: Variant) -> bool:
	return _true(value) or _true(_field(value, "ok"))

static func _valid_target(kind: Variant, target: Variant) -> bool:
	var position: Variant = _point(target)
	if not _truth(target) or _false(_field(target, "valid")) or not _truth(position) or not _is_finite(_field(position, "x")) or not _is_finite(_field(position, "z")):
		return false
	var target_kind: Variant = _field(target, "kind")
	if kind == "revive":
		return target_kind in ["npc", "player"] and not _false(_field(target, "revivable")) and (_truth(_field(target, "downed")) or _truth(_field(target, "dead")) or _number(_field(target, "hp", NAN)) <= 0)
	if kind == "intimidate":
		return target_kind == "npc" and not _truth(_field(target, "dead")) and not _truth(_field(target, "downed")) and _number(_field(target, "hp", NAN)) > 0 and not _false(_field(target, "intimidatable"))
	if kind == "breach_door":
		return target_kind == "door" and _true(_field(target, "locked")) and not _truth(_field(target, "opened")) and not _truth(_field(target, "destroyed")) and _true(_field(target, "breachable"))
	if kind == "unlock_safe":
		return target_kind == "safe" and _true(_field(target, "locked")) and not _truth(_field(target, "opened"))
	if kind == "unlock_door":
		return _true(_field(target, "locked")) and ((target_kind == "door" and not _truth(_field(target, "opened")) and not _false(_field(target, "lockpickable"))) or (target_kind == "vehicle" and not _false(_field(target, "lockpickable"))))
	if kind == "cut_fence":
		return target_kind == "fence" and not _false(_field(target, "cuttable")) and not _truth(_field(target, "cut"))
	if kind == "disable_power":
		return target_kind == "power_panel" and _true(_field(target, "powered")) and not _truth(_field(target, "disabled"))
	return kind == "plant_bomb" and not _truth(_field(target, "destroyed")) and ((target_kind == "vehicle" and not _false(_field(target, "bombable"))) or (target_kind == "door" and _true(_field(target, "locked")) and not _truth(_field(target, "opened")) and _true(_field(target, "bombable"))))

func _setting(kind: Variant, field: String, fallback: Variant) -> Variant:
	var value: Variant = _field(_balance.get(kind), field)
	return fallback if value == null else value

func _work_range(kind: Variant, target: Variant) -> float:
	var limit: float = _number(_setting(kind, "range", ACTIONS[kind].range))
	var specified: Variant = _field(target, "workRange")
	return minf(limit, maxf(0.05, float(specified))) if _is_finite(specified) else limit

func stats(id: Variant) -> Variant:
	var record: Variant = _roster.get(id)
	if record == null:
		return null
	var profession: Dictionary = PROFESSIONS[record.profession]
	return {"hpMultiplier": profession.hpMultiplier * (1 + 0.08 * _number(_or(record.skills.get("fitness"), 0))), "meleeMultiplier": profession.meleeMultiplier * (1 + 0.12 * _number(_or(record.skills.get("melee"), 0))), "skillLevel": _copy(record.skills), "level": record.level, "reviveFraction": minf(0.8, 0.35 + 0.05 * _number(_or(record.skills.get("medicine"), 0)))}

func add_xp(id: Variant, amount: Variant) -> bool:
	var record: Variant = _roster.get(id)
	if record == null or not _is_finite(amount) or amount <= 0:
		return false
	record.xp += floori(float(amount))
	var level: int = mini(20, 1 + floori(float(record.xp) / 100.0))
	if level > record.level:
		record.skillPoints += level - record.level
		record.level = level
	return true

func recruit(member: Dictionary) -> Dictionary:
	var id: Variant = member.get("id")
	var profession: Variant = member.get("profession")
	if not id is String or id.is_empty() or not PROFESSIONS.has(profession):
		return _result(false, "invalid_member")
	if _roster.has(id) or _actions.has(id):
		return _result(false, "already_recruited")
	if _roster.size() >= _number(_balance.maxMembers):
		return _result(false, "squad_full")
	var skills: Dictionary = {}
	for skill: String in PROFESSIONS[profession].skills:
		skills[skill] = 0
	_roster[id] = {"id": id, "profession": profession, "name": _utf16_prefix(_string(member.get("name", "")), 100), "xp": 0, "level": 1, "skillPoints": 0, "skills": skills, "cooldowns": {}, "status": "active", "hospitalUntil": 0, "downedAt": null, "weapon": null, "queued": []}
	return _result(true, "recruited")

func upgrade(id: Variant, skill: Variant) -> Dictionary:
	var record: Variant = _roster.get(id)
	if record == null or not record.skills.has(skill):
		return _result(false, "invalid_skill")
	if record.skillPoints < 1 or record.skills[skill] >= 5:
		return _result(false, "upgrade_unavailable")
	record.skillPoints -= 1
	record.skills[skill] += 1
	return _result(true, "upgraded")

static func _update_contact(action: Dictionary, target: Variant) -> void:
	for key: String in ["workPoint", "workNormal", "supportPoint"]:
		var position: Variant = _field(target, key)
		if _truth(position) and _is_finite(_field(position, "x")) and _is_finite(_field(position, "y")) and _is_finite(_field(position, "z")):
			action[key] = {"x": position.x, "y": position.y, "z": position.z}
		else:
			action.erase(key)

func _moving_bomb_target(action: Dictionary, target: Dictionary, time: float) -> bool:
	if action.kind != "plant_bomb" or target.get("kind") != "vehicle":
		return false
	var position: Variant = _or(target.get("workPoint"), _or(target.get("center"), target.get("position")))
	var previous: Variant = action.get("vehicleSample")
	var moving: bool = _true(target.get("moving")) or absf(_finite(target.get("speed"))) > 0.12
	if _truth(previous) and time > previous.at:
		var dx: float = _number(_field(position, "x", NAN)) - _number(previous.x)
		var dy: float = _number(_or(_field(position, "y"), 0)) - _number(previous.y)
		var dz: float = _number(_field(position, "z", NAN)) - _number(previous.z)
		var travel: float = sqrt(dx * dx + dy * dy + dz * dz)
		moving = moving or (travel > 0.015 and travel / (time - previous.at) > 0.12)
	action.vehicleSample = {"x": _field(position, "x", NAN), "y": _or(_field(position, "y"), 0), "z": _field(position, "z", NAN), "at": time}
	if moving:
		action.vehicleMovingUntil = time + 0.3
	return moving or time < _number(_or(action.get("vehicleMovingUntil"), 0))

func _publish(action: Dictionary) -> void:
	if _truth(action.get("detached")):
		return
	var state: Dictionary = {"kind": action.kind, "phase": action.phase, "progress": _or(action.get("progress"), 0), "targetId": action.targetId, "startedAt": action.phaseStartedAt, "duration": _balance.bombFuse if action.phase in ["retreat", "countdown"] else action.duration, "waitingForSafety": _truth(action.get("waitingForSafety"))}
	for key: String in ["workPoint", "workNormal", "supportPoint"]:
		if _truth(action.get(key)):
			state[key] = action[key].duplicate()
	_on_action.call(action.memberId, state)

func _finish(action: Dictionary, reason: String, completed: bool = false) -> Dictionary:
	if not is_same(_actions.get(action.memberId), action):
		return _result(false, "stale_request")
	_actions.erase(action.memberId)
	if reason in ["cancelled", "damaged", "member_unavailable", "hospitalized"]:
		clear_queue(action.memberId)
	if not _truth(action.get("detached")):
		_move_member.call(action.memberId, null, {"phase": "stop", "stopDistance": 0})
		_on_action.call(action.memberId, {"kind": action.kind, "phase": "completed" if completed else "cancelled", "progress": 1 if completed else 0, "targetId": action.targetId, "startedAt": _time(), "duration": 0, "reason": reason})
	if completed:
		add_xp(action.memberId, 25)
		var record: Variant = _roster.get(action.memberId)
		if record != null:
			record.cooldowns[action.kind] = _time() + _number(action.cooldown)
	return _result(completed, reason)

static func _competing(action: Dictionary, kind: Variant, target: Dictionary, target_id: Variant) -> bool:
	return action.get("targetId") == target_id and (action.get("kind") == kind or (target.get("kind") == "door" and action.get("kind") in ["unlock_door", "breach_door", "plant_bomb"] and kind in ["unlock_door", "breach_door", "plant_bomb"]))

static func _has_queue(record: Dictionary) -> bool:
	return _truth(record.get("resumeWork")) or not record.queued.is_empty()

func _target_busy(kind: Variant, target: Dictionary, target_id: Variant) -> bool:
	for action: Dictionary in _actions.values():
		if _competing(action, kind, target, target_id):
			return true
	for record: Dictionary in _roster.values():
		if _truth(record.get("resumeWork")) and _competing(record.resumeWork, kind, target, target_id):
			return true
		for queued: Dictionary in record.queued:
			if _competing(queued, kind, target, target_id):
				return true
	return false

func clear_queue(id: Variant) -> int:
	var record: Variant = _roster.get(id)
	if record == null:
		return 0
	var count: int = record.queued.size() + (1 if _truth(record.get("resumeWork")) else 0)
	record.queued = []
	record.erase("resumeWork")
	record.erase("queueHp")
	return count

func command(member_id: Variant, kind: Variant, target_id: Variant, options: Dictionary = {}) -> Dictionary:
	var record: Variant = _roster.get(member_id)
	var definition: Variant = ACTIONS.get(kind)
	var member: Variant = _get_member.call(member_id)
	var target: Variant = _get_target.call(target_id)
	var time: float = _time()
	if record == null or definition == null or record.profession != definition.profession:
		return _result(false, "wrong_profession")
	if not _alive(member) or record.status == "hospital":
		return _result(false, "member_unavailable")
	if not target_id is String or not _valid_target(kind, target) or target_id == member_id or (kind == "revive" and _field(_roster.get(target_id), "status") == "hospital"):
		return _result(false, "invalid_target")
	var active: Variant = _actions.get(member_id)
	if active != null and active.kind == kind and active.targetId == target_id:
		return _result(false, "busy")
	if _target_busy(kind, target, target_id):
		return _result(false, "target_busy")
	if not _truth(options.get("fromQueue", false)) and (_actions.has(member_id) or _has_queue(record) or _number(_or(record.cooldowns.get(kind), 0)) > time or not _truth(_can_start_queued.call(member_id))):
		if record.queued.size() >= _number(_balance.maxQueued):
			return _result(false, "queue_full")
		record.queued.append({"kind": kind, "targetId": target_id, "queuedAt": time})
		if not _is_finite(record.get("queueHp")):
			record.queueHp = _field(member, "hp")
		return _result(true, "queued", {"queued": true, "queuePosition": record.queued.size(), "memberId": member_id})
	if _actions.has(member_id):
		return _result(false, "busy")
	if _number(_or(record.cooldowns.get(kind), 0)) > time:
		return _result(false, "cooldown")
	_sequence += 1
	var action: Dictionary = {"id": _sequence, "memberId": member_id, "targetId": target_id, "kind": kind, "phase": "approach", "progress": 0, "startedAt": time, "phaseStartedAt": time, "lastProgressAt": time, "bestDistance": _distance(member, target), "duration": _number(_setting(kind, "duration", definition.duration)) / (1 + 0.12 * _number(_or(record.skills.get(definition.skill), 0))), "range": _work_range(kind, target), "cooldown": _setting(kind, "cooldown", definition.cooldown), "armed": false, "effectApplied": false, "lastHp": _field(member, "hp")}
	_update_contact(action, target)
	_actions[member_id] = action
	_publish(action)
	return _result(true, "accepted", {"actionId": action.id})

func _apply(action: Dictionary, target: Dictionary) -> Variant:
	if _truth(action.get("effectApplied")) or _settled_ids.has(action.id):
		return false
	action.effectApplied = true
	_settled_ids[action.id] = true
	if _settled_ids.size() > 4096:
		_settled_ids.erase(_settled_ids.keys()[0])
	var request: Dictionary = {"kind": action.kind, "memberId": action.memberId, "targetId": action.targetId, "target": target, "member": _get_member.call(action.memberId), "stats": stats(action.memberId), "actionId": action.id, "requestId": action.id}
	if _truth(_field(ACTIONS.get(action.kind), "noiseRadius")):
		request.noiseRadius = _setting(action.kind, "noiseRadius", ACTIONS[action.kind].noiseRadius)
	var receipt: Variant = _perform_effect.call(request)
	if receipt is PendingEffect:
		action.phase = "awaiting"
		action.progress = 1
		action.phaseStartedAt = _time()
		action.awaiting = true
		_publish(action)
		receipt.subscribe(_pending_receipt.bind(action.id))
		return null
	return _acknowledged(receipt)

func _pending_receipt(receipt: Variant, request_id: Variant) -> void:
	resolve_pending(request_id, receipt)

func resolve_pending(request_id: Variant, receipt: Variant) -> Dictionary:
	for action: Dictionary in _actions.values():
		if action.id == request_id and _truth(action.get("awaiting")):
			var ok: bool = _acknowledged(receipt)
			action.awaiting = false
			return _finish(action, "completed" if ok else "effect_rejected", ok)
	return _result(false, "unknown_request")

func update() -> void:
	var time: float = _time()
	_update_lifecycle(time)
	# A shallow five-action snapshot preserves source mutation/reentrancy order.
	for action: Dictionary in _actions.values():
		if _truth(action.get("awaiting")):
			continue
		var member: Variant = _get_member.call(action.memberId)
		var target: Variant = _get_target.call(action.targetId)
		_update_contact(action, target)
		if not _valid_target(action.kind, target):
			_finish(action, "target_invalid")
			continue
		if _truth(action.get("armed")):
			_update_armed(action, member, target, time)
			continue
		if not _alive(member):
			_finish(action, "member_unavailable")
			continue
		if _is_finite(action.get("lastHp")) and _number(_field(member, "hp", NAN)) < float(action.lastHp):
			_finish(action, "damaged")
			continue
		action.lastHp = _field(member, "hp")
		var pursue_vehicle: bool = action.kind == "plant_bomb" and target.get("kind") == "vehicle"
		var vehicle_moving: bool = _moving_bomb_target(action, target, time)
		action.range = _work_range(action.kind, target)
		var distance: float = _distance(member, target)
		if _truth(_field(member, "approachMoving")) or _truth(_field(member, "approachSearching")):
			action.lastProgressAt = time
		if distance > action.range or vehicle_moving:
			if action.phase != "approach":
				action.phase = "approach"
				action.phaseStartedAt = time
				action.progress = 0
				action.bestDistance = distance
				action.lastProgressAt = time
			if distance < action.bestDistance - 0.1:
				action.bestDistance = distance
				action.lastProgressAt = time
			if not pursue_vehicle and (time - action.startedAt > _number(_balance.approachTimeout) or time - action.lastProgressAt > _number(_balance.blockedTimeout)):
				_finish(action, "path_timeout")
				continue
			_move_member.call(action.memberId, target, {"phase": "approach", "stopDistance": _horizontal_range(member, target, action.range) * 0.85})
			_publish(action)
			continue
		if action.phase == "approach":
			action.phase = "working"
			action.phaseStartedAt = time
			if action.kind != "intimidate":
				_move_member.call(action.memberId, null, {"phase": "stop", "stopDistance": 0})
		if action.kind == "intimidate":
			_move_member.call(action.memberId, target, {"phase": "approach", "stopDistance": _horizontal_range(member, target, action.range) * 0.6})
		action.progress = minf(1.0, _divide(time - action.phaseStartedAt, _number(action.duration)))
		if action.progress < 1:
			_publish(action)
			continue
		if action.kind == "plant_bomb":
			action.armed = true
			action.armedAt = time
			action.detonateAt = time + _number(_balance.bombFuse)
			action.phaseStartedAt = time
			action.phase = "retreat"
			action.progress = 0
			_publish(action)
			continue
		if action.kind == "intimidate":
			_move_member.call(action.memberId, null, {"phase": "stop", "stopDistance": 0})
		var ok: Variant = _apply(action, target)
		if ok != null:
			_finish(action, "completed" if ok else "effect_rejected", ok)
	_update_queue(time)
	_update_auto_medic(time)

static func _divide(numerator: float, denominator: float) -> float:
	if denominator == 0.0:
		return NAN if numerator == 0.0 else (INF if numerator > 0.0 else -INF)
	return numerator / denominator

static func _horizontal_range(member: Dictionary, target: Dictionary, work_range: float) -> float:
	var height_delta: float = _number(_or(_field(_point(member), "y"), 0)) - _number(_or(_field(_point(target), "y"), 0))
	return sqrt(maxf(0, work_range * work_range - height_delta * height_delta))

func _update_lifecycle(time: float) -> void:
	for record: Dictionary in _roster.values():
		var member: Variant = _get_member.call(record.id)
		if record.status == "hospital":
			if time >= record.hospitalUntil and time >= _number(_or(record.get("lifecycleRetryAt"), 0)):
				record.lifecycleRetryAt = time + 1
				var ok: bool = _acknowledged(_perform_effect.call({"kind": "discharge", "memberId": record.id, "member": member, "stats": stats(record.id)}))
				if ok:
					record.status = "returning"
					record.hospitalUntil = 0
					record.downedAt = null
			continue
		if not _truth(member):
			clear_queue(record.id)
			continue
		if _has_queue(record):
			if not _alive(member) or (_is_finite(record.get("queueHp")) and _number(_field(member, "hp", NAN)) < float(record.queueHp)):
				clear_queue(record.id)
			else:
				record.queueHp = _field(member, "hp")
		if _truth(_field(member, "dead")) or _truth(_field(member, "downed")) or _number(_field(member, "hp", NAN)) <= 0:
			if record.downedAt == null:
				record.downedAt = time
			record.status = "downed"
			var rescue: Variant = _field(member, "qaRescueUntil")
			var qa_rescue_until: float = minf(record.downedAt + 600, maxf(0, float(rescue))) if _is_finite(rescue) else 0.0
			if (_truth(_field(member, "deathConfirmed")) or (_truth(_field(member, "dead")) and not _truth(_field(member, "downed"))) or (time - record.downedAt >= _number(_balance.reviveGrace) and time >= qa_rescue_until)) and time >= _number(_or(record.get("lifecycleRetryAt"), 0)):
				record.lifecycleRetryAt = time + 1
				var hospital_until: float = time + _number(_balance.hospitalDuration)
				var ok: bool = _acknowledged(_perform_effect.call({"kind": "hospitalize", "memberId": record.id, "member": member, "hospitalUntil": hospital_until}))
				if ok:
					record.status = "hospital"
					record.hospitalUntil = hospital_until
					var action: Variant = _actions.get(record.id)
					if action != null and not _truth(action.get("armed")) and not _truth(action.get("awaiting")):
						_finish(action, "hospitalized")
		else:
			record.downedAt = null
			if record.status == "downed":
				record.status = "active"
			if record.status == "returning" and _truth(_field(member, "followArrived")):
				record.status = "active"

func _update_armed(action: Dictionary, member: Variant, target: Dictionary, time: float) -> void:
	var elapsed: float = time - action.armedAt
	action.progress = minf(1.0, elapsed / maxf(0.001, action.detonateAt - action.armedAt))
	var center: Variant = target.get("center")
	var origin: Variant = center if _truth(center) and _is_finite(_field(center, "x")) and _is_finite(_field(center, "z")) else target.position
	var safe_distance: float = maxf(_number(_balance.retreatDistance), _finite(target.get("blastRadius")) + 1)
	var member_position: Variant = _point(member)
	var unsafe: bool = false
	if not _truth(action.get("detached")) and _alive(member):
		var dx: float = _number(_field(member_position, "x", NAN)) - _number(origin.x)
		var dz: float = _number(_field(member_position, "z", NAN)) - _number(origin.z)
		unsafe = sqrt(dx * dx + dz * dz) < safe_distance
	action.waitingForSafety = unsafe and time >= action.detonateAt
	if time >= action.detonateAt and not unsafe:
		var ok: Variant = _apply(action, target)
		if ok != null:
			_finish(action, "completed" if ok else "effect_rejected", ok)
		return
	if _truth(action.get("detached")):
		action.phase = "countdown"
		return
	if unsafe:
		action.phase = "retreat"
		var dx: float = _number(member_position.x) - _number(origin.x)
		var dz: float = _number(member_position.z) - _number(origin.z)
		var length: float = _number(_or(sqrt(dx * dx + dz * dz), 1))
		var goal_distance: float = safe_distance + 1
		var retreat: Dictionary = {"id": action.targetId, "position": {"x": _number(origin.x) + _number(_or(dx, 1 if not _truth(dz) else 0)) / length * goal_distance, "y": _or(_field(member_position, "y"), 0), "z": _number(origin.z) + dz / length * goal_distance}}
		_move_member.call(action.memberId, retreat, {"phase": "retreat", "stopDistance": 0.5})
	else:
		action.phase = "countdown"
		_move_member.call(action.memberId, null, {"phase": "stop", "stopDistance": 0})
	_publish(action)

func _update_queue(time: float) -> void:
	for record: Dictionary in _roster.values():
		if not _has_queue(record) or _actions.has(record.id) or not _alive(_get_member.call(record.id)) or record.status == "hospital" or not _truth(_can_start_queued.call(record.id)):
			continue
		var checked: int = 0
		while checked <= _number(_balance.maxQueued) and _has_queue(record):
			var next: Dictionary = record.resumeWork if _truth(record.get("resumeWork")) else record.queued[0]
			var target: Variant = _get_target.call(next.targetId)
			if _valid_target(next.kind, target) and _number(_or(record.cooldowns.get(next.kind), 0)) > time:
				break
			if _truth(record.get("resumeWork")):
				record.erase("resumeWork")
			else:
				record.queued.pop_front()
			if command(record.id, next.kind, next.targetId, {"fromQueue": true}).ok:
				break
			checked += 1
		if not _has_queue(record):
			record.erase("queueHp")

func _update_auto_medic(time: float) -> void:
	if time - _last_scan < _number(_balance.autoMedicInterval):
		return
	_last_scan = time
	var scan: Variant = _scan_revive_targets.call()
	var targets: Array = scan.slice(0, int(_number(_balance.maxMembers) + 1)) if scan is Array else []
	for record: Dictionary in _roster.values():
		if record.profession != "medic" or _actions.has(record.id) or _has_queue(record) or not _alive(_get_member.call(record.id)) or not _truth(_can_auto_revive.call(record.id)) or not _truth(_can_start_queued.call(record.id)):
			continue
		for target: Variant in targets:
			var id: Variant = target if target is String else _field(target, "id")
			if _field(_roster.get(id), "status") == "hospital":
				continue
			if command(record.id, "revive", id, {"fromQueue": true}).ok:
				break

func cancel(id: Variant) -> Dictionary:
	var cleared: int = clear_queue(id)
	var action: Variant = _actions.get(id)
	if action == null:
		return _result(cleared > 0, "queue_cancelled" if cleared > 0 else "no_action", {"queuedCleared": cleared})
	if _truth(action.get("awaiting")):
		return _result(false, "effect_pending", {"queuedCleared": cleared})
	if _truth(action.get("armed")):
		return _result(false, "bomb_armed", {"queuedCleared": cleared})
	_finish(action, "cancelled")
	return _result(true, "cancelled")

func dismiss(id: Variant) -> Dictionary:
	var record: Variant = _roster.get(id)
	if record == null:
		return _result(false, "not_recruited")
	clear_queue(id)
	var action: Variant = _actions.get(id)
	if not _truth(_field(action, "armed")) and not _truth(_field(action, "awaiting")):
		cancel(id)
	if _actions.has(id):
		_actions[id].detached = true
	_roster.erase(id)
	return _result(true, "dismissed", {"member": _copy(record)})

func set_weapon(id: Variant, weapon: Variant) -> bool:
	var record: Variant = _roster.get(id)
	if record == null:
		return false
	record.weapon = _copy(weapon)
	return true

func snapshot() -> Dictionary:
	var pending: Array = []
	var charges: Array = []
	var members: Array = []
	for action: Dictionary in _actions.values():
		if _truth(action.get("awaiting")):
			pending.append({"requestId": action.id, "memberId": action.memberId, "targetId": action.targetId, "kind": action.kind, "startedAt": action.phaseStartedAt, "cooldown": action.cooldown, "detached": _truth(action.get("detached"))})
		if _truth(action.get("armed")) and not _truth(action.get("effectApplied")):
			charges.append({"actionId": action.id, "memberId": action.memberId, "targetId": action.targetId, "kind": action.kind, "phase": action.phase, "armedAt": action.armedAt, "detonateAt": action.detonateAt, "cooldown": action.cooldown, "detached": _truth(action.get("detached")), "waitingForSafety": _truth(action.get("waitingForSafety"))})
	for record: Dictionary in _roster.values():
		var row: Dictionary = _copy(record)
		var action: Variant = _actions.get(record.id)
		if action != null and not _truth(action.get("armed")) and not _truth(action.get("awaiting")):
			row.resumeWork = {"kind": action.kind, "targetId": action.targetId, "queuedAt": action.startedAt}
		var cooldowns: Dictionary = {}
		for kind: Variant in record.cooldowns:
			cooldowns[kind] = maxf(0, _number(record.cooldowns[kind]) - _time())
		row.cooldowns = cooldowns
		members.append(row)
	return _copy({"version": 1, "sequence": _sequence, "settledActionIds": _settled_ids.keys(), "pendingTransactions": pending, "charges": charges, "members": members})

func _queue_entry(raw: Variant, profession: String) -> Variant:
	var target_id: Variant = _field(raw, "targetId")
	var kind: Variant = _field(raw, "kind")
	if not _truth(raw) or not target_id is String or target_id.is_empty() or _utf16_length(target_id) >= 512 or _field(ACTIONS.get(kind), "profession") != profession:
		return null
	return {"kind": kind, "targetId": target_id, "queuedAt": _finite(_field(raw, "queuedAt"), _time())}

func restore(data: Variant) -> Dictionary:
	var version: Variant = _field(data, "version")
	if not (version is int or version is float) or version != 1 or not _field(data, "members") is Array:
		return _result(false, "unsupported_save")
	if not _actions.is_empty():
		return _result(false, "commands_active")
	_roster.clear()
	var raw_members: Array = data.members
	for raw: Variant in raw_members.slice(0, int(_number(_balance.maxMembers))):
		if not raw is Dictionary or not recruit(raw).ok:
			continue
		var record: Dictionary = _roster[raw.id]
		var queue: Array = raw.queued if raw.get("queued") is Array else []
		for queued: Variant in queue.slice(0, int(_number(_balance.maxQueued))):
			var entry: Variant = _queue_entry(queued, record.profession)
			if entry != null:
				record.queued.append(entry)
		var resumed: Variant = _queue_entry(raw.get("resumeWork"), record.profession)
		if resumed != null:
			record.resumeWork = resumed
		if _is_finite(raw.get("queueHp")):
			record.queueHp = raw.queueHp
		record.weapon = _copy(raw.get("weapon"))
		record.hospitalUntil = maxf(0, _finite(raw.get("hospitalUntil")))
		record.downedAt = raw.downedAt if _is_finite(raw.get("downedAt")) and raw.downedAt >= 0 else null
		record.lifecycleRetryAt = maxf(0, _finite(raw.get("lifecycleRetryAt")))
		record.status = "hospital" if record.hospitalUntil > 0 else ("returning" if raw.get("status") == "returning" else ("downed" if raw.get("status") == "downed" else "active"))
		record.xp = maxi(0, mini(100000, floori(_finite(raw.get("xp")))))
		record.level = mini(20, 1 + floori(float(record.xp) / 100))
		var spent: int = 0
		for skill: Variant in record.skills:
			record.skills[skill] = mini(mini(5, maxi(0, floori(_finite(_field(raw.get("skills"), skill))))), maxi(0, record.level - 1 - spent))
			spent += record.skills[skill]
		record.skillPoints = record.level - 1 - spent
		for kind: String in PROFESSIONS[record.profession].actions:
			record.cooldowns[kind] = _time() + maxf(0, minf(120, _finite(_field(raw.get("cooldowns"), kind))))
	_sequence = maxi(_sequence, floori(maxf(0, _finite(data.get("sequence")))))
	var settled: Array = data.settledActionIds if data.get("settledActionIds") is Array else []
	for id: Variant in settled.slice(maxi(0, settled.size() - 4096)):
		if _safe_integer(id) and id > 0:
			_settled_ids[int(id)] = true
			_sequence = maxi(_sequence, int(id))
	var charges: Array = data.charges if data.get("charges") is Array else []
	for raw: Variant in charges.slice(0, 128):
		if not raw is Dictionary or raw.get("kind") != "plant_bomb" or _truth(raw.get("effectApplied")) or not raw.get("memberId") is String or not raw.get("targetId") is String or raw.memberId.is_empty() or raw.targetId.is_empty() or not _is_finite(raw.get("armedAt")) or not _is_finite(raw.get("detonateAt")) or raw.detonateAt < raw.armedAt or _actions.has(raw.memberId):
			continue
		var id: int
		if _safe_integer(raw.get("actionId")) and raw.actionId > 0:
			id = int(raw.actionId)
		else:
			_sequence += 1
			id = _sequence
		_sequence = maxi(_sequence, id)
		if _settled_ids.has(id):
			continue
		_actions[raw.memberId] = {"id": id, "memberId": raw.memberId, "targetId": raw.targetId, "kind": "plant_bomb", "phase": "retreat" if raw.get("phase") == "retreat" else "countdown", "armed": true, "armedAt": raw.armedAt, "detonateAt": raw.detonateAt, "startedAt": raw.armedAt, "phaseStartedAt": raw.armedAt, "duration": 0, "progress": 0, "cooldown": maxf(0, _finite(raw.get("cooldown"), ACTIONS.plant_bomb.cooldown)), "effectApplied": false, "detached": _truth(raw.get("detached")) or not _roster.has(raw.memberId), "waitingForSafety": _truth(raw.get("waitingForSafety"))}
	var pending: Array = data.pendingTransactions if data.get("pendingTransactions") is Array else []
	for raw: Variant in pending.slice(0, 128):
		if not raw is Dictionary or not _safe_integer(raw.get("requestId")) or raw.requestId < 1 or not ACTIONS.has(raw.get("kind")) or not raw.get("memberId") is String or not raw.get("targetId") is String or _actions.has(raw.memberId):
			continue
		_sequence = maxi(_sequence, int(raw.requestId))
		_settled_ids[int(raw.requestId)] = true
		_actions[raw.memberId] = {"id": int(raw.requestId), "memberId": raw.memberId, "targetId": raw.targetId, "kind": raw.kind, "phase": "awaiting", "progress": 1, "phaseStartedAt": _finite(raw.get("startedAt"), _time()), "duration": 0, "cooldown": maxf(0, _finite(raw.get("cooldown"))), "awaiting": true, "effectApplied": true, "detached": _truth(raw.get("detached")) or not _roster.has(raw.memberId), "requiresReconciliation": true}
	return _result(true, "restored")

func available_actions(target: Variant) -> Array:
	var value: Variant = _get_target.call(target) if target is String else target
	var available: Array = []
	for record: Dictionary in _roster.values():
		for kind: String in PROFESSIONS[record.profession].actions:
			if not _valid_target(kind, value):
				continue
			var target_id: Variant = _field(value, "id")
			available.append({"memberId": record.id, "profession": record.profession, "kind": kind, "queuedCount": record.queued.size(), "willQueue": _actions.has(record.id) or _has_queue(record) or _number(_or(record.cooldowns.get(kind), 0)) > _time() or not _truth(_can_start_queued.call(record.id)), "available": target_id != record.id and not (kind == "revive" and _field(_roster.get(target_id), "status") == "hospital") and record.status != "hospital" and _alive(_get_member.call(record.id)) and record.queued.size() < _number(_balance.maxQueued) and not _target_busy(kind, value, target_id)})
	return available

func get_record(id: Variant) -> Variant:
	var record: Variant = _roster.get(id)
	if record == null:
		return null
	var result: Dictionary = record.duplicate()
	result.hospitalRemaining = maxf(0, _number(record.hospitalUntil) - _time())
	return _copy(result)

func reset_qa_patient(id: Variant) -> Dictionary:
	var record: Variant = _roster.get(id)
	var action: Variant = _actions.get(id)
	if not _truth(_allow_qa_patient_reset.call()) or _field(record, "profession") != "bruiser" or _truth(_field(action, "armed")) or _truth(_field(action, "awaiting")):
		return _result(false, "qa_patient_reset_denied")
	if action != null:
		cancel(id)
	record.status = "downed"
	record.hospitalUntil = 0
	record.downedAt = _time()
	record.lifecycleRetryAt = 0
	return _result(true, "qa_patient_ready")

func get_queue(id: Variant) -> Array:
	return _copy(_field(_roster.get(id), "queued", []))

func get_roster() -> Array:
	var records: Array = []
	for record: Dictionary in _roster.values():
		var row: Dictionary = record.duplicate()
		row.hospitalRemaining = maxf(0, _number(record.hospitalUntil) - _time())
		records.append(row)
	return _copy(records)

func get_action(id: Variant) -> Variant:
	return _copy(_actions[id]) if _actions.has(id) else null
