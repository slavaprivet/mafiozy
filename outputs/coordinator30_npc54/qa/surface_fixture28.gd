extends SceneTree
const Surface = preload("res://scripts/hospital/npc_walk_surface28.gd")
class TestWorld extends Node3D:
	var _origin:=Vector3.ZERO
	var _block: Dictionary={"surface":{"cellSize":4.1,"startCol":0,"startRow":0,"grid":[[0,1,1],[1,1,1],[1,1,1]],"palette":{"0":{"kind":"ground","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":0.0}}}}
var scene: Node3D
var actor: CharacterBody3D
var surface: RefCounted
var rows: Array=[]
var output:=""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func box(at:Vector3,size:Vector3)->StaticBody3D:
	var floor:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var resource:=BoxShape3D.new();resource.size=size;shape.shape=resource
	floor.add_child(shape);scene.add_child(floor);floor.position=at
	return floor
func check(label:String,at:Vector3,expected:bool)->void:
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1,[actor.get_rid()])
	var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
	var result:Dictionary=surface.check(at,hit)
	rows.append({"label":label,"expected":expected,"result":result,"passed":bool(result.ok)==expected})
func _run()->void:
	# Allow the scheduler to attach and record this short-lived native child.
	await create_timer(2.0).timeout
	scene=TestWorld.new();root.add_child(scene);current_scene=scene
	actor=CharacterBody3D.new();scene.add_child(actor);actor.position=Vector3(2,0,2)
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.36;capsule.height=1.9;shape.shape=capsule;shape.position.y=.95;actor.add_child(shape)
	surface=Surface.new()
	assert(surface.configure(scene,actor))
	box(Vector3(2.05,-.1,2.05),Vector3(4.1,.2,4.1))
	await physics_frame;await physics_frame
	check("dry_ground",Vector3(2.05,0,2.05),true)
	check("bare_water",Vector3(6.15,0,6.15),false)
	check("shore_capsule_over_water",Vector3(3.95,0,2.05),false)
	var plate:=box(Vector3(6.15,-.09,6.15),Vector3(2,.2,2))
	await physics_frame;await physics_frame
	check("submerged_support",Vector3(6.15,.01,6.15),false)
	plate.position.y=.2
	await physics_frame;await physics_frame
	check("dry_supported_bridge",Vector3(6.15,.3,6.15),true)
	plate.get_child(0).shape.size=Vector3(.4,.2,2)
	await physics_frame;await physics_frame
	check("bridge_narrower_than_capsule",Vector3(6.15,.3,6.15),false)
	var passed:bool=rows.all(func(row:Dictionary)->bool:return bool(row.passed))
	var result:Dictionary={"passed":passed,"native_physics":true,"capsule_radius":capsule.radius,"capsule_height":capsule.height,"cases":rows}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SURFACE28 ",JSON.stringify(result));quit(0 if passed else 1)
