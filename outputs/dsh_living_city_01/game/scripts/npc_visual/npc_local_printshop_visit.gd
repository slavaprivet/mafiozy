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

# DSH_VISITHOLD: --city-visit-hold-recovery=N, 0 (default) = today's behaviour.
# Today every refusal in this composer ends in the terminal `HOLD` dead end
# (`_stop` below) and the terminal early-out in `tick()` then returns that
# status forever: the visit is never continued and the resident is never
# released, so the day controller keeps the activity (`act_not_released`).
# With N>0 a refusal first returns to `READY` so `begin()` may re-run the
# entrance (the door is simply asked again for `OPENING`, and the same
# tolerance is walked to again for a precision miss). Only when N attempts
# AND the no-progress window are both spent does the visit become terminal
# (`COMPLETE` + the refusal in `_reason`) and drop its callback table, so the
# owning controller observes a finishable terminal state and can release the
# resident. No physics, collider, timing or policy change: only this visit's
# own state.
const DSH_VISIT_HOLD_DEFAULT_WAIT_S := 120.0  # DSH_VISITHOLD: default no-progress window (s)
const DSH_VISIT_HOLD_ESCROW_MS := 750.0  # DSH_VISITHOLD: shortest gap between two re-issues of the same request
static var _dsh_hold_flag := -1  # DSH_VISITHOLD: --city-visit-hold-recovery, 0 = off
static var _dsh_hold_wait_ms := -1.0  # DSH_VISITHOLD: --city-visit-hold-wait-s * 1000
var _hold_attempts := 0  # DSH_VISITHOLD: re-issues already spent inside this composer
var _hold_progress_at := 0.0  # DSH_VISITHOLD: local ms of the last phase advance
var _hold_issue := ""  # DSH_VISITHOLD: the refusal that ended the last request
var _hold_issue_at := 0.0  # DSH_VISITHOLD
var _hold_retry_at := -1.0  # DSH_VISITHOLD: next local ms at which a re-issue may run
var _hold_pending := false  # DSH_VISITHOLD: one latched re-issue
var _hold_recovering := false  # DSH_VISITHOLD: re-issue in flight (recursion guard)
var _hold_begin := false  # DSH_VISITHOLD: the recovery tick owns begin()
var _hold_route_target := Vector3.ZERO  # DSH_VISITHOLD
var _hold_route_phase := ""  # DSH_VISITHOLD
var _hold_route_tolerance := 0.0  # DSH_VISITHOLD
var _completed_failures := 0  # DSH_VISITHOLD

## DSH_VISITHOLD: read-once history. 0 (default) keeps today's `_stop` -> HOLD
## exactly as it is, byte for byte.
static func _dsh_hold_recovery() -> int:  # DSH_VISITHOLD
	if _dsh_hold_flag < 0:
		_dsh_hold_flag = 0
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-visit-hold-recovery="):
				_dsh_hold_flag = clampi(int(argument.trim_prefix("--city-visit-hold-recovery=")), 0, 1024)
	return _dsh_hold_flag

static func _dsh_hold_wait() -> float:  # DSH_VISITHOLD
	if _dsh_hold_wait_ms < 0.0:
		_dsh_hold_wait_ms = DSH_VISIT_HOLD_DEFAULT_WAIT_S * 1000.0
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-visit-hold-wait-s="):
				_dsh_hold_wait_ms = clampf(float(argument.trim_prefix("--city-visit-hold-wait-s=")), 1.0, 3600.0) * 1000.0
	return _dsh_hold_wait_ms

func _dsh_hold_on() -> bool:  # DSH_VISITHOLD
	return _dsh_hold_recovery() > 0

func _hold_progress(now_ms: float, phase: String) -> void:  # DSH_VISITHOLD
	# Progress is the only thing that refills the counters: a new phase of the
	# entrance, or an accepted new request. Waiting/retrying at the same phase
	# is not progress.
	_hold_progress_at = now_ms
	_hold_attempts = 0
	_hold_retry_at = -1.0
	_hold_issue = ""
	_hold_pending = false

func _hold_telemetry(reason: String, now_ms: float, phase: String, result: String) -> void:  # DSH_VISITHOLD
	var body := _body()
	var frame := Engine.get_physics_frames()
	var position := body.global_position if is_instance_valid(body) else Vector3.ZERO
	print("DSH_VISITHOLD id=", _id, " reason=", reason,
		" attempt=", _hold_attempts, "/", _dsh_hold_recovery(),
		" waited_s=", "%.1f" % maxf(0.0, (now_ms - _hold_issue_at) / 1000.0),
		" phase=", phase, " result=", result, " frame=", frame,
		" waited_total_s=", "%.1f" % maxf(0.0, (now_ms - _hold_progress_at) / 1000.0),
		" released=", str(_completed_failures > 0), " pos=(", "%.2f" % position.x, ",", "%.2f" % position.y, ",", "%.2f" % position.z, ")")

func _hold_release(now_ms: float, reason: String) -> void:  # DSH_VISITHOLD
	# Bounded end: the visit becomes terminal instead of the permanent HOLD the
	# status()/tick() pair can never leave. Only this visit's own state changes;
	# every release/undo of movement belongs to the owning controller, which
	# already reads a terminal phase and then cancels or releases through the
	# public host.
	var phase := _phase
	if _request_id >= 0 and _cancel.is_valid(): _cancel.call(_request_id)
	_request_id = -1
	_phase = "COMPLETE"
	_reason = reason
	_completed_failures += 1
	_hold_pending = false
	_hold_retry_at = -1.0
	# Drop the retained bound-callable cycle exactly like the shop/hospital
	# release path does. The parent's own cancel/undo callbacks now become
	# no-ops instead of cancelling a request this composer no longer owns.
	_request = Callable(); _poll = Callable(); _cancel = Callable(); _door_started = Callable(); _occupants = Callable()
	_hold_telemetry(reason, now_ms, phase, "released")

func _hold_recover(now_ms: float, reason: String) -> bool:  # DSH_VISITHOLD
	if not _dsh_hold_on(): return false
	if _hold_recovering: return true
	if _hold_pending: return true
	var budget := _dsh_hold_recovery()
	var waited := now_ms - _hold_progress_at
	var exhausted := waited >= _dsh_hold_wait()
	if _hold_attempts >= budget or exhausted or not is_finite(now_ms):
		_hold_release(now_ms, reason if not exhausted else reason + ":no_progress_window")
		return true
	_hold_attempts += 1
	_hold_pending = true
	_hold_telemetry(reason, now_ms, _phase, "retry")
	return true

func _hold_entry(now_ms: float, reason: String) -> void:  # DSH_VISITHOLD
	# One latched re-issue, run to its end in this same tick: the shipped begin()
	# when there is no recorded request yet, otherwise the exact recorded
	# target/phase/tolerance. begin() re-arms the counters on success; a refusal
	# counts again and stops at the budget or at the no-progress window.
	_hold_issue = reason
	_hold_issue_at = now_ms
	_hold_recover(now_ms, reason)
	while _hold_pending and now_ms >= _hold_retry_at:
		_hold_do_retry(now_ms)
		_hold_begin_step(now_ms)
		_hold_retry_at = now_ms + DSH_VISIT_HOLD_ESCROW_MS

func _hold_do_retry(now_ms: float) -> void:  # DSH_VISITHOLD
	# The re-issue re-runs the shipped entrance for the phase that refused: the
	# same target, the same request phase and the same tolerance that the
	# caller supplied. For `OPENING` only the door deadline is re-anchored, so
	# the shipped OPENING block below asks the door again. No new target, no
	# new tolerance and no change to `_outside`/`_inside`/`_return`.
	_hold_pending = false
	if _phase == "OPENING":
		_since = now_ms
		_reason = ""
		return
	var target := _hold_route_target
	var phase := _hold_route_phase
	var tolerance := _hold_route_tolerance
	if phase == "WALK_TO_ENTRY":
		_street_return = _body().global_position
		target = _outside
		tolerance = .10 * WORLD_SCALE
	elif phase == "ENTERING":
		target = _inside
		tolerance = .025 * WORLD_SCALE
	elif phase == "EXITING":
		target = _return
		tolerance = .025 * WORLD_SCALE
	elif phase == "RETURNING_TO_STREET":
		target = _street_return
		tolerance = .025 * WORLD_SCALE
	if phase.is_empty() or not target.is_finite():
		_hold_begin = true
		return
	_hold_recovering = true
	_route(target, phase, tolerance)
	_hold_recovering = false

func _hold_begin_step(now_ms: float) -> void:  # DSH_VISITHOLD
	# begin() owns the `_busy` flag itself, so hand it a clear flag and restore
	# the recovery block's ownership afterwards. Its own guards are unchanged.
	_hold_begin = false
	var outer := _busy
	_busy = false
	_hold_recovering = true
	begin(now_ms)
	_hold_recovering = false
	_busy = outer

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
	# DSH_VISITHOLD: the shipped stop stays the last word unless the opt-in
	# recovery can turn this very refusal into a bounded re-issue or a bounded
	# terminal release. With the flag off (default) this is the old line.
	_hold_issue = reason
	_hold_issue_at = _now
	if _hold_recover(_now, reason): return
	if _request_id>=0 and _cancel.is_valid():_cancel.call(_request_id)
	_request_id=-1;_phase="HOLD";_reason=reason
func _route(target:Vector3,phase:String,tolerance:float) -> bool:
	var result:Variant=_request.call(target,phase,tolerance,_token.duplicate())
	if not _current():_stop("actor_lease_changed");return false
	if not result is Dictionary or not result.get("accepted") is bool or result.accepted!=true or not result.get("request_id") is int or result.request_id<0:
		_stop("route_owner_refused:"+phase);return false
	_request_id=result.request_id;_phase=phase;_reason=""
	# DSH_VISITHOLD: remember the exact request that was just accepted so a
	# refusal can re-issue this same target/phase/tolerance. This changes no
	# request itself.
	_hold_route_target=target;_hold_route_phase=phase;_hold_route_tolerance=tolerance
	if _dsh_hold_on():_hold_progress(_now,phase)
	return true
func begin(now_ms:float) -> bool:
	if _busy or _phase!="READY" or not _current() or not is_finite(now_ms) or now_ms<0:return false
	_busy=true;_now=now_ms;_since=now_ms
	_street_return=_body().global_position
	var accepted:=_route(_outside,"WALK_TO_ENTRY",.10*WORLD_SCALE)
	_busy=false;return accepted

func tick(now_ms:float) -> Dictionary:
	if _busy:return {"phase":_phase,"reason":"reentry"}
	if not is_finite(now_ms) or now_ms<_now:return {"phase":_phase,"reason":"invalid_local_clock"}
	# DSH_VISITHOLD: the exact-tick re-entry the caller's one-shot begin() cannot
	# do. It runs before the terminal early-out below, so a latched re-issue is
	# executed and the composition is genuinely continued instead of endlessly
	# reporting HOLD. It owns no physics: only begin() and the recorded route
	# request run, exactly as the caller runs them.
	if _dsh_hold_on() and (_hold_pending or _hold_begin) and now_ms>=_hold_retry_at:
		_busy=true;_now=now_ms
		_hold_entry(now_ms,_hold_issue)
		_busy=false
		if _phase=="HOLD":return status()
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
			if _horizontal_distance(target)>tolerance:
				# DSH_VISITHOLD: the same tolerance is walked to again; with the
				# flag off this is exactly today's `_stop`.
				if not _hold_recover(now_ms,"arrival_precision_required"):_stop("arrival_precision_required")
			elif _phase=="WALK_TO_ENTRY":_return=_body().global_position;_phase="OPENING";_since=now_ms;_request_id=-1;_hold_progress(now_ms,_phase)
			elif _phase=="ENTERING":
				_phase="BROWSING";_since=now_ms;_yaw=_body().rotation.y;_request_id=-1;_hold_progress(now_ms,_phase)
				_until=now_ms+3000.0+floor(_unit(_id,"visit:"+str(_cycle))*4000.0+.5)
			elif _phase=="EXITING":_route(_street_return,"RETURNING_TO_STREET",.025*WORLD_SCALE)
			else:_phase="COMPLETE";_completed+=1;_request_id=-1;_hold_progress(now_ms,_phase)
	# Begin the physical door request on the ARRIVED poll itself. A sparse
	# daily poll may come after the existing three-second door deadline.
	# The deadline remains anchored to physical entry arrival; retries do
	# not restart it, and current ownership/arrival precision stay required.
	if _phase=="OPENING":
		var interior:Node3D=_interior.get_ref()
		if float(interior.door_fraction("public"))==1.0:
			_route(_inside,"ENTERING",.025*WORLD_SCALE)
		else:
			var fraction_before:float=interior.door_fraction("public")
			var result:Dictionary=interior.request_door("public",true,_body().global_position,_occupants.call())
			if result.get("accepted",false) and fraction_before<.95 and _reason!="door_open_requested":
				_door_started.call("public",true);_reason="door_open_requested"
			if now_ms-_since>=3000.0:
				# DSH_VISITHOLD: ask the door again with a re-anchored deadline
				# instead of the permanent HOLD. The deadline is only re-anchored
				# for a retry, exactly as the shipped comment describes.
				if not _hold_recover(now_ms,"source_door_wait_timeout"):_stop("source_door_wait_timeout")
	elif _phase=="BROWSING":
		if now_ms>=_until:_route(_return,"EXITING",.025*WORLD_SCALE)
		else:_body().basis=Basis(Vector3.UP,_yaw+sin((now_ms-_since)/900.0)*.22)
	_busy=false;return status()

func status() -> Dictionary:
	return {"scope":"NEW_LOCAL_PREVIEW_SESSION_ONE_ORIGINAL_PHYSICAL_ENTRY","local_session":_session,"source_id":_id,"life_generation":_generation,"phase":_phase,"reason":_reason,"local_completed":_completed,"cycle":_cycle,"original_source_progress_written":false,"original_agenda_completed":false,"door_id":"native:"+BUILDING}
func cancel() -> void:
	if not _busy:
		_busy=true
		_hold_issue="cancelled";_hold_issue_at=_now
		if not _hold_recover(_now,"cancelled"):_stop("cancelled")
		_busy=false
