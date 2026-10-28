extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Ray=preload("res://scripts/transport/candidates/transport_vehicle_visual_triangle_ray_indexed.gd")
const Revised=preload("res://scripts/transport/candidates/transport_vehicle_visual_triangle_ray_revised.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func prepare_all(ray: RefCounted,r: Dictionary) -> Dictionary:
	var samples: Array[int]=[]
	for i in 10000:
		var start:=Time.get_ticks_usec(); var step: Dictionary=ray.prepare_step(r); samples.append(Time.get_ticks_usec()-start)
		if not step.ok: return {"ok":false,"error":step.get("error"),"steps":samples.size()}
		if step.status=="READY":
			samples.sort()
			return {"ok":true,"steps":samples.size(),"p95_us":samples[int((samples.size()-1)*.95)],"max_us":samples[-1],"total_us":_sum(samples),"meshes":step.meshes,"triangles":step.triangles}
	return {"ok":false,"error":"too_many_steps"}
func _sum(values: Array[int]) -> int:
	var total:=0
	for value in values: total+=value
	return total
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
	var start:=Time.get_ticks_usec(); var warm: Dictionary=prepare_all(a,r0); var cold_us:=Time.get_ticks_usec()-start
	check(warm.ok and prepare_all(b,other_r0).ok,"prewarm two vehicles")
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
	start=Time.get_ticks_usec(); var event: Dictionary=prepare_all(a,receipt(host,"car-a",1)); var event_us:=Time.get_ticks_usec()-start
	var r1:=receipt(host,"car-a",1)
	var moved: Dictionary=a.cast(r1,ray_origin,direction,5.0,"fallback")
	check(event.ok and moved.ok and absf(moved.hit.distance_m-1.2)<.000001,"same ArrayMesh in-place dent rebuilt; no stale alias")
	check(b.cast(other_r0,Vector3(5,0,1),direction,5.0,"fallback").ok,"other vehicle revision unaffected")
	begin=r1.duplicate(); begin.next_revision=2
	check(a.begin_geometry_change(begin,one),"replacement announced")
	var replacement:=triangle(-.4); one.mesh=replacement.mesh; replacement.free()
	check(prepare_all(a,receipt(host,"car-a",2)).ok,"replacement rebuilt")
	check(absf(a.cast(receipt(host,"car-a",2),ray_origin,direction,5.0,"fallback").hit.distance_m-1.4)<.000001,"replacement current geometry")
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"real hatch import")
	var metrics: Dictionary={"cold_us":cold_us,"synthetic_event_us":event_us,"synthetic_steps":warm.steps}
	if loaded.ok:
		var visual: RefCounted=loaded.visual; world.add_child(visual.root)
		visual.root.global_transform=Transform3D(Basis(Vector3.UP,.31),Vector3(5,1.5,-2))
		var real:=Ray.new(); var real_host:=RefCounted.new(); real.configure(visual.root,real_host,"real-hatch",1)
		var rr0:=receipt(real_host,"real-hatch",0)
		var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
		start=Time.get_ticks_usec(); var real_warm: Dictionary=prepare_all(real,rr0); metrics.real_ready_latency_us=Time.get_ticks_usec()-start
		metrics.real_prewarm_us=real_warm.get("total_us",0); metrics.step_p95_us=real_warm.get("p95_us",0); metrics.step_max_us=real_warm.get("max_us",0); metrics.steps=real_warm.get("steps",0)
		metrics.static_memory_delta_bytes=Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before
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
		start=Time.get_ticks_usec(); var real_event: Dictionary=prepare_all(real,receipt(real_host,"real-hatch",1)); metrics.real_event_us=Time.get_ticks_usec()-start
		check(real_event.ok and hit_node.mesh==same_resource,"real hatch same-resource vertex edit rebuilt")
		var real_after: Dictionary=real.cast(receipt(real_host,"real-hatch",1),source_origin,Vector3.FORWARD,5.0,"fallback")
		check(real_after.ok and not real_after.hit.is_empty(),"real hatch query after dent")
		metrics.real_before_distance=real_hit.hit.distance_m; metrics.real_after_distance=real_after.hit.get("distance_m",-1.0)
		metrics.real_meshes=real_warm.meshes; metrics.real_triangles=real_warm.triangles
		var baseline:=Revised.new(); var baseline_host:=RefCounted.new(); baseline.configure(visual.root,baseline_host,"baseline-hatch",1)
		var baseline_receipt:=receipt(baseline_host,"baseline-hatch",0)
		var baseline_warm: Dictionary=baseline.prewarm(baseline_receipt); check(baseline_warm.ok,"frozen revised baseline prewarm")
		var indexed_us: Array[int]=[]; var baseline_us: Array[int]=[]; var indexed_panel_us: Array[int]=[]; var baseline_panel_us: Array[int]=[]; var parity:=true
		for i in 30:
			var angle: float=float(i)*TAU/30.0
			var n:=Vector3(sin(angle),0,cos(angle))
			start=Time.get_ticks_usec(); var indexed_hit: Dictionary=real.cast(receipt(real_host,"real-hatch",1),center+n*4,-n,5.0,"fallback"); indexed_us.append(Time.get_ticks_usec()-start)
			start=Time.get_ticks_usec(); var baseline_hit: Dictionary=baseline.cast(baseline_receipt,center+n*4,-n,5.0,"fallback"); baseline_us.append(Time.get_ticks_usec()-start)
			if not indexed_hit.ok or not baseline_hit.ok or indexed_hit.hit.is_empty()!=baseline_hit.hit.is_empty(): parity=false
			elif not indexed_hit.hit.is_empty() and (indexed_hit.hit.object!=baseline_hit.hit.object or indexed_hit.hit.surface!=baseline_hit.hit.surface or indexed_hit.hit.triangle!=baseline_hit.hit.triangle or indexed_hit.hit.point_source.distance_to(baseline_hit.hit.point_source)>.000001 or indexed_hit.hit.normal_source.distance_to(baseline_hit.hit.normal_source)>.000001 or absf(indexed_hit.hit.distance_m-baseline_hit.hit.distance_m)>.000001): parity=false
			start=Time.get_ticks_usec(); var indexed_panel: Dictionary=real.cast(receipt(real_host,"real-hatch",1),center+n*2,-n,1.65,"contact"); indexed_panel_us.append(Time.get_ticks_usec()-start)
			start=Time.get_ticks_usec(); var baseline_panel: Dictionary=baseline.cast(baseline_receipt,center+n*2,-n,1.65,"contact"); baseline_panel_us.append(Time.get_ticks_usec()-start)
			if not indexed_panel.ok or not baseline_panel.ok or indexed_panel.hit.is_empty()!=baseline_panel.hit.is_empty(): parity=false
			elif not indexed_panel.hit.is_empty() and (indexed_panel.hit.object!=baseline_panel.hit.object or indexed_panel.hit.surface!=baseline_panel.hit.surface or indexed_panel.hit.triangle!=baseline_panel.hit.triangle or indexed_panel.hit.point_source.distance_to(baseline_panel.hit.point_source)>.000001 or indexed_panel.hit.normal_source.distance_to(baseline_panel.hit.normal_source)>.000001 or absf(indexed_panel.hit.distance_m-baseline_panel.hit.distance_m)>.000001): parity=false
		indexed_us.sort(); baseline_us.sort(); indexed_panel_us.sort(); baseline_panel_us.sort()
		metrics.indexed_query_p50_us=indexed_us[14]; metrics.indexed_query_p95_us=indexed_us[27]; metrics.indexed_query_max_us=indexed_us[-1]
		metrics.baseline_query_p50_us=baseline_us[14]; metrics.baseline_query_p95_us=baseline_us[27]; metrics.baseline_query_max_us=baseline_us[-1]
		metrics.indexed_panel_p50_us=indexed_panel_us[14]; metrics.indexed_panel_p95_us=indexed_panel_us[27]; metrics.indexed_panel_max_us=indexed_panel_us[-1]
		metrics.baseline_panel_p50_us=baseline_panel_us[14]; metrics.baseline_panel_p95_us=baseline_panel_us[27]; metrics.baseline_panel_max_us=baseline_panel_us[-1]
		check(parity,"30 radial fallback plus 30 panel rays match frozen revised baseline on transformed hatch")
		baseline.dispose(); real.dispose(); visual.dispose()
	a.dispose(); b.dispose(); world.free()
	print("TRANSPORT_VISUAL_TRIANGLE_RAY_INDEXED ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated incremental indexed candidate; no LIVE"}))
	quit(0 if failures.is_empty() else 1)
