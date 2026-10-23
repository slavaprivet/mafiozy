extends SceneTree

const Guard=preload("res://scripts/traversal/ladder_lifetime_guard.gd")
const Executor=preload("res://scripts/traversal/ladder_physical_executor.gd")
const Descriptor=preload("res://scripts/traversal/ladder_descriptor.gd")

var checks:=0
var failures: Array[String]=[]
var events: Array[Dictionary]=[]
var world: Node3D
var callback_guard: RefCounted
var callback_action: String=""
var callback_rearm_executor: RefCounted


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world=Node3D.new(); root.add_child(world)
	await _invalid_and_disarm()
	await _pending_source_queue_free()
	await _active_source_direct_free()
	await _actor_exit()
	await _duplicate_arm_and_dispose_callback()
	await _rearm_from_callback()
	await _finished_route_has_no_interruption()
	if checks==0: failures.append("test_did_not_execute")
	print("LADDER_LIFETIME_GUARD_INDEPENDENT_TEST ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"scope":"real executor pending/active lifecycle; production guard untouched"}))
	world.free(); quit(0 if failures.is_empty() else 1)


func _invalid_and_disarm() -> void:
	var guard=Guard.new()
	check(guard.arm(null).reason=="executor_unavailable" and not guard.armed(), "null executor rejected")
	var idle=Executor.new()
	check(guard.arm(idle).reason=="not_owned" and not guard.armed(), "unconfigured idle executor rejected")
	var fixture: Dictionary=await _fixture()
	check(guard.arm(fixture.executor).reason=="not_owned", "configured executor without E ownership rejected")
	var invalid_records: Array=fixture.records.duplicate(true); invalid_records[0].body=fixture.actor
	var invalid_begin: Dictionary=fixture.executor.begin(fixture.source,"lower",invalid_records,&"interact")
	check(not invalid_begin.accepted and guard.arm(fixture.executor).reason=="not_owned", "invalid source body cannot create guard authority")
	var began: Dictionary=fixture.executor.begin(fixture.source,"lower",fixture.records,&"interact")
	check(began.accepted and guard.arm(fixture.executor).valid and guard.armed(), "pending executor arms guard")
	_events_for(guard)
	guard.disarm(); fixture.envelope.queue_free(); await _sync()
	check(events.is_empty() and not guard.armed() and fixture.executor.busy(), "disarm disconnects source callbacks without mutating executor")
	fixture.executor.abort("test_cleanup"); guard.dispose(); _destroy(fixture); await _sync()


func _pending_source_queue_free() -> void:
	var fixture: Dictionary=await _fixture()
	var began: Dictionary=fixture.executor.begin(fixture.source,"lower",fixture.records,&"interact")
	var guard=Guard.new(); _events_for(guard)
	var armed: Dictionary=guard.arm(fixture.executor)
	var expected_root: Vector3=fixture.actor.global_position
	fixture.envelope.queue_free(); await _sync()
	var last: Dictionary=guard.last_interruption()
	check(began.accepted and armed.valid and armed.connections==3, "pending guard binds actor and two canonical unique sources")
	check(events.size()==1 and events[0].reason=="source_tree_exiting" and last.reason=="source_tree_exiting",
		"queued pending source emits one interruption")
	check(not guard.armed() and not fixture.executor.busy() and not bool(last.receipt.needs_physical_recovery)
		and last.receipt.actual_root==expected_root and fixture.executor.owned_filters().is_empty(),
		"pending source exit revokes before callback and preserves actual root")
	guard.dispose(); _destroy(fixture); await _sync()


func _active_source_direct_free() -> void:
	var fixture: Dictionary=await _fixture()
	check((await _admit(fixture)).active, "direct-free fixture active")
	var physical: Dictionary=_step_until_filter(fixture)
	check(physical.get("valid",false) and not fixture.executor.owned_filters().is_empty(), "active fixture owns conditional filter")
	var guard=Guard.new(); _events_for(guard); check(guard.arm(fixture.executor).valid, "active executor arms guard")
	var actual_before: Vector3=fixture.actor.global_position
	var count_before:=events.size()
	fixture.envelope.free()
	check(events.size()==count_before+1 and events[-1].reason=="source_tree_exiting", "direct source free interrupts synchronously before RID invalidation")
	var receipt: Dictionary=events[-1].receipt
	check(not guard.armed() and not fixture.executor.busy() and bool(receipt.needs_physical_recovery)
		and receipt.actual_root==actual_before and receipt.state.root_position==actual_before,
		"active source exit aborts at actual root with recovery receipt")
	check(fixture.executor.owned_filters().is_empty() and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()),
		"direct source free releases owned filter and retains borrowed exception")
	guard.dispose(); _destroy(fixture); await _sync()


func _actor_exit() -> void:
	for mode: String in ["queue","free"]:
		var fixture: Dictionary=await _fixture()
		check((await _admit(fixture)).active, "actor exit fixture active: "+mode)
		_step_until_filter(fixture)
		var guard=Guard.new(); _events_for(guard); check(guard.arm(fixture.executor).valid, "actor exit guard armed: "+mode)
		var actual_before: Vector3=fixture.actor.global_position
		if mode=="queue": fixture.actor.queue_free()
		else: fixture.actor.free()
		await _sync()
		check(events.size()==1 and events[0].reason=="actor_tree_exiting" and events[0].receipt.actual_root==actual_before
			and not guard.armed() and not fixture.executor.busy() and fixture.executor.owned_filters().is_empty(),
			"actor "+mode+" interrupts once before physical authority disappears")
		guard.dispose(); _destroy(fixture); await _sync()


func _duplicate_arm_and_dispose_callback() -> void:
	var fixture: Dictionary=await _fixture(); fixture.executor.begin(fixture.source,"lower",fixture.records,&"interact")
	var guard=Guard.new(); _events_for(guard)
	var first: Dictionary=guard.arm(fixture.executor); var second: Dictionary=guard.arm(fixture.executor)
	callback_guard=guard; callback_action="dispose"
	fixture.envelope.queue_free(); await _sync()
	check(first.connections==3 and second.connections==3 and events.size()==1, "re-arm replaces links without duplicate callback")
	check(not guard.armed() and guard.last_interruption().is_empty(), "listener may dispose guard synchronously without stale state")
	callback_guard=null; callback_action=""; _destroy(fixture); await _sync()


func _rearm_from_callback() -> void:
	var first_fixture: Dictionary=await _fixture(); first_fixture.executor.begin(first_fixture.source,"lower",first_fixture.records,&"interact")
	var second_fixture: Dictionary=await _fixture(); second_fixture.executor.begin(second_fixture.source,"lower",second_fixture.records,&"interact")
	var guard=Guard.new(); _events_for(guard); check(guard.arm(first_fixture.executor).valid, "first executor armed for callback reentry")
	callback_guard=guard; callback_action="rearm"; callback_rearm_executor=second_fixture.executor
	first_fixture.envelope.queue_free(); await _sync()
	check(events.size()==1 and bool(events[0].get("rearm_valid",false)) and guard.armed(), "listener re-arms second executor during first interruption")
	first_fixture.rail.queue_free(); await _sync()
	check(events.size()==1 and guard.armed(), "stale old-source event cannot revoke re-armed epoch")
	second_fixture.envelope.queue_free(); await _sync()
	check(events.size()==2 and events[1].reason=="source_tree_exiting" and not guard.armed(), "new epoch receives its own source interruption once")
	callback_guard=null; callback_rearm_executor=null; callback_action=""; guard.dispose()
	_destroy(first_fixture); _destroy(second_fixture); await _sync()


func _finished_route_has_no_interruption() -> void:
	var fixture: Dictionary=await _fixture()
	check((await _admit(fixture)).active, "completion fixture active")
	var guard=Guard.new(); _events_for(guard); check(guard.arm(fixture.executor).valid, "completion guard armed")
	var result: Dictionary=_drive(fixture,1200)
	check(result.get("valid",false) and result.reason=="complete" and not fixture.executor.busy(), "physical route completes before source exit")
	fixture.envelope.queue_free(); await _sync()
	check(events.is_empty() and not guard.armed() and guard.last_interruption().is_empty(), "source exit after completed ownership emits no recovery interruption")
	guard.dispose(); _destroy(fixture); await _sync()


func _events_for(guard: RefCounted) -> void:
	events.clear()
	guard.interrupted.connect(_on_interrupted)


func _on_interrupted(reason: String,receipt: Dictionary) -> void:
	events.append({"reason":reason,"receipt":receipt.duplicate(true)})
	if callback_action=="dispose" and is_instance_valid(callback_guard):
		callback_guard.dispose()
	elif callback_action=="rearm" and is_instance_valid(callback_guard):
		var result: Dictionary=callback_guard.arm(callback_rearm_executor)
		events[-1].rearm_valid=bool(result.get("valid",false))
		callback_action=""


func _admit(fixture: Dictionary) -> Dictionary:
	var began: Dictionary=fixture.executor.begin(fixture.source,"lower",fixture.records,&"interact")
	if not began.get("accepted",false): return began
	for window in 128:
		var result: Dictionary=fixture.executor.advance_admission(16)
		if not result.get("valid",false) or not result.get("pending",false): return result
	return {"valid":false,"active":false,"reason":"window_limit"}


func _step_until_filter(fixture: Dictionary) -> Dictionary:
	var result: Dictionary={"valid":false,"reason":"filter_not_acquired"}
	for frame in 240:
		result=fixture.executor.step(1.0/60.0)
		if not result.get("valid",false) or not fixture.executor.owned_filters().is_empty(): return result
	return result


func _drive(fixture: Dictionary,max_frames: int) -> Dictionary:
	var result: Dictionary={"valid":false,"reason":"frame_limit"}
	for frame in max_frames:
		if not fixture.executor.active(): break
		result=fixture.executor.step(1.0/60.0)
		if not result.get("valid",false): break
	return result


func _fixture() -> Dictionary:
	var scene:=Node3D.new(); world.add_child(scene)
	var source:={"id":"guard-source-"+str(scene.get_instance_id()),"lower":Vector3(0,0,1),"upper":Vector3(0,5,-.9),"outward":Vector3(0,0,1)}
	var descriptor: Dictionary=Descriptor.normalize(source)
	var ground:=_box(scene,"ground",Vector3(0,-.1,1),Vector3(3,.2,3),1,"ground")
	var roof:=_box(scene,"roof",Vector3(0,4.785,-1.65),Vector3(3,.2,3),1,"roof")
	var envelope:=_box(scene,"source-envelope",Vector3(0,3.0,1),Vector3(.8,2.0,.8),1,descriptor.id)
	var rail:=_box(scene,"source-rail",Vector3(.55,2.5,1),Vector3(.09,5.0,.09),1,descriptor.id)
	var persistent:=_box(scene,"persistent",Vector3(20,0,0),Vector3(1,1,1),1,"foreign")
	var actor:=CharacterBody3D.new(); actor.name="actor"; actor.position=descriptor.lower; actor.safe_margin=.001
	actor.collision_layer=2; actor.collision_mask=1; scene.add_child(actor)
	var collider:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.30; capsule.height=1.9
	collider.shape=capsule; collider.position.y=.95; actor.add_child(collider)
	await _sync(); actor.add_collision_exception_with(persistent)
	var records: Array=[
		{"body":envelope,"source_static_index":0,"building_entry_id":descriptor.id,"storey_part":"Storey_Exterior"},
		{"body":rail,"source_static_index":1,"building_entry_id":descriptor.id,"storey_part":"Roof_Ladder_Rail_Collision_Left"},
	]
	var executor=Executor.new(); var configured: Dictionary=executor.configure_actor(actor)
	return {"scene":scene,"source":source,"descriptor":descriptor,"ground":ground,"roof":roof,"envelope":envelope,"rail":rail,
		"persistent":persistent,"actor":actor,"records":records,"executor":executor,"configured":configured}


func _box(parent: Node3D,node_name: String,position: Vector3,size: Vector3,layer: int,source_id: String) -> StaticBody3D:
	var body:=StaticBody3D.new(); body.name=node_name; body.position=position; body.collision_layer=layer; body.collision_mask=layer
	body.set_meta("source_id",source_id); parent.add_child(body)
	var collider:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collider.shape=shape; body.add_child(collider); return body


func _exception_rids(actor: PhysicsBody3D) -> Array[RID]:
	var result: Array[RID]=[]
	if not is_instance_valid(actor): return result
	for body: PhysicsBody3D in actor.get_collision_exceptions():
		if is_instance_valid(body): result.append(body.get_rid())
	return result


func _destroy(fixture: Dictionary) -> void:
	if fixture.get("executor")!=null: fixture.executor.dispose()
	if is_instance_valid(fixture.get("scene")): fixture.scene.queue_free()


func _sync() -> void:
	await physics_frame; await physics_frame


func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
