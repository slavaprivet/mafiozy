extends RefCounted
const Routine58 = preload("res://scripts/city/runtime/npc_routine58.gd")
const Leisure58 = preload("res://scripts/city/runtime/npc_leisure58.gd")
const PreparedRoutes = preload("res://scripts/navigation/prepared_routes58.gd")
var _routine58: RefCounted
var _leisure58: RefCounted
var _leisure_arrived58 := false
# DSH_ONEGOAL58: places this resident already refused for the current decision, so a
# refusal is answered by CHOOSING ANOTHER AVAILABLE PLACE, never by standing still.
var _leisure58_avoid: Array = []
const LEISURE58_ATTEMPTS := 3
# DSH_ONEGOAL58: deeds whose place and seat were prepared before they were needed.
var _dsh_prefetched58 := 0
# DSH_RESERVE58: why a claimed bench seat was given up, for diagnosis of a lost walk.
var _leisure58_release_reason := ""
var _home58: RefCounted
var _home_intent58 := ""
var _rest_driver58: RefCounted
var _home_retry58 := 0.0
## DSH_ROUTINE_ROAM58 (proposal routine_stall58, OFF by default): release57 answered
## "no supported activity" in its simple path with _roam51_begin() (a real 5-15 m leg) and
## in its shipped path with _roam(). v58 replaced both with logical intents and left a
## plain RESTING stop, so the city stands still whenever no bench is free or the route
## planner refuses. This flag only restores that one decision; intents/owners unchanged.
var _dsh_roam58_flag := -1
func dsh_roam58_on() -> bool:  # DSH_ROUTINE_ROAM58
	if _dsh_roam58_flag < 0: _dsh_roam58_flag = 1 if OS.get_cmdline_user_args().has("--city-routine-roam58=1") else 0
	return _dsh_roam58_flag == 1
const ThreatLife30 = preload("res://scripts/city/runtime/npc_threat_life30.gd")
var _threat30: RefCounted
## One resident's local needs. Concrete visits own arrival and transactions;
## The opt-in hospital51 policy commits local HP through the current hit lifecycle;
## it never modifies imported source-save rows, cash, transforms or seats.
const Walk = preload("npc_daily_walk.gd")
const MedMarker = preload("res://scripts/hospital/npc_hospital_marker.gd")
const SimpleHospital = preload("res://scripts/hospital/npc_simple_hospital.gd")  # DSH_SIMPLEHOSP
const Restaurant28 = preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const Ambient29 = preload("res://scripts/npc_ambient/ambient_controller28.gd")
var _ambient29: RefCounted
const Economy28 = preload("res://scripts/shop/npc_economy_visit28.gd")
const PhysicalRoute51 = preload("res://scripts/hospital/npc_physical_route51.gd")
const Attention29 = preload("res://scripts/npc_visual/npc_attention29.gd")
var _attention29: RefCounted = Attention29.new()
const ResDiag = preload("res://scripts/npc_visual/npc_resident_diag.gd")
const NeedsCatalog = preload("res://scripts/npc_needs_catalog.gd")  # DSH_CATALOG
const MEDICAL_THRESHOLD := .5
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
# DSH_ONEGOAL58: the ordinary walk of a resident is the shipped `_walk` route to a place
# that was resolved to a supported standing point first. The old DSH_WANDER reporter, its
# random-target state and its telemetry were REMOVED from the active build instead of being
# kept behind a flag: one owner, one goal, one route, one state.
# DSH_DEATH: residents whose life ended with hp 0. A new life for that id reports the respawn
# and starts from an empty task set, so no goal, queue mark or hold survives the death.
static var _dsh_dead: Dictionary = {}  # DSH_DEATH
# DSH_CATALOG: the nearest site of the current goal's kind (the owner's district rule) and the
# kind it was chosen for. Read-only: telemetry plus the goal's own point.
var _dsh_site_choice: Dictionary = {}  # DSH_CATALOG
var _dsh_site_kind := ""  # DSH_CATALOG
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
# DSH_ONEGOAL58: the clock of the last place/need decision, see dsh_daily_decision_due().
var _last_decision_ms := -1.0e12
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
## DSH_SIMPLEHOSP: --city-simple-hospital=1. The owner's test stand - the hospital IS the
## palazzo copy and the resident walks straight to its measured centre, with no
## source_admit and no support_height proof. One owner per life, created on the first
## hospital goal; the walk itself lives in scripts/hospital/npc_simple_hospital.gd.
var _dsh_simple: RefCounted = null  # DSH_SIMPLEHOSP
# Native hospital51: a visit completes only after inside treatment AND outside arrival.
var _hospital_stage := ""
var _hospital_outside := Vector3.INF
var _hospital_treat_started := -1.0
var _hospital_treat_last := -1.0
var _hospital_treat_revision := -1
var _hospital_treat_hp := -1.0
var _hospital_treat_anchor := Vector3.INF
var _hospital_healed := false
var _hospital_exit_retry_at := 0.0
var _hospital_support51: RefCounted = null
var _roam51: RefCounted = null
var _roam51_active := false
var _restaurant28: RefCounted = null
var _restaurant28_stage := ""
var _restaurant28_meal_started := -1.0
var _restaurant28_meal_last := -1.0
var _restaurant28_meal_anchor := Vector3.INF
var _restaurant28_meal_revision := -1
var _restaurant28_meal_hp := -1.0
var _restaurant28_fed := false
var _restaurant28_medical := false
var _restaurant28_exit_retry_at := 0.0
var _restaurant28_retry_at := 0.0
var _restaurant28_receipt: Dictionary = {}
var _economy28: RefCounted = null
var _economy28_config_retry := 0.0
var _sandbox28_action := "walk"
## User clarification: restaurant wait is approximately two seconds.
const RESTAURANT28_MEAL_MS := 2000.0
const HOSPITAL51_TREAT_MS := 1500.0
## DSH_SIMPLEHOSP: the rest after one copy errand (arrival or exhausted attempts) before
## the still-low HP re-arms it. The task is never marked "served".
const DSH_SIMPLE_REARM_MS := 8000.0  # DSH_SIMPLEHOSP
var _energy := 100.0  # DSH_ENERGY: the owner's second bar, set once in _init
var _energy_ready := false  # DSH_ENERGY
var _dsh_energy_last := Vector3.INF  # First observation initializes; spawning is not walking.
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
var _completed := {"hospital":0,"restaurant":0,"bank":0,"shop":0,"drive":0,"walk":0}
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
	# DSH_DEATH: a new life of a resident that died starts clean and says so. Nothing from
	# the previous route is carried in (the queue, the goal and the walk belong to the life
	# that ended), and the mark is consumed exactly once.
	if _dsh_dead.has(str(token.source_id)) or int(token.get("life_generation", 1)) > 1:
		# Debug injuries/hunger are startup seams, never a respawn policy.
		_energy = 100.0; _dsh_hp_apply_pending = false
		_dsh_dead.erase(str(token.source_id))
		print("DSH_RESPAWN id=", str(token.source_id), " cleared_tasks=true goals=", str(_dsh_task_queue),
			" energy=%.0f" % _energy, " frame=", Engine.get_physics_frames())
	if _dsh_simple_on():
		_routine58 = Routine58.new(); _routine58.configure(str(token.source_id))
		_economy28_prepare()
		_next_decision = _now + _sandbox28_random() * 4000.0
	return {"ok":true,"source_id":token.source_id,"scope":"new_local_resident_needs"}

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}

# --------------------------------------------------------------------------- #
# DSH_MEDPRIORITY: owner's step 3. --city-medical-threshold=<0..1> (absent = the
# shipped 0.75) makes a resident below that fraction of its max HP take the hospital
# as goal #1 and interrupt the current deed. The comparison is STRICTLY LESS:
#   hp_pct <= threshold_pct     (50.0 % is included by the user rule)
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
	ResDiag.chain(str(_token.get("source_id", "")), stage, row, marker, _token.get("body"),
		detail + " " + NeedsCatalog.site_telemetry(_dsh_site_choice), _dsh_hp_pct(row))

## DSH_CATALOG: the owner's district rule - among every known site of this kind take the
## NEAREST to the resident (inside DISTRICТ_RADIUS_M when one is that close, otherwise the
## nearest overall). One line per change of the chosen site, so a log shows that a near site
## was picked and not one across the city.
func _dsh_site_pick(kind: String) -> Dictionary:  # DSH_CATALOG
	if kind.is_empty(): return {}
	var body: Variant = _token.get("body")
	if not is_instance_valid(body) or not body is Node3D: return _dsh_site_choice
	var scene: Node3D = _dsh_life_scene()
	if not is_instance_valid(scene): return _dsh_site_choice
	NeedsCatalog.scan(scene)
	var here: Vector3 = (body as Node3D).global_position
	var choice: Dictionary = NeedsCatalog.nearest(kind, here)
	if not bool(choice.get("ok", false)): return choice
	var changed: bool = kind != _dsh_site_kind or str(choice.get("site_id", "")) != str(_dsh_site_choice.get("site_id", ""))
	_dsh_site_kind = kind
	_dsh_site_choice = choice
	if changed:
		print("DSH_SITE id=", str(_token.get("source_id", "")), " kind=", kind,
			" ", NeedsCatalog.site_telemetry(choice),
			" body=(", "%.1f" % here.x, ",", "%.1f" % here.z, ")",
			" radius_m=%.0f" % NeedsCatalog.DISTRICT_RADIUS_M,
			" frame=", Engine.get_physics_frames())
	return choice

## DSH_RESDIAG: the per-frame repaint of one resident's caption. The city steps the hit
## owner every physics frame, while this life is only polled on its turn in the daily slice
## (measured period ~1.6 s), so the owner's display is painted from that every-frame hook -
## with no throttle of any kind in between - as well as from the hit itself.
func dsh_repaint_caption() -> void:
	if _disposed or _walk == null: return
	if ResDiag.simple_vitals_on() and not ResDiag.diag_on():
		ResDiag.repaint_focus30(_token.get("body")); return
	if not ResDiag.hp_label_on() and not ResDiag.diag_on(): return
	var row: Dictionary = _life()
	if row.is_empty(): return
	_dsh_resdiag_step(row)

## DSH_RESDIAG: one read-only head-up display per resident, from the existing snapshots.
func _dsh_resdiag_step(row: Dictionary) -> void:
	if not ResDiag.diag_on() and not ResDiag.hp_label_on(): return
	if ResDiag.simple_vitals_on() and not ResDiag.diag_on():
		ResDiag.repaint_focus30(_token.get("body")); return
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
	var name := "Житель" if _dsh_simple_on() else str((body as Node3D).get_meta("dsh_test_resident_name", str(_token.get("source_id", ""))))
	# The simple resident uses only ResDiag's current-health writer. Keep the older
	# direct caption path isolated for runs that do not request this local scenario.
	if not _dsh_simple_on():
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
	if SimpleHospital.enabled(): return .2
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
## The queue entry is dropped too, so a condition that ended can never leave a stale head
## that would send the resident to a place it no longer needs.
func _release_served(task: String) -> void:  # DSH_TASKQUEUE
	match task:
		"hospital": _dsh_queued_hospital = false
		"restaurant": _dsh_queued_restaurant = false
	_dsh_task_queue.erase(task)

## DSH_ENERGY: after a goal ends, a condition that is still true re-arms its task, so a
## resident that is still hungry (or still hurt) keeps its place in the queue. The energy
## side only re-arms when the state already dropped out of "low" once, which is exactly
## what `_release_served` records.
func _dsh_rearm_energy_queue(row: Dictionary) -> void:  # DSH_ENERGY
	if _energy < _dsh_energy_threshold() * 100.0 and not _dsh_queued_restaurant: _dsh_queue_push("restaurant")
	# DSH_SIMPLEHOSP: with the direct copy errand the hospital task never enters the
	# queue, so the queue must not re-arm it here either.
	if _needs_hospital(row) and not _dsh_queued_hospital and not _dsh_simple_on(): _dsh_queue_push("hospital")


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
	if _dsh_simple_on():
		if _dsh_hp_apply_pending:
			_dsh_hp_apply_pending = false
			if not row.get("dead", false) and applied < float(row.get("hp", 0)): row.hp = applied
		return clampf(float(row.get("hp", 0)), 0.0, maximum)
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
## the errand ended without arrival, no_goal when HP remained above the threshold.
func _dsh_med_emit(result: String, row: Dictionary, reason: String = "") -> void:  # DSH_MEDPRIORITY
	if not _dsh_med_on(): return
	# DSH_ROWPROBE: the identity of the ROW this decision reads, next to the one the hit
	# stamped. Equal row_hash + a visible _dsh_hit_hp proves both sides share one Dictionary;
	# a different hash or a missing stamp is the split the owner is looking for.
	print("DSH_ROWPROBE site=life id=", str(_token.get("source_id", "")), " row_hash=", row.hash(),
		" health_id=", (_health.get_instance_id() if is_instance_valid(_health) else -1),
		" hp=", "%.0f" % clampf(float(row.get("hp", 0)), 0.0, 100.0),
		" stamp_frame=", str(row.get("_dsh_hit_frame", "none")),
		" stamp_hp=", str(row.get("_dsh_hit_hp", "none")),
		" stamp_owner=", str(row.get("_dsh_hit_owner", "none")),
		" frame=", Engine.get_physics_frames())
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
		+ " threshold_pct=%.1f" % (_dsh_threshold() * 100.0) + " strict_lt=false inclusive_lte=true" \
		+ " goal=" + goal_kind + " marker=" + marker_text \
		+ " dist_m=%.1f" % distance + " moved_m=%.1f" % _dsh_moved_m \
		+ " " + NeedsCatalog.site_telemetry(_dsh_site_choice) \
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
func threat_physics_active30() -> bool:
	return _threat30 != null and _threat30.active()

func threat_event30(event: Dictionary, world: RefCounted) -> Dictionary:
	if _disposed or not Thread.is_main_thread(): return {"accepted":false,"reason":"life_retired"}
	if _threat30 == null: _threat30=ThreatLife30.new()
	return _threat30.accept(self,event,world)

func incident_can_hear(owner: RefCounted) -> bool:
	if _disposed or not Thread.is_main_thread() or _busy or owner!=_health or not _host.target_current(_token): return false
	if _dsh_simple_goal_active() or _restaurant28_active() or _economy28_active(): return false
	if _visit!=null or _interrupting or _health.should_pause_walk(): return false
	return _phase in ["IDLE","RESTING","WAITING_FOR_RECOVERY","WALKING","AMBIENT","INCIDENT_REACTING"]

func accept_incident_event(owner: RefCounted, event: Dictionary) -> Dictionary:
	if _disposed or not Thread.is_main_thread() or owner!=_health or not _host.target_current(_token):
		return {"accepted":false,"reason":"current_daily_owner_required"}
	if _busy: return {"accepted":false,"retryable":true,"reason":"life_busy"}
	if _dsh_simple_goal_active() or _restaurant28_active() or _economy28_active(): return {"accepted":false,"reason":"physical_need_visit_owned"}
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
	_attention29.clear()
	if _roam51_active and _roam51 != null: _roam51.cancel(); _roam51_active=false
	_leisure58_abandon("incident")
	_ambient29_cancel("incident")
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
	if _threat30 != null and _threat30.step(delta,row):
		_busy=false; return
	if _attention29.step(self, delta, row):
		_dsh_energy_drain(); _dsh_resdiag_step(row); _busy=false; return
	if _ambient29 != null and _ambient29.active():
		if _health.should_pause_walk() or not _host.target_current(_token) or _hospital51_below_threshold(row) or (dsh_energy_on() and _energy < 20.0) or dsh_economy_priority_pending():
			_ambient29.cancel("priority"); _phase="IDLE"; _next_decision=_now
		else:
			var result: String = _ambient29.step(delta)
			_dsh_energy_drain(); _dsh_resdiag_step(row)
			if result != "active":
				if _routine58 != null: _routine58.after_ambient(_now, _sandbox28_random(), _routine58_clock())
				_phase="IDLE"; _next_decision=_now
			_busy=false; return
	if _routine58_home_active():
		_routine58_step_home(delta, row)
		_dsh_energy_drain(); _dsh_resdiag_step(row); _busy=false; return
	if _dsh_simple_goal_active():
		if _health.should_pause_walk() or not _host.target_current(_token):
			_hospital_treat_started = -1.0
			_hospital28_clear_treatment_pose()
			_busy=false; return
		_hospital51_step(delta, row)
		_dsh_energy_drain()
		# A low energy trigger joins the queue without stealing the medical route.
		if dsh_energy_on(): _dsh_rearm_energy_queue(row)
		_dsh_resdiag_step(row)
		_dsh_quit_after()
		_busy=false; return
	if _economy28_active():
		if _health.should_pause_walk() or not _host.target_current(_token):
			_economy28.pause(); _busy = false; return
		_economy28_step(delta, row)
		_dsh_energy_drain()
		if dsh_energy_on(): _dsh_rearm_energy_queue(row)
		_dsh_resdiag_step(row); _dsh_quit_after()
		_busy = false; return
	if _restaurant28_active():
		if _health.should_pause_walk() or not _host.target_current(_token):
			_restaurant28_meal_started = -1.0
			_busy=false; return
		_restaurant28_step(delta, row)
		_dsh_energy_drain()
		if dsh_energy_on(): _dsh_rearm_energy_queue(row)
		_dsh_resdiag_step(row); _dsh_quit_after()
		_busy=false; return
	if _roam51_active and _dsh_simple_on():
		if _health.should_pause_walk() or not _host.target_current(_token):
			_roam51.cancel(); _roam51_active=false
			_leisure58_abandon("health_or_owner_lost")
			_phase="RESTING"; _next_decision=_now+250.0
			_busy=false; return
		if _needs_hospital(row):
			_roam51.cancel(); _roam51_active=false
			_leisure58_abandon("medical_priority")
			_dsh_simple_begin(row)
		elif dsh_energy_on() and _energy < _dsh_energy_threshold() * 100.0 and _now >= _restaurant28_retry_at and not _hospital51_below_threshold(row):
			_roam51.cancel(); _roam51_active=false
			_leisure58_abandon("energy_priority")
			_dsh_queue_push("restaurant")
			_restaurant28_begin()
		else:
			# DSH_RESERVE58: the seat was reserved at goal-selection time, so the walk
			# itself keeps that exact reservation alive. Without this renewal a long
			# walk would drop its own seat on the selection deadline.
			if _leisure58 != null and not _leisure58.renew(_token.get("body")) and _leisure58.reserved_bench_id() != 0:
				_leisure58_abandon("bench_selection_lease_lost")
				_leisure_arrived58=false
			var leisure_lost: bool = _leisure58 != null and not _leisure58.current()
			var roam_result: String = "blocked" if leisure_lost else _roam51.step(delta)
			if roam_result in ["arrived", "blocked"]:
				var roam_reason: String="leisure_bench_removed" if leisure_lost else _roam51.last_reason()
				_leisure_arrived58=roam_result=="arrived"
				if _routine58 != null: _routine58.leisure_attempt(_now,_leisure_arrived58)
				# DSH_RESERVE58: an arrived resident KEEPS its reserved seat until the
				# bench action adopts it; a failed walk frees the seat at once.
				if roam_result != "arrived" or _leisure58 == null or _leisure58.reserved_bench_id() == 0:
					_leisure58_abandon("walk_ended:"+roam_reason)
				_roam51.cancel(); _roam51_active=false
				_phase="RESTING"; _goal={}
				_next_decision=_now+(1000.0+_sandbox28_random()*2000.0 if roam_result=="arrived" else SimpleHospital.roam_retry_delay_ms29(str(_token.source_id),_roam_serial,roam_reason))
				if roam_result=="arrived":
					_completed.walk+=1
					dsh_economy_roam_arrived(str(_roam_serial))
				print("NPC_ROAM51 id=",str(_token.source_id)," result=",roam_result," reason=",roam_reason," frame=",frame)
		_dsh_energy_drain()
		if dsh_energy_on(): _dsh_rearm_energy_queue(row)
		_dsh_resdiag_step(row); _dsh_quit_after()
		_busy=false; return
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
				# The base states stay exactly as they were: a completed walk is followed by
				# a short rest, a refused one by a bounded pause before the next decision.
				_walk.cancel(); _completed.walk+=1; _phase="RESTING"; _next_decision=_now+1000.0+_unit("rest:"+str(_roam_serial))*2000.0
				_leisure58_prefetch()  # DSH_ONEGOAL58: prepare the next deed during the pause
			elif walking.status in ["BLOCKED","CANCELLED"]:
				_reason=str(walking.reason); _phase="RESTING"; _next_decision=_now+1500.0
				_leisure58_prefetch()  # DSH_ONEGOAL58: same, a refused walk is not a lost pause
	if _routine58_rest_active(): _routine58_hold(delta)
	if _phase in ["IDLE","RESTING"]: _leisure58_prefetch()  # DSH_ONEGOAL58: decide the next deed now
	_dsh_energy_drain()  # DSH_ENERGY: spent by the metres the shipped host really moved
	_dsh_resdiag_step(row)  # DSH_RESDIAG: the head-up display of the owner's test resident
	_dsh_quit_after()  # DSH_MEDPRIORITY: --city-quit-after=<s> bounds a short proof run
	if dsh_daily_decision_due() and _phase in ["IDLE","RESTING","WAITING_FOR_RECOVERY"] and _now>=_next_decision: _choose(row)
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
	if _now < _next_medical: return false
	if row.get("dead", false) or row.get("_medicalDowned", false) or row.get("_forcedCrawl", false) or float(row.get("max_hp", 0)) <= 0.0: return false
	if _dsh_simple_on(): return _hospital51_below_threshold(row)
	var threshold: float = _dsh_threshold() if _dsh_med_on() else MEDICAL_THRESHOLD
	var hp: float = _dsh_effective_hp(row) if _dsh_med_on() else float(row.get("hp", 0))
	return NeedsCatalog.health_at_or_below(row, hp, threshold)

func _hospital51_below_threshold(row: Dictionary) -> bool:
	# Existing callers share the user's inclusive half-health rule.
	if row.get("dead", false) or row.get("_medicalDowned", false) or row.get("_forcedCrawl", false) or float(row.get("max_hp", 0)) <= 0.0: return false
	return NeedsCatalog.health_at_or_below(row, _dsh_effective_hp(row), .5)

func _new_goal(kind: String) -> Dictionary:
	_sequence+=1
	return {"goal_id":str(_token.source_id)+":daily:"+str(_sequence),"kind":kind}

## DSH_MEDPRIORITY: the owner's "damage must land immediately" seam. The hit owner calls
## this from the very call that applied the damage, so the medical priority is decided in
## the same frame instead of waiting for this resident's turn in the daily poll slice
## (measured period ~1.6 s). It decides exactly what `_choose` decides and never reads a
## clock, invents damage or moves anything.
func dsh_notice_damage() -> Dictionary:
	var scene30: Node3D = _dsh_life_scene()
	if is_instance_valid(scene30):
		var world30: RefCounted = scene30.get_meta("npc_threat_world30") if scene30.has_meta("npc_threat_world30") else null
		if world30 != null: world30.confirmed_hit(self)
	_attention29.clear()
	_ambient29_cancel("hit")
	if _routine58_home_active(): _home58.request_wake("hit")
	if _disposed or _busy or not Thread.is_main_thread(): return {"ok":false,"reason":"life_busy_or_disposed"}
	if (not _dsh_med_on() and not _dsh_simple_on()) or not _host.target_current(_token): return {"ok":false,"reason":"not_current"}
	var row: Dictionary = _life()
	if row.is_empty() or row.get("dead", false) or float(row.get("hp", 0)) <= 0: return {"ok":false,"reason":"life_not_living"}
	if _routine58_home_active() and _hospital51_below_threshold(row):
		return {"ok":true,"reason":"hospital_pending_physical_home_exit","goal":"hospital"}
	if _economy28_active() and _hospital51_below_threshold(row):
		_economy28.request_priority("hospital")
		return {"ok":true,"reason":"hospital_pending_physical_economy_exit","goal":"hospital"}
	if _restaurant28_active() and _hospital51_below_threshold(row):
		_restaurant28_medical = true
		_restaurant28_meal_started = -1.0
		return {"ok":true,"reason":"hospital_pending_physical_restaurant_exit","goal":"hospital"}
	if str(_goal.get("kind", "")) == "hospital" or _visit != null: return {"ok":true,"reason":"already_serving_health"}
	if not _needs_hospital(row): return {"ok":true,"reason":"threshold_not_crossed"}
	if _dsh_simple_on():  # DSH_SIMPLEHOSP: the copy errand is taken directly, never queued
		_dsh_med_chain("damaged", row, "hp_at_or_below_threshold_from_hit")
		var simple_started: bool = _dsh_simple_begin(row)
		return {"ok":simple_started, "reason":"simple_hospital_from_hit" if simple_started else "simple_hospital_pending", "goal":"hospital"}
	_dsh_marker_ready()
	_dsh_med_chain("damaged", row, "hp_at_or_below_threshold_from_hit")
	_dsh_queue_push("hospital")
	var task: String = _dsh_queue_pop_front()
	_mark_served(task)
	_start(_new_goal(task), task == "hospital")
	return {"ok":true,"reason":"medical_priority_from_hit","goal":task}

# --------------------------------------------------------------------------- #
# DSH_SIMPLEHOSP: --city-simple-hospital=1. The owner's rule for this test stand: the
# standing hospital is off, the hospital IS the palazzo copy (TownClone_1, sign
# "БОЛЬНИЦА"), and the resident walks to the measured centre of that copy directly -
# no source_admit, no support_height, no admission band. That point is outside the
# pinned source crop, so the shipped proof chain can never admit it (measured:
# support_height_nan -> medical_priority_admission_refused -> the errand ends 25-30 m
# short of the copy). The walk itself lives in npc_simple_hospital.gd and moves this
# resident's own body; this life only decides when the errand starts, ends and repeats.
#
# The task is never marked served here: while HP is still below the threshold the goal
# re-arms itself, and a failed run of bounded attempts is repeated after a short rest -
# the owner's "не помечать served после одной неудачи".
# --------------------------------------------------------------------------- #
func _dsh_simple_on() -> bool:  # DSH_SIMPLEHOSP
	return SimpleHospital.enabled()

func _dsh_simple_goal_active() -> bool:  # DSH_SIMPLEHOSP
	return _dsh_simple != null and _dsh_simple_on() and str(_goal.get("kind", "")) == "hospital" and _visit == null

## DSH_SIMPLEHOSP: the map the city navigation really walks on. Reached exactly the way
## npc_daily_walk.gd reaches it: the host's navigation owner, then its backend.
func _dsh_simple_map() -> RID:  # DSH_SIMPLEHOSP
	if not is_instance_valid(_host): return RID()
	var navigation: Variant = _host.get("_navigation")
	if navigation == null: return RID()
	if navigation.has_method("map_rid"):
		var direct: RID = navigation.map_rid()
		if direct.is_valid(): return direct
	var backend: Variant = navigation.get("_backend")
	if backend != null and backend.has_method("map_rid"): return backend.map_rid()
	return RID()

## DSH_SIMPLEHOSP: the stand's own line for the cases the walk owner cannot report (a
## target that could not be resolved has no point to print).
func _dsh_simple_report(result: String, reason: String) -> void:  # DSH_SIMPLEHOSP
	print("DSH_SIMPLEHOSP id=", str(_token.get("source_id", "")), " target=none dist_m=-1.0",
		" phase=none result=", result, " reason=", reason,
		" frame=", Engine.get_physics_frames())

## DSH_SIMPLEHOSP: take the owner's copy errand. The ordinary walk is cancelled first (the
## same bounded cancellation `_start` uses), because the resident host moves a body only
## while a navigation request owns it.
func _dsh_simple_begin(row: Dictionary) -> bool:  # DSH_SIMPLEHOSP
	if _visit != null or _restaurant28_active() or _economy28_active() or _routine58_home_active(): return false
	if _roam51 != null: _roam51.cancel()
	_roam51_active=false
	_leisure58_abandon("medical_priority")
	var cancelled: Dictionary = _walk.cancel()
	if not cancelled.get("ok", false):
		_reason = "simple_hospital_previous_walk_pending"
		_phase = "IDLE"
		_next_decision = _now + 500.0
		return false
	var body: Variant = _token.get("body")
	if not is_instance_valid(body) or not body is CharacterBody3D: return false
	if _dsh_simple != null: _dsh_simple.cancel()
	_dsh_simple = Restaurant28.new() # Shared signed hospital slots + physical route.
	var started: bool = _dsh_simple.begin(_dsh_life_scene(), body as CharacterBody3D,
		_dsh_simple_map(), str(_token.get("source_id", "")), "БОЛЬНИЦА")
	if not started:
		_dsh_simple.cancel()
		_dsh_simple_report("blocked", "walk_owner_refused:" + _dsh_simple.last_reason())
		_next_medical = _now + 5000.0
		_next_decision = _now + 5000.0
		return false
	_hospital_stage = "INBOUND"
	var outside: Variant = _dsh_simple.outside_point()
	_hospital_outside = outside if outside is Vector3 else Vector3.INF
	_hospital_healed = false
	_hospital_treat_started = -1.0
	_goal = _new_goal("hospital")
	_phase = "WALKING"
	_reason = ""
	_dsh_queued_hospital = false  # DSH_TASKQUEUE: the copy errand is never "served"
	_dsh_med_goal_id = str(_goal.get("goal_id", ""))
	_dsh_med_reported = true
	_dsh_med_emit("goal_set", row, "signed_hospital_capacity29")
	return true

# Walk owner's real geometry predicate is required at every treatment sample.
func _hospital51_inside() -> bool:
	if _dsh_simple == null or not _dsh_simple.is_inside() or not _host.target_current(_token): return false
	var body: CharacterBody3D = _token.body
	if _hospital_support51 == null:
		_hospital_support51 = PhysicalRoute51.new()
		if not _hospital_support51.configure(body): _hospital_support51 = null; return false
	return Restaurant28.supported(body, _hospital_support51)

func _hospital51_log(stage: String, reason: String = "") -> void:
	var row: Dictionary = _life()
	print("NPC_HOSPITAL51 id=", str(_token.get("source_id", "")), " stage=", stage,
		" hp=", row.get("hp", -1), " reason=", reason, " queue=", str(_dsh_task_queue),
		" frame=", Engine.get_physics_frames())

func _hospital28_clear_treatment_pose() -> void:
	var body: Variant = _token.get("body")
	if is_instance_valid(body) and body is Node3D and body.has_meta("npc_treatment28"):
		body.remove_meta("npc_treatment28")

func _hospital51_step(delta: float, row: Dictionary) -> void:
	if _hospital_stage == "EXIT_RETRY":
		_dsh_simple.hold(delta)
		if _now < _hospital_exit_retry_at: return
		_hospital_exit_retry_at = _now + 1500.0
		if _dsh_simple.begin_exit():
			_hospital_stage = "OUTBOUND"
			_hospital51_log("exit_retry")
		return
	if _hospital_stage == "TREATING":
		var body: CharacterBody3D = _token.body
		_dsh_simple.hold(delta)
		if not _hospital51_inside():
			_hospital51_log("treatment_cancelled", "left_interior")
			if _dsh_simple.needs_exit():
				if _dsh_simple.begin_exit(): _hospital_stage = "OUTBOUND"
				else: _hospital_stage = "EXIT_RETRY"; _hospital_exit_retry_at = _now + 1500.0
			else: _dsh_simple_finish(row, false)
			return
		var adapter: Variant = _health.get("_adapter")
		if not is_instance_valid(adapter) or not adapter._fresh():
			_dsh_simple_finish(row, false); return
		var revision: int = int(adapter._revision)
		var displaced: bool = _hospital_treat_anchor.is_finite() and body.global_position.distance_to(_hospital_treat_anchor) > 0.05
		if _hospital_treat_started < 0.0 or revision != _hospital_treat_revision or float(row.hp) != _hospital_treat_hp or _now - _hospital_treat_last > 250.0 or displaced:
			_hospital_treat_started = _now
			_hospital_treat_revision = revision
			_hospital_treat_hp = float(row.hp)
			_hospital_treat_anchor = body.global_position
		_hospital_treat_last = _now
		body.set_meta("npc_treatment28", {"frame":Engine.get_physics_frames(), "body_id":body.get_instance_id(), "delta":delta, "active":true, "kind":"hospital", "elapsed_s":maxf(0.0, (_now - _hospital_treat_started) / 1000.0)})
		if _now - _hospital_treat_started < HOSPITAL51_TREAT_MS: return
		if not _hospital51_heal(row):
			_hospital51_log("treatment_cancelled", "health_lease_changed")
			_dsh_simple_finish(row, false); return
		_hospital51_log("treated", "inside_still_1500ms")
		_hospital28_clear_treatment_pose()
		if not _dsh_simple.begin_exit():
			_hospital_stage = "EXIT_RETRY"
			_hospital_exit_retry_at = _now + 1500.0
			_hospital51_log("exit_blocked", "keeping_owned_visit")
			return
		_hospital_stage = "OUTBOUND"
		_hospital51_log("leaving")
		return
	var result: String = _dsh_simple.step(delta)
	if result == "blocked":
		if _hospital_stage == "OUTBOUND":
			_hospital_stage = "EXIT_RETRY"
			_hospital_exit_retry_at = _now + 1500.0
			_hospital51_log("exit_blocked", "keeping_owned_visit")
		elif _dsh_simple.needs_exit():
			if _dsh_simple.begin_exit(): _hospital_stage = "OUTBOUND"
			else: _hospital_stage = "EXIT_RETRY"; _hospital_exit_retry_at = _now + 1500.0
		else: _dsh_simple_finish(row, false)
		return
	if result not in ["entered", "exited"]: return
	if _hospital_stage == "INBOUND":
		if not _hospital51_inside():
			_hospital51_log("arrival_rejected", "not_physically_inside")
			_dsh_simple_finish(row, false); return
		_hospital_stage = "TREATING"
		_hospital_treat_started = -1.0
		_hospital51_log("entered", "door_plane_and_room_floor_verified")
	elif _hospital_stage == "OUTBOUND":
		if not _dsh_simple.is_outside():
			_hospital51_log("exit_rejected", "still_inside")
			_dsh_simple_finish(row, false); return
		_hospital51_log("exited")
		_dsh_simple_finish(row, _hospital_healed)

# Same local health owner and synchronous HP/revision receipt as the existing treatment
# port. New local user policy; never edits source-save rows or revives a dead life.
func _hospital51_heal(row: Dictionary) -> bool:
	if _hospital_healed or not _hospital51_inside() or not is_same(row, _life()): return false
	var adapter: Variant = _health.get("_adapter")
	if not is_instance_valid(adapter) or adapter._busy or adapter._retired or not adapter._fresh(): return false
	if not is_same(adapter._row, row) or adapter._binding != _health._binding or adapter._current.get_object() != _health: return false
	if int(adapter._revision) != _hospital_treat_revision or float(row.hp) != _hospital_treat_hp: return false
	if row.get("dead", false) or row.get("_medicalDowned", false) or row.get("_forcedCrawl", false) or float(row.hp) <= 0.0 or float(row.get("max_hp", 0)) <= 0.0: return false
	var event_id: String = "local_hospital51:" + str(get_instance_id()) + ":" + str(_goal.get("goal_id", ""))
	if adapter._seen.has(event_id) or adapter._seen.size() >= 4096: return false
	var hp_before: float = float(row.hp)
	adapter._busy = true
	adapter._seen[event_id] = true
	row.hp = row.max_hp
	adapter._revision += 1
	adapter._last_now = maxf(float(adapter._last_now), _now)
	var receipt: Dictionary = adapter._done(event_id, true, "hospital51_native_walk_in_treatment", {})
	receipt["hospital"] = {"goal_id":_goal.get("goal_id", ""), "treatment_ms":_now - _hospital_treat_started, "hp_before":hp_before, "hp_after":row.hp, "inside":true, "policy":"user_local_hospital51"}
	adapter._events[event_id] = receipt.duplicate(true)
	_health.last_result = receipt.duplicate(true)
	preload("res://scripts/npc_visual/npc_heal_fx30.gd").confirmed30(_health,event_id)
	_hospital_healed = true
	_dsh_hp_apply_pending = false
	return true

func _dsh_simple_finish(row: Dictionary, arrived: bool) -> void:
	_hospital28_clear_treatment_pose()
	var detail: String = _dsh_simple.last_reason() if _dsh_simple != null else ""
	if arrived:
		_completed["hospital"] = int(_completed.get("hospital", 0)) + 1
		_hospital51_log("complete", "treated_and_physically_exited")
	else:
		_hospital51_log("blocked", detail)
	if _dsh_simple != null: _dsh_simple.cancel()
	_hospital_stage = ""
	_hospital_treat_started = -1.0
	_goal = {}
	_phase = "IDLE"
	_reason = "" if arrived else detail
	_release_served("hospital")
	_next_decision = _now + (1000.0 if arrived else 1500.0)
	# Successful healing removes the need. Fresh damage may immediately create a new one.
	_next_medical = _now if arrived else _now + DSH_SIMPLE_REARM_MS

# Restaurant energy belongs to this life, not the old commerce/service factory.
# Like hospital, completion is published only after a physically verified exit.
func _restaurant28_active() -> bool:
	return _dsh_simple_on() and _restaurant28 != null and not _restaurant28_stage.is_empty() and str(_goal.get("kind", "")) == "restaurant"

func _restaurant28_log(stage: String, reason: String = "") -> void:
	print("NPC_RESTAURANT28 id=", str(_token.get("source_id", "")), " stage=", stage,
		" energy=", _energy, " reason=", reason, " queue=", str(_dsh_task_queue),
		" frame=", Engine.get_physics_frames())

func _restaurant28_begin() -> bool:
	# Latest user policy: hungry residents choose restaurant OR shop once, and keep
	# that choice/price through a bank detour. Both charge the actual local account.
	if not _economy28_prepare():
		_phase = "RESTING"; _next_decision = maxf(_now + 1000.0, _economy28_config_retry)
		return false
	_economy28.request_food()
	return _economy28_try_begin(_life())

func _restaurant28_request_exit(reason: String) -> void:
	_restaurant28_meal_started = -1.0
	if _restaurant28.begin_exit():
		_restaurant28_stage = "OUTBOUND"
		_restaurant28_log("leaving", reason)
	else:
		_restaurant28_stage = "EXIT_RETRY"
		_restaurant28_exit_retry_at = _now + 1500.0
		_restaurant28_log("exit_blocked", "keeping_owned_visit:" + reason)

func _restaurant28_step(delta: float, row: Dictionary) -> void:
	if _hospital51_below_threshold(row): _restaurant28_medical = true
	if _restaurant28_medical and _restaurant28_stage not in ["OUTBOUND", "EXIT_RETRY"]:
		if _restaurant28.needs_exit(): _restaurant28_request_exit("hospital_priority")
		else: _restaurant28_finish(false, "hospital_priority_before_entry")
		return
	if _restaurant28_stage == "EXIT_RETRY":
		_restaurant28.stand(delta)
		if _now >= _restaurant28_exit_retry_at: _restaurant28_request_exit("retry")
		return
	if _restaurant28_stage == "MEAL":
		_restaurant28.stand(delta)
		if not _restaurant28.is_inside():
			_restaurant28_request_exit("meal_cancelled_live_interior_lost")
			return
		var adapter: Variant = _health.get("_adapter")
		if not is_instance_valid(adapter) or not adapter._fresh():
			_restaurant28_request_exit("meal_cancelled_health_owner_changed")
			return
		var body: CharacterBody3D = _token.body
		var revision: int = int(adapter._revision)
		var moved: bool = _restaurant28_meal_anchor.is_finite() and body.global_position.distance_to(_restaurant28_meal_anchor) > .05
		if _restaurant28_meal_started < 0.0 or _now - _restaurant28_meal_last > 250.0 or moved or revision != _restaurant28_meal_revision or float(row.hp) != _restaurant28_meal_hp:
			_restaurant28_meal_started = _now
			_restaurant28_meal_anchor = body.global_position
			_restaurant28_meal_revision = revision
			_restaurant28_meal_hp = float(row.hp)
		_restaurant28_meal_last = _now
		if _now - _restaurant28_meal_started < RESTAURANT28_MEAL_MS: return
		# Synchronous current-life transaction. A stale/dead/changed actor cannot eat.
		if _restaurant28_fed or not is_same(row, _life()) or not _host.target_current(_token) or _health.should_pause_walk() or _hospital51_below_threshold(row):
			_restaurant28_request_exit("meal_cancelled_current_life_changed")
			return
		var before: float = _energy
		_energy = 100.0
		_restaurant28_fed = true
		_restaurant28_receipt = {"event_id":"local_restaurant28:" + str(get_instance_id()) + ":" + str(_goal.goal_id), "source_id":str(_token.source_id), "goal_id":str(_goal.goal_id), "inside":true, "meal_ms":_now - _restaurant28_meal_started, "energy_before":before, "energy_after":_energy, "frame":Engine.get_physics_frames(), "authority":"local_daily_energy", "service_transaction":false}
		_dsh_energy_last = body.global_position
		_dsh_energy_last_ms = Time.get_ticks_msec()
		_dsh_energy_emit("restored_inside")
		_restaurant28_log("fed", "inside_still_2000ms")
		_restaurant28_request_exit("meal_complete")
		return
	var result: String = _restaurant28.step(delta)
	if result == "entered":
		_restaurant28_stage = "MEAL"
		_restaurant28_meal_started = -1.0
		_restaurant28_log("entered", "closed_door_plane_and_live_floor_verified")
	elif result == "exited":
		_restaurant28_log("exited")
		_restaurant28_finish(_restaurant28_fed and not _restaurant28_medical, "physical_exit")
	elif result == "blocked":
		if _restaurant28_stage == "OUTBOUND":
			_restaurant28_stage = "EXIT_RETRY"
			_restaurant28_exit_retry_at = _now + 1500.0
			_restaurant28_log("exit_blocked", "keeping_owned_visit")
		elif _restaurant28.needs_exit(): _restaurant28_request_exit("inbound_blocked_inside")
		else: _restaurant28_finish(false, _restaurant28.last_reason())

func _restaurant28_finish(completed: bool, reason: String) -> void:
	if completed and (not _restaurant28_fed or not _restaurant28.is_outside()): completed = false
	var medical: bool = _restaurant28_medical
	if completed:
		_completed.restaurant += 1
		_record("restaurant_completed", "fed_and_physically_exited")
		_restaurant28_log("complete", "fed_and_physically_exited")
	else:
		_record("restaurant_interrupted" if medical else "restaurant_blocked", reason)
		_restaurant28_log("interrupted" if medical else "blocked", reason)
	_restaurant28.cancel(); _restaurant28 = null
	_restaurant28_stage = ""; _restaurant28_meal_started = -1.0
	_restaurant28_medical = false
	_release_served("restaurant")
	if dsh_energy_on() and _energy < _dsh_energy_threshold() * 100.0: _dsh_queue_push("restaurant")
	_goal = {}; _phase = "IDLE"; _reason = "" if completed else reason
	_restaurant28_retry_at = _now if completed or medical else _now + 8000.0
	_next_decision = _now if medical else _now + 1000.0

func _economy28_prepare() -> bool:
	if not _dsh_simple_on() or _disposed or _now < _economy28_config_retry: return false
	if _economy28 != null: return true
	var row: Dictionary = _life()
	if row.is_empty() or row.get("dead", false) or float(row.get("hp", 0)) <= 0.0: return false
	var candidate := Economy28.new()
	var result: Dictionary = candidate.configure(self, _account, _dsh_life_scene(), _dsh_simple_map())
	if not result.get("ok", false):
		_economy28_config_retry = _now + 8000.0
		print("NPC_ECONOMY28 id=", str(_token.get("source_id", "")), " stage=configuration_blocked reason=", result.get("reason", "unknown"))
		return false
	_economy28 = candidate
	return true

func _economy28_active() -> bool:
	return _dsh_simple_on() and _economy28 != null and _economy28.active()

func _sandbox28_random() -> float:
	return _economy28.random_unit() if _economy28 != null else randf()

## External ambient owner integration: only call after a genuine native arrived.
## A blocked leg, cancelled leg, begin callback or animation ending is not arrival.
func dsh_economy_roam_arrived(goal_id: String) -> void:
	# The logical policy selects service intents independently of travelled legs.
	if _routine58 != null: return
	if not _economy28_prepare(): return
	var action: String = _economy28.note_roam_arrived(goal_id)
	if not action.is_empty(): _sandbox28_action = action

func dsh_take_ambient28_choice() -> bool:
	if _disposed or _sandbox28_action != "ambient": return false
	_sandbox28_action = "walk"
	return true

func dsh_economy_priority_pending() -> bool:
	if _disposed or not _dsh_simple_on(): return false
	return _economy28_active() or (_economy28 != null and _economy28.has_pending_need() and not _economy28.optional_retry56(_now) and not _routine58_purchase_deferred())

func _economy28_try_begin(row: Dictionary) -> bool:
	if _disposed or row.is_empty() or row.get("dead", false) or float(row.get("hp", 0)) <= 0.0: return false
	if _dsh_simple_goal_active() or _restaurant28_active() or _visit != null or _hospital51_below_threshold(row) or _routine58_home_active(): return false
	if not _economy28_prepare(): return false
	if _economy28.active(): return true
	if dsh_energy_on() and _energy < 20.0: _economy28.request_food()
	if not _economy28.has_pending_need() or _routine58_purchase_deferred(): return false
	var kind: String = _economy28.desired_kind(_now)
	if kind.is_empty():
		if _economy28.optional_retry56(_now): return false
		_phase = "RESTING"; _next_decision = maxf(_now + 250.0, float(_economy28.snapshot().retry_at))
		return true
	if _roam51 != null: _roam51.cancel()
	_roam51_active = false
	_leisure58_abandon("economy_priority")
	if not _walk.cancel().get("ok", false): _phase = "RESTING"; _next_decision = _now + 500.0; return true
	if not _economy28.begin(kind, _now):
		_goal = {}; _phase = "RESTING"; _next_decision = _now + 1000.0
		return not _economy28.optional_retry56(_now)
	_goal = _new_goal(kind); _phase = "WALKING"; _reason = ""
	_sandbox28_action = "walk"
	_record("economy_started", kind)
	return true

func _economy28_step(delta: float, row: Dictionary) -> void:
	var result: String = _economy28.step(delta, _now, row)
	if result != "done": return
	var completion: Dictionary = _economy28.take_completion()
	var kind: String = str(completion.get("kind", ""))
	if completion.get("completed", false) and _completed.has(kind):
		_completed[kind] = int(_completed[kind]) + 1
		_record("economy_completed", kind + ":paid_and_physically_exited")
	_goal = {}; _phase = "IDLE"
	_next_decision = _now if not str(completion.get("priority", "")).is_empty() else _now + 1000.0

func _economy28_restore_energy(visit: RefCounted, receipt: Dictionary) -> Dictionary:
	if _disposed or visit != _economy28 or not visit.current_inside() or not visit._committed: return {"energy_restored":false}
	if receipt.get("kind") not in ["local_shop_purchase28", "local_restaurant_purchase28"] or int(receipt.get("amount", 0)) < 5: return {"energy_restored":false}
	var row: Dictionary = _life()
	if row.is_empty() or row.get("dead", false) or _hospital51_below_threshold(row): return {"energy_restored":false}
	var before: float = _energy
	_energy = 100.0; _release_served("restaurant")
	_restaurant28_receipt = receipt.duplicate(true)
	_restaurant28_receipt.merge({"energy_before":before,"energy_after":_energy,"energy_restored":true})
	print("NPC_NEEDS28 id=", str(_token.source_id), " stage=energy_restored kind=", visit._kind,
		" before=", before, " after=", _energy, " event=", receipt.get("event_id", ""), " frame=", Engine.get_physics_frames())
	return {"energy_before":before,"energy_after":_energy,"energy_restored":true}

## Task58: frees the bench that THIS resident reserved when it chose to walk there.
## Called wherever a walk to a bench is cut short, so an interrupted resident never
## holds a seat another resident could be using. The registry is the only owner of
## the seat: this only drops the exact reservation this life placed.
func _leisure58_abandon(reason: String) -> void:
	if _leisure58 == null: return
	var body: Variant = _token.get("body")
	_leisure58.clear(body if body is CharacterBody3D else null)
	if not reason.is_empty(): _leisure58_release_reason = reason

## DSH_ONEGOAL58: one goal, and a refused goal is answered by choosing another place.
## Bounded to LEISURE58_ATTEMPTS real benches; each refused place is remembered so the
## next attempt cannot offer it again, and a refusal never leaves the resident standing.
## DSH_ONEGOAL58: the next deed is decided WHILE the resident is between actions, not after
## the pause ends. Measured defect: exit -> new intent -> first 10 cm took seconds, because
## the whole choice (schedule, wallet, site scan, seat search, first path query) happened only
## when the resident was already free. Here the choice and its seat are prepared in advance;
## when the pause ends the walk starts immediately with the reservation already in hand.
func _leisure58_prefetch() -> bool:
	if _leisure58 == null or _routine58 == null: return false
	if _leisure58.reserved_bench_id() != 0: return true
	var kind: String = str(_routine58.choose(_routine58_clock(), _now, _routine58_purchase_deferred()).get("kind", ""))
	if kind != "leisure": return false
	var body: CharacterBody3D = _token.get("body") as CharacterBody3D
	if not is_instance_valid(body): return false
	if _routine58 != null: _routine58.leisure_attempt(_now)
	var prepared: Dictionary = _leisure58.select(body, _sandbox28_random(), _leisure58_avoid)
	if prepared.is_empty(): return false
	_dsh_prefetched58 += 1
	return true

func _leisure58_begin() -> bool:
	if _routine58 == null: return false
	_routine58.leisure_attempt(_now)
	var body: CharacterBody3D = _token.get("body") as CharacterBody3D
	if not is_instance_valid(body) or not _walk.cancel().get("ok",false): return false
	if _leisure58 == null:
		_leisure58=Leisure58.new()
		if not _leisure58.configure(_dsh_life_scene(),body): _leisure58=null; return false
	var reason := ""
	for attempt: int in LEISURE58_ATTEMPTS:
		var destination: Dictionary = _leisure58.select(body,_sandbox28_random(),_leisure58_avoid)
		if destination.is_empty():
			reason=str(_leisure58.snapshot().reason)
			break
		_roam_serial+=1; _leisure_arrived58=false
		if _roam51==null: _roam51=SimpleHospital.new()
		_roam51_active=_roam51.begin(destination.point,body,_dsh_simple_map(),str(_token.source_id),"roam")
		if _roam51_active:
			_goal=_new_goal("leisure"); _goal["destination"]=destination.duplicate()
			_phase="WALKING"; _reason=""
			# DSH_ROUTES58: one line per walk that names the route source, so a log shows
			# whether the prepared graph or the physical search carried this resident.
			print("NPC_ROUTE58 id=",str(_token.source_id)," source=",str(_roam51._prepared58_reason),
				" plan_ok=",_roam51._prepared58_plan_ok," plan_points=",int(_roam51._prepared58_plan_points),
				" prepared_used=",int(_roam51._prepared58_used)," length_m=","%.1f" % float(_roam51._prepared58_length_m),
				" graph_on=",_roam51.prepared58_on()," graph_loaded=",PreparedRoutes.loaded(),
				" phase=",str(_roam51._phase)," waypoints=",int(_roam51._route.route.size()),
				" target=",destination.point)
			# DSH_RESERVE58: the seat was already reserved by this selection, so the log
			# names the seat this resident holds - two residents can no longer log the
			# same bench, and the print proves which serial this life owns.
			print("NPC_ROUTINE58 id=",str(_token.source_id)," stage=leisure_started bench=",destination.bench_path,
				" target=",destination.point," seat_reserved=",not _leisure58.reserved_slot().is_empty(),
				" seat_serial=",int(_leisure58.reserved_slot().get("serial",-1))," attempt=",attempt+1)
			return true
		# This exact place is refused for a stated reason: remember it and take the next
		# available one. The seat it reserved is freed in the same call.
		reason=_roam51.last_reason()
		_leisure58_avoid.append(int(destination.bench_id))
		_leisure58_abandon("walk_begin_refused:"+reason)
	_reason="leisure:"+reason	# DSH_ONEGOAL58: the avoid list covers ONE decision only. Keeping only the last
	# refused place lets the next decision try every real bench again, in distance order.
	if _leisure58_avoid.size()>0: _leisure58_avoid=[_leisure58_avoid[-1]]
	return false


## DSH_ONEGOAL58: needs and place choice are re-evaluated at most once per second, while
## MOTION keeps running every physics frame. The expensive part of a resident tick is not
## the walk: it is re-asking "what do I want" - health, energy, wallet, schedule, shop
## planning, site scan - for ten residents every frame, and then changing its mind
## mid-action. The clock below bounds that question without touching any movement code.
const DECISION_INTERVAL_MS := 1000.0
static var _dsh_decision_interval := -1.0
func _decision_interval_ms() -> float:
	if _dsh_decision_interval < 0.0:
		_dsh_decision_interval = DECISION_INTERVAL_MS
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-decision-interval-ms="):
				_dsh_decision_interval = clampf(float(argument.trim_prefix("--city-decision-interval-ms=")), 50.0, 5000.0)
	return _dsh_decision_interval

func dsh_daily_decision_due() -> bool:
	if _now - _last_decision_ms < _decision_interval_ms(): return false
	_last_decision_ms = _now
	return true

func _choose(row: Dictionary) -> void:
	_last_decision_ms = _now
	_dsh_decisions+=1  # DSH_LIFETRACE
	# DSH_SIMPLEHOSP: the owner's direct copy errand is decided BEFORE the queue and
	# before the marker admission, so nothing below can mark the task served or hand this
	# resident to the standing hospital's controller.
	if _needs_hospital(row) and _dsh_simple_on():
		_dsh_site_pick("hospital")  # DSH_CATALOG: nearest hospital site of this district
		if _dsh_med_on(): _dsh_med_chain("damaged", row, "hp_at_or_below_threshold_simple")
		_dsh_simple_begin(row)
		return
	if _dsh_simple_on():
		_release_served("hospital")
		# A retry cooldown may delay the route, but cannot let food outrank low HP.
		if _hospital51_below_threshold(row):
			_phase = "RESTING"; _next_decision = maxf(_now + 250.0, _next_medical)
			return
		if dsh_energy_on(): _dsh_rearm_energy_queue(row)
		if _queue_has("restaurant") and _now >= _restaurant28_retry_at:
			_restaurant28_begin()
			return
		if _economy28_try_begin(row): return
		_routine58_choose(row)
		return
	# DSH_ENERGY / DSH_TASKQUEUE: the owner's ordering. Health outranks energy: a resident
	# below both thresholds gets hospital first and restaurant next, and neither goal
	# overwrites the other - they wait in the queue. A resident in neither condition keeps
	# exactly the shipped life below.
	# DSH_TASKQUEUE: the owner's order is health before energy. Health is therefore asked
	# FIRST and only then does the energy side put its task in, so a resident in both
	# states always ends up with ["hospital","restaurant"].
	# DSH_CATALOG: the owner's step 4. Both the condition and the priority of a place live
	# in ONE record in npc_needs_catalog.gd; this loop only walks the armed records in
	# priority order, so adding a place never means editing the life in three places.
	# Health still outranks energy because the record's priority says so, not because the
	# branches happen to be written in that order.
	var catalog: Array = NeedsCatalog.order(row, _energy, dsh_energy_on())
	for record: Dictionary in catalog:
		var place: String = str(record.get("id", ""))
		# DSH_CATALOG: the owner's district rule - the concrete site of this kind is the
		# nearest one to the resident, never one across the city. The choice is reported once
		# per change and repeated in every goal line below.
		_dsh_site_pick(place)
		_dsh_queue_push(place)
		if place == "hospital":
			_dsh_marker_ready()  # DSH_MEDPRIORITY: the visible room marker of the goal
			if _dsh_med_on(): _dsh_med_chain("damaged", row, "hp_at_or_below_threshold")  # DSH_MEDCHAIN
		elif _dsh_med_on() and place == "restaurant":
			_dsh_med_chain("goal_set", row, "restaurant_from_catalog")
	if not _needs_hospital(row) and _dsh_queued_hospital:
		_release_served("hospital")  # DSH_TASKQUEUE: the condition ended, the task is free again
	if dsh_energy_on() and _dsh_queued_restaurant:
		var meal_record: Dictionary = NeedsCatalog.find("restaurant")
		var meal_condition: Dictionary = meal_record.get("condition", {})
		if not NeedsCatalog._matches(meal_condition, row, _energy, true): _release_served("restaurant")
	# DSH_CATALOG: the queue is worked head-first, so the record with the lowest priority
	# number is served first and the rest wait - they never overwrite each other.
	if not _dsh_task_queue.is_empty():
		var task: String = _dsh_task_queue[0]
		if task == "hospital":
			_dsh_queue_pop_front()
			_mark_served("hospital")
			_start(_new_goal("hospital"), true)  # DSH_CATALOG: visit/direct owner takes over
			return
		elif task == "restaurant":
			_dsh_queue_pop_front()
			_mark_served("restaurant")
			_start(_new_goal("restaurant")); return
	# DSH_MEDPRIORITY: the owner's 50 %-exactly case. This line is printed only when the
	# new threshold flag is present, and only on a change of the resident's HP state.
	if _dsh_med_on():
		if MedMarker.current().is_empty(): _dsh_marker_ready()
		if NeedsCatalog.health_at_or_below(row, _dsh_effective_hp(row), _dsh_threshold()):
			_dsh_med_emit("blocked", row, "medical_priority_admission_refused")
			_dsh_med_chain("blocked:goal_not_owned", row, "medical_priority_admission_refused")
		else:
			_dsh_med_emit("no_goal", row, "hp_above_threshold")
			_dsh_med_chain("no_goal", row, "hp_above_threshold")
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
	var origin: Vector3 = body.global_position
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
		if begun.get("ok",false):
			_phase="WALKING"; _reason=""
			return
	_phase="RESTING"; _reason="no_current_clear_walking_goal"; _next_decision=_now+1500.0

## Scheduler/health death hook: validate the actual owner's terminal row, then
## cancel routes/pending needs immediately without waiting for the daily slice.
func dsh_notice_death() -> bool:
	if _disposed: return true
	if not is_instance_valid(_health) or _health.get("_token") != _token: return false
	var terminal: Variant = _health.get("_row")
	if not terminal is Dictionary or (not terminal.get("dead", false) and float(terminal.get("hp", 1.0)) > 0.0): return false
	_end_life()
	return true

func _end_life() -> void:
	ResDiag.unregister_life30(str(_token.get("source_id","")),self)
	if _threat30 != null: _threat30.cancel("death"); _threat30=null
	_attention29.clear(false)
	_ambient29_cancel("death")
	if _home58 != null: _home58.cancel("death"); _home58=null
	if _rest_driver58 != null: _rest_driver58.cancel(); _rest_driver58=null
	if _routine58 != null: _routine58.clear()
	_hospital28_clear_treatment_pose()
	if _economy28 != null: _economy28.cancel("life_ended"); _economy28 = null
	_sandbox28_action = "walk"
	# DSH_DEATH: the owner's step 1. A life that ends at hp 0 stops here: the visit is
	# cancelled and disposed, the direct errand is cancelled, the walk is disposed, every
	# task mark and the queue are dropped. Nothing of this route can be resumed, and the
	# id is remembered so the next life of this resident reports a clean respawn.
	var row: Dictionary = _life()
	if row.is_empty() and is_instance_valid(_health):
		var terminal: Variant = _health.get("_row")
		if terminal is Dictionary: row = terminal
	var died: bool = not row.is_empty() and (float(row.get("hp", 0)) <= 0.0 or bool(row.get("dead", false)))
	var id: String = str(_token.get("source_id", ""))
	if died:
		print("DSH_DEATH id=", id, " hp=0 action=stop_path goals=", str(_dsh_task_queue),
			" goal=", str(_goal.get("kind", "none")), " visited=", _completed.duplicate(),
			" frame=", Engine.get_physics_frames())
		_dsh_dead[id] = true
	if _visit!=null:
		_visit.cancel("actor_life_ended"); _visit.dispose(); _visit=null
	if _dsh_simple!=null: _dsh_simple.cancel(); _dsh_simple=null  # DSH_SIMPLEHOSP
	if _roam51!=null: _roam51.cancel(); _roam51=null
	if _restaurant28!=null: _restaurant28.cancel(); _restaurant28=null
	_restaurant28_stage=""; _restaurant28_meal_started=-1.0; _restaurant28_medical=false
	_hospital_support51=null
	_roam51_active=false
	_leisure58_abandon("end_life")
	if _walk!=null: _walk.dispose()
	# DSH_DEATH: without this the old goal, queue and served marks would outlive the body.
	_goal={}
	_dsh_task_queue.clear()
	_dsh_queued_hospital=false
	_hospital_stage=""
	_hospital_treat_started=-1.0
	_dsh_queued_restaurant=false
	_dsh_med_state=""
	_energy=0.0 if died else _energy
	_phase="RETIRED"; _disposed=true; _factory=Callable()
	_incident_waiting_release=false; _clear_incident_hold(); _incident_seen.clear(); _incident_seen_ring.clear()
	_health=null; _account=null; _host=null

func snapshot() -> Dictionary:
	return {"attention29":_attention29.active,"source_id":_token.get("source_id",""),"phase":_phase,"reason":_reason,"goal":_goal.duplicate(true),"completed":_completed.duplicate(),"events":_journal.duplicate(true),"activity":_visit.snapshot() if _visit!=null else {},"walk":_walk.snapshot() if _walk!=null else {},"account":_account.snapshot() if _account!=null else {},"hospital51_stage":_hospital_stage,"hospital51_healed":_hospital_healed,"restaurant28_stage":_restaurant28_stage,"restaurant28_fed":_restaurant28_fed,"restaurant28_receipt":_restaurant28_receipt.duplicate(true),"restaurant28_route":_restaurant28.snapshot() if _restaurant28!=null else {},"roam51_active":_roam51_active,"economy28":_economy28.snapshot() if _economy28!=null else {},"sandbox28_action":_sandbox28_action,"routine58":_routine58.snapshot() if _routine58!=null else {},"home58":_home58.snapshot() if _home58!=null else {},"pending_needs":_dsh_task_queue.duplicate(),"source_rows_written":false,"profile_peaks":_profile_snapshot(),"controller_peaks":_controller_peaks.duplicate(true),"visit_timing":_visit_timing.duplicate(true),"visit_controller_timing":_visit_controller_timing.duplicate(true),"incident_waiting_release":_incident_waiting_release,"incident_hold_until":_incident_hold_until,"incident_seen":_incident_seen.size()}

func dispose() -> void:
	_attention29.clear(false)
	_ambient29_cancel("disposed")
	if _disposed or _busy: return
	if _home58 != null: _home58.cancel("disposed"); _home58=null
	if _rest_driver58 != null: _rest_driver58.cancel(); _rest_driver58=null
	if _routine58 != null: _routine58.clear()
	_hospital28_clear_treatment_pose()
	if _economy28 != null: _economy28.cancel("scheduler_disposed"); _economy28 = null
	_sandbox28_action = "walk"
	if _visit!=null:
		_visit.cancel("scheduler_disposed")
		# The host/scene owner keeps stepping until the physical owner releases.
		if not _visit.snapshot().get("released",false): _interrupting=true; return
		_visit.dispose(); _visit=null
	if _dsh_simple!=null: _dsh_simple.cancel(); _dsh_simple=null  # DSH_SIMPLEHOSP
	if _roam51!=null: _roam51.cancel(); _roam51=null
	if _restaurant28!=null: _restaurant28.cancel(); _restaurant28=null
	_restaurant28_stage=""; _restaurant28_meal_started=-1.0; _restaurant28_medical=false
	_hospital_support51=null
	_roam51_active=false
	_leisure58_abandon("dispose")
	if _walk!=null: _walk.dispose()
	ResDiag.unregister_life30(str(_token.get("source_id","")),self)
	_disposed=true; _phase="DISPOSED"; _factory=Callable()

func _ambient29_cancel(reason: String) -> void:
	if _ambient29 == null: return
	_ambient29.cancel(reason)
	if reason in ["death","disposed"]: _ambient29=null
	elif _phase=="AMBIENT": _phase="IDLE"; _next_decision=_now

func _ambient29_start(allowed: Array = []) -> bool:
	if _routine58_home_active(): return false
	if not _walk.cancel().get("ok",false): return false
	if _roam51 != null: _roam51.cancel()
	_roam51_active=false
	if _ambient29 == null:
		var candidate: RefCounted=Ambient29.new()
		if not candidate.configure(_host,_token,_dsh_life_scene(),_dsh_simple_map()): return false
		_ambient29=candidate
	if not _ambient29.try_begin(allowed): return false
	_phase="AMBIENT"; _goal={}; _reason=""
	return true

## DSH_RESERVE58: the seat reserved at goal-selection time is handed to the bench
## action at the bench. One claim, one seat, no second look for a free place.
func _ambient29_start_reserved() -> bool:
	if _routine58_home_active():
		_leisure58_abandon("home_priority")
		return false
	if _leisure58 == null: return false
	var lease: Dictionary = _leisure58.reserved_slot()
	if lease.is_empty(): return false
	if not _walk.cancel().get("ok",false):
		_leisure58_abandon("walk_cancel_refused")
		return false
	if _roam51 != null: _roam51.cancel()
	_roam51_active=false
	if _ambient29 == null:
		var candidate: RefCounted=Ambient29.new()
		if not candidate.configure(_host,_token,_dsh_life_scene(),_dsh_simple_map()):
			_leisure58_abandon("ambient_unavailable")
			return false
		_ambient29=candidate
	if not _ambient29.try_begin_reserved(lease,_leisure58):
		_leisure58_abandon("reserved_seat_refused")
		return false
	# The bench action now owns the claim; this life keeps no second copy of it.
	_leisure58.clear(_token.get("body"))
	_phase="AMBIENT"; _goal={}; _reason=""
	return true

## Routine58 emits intent; current service/home owners remain authoritative.
func _routine58_clock() -> RefCounted:
	var body: Node = _token.get("body")
	if not is_instance_valid(body) or not body.is_inside_tree(): return null
	var value: Variant = body.get_tree().root.get_meta("mafiozi_visual_clock", null)
	return value if value is RefCounted else null

func _routine58_home_active() -> bool:
	return _home58 != null and _home58.active()

func _routine58_rest_active() -> bool:
	return _routine58 != null and _phase in ["IDLE", "RESTING"] and not _routine58_home_active() and not _economy28_active() and not _roam51_active and _visit == null and not _dsh_simple_goal_active() and not _restaurant28_active()

func _routine58_hold(delta: float) -> void:
	# Stillness retains native gravity/contact; a removed floor never suspends a
	# resident in air until the next scheduled meal. No route is begun or reset.
	if _walk == null or str(_walk.get("_phase")) not in ["IDLE", "CANCELLED", "COMPLETE", "BLOCKED"]: return
	var body: CharacterBody3D = _token.body
	if _rest_driver58 == null:
		_rest_driver58 = PhysicalRoute51.new()
		if not _rest_driver58.configure(body): _rest_driver58=null; return
	var before: Vector3 = body.global_position
	_rest_driver58.hold(delta)
	var after: Vector3 = body.global_position
	var velocity: Vector3 = (after-before)/delta
	body.set_meta("npc_physical_drive51", {"frame":Engine.get_physics_frames(), "body_id":body.get_instance_id(), "from":before, "to":after, "velocity":velocity, "delta":delta, "walking":Vector2(velocity.x,velocity.z).length()>.03})

func _routine58_release_home(reason: String) -> bool:
	if not _routine58_home_active(): return true
	_home58.request_wake(reason)
	# Physical exit stays on the home owner's ticks before threat can own motion.
	return not _home58.active()

func _routine58_prepare_home() -> bool:
	if _home58 != null: return _home58.available()
	if _now < _home_retry58: return false
	_home_retry58 = _now + 8000.0
	var path := "res://scripts/homes/npc_home_controller58.gd"
	if not ResourceLoader.exists(path): return false
	var script: Script = load(path)
	if script == null: return false
	var candidate: RefCounted = script.new()
	if not candidate.configure(self, _dsh_life_scene(), _dsh_simple_map()): return false
	_home58 = candidate
	return _home58.available()

func _routine58_paid(visit: RefCounted, receipt: Dictionary) -> bool:
	if _disposed or _routine58 == null or visit != _economy28 or not visit.current_inside() or not visit._committed: return false
	if int(receipt.get("amount", 0)) < 5 or receipt.get("kind") not in ["local_shop_purchase28", "local_restaurant_purchase28"]: return false
	return _routine58.note_paid(str(receipt.get("routine_ticket58", "")), str(receipt.get("event_id", "")), str(visit._kind))

func _routine58_purchase_deferred() -> bool:
	if _economy28 == null or not _economy28.has_routine_pending58(): return false
	if dsh_energy_on() and _energy < 20.0: return false
	if _economy28.routine_deferred58(_now): return true
	return _routine58 != null and _routine58.home_intent(_routine58_clock()).get("kind", "") == "home_sleep"

func _routine58_step_home(delta: float, row: Dictionary) -> void:
	var clock: RefCounted = _routine58_clock()
	var desired: Dictionary = _routine58.home_intent(clock) if _routine58 != null else {}
	if _hospital51_below_threshold(row): _home58.request_wake("hospital")
	elif dsh_energy_on() and _energy < 20.0: _home58.request_wake("energy")
	elif desired.get("kind", "") != "home_sleep" and not _routine58_purchase_deferred() and _routine58 != null and not _routine58.due_purchase(clock).is_empty(): _home58.request_wake("scheduled_meal_or_supplies")
	elif desired.is_empty(): _home58.request_wake("wake_time")
	elif _home_intent58 != str(desired.kind): _home58.request_wake("routine_changed")
	if _health.should_pause_walk():
		_home58.request_wake("health_owner")
		return
	var result: String = _home58.step(delta, row)
	if not _home58.active():
		_phase="IDLE"; _goal={}; _home_intent58=""; _next_decision=_now
		if result == "blocked": _home_retry58=_now+8000.0

func _routine58_choose(row: Dictionary) -> void:
	if _routine58 == null:
		_phase="RESTING"; _next_decision=_now+1000.0; return
	# DSH_RESERVE58: a resident that already walked to a reserved seat takes THAT seat
	# before any new plan is made, so the reserved place is used and not re-chosen.
	if _leisure_arrived58 and _leisure58 != null and _leisure58.reserved_bench_id() != 0:
		if _ambient29_start_reserved():
			_leisure_arrived58=false
			return
	var clock: RefCounted = _routine58_clock()
	var intent: Dictionary = _routine58.choose(clock, _now, _routine58_purchase_deferred())
	var kind: String = str(intent.get("kind", ""))
	if kind in ["shop", "restaurant"]:
		if _economy28_prepare() and _economy28.request_routine58(kind, str(intent.ticket)):
			if _economy28_try_begin(row): return
	elif kind in ["home_sleep", "home_rest"] and _now >= _home_retry58:
		if _routine58_prepare_home() and _walk.cancel().get("ok",false):
			if _home58.begin(intent):
				_home_intent58=kind; _phase="HOME58"; _goal=_new_goal(kind); _reason=""; return
		_home_retry58 = _now + 8000.0
	elif kind == "leisure":
		if _leisure58_begin(): return
	if _leisure_arrived58 and kind not in ["home_sleep", "home_rest", "shop", "restaurant"]:
		_leisure_arrived58=false
		if _ambient29_start(["bench"]): return
	# A missing/destroyed/unreachable home is an explicit supported-stop fallback.
	# It never certifies sleeping, claims a bed, or labels a spawn point a home.
	if kind != "rest" and _ambient29_start(_routine58.ambient_choices(clock)): return
	# DSH_ROUTINE_ROAM58: without the flag this is the shipped v58 stop that reads as ten
	# residents standing still. With it the shipped random roam chooser decides instead,
	# exactly as the shipped (non-simple) path still does through _roam(). Stated trade:
	# random world walk targets return to the simple path, so a leg may have no purpose.
	if dsh_roam58_on() and kind != "rest":
		_roam()
		return
	_phase="RESTING"; _goal={}; _reason="routine_waiting_for_supported_activity"
	_next_decision=_now+1000.0
