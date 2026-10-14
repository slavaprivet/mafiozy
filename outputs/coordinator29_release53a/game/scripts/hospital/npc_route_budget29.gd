extends RefCounted
## One main-thread planning budget for the whole physics frame, not per resident.
## Jobs are weak references; this service never owns a route or an actor.
## A single physics query cannot be interrupted, so FRAME_US is a soft deadline.
const FRAME_US := 1800
const MAX_UNITS_PER_FRAME := 128
const MAX_JOBS := 384
const MAX_NODES := 65536
const MAX_HEAP_ITEMS := 131072
## Explicit lifecycle cancellation is immediate. This fallback permits sliced/LOD
## callers; it is not a death detector or permission to omit cancel().
const STALE_CALLER_FRAMES := 120
static var _jobs: Dictionary = {}
static var _order: Array[int] = []
static var _nodes := 0
static var _heap_items := 0
static var _frame := -1
static var _pumping := false
static var _last_us := 0
static var _max_us := 0
static var _last_units := 0
static var _max_unit_us := 0
static var _rejected := 0
static var _retired := 0

static func enqueue(job: RefCounted) -> bool:
	var key: int = job.get_instance_id()
	release(job)
	if _jobs.size() >= MAX_JOBS:
		_rejected += 1
		return false
	_jobs[key] = {"ref":weakref(job), "touch":Engine.get_physics_frames(), "nodes":0, "heap":0}
	_order.append(key)
	return true

static func touch(job: RefCounted) -> void:
	var key: int = job.get_instance_id()
	if _jobs.has(key): _jobs[key].touch = Engine.get_physics_frames()

static func _remove(key: int) -> void:
	if not _jobs.has(key): return
	_nodes -= int(_jobs[key].nodes)
	_heap_items -= int(_jobs[key].heap)
	_jobs.erase(key)
	_order.erase(key)

static func release(job: RefCounted) -> void:
	_remove(job.get_instance_id())

## Reserve before adding a node/heap item. Negative deltas release popped items.
static func claim(job: RefCounted, nodes_delta: int, heap_delta: int) -> bool:
	var key: int = job.get_instance_id()
	if not _jobs.has(key): return false
	var entry: Dictionary = _jobs[key]
	if _nodes + nodes_delta > MAX_NODES or _heap_items + heap_delta > MAX_HEAP_ITEMS: return false
	if int(entry.nodes) + nodes_delta < 0 or int(entry.heap) + heap_delta < 0: return false
	entry.nodes = int(entry.nodes) + nodes_delta
	entry.heap = int(entry.heap) + heap_delta
	_nodes += nodes_delta
	_heap_items += heap_delta
	return true

static func pump() -> void:
	var frame: int = Engine.get_physics_frames()
	if _pumping or _frame == frame: return
	_frame = frame
	_pumping = true
	var started: int = Time.get_ticks_usec()
	var deadline: int = started + FRAME_US
	_last_units = 0
	# Bounded ring; rotate after EACH partial expansion, independent of caller order.
	while not _order.is_empty() and _last_units < MAX_UNITS_PER_FRAME and Time.get_ticks_usec() < deadline:
		var key: int = _order.pop_front()
		if not _jobs.has(key): continue
		var entry: Dictionary = _jobs[key]
		var job: RefCounted = entry.ref.get_ref()
		if job == null:
			_remove(key)
			_retired += 1
			continue
		if frame - int(entry.touch) > STALE_CALLER_FRAMES or not job._budget_live():
			job.cancel()
			_remove(key)
			_retired += 1
			continue
		var before: int = Time.get_ticks_usec()
		job._budget_step()
		_max_unit_us = maxi(_max_unit_us, Time.get_ticks_usec() - before)
		_last_units += 1
		if _jobs.has(key): _order.append(key)
	_last_us = Time.get_ticks_usec() - started
	_max_us = maxi(_max_us, _last_us)
	_pumping = false

static func diagnostics() -> Dictionary:
	return {"jobs":_jobs.size(), "nodes":_nodes, "heap_items":_heap_items,
		"frame":_frame, "frame_us":_last_us, "max_frame_us":_max_us,
		"units":_last_units, "max_unit_us":_max_unit_us,
		"budget_us":FRAME_US, "max_jobs":MAX_JOBS, "max_nodes":MAX_NODES,
		"max_heap_items":MAX_HEAP_ITEMS, "rejected":_rejected, "retired":_retired,
		"soft_deadline":true}
