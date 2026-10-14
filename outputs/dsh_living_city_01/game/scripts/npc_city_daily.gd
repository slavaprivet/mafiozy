extends RefCounted
## Scene wiring for real admitted residents. Movement remains in population.step
## and transport._physics_process; visit/account code alone commits services.
const Life = preload("npc_daily_life.gd")
const Account = preload("shop/npc_local_account.gd")
const Drive = preload("npc_daily_drive.gd")
var _scene: WeakRef
var _population: RefCounted
var _hospital: WeakRef
var _bank: WeakRef
var _hospital_script: Script
var _bank_script: Script
var _shop_script: Script
var _entry := PackedByteArray()
var _geometry := PackedByteArray()
var _road_path := ""
var _road_sha := ""
var _lives := {}
var _accounts := {}
var _health := {}
var _failures := {}
var _disposed := false
var _frame := -1
var _cursor := 0
var _samples := 0
var _total_us := 0
var _max_us := 0
var _max_frame := -1
var _life_peaks:Array[Dictionary]=[]
var _dsh_trace := -1  # DSH_LIFETRACE: --city-life-trace=N, 0 (default) = off
var _dsh_trace_ids: Array = []  # DSH_LIFETRACE: the traced source_ids
var _dsh_trace_pick := false  # DSH_LIFETRACE: the id list is resolved once
var _dsh_trace_t0 := 0  # DSH_LIFETRACE: this trace's wall-clock start
var _dsh_trace_ms := 0  # DSH_LIFETRACE: last print, one per wall second
var _dsh_trace_pos := {}  # DSH_LIFETRACE: id -> body position at the last print
var _dsh_trace_status := {}  # DSH_LIFETRACE: id -> last observed record status
var _dsh_trace_status_ms := {}  # DSH_LIFETRACE: id -> when it was first seen
var _dsh_trace_moved_m := {}  # DSH_LIFETRACE: id -> metres since the last print
var _dsh_trace_moved_s := {}  # DSH_LIFETRACE: id -> print periods with motion
var _dsh_life_clock := -1  # DSH_LIFECLOCK: --city-life-clock
var _dsh_life_cap_value := 10.0  # DSH_LIFECLOCK: --city-life-clock-cap

func _init() -> void:
	for _index in 12: _life_peaks.append({"frame":-1,"source_id":"","phase":"","kind":"","us":0})
	_dsh_poll_ring.resize(DSH_POLL_RING)  # DSH_DAILYFX

func _record_life_peak(frame: int, source_id: String, phase: String, kind: String, elapsed: int) -> void:
	var minimum_index:=0
	for index in range(1,_life_peaks.size()):
		if int(_life_peaks[index]["us"])<int(_life_peaks[minimum_index]["us"]): minimum_index=index
	if elapsed<=int(_life_peaks[minimum_index]["us"]): return
	var peak: Dictionary=_life_peaks[minimum_index]
	peak["frame"]=frame; peak["source_id"]=source_id; peak["phase"]=phase; peak["kind"]=kind; peak["us"]=elapsed

func _life_peaks_snapshot() -> Array[Dictionary]:
	var peaks: Array[Dictionary]=[]
	for peak: Dictionary in _life_peaks:
		if int(peak["frame"])>=0: peaks.append(peak.duplicate())
	peaks.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.us)>int(b.us))
	return peaks

func configure(scene: Node3D, population: RefCounted, hospital: Node3D, bank: Node3D, hospital_script: Script, bank_script: Script, shop_script: Script, entry_bytes: PackedByteArray, geometry_bytes: PackedByteArray, route_path: String, route_sha: String) -> Dictionary:
	if _scene!=null or _disposed or not is_instance_valid(scene) or not scene.is_inside_tree() or not is_instance_valid(population) or population.get("residents")==null or population.get("policy")==null: return {"ok":false,"reason":"current_population_required"}
	if not is_instance_valid(hospital) or not hospital.get("ready_for_use") or not is_instance_valid(bank) or not bank.get("ready_for_use"): return {"ok":false,"reason":"actual_hospital_and_bank_required"}
	for script: Script in [hospital_script,bank_script,shop_script]:
		if script==null or not script.can_instantiate(): return {"ok":false,"reason":"concrete_visit_scripts_required"}
	_scene=weakref(scene); _population=population; _hospital=weakref(hospital); _bank=weakref(bank)
	_hospital_script=hospital_script; _bank_script=bank_script; _shop_script=shop_script
	_entry=entry_bytes.duplicate(); _geometry=geometry_bytes.duplicate(); _road_path=route_path; _road_sha=route_sha
	scene.tree_exiting.connect(_retire_scene,CONNECT_ONE_SHOT)
	for owner: RefCounted in population.hit_owners:
		var token: Dictionary=owner.get("_token")
		if not population.residents.target_current(token): continue
		var id: String=token.source_id
		var account:=Account.new()
		var admitted: Dictionary=account.configure(population.residents,token,owner)
		if not admitted.get("ok",false): _failures[id]=admitted; continue
		var bank_bound: Dictionary=account.bind_bank(scene)
		if not bank_bound.get("ok",false): account.dispose(); _failures[id]=bank_bound; continue
		var life:=Life.new()
		var active: Dictionary=life.configure(population.residents,token,owner,account,population.policy,Callable(self,"_create_visit").bind(id))
		if not active.get("ok",false): life.dispose(); account.dispose(); _failures[id]=active; continue
		_accounts[id]=account; _lives[id]=life; _health[id]=owner
	return {"ok":not _lives.is_empty(),"residents":_lives.size(),"failures":_failures.duplicate(true),"scene_mechanics":"new_local_session"}

func incident_can_hear(owner: RefCounted, _observation: Dictionary) -> bool:
	if _disposed or not Thread.is_main_thread() or not is_instance_valid(owner): return false
	var token: Dictionary=owner.get("_token")
	var id: String=str(token.get("source_id",""))
	if id.is_empty() or not _health.has(id) or _health[id]!=owner or not _lives.has(id) or not _population.residents.target_current(token): return false
	return _lives[id].incident_can_hear(owner)

func incident_submit_witness(owner: RefCounted, event: Dictionary) -> Dictionary:
	if _disposed or not Thread.is_main_thread() or not is_instance_valid(owner): return {"accepted":false,"reason":"daily_owner_unavailable"}
	var token: Dictionary=owner.get("_token")
	var id: String=str(event.get("witness_source_id",""))
	if id.is_empty() or str(token.get("source_id",""))!=id or not _health.has(id) or _health[id]!=owner or not _lives.has(id) or not _population.residents.target_current(token):
		return {"accepted":false,"reason":"current_health_owner_required"}
	return _lives[id].accept_incident_event(owner,event)

func _create_visit(kind: String, goal: Dictionary, activity_owner: RefCounted, id: String) -> Dictionary:
	if _disposed or _scene==null or not is_instance_valid(_scene.get_ref()) or not _lives.has(id) or _lives[id]!=activity_owner: return {"ok":false,"reason":"current_daily_owner_required"}
	var host: RefCounted=_population.residents
	var token: Dictionary=_health[id]._token
	if not host.target_current(token): return {"ok":false,"reason":"current_walker_required"}
	var scene: Node3D=_scene.get_ref()
	var controller: RefCounted
	var result: Dictionary
	match kind:
		"hospital":
			controller=_hospital_script.new()
			result=controller.configure(host,_population.policy,_health[id],_hospital.get_ref(),scene,"LOCAL_DAILY24:"+id,activity_owner)
		"bank":
			controller=_bank_script.new()
			result=controller.configure(host,_population.policy,_health[id],_bank.get_ref(),scene,"LOCAL_DAILY24:"+id,activity_owner,_accounts[id],goal)
		"shop":
			controller=_shop_script.new()
			result=controller.configure(host,_population.policy,_health[id],scene,activity_owner,_accounts[id],goal,_entry,_geometry)
		"drive":
			var transport: Node3D=scene.get("preview_transport")
			if not is_instance_valid(transport): return {"ok":false,"reason":"native_transport_unavailable"}
			controller=Drive.new()
			result=controller.configure(host,token,activity_owner,transport,_road_path,_road_sha)
		_: return {"ok":false,"reason":"unknown_activity"}
	if not result.get("ok",false):
		controller.dispose(); return result
	return {"ok":true,"controller":controller}

const DAILY_SLICE:=48
# DSH_VISITCACHE: the meta key the two daily route files cache the block/site enumerations under
# (npc_local_printshop_route.gd, npc_daily_entry_route.gd). The DSH_DAILY line below reads its
# counters; with --city-visit-scene-cache=0 nothing ever creates the dictionary.
const DSH_VISIT_CACHE_KEY := "dsh_visit_scene_cache"  # DSH_VISITCACHE
# DSH_NAVDAILY (temporary): the slice cadence and the resident key order are cached.
# _lives only changes in configure()/dispose(), so the 284-element keys() Array and
# the per-frame element count are rebuilt only when the resident count changes;
# polling cadence, ordering and the cursor walk are unchanged.
# --city-daily-slice=N (default 48 = current behaviour) is an A/B cadence lever.
var _dsh_slice := 0  # DSH_NAVDAILY: 0 = unresolved
var _dsh_ids: Array = []  # DSH_NAVDAILY: cached _lives key order
var _dsh_per_frame := 0  # DSH_NAVDAILY: cached ceil(count/slice)
# DSH_DAILYMIN: --city-daily-min-per-frame=N is an opt-in FLOOR on how many lives
# one city step polls. 0 (default) keeps exactly the cached ceil(count/slice).
var _dsh_min_per_frame := -1  # DSH_DAILYMIN
const DSH_POLL_RING:=64  # DSH_DAILYFX: per-poll window behind the DSH_DAILY distribution
var _dsh_poll_ring:=PackedInt32Array()  # DSH_DAILYFX
var _dsh_poll_cursor:=0  # DSH_DAILYFX
var _dsh_poll_filled:=0  # DSH_DAILYFX
var _dsh_budget_cache:=-1  # DSH_DAILYFX: --city-daily-budget-us, 0 = today's fixed count
var _dsh_worst_us:=0  # DSH_DAILYFX: worst poll of the print window
var _dsh_worst_id:=""  # DSH_DAILYFX
var _dsh_worst_from:=""  # DSH_DAILYFX
var _dsh_worst_to:=""  # DSH_DAILYFX
var _dsh_worst_state:=""  # DSH_DAILYFX
var _dsh_worst_reason:=""  # DSH_DAILYFX
var _dsh_worst_parts:=""  # DSH_DAILYFX

func _dsh_daily_slice() -> int:  # DSH_NAVDAILY
	if _dsh_slice <= 0:
		_dsh_slice = 96  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-slice="):
				_dsh_slice = maxi(1, int(argument.trim_prefix("--city-daily-slice=")))
	return _dsh_slice

func _dsh_daily_min_per_frame() -> int:  # DSH_DAILYMIN
	if _dsh_min_per_frame < 0:
		_dsh_min_per_frame = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-min-per-frame="):
				_dsh_min_per_frame = maxi(0, int(argument.trim_prefix("--city-daily-min-per-frame=")))
	return _dsh_min_per_frame

# DSH_DAILYFX: --city-daily-budget-us=N stops the rotating slice of ONE city step
# once N microseconds of it are spent, and the cursor below now advances by the
# number of residents actually polled, so the walk resumes exactly where it stopped.
# 0 (default) never breaks: the poll count per step is today's ceil(count/slice).
func _dsh_daily_budget() -> int:  # DSH_DAILYFX
	if _dsh_budget_cache<0:
		_dsh_budget_cache=0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-budget-us="):
				_dsh_budget_cache=maxi(0,int(argument.trim_prefix("--city-daily-budget-us=")))
	return _dsh_budget_cache

# DSH_DAILYFX: one point of the per-poll distribution of the last DSH_POLL_RING polls.
func _dsh_poll_us_at(ratio: float) -> int:  # DSH_DAILYFX
	if _dsh_poll_filled<=0: return 0
	var sorted:=_dsh_poll_ring.slice(0,_dsh_poll_filled)
	sorted.sort()
	return int(sorted[mini(sorted.size()-1,int(float(sorted.size())*ratio))])

# DSH_DAILYFX: the polled resident's own profile peaks (configure / begin /
# visit_step / visit_snapshot) so a spike names its sub-call without a new probe.
func _dsh_poll_parts(life: RefCounted) -> String:  # DSH_DAILYFX
	var peaks: Array=life._profile_peaks
	var text:=""
	for peak: Dictionary in peaks:
		if int(peak["us"])<1000: continue
		if not text.is_empty(): text+=","
		text+=str(peak["part"])+":"+str(int(peak["us"]))+"@"+str(int(peak["frame"]))
	return text

# --------------------------------------------------------------------------- #
# DSH_LIFETRACE: read-only diagnosis. --city-life-trace=0 (default) prints nothing and
# changes no decision; with N>0 one line per traced resident per wall second.
# --------------------------------------------------------------------------- #
func _dsh_life_trace() -> int:  # DSH_LIFETRACE
	if _dsh_trace < 0:
		_dsh_trace = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-life-trace="):
				_dsh_trace = clampi(int(argument.trim_prefix("--city-life-trace=")), 0, 32)
	return _dsh_trace

# DSH_LIFETRACE: N residents by a stride over the sorted ids (a spread sample), or the
# exact list in --city-life-trace-ids=resident_3,resident_77 when that is given.
func _dsh_trace_pick_ids() -> void:  # DSH_LIFETRACE
	_dsh_trace_pick = true
	_dsh_trace_ids = []
	var wanted: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--city-life-trace-ids="):
			wanted = argument.trim_prefix("--city-life-trace-ids=")
	if not wanted.is_empty():
		for piece: String in wanted.split(",", false):
			if _lives.has(piece) and not _dsh_trace_ids.has(piece): _dsh_trace_ids.append(piece)
		return
	var n: int = _dsh_life_trace()
	if n <= 0 or _lives.is_empty(): return
	var ids: Array = _lives.keys()
	ids.sort()
	if n >= ids.size():
		_dsh_trace_ids = ids
		return
	var stride: int = maxi(1, int(ids.size() / n))
	for index in range(0, ids.size(), stride):
		_dsh_trace_ids.append(ids[index])
		if _dsh_trace_ids.size() >= n: break

# DSH_LIFETRACE: best-effort destination of a visit controller. The four visit owners do
# not share one field name, so this reads the ones they do share and reports "-" otherwise.
func _dsh_trace_visit(v: RefCounted) -> Array:  # DSH_LIFETRACE
	if v == null: return ["-", "-", false, -1.0, "-"]
	var script: Script = v.get_script()
	var name: String = "-"
	if script != null: name = script.resource_path.get_file()
	var phase: String = str(v.get("_phase"))
	var released: Variant = v.get("_released")
	var elapsed: Variant = v.get("_elapsed")
	var reason: String = str(v.get("_reason"))
	return [name, phase, released, elapsed, reason]

func _dsh_trace_line(frame: int) -> void:  # DSH_LIFETRACE
	var now_ms: int = Time.get_ticks_msec()
	if _dsh_trace_ms == 0: _dsh_trace_ms = now_ms
	if now_ms - _dsh_trace_ms < 1000: return
	_dsh_trace_ms = now_ms
	if not _dsh_trace_pick: _dsh_trace_pick_ids()
	if _dsh_trace_ids.is_empty(): return
	if _dsh_trace_t0 == 0: _dsh_trace_t0 = now_ms
	var residents: RefCounted = _population.residents
	var t: float = float(now_ms - _dsh_trace_t0) / 1000.0
	for id: String in _dsh_trace_ids:
		if not _lives.has(id): continue
		var life: RefCounted = _lives[id]
		var walk: RefCounted = life._walk
		var record: Dictionary = residents._records.get(id, {})
		var body: CharacterBody3D = record.body
		var pos: Vector3 = body.global_position if is_instance_valid(body) else Vector3.ZERO
		var moved: float = float(_dsh_trace_moved_m.get(id, 0.0))
		var moved_s: float = float(_dsh_trace_moved_s.get(id, 0.0))
		if _dsh_trace_pos.has(id):
			var prev_pos: Vector3 = _dsh_trace_pos[id]
			var step_m: float = pos.distance_to(prev_pos)
			if step_m > 0.005: moved += step_m; moved_s += 1.0
		_dsh_trace_pos[id] = pos
		_dsh_trace_moved_m[id] = moved
		_dsh_trace_moved_s[id] = moved_s
		var rstatus: String = str(record.get("status", "-"))
		if not _dsh_trace_status.has(id) or str(_dsh_trace_status[id]) != rstatus:
			_dsh_trace_status[id] = rstatus
			_dsh_trace_status_ms[id] = now_ms
		var rage: float = float(now_ms - int(_dsh_trace_status_ms.get(id, now_ms))) / 1000.0
		var walk_phase: String = str(walk._phase) if walk != null else "-"
		var walk_age: float = float(now_ms - int(walk._dsh_phase_since_ms)) / 1000.0 if walk != null else -1.0
		var blocks: int = int(walk._dsh_blocks) if walk != null else -1
		var wr: String = str(walk._reason) if walk != null else "-"
		var req: int = int(walk._request) if walk != null else -1
		var legs: String = "%d/%d" % [int(walk._edge), walk._points.size()] if walk != null else "-"
		var target: Vector3 = walk._target if walk != null else Vector3.ZERO
		var visit: Array = _dsh_trace_visit(life._visit)
		var done: Dictionary = life._completed
		var last: String = "-"
		if not life._journal.is_empty():
			var entry: Dictionary = life._journal[-1]
			last = str(entry.get("event", "-")) + "@" + ("%.1f" % float(entry.get("at", -1.0)))
		print("DSH_LIFETRACE f=", frame, " id=", id, " t=", "%.1f" % t,
			" life=", life._phase, " life_age=", "%.1f" % (float(now_ms - int(life._dsh_phase_since_ms)) / 1000.0),
			" goal=", str(life._goal.get("kind", "-")), " gid=", str(life._goal.get("goal_id", "-")),
			" op=", str(life._goal.get("operation", "-")),
			" next_in=", "%.1f" % (float(life._next_decision) - float(life._now)),
			" lreason=", life._reason, " decisions=", int(life._dsh_decisions), " retries=", int(life._dsh_retries),
			" walk=", walk_phase, " walk_age=", "%.1f" % walk_age, " legs=", legs,
			" tgt=(", "%.1f" % target.x, ",", "%.1f" % target.y, ",", "%.1f" % target.z, ")",
			" blocks=", blocks, " wreason=", wr,
			" req=", req, " rstatus=", rstatus, " rage=", "%.1f" % rage,
			" rreason=", str(record.get("reason", "")),
			" visit=", visit[0], " vphase=", visit[1], " vrel=", str(visit[2]),
			" velapsed=", ("%.1f" % float(visit[3])) if (visit[3] is float or visit[3] is int) else "-",
			" vreason=", visit[4],
			" moved=", "%.2f" % moved, " mtime=", "%.1f" % moved_s,
			" done=", int(done.get("walk", 0)), "/", int(done.get("hospital", 0)), "/",
			int(done.get("bank", 0)), "/", int(done.get("shop", 0)), "/", int(done.get("drive", 0)),
			" last=", last)
		_dsh_trace_moved_m[id] = 0.0
		_dsh_trace_moved_s[id] = 0.0

# DSH_LIFECLOCK: --city-life-clock=1 (default) gives the daily timers the real elapsed game
# time. A life is polled once per daily slice (96 city steps ~ 4.75 s) while its `delta` is one
# city step (~0.05 s), so every accumulator ran ~96x slow. --city-life-clock-cap bounds ONE
# credited interval: the interval is ~4.75 s, so a cap below that would silently lose real time;
# 10 s preserves every normal poll and still stops a hitch/load spike from stepping through
# several detours or deadlines in one jump. Paused time (the source idle window of
# should_pause_walk) is credited as 0.0, never as a shortened interval.
func _dsh_life_clock_on() -> int:  # DSH_LIFECLOCK
	if _dsh_life_clock < 0:
		_dsh_life_clock = 1
		_dsh_life_cap_value = 10.0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-life-clock="):
				_dsh_life_clock = maxi(0, int(argument.trim_prefix("--city-life-clock=")))
			elif argument.begins_with("--city-life-clock-cap="):
				_dsh_life_cap_value = maxf(0.05, float(argument.trim_prefix("--city-life-clock-cap=")))
	return _dsh_life_clock

func _dsh_life_cap() -> float:  # DSH_LIFECLOCK
	return _dsh_life_cap_value

func step(delta: float) -> void:
	if _disposed or _scene==null or not is_instance_valid(_scene.get_ref()) or not is_finite(delta) or delta<=0.0 or delta>.05: return
	var frame:=Engine.get_physics_frames()
	if frame==_frame: return
	_frame=frame
	var started:=Time.get_ticks_usec()
	# The walk and visit controllers only POLL. The native navigation host advances
	# every actor in population.step on every frame, so polling all residents here
	# cost about 1 ms per resident per frame at city scale and dominated the frame.
	# Poll a rotating slice instead: every resident is still served once per
	# DAILY_SLICE frames, so a leg or visit advance lands at most that many frames
	# later. Decisions keep their own millisecond time base, so no work is skipped,
	# only sampled less often.
	# DSH_NAVDAILY: the key order is cached; a resident-count change rebuilds it. Same
	# residents, same order, same cursor arithmetic, same polling cadence.
	var count:=_lives.size()
	if _dsh_ids.size()!=count:
		_dsh_ids=_lives.keys()
		_dsh_per_frame=maxi(1,int(ceil(float(count)/float(_dsh_daily_slice()))))
	var ids: Array=_dsh_ids
	var per_frame:=_dsh_per_frame
	# DSH_DAILYMIN: an opt-in floor only. count==0 keeps per_frame untouched and
	# the loop below breaks immediately, exactly as before.
	var dsh_min_polls:=_dsh_daily_min_per_frame()
	if dsh_min_polls>per_frame and count>0: per_frame=mini(count, dsh_min_polls)
	var stepped:=0
	var life_total:=0
	var dsh_budget:=_dsh_daily_budget()  # DSH_DAILYFX
	# DSH_NAVDAILY: `phases` is read only by the DSH_DAILY print below.
	var dsh_phases_frame:=frame%15==0
	var phases:={}
	for k in per_frame:
		if count<=0: break
		# DSH_DAILYFX: dsh_budget==0 (default) never breaks here. k>0 guarantees at
		# least one poll per step, so no step can starve the walk.
		if dsh_budget>0 and k>0 and Time.get_ticks_usec()-started>=dsh_budget: break
		var index:=(_cursor+k)%count
		var life: RefCounted=_lives[ids[index]]
		var life_started:=Time.get_ticks_usec()
		var life_phase:String=life._phase
		var life_kind:String=str(life._goal.get("kind",""))
		# DSH_LIFECLOCK: the timer input is the REAL game time since this life's previous
		# poll, kept strictly separate from `delta` (one city step, ~0.05 s), so nothing else
		# in the chain - guards, order, physics - changes. `_dsh_elapsed` stays -1.0 while the
		# flag is 0, and every clock then falls back to `delta` (today's behaviour).
		if _dsh_life_clock_on() == 1:
			var dsh_now: int = Time.get_ticks_msec()
			var dsh_last: int = int(life._dsh_last_ms)
			life._dsh_last_ms = dsh_now
			if dsh_last <= 0 or life._health.should_pause_walk(): life._dsh_elapsed = 0.0
			else: life._dsh_elapsed = clampf(float(dsh_now - dsh_last) / 1000.0, 0.0, _dsh_life_cap())
		life.step(delta)
		var life_us:=Time.get_ticks_usec()-life_started
		stepped+=1; life_total+=life_us
		if dsh_phases_frame: phases[life_phase]=int(phases.get(life_phase,0))+1
		if life_us>=1000:
			_record_life_peak(frame,str(ids[index]),life_phase,life_kind,life_us)
		# DSH_DAILYFX: per-poll window sample and the worst poll of the window, with
		# the resident's own start/end phase, reason and profile peaks.
		_dsh_poll_ring[_dsh_poll_cursor]=life_us
		_dsh_poll_cursor=(_dsh_poll_cursor+1)%DSH_POLL_RING
		if _dsh_poll_filled<DSH_POLL_RING: _dsh_poll_filled+=1
		if life_us>_dsh_worst_us:
			_dsh_worst_us=life_us
			_dsh_worst_id=str(ids[index])
			_dsh_worst_from=life_phase
			_dsh_worst_to=str(life._phase)
			_dsh_worst_state=life_kind
			_dsh_worst_reason=str(life._reason)
			_dsh_worst_parts=_dsh_poll_parts(life) if life_us>=2000 else ""
	if count>0: _cursor=(_cursor+stepped)%count
	var elapsed:=Time.get_ticks_usec()-started
	# DSH_VISITCACHE: the visit-scene cache trigger of this window. lookups = every cache decision
	# (one per configured daily route), hits/builds its outcome, us the time the cache itself spent
	# (membership guard + build). Reset with the rest of this window, like every DSH_DAILYFX field.
	var dsh_cache_lookups:=0  # DSH_VISITCACHE
	var dsh_cache_hits:=0  # DSH_VISITCACHE
	var dsh_cache_builds:=0  # DSH_VISITCACHE
	var dsh_cache_us:=0  # DSH_VISITCACHE
	if frame%15==0:
		var dsh_cache_value: Variant=_scene.get_ref().get_meta(DSH_VISIT_CACHE_KEY,{})
		var dsh_cache: Dictionary=dsh_cache_value if dsh_cache_value is Dictionary else {}
		dsh_cache_lookups=int(dsh_cache.get("lookups",0));dsh_cache_hits=int(dsh_cache.get("hits",0));dsh_cache_builds=int(dsh_cache.get("builds",0));dsh_cache_us=int(dsh_cache.get("us",0))
		dsh_cache["lookups"]=0;dsh_cache["hits"]=0;dsh_cache["builds"]=0;dsh_cache["us"]=0
	if frame%15==0: print("DSH_DAILY f=",frame," lives=",count," stepped=",stepped," life_us=",life_total," overhead_us=",elapsed-life_total," total_us=",elapsed," phases=",phases," polls=",_dsh_poll_filled," pmin=",_dsh_poll_us_at(0.0)," p50=",_dsh_poll_us_at(.5)," p90=",_dsh_poll_us_at(.9)," pmax=",_dsh_poll_us_at(1.0)," budget_us=",dsh_budget," worst_us=",_dsh_worst_us," worst_id=",_dsh_worst_id," worst_from=",_dsh_worst_from," worst_to=",_dsh_worst_to," worst_state=",_dsh_worst_state," worst_reason=",_dsh_worst_reason," worst_parts=",_dsh_worst_parts," scene_cache_lookups=",dsh_cache_lookups," scene_cache_hits=",dsh_cache_hits," scene_cache_builds=",dsh_cache_builds," scene_cache_us=",dsh_cache_us)
	if frame%15==0: _dsh_poll_filled=0; _dsh_poll_cursor=0; _dsh_worst_us=0; _dsh_worst_id=""; _dsh_worst_from=""; _dsh_worst_to=""; _dsh_worst_state=""; _dsh_worst_reason=""; _dsh_worst_parts=""  # DSH_DAILYFX: the window is the print interval
	if _dsh_life_trace() > 0: _dsh_trace_line(frame)  # DSH_LIFETRACE: one line per traced resident per wall second
	# DSH_LIVES (temporary): the population-wide counterpart of DSH_ECON, so one long
	# run can prove that daily life advances under simulation LOD without sampling
	# three residents. Additive: DSH_ECON keeps its exact shape and cadence.
	if frame%600==0 and not _lives.is_empty():
		var dsh_walking:=0
		var dsh_activity:=0
		var dsh_resting:=0
		var dsh_idle:=0
		var dsh_other:=0
		var dsh_done:={}
		# The walk controller carries its own liveness guards (a leg that takes
		# over 30 s, or a READY leg with no motion for 2 s, goes to a detour). Its
		# phase and active time are therefore the direct stuck signal: a life can
		# report WALKING while its own walk controller sits in BLOCKED.
		var dsh_walk_blocked:=0
		var dsh_walk_detour:=0
		var dsh_walk_complete:=0
		var dsh_walk_age_max:=0.0
		var dsh_now_ms:=Time.get_ticks_msec()  # DSH_LIFETRACE
		var dsh_residents: RefCounted=_population.residents  # DSH_LIFETRACE
		var dsh_walk_req:=0  # DSH_LIFETRACE
		var dsh_walk_planning:=0  # DSH_LIFETRACE
		var dsh_walk_walking:=0  # DSH_LIFETRACE
		var dsh_walk_idle:=0  # DSH_LIFETRACE
		var dsh_leg_wait:=0  # DSH_LIFETRACE
		var dsh_path_pending:=0  # DSH_LIFETRACE
		var dsh_path_ready:=0  # DSH_LIFETRACE
		var dsh_path_blocked:=0  # DSH_LIFETRACE
		var dsh_act_notreleased:=0  # DSH_LIFETRACE
		var dsh_act_unknown:=0  # DSH_LIFETRACE
		var dsh_act_stuck60:=0  # DSH_LIFETRACE
		var dsh_rest_long:=0  # DSH_LIFETRACE
		var dsh_rest_left:=0.0  # DSH_LIFETRACE
		var dsh_block_reasons:={}  # DSH_LIFETRACE
		for dsh_id: String in _lives:  # DSH_LIFETRACE: the id is needed for the record read
			var dsh_life: RefCounted=_lives[dsh_id]
			var dsh_phase:String=dsh_life._phase
			if dsh_phase=="WALKING": dsh_walking+=1
			elif dsh_phase=="ACTIVITY": dsh_activity+=1
			elif dsh_phase=="RESTING": dsh_resting+=1
			elif dsh_phase=="IDLE": dsh_idle+=1
			else: dsh_other+=1
			var dsh_walk: RefCounted=dsh_life._walk
			if dsh_walk!=null:
				var dsh_walk_phase:String=dsh_walk._phase
				if dsh_walk_phase=="BLOCKED": dsh_walk_blocked+=1
				elif dsh_walk_phase=="DETOUR": dsh_walk_detour+=1
				elif dsh_walk_phase=="COMPLETE": dsh_walk_complete+=1
				var dsh_age: float=float(dsh_walk._active_time)
				if dsh_age>dsh_walk_age_max: dsh_walk_age_max=dsh_age
			# DSH_LIFETRACE: the 284-wide wait/block balance. Integer adds plus one record
			# read per resident, inside the loop that already runs once per 600 frames.
			if dsh_walk!=null:
				var dsh_wp:String=dsh_walk._phase
				if dsh_wp=="PLANNING": dsh_walk_planning+=1
				elif dsh_wp=="WALKING":
					dsh_walk_walking+=1
					if int(dsh_walk._request)<0: dsh_leg_wait+=1
				elif dsh_wp=="IDLE": dsh_walk_idle+=1
				elif dsh_wp=="BLOCKED":
					var dsh_br:String=str(dsh_walk._reason)
					dsh_block_reasons[dsh_br]=int(dsh_block_reasons.get(dsh_br,0))+1
				if int(dsh_walk._request)>=0: dsh_walk_req+=1
			var dsh_record: Dictionary=dsh_residents._records.get(dsh_id,{})  # DSH_LIFETRACE
			var dsh_rs: String=str(dsh_record.get("status",""))
			if dsh_rs=="PENDING": dsh_path_pending+=1
			elif dsh_rs=="READY": dsh_path_ready+=1
			elif dsh_rs=="BLOCKED" or dsh_rs=="NO_PATH": dsh_path_blocked+=1
			if dsh_phase=="RESTING":
				var dsh_left: float=float(dsh_life._next_decision)-float(dsh_life._now)
				dsh_rest_left+=dsh_left
				if dsh_left>9.0: dsh_rest_long+=1
			if dsh_phase=="ACTIVITY" and dsh_life._visit!=null:
				var dsh_rel: Variant=dsh_life._visit.get("_released")
				if dsh_rel is bool:
					if not dsh_rel: dsh_act_notreleased+=1
				else: dsh_act_unknown+=1
				if float(dsh_now_ms-int(dsh_life._dsh_phase_since_ms))>60000.0: dsh_act_stuck60+=1
			for dsh_key: Variant in dsh_life._completed:
				dsh_done[str(dsh_key)]=int(dsh_done.get(str(dsh_key),0))+int(dsh_life._completed[dsh_key])
		print("DSH_LIVES f=",frame," n=",_lives.size()," walking=",dsh_walking," activity=",dsh_activity," resting=",dsh_resting," idle=",dsh_idle," other=",dsh_other," walk_blocked=",dsh_walk_blocked," walk_detour=",dsh_walk_detour," walk_complete=",dsh_walk_complete," walk_age_max_s=","%.1f" % dsh_walk_age_max, " walk_req=",dsh_walk_req," walk_planning=",dsh_walk_planning, " walk_walking=",dsh_walk_walking," walk_idle=",dsh_walk_idle," leg_wait=",dsh_leg_wait, " path_pending=",dsh_path_pending," path_ready=",dsh_path_ready, " path_blocked=",dsh_path_blocked, " act_not_released=",dsh_act_notreleased," act_released_unknown=",dsh_act_unknown, " act_stuck60=",dsh_act_stuck60," rest_long=",dsh_rest_long, " rest_left_mean_s=","%.1f" % (dsh_rest_left/maxf(1.0,float(dsh_resting))), " block_reasons=",JSON.stringify(dsh_block_reasons)," completed=",JSON.stringify(dsh_done))
	# DSH_ECON (temporary): a time series proving the personal economy moves.
	if frame%600==0 and not _lives.is_empty():
		var econ_ids: Array=_lives.keys()
		var stride: int=maxi(1,int(econ_ids.size()/3))
		for probe_index in range(mini(3,econ_ids.size())):
			var eid: String=str(econ_ids[mini(probe_index*stride,econ_ids.size()-1)])
			if not _lives.has(eid): continue
			var life_state: Dictionary=_lives[eid].snapshot()
			var account_state: Dictionary=life_state.get("account",{})
			var ledger: Dictionary=account_state.get("account",{})
			print("DSH_ECON f=",frame," id=",eid," phase=",str(life_state.get("phase",""))," goal=",str(life_state.get("goal",{}).get("kind",""))," cash=",int(ledger.get("cash",-1))," bank=",int(ledger.get("bank",-1))," spent=",int(ledger.get("spent",-1))," total=",int(ledger.get("initial_total",-1))," conserved=",bool(account_state.get("conserved",false))," completed=",JSON.stringify(life_state.get("completed",{}))," events=",JSON.stringify(life_state.get("events",[]).slice(0,3)))
	_samples+=1; _total_us+=elapsed
	if elapsed>_max_us: _max_us=elapsed; _max_frame=frame
func snapshot(include_details: bool=false) -> Dictionary:
	var rows:=[]
	for id: String in _lives:
		var life: RefCounted=_lives[id]
		rows.append(life.snapshot() if include_details else {"source_id":id,"phase":life._phase,"reason":life._reason,"kind":life._goal.get("kind",""),"completed":life._completed.duplicate()})
	return {"residents":rows,"failures":_failures.duplicate(true),"scope":"local_daily_services","cost":{"samples":_samples,"total_us":_total_us,"max_us":_max_us,"max_frame":_max_frame},"life_peaks":_life_peaks_snapshot(),"native_movement_tick_added":false}

func dispose() -> void:
	if _disposed: return
	var pending:=false
	for life: RefCounted in _lives.values():
		life.dispose()
		if life._phase!="DISPOSED" and life._phase!="RETIRED": pending=true
	if pending: return
	for account: RefCounted in _accounts.values(): account.dispose()
	_disposed=true; _lives.clear(); _accounts.clear(); _health.clear(); _scene=null

func _retire_scene() -> void:
	# A destroyed scene cannot physically unwind a visit. Its existing host owns
	# body teardown; retire our goals and break factory reference cycles now.
	for life: RefCounted in _lives.values(): life._end_life()
	for account: RefCounted in _accounts.values(): account.dispose()
	_disposed=true; _lives.clear(); _accounts.clear(); _health.clear(); _scene=null
