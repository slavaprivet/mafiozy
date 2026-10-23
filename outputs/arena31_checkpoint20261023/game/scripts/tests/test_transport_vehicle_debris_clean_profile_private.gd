extends SceneTree
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Baseline = preload("res://scripts/transport/transport_vehicle_debris.gd")
const Candidate = preload("res://scripts/transport/candidates/transport_vehicle_debris_clean_profile_private.gd")
const BodyFactory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func _sources(visual: RefCounted) -> Array:
	var result: Array = []
	for id in ["front_left", "rear_left", "front_right", "rear_right"]: result.append(visual.doors[id])
	for name in ["Hood_lid", "Trunk_lid"]:
		for node in visual.nodes.values():
			if node.get_meta("source_name", "") == name: result.append(node); break
	for id in ["front_left", "front_right", "rear_left", "rear_right"]: result.append(visual.wheels[id].pivot)
	return result

func _rows(sources: Array) -> Array:
	var result: Array = []
	for i in sources.size(): result.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	return result

func _comparison(baseline: RefCounted, candidate: RefCounted, sources: Array, vehicle_root: Node3D) -> Dictionary:
	var max_point_error := 0.0
	var max_support_error := 0.0
	var equal_counts: bool = baseline._entries.size()==10 and candidate._entries.size()==10
	var directions := [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD,Vector3(1,1,1).normalized(),Vector3(-1,.4,.7).normalized(),Vector3(.3,-1,-.6).normalized()]
	for i in baseline._entries.size():
		var source_basis := Basis(sources[i].global_transform.basis.get_rotation_quaternion())
		var root_basis := Basis(vehicle_root.global_transform.basis.orthonormalized().get_rotation_quaternion())
		var a: Array = baseline._entries[i].hulls
		var b: Array = candidate._entries[i].hulls
		if a.size()!=b.size(): equal_counts=false; continue
		for j in a.size():
			var left: PackedVector3Array = a[j].points
			var right: PackedVector3Array = b[j].points
			if left.size()!=right.size(): equal_counts=false; continue
			for k in left.size(): max_point_error=maxf(max_point_error,(source_basis*left[k]).distance_to(root_basis*right[k]))
			for direction in directions:
				var ls := -INF; var rs := -INF
				for point in left: ls=maxf(ls,(source_basis*point).dot(direction))
				for point in right: rs=maxf(rs,(root_basis*point).dot(direction))
				max_support_error=maxf(max_support_error,absf(ls-rs))
	return {"equal_counts":equal_counts,"point_max_m":max_point_error,"support_max_m":max_support_error}

func _private_visuals(candidate: RefCounted, sources: Array) -> bool:
	var source_meshes: Dictionary = {}
	var source_materials: Dictionary = {}
	for source in sources: _resources(source,source_meshes,source_materials)
	var private_meshes: Dictionary = {}
	var private_materials: Dictionary = {}
	for entry: Dictionary in candidate._entries: _resources(entry.template,private_meshes,private_materials)
	if private_meshes.size()!=76 or private_materials.size()!=76: return false
	for id in private_meshes:
		if source_meshes.has(id): return false
	for id in private_materials:
		if source_materials.has(id): return false
	return true

func _resources(node: Node3D, meshes: Dictionary, materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		meshes[node.mesh.get_instance_id()] = true
		for s in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(s)
			if material != null: materials[material.get_instance_id()] = true
	for child in node.get_children():
		if child is Node3D: _resources(child,meshes,materials)

func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var ground := StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var collision := CollisionShape3D.new(); var ground_box := BoxShape3D.new(); ground_box.size=Vector3(180,.5,180); collision.shape=ground_box; collision.position.y=-.25; ground.add_child(collision)
	var catalogue := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	check(catalogue.get("ok",false),"verified visual catalogue")
	if not catalogue.get("ok",false): finish({}); return
	var record: Dictionary = catalogue.entries.city_hatchback
	var sha: String = record.sha256
	var descriptor_document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	var physics_descriptor: Dictionary = {}
	for value: Dictionary in descriptor_document.get("profiles",[]):
		if value.get("profile_id","")=="city_hatchback": physics_descriptor=value; break
	check(not physics_descriptor.is_empty(),"actual hatch physics descriptor")
	if physics_descriptor.is_empty(): finish({}); return
	var factory := BodyFactory.new()
	var cars: Array = []
	var baseline_us: Array[int] = []
	var candidate_us: Array[int] = []
	var memory: Dictionary = {}
	var candidate_memory_start:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var worst_point := 0.0
	var worst_support := 0.0
	var private_visuals := false
	for i in 10:
		var loaded := Visual.instantiate_visual(record,catalogue.base_path)
		check(loaded.get("ok",false),"load actual hatch "+str(i))
		if not loaded.get("ok",false): break
		var visual: RefCounted = loaded.visual
		var owner: RigidBody3D = factory.spawn_from_descriptor({"vehicle_id":"debris-pack-"+str(i),"life_generation":1,"profile_id":"city_hatchback","active":false,"position_m":Vector3(float(i%5)*18,2.5,float(i/5)*18),"yaw_rad":.43+i*.08,"source_clock":1},physics_descriptor)
		check(owner != null,"actual BodyFactory vehicle "+str(i))
		if owner == null: visual.dispose(); break
		if i==5:
			owner.rotation.x=.13
			owner.rotation.z=-.09
		world.add_child(owner)
		owner.add_child(visual.root)
		visual.root.set_meta("verified_glb_sha",sha)
		visual.root.set_meta("geometry_revision",0)
		var sources := _sources(visual)
		var rows := _rows(sources)
		var baseline := Baseline.new(); var candidate := Candidate.new()
		var at := Time.get_ticks_usec(); var base_result: Dictionary=baseline.configure(visual.root,world,rows,owner); baseline_us.append(Time.get_ticks_usec()-at)
		at=Time.get_ticks_usec(); var result: Dictionary=candidate.configure(visual.root,world,rows,owner,sha,0); candidate_us.append(Time.get_ticks_usec()-at)
		check(base_result.get("ok",false) and result.get("ok",false) and result.get("hulls",0)==76 and result.get("vertices",0)==142948,"actual 10/76/142948 "+str(i)+" "+str(result))
		if not result.get("ok",false):
			print("CLEAN_PACK_CONFIGURE_FAILED ",i," ",result)
			baseline.dispose(); candidate.dispose(); visual.dispose(); owner.free(); break
		check(result.get("reused_points",-1)==(0 if i==0 else 76),"all warm hull points reused into private shapes "+str(i))
		var comparison := _comparison(baseline,candidate,sources,visual.root)
		worst_point=maxf(worst_point,comparison.point_max_m)
		worst_support=maxf(worst_support,comparison.support_max_m)
		check(comparison.equal_counts and comparison.point_max_m<.00005 and comparison.support_max_m<.00005,"all compound hull points/support preserve cavities "+str(i)+" "+str(comparison))
		if i==0: private_visuals=_private_visuals(candidate,sources)
		baseline.dispose()
		cars.append({"visual":visual,"candidate":candidate,"owner":owner,"sources":sources})
		if i in [0,2,9]: memory[str(i+1)] = Performance.get_monitor(Performance.MEMORY_STATIC)
	check(private_visuals,"76 private visual mesh/material resources retained")
	if cars.size()!=10: finish({}); return
	var unsupported_import := Visual.instantiate_visual(record,catalogue.base_path)
	check(unsupported_import.get("ok",false),"nonrigid ancestry probe loads")
	if unsupported_import.get("ok",false):
		var unsupported_visual: RefCounted=unsupported_import.visual
		var unsupported_parent:=Node3D.new(); world.add_child(unsupported_parent)
		unsupported_parent.global_transform=Transform3D((Basis(Vector3.UP,.8)*Basis(Vector3.FORWARD,.27)).scaled(Vector3(1.08,.94,1.03)),Vector3(80,2.5,0))
		unsupported_parent.add_child(unsupported_visual.root)
		unsupported_visual.root.set_meta("verified_glb_sha",sha)
		unsupported_visual.root.set_meta("geometry_revision",0)
		var unsupported:=Candidate.new()
		check(unsupported.configure(unsupported_visual.root,world,_rows(_sources(unsupported_visual)),null,sha,0).get("error","")=="nonrigid_profile_transform","nonuniform rotated ancestry refuses cached pack")
		unsupported.dispose(); unsupported_visual.dispose(); unsupported_parent.free()
	# Keep the trusted world frame restricted to the actual rigid BodyFactory path.
	var scaled: Dictionary = cars[8]
	scaled.visual.root.scale=Vector3(1.01,1,1)
	check(scaled.candidate.prewarm_step(1).get("error","")=="nonrigid_profile_transform","later nonrigid parent/visual scale fails closed")
	scaled.visual.root.scale=Vector3.ONE
	var wrong_sha: Dictionary = cars[7]
	wrong_sha.visual.root.set_meta("verified_glb_sha","0".repeat(64))
	check(wrong_sha.candidate.prewarm_step(1).get("error","")=="clean_profile_changed","descriptor SHA change fails closed")
	wrong_sha.visual.root.set_meta("verified_glb_sha",sha)
	# A dirty source is rejected before adding physics shapes or launching.
	var dirty: Dictionary = cars[9]
	dirty.visual.root.set_meta("geometry_revision",1)
	check(dirty.candidate.prewarm_step(1).get("error","")=="clean_profile_changed","deformation revision invalidates before prewarm")
	check(dirty.candidate.launch([]).get("error","")=="clean_profile_changed","deformation revision invalidates before launch")
	# Preserve moving vehicle visual and collision world pose through inherited launch.
	var moving: Dictionary = cars[0]
	moving.owner.rotation.y += .32
	moving.owner.position += Vector3(2,-.4,1)
	var prepared_steps := 0
	var prewarm_max_us := 0
	while not moving.candidate.stats().ready and prepared_steps<200:
		var at := Time.get_ticks_usec(); var step: Dictionary=moving.candidate.prewarm_step(1); prewarm_max_us=maxi(prewarm_max_us,Time.get_ticks_usec()-at)
		check(step.get("ok",false),"bounded prewarm "+str(prepared_steps))
		prepared_steps+=1
		await physics_frame
	check(moving.candidate.stats().ready,"prewarm ready")
	var expected: Array[Transform3D] = []
	for source in moving.sources: expected.append(source.global_transform)
	var motions: Array = []
	for i in 10: motions.append({"linear_velocity":Vector3(float(i)*.12,2.0+i*.05,-1),"angular_velocity":Vector3(.2,i*.08,-.3)})
	var at := Time.get_ticks_usec(); var launch: Dictionary=moving.candidate.launch(motions); var launch_us := Time.get_ticks_usec()-at
	check(launch.get("ok",false) and launch.get("bodies",0)==10 and launch.get("hulls",0)==76,"moving launch 10/76")
	for i in moving.candidate.bodies().size():
		var body: RigidBody3D=moving.candidate.bodies()[i]
		check((body.global_transform*body.get_child(0).transform).is_equal_approx(expected[i]),"rigid move visual pose "+str(i))
		check(body.get_collision_exceptions().has(moving.owner),"source owner exclusion "+str(i))
	await physics_frame
	var awake: bool = moving.candidate.stats().sleeping<10
	var settle_frames := 0
	while moving.candidate.stats().sleeping<10 and settle_frames<1200:
		await physics_frame; settle_frames+=1
	check(awake and moving.candidate.stats().sleeping==10,"native physics awake then settled")
	# Mutating one provider's public Shape must not affect any other provider or
	# the point pack from which later private shapes are made.
	var shape: ConvexPolygonShape3D = cars[1].candidate._entries[0].hulls[0]
	var neighbor: ConvexPolygonShape3D = cars[2].candidate._entries[0].hulls[0]
	var active: ConvexPolygonShape3D = moving.candidate._entries[0].hulls[0]
	var neighbor_bytes := neighbor.points.to_byte_array()
	var active_bytes := active.points.to_byte_array()
	var cached_bytes: PackedByteArray = Candidate._packs[sha].meshes[0].points.to_byte_array()
	check(shape!=neighbor and shape!=active and neighbor!=active,"all per-car physical Shapes have private identities")
	shape.margin += .1
	shape.custom_solver_bias=.1
	var attacked := shape.points; attacked[0].x += 2.0; shape.points=attacked
	check(neighbor.points.to_byte_array()==neighbor_bytes and active.points.to_byte_array()==active_bytes,"shape point alias attack cannot affect another car")
	check(neighbor.margin!=shape.margin and neighbor.custom_solver_bias!=shape.custom_solver_bias,"shape margin/solver alias attack cannot affect another car")
	check(Candidate._packs[sha].meshes[0].points.to_byte_array()==cached_bytes,"cached profile points remain immutable after provider mutation")
	check(moving.candidate.stats().sleeping==10,"launched debris remains settled after other car shape attack")
	var sums := {"baseline":0,"candidate":0}
	for value in baseline_us: sums.baseline+=value
	for value in candidate_us: sums.candidate+=value
	for row: Dictionary in cars:
		row.candidate.dispose(); row.visual.dispose(); row.owner.free()
	await process_frame
	var candidate_memory_after_dispose:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var baseline_memory_start:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var baseline_memory: Dictionary={}
	var baseline_cars: Array=[]
	for i in 10:
		var loaded:=Visual.instantiate_visual(record,catalogue.base_path)
		if not loaded.get("ok",false): check(false,"baseline memory visual "+str(i)); break
		var visual: RefCounted=loaded.visual
		var owner: RigidBody3D=factory.spawn_from_descriptor({"vehicle_id":"debris-memory-"+str(i),"life_generation":1,"profile_id":"city_hatchback","active":false,"position_m":Vector3(float(i%5)*18,2.5,float(i/5)*18),"yaw_rad":.43+i*.08,"source_clock":1},physics_descriptor)
		if owner==null: check(false,"baseline memory body "+str(i)); visual.dispose(); break
		world.add_child(owner); owner.add_child(visual.root)
		var provider:=Baseline.new()
		check(provider.configure(visual.root,world,_rows(_sources(visual)),owner).get("hulls",0)==76,"baseline memory provider "+str(i))
		baseline_cars.append({"provider":provider,"visual":visual,"owner":owner})
		if i in [0,2,9]: baseline_memory[str(i+1)]=Performance.get_monitor(Performance.MEMORY_STATIC)
	for row: Dictionary in baseline_cars:
		row.provider.dispose(); row.visual.dispose(); row.owner.free()
	finish({"baseline_configure_us":baseline_us,"candidate_configure_us":candidate_us,"configure_sum_us":sums,"candidate_memory_start":candidate_memory_start,"candidate_memory_static_1_3_10_bytes":memory,"candidate_memory_after_dispose":candidate_memory_after_dispose,"baseline_memory_start":baseline_memory_start,"baseline_memory_static_1_3_10_bytes":baseline_memory,"memory_after_all_dispose":Performance.get_monitor(Performance.MEMORY_STATIC),"worst_point_error_m":worst_point,"worst_support_error_m":worst_support,"prewarm_steps":prepared_steps,"prewarm_step_max_us":prewarm_max_us,"launch_us":launch_us,"settle_frames":settle_frames,"scope":"actual GLB/headless CPU and physics; immutable CLEAN trust contract; no GPU or full city"})

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_CLEAN_PRIVATE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
