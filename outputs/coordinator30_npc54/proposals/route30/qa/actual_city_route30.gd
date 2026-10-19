extends SceneTree
const Simple = preload("res://scripts/hospital/npc_simple_hospital.gd")
const Budget = preload("res://scripts/hospital/npc_route_budget29.gd")
const Work = preload("res://scripts/navigation/npc_navigation_work29.gd")
const START := Vector3(136.338562,.003,-13.815775)
const GOAL := Vector3(69.7,.303,1)
var output := ""
var game:Node3D
var checks:Array[Dictionary]=[]
var samples:Array[Dictionary]=[]
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func check(label:String,ok:bool,extra:Dictionary={})->bool:
	extra.merge({"label":label,"passed":ok});checks.append(extra);return ok
func finish()->void:
	var passed:bool=checks.all(func(row:Dictionary)->bool:return row.passed)
	var report:Dictionary={"passed":passed,"checks":checks,"samples":samples,"actual_city":true,"production_residents":1,"extra_plain_fixture_capsules":1,"relocations_after_test_begin":0,"performance_accepted":false,"heap_leak_acceptance":false}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ACTUAL_CITY_ROUTE30 ",JSON.stringify(report));quit(0 if passed else 1)
func _run()->void:
	game=load("res://scenes/main_city.tscn").instantiate();root.add_child(game);current_scene=game
	var ready_until:int=Time.get_ticks_msec()+90000
	var pop:RefCounted
	while Time.get_ticks_msec()<ready_until:
		await physics_frame
		pop=game.get("preview_population")
		if game.get("preview_ready")==true and pop!=null and pop.get("city_ready")==true and pop.get("daily")!=null:break
	if not check("one_resident_city_ready",pop!=null and pop.get("city_ready")==true and pop.hit_owners.size()==1):finish();return
	var map:RID=pop.navigation._backend.map_rid()
	if not check("same_authoritative_native_map",map.is_valid() and NavigationServer3D.get_maps().has(map) and NavigationServer3D.map_get_iteration_id(map)>0 and Work.queue_for_map(map)!=null):finish();return
	var body:=CharacterBody3D.new();body.name="Route30FixtureCapsule";body.collision_layer=1;body.collision_mask=1
	var shape:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.36;cap.height=1.9;shape.shape=cap;shape.position.y=.95;body.add_child(shape)
	game.add_child(body);body.global_position=START
	await physics_frame;await physics_frame
	var drive:RefCounted=Simple.new()
	if not check("exact_68m_service_begin",drive.begin(GOAL,body,map,"route30_native_capsule","service_approach")):finish();return
	check("service_uses_existing_guide_at_68m",drive._guide.diagnostics().distant and drive._guide.diagnostics().local_domain_m==24.0)
	var started:int=Time.get_ticks_msec();var last:int=-1000;var result:="";var max_local_distance:=0.0;var progress:=0.0;var previous_revision:=-1
	while Time.get_ticks_msec()-started<150000 and drive.active():
		await physics_frame
		var before:Vector3=body.global_position
		result=drive.step(1.0/60.0);progress+=Simple._flat(before,body.global_position)
		if drive._guide.status=="ready" and drive._guide.revision!=previous_revision:
			previous_revision=drive._guide.revision
			var waypoint:Vector3=drive._guide.waypoint()
			print("ROUTE30_CHECKPOINT ",JSON.stringify({"at":body.global_position,"goal":waypoint,"standing":drive._route.standing(waypoint),"points":drive._guide._points,"revision":previous_revision}))
		if drive._route.status=="searching" or drive._route.status=="ready":max_local_distance=maxf(max_local_distance,Simple._flat(before,drive._route.goal))
		if Time.get_ticks_msec()-last>=1000:
			last=Time.get_ticks_msec()
			samples.append({"ms":last-started,"position":body.global_position,"local_goal":drive._route.goal,"phase":drive.phase(),"reason":drive.last_reason(),"distance_m":drive.distance_m(),"route":drive._route.diagnostics(),"guide":drive._guide.diagnostics(),"watch":drive.service_watch_state30(),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
		if result in ["arrived","blocked"]:break
	var truthful:bool=(result=="arrived" and drive.distance_m()<Simple.ARRIVE_M) or (result=="blocked" and drive.distance_m()>Simple.ARRIVE_M and drive.service_watch_state30().get("blocked",false))
	check("long_guide_crosses_obstacles_without_fake_arrival",truthful and progress>60.0,{"result":result,"distance_m":drive.distance_m(),"progress_m":progress,"elapsed_ms":Time.get_ticks_msec()-started,"reason":drive.last_reason(),"watch":drive.service_watch_state30(),"outer_service_door_owner_absent_in_this_fixture":true,"full_hospital_acceptance":false})
	check("guide_never_collapses_to_75m_local_leg",max_local_distance<=24.5,{"max_local_distance_m":max_local_distance})
	drive.cancel();body.queue_free();await physics_frame;await physics_frame
	check("own_route_memory_released",drive._route._nodes.is_empty() and drive._route._open.is_empty() and drive._guide._points.is_empty() and drive._guide._physical30==null)
	for second in 12:
		await create_timer(1.0).timeout
		samples.append({"cleanup_second":second+1,"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"budget":Budget.diagnostics(),"native":Work.diagnostics(),"resident_count":pop.hit_owners.size()})
	check("population_still_one_after_cleanup",pop.hit_owners.size()==1 and pop.daily._lives.size()==1)
	finish()
