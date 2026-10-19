extends Node
const Driver = preload("res://scripts/city/runtime/npc_threat_route30.gd")
class Residents extends RefCounted:
	var _records: Dictionary={}
	func occupants()->Array:return []
class Population extends RefCounted:
	var residents:=Residents.new()
	func occupants()->Array:return []
class World extends Node3D:
	var preview_population:=Population.new()
	var preview_venue_staff29: Node
	var _player: CharacterBody3D
	var _origin:=Vector3.ZERO
	var _block: Dictionary={}
var world: World
var checks: Dictionary={}
var evidence: Dictionary={}
var out := ""
func _ready()->void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func check(key:String,value:bool)->void:checks[key]=value
func frame()->void:await get_tree().physics_frame
func actor(id:String,point:Vector3)->CharacterBody3D:
	var body:=CharacterBody3D.new();body.name=id;body.collision_layer=1;body.collision_mask=1
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.9
	shape.shape=capsule;shape.position.y=.95;body.add_child(shape);world.add_child(body);body.position=point
	world.preview_population.residents._records[id]={"body":body,"row":{"source_id":id},"generation":1}
	return body
func box(id:String,point:Vector3,size:Vector3)->void:
	var fixed:=StaticBody3D.new();fixed.name=id;fixed.position=point
	var shape:=CollisionShape3D.new();var geometry:=BoxShape3D.new();geometry.size=size;shape.shape=geometry;fixed.add_child(shape);world.add_child(fixed)
func _run()->void:
	world=World.new();world.name="IsolatedFleeBudget58";get_tree().root.add_child(world);get_tree().current_scene=world
	var grid:Array=[]
	for z:int in range(40):
		var row:Array=[]
		for x:int in range(40):row.append(1)
		grid.append(row)
	world._block={"surface":{"grid":grid,"palette":{"1":{"solid":true,"kind":"grass","heightM":0.0},"2":{"solid":false,"kind":"water","heightM":-2.0}},"cellSize":1.0,"startCol":-20,"startRow":-20}}
	box("Floor",Vector3(0,-.1,0),Vector3(40,.2,40))
	box("SolidWall",Vector3(-1.2,1.5,0),Vector3(.3,3,12))
	var body:=actor("test58",Vector3(0,.003,0));await frame();await frame()
	var driver:=Driver.new();check("configured_real_capsule",driver.configure(body,"test58",1.8))
	check("begin_escape",driver.begin_escape58(Vector3(4,.003,0),0))
	var before:Vector3=body.global_position;var min_distance:=4.0;var max_step:=0.0;var max_speed:=0.0
	for i:int in range(180):
		await frame()
		driver.step(1.0/60.0)
		var travelled:float=Driver._flat(body.global_position,before)
		max_step=maxf(max_step,travelled);max_speed=maxf(max_speed,travelled*60.0);min_distance=minf(min_distance,Driver._flat(body.global_position,Vector3(4,.003,0)))
		before=body.global_position
		if driver.moved_m>=2.5:break
	check("actual_side_retreat",driver.moved_m>=2.5 and absf(body.position.x)<.2 and absf(body.position.z)>2.0)
	check("native_speed_110_percent",max_speed>1.8 and max_speed<2.1 and max_step<.04)
	check("distance_never_approaches_known_threat",min_distance>=3.99 and Driver._flat(body.global_position,Vector3(4,.003,0))>4.6)
	check("wall_preserved",body.collision_mask==1 and body.position.x>-.5)
	check("bounded_preselection",driver._selection58.size()<=10 and driver._selection58.size()>=4 and driver._work_us58()<200000)
	evidence.retreat={"snapshot":driver.snapshot(),"position":body.position,"max_speed":max_speed,"min_threat_distance":min_distance}
	driver.cancel()
	# Synthetic budget assignment is ONLY on this isolated fixture driver. No
	# city actor, money, physics transform or production route is overwritten.
	var limited:=Driver.new();check("second_driver_configured",limited.configure(body,"test58",1.8))
	limited._route.service_us29=199999;limited._selection_us58=2
	check("over_cap_begin",limited.begin_escape58(Vector3(4,.003,0),0))
	var queries:int=limited._route.queries;await frame();var first:String=limited.step(1.0/60.0)
	check("combined_cap_blocks_before_queries",first=="blocked" and limited.reason=="bounded_route_deadline" and limited._route.queries==queries and limited._selection58.is_empty())
	limited.cancel();check("retry_begin",limited.begin_escape58(Vector3(4,.003,0),1));await frame();var second:String=limited.step(1.0/60.0)
	check("retry_does_not_reset_incident_cap",second=="blocked" and limited._work_us58()==200001 and limited._route.queries==queries and limited.moved_m==0.0)
	evidence.budget=limited.snapshot();limited.cancel()
	var passed:bool=not checks.is_empty()
	for value:bool in checks.values():passed=passed and value
	var result:Dictionary={"passed":passed,"reason":"complete","checks":checks,"evidence":evidence,"isolated_fixture":true,"city_behavior_acceptance":false,"production_modified":false}
	var file:=FileAccess.open(out.path_join("UNIT58.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("UNIT58_FINISH ",JSON.stringify(result));get_tree().quit(0 if passed else 1)
