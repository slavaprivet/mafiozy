extends SceneTree
const Experiment=preload("res://scripts/transport/candidates/transport_vehicle_debris_clean_hull.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Deformation=preload("res://scripts/transport/transport_vehicle_deformation.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Solver=preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const REPEATS:=8
var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var ground_collision:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(100,.5,100); ground_collision.shape=box; ground_collision.position.y=-.25; ground.add_child(ground_collision)
	var damage:=Bindings.load_oracle(); var profile: Dictionary={}
	for row: Dictionary in damage.get("rows",[]):
		if row.profile_id=="compact_sedan": profile=row; break
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	check(not profile.is_empty() and loaded.ok,"actual compact sedan source")
	if profile.is_empty() or not loaded.ok: finish({}); return
	var visual=loaded.visual; var vehicle:=RigidBody3D.new(); world.add_child(vehicle)
	vehicle.set_meta("vehicle_id","clean-hull-experiment"); vehicle.set_meta("life_generation",1); vehicle.set_meta("profile_id","compact_sedan"); vehicle.add_child(visual.root)
	var bound:=Bindings.bind(visual,profile); var solver:=Solver.new(); var adapter:=Deformation.new()
	var setup: bool=bound.ok and solver.configure("clean-hull-experiment",1,"compact_sedan",Solver.VISUAL_MANIFEST_SHA256,bound.crash_profile_source) and adapter.configure(visual,vehicle,{"vehicle_id":"clean-hull-experiment","life_generation":1},bound.crash_profile_source)
	check(setup,"actual solver and adapter")
	if not setup: finish({}); return
	var prep: Dictionary={}
	while prep.get("status")!="READY":
		prep=adapter.prepare_step(1)
		if not prep.get("ok",false): break
	check(prep.get("status")=="READY","actual subdivided deformation prepared")
	var rest:=adapter.apply_snapshot(solver.deformation_snapshot_native())
	var hit:=solver.apply_impact_native({"vehicle_id":"clean-hull-experiment","life_generation":1,"physics_tick":1,"impact_sequence":1,"event_id":"clean-hull-hit","point_native_m":Vector3(-.08,.76,-2.18),"normal_native":Vector3(0,0,-1),"impact_speed_mps":14.0})
	var applied:=adapter.apply_snapshot(solver.deformation_snapshot_native())
	check(rest.ok and hit.applied and applied.ok and applied.changed_meshes==68,"actual strong deformation applied")
	var lid: Node3D
	for node in visual.nodes.values():
		if node.get_meta("source_name","")=="Hood_lid": lid=node; break
	var assemblies: Array[Node3D]=[visual.doors.front_left,visual.doors.rear_left,lid]
	var jobs: Array=[]
	for assembly in assemblies:
		for changed: MeshInstance3D in applied.changed_nodes:
			if changed==assembly or assembly.is_ancestor_of(changed): jobs.append({"assembly":assembly,"mesh":changed})
	check(jobs.size()==14,"same strong-case 14 dirty meshes")
	var direct_times: Array[float]=[]; var clean_times: Array[float]=[]; var clean_native_times: Array[float]=[]
	var raw_total:=0; var clean_total:=0; var direct_final: Array=[]; var clean_final: Array=[]
	for repeat in REPEATS:
		var direct_begin:=Time.get_ticks_usec(); var direct_rows: Array=[]
		for job: Dictionary in jobs:
			var staged:=Experiment.stage(job.mesh,job.assembly,false); check(staged.ok,"direct stage")
			if staged.ok: direct_rows.append(staged)
		direct_times.append(Time.get_ticks_usec()-direct_begin)
		var clean_begin:=Time.get_ticks_usec(); var clean_rows: Array=[]; var native_sum:=0
		for job: Dictionary in jobs:
			var staged:=Experiment.stage(job.mesh,job.assembly,true); check(staged.ok,"native clean stage")
			if staged.ok: clean_rows.append(staged); native_sum+=int(staged.native_us)
		clean_times.append(Time.get_ticks_usec()-clean_begin); clean_native_times.append(native_sum)
		if repeat==REPEATS-1: direct_final=direct_rows; clean_final=clean_rows
	check(direct_final.size()==jobs.size() and clean_final.size()==jobs.size(),"all strong-case hulls staged")
	var directions:=_directions(); var support_failures:=0; var max_support_error:=0.0
	for i in mini(direct_final.size(),clean_final.size()):
		var direct: Dictionary=direct_final[i]; var clean: Dictionary=clean_final[i]
		raw_total+=int(direct.raw_count); clean_total+=int(clean.clean_count)
		var support_error:=_support_error(direct.raw_points,clean.collision_points,directions); max_support_error=maxf(max_support_error,support_error)
		if support_error>.00001: support_failures+=1
		check((direct.private_mesh as ArrayMesh).get_surface_count()==(clean.private_mesh as ArrayMesh).get_surface_count(),"render mesh retained "+str(i))
	check(clean_total<raw_total,"native cleaning removes only redundant convex input points")
	var bodies:=_collision_pair(world,jobs,direct_final,clean_final)
	var settle:=0
	while settle<900 and not bodies.all(func(body): return body.sleeping):
		await physics_frame; settle+=1
	check(bodies.all(func(body): return body.sleeping and body.global_position.y>-1.0),"direct and native-clean hulls collide and sleep")
	var direct_p95:=_percentile(direct_times,.95); var clean_p95:=_percentile(clean_times,.95)
	var accepted:=support_failures==0 and clean_p95<direct_p95
	var metrics={"verdict":"ACCEPT" if accepted else "REJECT","dirty_meshes":jobs.size(),"raw_points":raw_total,"clean_points":clean_total,"support_failures":support_failures,"max_support_error_m":max_support_error,"direct":{"p50_us":_percentile(direct_times,.5),"p95_us":direct_p95,"max_us":direct_times.max()},"clean":{"p50_us":_percentile(clean_times,.5),"p95_us":clean_p95,"max_us":clean_times.max(),"native_clean_p95_us":_percentile(clean_native_times,.95)},"settle_frames":settle}
	for body in bodies: body.free()
	adapter.dispose(); visual.dispose(); vehicle.free(); finish(metrics)
func _collision_pair(world: Node3D,jobs: Array,direct_rows: Array,clean_rows: Array) -> Array[RigidBody3D]:
	var result: Array[RigidBody3D]=[]
	for clean_mode in 2:
		var body:=RigidBody3D.new(); body.mass=40; body.collision_layer=1; body.collision_mask=1; body.linear_damp=.35; body.angular_damp=2.0; body.position=Vector3(-4 if clean_mode==0 else 4,3,0)
		var rows: Array=direct_rows if clean_mode==0 else clean_rows
		for i in rows.size():
			var collision:=CollisionShape3D.new(); collision.shape=rows[i].shape; var assembly: Node3D=jobs[i].assembly
			collision.transform=Transform3D(Basis(assembly.global_transform.basis.get_rotation_quaternion()),Vector3.ZERO).inverse()*Transform3D(Basis(assembly.global_transform.basis.get_rotation_quaternion()),assembly.global_position)
			body.add_child(collision)
		world.add_child(body); result.append(body)
	return result
func _directions() -> PackedVector3Array:
	var result:=PackedVector3Array([Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3(-1,0,0),Vector3(0,-1,0),Vector3(0,0,-1)])
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]: result.append(Vector3(x,y,z).normalized())
	for i in 32: result.append(Vector3(sin(i*12.9898),sin(i*78.233+1.0),sin(i*37.719+2.0)).normalized())
	return result
func _support_error(raw: PackedVector3Array,clean: PackedVector3Array,directions: PackedVector3Array) -> float:
	var maximum:=0.0
	for direction in directions:
		var raw_max:=-INF; var raw_min:=INF; var clean_max:=-INF; var clean_min:=INF
		for point in raw:
			var value:=point.dot(direction); raw_max=maxf(raw_max,value); raw_min=minf(raw_min,value)
		for point in clean:
			var value:=point.dot(direction); clean_max=maxf(clean_max,value); clean_min=minf(clean_min,value)
		maximum=maxf(maximum,maxf(absf(raw_max-clean_max),absf(raw_min-clean_min)))
	return maximum
func _percentile(values: Array[float],fraction: float) -> float:
	var sorted:=values.duplicate(); sorted.sort(); return sorted[clampi(int(ceil((sorted.size()-1)*fraction)),0,sorted.size()-1)]
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_CLEAN_HULL_EXPERIMENT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"repeats":REPEATS,"scope":"measurement-only native convex cleaning; exact render geometry retained; no integration/GPU/authority"}))
	quit(0 if failures.is_empty() else 1)
