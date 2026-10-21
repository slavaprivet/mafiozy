extends SceneTree
const Executor=preload("res://scripts/traversal/ladder_physical_executor.gd")
var checks:=0
var failures: Array[String]=[]
var frame_costs: Array[int]=[]
var admission_costs: Array[int]=[]
var root_samples:=0

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
	check(bodies.size()==interior.staticBodies.size(),"actual source cardinality")
	var records: Array=[]
	for i in mini(bodies.size(),interior.staticBodies.size()):
		var source: Dictionary=interior.staticBodies[i]
		var expected:=PackedVector3Array()
		for p: Array in source.polygonXZ:
			expected.append(Vector3(p[0],source.minY,p[1]))
			expected.append(Vector3(p[0],source.maxY,p[1]))
		check(bodies[i].get_child(0).shape.points==expected,"source polygon binding %d"%i)
		records.append({"body":bodies[i],"source_static_index":i,"building_entry_id":source.buildingEntryId,"storey_part":source.get("storeyPart","")})
	var actor:=CharacterBody3D.new()
	actor.collision_layer=2; actor.collision_mask=1
	var collision:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.30; capsule.height=1.9
	collision.shape=capsule; collision.position.y=.95
	actor.add_child(collision); scene.add_child(actor)
	actor.global_position=Vector3(fixture.descriptor.lower.x,fixture.descriptor.lower.y,fixture.descriptor.lower.z)
	actor.velocity=Vector3(1,2,3)
	# Deliberately host-owned exception: it must survive all route lifetimes.
	var persistent:=StaticBody3D.new()
	var persistent_shape:=CollisionShape3D.new()
	persistent_shape.shape=BoxShape3D.new()
	persistent.add_child(persistent_shape); scene.add_child(persistent)
	persistent.position=Vector3(1000,1000,1000)
	actor.add_collision_exception_with(persistent)
	await physics_frame
	await physics_frame
	var executor:=Executor.new()
	check(executor.configure_actor(actor).valid,"actual player envelope .30/.95 configured")
	check(not executor.request_slide().claimed,"Ctrl cannot acquire idle ladder")
	var ascent:=admit(executor,fixture.descriptor,"lower",records)
	check(ascent,"single E bounded admission")
	if ascent:
		check(drive(executor,actor,persistent),"complete actual-source native ascent")
		check(absf(actor.global_position.y-6.47)<=.012,"actual supporting floor skin retained")
		check(executor.state().root_position==actor.global_position,"committed state equals real terminal root")
		var descent:=admit(executor,fixture.descriptor,"upper",records)
		check(descent,"upper E from real grounded roof")
		if descent:
			check(executor.request_slide().accepted,"Ctrl after E enables slide")
			check(drive(executor,actor,persistent),"complete native fast slide")
			check(actor.global_position.distance_to(Vector3(fixture.descriptor.lower.x,fixture.descriptor.lower.y,fixture.descriptor.lower.z))<=.012,"slide ends on lower native support")
	check(actor.velocity==Vector3(1,2,3),"executor never overwrites caller velocity")
	check(actor.get_collision_exceptions().size()==1 and actor.get_collision_exceptions().has(persistent),"host exception survives both completions")
	check(executor.owned_filters().is_empty(),"all owned exceptions restored")
	# Late full-body blocker: revoke at the real committed root and restore only
	# executor-owned filters, preserving the host's unrelated exception.
	if admit(executor,fixture.descriptor,"lower",records):
		var first: Dictionary=executor.step(1.0/60.0)
		check(first.valid and first.get("active",false),"late blocker fixture active: "+str(first))
		var before: Vector3=actor.global_position
		var blocker:=StaticBody3D.new()
		var blocker_shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new(); box.size=Vector3(2,2,2)
		blocker_shape.shape=box; blocker.add_child(blocker_shape)
		scene.add_child(blocker); blocker.global_position=before+Vector3(0,1,0)
		await physics_frame
		var stopped: Dictionary=executor.step(1.0/60.0)
		check(not stopped.valid and stopped.reason=="dynamic_blocked","late native blocker rejects next sample: "+str(stopped))
		check(actor.global_position==before and stopped.get("actual_root")==before and stopped.get("state",{}).get("root_position")==before,"blocked prefix preserves real body root")
		check(executor.owned_filters().is_empty() and actor.get_collision_exceptions().size()==1 and actor.get_collision_exceptions().has(persistent),"dynamic abort releases only own filters")
		blocker.free()
	executor.dispose()
	print("LADDER_PHYSICAL_EXECUTOR_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"physical_samples":root_samples,"admission_cpu_us":stats(admission_costs),"step_cpu_us":stats(frame_costs),"scope":"actual-main TEST_ONLY actor .30/.95; player/input/rig/LIVE not connected"}))
	scene.free(); quit(0 if failures.is_empty() else 1)

func admit(executor: RefCounted,descriptor: Dictionary,end: String,records: Array) -> bool:
	var started:=Time.get_ticks_usec()
	var begin: Dictionary=executor.begin(descriptor,end,records)
	admission_costs.append(Time.get_ticks_usec()-started)
	if not begin.accepted: check(false,"begin reason "+str(begin.reason)); return false
	for window in 100:
		started=Time.get_ticks_usec()
		var result: Dictionary=executor.advance_admission(16)
		admission_costs.append(Time.get_ticks_usec()-started)
		if not result.valid: check(false,"admission reason "+str(result.reason)); return false
		if not result.pending: return result.active
	return false

func drive(executor: RefCounted,actor: CharacterBody3D,persistent: PhysicsBody3D) -> bool:
	for frame in 600:
		var started:=Time.get_ticks_usec()
		var result: Dictionary=executor.step(1.0/60.0)
		frame_costs.append(Time.get_ticks_usec()-started)
		if not result.valid: check(false,"physical reason "+str(result.reason)+" at "+str(actor.global_position)+" contact "+str(result.get("physical_contact",{}))); return false
		root_samples+=result.accepted_samples
		check(result.actual_root==actor.global_position and result.state.root_position==actor.global_position,"actual root owns pose state")
		check(result.pose.valid and result.pose.root_position==actor.global_position,"pose matches actual committed body")
		check(actor.get_collision_exceptions().has(persistent),"persistent host exception preserved")
		if not result.active: return result.reason=="complete"
	return false

func stats(samples: Array[int]) -> Dictionary:
	samples.sort()
	return {"samples":samples.size(),"p50":samples[samples.size()/2] if not samples.is_empty() else 0,"p95":samples[int(samples.size()*.95)] if not samples.is_empty() else 0}

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
