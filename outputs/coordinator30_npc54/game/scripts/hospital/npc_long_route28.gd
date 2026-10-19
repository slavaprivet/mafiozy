extends RefCounted
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Work = preload("res://scripts/navigation/npc_navigation_work29.gd")
## Bounded distant-route GUIDE over the already-published city navigation map.
## Never moves a body or grants admission. Each waypoint must be planned/walked
## by the existing live full-capsule local solver (including shoreline admission).
## Backend/API limits match npc_city_engine_navigation.gd's native query contract.
const LOCAL_ONLY_M := 75.0
const LEG_M := 24.0
## Service approaches must never expand the whole 75m legacy local domain.
const SERVICE_LOCAL_M := LEG_M
const MAX_QUERY_POLYGONS := 8192
const MAX_ROUTE_M := 2000.0
const MAX_RAW_POINTS := 4096
const MAX_WAYPOINTS := 512
const QUERY_TIMEOUT_MS := 5000
const PREPARE_US := 600
const PREPARE_ITEMS := 64
const MAX_REQUERIES := 1
const QUEUE_TIMEOUT_MS := 15000
const PREPARE_TIMEOUT_MS := 15000
const PREPARE_QUANTUM := 8
var status := "idle"
var reason := ""
var revision := 0
var _body: WeakRef
var _body_id := 0
var _map := RID()
var _iteration := 0
var _goal := Vector3.ZERO
var _query_start := Vector3.ZERO
var _phase := "idle"
var _serial := 0
var _requeries := 0
var _submitted_ms := 0
var _next_map_check_ms := 0
var _distant := false
var _local_only_m := LOCAL_ONLY_M
var _raw := PackedVector3Array()
var _raw_index := 0
var _cursor := Vector3.ZERO
var _points: Array[Vector3] = []
var _index := 0
var _metres := 0.0
var _prepare_max_us := 0
var _submit_us := 0
var _query_wall_ms := 0
var _stale_callbacks := 0
var _last_retry_reason := ""
var _queue_ref: WeakRef
var _owner: RefCounted
var _ticket := 0
var _queued_ms := 0
var _wait_reason := ""
var _queue_wait_ms := 0
var _work_units := 0
var _work_us := 0
var _progress_revision := 0
var _pending_result: NavigationPathQueryResult3D
var _prepare_started_ms := 0
var _physical30: WeakRef
var _repair_pending30 := false
var _repair_raw30 := Vector3.ZERO
var _repair_length30 := 0.0
var _repair_index30 := 0
var _repair_probes30 := 0
var _repaired30 := 0
const REPAIR_RADII30 := [1.0,2.0,4.0,6.0]

func _queue() -> RefCounted:
	var queue: RefCounted=_queue_ref.get_ref() if _queue_ref!=null else null
	return queue if queue!=null and not queue._disposed else null

func _retire_owner() -> void:
	var queue: RefCounted=_queue()
	if _owner!=null:
		_owner.dead=true
		if queue!=null:queue.cancel(_owner)
	_owner=null
	Work.release_guide(self)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _actor() -> CharacterBody3D:
	if _body == null: return null
	var actor: Variant = _body.get_ref()
	if not actor is CharacterBody3D or not is_instance_valid(actor) or actor.get_instance_id() != _body_id or not actor.is_inside_tree() or actor.is_queued_for_deletion(): return null
	return actor

func _map_current() -> bool:
	# A nonzero RID can already have been freed by a map rebuild. Never query it
	# merely because RID.is_valid() is true; only the server's live maps qualify.
	return _map.is_valid() and NavigationServer3D.get_maps().has(_map)

func begin(actor: CharacterBody3D, map: RID, destination: Vector3, local_only_m: float = LOCAL_ONLY_M, physical: RefCounted = null) -> bool:
	cancel()
	if not is_instance_valid(actor) or not actor.is_inside_tree() or not destination.is_finite(): return _fail("invalid_actor_or_goal")
	if not is_finite(local_only_m) or local_only_m < LEG_M or local_only_m > LOCAL_ONLY_M: return _fail("invalid_local_domain")
	_local_only_m = local_only_m
	_physical30=weakref(physical) if physical!=null else null
	_repair_pending30=false;_repair_probes30=0;_repaired30=0
	_body = weakref(actor); _body_id = actor.get_instance_id(); _map = map; _goal = destination
	_query_start = actor.global_position; _requeries = 0; _metres = 0.0
	_prepare_max_us = 0; _submit_us = 0; _query_wall_ms = 0; _last_retry_reason = ""
	_work_units=0;_work_us=0;_queue_wait_ms=0;_progress_revision=0
	if _query_start.distance_to(_goal) > MAX_ROUTE_M: return _fail("destination_outside_query_bound")
	_distant = _flat(_query_start, _goal) > _local_only_m
	if not _distant:
		# Ordinary 5–15 m roam and final door/interior legs keep the current local solver.
		_points = [_goal]; _index = 0; _phase = "local"; status = "ready"; revision += 1
		return true
	return _submit()

func _fail(detail: String) -> bool:
	_retire_owner()
	status = "blocked"; reason = detail; _phase = "blocked"; revision += 1
	_raw.clear();_pending_result=null;_repair_pending30=false
	return false

func _submit() -> bool:
	var actor: CharacterBody3D = _actor()
	if actor == null: return _fail("actor_retired")
	if not _map_current(): return _fail("current_native_map_required_for_distant_route")
	_iteration = NavigationServer3D.map_get_iteration_id(_map)
	if _iteration <= 0: return _fail("native_map_not_published")
	_query_start = actor.global_position
	if _query_start.distance_to(_goal) > MAX_ROUTE_M: return _fail("destination_outside_query_bound")
	_retire_owner()
	var queue: RefCounted=Work.queue_for_map(_map)
	if queue==null:return _fail("authoritative_queue_not_bound")
	_queue_ref=weakref(queue)
	if not Work.claim_guide(self):return _fail("guide_capacity")
	_serial += 1; revision += 1
	_owner=Queue.Owner.new("guide29:"+str(_body_id)+":"+str(get_instance_id()),_serial)
	_points.clear(); _raw.clear(); _raw_index = 0; _index = 0; _metres = 0.0
	_repair_pending30=false
	_pending_result=null;_ticket=0
	_queued_ms=Time.get_ticks_msec();_queue_wait_ms=0;_wait_reason="authority_admission"
	status = "searching"; _phase = "query_queued"; reason = ""
	return true

func _try_submit() -> void:
	var queue: RefCounted=_queue()
	if queue==null:
		_fail("authoritative_queue_retired")
		return
	if not queue.reserve(Engine.get_physics_frames(),_owner):
		_wait_reason="authority_admission"
		return
	# Enrol in the real queue even when native capacity is full. Checking the
	# semaphore first would hide later callers from its cohort fairness.
	if not Work.can_submit():
		_wait_reason="native_capacity";queue.finish()
		return
	var actor: CharacterBody3D=_actor()
	if actor==null or not _map_current():
		_fail("actor_or_map_retired_before_submit");queue.finish()
		return
	_iteration=NavigationServer3D.map_get_iteration_id(_map)
	_query_start=actor.global_position
	if _iteration<=0 or _query_start.distance_to(_goal)>MAX_ROUTE_M:
		_fail("map_or_destination_invalid_before_submit");queue.finish()
		return
	var parameters := NavigationPathQueryParameters3D.new()
	parameters.map = _map
	parameters.start_position = _query_start
	parameters.target_position = _goal
	parameters.navigation_layers = 1
	parameters.path_search_max_polygons = MAX_QUERY_POLYGONS
	parameters.path_search_max_distance = MAX_ROUTE_M
	parameters.path_return_max_length = MAX_ROUTE_M
	parameters.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	_submitted_ms = Time.get_ticks_msec(); _next_map_check_ms = _submitted_ms + 1000
	var started: int = Time.get_ticks_usec()
	_ticket=Work.submit(parameters,self,&"_finish_query",[_serial,_iteration])
	_submit_us = Time.get_ticks_usec() - started
	queue.finish()
	if _ticket>0:
		_phase="query_wait";_wait_reason="native_result"
		_queue_wait_ms=_submitted_ms-_queued_ms;_progress_revision+=1

func _finish_query(serial: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	if serial != _serial or iteration != _iteration or status != "searching" or _phase != "query_wait":
		_stale_callbacks += 1
		return
	# Store only. Bounded result consumption and waypoint preparation require the
	# SAME authority reserve/finish as ordinary backend work, on a later tick.
	_ticket=0;_pending_result=result;_phase="result_ready";_wait_reason="prepare_admission"
	_query_wall_ms=Time.get_ticks_msec()-_submitted_ms
	_prepare_started_ms=Time.get_ticks_msec()
	_progress_revision+=1

func _consume_result() -> void:
	var actor: CharacterBody3D = _actor()
	if actor == null:
		_fail("actor_retired")
		return
	if not _map_current() or NavigationServer3D.map_get_iteration_id(_map) != _iteration:
		retry("map_changed_during_query")
		return
	if _flat(actor.global_position, _query_start) > .75:
		retry("actor_moved_during_query")
		return
	var proposal: PackedVector3Array = _pending_result.path
	if proposal.is_empty() or proposal.size() > MAX_RAW_POINTS or not is_finite(_pending_result.path_length) or _pending_result.path_length > MAX_ROUTE_M:
		_fail("native_proposal_empty_or_over_bound")
		return
	if not proposal[0].is_finite() or not proposal[-1].is_finite():
		_fail("native_proposal_nonfinite")
		return
	# Source nav may end just outside a new clone. A <=24 m connector is merely
	# proposed; the local solver still has to prove the whole capsule can traverse it.
	if _flat(_query_start, proposal[0]) > LEG_M or _flat(proposal[-1], _goal) > LEG_M or absf(proposal[0].y - _query_start.y) > .7 or absf(proposal[-1].y - _goal.y) > .7:
		_fail("native_partial_route_outside_local_connector")
		return
	_raw = proposal
	_raw.append(_goal)
	_raw_index = 0; _cursor = _query_start; _phase = "prepare";_pending_result=null

func tick() -> String:
	if status in ["idle", "cancelled", "blocked", "complete"]: return status
	if _actor() == null:
		_fail("actor_retired")
		return status
	var now: int = Time.get_ticks_msec()
	if _distant and _phase!="query_queued" and now >= _next_map_check_ms:
		_next_map_check_ms = now + 1000
		if not _map_current():
			_fail("native_map_retired")
			return status
		if NavigationServer3D.map_get_iteration_id(_map) != _iteration:
			retry("native_map_iteration_changed")
			return status
	if _phase == "query_wait" and now - _submitted_ms > QUERY_TIMEOUT_MS:
		retry("native_query_timeout")
		return status
	if _phase=="query_queued":
		_queue_wait_ms=now-_queued_ms
		if _queue_wait_ms>QUEUE_TIMEOUT_MS:_fail("authority_queue_timeout")
		else:_try_submit()
	if _phase in ["result_ready","prepare"]:
		if now-_prepare_started_ms>PREPARE_TIMEOUT_MS:_fail("prepare_queue_timeout")
		else:_prepare()
	return status

func _prepare() -> void:
	var queue: RefCounted=_queue()
	if queue==null:
		_fail("authoritative_queue_retired")
		return
	if not queue.reserve(Engine.get_physics_frames(),_owner):
		_wait_reason="authority_admission"
		return
	if not Work.prepare_allowed():
		_wait_reason="shared_prepare_budget";queue.finish()
		return
	var started: int = Time.get_ticks_usec()
	var items := 0
	_wait_reason=""
	while items<PREPARE_QUANTUM and Work.prepare_allowed() and not queue.expired() and _phase in ["result_ready","prepare"]:
		var unit_started: int=Time.get_ticks_usec()
		if _phase=="result_ready":_consume_result()
		else:_prepare_one()
		Work.charge_prepare(unit_started,1);items+=1;_work_units+=1;_progress_revision+=1
	var elapsed: int=Time.get_ticks_usec()-started
	_work_us+=elapsed;_prepare_max_us=maxi(_prepare_max_us,elapsed)
	queue.finish()

func _prepare_one() -> void:
	if _repair_pending30:
		_repair_one30()
		return
	if _raw_index < _raw.size():
		var endpoint: Vector3=_raw[_raw_index]
		if not endpoint.is_finite():
			_fail("native_proposal_nonfinite")
			return
		var length: float = _cursor.distance_to(endpoint)
		if length <= .001:
			_raw_index += 1
			return
		var point: Vector3 = _cursor.move_toward(endpoint, LEG_M)
		if _physical30!=null:
			_repair_raw30=point;_repair_length30=length;_repair_index30=0;_repair_pending30=true
			return
		_append_prepared30(point,point,length)
	_finish_prepare30()

## Source nav predates live clone geometry. Repair only a proposed intermediate
## checkpoint, never the final goal. Each probe consumes the existing queue's
## prepare quantum; actual traversal still belongs to the unchanged capsule A*.
func _repair_one30() -> void:
	var physical: RefCounted=_physical30.get_ref() if _physical30!=null else null
	if physical==null:_fail("physical_checkpoint_owner_retired30");return
	var previous: Vector3=_points[-1] if not _points.is_empty() else _query_start
	var candidate: Vector3=_repair_raw30
	var final_point: bool=_raw_index==_raw.size()-1 and _repair_length30<=LEG_M
	if _repair_index30>0:
		if final_point or _repair_index30>REPAIR_RADII30.size()*8:
			_fail("physical_guide_checkpoint_unavailable30");return
		var toward: Vector3=previous-_repair_raw30;toward.y=0.0
		if toward.length_squared()<.0001:toward=Vector3.RIGHT
		toward=toward.normalized()
		var index:int=_repair_index30-1
		var direction: Vector3=toward.rotated(Vector3.UP,float(index%8)*TAU/8.0)
		candidate+=direction*float(REPAIR_RADII30[index/8])
	_repair_index30+=1;_repair_probes30+=1
	if _flat(previous,candidate)>LEG_M+.001:return
	var supported: Variant=physical.floor_at(candidate,_repair_raw30.y)
	if not supported is Vector3 or absf(supported.y-_repair_raw30.y)>.5 or not physical.standing(supported):return
	if _flat(supported,_repair_raw30)>.01:_repaired30+=1
	_repair_pending30=false
	_append_prepared30(_goal if final_point else supported,_repair_raw30,_repair_length30)
	_finish_prepare30()

func _append_prepared30(point: Vector3, raw_point: Vector3, length: float) -> void:
	var previous: Vector3=_points[-1] if not _points.is_empty() else _query_start
	_metres+=previous.distance_to(point)
	if _metres>MAX_ROUTE_M or _points.size()>=MAX_WAYPOINTS:
		_fail("prepared_route_over_bound");return
	_points.append(point);_cursor=raw_point
	if length<=LEG_M:_raw_index+=1

func _finish_prepare30() -> void:
	if status == "blocked" or _raw_index < _raw.size(): return
	_raw.clear()
	if _points.is_empty(): _points.append(_goal)
	# Keep the exact supplied endpoint; do not substitute the navmesh projection.
	_points[-1] = _goal
	_index = 0; _phase = "following"; status = "ready"; revision += 1
	_retire_owner()

func waypoint() -> Variant:
	return _points[_index] if status == "ready" and _index < _points.size() else null

## Call only after the full-capsule local driver reports an actual arrival.
## "next" never means final goal completion; the caller must run the next local leg.
func advance(actual_position: Vector3) -> String:
	if status != "ready": return status
	var next: Variant = waypoint()
	if not actual_position.is_finite() or not next is Vector3 or _flat(actual_position, next) > .45 or absf(actual_position.y - next.y) > .5:
		_fail("local_arrival_not_at_guide_waypoint")
		return status
	if _distant:
		if not _map_current():
			_fail("native_map_retired")
			return status
		if NavigationServer3D.map_get_iteration_id(_map) != _iteration:
			retry("native_map_changed_at_checkpoint")
			return status
	_index += 1; revision += 1
	# New clones are not baked into the source navmesh. Once within the bounded
	# local domain, the exact live-physics route owns the complete final approach.
	if _index < _points.size() and _flat(actual_position,_goal)<=_local_only_m:
		_points=[_goal];_index=0
		return "next"
	if _index < _points.size(): return "next"
	status = "complete"; _phase = "complete"
	return "complete"

## At most one native requery per outer leg. Local moving-obstacle retries normally
## stay with the same waypoint; this is for stale maps or an exhausted local detour.
func retry(detail: String) -> bool:
	if not _distant or _requeries >= MAX_REQUERIES: return _fail(detail + ":retry_bound")
	_requeries += 1; _last_retry_reason = detail
	return _submit()

func cancel() -> void:
	_retire_owner()
	_serial += 1; revision += 1
	status = "cancelled"; _phase = "cancelled"; reason = ""
	_points.clear(); _raw.clear(); _index = 0
	_body = null; _body_id = 0
	_map = RID(); _iteration = 0; _distant = false
	_queue_ref=null;_ticket=0;_pending_result=null;_wait_reason=""
	_physical30=null;_repair_pending30=false

func diagnostics() -> Dictionary:
	return {"status":status, "phase":_phase, "reason":reason, "distant":_distant, "waypoint":_index, "waypoints":_points.size(), "metres":_metres, "local_leg_limit_m":LEG_M, "local_domain_m":_local_only_m, "map_iteration":_iteration, "revision":revision, "requeries":_requeries, "last_retry_reason":_last_retry_reason, "query_submit_us":_submit_us, "query_wall_ms":_query_wall_ms, "prepare_max_us":_prepare_max_us, "stale_callbacks":_stale_callbacks,"wait_reason":_wait_reason,"queue_wait_ms":_queue_wait_ms,"work_units":_work_units,"work_us":_work_us,"progress_revision":_progress_revision,"query_ticket":_ticket,"checkpoint_probes30":_repair_probes30,"checkpoint_repairs30":_repaired30,"shared_work":Work.diagnostics()}
