extends RefCounted
## Native errand travel. The existing host remains the sole movement/gait tick.
## A map path is only a proposal: every short leg uses current source + physics.
const Detour = preload("city/runtime/npc_native_obstacle_detour.gd")
const MAX_LEG_M := 5.0
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
const MAX_POINTS := 4096
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
var _last_motion := Vector3.ZERO
var _last_motion_at := 0.0
var _last_leg_failure := {}
var _path_admission := {}
var _native_endpoints := {}

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
	var backend: RefCounted = _navigation.get("_backend")
	_map=backend.map_rid()
	if not _map.is_valid(): return {"ok":false,"reason":"native_map_missing"}
	_target=target; _epoch+=1; _edge=0; _points.clear(); _active_time=0.0; _reason=""
	_iteration=NavigationServer3D.map_get_iteration_id(_map)
	var parameters:=NavigationPathQueryParameters3D.new()
	parameters.map=_map; parameters.start_position=_token.body.global_position; parameters.target_position=target
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
	_query_us=Time.get_ticks_usec()-_query_started
	if not _map.is_valid() or NavigationServer3D.map_get_iteration_id(_map)!=iteration:
		_block("navigation_changed_during_query"); return
	var path: PackedVector3Array=result.get_path()
	_native_endpoints={"count":path.size(),"target":_target,"body":_token.body.global_position}
	if not path.is_empty(): _native_endpoints.merge({"first":path[0],"last":path[-1],"start_gap":path[0].distance_to(_token.body.global_position),"target_gap":path[-1].distance_to(_target)})
	if path.is_empty() or path.size()>MAX_POINTS or path[-1].distance_to(_target)>.20 or path[0].distance_to(_token.body.global_position)>2.0:
		_block("destination_not_on_current_native_map"); return
	if path[0].distance_to(_token.body.global_position)>.35 and (_policy==null or not _policy.native_clear_segment(_token,_token.body.global_position,path[0])):
		_block("actual_start_connector_blocked"); return
	var previous: Vector3=_token.body.global_position
	for point: Vector3 in path:
		if not point.is_finite(): _block("nonfinite_native_path"); return
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
	if not _current(): _block("actor_or_navigation_owner_ended"); return
	var pause: Callable=_host._records[_token.source_id].get("walk_pause",Callable())
	var paused:=pause.is_valid() and bool(pause.call())
	if not _current(): _block("actor_changed_during_pause_check"); return
	if paused: return
	_active_time+=delta
	if _active_time>900.0: _block("bounded_errand_deadline"); return
	if _phase=="DETOUR":
		_step_detour();return
	if _phase=="PLANNING":
		if Time.get_ticks_usec()-_query_started>10000000: _block("native_query_timeout")
		return
	if _request<0:
		if _navigation.state()!="READY": return
		_request=_host.request_daily_walk(_owner.get_ref(),_token,_points[_edge])
		if _request<0:
			_last_leg_failure={"body":_token.body.global_position,"target":_points[_edge],"host_reason":_host._records[_token.source_id].get("reason",""),"policy":_policy.diagnostics() if _policy!=null else {}}
			_begin_detour("current_leg_admission_refused"); return
		_leg_started=_active_time
		_last_motion=_token.body.global_position;_last_motion_at=_active_time
		return
	if int(_host._records[_token.source_id].get("request",-1))!=_request:
		_block("exact_native_request_superseded"); return
	var native: Dictionary=_navigation.poll(_request)
	var status: String=str(native.get("status","UNKNOWN"))
	if status=="ARRIVED":
		var body: CharacterBody3D=_token.body
		if not body.is_on_floor() or Vector2(body.global_position.x-_points[_edge].x,body.global_position.z-_points[_edge].z).length()>.20:
			_block("arrival_without_physical_position"); return
		_edge+=1
		if _edge>=_points.size(): _phase="COMPLETE"; return
		if not _cancel_request(): _block("completed_leg_cancellation_refused"); return
	elif status in ["BLOCKED","NO_PATH"]:
		_begin_detour("native_route:"+status)
	elif status not in ["PENDING","READY"]:
		_block("native_route:"+status)
	elif _active_time-_leg_started>30.0:
		_begin_detour("native_leg_deadline")
	elif status=="READY":
		if _token.body.global_position.distance_to(_last_motion)>.03:
			_last_motion=_token.body.global_position;_last_motion_at=_active_time
		elif _active_time-_last_motion_at>2.0:
			_begin_detour("current_ready_leg_no_motion")

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
	if _detour!=null: _detour.cancel()
	_epoch+=1; _phase="BLOCKED"; _reason=reason
	_cancel_request()
	_revoke_path()

func _revoke_path() -> void:
	if _path_cookie<0: return
	if is_instance_valid(_policy) and _owner!=null and is_instance_valid(_owner.get_ref()):
		_policy.revoke_errand_path(_owner.get_ref(),_token,_path_cookie)
	_path_cookie=-1

func cancel() -> Dictionary:
	if _detour!=null: _detour.cancel()
	_epoch+=1
	if not _cancel_request(): return {"ok":false,"reason":"exact_cancellation_unconfirmed"}
	_revoke_path()
	_phase="CANCELLED"; return {"ok":true}

func snapshot() -> Dictionary:
	return {"status":_phase,"reason":_reason,"epoch":_epoch,"target":_target,"leg":_edge,"legs":_points.size(),"request_id":_request,"active_seconds":_active_time,"native_query_wall_us":_query_us,"actor_transform_written":false,"source_authority":false,"path_admission":_path_admission,"last_leg_failure":_last_leg_failure,"native_endpoints":_native_endpoints,"detour":_detour.snapshot() if _detour!=null else {}}

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


func _begin_detour(reason: String) -> void:
	if not _current() or _policy==null or not _policy.has_method("native_clear_segment") or _detour_count>=2:
		_block(reason+":detour_unavailable_or_budget");return
	# Only the exact current job is cancelled; the helper cannot move actors,
	# cancel other work, or authorize its proposals.
	if not _cancel_request(): _block("detour_exact_cancellation_refused");return
	_revoke_path()
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
	for index in range(rejoin+1,_points.size()): proposal.append(_points[index])
	if proposal.size()==1: proposal.append(proposal[0])
	var admitted: Dictionary=_policy.authorize_errand_path(_owner.get_ref(),_token,_map,_iteration,proposal)
	if not admitted.get("ok",false): _block(str(admitted.get("reason","detour_path_refused")));return
	_path_cookie=int(admitted.cookie);_points=proposal.slice(1);_edge=0;_request=-1
	_detour=null;_phase="WALKING";_reason=""
