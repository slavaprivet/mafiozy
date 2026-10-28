extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Baseline=preload("res://scripts/transport/transport_vehicle_debris.gd")
const Candidate=preload("res://scripts/transport/candidates/transport_vehicle_debris_unique_points.gd")
const PAIRS:=20
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
	var sources:=_sources(visual)
	check(sources.size()==10,"source explosion order has ten assemblies")
	var rows:=_rows(sources)
	var baseline:=Baseline.new(); var candidate:=Candidate.new()
	var baseline_result: Dictionary=baseline.configure(visual.root,world,rows)
	var candidate_result: Dictionary=candidate.configure(visual.root,world,rows)
	check(baseline_result.get("ok",false) and candidate_result.get("ok",false),"baseline and candidate configure")
	check(baseline_result.get("assemblies",0)==10 and baseline_result.get("hulls",0)==76 and candidate_result.get("assemblies",0)==10 and candidate_result.get("hulls",0)==76 and candidate_result.get("vertices",-1)==baseline_result.get("vertices",-2),"10 bodies / 76 hulls / complete visual vertex receipt")
	if not baseline_result.get("ok",false) or not candidate_result.get("ok",false):
		baseline.dispose(); candidate.dispose(); visual.dispose(); finish({}); return
	var exact:=_compare_prepared(baseline,candidate,sources)
	check(exact.unique_bytes_equal,"all 76 hull point arrays equal first-occurrence exact unique baseline points")
	check(exact.support_equal,"all tested convex support extrema match frozen hulls")
	check(exact.strict_unique and exact.candidate_points<exact.baseline_points and candidate_result.get("duplicates_removed",-1)==exact.baseline_points-exact.candidate_points,"candidate removes only exact duplicate collision points")
	check(exact.private_meshes==76 and exact.private_materials==76 and exact.source_materials==29,"76 private meshes / 76 private materials / 29 source identities")
	check(exact.private_resources_independent,"private mesh/material Resources stay per-surface and source-independent")
	var comparison:=_benchmark_configure(visual.root,world,rows)
	var prewarm:=await _prewarm_pair(baseline,candidate)
	check(baseline.stats().ready and candidate.stats().ready,"both providers reach READY through inherited prewarm")
	var motions: Array=[]
	for i in sources.size(): motions.append({"linear_velocity":Vector3(i*.12,2.0+i*.05,-1),"angular_velocity":Vector3(.2,i*.08,-.3)})
	var at:=Time.get_ticks_usec(); var launched_baseline: Dictionary=baseline.launch(motions); var baseline_launch_us:=Time.get_ticks_usec()-at
	check(launched_baseline.get("ok",false) and launched_baseline.get("bodies",0)==10 and launched_baseline.get("hulls",0)==76,"baseline launch")
	check(_launched_contract(baseline,motions),"baseline launch velocity/layer/collision contract")
	baseline.reset()
	at=Time.get_ticks_usec(); var launched_candidate: Dictionary=candidate.launch(motions); var candidate_launch_us:=Time.get_ticks_usec()-at
	check(launched_candidate.get("ok",false) and launched_candidate==launched_baseline,"candidate launch receipt matches baseline")
	check(_launched_contract(candidate,motions),"candidate launch velocity/layer/collision contract")
	var settle_frames:=0
	while candidate.stats().sleeping<10 and settle_frames<900:
		await physics_frame; settle_frames+=1
	check(candidate.bodies().all(func(body: RigidBody3D): return body.global_position.is_finite()),"candidate bodies remain finite under actual physics")
	check(candidate.stats().sleeping==10,"deduplicated hull bodies collide and sleep naturally")
	candidate.reset(); baseline.dispose(); candidate.dispose(); visual.dispose()
	finish({"actual":{"assemblies":10,"hulls":76,"private_meshes":exact.private_meshes,"private_materials":exact.private_materials,"source_material_identities":exact.source_materials,"visual_vertices":baseline_result.get("vertices",0),"baseline_collision_points":exact.baseline_points,"candidate_collision_points":exact.candidate_points,"duplicates_removed":exact.baseline_points-exact.candidate_points,"baseline_point_payload_bytes":exact.baseline_points*12,"candidate_point_payload_bytes":exact.candidate_points*12,"settle_frames":settle_frames},"configure_20_pairs":comparison,"prewarm":prewarm,"launch_us":{"baseline":baseline_launch_us,"candidate":candidate_launch_us}})

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
	var unique_bytes_equal:=true; var support_equal:=true; var strict_unique:=true; var baseline_points:=0; var candidate_points:=0
	var private_mesh_ids: Dictionary={}; var private_material_ids: Dictionary={}; var source_mesh_ids: Dictionary={}; var source_material_ids: Dictionary={}
	for source: Node3D in sources: _collect_source_resources(source,source_mesh_ids,source_material_ids)
	for entry_index in baseline._entries.size():
		var left: Dictionary=baseline._entries[entry_index]; var right: Dictionary=candidate._entries[entry_index]
		if left.hulls.size()!=right.hulls.size() or left.collisions.size()!=right.collisions.size(): unique_bytes_equal=false; continue
		for hull_index in left.hulls.size():
			var left_points: PackedVector3Array=left.hulls[hull_index].points; var right_points: PackedVector3Array=right.hulls[hull_index].points
			var expected:=Candidate._exact_unique_points(left_points); baseline_points+=left_points.size(); candidate_points+=right_points.size()
			if expected.to_byte_array()!=right_points.to_byte_array(): unique_bytes_equal=false
			if Candidate._exact_unique_points(right_points).to_byte_array()!=right_points.to_byte_array(): strict_unique=false
			if not _support_equal(left_points,right_points): support_equal=false
			if left.collisions[hull_index].shape!=left.hulls[hull_index] or right.collisions[hull_index].shape!=right.hulls[hull_index]: unique_bytes_equal=false
		_collect_private_resources(right.template,private_mesh_ids,private_material_ids)
	var independent:=private_mesh_ids.size()==76 and private_material_ids.size()==76
	for id in private_mesh_ids: independent=independent and not source_mesh_ids.has(id)
	for id in private_material_ids: independent=independent and not source_material_ids.has(id)
	return {"unique_bytes_equal":unique_bytes_equal,"support_equal":support_equal,"strict_unique":strict_unique,"baseline_points":baseline_points,"candidate_points":candidate_points,"private_meshes":private_mesh_ids.size(),"private_materials":private_material_ids.size(),"source_materials":source_material_ids.size(),"private_resources_independent":independent}

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

func _prewarm_pair(baseline: RefCounted,candidate: RefCounted) -> Dictionary:
	var samples:={"baseline":[],"candidate":[]}
	while not baseline.stats().ready or not candidate.stats().ready:
		for row: Array in [["baseline",baseline],["candidate",candidate]]:
			if row[1].stats().ready: continue
			var at:=Time.get_ticks_usec(); var result: Dictionary=row[1].prewarm_step(10); samples[row[0]].append(Time.get_ticks_usec()-at)
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
	print("TRANSPORT_VEHICLE_DEBRIS_UNIQUE_POINTS ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated headless exact collision-point dedup/configure/prewarm/launch; no GPU/FPS/full-scene/adoption"}))
	quit(0 if failures.is_empty() else 1)
