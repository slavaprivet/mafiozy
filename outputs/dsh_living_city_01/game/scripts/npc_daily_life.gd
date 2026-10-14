extends RefCounted
## One resident's local needs. Concrete visits own arrival and transactions;
## this scheduler never changes HP, cash, transforms, seats or source rows.
const Walk = preload("npc_daily_walk.gd")
const MEDICAL_THRESHOLD := .75
## DSH_NEEDS: "little money -> go to the bank and top up" thresholds. Cash below
## NEEDS_LOW_CASH counts as low; a withdrawal never takes less than
## NEEDS_WITHDRAW_MIN, and a deposit keeps NEEDS_CASH_RESERVE in hand so the
## planned purchase stays possible after banking.
const NEEDS_LOW_CASH := 6
const NEEDS_WITHDRAW_MIN := 15
const NEEDS_CASH_RESERVE := 12
const SHOP_INTERVAL_MS := 300000.0
var _host: RefCounted
var _health: RefCounted
var _account: RefCounted
var _policy: RefCounted
var _token := {}
var _factory: Callable
var _walk: RefCounted
var _visit: RefCounted
var _goal := {}
var _phase := "UNBOUND"
var _reason := ""
var _now := 0.0
var _dsh_phase_since_ms := 0  # DSH_LIFETRACE: wall clock of the last observed phase
var _dsh_phase_seen := ""  # DSH_LIFETRACE
var _dsh_decisions := 0  # DSH_LIFETRACE
var _dsh_retries := 0  # DSH_LIFETRACE
var _dsh_elapsed := -1.0  # DSH_LIFECLOCK: real game time since this life's previous poll (<0 = not set)
var _dsh_last_ms := 0  # DSH_LIFECLOCK: this life's own previous poll in wall ms; the caller reads and writes exactly this name
var _dsh_probe_life := -1  # DSH_VISITPROBE: --city-visit-probe
var _dsh_life_seen := ""  # DSH_VISITPROBE: the last printed tuple
static var _dsh_s_life_nr := 0  # DSH_VISITPROBE: terminal status seen without released
static var _dsh_s_life_ms := 0  # DSH_VISITPROBE
var _next_decision := 0.0
var _next_shop := 0.0
var _next_drive := 0.0
var _next_medical := 0.0
var _next_bank := 0.0
var _sequence := 0
var _roam_serial := 0
var _frame := -1
var _busy := false
var _disposed := false
var _bank_established := false
var _dsh_needs := -1  # DSH_NEEDS
var _interrupting := false
const INCIDENT_HOLD_MS := 1200.0
const INCIDENT_MAX_HOLD_MS := 3000.0
var _incident_waiting_release := false
var _incident_hold_started := -1.0
var _incident_hold_until := -1.0
var _incident_hold_cap := -1.0
var _incident_seen: Dictionary = {}
var _incident_seen_ring: Array[String] = []
var _journal: Array[Dictionary] = []
var _completed := {"hospital":0,"bank":0,"shop":0,"drive":0,"walk":0}
var _profile_peaks: Array[Dictionary] = []
var _controller_peaks: Array[Dictionary] = []
var _visit_controller_timing: Dictionary = {}
var _visit_timing := {
	"bank":{"step":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""},"snapshot":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""}},
	"shop":{"step":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""},"snapshot":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""}},
	"hospital":{"step":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""},"snapshot":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""}},
	"drive":{"step":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""},"snapshot":{"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_phase":""}}
}

func _init() -> void:
	for _index in 12:
		_profile_peaks.append({"source_id":"","kind":"","phase":"","part":"","us":0,"frame":-1})

func _record_visit_timing(kind: String, part: String, elapsed: int, frame: int, phase: String) -> void:
	if not _visit_timing.has(kind): return
	var bucket: Dictionary=_visit_timing[kind][part]
	bucket["samples"]=int(bucket["samples"])+1
	bucket["total_us"]=int(bucket["total_us"])+elapsed
	if elapsed>int(bucket["max_us"]):
		bucket["max_us"]=elapsed; bucket["max_frame"]=frame; bucket["max_phase"]=phase

func _profile(label: String, started: int) -> void:
	var elapsed := Time.get_ticks_usec() - started
	if elapsed < 1000: return
	var minimum_index:=0
	for index in range(1,_profile_peaks.size()):
		if int(_profile_peaks[index]["us"])<int(_profile_peaks[minimum_index]["us"]): minimum_index=index
	if elapsed<=int(_profile_peaks[minimum_index]["us"]): return
	var peak: Dictionary=_profile_peaks[minimum_index]
	peak["source_id"]=_token.get("source_id",""); peak["kind"]=_goal.get("kind","")
	peak["phase"]=_phase; peak["part"]=label; peak["us"]=elapsed; peak["frame"]=Engine.get_physics_frames()

func _profile_snapshot() -> Array[Dictionary]:
	var peaks: Array[Dictionary]=[]
	for peak: Dictionary in _profile_peaks:
		if int(peak["us"])>0: peaks.append(peak.duplicate())
	peaks.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.us)>int(b.us))
	return peaks

## Factory(kind, goal, activity_owner) returns a CONFIGURED concrete controller
## with begin/step/snapshot/cancel/dispose. Its service owner is authoritative.
func configure(host: RefCounted, token: Dictionary, health: RefCounted, account: RefCounted, policy: RefCounted, factory: Callable) -> Dictionary:
	if _phase!="UNBOUND" or _disposed or not is_instance_valid(host) or not host.target_current(token): return _fail("current_actor_required")
	if not is_instance_valid(health) or health.get("_host")!=host or health.get("_token")!=token or not is_instance_valid(account) or account.get("_host")!=host or account.get("_token")!=token: return _fail("same_actor_health_and_account_required")
	if not is_instance_valid(policy) or not policy.has_method("source_admit") or not policy.has_method("support_height") or not factory.is_valid(): return _fail("world_and_activity_factory_required")
	_host=host; _token=token.duplicate(); _health=health; _account=account; _policy=policy; _factory=factory
	_walk=Walk.new()
	var configured: Dictionary=_walk.configure(host,token,self)
	if not configured.get("ok",false): _host=null; return configured
	_now=health._now()
	var offset:=_unit("start")
	_next_shop=_now+20000.0+offset*45000.0
	_next_bank=_now+12000.0+offset*90000.0
	_next_drive=_now+45000.0+_unit("drive")*120000.0
	_next_decision=_now+offset*4000.0
	var money: Dictionary=account.snapshot().account
	_bank_established=int(money.get("bank",0))>0 or bool(money.get("deposit_seen",false))
	_phase="IDLE"
	return {"ok":true,"source_id":token.source_id,"scope":"new_local_resident_needs"}

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}

func _unit(salt: String) -> float:
	var value:=2166136261
	var text: String=str(_token.get("source_id",""))+":"+salt
	for index in text.length(): value=((value^text.unicode_at(index))*16777619)&0xffffffff
	return float(value)/4294967296.0

func _life() -> Dictionary:
	if _disposed or not is_instance_valid(_host) or not is_instance_valid(_health) or _health.get("_host")!=_host or _health.get("_token")!=_token: return {}
	var current: Dictionary=_health._current(_health._binding)
	if current.is_empty() or not is_same(current.get("row"),_health._row): return {}
	return current.row

func _record(event: String, reason: String="") -> void:
	_journal.append({"event":event,"kind":_goal.get("kind",""),"goal_id":_goal.get("goal_id",""),"at":_now,"reason":reason})
	if _journal.size()>16: _journal.pop_front()


## The life owner is the only public boundary allowed to interrupt its private controllers.
func incident_can_hear(owner: RefCounted) -> bool:
	if _disposed or not Thread.is_main_thread() or _busy or owner!=_health or not _host.target_current(_token): return false
	if _visit!=null or _interrupting or _health.should_pause_walk(): return false
	return _phase in ["IDLE","RESTING","WAITING_FOR_RECOVERY","WALKING","INCIDENT_REACTING"]

func accept_incident_event(owner: RefCounted, event: Dictionary) -> Dictionary:
	if _disposed or not Thread.is_main_thread() or owner!=_health or not _host.target_current(_token):
		return {"accepted":false,"reason":"current_daily_owner_required"}
	if _busy: return {"accepted":false,"retryable":true,"reason":"life_busy"}
	if _interrupting or _incident_waiting_release: return {"accepted":false,"reason":"life_interruption_pending"}
	if event.get("schema")!="local_city_incident/v1" or event.get("authority")!="local_presentation" or event.get("server_ack",true) or event.get("hp_changed",true) or event.get("money_changed",true):
		return {"accepted":false,"reason":"presentation_only_event_required"}
	var kind: String=str(event.get("kind",""))
	var distance: float=float(event.get("distance_m",INF))
	if not is_finite(distance) or distance<0.0 or distance>41.0 or event.get("source_identified",true):
		return {"accepted":false,"reason":"incident_perception_bounds"}
	if kind=="gunshot_visual":
		if event.get("visibility_confirmed")!=true or event.get("line_of_sight")!=true or event.get("fov_confirmed")!=true or not event.has("origin"):
			return {"accepted":false,"reason":"visual_proof_required"}
	elif kind=="heard_gunfire":
		if event.get("audible")!=true or event.get("visibility_confirmed",false) or event.has("origin") or event.has("weapon_id") or (not event.get("line_of_sight",false) and distance>18.45):
			return {"accepted":false,"reason":"auditory_proof_required"}
	else:
		return {"accepted":false,"reason":"unsupported_incident_kind"}
	if event.get("witness_role_scope")!="ordinary_unarmed_civilian": return {"accepted":false,"reason":"role_scope"}
	var body: Variant=_token.get("body")
	if not is_instance_valid(body) or not body is Node3D or str(event.get("witness_source_id",""))!=str(_token.get("source_id","")) or str(event.get("witness_session_id",""))!=str(_token.get("session_id","")) or int(event.get("witness_life_generation",-1))!=int(_token.get("life_generation",-2)) or int(event.get("witness_body_instance_id",-1))!=body.get_instance_id():
		return {"accepted":false,"reason":"witness_life_mismatch"}
	var event_id: String=str(event.get("event_id",""))
	if event_id.is_empty() or _incident_seen.has(event_id): return {"accepted":false,"reason":"duplicate_or_missing_event"}
	var row: Dictionary=_life()
	_now=_health._now()
	if row.is_empty() or row.get("dead",false) or float(row.get("hp",0))<=0 or _health.should_pause_walk() or _needs_hospital(row) or _goal.get("kind")=="hospital":
		return {"accepted":false,"reason":"medical_or_hospital_priority"}
	if _visit!=null:
		var stopped_visit: Dictionary=_visit.cancel("incident_gunshot")
		if not stopped_visit.get("ok",false):
			var refusal: String=str(stopped_visit.get("reason","visit_cancel_refused"))
			return {"accepted":false,"retryable":refusal=="controller_busy","reason":refusal}
		_interrupting=true
		_incident_waiting_release=true
		_record("interrupted","incident_gunshot")
	else:
		var stopped_walk: Dictionary=_walk.interrupt_current_route()
		if not stopped_walk.get("ok",false):
			return {"accepted":false,"retryable":bool(stopped_walk.get("retryable",false)),"reason":str(stopped_walk.get("reason","walk_cancel_refused"))}
		_start_incident_hold()
	_incident_seen[event_id]=true
	_incident_seen_ring.append(event_id)
	if _incident_seen_ring.size()>64: _incident_seen.erase(_incident_seen_ring.pop_front())
	return {"accepted":true,"reason":"waiting_for_visit_release" if _incident_waiting_release else "local_startle"}

func _start_incident_hold() -> void:
	if _incident_hold_started<0.0 or _now>=_incident_hold_cap:
		_incident_hold_started=_now
		_incident_hold_cap=_now+INCIDENT_MAX_HOLD_MS
	_incident_hold_until=minf(_now+INCIDENT_HOLD_MS,_incident_hold_cap)
	_phase="INCIDENT_REACTING"
	_reason="local_gunshot_startle"
	_next_decision=_incident_hold_until
	_record("reaction","gunshot_startle")

func _clear_incident_hold() -> void:
	_incident_hold_started=-1.0
	_incident_hold_until=-1.0
	_incident_hold_cap=-1.0

# DSH_VISITPROBE: the life-side counterpart. `npc_daily_life.gd:147` finishes an activity only
# when a terminal status comes WITH `released`; a terminal status without it is ignored and the
# visit is polled again silently. This prints that case once per change, read-only.
func _dsh_probe_life_on() -> int:  # DSH_VISITPROBE
	if _dsh_probe_life < 0:
		_dsh_probe_life = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-visit-probe="):
				_dsh_probe_life = maxi(0, int(argument.trim_prefix("--city-visit-probe=")))
	return _dsh_probe_life

func _dsh_life_probe(status: String, state: Dictionary) -> void:  # DSH_VISITPROBE
	var released: bool = bool(state.get("released",false))
	var terminal: bool = status in ["CANCELLED","BLOCKED","HOLD","FAILED","STALE","DISPOSED"]
	var tuple: String = "%s|%s|%s|%s" % [status, str(released), _phase, str(_goal.get("kind","-"))]
	if tuple == _dsh_life_seen: return
	_dsh_life_seen = tuple
	var now: int = Time.get_ticks_msec()
	if terminal and not released:
		_dsh_s_life_nr += 1
		print("DSH_VISITPROBE life_terminal_without_release id=", str(_token.get("source_id","")),
			" status=", status, " reason=", str(state.get("reason","")), " life=", _phase,
			" goal=", str(_goal.get("kind","-")), " gid=", str(_goal.get("goal_id","-")),
			" life_age_s=", "%.1f" % (float(now - _dsh_phase_since_ms) / 1000.0),
			" total_without_release=", _dsh_s_life_nr, " step=", str(state.get("phase","-")),
			" releases_field=", str(state.has("released")))

func step(delta: float) -> void:
	if _disposed or _busy or not Thread.is_main_thread() or not is_finite(delta) or delta<=0.0 or delta>.05: return
	var frame:=Engine.get_physics_frames()
	if frame==_frame: return
	_frame=frame; _busy=true
	# DSH_LIFETRACE: two compares per life tick; the clock is read only on a change.
	if _phase!=_dsh_phase_seen: _dsh_phase_seen=_phase; _dsh_phase_since_ms=Time.get_ticks_msec()
	var row:=_life()
	if row.is_empty() or row.get("dead",false) or float(row.get("hp",0))<=0:
		_end_life(); _busy=false; return
	_now=_health._now()
	if _visit!=null:
		# Let boarding/exit/interior owners unwind physically before another task.
		if not _interrupting and _goal.get("kind")!="hospital" and _needs_hospital(row):
			_visit.cancel("medical_priority"); _interrupting=true; _record("interrupted","medical_priority")
		var visit_kind:=str(_goal.get("kind","")); var visit_phase:=_phase
		var profile_started := Time.get_ticks_usec()
		_visit._dsh_elapsed = _dsh_elapsed  # DSH_LIFECLOCK: the visit clocks read this
		_visit.step(delta)
		var visit_step_us:=Time.get_ticks_usec()-profile_started
		_profile("visit_step",profile_started)
		_record_visit_timing(visit_kind,"step",visit_step_us,frame,visit_phase)
		profile_started=Time.get_ticks_usec()
		var state: Dictionary=_visit.snapshot()
		var visit_snapshot_us:=Time.get_ticks_usec()-profile_started
		_profile("visit_snapshot",profile_started)
		_record_visit_timing(visit_kind,"snapshot",visit_snapshot_us,frame,visit_phase)
		var status: String=str(state.get("status",state.get("phase","")))
		if _dsh_probe_life_on() == 1: _dsh_life_probe(status,state)  # DSH_VISITPROBE
		if status in ["COMPLETE","DONE"]: _finish_activity(true,state)
		elif status in ["CANCELLED","BLOCKED","HOLD","FAILED","STALE","DISPOSED"] and state.get("released",false): _finish_activity(false,state)
		_busy=false; return
	if not _host.target_current(_token): _phase="WAITING_FOR_RECOVERY"; _busy=false; return
	if _health.should_pause_walk():
		# Existing health/combat and medical owners retain priority over startle.
		if _phase=="INCIDENT_REACTING": _clear_incident_hold(); _phase="IDLE"; _next_decision=_now
		_busy=false; return
	if _phase=="INCIDENT_REACTING":
		if _needs_hospital(row):
			_clear_incident_hold(); _phase="IDLE"; _next_decision=_now
		elif _now<_incident_hold_until:
			_busy=false; return
		else:
			_clear_incident_hold(); _phase="IDLE"; _reason=""; _next_decision=_now
	if _phase=="WALKING":
		if _needs_hospital(row):
			if _walk.cancel().get("ok",false): _phase="IDLE"; _next_decision=_now
		else:
			_walk._dsh_elapsed = _dsh_elapsed  # DSH_LIFECLOCK
			_walk.step(delta)
			var walking: Dictionary=_walk.snapshot()
			if walking.status=="COMPLETE":
				_walk.cancel(); _completed.walk+=1; _phase="RESTING"; _next_decision=_now+2000.0+_unit("rest:"+str(_roam_serial))*6500.0
			elif walking.status in ["BLOCKED","CANCELLED"]:
				_reason=str(walking.reason); _phase="RESTING"; _next_decision=_now+1500.0
	if _phase in ["IDLE","RESTING","WAITING_FOR_RECOVERY"] and _now>=_next_decision: _choose(row)
	_busy=false

## DSH_NEEDS: opt-in --city-needs=1. Default 0 keeps every existing decision path.
func _needs_on() -> bool:  # DSH_NEEDS
	if _dsh_needs < 0:
		_dsh_needs = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-needs="):
				_dsh_needs = maxi(0, mini(1, int(argument.trim_prefix("--city-needs="))))
	return _dsh_needs == 1

func _needs_hospital(row: Dictionary) -> bool:
	return _now>=_next_medical and float(row.get("max_hp",0))>0 and float(row.get("hp",0))<float(row.max_hp)*MEDICAL_THRESHOLD and not row.get("_medicalDowned",false) and not row.get("_forcedCrawl",false)

func _new_goal(kind: String) -> Dictionary:
	_sequence+=1
	return {"goal_id":str(_token.source_id)+":daily:"+str(_sequence),"kind":kind}

func _choose(row: Dictionary) -> void:
	_dsh_decisions+=1  # DSH_LIFETRACE
	if _needs_hospital(row):
		_start(_new_goal("hospital")); return
	var wallet: Dictionary=_account.snapshot().account
	var pending: Dictionary=wallet.get("pending_purchase",{})
	if _now>=_next_shop:
		var goal_id: String=str(pending.get("goal_id",_new_goal("shop").goal_id))
		var choice: Dictionary=_account.plan_purchase(goal_id,_now)
		if choice.get("ok",false) and choice.get("kind")=="shop":
			_start({"goal_id":goal_id,"kind":"shop"}); return
		if choice.get("ok",false) and choice.get("kind")=="bank" and choice.get("funded",false) and _now>=_next_bank:
			var bank_goal:=_new_goal("bank")
			bank_goal.operation="withdraw"
			bank_goal.amount=mini(int(wallet.bank),maxi(int(choice.amount),15-int(wallet.cash)))
			bank_goal.resume_purchase=goal_id
			_start(bank_goal); return
		# No made-up money: unavailable income leaves the purchase pending.
		_reason=str(choice.get("reason","purchase_unavailable")); _next_shop=_now+10000.0
	# DSH_NEEDS: "little money -> go to the bank and top up". This is the rule that
	# was missing: cash was only ever topped up as a side effect of a planned
	# newspaper purchase, so a resident with a low wallet never banked. Opt-in.
	if _needs_on() and _now>=_next_bank and int(wallet.get("cash",0))<NEEDS_LOW_CASH and int(wallet.get("bank",0))>=NEEDS_WITHDRAW_MIN:
		var topped:=_new_goal("bank")
		topped.operation="withdraw"
		topped.amount=mini(int(wallet.bank),maxi(NEEDS_WITHDRAW_MIN,NEEDS_CASH_RESERVE-int(wallet.cash)))
		_start(topped); return
	if not _bank_established and _now>=_next_bank and int(wallet.get("cash",0))>=12:
		var saving:=_new_goal("bank")
		saving.operation="deposit"
		# DSH_NEEDS: keep a purchase reserve in hand instead of banking 60% of
		# everything, which could leave the wallet unable to buy at all.
		var keep: int = NEEDS_CASH_RESERVE if _needs_on() else 0
		var depositable: int = maxi(0, int(wallet.cash)-keep)
		if depositable<=0:
			if _now>=_next_drive:
				_next_drive=_now+90000.0+_unit("drive:"+str(_sequence))*180000.0
				_start(_new_goal("drive")); return
			_roam(); return
		saving.amount=int(floor(float(depositable)*.60))
		_start(saving); return
	if _now>=_next_drive:
		_next_drive=_now+90000.0+_unit("drive:"+str(_sequence))*180000.0
		_start(_new_goal("drive")); return
	_roam()

func _start(goal: Dictionary) -> void:
	var cancelled: Dictionary=_walk.cancel()
	if not cancelled.get("ok",false): _reason="previous_walk_cancellation_pending"; _next_decision=_now+1000.0; return
	_goal=goal
	var profile_started := Time.get_ticks_usec()
	var created: Variant=_factory.call(goal.kind,goal.duplicate(true),self)
	_profile("configure",profile_started)
	if not created is Dictionary or not created.get("ok",false) or not is_instance_valid(created.get("controller")):
		_retry(str(created.get("reason","activity_unavailable")) if created is Dictionary else "factory_result"); return
	var controller: RefCounted=created.controller
	for method: String in ["begin","step","snapshot","cancel","dispose"]:
		if not controller.has_method(method):
			if controller.has_method("dispose"): controller.dispose()
			_retry("activity_interface:"+method); return
	_visit=controller; _interrupting=false
	profile_started=Time.get_ticks_usec()
	var begun: Variant=_visit.begin()
	_profile("begin",profile_started)
	if not begun is Dictionary or not begun.get("ok",false):
		_visit.cancel("begin_refused")
		# Even failed admission may own a lease which needs normal cleanup ticks.
		_phase="ACTIVITY"; _interrupting=true; _reason=str(begun.get("reason","begin_refused")) if begun is Dictionary else "begin_result"; return
	_phase="ACTIVITY"; _reason=""; _record("started")
	if _needs_on():  # DSH_NEEDS: one line per started activity, with the need state
		var need_row: Dictionary=_life()
		var need_wallet: Dictionary=_account.snapshot().account
		print("DSH_NEEDS id=",str(_token.get("source_id",""))," goal=",str(goal.get("kind",""))," op=",str(goal.get("operation","-")),
			" hp=",int(need_row.get("hp",-1)),"/",int(need_row.get("max_hp",-1)),
			" cash=",int(need_wallet.get("cash",-1))," bank=",int(need_wallet.get("bank",-1)),
			" low_cash_at=",NEEDS_LOW_CASH," reserve=",NEEDS_CASH_RESERVE)

func _finish_activity(success: bool, state: Dictionary) -> void:
	var kind: String=str(_goal.get("kind",""))
	if state.get("timing_buckets",{}) is Dictionary and not state.get("timing_buckets",{}).is_empty():
		_visit_controller_timing[kind]=state["timing_buckets"].duplicate(true)
	var samples: Array=state.get("profile_peaks",[])
	var visit_state: Variant=state.get("visit",{})
	if visit_state is Dictionary:
		samples.append_array(visit_state.get("profile_peaks",[]))
	for sample: Dictionary in samples:
		var captured := sample.duplicate(true);captured["kind"] = kind;captured["source_id"] = _token.get("source_id","")
		_controller_peaks.append(captured)
	_controller_peaks.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.us)>int(b.us))
	if _controller_peaks.size()>12:_controller_peaks.resize(12)
	# COMPLETE is published by a visit only after its physical return/release.
	if not state.get("released",false): return
	_visit.dispose(); _visit=null
	if success and not _interrupting:
		if _completed.has(kind): _completed[kind]+=1
		if kind=="bank":
			_bank_established=true; _next_bank=_now+1000.0
			if _goal.get("operation")=="withdraw": _next_shop=_now
		elif kind=="shop": _next_shop=_now+SHOP_INTERVAL_MS
		elif kind=="hospital": _next_medical=_now+1000.0
		_record("completed"); _goal={}; _phase="IDLE"; _next_decision=_now+1000.0
	else: _retry(str(state.get("reason",_reason)))
	_interrupting=false
	if _incident_waiting_release:
		_incident_waiting_release=false
		var current: Dictionary=_life()
		if not current.is_empty() and not _health.should_pause_walk() and not _needs_hospital(current) and _goal.get("kind")!="hospital":
			_start_incident_hold()
		else:
			_clear_incident_hold(); _phase="IDLE"; _next_decision=_now

func _retry(reason: String) -> void:
	_reason=reason; _record("retry",reason)
	_dsh_retries+=1  # DSH_LIFETRACE
	match str(_goal.get("kind","")):
		"hospital": _next_medical=_now+10000.0
		"bank": _next_bank=_now+30000.0
		"shop": _next_shop=_now+15000.0
	_phase="IDLE"; _next_decision=_now+1500.0; _goal={}

func _roam() -> void:
	_roam_serial+=1
	var body: CharacterBody3D=_token.body
	# Bounded source-floor proposals. The current native path and host still
	# validate every segment; these points never authorize teleport or passage.
	for attempt in 6:
		var angle:=TAU*_unit("walk:"+str(_roam_serial)+":"+str(attempt))
		var distance:=6.0+_unit("range:"+str(_roam_serial)+":"+str(attempt))*18.0
		var target:=body.global_position+Vector3(cos(angle),0,sin(angle))*distance
		var floor_y: float=_policy.support_height(target,_token.source_id,_token.life_generation)
		if not is_finite(floor_y): continue
		target.y=floor_y
		if not _policy.source_admit(target,_token.source_id,_token.life_generation,.738,"target"): continue
		var begun: Dictionary=_walk.begin(target)
		if begun.get("ok",false): _phase="WALKING"; _reason=""; return
	_phase="RESTING"; _reason="no_current_clear_walking_goal"; _next_decision=_now+2000.0

func _end_life() -> void:
	if _visit!=null:
		_visit.cancel("actor_life_ended"); _visit.dispose(); _visit=null
	if _walk!=null: _walk.dispose()
	_phase="RETIRED"; _disposed=true; _factory=Callable()
	_incident_waiting_release=false; _clear_incident_hold(); _incident_seen.clear(); _incident_seen_ring.clear()
	_health=null; _account=null; _host=null

func snapshot() -> Dictionary:
	return {"source_id":_token.get("source_id",""),"phase":_phase,"reason":_reason,"goal":_goal.duplicate(true),"completed":_completed.duplicate(),"events":_journal.duplicate(true),"activity":_visit.snapshot() if _visit!=null else {},"walk":_walk.snapshot() if _walk!=null else {},"account":_account.snapshot() if _account!=null else {},"source_rows_written":false,"profile_peaks":_profile_snapshot(),"controller_peaks":_controller_peaks.duplicate(true),"visit_timing":_visit_timing.duplicate(true),"visit_controller_timing":_visit_controller_timing.duplicate(true),"incident_waiting_release":_incident_waiting_release,"incident_hold_until":_incident_hold_until,"incident_seen":_incident_seen.size()}

func dispose() -> void:
	if _disposed or _busy: return
	if _visit!=null:
		_visit.cancel("scheduler_disposed")
		# The host/scene owner keeps stepping until the physical owner releases.
		if not _visit.snapshot().get("released",false): _interrupting=true; return
		_visit.dispose(); _visit=null
	if _walk!=null: _walk.dispose()
	_disposed=true; _phase="DISPOSED"; _factory=Callable()
