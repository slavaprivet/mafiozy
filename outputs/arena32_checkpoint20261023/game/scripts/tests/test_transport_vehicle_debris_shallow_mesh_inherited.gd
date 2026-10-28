extends SceneTree
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Debris = preload("res://scripts/transport/candidates/transport_vehicle_debris_shallow_mesh.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var ground := StaticBody3D.new(); ground.collision_layer=1; ground.collision_mask=0; world.add_child(ground)
	var ground_shape := CollisionShape3D.new(); var ground_box := BoxShape3D.new(); ground_box.size=Vector3(80,.5,80); ground_shape.shape=ground_box; ground_shape.position.y=-.25; ground.add_child(ground_shape)
	var baseline_samples: Array[float] = []
	var baseline_wait_us: Array[float]=[]
	for frame in 120:
		var wait_at:=Time.get_ticks_usec(); await physics_frame; baseline_wait_us.append(Time.get_ticks_usec()-wait_at); baseline_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	var catalog := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded := Visual.instantiate_visual(catalog.entries.city_hatchback,catalog.base_path)
	check(loaded.ok,"actual hatch GLB")
	if not loaded.ok: finish({}); return
	var visual = loaded.visual; world.add_child(visual.root)
	visual.root.global_transform = Transform3D((Basis(Vector3.UP,.43)*Basis(Vector3.FORWARD,.27)).scaled(Vector3(1.08,.94,1.03)),Vector3(0,2.5,0))
	var vehicle_owner:=AnimatableBody3D.new(); vehicle_owner.collision_layer=2; vehicle_owner.collision_mask=8; world.add_child(vehicle_owner)
	var sources: Array = []
	for id in ["front_left","rear_left","front_right","rear_right"]: sources.append(visual.doors[id])
	for source_name in ["Hood_lid","Trunk_lid"]:
		var found: Node3D
		for node in visual.nodes.values():
			if node.get_meta("source_name","") == source_name: found=node; break
		check(found != null,"actual source shell assembly "+source_name)
		sources.append(found)
	for id in ["front_left","front_right","rear_left","rear_right"]: sources.append(visual.wheels[id].pivot)
	var source_meshes: Dictionary = {}
	for source in sources:
		var mesh_stack: Array[Node]=[source]
		while not mesh_stack.is_empty():
			var mesh_node: Node=mesh_stack.pop_back()
			if mesh_node is MeshInstance3D: source_meshes[mesh_node.mesh]=true
			for child in mesh_node.get_children(): mesh_stack.append(child)
	var rows: Array = []
	for i in sources.size(): rows.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	var debris := Debris.new()
	var bad := Debris.new()
	check(not bad.configure(visual.root,world,[{"source":sources[0],"mass_kg":NAN,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08}]).ok and sources[0].visible,"invalid configure is non-mutating")
	var invalidated := Debris.new(); check(invalidated.configure(visual.root,world,[rows[0]]).ok and invalidated.invalidate_geometry() and not invalidated.launch([]).ok and sources[0].visible,"explicit deformation invalidation requires reconfigure")
	var configure_at := Time.get_ticks_usec(); var configured: Dictionary = debris.configure(visual.root,world,rows,vehicle_owner); var configure_us := Time.get_ticks_usec()-configure_at
	check(configured.ok and configured.assemblies==10 and configured.hulls>=10,"ten actual assemblies and compound hull cache")
	check(sources.all(func(n): return n.visible),"configure leaves authored assemblies visible")
	var motions: Array = []
	for i in sources.size(): motions.append({"linear_velocity":Vector3(i*.12,2.0+i*.05,-1),"angular_velocity":Vector3(.2,i*.08,-.3)})
	check(debris.launch(motions).get("error","")=="PREWARM_PENDING","unprepared blast remains pending")
	var prewarm_samples: Array[float]=[]
	var prewarm_step_us: Array[float]=[]; var prewarm_wait_us: Array[float]=[]
	while not debris.stats().ready:
		var step_at:=Time.get_ticks_usec()
		var warm: Dictionary=debris.prewarm_step(1)
		prewarm_step_us.append(Time.get_ticks_usec()-step_at)
		check(warm.ok,"bounded prewarm step")
		var warm_wait_at:=Time.get_ticks_usec()
		await physics_frame
		prewarm_wait_us.append(Time.get_ticks_usec()-warm_wait_at)
		prewarm_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	var prepared_samples: Array[float]=[]
	# Performance monitors update at a lower cadence; discard one full window.
	for frame in 120: await physics_frame
	for frame in 120:
		await physics_frame; prepared_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	var invalid := motions.duplicate(true); invalid[4].linear_velocity=Vector3(NAN,0,0)
	check(not debris.launch(invalid).ok and sources.all(func(n): return n.visible) and debris.bodies().is_empty(),"launch validates atomically")
	var injected:=Node3D.new(); sources[0].add_child(injected)
	check(debris.launch(motions).get("error","")=="hierarchy_changed" and sources.all(func(n): return n.visible),"new descendant invalidates cached assembly")
	sources[0].remove_child(injected); injected.free()
	var expected: Array[Transform3D] = []
	for source in sources: expected.append(source.global_transform)
	var launch_at := Time.get_ticks_usec(); var launch: Dictionary = debris.launch(motions); var launch_us := Time.get_ticks_usec()-launch_at
	check(launch.ok and launch.get("bodies",0)==10 and sources.all(func(n): return not n.visible),"single physical detach hides exact roots "+str(launch))
	var bodies := debris.bodies()
	for i in bodies.size():
		var body: RigidBody3D = bodies[i]
		var detached_visual:=body.get_child(0) as Node3D
		check((body.global_transform*detached_visual.transform).is_equal_approx(expected[i]),"world pose including roll and baked nonuniform scale "+str(i))
		check(body.mass==18.0+i and body.collision_layer==8 and body.collision_mask==3,"caller physics authority "+str(i))
		check(is_equal_approx(body.linear_damp,.35) and is_equal_approx(body.angular_damp,2.0) and is_equal_approx(body.physics_material_override.friction,.75) and is_equal_approx(body.physics_material_override.bounce,.08),"caller damping and material authority "+str(i))
		check(body.get_collision_exceptions().has(vehicle_owner),"prepared body excludes owning vehicle "+str(i))
		check(body.linear_velocity.is_equal_approx(motions[i].linear_velocity) and body.angular_velocity.is_equal_approx(motions[i].angular_velocity),"caller launch velocity "+str(i))
		var mesh_count := 0; var hull_count := 0
		for child in body.get_children():
			if child is Node3D:
				var stack: Array[Node]=[child]
				while not stack.is_empty():
					var node: Node = stack.pop_back()
					if node is MeshInstance3D: mesh_count+=1
					for nested in node.get_children(): stack.append(nested)
			if child is CollisionShape3D and child.shape is ConvexPolygonShape3D: hull_count+=1
		check(mesh_count>0 and hull_count>0,"real opaque clone and convex collision "+str(i))
		var private_meshes := true
		var private_stack: Array[Node]=[body.get_child(0)]
		while not private_stack.is_empty():
			var private_node: Node=private_stack.pop_back()
			if private_node is MeshInstance3D and source_meshes.has(private_node.mesh): private_meshes=false
			for child in private_node.get_children(): private_stack.append(child)
		check(private_meshes,"detached clone owns private mesh resources "+str(i))
	check(not debris.launch(motions).ok and debris.bodies().size()==10,"repeated detach refused")
	var awake_samples: Array[float] = []
	for frame in 30: await physics_frame
	for frame in 120:
		await physics_frame; awake_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	var settle_frames := 0
	while debris.stats().sleeping < 10 and settle_frames < 1200:
		await physics_frame; settle_frames+=1
	if debris.stats().sleeping < 10:
		for body in debris.bodies(): print("DEBRIS_UNSETTLED ",body.name," sleeping=",body.sleeping," pos=",body.global_position," lv=",body.linear_velocity," av=",body.angular_velocity)
	var settled_samples: Array[float] = []
	for frame in 120:
		await physics_frame; settled_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	check(debris.stats().sleeping==10 and debris.bodies().all(func(b): return is_instance_valid(b) and b.visible),"actual gravity collision reaches native sleep and persists")
	var asleep_us := int(_percentile(settled_samples,.95)*1000.0)
	# A second real car verifies the bounded 20-piece physical stress case.
	var loaded2 := Visual.instantiate_visual(catalog.entries.city_hatchback,catalog.base_path)
	check(loaded2.ok,"second actual hatch GLB")
	var visual2=loaded2.visual; world.add_child(visual2.root)
	visual2.root.global_transform=Transform3D(Basis(Vector3.UP,-.31)*Basis(Vector3.RIGHT,-.19),Vector3(12,2.5,1))
	var sources2: Array=[]
	for id in ["front_left","rear_left","front_right","rear_right"]: sources2.append(visual2.doors[id])
	for source_name in ["Hood_lid","Trunk_lid"]:
		for node in visual2.nodes.values():
			if node.get_meta("source_name","")==source_name: sources2.append(node); break
	for id in ["front_left","front_right","rear_left","rear_right"]: sources2.append(visual2.wheels[id].pivot)
	var rows2: Array=[]
	for i in sources2.size(): rows2.append({"source":sources2[i],"mass_kg":22.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	var debris2:=Debris.new(); check(debris2.configure(visual2.root,world,rows2).ok,"second ten assemblies configured")
	while not debris2.stats().ready:
		check(debris2.prewarm_step(1).ok,"second bounded prewarm step")
		await physics_frame
	for frame in 120: await physics_frame
	var motions2: Array=[]
	for i in sources2.size(): motions2.append({"linear_velocity":Vector3(-i*.1,2.2+i*.04,.8),"angular_velocity":Vector3(-.15,i*.06,.25)})
	check(debris2.launch(motions2).ok,"twenty total real physical debris launched")
	for frame in 30: await physics_frame
	var stress_samples: Array[float]=[]
	for frame in 120:
		await physics_frame; stress_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	var stress_settle_frames:=0
	while debris2.stats().sleeping<10 and stress_settle_frames<1200:
		await physics_frame; stress_settle_frames+=1
	check(debris.stats().sleeping==10 and debris2.stats().sleeping==10 and debris.bodies().size()+debris2.bodies().size()==20,"two cars twenty pieces settle and persist")
	debris2.dispose(); visual2.dispose()
	debris.reset()
	check(sources.all(func(n): return n.visible) and debris.bodies().is_empty(),"reset restores originals and bodies")
	check(debris.launch(motions).ok,"reset permits authoritative repeat")
	debris.dispose()
	check(sources.all(func(n): return n.visible),"dispose restores exact visibility")
	visual.dispose()
	finish({"configure_us":configure_us,"launch_us":launch_us,"settle_frames":settle_frames,"stress_settle_frames":stress_settle_frames,"baseline_physics_p50_ms":_percentile(baseline_samples,.50),"baseline_physics_p95_ms":_percentile(baseline_samples,.95),"baseline_frame_wait_p95_us":_percentile(baseline_wait_us,.95),"prewarm_step_p95_us":_percentile(prewarm_step_us,.95),"prewarm_step_max_us":prewarm_step_us.max(),"prewarm_frame_wait_p95_us":_percentile(prewarm_wait_us,.95),"prewarm_frame_wait_max_us":prewarm_wait_us.max(),"prepared10_physics_p50_ms":_percentile(prepared_samples,.50),"prepared10_physics_p95_ms":_percentile(prepared_samples,.95),"awake_physics_p50_ms":_percentile(awake_samples,.50),"awake_physics_p95_ms":_percentile(awake_samples,.95),"stress20_physics_p50_ms":_percentile(stress_samples,.50),"stress20_physics_p95_ms":_percentile(stress_samples,.95),"settled_physics_p50_ms":_percentile(settled_samples,.50),"settled_physics_p95_ms":_percentile(settled_samples,.95),"settled_p95_us":asleep_us,"hulls":configured.get("hulls",0)})

func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate(); sorted.sort()
	return sorted[clampi(int(ceil((sorted.size()-1)*fraction)),0,sorted.size()-1)]
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_VEHICLE_DEBRIS ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"actual hatch GLB; native rigid bodies/compound convex hulls; no HP/fire/main/GPU"}))
	quit(0 if failures.is_empty() else 1)
