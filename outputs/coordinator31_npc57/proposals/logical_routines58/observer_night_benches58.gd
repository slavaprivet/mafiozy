extends Node
var _scene: Node3D
var _pop: RefCounted
var _start:=0
var _bound:=0
var _next:=0
var _out:=""
var _rows:Dictionary={}
var _samples:Array=[]
var _installation:Dictionary={}
var _reinstall:Dictionary={}
var _sleep_proofs:Dictionary={}
var _night_started_ms:=-1
func _ready()->void:
	_scene=get_parent();_start=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):_out=arg.trim_prefix("--qa-out=")
	assert(not _out.is_empty())
func _physics_process(_delta:float)->void:
	var now:int=Time.get_ticks_msec()
	if _installation.is_empty():
		var host:Node=_scene.get("preview_homes58")
		if is_instance_valid(host) and host.current_sites().size()==4:
			var helper:Script=load(get_script().resource_path.get_base_dir().path_join("bench_patch/scripts/homes/npc_home_benches58.gd"))
			_installation=helper.install(_scene,host.current_sites())
			if not _installation.get("ok",false):_finish("bench_install_failed");return
			_reinstall=helper.install(_scene,host.current_sites())
	if _bound==0:
		_pop=_scene.get("preview_population")
		if _installation.is_empty() or _pop==null or not _pop.city_ready or _pop.daily==null or _pop.daily._lives.size()!=10:
			if now-_start>60000:_finish("startup_timeout")
			return
		_bound=now;_next=now
		for id:String in _pop.daily._lives:
			var life:RefCounted=_pop.daily._lives[id];var body:CharacterBody3D=life._token.body
			_rows[id]={"body_id":body.get_instance_id(),"start":body.global_position,"last":body.global_position,"max_displacement":0.0,"travel":0.0,"max_step":0.0,"leisure_started":false,"arrived":false,"bench_pose":false,"bench_path":"","walks_start":life._completed.walk,"pose_first_ms":-1,"night_displacement":0.0}
	if _pop.daily._lives.size()!=10 or _scene.preview_venue_staff29._rows.size()!=12:
		_finish("population_drift");return
	for id:String in _rows:
		var life:RefCounted=_pop.daily._lives.get(id)
		if life==null:_finish("life_missing");return
		var body:CharacterBody3D=life._token.body;var row:Dictionary=_rows[id]
		if body.get_instance_id()!=row.body_id:_finish("body_changed");return
		var step:float=body.global_position.distance_to(row.last)
		row.max_step=maxf(float(row.max_step),step);row.travel+=step;row.last=body.global_position
		row.max_displacement=maxf(float(row.max_displacement),body.global_position.distance_to(row.start))
		if _night_started_ms<0 and id in ["resident_2","resident_7"] and life._home58!=null:
			var home:Dictionary=life._home58.snapshot()
			if home.get("sleeping",false) and home.get("support_current",false) and home.get("claim_current",false):
				_sleep_proofs[id]={"home":home,"position":body.global_position,"elapsed_ms":now-_bound}
		if row.has("leisure_start_position"):
			row.night_displacement=maxf(float(row.night_displacement),body.global_position.distance_to(row.leisure_start_position))
		if life._goal.get("kind","")=="leisure" and life._roam51_active:
			if not row.leisure_started:row["leisure_start_position"]=body.global_position
			row.leisure_started=true;row.bench_path=str(life._goal.get("destination",{}).get("bench_path",""))
		if life._completed.walk>int(row.walks_start) and row.leisure_started:row.arrived=true
		if life._ambient29!=null:
			var ambient:Dictionary=life._ambient29.snapshot()
			if row.arrived and ambient.kind=="bench" and int(ambient.pose_frames)>8 and int(ambient.bench_inventory.occupied)>0:
				row.bench_pose=true;row["seated_bench_path"]=str(life._ambient29._seat.get("bench_path",""));row["pose_frames"]=ambient.pose_frames;row["bench_slot"]=ambient.bench_slot;row["seated_position"]=body.global_position
				if row.pose_first_ms<0:row.pose_first_ms=now-_bound
	if _night_started_ms<0 and _sleep_proofs.size()==2:
		var clock:RefCounted=get_tree().root.get_meta("mafiozi_visual_clock")
		assert(clock.set_hour(22.5));clock.running=false;_night_started_ms=now
	if now>=_next:
		_next=now+1000
		var sample:Dictionary={"elapsed_ms":now-_bound,"residents":{}}
		for id:String in _rows:
			var life:RefCounted=_pop.daily._lives[id]
			sample.residents[id]={"position":life._token.body.global_position,"phase":life._phase,"goal":life._goal.duplicate(true),"routine":life._routine58.snapshot(),"leisure":life._leisure58.snapshot() if life._leisure58!=null else {},"home":life._home58.snapshot() if life._home58!=null else {},"ambient":life._ambient29.snapshot() if life._ambient29!=null else {},"route":{"phase":life._roam51.phase(),"target":life._roam51.target(),"distance":life._roam51.distance_m(),"attempts":life._roam51.attempts(),"reason":life._roam51.last_reason(),"watch":life._roam51.roam_watch_state29()} if life._roam51_active else {}}
		_samples.append(sample)
	if _night_started_ms>=0 and now-_night_started_ms>=90000:_finish("window_complete")
	elif now-_bound>=300000:_finish("home_sleep_or_night_timeout")
func _finish(reason:String)->void:
	set_physics_process(false)
	var checks:Dictionary={"window_complete":reason=="window_complete","four_real_benches":_installation.get("ok",false),"nine_total_benches":_installation.get("registry",{}).get("benches",0)==9,"idempotent_install":_reinstall.get("ok",false) and _reinstall.get("registry",{}).get("benches",0)==9,"ten_residents_twelve_staff":_pop!=null and _pop.daily!=null and _pop.daily._lives.size()==10 and _scene.preview_venue_staff29._rows.size()==12}
	var completed:=false
	checks["both_actual_home_sleep_before_night_walk"]=_sleep_proofs.size()==2
	for id:String in ["resident_2","resident_7"]:
		var row:Dictionary=_rows.get(id,{})
		checks[id+"_no_teleport"]=float(row.get("max_step",INF))<=.2
		checks[id+"_actual_night_walk"]=row.get("leisure_started",false) and float(row.get("night_displacement",0.0))>=2.0
		if row.get("leisure_started",false) and row.get("arrived",false) and row.get("bench_pose",false) and float(row.get("max_displacement",0))>=2.0 and str(row.get("seated_bench_path","")).ends_with("OriginalBenchHome58"):completed=true
	checks["real_home_bench_walk_arrival_and_seated_pose"]=completed
	var result:Dictionary={"passed":not checks.values().has(false),"reason":reason,"checks":checks,"installation":_installation,"reinstall":_reinstall,"rows":_rows,"samples":_samples,"actual_sleep_proofs":_sleep_proofs,"night_started_ms":_night_started_ms,"scope":"Exact stage05 plus routine8 and bench helper overlays; original residents2/7 physically reach assigned home, sleep, physically exit and walk to real bench with committed pose.","clock_override":"Same shared clock03:00 paused until both late residents have actual sleep/support/claim proof, then22:30 paused on same day; no NPC position/health/money writes"}
	var file=FileAccess.open(_out.path_join("NIGHT_BENCHES58.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NIGHT_BENCHES58_RESULT ",JSON.stringify({"passed":result.passed,"checks":checks,"reason":reason}))
	get_tree().quit(0 if result.passed else 2)
