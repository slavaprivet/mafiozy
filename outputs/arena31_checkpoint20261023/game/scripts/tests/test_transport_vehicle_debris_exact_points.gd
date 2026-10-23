extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Refresh=preload("res://scripts/transport/candidates/transport_vehicle_debris_exact_points.gd")
const Subdivider=preload("res://scripts/transport/transport_mesh_subdivision.gd")
const Deformation=preload("res://scripts/transport/transport_vehicle_deformation.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Solver=preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const REPEATS:=24
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var duplicate_fixture:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3.RIGHT,Vector3.ZERO,Vector3.BACK])
	var exact_fixture: PackedVector3Array=Refresh._exact_unique_points(duplicate_fixture)
	check(exact_fixture.to_byte_array()==PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK]).to_byte_array(),"exact dedup preserves first-occurrence coordinates and order")
	check(_support_equal(duplicate_fixture,exact_fixture),"exact duplicate removal preserves convex support")
	var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var ground_collision:=CollisionShape3D.new(); var ground_box:=BoxShape3D.new(); ground_box.size=Vector3(80,.5,80); ground_collision.shape=ground_box; ground_collision.position.y=-.25; ground.add_child(ground_collision)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"actual hatch GLB")
	if not loaded.ok: finish({}); return
	var visual=loaded.visual; world.add_child(visual.root); visual.root.position=Vector3(0,2.5,0)
	var lid: Node3D
	for node in visual.nodes.values():
		if node.get_meta("source_name","")=="Hood_lid": lid=node; break
	var assemblies: Array[Node3D]=[visual.doors.front_left,lid,visual.wheels.front_left.pivot]
	var rows: Array=[]
	for i in assemblies.size(): rows.append({"source":assemblies[i],"mass_kg":18.0+i*3,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05})
	var unconfigured:=Refresh.new()
	check(unconfigured.refresh_geometry(assemblies[0],[],0,1).error=="not_configured","refresh requires configured lifecycle")
	var debris:=Refresh.new(); var configured:=debris.configure(visual.root,world,rows,null,0)
	check(configured.ok and configured.assemblies==3,"candidate configured actual assemblies")
	if not configured.ok: finish({}); return
	# Refresh the actual prepared bodies: shapes have already entered the physics
	# server, but remain frozen and collision-disabled until the event launch.
	while not debris.stats().ready:
		check(debris.prewarm_step(1).ok,"bounded inherited prewarm")
		await physics_frame
	var dirty_nodes: Array[MeshInstance3D]=[]
	for assembly in assemblies: dirty_nodes.append(_first_opaque_mesh(assembly))
	check(dirty_nodes.all(func(n): return n!=null),"actual dirty meshes bound")
	var door_before:=debris.geometry_receipt(assemblies[0])
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[1]],0,1).error=="outside_assembly","outside assembly rejected")
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0],dirty_nodes[0]],0,1).error=="dirty_identity","duplicate dirty mesh rejected")
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],0,2).error=="stale_revision","revision jumps rejected")
	var child:=dirty_nodes[0] as Node3D; var child_transform:=child.transform; child.position.x+=.01
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],0,1).error=="source_pose","changed descendant pose rejected")
	child.transform=child_transform
	var assembly_scale:=assemblies[0].scale; assemblies[0].scale.x*=1.01
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],0,1).error=="source_scale","changed assembly scale rejected")
	assemblies[0].scale=assembly_scale
	var invalid_old: Mesh=dirty_nodes[0].mesh; dirty_nodes[0].mesh=_replacement_mesh(dirty_nodes[0],.02,false,true)
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],0,1).error=="geometry_nonfinite" and debris.geometry_receipt(assemblies[0])==door_before,"nonfinite geometry rejected atomically")
	dirty_nodes[0].mesh=invalid_old
	var door_meshes:=_opaque_meshes(assemblies[0])
	check(door_meshes.size()>1,"actual door has unreported-geometry witness")
	if door_meshes.size()>1:
		var other_old: Mesh=door_meshes[1].mesh; door_meshes[1].mesh=other_old.duplicate(true)
		check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],0,1).error=="unreported_geometry" and debris.geometry_receipt(assemblies[0])==door_before,"unreported replacement rejected atomically")
		door_meshes[1].mesh=other_old
	# Door changes the same ArrayMesh object; lid replaces geometry; wheel adds a
	# vertex to indexed surface layout, representing source subdivision.
	_deform_in_place(dirty_nodes[0],assemblies[0],.08)
	dirty_nodes[1].mesh=_replacement_mesh(dirty_nodes[1],.07,false,false)
	var triangles_before:=_triangle_count(dirty_nodes[2].mesh as ArrayMesh)
	var subdivision:=Subdivider.subdivide(dirty_nodes[2].mesh as ArrayMesh,.0001,triangles_before+1)
	check(subdivision.ok and subdivision.splits==1 and subdivision.triangles>triangles_before,"actual source subdivision changes wheel topology")
	if subdivision.ok: dirty_nodes[2].mesh=subdivision.mesh
	var labels:=["door_in_place","lid_replacement","wheel_subdivision"]
	var metrics:={}
	for assembly_index in assemblies.size():
		var assembly:=assemblies[assembly_index]; var dirty:=dirty_nodes[assembly_index]
		var before:=debris.geometry_receipt(assembly); var body_id: int=before.body_id; var times: Array[float]=[]; var revision:=0; var last_refresh: Dictionary={}
		for iteration in REPEATS:
			var at:=Time.get_ticks_usec(); var refreshed:=debris.refresh_geometry(assembly,[dirty],revision,revision+1); times.append(Time.get_ticks_usec()-at)
			last_refresh=refreshed
			check(refreshed.ok and refreshed.changed_meshes==1,"exact refresh "+labels[assembly_index])
			if not refreshed.ok:
				failures.append("refresh detail "+labels[assembly_index]+" "+JSON.stringify(refreshed)); break
			revision+=1
		var after:=debris.geometry_receipt(assembly)
		check(after.revision==REPEATS and after.shape_ids==before.shape_ids and after.material_ids==before.material_ids and after.body_id==body_id,"body/shape/material identity reused "+labels[assembly_index])
		check(after.private_mesh_ids!=before.private_mesh_ids,"private geometry replaced "+labels[assembly_index])
		check(_point_sets_equal_for(after.point_sets_by_source,_assembly_point_sets(assembly,after.bake_basis),[dirty.get_instance_id()]),"full exact unique point list "+labels[assembly_index])
		var expected_max:=_assembly_max(assembly)
		var collision_max:=-INF
		for maximum: Vector3 in after.point_maxima: collision_max=maxf(collision_max,maximum.x)
		check(absf(collision_max-expected_max)<.00001,"exact current collision geometry "+labels[assembly_index])
		check(debris.refresh_geometry(assembly,[dirty],revision-1,revision+1).error=="stale_revision","stale revision rejected "+labels[assembly_index])
		metrics[labels[assembly_index]]={"p50_us":_percentile(times,.50),"p95_us":_percentile(times,.95),"max_us":times.max(),"source_vertices":_vertex_count(assembly),"hull_points":last_refresh.get("hull_points",0),"duplicates_removed":last_refresh.get("duplicates_removed",0)}
	metrics["three_part_p95_sum_us"]=float(metrics.door_in_place.p95_us)+float(metrics.lid_replacement.p95_us)+float(metrics.wheel_subdivision.p95_us)
	var motions:=[]
	for i in assemblies.size(): motions.append({"linear_velocity":Vector3(i*.4,1.8,-.5),"angular_velocity":Vector3(.2,.1*i,-.2)})
	var launched:=debris.launch(motions)
	check(launched.ok and debris.bodies().size()==3,"refreshed bodies launch physically")
	if not launched.ok:
		failures.append("launch detail "+JSON.stringify(launched)); debris.dispose(); visual.dispose(); finish(metrics); return
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],REPEATS,REPEATS+1).get("error","")=="after_launch","refresh after launch rejected")
	var settle_frames:=0
	while debris.stats().sleeping<3 and settle_frames<900:
		await physics_frame; settle_frames+=1
	check(debris.stats().sleeping==3,"refreshed compound bodies collide and sleep")
	check(debris.bodies().all(func(body): return body.global_position.y>-1.0 and body.get_child_count()>1),"physical hulls remain active")
	metrics["settle_frames"]=settle_frames
	debris.reset()
	check(debris.refresh_geometry(assemblies[0],[dirty_nodes[0]],REPEATS,REPEATS+1).error=="after_launch","reset cannot reopen launched refresh lifecycle")
	debris.dispose(); visual.dispose()
	await _pending_and_deleted_lifecycle(world,catalogue)
	metrics["actual_solver_refresh"]=_actual_solver_refresh(world,catalogue)
	finish(metrics)

func _first_opaque_mesh(source: Node3D) -> MeshInstance3D:
	var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D and not node.visible: continue
		if node is MeshInstance3D and _opaque(node): return node
		for child: Node in node.get_children(): stack.append(child)
	return null
func _opaque(node: MeshInstance3D) -> bool:
	if node.mesh==null: return false
	for surface in node.mesh.get_surface_count():
		var material: Material=node.get_active_material(surface)
		if material==null or material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	return true
func _deform_in_place(node: MeshInstance3D, assembly: Node3D, amount: float) -> void:
	var replacement:=_replacement_mesh(node,amount,false,false) as ArrayMesh
	var current:=node.mesh as ArrayMesh; current.clear_surfaces()
	for surface in replacement.get_surface_count():
		current.add_surface_from_arrays(replacement.surface_get_primitive_type(surface),replacement.surface_get_arrays(surface))
		current.surface_set_material(surface,replacement.surface_get_material(surface))
func _replacement_mesh(node: MeshInstance3D, amount: float, subdivide: bool, nonfinite: bool) -> ArrayMesh:
	var result:=ArrayMesh.new()
	# The chosen vertex moves in mesh-local X; exactness is checked from current
	# source geometry rather than assuming a particular authored basis.
	for surface in node.mesh.get_surface_count():
		var arrays: Array=node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
		if surface==0 and not vertices.is_empty():
			vertices[0].x=NAN if nonfinite else vertices[0].x+amount
			if subdivide and not arrays[Mesh.ARRAY_INDEX].is_empty():
				var old_count:=vertices.size(); vertices.append(vertices[0]); arrays[Mesh.ARRAY_VERTEX]=vertices
				for slot in range(1,Mesh.ARRAY_INDEX):
					var value: Variant=arrays[slot]
					if value is PackedVector3Array and value.size()==old_count: value.append(value[0])
					elif value is PackedVector2Array and value.size()==old_count: value.append(value[0])
					elif value is PackedColorArray and value.size()==old_count: value.append(value[0])
					elif value is PackedFloat32Array and value.size()==old_count*4:
						for i in 4: value.append(value[i])
					elif value is PackedInt32Array and value.size()==old_count*4:
						for i in 4: value.append(value[i])
			else: arrays[Mesh.ARRAY_VERTEX]=vertices
		else: arrays[Mesh.ARRAY_VERTEX]=vertices
		result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),arrays)
		result.surface_set_material(surface,node.mesh.surface_get_material(surface))
	return result
func _assembly_max(source: Node3D) -> float:
	var inverse:=source.global_transform.affine_inverse(); var maximum:=-INF; var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D and not node.visible: continue
		if node is MeshInstance3D and _opaque(node):
			var relative: Transform3D=inverse*node.global_transform
			for surface in node.mesh.get_surface_count():
				var points: PackedVector3Array=relative*(node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
				for point in points: maximum=maxf(maximum,point.x)
		for child: Node in node.get_children(): stack.append(child)
	return maximum
func _assembly_point_sets(source: Node3D,bake_basis: Basis) -> Dictionary:
	var result: Dictionary={}; var inverse:=source.global_transform.affine_inverse()
	_append_point_sets(source,inverse,Transform3D(bake_basis,Vector3.ZERO),result)
	return result
func _append_point_sets(node: Node3D, inverse: Transform3D, bake: Transform3D, result: Dictionary) -> void:
	if not node.visible: return
	if node is MeshInstance3D and _opaque(node):
		var points:=PackedVector3Array(); var relative: Transform3D=bake*(inverse*node.global_transform)
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			points.append_array(relative*vertices)
		var seen: Dictionary={}; var unique:=PackedVector3Array()
		for point in points:
			if not seen.has(point): seen[point]=true; unique.append(point)
		result[node.get_instance_id()]=unique
	for child in node.get_children():
		if child is Node3D: _append_point_sets(child,inverse,bake,result)
func _point_sets_equal_for(actual: Dictionary,expected: Dictionary,ids: Array) -> bool:
	for id in ids:
		if not expected.has(id): return false
		if not actual.has(id) or not actual[id] is PackedVector3Array: return false
		if (actual[id] as PackedVector3Array).to_byte_array()!=(expected[id] as PackedVector3Array).to_byte_array(): return false
	return true
func _support_equal(full: PackedVector3Array,unique: PackedVector3Array) -> bool:
	for direction in [Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3(1,2,3).normalized(),Vector3(-3,1,-2).normalized()]:
		var a:=-INF; var b:=-INF
		for point in full: a=maxf(a,point.dot(direction))
		for point in unique: b=maxf(b,point.dot(direction))
		if a!=b: return false
	return true
func _opaque_meshes(source: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]; var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is Node3D and not node.visible: continue
		if node is MeshInstance3D and _opaque(node): result.append(node)
		for child in node.get_children(): stack.append(child)
	return result
func _triangle_count(mesh: ArrayMesh) -> int:
	var count:=0
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		count+=(indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3
	return count
func _pending_and_deleted_lifecycle(world: Node3D, catalogue: Dictionary) -> void:
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"secondary lifecycle visual")
	if not loaded.ok: return
	var visual=loaded.visual; world.add_child(visual.root); visual.root.position=Vector3(8,2.5,0)
	var source: Node3D=visual.wheels.front_right.pivot; var dirty:=_first_opaque_mesh(source)
	var helper:=Refresh.new(); var configured:=helper.configure(visual.root,world,[{"source":source,"mass_kg":24.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05}],null,4)
	check(configured.ok,"secondary pending candidate configured")
	if configured.ok:
		_deform_in_place(dirty,source,.01)
		check(helper.refresh_geometry(source,[dirty],4,5).ok,"refresh works while prewarm pending")
		check(helper.launch([{"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO}]).error=="PREWARM_PENDING","refresh does not bypass prewarm lifecycle")
		var original_parent:=source.get_parent(); source.reparent(world,true)
		check(helper.refresh_geometry(source,[dirty],5,6).error=="source_changed","reparented source rejected")
		source.reparent(original_parent,true); dirty.free()
		check(helper.refresh_geometry(source,[dirty],5,6).error=="hierarchy","deleted configured mesh rejected")
	helper.dispose(); visual.dispose()
func _actual_solver_refresh(world: Node3D, catalogue: Dictionary) -> Dictionary:
	var damage:=Bindings.load_oracle(); var profile: Dictionary={}
	for row: Dictionary in damage.get("rows",[]):
		if row.profile_id=="compact_sedan": profile=row; break
	var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	check(not profile.is_empty() and loaded.ok,"actual solver profile and GLB")
	if profile.is_empty() or not loaded.ok: return {"ok":false,"error":"fixture"}
	var visual=loaded.visual; var body:=RigidBody3D.new(); world.add_child(body)
	body.set_meta("vehicle_id","refresh-current-geometry"); body.set_meta("life_generation",1); body.set_meta("profile_id","compact_sedan"); body.add_child(visual.root)
	var bound:=Bindings.bind(visual,profile); var solver:=Solver.new(); var adapter:=Deformation.new()
	var setup_ok: bool=bound.ok and solver.configure("refresh-current-geometry",1,"compact_sedan",Solver.VISUAL_MANIFEST_SHA256,bound.crash_profile_source) and adapter.configure(visual,body,{"vehicle_id":"refresh-current-geometry","life_generation":1},bound.crash_profile_source)
	check(setup_ok,"actual solver and deformation adapter configured")
	if not setup_ok: visual.dispose(); body.free(); return {"ok":false,"error":"setup"}
	var prep: Dictionary={}; var prepare_begin:=Time.get_ticks_usec()
	while prep.get("status")!="READY":
		prep=adapter.prepare_step(1)
		if not prep.get("ok",false): break
	var prepare_us:=Time.get_ticks_usec()-prepare_begin
	check(prep.get("ok",false) and prep.get("status")=="READY","actual source subdivision prepared")
	var lid: Node3D
	for node in visual.nodes.values():
		if node.get_meta("source_name","")=="Hood_lid": lid=node; break
	var assemblies: Array[Node3D]=[visual.doors.front_left,visual.doors.rear_left,lid]
	var rows: Array=[]
	for assembly in assemblies: rows.append({"source":assembly,"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05})
	var helper:=Refresh.new(); var configured:=helper.configure(visual.root,world,rows,null,0)
	check(configured.ok,"candidate cached original assemblies before actual impact")
	if not configured.ok: adapter.dispose(); visual.dispose(); body.free(); return {"ok":false,"error":configured.get("error","")}
	var rest:=adapter.apply_snapshot(solver.deformation_snapshot_native())
	var hit:=solver.apply_impact_native({"vehicle_id":"refresh-current-geometry","life_generation":1,"physics_tick":1,"impact_sequence":1,"event_id":"refresh-current-hit","point_native_m":Vector3(-.08,.76,-2.18),"normal_native":Vector3(0,0,-1),"impact_speed_mps":14.0})
	var apply_begin:=Time.get_ticks_usec(); var applied:=adapter.apply_snapshot(solver.deformation_snapshot_native()); var apply_us:=Time.get_ticks_usec()-apply_begin
	check(rest.ok and hit.applied and applied.ok and applied.changed_meshes>0,"actual solver impact applied current subdivided geometry")
	var refreshed_assemblies:=0; var dirty_meshes:=0; var refresh_us:=0; var refreshed_vertices:=0; var hull_points:=0; var duplicates_removed:=0
	for assembly in assemblies:
		var dirty: Array=[]
		for changed: MeshInstance3D in applied.get("changed_nodes",[]):
			if changed==assembly or assembly.is_ancestor_of(changed): dirty.append(changed)
		if dirty.is_empty(): continue
		var started:=Time.get_ticks_usec(); var refreshed:=helper.refresh_geometry(assembly,dirty,0,1); refresh_us+=Time.get_ticks_usec()-started
		check(refreshed.ok,"actual changed_nodes intersection refreshes exact prepared debris")
		if refreshed.ok:
			refreshed_assemblies+=1; dirty_meshes+=dirty.size(); refreshed_vertices+=int(refreshed.vertices); hull_points+=int(refreshed.hull_points); duplicates_removed+=int(refreshed.duplicates_removed)
			var receipt:=helper.geometry_receipt(assembly)
			var dirty_ids: Array=[]
			for dirty_node: MeshInstance3D in dirty: dirty_ids.append(dirty_node.get_instance_id())
			check(_point_sets_equal_for(receipt.point_sets_by_source,_assembly_point_sets(assembly,receipt.bake_basis),dirty_ids),"actual solver collision point set equals current subdivided geometry")
	check(refreshed_assemblies>0,"actual impact intersects configured detachable assemblies")
	var result={"ok":refreshed_assemblies>0,"prepare_us":prepare_us,"apply_us":apply_us,"refresh_us":refresh_us,"changed_meshes":applied.get("changed_meshes",0),"dirty_meshes":dirty_meshes,"assemblies":refreshed_assemblies,"vertices":refreshed_vertices,"hull_points":hull_points,"duplicates_removed":duplicates_removed,"hulls":configured.get("hulls",0)}
	helper.dispose(); adapter.dispose(); visual.dispose(); body.free(); return result
func _vertex_count(source: Node3D) -> int:
	var count:=0; var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is MeshInstance3D and _opaque(node):
			for surface in node.mesh.get_surface_count(): count+=node.mesh.surface_get_array_len(surface)
		for child: Node in node.get_children(): stack.append(child)
	return count
func _percentile(values: Array[float], fraction: float) -> float:
	var sorted:=values.duplicate(); sorted.sort(); return sorted[clampi(int(ceil((sorted.size()-1)*fraction)),0,sorted.size()-1)]
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_EXACT_POINTS ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"repeats":REPEATS,"scope":"candidate exact dirty-assembly refresh; actual hatch physical collision; no integration/authority/GPU"}))
	quit(0 if failures.is_empty() else 1)
