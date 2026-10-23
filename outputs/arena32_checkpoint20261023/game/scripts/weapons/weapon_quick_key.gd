extends RefCounted
## Exact source tap/hold state machine. The host supplies its real monotonic
## clock (milliseconds), scheduler and cancellation; no synthetic input loop.
class Press extends RefCounted:
	var started: float
	var fired := false
	var timer: Variant = null
var _press: Press
var _tap: Callable
var _hold: Callable
var _enabled: Callable
var _now: Callable
var _schedule: Callable
var _cancel: Callable
var _hold_ms := 200.0
var _configured := false

func configure(on_tap: Callable, on_hold: Callable, enabled: Callable, now: Callable, schedule: Callable, cancel_timer: Callable, hold_ms: float = 200) -> bool:
	if not on_tap.is_valid() or not on_hold.is_valid() or not enabled.is_valid() or not now.is_valid() or not schedule.is_valid() or not cancel_timer.is_valid() or not is_finite(hold_ms) or hold_ms < 0: return false
	cancel()
	_tap=on_tap;_hold=on_hold;_enabled=enabled;_now=now;_schedule=schedule;_cancel=cancel_timer;_hold_ms=hold_ms;_configured=true
	return true

func cancel() -> void:
	if _press != null and _press.timer != null: _cancel.call(_press.timer)
	_press=null

func _timeout(state: Press) -> void:
	if _press != state or state.fired or not _enabled.call(): return
	state.fired=true
	_hold.call()

func down(repeat: bool = false) -> bool:
	if not _configured or repeat or _press != null or not _enabled.call(): return false
	var state := Press.new()
	state.started=float(_now.call());_press=state
	state.timer=_schedule.call(_timeout.bind(state),_hold_ms)
	return true

func up() -> bool:
	if _press == null: return false
	var state := _press
	cancel()
	if not _enabled.call() or state.fired: return true
	if float(_now.call())-state.started >= _hold_ms: _hold.call()
	else: _tap.call()
	return true

func pressed() -> bool:
	return _press != null

func dispose() -> void:
	cancel();_configured=false
	_tap=Callable();_hold=Callable();_enabled=Callable();_now=Callable();_schedule=Callable();_cancel=Callable()
