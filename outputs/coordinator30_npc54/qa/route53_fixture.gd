extends SceneTree
const Route = preload("res://scripts/hospital/npc_physical_route51.gd")
class TestWorld extends Node3D:
	var _origin:=Vector3(20,0,20)
	var _block: Dictionary={"surface":{"cellSize":50.0,"startCol":0,"startRow":0,"grid":[[0]],"palette":{"0":{"kind":"ground","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
var scene: Node3D
var actor: CharacterBody3D
var walls: Array[Node]=[]
var rows: Array=[]
var output:=""
func _initialize()->void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func box(at:Vector3,size:Vector3)->StaticBody3D:
	var solid:=StaticBody3D.new();var shape:=CollisionShape3D.new();var resource:=BoxShape3D.new()
	resource.size=size;shape.shape=resource;solid.add_child(shape);scene.add_child(solid);solid.position=at
	return solid
func solve(label:String,goal:Vector3,expected:String,fallback:bool)->void:
	var route:RefCounted=Route.new();assert(route.configure(actor));route.begin(goal)
	var ticks:=0;var started:=Time.get_ticks_usec()
	while route.status=="searching" and ticks<1800:
		route.tick();ticks+=1
		await physics_frame
	var clear:=true;var previous:Vector3=actor.global_position
	for point:Vector3 in route.route:
		clear=clear and route.edge_clear(previous,point);previous=point
	var result:Dictionary=route.diagnostics()
	result.merge({"label":label,"expected":expected,"ticks":ticks,"elapsed_us":Time.get_ticks_usec()-started,"edges_clear":clear,
		"passed":route.status==expected and clear and (not fallback or route._coarse_fallback) and actor.collision_mask==1})
	rows.append(result)
func _run()->void:
	await create_timer(2.0).timeout
	scene=TestWorld.new();root.add_child(scene);current_scene=scene
	box(Vector3(0,-.1,0),Vector3(24,.2,8))
	actor=CharacterBody3D.new();scene.add_child(actor);actor.position=Vector3(-8,.003,0)
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.36;capsule.height=1.9;shape.shape=capsule;shape.position.y=.95;actor.add_child(shape)
	walls.append(box(Vector3(0,1,0),Vector3(.4,2,3.5)))
	await physics_frame;await physics_frame
	await solve("coarse_detour_full_capsule",Vector3(8,.003,0),"ready",false)
	for wall:Node in walls:wall.queue_free()
	walls.clear();await physics_frame;await physics_frame
	walls.append(box(Vector3(0,1,-5),Vector3(.4,2,10)))
	walls.append(box(Vector3(0,1,5.8),Vector3(.4,2,10)))
	await physics_frame;await physics_frame
	await solve("narrow_gap_falls_back_to_fine",Vector3(8,.003,0),"ready",true)
	# The .60 m gap cannot admit the unchanged .72 m diameter capsule.
	walls[1].position.z=5.6
	await physics_frame;await physics_frame
	await solve("subcapsule_gap_rejected",Vector3(8,.003,0),"blocked",true)
	var passed:bool=rows.all(func(row:Dictionary)->bool:return bool(row.passed))
	var result:Dictionary={"passed":passed,"native_physics":true,"radius":capsule.radius,"height":capsule.height,"mask":actor.collision_mask,"cases":rows}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ROUTE53 ",JSON.stringify(result));quit(0 if passed else 1)
