extends "../perf30/observer_perf30.gd"
## Read-only actual-city cohort observer. No movement/HP/needs writes.
var _expected30:=16
var _mass30: Array[Dictionary]=[]
var _positions30: Dictionary={}
var _travel30: Dictionary={}
var _seen30: Dictionary={}
var _max_mass_sample_us30:=0

func _ready() -> void:
	super._ready()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-residents="):_expected30=int(arg.trim_prefix("--qa-residents="))
	for i in int(ceil(_measure_s+_warmup_s))+5:_mass30.append({})

func _process(delta: float) -> void:
	if _finished:return
	if _ready_ms==0:
		var scene: Node3D=get_tree().current_scene
		var population: RefCounted=scene.get("preview_population")
		if population!=null and population.get("city_ready")==true and population.has_method("city_stream_complete") and not population.city_stream_complete():
			if Time.get_ticks_msec()-_start_ms>100000:_finish("stream_timeout")
			return
	super._process(delta)

func _sample(now: int,scene: Node3D) -> void:
	super._sample(now,scene)
	if _finished:return
	var started: int=Time.get_ticks_usec()
	var phases: Dictionary={};var goals: Dictionary={};var current_count:=0;var stationary:=0
	var completions: Dictionary={};var physical_recent:=0;var physical_expected:=0
	for id: String in _pop.daily._lives:
		var life: RefCounted=_pop.daily._lives[id]
		if not _pop.residents.target_current(life._token):continue
		current_count+=1
		var body: Node3D=life._token.body
		var position: Vector3=body.global_position
		if _positions30.has(id):
			var distance: float=position.distance_to(_positions30[id])
			if distance<4.0:_travel30[id]=float(_travel30.get(id,0.0))+distance
			if distance<0.01:stationary+=1
		_positions30[id]=position
		phases[life._phase]=int(phases.get(life._phase,0))+1
		var kind: String=str(life._goal.get("kind",""));goals[kind]=int(goals.get(kind,0))+1
		_seen30[id]=true
		for key: String in life._completed:completions[key]=int(completions.get(key,0))+int(life._completed[key])
		if _pop.daily._physical_needed30(life):
			physical_expected+=1
			if Engine.get_physics_frames()-int(life._frame)<=1:physical_recent+=1
	_mass30[_sample_count-1]={"measure_ms":now-_sample_start_ms if _sample_start_ms>0 else -1,"current_tokens":current_count,"phases":phases,"goals":goals,"completions":completions,"stationary_last_second":stationary,"physical_expected":physical_expected,"physical_recent":physical_recent,"dispatch":_pop.daily.physical_dispatch_state30(),"queries":_pop._avoidance29.query_state30() if _has(_pop,"_avoidance29") and _pop.get("_avoidance29")!=null else {}}
	_max_mass_sample_us30=maxi(_max_mass_sample_us30,Time.get_ticks_usec()-started)

func _finish(reason: String) -> void:
	if _finished:return
	_finished=true
	var usable: Array[Dictionary]=_samples.slice(0,_sample_count)
	var measured: Array[Dictionary]=usable.filter(func(r:Dictionary)->bool:return int(r.measure_ms)>=0)
	var errors: Array[String]=[]
	if not reason.is_empty():errors.append(reason)
	if measured.size()<int(_measure_s)-3:errors.append("insufficient_samples")
	if measured.any(func(r:Dictionary)->bool:return int(r.residents)!=_expected30 or int(r.lives)!=_expected30):errors.append("resident_count")
	if measured.any(func(r:Dictionary)->bool:return int(r.staff)!=_expected_staff or int(r.venues)!=12 or int(r.new_venues)!=8):errors.append("venue_staff_content")
	var mass: Array[Dictionary]=_mass30.slice(0,_sample_count)
	if mass.any(func(r:Dictionary)->bool:return int(r.get("current_tokens",0))!=_expected30):errors.append("current_tokens")
	var actual: Array=_seen30.keys();actual.sort()
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))
	var wanted: Array=[]
	for row: Dictionary in packet.rows:
		if wanted.size()>=_expected30:break
		wanted.append(str(row.source_id))
	wanted.sort()
	if actual!=wanted:errors.append("source_identity_set")
	var moved:=0
	for id: String in _travel30:
		if float(_travel30[id])>0.5:moved+=1
	if moved==0:errors.append("no_actual_motion")
	var final_camera: Dictionary=_camera_values(_camera) if is_instance_valid(_camera) else {}
	if final_camera!=_camera_record:errors.append("fixed_camera_changed")
	var report: Dictionary={"schema":"mafiozi.mass30.native/v1","ok":errors.is_empty(),"errors":errors,"pid":OS.get_process_id(),"expected_residents":_expected30,"expected_staff":_expected_staff,"warmup_seconds":_warmup_s,"measurement_seconds":_measure_s,"measurement_start_unix_ms":_sample_start_unix_ms,"measurement_end_unix_ms":Time.get_unix_time_from_system()*1000.0,"frame_count":_frame_count,"frame_ms":_frame_ms.slice(0,_frame_count),"frame_at_s":_frame_at_s.slice(0,_frame_count),"samples":usable,"mass_samples":mass,"actual_ids":actual,"wanted_ids":wanted,"moved_residents":moved,"travel_metres":_travel30,"camera":_camera_record,"final_camera":final_camera,"max_sample_us":_max_sample_us,"max_mass_sample_us":_max_mass_sample_us30,"max_observer_us":_max_frame_observer_us,"snapshot":_pop.snapshot() if _pop!=null else {},"npc_or_hp_writes":false,"performance_accepted":false}
	if not _out.is_empty():
		var file: FileAccess=FileAccess.open(_out.path_join("MASS30.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(report));file.close()
		if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png(_out.path_join("view.png"))
	print("MASS30_RESULT ",JSON.stringify({"ok":errors.is_empty(),"errors":errors,"residents":actual.size(),"moved":moved,"frames":_frame_count}))
	get_tree().quit(0 if errors.is_empty() else 1)
