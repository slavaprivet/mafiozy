extends "res://scripts/preview_population.gd"
## Explicit local city bootstrap; original source rows remain immutable.
const CityPolicy = preload("res://scripts/city/runtime/npc_city_world_policy.gd")
const CityDaily = preload("res://scripts/npc_city_daily.gd")
## The city navigation stack (city engine + city-era host) is ported into
## scripts/city/runtime/; release48's preview host keeps serving main.tscn.
const CityNavigation = preload("res://scripts/city/runtime/npc_city_navigation_host.gd")
const HospitalVisit = preload("res://scripts/hospital/npc_daily_hospital_visit.gd")
const BankVisit = preload("res://scripts/bank_geometry/npc_daily_bank_visit.gd")
const ShopVisit = preload("res://scripts/shop/npc_daily_shop.gd")
const CITY_PACKET := "b9c810e81b8b3da6afc048a32c4fe50745f32e4b15d0fd55ff876e69c35c54a1"
const CITY_PREPARED := "929a5083842a5325ba5d4d823b1ac63c8b56b459ac19b414057ce6190f35f288"
const CITY_BLOCK := "38b4b50ca06fb60172173b04c5b49ff567a84509ea01901a24306ab0d3b41dc7"
const CITY_DIRECTORY := "res://assets/npc_city/"
const IncidentDispatcher = preload("res://scripts/city/runtime/npc_incident_dispatcher.gd")
const ROAD_SHA := "dc77f6495d2657dff91106ca831cf41fb7f7c4ecb80e3211322999e74ad82f4b"
const SingleLifecycle28 = preload("res://scripts/hospital/npc_single_lifecycle28.gd")
var _single_lifecycle28: Node
var daily: RefCounted
var incident_dispatcher: RefCounted
var admission_results := {}
var daily_setup := {}
var city_ready := false
var _scene_ref: WeakRef
var _startup_us := 0
const FALLBACK_BUDGET_US := 2000
const FALLBACK_MAX_PROBES := 32
# POPULATION_RINGS19: bounded source placement extension; default 19, explicit 16 rollback.
var _city_fallback_ring_cache := -1
var _startup_progress := {"phase":"not_started","birth_attempts":0,"fallback_probes":0,"fallback_admitted":0,"fallback_yields":0,"health_bound":0,"last_source_id":"","last_reason":""}
const LOGIC_SAMPLE_CAPACITY := 2048
const LOGIC_PEAK_CAPACITY := 12
var _logic_samples := PackedInt64Array()
var _logic_frame_samples := PackedInt64Array()
var _logic_navigation_samples := PackedInt64Array()
var _logic_health_samples := PackedInt64Array()
var _logic_daily_samples := PackedInt64Array()
var _logic_resident_samples := PackedInt64Array()
var _logic_effect_samples := PackedInt64Array()
var _logic_unattributed_samples := PackedInt64Array()
var _logic_profiler_samples := PackedInt64Array()
var _logic_sample_count := 0
var _logic_cursor := 0
var _logic_peaks: Array[Dictionary] = []
var _logic_buckets: Dictionary = {}
var _logic_peak_frame: Dictionary = {}
var _startup_timing: Dictionary = {}
var _startup_frame_start := -1
var _startup_frame_end := -1
var _navigation_ready_wait_frames := 0
var _dsh_phys_last := 0  # DSH_QUERY_PROBE (temporary: physics-rate probe)
var _dsh_phys_ms := 0  # DSH_QUERY_PROBE
var _dsh_step_counters_ms := 0  # DSH_NAVDAILY: DSH_NAVSTEP wall-second window
var _dsh_step_counters := {}  # DSH_NAVDAILY: navigation step counters at window start
var _dsh_spf_ms := 0  # DSH_STEPSPERFRAME: wall-second window start
var _dsh_spf_window_drawn := 0  # DSH_STEPSPERFRAME: rendered frames at window start
var _dsh_spf_drawn := -1  # DSH_STEPSPERFRAME: drawn frame currently being counted
var _dsh_spf_steps := 0  # DSH_STEPSPERFRAME: whole-city steps inside that drawn frame
var _dsh_spf_h1 := 0  # DSH_STEPSPERFRAME
var _dsh_spf_h2 := 0  # DSH_STEPSPERFRAME
var _dsh_spf_h3 := 0  # DSH_STEPSPERFRAME
var _dsh_spf_steps_total := 0  # DSH_STEPSPERFRAME
var _dsh_load_cache := -1  # DSH_LOADBATCH
var _dsh_probe_cfg := -1  # DSH_LOADBATCH
var _dsh_load_ms := 0  # DSH_LOAD
var _dsh_load_started_ms := 0  # DSH_LOAD
# DSH_DAILYFX: fx-bucket split. The counters are locals inside the effects loop and
# are copied into these fields once per city step, so no per-owner allocation is added.
var _dsh_fx_blood_steps := 0  # DSH_DAILYFX: owners that executed blood.step()
var _dsh_fx_marks_steps := 0  # DSH_DAILYFX: owners that executed marks.step()
var _dsh_fx_active_steps := 0  # DSH_DAILYFX: of those, owners with live particles/wounds
var _dsh_fx_probe_cache := -1  # DSH_DAILYFX: --city-dailyfx-probe
var _dsh_fx_stagger_cache := -1  # DSH_DAILYFX: --city-fx-idle-stagger
var _dsh_fx_seeded := PackedByteArray()  # DSH_DAILYFX: owners whose idle phase was seeded
# DSH_FXIDLE: the blood pool of an owner that never emitted a particle is empty and
# invisible (npc_blood_renderer.gd:48 visible_instance_count=0), so the whole fx branch
# is bypassed for it. These are locals inside the effects loop, copied into fields once
# per city step, exactly like the DSH_DAILYFX counters above: no per-owner allocation.
var _dsh_fx_skipped_steps := 0  # DSH_FXIDLE: blood.step() calls removed in the last step
var _dsh_fx_bypass_steps := 0  # DSH_FXIDLE: owners whose blood branch was bypassed
var _dsh_fx_idle_skip_cache := -1  # DSH_FXIDLE: --city-fx-idle-skip
# DSH_STREAMLOAD: early readiness + budgeted, visibility-gated population streaming.
# Every flag defaults to today's behaviour: with no --city-early-cohort the blocking load
# below runs unchanged and _stream_on stays false.
const STREAM_CELL_M := 4.1  # DSH_STREAMLOAD: mirrors preview_resident_host._admit_record
const DailyAccount = preload("res://scripts/shop/npc_local_account.gd")
const DailyLife = preload("res://scripts/npc_daily_life.gd")
var _stream_flags_cache: Dictionary = {}
var _stream_on := false
var _stream_phase := "off"
var _stream_rows: Array = []
var _stream_pending_ids: Array = []
var _stream_done: Dictionary = {}
var _stream_held: Dictionary = {}
var _stream_cursor: Dictionary = {}
var _stream_bound: Dictionary = {}
var _stream_sorted: Array = []
var _stream_order_dirty := true
var _stream_order_camera := Vector3.ZERO
var _stream_active := ""
var _stream_gate_forced := false
var _stream_total := 0
var _stream_ready_us := 0
var _stream_ready_ms := 0
var _stream_all_us := 0
var _stream_credit_us := 0
var _stream_window := -1
var _stream_admits := 0
var _stream_forced := 0
var _stream_gate_skips := 0
var _stream_probes := 0
var _stream_probes_prev := 0
var _stream_unresolved := 0
var _stream_report_ms := 0
var _stream_items := 0
var _stream_charged_us := 0
var _stream_y := 0.0
var _stream_err := 0.0
var _stream_camera_ok := false
var _stream_daily_mode := "off"
var _stream_daily_failures := 0
var _stream_packet := PackedByteArray()
var _stream_trust: Dictionary = {}
var _stream_sites: Array[Node3D] = []
var _stream_fades: Array = []

# POPULATION_RINGS19: no source/body/health/owner admission is bypassed.
# 19*16=304 fallback slots stays below the host's existing 512-attempt cap.
# Batch/elapsed budgets and original ring/direction order remain unchanged.
func _city_fallback_max_ring() -> int:
	if _city_fallback_ring_cache < 0:
		_city_fallback_ring_cache = 19
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-spawn-rings="):
				_city_fallback_ring_cache = clampi(int(argument.trim_prefix("--city-spawn-rings=")), 16, 19)
	return _city_fallback_ring_cache

func _new_timing_bucket() -> Dictionary:
	return {"samples":0,"total_us":0,"max_us":0,"max_frame":-1}

func _new_logic_peak() -> Dictionary:
	return {"frame":-1,"total_us":0,"navigation_us":0,"health_us":0,"daily_us":0,"residents_us":0,"effects_us":0,"unattributed_us":0}

func _new_startup_bucket() -> Dictionary:
	return {"samples":0,"total_us":0,"max_us":0,"max_frame":-1,"max_source_id":""}

func _init() -> void:
	_logic_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_frame_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_navigation_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_health_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_daily_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_resident_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_effect_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_unattributed_samples.resize(LOGIC_SAMPLE_CAPACITY)
	_logic_profiler_samples.resize(LOGIC_SAMPLE_CAPACITY)
	for label: String in ["navigation_pump","health","daily","residents","effects","unattributed"]:
		_logic_buckets[label]=_new_timing_bucket()
	for label: String in ["configure","birth_admission","fallback_probe","health_bind","daily_configure"]:
		_startup_timing[label]=_new_startup_bucket()
	_logic_peak_frame=_new_logic_peak()
	for _index in LOGIC_PEAK_CAPACITY: _logic_peaks.append(_new_logic_peak())

# DSH_DAILYFX: --city-dailyfx-probe=1 adds the idle/active split of the fx bucket
# (two extra property reads per EXECUTING owner). 0 (default) leaves the counter
# cost at one integer add per executing owner and reports fx_active=0.
func _dsh_fx_probe() -> int:  # DSH_DAILYFX
	if _dsh_fx_probe_cache < 0:
		_dsh_fx_probe_cache = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-dailyfx-probe="):
				_dsh_fx_probe_cache = 1 if int(argument.trim_prefix("--city-dailyfx-probe=")) != 0 else 0
	return _dsh_fx_probe_cache

# DSH_ACCEPTED: the blood adapters' 250 ms idle refresh is staggered BY DEFAULT.
# --city-fx-idle-stagger=1 (default) spreads the whole cohort's refresh over that
# window instead of letting it start its timer inside the same city step; only an
# UNSET deadline is ever seeded, once per owner per run, so the documented 250 ms
# refresh bound is unchanged. --city-fx-idle-stagger=0 is the rollback: the seeding
# function is never called and every deadline stays byte for byte as before.
func _dsh_fx_stagger() -> int:  # DSH_DAILYFX
	if _dsh_fx_stagger_cache < 0:
		_dsh_fx_stagger_cache = 1  # DSH_ACCEPTED: fx-idle-stagger включён по умолчанию; --city-fx-idle-stagger=0 откатывает
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-fx-idle-stagger="):
				_dsh_fx_stagger_cache = 1 if int(argument.trim_prefix("--city-fx-idle-stagger=")) != 0 else 0
	return _dsh_fx_stagger_cache

# DSH_DAILYFX: seed an UNSTARTED blood adapter's idle deadline with a stable
# per-owner phase inside the SAME 250 ms window, so the cohort refreshes as a
# trickle instead of a herd. Only a deadline that is still unset (<0) is written,
# once per owner per run, so the documented 250 ms refresh bound is unchanged.
func _dsh_fx_stagger_cohort() -> void:  # DSH_DAILYFX
	var total:=hit_owners.size()
	if total<=0 or _dsh_fx_seeded.size()==total: return
	_dsh_fx_seeded.resize(total)
	var now_us:=Time.get_ticks_usec()
	for index in total:
		if int(_dsh_fx_seeded[index])!=0: continue
		_dsh_fx_seeded[index]=1
		var owner: RefCounted=hit_owners[index]
		if owner==null: continue
		var blood: Variant=owner.get("blood")
		if blood==null or blood.get("renderer")==null: continue
		var idle: Variant=blood.get("_idle_checked_at_usec")
		if idle is int and int(idle)<0:
			blood.set("_idle_checked_at_usec",now_us-int(250000.0*float(index)/float(total)))

# DSH_FXSLICE: --city-fx-slice=N serves at most N IDLE blood owners per city step in a
# rotating order, so the cohort's 250 ms idle refresh cannot land in one step. An owner
# whose effects are live (particles or wounds) is never deferred. Accepted default 64;
# --city-fx-slice=0 runs every due owner, exactly as before.
var _dsh_fx_slice_cache := -1  # DSH_FXSLICE
var _dsh_fx_cursor := 0  # DSH_FXSLICE: rotating start of the served window
var _dsh_fx_deferred_steps := 0  # DSH_FXSLICE: idle owners deferred in the last step

func _dsh_fx_slice() -> int:  # DSH_FXSLICE
	if _dsh_fx_slice_cache < 0:
		_dsh_fx_slice_cache = 64
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-fx-slice="):
				_dsh_fx_slice_cache = maxi(0, int(argument.trim_prefix("--city-fx-slice=")))
	return _dsh_fx_slice_cache

func _dsh_fx_live(blood: RefCounted) -> bool:  # DSH_FXSLICE
	var renderer: Variant=blood.get("renderer")
	if renderer==null: return false
	var wounds: Variant=renderer.get("_wounds")
	return bool(renderer.get("_has_particles")) or (wounds is Array and not (wounds as Array).is_empty())

# DSH_FXIDLE: --city-fx-idle-skip=1 (default) bypasses the blood branch of an owner that
# has never emitted a particle; 0 is the exact rollback (every gate, every deadline and
# every lease check where and when it runs today). Same cached-reader shape as every
# other lever in this file.
func _dsh_fx_idle_skip() -> int:  # DSH_FXIDLE
	if _dsh_fx_idle_skip_cache < 0:
		_dsh_fx_idle_skip_cache = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-fx-idle-skip="):
				_dsh_fx_idle_skip_cache = 0 if int(argument.trim_prefix("--city-fx-idle-skip=")) == 0 else 1
	return _dsh_fx_idle_skip_cache

# DSH_FXIDLE: the sticky "never bloodied" answer plus the ONE side effect of the
# skipped update() that would be observable later.
#   * "never bloodied" == renderer.emitted==0. `emitted` is incremented inside
#     npc_blood_renderer._emit():64, which accept():68 calls before it appends any
#     wound, and it is NOT reset by clear():149-151 or dispose():153-156. It therefore
#     separates "never bled" from "bled and healed": _wounds empties again at :104-105
#     and _has_particles drops back to false at :145, `emitted` never returns to 0.
#   * update() at empty state is a no-op EXCEPT :102 (_last_root=_body.global_position),
#     the baseline of the teleport test at :101. A resident that walks further than
#     maxf(1.0,_height*4) since its last update is classified as teleported, and :103
#     then does `_life.fill(0); _has_particles=false`. Without the write below the
#     baseline would go stale for thousands of steps and the FIRST update after a wound
#     would erase the freshly accepted burst (:68) and delay the first drip (:108).
#     Writing the same value :102 writes makes that impossible; it is exactly what
#     update() would have stored had it run at this step.
#   * `_last_time` (:100) only serves the backwards-clock test, and _now() is derived
#     from a per-owner fixed _start_us, so it cannot move backwards. _wounds is empty,
#     _next_emission is only read when a wound exists (:109-113), `if active!=0` (:126)
#     is false and _life is already all <=0. None of them is reproduced because none of
#     them can be observed.
#   * A missing body node is NOT bypassed: today's path then keeps running the lease
#     check, so a pool whose owner died or was removed is still retired by
#     npc_blood_adapter.retire():85-88 within the 250 ms bound.
# Returns 0 = run today's path, 1 = bypassed (deadline not due), 2 = bypassed
# (deadline was due: one blood.step() call removed from this city step).
func _dsh_fx_idle_bypass(blood: RefCounted, now_us: int) -> int:  # DSH_FXIDLE
	var renderer: Variant=blood.get("renderer")
	if renderer==null or int(renderer.get("emitted"))!=0: return 0
	var body: Variant=renderer.get("_body")
	if body==null or not is_instance_valid(body): return 0
	renderer.set("_last_root",(body as Node3D).global_position)
	var idle: Variant=blood.get("_idle_checked_at_usec")
	if idle is int and (int(idle)<0 or now_us-int(idle)>=250000): return 2
	return 1

func _record_timing(label: String, elapsed: int, frame: int) -> void:
	var bucket: Dictionary=_logic_buckets[label]
	bucket["samples"]=int(bucket["samples"])+1
	bucket["total_us"]=int(bucket["total_us"])+elapsed
	if elapsed>int(bucket["max_us"]):
		bucket["max_us"]=elapsed
		bucket["max_frame"]=frame

func _record_startup_timing(label: String, started: int, frame: int, source_id: String="") -> void:
	var elapsed:=Time.get_ticks_usec()-started
	var bucket: Dictionary=_startup_timing[label]
	bucket["samples"]=int(bucket["samples"])+1
	bucket["total_us"]=int(bucket["total_us"])+elapsed
	if elapsed>int(bucket["max_us"]):
		bucket["max_us"]=elapsed; bucket["max_frame"]=frame; bucket["max_source_id"]=source_id

func _logic_frame_trace() -> Dictionary:
	# Packed columns keep per-frame storage fixed-size and do not allocate rows on
	# the hot path. At capacity, next_write_index is the oldest chronological slot.
	return {"capacity":LOGIC_SAMPLE_CAPACITY,"sample_count":_logic_sample_count,
		"next_write_index":_logic_cursor,"frames":_logic_frame_samples.duplicate(),
		"total_us":_logic_samples.duplicate(),"navigation_us":_logic_navigation_samples.duplicate(),
		"health_us":_logic_health_samples.duplicate(),"daily_us":_logic_daily_samples.duplicate(),
		"residents_us":_logic_resident_samples.duplicate(),"effects_us":_logic_effect_samples.duplicate(),
		"unattributed_us":_logic_unattributed_samples.duplicate(),
		"profiler_write_us":_logic_profiler_samples.duplicate(),
		"logic_including_profiler_us":_logic_inclusive_samples()}

func _logic_inclusive_samples() -> PackedInt64Array:
	var inclusive:=PackedInt64Array()
	inclusive.resize(LOGIC_SAMPLE_CAPACITY)
	for index in LOGIC_SAMPLE_CAPACITY: inclusive[index]=_logic_samples[index]+_logic_profiler_samples[index]
	return inclusive

func _store_logic_peak(frame: int, total_us: int, navigation_us: int, health_us: int, daily_us: int, residents_us: int, effects_us: int, unattributed_us: int) -> void:
	var minimum_index:=0
	for index in range(1,_logic_peaks.size()):
		if int(_logic_peaks[index]["total_us"])<int(_logic_peaks[minimum_index]["total_us"]): minimum_index=index
	if total_us<=int(_logic_peaks[minimum_index]["total_us"]): return
	var peak: Dictionary=_logic_peaks[minimum_index]
	peak["frame"]=frame; peak["total_us"]=total_us; peak["navigation_us"]=navigation_us
	peak["health_us"]=health_us; peak["daily_us"]=daily_us; peak["residents_us"]=residents_us
	peak["effects_us"]=effects_us; peak["unattributed_us"]=unattributed_us

func _startup_current(scene: Node3D) -> bool:
	return not _disposed and _scene_ref!=null and _scene_ref.get_ref()==scene and is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene.get("preview_population")==self

# DSH_LOADBATCH: per-physics-tick budget for the load loops. 0 (default) is exactly the
# source behaviour: one resident per physics tick, so every default stays unchanged.
func _dsh_load_batch_us() -> int:
	if _dsh_load_cache < 0:
		_dsh_load_cache = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-load-batch-ms="):
				_dsh_load_cache = maxi(0, int(argument.trim_prefix("--city-load-batch-ms="))) * 1000
	return _dsh_load_cache

# DSH_LOADBATCH: probe-loop budget. FALLBACK_BUDGET_US (2000 us) is smaller than one
# placement probe, so the source loop yields after every single probe; the flag raises
# that per-tick bound only - probe order, the acceptance test and the 32-probe cap are
# untouched.
func _dsh_load_probe_us() -> int:
	if _dsh_probe_cfg < 0:
		_dsh_probe_cfg = FALLBACK_BUDGET_US
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-load-probe-budget-ms="):
				_dsh_probe_cfg = maxi(FALLBACK_BUDGET_US, int(argument.trim_prefix("--city-load-probe-budget-ms=")) * 1000)
	return _dsh_probe_cfg

func _dsh_avg_ms(bucket: Dictionary) -> String:
	var samples:=int(bucket["samples"])
	return "0.0" if samples<=0 else "%.1f" % (float(bucket["total_us"])/float(samples)/1000.0)

# DSH_LOAD (intentional, keep): one line per wall second while the city loads. The
# per-item buckets below are already recorded for free by setup_city, so this print is
# the measurement that decides where the load time belongs: an avg close to the whole
# physics frame means per-ITEM cost, an avg of a few ms means the one-item-per-tick
# CADENCE.
func _dsh_load_report(phase: String, done: int, total: int) -> void:
	var now:=Time.get_ticks_msec()
	if _dsh_load_ms==0:
		_dsh_load_ms=now; _dsh_load_started_ms=now; return
	if now-_dsh_load_ms<1000: return
	_dsh_load_ms=now
	var birth: Dictionary=_startup_timing["birth_admission"]
	var probe: Dictionary=_startup_timing["fallback_probe"]
	var bound: Dictionary=_startup_timing["health_bind"]
	print("DSH_LOAD phase=",phase," t=","%.1f" % (float(now-_dsh_load_started_ms)/1000.0),"s done=",done,"/",total,
		" birth n=",int(birth["samples"])," avg_ms=",_dsh_avg_ms(birth)," max_ms=","%.1f" % (float(birth["max_us"])/1000.0),
		" probe n=",int(probe["samples"])," avg_ms=",_dsh_avg_ms(probe)," max_ms=","%.1f" % (float(probe["max_us"])/1000.0),
		" bind n=",int(bound["samples"])," avg_ms=",_dsh_avg_ms(bound)," max_ms=","%.1f" % (float(bound["max_us"])/1000.0),
		" batch_ms=",int(_dsh_load_batch_us()/1000)," probe_budget_ms=",int(_dsh_load_probe_us()/1000))

# DSH_STREAMLOAD: one cached flag scan. Defaults are today's behaviour:
#   --city-early-cohort=N   0 = OFF; N>=1 = report ready after the first N rows, stream the rest
#   --city-stream-ms=N      0 = one item per physics tick (control cadence); N>0 = rolling
#                           credit of N ms per rendered frame (per physics tick when headless)
#   --city-stream-order=dist|packet   dist (default) = nearest first from the camera
#   --city-stream-vis=0|1   1 (default) = hold a row back while its next spawn point is visible
#   --city-stream-hold-s=X  5.0 (default) = admit a held row anyway after X wall seconds
#   --city-stream-order-refresh-m=X  4.0 (default) = rebuild the distance order after X m
#   --city-stream-fade=MS   0 = OFF; fade a forced (visible) admission in over MS milliseconds
func _stream_flags() -> Dictionary:
	if _stream_flags_cache.is_empty():
		var cfg := {"cohort":0,"budget_us":0,"order":"dist","vis":1,"hold_ms":5000,"refresh_m":4.0,"fade_ms":0}
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-early-cohort="):
				cfg["cohort"] = maxi(0, int(argument.trim_prefix("--city-early-cohort=")))
			elif argument.begins_with("--city-stream-ms="):
				cfg["budget_us"] = maxi(0, int(argument.trim_prefix("--city-stream-ms="))) * 1000
			elif argument.begins_with("--city-stream-order="):
				cfg["order"] = "packet" if argument.trim_prefix("--city-stream-order=") == "packet" else "dist"
			elif argument.begins_with("--city-stream-vis="):
				cfg["vis"] = 0 if int(argument.trim_prefix("--city-stream-vis=")) == 0 else 1
			elif argument.begins_with("--city-stream-hold-s="):
				cfg["hold_ms"] = maxi(0, roundi(float(argument.trim_prefix("--city-stream-hold-s=")) * 1000.0))
			elif argument.begins_with("--city-stream-order-refresh-m="):
				cfg["refresh_m"] = maxf(0.0, float(argument.trim_prefix("--city-stream-order-refresh-m=")))
			elif argument.begins_with("--city-stream-fade="):
				cfg["fade_ms"] = maxi(0, int(argument.trim_prefix("--city-stream-fade=")))
		_stream_flags_cache = cfg
	return _stream_flags_cache

# DSH_STREAMLOAD: read-only seam for the bootstrap. `complete` is also true when streaming
# is off, so a default run never takes the streaming branch anywhere.
func city_stream_complete() -> bool:
	return _stream_phase == "complete" or _stream_phase == "off"

func city_stream_pending() -> int:
	return _stream_pending_ids.size()

func city_stream_report() -> Dictionary:
	return {"enabled":_stream_on,"phase":_stream_phase,"pending":_stream_pending_ids.size(),
		"total":_stream_total,"admits":_stream_admits,"bound":hit_owners.size(),
		"forced":_stream_forced,"unresolved":_stream_unresolved,"probes":_stream_probes,
		"ready_us":_stream_ready_us,"all_us":_stream_all_us,"daily_mode":_stream_daily_mode,
		"daily_failures":_stream_daily_failures,"point_error_m":_stream_err,
		"flags":_stream_flags().duplicate()}

# DSH_STREAMLOAD: the exact world point preview_resident_host._admit_record() would use for
# this row and this ring candidate, so the visibility test happens before the body exists.
# Cursor.x == 0 is the source birth point; ring/direction match the source fallback loop.
func _stream_point(record: Dictionary, cursor: Vector2i) -> Vector3:
	var raw: Dictionary = record.row.source_raw
	var r := float(raw.r)
	var c := float(raw.c)
	if cursor.x > 0:
		var angle := TAU * float(cursor.y) / 16.0
		r += sin(angle) * float(cursor.x) * .5
		c += cos(angle) * float(cursor.x) * .5
	return Vector3(c * STREAM_CELL_M - CityPolicy.ORIGIN.x, _stream_y, r * STREAM_CELL_M - CityPolicy.ORIGIN.z)

# DSH_STREAMLOAD: 0 = clear, 1 = held (visible right now), 2 = held too long, admit anyway.
# The test is Camera3D.is_position_in_frustum(): the cheapest CORRECT single call - it uses
# the camera's own frustum planes, needs no viewport size or projection/unprojection work,
# allocates nothing per candidate, and unlike unproject_position() it stays correct for a
# point behind the camera or beyond the far plane. The camera is resolved once per tick.
func _stream_gate(camera: Camera3D, record: Dictionary, clock: int) -> int:
	if int(_stream_flags()["vis"]) == 0: return 0
	var id: String = record.row.source_id
	var held_since: int = int(_stream_held.get(id, -1))
	if held_since < 0:
		_stream_held[id] = clock
		held_since = clock
	var hold_ms: int = int(_stream_flags()["hold_ms"])
	if hold_ms > 0 and clock - held_since >= hold_ms: return 2
	if camera == null: return 0
	var cursor: Vector2i = _stream_cursor.get(id, Vector2i.ZERO)
	if camera.is_position_in_frustum(_stream_point(record, cursor)): return 1
	_stream_held.erase(id)
	return 0

# DSH_STREAMLOAD: nearest-first order from the camera. Rebuilt after every admission and
# whenever the camera has moved --city-stream-order-refresh-m metres, so the walk below
# starts at the closest pending row without sorting inside the per-tick path.
func _stream_rebuild_order(camera: Camera3D) -> void:
	var origin := Vector3.ZERO
	if camera != null: origin = camera.global_position
	_stream_sorted = []
	if str(_stream_flags()["order"]) == "packet":
		for row: Dictionary in _stream_rows:
			var pid: String = row.source_id
			if not _stream_done.has(pid): _stream_sorted.append(pid)
	else:
		var ranked: Array = []
		for row: Dictionary in _stream_rows:
			var rid: String = row.source_id
			if _stream_done.has(rid): continue
			var record: Dictionary = residents._records[rid]
			var cursor: Vector2i = _stream_cursor.get(rid, Vector2i.ZERO)
			ranked.append([_stream_point(record, cursor).distance_squared_to(origin), rid])
		ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for entry: Array in ranked: _stream_sorted.append(entry[1])
	_stream_order_dirty = false
	_stream_order_camera = origin

# DSH_STREAMLOAD: choose the row to work on. A row whose ring search is already running
# keeps it (the source fallback loop also finishes one resident before the next), but a row
# that is visible right now never blocks the queue behind it: the next nearest clear row is
# picked instead and the held row resumes from its own cursor later.
func _stream_pick(camera: Camera3D, clock: int) -> String:
	var refresh: float = float(_stream_flags()["refresh_m"])
	if _stream_order_dirty or (_stream_sorted.is_empty() and not _stream_pending_ids.is_empty()):
		_stream_rebuild_order(camera)
	elif camera != null and _stream_order_camera.distance_squared_to(camera.global_position) > refresh * refresh:
		_stream_rebuild_order(camera)
	if not _stream_active.is_empty():
		if not _stream_done.has(_stream_active):
			var active_record: Dictionary = residents._records[_stream_active]
			var active_gate: int = _stream_gate(camera, active_record, clock)
			if active_gate != 1:
				_stream_gate_forced = active_gate == 2
				return _stream_active
		_stream_active = ""
	for id: String in _stream_sorted:
		if _stream_done.has(id): continue
		var record: Dictionary = residents._records[id]
		var gate: int = _stream_gate(camera, record, clock)
		if gate == 0:
			_stream_gate_forced = false
			_stream_active = id
			return id
		if gate == 2:
			_stream_gate_forced = true
			_stream_active = id
			return id
		_stream_gate_skips += 1
	return ""

# DSH_STREAMLOAD: charge the measured cost of one streamed item to the rolling budget.
func _stream_charge(started_us: int) -> void:
	var cost_us := Time.get_ticks_usec() - started_us
	_stream_items += 1
	_stream_charged_us += cost_us
	if int(_stream_flags()["budget_us"]) > 0: _stream_credit_us -= cost_us

# DSH_STREAMLOAD (new marker, no existing print touched): one line per wall second while
# the population streams. pending/bound is the population state, held/gate_skips/forced is
# the visibility gate, charged_ms/items is what the budget actually paid for this second.
func _stream_report() -> void:
	var now := Time.get_ticks_msec()
	var origin: int = _dsh_load_started_ms if _dsh_load_started_ms > 0 else now
	if _stream_report_ms == 0:
		_stream_report_ms = now
		return
	if now - _stream_report_ms < 1000: return
	var window_ms := now - _stream_report_ms
	_stream_report_ms = now
	var probes_s := _stream_probes - _stream_probes_prev
	_stream_probes_prev = _stream_probes
	print("DSH_STREAMLOAD s=", "%.1f" % (float(now - origin) / 1000.0),
		" pending=", _stream_pending_ids.size(), " bound=", hit_owners.size(), " admits=", _stream_admits,
		" forced=", _stream_forced, " held=", _stream_held.size(), " gate_skips=", _stream_gate_skips,
		" probes=", _stream_probes, " probes_s=", "%.1f" % (float(probes_s) * 1000.0 / float(maxi(1, window_ms))),
		" charged_ms=", int(_stream_charged_us / 1000), " items=", _stream_items,
		" budget_ms=", int(int(_stream_flags()["budget_us"]) / 1000), " order=", str(_stream_flags()["order"]),
		" vis=", int(_stream_flags()["vis"]), " cam=", 1 if _stream_camera_ok else 0,
		" daily=", _stream_daily_mode, " unresolved=", _stream_unresolved, " err_m=", "%.2f" % _stream_err)
	_stream_gate_skips = 0
	_stream_charged_us = 0
	_stream_items = 0

# DSH_STREAMLOAD: the source fallback ring/direction search, resumable across ticks. Ring
# 1..16 x direction 0..15 is exactly the source order, the cursor is advanced only after a
# completed authority call, so no probe is repeated or skipped when the batch budget ends
# mid-search. Returns 1 = placed, 0 = more probes pending, 2 = search exhausted.
func _stream_ring(id: String, raw: Dictionary) -> int:
	var cursor: Vector2i = _stream_cursor.get(id, Vector2i(1, 0))
	var ring: int = maxi(1, cursor.x)
	var direction: int = cursor.y
	var budget_probe_us: int = _dsh_load_probe_us()
	var batch_started := Time.get_ticks_usec()
	var batch_probes := 0
	var max_ring: int = _city_fallback_max_ring()
	while ring <= max_ring:
		var angle := TAU * float(direction) / 16.0
		var probe_started := Time.get_ticks_usec()
		var result: Dictionary = residents.admit_city_spawn(id, float(raw.r) + sin(angle) * float(ring) * .5, float(raw.c) + cos(angle) * float(ring) * .5)
		_record_startup_timing("fallback_probe", probe_started, Engine.get_physics_frames(), id)
		admission_results[id] = result
		batch_probes += 1
		_stream_probes += 1
		_startup_progress.fallback_probes += 1
		_startup_progress.last_source_id = id
		_startup_progress.last_reason = str(result.get("reason", ""))
		if ring == 1 and direction == 0:
			print("DSH_PROBE ", id, " ", JSON.stringify(result))
		direction += 1
		if direction >= 16:
			direction = 0
			ring += 1
		if result.get("status") == "IDLE":
			_startup_progress.fallback_admitted += 1
			_stream_cursor.erase(id)
			return 1
		if ring <= max_ring: _stream_cursor[id] = Vector2i(ring, direction)
		if batch_probes >= FALLBACK_MAX_PROBES or Time.get_ticks_usec() - batch_started >= budget_probe_us:
			_startup_progress.fallback_yields += 1
			_dsh_load_report("fallback_placement", int(_startup_progress.fallback_admitted), _stream_total)
			return 0
	_stream_cursor.erase(id)
	return 2

# DSH_STREAMLOAD: the health_binding body of setup_city, per resident, in the same tick
# that admitted the body - so no admitted resident is ever without its health owner (the
# blocking loop had no such window either), and the streamed resident joins the daily
# cycle exactly where the blocking run would have registered it.
func _stream_bind_health(scene: Node3D, id: String) -> bool:
	var record: Dictionary = residents._records[id]
	if not is_instance_valid(record.body): return true
	var health_started:=Time.get_ticks_usec()
	var health:=LocalHits.new()
	var token: Dictionary=residents.target_from_collider(record.body)
	var linked: Dictionary=health.configure(residents,token,_stream_packet,_stream_trust,scene.preview_weapons,{"marksman":0.0,"scope":"local_new_session","session_id":SESSION})
	if not linked.get("ok",false):
		health.dispose(); _fail("city_health:"+str(linked)); return false
	_record_startup_timing("health_bind",health_started,Engine.get_physics_frames(),id)
	hit_owners.append(health); record.walk_pause=Callable(health,"should_pause_walk")
	_stream_bound[id]=true
	_startup_progress.health_bound=hit_owners.size()
	_startup_progress.last_source_id=id
	_dsh_load_report("health_binding",hit_owners.size(),_stream_total)
	if _stream_daily_mode == "incremental" and not _stream_register_daily(id,health): _stream_daily_failures+=1
	return true

# DSH_STREAMLOAD: register one late resident with the ALREADY configured daily host, using
# exactly what npc_city_daily.configure() uses for the cohort (same objects, same order,
# same bookkeeping). That owner file builds _lives/_accounts/_health once from
# population.hit_owners and rejects a second configure(), so this is the only way a resident
# that streams in later can join the same daily cycle without editing that file.
func _stream_register_daily(id: String, owner: RefCounted) -> bool:
	if daily == null: return false
	var lives: Variant = daily.get("_lives")
	var accounts: Variant = daily.get("_accounts")
	var health: Variant = daily.get("_health")
	var failures: Variant = daily.get("_failures")
	if not lives is Dictionary or not accounts is Dictionary or not health is Dictionary or not daily.has_method("_create_visit"): return false
	var token: Dictionary=owner.get("_token")
	if not residents.target_current(token): return false
	var account:=DailyAccount.new()
	var admitted: Dictionary=account.configure(residents,token,owner)
	if not admitted.get("ok",false):
		if failures is Dictionary: failures[id]=admitted
		return false
	var scene: Node3D = _scene_ref.get_ref() if _scene_ref!=null else null
	var bank_bound: Dictionary = account.bind_bank(scene) if is_instance_valid(scene) else {"ok":false,"reason":"scene_unavailable"}
	if not bank_bound.get("ok",false):
		account.dispose()
		if failures is Dictionary: failures[id]=bank_bound
		return false
	var life:=DailyLife.new()
	var active: Dictionary=life.configure(residents,token,owner,account,policy,Callable(daily,"_create_visit").bind(id))
	if not active.get("ok",false):
		life.dispose(); account.dispose()
		if failures is Dictionary: failures[id]=active
		return false
	(lives as Dictionary)[id]=life
	(accounts as Dictionary)[id]=account
	(health as Dictionary)[id]=owner
	return true

# DSH_STREAMLOAD: fade a forced (visible) admission in instead of popping it. OFF by
# default: instance transparency moves the resident's meshes into the transparent pass for
# the duration, which is a rendering change that has to be eyeballed before it is trusted.
func _stream_fade_begin(id: String) -> void:
	var ms: int = int(_stream_flags()["fade_ms"])
	if ms <= 0: return
	var record: Dictionary = residents._records[id]
	if not is_instance_valid(record.body): return
	var nodes: Array = record.body.find_children("*", "GeometryInstance3D", true, false)
	if nodes.is_empty(): return
	for node: Node in nodes: (node as GeometryInstance3D).transparency = 1.0
	_stream_fades.append({"nodes":nodes,"ms":ms,"t":0.0})

func _stream_fades_step(delta: float) -> void:
	for index in range(_stream_fades.size() - 1, -1, -1):
		var fade: Dictionary = _stream_fades[index]
		fade["t"] = float(fade["t"]) + delta * 1000.0
		var span := maxf(1.0, float(fade["ms"]))
		var left := clampf(1.0 - float(fade["t"]) / span, 0.0, 1.0)
		for node: Node in fade["nodes"]:
			if is_instance_valid(node): (node as GeometryInstance3D).transparency = left
		if left <= 0.0: _stream_fades.remove_at(index)

# DSH_STREAMLOAD: the per-tick streaming pass. At most ONE admission per call - the same
# one-item-per-tick cadence the blocking load uses - with the rolling per-frame budget as
# the only throttle, and the frustum gate deciding which pending row may be admitted now.
# The body comes from the same admit_city_spawn() call the source fallback loop uses, at the
# same point and in the same ring/direction order, so no resident loses its search space.
func _stream_tick(scene: Node3D, delta: float) -> void:
	if not _stream_fades.is_empty(): _stream_fades_step(delta)
	if _stream_phase != "streaming": return
	if not _startup_current(scene): return
	if _stream_pending_ids.is_empty():
		_stream_finish(scene)
		return
	var budget_us: int = int(_stream_flags()["budget_us"])
	var window: int = Engine.get_frames_drawn()
	if window <= 0: window = -Engine.get_physics_frames()
	if window != _stream_window:
		_stream_window = window
		if budget_us > 0: _stream_credit_us = mini(_stream_credit_us + budget_us, budget_us)
	if budget_us > 0 and _stream_credit_us < 0:
		_stream_report()
		return
	var viewport: Viewport = scene.get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	_stream_camera_ok = is_instance_valid(camera)
	var id: String = _stream_pick(camera, Time.get_ticks_msec())
	if id.is_empty():
		_stream_report()
		return
	var forced: bool = _stream_gate_forced
	var started_us := Time.get_ticks_usec()
	var record: Dictionary = residents._records[id]
	var raw: Dictionary = record.row.source_raw
	var body_ok := false
	if not bool(record.get("attempted", false)) and not _stream_cursor.has(id):
		# The source birth attempt, with the same guard order as admit_next() and the birth loop.
		var probe_started := Time.get_ticks_usec()
		var result: Dictionary = residents.admit_city_spawn(id, float(raw.r), float(raw.c))
		if _startup_progress.birth_attempts < 5:
			print("DSH_ADMIT ", id, " ", JSON.stringify(result))
		_record_startup_timing("birth_admission", probe_started, Engine.get_physics_frames(), id)
		_startup_progress.birth_attempts += 1
		_startup_progress.last_source_id = id
		admission_results[id] = result
		_stream_probes += 1
		body_ok = is_instance_valid(residents._records[id].body)
		var expected: Vector3 = _stream_point(record, Vector2i.ZERO)
		if body_ok:
			var actual: Vector3 = residents._records[id].body.global_position
			_stream_err = maxf(_stream_err, Vector2(expected.x - actual.x, expected.z - actual.z).length())
		else:
			_stream_cursor[id] = Vector2i(1, 0)
	else:
		var state: int = _stream_ring(id, raw)
		body_ok = is_instance_valid(residents._records[id].body)
		if state == 2 and not body_ok:
			# The source fallback loop also leaves a resident unplaced once its bounded search
			# is exhausted; the count is reported instead of being skipped silently.
			_stream_unresolved += 1
			_stream_done[id] = true
			_stream_pending_ids.erase(id)
			_stream_held.erase(id)
	if body_ok:
		_stream_admits += 1
		_stream_y = residents._records[id].body.global_position.y
		if forced:
			_stream_forced += 1
			if int(_stream_flags()["fade_ms"]) > 0: _stream_fade_begin(id)
		if not _stream_bound.has(id):
			if not _stream_bind_health(scene, id): return
		_stream_done[id] = true
		_stream_pending_ids.erase(id)
		_stream_cursor.erase(id)
		_stream_held.erase(id)
		# Only a completed placement changes what the nearest-first order means; a mere probe
		# leaves it valid, and the camera-move trigger already covers the other case.
		_stream_order_dirty = true
	_stream_charge(started_us)
	_stream_report()

# DSH_STREAMLOAD: early readiness. Geometry, both sites, the navigation map and the first
# cohort are in place, so city_ready becomes true here and the remaining rows are handed to
# the per-tick stream instead of blocking setup_city. status keeps today's exact formula.
func _stream_begin(scene: Node3D, parsed: Dictionary, qa_source_ids: Array[String], packet: PackedByteArray, trust: Dictionary, sites: Array[Node3D], started_us: int) -> bool:
	_stream_total = parsed.rows.size()
	_stream_packet = packet
	_stream_trust = trust.duplicate(true)
	_stream_sites = sites.duplicate()
	_stream_rows = []
	_stream_pending_ids = []
	_stream_done.clear()
	_stream_cursor.clear()
	_stream_held.clear()
	_stream_bound.clear()
	_stream_sorted = []
	_stream_order_dirty = true
	_stream_active = ""
	for row: Dictionary in parsed.rows:
		if not qa_source_ids.is_empty() and row.source_id not in qa_source_ids: continue
		_stream_rows.append(row)
		# Only rows that still have no body are pending: the cohort is already placed, and a
		# placed row must never be handed to the placement search again.
		if is_instance_valid(residents._records[row.source_id].body):
			_stream_done[row.source_id] = true
		else:
			_stream_pending_ids.append(row.source_id)
	var viewport: Viewport = scene.get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	_stream_y = camera.global_position.y - 1.6 if is_instance_valid(camera) else 0.0
	_stream_ready_us = Time.get_ticks_usec()
	_stream_ready_ms = Time.get_ticks_msec()
	if not _configure_daily(scene, sites, true): return false
	_stream_phase = "streaming"
	city_ready = true
	status = "ready" if hit_owners.size() == _stream_total else "pending_placement"
	_startup_progress.phase = "streaming"
	_startup_us = Time.get_ticks_usec() - started_us
	_startup_frame_end = Engine.get_physics_frames()
	print("DSH_STREAMLOAD ready t=", "%.1f" % (float(_stream_ready_ms - _dsh_load_started_ms) / 1000.0), "s",
		" city_ready=", city_ready, " phase=", str(_startup_progress.get("phase", "")),
		" cohort=", hit_owners.size(), "/", _stream_total, " pending=", _stream_pending_ids.size(),
		" sites=", sites.size(), " nav=", navigation.state(),
		" budget_ms=", int(int(_stream_flags()["budget_us"]) / 1000), " order=", str(_stream_flags()["order"]),
		" vis=", int(_stream_flags()["vis"]), " hold_s=", "%.1f" % (float(int(_stream_flags()["hold_ms"])) / 1000.0),
		" fade_ms=", int(_stream_flags()["fade_ms"]), " daily=", _stream_daily_mode)
	return true

# DSH_STREAMLOAD: the stream is over. Nothing is left half-done: every pending row either
# has its body or has exhausted its search, the daily host is configured for the complete
# population (deferred mode) and status/phase end exactly where the blocking run ends.
func _stream_finish(scene: Node3D) -> void:
	if _stream_phase != "streaming": return
	if _stream_daily_mode == "deferred":
		if not _configure_daily(scene, _stream_sites): return
	var daily_lives := -1
	if daily != null:
		var lives: Variant = daily.get("_lives")
		if lives is Dictionary:
			daily_lives = (lives as Dictionary).size()
			daily_setup["residents"] = daily_lives
	city_ready = true
	status = "ready" if hit_owners.size() == _stream_total else "pending_placement"
	_dsh_shadow_ab()
	_startup_progress.phase = "complete"
	_stream_all_us = Time.get_ticks_usec() - _stream_ready_us
	_stream_phase = "complete"
	_stream_active = ""
	var origin: int = _dsh_load_started_ms if _dsh_load_started_ms > 0 else Time.get_ticks_msec()
	print("DSH_STREAMLOAD complete t=", "%.1f" % (float(Time.get_ticks_msec() - origin) / 1000.0), "s",
		" stream_ms=", int(float(_stream_all_us) / 1000.0), " admitted=", hit_owners.size(), "/", _stream_total,
		" bound=", hit_owners.size(), " unresolved=", _stream_unresolved, " admits=", _stream_admits,
		" forced=", _stream_forced, " probes=", _stream_probes, " daily=", _stream_daily_mode,
		" daily_lives=", daily_lives, " daily_failures=", _stream_daily_failures, " err_m=", "%.2f" % _stream_err,
		" city_ready=", city_ready, " status=", status, " phase=", str(_startup_progress.get("phase", "")))

# DSH_STREAMLOAD: the source daily_configure block, extracted so the early-ready path and
# the (fallback) end-of-stream path call it at the same point in the sequence with the same
# arguments. `extend` additionally allows residents that arrive AFTER configure() to join
# the daily cycle; if that host's shape ever refuses, the configure is deferred to the end
# of the stream instead - today's order - rather than leaving residents out of the cycle.
func _configure_daily(scene: Node3D, sites: Array[Node3D], extend: bool = false) -> bool:
	var extendable := false
	if extend:
		var probe: RefCounted = CityDaily.new()
		extendable = probe.get("_lives") is Dictionary and probe.get("_accounts") is Dictionary and probe.get("_health") is Dictionary and probe.has_method("_create_visit")
		probe.dispose()
		if not extendable:
			_stream_daily_mode = "deferred"
			_startup_progress.phase = "daily_configure"
			return true
	_startup_progress.phase="daily_configure"
	combat_status="new_local_session"
	var daily_started:=Time.get_ticks_usec()
	daily=CityDaily.new()
	daily_setup=daily.configure(scene,self,sites[0],sites[1],HospitalVisit,BankVisit,ShopVisit,FileAccess.get_file_as_bytes("res://data/LOCAL_PRINTSHOP_ENTRY.json"),FileAccess.get_file_as_bytes("res://data/ENTRY_GEOMETRY.json"),"res://scripts/route/DRIVE_THEN_WALK.json",ROAD_SHA)
	if not daily_setup.get("ok",false):
		if not extend: return _fail("city_daily:"+str(daily_setup))
		# DSH_STREAMLOAD: the daily host refused the early cohort. That must not fail the city
		# (the blocking path would still be loading), so configure it once at the end of the
		# stream instead - exactly today's order, for every resident.
		var dsh_refused: String=str(daily_setup)
		daily.dispose(); daily=null; daily_setup={}
		_stream_daily_mode="deferred"
		print("DSH_STREAMLOAD daily=deferred reason=",dsh_refused)
		return true
	_record_startup_timing("daily_configure",daily_started,Engine.get_physics_frames())
	var incidents: Dictionary=_configure_incident_dispatcher(scene)
	daily_setup["incident_dispatcher"]=incidents
	if extend: _stream_daily_mode = "incremental"
	return true

# DSH_TELEMETRY (temporary A/B): measure what NPC shadow casting costs.
# DSH_STREAMLOAD: extracted verbatim into a method so the streamed path runs the same sweep
# over the completed population instead of over the early cohort only.
func _configure_incident_dispatcher(scene: Node3D) -> Dictionary:
	if incident_dispatcher!=null: return {"ok":true,"reason":"already_configured"}
	if not is_instance_valid(scene) or not scene.is_inside_tree() or daily==null: return {"ok":false,"reason":"current_city_daily_required"}
	var weapons: Variant=scene.get("preview_weapons")
	if not is_instance_valid(weapons) or not weapons is Node: return {"ok":false,"reason":"committed_preview_weapons_required"}
	var dispatcher: RefCounted=IncidentDispatcher.new()
	var configured: Dictionary=dispatcher.configure(weapons,self)
	if not configured.get("ok",false): dispatcher.dispose(); return configured
	incident_dispatcher=dispatcher
	return configured

func incident_candidate_count() -> int:
	return hit_owners.size()

func incident_candidate_at(index: int) -> Variant:
	return hit_owners[index] if index>=0 and index<hit_owners.size() else null

func _incident_observation_current(owner: Object, observation: Dictionary) -> bool:
	if _disposed or not is_instance_valid(owner) or not hit_owners.has(owner) or residents==null: return false
	var owner_token_value: Variant=owner.get("_token")
	var observation_token_value: Variant=observation.get("token")
	if not owner_token_value is Dictionary or not observation_token_value is Dictionary: return false
	var owner_token: Dictionary=owner_token_value
	var observation_token: Dictionary=observation_token_value
	if str(owner_token.get("source_id",""))!=str(observation_token.get("source_id","")) or str(owner_token.get("session_id",""))!=str(observation_token.get("session_id","")) or int(owner_token.get("life_generation",-1))!=int(observation_token.get("life_generation",-2)) or owner_token.get("body")!=observation_token.get("body"): return false
	return residents.target_current(owner_token)

func incident_target_current(owner: Object, observation: Dictionary) -> bool:
	return _incident_observation_current(owner,observation)

func incident_can_hear(owner: Object, observation: Dictionary) -> bool:
	return daily!=null and _incident_observation_current(owner,observation) and daily.incident_can_hear(owner,observation)

func incident_submit_witness(owner: Object, event: Dictionary) -> Dictionary:
	if daily==null: return {"accepted":false,"reason":"city_daily_unavailable"}
	return daily.incident_submit_witness(owner,event)

func incident_game_paused() -> bool:
	var scene: Node3D=_scene_ref.get_ref() if _scene_ref!=null else null
	return not is_instance_valid(scene) or not scene.is_inside_tree() or scene.get_tree().paused

func _dsh_shadow_ab() -> void:
	if not OS.get_cmdline_user_args().has("--city-no-npc-shadows") or residents==null: return
	var dsh_shadowless := 0
	for dsh_id: String in residents._records:
		var dsh_body: Node = residents._records[dsh_id].get("body")
		if not is_instance_valid(dsh_body): continue
		var dsh_stack: Array[Node] = [dsh_body]
		while not dsh_stack.is_empty():
			var dsh_node: Node = dsh_stack.pop_back()
			if dsh_node is GeometryInstance3D: (dsh_node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for dsh_child: Node in dsh_node.get_children(): dsh_stack.append(dsh_child)
			dsh_shadowless += 1
	print("DSH_SHADOW_AB shadows_off_nodes=", dsh_shadowless)

func setup_city(scene: Node3D, sites: Array[Node3D], staged_three: bool=false, qa_source_ids: Array[String]=[]) -> bool:
	if _disposed or status!="not_loaded" or sites.size()!=2: return false
	status="loading_city"; _scene_ref=weakref(scene)
	var started:=Time.get_ticks_usec()
	_startup_frame_start=Engine.get_physics_frames()
	_startup_progress.phase="configure"
	var selected_sha: String=PACKET_SHA if staged_three else CITY_PACKET
	var packet_path:=DIRECTORY+PACKET_SHA+".json" if staged_three else CITY_DIRECTORY+"session_packet.json"
	var packet:=FileAccess.get_file_as_bytes(packet_path)
	if FileAccess.get_sha256(packet_path)!=selected_sha: return _fail("city_packet_pin")
	var parsed: Dictionary=JSON.parse_string(packet.get_string_from_utf8())
	# Explicit functional QA cohort only. Normal/bootstrap callers leave this
	# empty and load the complete pinned packet without population reduction.
	if staged_three and not qa_source_ids.is_empty(): return _fail("mixed_qa_population_modes")
	for id: String in qa_source_ids:
		if not parsed.rows.any(func(row: Dictionary) -> bool: return row.source_id==id): return _fail("unknown_qa_source_id")
	var sources: Dictionary={}
	for receipt: Dictionary in parsed.source_receipts: sources[receipt.path]=receipt.sha256
	var states: Dictionary={}
	for row: Dictionary in parsed.rows:
		owners[row.source_id]=Queue.Owner.new(row.source_id,1)
		states[row.source_id]="ordinary_outdoor"
	var trust: Dictionary={"accepted":true,"packet_sha256":selected_sha,"packet_path":packet_path,"sources":sources,"session_id":SESSION,"prepared_sha256":CITY_PREPARED,"block_sha256":CITY_BLOCK}
	policy=CityPolicy.new()
	var approved: Dictionary=policy.configure(scene,parsed.rows,owners,trust,{"version":1,"states":states})
	if not approved.get("ok",false): return _fail("city_policy:"+str(approved))
	_queue=Queue.new()
	# DSH_NAVPUMP: opt-in per-step budget of the path queue. Without these flags
	# the queue keeps its exact defaults (8 admits / 4000 us) and this block does
	# nothing at all. Measured reason: 137 waiting residents at ~2 ready routes/s.
	var dsh_pump_budget := 4000
	var dsh_pump_admits := 8
	for dsh_argument: String in OS.get_cmdline_user_args():
		if dsh_argument.begins_with("--city-nav-pump-budget-us="): dsh_pump_budget = maxi(0, int(dsh_argument.trim_prefix("--city-nav-pump-budget-us=")))
		elif dsh_argument.begins_with("--city-nav-pump-admits="): dsh_pump_admits = maxi(1, int(dsh_argument.trim_prefix("--city-nav-pump-admits=")))
	if dsh_pump_budget != 4000 or dsh_pump_admits != 8:
		_queue.configure_budget(dsh_pump_budget, dsh_pump_admits)
		print("DSH_NAVPUMP budget_us=", dsh_pump_budget, " admits=", dsh_pump_admits)
	navigation=CityNavigation.new()
	if not navigation.attach_city_existing(scene,scene._printshop,scene._block,scene._printshop_data,_queue,SESSION,1,1,sites): return _fail("city_navigation:"+str(navigation.diagnostics()))
	residents=Residents.new()
	var configured: Dictionary=residents.configure(scene,navigation,packet,trust,FileAccess.get_file_as_bytes(CITY_DIRECTORY+"prepared/manifest.json"),CITY_DIRECTORY+"prepared",owners,Callable(policy,"source_admit"),Callable(policy,"support_height"))
	if not configured.get("ok",false): return _fail("city_residents:"+str(configured))
	if not policy.bind_host(residents): return _fail("city_policy_host_binding")
	_record_startup_timing("configure",started,Engine.get_physics_frames())
	_startup_progress.phase="source_birth"
	# DSH_STREAMLOAD: the flag scan for this run. Streaming stays off for the staged preview
	# path, whose rows are placed at PREVIEW_STAGES points rather than at source coordinates.
	var stream_flags: Dictionary=_stream_flags()
	var stream_cohort: int=int(stream_flags["cohort"])
	var stream_cohort_rows:=0
	var stream_cohort_bound:=0
	_stream_on = stream_cohort > 0 and not staged_three
	var load_birth_budget_us:=_dsh_load_batch_us()  # DSH_LOADBATCH: 0 = one item per tick
	var load_birth_started_us:=Time.get_ticks_usec()  # DSH_LOADBATCH
	for row: Dictionary in parsed.rows:
		if not _startup_current(scene): return false
		if not qa_source_ids.is_empty() and row.source_id not in qa_source_ids: continue
		if staged_three and not PREVIEW_STAGES.has(row.source_id): continue
		var admission_started:=Time.get_ticks_usec()
		if staged_three:
			var point: Vector2=PREVIEW_STAGES[row.source_id]
			admission_results[row.source_id]=residents.admit_preview_stage(row.source_id,point.y,point.x)
		elif not qa_source_ids.is_empty():
			admission_results[row.source_id]=residents.admit_city_spawn(row.source_id,float(row.source_raw.r),float(row.source_raw.c))
		else:
			admission_results[row.source_id]=residents.admit_next()
		# DSH_TELEMETRY (temporary): the first admissions decide whether placement can work at all.
		if _startup_progress.birth_attempts < 5:
			print("DSH_ADMIT ", row.source_id, " ", JSON.stringify(admission_results[row.source_id]))
		_record_startup_timing("birth_admission",admission_started,Engine.get_physics_frames(),row.source_id)
		_startup_progress.birth_attempts+=1
		_startup_progress.last_source_id=row.source_id
		_dsh_load_report("source_birth",int(_startup_progress.birth_attempts),parsed.rows.size())
		# DSH_STREAMLOAD: early readiness stops the blocking birth pass after the cohort and
		# leaves every remaining row to the streaming pass, which uses the same admission call
		# in the same way; with no flag _stream_on is false and this block does nothing.
		if _stream_on:
			stream_cohort_rows+=1
			if is_instance_valid(residents._records[row.source_id].body): stream_cohort_bound+=1
			if stream_cohort_rows>=stream_cohort and stream_cohort_bound>=1: break
		# DSH_LOADBATCH: source behaviour admits exactly one original model per physics frame.
		# With --city-load-batch-ms=N the loop keeps admitting while this physics tick is
		# still inside the budget and yields once afterwards; every per-item call, every
		# guard and their order are unchanged, and the loop resumes at the same row, so no
		# row is skipped or admitted twice when the budget runs out mid-pass.
		if load_birth_budget_us<=0 or Time.get_ticks_usec()-load_birth_started_us>=load_birth_budget_us:
			# Keep startup admission bounded to one original model per physics frame.
			await scene.get_tree().physics_frame
			load_birth_started_us=Time.get_ticks_usec()
			if not _startup_current(scene): return false
	# DSH_STREAMLOAD: with streaming on, every row that still has no body is resolved by the
	# per-tick stream instead of this blocking pass; the per-row probe order and budget are
	# the same, they are just spent from step() and under the visibility gate.
	if not staged_three and not _stream_on:
		_startup_progress.phase="fallback_placement"
		var batch_started:=Time.get_ticks_usec()
		var dsh_probe_budget_us:=_dsh_load_probe_us()  # DSH_LOADBATCH: default FALLBACK_BUDGET_US
		var batch_probes:=0
		# An initial source candidate may intersect authored native geometry. The
		# new local resolver searches nearby; immutable birth positions stay saved.
		for row: Dictionary in parsed.rows:
			if not _startup_current(scene): return false
			if not qa_source_ids.is_empty() and row.source_id not in qa_source_ids: continue
			if is_instance_valid(residents._records[row.source_id].body): continue
			var raw: Dictionary=row.source_raw
			var placed:=false
			for ring in range(1,_city_fallback_max_ring()+1):
				for direction in 16:
					var angle:=TAU*float(direction)/16.0
					var probe_started:=Time.get_ticks_usec()
					var result: Dictionary=residents.admit_city_spawn(row.source_id,float(raw.r)+sin(angle)*float(ring)*.5,float(raw.c)+cos(angle)*float(ring)*.5)
					_record_startup_timing("fallback_probe",probe_started,Engine.get_physics_frames(),row.source_id)
					admission_results[row.source_id]=result
					batch_probes+=1; _startup_progress.fallback_probes+=1
					_startup_progress.last_source_id=row.source_id
					_startup_progress.last_reason=str(result.get("reason",""))
					if ring==1 and direction==0:
						print("DSH_PROBE ", row.source_id, " ", JSON.stringify(result))
					if result.get("status")=="IDLE":
						placed=true; _startup_progress.fallback_admitted+=1; break
					# Budget is checked at each complete authority call; no check is
					# split or omitted. One slow call can exceed the cooperative limit.
					if batch_probes>=FALLBACK_MAX_PROBES or Time.get_ticks_usec()-batch_started>=dsh_probe_budget_us:
						_startup_progress.fallback_yields+=1
						_dsh_load_report("fallback_placement",int(_startup_progress.fallback_admitted),parsed.rows.size())
						await scene.get_tree().physics_frame
						if not _startup_current(scene): return false
						batch_started=Time.get_ticks_usec(); batch_probes=0
				if placed: break
			if placed:
				# DSH_LOADBATCH: source behaviour never instantiates two successfully admitted
				# source models in one frame. With the probe budget raised, the yield is taken
				# on that same per-tick budget instead; the counters are reset identically.
				if dsh_probe_budget_us<=FALLBACK_BUDGET_US or Time.get_ticks_usec()-batch_started>=dsh_probe_budget_us:
					_startup_progress.fallback_yields+=1
					await scene.get_tree().physics_frame
					if not _startup_current(scene): return false
				batch_started=Time.get_ticks_usec(); batch_probes=0
	_startup_progress.phase="navigation_ready"
	var nav_deadline:=Time.get_ticks_msec()+30000
	while _startup_current(scene) and navigation.state()!="READY" and Time.get_ticks_msec()<nav_deadline:
		_navigation_ready_wait_frames+=1
		await scene.get_tree().physics_frame
		if not _startup_current(scene): return false
	if not _startup_current(scene): return false
	if navigation.state()!="READY": return _fail("city_navigation_not_ready:"+str(navigation.diagnostics()))
	_startup_progress.phase="health_binding"
	var load_health_budget_us:=_dsh_load_batch_us()  # DSH_LOADBATCH: 0 = one item per tick
	var load_health_started_us:=Time.get_ticks_usec()  # DSH_LOADBATCH
	# Attach genuine health owners only to bodies admitted by current physics.
	for row: Dictionary in parsed.rows:
		if not _startup_current(scene): return false
		var record: Dictionary=residents._records[row.source_id]
		if not is_instance_valid(record.body): continue
		var health_started:=Time.get_ticks_usec()
		var health:=LocalHits.new()
		var token: Dictionary=residents.target_from_collider(record.body)
		var linked: Dictionary=health.configure(residents,token,packet,trust,scene.preview_weapons,{"marksman":0.0,"scope":"local_new_session","session_id":SESSION})
		if not linked.get("ok",false): health.dispose(); return _fail("city_health:"+str(linked))
		_record_startup_timing("health_bind",health_started,Engine.get_physics_frames(),row.source_id)
		hit_owners.append(health); record.walk_pause=Callable(health,"should_pause_walk")
		_startup_progress.health_bound=hit_owners.size()
		_startup_progress.last_source_id=row.source_id
		_dsh_load_report("health_binding",hit_owners.size(),parsed.rows.size())
		# DSH_LOADBATCH: same budget batching as source_birth. The health owner, its token and
		# the append stay strictly per row and in order.
		if load_health_budget_us<=0 or Time.get_ticks_usec()-load_health_started_us>=load_health_budget_us:
			await scene.get_tree().physics_frame
			load_health_started_us=Time.get_ticks_usec()
			if not _startup_current(scene): return false
	if _stream_on:
		# DSH_STREAMLOAD: early readiness. Both sites, the navigation map and the first cohort
		# are in place, so the city reports ready here and the remaining rows stream from
		# step(); with no flag _stream_on is false and this branch is never taken.
		return _stream_begin(scene,parsed,qa_source_ids,packet,trust,sites,started)
	if not _configure_daily(scene,sites): return false
	city_ready=true; status="ready" if hit_owners.size()==parsed.rows.size() else "pending_placement"
	if SingleLifecycle28.enabled() and qa_source_ids==["resident_1"]:
		_single_lifecycle28=SingleLifecycle28.new();scene.add_child(_single_lifecycle28)
		if not _single_lifecycle28.configure(scene,self,packet,trust):return _fail("single_lifecycle28_configure")
	# DSH_TELEMETRY (temporary A/B): measure what NPC shadow casting costs.
	# DSH_STREAMLOAD: the sweep is now a method, so the streaming path runs it over the
	# completed population instead of only over the early cohort.
	_dsh_shadow_ab()
	_startup_progress.phase="complete"
	_startup_us=Time.get_ticks_usec()-started
	_startup_frame_end=Engine.get_physics_frames()
	return true

func step(delta: float) -> void:
	if _disposed or navigation==null: return
	if is_instance_valid(_single_lifecycle28) and _single_lifecycle28.suspended():
		residents.step_single_corpse28(_single_lifecycle28);return
	var started:=Time.get_ticks_usec()
	var frame:=Engine.get_physics_frames()
	# DSH_QUERY_PROBE (temporary): real physics ticks per real second. The city logic runs
	# inside _physics_process, so a long rendered frame executes this up to 8 times and
	# every measured CPU bucket is multiplied by that count. TIME_PROCESS never shows it.
	var dsh_now_ms := Time.get_ticks_msec()
	if _dsh_phys_ms == 0:
		_dsh_phys_ms = dsh_now_ms
		_dsh_phys_last = Engine.get_physics_frames()
	elif dsh_now_ms - _dsh_phys_ms >= 1000:
		var dsh_dt := float(dsh_now_ms - _dsh_phys_ms) / 1000.0
		var dsh_ticks := Engine.get_physics_frames() - _dsh_phys_last
		print("DSH_PHYS hz=","%.1f" % (float(dsh_ticks)/dsh_dt)," render_fps=",Engine.get_frames_per_second()," drawn=",Engine.get_frames_drawn()," city_ready=",city_ready," phase=",str(_startup_progress.get("phase","")))
		_dsh_phys_ms = dsh_now_ms
		_dsh_phys_last = Engine.get_physics_frames()
	# DSH_STEPSPERFRAME (intentional, keep): whole-city steps per RENDERED frame. Zero-step
	# frames are derived from the drawn-frame counter delta, because no step call happens
	# inside them. This makes the stride beat visible directly: 41 -> 8-14 fps comes from
	# rendered frames that fit two 37 ms city steps in a row. Gated to one wall second.
	if city_ready:
		var dsh_spf_now:=Time.get_ticks_msec()
		var dsh_spf_seen:=Engine.get_frames_drawn()
		if _dsh_spf_ms==0:
			_dsh_spf_ms=dsh_spf_now
			_dsh_spf_window_drawn=dsh_spf_seen
			_dsh_spf_drawn=dsh_spf_seen
			_dsh_spf_steps=0
		if dsh_spf_seen!=_dsh_spf_drawn:
			# The previously counted rendered frame is complete: file its bucket.
			if _dsh_spf_steps>=3: _dsh_spf_h3+=1
			elif _dsh_spf_steps==2: _dsh_spf_h2+=1
			elif _dsh_spf_steps==1: _dsh_spf_h1+=1
			_dsh_spf_drawn=dsh_spf_seen
			_dsh_spf_steps=0
		_dsh_spf_steps+=1
		_dsh_spf_steps_total+=1
		if dsh_spf_now-_dsh_spf_ms>=1000:
			var dsh_spf_stepped:=_dsh_spf_h1+_dsh_spf_h2+_dsh_spf_h3+(1 if _dsh_spf_steps>0 else 0)
			var dsh_spf_frames:=dsh_spf_seen-_dsh_spf_window_drawn
			var dsh_spf_zero:=maxi(0,dsh_spf_frames-dsh_spf_stepped)
			var dsh_spf_dt:=float(dsh_spf_now-_dsh_spf_ms)/1000.0
			print("DSH_STEPSPERFRAME h0=",dsh_spf_zero," h1=",_dsh_spf_h1," h2=",_dsh_spf_h2," h3plus=",_dsh_spf_h3," frames=",dsh_spf_frames," steps=",_dsh_spf_steps_total," steps_per_frame=",("0.00" if dsh_spf_frames<=0 else "%.2f" % (float(_dsh_spf_steps_total)/float(dsh_spf_frames)))," render_fps_avg=",("0.0" if dsh_spf_dt<=0.0 else "%.1f" % (float(dsh_spf_frames)/dsh_spf_dt)))
			_dsh_spf_ms=dsh_spf_now
			_dsh_spf_window_drawn=dsh_spf_seen
			_dsh_spf_drawn=dsh_spf_seen
			_dsh_spf_steps=0
			_dsh_spf_steps_total=0
			_dsh_spf_h1=0; _dsh_spf_h2=0; _dsh_spf_h3=0
	var phase_started:=Time.get_ticks_usec()
	navigation.pump(frame)
	var navigation_us:=Time.get_ticks_usec()-phase_started
	# DSH_NAVDAILY (temporary): split the `resid` bucket. `resid` is the whole 287-record
	# loop; this reports how much of it is navigation.step() (source-policy admission +
	# swept capsule + move_and_slide) and how much is surrounding loop overhead.
	var dsh_step_ms:=Time.get_ticks_msec()
	if _dsh_step_counters_ms==0:
		_dsh_step_counters_ms=dsh_step_ms
		_dsh_step_counters=navigation.counters()
	elif dsh_step_ms-_dsh_step_counters_ms>=1000:
		var dsh_step_now: Dictionary=navigation.counters()
		var dsh_step_delta:=int(dsh_step_now["steps"])-int(_dsh_step_counters["steps"])
		var dsh_step_sum:=int(dsh_step_now["step_us_total"])-int(_dsh_step_counters["step_us_total"])
		var dsh_step_blocked:=int(dsh_step_now["blocked_steps"])-int(_dsh_step_counters["blocked_steps"])
		var dsh_step_dt:=float(dsh_step_ms-_dsh_step_counters_ms)/1000.0
		print("DSH_NAVSTEP steps/s=","%.0f" % (float(dsh_step_delta)/dsh_step_dt)," step_us/s=",dsh_step_sum," avg_us=",("0" if dsh_step_delta<=0 else "%.1f" % (float(dsh_step_sum)/float(dsh_step_delta)))," max_us=",int(dsh_step_now["step_us_max"])," blocked/s=","%.0f" % (float(dsh_step_blocked)/dsh_step_dt))
		_dsh_step_counters_ms=dsh_step_ms
		_dsh_step_counters=dsh_step_now
	if residents==null: return
	# DSH_STREAMLOAD: the population streams from here - the normal per-frame step path that
	# already runs the navigation pump and every resident - so the rest of the city keeps
	# working while the remaining residents are admitted and health-bound one at a time.
	if _stream_on:
		var stream_scene: Node3D = _scene_ref.get_ref() if _scene_ref!=null else null
		if is_instance_valid(stream_scene): _stream_tick(stream_scene,delta)
	phase_started=Time.get_ticks_usec()
	# A confirmed bleedout may synchronously retire this exact one-NPC owner.
	var health_dispatch28: Array=hit_owners.duplicate() if _single_lifecycle28!=null else hit_owners
	for health: RefCounted in health_dispatch28: health.step()
	if is_instance_valid(_single_lifecycle28) and _single_lifecycle28.suspended():
		residents.step_single_corpse28(_single_lifecycle28);return
	var health_us:=Time.get_ticks_usec()-phase_started
	phase_started=Time.get_ticks_usec()
	if city_ready and daily!=null: daily.step(delta)
	if city_ready and incident_dispatcher!=null: incident_dispatcher.step(delta)
	var daily_us:=Time.get_ticks_usec()-phase_started
	phase_started=Time.get_ticks_usec()
	residents.step(delta)
	var residents_us:=Time.get_ticks_usec()-phase_started
	phase_started=Time.get_ticks_usec()
	# DSH_NAVDAILY: identical gates, identical order, identical short-circuiting; each owner
	# property is now read once instead of two or three times. No dictionary work and no
	# allocation was added.
	# DSH_DAILYFX: the fx bucket is counted per executing owner. The counters are plain
	# integer adds on the branch that already runs, so a step where nothing is due pays
	# nothing. --city-fx-idle-stagger=1 (default 0) desynchronises the cohort's 250 ms
	# idle refresh; --city-dailyfx-probe=1 (default 0) adds the idle/active split.
	var dsh_fx_probe:=_dsh_fx_probe()
	if _dsh_fx_stagger()==1: _dsh_fx_stagger_cohort()
	# DSH_FXSLICE: at most dsh_fx_cap IDLE owners per step, rotating; live effects always run.
	var dsh_fx_cap:=_dsh_fx_slice()
	# DSH_FXIDLE: one flag and one clock reading per city step. With
	# --city-fx-idle-skip=0 the ternary at the gate below never calls the bypass test, so
	# no owner is skipped, no deadline is read and no _last_root is written: today's path.
	var dsh_fx_idle_skip:=_dsh_fx_idle_skip()
	var dsh_fx_now_us:=Time.get_ticks_usec()
	var dsh_fx_total:=hit_owners.size()
	var dsh_fx_served:=0
	var dsh_fx_deferred:=0
	var dsh_fx_skipped:=0  # DSH_FXIDLE: due never-bloodied owners bypassed
	var dsh_fx_bypass:=0  # DSH_FXIDLE: every never-bloodied owner bypassed
	var dsh_fx_blood:=0
	var dsh_fx_marks:=0
	var dsh_fx_active:=0
	for dsh_fx_k in dsh_fx_total:
		var dsh_fx_index: int=(_dsh_fx_cursor+dsh_fx_k)%dsh_fx_total if dsh_fx_cap>0 else dsh_fx_k
		var health: RefCounted=hit_owners[dsh_fx_index]
		var blood: RefCounted=health.blood
		# DSH_FXIDLE: the whole blood branch - blood.should_step() (npc_blood_adapter.gd:74-78)
		# and the blood.step() it guards (:80-83) - is bypassed for an owner that has never
		# emitted a particle, so its idle refresh and the _current() lease chain of :28-31 are
		# not paid at all. An owner that has ever bled reads emitted!=0 and takes the
		# unchanged branch below, so a wound is never delayed: accept() sets _has_particles
		# (npc_blood_renderer.gd:55, called at :68) and should_step() short-circuits on it
		# (:77), which makes the very next city step run the full step() with the fresh
		# _last_root written by the bypass test on the steps before the wound.
		var dsh_fx_idle: int=_dsh_fx_idle_bypass(blood,dsh_fx_now_us) if blood!=null and dsh_fx_idle_skip==1 else 0
		if dsh_fx_idle>0:
			dsh_fx_bypass+=1
			if dsh_fx_idle>1: dsh_fx_skipped+=1
		elif blood!=null and blood.should_step():
			if dsh_fx_cap<=0 or dsh_fx_served<dsh_fx_cap or _dsh_fx_live(blood):
				blood.step(delta)
				dsh_fx_served+=1
				dsh_fx_blood+=1
				if dsh_fx_probe==1:
					var blood_renderer: Variant=blood.get("renderer")
					if blood_renderer!=null:
						var blood_wounds: Variant=blood_renderer.get("_wounds")
						if bool(blood_renderer.get("_has_particles")) or (blood_wounds is Array and not (blood_wounds as Array).is_empty()): dsh_fx_active+=1
			else:
				dsh_fx_deferred+=1
		var marks: RefCounted=health.marks
		if marks!=null:
			var marks_renderer: RefCounted=marks.renderer
			if marks_renderer!=null and not marks_renderer._marks.is_empty():
				marks.step()
				dsh_fx_marks+=1
	if dsh_fx_cap>0 and dsh_fx_total>0: _dsh_fx_cursor=(_dsh_fx_cursor+dsh_fx_served)%dsh_fx_total
	_dsh_fx_deferred_steps=dsh_fx_deferred
	_dsh_fx_skipped_steps=dsh_fx_skipped
	_dsh_fx_bypass_steps=dsh_fx_bypass
	var effects_us:=Time.get_ticks_usec()-phase_started
	_dsh_fx_blood_steps=dsh_fx_blood
	_dsh_fx_marks_steps=dsh_fx_marks
	_dsh_fx_active_steps=dsh_fx_active
	# DSH_TELEMETRY (temporary): where the collapsed city frame actually goes.
	if frame%30==0:
		print("DSH_CITY f=",frame," fps=",Engine.get_frames_per_second()," ready=",city_ready," phase=",str(_startup_progress.get("phase",""))," births=",int(_startup_progress.get("birth_attempts",0))," probes=",int(_startup_progress.get("fallback_probes",0))," bound=",int(_startup_progress.get("health_bound",0))," nav=",navigation_us," health=",health_us," daily=",daily_us," resid=",residents_us," fx=",effects_us," total=",Time.get_ticks_usec()-started," fx_blood=",_dsh_fx_blood_steps," fx_marks=",_dsh_fx_marks_steps," fx_active=",_dsh_fx_active_steps," fx_owners=",hit_owners.size()," fx_idle_deferred=",_dsh_fx_deferred_steps," fx_idle_skipped=",_dsh_fx_skipped_steps," fx_idle_bypass=",_dsh_fx_bypass_steps)
		# DSH_TELEMETRY (temporary): attribute the frame outside city logic.
		print("DSH_PERF f=",frame," fps=",Engine.get_frames_per_second()," process_ms=",int(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)," physics_ms=",int(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)," draw_calls=",int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))," prims=",int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))," nodes=",int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))," bodies=",int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))," ready=",city_ready)
	if city_ready:
		var elapsed:=Time.get_ticks_usec()-started
		var unattributed_us:=elapsed-navigation_us-health_us-daily_us-residents_us-effects_us
		var profiler_started:=Time.get_ticks_usec()
		_record_timing("navigation_pump",navigation_us,frame)
		_record_timing("health",health_us,frame)
		_record_timing("daily",daily_us,frame)
		_record_timing("residents",residents_us,frame)
		_record_timing("effects",effects_us,frame)
		_record_timing("unattributed",unattributed_us,frame)
		var sample_slot: int=_logic_sample_count if _logic_sample_count<LOGIC_SAMPLE_CAPACITY else _logic_cursor
		_logic_frame_samples[sample_slot]=frame; _logic_samples[sample_slot]=elapsed
		_logic_navigation_samples[sample_slot]=navigation_us; _logic_health_samples[sample_slot]=health_us
		_logic_daily_samples[sample_slot]=daily_us; _logic_resident_samples[sample_slot]=residents_us
		_logic_effect_samples[sample_slot]=effects_us; _logic_unattributed_samples[sample_slot]=unattributed_us
		if _logic_sample_count<LOGIC_SAMPLE_CAPACITY: _logic_sample_count+=1
		else: _logic_cursor=(_logic_cursor+1)%LOGIC_SAMPLE_CAPACITY
		if elapsed>int(_logic_peak_frame["total_us"]):
			_logic_peak_frame["frame"]=frame; _logic_peak_frame["total_us"]=elapsed
			_logic_peak_frame["navigation_us"]=navigation_us; _logic_peak_frame["health_us"]=health_us
			_logic_peak_frame["daily_us"]=daily_us; _logic_peak_frame["residents_us"]=residents_us
			_logic_peak_frame["effects_us"]=effects_us; _logic_peak_frame["unattributed_us"]=unattributed_us
		if elapsed>=4000: _store_logic_peak(frame,elapsed,navigation_us,health_us,daily_us,residents_us,effects_us,unattributed_us)
		var profiler_write_us:=Time.get_ticks_usec()-profiler_started
		_logic_profiler_samples[sample_slot]=profiler_write_us
		if int(_logic_peak_frame["frame"])==frame and int(_logic_peak_frame["total_us"])==elapsed:
			_logic_peak_frame["profiler_write_us"]=profiler_write_us
			_logic_peak_frame["logic_including_profiler_us"]=elapsed+profiler_write_us

func snapshot() -> Dictionary:
	var sorted: Array[int]=[]
	var profile_sorted: Array[int]=[]
	var inclusive_sorted: Array[int]=[]
	for index in _logic_sample_count:
		var logic_us:=int(_logic_samples[index]); var profiler_us:=int(_logic_profiler_samples[index])
		sorted.append(logic_us); profile_sorted.append(profiler_us); inclusive_sorted.append(logic_us+profiler_us)
	sorted.sort()
	profile_sorted.sort(); inclusive_sorted.sort()
	var cost: Dictionary={"scope":"NPC logic excludes profiler writes; not rendered FPS","samples":_logic_sample_count,"profiler_write_samples":_logic_sample_count}
	if not sorted.is_empty(): cost.merge({"p50_us":sorted[int(sorted.size()*.5)],"p95_us":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max_us":sorted[-1]})
	if not profile_sorted.is_empty(): cost.merge({"profiler_write_p50_us":profile_sorted[int(profile_sorted.size()*.5)],"profiler_write_p95_us":profile_sorted[mini(profile_sorted.size()-1,int(profile_sorted.size()*.95))],"profiler_write_max_us":profile_sorted[-1]})
	if not inclusive_sorted.is_empty(): cost.merge({"logic_including_profiler_p50_us":inclusive_sorted[int(inclusive_sorted.size()*.5)],"logic_including_profiler_p95_us":inclusive_sorted[mini(inclusive_sorted.size()-1,int(inclusive_sorted.size()*.95))],"logic_including_profiler_max_us":inclusive_sorted[-1]})
	var peaks: Array[Dictionary]=[]
	for peak: Dictionary in _logic_peaks:
		if int(peak["frame"])>=0: peaks.append(peak.duplicate())
	peaks.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a["total_us"])>int(b["total_us"]))
	return {"status":status,"error":error,"city_ready":city_ready,"admitted":hit_owners.size(),"startup_us":_startup_us,"startup_frames":{"first":_startup_frame_start,"last":_startup_frame_end,"navigation_ready_wait_frames":_navigation_ready_wait_frames},"startup_timing":_startup_timing.duplicate(true),"startup_progress":_startup_progress.duplicate(),"admissions":admission_results.duplicate(true),"residents":residents.snapshot() if residents!=null else {},"navigation":navigation.diagnostics() if navigation!=null else {},"policy":policy.diagnostics() if policy!=null else {},"daily_setup":daily_setup,"daily":daily.snapshot() if daily!=null else {},"incidents":incident_dispatcher.snapshot() if incident_dispatcher!=null else {},"logic_cost":cost,"logic_peaks":peaks,"logic_peak_frame":_logic_peak_frame.duplicate(),"logic_timing_buckets":_logic_buckets.duplicate(true),"logic_frame_trace":_logic_frame_trace(),"stream":city_stream_report()}

func dispose() -> void:
	if is_instance_valid(_single_lifecycle28):_single_lifecycle28.dispose();_single_lifecycle28=null
	if incident_dispatcher!=null: incident_dispatcher.dispose(); incident_dispatcher=null
	if daily!=null:
		daily._retire_scene(); daily=null
	city_ready=false
	# DSH_STREAMLOAD: the streaming pass dies with the population it streams.
	_stream_on=false; _stream_phase="off"; _stream_pending_ids.clear(); _stream_sorted.clear(); _stream_held.clear(); _stream_fades.clear()
	super.dispose()
