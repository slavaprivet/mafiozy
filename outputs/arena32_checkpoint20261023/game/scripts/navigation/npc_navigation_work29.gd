extends RefCounted
## Capacity/accounting adapter, NOT a second authority queue. Existing city Queue
## owns admission/fairness; callers MUST reserve/finish it around actual work.
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const MAX_MAPS := 8
const MAX_GUIDES := 384
const MAX_INFLIGHT := 2
const MAX_SUBMITS_PER_FRAME := 1
const PREPARE_US := 600
const PREPARE_ITEMS := 64
static var _maps: Dictionary = {}
static var _pending: Dictionary = {}
static var _guides: Dictionary = {}
static var _ticket := 0
static var _frame := -1
static var _submitted := 0
static var _prepare_us := 0
static var _prepare_items := 0
static var _max_inflight := 0
static var _max_prepare_us := 0
static var _max_prepare_items := 0
static var _started := 0
static var _completed := 0
static var _dropped_callbacks := 0

static func _refresh() -> void:
	var frame: int=Engine.get_physics_frames()
	if _frame==frame:return
	_frame=frame;_submitted=0;_prepare_us=0;_prepare_items=0

## Only the already-authoritative backend binds its actual queue for this map.
static func bind_map(map: RID, queue: RefCounted) -> bool:
	if not Thread.is_main_thread() or not map.is_valid() or not queue is Queue or queue._disposed or not queue._native_enabled:return false
	var retired: Array=[]
	for key: int in _maps:
		var existing: RefCounted=_maps[key].queue.get_ref()
		if existing==null or existing._disposed or not NavigationServer3D.get_maps().has(_maps[key].map):retired.append(key)
	for key: int in retired:_maps.erase(key)
	var key: int=map.get_id()
	if _maps.has(key):return _maps[key].map==map and _maps[key].queue.get_ref()==queue
	if _maps.size()>=MAX_MAPS:return false
	_maps[key]={"map":map,"queue":weakref(queue)}
	return true

static func queue_for_map(map: RID) -> RefCounted:
	if not _maps.has(map.get_id()):return null
	var entry: Dictionary=_maps[map.get_id()]
	var queue: RefCounted=entry.queue.get_ref()
	return queue if entry.map==map and queue!=null and not queue._disposed else null

static func can_submit() -> bool:
	_refresh()
	return Thread.is_main_thread() and _pending.size()<MAX_INFLIGHT and _submitted<MAX_SUBMITS_PER_FRAME

static func claim_guide(guide: RefCounted) -> bool:
	var stale: Array=[]
	for key: int in _guides:
		if _guides[key].get_ref()==null:stale.append(key)
	for key: int in stale:_guides.erase(key)
	var key: int=guide.get_instance_id()
	if _guides.has(key):return true
	if _guides.size()>=MAX_GUIDES:return false
	_guides[key]=weakref(guide)
	return true

static func release_guide(guide: RefCounted) -> void:
	_guides.erase(guide.get_instance_id())

## Internal permit operation is also used by the synthetic callback fixture.
## Cancellation NEVER releases it: the actual engine query is still outstanding.
static func _allocate(receiver: RefCounted, method: StringName, arguments: Array) -> int:
	if not can_submit() or receiver==null or not receiver.has_method(method):return 0
	_ticket+=1;_submitted+=1;_started+=1
	_pending[_ticket]={"receiver":weakref(receiver),"method":method,"args":arguments.duplicate(),"submitted_ms":Time.get_ticks_msec()}
	_max_inflight=maxi(_max_inflight,_pending.size())
	return _ticket

static func submit(parameters: NavigationPathQueryParameters3D, receiver: RefCounted, method: StringName, arguments: Array) -> int:
	var ticket: int=_allocate(receiver,method,arguments)
	if ticket==0:return 0
	var result:=NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(parameters,result,_callback.bind(ticket,result))
	return ticket

static func _callback(ticket: int, result: NavigationPathQueryResult3D) -> void:
	# Native completion may originate from a worker. All state remains main-thread.
	_complete.call_deferred(ticket,result)

static func _complete(ticket: int, result: NavigationPathQueryResult3D) -> void:
	if not _pending.has(ticket):return
	var entry: Dictionary=_pending[ticket]
	_pending.erase(ticket);_completed+=1
	var receiver: RefCounted=entry.receiver.get_ref()
	if receiver==null or not receiver.has_method(entry.method):
		_dropped_callbacks+=1
		return
	var arguments: Array=entry.args
	arguments.append(result)
	receiver.callv(entry.method,arguments)

static func prepare_allowed() -> bool:
	_refresh()
	return _prepare_us<PREPARE_US and _prepare_items<PREPARE_ITEMS

static func charge_prepare(started_us: int, items: int) -> void:
	_refresh()
	_prepare_us+=maxi(0,Time.get_ticks_usec()-started_us)
	_prepare_items+=items
	_max_prepare_us=maxi(_max_prepare_us,_prepare_us)
	_max_prepare_items=maxi(_max_prepare_items,_prepare_items)

static func diagnostics() -> Dictionary:
	_refresh()
	var oldest_ms := 0
	for entry: Dictionary in _pending.values():oldest_ms=maxi(oldest_ms,Time.get_ticks_msec()-int(entry.submitted_ms))
	return {"frame":_frame,"inflight":_pending.size(),"max_inflight":_max_inflight,
		"submitted_this_frame":_submitted,"max_submits_per_frame":MAX_SUBMITS_PER_FRAME,
		"prepare_us":_prepare_us,"prepare_items":_prepare_items,"max_prepare_us":_max_prepare_us,
		"max_prepare_items":_max_prepare_items,"prepare_budget_us":PREPARE_US,
		"started":_started,"completed":_completed,"dropped_callbacks":_dropped_callbacks,
		"authority_maps":_maps.size(),"guides":_guides.size(),"oldest_native_ms":oldest_ms,"soft_deadline":true,"cancel_keeps_native_permit":true}
