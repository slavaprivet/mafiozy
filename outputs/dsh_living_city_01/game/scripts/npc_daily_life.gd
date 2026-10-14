extends RefCounted
## One resident's local needs. Concrete visits own arrival and transactions;
## this scheduler never changes HP, cash, transforms, seats or source rows.
const Walk = preload("npc_daily_walk.gd")
const MedMarker = preload("res://scripts/hospital/npc_hospital_marker.gd")
const ResDiag = preload("res://scripts/npc_visual/npc_resident_diag.gd")
const MEDICAL_THRESHOLD := .75
## DSH_MEDPRIORITY: --city-medical-threshold=<0..1> overrides MEDICAL_THRESHOLD. The flag's
## ABSENCE (not its value) is what arms the new read-only telemetry and the hospital room
## marker, so a run without any new argument behaves exactly as before. --city-hp=<0..100>
## is a DEBUG-ONLY second opinion on the row's HP: the source row is never written.
static var _dsh_med_flag: int = -1  # DSH_MEDPRIORITY: -1 unknown, 0 absent, 1 present
static var _dsh_med_threshold: float = MEDICAL_THRESHOLD  # DSH_MEDPRIORITY
static var _dsh_hp_flag: int = -2  # DSH_MEDPRIORITY: -2 unknown, -1 absent, 0..100 override
static var _dsh_med_rings: Array = []  # DSH_MEDPRIORITY: read-only, bounded to 48 rows
var _dsh_moved_m := 0.0  # DSH_MEDPRIORITY: metres actually walked since the first medical goal
var _dsh_moved_last := Vector3.ZERO  # DSH_MEDPRIORITY
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
var _dsh_med_state := ""  # DSH_MEDPRIORITY: the last emitted result for the active goal
var _dsh_med_reported := false  # DSH_MEDPRIORITY: one report per resident process
var _dsh_med_goal_id := ""  # DSH_MEDPRIORITY: the goal_id the last line described
var _dsh_hp_apply_pending := true  # DSH_MEDPRIORITY: --city-hp writes the row once per life
var _energy := 100.0  # DSH_ENERGY: the owner's second bar, set once in _init
var _energy_ready := false  # DSH_ENERGY
var _dsh_energy_last := Vector3.ZERO  # DSH_ENERGY: the body sample of the previous poll
var _dsh_energy_last_ms := 0  # DSH_ENERGY
var _dsh_energy_walked_m := 0.0  # DSH_ENERGY
var _dsh_energy_seen := ""  # DSH_ENERGY: the last emitted (move, whole percent)
var _dsh_energy_last_delta := 0.0  # DSH_ENERGY: metres charged in the last poll
var _dsh_task_queue: Array[String] = []  # DSH_TASKQUEUE
var _dsh_queued_hospital := false  # DSH_TASKQUEUE
var _dsh_queued_restaurant := false  # DSH_TASKQUEUE
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
	ResDiag.register_life(str(token.source_id), self)  # DSH_MEDPRIORITY: the hit-time check
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
	# DSH_ENERGY: --city-energy-start=<0..100> is the debug start of the second bar.
	if not _energy_ready:
		_energy_ready = true
		_energy = _dsh_energy_start()
	return {"ok":true,"source_id":token.source_id,"scope":"new_local_resident_needs"}

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}

# --------------------------------------------------------------------------- #
# DSH_MEDPRIORITY: owner's step 3. --city-medical-threshold=<0..1> (absent = the
# shipped 0.75) makes a resident below that fraction of its max HP take the hospital
# as goal #1 and interrupt the current deed. The comparison is STRICTLY LESS:
#   hp_pct < threshold_pct      (exactly 50.0 % with a 50 % threshold never goes)
# --city-hp=<0..100> is a DEBUG-ONLY second opinion on the row's HP, in PERCENT of
# max_hp (the owner's unit: --city-hp=50 means exactly 50 %, --city-hp=49 means 49 % of
# max_hp). The source row and every other owner keep the authored value; only this
# life's medical decision and its telemetry read the override, which is stated in
# MAFIOZY_MED_PRIORITY.md. All of it is read-only: no body, gait, source row or cash write.
# --------------------------------------------------------------------------- #
## DSH_MEDCHAIN: the owner's scenario, one line per stage. `arrived` is never claimed
## without the body actually standing in the marker; every other stage is a fact the
## shipped visit already published. The door is never opened from here - the copy's own
## owner (npc_city_clone_door_swing.gd) opens it on the resident's proximity.
func _dsh_med_chain(stage: String, row: Dictionary, detail: String = "") -> void:
	if not _dsh_med_on(): return
	var where: Dictionary = MedMarker.current()
	var marker: Variant = where.marker if not where.is_empty() else null
	if stage == "arrived":
		var body: Variant = _token.get("body")
		if not is_instance_valid(body) or not body is Node3D or not marker is Vector3: return
		var here: Vector3 = (body as Node3D).global_position
		var at: Vector3 = marker
		if Vector2(here.x - at.x, here.z - at.z).length() > 2.0: return
	ResDiag.chain(str(_token.get("source_id", "")), stage, row, marker, _token.get("body"), detail, _dsh_hp_pct(row))

## DSH_RESDIAG: one read-only head-up display per resident, from the existing snapshots.
func _dsh_resdiag_step(row: Dictionary) -> void:
	if not ResDiag.diag_on() and not ResDiag.hp_label_on(): return
	var body: Variant = _token.get("body")
	if not is_instance_valid(body) or not body is Node3D: return
	var walk: Dictionary = _walk.snapshot() if _walk != null else {}
	if str(walk.get("reason", "")).length() > 0: ResDiag.count_reason(str(_token.get("source_id", "")), str(walk.reason))
	var marker: Dictionary = MedMarker.current()
	var distance := -1.0
	if not marker.is_empty():
		var at: Vector3 = marker.marker
		var here: Vector3 = (body as Node3D).global_position
		distance = Vector2(here.x - at.x, here.z - at.z).length()
	var name := str((body as Node3D).get_meta("dsh_test_resident_name", str(_token.get("source_id", ""))))
	# DSH_RESBAR: push the vitals into the head label from HERE, where hp and energy are known
	# for certain. Previously only the log line was written, so the owner saw the name alone.
	var dsh_label: Node = (body as Node3D).find_child("DshResidentName", true, false)
	if dsh_label == null:
		var dsh_parent: Node = (body as Node3D).get_parent()
		if dsh_parent != null: dsh_label = dsh_parent.find_child("DshResidentName", true, false)
	if dsh_label is Label3D:
		var dsh_text := "%s\nHP %.0f%%  EN %.0f%%" % [name, clampf(_dsh_hp_pct(row), 0.0, 100.0), clampf(_energy, 0.0, 100.0)]
		if (dsh_label as Label3D).text != dsh_text:
			(dsh_label as Label3D).text = dsh_text
			print("DSH_RESBAR id=", str(_token.get("source_id", "")), " text=\"", dsh_text.replace("\n", " | "), "\"")
	# DSH_RESDIAG: the label shows what the medical decision reads, so with --city-hp the
	# head-up display and the telemetry never disagree about the wound.
	var shown: Dictionary = row.duplicate()
	shown["hp"] = _dsh_effective_hp(row)
	var diag_walk := {
		"leg": int(walk.get("leg", 0)), "legs": int(walk.get("legs", 1)),
		"native_query_wall_us": int(walk.get("native_query_wall_us", 0)),
		"fresh_replans": int(walk.get("fresh_replans", 0)),
		"path_admission": walk.get("path_admission", "-"),
		"admission_wait_s": float(walk.get("initial_path_admission_wait_us", 0)) / 1000000.0,
		"detour_count": int(walk.get("detour", {}).get("count", 0)) if walk.get("detour", {}) is Dictionary else 0,
		"detour_limit": _walk._dsh_detour_per_leg(),
	}
	var life_state := {
		"phase": (_visit.snapshot().get("status", _phase) if _visit != null else _phase),
		"goal_kind": str(_goal.get("kind", "нет")),
		"distance_m": distance,
		"state_seconds": float(Time.get_ticks_msec() - _dsh_phase_since_ms) / 1000.0,
		"energy_on": dsh_energy_on(),
		"energy": _energy,
		"energy_fixed": _dsh_energy_start_fixed,
		"queue": _dsh_task_queue.duplicate(),
	}
	ResDiag.update(str(_token.get("source_id", "")), body, shown, life_state, diag_walk, name)
	# DSH_ENERGY: the same line as a change of the whole percent, so the head-up display
	# has a history even when only --city-resident-diag is on.
	if _dsh_energy_state_changed():
		print("DSH_ENERGY id=", str(_token.get("source_id", "")), " energy=%.0f" % _energy,
			" delta=", "%.1f" % _dsh_energy_last_delta, " walked_m=%.1f" % _dsh_energy_walked_m,
			" goal=", str(_goal.get("kind", "none")), " queue=", str(_dsh_task_queue),
			" threshold=%.3f" % _dsh_energy_threshold(), " frame=", Engine.get_physics_frames())

## DSH_MEDPRIORITY: --city-quit-after=<seconds> ends the process after that much wall
## time. It is a proof-run bound for a headless verification, off by default, and it
## never touches a decision: it only asks the tree to quit.
static var _dsh_quit_flag: int = -1  # DSH_MEDPRIORITY
static var _dsh_quit_started_ms: int = 0  # DSH_MEDPRIORITY

func _dsh_quit_after() -> void:
	if _dsh_quit_flag == -1:
		_dsh_quit_flag = 0
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-quit-after="):
				_dsh_quit_flag = maxi(0, int(argument.trim_prefix("--city-quit-after=")))
		if _dsh_quit_flag > 0: _dsh_quit_started_ms = Time.get_ticks_msec()
	elif _dsh_quit_flag > 0 and Time.get_ticks_msec() - _dsh_quit_started_ms >= _dsh_quit_flag * 1000:
		_dsh_quit_flag = -2
		var body: Variant = _token.get("body")
		if is_instance_valid(body) and body is Node3D and (body as Node3D).is_inside_tree():
			(body as Node3D).get_tree().quit(0)

static func _dsh_med_on() -> bool:
	if _dsh_med_flag < 0:
		_dsh_med_flag = 0
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-medical-threshold="):
				_dsh_med_flag = 1
				_dsh_med_threshold = clampf(float(argument.trim_prefix("--city-medical-threshold=")), 0.0, 1.0)
	return _dsh_med_flag == 1

# --------------------------------------------------------------------------- #
# DSH_ENERGY: the owner's energy bar. Energy is 0..100 %, starts at
# --city-energy-start=<0..100> (default 100) and falls ONLY with the metres the
# resident actually covers, by --city-energy-drain-per-m=<points per metre>.
# Below --city-energy-threshold=<0..1> (default 0.2) the restaurant becomes goal #2.
# DSH_TASKQUEUE: hospital (health) is served before restaurant (energy); the queue
# holds 1-3 tasks and the current goal is the head of it.
#
# Drain table (owner's request):
#   1.0   fast test  - 1 % per metre, 100 % -> 20 % in 80 m (about a minute of walking)
#   0.2   medium     - 100 % -> 20 % in 400 m
#   0.05  game slow  - 1 % per 20 m, the value to switch on later with no code change
#   0     the mechanic is OFF: no drain, no queue, the shipped life runs unchanged
# The sandbox default is 1.0 (fast test); --city-energy-drain-per-m=0 disables it.
# --------------------------------------------------------------------------- #
const ENERGY_DRAIN_DEFAULT := 1.0  # DSH_ENERGY: fast test value, owner's request
## DSH_ENERGY: the fastest a resident may be charged for. The authored gait is <= 1.8 m/s
## and even a feartime run is capped at 1.8/4.1*4.1 = 1.8 m/s by preview_resident_host.gd,
## so anything above this is a placement move, not a step. Measured before the guard: the
## streamed placement of one resident showed up as one 42.3 m jump and drained the whole
## bar in a single line (energy=0 delta=42.3).
const ENERGY_MAX_CHARGE_SPEED := 3.0
static var _dsh_energy_drain_flag: float = -1.0  # DSH_ENERGY
static var _dsh_energy_start_flag: float = -1.0  # DSH_ENERGY
static var _dsh_energy_start_fixed: bool = false  # DSH_ENERGY: --city-energy-start was given
static var _dsh_energy_threshold_flag: float = -1.0  # DSH_ENERGY

static func _dsh_energy_parse() -> void:  # DSH_ENERGY
	if _dsh_energy_drain_flag >= 0.0: return
	_dsh_energy_drain_flag = ENERGY_DRAIN_DEFAULT
	_dsh_energy_start_flag = 100.0
	_dsh_energy_threshold_flag = .2
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--city-energy-drain-per-m="):
			_dsh_energy_drain_flag = maxf(0.0, float(argument.trim_prefix("--city-energy-drain-per-m=")))
		elif argument.begins_with("--city-energy-start="):
			_dsh_energy_start_flag = clampf(float(argument.trim_prefix("--city-energy-start=")), 0.0, 100.0)
			_dsh_energy_start_fixed = true
		elif argument.begins_with("--city-energy-threshold="):
			_dsh_energy_threshold_flag = clampf(float(argument.trim_prefix("--city-energy-threshold=")), 0.0, 1.0)

static func _dsh_energy_drain_per_m() -> float:  # DSH_ENERGY
	_dsh_energy_parse()
	return _dsh_energy_drain_flag

static func _dsh_energy_threshold() -> float:  # DSH_ENERGY
	_dsh_energy_parse()
	return _dsh_energy_threshold_flag

static func _dsh_energy_start() -> float:  # DSH_ENERGY
	_dsh_energy_parse()
	return _dsh_energy_start_flag

func dsh_energy_on() -> bool:  # DSH_ENERGY
	return _dsh_energy_drain_per_m() > 0.0

func dsh_energy() -> float:  # DSH_ENERGY
	return _energy

## DSH_ENERGY: the metres this resident really covered since the previous poll, read from
## the body the shipped host moves. It never moves anything itself.
func _dsh_energy_drain() -> void:
	var body: Variant = _token.get("body")
	if not is_instance_valid(body) or not body is Node3D: return
	if not dsh_energy_on():
		# DSH_MEDPRIORITY: the medical line still reports how far the resident actually
		# walked, even when the energy mechanic is off.
		var where: Vector3 = (body as Node3D).global_position
		if _dsh_moved_last.is_finite():
			var travelled: float = Vector2(where.x - _dsh_moved_last.x, where.z - _dsh_moved_last.z).length()
			if travelled > 0.0 and travelled <= 3.0: _dsh_moved_m += travelled
		_dsh_moved_last = where
		return
	var here: Vector3 = (body as Node3D).global_position
	if not _dsh_energy_last.is_finite():
		_dsh_energy_last = here
		_dsh_energy_last_ms = Time.get_ticks_msec()
		return
	var step_m: float = Vector2(here.x - _dsh_energy_last.x, here.z - _dsh_energy_last.z).length()
	_dsh_energy_last = here
	if step_m <= 0.0: return
	var now_ms: int = Time.get_ticks_msec()
	# A poll covers ~1.6 s of real time in the city; a single jump longer than 10 s is a
	# load hitch, never a walk, so it is not charged as distance.
	if _dsh_energy_last_ms > 0 and now_ms - _dsh_energy_last_ms > 10000:
		_dsh_energy_last_ms = now_ms
		return
	# DSH_ENERGY: only a plausible step is charged. A teleport-sized move (streamed
	# placement, a host relocation) is a real displacement of the body but never walking,
	# and charging it would empty the bar in one line.
	var elapsed_s: float = float(now_ms - _dsh_energy_last_ms) / 1000.0 if _dsh_energy_last_ms > 0 else 0.05
	var bound_m: float = maxf(.05, elapsed_s) * ENERGY_MAX_CHARGE_SPEED
	_dsh_energy_last_ms = now_ms
	if step_m > bound_m: return
	var before: float = _energy
	_energy = clampf(_energy - step_m * _dsh_energy_drain_per_m(), 0.0, 100.0)
	_dsh_energy_walked_m += step_m
	_dsh_moved_m += step_m  # DSH_MEDPRIORITY: the same travelled metres, for the medical line
	_dsh_energy_last_delta = step_m
	if int(before) != int(_energy):
		_dsh_energy_emit("drained", "%.1f" % step_m)

## DSH_ENERGY: one line when the whole percent changes, so a long walk is a few lines and
## not one per frame.
func _dsh_energy_emit(move: String, delta: String = "-") -> void:  # DSH_ENERGY
	if not dsh_energy_on(): return
	var key := move + ":" + str(int(_energy))
	if key == _dsh_energy_seen: return
	_dsh_energy_seen = key
	print("DSH_ENERGY id=", str(_token.get("source_id", "")), " energy=%.0f" % _energy,
		" delta=", delta, " walked_m=%.1f" % _dsh_energy_walked_m,
		" goal=", str(_goal.get("kind", "none")), " queue=", str(_dsh_task_queue),
		" threshold=%.3f" % _dsh_energy_threshold(), " frame=", Engine.get_physics_frames())

## DSH_ENERGY: the same state key as `_dsh_energy_emit`, so the diagnostic mirror (needed
## when only --city-resident-diag is on) never disagrees with it.
func _dsh_energy_state_changed() -> bool:  # DSH_ENERGY
	if not dsh_energy_on(): return false
	var key := "drained:" + str(int(_energy))
	if key == _dsh_energy_seen: return false
	_dsh_energy_seen = key
	return true

## DSH_TASKQUEUE: the owner's ordering. Hospital is health and outranks the restaurant;
## a task already in the queue is never pushed twice.
func _dsh_queue_push(task: String) -> void:  # DSH_TASKQUEUE
	if _dsh_task_queue.has(task): return
	if _dsh_task_queue.size() >= 3: return
	_dsh_task_queue.append(task)
	print("DSH_TASKQUEUE id=", str(_token.get("source_id", "")), " push=", task,
		" pop=-", " current=", str(_goal.get("kind", "none")), " queue=", str(_dsh_task_queue),
		" frame=", Engine.get_physics_frames())

func _dsh_queue_pop_front() -> String:  # DSH_TASKQUEUE
	if _dsh_task_queue.is_empty(): return ""
	var task: String = str(_dsh_task_queue.pop_front())
	print("DSH_TASKQUEUE id=", str(_token.get("source_id", "")), " push=-", " pop=", task,
		" current=", task, " queue=", str(_dsh_task_queue), " frame=", Engine.get_physics_frames())
	return task

func _queue_has(task: String) -> bool:  # DSH_TASKQUEUE
	return _dsh_task_queue.has(task)

## DSH_TASKQUEUE: a served task leaves the queue and does not come back until its own
## condition appears again, so neither goal re-arms itself on every decision.
func _mark_served(task: String) -> void:  # DSH_TASKQUEUE
	match task:
		"hospital": _dsh_queued_hospital = true
		"restaurant": _dsh_queued_restaurant = true

## DSH_TASKQUEUE: the same condition returning after a served task frees that task again.
func _release_served(task: String) -> void:  # DSH_TASKQUEUE
	match task:
		"hospital": _dsh_queued_hospital = false
		"restaurant": _dsh_queued_restaurant = false

## DSH_ENERGY: after a goal ends, a condition that is still true re-arms its task, so a
## resident that is still hungry (or still hurt) keeps its place in the queue. The energy
## side only re-arms when the state already dropped out of "low" once, which is exactly
## what `_release_served` records.
func _dsh_rearm_energy_queue(row: Dictionary) -> void:  # DSH_ENERGY
	if _energy < _dsh_energy_threshold() * 100.0 and not _dsh_queued_restaurant: _dsh_queue_push("restaurant")
	if _needs_hospital(row) and not _dsh_queued_hospital: _dsh_queue_push("hospital")


func _dsh_energy_queue() -> void:  # DSH_ENERGY
	var low: bool = _energy < _dsh_energy_threshold() * 100.0
	if low:
		if _dsh_queued_restaurant: return
		_dsh_queue_push("restaurant")
		_dsh_energy_emit("low")
	else:
		if _dsh_queued_restaurant: _release_served("restaurant")

func _dsh_threshold() -> float:  # DSH_MEDPRIORITY
	_dsh_med_on()
	return _dsh_med_threshold

func _dsh_hp_override() -> float:  # DSH_MEDPRIORITY
	if _dsh_hp_flag == -2:
		_dsh_hp_flag = -1
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-hp="):
				_dsh_hp_flag = clampi(int(round(float(argument.trim_prefix("--city-hp=")))), 0, 100)
	return float(_dsh_hp_flag)

## The row's HP as this life's medical decision reads it, in ABSOLUTE hit points. The
## --city-hp percent is scaled by this row's own max_hp, so 50 means exactly half of the
## resident's own bar.
##
## DSH_MEDPRIORITY (debug seam, measured): the shipped hospital visit refuses an errand
## while `_health._row.hp >= _health._row.max_hp` (npc_daily_hospital_visit.gd:190), so a
## decision-only override left every injured-but-untouched resident unable to walk at all
## (measured: 907 lines `hospital_begin_refused:no_treatment_needed`). The override
## therefore writes the SAME debug value into the health owner's own row - exactly what a
## real shot does through npc_ordinary_hit_lifecycle.gd:140 - once per life generation,
## only when --city-hp is present, and only downwards. Telemetry carries
## `hp_applied_to_row=true` so the owner can see when the seam acted.
func _dsh_effective_hp(row: Dictionary) -> float:  # DSH_MEDPRIORITY
	var maximum: float = float(row.get("max_hp", 0))
	var override_pct: float = _dsh_hp_override()
	if override_pct < 0.0: return clampf(float(row.get("hp", 0)), 0.0, maxf(0.0, maximum))
	if maximum <= 0.0: return clampf(override_pct, 0.0, 100.0)
	var applied: float = clampf(override_pct / 100.0 * maximum, 0.0, maximum)
	if _dsh_hp_apply_pending and not row.get("dead", false) and applied < float(row.get("hp", 0)):
		row.hp = applied
		_dsh_hp_apply_pending = false
	return applied

func _dsh_hp_pct(row: Dictionary) -> float:  # DSH_MEDPRIORITY
	var maximum: float = float(row.get("max_hp", 0))
	if maximum <= 0.0: return -1.0
	return _dsh_effective_hp(row) / maximum * 100.0

## DSH_MEDPRIORITY: the one line per change of state. `result` is goal_set when the
## goal is taken, arrived when the resident physically reached the marker, blocked when
## the errand ended without arrival, no_goal when the strict threshold was not crossed.
func _dsh_med_emit(result: String, row: Dictionary, reason: String = "") -> void:  # DSH_MEDPRIORITY
	if not _dsh_med_on(): return
	# DSH_MEDPRIORITY: one line per state, and `goal_set`/`no_goal` are keyed by the goal
	# they describe. Without the key a repeated `_start` of the same goal (measured: 40
	# `goal_set` lines for 8 residents in 70 s, because the hospital lease frees the task
	# again while HP is still below the threshold) would print identical lines.
	var state := result
	if result == "goal_set" or result == "arrived": state = result + "|" + str(_goal.get("goal_id", ""))
	if state == _dsh_med_state: return
	_dsh_med_state = state
	var goal_kind: String = str(_goal.get("kind", "-"))
	var marker_text := "-"
	var distance: float = -1.0
	var where: Dictionary = MedMarker.current()
	var body: Variant = _token.get("body")
	if not where.is_empty():
		var at: Vector3 = where.marker
		marker_text = "(%.2f,%.2f,%.2f)" % [at.x, at.y, at.z]
		if is_instance_valid(body) and body is Node3D:
			var here: Vector3 = (body as Node3D).global_position
			distance = Vector2(here.x - at.x, here.z - at.z).length()
	var line := "DSH_MEDPRIORITY id=" + str(_token.get("source_id", "")) \
		+ " hp=" + str(int(round(_dsh_effective_hp(row)))) + "/" + str(int(row.get("max_hp", -1))) \
		+ " hp_pct=%.1f" % _dsh_hp_pct(row) + " threshold=%.3f" % _dsh_threshold() \
		+ " threshold_pct=%.1f" % (_dsh_threshold() * 100.0) + " strict_lt=true" \
		+ " goal=" + goal_kind + " marker=" + marker_text \
		+ " dist_m=%.1f" % distance + " moved_m=%.1f" % _dsh_moved_m \
		+ " hp_applied_to_row=" + ("true" if _dsh_hp_override() >= 0.0 else "false") \
		+ " result=" + result
	if not reason.is_empty(): line += " reason=" + reason
	print(line)
	if _dsh_med_rings.size() >= 48: _dsh_med_rings.pop_front()
	_dsh_med_rings.append(line)

## DSH_MEDPRIORITY: called only from paths a --city-medical-threshold run already takes.
func _dsh_med_flush() -> void:  # DSH_MEDPRIORITY
	if not _dsh_med_on(): return
	var row: Dictionary = _life()
	if row.is_empty() or row.get("dead", false) or float(row.get("hp", 0)) <= 0: return
	if str(_goal.get("kind", "")) != "hospital":
		_dsh_med_state = ""
		_dsh_med_goal_id = ""
		return
	var goal_id: String = str(_goal.get("goal_id", ""))
	if goal_id != _dsh_med_goal_id:
		_dsh_med_goal_id = goal_id
		_dsh_med_state = ""
	if _visit != null: return
	if _phase == "WALKING":
		if not _dsh_med_reported:
			_dsh_med_reported = true
			var admission: Dictionary = MedMarker.admission(_policy, str(_token.get("source_id", "")), int(_token.get("life_generation", -1)))
			_dsh_med_emit("goal_set", row, "marker_admit=" + str(admission.get("admitted", false)) + ":" + str(admission.get("reason", "")))
		return
	if _phase in ["IDLE", "RESTING", "WAITING_FOR_RECOVERY"] and _dsh_med_reported:
		_dsh_med_emit("blocked", row, _reason if not _reason.is_empty() else "goal_without_walk")

## DSH_MEDPRIORITY: the visible hospital room marker is resolved once per process, on the
## frames this life would already occupy, and only under the new flag.
func _dsh_life_scene() -> Node3D:  # DSH_MEDPRIORITY
	if is_instance_valid(_policy):
		for key: String in ["_scene", "_scene_owner"]:
			var bound: Variant = _policy.get(key)
			if bound is WeakRef:
				var target: Variant = (bound as WeakRef).get_ref()
				if target is Node3D: return target as Node3D
			elif bound is Node3D: return bound as Node3D
	var body: Variant = _token.get("body")
	if is_instance_valid(body) and body is Node3D:
		var node: Node3D = body as Node3D
		var scene: Node = node.owner
		if scene == null and node.is_inside_tree(): scene = node.get_tree().current_scene
		if scene == null and node.is_inside_tree(): scene = node.get_tree().root
		if scene is Node3D: return scene as Node3D
	return null

func _dsh_marker_ready() -> bool:  # DSH_MEDPRIORITY
	if not _dsh_med_on(): return false
	if not MedMarker.current().is_empty(): return true
	var scene: Node3D = _dsh_life_scene()
	if not is_instance_valid(scene): return false
	MedMarker.resolve(scene)
	if not MedMarker.current().is_empty():
		MedMarker.install_visual()
		return true
	return false

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
		elif _dsh_med_on() and str(_goal.get("kind",""))=="hospital":  # DSH_MEDPRIORITY
			var door_fraction: float = float(state.get("door_fraction", 0.0))
			var stage: String = ResDiag.visit_stage(status, bool(state.get("door_owned", false)), door_fraction)
			if not stage.is_empty(): _dsh_med_chain(stage, row, "visit_status=" + status + " door_fraction=%.2f" % door_fraction)
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
	_dsh_energy_drain()  # DSH_ENERGY: spent by the metres the shipped host really moved
	_dsh_resdiag_step(row)  # DSH_RESDIAG: the head-up display of the owner's test resident
	_dsh_quit_after()  # DSH_MEDPRIORITY: --city-quit-after=<s> bounds a short proof run
	if _phase in ["IDLE","RESTING","WAITING_FOR_RECOVERY"] and _now>=_next_decision: _choose(row)
	# DSH_ENERGY / DSH_TASKQUEUE: if the condition that produced the goal is still true after
	# the goal ended, the task goes back into the queue and is taken on the next decision.
	if dsh_energy_on() and _phase in ["IDLE","RESTING"]: _dsh_rearm_energy_queue(row)
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
	if _now<_next_medical or float(row.get("max_hp",0))<=0 or row.get("_medicalDowned",false) or row.get("_forcedCrawl",false): return false
	# DSH_MEDPRIORITY: STRICTLY LESS (owner's rule: exactly 50 % with a 50 % threshold
	# never goes to hospital). Without the flag both sides are the shipped expression.
	if _dsh_med_on():
		return _dsh_effective_hp(row) < float(row.max_hp)*_dsh_threshold()
	return float(row.get("hp",0))<float(row.max_hp)*MEDICAL_THRESHOLD

func _new_goal(kind: String) -> Dictionary:
	_sequence+=1
	return {"goal_id":str(_token.source_id)+":daily:"+str(_sequence),"kind":kind}

## DSH_MEDPRIORITY: the owner's "damage must land immediately" seam. The hit owner calls
## this from the very call that applied the damage, so the medical priority is decided in
## the same frame instead of waiting for this resident's turn in the daily poll slice
## (measured period ~1.6 s). It decides exactly what `_choose` decides and never reads a
## clock, invents damage or moves anything.
func dsh_notice_damage() -> Dictionary:
	if _disposed or _busy or not Thread.is_main_thread(): return {"ok":false,"reason":"life_busy_or_disposed"}
	if not _dsh_med_on() or not _host.target_current(_token): return {"ok":false,"reason":"not_current"}
	var row: Dictionary = _life()
	if row.is_empty() or row.get("dead", false) or float(row.get("hp", 0)) <= 0: return {"ok":false,"reason":"life_not_living"}
	if str(_goal.get("kind", "")) == "hospital" or _visit != null: return {"ok":true,"reason":"already_serving_health"}
	if not _needs_hospital(row): return {"ok":true,"reason":"threshold_not_crossed"}
	_dsh_marker_ready()
	_dsh_med_chain("damaged", row, "hp_strictly_below_threshold_from_hit")
	_dsh_queue_push("hospital")
	var task: String = _dsh_queue_pop_front()
	_mark_served(task)
	_start(_new_goal(task), task == "hospital")
	return {"ok":true,"reason":"medical_priority_from_hit","goal":task}

func _choose(row: Dictionary) -> void:
	_dsh_decisions+=1  # DSH_LIFETRACE
	# DSH_ENERGY / DSH_TASKQUEUE: the owner's ordering. Health outranks energy: a resident
	# below both thresholds gets hospital first and restaurant next, and neither goal
	# overwrites the other - they wait in the queue. A resident in neither condition keeps
	# exactly the shipped life below.
	# DSH_TASKQUEUE: the owner's order is health before energy. Health is therefore asked
	# FIRST and only then does the energy side put its task in, so a resident in both
	# states always ends up with ["hospital","restaurant"].
	if _needs_hospital(row):
		_dsh_marker_ready()  # DSH_MEDPRIORITY: resolve and place the visible room marker
		if _dsh_med_on(): _dsh_med_chain("damaged", row, "hp_strictly_below_threshold")  # DSH_MEDCHAIN
		_dsh_queue_push("hospital")  # DSH_TASKQUEUE: health first, always
	elif _dsh_queued_hospital:
		_release_served("hospital")  # DSH_TASKQUEUE: the condition ended, the task is free again
	if dsh_energy_on():
		_dsh_energy_queue()  # DSH_ENERGY
		if _dsh_task_queue.has("hospital") and _dsh_task_queue.find("hospital") > 0:
			_dsh_task_queue.erase("hospital")
			_dsh_task_queue.push_front("hospital")
			print("DSH_TASKQUEUE id=", str(_token.get("source_id", "")), " push=-", " pop=-",
				" current=hospital", " queue=", str(_dsh_task_queue),
				" frame=", Engine.get_physics_frames(), " reorder=hospital_first")
	if _queue_has("hospital"):
		var hospital_task: String = _dsh_queue_pop_front()
		_mark_served(hospital_task)
		_start(_new_goal(hospital_task), true); return
	if _queue_has("restaurant"):
		var meal_task: String = _dsh_queue_pop_front()
		_mark_served(meal_task)
		if _dsh_med_on(): _dsh_med_chain("goal_set", row, "restaurant_from_queue")
		_start(_new_goal(meal_task)); return
	# DSH_MEDPRIORITY: the owner's 50 %-exactly case. This line is printed only when the
	# new threshold flag is present, and only on a change of the resident's HP state.
	if _dsh_med_on():
		if MedMarker.current().is_empty(): _dsh_marker_ready()
		if _dsh_effective_hp(row) < float(row.get("max_hp",0))*_dsh_threshold():
			_dsh_med_emit("blocked", row, "medical_priority_admission_refused")
			_dsh_med_chain("blocked:goal_not_owned", row, "medical_priority_admission_refused")
		else:
			_dsh_med_emit("no_goal", row, "hp_not_strictly_below_threshold")
			_dsh_med_chain("no_goal", row, "hp_not_strictly_below_threshold")
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

func _start(goal: Dictionary, med_priority: bool=false) -> void:
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
	if med_priority:  # DSH_MEDPRIORITY: the goal is set and owned before admission is polled
		var med_row: Dictionary=_life()
		if not med_row.is_empty():
			var admission: Dictionary=MedMarker.admission(_policy,str(_token.get("source_id","")),int(_token.get("life_generation",-1)))
			# DSH_MEDPRIORITY: the state key is NOT pre-set here - `_dsh_med_emit` owns it,
			# and pre-setting it silently suppressed the goal_set line.
			_dsh_med_goal_id=str(goal.get("goal_id","")); _dsh_med_reported=true
			_dsh_med_emit("goal_set",med_row,"marker_admit="+str(admission.get("admitted",false))+":"+str(admission.get("reason","")))
	profile_started=Time.get_ticks_usec()
	var begun: Variant=_visit.begin()
	_profile("begin",profile_started)
	if not begun is Dictionary or not begun.get("ok",false):
		_visit.cancel("begin_refused")
		# Even failed admission may own a lease which needs normal cleanup ticks.
		_phase="ACTIVITY"; _interrupting=true; _reason=str(begun.get("reason","begin_refused")) if begun is Dictionary else "begin_result"
		if med_priority:  # DSH_MEDPRIORITY: the hospital controller refused the errand itself
			var refused_row: Dictionary=_life()
			if not refused_row.is_empty(): _dsh_med_emit("blocked",refused_row,"hospital_begin_refused:"+_reason)
		return
	_phase="ACTIVITY"; _reason=""; _record("started")
	# DSH_MEDCHAIN: the goal is owned and the visit has accepted the errand.
	if med_priority and _dsh_med_on():
		var chain_row: Dictionary=_life()
		if not chain_row.is_empty(): _dsh_med_chain("goal_set", chain_row, "visit="+str(_visit.snapshot().get("status","-")))
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
	if _dsh_med_on() and kind=="hospital": _dsh_med_arrival_check()  # DSH_MEDPRIORITY
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
	_dsh_med_flush()  # DSH_MEDPRIORITY: the hospital errand's terminal line

## DSH_MEDPRIORITY: one line when the resident has physically arrived at the marker. The
## marker is the goal; the shipped hospital visit only ever walks to the real hospital's
## route-data handoff, so a resident that never entered the clone is reported as blocked by
## that visit's own reason instead of being called an arrival.
func _dsh_med_arrival_check() -> void:
	var row: Dictionary=_life()
	if row.is_empty(): return
	var where: Dictionary=MedMarker.current()
	if where.is_empty(): return
	var body: Variant=_token.get("body")
	if not is_instance_valid(body) or not body is Node3D: return
	var here: Vector3=(body as Node3D).global_position
	var at: Vector3=where.marker
	var distance: float=Vector2(here.x-at.x,here.z-at.z).length()
	if distance<=2.0:
		_dsh_med_emit("arrived",row,"within_2m_of_marker")
		_dsh_med_chain("arrived",row,"body_within_2m_of_marker")
	else:
		_dsh_med_emit("blocked",row,"hospital_visit_ended_at_dist_%.1f_m_outside_marker" % distance)
		_dsh_med_chain("blocked:visit_ended_outside_marker",row,"dist_m=%.1f" % distance)

func _retry(reason: String) -> void:
	_reason=reason; _record("retry",reason)
	_dsh_retries+=1  # DSH_LIFETRACE
	match str(_goal.get("kind","")):
		"hospital": _next_medical=_now+10000.0
		"bank": _next_bank=_now+30000.0
		"shop": _next_shop=_now+15000.0
	_phase="IDLE"; _next_decision=_now+1500.0; _goal={}
	_dsh_med_flush()  # DSH_MEDPRIORITY: the hospital goal was cleared above

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
