extends SceneTree

const Route = preload("res://scripts/traversal/ladder_source_route_probe.gd")
const Motion = preload("res://scripts/traversal/ladder_motion.gd")

var checks := 0
var failures: Array[String] = []
var world: Node3D
var profile := {}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world=Node3D.new(); root.add_child(world)
	await _test_budgeted_admission()
	await _test_valid_plan_and_filters()
	await _test_blockers_and_prefix()
	await _test_lease_mutations()
	await _test_malformed_records()
	await _test_malformed_plans()
	print("LADDER_SOURCE_ROUTE_INDEPENDENT_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"profile":profile,"scope":"independent actual Godot headless physics; production helper untouched"}))
	world.free(); quit(0 if failures.is_empty() else 1)


func _test_budgeted_admission() -> void:
	var fixture: Dictionary=await _fixture()
	var plan: Dictionary=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	check(plan.valid and int(plan.total_admission_samples)>32, "budgeted prepare creates a bounded multi-window admission")
	if plan.valid:
		var premature: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":fixture.descriptor.lower}])
		var premature_filter: Dictionary=fixture.route.movement_filters(plan,fixture.descriptor.lower,fixture.descriptor.lower+Vector3(.01,0,0))
		check(not premature.clear and premature.reason=="admission_incomplete" and not premature_filter.valid
			and premature_filter.reason=="admission_incomplete", "samples and movement filters stay closed before complete admission")
		for bad: Dictionary in [
			{"name":"wrong-cursor","cursor":1,"budget":16}, {"name":"zero-budget","cursor":0,"budget":0},
			{"name":"over-cap","cursor":0,"budget":33},
		]:
			var rejected: Dictionary=fixture.route.inspect_window(plan,bad.cursor,bad.budget)
			check(not rejected.clear and rejected.reason=="invalid_window" and rejected.next_cursor==0,
				"window rejects "+bad.name+" without cursor advance")
		var cursor:=0
		var windows:=0
		var complete:=false
		var window_costs: Array[int]=[]
		while not complete and windows<128:
			var began:=Time.get_ticks_usec()
			var admitted: Dictionary=fixture.route.inspect_window(plan,cursor)
			window_costs.append(Time.get_ticks_usec()-began)
			check(admitted.clear and int(admitted.accepted_samples)>=0 and int(admitted.accepted_samples)<=16
				and int(admitted.next_cursor)==cursor+int(admitted.accepted_samples), "window advances exact sequential accepted prefix")
			if not admitted.clear: break
			cursor=int(admitted.next_cursor); complete=bool(admitted.complete); windows+=1
		check(complete and cursor==int(plan.total_admission_samples) and windows>=3, "all bounded windows complete one admission")
		window_costs.sort()
		profile.admission_windows={"samples":window_costs.size(),"max_samples_per_window":16,
			"p50_us":window_costs[floori(window_costs.size()*.5)],"p95_us":window_costs[maxi(0,int(ceil(window_costs.size()*.95))-1)]}
		var post: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":fixture.descriptor.lower}])
		var extra: Dictionary=fixture.route.inspect_window(plan,cursor,1)
		check(post.clear and not extra.clear and extra.reason=="invalid_window", "completed admission enables samples and cannot be advanced twice")
	_destroy(fixture); await _sync()

	# A blocker appearing only after the first accepted window must stop a later
	# window and preserve the already certified prefix.
	fixture=await _fixture()
	plan=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	var first: Dictionary=fixture.route.inspect_window(plan,0,16)
	var late_position: Vector3=fixture.descriptor.lower.lerp(plan.initial_state.path[2],.72)
	var late_blocker:=_body(fixture.scene,"late-foreign",late_position,Vector3(.8,.8,.8),1,"foreign")
	await _sync()
	var cursor:=int(first.next_cursor)
	var late: Dictionary={"clear":true}
	while late.clear:
		late=fixture.route.inspect_window(plan,cursor,16)
		if late.clear: cursor=int(late.next_cursor)
		if bool(late.get("complete",false)): break
	check(first.clear and not late.clear and late.reason=="dynamic_blocked" and cursor>=16,
		"late blocker fails a later window after preserving prior accepted windows: "+str(late))
	var closed_after_failure: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":fixture.descriptor.lower}])
	check(not closed_after_failure.clear and closed_after_failure.reason=="admission_incomplete", "failed window leaves route closed")
	late_blocker.queue_free(); _destroy(fixture); await _sync()

	# Every window revalidates the live source geometry and terminal support.
	fixture=await _fixture(); plan=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	first=fixture.route.inspect_window(plan,0,8); fixture.envelope.position.x+=.01; await _sync()
	var moved: Dictionary=fixture.route.inspect_window(plan,int(first.next_cursor),8)
	check(first.clear and not moved.clear and moved.reason=="source_lease_changed", "source movement between windows invalidates pending lease")
	_destroy(fixture); await _sync()
	fixture=await _fixture(); plan=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	first=fixture.route.inspect_window(plan,0,8); fixture.roof.position.y-=.02; await _sync()
	var support_changed: Dictionary=fixture.route.inspect_window(plan,int(first.next_cursor),8)
	check(first.clear and not support_changed.clear and support_changed.reason=="terminal_support_changed", "terminal support is revalidated between windows")
	_destroy(fixture); await _sync()

	# Public coordinated edits cannot substitute for the private canonical lease.
	for forgery: String in ["index-role-rids","token"]:
		fixture=await _fixture(); plan=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
		var forged: Dictionary=plan.duplicate(true)
		if forgery=="index-role-rids":
			forged.bindings[0].source_static_index=99
			forged.bindings[1].role="Storey_Exterior"
			forged.bound_rids.append(fixture.rail.get_rid())
		else:
			forged.lease_token=int(plan.lease_token)+1000
		var forged_result: Dictionary=fixture.route.inspect_window(forged,0,8)
		check(not forged_result.clear and forged_result.reason=="source_lease_changed", "pending coordinated "+forgery+" forgery rejected")
		_destroy(fixture); await _sync()

	# A newer prepare owns the single private lease; an unsuccessful admission
	# must also revoke the previously admitted plan.
	fixture=await _fixture(); var old_plan: Dictionary=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	var new_plan: Dictionary=fixture.route.prepare(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	var old_result: Dictionary=fixture.route.inspect_window(old_plan,0,8)
	check(new_plan.valid and not old_result.clear and old_result.reason=="source_lease_changed", "new prepare replaces the prior private lease")
	# Complete a fresh synchronous admission, then deliberately fail prepare.
	var admitted_plan: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	var invalid_source: Dictionary=fixture.source.duplicate(true); invalid_source.route_exclude_rids=[fixture.envelope.get_rid()]
	var failed_prepare: Dictionary=fixture.route.prepare(fixture.descriptor.lower,invalid_source,"lower",fixture.records)
	var stale_after_failure: Dictionary=fixture.route.inspect_samples(admitted_plan,[{"root_position":fixture.descriptor.lower}])
	check(not failed_prepare.valid and not stale_after_failure.clear,
		"failed prepare revokes the previously admitted private lease")
	_destroy(fixture); await _sync()


func _test_valid_plan_and_filters() -> void:
	var fixture: Dictionary=await _fixture()
	var source_before: Dictionary=fixture.source.duplicate(true)
	var plan: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	check(plan.valid, "valid source route and terminal settle admitted: "+str(plan.get("reason")))
	if plan.valid:
		check(fixture.source==source_before and plan.descriptor.lower==fixture.descriptor.lower and plan.descriptor.upper==fixture.descriptor.upper
			and plan.descriptor.step_off_point==fixture.descriptor.step_off_point and plan.descriptor.path.size()==4,
			"source descriptor endpoints/path remain intact")
		check(plan.initial_state.descriptor.path.size()==4 and plan.initial_state.path.back()==plan.grounding.grounded_feet
			and plan.initial_state.path[-2]==fixture.descriptor.step_off_point and is_equal_approx(float(plan.grounding.drop_m),.115),
			"Motion initial state appends only query-derived grounded endpoint")
		check(plan.bindings.size()==2 and plan.bound_rids==[fixture.envelope.get_rid()] and not plan.bound_rids.has(fixture.rail.get_rid()),
			"current source lease binds envelope and retains rail collision")
		var binding: Dictionary=plan.bindings[0]
		check(binding.rid==fixture.envelope.get_rid() and binding.instance_id==fixture.envelope.get_instance_id()
			and binding.transform==fixture.envelope.global_transform and binding.shape_rid==fixture.envelope_shape.shape.get_rid()
			and binding.shape_transform==Transform3D(Basis.IDENTITY,fixture.envelope_shape.position), "body/shape geometry lease is exact")
		var inside_from: Vector3=fixture.descriptor.lower+Vector3(0,0,.10)
		var inside_to: Vector3=fixture.descriptor.lower+Vector3(0,0,.14)
		var inside: Dictionary=fixture.route.movement_filters(plan,inside_from,inside_to)
		check(inside.valid and inside.during_move==plan.bound_rids and inside.after_move==plan.bound_rids, "inside corridor keeps exact source filter")
		var edge_from: Vector3=fixture.descriptor.lower+fixture.descriptor.normal*.50
		var edge_to: Vector3=fixture.descriptor.lower+fixture.descriptor.normal*.52
		var leaving: Dictionary=fixture.route.movement_filters(plan,edge_from,edge_to)
		check(leaving.valid and leaving.during_move==plan.bound_rids and leaving.after_move.is_empty(), "boundary exit retains filter during accepted tiny sweep then restores: "+str(leaving))
		var outside_from: Vector3=fixture.descriptor.lower+fixture.descriptor.normal*.52
		var outside_to: Vector3=fixture.descriptor.lower+fixture.descriptor.normal*.56
		var outside: Dictionary=fixture.route.movement_filters(plan,outside_from,outside_to)
		check(outside.valid and outside.during_move.is_empty() and outside.after_move.is_empty(), "outside corridor keeps source collisions restored: "+str(outside))
		check(not fixture.route.movement_filters(plan,inside_from,inside_from+Vector3(.04002,0,0)).valid
			and not fixture.route.movement_filters(plan,Vector3(NAN,0,0),inside_to).valid, "movement filter rejects oversized and nonfinite segments")
		var state_path: Array=Motion.route_points(plan.initial_state)
		check(state_path.back()==plan.grounding.grounded_feet and state_path[-2]==fixture.descriptor.step_off_point, "returned Motion path preserves authored then grounded endpoints")
		check(int(plan.admitted_samples)>0, "plan records complete admitted sample count")
		var costs: Array[int]=[]
		for index in 272:
			var began:=Time.get_ticks_usec(); fixture.route.movement_filters(plan,inside_from,inside_to)
			if index>=16: costs.append(Time.get_ticks_usec()-began)
		costs.sort(); profile.movement_filters={"samples":costs.size(),"p50_us":costs[127],"p95_us":costs[242]}
	var down: Dictionary=fixture.route.inspect(fixture.descriptor.step_off_point,fixture.source,"upper",fixture.records)
	check(down.valid and down.grounding.is_empty() and down.initial_state.path.back()==fixture.descriptor.lower, "upper entry preserves exact authored descent without settle append")
	var blanket: Dictionary=fixture.source.duplicate(true); blanket.route_exclude_rids=[fixture.envelope.get_rid()]
	check(fixture.route.inspect(fixture.descriptor.lower,blanket,"lower",fixture.records).reason=="blanket_exclusions_rejected", "blanket source exclusions fail closed")
	_destroy(fixture); await _sync()


func _test_blockers_and_prefix() -> void:
	var fixture: Dictionary=await _fixture()
	var plan: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	check(plan.valid, "blocker fixture starts with valid plan")
	if plan.valid:
		var rail_sample: Vector3=fixture.descriptor.lower+Vector3(.22,2.0,0)
		var rail_result: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":rail_sample}])
		check(not rail_result.clear and rail_result.reason=="dynamic_blocked" and rail_result.accepted_samples==0, "leased source rail remains a physical blocker")
		var foreign:=_body(fixture.scene,"foreign",Vector3(2,2.2,1),Vector3(.4,.5,.4),1,"foreign")
		await _sync()
		var samples: Array=[{"root_position":fixture.descriptor.lower},{"root_position":Vector3(0,.2,1)},{"root_position":Vector3(2,2.2,1)}]
		var prefix: Dictionary=fixture.route.inspect_samples(plan,samples)
		check(not prefix.clear and prefix.reason=="dynamic_blocked" and prefix.accepted_samples==2, "foreign blocker preserves exact accepted prefix: "+str(prefix))
		var invalid_samples: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":fixture.descriptor.lower},{"root_position":Vector3(NAN,0,0)}])
		check(not invalid_samples.clear and invalid_samples.reason=="invalid_sample" and invalid_samples.accepted_samples==1, "malformed sample preserves prior accepted prefix")
		foreign.queue_free(); await _sync()
	_destroy(fixture); await _sync()


func _test_lease_mutations() -> void:
	for mutation: String in ["move","shape-data","shape-replace","shape-transform","disable","layer","mask","velocity","source-meta","support-move","body-replace"]:
		var fixture: Dictionary=await _fixture()
		var plan: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
		check(plan.valid, "lease mutation fixture admitted: "+mutation)
		if plan.valid:
			match mutation:
				"move": fixture.envelope.position.x+=.01
				"shape-data": (fixture.envelope_shape.shape as BoxShape3D).size.x+=.01
				"shape-replace":
					var shape:=BoxShape3D.new(); shape.size=(fixture.envelope_shape.shape as BoxShape3D).size; fixture.envelope_shape.shape=shape
				"shape-transform": fixture.envelope_shape.position.x+=.01
				"disable": fixture.envelope.shape_owner_set_disabled(fixture.envelope.shape_find_owner(0),true)
				"layer": fixture.envelope.collision_layer=2
				"mask": fixture.envelope.collision_mask=2
				"velocity": fixture.envelope.constant_linear_velocity=Vector3(.001,0,0)
				"source-meta": fixture.envelope.set_meta("source_id","foreign")
				"support-move": fixture.roof.position.y-=.01
				"body-replace": fixture.envelope.queue_free()
			await _sync()
			var result: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":fixture.descriptor.lower}])
			var expected:="terminal_support_changed" if mutation=="support-move" else "source_lease_changed"
			check(not result.clear and result.reason==expected and result.accepted_samples==0, "stale lease rejected after "+mutation+": "+str(result.reason))
		_destroy(fixture); await _sync()


func _test_malformed_records() -> void:
	var fixture: Dictionary=await _fixture()
	var cases: Array=[
		{"name":"empty","records":[],"reason":"source_bindings_required"},
		{"name":"nondictionary","records":[42],"reason":"invalid_source_binding"},
		{"name":"nonstatic","records":[{"body":fixture.actor,"source_static_index":0,"building_entry_id":fixture.descriptor.id,"storey_part":"Storey"}],"reason":"invalid_source_binding"},
		{"name":"missing-index","records":[{"body":fixture.envelope,"building_entry_id":fixture.descriptor.id,"storey_part":"Storey"}],"reason":"invalid_source_binding"},
		{"name":"negative-index","records":[{"body":fixture.envelope,"source_static_index":-1,"building_entry_id":fixture.descriptor.id,"storey_part":"Storey"}],"reason":"invalid_source_binding"},
		{"name":"float-index","records":[{"body":fixture.envelope,"source_static_index":0.0,"building_entry_id":fixture.descriptor.id,"storey_part":"Storey"}],"reason":"invalid_source_binding"},
		{"name":"duplicate-index","records":[fixture.records[0],{"body":fixture.rail,"source_static_index":0,"building_entry_id":fixture.descriptor.id,"storey_part":"Roof_Ladder_Rail_Collision_Left"}],"reason":"invalid_source_binding"},
		{"name":"duplicate-body","records":[fixture.records[0],{"body":fixture.envelope,"source_static_index":2,"building_entry_id":fixture.descriptor.id,"storey_part":"Storey_Exterior"}],"reason":"duplicate_source_body"},
		{"name":"wrong-entry","records":[{"body":fixture.envelope,"source_static_index":0,"building_entry_id":"foreign","storey_part":"Storey"}],"reason":"source_identity_mismatch"},
		{"name":"missing-role","records":[{"body":fixture.envelope,"source_static_index":0,"building_entry_id":fixture.descriptor.id}],"reason":"source_role_required"},
		{"name":"numeric-role","records":[{"body":fixture.envelope,"source_static_index":0,"building_entry_id":fixture.descriptor.id,"storey_part":42}],"reason":"source_role_required"},
	]
	for item: Dictionary in cases:
		var result: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",item.records)
		check(not result.valid and result.reason==item.reason, "malformed source record rejected: "+item.name+" => "+str(result.get("reason")))
	var empty_role: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",
		[{"body":fixture.envelope,"source_static_index":0,"building_entry_id":fixture.descriptor.id,"storey_part":""}])
	check(empty_role.valid, "explicit empty String storey_part retains canonical source base-envelope role")
	fixture.envelope.set_meta("source_id","foreign")
	var meta_bad: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	check(not meta_bad.valid and meta_bad.reason=="invalid_source_binding", "body source_id metadata mismatch rejected")
	fixture.envelope.set_meta("source_id",fixture.descriptor.id)
	var extra_shape:=CollisionShape3D.new(); var extra_box:=BoxShape3D.new(); extra_box.size=Vector3(.1,.1,.1); extra_shape.shape=extra_box; extra_shape.position=Vector3(3,3,3); fixture.envelope.add_child(extra_shape); await _sync()
	var multi: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	check(not multi.valid and multi.reason=="source_shape_mismatch", "multi-shape source binding rejected")
	_destroy(fixture); await _sync()


func _test_malformed_plans() -> void:
	var fixture: Dictionary=await _fixture()
	var plan: Dictionary=fixture.route.inspect(fixture.descriptor.lower,fixture.source,"lower",fixture.records)
	check(plan.valid, "malformed-plan fixture admitted: "+str(plan.get("reason")))
	if plan.valid:
		for mutation: Dictionary in [
			{"name":"provider","key":"provider","value":"OLD"}, {"name":"valid","key":"valid","value":false},
			{"name":"descriptor","key":"descriptor","value":[]}, {"name":"bindings","key":"bindings","value":{}},
			{"name":"bound-rids","key":"bound_rids","value":{}}, {"name":"mask","key":"collision_mask","value":2},
			{"name":"actor","key":"actor_rid","value":RID()},
		]:
			var malformed: Dictionary=plan.duplicate(true); malformed[mutation.key]=mutation.value
			var result: Dictionary=fixture.route.inspect_samples(malformed,[{"root_position":fixture.descriptor.lower}])
			check(not result.clear and result.accepted_samples==0, "malformed plan rejected: "+mutation.name+" => "+str(result.reason))
		var binding_tamper: Dictionary=plan.duplicate(true); binding_tamper.bindings[0].transform.origin.x+=.01
		check(fixture.route.inspect_samples(binding_tamper,[{"root_position":fixture.descriptor.lower}]).reason=="source_lease_changed", "tampered binding receipt rejected")
		var missing_state: Dictionary=plan.duplicate(true); missing_state.erase("initial_state")
		var missing_state_result: Dictionary=fixture.route.inspect_samples(missing_state,[{"root_position":fixture.descriptor.lower}])
		check(not missing_state_result.clear and missing_state_result.reason=="invalid_plan", "plan without Motion initial_state rejected")
		var state_tamper: Dictionary=plan.duplicate(true); state_tamper.initial_state.path.append(Vector3(99,99,99))
		var state_result: Dictionary=fixture.route.inspect_samples(state_tamper,[{"root_position":fixture.descriptor.lower}])
		check(not state_result.clear and state_result.reason in ["invalid_plan","source_lease_changed"], "tampered Motion initial_state rejected")
		var index_tamper: Dictionary=plan.duplicate(true); index_tamper.bindings[0].source_static_index=99
		var index_result: Dictionary=fixture.route.inspect_samples(index_tamper,[{"root_position":fixture.descriptor.lower}])
		check(not index_result.clear and index_result.reason in ["invalid_plan","source_lease_changed"], "tampered source index lease rejected")
		var dual_index_tamper: Dictionary=plan.duplicate(true); dual_index_tamper.bindings[0].source_static_index=99; dual_index_tamper.bindings[0].captured_source_static_index=99
		var dual_index_result: Dictionary=fixture.route.inspect_samples(dual_index_tamper,[{"root_position":fixture.descriptor.lower}])
		check(not dual_index_result.clear and dual_index_result.reason in ["invalid_plan","source_lease_changed"], "coordinated source index receipt tamper rejected")
		var duplicate_binding: Dictionary=plan.duplicate(true); duplicate_binding.bindings.append(duplicate_binding.bindings[0].duplicate(true))
		var duplicate_result: Dictionary=fixture.route.inspect_samples(duplicate_binding,[{"root_position":fixture.descriptor.lower}])
		check(not duplicate_result.clear and duplicate_result.reason in ["invalid_plan","source_lease_changed","source_filters_changed"], "duplicate binding receipt rejected")
		var role_filter_tamper: Dictionary=plan.duplicate(true); role_filter_tamper.bindings[1].role="Storey_Exterior"; role_filter_tamper.bound_rids.append(fixture.rail.get_rid())
		var role_filter_result: Dictionary=fixture.route.inspect_samples(role_filter_tamper,[{"root_position":fixture.descriptor.lower+Vector3(.22,2.0,0)}])
		check(not role_filter_result.clear, "coordinated rail-role/filter tamper cannot suppress rail blocker")
		var descriptor_tamper: Dictionary=plan.duplicate(true); descriptor_tamper.descriptor.path[1]+=Vector3(.01,0,0)
		var descriptor_result: Dictionary=fixture.route.inspect_samples(descriptor_tamper,[{"root_position":fixture.descriptor.lower}])
		check(not descriptor_result.clear and descriptor_result.reason in ["invalid_plan","source_lease_changed"], "mutated normalized descriptor rejected: "+str(descriptor_result.reason))
		var injected: Dictionary=plan.duplicate(true); injected.bound_rids.append(fixture.rail.get_rid())
		var rail_sample: Vector3=fixture.descriptor.lower+Vector3(.22,2.0,0)
		var injected_result: Dictionary=fixture.route.inspect_samples(injected,[{"root_position":rail_sample}])
		check(not injected_result.clear, "forged bound RID cannot suppress rail blocker")
		var grounding_tamper: Dictionary=plan.duplicate(true); grounding_tamper.grounding.grounded_feet+=Vector3.UP*.01
		var grounding_result: Dictionary=fixture.route.inspect_samples(grounding_tamper,[{"root_position":fixture.descriptor.lower}])
		check(not grounding_result.clear and grounding_result.reason in ["invalid_plan","source_lease_changed","terminal_support_changed"], "tampered grounding receipt rejected: "+str(grounding_result.reason))
		fixture.route.dispose()
		var disposed: Dictionary=fixture.route.inspect_samples(plan,[{"root_position":fixture.descriptor.lower}])
		check(not disposed.clear and disposed.accepted_samples==0, "disposed route authority rejects prior plan")
	_destroy(fixture); await _sync()


func _fixture() -> Dictionary:
	var scene:=Node3D.new(); world.add_child(scene)
	var source:={"id":"source-ladder","lower":Vector3(0,0,1),"upper":Vector3(0,5,-.9),"outward":Vector3(0,0,1)}
	var descriptor: Dictionary=preload("res://scripts/traversal/ladder_descriptor.gd").normalize(source)
	var ground:=_body(scene,"ground",Vector3(0,-.1,1),Vector3(3,.2,3),1,"ground")
	var roof:=_body(scene,"roof",Vector3(0,4.785,-1.65),Vector3(3,.2,3),1,"roof")
	var envelope:=_body(scene,"source-envelope",Vector3(0,3.0,1),Vector3(.8,2.0,.8),1,descriptor.id)
	var rail:=_body(scene,"source-rail",Vector3(.55,2.5,1),Vector3(.09,5.0,.09),1,descriptor.id)
	var actor:=CharacterBody3D.new(); actor.position=Vector3(20,0,0); actor.collision_layer=1; actor.collision_mask=1; scene.add_child(actor)
	var actor_collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.3; capsule.height=1.9; actor_collision.shape=capsule; actor_collision.position.y=.962; actor.add_child(actor_collision)
	await _sync()
	var route:=Route.new(); route.configure(world.get_world_3d().direct_space_state,1,actor.get_rid())
	var records: Array=[
		{"body":envelope,"source_static_index":0,"building_entry_id":descriptor.id,"storey_part":"Storey_Exterior"},
		{"body":rail,"source_static_index":1,"building_entry_id":descriptor.id,"storey_part":"Roof_Ladder_Rail_Collision_Left"},
	]
	return {"scene":scene,"source":source,"descriptor":descriptor,"ground":ground,"roof":roof,"envelope":envelope,
		"envelope_shape":envelope.get_child(0),"rail":rail,"actor":actor,"route":route,"records":records}


func _body(parent: Node3D, node_name: String, position: Vector3, size: Vector3, layer: int, source_id: String) -> StaticBody3D:
	var body:=StaticBody3D.new(); body.name=node_name; body.position=position; body.collision_layer=layer; body.collision_mask=layer; body.set_meta("source_id",source_id); parent.add_child(body)
	var collider:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collider.shape=shape; body.add_child(collider); return body


func _destroy(fixture: Dictionary) -> void:
	if fixture.get("route")!=null: fixture.route.dispose()
	if is_instance_valid(fixture.get("scene")): fixture.scene.queue_free()


func _sync() -> void:
	await physics_frame; await physics_frame


func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
