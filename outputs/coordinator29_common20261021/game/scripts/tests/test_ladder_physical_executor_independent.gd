extends SceneTree

const Executor=preload("res://scripts/traversal/ladder_physical_executor.gd")
const Descriptor=preload("res://scripts/traversal/ladder_descriptor.gd")
const Motion=preload("res://scripts/traversal/ladder_motion.gd")
const Probe=preload("res://scripts/traversal/ladder_probe.gd")

var checks:=0
var failures: Array[String]=[]
var world: Node3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world=Node3D.new(); root.add_child(world)
	await _input_and_actor_contract()
	await _filter_lifecycle()
	await _actor_lease_fail_closed()
	await _full_terminal_contact()
	await _partial_native_collision()
	await _cadence_physical()
	if checks==0: failures.append("test_did_not_execute")
	print("LADDER_PHYSICAL_EXECUTOR_INDEPENDENT_TEST ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"scope":"independent real CharacterBody physics; production executor untouched"}))
	world.free(); quit(0 if failures.is_empty() else 1)


func _input_and_actor_contract() -> void:
	var fixture: Dictionary=await _fixture()
	var executor=fixture.executor
	var idle_slide: Dictionary=executor.request_slide()
	check(not idle_slide.claimed and not idle_slide.accepted and idle_slide.reason=="input_pass_through",
		"Ctrl before E is not claimed")
	var wrong_action: Dictionary=executor.begin(fixture.source,"lower",fixture.records,&"ladder_slide")
	check(not wrong_action.claimed and not wrong_action.accepted and wrong_action.reason=="input_pass_through" and not executor.busy(),
		"only E/interact may begin physical ladder ownership")
	var begin: Dictionary=executor.begin(fixture.source,"lower",fixture.records,&"interact")
	check(begin.claimed and begin.accepted and begin.pending and executor.busy() and not executor.active(),
		"E begins pending admission without activating motion")
	var blocked_slide: Dictionary=executor.request_slide()
	check(not blocked_slide.claimed and blocked_slide.reason=="input_pass_through", "Ctrl cannot bypass pending E admission")
	var cancelled: Dictionary=executor.request_cancel()
	check(not cancelled.valid and cancelled.reason=="admission_cancelled" and not executor.busy() and executor.owned_filters().is_empty(),
		"pending cancel revokes admission and owns no filters")
	_destroy(fixture); await _sync()

	fixture=await _fixture(.30,.962)
	check(fixture.configured.valid, "actual radius .30 and collider Y .962 are admitted")
	_destroy(fixture); await _sync()
	fixture=await _fixture(.34,.95)
	check(not fixture.configured.valid and fixture.configured.reason=="actor_envelope_mismatch", "actor radius beyond conservative probe envelope is rejected")
	_destroy(fixture); await _sync()
	fixture=await _fixture(.30,.963)
	check(not fixture.configured.valid and fixture.configured.reason=="actor_envelope_mismatch", "collider above floor-skin envelope is rejected")
	_destroy(fixture); await _sync()
	fixture=await _fixture(.30,.95,.013)
	check(not fixture.configured.valid and fixture.configured.reason=="actor_envelope_mismatch", "initial safe margin beyond .012m is rejected")
	_destroy(fixture); await _sync()


func _filter_lifecycle() -> void:
	# Abort removes only executor-owned filters and preserves host exceptions.
	var fixture: Dictionary=await _fixture()
	var executor=fixture.executor
	check((await _admit(fixture)).active, "abort fixture admitted")
	var acquired: Dictionary=_step_until_filter(fixture)
	var exception_rids:=_exception_rids(fixture.actor)
	check(acquired.get("valid",false) and executor.owned_filters().has(fixture.envelope.get_rid())
		and exception_rids.has(fixture.persistent.get_rid()) and not executor.owned_filters().has(fixture.persistent.get_rid())
		and not exception_rids.has(fixture.rail.get_rid()), "executor owns envelope only; persistent exception and collidable rail retain ownership")
	var aborted: Dictionary=executor.abort("test_abort")
	check(not aborted.valid and aborted.reason=="test_abort" and executor.owned_filters().is_empty()
		and _exception_rids(fixture.actor).has(fixture.persistent.get_rid())
		and not _exception_rids(fixture.actor).has(fixture.envelope.get_rid()), "abort restores owned filters and preserves preexisting exception")
	fixture.actor.global_position+=Vector3(0,0,.1)
	var restarted: Dictionary=executor.begin(fixture.source,"lower",fixture.records,&"interact")
	check(restarted.accepted and restarted.pending, "idle begin refreshes normally walked root after prior abort")
	executor.request_cancel()
	_destroy(fixture); await _sync()

	# Active cancel returns physically along committed history, then cleans filters.
	fixture=await _fixture(); executor=fixture.executor
	check((await _admit(fixture)).active, "cancel fixture admitted")
	_step_until_filter(fixture)
	var cancelled: Dictionary=executor.request_cancel()
	check(cancelled.claimed and cancelled.accepted and cancelled.reason=="safe_cancel", "active cancel is accepted without teleport")
	var cancel_start: Vector3=fixture.actor.global_position
	var cancel_result: Dictionary=_drive(fixture,600)
	var cancel_delta: Vector3=fixture.actor.global_position-fixture.descriptor.lower
	check(cancel_result.get("valid",false) and cancel_result.reason=="complete" and not executor.busy()
		and Vector2(cancel_delta.x,cancel_delta.z).length()<=Executor.ROOT_EPSILON_M
		and cancel_delta.y>=-Executor.ROOT_EPSILON_M and cancel_delta.y<=fixture.actor.safe_margin+Executor.ROOT_EPSILON_M
		and cancel_result.actual_root==fixture.actor.global_position and cancel_result.state.root_position==fixture.actor.global_position
		and cancel_start.distance_to(fixture.actor.global_position)>0.0, "cancel physically returns to lower endpoint and completes: result="+str(cancel_result)+" actual="+str(fixture.actor.global_position)+" expected="+str(fixture.descriptor.lower))
	check(executor.owned_filters().is_empty() and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()),
		"cancel completion releases only owned filters")
	_destroy(fixture); await _sync()

	# Dispose and reconfigure must clean the prior actor before changing authority.
	fixture=await _fixture(); executor=fixture.executor
	check((await _admit(fixture)).active, "dispose fixture admitted")
	_step_until_filter(fixture); executor.dispose()
	check(executor.owned_filters().is_empty() and not _exception_rids(fixture.actor).has(fixture.envelope.get_rid())
		and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()), "dispose restores prior actor filters and preserves host exception")
	check(not executor.request_slide().claimed, "disposed executor does not claim Ctrl")
	_destroy(fixture); await _sync()

	fixture=await _fixture(); executor=fixture.executor
	check((await _admit(fixture)).active, "reconfigure fixture admitted")
	_step_until_filter(fixture)
	var replacement:=_actor(fixture.scene,"replacement",Vector3(20,0,0),.30,.95)
	await _sync()
	var reconfigured: Dictionary=executor.configure_actor(replacement)
	check(reconfigured.valid and executor.owned_filters().is_empty()
		and not _exception_rids(fixture.actor).has(fixture.envelope.get_rid())
		and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()), "reconfigure cleans only filters owned on the former actor")
	executor.dispose(); _destroy(fixture); await _sync()

	# A source body may disappear before cleanup; stale RID ownership still clears
	# while unrelated host exceptions remain untouched.
	fixture=await _fixture(); executor=fixture.executor
	check((await _admit(fixture)).active, "freed-source cleanup fixture admitted")
	_step_until_filter(fixture); fixture.envelope.queue_free(); await _sync(); aborted=executor.abort("source_freed")
	check(not aborted.valid and executor.owned_filters().is_empty() and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()),
		"freed source RID cleanup clears ownership and preserves host exception")
	_destroy(fixture); await _sync()


func _actor_lease_fail_closed() -> void:
	for mutation: String in ["move-pending","move-active","midroute-skin","mask","cancel-mask","layer","safe-margin","nan-root","shape-data","shape-replace","shape-transform","disable","basis","freed"]:
		var fixture: Dictionary=await _fixture()
		var executor=fixture.executor
		var began: Dictionary=executor.begin(fixture.source,"lower",fixture.records,&"interact")
		check(began.accepted and began.pending, "actor lease mutation begins pending: "+mutation)
		if mutation!="move-pending" and mutation!="freed":
			var admitted: Dictionary=await _finish_admission(executor)
			check(admitted.active, "actor lease mutation admits before change: "+mutation)
		match mutation:
			"move-pending": fixture.actor.global_position.x+=.01
			"move-active": fixture.actor.global_position.x+=.01
			"midroute-skin": fixture.actor.global_position.y+=.0005
			"mask": fixture.actor.collision_mask=2
			"cancel-mask": fixture.actor.collision_mask=2
			"layer": fixture.actor.collision_layer=4
			"safe-margin": fixture.actor.safe_margin=.02
			"nan-root": fixture.actor.global_position=Vector3(NAN,0,0)
			"shape-data": (fixture.actor_shape.shape as CapsuleShape3D).radius=.29
			"shape-replace":
				var capsule:=CapsuleShape3D.new(); capsule.radius=.30; capsule.height=1.9; fixture.actor_shape.shape=capsule
			"shape-transform": fixture.actor_shape.position.y+=.001
			"disable": fixture.actor.shape_owner_set_disabled(fixture.actor.shape_find_owner(0),true)
			"basis": fixture.actor.global_basis=Basis(Vector3.UP,.01)
			"freed": fixture.actor.queue_free()
		await _sync()
		var result: Dictionary=executor.advance_admission(16) if mutation in ["move-pending","freed"] else executor.request_cancel() if mutation=="cancel-mask" else executor.step(1.0/60.0)
		var expected:="actor_unavailable" if mutation=="freed" else "actor_shape_changed" if mutation in ["shape-data","shape-replace","shape-transform","disable"] else "actor_authority_changed"
		check(not result.valid and result.reason==expected and not executor.busy() and executor.owned_filters().is_empty()
			and (mutation!="cancel-mask" or result.claimed and not result.accepted),
			"actor "+mutation+" invalidates ownership and cleans filters: "+str(result.get("reason")))
		_destroy(fixture); await _sync()


func _full_terminal_contact() -> void:
	var fixture: Dictionary=await _fixture()
	var admitted: Dictionary=await _admit(fixture)
	check(admitted.active, "terminal fixture admitted")
	var max_frame_move:=0.0
	var result: Dictionary={}
	var frames:=0
	while fixture.executor.active() and frames<600:
		var before: Vector3=fixture.actor.global_position
		result=fixture.executor.step(1.0/60.0)
		max_frame_move=maxf(max_frame_move,before.distance_to(fixture.actor.global_position))
		if not result.valid: break
		frames+=1
	var roof_top: float=fixture.roof.global_position.y+(fixture.roof_shape.shape as BoxShape3D).size.y*.5
	var floor_gap: float=fixture.actor.global_position.y-roof_top
	check(result.get("valid",false) and result.reason=="complete" and not fixture.executor.busy()
		and bool(result.state.done) and result.actual_root==fixture.actor.global_position
		and result.state.root_position==fixture.actor.global_position, "full ascent completes from actual CharacterBody root")
	check(floor_gap>=-Executor.ROOT_EPSILON_M and floor_gap<=Probe.FLOOR_SKIN_M+Executor.ROOT_EPSILON_M
		and Vector2(fixture.actor.global_position.x-fixture.descriptor.step_off_point.x,
			fixture.actor.global_position.z-fixture.descriptor.step_off_point.z).length()<=Executor.ROOT_EPSILON_M,
		"radius .30 feet finish on real roof within .012m safe-margin: gap="+str(floor_gap))
	check(max_frame_move<=Motion.CLIMB_SPEED_MPS/60.0+.00002, "full physical route never teleports between frames")
	check(fixture.executor.owned_filters().is_empty() and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()),
		"terminal completion restores conditional filters and keeps preexisting exception")
	_destroy(fixture); await _sync()


func _cadence_physical() -> void:
	for hz: int in [10,30,60,144]:
		var fixture: Dictionary=await _fixture()
		var admitted: Dictionary=await _admit(fixture)
		var result: Dictionary={}
		var frames:=0
		while admitted.get("active",false) and fixture.executor.active() and frames<hz*20:
			result=fixture.executor.step(1.0/hz)
			if not result.get("valid",false): break
			frames+=1
		var roof_top: float=fixture.roof.global_position.y+(fixture.roof_shape.shape as BoxShape3D).size.y*.5
		var gap: float=fixture.actor.global_position.y-roof_top
		check(admitted.get("active",false) and result.get("valid",false) and result.reason=="complete"
			and not fixture.executor.busy() and result.state.root_position==fixture.actor.global_position
			and gap>=-Executor.ROOT_EPSILON_M and gap<=fixture.actor.safe_margin+Executor.ROOT_EPSILON_M,
			"physical ascent retains actual supported root at %d Hz: gap=%s reason=%s" % [hz,str(gap),str(result.get("reason"))])
		_destroy(fixture); await _sync()


func _partial_native_collision() -> void:
	# The query capsule is offset by FLOOR_SKIN while the actual capsule has feet
	# at root Y. Native movement therefore stops on the roof safe margin instead
	# of teleporting to the planned floor point; this is the one bounded partial
	# collision the executor is allowed to accept.
	var fixture: Dictionary=await _fixture(.30,.95,.001)
	check((await _admit(fixture)).active, "terminal partial-contact fixture admitted")
	var result: Dictionary={}
	var prior: Vector3=fixture.actor.global_position
	var last_delta: float=0.0
	for frame in 240:
		prior=fixture.actor.global_position
		result=fixture.executor.step(1.0/60.0)
		last_delta=prior.distance_to(fixture.actor.global_position)
		if not result.valid or result.reason=="complete": break
	var roof_top: float=fixture.roof.global_position.y+(fixture.roof_shape.shape as BoxShape3D).size.y*.5
	var actual_gap: float=fixture.actor.global_position.y-roof_top
	check(result.get("valid",false) and result.reason=="complete" and bool(result.state.done),
		"bounded native terminal safe-margin collision is accepted")
	check(actual_gap>Executor.ROOT_EPSILON_M and actual_gap<=Probe.FLOOR_SKIN_M+Executor.ROOT_EPSILON_M
		and result.actual_root==fixture.actor.global_position and result.state.root_position==fixture.actor.global_position
		and last_delta<=Motion.CLIMB_SPEED_MPS/60.0+.00002,
		"accepted partial terminal contact preserves actual root without teleport: gap="+str(actual_gap))
	check(fixture.executor.owned_filters().is_empty() and _exception_rids(fixture.actor).has(fixture.persistent.get_rid()),
		"physical abort restores only executor-owned filters")
	_destroy(fixture); await _sync()


func _admit(fixture: Dictionary) -> Dictionary:
	var began: Dictionary=fixture.executor.begin(fixture.source,"lower",fixture.records,&"interact")
	if not began.get("accepted",false): return began
	return await _finish_admission(fixture.executor)


func _finish_admission(executor: RefCounted) -> Dictionary:
	var result: Dictionary={"valid":false,"active":false,"pending":true,"reason":"not_started"}
	for window in 128:
		result=executor.advance_admission(16)
		if not result.get("valid",false) or not result.get("pending",false): return result
	return result


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


func _fixture(radius: float=.30,collider_y: float=.95,safe_margin: float=.001) -> Dictionary:
	var scene:=Node3D.new(); world.add_child(scene)
	var source:={"id":"executor-source","lower":Vector3(0,0,1),"upper":Vector3(0,5,-.9),"outward":Vector3(0,0,1)}
	var descriptor: Dictionary=Descriptor.normalize(source)
	var ground:=_box(scene,"ground",Vector3(0,-.1,1),Vector3(3,.2,3),1,"ground")
	var roof:=_box(scene,"roof",Vector3(0,4.785,-1.65),Vector3(3,.2,3),1,"roof")
	var envelope:=_box(scene,"source-envelope",Vector3(0,3.0,1),Vector3(.8,2.0,.8),1,descriptor.id)
	var rail:=_box(scene,"source-rail",Vector3(.55,2.5,1),Vector3(.09,5.0,.09),1,descriptor.id)
	var persistent:=_box(scene,"persistent-host-exception",Vector3(20,0,0),Vector3(1,1,1),1,"foreign")
	var actor:=_actor(scene,"actor",descriptor.lower,radius,collider_y,safe_margin)
	await _sync()
	actor.add_collision_exception_with(persistent)
	var records: Array=[
		{"body":envelope,"source_static_index":0,"building_entry_id":descriptor.id,"storey_part":"Storey_Exterior"},
		{"body":rail,"source_static_index":1,"building_entry_id":descriptor.id,"storey_part":"Roof_Ladder_Rail_Collision_Left"},
	]
	var executor=Executor.new(); var configured: Dictionary=executor.configure_actor(actor)
	return {"scene":scene,"source":source,"descriptor":descriptor,"ground":ground,"roof":roof,"roof_shape":roof.get_child(0),
		"envelope":envelope,"rail":rail,"persistent":persistent,"actor":actor,"actor_shape":actor.get_child(0),
		"records":records,"executor":executor,"configured":configured}


func _actor(parent: Node3D,node_name: String,position: Vector3,radius: float,collider_y: float,safe_margin: float=.001) -> CharacterBody3D:
	var actor:=CharacterBody3D.new(); actor.name=node_name; actor.safe_margin=safe_margin
	actor.collision_layer=2; actor.collision_mask=1; parent.add_child(actor); actor.global_position=position
	var collider:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=radius; capsule.height=1.9
	collider.shape=capsule; collider.position.y=collider_y; actor.add_child(collider); return actor


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
