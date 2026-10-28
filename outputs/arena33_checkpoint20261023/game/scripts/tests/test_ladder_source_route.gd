extends SceneTree
const Route=preload("res://scripts/traversal/ladder_source_route_probe.gd")
const Motion=preload("res://scripts/traversal/ladder_motion.gd")
const Pose=preload("res://scripts/traversal/ladder_pose.gd")
var failures: Array[String]=[]
var checks:=0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/printshop_ladder_source.json"))
	var interior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var scene: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var bodies: Array=[]
	for node: Node in scene.get_node("PrintshopInterior").get_children():
		if node is StaticBody3D and node.get_meta("interior_kind","")=="source-static": bodies.append(node)
	check(bodies.size()==interior.staticBodies.size(),"actual body index cardinality")
	var records: Array=[]
	for i in mini(bodies.size(),interior.staticBodies.size()):
		var source: Dictionary=interior.staticBodies[i]
		var expected:=PackedVector3Array()
		for p: Array in source.polygonXZ:
			expected.append(Vector3(p[0],source.minY,p[1]))
			expected.append(Vector3(p[0],source.maxY,p[1]))
		check(bodies[i].get_child(0).shape.points==expected,"exact source body geometry index%d"%i)
		records.append({"body":bodies[i],"source_static_index":i,"building_entry_id":source.buildingEntryId,"storey_part":source.get("storeyPart","")})
	var actor:=CharacterBody3D.new()
	actor.collision_layer=2
	actor.collision_mask=1
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.33
	capsule.height=1.9
	shape.shape=capsule
	shape.position.y=.962
	actor.add_child(shape)
	scene.add_child(actor)
	actor.global_position=Vector3(fixture.descriptor.lower.x,fixture.descriptor.lower.y,fixture.descriptor.lower.z)
	await physics_frame
	await physics_frame
	var route:=Route.new()
	route.configure(scene.get_world_3d().direct_space_state,1,actor.get_rid())
	var started:=Time.get_ticks_usec()
	var plan: Dictionary=route.prepare(actor.global_position,fixture.descriptor,"lower",records)
	var prepare_us:=Time.get_ticks_usec()-started
	var admission_costs: Array[int]=[]
	if plan.valid:
		check(not route.inspect_samples(plan,[]).clear,"pending admission cannot inspect runtime motion")
		check(not route.movement_filters(plan,actor.global_position,actor.global_position).valid,"pending admission cannot acquire physical source filters")
		check(not route.inspect_window(plan,1,16).clear,"out-of-order admission cursor rejected")
		check(not route.inspect_window(plan,0,0).clear and not route.inspect_window(plan,0,33).clear,"invalid admission budgets rejected")
		var cursor:=0
		var completed:=false
		while not completed:
			var began:=Time.get_ticks_usec()
			var window: Dictionary=route.inspect_window(plan,cursor,16)
			admission_costs.append(Time.get_ticks_usec()-began)
			check(window.clear and window.accepted_samples<=16,"bounded actual-main admission window")
			if not window.clear:
				plan=window
				plan.valid=false
				break
			cursor=window.next_cursor
			completed=window.complete
	var admission_us:=Time.get_ticks_usec()-started
	check(plan.valid,"full actual source route admitted: "+str(plan.reason))
	var physical_samples:=0
	var costs: Array[int]=[]
	var filter_costs: Array[int]=[]
	var native_done:=false
	var native_slide_done:=false
	var slide_samples:=0
	if plan.valid:
		check(plan.initial_state.descriptor.step_off_point.y>plan.initial_state.path[-1].y,"source endpoint unchanged and physical ground appended")
		check(absf(plan.initial_state.path[-1].y-6.47)<.00001,"unified terminal is real roof")
		check(plan.descriptor.route_exclude_rids.is_empty(),"no blanket source exception")
		var state: Dictionary=plan.initial_state
		var frames:=0
		while not state.done and frames<300:
			frames+=1
			var proposal: Dictionary=Motion.propose(state,1.0/60.0)
			var began:=Time.get_ticks_usec()
			var inspected: Dictionary=route.inspect_samples(plan,proposal.sweep_samples)
			costs.append(Time.get_ticks_usec()-began)
			check(inspected.clear,"real path remains clear while ascending")
			if not inspected.clear: break
			var accepted:=0
			for sample: Dictionary in proposal.sweep_samples:
				var filter_began:=Time.get_ticks_usec()
				var filters: Dictionary=route.movement_filters(plan,actor.global_position,sample.root_position)
				filter_costs.append(Time.get_ticks_usec()-filter_began)
				check(filters.valid,"bounded source filter transition validated")
				if not filters.valid: break
				_sync_filters(actor,filters.during_move)
				var collision:=actor.move_and_collide(sample.root_position-actor.global_position)
				if collision!=null or actor.global_position.distance_to(sample.root_position)>.00001:
					check(false,"native root rejected at"+str(actor.global_position)+" target"+str(sample.root_position))
					break
				_sync_filters(actor,filters.after_move)
				accepted+=1
				physical_samples+=1
			state=Motion.commit(state,proposal,accepted,"physical_blocked")
			var pose: Dictionary=Pose.propose(state.descriptor,{"root_position":state.root_position,"travelled_m":state.travelled_m,"direction":state.direction,"sliding":state.sliding,"mount_progress":state.mount_progress,"dismount_progress":state.dismount_progress})
			check(pose.valid and pose.root_position==state.root_position,"committed pose uses actual accepted physical root")
			if accepted<proposal.sweep_samples.size(): break
		native_done=state.done
		check(state.done and not state.aborted,"complete native ascent")
		check(actor.global_position.distance_to(plan.grounding.grounded_feet)<.00001,"physical source ascent reaches grounded roof")
		check(actor.get_collision_exceptions().is_empty(),"all own source filters restored at roof")
		var descent: Dictionary=route.inspect(actor.global_position,fixture.descriptor,"upper",records)
		check(descent.valid,"upper E admission from actual grounded roof")
		if descent.valid:
			var slide: Dictionary=Motion.slide_down(descent.initial_state)
			check(slide.valid and slide.sliding,"source Ctrl slide proposal after admitted upper E")
			var proposal: Dictionary=Motion.propose(slide,.1)
			check(route.inspect_samples(descent,proposal.sweep_samples).clear,"source fast-slide samples inspect under actual policy")
			var slide_frames:=0
			while not slide.done and slide_frames<300:
				slide_frames+=1
				proposal=Motion.propose(slide,1.0/60.0)
				var inspected: Dictionary=route.inspect_samples(descent,proposal.sweep_samples)
				check(inspected.clear,"native fast-slide route remains clear")
				if not inspected.clear: break
				var accepted:=0
				for sample: Dictionary in proposal.sweep_samples:
					var filters: Dictionary=route.movement_filters(descent,actor.global_position,sample.root_position)
					check(filters.valid,"native fast-slide conditional filter admitted")
					if not filters.valid: break
					_sync_filters(actor,filters.during_move)
					var collision:=actor.move_and_collide(sample.root_position-actor.global_position)
					check(collision==null and actor.global_position.distance_to(sample.root_position)<.00001,"native fast-slide actual physical sample accepted")
					if collision!=null: break
					_sync_filters(actor,filters.after_move)
					accepted+=1
					slide_samples+=1
				slide=Motion.commit(slide,proposal,accepted,"physical_blocked")
				if accepted<proposal.sweep_samples.size(): break
			native_slide_done=slide.done and not slide.aborted
			check(native_slide_done,"native full fast-slide reaches released state")
			check(actor.global_position.distance_to(slide.descriptor.lower)<.00001,"native fast-slide reaches source lower support")
			_sync_filters(actor,[])
			check(actor.get_collision_exceptions().is_empty(),"native fast-slide owned source filters restored on completion")
	_sync_filters(actor,[])
	route.dispose()
	check(not route.inspect(actor.global_position,fixture.descriptor,"upper",records).valid,"disposed route cannot admit")
	costs.sort()
	filter_costs.sort()
	admission_costs.sort()
	print("LADDER_SOURCE_ROUTE_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"physical_samples":physical_samples,"native_done":native_done,"native_slide_done":native_slide_done,"slide_samples":slide_samples,"admission_us":admission_us,"prepare_us":prepare_us,"window_cpu_us":{"samples":admission_costs.size(),"p50":admission_costs[admission_costs.size()/2] if not admission_costs.is_empty() else 0,"p95":admission_costs[int(admission_costs.size()*.95)] if not admission_costs.is_empty() else 0},"inspect_cpu_us":{"samples":costs.size(),"p50":costs[costs.size()/2] if not costs.is_empty() else 0,"p95":costs[int(costs.size()*.95)] if not costs.is_empty() else 0},"filter_cpu_us":{"samples":filter_costs.size(),"p50":filter_costs[filter_costs.size()/2] if not filter_costs.is_empty() else 0,"p95":filter_costs[int(filter_costs.size()*.95)] if not filter_costs.is_empty() else 0},"scope":"actual-main TEST_ONLY physical actor; real player/rig/input remain unconnected"}))
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _sync_filters(actor: PhysicsBody3D,wanted: Array) -> void:
	for existing: PhysicsBody3D in actor.get_collision_exceptions():
		if not wanted.has(existing.get_rid()): actor.remove_collision_exception_with(existing)
	for rid: RID in wanted: PhysicsServer3D.body_add_collision_exception(actor.get_rid(),rid)

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
