extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Ray=preload("res://scripts/transport/candidates/transport_vehicle_visual_triangle_ray_revised.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func receipt(host: RefCounted,id: String,revision: int) -> Dictionary:
	return {"authority":host,"vehicle_id":id,"life_generation":1,"geometry_revision":revision}
func triangle(z: float) -> MeshInstance3D:
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,z),Vector3(1,-1,z),Vector3(0,1,z)])
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new(); material.cull_mode=BaseMaterial3D.CULL_DISABLED; mesh.surface_set_material(0,material)
	var instance:=MeshInstance3D.new(); instance.mesh=mesh
	return instance
func rewrite_in_place(instance: MeshInstance3D,delta: Vector3) -> void:
	var mesh:=instance.mesh as ArrayMesh; var rows: Array=[]
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i in positions.size(): positions[i]=positions[i]+delta
		arrays[Mesh.ARRAY_VERTEX]=positions
		rows.append({"arrays":arrays,"material":mesh.surface_get_material(surface),"name":mesh.surface_get_name(surface)})
	mesh.clear_surfaces()
	for row: Dictionary in rows:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,row.arrays)
		var index:=mesh.get_surface_count()-1
		mesh.surface_set_material(index,row.material); mesh.surface_set_name(index,row.name)
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var host:=RefCounted.new(); var other:=RefCounted.new()
	var one:=triangle(0); var two:=triangle(0); world.add_child(one); world.add_child(two); two.position.x=5
	var a:=Ray.new(); var b:=Ray.new()
	check(a.configure(one,host,"car-a",1) and b.configure(two,host,"car-b",1),"two independent vehicle lifetimes")
	var r0:=receipt(host,"car-a",0); var other_r0:=receipt(host,"car-b",0)
	check(not a.cast(r0,Vector3(0,0,1),Vector3.FORWARD,5.0,"fallback").ok,"cold query fails closed")
	var start:=Time.get_ticks_usec(); var warm: Dictionary=a.prewarm(r0); var cold_us:=Time.get_ticks_usec()-start
	check(warm.ok and b.prewarm(other_r0).ok,"prewarm two vehicles")
	var ray_origin:=Vector3(0,0,1); var direction:=Vector3.FORWARD
	check(not a.cast(other_r0,ray_origin,direction,5.0,"fallback").ok,"cross vehicle receipt rejected")
	check(not a.cast(receipt(other,"car-a",0),ray_origin,direction,5.0,"fallback").ok,"forged authority rejected")
	var initial: Dictionary=a.cast(r0,ray_origin,direction,5.0,"fallback")
	check(initial.ok and absf(initial.hit.distance_m-1.0)<.000001,"cached initial geometry")
	one.visible=false
	check(a.cast(r0,ray_origin,direction,5.0,"fallback").hit.is_empty(),"visibility live without geometry revision")
	one.visible=true
	var mat:=one.mesh.surface_get_material(0) as StandardMaterial3D
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(a.cast(r0,ray_origin,direction,5.0,"fallback").hit.is_empty(),"material transparency live")
	mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	check(not a.cast(receipt(host,"car-a",1),ray_origin,direction,5.0,"fallback").ok,"forged future revision rejected")
	var saved_mesh: Mesh=one.mesh; var unannounced:=triangle(-.3); one.mesh=unannounced.mesh
	check(a.cast(r0,ray_origin,direction,5.0,"fallback").get("error")=="unannounced_geometry_change","unannounced mesh replacement fails closed")
	one.mesh=saved_mesh; unannounced.free()
	var added:=triangle(.2); one.add_child(added)
	check(a.cast(r0,ray_origin,direction,5.0,"fallback").get("error")=="unannounced_mesh_inventory_change","unannounced mesh inventory fails closed")
	added.free()
	var begin:=r0.duplicate(); begin.next_revision=1
	check(a.begin_geometry_change(begin,one),"host invalidates before in-place edit")
	check(not a.cast(r0,ray_origin,direction,5.0,"fallback").ok,"queries blocked during mutation")
	rewrite_in_place(one,Vector3(0,0,-.2))
	start=Time.get_ticks_usec(); var event: Dictionary=a.finish_geometry_change(receipt(host,"car-a",1)); var event_us:=Time.get_ticks_usec()-start
	var r1:=receipt(host,"car-a",1)
	var moved: Dictionary=a.cast(r1,ray_origin,direction,5.0,"fallback")
	check(event.ok and moved.ok and absf(moved.hit.distance_m-1.2)<.000001,"same ArrayMesh in-place dent rebuilt; no stale alias")
	check(b.cast(other_r0,Vector3(5,0,1),direction,5.0,"fallback").ok,"other vehicle revision unaffected")
	begin=r1.duplicate(); begin.next_revision=2
	check(a.begin_geometry_change(begin,one),"replacement announced")
	var replacement:=triangle(-.4); one.mesh=replacement.mesh; replacement.free()
	check(a.finish_geometry_change(receipt(host,"car-a",2)).ok,"replacement rebuilt")
	check(absf(a.cast(receipt(host,"car-a",2),ray_origin,direction,5.0,"fallback").hit.distance_m-1.4)<.000001,"replacement current geometry")
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"real hatch import")
	var metrics: Dictionary={"cold_us":cold_us,"synthetic_event_us":event_us}
	if loaded.ok:
		var visual: RefCounted=loaded.visual; world.add_child(visual.root)
		var real:=Ray.new(); var real_host:=RefCounted.new(); real.configure(visual.root,real_host,"real-hatch",1)
		var rr0:=receipt(real_host,"real-hatch",0)
		start=Time.get_ticks_usec(); var real_warm: Dictionary=real.prewarm(rr0); metrics.real_prewarm_us=Time.get_ticks_usec()-start
		check(real_warm.ok and real_warm.triangles>0,"real hatch prewarm current triangles")
		var center: Vector3=visual.root.global_transform*Vector3(0,.75,0)
		var source_origin: Vector3=center+Vector3.BACK*4
		start=Time.get_ticks_usec(); var real_hit: Dictionary=real.cast(rr0,source_origin,Vector3.FORWARD,5.0,"fallback"); metrics.real_fallback_us=Time.get_ticks_usec()-start
		check(real_hit.ok and not real_hit.hit.is_empty(),"real hatch cached ray")
		start=Time.get_ticks_usec(); var panel: Dictionary=real.cast(rr0,center+Vector3.BACK*2,Vector3.FORWARD,1.65,"contact"); metrics.real_panel_us=Time.get_ticks_usec()-start
		check(panel.ok and not panel.hit.is_empty(),"real hatch cached panel ray")
		var hit_node: MeshInstance3D=real_hit.hit.object
		var real_begin:=rr0.duplicate(); real_begin.next_revision=1
		check(real.begin_geometry_change(real_begin,hit_node),"real hatch in-place edit invalidated")
		var same_resource: Mesh=hit_node.mesh
		rewrite_in_place(hit_node,Vector3(0,0,.05))
		start=Time.get_ticks_usec(); var real_event: Dictionary=real.finish_geometry_change(receipt(real_host,"real-hatch",1)); metrics.real_event_us=Time.get_ticks_usec()-start
		check(real_event.ok and hit_node.mesh==same_resource,"real hatch same-resource vertex edit rebuilt")
		var real_after: Dictionary=real.cast(receipt(real_host,"real-hatch",1),source_origin,Vector3.FORWARD,5.0,"fallback")
		check(real_after.ok and not real_after.hit.is_empty(),"real hatch query after dent")
		metrics.real_before_distance=real_hit.hit.distance_m; metrics.real_after_distance=real_after.hit.get("distance_m",-1.0)
		metrics.real_meshes=real_warm.meshes; metrics.real_triangles=real_warm.triangles
		real.dispose(); visual.dispose()
	a.dispose(); b.dispose(); world.free()
	print("TRANSPORT_VISUAL_TRIANGLE_RAY_REVISED ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated revision-bound snapshot candidate; HOLD pending loaded-scene budget"}))
	quit(0 if failures.is_empty() else 1)
