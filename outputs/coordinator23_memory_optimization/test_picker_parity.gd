extends SceneTree
var out:Dictionary={"checks":0,"errors":[]}
func check(ok:bool,label:String)->void:
	out.checks+=1
	if not ok:out.errors.append(label)
func sync(n:int)->void:
	for i:int in n:await physics_frame;await process_frame
func _initialize()->void:run.call_deferred()
func p95(a:Array)->float:a.sort();return a[mini(a.size()-1,int(a.size()*.95))] if not a.is_empty() else 0
func triangle_at(x:float=0.0,flipped:bool=false)->ArrayMesh:
	var mesh:=ArrayMesh.new();rewrite_triangle(mesh,x,flipped);return mesh
func rewrite_triangle(mesh:ArrayMesh,x:float,flipped:bool=false)->void:
	mesh.clear_surfaces()
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1+x,-1,0),Vector3(1+x,-1,0),Vector3(1+x,1,0) if flipped else Vector3(x,1,0)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func mutation_test(scene:Node3D,c:Node,candidate:RefCounted)->void:
	var holder:=Node3D.new();scene.add_child(holder)
	var node:=MeshInstance3D.new();node.mesh=triangle_at();node.set_meta("source_name","mutation_test");holder.add_child(node)
	var picker:RefCounted=candidate.get_script().new();picker.configure(c.renderer,holder,candidate._options,Callable(c,"_cargo_ray_clear"));picker.last_stats={"car_aabb_tests":0,"car_triangle_tests":0}
	check(not picker.car_clear(Vector3(0,.4,2),Vector3(0,.4,-2)),"initial triangle blocks")
	var same_mesh:Mesh=node.mesh
	rewrite_triangle(node.mesh,0,true)
	check(node.mesh==same_mesh,"same ArrayMesh instance mutated")
	check(picker.car_clear(Vector3(0,.4,2),Vector3(0,.4,-2)),"inplace samebounds topology invalidates cached intersection")
	rewrite_triangle(node.mesh,10,false)
	check(picker.car_clear(Vector3(0,0,2),Vector3(0,0,-2)),"inplace changedbounds old location clear")
	check(not picker.car_clear(Vector3(10,0,2),Vector3(10,0,-2)),"inplace changedbounds new location blocks")
	node.mesh=triangle_at(-10)
	check(picker.car_clear(Vector3(10,0,2),Vector3(10,0,-2)),"replacement old location clear")
	check(not picker.car_clear(Vector3(-10,0,2),Vector3(-10,0,-2)),"replacement new location blocks")
	node.mesh=triangle_at();node.scale=Vector3(2,2,2)
	check(not picker.car_clear(Vector3(0,.8,4),Vector3(0,.8,-4)),"scaled transform intersects correct triangle")
	node.scale=Vector3(0,1,1)
	check(not picker.car_clear(Vector3(0,0,2),Vector3(0,0,-2)),"singular transform failsclosed without inverse")
	node.free()
	check(picker.car_clear(Vector3(0,0,2),Vector3(0,0,-2)),"freed mesh instance safely skipped")
	holder.free()
func run()->void:
	var scene:Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready:await sync(1)
	var p:CharacterBody3D=scene._player;var t:Node3D=scene.preview_transport;var w:Node=scene.preview_weapons;var c:Node=w.get_node("WeaponCargo")
	p._free_mouse_look=true;var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.7);p.global_position.y=.01
	p._camera_yaw=0;p._camera_pitch=-.55;p._update_camera_rotation();t.compartments.set_open("trunk",true);await sync(90)
	for id:String in load("res://scripts/weapon_visual/weapon_visual_catalog.gd").IDS:
		if id=="none":continue
		check(w.equip(id).ok,id+" equip");check(c.store_held().ok,id+" store")
	var candidate:RefCounted=c._cargo_picker;var camera:Camera3D=p.get_preview_camera();var timings:Array=[];var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var expected:Array=[]
	for yi:int in range(-8,9):
		for pi:int in range(4,10):
			p._camera_yaw=yi*.08;p._camera_pitch=-pi*.1;p._update_camera_rotation()
			var started:=Time.get_ticks_usec();var hit:Dictionary=candidate.pick(camera);timings.append(Time.get_ticks_usec()-started)
			expected.append({"yaw":p._camera_yaw,"pitch":p._camera_pitch,"hit":hit.duplicate()})
	var built:=0;var resources:Dictionary={}
	for part:Dictionary in candidate._parts:
		if part.mesh!=null:built+=1
		var node:MeshInstance3D=part.node.get_ref();resources[node.mesh.get_instance_id()]=true
	out.normal_camera={"queries":timings.size(),"p95_us":p95(timings),"max_us":timings.back(),"retained_parts":candidate._parts.size(),"built_parts":built,"unique_mesh_resources":resources.size(),"static_growth_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before}
	var original:RefCounted=load("C:/Users/Слава/Desktop/Мафиози/outputs/coordinator23_memory_optimization/cargo_aim_picker_original.gd").new()
	original.configure(c.renderer,t.visual.root,candidate._options,Callable(c,"_cargo_ray_clear"))
	check(original._parts.size()==candidate._parts.size(),"all original car parts retained")
	for row:Dictionary in expected:
		p._camera_yaw=row.yaw;p._camera_pitch=row.pitch;p._update_camera_rotation();var old:Dictionary=original.pick(camera)
		check(old.get("hit",false)==row.hit.get("hit",false),"ordinary orbit hit parity")
		if old.get("hit",false):check(old.item_uid==row.hit.item_uid and old.point.distance_to(row.hit.point)<.0001,"ordinary orbit exact item/surface parity")
	for opened:bool in [false,true]:
		t.compartments.set_open("trunk",opened);await sync(90)
		for part:Dictionary in candidate._parts:
			var node:MeshInstance3D=part.node.get_ref();var target:Vector3=node.global_transform*node.mesh.get_aabb().get_center()
			for axis:Vector3 in [Vector3(0,2,4),Vector3(-3,1,0),Vector3(3,1,0)]:
				var from:Vector3=t.body.global_position+axis
				candidate.last_stats={"car_aabb_tests":0,"car_triangle_tests":0};original.last_stats={"car_aabb_tests":0,"car_triangle_tests":0}
				check(candidate.car_clear(from,target)==original.car_clear(from,target),"lid/part obstruction parity")
	var mesh:Mesh=candidate._parts[0].node.get_ref().mesh
	check(mesh.generate_triangle_mesh()==mesh.generate_triangle_mesh(),"native Mesh returns shared cached acceleration")
	candidate._options.generation+=1
	check(not candidate.pick(camera).get("hit",false),"stale generation rejected")
	candidate._options.generation-=1
	t.compartments.set_open("trunk",true);await sync(90)
	p._camera_yaw=0;p._camera_pitch=-.55;p._update_camera_rotation()
	mutation_test(scene,c,candidate)
	out.full_cargo=c.cargo.summary(c.generation);out.capacities={"surface":w.surface_effects.stats(),"rpg":w.rpg_effects.stats(),"projectiles":w.effects.stats()}
	FileAccess.open("C:/Users/Слава/Desktop/Мафиози/outputs/coordinator23_memory_optimization/PICKER_PARITY.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"));print("PICKER_PARITY ",out.checks," errors=",out.errors," normal=",out.normal_camera);scene.free();quit(0 if out.errors.is_empty() else 1)

