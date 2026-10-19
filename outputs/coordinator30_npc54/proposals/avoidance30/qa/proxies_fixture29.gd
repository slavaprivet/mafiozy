extends SceneTree
const Avoid=preload("res://scripts/navigation/npc_local_avoidance29.gd")
var output:=""
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func sample_case(label:String,spacing:float,progress:bool)->Dictionary:
	var service:=Avoid.new();var rows:Array[Avoid.FrameInput]=[]
	var samples:Array=[];var snapshot_samples:Array=[];var solve_samples:Array=[]
	for index:int in 286:
		var row:=Avoid.FrameInput.new();row.key="proxy_"+str(index).pad_zeros(3)
		row.position=Vector3(float(index%17)*spacing,0,float(index/17)*spacing)
		row.velocity=Vector3(1.8 if index%2==0 else -1.8,0,0);rows.append(row)
	var bounded:=true;var max_pairs:=0;var max_scans:=0;var admitted_by_frame:=[]
	for frame:int in 120:
		var start:int=Time.get_ticks_usec()
		if progress:
			for row:Avoid.FrameInput in rows:row.position+=row.velocity/60.0
		assert(service.snapshot(rows,frame,frame*17))
		for row:Avoid.FrameInput in rows:service.steer(row.key,row.velocity.normalized(),1.8)
		samples.append(Time.get_ticks_usec()-start)
		var state:Dictionary=service.diagnostics()
		bounded=bounded and state.decisions<=16 and state.max_scan<=64 and state.max_neighbors<=8 and state.scans<=16*64 and state.pair_evaluations<=16*8*3
		snapshot_samples.append(state.snapshot_us);solve_samples.append(state.solve_us)
		max_pairs=maxi(max_pairs,int(state.pair_evaluations));max_scans=maxi(max_scans,int(state.scans))
		if frame<18:admitted_by_frame.append(service._rows.values().filter(func(a:RefCounted)->bool:return int(a.state.decisions)>0).size())
	var all_served:bool=service._rows.values().all(func(a:RefCounted)->bool:return int(a.state.decisions)>=6)
	assert(service.snapshot([],120,2040));var cleaned:bool=service.diagnostics().states==0
	var overflow:Array[Avoid.FrameInput]=rows.duplicate()
	while overflow.size()<=384:overflow.append(rows[0])
	var refuses:bool=not service.snapshot(overflow,121,2057)
	var cold:int=samples[0]
	samples.sort();snapshot_samples.sort();solve_samples.sort()
	return {"label":label,"passed":bounded and all_served and cleaned and refuses,"count":286,"bounded":bounded,"all_served_at_least_6_times":all_served,"first_admissions_by_frame":admitted_by_frame,"max_pair_evaluations":max_pairs,"max_scans":max_scans,"cleanup":cleaned,"overflow_refused":refuses,"snapshot_p50_us":snapshot_samples[60],"solve_p50_us":solve_samples[60],"component_us":{"p50":samples[60],"p95":samples[114],"max":samples[-1],"cold_first_frame":cold}}
func lifecycle()->Dictionary:
	var service:=Avoid.new();var row:=Avoid.FrameInput.new();row.key="same_actor:life:1:body:1"
	var checks:Dictionary={}
	checks.initial=service.snapshot([row],0,0)
	checks.stale_frame=not service.snapshot([row],-1,0)
	checks.clock_backwards=not service.snapshot([row],1,-1)
	service.snapshot([row],1,4000)
	checks.first_attempt_not_stuck=not bool(service.steer(row.key,Vector3.RIGHT,1.8).replan)
	row.waiting=true;service.snapshot([row],2,8000)
	var held:Dictionary=service.steer(row.key,Vector3.RIGHT,1.8)
	checks.fifo_hold=held.waiting and held.ratio==0.0 and not held.replan
	row.waiting=false;service.snapshot([row],3,8017)
	var released:Dictionary=service.steer(row.key,Vector3.RIGHT,1.8)
	checks.fifo_resume=not released.waiting and not released.replan
	service.snapshot([row],100,20000)
	checks.paused_time_not_stuck=not bool(service.steer(row.key,Vector3.RIGHT,1.8).replan)
	var old_key:String=row.key;row.key="same_actor:life:2:body:1"
	service.snapshot([row],101,20017)
	checks.replacement=not service._rows.has(old_key) and service._rows.size()==1
	service.snapshot([],102,20034)
	checks.retirement=service._rows.is_empty() and service._cells.is_empty() and service._layers.is_empty()
	var other:=Avoid.FrameInput.new();other.key="other";other.position=Vector3(100,0,100)
	service.snapshot([row,other],103,20051);service.steer(row.key,Vector3.RIGHT,1.8)
	service.snapshot([row,other],104,20068)
	var changed:Dictionary=service.steer(row.key,Vector3.FORWARD,1.8)
	checks.next_frame_waypoint_heading=(changed.direction as Vector3).dot(Vector3.FORWARD)>.99
	return {"passed":checks.values().all(func(value:bool)->bool:return value),"checks":checks}
func _run()->void:
	await create_timer(2.0).timeout
	var cases:Array=[]
	cases.append(sample_case("ordinary_spaced_progress",5.0,true))
	cases.append(sample_case("dense_opposed_progress",1.1,true))
	cases.append(sample_case("dense_blocked",1.1,false))
	cases.append(sample_case("adversarial_one_cell",.01,false))
	var life:Dictionary=lifecycle()
	var report:Dictionary={"passed":cases.all(func(row:Dictionary)->bool:return row.passed) and life.passed,"lifecycle":life,"cases":cases,"synthetic_proxy_count":286,"spawned_bodies":0,"max_decisions_per_frame":16,"max_reconsideration_frames":18,"max_scanned_per_decision":64,"max_neighbors_per_decision":8,"bounds_do_not_require_sort":true,"includes_core_snapshot_and_all_286_calls":true,"native_adapter_gather_excluded":true,"gameplay_performance_accepted":false,"parallel_functional_not_clean_perf":true}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("AVOIDANCE_PROXIES29 ",JSON.stringify(report));quit(0 if report.passed else 1)
