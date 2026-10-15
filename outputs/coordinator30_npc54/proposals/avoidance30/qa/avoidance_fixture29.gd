extends SceneTree
const World=preload("res://scripts/navigation/npc_avoidance_world29.gd")
const Route=preload("res://scripts/hospital/npc_physical_route51.gd")
const Simple=preload("res://scripts/hospital/npc_simple_hospital.gd")
class Records extends RefCounted:
	var _records:Dictionary={}
class Population extends RefCounted:
	var residents:RefCounted=Records.new()
class DoorHints extends RefCounted:
	var current:=0
	var actors:Array=[]
	func doorway_state29(body:CharacterBody3D)->Dictionary:
		var index:int=actors.find(body)
		return {"controlled":true,"mode":"waiting" if index>current else ("crossing" if index==current else "none"),"portal_owner":index==current}
class TestWorld extends Node3D:
	var _origin:=Vector3(20,0,20)
	var _block:Dictionary={"surface":{"cellSize":50.0,"startCol":0,"startRow":0,"grid":[[0]],"palette":{"0":{"kind":"ground","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
	var preview_population:RefCounted=Population.new()
var scene:Node3D
var actors:Array=[]
var routes:Array=[]
var result_rows:Array=[]
var output:=""
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func box(at:Vector3,size:Vector3)->StaticBody3D:
	var solid:=StaticBody3D.new();var shape:=CollisionShape3D.new();var resource:=BoxShape3D.new()
	resource.size=size;shape.shape=resource;solid.add_child(shape);scene.add_child(solid);solid.position=at
	return solid
func setup(origins:Array)->void:
	actors.clear();routes.clear()
	scene=TestWorld.new();root.add_child(scene);current_scene=scene
	box(Vector3(0,-.1,0),Vector3(35,.2,14))
	for index:int in origins.size():
		var actor:=CharacterBody3D.new();scene.add_child(actor);actor.position=origins[index]
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
		capsule.radius=.36;capsule.height=1.9;shape.shape=capsule;shape.position.y=.95;actor.add_child(shape)
		actors.append(actor)
		scene.preview_population.residents._records[str(index)]={"body":actor,"row":{"source_id":"resident_"+str(index)}}
	await physics_frame;await physics_frame
	for actor:CharacterBody3D in actors:
		var route:RefCounted=Route.new();assert(route.configure(actor));routes.append(route)
func scenario(label:String,origins:Array,goals:Array,door:bool=false,simple:bool=false)->void:
	await setup(origins)
	var service:RefCounted=World.for_scene(scene)
	var hints:RefCounted
	var obstacle:StaticBody3D
	var drives:Array=[];var drive_started:Dictionary={}
	if door:
		box(Vector3(-5,1,-1.2),Vector3(14,2,.2));box(Vector3(-5,1,1.2),Vector3(14,2,.2))
		box(Vector3(-12,1,0),Vector3(.2,2,2.4))
		obstacle=box(Vector3(0,1,0),Vector3(.25,2,2.4))
		hints=DoorHints.new();hints.actors=actors;scene.set_meta("npc_venue_registry29",hints)
	if simple:
		for index:int in actors.size():
			var drive:RefCounted=Simple.new();drives.append(drive)
			if not door:assert(drive.begin(goals[index],actors[index],RID(),"resident_"+str(index),"roam"));drive_started[index]=true
	var arrived:Dictionary={};var crossed:Array=[];var minimum:=INF;var max_scan:=0;var max_decisions:=0
	var closed_clear:=true;var fifo_hold:=true;var door_overlap:=false
	var began:int=Time.get_ticks_msec();var frames:=0
	while Time.get_ticks_msec()-began<22000 and arrived.size()<actors.size():
		await physics_frame;frames+=1
		if door and Time.get_ticks_msec()-began>=2000 and is_instance_valid(obstacle):obstacle.queue_free();obstacle=null
		service.refresh(scene)
		for index:int in actors.size():
			var actor:CharacterBody3D=actors[index];var route:RefCounted=routes[index]
			if arrived.has(index):route.hold(1.0/60.0);continue
			var desired:Vector3=goals[index]-actor.global_position;desired.y=0.0
			if desired.length()<.3:arrived[index]=true;route.hold(1.0/60.0);continue
			if simple:
				if door and index>int(hints.current):route.hold(1.0/60.0);continue
				if not drive_started.has(index):
					assert(drives[index].begin(goals[index],actor,RID(),"resident_"+str(index),"service_approach"));drive_started[index]=true
				var status:String=drives[index].step(1.0/60.0)
				if status=="arrived":arrived[index]=true
			else:
				var choice:Dictionary=service.steer(actor,desired.normalized(),1.8)
				var attempt:Vector3=choice.direction*minf(desired.length(),1.8*float(choice.ratio)/60.0)
				var before:Vector3=actor.global_position
				if bool(choice.waiting):route.hold(1.0/60.0)
				elif route.floor_at(actor.global_position+choice.direction*.35,actor.global_position.y) is Vector3:
					route.move(choice.direction,attempt.length(),1.0/60.0)
				else:route.hold(1.0/60.0)
			if door:
				if is_instance_valid(obstacle) and actor.position.x>-.45:closed_clear=false
				if index>int(hints.current) and absf(actor.position.x-float(origins[index].x))>.015:fifo_hold=false
				if index==int(hints.current) and actor.position.x>.9:
					if absf(actor.position.z)>.74:closed_clear=false
					crossed.append(index);hints.current+=1
		var inside:=0
		for a:int in actors.size():
			if absf(actors[a].position.x)<.55:inside+=1
			for b:int in range(a+1,actors.size()):minimum=minf(minimum,Vector2(actors[a].position.x-actors[b].position.x,actors[a].position.z-actors[b].position.z).length())
		if door and inside>1:door_overlap=true
		var diag:Dictionary=service.core.diagnostics();max_scan=maxi(max_scan,int(diag.max_scan));max_decisions=maxi(max_decisions,int(diag.decisions))
	var passed:bool=arrived.size()==actors.size() and minimum>=.718 and closed_clear and fifo_hold and not door_overlap
	if door:passed=passed and crossed==[0,1,2]
	result_rows.append({"label":label,"passed":passed,"arrived":arrived.size(),"actors":actors.size(),"minimum_center_separation_m":minimum,"frames":frames,"elapsed_ms":Time.get_ticks_msec()-began,"closed_door_clear":closed_clear,"fifo_waiters_held":fifo_hold,"crossing_order":crossed,"overlapping_door_users":door_overlap,"max_scan":max_scan,"max_decisions":max_decisions,"positions":actors.map(func(a:CharacterBody3D)->Vector3:return a.position)})
	for drive:RefCounted in drives:drive.cancel()
	for route:RefCounted in routes:route.cancel()
	scene.queue_free();await physics_frame;await physics_frame
func _run()->void:
	await create_timer(2.0).timeout
	await scenario("native_two_way",[Vector3(-4,.003,0),Vector3(4,.003,0)],[Vector3(6,.003,0),Vector3(-6,.003,0)])
	await scenario("native_merge_three",[Vector3(-4,.003,-1.5),Vector3(-4,.003,1.5),Vector3(-6,.003,0)],[Vector3(5,.003,0),Vector3(7,.003,0),Vector3(9,.003,0)])
	await scenario("native_fifo_closed_door",[Vector3(-2.8,.003,0),Vector3(-4.2,.003,0),Vector3(-5.6,.003,0)],[Vector3(4,.003,-1.5),Vector3(6,.003,1.5),Vector3(8,.003,0)],true,true)
	await scenario("actual_simple_driver_two_way",[Vector3(-4,.003,0),Vector3(4,.003,0)],[Vector3(6,.003,0),Vector3(-6,.003,0)],false,true)
	await setup([Vector3(0,.003,0)])
	var service:RefCounted=World.for_scene(scene);service.refresh(scene)
	var registered:bool=service.core.diagnostics().actors==1
	actors[0].collision_layer=0;await physics_frame;service.refresh(scene)
	var disabled:bool=service.core.diagnostics().actors==0 and service._entries.is_empty()
	actors[0].collision_layer=1;await physics_frame;service.refresh(scene)
	var restored:bool=service.core.diagnostics().actors==1
	actors[0].queue_free();await physics_frame;await physics_frame;service.refresh(scene)
	var freed:bool=service.core.diagnostics().actors==0 and service._entries.is_empty()
	result_rows.append({"label":"adapter_death_and_free_cleanup","passed":registered and disabled and restored and freed,"registered":registered,"death_collision_disabled_removed":disabled,"reactivated":restored,"queue_free_removed":freed})
	scene.queue_free();await physics_frame
	var passed:bool=result_rows.all(func(row:Dictionary)->bool:return row.passed)
	var report:Dictionary={"passed":passed,"cases":result_rows,"native_full_capsules":true,"max_simultaneous_fixture_bodies":3,"production_population_changed":false,"gameplay_performance_accepted":false}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("AVOIDANCE29 ",JSON.stringify(report));quit(0 if passed else 1)
