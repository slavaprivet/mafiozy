extends RefCounted
## Complete opt-in physical errand. No body transform, gait or source-row writes.
## Outdoor DailyWalk proposes native legs; EntryRoute is host-stepped indoors.
const DailyWalk = preload("../npc_daily_walk.gd")
const EntryRoute = preload("npc_daily_entry_route.gd")
const Treatment = preload("npc_hospital_treatment_port.gd")
var _host: RefCounted
var _policy: RefCounted
var _health: RefCounted
var _site: Node3D
var _scene: Node3D
var _token: Dictionary = {}
var _activity: WeakRef
var _daily: RefCounted
var _route: RefCounted
var _treatment: RefCounted
var _account: RefCounted
var _goal: Dictionary = {}
var _route_bytes := PackedByteArray()
var _targets: Dictionary = {}
var _session := ""
var _kind := "hospital"
var _phase := "UNBOUND"
var _reason := ""
var _frame := -1
var _request := -1
var _treatment_id := -1
var _revision := -1
var _door_time := 0.0
var _door_claimed := false
var _bound := false
var _disposed := false
var _busy := false
var _service_result: Dictionary = {}
var _start_position := Vector3.ZERO
var _start_hp := 0.0
var _route_stats: Dictionary = {}
var _released := false
var _cancelling := false
var _entry_acquired := false
var _profile_peaks: Array[Dictionary] = []
var _timing_buckets: Dictionary = {}

func _init() -> void:
	for _index in 12: _profile_peaks.append({"part":"","phase":"","us":0})
	_ensure_timing_buckets()

func _new_timing_bucket() -> Dictionary:
	return {"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""}

func _ensure_timing_buckets() -> void:
	if not _timing_buckets.is_empty(): return
	for label: String in ["step_total","current","outdoor_step","outdoor_snapshot","entry_poll","occupants","door_update","service_poll","service_begin","entry_request"]:
		_timing_buckets[label]=_new_timing_bucket()

func _record_timing(label: String, started: int, frame: int=-1, phase: String="") -> void:
	if _timing_buckets.is_empty(): _ensure_timing_buckets()
	var elapsed:=Time.get_ticks_usec()-started
	var bucket: Dictionary=_timing_buckets[label]
	bucket["samples"]=int(bucket["samples"])+1
	bucket["total_us"]=int(bucket["total_us"])+elapsed
	if elapsed>int(bucket["max_us"]):
		bucket["max_us"]=elapsed
		bucket["max_frame"]=Engine.get_physics_frames() if frame<0 else frame
		bucket["max_phase"]=phase

func _profile(label: String, started: int) -> void:
	var elapsed := Time.get_ticks_usec() - started
	if elapsed < 1000: return
	var minimum_index:=0
	for index in range(1,_profile_peaks.size()):
		if int(_profile_peaks[index]["us"])<int(_profile_peaks[minimum_index]["us"]): minimum_index=index
	if elapsed<=int(_profile_peaks[minimum_index]["us"]): return
	var peak: Dictionary=_profile_peaks[minimum_index]
	peak["part"]=label; peak["phase"]=_phase; peak["us"]=elapsed; peak["frame"]=Engine.get_physics_frames()

func _profile_snapshot() -> Array[Dictionary]:
	var peaks: Array[Dictionary]=[]
	for peak: Dictionary in _profile_peaks:
		if int(peak["us"])>0: peaks.append(peak.duplicate())
	peaks.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.us)>int(b.us))
	return peaks

func configure(host: RefCounted, policy: RefCounted, hit_owner: RefCounted, hospital: Node3D, scene: Node3D, local_session: String, activity_owner: RefCounted=null) -> Dictionary:
	return _configure(host,policy,hit_owner,hospital,scene,local_session,activity_owner,"hospital",null,{})

## Same physical controller, with the separate existing account owner as the
## sole ledger writer. The exact public native bank gate must admit arrival.
func configure_bank(host: RefCounted, policy: RefCounted, hit_owner: RefCounted, bank: Node3D, scene: Node3D, local_session: String, activity_owner: RefCounted, account: RefCounted, goal: Dictionary) -> Dictionary:
	if not is_instance_valid(account) or not account.has_method("begin_service") or goal.get("kind")!="bank" or not goal.get("goal_id") is String:return {"ok":false,"reason":"actual_bank_account_goal"}
	return _configure(host,policy,hit_owner,bank,scene,local_session,activity_owner,"bank",account,goal)

func _configure(host:RefCounted,policy:RefCounted,health:RefCounted,site:Node3D,scene:Node3D,session:String,activity:RefCounted,kind:String,account:RefCounted,goal:Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _phase!="UNBOUND" or _disposed or session.is_empty() or not is_instance_valid(health) or health._host!=host:return {"ok":false,"reason":"current_health_host"}
	var token:Dictionary=health._token
	if health._current(health._binding).is_empty() or not host.target_current(token) or not is_instance_valid(site) or not site.get("ready_for_use") or not is_instance_valid(scene) or not scene.has_method("_current_door_occupants"):return {"ok":false,"reason":"current_actor_loaded_site_occupants"}
	var root_dir:String=get_script().resource_path.get_base_dir()
	var data_path:String=root_dir+"/hospital_route_data.json" if kind=="hospital" else root_dir+"/../bank_geometry/bank_route_data.json"
	var bytes:=FileAccess.get_file_as_bytes(data_path)
	var data:Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary or not EntryRoute.ACCEPTED.has(data.get("source_id")) or EntryRoute._hash(bytes)!=EntryRoute.ACCEPTED[data.source_id] or site.targets().get("data_sha256")!=data.interior_sha256:return {"ok":false,"reason":"accepted_entry_packet"}
	_host=host;_policy=policy;_health=health;_site=site;_scene=scene;_token=token.duplicate();_session=session;_kind=kind;_account=account;_goal=goal.duplicate(true);_route_bytes=bytes
	_activity=weakref(activity if activity!=null else self)
	for key:String in data.goals:_targets[key]=EntryRoute._v(data.goals[key])
	if kind=="hospital":
		_treatment=Treatment.new();var result:Dictionary=_treatment.configure(health,site,session)
		if not result.get("ok",false):_treatment.dispose();_treatment=null;return result
	else:
		if not account.snapshot().get("bank_bound",false):
			var result:Dictionary=account.bind_bank(scene)
			if not result.get("ok",false):return result
	_daily=DailyWalk.new()
	var accepted:Dictionary=_daily.configure(host,token,_activity.get_ref())
	if not accepted.get("ok",false):_daily.dispose();_daily=null;if_treatment_dispose();return accepted
	_phase="READY"
	return {"ok":true,"kind":kind,"source_id":token.source_id,"hospital_or_bank_id":data.source_id,"handoff":_targets.handoff,"host_sole_mover":true,"parent_activity_preserved":activity!=null}

func if_treatment_dispose() -> void:
	if _treatment!=null:_treatment.dispose();_treatment=null

func _current() -> bool:
	var started := Time.get_ticks_usec()
	var frame := Engine.get_physics_frames()
	var phase := _phase
	var result := _current_impl()
	_record_timing("current",started,frame,phase)
	_profile("current",started)
	return result

func _current_impl() -> bool:
	if not Thread.is_main_thread() or _disposed or _host==null or not is_instance_valid(_health) or not is_instance_valid(_site) or not _site.is_inside_tree() or not _site.ready_for_use or _activity==null or not is_instance_valid(_activity.get_ref()):return false
	if _health._host!=_host or _health._token!=_token or _health._current(_health._binding).is_empty() or not _host.target_current(_token):return false
	var row:Dictionary=_health._row
	if row.hp<=0 or row.get("dead",false) or row.get("alive",true)==false:return false
	for key:String in ["_medicalDowned","_forcedCrawl","_inVehicle","_ambulanceInTransit","_carriedByAmbulance","_evacuated"]:
		if row.get(key,false):return false
	var lease:Dictionary=_host.daily_activity_status(_token.source_id)
	return lease.get("owner")==_activity.get_ref() and lease.get("current",false) and lease.get("life_generation")==_token.life_generation

func begin() -> Dictionary:
	if _busy or _phase!="READY" or not _current():return {"ok":false,"reason":"current_ready_visit"}
	if _kind=="hospital" and _health._row.hp>=_health._row.max_hp:return {"ok":false,"reason":"no_treatment_needed"}
	_revision=int(_health._adapter._revision);_start_hp=float(_health._row.hp);_start_position=_token.body.global_position
	var result:Dictionary=_daily.begin(_targets.handoff)
	if not result.get("ok",false):_reason=str(result.get("reason","outdoor_route"));return result
	_phase="WALKING_TO_STREET"
	return {"ok":true,"status":_phase,"kind":_kind}

func _claim_door() -> bool:
	var existing:Variant=_site.get_meta("daily_entry_visit_owner") if _site.has_meta("daily_entry_visit_owner") else null
	if existing is WeakRef and is_instance_valid(existing.get_ref()) and existing.get_ref()!=self:return false
	_site.set_meta("daily_entry_visit_owner",weakref(self));_door_claimed=true;return true
func _door_current() -> bool:
	if not is_instance_valid(_site) or not _door_claimed:return false
	var claim:Variant=_site.get_meta("daily_entry_visit_owner") if _site.has_meta("daily_entry_visit_owner") else null
	return claim is WeakRef and claim.get_ref()==self
func _occupants() -> Array:
	var started:=Time.get_ticks_usec()
	var result: Array=[]
	if is_instance_valid(_scene): result=_scene._current_door_occupants()
	_record_timing("occupants",started,Engine.get_physics_frames(),_phase)
	return result

func _bind_entry() -> bool:
	if not _current() or not _claim_door():_reason="entry_door_owned";return false
	_route=EntryRoute.new()
	var result:Dictionary=_route.configure(_host,_policy,_host._navigation,_scene,_token,_site,_route_bytes,_activity.get_ref())
	if not result.get("ok",false):_reason=str(result.get("reason","entry_configure"));_route.dispose();_route=null;return false
	# Prove the actual street handoff while DailyWalk's exact native path lease
	# still exists. Cancellation then revokes that path before local binding.
	var cancelled:Dictionary=_daily.cancel()
	if not cancelled.get("ok",false):_reason="outdoor_request_not_released";_route.dispose();_route=null;return false
	result=_host.bind_local_navigation_adapter(_route,_token)
	if not result.get("ok",false):_reason=str(result.get("reason","public_bind"));_route.dispose();_route=null;return false
	_bound=true;_entry_acquired=true;return true

func _request_target(key:String,phase:String) -> bool:
	var started:=Time.get_ticks_usec()
	var frame:=Engine.get_physics_frames()
	if _route==null or not _door_current():
		_record_timing("entry_request",started,frame,phase)
		_reason="entry_owner_changed";return false
	var result:Dictionary=_route.request_target(key)
	_record_timing("entry_request",started,frame,phase)
	if not result.get("ok",false):_reason="entry_admission:"+str(result.get("reason","unknown"));return false
	_request=int(result.request_id);_phase=phase;return true

func step(delta:float) -> void:
	var frame:=Engine.get_physics_frames()
	var started:=Time.get_ticks_usec()
	var phase_at_start:=_phase
	_step_impl(delta)
	_record_timing("step_total",started,frame,phase_at_start)

func _step_impl(delta:float) -> void:
	if _busy or _disposed or not Thread.is_main_thread() or not is_finite(delta) or delta<=0 or delta>.05:return
	var frame:=Engine.get_physics_frames()
	if frame==_frame:return
	_frame=frame
	if _phase in ["UNBOUND","READY","COMPLETE","CANCELLED","BLOCKED","DISPOSED"]:return
	_busy=true
	if _phase=="HOLD":
		if _bound and _current() and _route!=null and _route._current():
			_revision=int(_health._adapter._revision)
			_start_unwind()
		_busy=false;return
	if not _current():_stop("actor_injury_death_or_owner_changed");return
	if int(_health._adapter._revision)!=_revision:_stop("new_health_event");return
	if _bound and (_route==null or not _route._current() or not _door_current()):_stop("local_request_or_geometry_superseded");return
	if _phase=="WALKING_TO_STREET":
		var profile_started := Time.get_ticks_usec()
		_daily.step(delta);_record_timing("outdoor_step",profile_started,frame,_phase);_profile("outdoor_step",profile_started)
		profile_started=Time.get_ticks_usec()
		var status:Dictionary=_daily.snapshot();_record_timing("outdoor_snapshot",profile_started,frame,_phase);_profile("outdoor_snapshot",profile_started)
		if status.status=="COMPLETE":
			if not _bind_entry() or not _request_target("street","WALKING_ONTO_APPROACH"):_stop(_reason);return
		elif status.status in ["BLOCKED","CANCELLED","DISPOSED"]:_stop("outdoor:"+str(status.reason));return
	elif _phase in ["WALKING_ONTO_APPROACH","WALKING_TO_DOOR","WALKING_TO_THRESHOLD","WALKING_INSIDE","WALKING_TO_SERVICE","EXITING_TO_THRESHOLD","EXITING_TO_DOOR","RETURNING_TO_STREET","RETURNING_TO_HANDOFF"]:
		var profile_started := Time.get_ticks_usec()
		var result:Dictionary=_route.poll(_request);_record_timing("entry_poll",profile_started,frame,_phase);_profile("entry_poll",profile_started)
		if result.status not in ["READY","PENDING","ARRIVED"]:_stop("entry_route:"+str(result.status)+":"+str(result.get("reason","")));return
		if result.status=="ARRIVED":
			match _phase:
				"WALKING_ONTO_APPROACH":
					if not _request_target("outside","WALKING_TO_DOOR"):_stop(_reason);return
				"WALKING_TO_DOOR":_phase="OPENING";_door_time=0.0
				"WALKING_TO_THRESHOLD":
					if not _request_target("inside","WALKING_INSIDE"):_stop(_reason);return
				"WALKING_INSIDE":
					if not _request_target("service","WALKING_TO_SERVICE"):_stop(_reason);return
				"WALKING_TO_SERVICE":
					if not _begin_service():_stop(_reason);return
				"EXITING_TO_THRESHOLD":
					if not _request_target("outside","EXITING_TO_DOOR"):_stop(_reason);return
				"EXITING_TO_DOOR":_phase="CLOSING";_door_time=0.0
				"RETURNING_TO_STREET":
					if not _request_target("handoff","RETURNING_TO_HANDOFF"):_stop(_reason);return
				"RETURNING_TO_HANDOFF":
					if not _route.purposeful_handoff_current():_stop("current_purposeful_handoff_refused");return
					if not _release_entry():_stop("public_entry_release_failed");return
					_release_door();_released=true;_phase="CANCELLED" if _cancelling else "COMPLETE"
	elif _phase in ["OPENING","CANCEL_OPENING","CLOSING"]:
		var opening:=_phase!="CLOSING";var fraction:float=_site.door_fraction("public")
		if fraction==(1.0 if opening else 0.0):
			var goal_key:="outside" if _cancelling and opening else ("threshold" if opening else "street")
			var next_phase:="EXITING_TO_DOOR" if _cancelling and opening else ("WALKING_TO_THRESHOLD" if opening else "RETURNING_TO_STREET")
			if not _request_target(goal_key,next_phase):_stop(_reason);return
		else:
			var people:Array=_occupants()
			if not _current() or not _door_current():_stop("owner_changed_during_occupants");return
			var door_started:=Time.get_ticks_usec()
			var door:Dictionary=_site.request_door("public",opening,_token.body.global_position,people)
			if door.get("accepted",false):
				# Root should not separately advance this site's door while this
				# exclusive controller holds the daily_entry_visit_owner claim.
				_site.advance(delta,people)
			_record_timing("door_update",door_started,frame,_phase)
			_door_time+=delta
			if _door_time>12.0:_stop("door_sweep_or_action_timeout");return
	elif _phase=="TREATING":
		var treatment_started:=Time.get_ticks_usec()
		var result:Dictionary=_treatment.poll(_treatment_id)
		_record_timing("service_poll",treatment_started,frame,_phase)
		if result.status=="COMPLETE":
			_service_result=result.duplicate(true);_revision=int(_health._adapter._revision)
			if not _request_target("threshold","EXITING_TO_THRESHOLD"):_stop(_reason);return
		elif result.status!="PENDING":_stop("treatment:"+str(result.get("reason",result.status)));return
	_busy=false

func _begin_service() -> bool:
	var service_started:=Time.get_ticks_usec()
	if _kind=="hospital":
		var result:Dictionary=_treatment.begin(_request)
		_record_timing("service_begin",service_started)
		if not result.get("ok",false):_reason="treatment_begin:"+str(result.get("reason","unknown"));return false
		_treatment_id=int(result.treatment_id);_phase="TREATING";return true
	var result:Dictionary=_account.begin_service(_goal,null,_health._now())
	_record_timing("service_begin",service_started)
	if not _current():_reason="account_changed_actor_owner";return false
	if not result.get("ok",false) or result.get("status")!="COMPLETE":_reason="bank_arrival_service:"+str(result.get("reason","not_completed"));return false
	_service_result=result.duplicate(true)
	return _request_target("threshold","EXITING_TO_THRESHOLD")

func _release_entry() -> bool:
	if _route==null:return true
	_route_stats=_route.diagnostics.duplicate(true)
	var okay:=true
	if _bound:
		var result:Dictionary=_host.release_local_navigation_adapter(_route,_token)
		okay=result.get("ok",false)
		# Auto-release after death/stale life may already have completed. A
		# newer proxy must remain untouched even though this child is obsolete.
		if not okay and _host._navigation!=_route:okay=true
	if not okay:return false
	_route.dispose();_route=null;_bound=false;_request=-1;return true
func _release_door() -> void:
	if _door_current():_site.remove_meta("daily_entry_visit_owner")
	_door_claimed=false
func _stop(reason:String) -> void:
	if _treatment!=null and _treatment_id>=0:_treatment.cancel(_treatment_id)
	_reason=reason;_cancelling=true
	if not _bound:
		var result:Dictionary=_daily.cancel() if _daily!=null else {"ok":true}
		_released=result.get("ok",false) and not _entry_acquired
		_release_door();_phase="CANCELLED" if _released else "HOLD";_busy=false;return
	# Injury while still walking cancels service, then physically unwinds. A
	# dead/stale/replaced actor is never moved or advertised as safely released.
	if not _current() or _route==null or not _route._current():
		if _route==null or not _host.physical_life_current(_token) or not _host._local_walker_current(_token) or not _route._owns_life() or _host._navigation!=_route:
			_release_entry();_release_door()
		_phase="HOLD";_busy=false;return
	_revision=int(_health._adapter._revision)
	_start_unwind();_busy=false

func _start_unwind() -> void:
	if _route==null or not _door_current():_phase="HOLD";return
	if _phase in ["RETURNING_TO_STREET","RETURNING_TO_HANDOFF"] and _route.poll(_request).status in ["READY","ARRIVED"]:return
	var fraction:float=_site.door_fraction("public")
	var outward:Vector3=(_targets.street-_targets.threshold).normalized()
	var outside_distance:float=(_targets.outside-_targets.threshold).dot(outward)
	var actually_outside:bool=(_token.body.global_position-_targets.threshold).dot(outward)>=outside_distance-.04
	if fraction==0.0 and actually_outside:
		if not _request_target("street","RETURNING_TO_STREET"):_phase="HOLD"
	elif fraction==1.0:
		if not _request_target("outside","EXITING_TO_DOOR"):_phase="HOLD"
	else:
		# A partially moving leaf must be completed safely before crossing.
		_phase="CANCEL_OPENING";_door_time=0.0

func cancel(reason:String="cancelled") -> Dictionary:
	if not Thread.is_main_thread():return {"ok":false,"reason":"main_thread_required"}
	if _disposed:return {"ok":true,"status":"DISPOSED"}
	if _busy:return {"ok":false,"reason":"controller_busy"}
	if _phase=="COMPLETE":return {"ok":true,"status":"COMPLETE","service_result":_service_result.duplicate(true)}
	_stop(reason);return {"ok":true,"status":_phase,"released":_released,"reason":_reason,"at_site":is_instance_valid(_site) and _token.get("body")!=null and is_instance_valid(_token.body) and _site.contains_service(_token.body.global_position)}

func snapshot() -> Dictionary:
	return {"status":_phase,"reason":_reason,"kind":_kind,"released":_released,"cancelling":_cancelling,"source_id":_token.get("source_id",""),"life_generation":_token.get("life_generation",-1),"request_id":_request,"treatment_id":_treatment_id,"hp_before":_start_hp,"service_completed":not _service_result.is_empty(),"service_result":_service_result.duplicate(true),"local_route_bound":_bound,"door_owned":_door_current(),"outdoor":_daily.snapshot() if _daily!=null else {},"entry":_route.diagnostics.duplicate(true) if _route!=null else _route_stats.duplicate(true),"source_state_written":false,"actor_transform_written":false,"profile_peaks":_profile_snapshot(),"timing_buckets":_timing_buckets.duplicate(true)}

func dispose() -> void:
	if _disposed or not Thread.is_main_thread():return
	if not _released:
		_stop("disposed")
		# A current living actor still inside must receive cleanup ticks. A
		# retired life can drop resources without claiming physical handoff.
		if not _released and _host!=null and _host._local_walker_current(_token):return
	else:_release_entry();_release_door()
	if _daily!=null:_daily.dispose();_daily=null
	if_treatment_dispose();_disposed=true;_phase="DISPOSED";_host=null;_policy=null;_health=null;_account=null;_activity=null
