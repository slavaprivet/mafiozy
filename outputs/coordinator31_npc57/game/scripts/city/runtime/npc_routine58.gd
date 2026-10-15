extends RefCounted
## A small intent selector. The shared DayClock owns time; service/home owners
## own movement, beds and money. This object never changes a body or an account.
## DSH_LIVELY58 (--city-lively58=1, default off): the accepted cadence parks a
## resident for 8-32 s after every ambient action and only reconsiders a stroll
## every 45-120 s, so a full city reads as standing still. The flag only shortens
## those two waits; every intent, priority and owner stays exactly as it is.
const LIVELY_REST_QUIET_MS := 3000.0
const LIVELY_REST_MS := 1500.0
const LIVELY_REST_SPREAD_MS := 2500.0
const LIVELY_RETRY_ARRIVED_MS := 12000.0
const LIVELY_RETRY_MS := 6000.0
static var _lively58_flag := -1
static func lively58_on() -> bool:
	if _lively58_flag < 0: _lively58_flag = 1 if OS.get_cmdline_user_args().has("--city-lively58=1") else 0
	return _lively58_flag == 1
var _source_id := ""
var _profile: Dictionary = {}
var _paid_days: Dictionary = {}
var _pending: Dictionary = {}
var _last_receipt := ""
var _rest_until_ms := 0.0
var _leisure_retry_ms := 0.0
var _last_intent: Dictionary = {}

func configure(source_id: String) -> void:
	_source_id = source_id
	var late: bool = _unit("late") < .2
	_profile = {
		"breakfast": 7.0 + _unit("breakfast") * 1.5 + (2.5 if late else 0.0),
		"lunch": 12.0 + _unit("lunch") * 1.5,
		"dinner": 18.0 + _unit("dinner") * 2.0,
		"supplies": 10.0 + _unit("supplies") * 6.0,
		"bedtime": 1.0 + _unit("bedtime") * 1.5 if late else 21.5 + _unit("bedtime") * 2.0,
		"wake": 9.0 + _unit("wake") * 1.5 if late else 6.5 + _unit("wake") * 1.5,
		"home_rest": 14.0 + _unit("home_rest") * 2.0,
		"homebody": _unit("homebody") < .45, "late": late}

func _unit(salt: String) -> float:
	return float((_source_id + ":routine58:" + salt).hash() % 1000003) / 1000003.0

func _clock(clock: RefCounted) -> Dictionary:
	if clock == null: return {}
	var hour: Variant = clock.get("hour")
	var day: Variant = clock.get("day_index")
	if not (hour is float or hour is int) or not is_finite(float(hour)) or not day is int: return {}
	return {"hour": fposmod(float(hour), 24.0), "day": int(day)}

func home_intent(clock: RefCounted) -> Dictionary:
	var time: Dictionary = _clock(clock)
	if time.is_empty(): return {}
	var hour: float = time.hour
	var bedtime: float = _profile.bedtime
	var wake: float = _profile.wake
	var asleep_window: bool = hour >= bedtime or hour < wake if bedtime > wake else hour >= bedtime and hour < wake
	if asleep_window:
		return {"kind": "home_sleep", "source_id": _source_id, "hour": hour, "wake_hour": wake}
	if _profile.homebody and hour >= float(_profile.home_rest) and hour < float(_profile.home_rest) + 1.5:
		return {"kind": "home_rest", "source_id": _source_id, "hour": hour, "wake_hour": float(_profile.home_rest) + 1.5}
	return {}

func due_purchase(clock: RefCounted) -> Dictionary:
	if not _pending.is_empty(): return _pending.duplicate()
	var time: Dictionary = _clock(clock)
	if time.is_empty(): return {}
	# Never run a catch-up loop when N changes the clock or a resident recovers.
	# Only today's currently open window can create one pending errand.
	for name: String in ["breakfast", "lunch", "dinner", "supplies"]:
		var start: float = _profile[name]
		if float(time.hour) < start or float(time.hour) >= start + 1.5: continue
		if int(_paid_days.get(name, -1)) == int(time.day): continue
		return {"kind": "shop" if name == "supplies" else "restaurant", "event": name,
			"day": time.day, "ticket": _source_id + ":routine58:" + str(time.day) + ":" + name}
	return {}

func choose(clock: RefCounted, now_ms: float, purchase_deferred: bool = false) -> Dictionary:
	var home: Dictionary = home_intent(clock)
	# An unpaid scheduled purchase is retained overnight. Actual urgent hunger
	# is already handled by Daily/Economy before this discretionary selector.
	if home.get("kind", "") == "home_sleep": _last_intent=home.duplicate(); return home
	var errand: Dictionary = {} if purchase_deferred else due_purchase(clock)
	if not errand.is_empty():
		_pending = errand.duplicate(); _last_intent = errand.duplicate(); return errand
	if not home.is_empty(): _last_intent = home.duplicate(); return home
	if now_ms < _rest_until_ms:
		_last_intent={"kind":"rest","until_ms":_rest_until_ms,"reason":"pause_after_real_activity"}
		return _last_intent.duplicate()
	var time: Dictionary = _clock(clock)
	if not time.is_empty() and now_ms >= _leisure_retry_ms:
		var night_walk: bool = _profile.late and (float(time.hour)>=22.0 or float(time.hour)<float(_profile.bedtime))
		var day_walk: bool = float(time.hour)>=9.0 and float(time.hour)<21.0
		if night_walk or day_walk:
			_last_intent={"kind":"leisure","reason":"night_walk_to_real_bench" if night_walk else "walk_to_real_bench"}
			return _last_intent.duplicate()
	_last_intent = {"kind": "rest" if now_ms < _rest_until_ms else "ambient", "until_ms": _rest_until_ms,
		"reason": "between_real_errands" if not _clock(clock).is_empty() else "shared_clock_unavailable"}
	return _last_intent.duplicate()

func note_paid(ticket: String, event_id: String, kind: String) -> bool:
	# Daily calls this only from its current inside/committed Economy owner.
	if ticket.is_empty() or event_id.is_empty() or event_id == _last_receipt or _pending.get("ticket") != ticket or _pending.get("kind") != kind: return false
	_paid_days[str(_pending.event)] = int(_pending.day)
	_last_receipt = event_id; _pending.clear()
	return true

func after_ambient(now_ms: float, unit: float, clock: RefCounted) -> void:
	var quiet: bool = not home_intent(clock).is_empty()
	if lively58_on():  # DSH_LIVELY58
		_rest_until_ms = now_ms + (LIVELY_REST_QUIET_MS if quiet else LIVELY_REST_MS) + clampf(unit, 0.0, 1.0) * LIVELY_REST_SPREAD_MS
		return
	_rest_until_ms = now_ms + (20000.0 if quiet else 8000.0) + clampf(unit, 0.0, 1.0) * 12000.0

func leisure_attempt(now_ms: float, arrived: bool = false) -> void:
	if lively58_on():  # DSH_LIVELY58
		_leisure_retry_ms = now_ms + (LIVELY_RETRY_ARRIVED_MS if arrived else LIVELY_RETRY_MS)
		return
	_leisure_retry_ms = now_ms + (120000.0 if arrived else 45000.0)

func ambient_choices(clock: RefCounted) -> Array:
	return ["bench", "phone", "book", "watch", "look_far"] if not home_intent(clock).is_empty() else []

func clear() -> void:
	_pending.clear(); _paid_days.clear(); _last_intent.clear(); _rest_until_ms = 0.0; _leisure_retry_ms=0.0

func snapshot() -> Dictionary:
	return {"source_id": _source_id, "profile": _profile.duplicate(), "paid_days": _paid_days.duplicate(),
		"pending": _pending.duplicate(), "intent": _last_intent.duplicate(), "rest_until_ms": _rest_until_ms,"leisure_retry_ms":_leisure_retry_ms,
		"clock_owner": "mafiozi_visual_clock", "random_world_targets": false}
