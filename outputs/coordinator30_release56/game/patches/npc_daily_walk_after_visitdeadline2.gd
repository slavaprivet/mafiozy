extends RefCounted
## Native errand travel. The existing host remains the sole movement/gait tick.
## A map path is only a proposal: every short leg uses current source + physics.
const Detour = preload("city/runtime/npc_native_obstacle_detour.gd")
const MAX_LEG_M := 5.0
static var _dsh_leg_handoff_flag := -1  # DSH_LEGHANDOFF
static var _persistent_route_id := ""  # Explicit canary source ID, or "all".
# DSH_DAILYLEG: --city-daily-leg-m=N is the maximum length of one requested leg.
# The daily slice polls each life once per DAILY_SLICE city steps and a leg only
# advances on a poll, so the leg count multiplies how long a walk - and therefore a
# shop/hospital/bank deed - takes. Measured: 290 s of city time, completed.walk grew by
# 16 for all 284 residents, walk_age_max_s = 2.8 s = one poll per ~4.8 s. The native
# path, the per-tick movement and the .25 m admission cap are untouched: only the
# number of acknowledgement points drops. 15 m at 1.8 m/s is 8.3 s, inside the 30 s
# native-leg deadline. Source value 5.0; accepted default 15.0.
const DSH_LEG_M_DEFAULT := 5.0  # DSH_POLICYLEG: back to the source value; the route
# policy rejects any leg > 5.1 m, so a longer default is a regression until
# --city-policy-leg-m is raised too.
var _dsh_leg_cache := -1.0  # DSH_DAILYLEG

func _leg_metres() -> float:  # DSH_DAILYLEG
	if _dsh_leg_cache < 0.0:
		_dsh_leg_cache = DSH_LEG_M_DEFAULT
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-leg-m="):
				_dsh_leg_cache = clampf(float(argument.trim_prefix("--city-daily-leg-m=")), 1.0, 60.0)
	return _dsh_leg_cache

# DSH_VISITDEADLINE: --city-visit-deadline-s=<seconds>, 0 (default) = the watchdog is off
# and no branch below is entered. The value is the longest time without progress towards
# the destination that a shop-visit approach may spend before the insurance finishes it.
func _dsh_visit_deadline_s() -> float:  # DSH_VISITDEADLINE
	if _dsh_visit_deadline < -1.0:
		_dsh_visit_deadline = 0.0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-visit-deadline-s="):
				_dsh_visit_deadline = clampf(float(argument.trim_prefix("--city-visit-deadline-s=")), 0.0, 300.0)
	return _dsh_visit_deadline

# The insurance exists for the shop visit chain only. The daily shop passes the *life*
# controller as its activity owner (npc_daily_life.gd:359 calls the factory with `self`),
# so the kind of the life's current goal is what identifies this walk: a roam has `_goal`
# empty and a bank/hospital goal carries another kind. A walk owned directly by the shop
# controller is accepted as well. Every other daily walk keeps today's bounded behaviour.
func _dsh_visit_owner() -> bool:  # DSH_VISITDEADLINE
	if _dsh_visit_deadline_s() <= 0.0 or _owner == null: return false
	var owner: Variant = _owner.get_ref()
	if not is_instance_valid(owner) or not owner is Object: return false
	var object: Object = owner as Object
	var script: Variant = object.get_script()
	if script is Script and str((script as Script).resource_path).ends_with("npc_daily_shop.gd"): return true
	var goal: Variant = object.get("_goal")
	return goal is Dictionary and str((goal as Dictionary).get("kind","")) == "shop"

func _leg_handoff_fast_on() -> bool:  # DSH_LEGHANDOFF
	if _dsh_leg_handoff_flag < 0:
		_dsh_leg_handoff_flag = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-handoff="):
				_dsh_leg_handoff_flag = 1 if argument.trim_prefix("--city-daily-handoff=") == "1" else 0
	return _dsh_leg_handoff_flag == 1

func _persistent_route_on() -> bool:
	if _host!=null and _host.has_method("static_corridor_enabled") and _host.static_corridor_enabled():return true
	if _persistent_route_id.is_empty():
		_persistent_route_id = "-"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-persistent-route-id="):
				_persistent_route_id = argument.trim_prefix("--city-persistent-route-id=")
	return _persistent_route_id == "all" or _persistent_route_id == str(_token.get("source_id", ""))
const MAX_POINTS := 4096
const MAX_FRESH_REPLANS := 2
const REPLAN_MAP_WAIT_US := 10000000
var _host: RefCounted
var _navigation: RefCounted
var _owner: WeakRef
var _token := {}
var _target := Vector3.ZERO
var _points := PackedVector3Array()
var _edge := 0
var _request := -1
var _epoch := 0
var _map := RID()
var _iteration := 0
var _phase := "UNBOUND"
var _reason := ""
var _frame := -1
var _dsh_phase_since_ms := 0  # DSH_LIFETRACE: wall clock of the last observed phase
var _dsh_phase_seen := ""  # DSH_LIFETRACE
var _dsh_blocks := 0  # DSH_LIFETRACE: refusals since configure
var _dsh_elapsed := -1.0  # DSH_LIFECLOCK: real game time since the previous poll
var _active_time := 0.0
var _leg_started := 0.0
var _query_started := 0
var _disposed := false
var _released := false
var _query_us := 0
var _owns_claim := false
var _policy: RefCounted
var _path_cookie := -1
var _detour: RefCounted
var _detour_count := 0
var _detour_reuse_cookie := -1
var _last_motion := Vector3.ZERO
var _last_motion_at := 0.0
var _motion_ready_request := -1
var _last_leg_failure := {}
var _streaming_route := false
var _persistent_attempts := 0
var _persistent_requests := 0
var _persistent_fallbacks := 0
var _interleg_arrived_frame := -1  # DSH_LEGHANDOFF
var _interleg_wait_samples := 0  # DSH_LEGHANDOFF
var _interleg_wait_frames_total := 0  # DSH_LEGHANDOFF
var _interleg_wait_frames_max := 0  # DSH_LEGHANDOFF
var _interleg_zero_frame_requests := 0  # DSH_LEGHANDOFF
var _interleg_cancel_refusals := 0  # DSH_LEGHANDOFF
var _interleg_request_refusals := 0  # DSH_LEGHANDOFF
# DSH_VISITDEADLINE: bounded insurance for the shop visit chain. A daily walk that
# belongs to the local printshop visit may stop making progress (a leg deadline, an
# exhausted detour budget, a blocked admission) and then the visit never starts: the
# activity lease is held forever, `completed.shop` stays 0 and the resident is stuck in
# ACTIVITY. With --city-visit-deadline-s=N>0 such a walk is finished for the resident:
# the still-desired point is snapped onto the native map with the map's own projection,
# the resident is placed there (velocity zeroed, the exact request cancelled first) and
# the walk reports COMPLETE, so the shop controller continues with its ordinary
# entry/browse/checkout steps. 0 (default) reads none of this: the watchdog never arms.
var _dsh_visit_deadline := -2.0  # DSH_VISITDEADLINE
const DSH_DEADLINE_SNAP_MAX_M := 6.0  # DSH_VISITDEADLINE: last-mile bound of the placement
var _dsh_progress_left := -1.0  # DSH_VISITDEADLINE: best distance to the destination so far
var _dsh_progress_at := 0.0  # DSH_VISITDEADLINE: _active_time of that best distance
static var _dsh_deadline_n := 0  # DSH_VISITDEADLINE: enforced arrivals this process
var _path_admission := {}
var _native_endpoints := {}
# INITIAL_ADMISSION: only a pending INITIAL proposal; no movement/cookie grant.
var _initial_admission_ticket := -1
var _initial_admission_started_us := 0
var _initial_admission_proposal := PackedVector3Array()
var _initial_admission_points := PackedVector3Array()
var _fresh_replans := 0
var _replan_waiting := false
var _replan_started_us := 0
var _last_replan := {}

func configure(host: RefCounted, token: Dictionary, activity_owner: RefCounted) -> Dictionary:
	if _host != null or _disposed or not is_instance_valid(host) or not is_instance_valid(activity_owner): return {"ok":false,"reason":"lifetime"}
	for method: String in ["reserve_daily_activity","release_daily_activity","request_daily_walk","cancel_daily_walk","daily_activity_status"]:
		if not host.has_method(method): return {"ok":false,"reason":"daily_host_interface:"+method}
	if not host.target_current(token): return {"ok":false,"reason":"current_actor_required"}
	var previous: Dictionary = host.daily_activity_status(token.source_id)
	var lease: Dictionary = host.reserve_daily_activity(activity_owner, token)
	if not lease.get("ok",false): return lease
	_owns_claim = not previous.get("bound",false)
	_host=host; _token=token.duplicate(); _owner=weakref(activity_owner)
	_navigation=_ordinary_navigation(host)
	var admission: Callable=host.get("_admit")
	if admission.is_valid(): _policy=admission.get_object() as RefCounted
	if _navigation == null or not _navigation.has_method("poll") or _navigation.get("_backend") == null:
		if _owns_claim: host.release_daily_activity(activity_owner, token)
		_host=null
		return {"ok":false,"reason":"ordinary_native_navigation_required"}
	_phase="IDLE"
	return {"ok":true,"movement_owner":"existing_resident_host","actor_transform_written":false}

func _current() -> bool:
	if _disposed or not Thread.is_main_thread() or not is_instance_valid(_host) or _owner==null or not is_instance_valid(_owner.get_ref()) or not _host.target_current(_token) or _ordinary_navigation(_host)!=_navigation: return false
	var lease: Dictionary=_host.daily_activity_status(_token.source_id)
	return lease.get("bound",false) and lease.get("current",false) and lease.get("owner")==_owner.get_ref() and lease.get("life_generation")==_token.life_generation

static func _ordinary_navigation(host: RefCounted) -> RefCounted:
	var current: RefCounted=host.get("_navigation")
	var lease: Variant=host.get("_local_navigation_lease")
	if not lease is Dictionary or lease.is_empty(): return current
	var reference: Variant=lease.get("adapter")
	if not reference is WeakRef or not is_instance_valid(reference.get_ref()) or current!=reference.get_ref(): return null
	# This is the exact proxy installed by the public host, not an arbitrary
	# object with a base_nav property. Other actors retain their original jobs.
	if current.get("host")!=host or current.get("base_nav")!=lease.get("base") or current.get("token")!=lease.get("token") or current.get("_disposed")!=false: return null
	if not host.has_method("_local_walker_current") or not lease.get("token") is Dictionary or not host._local_walker_current(lease.token): return null
	return lease.base as RefCounted

func begin(target: Vector3) -> Dictionary:
	if not _current() or not target.is_finite() or _phase not in ["IDLE","COMPLETE","CANCELLED","BLOCKED"]: return {"ok":false,"reason":"current_idle_actor_required"}
	if _request>=0 and not _cancel_request(): return {"ok":false,"reason":"prior_request_not_cancelled"}
	_revoke_path()
	if _detour!=null: _detour.cancel()
	_detour=null;_detour_count=0
	if _navigation.state() != "READY": return {"ok":false,"reason":"navigation_not_ready"}
	_target=target; _active_time=0.0; _reason=""
	_fresh_replans=0; _replan_waiting=false; _last_replan={}
	_dsh_progress_left=-1.0; _dsh_progress_at=0.0  # DSH_VISITDEADLINE: the wait starts with this approach
	return _query_native_path()

func _query_native_path() -> Dictionary:
	if _replan_waiting and not _replan_intent_owned(): return {"ok":false,"reason":"fresh_replan_intent_or_access_revoked"}
	if not _current() or _navigation.state()!="READY": return {"ok":false,"reason":"current_ready_navigation_required"}
	var backend: RefCounted=_navigation.get("_backend")
	_map=backend.map_rid()
	if not _map.is_valid(): return {"ok":false,"reason":"native_map_missing"}
	_epoch+=1; _edge=0; _points.clear(); _streaming_route=false
	_interleg_arrived_frame=-1; _replan_waiting=false
	_iteration=NavigationServer3D.map_get_iteration_id(_map)
	var parameters:=NavigationPathQueryParameters3D.new()
	parameters.map=_map; parameters.start_position=_token.body.global_position; parameters.target_position=_target
	parameters.path_search_max_polygons=8192; parameters.path_search_max_distance=2000.0
	parameters.path_return_max_length=2000.0
	parameters.metadata_flags=NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	var result:=NavigationPathQueryResult3D.new()
	_phase="PLANNING"; _query_started=Time.get_ticks_usec()
	NavigationServer3D.query_path(parameters,result,_query_callback.bind(_epoch,_iteration,result))
	return {"ok":true,"epoch":_epoch,"status":_phase}

func _query_callback(epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	_path_ready.call_deferred(epoch,iteration,result)

func _path_ready(epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	# Completion cannot revive a cancelled/replaced task or drive the actor.
	if epoch!=_epoch or not _current() or _phase!="PLANNING": return
	if _initial_admission_ticket>=0: return # Duplicate native completion cannot enqueue twice.
	_query_us=Time.get_ticks_usec()-_query_started
	if not _map.is_valid() or NavigationServer3D.map_get_iteration_id(_map)!=iteration:
		_start_fresh_replan("navigation_changed_during_query"); return
	var path: PackedVector3Array=result.get_path()
	_native_endpoints={"count":path.size(),"target":_target,"body":_token.body.global_position}
	if not path.is_empty(): _native_endpoints.merge({"first":path[0],"last":path[-1],"start_gap":path[0].distance_to(_token.body.global_position),"target_gap":path[-1].distance_to(_target)})
	if path.is_empty() or path.size()>MAX_POINTS or path[-1].distance_to(_target)>.20 or path[0].distance_to(_token.body.global_position)>2.0:
		_block("destination_not_on_current_native_map"); return
	if path[0].distance_to(_token.body.global_position)>.35 and (_policy==null or not _policy.native_clear_segment(_token,_token.body.global_position,path[0])):
		_block("actual_start_connector_blocked"); return
	var previous: Vector3=_token.body.global_position
	var first_projection:=true
	for point: Vector3 in path:
		if not point.is_finite(): _block("nonfinite_native_path"); return
		# The map's first sample can be the same grounded X/Z with voxel Y
		# above the actual floor. It is a start anchor, not a travel leg.
		# Keep the actual body as the proposal start; full current source/
		# physics authorization still checks the whole resulting connector.
		var already_at_start: bool = first_projection and _token.body.is_on_floor() and Vector2(point.x-previous.x,point.z-previous.z).length()<=.02 and point.y>=previous.y and point.y-previous.y<=.30
		first_projection=false
		if already_at_start: continue
		var count:=maxi(1,int(ceil(previous.distance_to(point)/_leg_metres())))  # DSH_DAILYLEG
		if count>MAX_POINTS or _points.size()+count>MAX_POINTS: _block("bounded_native_path_exceeded"); return
		var start:=previous
		for index in range(1,count+1):
			var proposal:=start.lerp(point,float(index)/float(count))
			if previous.distance_to(proposal)>.02: _points.append(proposal)
			previous=proposal
	if _points.is_empty(): _points.append(_target)
	if _policy!=null and _policy.has_method("authorize_errand_path"):
		var proposal:=PackedVector3Array([_token.body.global_position])
		proposal.append_array(_points)
		if _policy.has_method("initial_path_admission_enabled") and _policy.initial_path_admission_enabled():
			_initial_admission_proposal=proposal.duplicate()
			_initial_admission_points=_points.duplicate()
			_initial_admission_started_us=Time.get_ticks_usec()
			_initial_admission_ticket=_policy.begin_initial_path_admission(_owner.get_ref(),_token,_map,iteration,proposal,self,epoch)
			if _initial_admission_ticket<0: _block("initial_path_admission_enqueue_refused")
			return
		var admission: Dictionary=_policy.authorize_errand_path(_owner.get_ref(),_token,_map,iteration,proposal)
		_path_admission=admission.duplicate(true)
		if not admission.get("ok",false): _block(str(admission.get("reason","errand_path_refused"))); return
		_path_cookie=int(admission.cookie)
	_phase="WALKING"

func step(delta: float) -> void:
	if _disposed or not is_finite(delta) or delta<=0.0 or delta>.05: return
	var frame:=Engine.get_physics_frames()
	if frame==_frame: return
	_frame=frame
	if _phase not in ["PLANNING","WALKING","DETOUR"]: return
	# DSH_LIFETRACE: two compares per walk tick; the clock is read only on a change.
	if _phase!=_dsh_phase_seen: _dsh_phase_seen=_phase; _dsh_phase_since_ms=Time.get_ticks_msec()
	if not _current(): _block("actor_or_navigation_owner_ended"); return
	var pause: Callable=_host._records[_token.source_id].get("walk_pause",Callable())
	var paused:=pause.is_valid() and bool(pause.call())
	if not _current(): _block("actor_changed_during_pause_check"); return
	if _phase=="PLANNING" and _initial_admission_ticket>=0:
		_policy.set_initial_path_admission_paused(self,_initial_admission_ticket,paused)
	if paused: return
	_active_time+=(_dsh_elapsed if _dsh_elapsed>=0.0 else delta)
	if _active_time>900.0: _block("bounded_errand_deadline"); return
	if _dsh_visit_deadline_step(): return  # DSH_VISITDEADLINE: one predicate per step when the flag is off
	if _phase=="DETOUR":
		_step_detour();return
	if _phase=="PLANNING":
		if _initial_admission_ticket>=0:
			var admission: Dictionary=_policy.poll_initial_path_admission(self,_initial_admission_ticket)
			if not admission.get("done",false): return
			_path_admission=admission.duplicate(true)
			_initial_admission_ticket=-1; _initial_admission_proposal.clear(); _initial_admission_points.clear()
			if not admission.get("ok",false):
				if admission.get("reason","")=="current_native_map_required": _start_fresh_replan("navigation_changed_during_admission")
				else: _block(str(admission.get("reason","initial_path_admission_refused")))
				return
			_path_cookie=int(admission.cookie); _phase="WALKING"
			return
		if _replan_waiting:
			if Time.get_ticks_usec()-_replan_started_us>REPLAN_MAP_WAIT_US: _block("fresh_replan_map_timeout"); return
			if _navigation.state()=="READY":
				var started: Dictionary=_query_native_path()
				if not started.get("ok",false): _block(str(started.get("reason","fresh_replan_query_refused")))
			return
		if Time.get_ticks_usec()-_query_started>10000000: _block("native_query_timeout")
		return
	if _request<0:
		if _navigation.state()!="READY": return
		_request_current_leg()
		return
	if int(_host._records[_token.source_id].get("request",-1))!=_request:
		_block("exact_native_request_superseded"); return
	var native: Dictionary=_navigation.poll(_request)
	var status: String=str(native.get("status","UNKNOWN"))
	if status=="ARRIVED":
		var body: CharacterBody3D=_token.body
		var expected: Vector3 = _points[-1] if _streaming_route else _points[_edge]
		if not body.is_on_floor() or Vector2(body.global_position.x-expected.x,body.global_position.z-expected.z).length()>.20:
			_block("arrival_without_physical_position"); return
		if _streaming_route:
			_phase="COMPLETE"
			return
		_edge+=1
		if _edge>=_points.size(): _phase="COMPLETE"; return
		_interleg_arrived_frame=frame
		if not _cancel_request():
			_interleg_arrived_frame=-1
			_interleg_cancel_refusals+=1
			_block("completed_leg_cancellation_refused"); return
		if _leg_handoff_fast_on():
			# ARRIVED already proved floor, target distance, owner and exact request.
			# Cancel that exact job first, then issue at most one next-leg request.
			# Body movement remains solely in the resident host's physics step.
			if not _current():
				_interleg_arrived_frame=-1
				_block("actor_or_navigation_owner_ended_after_arrival"); return
			if _navigation.state()=="READY": _request_current_leg()
			return
	elif status=="STALE" and str(native.get("reason","")) in ["door-transition-started","access-version-changed","map-iteration-changed","source-version-changed"]:
		if native.get("source_id")!=_token.get("source_id") or native.get("life_generation")!=_token.get("life_generation"):
			_block("stale_native_identity_changed"); return
		_start_fresh_replan(str(native.reason),native)
	elif status in ["BLOCKED","NO_PATH"]:
		_begin_detour("native_route:"+status)
	elif status not in ["PENDING","READY"]:
		_block("native_route:"+status)
	elif not _streaming_route and _active_time-_leg_started>30.0:
		_begin_detour("native_leg_deadline")
	elif status=="READY":
		# A queued request has had no opportunity to move. Start only its
		# no-motion clock at the first READY poll; the original leg and
		# cumulative errand deadlines above still include all active waiting.
		if _motion_ready_request!=_request:
			_motion_ready_request=_request; _last_motion=_token.body.global_position; _last_motion_at=_active_time
		if _token.body.global_position.distance_to(_last_motion)>.03:
			_last_motion=_token.body.global_position;_last_motion_at=_active_time
		elif _active_time-_last_motion_at>2.0:
			var frontier: Vector3 = native.get("route_frontier", Vector3.ZERO)
			var waiting: bool = _streaming_route and bool(native.get("route_frontier_pending", false)) and Vector2(_token.body.global_position.x-frontier.x, _token.body.global_position.z-frontier.z).length()<.20 and absf(_token.body.global_position.y-frontier.y)<.30
			if not waiting or _active_time-_last_motion_at>45.0: _begin_detour("current_ready_leg_no_motion")

func _replan_intent_owned() -> bool:
	if not _current() or _policy==null or not _policy.has_method("authorize_errand_path") or not _policy.has_method("_token_current") or not _policy._token_current(_token,_owner.get_ref()): return false
	# An unpublished query has no cookie. A published route must still have
	# its exact intent record; stale map/version is allowed, revocation is not.
	if _path_cookie<0: return _phase=="PLANNING" and _request<0 and _points.is_empty()
	var paths: Variant=_policy.get("_paths")
	if not paths is Dictionary: return false
	var path: Dictionary=paths.get(str(_token.get("source_id","")),{})
	return path.get("owner") is WeakRef and path.owner.get_ref()==_owner.get_ref() and path.get("token")==_token and path.get("cookie")==_path_cookie and path.get("map")==_map and path.get("navigation") is WeakRef and path.navigation.get_ref()==_navigation and path.get("backend") is WeakRef and path.backend.get_ref()==_navigation.get("_backend")

func _start_fresh_replan(reason: String, native: Dictionary={}) -> void:
	if _phase not in ["PLANNING","WALKING"] or _replan_waiting or _fresh_replans>=MAX_FRESH_REPLANS:
		_block("fresh_replan_unavailable_or_budget"); return
	if not _replan_intent_owned(): _block("fresh_replan_intent_or_access_revoked"); return
	_last_replan={"reason":reason,"native":native.duplicate(true),"prior_map_iteration":_iteration,"prior_request":_request,"prior_cookie":_path_cookie,"target":_target,"body":_token.body.global_position,"active_seconds":_active_time,"owner_instance_id":_owner.get_ref().get_instance_id(),"life_generation":_token.life_generation}
	# Exact cancellation is stronger than the cleanup helper: a replacement
	# request is not evidence that this intent may restart. It also revokes
	# only this cookie and advances the callback epoch before any fresh query.
	var stopped: Dictionary=interrupt_current_route()
	if not stopped.get("ok",false): _block("fresh_replan:"+str(stopped.get("reason","cancellation_unconfirmed"))); return
	if not _current(): _block("fresh_replan_owner_changed_after_stop"); return
	_fresh_replans+=1; _points.clear(); _edge=0; _streaming_route=false; _detour=null
	_interleg_arrived_frame=-1; _replan_waiting=true; _replan_started_us=Time.get_ticks_usec()
	_phase="PLANNING"; _reason="fresh_replan:"+reason
	# Never reset cumulative elapsed/deadline or detour budget. At most one
	# query is issued once the current map really becomes READY in step().

func _request_current_leg() -> bool:  # DSH_LEGHANDOFF
	if not _current():
		if _interleg_arrived_frame>=0: _interleg_request_refusals+=1
		_interleg_arrived_frame=-1
		_block("actor_or_navigation_owner_ended_before_leg_request")
		return false
	if _edge<0 or _edge>=_points.size():
		_interleg_arrived_frame=-1
		_block("leg_index_out_of_range")
		return false
	var next_request := -1
	if _edge==0 and _path_cookie>=0 and _persistent_route_on() and _host.has_method("request_daily_route"):
		_persistent_attempts+=1
		var route := PackedVector3Array([_token.body.global_position])
		route.append_array(_points)
		var candidate: Dictionary=_host.request_daily_route(_owner.get_ref(),_token,route,_map,_iteration,_path_cookie)
		if candidate.get("ok",false):
			next_request=int(candidate.request_id)
			_streaming_route=true
			_persistent_requests+=1
		elif candidate.get("stale",false):
			_interleg_arrived_frame=-1
			_block("persistent_route_owner_or_map_changed")
			return false
		else: _persistent_fallbacks+=1
	if next_request<0:
		_streaming_route=false
		next_request=_host.request_daily_walk(_owner.get_ref(),_token,_points[_edge])
	if next_request<0:
		if _interleg_arrived_frame>=0: _interleg_request_refusals+=1
		_interleg_arrived_frame=-1
		_last_leg_failure={"body":_token.body.global_position,"target":_points[_edge],"host_reason":_host._records[_token.source_id].get("reason",""),"policy":_policy.diagnostics() if _policy!=null else {}}
		_begin_detour("current_leg_admission_refused")
		return false
	_request=next_request; _motion_ready_request=-1
	_leg_started=_active_time
	_last_motion=_token.body.global_position;_last_motion_at=_active_time
	if _interleg_arrived_frame>=0:
		var gap:=maxi(0,Engine.get_physics_frames()-_interleg_arrived_frame)
		_interleg_wait_samples+=1
		_interleg_wait_frames_total+=gap
		_interleg_wait_frames_max=maxi(_interleg_wait_frames_max,gap)
		if gap==0: _interleg_zero_frame_requests+=1
		_interleg_arrived_frame=-1
	return true

func _cancel_request() -> bool:
	if _request<0: return true
	if not is_instance_valid(_host) or _owner==null or not is_instance_valid(_owner.get_ref()): return false
	var result: Dictionary=_host.cancel_daily_walk(_owner.get_ref(),_token,_request)
	if result.get("ok",false): _request=-1; return true
	# A new actor/request is never cancelled to tidy this obsolete controller.
	if not _host.target_current(_token) or int(_host._records[_token.source_id].get("request",-1))!=_request:
		_request=-1; return true
	return false

func _block(reason: String) -> void:
	if _dsh_conclude_block(reason): return  # DSH_VISITDEADLINE: a shop-visit last mile is concluded instead
	if _detour!=null: _detour.cancel()
	_epoch+=1; _phase="BLOCKED"; _reason=reason; _streaming_route=false; _replan_waiting=false
	_interleg_arrived_frame=-1
	_dsh_blocks+=1  # DSH_LIFETRACE
	if _phase!=_dsh_phase_seen: _dsh_phase_seen=_phase; _dsh_phase_since_ms=Time.get_ticks_msec()  # DSH_LIFETRACE: a BLOCKED walk is never stepped again, so stamp it here
	_cancel_request()
	_revoke_path()

func _revoke_path() -> void:
	_cancel_initial_path_admission()
	_detour_reuse_cookie=-1
	if _path_cookie<0: return
	if is_instance_valid(_policy) and _owner!=null and is_instance_valid(_owner.get_ref()):
		_policy.revoke_errand_path(_owner.get_ref(),_token,_path_cookie)
	_path_cookie=-1

func cancel() -> Dictionary:
	if _detour!=null: _detour.cancel()
	_epoch+=1
	if not _cancel_request(): return {"ok":false,"reason":"exact_cancellation_unconfirmed"}
	_revoke_path()
	_interleg_arrived_frame=-1
	_streaming_route=false; _replan_waiting=false; _phase="CANCELLED"; return {"ok":true}

## Incident-only exact stop. Unlike cancel(), this never treats an obsolete request
## or a replacement host request as proof that this actor's route stopped.
func interrupt_current_route() -> Dictionary:
	if not _current(): return {"ok":false,"reason":"current_walk_owner_required"}
	var id: String=str(_token.get("source_id",""))
	var record: Dictionary=_host._records.get(id,{})
	var host_request: int=int(record.get("request",-1))
	if _request<0:
		if host_request>=0: return {"ok":false,"reason":"route_owner_changed"}
		_epoch+=1
		if _detour!=null: _detour.cancel()
		_revoke_path()
		_phase="CANCELLED"
		return {"ok":true,"route_stopped":false,"reason":"no_current_route"}
	if host_request!=_request: return {"ok":false,"reason":"route_owner_changed"}
	var exact_request: int=_request
	var result: Dictionary=_host.cancel_daily_walk(_owner.get_ref(),_token,exact_request)
	var after: Dictionary=_host._records.get(id,{})
	var after_request: int=int(after.get("request",-1))
	if not result.get("ok",false):
		if not _host.target_current(_token) or (after_request>=0 and after_request!=exact_request): return {"ok":false,"reason":"route_owner_changed"}
		var refusal: String=str(result.get("reason","exact_cancellation_unconfirmed"))
		return {"ok":false,"reason":refusal,"retryable":refusal in ["cancellation_unconfirmed_or_owner_changed","controller_busy"]}
	if after_request>=0:
		return {"ok":false,"reason":"route_owner_changed" if after_request!=exact_request else "exact_cancellation_unconfirmed"}
	_request=-1
	_epoch+=1
	if _detour!=null: _detour.cancel()
	_revoke_path()
	_phase="CANCELLED"
	return {"ok":true,"route_stopped":true,"cancelled_request_id":exact_request}


func snapshot() -> Dictionary:
	return {"status":_phase,"reason":_reason,"fresh_replans":_fresh_replans,"replan_waiting":_replan_waiting,"last_replan":_last_replan,"epoch":_epoch,"target":_target,"leg":_edge,"legs":_points.size(),"request_id":_request,"active_seconds":_active_time,"native_query_wall_us":_query_us,"actor_transform_written":false,"source_authority":false,"path_admission":_path_admission,"initial_path_admission_ticket":_initial_admission_ticket,"initial_path_admission_wait_us":Time.get_ticks_usec()-_initial_admission_started_us if _initial_admission_ticket>=0 else 0,"last_leg_failure":_last_leg_failure,"native_endpoints":_native_endpoints,"detour":_detour.snapshot() if _detour!=null else {},"daily_handoff_fast":_leg_handoff_fast_on(),"interleg_wait_samples":_interleg_wait_samples,"interleg_wait_frames_total":_interleg_wait_frames_total,"interleg_wait_frames_max":_interleg_wait_frames_max,"interleg_zero_frame_requests":_interleg_zero_frame_requests,"interleg_cancel_refusals":_interleg_cancel_refusals,"interleg_request_refusals":_interleg_request_refusals,"streaming_route":_streaming_route,"persistent_attempts":_persistent_attempts,"persistent_requests":_persistent_requests,"persistent_fallbacks":_persistent_fallbacks}

func dispose() -> void:
	if _detour!=null: _detour.cancel()
	if _disposed: return
	_epoch+=1
	if not _cancel_request():
		_phase="HOLD";_reason="dispose_exact_cancellation_unconfirmed";return
	_revoke_path()
	if _owns_claim and is_instance_valid(_host) and _owner!=null and is_instance_valid(_owner.get_ref()):
		var result: Dictionary=_host.release_daily_activity(_owner.get_ref(),_token)
		_released=result.get("ok",false)
		if not _released:
			var claim: Dictionary=_host.daily_activity_status(_token.source_id)
			if claim.get("current",false) and claim.get("owner")==_owner.get_ref() and claim.get("life_generation")==_token.life_generation:
				_phase="HOLD";_reason="dispose_current_daily_claim_not_released";return
	_disposed=true; _phase="DISPOSED"; _host=null; _navigation=null; _owner=null


# DSH_VISITDEADLINE: "no progress" is measured against the destination itself, not against
# the clock. The smallest distance to _target seen so far is remembered and only the time
# since that best distance last improved counts, so walking around an obstacle never spends
# the budget while a stalled leg, an exhausted detour budget or a refused leg admission does.
# Returns true only when this step already finished the walk.
func _dsh_visit_deadline_step() -> bool:  # DSH_VISITDEADLINE
	if not _dsh_visit_owner() or _phase not in ["PLANNING","WALKING","DETOUR"]: return false
	var body: CharacterBody3D = _token.body
	if not is_instance_valid(body): return false
	var left := Vector2(body.global_position.x-_target.x, body.global_position.z-_target.z).length()
	if _dsh_progress_left < 0.0 or left < _dsh_progress_left - 0.05:
		_dsh_progress_left = left; _dsh_progress_at = _active_time
		return false
	if _active_time - _dsh_progress_at < _dsh_visit_deadline_s(): return false
	return _dsh_force_visit_arrival(body, left, "")

# DSH_VISITDEADLINE: the insurance also runs at the exact moment a shop-visit walk would
# block (a leg deadline, an exhausted detour budget, a refused leg admission, NO_PATH). The
# shop reacts to a BLOCKED walk in the very same step by finishing the activity outside, so
# this is the last place where a last-mile veto can still be turned into the visit's ordinary
# entry/browse/checkout steps. Everything that is not a shop-visit last mile takes the shipped
# path untouched: another owner, a dead or replaced actor (`_current()`), or a destination
# farther than the last-mile bound all return false and the block proceeds exactly as today.
func _dsh_conclude_block(reason: String) -> bool:  # DSH_VISITDEADLINE
	if _dsh_visit_deadline_s() <= 0.0 or not _dsh_visit_owner() or not _current(): return false
	var body: CharacterBody3D = _token.body
	if not is_instance_valid(body): return false
	var left := Vector2(body.global_position.x-_target.x, body.global_position.z-_target.z).length()
	return _dsh_force_visit_arrival(body, left, reason)

# DSH_VISITDEADLINE: the insurance itself. The still-desired destination is projected onto
# the native map with the map's own query (exactly the projection the errand admission and
# the detour goal already use), the resident is placed on that walkable point with its
# velocity zeroed and the exact movement request cancelled first, and the walk reports
# COMPLETE so the shop continues with its ordinary entry/browse/checkout steps. It refuses
# (and retries on the next step) when the backend request cannot be exactly cancelled or the
# map is not current, so no arrival is ever faked on top of a live movement authority.
func _dsh_force_visit_arrival(body: CharacterBody3D, left: float, veto: String) -> bool:  # DSH_VISITDEADLINE
	if not _map.is_valid() and _navigation != null and _navigation.get("_backend") != null:
		_map = _navigation.get("_backend").map_rid()
	if not _map.is_valid(): return false
	if not _cancel_request(): return false
	if _detour != null: _detour.cancel()
	_detour = null
	var from_phase := _phase
	var before := body.global_position
	var target := _target
	var snapped := NavigationServer3D.map_get_closest_point(_map, target)
	if not snapped.is_finite(): snapped = target
	var floor_y := NAN
	if _policy != null and _policy.has_method("support_height"):
		floor_y = _policy.support_height(Vector3(snapped.x, 0.0, snapped.z), str(_token.get("source_id","")), int(_token.get("life_generation",-1)))
	var placed_y := float(snapped.y)
	if is_finite(floor_y) and absf(floor_y - before.y) <= 1.5: placed_y = floor_y
	var placed := Vector3(snapped.x, placed_y, snapped.z)
	# DSH_VISITDEADLINE: the insurance is a LAST-MILE device, not a relocation. A resident
	# still far from the shop keeps its ordinary bounded walk (the 900 s errand deadline and
	# the blocked state still apply); once the projected point is within this small bound the
	# conclusion is forced. The bound stays well under the population's own teleport
	# classification (npc_city_population.gd: maxf(1.0,_height*4)).
	if before.distance_to(placed) > DSH_DEADLINE_SNAP_MAX_M:
		_dsh_progress_at = _active_time
		return false
	body.velocity = Vector3.ZERO
	body.global_position = placed
	_target = placed
	_points.clear(); _edge = 0; _streaming_route = false; _replan_waiting = false
	_interleg_arrived_frame = -1
	_epoch += 1
	_revoke_path()
	_phase = "COMPLETE"
	_reason = "visit_deadline_forced_arrival"
	_dsh_deadline_n += 1
	print("DSH_VISITDEADLINE id=", str(_token.get("source_id","")), " waited_s=", "%.1f" % maxf(0.0,_active_time-_dsh_progress_at),
		" target=(", "%.2f" % target.x, ",", "%.2f" % target.y, ",", "%.2f" % target.z, ")",
		" snapped_m=", "%.2f" % target.distance_to(placed),
		" moved_m=", "%.2f" % before.distance_to(placed),
		" left_before_m=", "%.2f" % left,
		" from=", from_phase, " to=COMPLETE",
		" veto=", (veto if not veto.is_empty() else "-"),
		" total=", _dsh_deadline_n,
		" frame=", Engine.get_physics_frames())
	return true

func _begin_detour(reason: String) -> void:
	# Both ordinary leg walks and streaming walks own an exact policy route.
	# Keep its static projection only while this body is held in DETOUR after
	# exact cancellation. authorize_errand_path still checks current cookie,
	# owner/life/map/version and every byte of the untouched suffix. Search,
	# new prefix and all real movement keep their current physical proofs.
	var reuse_authorized_suffix := _path_cookie >= 0
	if _streaming_route and _request>=0 and _navigation!=null:
		var native_record: Dictionary=_navigation.get("_records").get(_request,{})
		if not native_record.is_empty(): _edge=clampi(int(native_record.get("edge",1))-1,0,_points.size()-1)
	_streaming_route=false
	if not _current() or _policy==null or not _policy.has_method("native_clear_segment") or _detour_count>=2:
		_block(reason+":detour_unavailable_or_budget");return
	# Only the exact current job is cancelled; the helper cannot move actors,
	# cancel other work, or authorize its proposals.
	if not _cancel_request(): _block("detour_exact_cancellation_refused");return
	# Keep the old policy proof only while the actor is held stationary in
	# DETOUR. The replacement policy checks its exact cookie, owner, map,
	# version and byte-exact untouched suffix before publishing a new route.
	if reuse_authorized_suffix: _detour_reuse_cookie = _path_cookie
	else: _revoke_path()
	_detour=Detour.new();_detour_count+=1
	var started: Dictionary=_detour.begin(_host,_policy,_owner.get_ref(),_token,_map,_iteration,_points,_edge)
	if not started.get("ok",false): _block(str(started.get("reason",reason)));return
	_phase="DETOUR";_reason=reason

func _step_detour() -> void:
	var result: Dictionary=_detour.step()
	if result.status=="SEARCHING": return
	if result.status!="FOUND": _block(str(result.get("reason","detour_failed")));return
	var rejoin: int=result.rejoin_index
	var proposal: PackedVector3Array=result.points
	if not _current() or proposal.is_empty() or proposal[0].distance_to(_token.body.global_position)>.05 or rejoin<_edge or rejoin>=_points.size():
		_block("detour_result_changed");return
	var fresh_prefix_count := proposal.size()
	for index in range(rejoin+1,_points.size()): proposal.append(_points[index])
	if proposal.size()==1:
		proposal.append(proposal[0])
		fresh_prefix_count=proposal.size()
	var admitted: Dictionary = _policy.authorize_errand_path(_owner.get_ref(),_token,_map,_iteration,proposal,_detour_reuse_cookie,fresh_prefix_count,rejoin+2) if _detour_reuse_cookie>=0 else _policy.authorize_errand_path(_owner.get_ref(),_token,_map,_iteration,proposal)
	if not admitted.get("ok",false) and _detour_reuse_cookie>=0:
		# Stale or changed suffix gets no reused proof; the ordinary full check
		# remains the only safe fallback for this same current physical owner.
		admitted=_policy.authorize_errand_path(_owner.get_ref(),_token,_map,_iteration,proposal)
	if not admitted.get("ok",false): _block(str(admitted.get("reason","detour_path_refused")));return
	_path_cookie=int(admitted.cookie);_points=proposal.slice(1);_edge=0;_request=-1
	_detour_reuse_cookie=-1
	_detour=null;_phase="WALKING";_reason=""

# Exact private queue intent. Re-reading _current proves today's physical life
# and claim; no memo/token receipt survives a physics frame.
func _initial_admission_intent_current(epoch: int, map: RID, iteration: int, proposal: PackedVector3Array) -> bool:
	if _phase!="PLANNING" or _replan_waiting or epoch!=_epoch or map!=_map or iteration!=_iteration or not _current(): return false
	# PackedVector equality is exact and implemented natively; no GDScript N²
	# point loop. Enqueue once verifies proposal[1:] against these exact points.
	return proposal==_initial_admission_proposal and _points==_initial_admission_points and proposal.size()==_points.size()+1

func _initial_admission_current(ticket: int, epoch: int, map: RID, iteration: int, proposal: PackedVector3Array) -> bool:
	return ticket==_initial_admission_ticket and _initial_admission_intent_current(epoch,map,iteration,proposal)

func _cancel_initial_path_admission() -> void:
	if _initial_admission_ticket>=0 and is_instance_valid(_policy): _policy.cancel_initial_path_admission(self,_initial_admission_ticket)
	_initial_admission_ticket=-1; _initial_admission_started_us=0; _initial_admission_proposal.clear(); _initial_admission_points.clear()
