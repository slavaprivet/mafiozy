extends RefCounted
## Input projection only. Source bridge owns attack admission, timing and choice.
## Port of assets/maps/city_rebuild_v1/world_walk_melee_input.mjs.
const PORTS := ["beginWalkMelee", "setWalkMeleeCharge", "setWalkMeleeBlock"]
var _ports: Dictionary = {}
var _owner: WeakRef
var _now: Callable
var _configured := false
var _disposed := false
var _busy := false
var _fault := ""
var _clock := 0.0
var _held := false
var _pressed_at: Variant = null
var _spent := false
var _blocking := false
var _current: Dictionary = {}
var _sequence: Variant = 0
var _side := 1
var _reserved_heavy := false
var _context := {"allowed":true,"armed":false,"airborne":false,"yaw":0.0,"airHeight":0.0}
var _calls := 0

func configure(ports: Dictionary, now_seconds: Callable = Callable()) -> Dictionary:
	if _configured or _disposed or _busy or not Thread.is_main_thread(): return _error("configuration")
	var bound: Object = null
	for key: String in PORTS:
		var port: Variant = ports.get(key)
		if not port is Callable or not port.is_valid(): return _error("missing_bridge:"+key)
		if port.get_argument_count() != 1: return _error("bridge_arity:"+key)
		var object: Object = port.get_object()
		if not is_instance_valid(object) or object == self or object is Node and object.is_queued_for_deletion(): return _error("bridge_owner")
		if bound != null and object != bound: return _error("mixed_bridge_owners")
		bound = object
	if not now_seconds.is_null() and not _clock_live(now_seconds): return _error("clock_owner")
	if not now_seconds.is_null() and now_seconds.get_argument_count() != 0: return _error("clock_arity")
	_owner = weakref(bound)
	for key: String in PORTS: _ports[key] = ports[key]
	_now = now_seconds
	_configured = true
	return {"ok":true}

static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _clock_live(callback: Callable) -> bool:
	if not callback.is_valid(): return false
	var owner: Object = callback.get_object()
	return not owner is Node or not owner.is_queued_for_deletion()

func _error(reason: String) -> Dictionary:
	return {"valid":false,"error":reason,"may_have_dispatched":_busy and _calls > 0}

func _live() -> bool:
	if _owner == null or not is_instance_valid(_owner.get_ref()): return false
	if _owner.get_ref() is Node and _owner.get_ref().is_queued_for_deletion(): return false
	for key: String in PORTS:
		var port: Callable = _ports[key]
		if not port.is_valid() or port.get_object() != _owner.get_ref(): return false
	return true

func _enter() -> bool:
	if _busy:
		_fault = "reentry"
		return false
	if not Thread.is_main_thread(): return false
	if not _configured or _disposed or not _fault.is_empty(): return false
	if not _live(): _fault = "bridge_lifetime"; return false
	_busy = true; _calls = 0
	return true

func _entry_error() -> Dictionary:
	return _error(_fault if not _fault.is_empty() else "unavailable")

func _call_port(key: String, argument: Variant) -> Variant:
	if not _fault.is_empty(): return null
	if not _live(): _fault = "bridge_lifetime"; return null
	_calls += 1
	var result: Variant = (_ports[key] as Callable).call(argument)
	if not _live(): _fault = "bridge_lifetime"
	# Actual source charge/block setters always acknowledge with bool (false is
	# a valid source refusal). Godot callback errors return null instead of
	# unwinding this caller; never dispatch a begin after a failed setter.
	if _fault.is_empty() and key != "beginWalkMelee" and not result is bool:
		_fault = "bridge_ack:"+key
	return result

func _finish(time: float, started: bool = false) -> Dictionary:
	var result: Dictionary = _snapshot(time,started) if _fault.is_empty() else _error(_fault)
	_busy = false
	return result

func _options_valid(options: Dictionary) -> bool:
	for key: String in ["allowed","armed","airborne","blocked","cancelled"]:
		if options.has(key) and not options[key] is bool: return false
	for key: String in ["yaw","airHeight"]:
		if options.has(key) and not (options[key] is float or options[key] is int): return false
	return true

func _time_of(value: Variant) -> float:
	var time: Variant = value
	if not _finite(time):
		if _now.is_null(): time = Time.get_ticks_usec()/1000000.0
		elif not _clock_live(_now): _fault = "clock_lifetime"; return _clock
		else:
			time = _now.call()
			if not _clock_live(_now): _fault = "clock_lifetime"; return _clock
			if not _live(): _fault = "bridge_lifetime"; return _clock
	if not _finite(time): _fault = "finite_time_required"; return _clock
	_clock = maxf(_clock,float(time))
	return _clock

func _update(options: Dictionary) -> void:
	for key: String in _context:
		if options.has(key): _context[key] = options[key]
	if options.get("blocked") == true: _context.allowed = false

func _permitted() -> bool:
	return _context.allowed != false and not _context.armed

func _clear_hold() -> void:
	if not _reserved_heavy and (_held or _pressed_at != null): _call_port("setWalkMeleeCharge",false)
	_held = false; _pressed_at = null; _spent = false

func _clear_all() -> void:
	if _reserved_heavy: _call_port("setWalkMeleeCharge",false)
	_reserved_heavy = false
	_clear_hold()
	_call_port("setWalkMeleeBlock",false)
	_blocking = false; _current = {}

func _expire(time: float) -> void:
	if not _current.is_empty() and time-float(_current.time) >= float(_current.duration):
		if _reserved_heavy: _call_port("setWalkMeleeCharge",false)
		_reserved_heavy = false; _current = {}

func _begin(time: float, heavy: bool = false) -> bool:
	var yaw: float = float(_context.yaw) if _finite(_context.yaw) else 0.0
	var result: Variant = _call_port("beginWalkMelee",{"angle":PI/2-yaw,"airborne":_context.airborne,"heavy":heavy})
	if not _fault.is_empty(): return false
	if not result is Dictionary or not result.get("accepted",false) or not _finite(result.get("duration")) or float(result.duration) <= 0: return false
	# Native host boundary: a successful bridge reply must contain copied scalar
	# metadata. No arbitrary objects, unbounded windows or borrowed source arrays.
	var window: Variant = result.get("contactWindow",[])
	if not window is Array or window.size() > 16 or not result.get("type") is String or not _finite(result.get("seq")) or not _finite(result.get("startAt")) or not _finite(result.get("side")):
		_fault = "bridge_reply"; return false
	for item: Variant in window:
		if not _finite(item): _fault = "bridge_reply"; return false
	_reserved_heavy = heavy
	_side = -1 if result.side < 0 else 1
	_sequence = result.seq
	var air_height: float = float(_context.airHeight)
	if is_nan(air_height): air_height = 0.0
	_current = {"id":result.seq,"seq":result.seq,"type":result.type,"time":time,"sourceStartAt":result.startAt,"duration":result.duration,"side":_side,"yaw":yaw,"airHeight":maxf(0.0,air_height),"contactWindow":window.duplicate()}
	return true

func _snapshot(time: float, started: bool = false) -> Dictionary:
	var active := not _current.is_empty() and time-float(_current.time) < float(_current.duration)
	var charge: float = clampf((time-float(_pressed_at))/1.2,0,1) if _held and not _spent and not _blocking and _pressed_at != null else 0.0
	return {"action":{"type":_current.type if active else "none","progress":clampf((time-float(_current.time))/float(_current.duration),0,1) if active else 0.0,"side":_side,"blocking":_blocking,"charge":charge},"start":_current.duplicate(true) if active else null,"started":started,"held":_held,"sequence":_sequence}

func _input(method: String, options: Dictionary) -> Dictionary:
	if not _enter(): return _entry_error()
	if not _options_valid(options):
		_busy = false
		return _error("options")
	var time := _time_of(options.get("time"))
	if not _fault.is_empty(): return _finish(time)
	_update(options); _expire(time)
	if not _permitted(): _clear_all(); return _finish(time)
	var started := false
	if method == "press":
		if _held or _blocking: return _finish(time)
		if _context.airborne: return _finish(time,_current.is_empty() and _begin(time))
		_held = true; _pressed_at = time; _spent = false
		_call_port("setWalkMeleeCharge",true)
		started = _current.is_empty() and _begin(time)
	elif method == "release":
		var earned: bool = _held and not _spent and not _blocking and not _context.airborne and not options.get("cancelled",false) and _pressed_at != null and time-float(_pressed_at) >= 1.2
		started = earned and _current.is_empty() and _begin(time,true)
		_clear_hold()
	else:
		var buttons: Variant = options.get("buttons")
		# JS bitwise ToInt32 retains the low bit. Float64 integers at/above
		# 2^53 are all even; avoid converting those values to a native int64.
		if _finite(buttons) and floorf(float(buttons)) == float(buttons) and (absf(float(buttons)) >= 9007199254740992.0 or (int(buttons)&1) == 0): _clear_hold()
		if _context.airborne: _clear_hold(); return _finish(time)
		if _held and not _spent and not _blocking and _current.is_empty() and _pressed_at != null and time-float(_pressed_at) >= 1.2:
			_spent = true; started = _begin(time,true)
			if not started: _call_port("setWalkMeleeCharge",false)
	return _finish(time,started)

func press(options: Dictionary = {}) -> Dictionary: return _input("press",options)
func release(options: Dictionary = {}) -> Dictionary: return _input("release",options)
func step(options: Dictionary = {}) -> Dictionary: return _input("step",options)

func cancel() -> Dictionary:
	if not _enter(): return _entry_error()
	_clear_all()
	return _finish(_clock)

func block(value: bool) -> Dictionary:
	if not _enter(): return _entry_error()
	var response: Variant = _call_port("setWalkMeleeBlock",true) if value and _permitted() else false
	_blocking = response is bool and response == true
	if not value: _call_port("setWalkMeleeBlock",false)
	if _blocking:
		if _reserved_heavy: _call_port("setWalkMeleeCharge",false)
		_reserved_heavy = false; _clear_hold(); _current = {}
	return _finish(_clock)

func dispose() -> Dictionary:
	if not Thread.is_main_thread(): return _error("unavailable")
	if _busy: _fault = "reentry"; return _error(_fault)
	# Explicit cancel must precede disposal while source owner is still alive.
	# Destruction cannot authorize a new source mutation or release a newer life.
	_disposed = true; _ports.clear(); _owner = null; _now = Callable(); _current.clear()
	return {"ok":true}
