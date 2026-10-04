extends RefCounted
## One daily goal: native approach -> original physical visit -> actual account
## checkout -> original street return. The existing host alone ticks movement.
const Walk = preload("../npc_daily_walk.gd")
const Route = preload("res://scripts/npc_visual/npc_local_printshop_route.gd")
const Visit = preload("npc_local_shop_visit.gd")
var _host: RefCounted
var _health: RefCounted
var _account: RefCounted
var _policy: RefCounted
var _scene: WeakRef
var _owner: WeakRef
var _token := {}
var _goal := {}
var _entry := PackedByteArray()
var _geometry := PackedByteArray()
var _walk: RefCounted
var _route: RefCounted
var _visit: RefCounted
var _handoff := Vector3.ZERO
var _phase := "UNBOUND"
var _reason := ""
var _terminal := "BLOCKED"
var _request := -1
var _serial := -1
var _bound := false
var _released := false
var _cancel_requested := false
var _disposed := false
var _frame := -1
var _request_frame := -1
var _busy := false
var _elapsed := 0.0
var _dsh_elapsed := -1.0  # DSH_LIFECLOCK: real game time since the previous poll
var _now := 0.0
var _dsh_probe := -1  # DSH_VISITPROBE: --city-visit-probe, 0 (default) = off
var _dsh_seen := ""  # DSH_VISITPROBE: the last printed state tuple
var _dsh_status := ""  # DSH_VISITPROBE: last observed record status
var _dsh_status_ms := 0  # DSH_VISITPROBE: when that status was first seen
var _dsh_attempts := 0  # DSH_VISITPROBE: entries into _bind_visit()
var _dsh_counted := false  # DSH_VISITPROBE: this instance already filed its outcome
static var _dsh_s_ids: Array = []  # DSH_VISITPROBE: --city-visit-probe-ids
static var _dsh_s_n := -1  # DSH_VISITPROBE: --city-visit-probe-count
static var _dsh_s_ms := 0  # DSH_VISITPROBE: the once-per-second counters line
static var _dsh_s_visit := 0  # DSH_VISITPROBE
static var _dsh_s_complete := 0  # DSH_VISITPROBE
static var _dsh_s_cancel := 0  # DSH_VISITPROBE
static var _dsh_s_refuse := 0  # DSH_VISITPROBE
static var _dsh_s_hold := 0  # DSH_VISITPROBE
static var _dsh_s_attempts := 0  # DSH_VISITPROBE
var _commerce_result := {}
var _release_result := {}
var _timing_buckets: Dictionary = {}

# DSH_DAILYPIN: --city-daily-pin-cache=1 proves the two pinned session constants ONCE per
# process instead of on every activity start. Today every shop start re-hashes 20 738 B
# (entry) plus 174 616 B (lane geometry) and re-parses the 174 616 B JSON, although
# npc_city_daily holds exactly one copy of each blob for the whole scene. 0 (default)
# re-proves every start, byte for byte as today. A pair of blobs with other sizes always
# runs the full proof again.
static var _dsh_pin_flag := -1  # DSH_DAILYPIN
static var _dsh_pin_value: Dictionary = {}  # DSH_DAILYPIN
static var _dsh_pin_sizes := ""  # DSH_DAILYPIN
static var _dsh_pin_ok := false  # DSH_DAILYPIN
# DSH_STUTTER: the full identity of the pair that was proven -- both file paths, both
# pins, and the modification time and byte length of both files (the two APIs
# DSH_BINDFAST already uses in this project) -- plus the proven bytes themselves. A
# hold is only reachable when all of it matches, so it can never be spent on another
# blob, on the same bytes under a rewritten file, or on a file rewritten while the
# app ran. Failure still returns through the shipped refusal path and is never held.
const DSH_PIN_ENTRY_PATH := "res://data/LOCAL_PRINTSHOP_ENTRY.json"  # DSH_STUTTER
const DSH_PIN_GEOMETRY_PATH := "res://data/ENTRY_GEOMETRY.json"  # DSH_STUTTER
static var _dsh_pin_identity := ""  # DSH_STUTTER
static var _dsh_pin_entry := PackedByteArray()  # DSH_STUTTER: the proven entry bytes
static var _dsh_pin_geometry_bytes := PackedByteArray()  # DSH_STUTTER

static func _dsh_pin_stamp(path: String) -> String:  # DSH_STUTTER
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return "absent"
	var size := file.get_length()
	file.close()
	return str(FileAccess.get_modified_time(path)) + ":" + str(size)

static func _dsh_pin_source() -> String:  # DSH_STUTTER
	return DSH_PIN_ENTRY_PATH + "|" + Route.ENTRY_SHA + "|" + _dsh_pin_stamp(DSH_PIN_ENTRY_PATH) + "|" + DSH_PIN_GEOMETRY_PATH + "|" + Route.GEOMETRY_SHA + "|" + _dsh_pin_stamp(DSH_PIN_GEOMETRY_PATH)

static func _dsh_pin_on() -> bool:  # DSH_DAILYPIN
	if _dsh_pin_flag < 0:
		_dsh_pin_flag = 1  # DSH_ACCEPTED: the pinned session constants are proven once by default; --city-daily-pin-cache=0 restores the per-start re-proof
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-pin-cache="):
				_dsh_pin_flag = 1 if int(argument.trim_prefix("--city-daily-pin-cache=")) != 0 else 0
	return _dsh_pin_flag == 1

# DSH_DAILYPIN: exactly today's two hashes and today's parse, with the verdict remembered
# for the blob sizes that were proven. Never a weaker gate: different sizes re-prove.
static func _dsh_pin_admit(entry_bytes: PackedByteArray, geometry_bytes: PackedByteArray) -> bool:  # DSH_DAILYPIN
	var sizes:=str(entry_bytes.size())+":"+str(geometry_bytes.size())
	# DSH_STUTTER: same gate, keyed by everything that can change the answer, and the
	# bytes must still compare equal to the ones this verdict was proven against.
	if _dsh_pin_on() and _dsh_pin_ok and _dsh_pin_sizes==sizes and _dsh_pin_identity==_dsh_pin_source() and _dsh_pin_entry==entry_bytes and _dsh_pin_geometry_bytes==geometry_bytes: return true
	if Visit._hash(entry_bytes)!=Route.ENTRY_SHA or Visit._hash(geometry_bytes)!=Route.GEOMETRY_SHA:
		if _dsh_pin_on(): _dsh_pin_ok=false
		return false
	var parsed: Variant=JSON.parse_string(geometry_bytes.get_string_from_utf8())
	if not parsed is Dictionary: return false
	_dsh_pin_value=parsed
	if _dsh_pin_on():
		_dsh_pin_ok=true
		_dsh_pin_sizes=sizes
		_dsh_pin_identity=_dsh_pin_source()  # DSH_STUTTER
		_dsh_pin_entry=entry_bytes  # DSH_STUTTER: the bytes this verdict was proven against
		_dsh_pin_geometry_bytes=geometry_bytes  # DSH_STUTTER
	return true

static func _dsh_pin_geometry() -> Dictionary: return _dsh_pin_value  # DSH_DAILYPIN

func _init() -> void:
	_ensure_timing_buckets()

func _new_timing_bucket() -> Dictionary:
	return {"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""}

func _ensure_timing_buckets() -> void:
	if not _timing_buckets.is_empty(): return
	for label: String in ["step_total","current","walk_step","walk_snapshot","route_poll","printshop_tick","commerce_copy","occupants","unwind"]:
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
		bucket["max_phase"]=_phase if phase.is_empty() else phase

func configure(host: RefCounted, policy: RefCounted, health: RefCounted, scene: Node3D, activity_owner: RefCounted, account: RefCounted, goal: Dictionary, entry_bytes: PackedByteArray, geometry_bytes: PackedByteArray) -> Dictionary:
	if _phase!="UNBOUND" or _disposed or not Thread.is_main_thread(): return _fail("lifetime")
	if not is_instance_valid(host) or not is_instance_valid(health) or not is_instance_valid(account) or not is_instance_valid(activity_owner) or not is_instance_valid(scene) or not scene.is_inside_tree(): return _fail("actual_owners_required")
	var token: Variant=health.get("_token")
	if not token is Dictionary or health.get("_host")!=host or account.get("_host")!=host or account.get("_token")!=token or not host.target_current(token): return _fail("same_actor_health_account")
	var lease: Dictionary=host.daily_activity_status(token.source_id)
	if not lease.get("current",false) or lease.get("owner")!=activity_owner or lease.get("life_generation")!=token.life_generation: return _fail("actual_daily_activity_owner")
	if goal.get("kind")!="shop" or str(goal.get("goal_id","")).is_empty() or not scene.has_method("_current_door_occupants"): return _fail("shop_goal_or_door_occupants")
	var population: Variant=scene.get("preview_population")
	if not is_instance_valid(population) or not population.has_method("door_started"): return _fail("actual_door_access_owner")
	# DSH_DAILYPIN: the same pins and the same failure label; only the repeated proof is cached.
	if not _dsh_pin_admit(entry_bytes,geometry_bytes): return _fail("entry_geometry_pins")
	var geometry: Dictionary=_dsh_pin_geometry()
	if not geometry.get("selected_lane") is Dictionary or not geometry.selected_lane.get("admitted",false): return _fail("source_lane_required")
	var outside: Array=geometry.selected_lane.outside
	if outside.size()!=3: return _fail("source_lane_shape")
	# This is the exterior end of the existing <=9m one-entry corridor. The
	# ordinary map/host must admit the actual approach before the lease exists.
	_handoff=Vector3(minf(8.5,float(outside[0])+1.1),0.0,float(outside[2]))
	var floor_y: float=policy.support_height(_handoff,token.source_id,token.life_generation)
	if not is_finite(floor_y): return _fail("current_handoff_floor")
	_handoff.y=floor_y
	if not policy.source_admit(_handoff,token.source_id,token.life_generation,.738,"target"): return _fail("current_handoff_source")
	_host=host; _health=health; _account=account; _policy=policy; _scene=weakref(scene); _owner=weakref(activity_owner); _token=token.duplicate(); _goal=goal.duplicate(true)
	# DSH_STUTTER: with the pin hold on, these are the same bytes that were just proven
	# and PackedByteArray is copy-on-write, so the ~195 KB duplicate is not needed. With
	# --city-daily-pin-cache=0 the shipped duplicate runs verbatim.
	if _dsh_pin_on(): _entry=entry_bytes; _geometry=geometry_bytes
	else: _entry=entry_bytes.duplicate(); _geometry=geometry_bytes.duplicate()
	_walk=Walk.new()
	var result: Dictionary=_walk.configure(host,_token,activity_owner)
	if not result.get("ok",false): _walk=null; return result
	_phase="READY"
	return {"ok":true,"source_id":token.source_id,"handoff":_handoff,"scope":"new_local_daily_shop_goal"}

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}

func _current() -> bool:
	var started:=Time.get_ticks_usec()
	var frame:=Engine.get_physics_frames()
	var phase:=_phase
	var result:=_current_impl()
	_record_timing("current",started,frame,phase)
	return result

func _current_impl() -> bool:
	if _disposed or not is_instance_valid(_host) or _owner==null or not is_instance_valid(_owner.get_ref()) or _scene==null or not is_instance_valid(_scene.get_ref()) or not _host.target_current(_token): return false
	var lease: Dictionary=_host.daily_activity_status(_token.source_id)
	if not lease.get("current",false) or lease.get("owner")!=_owner.get_ref() or lease.get("life_generation")!=_token.life_generation: return false
	var current: Dictionary=_health._current(_health._binding)
	return not current.is_empty() and is_same(current.get("row"),_health._row) and not current.row.get("dead",false) and float(current.row.get("hp",0))>0.0

func begin() -> Dictionary:
	if _phase!="READY" or not _current(): return _fail("current_ready_goal_required")
	var planned: Dictionary=_account.plan_purchase(str(_goal.goal_id),_health._now())
	if not planned.get("ok",false) or planned.get("kind")!="shop":
		var reason: String=str(planned.get("reason","bank_required"))
		_finish_outside("HOLD",reason)
		return _fail(reason)
	var begun: Dictionary=_walk.begin(_handoff)
	if not begun.get("ok",false): _finish_outside("BLOCKED",str(begun.get("reason","approach_refused"))); return begun
	_phase="APPROACH"; _now=_health._now()
	return {"ok":true,"status":_phase}

func _same_lease() -> bool:
	if not _bound or not is_instance_valid(_host): return false
	var lease: Dictionary=_host.local_navigation_adapter_status()
	return lease.get("bound",false) and lease.get("source_id")==_token.source_id and int(lease.get("serial",-1))==_serial

# DSH_VISITPROBE: read-only diagnosis of the APPROACH -> VISIT transition. It calls none of
# the five gates again and touches no decision: it reads the fields the controller already
# wrote and counts two entries (_step_impl, _bind_visit). 0 = off, one compare per step.
func _dsh_probe_on() -> int:  # DSH_VISITPROBE
	if _dsh_probe < 0:
		_dsh_probe = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-visit-probe="):
				_dsh_probe = maxi(0, int(argument.trim_prefix("--city-visit-probe=")))
			elif argument.begins_with("--city-visit-probe-ids="):
				for piece: String in argument.trim_prefix("--city-visit-probe-ids=").split(",", false):
					if not _dsh_s_ids.has(piece): _dsh_s_ids.append(piece)
			elif argument.begins_with("--city-visit-probe-count="):
				_dsh_s_n = maxi(1, int(argument.trim_prefix("--city-visit-probe-count=")))
		if _dsh_s_n < 0: _dsh_s_n = 4
	return _dsh_probe

func _dsh_probe_selected(id: String) -> bool:  # DSH_VISITPROBE
	if not _dsh_s_ids.is_empty(): return _dsh_s_ids.has(id)
	if _dsh_s_ids.size() >= _dsh_s_n: return false
	if _dsh_s_n > 0: _dsh_s_ids.append(id)
	return true

func _dsh_probe_line(site: String) -> void:  # DSH_VISITPROBE
	if not _dsh_probe_selected(str(_token.get("source_id",""))): return
	var id: String = str(_token.get("source_id",""))
	var record: Dictionary = _host._records.get(id, {}) if _host != null else {}
	var rstatus: String = str(record.get("status",""))
	var now: int = Time.get_ticks_msec()
	if rstatus != _dsh_status: _dsh_status = rstatus; _dsh_status_ms = now
	var walk_phase: String = "-"
	if _walk != null:
		var walking: Dictionary = _walk.snapshot()
		walk_phase = str(walking.get("status","-"))
	var route_phase: String = "-"
	if _route != null: route_phase = str(_route._phase)
	var body: CharacterBody3D = _token.body
	var pos: Vector3 = body.global_position if is_instance_valid(body) else Vector3.ZERO
	var lease: Dictionary = _host.local_navigation_adapter_status() if _host != null else {}
	var tuple: String = "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [_phase, walk_phase, route_phase,
		_terminal, _reason, str(_released), str(_request), rstatus, str(_dsh_attempts)]
	if tuple == _dsh_seen: return
	_dsh_seen = tuple
	print("DSH_VISITPROBE site=", site, " id=", id, " gen=", int(_token.get("life_generation",-1)),
		" goal=", str(_goal.get("kind","-")), " gid=", str(_goal.get("goal_id","-")),
		" shop=", _phase, " walk=", walk_phase, " route=", route_phase,
		" released=", _released, " terminal=", _terminal, " reason=", _reason,
		" attempts=", _dsh_attempts, " bound=", _bound, " serial=", _serial,
		" lease=", str(lease.get("bound",false)), "/", str(lease.get("source_id","-")), "/",
		str(int(lease.get("serial",-1))),
		" req=", _request, " hreq=", int(record.get("request",-1)), " rstatus=", rstatus,
		" rage_s=", "%.1f" % (float(now - _dsh_status_ms) / 1000.0),
		" handoff=(", "%.2f" % _handoff.x, ",", "%.2f" % _handoff.y, ",", "%.2f" % _handoff.z, ")",
		" pos=(", "%.2f" % pos.x, ",", "%.2f" % pos.y, ",", "%.2f" % pos.z, ")",
		" dist=", "%.2f" % pos.distance_to(_handoff), " tol=.20 floor=", body.is_on_floor() if is_instance_valid(body) else false,
		" outside_safe=", _outside_safe())
	if not _dsh_counted:
		if _phase == "VISIT":
			_dsh_counted = true; _dsh_s_visit += 1
		elif _released:
			_dsh_counted = true
			if _terminal == "CANCELLED": _dsh_s_cancel += 1
			else: _dsh_s_refuse += 1
		elif _terminal not in ["BLOCKED","CANCELLED","HOLD"] and _dsh_attempts > 0:
			_dsh_counted = true; _dsh_s_hold += 1

func _dsh_probe_counters() -> void:  # DSH_VISITPROBE
	var now: int = Time.get_ticks_msec()
	if _dsh_s_ms == 0: _dsh_s_ms = now
	if now - _dsh_s_ms < 1000: return
	_dsh_s_ms = now
	print("DSH_VISITPROBE counters t=", int(now / 1000), " visit=", _dsh_s_visit,
		" cancel=", _dsh_s_cancel, " refuse=", _dsh_s_refuse, " hold_no_release=", _dsh_s_hold,
		" gate_attempts=", _dsh_s_attempts, " approach_stuck=", maxi(0, _dsh_s_attempts - _dsh_s_visit),
		" selected=", _dsh_s_ids.size())

func _bind_visit() -> void:
	_dsh_attempts+=1; _dsh_s_attempts+=1  # DSH_VISITPROBE
	if not _walk.cancel().get("ok",false): _reason="approach_cancellation_pending"; return
	_walk.dispose(); _walk=null
	var world: Node3D=_scene.get_ref()
	_route=Route.new()
	if not _route.configure(_host,_policy,_host._navigation,world,_token,_entry,_geometry): _finish_outside("BLOCKED","entry_configuration_refused"); return
	var bound: Dictionary=_host.bind_local_navigation_adapter(_route,_token)
	if not bound.get("ok",false): _route.dispose(); _route=null; _finish_outside("BLOCKED","public_bind_refused:"+str(bound.get("reason",""))); return
	_bound=true; _serial=int(bound.serial)
	_visit=Visit.new()
	var session: String="LOCAL_NPC_VISIT23:daily:"+str(_goal.goal_id)
	if not _visit.configure(_host,world.get("_printshop"),_entry,session,_token.source_id,_request_visit,_route.poll,_cancel_visit,_door_started,_occupants) or not _visit.bind_commerce(_account,str(_goal.goal_id)):
		_finish_outside("BLOCKED","visit_configuration_refused"); return
	if not _visit.begin(_now): _finish_outside("BLOCKED","visit_begin_refused"); return
	_phase="VISIT"

func _request_visit(target: Vector3, phase: String, tolerance: float, token: Dictionary) -> Dictionary:
	var frame: int=Engine.get_physics_frames()
	if not _same_lease() or not _current() or frame==_request_frame: return {"accepted":false,"reason":"current_one_request_per_frame"}
	_request_frame=frame
	var result: Dictionary=_route.request_route(target,phase,tolerance,token)
	if result.get("accepted",false): _request=int(result.request_id)
	return result

func _cancel_exact() -> bool:
	if _request<0: return true
	if not _same_lease() or not _host.target_current(_token) or int(_host._records[_token.source_id].get("request",-1))!=_request: _request=-1; return true
	var result: Dictionary=_host.cancel_local_walk(_route,_token,_request)
	if result.get("ok",false) and int(result.get("cancelled_request_id",-1))==_request: _request=-1; return true
	return false

func _cancel_visit(request_id: int) -> void:
	if request_id==_request: _cancel_exact()

func _door_started(door: String, opening: bool) -> void:
	if _current(): _scene.get_ref().preview_population.door_started(door,opening)

func _occupants() -> Array:
	var started:=Time.get_ticks_usec()
	var frame:=Engine.get_physics_frames()
	var phase:=_phase
	var result: Array=_scene.get_ref()._current_door_occupants() if _current() else []
	_record_timing("occupants",started,frame,phase)
	return result

func _outside_safe() -> bool:
	if not _current(): return false
	var body: CharacterBody3D=_token.body
	var excluded: Array[RID]=[body.get_rid()]
	return body.is_on_floor() and _host._source_admits(body.global_position,_host._records[_token.source_id],"route") and _host._physical_clear(body.global_position,excluded)

func _disable_checkout() -> void:
	if _visit==null: return
	if _visit.commerce_service>=0: _account.cancel_service(_visit.commerce_service)
	_visit.commerce=null

func _finish_outside(terminal: String, reason: String) -> void:
	_terminal=terminal; _reason=reason
	if _walk!=null:
		if not _walk.cancel().get("ok",false): _phase="HOLD"; return
		_walk.dispose(); _walk=null
	if _current() and not _outside_safe(): _phase="HOLD"; return
	if not _release(): _phase="HOLD"; return
	_phase=terminal

func _release() -> bool:
	if _walk!=null:
		if not _walk.cancel().get("ok",false): return false
		_walk.dispose(); _walk=null
	if not _cancel_exact(): return false
	if _bound:
		_release_result=_host.release_local_navigation_adapter(_route,_token)
		if not _release_result.get("ok",false) and _same_lease(): return false
		_bound=false
	if _route!=null: _route.dispose(); _route=null
	if _visit!=null:
		# Break only this composer's retained bound-callable cycle after release.
		_visit._request=Callable(); _visit._poll=Callable(); _visit._cancel=Callable(); _visit._door_started=Callable(); _visit._occupants=Callable(); _visit=null
	_released=true
	return true

func _unwind() -> void:
	_disable_checkout()
	if _outside_safe(): _finish_outside(_terminal,_reason); return
	if not _same_lease() or not _current():
		if _release(): _phase=_terminal
		return
	if _route._phase=="ENTERING" and _phase not in ["UNWIND_EXIT","UNWIND_STREET"]:
		if _visit!=null: _visit.cancel()
		if not _cancel_exact(): _phase="HOLD"; return
		var result: Dictionary=_request_visit(_route._return,"EXITING",.025*4.1,_token)
		if result.get("accepted",false): _phase="UNWIND_EXIT"
		else: _phase="HOLD"
	# A closed door or changed geometry is never bypassed. Keep this owner and
	# HOLD/released=false when the original route cannot safely unwind.

func step(delta: float) -> void:
	var frame:=Engine.get_physics_frames()
	var started:=Time.get_ticks_usec()
	var phase_at_start:=_phase
	_step_impl(delta)
	_record_timing("step_total",started,frame,phase_at_start)

func _step_impl(delta: float) -> void:
	if _disposed or _released or _busy or not Thread.is_main_thread() or not is_finite(delta) or delta<=0.0 or delta>.05: return
	var frame: int=Engine.get_physics_frames()
	if frame==_frame: return
	_frame=frame; _busy=true
	if _dsh_probe_on() == 1: _dsh_probe_line("step"); _dsh_probe_counters()  # DSH_VISITPROBE
	if not _current():
		_terminal="CANCELLED"; _reason="actor_or_activity_life_ended"; _disable_checkout()
		if _walk!=null: _walk.cancel(); _walk.dispose(); _walk=null
		if _release(): _phase="CANCELLED"
		_busy=false; return
	_now=_health._now()
	if _health.should_pause_walk():
		# Both original browse and checkout clocks must receive pause samples.
		if _phase=="VISIT" and _visit!=null: _visit.tick(_now)
		_busy=false; return
	_elapsed+=(_dsh_elapsed if _dsh_elapsed>=0.0 else delta)
	if _elapsed>180.0 and not _cancel_requested: _cancel_requested=true; _terminal="HOLD"; _reason="bounded_shop_deadline"; _disable_checkout()
	if _phase=="APPROACH":
		if _cancel_requested: _finish_outside(_terminal,_reason)
		else:
			var walk_started:=Time.get_ticks_usec()
			_walk._dsh_elapsed = _dsh_elapsed  # DSH_LIFECLOCK: the approach walk's clocks
			_walk.step(delta); _record_timing("walk_step",walk_started,frame,_phase)
			walk_started=Time.get_ticks_usec()
			var walking: Dictionary=_walk.snapshot(); _record_timing("walk_snapshot",walk_started,frame,_phase)
			if walking.status=="COMPLETE": _bind_visit()
			elif walking.status in ["BLOCKED","CANCELLED"]: _finish_outside("BLOCKED",str(walking.reason))
	elif _phase in ["UNWIND_EXIT","UNWIND_STREET"]:
		var poll_started:=Time.get_ticks_usec()
		var native: Dictionary=_route.poll(_request)
		_record_timing("route_poll",poll_started,frame,_phase)
		if native.get("status")=="ARRIVED":
			if _phase=="UNWIND_EXIT":
				var result: Dictionary=_request_visit(_route._street_return,"RETURNING_TO_STREET",.025*4.1,_token)
				if result.get("accepted",false): _phase="UNWIND_STREET"
				else: _phase="HOLD"
			else: _finish_outside(_terminal,_reason)
		elif native.get("status") not in ["READY","PENDING"]: _phase="HOLD"
	elif _phase=="VISIT":
		if _cancel_requested:
			var unwind_started:=Time.get_ticks_usec(); _unwind(); _record_timing("unwind",unwind_started,frame,_phase)
		if _phase=="VISIT" and _visit!=null:
			var visit_started:=Time.get_ticks_usec()
			var result: Dictionary=_visit.tick(_now)
			_record_timing("printshop_tick",visit_started,frame,_phase)
			var commerce_started:=Time.get_ticks_usec()
			_commerce_result=_visit.commerce_result.duplicate(true)
			_record_timing("commerce_copy",commerce_started,frame,_phase)
			if result.phase=="COMPLETE":
				var purchased: bool=_commerce_result.get("ok",false) and _commerce_result.get("status",_commerce_result.get("phase","")) in ["COMPLETE","complete"]
				_finish_outside(_terminal if _cancel_requested else "COMPLETE" if purchased else "HOLD",_reason if _cancel_requested else "" if purchased else "checkout_not_committed")
			elif result.phase=="HOLD":
				_terminal="HOLD"; _reason=str(result.reason); _cancel_requested=true; _unwind()
	elif _phase=="HOLD" and not _released: _unwind()
	_busy=false

func cancel(reason: String="cancelled") -> Dictionary:
	if _released: return {"ok":true,"released":true}
	_cancel_requested=true; _terminal="CANCELLED"; _reason=reason; _disable_checkout()
	if not _busy:
		if _phase in ["READY","APPROACH"]: _finish_outside("CANCELLED",reason)
		else: _unwind()
	return {"ok":true,"released":_released,"status":_phase}

func snapshot() -> Dictionary:
	return {"status":_phase,"reason":_reason,"released":_released,"goal":_goal.duplicate(true),"handoff":_handoff,"active_seconds":_elapsed,"request_id":_request,"public_lease_serial":_serial,"commerce":_commerce_result.duplicate(true),"release":_release_result.duplicate(true),"visit":_visit.status() if _visit!=null else {},"walk":_walk.snapshot() if _walk!=null else {},"source_authority":false,"actor_transform_written":false,"timing_buckets":_timing_buckets.duplicate(true)}

func dispose() -> void:
	if _disposed: return
	if not _released:
		cancel("disposed")
		if not _released: return
	_disposed=true; _phase="DISPOSED"; _host=null; _health=null; _account=null; _policy=null; _owner=null; _scene=null
