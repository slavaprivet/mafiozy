extends RefCounted
## Exact admission/cohort slice of world.html; NOT a pathfinder.
## Owner identity is object identity, never a render node or normalized source ID.
## Main-thread, non-reentrant API. Clock must return monotonic integer microseconds.

class Owner extends RefCounted:
	var _source_id: String
	var _life_generation: int
	var source_id: String:
		get: return _source_id
	var life_generation: int:
		get: return _life_generation
	var dead := false
	var empire_route_queued := false
	var empire_pending_route := false
	var search_pending := false
	var continuation: Variant = null
	var search_kind: Variant = null
	var request_at: Variant = null
	var attempt_us := 0
	var admitted_us := 0
	var wait_start_us := 0
	var last_wait_us := 0
	var last_cpu_us := 0
	var total_cpu_us := 0
	var quanta := 0
	func _init(id: String, generation: int = 1) -> void:
		_source_id = id
		_life_generation = generation

var _clock: Callable
var _native_enabled := true
var _disposed := false
var _busy := false
var _last_clock := -1
var _frame: Variant = null
var _deadline := 0
var _count := 0
var _epoch := 0
var _used := 0
var _started: Variant = null
var _current: Owner = null
var _queue: Dictionary = {}
var _served: Dictionary = {}
var _batch: Dictionary = {}
var _batch_count := 0
var _stats := {"admitted": 0, "deferred": 0, "expired": 0}
var rejected_calls := 0

func _init(clock_usec: Callable = Callable(), native_enabled: bool = true) -> void:
	_clock = clock_usec
	_native_enabled = native_enabled

func _enter() -> bool:
	if not Thread.is_main_thread():
		return false
	if _busy or _disposed:
		rejected_calls += 1
		return false
	_busy = true
	return true

func _now() -> int:
	var value: Variant = _clock.call() if _clock.is_valid() else Time.get_ticks_usec()
	if not value is int or value < 0 or value < _last_clock:
		rejected_calls += 1
		return -1
	_last_clock = value
	return value

func _finish_at(now: int) -> void:
	if _started == null:
		return
	var elapsed: int = maxi(0, now - int(_started))
	_used += elapsed
	if _current != null:
		_current.last_cpu_us = elapsed
		_current.total_cpu_us += elapsed
		_current.quanta += 1
	_current = null
	_started = null
	_deadline = 0

func _head() -> Owner:
	# Dictionary iteration preserves insertion order without allocating keys().
	for actor: Owner in _queue:
		return actor
	return null

func reserve(frame_id: int, owner: Owner = null) -> bool:
	if not _enter():
		return false
	if owner != null and (owner.source_id.is_empty() or owner.life_generation < 1):
		rejected_calls += 1
		_busy = false
		return false
	if not _native_enabled:
		_busy = false
		return true
	var now := _now()
	if now < 0:
		_busy = false
		return false
	var new_frame: bool = _frame == null or frame_id != _frame
	if new_frame:
		_frame = frame_id
		_deadline = 0
		_used = 0
		_started = null
		_current = null
		_count = 0
		_epoch += 1
		_served.clear()
	else:
		_finish_at(now)
	if owner != null:
		owner.attempt_us = now
		if not _queue.has(owner):
			owner.wait_start_us = now
		_queue[owner] = _epoch
		if _queue.size() > 512:
			_queue.erase(_head())
	if new_frame:
		# Erasing during Dictionary iteration is undefined; collect removals first.
		var expired_owners: Array = []
		for actor: Owner in _queue:
			if actor.dead or (_epoch - int(_queue[actor]) > 1 and not (actor.empire_route_queued and actor.empire_pending_route)):
				expired_owners.append(actor)
		for actor: Owner in expired_owners:
			_queue.erase(actor)
			_batch.erase(actor)
		var removed: Array = []
		for actor: Owner in _batch:
			if not _queue.has(actor):
				removed.append(actor)
		for actor: Owner in removed:
			_batch.erase(actor)
		if _batch.is_empty():
			_batch_count = 0
	if _batch.is_empty():
		_batch_count = 0
	var head := _head()
	while head != null and head.dead:
		_queue.erase(head)
		_batch.erase(head)
		head = _head()
	for actor: Owner in _queue:
		if _batch_count >= 8:
			break
		if not _batch.has(actor) and not _served.has(actor):
			_batch[actor] = true
			_batch_count += 1
	if _count >= 8 or _used >= 4000 or (owner != null and (_served.has(owner) or not _batch.has(owner))) or (owner == null and head != null):
		_stats.deferred += 1
		_busy = false
		return false
	_current = owner
	_started = now
	_deadline = now + maxi(0, 4000 - _used)
	if owner != null:
		owner.last_wait_us = maxi(0, now - owner.wait_start_us)
		owner.admitted_us = now
		_queue.erase(owner)
		_batch.erase(owner)
		_served[owner] = true
	_count += 1
	_stats.admitted += 1
	_busy = false
	return true

func finish() -> bool:
	if not _enter():
		return false
	var now := _now()
	if now >= 0:
		_finish_at(now)
	_busy = false
	return now >= 0

func expired() -> bool:
	if not _enter():
		return true # Invalid host access cannot authorize additional work.
	if not _native_enabled or _deadline <= 0:
		_busy = false
		return false
	var now := _now()
	var result: bool = now < 0 or (_native_enabled and _deadline > 0 and now >= _deadline)
	if result and now >= 0:
		_stats.expired += 1
	_busy = false
	return result

func cancel(owner: Owner) -> bool:
	if not _enter():
		return false
	if owner == null:
		rejected_calls += 1
		_busy = false
		return false
	owner.search_pending = false
	owner.continuation = null
	owner.search_kind = null
	owner.request_at = null
	_queue.erase(owner)
	_batch.erase(owner)
	# Source retains current/served until finish/frame change, even after cancel.
	_busy = false
	return true

func diagnostics() -> Dictionary:
	if not _enter():
		return {"error": "unavailable"}
	var result := {"frame": _frame, "epoch": _epoch, "deadline_us": _deadline,
		"used_us": _used, "count": _count, "batch_count": _batch_count,
		"queue_size": _queue.size(), "batch_size": _batch.size(), "served_size": _served.size(),
		"started_us": _started, "current": "" if _current == null else _current.source_id,
		"stats": _stats.duplicate(), "queue": [], "batch": [], "served": []}
	for actor: Owner in _queue:
		result.queue.append(actor.source_id)
	for actor: Owner in _batch:
		result.batch.append(actor.source_id)
	for actor: Owner in _served:
		result.served.append(actor.source_id)
	_busy = false
	return result

func dispose() -> bool:
	if not _enter():
		return false
	_queue.clear()
	_batch.clear()
	_served.clear()
	_current = null
	_clock = Callable()
	_started = null
	_deadline = 0
	_disposed = true
	_busy = false
	return true
