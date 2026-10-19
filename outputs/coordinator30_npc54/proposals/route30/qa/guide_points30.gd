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
	var deadline:int=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline and drive._guide.status=="searching":
		await physics_frame;drive.step(1.0/60.0)
	check("guide_ready",drive._guide.status=="ready")
	for point:Vector3 in drive._guide._points:
		var floor:Variant=drive._route.floor_at(point,point.y)
		var rows:Array=[]
		for offset:Vector3 in [Vector3.ZERO,Vector3(0,0,1),Vector3(0,0,-1),Vector3(0,0,2),Vector3(0,0,-2),Vector3(0,0,4),Vector3(0,0,-4),Vector3(0,0,6),Vector3(0,0,-6),Vector3(0,0,8),Vector3(0,0,-8)]:
			var proposed:Vector3=point+offset;var supported:Variant=drive._route.floor_at(proposed,point.y)
			rows.append({"offset":offset,"floor":supported,"standing":supported is Vector3 and drive._route.standing(supported),"collider":drive._route._last_collider})
		samples.append({"point":point,"floor":floor,"raw_standing":drive._route.standing(point),"floor_standing":floor is Vector3 and drive._route.standing(floor),"candidates":rows})
	drive.cancel();body.queue_free();finish()
