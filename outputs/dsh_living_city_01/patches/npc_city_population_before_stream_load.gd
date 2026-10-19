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
const ROAD_SHA := "dc77f6495d2657dff91106ca831cf41fb7f7c4ecb80e3211322999e74ad82f4b"
var daily: RefCounted
var admission_results := {}
var daily_setup := {}
var city_ready := false
var _scene_ref: WeakRef
var _startup_us := 0
const FALLBACK_BUDGET_US := 2000
const FALLBACK_MAX_PROBES := 32
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
	_queue=Queue.new(); navigation=CityNavigation.new()
	if not navigation.attach_city_existing(scene,scene._printshop,scene._block,scene._printshop_data,_queue,SESSION,1,1,sites): return _fail("city_navigation:"+str(navigation.diagnostics()))
	residents=Residents.new()
	var configured: Dictionary=residents.configure(scene,navigation,packet,trust,FileAccess.get_file_as_bytes(CITY_DIRECTORY+"prepared/manifest.json"),CITY_DIRECTORY+"prepared",owners,Callable(policy,"source_admit"),Callable(policy,"support_height"))
	if not configured.get("ok",false): return _fail("city_residents:"+str(configured))
	if not policy.bind_host(residents): return _fail("city_policy_host_binding")
	_record_startup_timing("configure",started,Engine.get_physics_frames())
	_startup_progress.phase="source_birth"
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
	if not staged_three:
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
			for ring in range(1,17):
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
	_startup_progress.phase="daily_configure"
	combat_status="new_local_session"
	var daily_started:=Time.get_ticks_usec()
	daily=CityDaily.new()
	daily_setup=daily.configure(scene,self,sites[0],sites[1],HospitalVisit,BankVisit,ShopVisit,FileAccess.get_file_as_bytes("res://data/LOCAL_PRINTSHOP_ENTRY.json"),FileAccess.get_file_as_bytes("res://data/ENTRY_GEOMETRY.json"),"res://scripts/route/DRIVE_THEN_WALK.json",ROAD_SHA)
	if not daily_setup.get("ok",false): return _fail("city_daily:"+str(daily_setup))
	_record_startup_timing("daily_configure",daily_started,Engine.get_physics_frames())
	city_ready=true; status="ready" if hit_owners.size()==parsed.rows.size() else "pending_placement"
	# DSH_TELEMETRY (temporary A/B): measure what NPC shadow casting costs.
	if OS.get_cmdline_user_args().has("--city-no-npc-shadows") and residents!=null:
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
	_startup_progress.phase="complete"
	_startup_us=Time.get_ticks_usec()-started
	_startup_frame_end=Engine.get_physics_frames()
	return true

func step(delta: float) -> void:
	if _disposed or navigation==null: return
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
	phase_started=Time.get_ticks_usec()
	for health: RefCounted in hit_owners: health.step()
	var health_us:=Time.get_ticks_usec()-phase_started
	phase_started=Time.get_ticks_usec()
	if city_ready and daily!=null: daily.step(delta)
	var daily_us:=Time.get_ticks_usec()-phase_started
	phase_started=Time.get_ticks_usec()
	residents.step(delta)
	var residents_us:=Time.get_ticks_usec()-phase_started
	phase_started=Time.get_ticks_usec()
	# DSH_NAVDAILY: identical gates, identical order, identical short-circuiting; each owner
	# property is now read once instead of two or three times. No dictionary work and no
	# allocation was added.
	for health: RefCounted in hit_owners:
		var blood: RefCounted=health.blood
		if blood!=null and blood.should_step(): blood.step(delta)
		var marks: RefCounted=health.marks
		if marks!=null:
			var marks_renderer: RefCounted=marks.renderer
			if marks_renderer!=null and not marks_renderer._marks.is_empty(): marks.step()
	var effects_us:=Time.get_ticks_usec()-phase_started
	# DSH_TELEMETRY (temporary): where the collapsed city frame actually goes.
	if frame%30==0:
		print("DSH_CITY f=",frame," fps=",Engine.get_frames_per_second()," ready=",city_ready," phase=",str(_startup_progress.get("phase",""))," births=",int(_startup_progress.get("birth_attempts",0))," probes=",int(_startup_progress.get("fallback_probes",0))," bound=",int(_startup_progress.get("health_bound",0))," nav=",navigation_us," health=",health_us," daily=",daily_us," resid=",residents_us," fx=",effects_us," total=",Time.get_ticks_usec()-started)
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
	return {"status":status,"error":error,"city_ready":city_ready,"admitted":hit_owners.size(),"startup_us":_startup_us,"startup_frames":{"first":_startup_frame_start,"last":_startup_frame_end,"navigation_ready_wait_frames":_navigation_ready_wait_frames},"startup_timing":_startup_timing.duplicate(true),"startup_progress":_startup_progress.duplicate(),"admissions":admission_results.duplicate(true),"residents":residents.snapshot() if residents!=null else {},"navigation":navigation.diagnostics() if navigation!=null else {},"policy":policy.diagnostics() if policy!=null else {},"daily_setup":daily_setup,"daily":daily.snapshot() if daily!=null else {},"logic_cost":cost,"logic_peaks":peaks,"logic_peak_frame":_logic_peak_frame.duplicate(),"logic_timing_buckets":_logic_buckets.duplicate(true),"logic_frame_trace":_logic_frame_trace()}

func dispose() -> void:
	if daily!=null:
		daily._retire_scene(); daily=null
	city_ready=false
	super.dispose()
