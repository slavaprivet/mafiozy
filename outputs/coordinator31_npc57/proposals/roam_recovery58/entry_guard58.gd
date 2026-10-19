extends SceneTree
## Native GDScript regression of the actual guard against recorded observations.
## This runs no physical simulation; the separate QA recovery fixture does that.
var checks:Dictionary={}

func _initialize()->void:
	call_deferred("_run")

func _arg(prefix:String)->String:
	for value:String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):return value.trim_prefix(prefix)
	return ""

func _flat(a:Array,b:Array)->float:
	return Vector2(float(a[0])-float(b[0]),float(a[2])-float(b[2])).length()

func _run()->void:
	# Allow the scheduler to register this exact owned child before it exits.
	await create_timer(2.0).timeout
	var baseline_script:Script=load("res://scripts/hospital/npc_simple_hospital.gd")
	var candidate_script:Script=load(_arg("--candidate="))
	var trace:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(_arg("--trace=")))
	var baseline:RefCounted=baseline_script.new()
	var candidate:RefCounted=candidate_script.new()
	var first_trigger_ms:int=-1
	var service_equal:bool=true
	var triggered_samples:int=0
	for row:Dictionary in trace.rows:
		var remaining:float=_flat(row.position,row.waypoint)
		var legacy:bool=baseline._service_waypoint_stalled56(1,int(row.way_key),remaining,float(row.delta_s))
		var current:bool=candidate._service_waypoint_stalled56(1,int(row.way_key),remaining,float(row.delta_s))
		service_equal=service_equal and legacy==current
		if current:
			triggered_samples+=1
			if first_trigger_ms<0:first_trigger_ms=int(row.measure_ms)
	checks.recorded_episode_has_762_samples=trace.rows.size()==762
	checks.recorded_guard_requests_replan=first_trigger_ms>=0
	checks.recorded_first_replan_under_10_seconds=first_trigger_ms>=0 and first_trigger_ms-int(trace.rows[0].measure_ms)<=10000
	checks.existing_service_guard_results_identical=service_equal
	# A sequence of locally improving waypoints may lead away from the final
	# destination: the guard receives only local remaining and waypoint identity.
	var detour:RefCounted=candidate_script.new()
	var legal_detour_ok:=true
	for way in range(8):
		for tick in range(60):
			legal_detour_ok=legal_detour_ok and not detour._service_waypoint_stalled56(7,way,2.0-float(tick)*.025,1.0/60.0)
	checks.local_waypoint_progress_preserves_detour=legal_detour_ok
	var aligned:RefCounted=candidate_script.new()
	var aligned_trigger:=-1
	for tick in range(190):
		if aligned._service_waypoint_stalled56(9,4,0.0,1.0/60.0) and aligned_trigger<0:aligned_trigger=tick
	checks.flat_aligned_guard_triggers=aligned_trigger>=179 and aligned_trigger<=182
	# A newly prepared path or a newly reached waypoint has its own local guard.
	checks.new_path_resets_local_guard=not aligned._service_waypoint_stalled56(10,4,0.0,1.0/60.0)
	checks.new_waypoint_resets_local_guard=not aligned._service_waypoint_stalled56(10,5,0.0,1.0/60.0)
	var passed:=true
	for value:bool in checks.values():passed=passed and value
	var result:Dictionary={"passed":passed,"checks":checks,"first_recorded_trigger_ms":first_trigger_ms,
		"first_recorded_trigger_after_s":float(first_trigger_ms-int(trace.rows[0].measure_ms))/1000.0,
		"triggered_recorded_samples":triggered_samples,"aligned_trigger_tick":aligned_trigger,
		"scope":"Native execution of the unmodified GDScript guard method; recorded observations are not a physics replay. Old roam callsite did not invoke this method. Separate native movement proof is required.",
		"full_city_acceptance":false,"performance_accepted":false}
	var out:=FileAccess.open(_arg("--out="),FileAccess.WRITE)
	out.store_string(JSON.stringify(result,"\t"));out.close()
	print("RECORDED_GUARD58 ",JSON.stringify(result))
	quit(0 if passed else 1)
