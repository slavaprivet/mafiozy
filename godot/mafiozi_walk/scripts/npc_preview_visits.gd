extends RefCounted
## Root-owned, one-shot local preview scheduler. The resident host remains the
## sole movement/gait owner. No source agenda, HP, saved row or transform writes.
const Route = preload("res://scripts/npc_visual/npc_local_printshop_route.gd")
const Visit = preload("res://scripts/npc_visual/npc_local_printshop_visit.gd")
const DIRECTORY := "res://assets/npc_visual/local_printshop/"
const ACTOR := "resident_169"
const SCOPE := "NEW_LOCAL_PREVIEW_SESSION_ONE_ORIGINAL_PHYSICAL_ENTRY"
const LOCAL_SESSION := "LOCAL_NPC_VISIT23:root24-printshop-once"
const START_DELAY := 3.0
const NAV_WAIT_LIMIT := 30.0
const TOTAL_ACTIVE_LIMIT := 180.0
const VISIT_LIMIT := 45.0
const CLEARANCE_LIMIT := 10.0
const CLEARANCE_INTERVAL := .5
const CLEARANCE_SAMPLE := .25
const ORIGINAL_OTHER_ACTORS := ["resident_72","resident_252"]
const FOOTPRINT := .738
const BODY_HEIGHT := 1.9
const SUPPORT_OFFSETS := [Vector2.ZERO,Vector2(-FOOTPRINT,-FOOTPRINT),Vector2(-FOOTPRINT,FOOTPRINT),Vector2(FOOTPRINT,-FOOTPRINT),Vector2(FOOTPRINT,FOOTPRINT)]
const TERMINAL_ROUTE := ["BLOCKED","NO_PATH","STALE","CANCELLED","REJECTED","UNSUPPORTED_BODY"]
var _scene: WeakRef
var _host: RefCounted
var _navigation: RefCounted
var _policy: RefCounted
var _route: RefCounted
var _visit: RefCounted
var _door_started: Callable
var _occupants: Callable
var _entry := PackedByteArray()
var _geometry := PackedByteArray()
var _points: Array[Vector3] = []
var _token := {}
var _lease_serial := -1
var _phase := "UNBOUND"
var _reason := ""
var _clock := 0.0
var _phase_at := 0.0
var _paused_seconds := 0.0
var _paused := false
var _leg := 0
var _leg_attempts := 0
var _leg_since := 0.0
var _leg_budget := 0.0
var _clearance_leg := -1
var _clearance_until := 0.0
var _clearance_next_at := 0.0
var _clearance_polls := 0
var _clearance_waits := 0
var _clearance_probe_count := 0
var _clearance_probe_total_us := 0
var _clearance_probe_max_us := 0
var _clearance_probe_samples: Array[int] = []
var _clearance_last := {}
var _clearance_history: Array[Dictionary] = []
var _clearance_shape := BoxShape3D.new()
var _clearance_query := PhysicsShapeQueryParameters3D.new()
var _clearance_ray := PhysicsRayQueryParameters3D.new()
var _visit_since := 0.0
var _request := -1
var _visit_request := -1
var _cancel_result := {}
var _cancel_attempts := 0
var _requests := 0
var _approach_requests := 0
var _retries := 0
var _last_step_frame := -1
var _last_request_frame := -1
var _duplicate_steps := 0
var _invalid_deltas := 0
var _request_limit_hits := 0
var _bound := false
var _disposed := false
var _history: Array[Dictionary] = []
var _legs: Array[Dictionary] = []
var _last_visit_status := {}
var _release_result := {}
var _release_attempts := 0
var _approach_sha := ""

func setup(world: Node3D, host: RefCounted, navigation: RefCounted, policy: RefCounted, door_started: Callable, occupants: Callable) -> Dictionary:
	if _phase!="UNBOUND" or _disposed or not Thread.is_main_thread():return {"ok":false,"reason":"scheduler_lifetime"}
	if not is_instance_valid(world) or not world.is_inside_tree() or host==null or navigation==null or policy==null or not door_started.is_valid() or not occupants.is_valid():return {"ok":false,"reason":"binding"}
	for method: String in ["bind_local_navigation_adapter","cancel_local_walk","release_local_navigation_adapter","local_navigation_adapter_status","target_from_collider","target_current","request_walk"]:
		if not host.has_method(method):return {"ok":false,"reason":"public_owner_contract_missing:"+method}
	_scene=weakref(world);_host=host;_navigation=navigation;_policy=policy;_door_started=door_started;_occupants=occupants
	_clearance_shape.size=Vector3(FOOTPRINT*2,BODY_HEIGHT,FOOTPRINT*2)
	_clearance_query.shape=_clearance_shape;_clearance_query.collision_mask=1|256;_clearance_query.margin=.001
	_clearance_ray.collision_mask=1
	_entry=FileAccess.get_file_as_bytes(DIRECTORY+"entry.v1.json")
	_geometry=FileAccess.get_file_as_bytes(DIRECTORY+"geometry.v1.json")
	if not _read_approach():
		_change("HOLD","invalid_declared_local_approach_data")
		return {"ok":false,"reason":_reason}
	_change("WAIT_NAV","waiting_for_native_READY")
	return {"ok":true,"scope":SCOPE,"source_id":ACTOR,"once_per_launch":true}

func _read_approach() -> bool:
	var path: String=DIRECTORY+"approach.v1.json"
	var file: FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null:return false
	var length: int=file.get_length()
	if length>16384:file.close();return false
	var bytes: PackedByteArray=file.get_buffer(length)
	file.close()
	if bytes.size()!=length:return false
	var parser:=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return false
	var data: Dictionary=parser.data
	if data.get("schema")!="mafiozi.local-printshop-approach/v1" or data.get("scope")!=SCOPE or data.get("source_id")!=ACTOR or data.get("original_source_progression")!=false:return false
	if not data.get("path") is Array or data.path.is_empty() or data.path.size()>64 or int(data.get("leg_count",-1))!=data.path.size():return false
	var points: Array[Vector3]=[]
	for value: Variant in data.path:
		if not value is Array or value.size()!=3:return false
		for coordinate: Variant in value:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):return false
		var point:=Vector3(value[0],value[1],value[2])
		if not points.is_empty() and point.distance_to(points[-1])>8.0:return false
		points.append(point)
	var entry_parser:=JSON.new()
	if entry_parser.parse(_entry.get_string_from_utf8())!=OK or not entry_parser.data is Dictionary:return false
	var outside: Variant=entry_parser.data.get("public_approach_preview")
	if not outside is Array or outside.size()!=3:return false
	if points[-1].distance_to(Vector3(outside[0],outside[1],outside[2]))>1.6:return false
	_points=points;_approach_sha=FileAccess.get_sha256(path)
	return true

func _change(phase: String, reason: String="") -> void:
	if _phase==phase and _reason==reason:return
	_phase=phase;_reason=reason;_phase_at=_clock
	if _history.size()<128:_history.append({"phase":phase,"reason":reason,"active_seconds":_clock,"leg":_leg})

func _record() -> Dictionary:
	# Read-only access to the currently installed pause callback/request cursor.
	# In particular, do not erase the selected actor's preview entry or write row.
	if _host==null:return {}
	var rows: Variant=_host.get("_records")
	return rows.get(ACTOR,{}) if rows is Dictionary else {}

func _world() -> Node3D:
	return _scene.get_ref() as Node3D if _scene!=null else null

func _current() -> bool:
	var world: Node3D=_world()
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and _host!=null and _host.target_current(_token)

func _same_public_lease() -> bool:
	if not _bound or _host==null:return false
	var state: Dictionary=_host.local_navigation_adapter_status()
	return state.get("bound",false) and state.get("source_id")==ACTOR and state.get("serial")==_lease_serial

func _bind() -> void:
	var world: Node3D=_world()
	if not is_instance_valid(world):_hold("scene_ended");return
	var actor: Node=world.get_node_or_null("npc_"+ACTOR)
	_token=_host.target_from_collider(actor)
	if not _token.get("ok",false) or _token.get("source_id")!=ACTOR:_hold("original_walking_actor_unavailable");return
	_route=Route.new()
	if not _route.configure(_host,_policy,_navigation,world,_token,_entry,_geometry):_hold("entry_adapter_configuration_refused");return
	var result: Dictionary=_host.bind_local_navigation_adapter(_route,_token)
	if not result.get("ok",false):_hold("public_bind_refused:"+str(result.get("reason","unknown")));return
	_bound=true;_lease_serial=int(result.serial)
	_change("START_DELAY","three_second_preview_pause")

func _claim_request_frame() -> bool:
	var frame: int=Engine.get_physics_frames()
	if _last_request_frame==frame:_request_limit_hits+=1;return false
	_last_request_frame=frame;_requests+=1
	return true

func _request_leg() -> void:
	if _leg>=_points.size():_begin_visit();return
	if _navigation.state()!="READY":return
	if not _claim_request_frame():return
	var body: CharacterBody3D=_token.body
	var distance: float=body.global_position.distance_to(_points[_leg])
	if distance>8.0:_hold("current_leg_outside_native_request_range");return
	_leg_attempts+=1;_approach_requests+=1;_leg_since=_clock
	var speed: float=maxf(.25,float(_record().get("speed",1.8)))
	_leg_budget=clampf(4.0+distance/speed*2.5,6.0,20.0)
	_request=_host.request_walk(ACTOR,_points[_leg])
	if _request<0:_retry_or_hold("native_request_refused");return
	_legs.append({"leg":_leg,"attempt":_leg_attempts,"request_id":_request,"from":_xyz(body.global_position),"goal":_xyz(_points[_leg]),"start_active_seconds":_clock,"deadline_seconds":_leg_budget})
	_change("APPROACH","native_leg_"+str(_leg+1))

func _approach_tick() -> void:
	if _request<0:
		if _clock-_phase_at>20.0:_hold("native_ready_wait_timeout")
		else:_request_leg()
		return
	if int(_record().get("request",-1))!=_request:_hold("ordinary_route_superseded");return
	var result: Dictionary=_navigation.poll(_request)
	var status: String=str(result.get("status","UNKNOWN"))
	if status=="ARRIVED":
		var body: CharacterBody3D=_token.body
		var distance: float=Vector2(body.global_position.x-_points[_leg].x,body.global_position.z-_points[_leg].z).length()
		if distance>.20 or not body.is_on_floor():_hold("native_arrival_without_physical_position");return
		_legs[-1].status=status;_legs[-1].arrival=_xyz(body.global_position);_legs[-1].elapsed_seconds=_clock-_leg_since
		_request=-1;_leg+=1;_leg_attempts=0;_clearance_leg=-1
		# Next leg starts on a later physics frame, never a catch-up loop.
		_change("APPROACH","next_native_leg")
	elif status in TERMINAL_ROUTE:
		_retry_or_hold("native_route:"+status)
	elif status not in ["PENDING","READY"]:
		_hold("unknown_native_route_status:"+status)
	elif _clock-_leg_since>=_leg_budget:
		_retry_or_hold("native_leg_deadline")

func _cancel_owned_request(request_id: int) -> bool:
	if request_id<0:return true
	# A replaced request or ended life must never be cancelled through the base
	# navigation. Public release can retire our old lease without touching it.
	if not _same_public_lease() or not _current():
		_cancel_result={"skipped":true,"reason":"exact_live_lease_ended","request_id":request_id}
		return true
	if int(_record().get("request",-1))!=request_id:
		_cancel_result={"skipped":true,"reason":"exact_request_no_longer_current","request_id":request_id}
		return true
	_cancel_attempts+=1
	_cancel_result=_host.cancel_local_walk(_route,_token,request_id)
	return _cancel_result.get("ok",false) and _cancel_result.get("cancelled_request_id",-1)==request_id

func _cancel_approach() -> bool:
	if not _cancel_owned_request(_request):return false
	_request=-1;return true

func _cancel_visit(request_id: int) -> void:
	# Visit callbacks may arrive after a newer leg. Retain a failed current
	# cancellation for bounded public-release retries; never clear a host field.
	if request_id!=_visit_request:return
	if _cancel_owned_request(request_id):_visit_request=-1

func _retry_or_hold(reason: String) -> void:
	if not _legs.is_empty() and _legs[-1].get("request_id")==_request:
		_legs[-1].status=reason;_legs[-1].elapsed_seconds=_clock-_leg_since
	if not _cancel_approach():_hold("public_approach_cancellation_unconfirmed");return
	# A refusal is not permission to ignore its obstacle. Wait only when the
	# unchanged segment has clear source/floor admission and exclusively current
	# original living walkers in the actual physical footprint. All retries still
	# use the public owner; no collision filters or owner state are changed.
	_clearance_last=_take_clearance_probe()
	if _clearance_last.get("kind")!="original_living_npc":_hold(reason+":"+str(_clearance_last.get("kind","unknown")));return
	if _clearance_leg!=_leg:_clearance_leg=_leg;_clearance_until=_clock+CLEARANCE_LIMIT
	if _clock>=_clearance_until:_hold("original_npc_clearance_deadline");return
	_clearance_waits+=1;_clearance_next_at=_clock+CLEARANCE_INTERVAL
	if _clearance_history.size()<64:_clearance_history.append({"leg":_leg,"at":_clock,"until":_clearance_until,"reason":reason,"evidence":_clearance_last.duplicate(true)})
	_change("WAIT_FOR_CLEARANCE","original_living_npc_in_current_segment")

func _take_clearance_probe() -> Dictionary:
	var began: int=Time.get_ticks_usec()
	var result: Dictionary=_probe_clearance()
	var elapsed: int=Time.get_ticks_usec()-began
	_clearance_probe_count+=1;_clearance_probe_total_us+=elapsed
	_clearance_probe_max_us=maxi(_clearance_probe_max_us,elapsed)
	if _clearance_probe_samples.size()<64:_clearance_probe_samples.append(elapsed)
	result["microseconds"]=elapsed
	return result

func _probe_clearance() -> Dictionary:
	var began: int=Time.get_ticks_usec()
	if _leg>=_points.size() or not _current() or not _same_public_lease():return {"kind":"actor_or_lease_changed"}
	var world: Node3D=_world();var body: CharacterBody3D=_token.body
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var excluded: Array[RID]=[body.get_rid()]
	_clearance_query.exclude=excluded;_clearance_ray.exclude=excluded
	var start: Vector3=body.global_position;var target: Vector3=_points[_leg]
	var count: int=maxi(1,int(ceil(start.distance_to(target)/CLEARANCE_SAMPLE)))
	if count>33:return {"kind":"segment_outside_bounded_range"}
	var blockers := {}
	for sample_index: int in count+1:
		var point: Vector3=start.lerp(target,float(sample_index)/count)
		if not _policy.source_admit(point,ACTOR,int(_token.life_generation),FOOTPRINT,"route"):return {"kind":"source_policy_refused","point":_xyz(point)}
		for offset: Vector2 in SUPPORT_OFFSETS:
			var probe: Vector3=point+Vector3(offset.x,0,offset.y)
			_clearance_ray.from=probe+Vector3.UP*.30;_clearance_ray.to=probe-Vector3.UP*.30
			var support: Dictionary=space.intersect_ray(_clearance_ray)
			if support.is_empty() or support.normal.y<.70 or absf(support.position.y-point.y)>.18:return {"kind":"floor_support_refused","point":_xyz(point)}
		_clearance_query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(BODY_HEIGHT*.5+.025))
		var overlaps: Array[Dictionary]=space.intersect_shape(_clearance_query,16)
		if overlaps.size()>=16:return {"kind":"overlap_capacity"}
		for overlap: Dictionary in overlaps:
			var collider: Object=overlap.collider
			var token: Dictionary=_host.target_from_collider(collider)
			if not token.get("ok",false) or token.get("source_id") not in ORIGINAL_OTHER_ACTORS or not _host.target_current(token):return {"kind":"other_physical_blocker","point":_xyz(point),"collider_class":collider.get_class() if is_instance_valid(collider) else "invalid"}
			blockers[token.source_id]={"source_id":token.source_id,"life_generation":token.life_generation,"body_instance_id":token.body_instance_id,"rig_instance_id":token.rig_instance_id,"point":_xyz(point)}
	return {"kind":"clear" if blockers.is_empty() else "original_living_npc","blockers":blockers.values(),"samples":count+1,"microseconds":Time.get_ticks_usec()-began,"request_id":_request,"physics_frame":Engine.get_physics_frames()}

func _clearance_tick() -> void:
	if _request>=0:_hold("clearance_has_active_request");return
	if _clock>=_clearance_until:_hold("original_npc_clearance_deadline");return
	if _clock<_clearance_next_at:return
	_clearance_next_at=_clock+CLEARANCE_INTERVAL;_clearance_polls+=1
	_clearance_last=_take_clearance_probe()
	var kind: String=str(_clearance_last.get("kind","unknown"))
	if kind=="original_living_npc":return
	if kind!="clear":_hold("clearance:"+kind);return
	_retries+=1
	_request_leg()

func _request_visit(target: Vector3, phase: String, tolerance: float, token: Dictionary) -> Dictionary:
	if not _same_public_lease() or not _claim_request_frame():return {"accepted":false,"reason":"request_frame_or_lease"}
	var result: Dictionary=_route.request_route(target,phase,tolerance,token)
	if result.get("accepted",false) and result.get("request_id") is int:_visit_request=result.request_id
	return result

func _begin_visit() -> void:
	if _last_request_frame==Engine.get_physics_frames():return
	var world: Node3D=_world()
	_visit=Visit.new()
	if not _visit.configure(_host,world.get("_printshop"),_entry,LOCAL_SESSION,ACTOR,Callable(self,"_request_visit"),Callable(_route,"poll"),Callable(self,"_cancel_visit"),_door_started,_occupants):_hold("local_visit_configuration_refused");return
	_visit_since=_clock
	if not _visit.begin(_clock*1000.0):_hold("local_visit_begin_refused");return
	_last_visit_status=_visit.status();_change("VISIT",str(_last_visit_status.get("phase","")))

func _visit_tick() -> void:
	if _clock-_visit_since>VISIT_LIMIT:_hold("local_visit_deadline");return
	_last_visit_status=_visit.tick(_clock*1000.0)
	var phase: String=str(_last_visit_status.get("phase","UNKNOWN"))
	if phase=="COMPLETE":
		_release();_change("COMPLETE","local_visit_completed_once")
	elif phase=="HOLD":_hold("local_visit:"+str(_last_visit_status.get("reason","unknown")))
	elif phase in ["WALK_TO_ENTRY","OPENING","ENTERING","BROWSING","EXITING","RETURNING_TO_STREET"]:_change("VISIT",phase)
	else:_hold("unknown_local_visit_phase:"+phase)

func step(delta: float) -> void:
	if _disposed or _phase in ["UNBOUND","DISPOSED"] or not Thread.is_main_thread():return
	if not is_finite(delta) or delta<=0.0 or delta>.05:_invalid_deltas+=1;return
	var frame: int=Engine.get_physics_frames()
	if _last_step_frame==frame:_duplicate_steps+=1;return
	_last_step_frame=frame
	if _phase in ["HOLD","COMPLETE"]:
		if _bound and _release_attempts<3:_release()
		return
	if not is_instance_valid(_world()):_hold("scene_ended");return
	if _bound and (not _current() or not _same_public_lease()):_hold("actor_life_or_public_lease_ended");return
	if not _bound:
		var initial_actor: Node=_world().get_node_or_null("npc_"+ACTOR)
		if not _host.target_from_collider(initial_actor).get("ok",false):_hold("original_walking_actor_unavailable");return
	var pause: Callable=_record().get("walk_pause",Callable())
	_paused=pause.is_valid() and bool(pause.call())
	if _bound and (not _current() or not _same_public_lease()):_hold("actor_life_changed_during_pause_check");return
	# The host owns paused movement; the scheduler freezes ALL local deadlines
	# and does not tick the composer's browsing/yaw clock while pause is active.
	if _paused:_paused_seconds+=delta;return
	_clock+=delta
	if _clock>TOTAL_ACTIVE_LIMIT:_hold("bounded_local_session_deadline");return
	if _phase=="WAIT_NAV":
		if _navigation.state()=="READY":_bind()
		elif _clock>NAV_WAIT_LIMIT:_hold("native_navigation_not_ready")
	elif _phase=="START_DELAY":
		if _clock-_phase_at>START_DELAY+20.0:_hold("initial_native_ready_wait_timeout")
		elif _clock-_phase_at>=START_DELAY:_request_leg()
	elif _phase=="APPROACH":_approach_tick()
	elif _phase=="WAIT_FOR_CLEARANCE":_clearance_tick()
	elif _phase=="VISIT":_visit_tick()

func _release() -> void:
	if _bound:_release_attempts+=1
	if not _cancel_approach():return
	if not _cancel_owned_request(_visit_request):return
	_visit_request=-1
	if _bound and _host!=null:
		_release_result=_host.release_local_navigation_adapter(_route,_token)
		if _release_result.get("ok",false) or not _same_public_lease():_bound=false
	# Public host release owns adapter disposal and preview resumption. Failed
	# pre-bind configuration has no public lease; retire only our own adapter.
	# Never bypass a still-current public lease merely because it was busy.
	if _route!=null and not _bound:_route.dispose()

func _hold(reason: String) -> void:
	if _visit!=null:_visit.cancel()
	_release();_change("HOLD",reason)

func _xyz(point: Vector3) -> Array:return [point.x,point.y,point.z]

func snapshot() -> Dictionary:
	var position: Variant=null
	if is_instance_valid(_token.get("body")):position=_xyz(_token.body.global_position)
	return {"phase":_phase,"reason":_reason,"scope":SCOPE,"source_id":ACTOR,"local_session":LOCAL_SESSION,"once_per_launch":true,"source_authority":false,"original_source_progress_written":false,"source_row_or_HP_written":false,"actor_transform_written":false,"active_seconds":_clock,"paused":_paused,"paused_seconds":_paused_seconds,"leg":_leg,"leg_count":_points.size(),"leg_attempts":_leg_attempts,"request_id":_request,"visit_request_id":_visit_request,"cancellation":_cancel_result.duplicate(true),"cancellation_attempts":_cancel_attempts,"requests":_requests,"approach_requests":_approach_requests,"retries":_retries,"clearance":{"leg":_clearance_leg,"deadline_active_seconds":_clearance_until,"next_probe_active_seconds":_clearance_next_at,"polls":_clearance_polls,"waits":_clearance_waits,"probe_cost":{"calls":_clearance_probe_count,"total_us":_clearance_probe_total_us,"max_us":_clearance_probe_max_us,"first_samples_us":_clearance_probe_samples.duplicate(),"sample_limit":64},"latest":_clearance_last.duplicate(true),"history":_clearance_history.duplicate(true)},"lease_bound":_bound,"lease_serial":_lease_serial,"release":_release_result.duplicate(true),"release_attempts":_release_attempts,"duplicate_step_calls_ignored":_duplicate_steps,"invalid_deltas_ignored":_invalid_deltas,"request_frame_limit_hits":_request_limit_hits,"position":position,"approach_sha256":_approach_sha,"visit":_last_visit_status.duplicate(true),"legs":_legs.duplicate(true),"history":_history.duplicate(true)}

func dispose() -> void:
	if _disposed:return
	if _visit!=null:_visit.cancel()
	_release();_disposed=true;_change("DISPOSED","population_dispose")
	_visit=null;_route=null;_host=null;_navigation=null;_policy=null;_scene=null
	_door_started=Callable();_occupants=Callable();_token.clear()
