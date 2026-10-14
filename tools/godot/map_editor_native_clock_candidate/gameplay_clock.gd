extends RefCounted
## Diagnostic-only active-time clock for one actual main/practice-host life.
var _owner: WeakRef
var _host: WeakRef
var _generation := -1
var _paused_total_ms := 0.0
var _pause_wall_ms := -1.0
var _last_ms := 0.0
var _serial := 0
var _resume_boundary_pending := false

func bind(owner: Node3D, host: Node, generation: int) -> bool:
	if _owner != null or not is_instance_valid(owner) or not is_instance_valid(host) or generation < 1: return false
	_owner = weakref(owner); _host = weakref(host); _generation = generation
	return true

func _live() -> bool:
	if _owner == null or _host == null: return false
	var owner: Variant = _owner.get_ref()
	var host: Variant = _host.get_ref()
	return is_instance_valid(owner) and is_instance_valid(host) and not owner.is_queued_for_deletion() and not host.is_queued_for_deletion() and owner.is_inside_tree() and host.get_parent() == owner and owner.preview_melee == host and int(owner.get_meta("gameplay_clock_generation", -1)) == _generation and host.gameplay_clock == self

func now_ms() -> float:
	if not _live(): return NAN
	# The owner can inspect the exact release boundary once before any active
	# source step; subsequent reads advance from the resumed wall clock.
	if _resume_boundary_pending:
		_resume_boundary_pending = false
		return _last_ms
	var wall_ms := _pause_wall_ms if _pause_wall_ms >= 0.0 else Time.get_ticks_usec() / 1000.0
	_last_ms = maxf(_last_ms, wall_ms - _paused_total_ms)
	return _last_ms

func pause(owner: Node3D, host: Node) -> Dictionary:
	if not _live() or owner != _owner.get_ref() or host != _host.get_ref() or _pause_wall_ms >= 0.0 or owner.get_tree().paused:
		return {"ok":false,"reason":"owner_or_nested_pause"}
	_pause_wall_ms = Time.get_ticks_usec() / 1000.0
	_resume_boundary_pending = false
	var at_ms := now_ms()
	_serial += 1
	return {"ok":true,"clock":self,"owner_id":owner.get_instance_id(),"host_id":host.get_instance_id(),"generation":_generation,"serial":_serial,"at_ms":at_ms}

func receipt_live(receipt: Dictionary) -> bool:
	return _live() and _pause_wall_ms >= 0.0 and receipt.get("ok") == true and receipt.get("clock") == self and receipt.get("owner_id") == _owner.get_ref().get_instance_id() and receipt.get("host_id") == _host.get_ref().get_instance_id() and receipt.get("generation") == _generation and receipt.get("serial") == _serial

func resume(receipt: Dictionary) -> bool:
	if not receipt_live(receipt): return false
	_paused_total_ms += maxf(0.0, Time.get_ticks_usec() / 1000.0 - _pause_wall_ms)
	_pause_wall_ms = -1.0
	_resume_boundary_pending = true
	return true

func is_paused() -> bool: return _pause_wall_ms >= 0.0
