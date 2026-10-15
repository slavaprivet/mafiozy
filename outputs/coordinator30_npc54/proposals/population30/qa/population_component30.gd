extends SceneTree
const Host=preload("res://scripts/npc_visual/preview_resident_host.gd")
const World=preload("res://scripts/navigation/npc_avoidance_world29.gd")
const Daily=preload("res://scripts/npc_city_daily.gd")
const Population=preload("res://scripts/npc_city_population.gd")
const Simple=preload("res://scripts/hospital/npc_simple_hospital.gd")
class TestWorld extends Node3D:
	var preview_population:RefCounted
	var _origin:=Vector3(50,0,50)
	var _block:Dictionary={"surface":{"cellSize":100.0,"startCol":0,"startRow":0,"grid":[[0]],"palette":{"0":{"kind":"ground","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
class StubPopulation extends RefCounted:
	var residents:RefCounted
class NavigationProbe extends RefCounted:
	var cancelled:Array=[]
	func cancel(request:int)->void:cancelled.append(request)
class TeardownProbe extends RefCounted:
	var disposed:=0
	func dispose()->void:disposed+=1
class TestLife extends RefCounted:
	var drive:RefCounted
	var _disposed:=false
	var _frame:=-1
	var _roam51_active:=false
	var _attention29:Dictionary={"active":false}
	var _ambient29:RefCounted
	var _dsh_last_ms:=0
	var _dsh_elapsed:=-1.0
	var _health:RefCounted
	var _visit:RefCounted
	var _phase:="IDLE"
	var _goal:Dictionary={}
	var _reason:="fixture"
	var _profile_peaks:Array=[]
	var ticks:=0
	var outcome:=""
	func _dsh_simple_goal_active()->bool:return drive!=null and drive.active()
	func _economy28_active()->bool:return false
	func _restaurant28_active()->bool:return false
	func step(delta:float)->void:
		_frame=Engine.get_physics_frames();ticks+=1
		if drive!=null:outcome=drive.step(delta)
var world:TestWorld
var output:=""
var checks:Array[Dictionary]=[]
var observations:Dictionary={}
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func check(label:String,ok:bool,detail:Dictionary={})->void:
	detail.merge({"label":label,"passed":ok});checks.append(detail)
func actor_at(id:String,pos:Vector3)->CharacterBody3D:
	var actor:=CharacterBody3D.new();actor.collision_layer=1;actor.collision_mask=1;actor.set_meta("source_id",id)
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.9
	shape.shape=capsule;shape.position.y=.95;actor.add_child(shape);world.add_child(actor);actor.position=pos
	return actor
func record_of(id:String,body:CharacterBody3D=null,generation:int=1)->Dictionary:
	return {"row":{"source_id":id},"body":body,"generation":generation,"request":-1,"activity":null,"melee_retaliation":null,"motion":null,"gait":null}
func index_checks()->void:
	var host:=Host.new();var nav:=NavigationProbe.new();host._navigation=nav
	for i in 287:
		var id:="resident_"+str(i+1);host._records[id]=record_of(id)
	var record:Dictionary=host._records.resident_1;record.body=actor_at("resident_1",Vector3(-20,.003,-20));record.request=99
	var activity:=TeardownProbe.new();var retaliation:=TeardownProbe.new();var rag:=TeardownProbe.new()
	record.activity=activity;record.melee_retaliation=retaliation;host._ragdolls.resident_1=rag
	host._active_track30(record)
	check("287_catalogue_only_one_work_record",host._records.size()==287 and host.active_records30().size()==1)
	record.single_dead28=true
	check("corpse_cannot_be_prematurely_removed",not host._cleanup_removed30(record) and host.active_records30().size()==1 and nav.cancelled.is_empty())
	record.single_dead28=false;record.single_successor28=RefCounted.new()
	check("respawn_wait_cannot_be_prematurely_removed",not host._cleanup_removed30(record))
	record.single_successor28=null
	check("final_removal_releases_owned_work",host._cleanup_removed30(record) and host.active_records30().is_empty() and record.request==-1 and nav.cancelled==[99] and activity.disposed==1 and retaliation.disposed==1 and rag.disposed==1)
	check("cleanup_idempotent",host._cleanup_removed30(record) and nav.cancelled==[99] and activity.disposed==1 and retaliation.disposed==1 and rag.disposed==1)
	var successor:=record_of("resident_1",actor_at("resident_1",Vector3(-20,.003,-20)),2)
	host._records.resident_1=successor;host._active_track30(successor)
	host._active_track30(record);host._active_prune30(record)
	check("old_record_cannot_replace_or_prune_successor",host.active_records30().size()==1 and is_same(host.active_records30()[0],successor) and not host._cleanup_removed30(record))
	check("source_catalogue_not_deleted",host._records.size()==287)
	host._cleanup_removed30(successor)
	check("successor_final_cleanup",host.active_records30().is_empty())
	host._navigation=null
func spatial_checks()->void:
	var host:=Host.new();var population:=StubPopulation.new();population.residents=host;world.preview_population=population
	for i in 12:
		var id:="resident_"+str(i+1);var body:=actor_at(id,Vector3(float(i%4)*2-3,.003,float(i/4)*2-2))
		host._records[id]=record_of(id,body);host._active_track30(host._records[id])
	var view:=World.new();check("snapshot_native_twelve_capsules",view.refresh(world) and view.query_state30().entries==12)
	var seen:Dictionary={};var sizes:Array=[]
	for i in 12:
		var found:Array=view.query_near30(Vector3.ZERO,12,4,16,"perception");sizes.append(found.size())
		for row:Dictionary in found:seen[row.source_id]=true
	check("fair_cursor_serves_all_twelve",seen.size()==12,{"served":seen.size(),"sizes":sizes})
	check("per_call_result_bound",sizes.all(func(n:int)->bool:return n<=4))
	check("separate_shot_channel",view.query_near30(Vector3.ZERO,12,32,128,"shot").size()==12)
	var state:Dictionary=view.query_state30();check("two_channel_global_scan_bound",state.scans_this_frame<=256 and state.cursors==2 and view._query_budget30.perception<=128 and view._query_budget30.shot<=128,{"state":state})
	var before:int=state.scans_this_frame
	for i in 20:view.query_near30(Vector3.ZERO,12,32,128,"perception")
	check("exhausted_budget_stays_bounded",view.query_state30().scans_this_frame<=256 and view._query_budget30.perception==128)
	check("unbounded_radius_and_channels_rejected",view.query_near30(Vector3.ZERO,65).is_empty() and view.query_near30(Vector3.ZERO,12,8,64,"unbounded").is_empty())
	await physics_frame
	var old:Dictionary=host._records.resident_1;var previous:CharacterBody3D=old.body
	var replacement:=record_of("resident_1",actor_at("resident_1",previous.global_position),2)
	previous.queue_free();host._records.resident_1=replacement;host._active_track30(replacement)
	check("refresh_replacement_generation",view.refresh(world))
	var rows:Array=view.query_near30(Vector3.ZERO,12,32,128,"shot")
	var ones:Array=rows.filter(func(row:Dictionary)->bool:return row.source_id=="resident_1")
	check("one_current_generation_only",ones.size()==1 and ones[0].body==replacement.body and ones[0].life_generation==2 and view.query_state30().entries==12)
	for record:Dictionary in host.active_records30():host._cleanup_removed30(record)
	await physics_frame;await physics_frame
	view.refresh(world)
	check("despawn_clears_both_snapshot_indexes",view.query_state30().entries==0 and view.query_state30().cells==0 and view.query_near30(Vector3.ZERO,12).is_empty())
	observations.spatial=view.query_state30();world.preview_population=null
func physical_checks()->void:
	var daily:=Daily.new();daily._physical_enabled30=1;daily._dsh_life_clock=0
	daily._scene=weakref(world);daily._dsh_slice=286;daily._dsh_budget_cache=1000
	var host:=Host.new();var population:=StubPopulation.new();population.residents=host;world.preview_population=population
	var bodies:Array[CharacterBody3D]=[];var lives:Array[TestLife]=[]
	for i in 3:
		var id:="walker_"+str(i);var body:=actor_at(id,Vector3(-10,.003,float(i)*4+10));bodies.append(body)
		host._records[id]=record_of(id,body);host._active_track30(host._records[id])
		var life:=TestLife.new();life.drive=Simple.new();lives.append(life);daily._lives[id]=life
	await physics_frame;await physics_frame
	for i in 3:
		var id:="walker_"+str(i);var body:CharacterBody3D=bodies[i];var life:TestLife=lives[i]
		check("native_driver_begin_"+str(i),life.drive.begin(body.global_position+Vector3(6,0,0),body,RID(),id,"service_approach"))
		check("wake_current_"+str(i),daily.wake_physical30(id))
	# Dormant lives are decision-only test doubles; the three moving bodies use
	# production Simple native physics through the actual full Daily.step path.
	var dormant:Array[TestLife]=[]
	for i in 284:
		var life:=TestLife.new();dormant.append(life);daily._lives["dormant_"+str(i)]=life
	await physics_frame;await physics_frame
	var frame_count:=0;var monotonic:=true;var double_tick:=false;var previous:Array[float]=[-10.0,-10.0,-10.0]
	for tick in 240:
		await physics_frame;frame_count+=1
		daily.step(1.0/60.0)
		var counts:Array=[]
		for life:TestLife in lives:counts.append(life.ticks)
		daily.step(1.0/60.0)
		for i in 3:
			if lives[i].ticks!=counts[i]:double_tick=true
			monotonic=monotonic and bodies[i].global_position.x>=previous[i]-.02;previous[i]=bodies[i].global_position.x
		if lives.all(func(life:TestLife)->bool:return life.outcome=="arrived"):break
	for i in 3:
		check("actual_native_arrival_"+str(i),lives[i].outcome=="arrived" and bodies[i].global_position.distance_to(Vector3(-4,.003,float(i)*4+10))<.8,{"ticks":lives[i].ticks,"position":bodies[i].global_position,"result":lives[i].outcome,"frames":frame_count})
	check("physics_frame_not_duplicated",not double_tick)
	check("physical_movement_not_scaled_by_decision_slice",monotonic and frame_count<240 and lives.all(func(life:TestLife)->bool:return life.ticks>60))
	check("dormant_rotation_not_starved_by_active_ticks",daily._lives.size()==287 and dormant.all(func(life:TestLife)->bool:return life.ticks>=1),{"served":dormant.filter(func(life:TestLife)->bool:return life.ticks>=1).size(),"count":dormant.size()})
	check("completed_drivers_leave_tick_set",daily._physical_lives30.is_empty())
	var old:RefCounted=lives[0];var next:=TestLife.new();daily._lives.walker_0=next;daily.wake_physical30("walker_0")
	check("old_generation_cannot_forget_new_life",not daily.forget_physical30("walker_0",old) and daily._physical_lives30.walker_0==next)
	check("exact_generation_retirement",daily.forget_physical30("walker_0",next) and daily._physical_lives30.is_empty())
	observations.physical=daily.physical_dispatch_state30()
	for body:CharacterBody3D in bodies:body.queue_free()
	world.preview_population=null
func _run()->void:
	world=TestWorld.new();root.add_child(world);current_scene=world
	var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(60,.2,60)
	collision.shape=shape;floor.add_child(collision);world.add_child(floor);floor.position=Vector3(0,-.1,0)
	await physics_frame;await physics_frame
	index_checks();await physics_frame;await physics_frame
	await spatial_checks();await physical_checks()
	await physics_frame;await physics_frame
	var passed:bool=checks.all(func(row:Dictionary)->bool:return row.passed)
	var report:Dictionary={"passed":passed,"checks":checks,"observations":observations,"native_capsules_peak":12,"catalogue_fixture_records":287,"actual_city_loaded":false,"physics_drivers_are_production_simple":true,"life_wrapper_is_test_double":true,"no_teleport_after_begin":true,"mass_acceptance":false,"performance_accepted":false}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("POPULATION_COMPONENT30 ",JSON.stringify(report));quit(0 if passed else 1)
