extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Baseline=preload("res://scripts/transport/transport_vehicle_debris.gd")
const Candidate=preload("res://scripts/transport/candidates/transport_vehicle_debris_incremental_prepare.gd")
const PAIRS:=20 # retained by the unused comparison helper copied for parity diagnostics
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var ground_collision:=CollisionShape3D.new(); var ground_shape:=BoxShape3D.new(); ground_shape.size=Vector3(80,.5,80)
	ground_collision.shape=ground_shape; ground_collision.position.y=-.25; ground.add_child(ground_collision)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.get("ok",false),"actual hatch visual loads")
	if not loaded.get("ok",false): finish({}); return
	var visual=loaded.visual; world.add_child(visual.root)
	visual.root.global_transform=Transform3D((Basis(Vector3.UP,.43)*Basis(Vector3.FORWARD,.27)).scaled(Vector3(1.08,.94,1.03)),Vector3(0,2.5,0))
	var launch_transform: Transform3D=visual.root.global_transform
	var sources:=_sources(visual)
	check(sources.size()==10,"source explosion order has ten assemblies")
	var rows:=_rows(sources)
	var baseline:=Baseline.new(); var candidate:=Candidate.new(); var at:=Time.get_ticks_usec()
	var baseline_result: Dictionary=baseline.configure(visual.root,world,rows); var baseline_configure_us:=Time.get_ticks_usec()-at
	check(baseline_result.get("ok",false) and baseline_result.get("assemblies",0)==10 and baseline_result.get("hulls",0)==76,"frozen baseline configures 10/76")
	check(candidate.configure(visual.root,world,rows).get("error","")=="incremental_begin_required","monolithic candidate configure is unavailable")
	at=Time.get_ticks_usec(); var begun: Dictionary=candidate.begin_configure(visual.root,world,rows,null,17); var begin_us:=Time.get_ticks_usec()-at
	check(begun.get("ok",false) and begun.get("state","")=="PREPARING" and begun.get("meshes_total",0)==76 and not begun.get("partial_provider_exposed",true),"transaction begins without exposing provider")
	check(candidate.launch([]).get("error","")=="PREPARATION_PENDING" and candidate.prewarm_step(1).get("error","")=="PREPARATION_PENDING","event/prewarm before configure fail explicitly")
	var stale_before:=candidate.preparation_receipt(); check(candidate.prepare_step(18).get("error","")=="stale_damage_revision" and candidate.preparation_receipt()==stale_before,"foreign damage revision is non-mutating")
	var step_us: Array=[]; var wall_at:=Time.get_ticks_usec(); var final_result: Dictionary={}
	while candidate.preparation_receipt().get("state","")=="PREPARING":
		check(candidate._entries.is_empty() and candidate._vehicle_root==null,"partial provider remains unpublished")
		at=Time.get_ticks_usec(); var step: Dictionary=candidate.prepare_step(17,1); step_us.append(Time.get_ticks_usec()-at)
		check(step.get("ok",false),"incremental mesh step "+str(step_us.size())+": "+str(step.get("error","")))
		if step_us.size()==11 or step_us.size()==39:
			visual.root.global_transform=Transform3D(Basis(Vector3.UP,.17)*visual.root.global_transform.basis,visual.root.global_position+Vector3(.71,0,-.43))
		if step.get("state","")=="CONFIGURED": final_result=step
		await process_frame
	var prepare_wall_us:=Time.get_ticks_usec()-wall_at
	check(final_result.get("assemblies",0)==10 and final_result.get("hulls",0)==76 and final_result.get("vertices",0)==baseline_result.get("vertices",-1),"atomic final commit publishes exact 10/76 receipt")
	check(candidate._entries.size()==10 and candidate._vehicle_root==visual.root,"complete provider publishes only at final boundary")
	var exact:=_compare_prepared(baseline,candidate,sources)
	check(exact.point_bytes_equal,"all 76 hull point byte arrays match frozen scalar path")
	check(exact.support_equal,"all tested convex support extrema match")
	check(step_us.size()==76,"rigid vehicle movement during preparation preserves all 76 exact hull snapshots")
	check(exact.private_meshes==76 and exact.private_materials==76 and exact.source_materials==29,"76 private meshes / 76 private materials / 29 source identities")
	check(exact.private_resources_independent,"private mesh/material Resources stay per-surface and source-independent")
	check(candidate.prewarm_step(1,18).get("error","")=="stale_damage_revision" and candidate.launch([],18).get("error","")=="stale_damage_revision","post-commit stale damage revision cannot prewarm or launch")
	visual.root.global_transform=launch_transform
	var prewarm:=await _prewarm_pair(baseline,candidate,17)
	check(baseline.stats().ready and candidate.stats().ready,"both providers reach READY through inherited prewarm")
	var motions: Array=[]
	for i in sources.size(): motions.append({"linear_velocity":Vector3(i*.12,2.0+i*.05,-1),"angular_velocity":Vector3(.2,i*.08,-.3)})
	at=Time.get_ticks_usec(); var launched_baseline: Dictionary=baseline.launch(motions); var baseline_launch_us:=Time.get_ticks_usec()-at
	check(launched_baseline.get("ok",false) and launched_baseline.get("bodies",0)==10 and launched_baseline.get("hulls",0)==76,"baseline launch")
	check(_launched_contract(baseline,motions),"baseline launch velocity/layer/collision contract")
	baseline.reset()
	at=Time.get_ticks_usec(); var launched_candidate: Dictionary=candidate.launch(motions,17); var candidate_launch_us:=Time.get_ticks_usec()-at
	check(launched_candidate.get("ok",false) and launched_candidate==launched_baseline,"candidate launch receipt matches baseline")
	check(_launched_contract(candidate,motions),"candidate launch velocity/layer/collision contract")
	var settle_frames:=0
	while candidate.stats().sleeping<10 and settle_frames<900:
		await physics_frame; settle_frames+=1
	check(candidate.bodies().all(func(body: RigidBody3D): return body.global_position.is_finite()),"candidate bodies remain finite under actual physics")
	check(candidate.stats().sleeping==10,"incrementally prepared bodies collide and sleep naturally")
	candidate.reset(); baseline.dispose(); candidate.dispose(); visual.dispose()
	await _failure_lifecycle(world,catalogue)
	finish({"actual":{"assemblies":10,"hulls":76,"private_meshes":exact.private_meshes,"private_materials":exact.private_materials,"source_material_identities":exact.source_materials,"vertices":baseline_result.get("vertices",0),"settle_frames":settle_frames},"baseline_configure_us":baseline_configure_us,"incremental":{"begin_us":begin_us,"steps":step_us.size(),"step":_distribution(step_us),"step_cpu_sum_us":_sum(step_us),"wall_us":prepare_wall_us},"prewarm":prewarm,"launch_us":{"baseline":baseline_launch_us,"candidate":candidate_launch_us}})

func _failure_lifecycle(world: Node3D,catalogue: Dictionary) -> void:
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.get("ok",false),"secondary failure-lifecycle visual")
	if not loaded.get("ok",false): return
	var visual=loaded.visual; world.add_child(visual.root); var sources:=_sources(visual); var helper:=Candidate.new()
	check(helper.begin_configure(visual.root,world,_rows(sources),null,4).get("ok",false),"secondary transaction begins")
	check(helper.prepare_step(4).get("ok",false),"secondary first mesh stages")
	var witness: Node3D=sources[0].get_child(0) as Node3D; var original:=witness.transform; witness.position.x+=.01
	check(helper.prepare_step(4).get("error","")=="assembly_pose_changed" and helper._entries.is_empty() and helper._vehicle_root==null,"source pose change aborts all partial preparation")
	witness.transform=original; helper.dispose()
	helper=Candidate.new(); check(helper.begin_configure(visual.root,world,_rows(sources),null,5).get("ok",false) and helper.cancel_preparation(),"explicit cancellation releases partial transaction")
	check(helper.launch([]).get("error","")=="not_configured","cancelled transaction cannot launch")
	helper.dispose()
	var hidden:=Node3D.new(); sources[0].add_child(hidden); hidden.visible=false
	var hidden_baseline:=Baseline.new(); helper=Candidate.new()
	check(hidden_baseline.configure(visual.root,world,_rows(sources)).get("error","")=="assembly_invisible" and helper.begin_configure(visual.root,world,_rows(sources),null,6).get("error","")=="assembly_invisible","hidden descendant rejection matches frozen subtree semantics")
	hidden_baseline.dispose(); helper.dispose(); hidden.free(); visual.dispose(); await process_frame

func _sum(values: Array) -> int:
	var total:=0
	for value in values: total+=int(value)
	return total

func _sources(visual: RefCounted) -> Array:
	var result: Array=[]
	for id in ["front_left","rear_left","front_right","rear_right"]: result.append(visual.doors[id])
	for source_name in ["Hood_lid","Trunk_lid"]:
		for node in visual.nodes.values():
			if node.get_meta("source_name","")==source_name: result.append(node); break
	for id in ["front_left","front_right","rear_left","rear_right"]: result.append(visual.wheels[id].pivot)
	return result

func _rows(sources: Array) -> Array:
	var result: Array=[]
	for i in sources.size(): result.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	return result

func _compare_prepared(baseline: RefCounted,candidate: RefCounted,sources: Array) -> Dictionary:
	var point_bytes_equal:=true; var support_equal:=true
	var private_mesh_ids: Dictionary={}; var private_material_ids: Dictionary={}; var source_mesh_ids: Dictionary={}; var source_material_ids: Dictionary={}
	for source: Node3D in sources: _collect_source_resources(source,source_mesh_ids,source_material_ids)
	for entry_index in baseline._entries.size():
		var left: Dictionary=baseline._entries[entry_index]; var right: Dictionary=candidate._entries[entry_index]
		if left.hulls.size()!=right.hulls.size() or left.collisions.size()!=right.collisions.size(): point_bytes_equal=false; continue
		for hull_index in left.hulls.size():
			var left_points: PackedVector3Array=left.hulls[hull_index].points; var right_points: PackedVector3Array=right.hulls[hull_index].points
			if left_points.to_byte_array()!=right_points.to_byte_array(): point_bytes_equal=false
			if not _support_equal(left_points,right_points): support_equal=false
			if left.collisions[hull_index].shape!=left.hulls[hull_index] or right.collisions[hull_index].shape!=right.hulls[hull_index]: point_bytes_equal=false
		_collect_private_resources(right.template,private_mesh_ids,private_material_ids)
	var independent:=private_mesh_ids.size()==76 and private_material_ids.size()==76
	for id in private_mesh_ids: independent=independent and not source_mesh_ids.has(id)
	for id in private_material_ids: independent=independent and not source_material_ids.has(id)
	return {"point_bytes_equal":point_bytes_equal,"support_equal":support_equal,"private_meshes":private_mesh_ids.size(),"private_materials":private_material_ids.size(),"source_materials":source_material_ids.size(),"private_resources_independent":independent}

func _collect_source_resources(node: Node3D,meshes: Dictionary,materials: Dictionary) -> void:
	if not node.visible: return
	if node is MeshInstance3D and not _opaque_mesh(node): return
	if node is MeshInstance3D and node.mesh!=null:
		meshes[node.mesh.get_instance_id()]=true
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if material!=null: materials[material.get_instance_id()]=true
	for child in node.get_children():
		if child is Node3D: _collect_source_resources(child,meshes,materials)

func _opaque_mesh(node: MeshInstance3D) -> bool:
	if node.mesh==null: return false
	for surface in node.mesh.get_surface_count():
		var material: Material=node.get_active_material(surface)
		if material==null: return false
		if material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	return true

func _geometry_isolation(world: Node3D,catalogue: Dictionary) -> void:
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.get("ok",false),"secondary actual hatch for shallow geometry isolation")
	if not loaded.get("ok",false): return
	var visual=loaded.visual; world.add_child(visual.root)
	var source: Node3D=visual.doors.front_left
	var helper:=Candidate.new(); var configured: Dictionary=helper.configure(visual.root,world,_rows([source]))
	check(configured.get("ok",false),"shallow candidate configures isolation assembly")
	if not configured.get("ok",false): helper.dispose(); visual.dispose(); return
	var source_mesh_node:=_first_opaque_mesh(source); var private_mesh_node:=_first_opaque_mesh(helper._entries[0].template)
	check(source_mesh_node!=null and private_mesh_node!=null and source_mesh_node.mesh!=private_mesh_node.mesh,"source/private mesh identities differ")
	if source_mesh_node==null or private_mesh_node==null: helper.dispose(); visual.dispose(); return
	var source_mesh:=source_mesh_node.mesh as ArrayMesh; var private_mesh:=private_mesh_node.mesh as ArrayMesh
	var source_material:=source_mesh_node.get_active_material(0) as StandardMaterial3D; var private_material:=private_mesh_node.get_active_material(0) as StandardMaterial3D
	check(source_material!=null and private_material!=null and source_material!=private_material,"explicit surface material copy is private")
	if source_material!=null and private_material!=null:
		var private_roughness:=private_material.roughness; source_material.roughness=clampf(source_material.roughness*.5,0,1)
		check(is_equal_approx(private_material.roughness,private_roughness),"source material mutation cannot alter private material")
		var source_color:=source_material.albedo_color; private_material.albedo_color=Color(.17,.29,.41,.83)
		check(source_material.albedo_color.is_equal_approx(source_color),"private material mutation cannot alter source material")
	var source_before:=_mesh_bytes(source_mesh); var private_before:=_mesh_bytes(private_mesh); var hull_before: PackedByteArray=helper._entries[0].hulls[0].points.to_byte_array()
	_mutate_first_vertex(source_mesh,.071)
	var source_after:=_mesh_bytes(source_mesh)
	check(source_after!=source_before and _mesh_bytes(private_mesh)==private_before,"in-place source geometry mutation cannot alter private mesh")
	_mutate_first_vertex(private_mesh,-.053)
	check(_mesh_bytes(private_mesh)!=private_before and _mesh_bytes(source_mesh)==source_after,"in-place private geometry mutation cannot alter source mesh")
	check(helper._entries[0].hulls[0].points.to_byte_array()==hull_before,"prepared collision points stay immutable across later mesh edits")
	helper.dispose(); visual.dispose()
	await process_frame

func _first_opaque_mesh(root_node: Node3D) -> MeshInstance3D:
	var stack: Array=[[root_node,true]]
	while not stack.is_empty():
		var row: Array=stack.pop_back(); var node: Node=row[0]; var is_root: bool=row[1]
		if node is Node3D and not node.visible and not is_root: continue
		if node is MeshInstance3D and _opaque_mesh(node): return node
		for child in node.get_children(): stack.append([child,false])
	return null

func _mesh_bytes(mesh: ArrayMesh) -> PackedByteArray:
	var rows: Array=[]
	for surface in mesh.get_surface_count(): rows.append([mesh.surface_get_primitive_type(surface),mesh.surface_get_arrays(surface)])
	return var_to_bytes(rows)

func _mutate_first_vertex(mesh: ArrayMesh,delta: float) -> void:
	var rows: Array=[]
	for surface in mesh.get_surface_count(): rows.append({"primitive":mesh.surface_get_primitive_type(surface),"arrays":mesh.surface_get_arrays(surface),"material":mesh.surface_get_material(surface)})
	var vertices: PackedVector3Array=rows[0].arrays[Mesh.ARRAY_VERTEX].duplicate(); vertices[0].x+=delta; rows[0].arrays[Mesh.ARRAY_VERTEX]=vertices
	mesh.clear_surfaces()
	for row: Dictionary in rows:
		mesh.add_surface_from_arrays(row.primitive,row.arrays); mesh.surface_set_material(mesh.get_surface_count()-1,row.material)

func _collect_private_resources(node: Node3D,meshes: Dictionary,materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		meshes[node.mesh.get_instance_id()]=true
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if material!=null: materials[material.get_instance_id()]=true
	for child in node.get_children():
		if child is Node3D: _collect_private_resources(child,meshes,materials)

func _support_equal(left: PackedVector3Array,right: PackedVector3Array) -> bool:
	for direction in [Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3(-1,2,.5).normalized(),Vector3(3,-.7,-2).normalized()]:
		var a:=-INF; var b:=-INF
		for point in left: a=maxf(a,point.dot(direction))
		for point in right: b=maxf(b,point.dot(direction))
		if a!=b: return false
	return true

func _benchmark_configure(vehicle_root: Node3D,parent: Node3D,rows: Array) -> Dictionary:
	var samples:={"baseline":[],"candidate":[]}
	for pair in PAIRS:
		var order: Array=[["baseline",Baseline],["candidate",Candidate]]
		if pair%2==1: order.reverse()
		for row: Array in order:
			var helper: RefCounted=row[1].new(); var at:=Time.get_ticks_usec(); var result: Dictionary=helper.configure(vehicle_root,parent,rows); var elapsed:=Time.get_ticks_usec()-at
			check(result.get("ok",false) and result.get("assemblies",0)==10 and result.get("hulls",0)==76,"configure benchmark "+row[0]+" pair "+str(pair))
			if result.get("ok",false): samples[row[0]].append(elapsed)
			helper.dispose()
	return {"baseline":_distribution(samples.baseline),"candidate":_distribution(samples.candidate)}

func _prewarm_pair(baseline: RefCounted,candidate: RefCounted,revision: int) -> Dictionary:
	var samples:={"baseline":[],"candidate":[]}
	while not baseline.stats().ready or not candidate.stats().ready:
		for row: Array in [["baseline",baseline],["candidate",candidate]]:
			if row[1].stats().ready: continue
			var at:=Time.get_ticks_usec(); var result: Dictionary=row[1].prewarm_step(10,revision) if row[0]=="candidate" else row[1].prewarm_step(10); samples[row[0]].append(Time.get_ticks_usec()-at)
			check(result.get("ok",false),"prewarm "+row[0])
		await physics_frame
	return {"baseline":_distribution(samples.baseline),"candidate":_distribution(samples.candidate)}

func _launched_contract(helper: RefCounted,motions: Array) -> bool:
	var bodies: Array=helper.bodies()
	if bodies.size()!=motions.size(): return false
	for i in bodies.size():
		var body:=bodies[i] as RigidBody3D
		if body==null or body.freeze or body.collision_layer!=8 or body.collision_mask!=3: return false
		if body.get_child_count()!=helper._entries[i].collisions.size()+1: return false
		if not body.linear_velocity.is_equal_approx(motions[i].linear_velocity) or not body.angular_velocity.is_equal_approx(motions[i].angular_velocity): return false
	return true

func _distribution(values: Array) -> Dictionary:
	var sorted:=values.duplicate(); sorted.sort(); var count:=sorted.size()
	if count==0: return {"count":0}
	var median: float=float(sorted[count/2]) if count%2 else (float(sorted[count/2-1])+float(sorted[count/2]))*.5
	var p95_index:=clampi(ceili(float(count)*.95)-1,0,count-1)
	return {"count":count,"min_us":sorted[0],"p50_us":median,"p95_us":sorted[p95_index],"max_us":sorted[-1],"samples_us":sorted}

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_VEHICLE_DEBRIS_INCREMENTAL_PREPARE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated headless transactional prepare/prewarm/launch; no GPU/FPS/full-scene/adoption"}))
	quit(0 if failures.is_empty() else 1)
