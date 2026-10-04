extends RefCounted
## New local preview session composition of the original native visit phases.
## Original cohort, agenda/progress/HP are read-only. No original-session claim.
## Route owner retains all movement, collider, support and fine-arrival checks.
const ENTRY_SHA := "3bda89bb0017b2d1ee5f5fca9c066d28a8e0f11a09670be43c771a027ce3518c"
const BUILDING := "REBUILD-VISUAL-print_shop-001"
const WORLD_SCALE := 4.1
var _session := ""
var _id := ""
var _generation := -1
var _host: RefCounted
var _interior: WeakRef
var _token := {}
var _route_owner: WeakRef
var _request: Callable
var _poll: Callable
var _cancel: Callable
var _door_started: Callable
var _occupants: Callable
var _request_id := -1
var _outside := Vector3.ZERO
var _inside := Vector3.ZERO
var _return := Vector3.ZERO
var _street_return := Vector3.ZERO
var _phase := "UNBOUND"
var _reason := ""
var _since := 0.0
var _now := -1.0
var _until := 0.0
var _yaw := 0.0
var _busy := false
var _cycle := 0
var _completed := 0

static func _hash(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
static func _point(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
static func _unit(id: String,salt: String) -> float:
	var text := id+":"+salt; var h:=2166136261
	for i in text.length():
		var code:=text.unicode_at(i)
		if code>65535:code=55296+((code-65536)>>10)
		h=((h^code)*16777619)&0xffffffff
	return float(h)/4294967296.0

## local_session must be a newly declared scope, separate from frozen source
## packet session. Caller must suspend preview walking for this exact actor.
## request(goal,phase,tolerance_m,token)->{accepted,request_id}; poll(id)->status.
## Callback must keep .738 footprint and ALL current source/native collisions.
func configure(host: RefCounted, interior: Node3D, entry_bytes: PackedByteArray, local_session: String, id: String, request_route: Callable, poll_route: Callable, cancel_route: Callable, door_started: Callable, occupants: Callable) -> bool:
	if _phase!="UNBOUND" or _busy or not local_session.begins_with("LOCAL_NPC_VISIT23:") or id not in ["resident_72","resident_169","resident_252"] or _hash(entry_bytes)!=ENTRY_SHA: return false
	if not is_instance_valid(interior) or not interior.get("ready_for_use") or not host._records.has(id):return false
	for callback:Callable in [request_route,poll_route,cancel_route,door_started,occupants]:
		if not callback.is_valid():return false
	var data:Dictionary=JSON.parse_string(entry_bytes.get_string_from_utf8())
	if data.get("source_id")!=BUILDING or data.get("scope")!="NEW_LOCAL_PREVIEW_SESSION_ONE_ORIGINAL_PHYSICAL_ENTRY":return false
	var record:Dictionary=host._records[id]
	var token:Dictionary=host.target_from_collider(record.body)
	if not token.get("ok",false) or not host.target_current(token):return false
	var claim: Variant=record.get("local_route_owner")
	if not claim is WeakRef or not is_instance_valid(claim.get_ref()):return false
	var route: RefCounted=claim.get_ref()
	if route.get("host")!=host or route.get("token")!=token or route.get("_disposed")!=false or route.get("_phase")!="READY":return false
	_host=host;_interior=weakref(interior);_token=token;_id=id;_generation=token.life_generation;_session=local_session
	_route_owner=weakref(route)
	_request=request_route;_poll=poll_route;_cancel=cancel_route;_door_started=door_started;_occupants=occupants
	_outside=_point(data.public_approach_preview);_inside=_point(data.public_inside_preview)
	_phase="READY";return true

func _current() -> bool:
	if not (_host!=null and _interior!=null and is_instance_valid(_interior.get_ref()) and _interior.get_ref().get("ready_for_use") and _host.target_current(_token)):return false
	var lease: Variant=_host._records[_id].get("local_route_owner")
	if not lease is WeakRef or _route_owner==null:return false
	var route: RefCounted=_route_owner.get_ref()
	if not is_instance_valid(route) or lease.get_ref()!=route or route._disposed or route._phase=="SUPERSEDED":return false
	return true
func _body() -> CharacterBody3D:return _token.body as CharacterBody3D
func _horizontal_distance(target: Vector3) -> float:
	var position:=_body().global_position;return Vector2(position.x-target.x,position.z-target.z).length()
func _stop(reason: String) -> void:
	if _request_id>=0 and _cancel.is_valid():_cancel.call(_request_id)
	_request_id=-1;_phase="HOLD";_reason=reason
func _route(target:Vector3,phase:String,tolerance:float) -> bool:
	var result:Variant=_request.call(target,phase,tolerance,_token.duplicate())
	if not _current():_stop("actor_lease_changed");return false
	if not result is Dictionary or not result.get("accepted") is bool or result.accepted!=true or not result.get("request_id") is int or result.request_id<0:
		_stop("route_owner_refused:"+phase);return false
	_request_id=result.request_id;_phase=phase;_reason="";return true
func begin(now_ms:float) -> bool:
	if _busy or _phase!="READY" or not _current() or not is_finite(now_ms) or now_ms<0:return false
	_busy=true;_now=now_ms;_since=now_ms
	_street_return=_body().global_position
	var accepted:=_route(_outside,"WALK_TO_ENTRY",.10*WORLD_SCALE)
	_busy=false;return accepted

func tick(now_ms:float) -> Dictionary:
	if _busy:return {"phase":_phase,"reason":"reentry"}
	if not is_finite(now_ms) or now_ms<_now:return {"phase":_phase,"reason":"invalid_local_clock"}
	if _phase in ["UNBOUND","READY","HOLD","COMPLETE"]:return status()
	_busy=true
	if not _current():_stop("actor_life_or_physics_changed");_busy=false;return status()
	var pause: Callable=_host._records[_id].get("walk_pause",Callable())
	var paused: bool=pause.is_valid() and pause.call()
	if not _current():_stop("actor_life_or_physics_changed");_busy=false;return status()
	if paused:
		var elapsed:=maxf(0.0,now_ms-_now);_since+=elapsed;_until+=elapsed;_now=now_ms;_busy=false;return status()
	_now=now_ms
	if _phase in ["WALK_TO_ENTRY","ENTERING","EXITING","RETURNING_TO_STREET"]:
		var result:Variant=_poll.call(_request_id)
		if not _current():_stop("actor_lease_changed")
		elif not result is Dictionary or not result.get("status") is String or result.status not in ["PENDING","READY","ARRIVED","BLOCKED","NO_PATH","STALE","CANCELLED","REJECTED","UNSUPPORTED_BODY"]:_stop("route_owner_unknown")
		elif result.status in ["BLOCKED","NO_PATH","STALE","CANCELLED","REJECTED","UNSUPPORTED_BODY"]:_stop("physical_route:"+result.status)
		elif result.status=="ARRIVED":
			var tolerance:=.10*WORLD_SCALE if _phase=="WALK_TO_ENTRY" else .025*WORLD_SCALE
			var target:=_outside if _phase=="WALK_TO_ENTRY" else _inside if _phase=="ENTERING" else _street_return if _phase=="RETURNING_TO_STREET" else _return
			if _horizontal_distance(target)>tolerance:_stop("arrival_precision_required")
			elif _phase=="WALK_TO_ENTRY":_return=_body().global_position;_phase="OPENING";_since=now_ms;_request_id=-1
			elif _phase=="ENTERING":
				_phase="BROWSING";_since=now_ms;_yaw=_body().rotation.y;_request_id=-1
				_until=now_ms+3000.0+floor(_unit(_id,"visit:"+str(_cycle))*4000.0+.5)
			elif _phase=="EXITING":_route(_street_return,"RETURNING_TO_STREET",.025*WORLD_SCALE)
			else:_phase="COMPLETE";_completed+=1;_request_id=-1
	elif _phase=="OPENING":
		var interior:Node3D=_interior.get_ref()
		if float(interior.door_fraction("public"))==1.0:
			_route(_inside,"ENTERING",.025*WORLD_SCALE)
		else:
			var fraction_before:float=interior.door_fraction("public")
			var result:Dictionary=interior.request_door("public",true,_body().global_position,_occupants.call())
			if result.get("accepted",false) and fraction_before<.95 and _reason!="door_open_requested":
				_door_started.call("public",true);_reason="door_open_requested"
			if now_ms-_since>=3000.0:_stop("source_door_wait_timeout")
	elif _phase=="BROWSING":
		if now_ms>=_until:_route(_return,"EXITING",.025*WORLD_SCALE)
		else:_body().basis=Basis(Vector3.UP,_yaw+sin((now_ms-_since)/900.0)*.22)
	_busy=false;return status()

func status() -> Dictionary:
	return {"scope":"NEW_LOCAL_PREVIEW_SESSION_ONE_ORIGINAL_PHYSICAL_ENTRY","local_session":_session,"source_id":_id,"life_generation":_generation,"phase":_phase,"reason":_reason,"local_completed":_completed,"cycle":_cycle,"original_source_progress_written":false,"original_agenda_completed":false,"door_id":"native:"+BUILDING}
func cancel() -> void:
	if not _busy:
		_busy=true;_stop("cancelled");_busy=false
