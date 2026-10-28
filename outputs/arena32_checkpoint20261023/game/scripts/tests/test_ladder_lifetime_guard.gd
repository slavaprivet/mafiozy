extends SceneTree
const Executor=preload("res://scripts/traversal/ladder_physical_executor.gd")
const Guard=preload("res://scripts/traversal/ladder_lifetime_guard.gd")
var checks:=0
var failures: Array[String]=[]
var events: Array=[]
var costs: Array[int]=[]
var cycle_costs: Array[int]=[]

func _initialize() -> void: run.call_deferred()
func run() -> void:
	for active in [false,true]:
		var fixture: Dictionary=await setup()
		var executor: RefCounted=fixture.executor
		check(executor.begin(fixture.descriptor,"lower",fixture.records).accepted,"actual-main E admitted")
		if active:
			for window in 128:
				var result: Dictionary=executor.advance_admission(16)
				if not result.valid or not result.pending: break
			check(executor.active(),"actual-main admission complete")
			check(executor.step(1.0/60.0).valid,"physical actor moved")
			check(not executor.owned_filters().is_empty(),"real source exceptions acquired")
		var guard:=Guard.new()
		guard.interrupted.connect(func(reason: String,receipt: Dictionary): events.append({"reason":reason,"receipt":receipt}))
		if not active:
			var connections_before: int=fixture.actor.get_signal_connection_list("tree_exiting").size()
			for cycle in 192:
				var cycle_began:=Time.get_ticks_usec()
				var cycle_receipt: Dictionary=guard.arm(executor)
				guard.disarm()
				if cycle>=64: cycle_costs.append(Time.get_ticks_usec()-cycle_began)
				check(cycle_receipt.valid and not guard.armed() and executor.busy(),"repeated guard cycles preserve executor ownership")
			check(fixture.actor.get_signal_connection_list("tree_exiting").size()==connections_before,"no actor signal accumulation")
		var began:=Time.get_ticks_usec()
		var armed: Dictionary=guard.arm(executor)
		costs.append(Time.get_ticks_usec()-began)
		check(armed.valid and armed.connections==fixture.records.size()+1,"exact current source+actor lifetime connections")
		var authority: Dictionary=executor.lifetime_authority()
		check(authority.valid and authority.actor==fixture.actor and authority.sources.size()==fixture.records.size(),"read-only authority preserves exact runtime identity")
		var from: Vector3=fixture.actor.global_position
		var before_events:=events.size()
		var source: StaticBody3D=fixture.records[5].body
		source.free()
		check(events.size()==before_events+1 and events[-1].reason=="source_tree_exiting","source removal synchronously interrupts once")
		check(not guard.armed() and not executor.busy() and executor.owned_filters().is_empty(),"ownership and native filters revoked before source removal finishes")
		check(events[-1].receipt.actual_root==from and fixture.actor.global_position==from,"lifecycle abort never teleports actor")
		check(events[-1].receipt.needs_physical_recovery==active,"pending/active recovery need distinguished")
		check(fixture.actor.get_collision_exceptions().size()==1 and fixture.actor.get_collision_exceptions().has(fixture.persistent),"host exception survives source free without engine null-body errors")
		check(not executor.lifetime_authority().valid,"aborted ownership cannot register stale source links")
		fixture.actor.free()
		check(events.size()==before_events+1,"disconnected actor exit cannot repeat interruption")
		guard.dispose(); executor.dispose(); fixture.scene.free()
	check(checks>0,"test executed")
	costs.sort()
	cycle_costs.sort()
	print("LADDER_LIFETIME_GUARD_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"arm_cpu_us":costs,"cycle_cpu_us":{"samples":cycle_costs.size(),"p50":cycle_costs[cycle_costs.size()/2],"p95":cycle_costs[int(cycle_costs.size()*.95)]},"scope":"actual-main source lifetime; player/rig/recovery/LIVE unconnected"}))
	quit(0 if failures.is_empty() else 1)

func setup() -> Dictionary:
	var descriptor: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/printshop_ladder_source.json")).descriptor
	var interior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var scene: Node3D=load("res://scenes/main.tscn").instantiate(); root.add_child(scene)
	await physics_frame; await physics_frame
	var bodies: Array=[]
	for node: Node in scene.get_node("PrintshopInterior").get_children():
		if node is StaticBody3D and node.get_meta("interior_kind","")=="source-static": bodies.append(node)
	check(bodies.size()==interior.staticBodies.size(),"actual source cardinality")
	var records: Array=[]
	for i in mini(bodies.size(),interior.staticBodies.size()):
		var source: Dictionary=interior.staticBodies[i]
		var expected:=PackedVector3Array()
		for p: Array in source.polygonXZ:
			expected.append(Vector3(p[0],source.minY,p[1])); expected.append(Vector3(p[0],source.maxY,p[1]))
		check(bodies[i].get_child(0).shape.points==expected,"source index geometry verified")
		records.append({"body":bodies[i],"source_static_index":i,"building_entry_id":source.buildingEntryId,"storey_part":source.get("storeyPart","")})
	var actor:=CharacterBody3D.new(); actor.collision_layer=2; actor.collision_mask=1
	var shape:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new()
	capsule.radius=.30; capsule.height=1.9; shape.shape=capsule; shape.position.y=.95
	actor.add_child(shape); scene.add_child(actor)
	actor.global_position=Vector3(descriptor.lower.x,descriptor.lower.y,descriptor.lower.z)
	var persistent:=StaticBody3D.new(); scene.add_child(persistent)
	actor.add_collision_exception_with(persistent)
	await physics_frame; await physics_frame
	var executor:=Executor.new(); check(executor.configure_actor(actor).valid,"actual player-sized capsule configured")
	return {"scene":scene,"actor":actor,"persistent":persistent,"records":records,"descriptor":descriptor,"executor":executor}

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
