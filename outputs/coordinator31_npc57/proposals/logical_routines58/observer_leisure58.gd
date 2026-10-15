extends Node
var _scene: Node3D
var _pop: RefCounted
var _start:=0
var _bound:=0
var _next:=0
var _out:=""
var _rows:Dictionary={}
var _samples:Array=[]
var _violations:Array=[]
func _ready()->void:
	_scene=get_parent();_start=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):_out=arg.trim_prefix("--qa-out=")
	assert(not _out.is_empty())
func _physics_process(_delta:float)->void:
	var now:int=Time.get_ticks_msec()
	if _bound==0:
		_pop=_scene.get("preview_population")
		if _pop==null or not _pop.city_ready or _pop.daily==null or _pop.daily._lives.size()!=10:
			if now-_start>60000:_finish("startup_timeout")
			return
		_bound=now;_next=now
		for id:String in _pop.daily._lives:
			var life:RefCounted=_pop.daily._lives[id];var body:CharacterBody3D=life._token.body
			_rows[id]={"body_id":body.get_instance_id(),"start":body.global_position,"last":body.global_position,"max_displacement":0.0,"travel":0.0,"max_step":0.0,"leisure_started":false,"arrived":false,"bench_pose":false,"walks_start":life._completed.walk}
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
		if life._goal.get("kind","")=="leisure" and life._roam51_active:row.leisure_started=true
		if life._completed.walk>int(row.walks_start):row.arrived=true
		if life._ambient29!=null:
			var ambient:Dictionary=life._ambient29.snapshot()
			if ambient.kind=="bench" and int(ambient.pose_frames)>8:row.bench_pose=true
	if now>=_next:
		_next=now+1000
		var sample:Dictionary={"elapsed_ms":now-_bound,"residents":{}}
		for id:String in _rows:
			var life:RefCounted=_pop.daily._lives[id]
			sample.residents[id]={"position":life._token.body.global_position,"phase":life._phase,"goal":life._goal.duplicate(true),"routine":life._routine58.snapshot(),"leisure":life._leisure58.snapshot() if life._leisure58!=null else {},"route":life._roam51.snapshot() if life._roam51_active else {}}
		_samples.append(sample)
	if now-_bound>=90000:_finish("window_complete")
func _finish(reason:String)->void:
	set_physics_process(false)
	var checks:Dictionary={"window_complete":reason=="window_complete","ten_residents_twelve_staff":_pop!=null and _pop.daily!=null and _pop.daily._lives.size()==10 and _scene.preview_venue_staff29._rows.size()==12}
	for id:String in ["resident_2","resident_7"]:
		var row:Dictionary=_rows.get(id,{})
		checks[id+"_purposeful_route"]=row.get("leisure_started",false)
		checks[id+"_actual_walk_2m"]=float(row.get("max_displacement",0))>=2.0
		checks[id+"_no_teleport"]=float(row.get("max_step",INF))<=.2
	checks["one_real_bench_arrival"]=_rows.get("resident_2",{}).get("arrived",false) or _rows.get("resident_7",{}).get("arrived",false)
	var result:Dictionary={"passed":not checks.values().has(false),"reason":reason,"checks":checks,"rows":_rows,"samples":_samples,"scope":"Stage04 plus routine overlay; actual night leisure, no home/sleep acceptance","clock_override":"same shared clock at22.5 paused; no NPC position/health/money writes"}
	var file=FileAccess.open(_out.path_join("LEISURE58.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("LEISURE58_RESULT ",JSON.stringify({"passed":result.passed,"checks":checks,"reason":reason}))
	get_tree().quit(0 if result.passed else 2)
