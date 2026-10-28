extends SceneTree

const Controller = preload("res://scripts/traversal/ladder_controller.gd")

var checks := 0
var failures: Array[String] = []
var world: Node3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await _collision_exception_lifecycle()
	await _terminal_support_revalidation()
	print("LADDER_SAFETY_LIFECYCLE_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"scope":"real CharacterBody collision exceptions, rail retention and commit-time five-point support"}))
	world.free()
	quit(0 if failures.is_empty() else 1)


func _collision_exception_lifecycle() -> void:
	var scene := Node3D.new(); world.add_child(scene)
	var compound := StaticBody3D.new(); compound.name = "authored-envelope"; compound.collision_layer = 1; scene.add_child(compound)
	_shape(compound,Vector3(0,-.1,1.5),Vector3(5,.2,4))
	_shape(compound,Vector3(0,4.9,-2),Vector3(5,.2,4))
	_shape(compound,Vector3(0,3.0,1),Vector3(.9,2.0,.8))
	var rail_l := _box(scene,"rail-left",Vector3(-.4,3.025,.62),Vector3(.09,6.05,.09))
	var rail_r := _box(scene,"rail-right",Vector3(.4,3.025,.62),Vector3(.09,6.05,.09))
	var persistent := _box(scene,"persistent-host-exception",Vector3(20,0,0),Vector3(1,1,1))
	var actor := _actor(scene); actor.position = Vector3(0,0,1)
	await physics_frame; await physics_frame
	actor.add_collision_exception_with(persistent)
	var rid_only := Controller.new(); rid_only.configure(world.get_world_3d().direct_space_state,1,actor.get_rid())
	rid_only.register_ladders([_source("rid-only",[compound.get_rid()])])
	var rid_candidate: Dictionary = rid_only.nearest_prompt(actor.position)
	var rid_begin: Dictionary = rid_only.try_begin(actor.position,rid_candidate,&"interact")
	check(not rid_begin.started and rid_begin.reason == "collision_exception_body_required", "RID-only configuration fails closed for authored route exclusions")
	var controller := Controller.new(); controller.configure_actor(world.get_world_3d().direct_space_state,1,actor)
	controller.register_ladders([_source("collision-lifecycle",[compound.get_rid()])])
	var candidate: Dictionary = controller.nearest_prompt(actor.position)
	var begun: Dictionary = controller.try_begin(actor.position,candidate,&"interact")
	var active_exceptions := _exception_rids(actor)
	check(begun.started and begun.receipt.route_exclude_rids == [compound.get_rid()], "successful E acquire exposes exact authored exclusion list")
	check(active_exceptions.has(compound.get_rid()) and controller.collision_exception_state().owned == [compound.get_rid()], "controller installs and owns exact route exclusion")
	check(not active_exceptions.has(rail_l.get_rid()) and not active_exceptions.has(rail_r.get_rid()), "rail bodies never enter exception set")
	check(active_exceptions.has(persistent.get_rid()) and not controller.collision_exception_state().owned.has(persistent.get_rid()), "pre-existing host exception is retained but never claimed")
	actor.position = Vector3(0,2.0,.62); await physics_frame
	check(actor.move_and_collide(Vector3(.25,0,0),true) != null, "rail remains physically collidable while envelope exception is active")
	actor.position = Vector3(0,0,1); await physics_frame
	var physical_blocked := false
	var frames := 0
	while controller.active() and frames < 1200:
		var step: Dictionary = controller.propose_step(1.0/60.0)
		var accepted := 0
		for sample: Dictionary in step.proposal.sweep_samples:
			var delta: Vector3 = sample.root_position - actor.position
			if actor.move_and_collide(delta,true) != null:
				physical_blocked = true
				break
			actor.move_and_collide(delta)
			accepted += 1
		controller.commit_step(step,accepted,"actual_body_blocked")
		frames += 1
	var final_state: Dictionary = controller.state()
	check(not physical_blocked and final_state.done and actor.position.distance_to(final_state.root_position) <= .0001, "real CharacterBody completes route through exact authored envelope")
	var released := _exception_rids(actor)
	check(not released.has(compound.get_rid()) and released.has(persistent.get_rid()) and controller.collision_exception_state().owned.is_empty(), "normal completion removes only owned exceptions")
	actor.position = Vector3(0,0,1); await physics_frame
	check(actor.move_and_collide(Vector3(0,3,0),true) != null, "authored body collision is restored after completion")
	var again: Dictionary = controller.nearest_prompt(actor.position)
	check(controller.try_begin(actor.position,again,&"interact").started and _exception_rids(actor).has(compound.get_rid()), "second lifetime reacquires exact route exception")
	controller.abort("test_abort")
	check(not _exception_rids(actor).has(compound.get_rid()) and _exception_rids(actor).has(persistent.get_rid()), "abort removes owned exception and preserves pre-existing host exception")
	again = controller.nearest_prompt(actor.position)
	check(controller.try_begin(actor.position,again,&"interact").started, "third lifetime starts for dispose cleanup")
	controller.dispose()
	check(controller.collision_exception_state().owned.is_empty() and not _exception_rids(actor).has(compound.get_rid()), "dispose removes every owned exception")
	controller.dispose()
	check(_exception_rids(actor).has(persistent.get_rid()), "dispose cleanup is idempotent and leaves host exception")
	scene.queue_free(); await physics_frame


func _terminal_support_revalidation() -> void:
	var scene := Node3D.new(); world.add_child(scene)
	_box(scene,"ground",Vector3(0,-.1,1.5),Vector3(5,.2,4))
	var roof := _box(scene,"roof",Vector3(0,4.9,-2),Vector3(5,.2,4))
	for side: float in [-1.0,1.0]: _box(scene,"rail",Vector3(side*.4,3.025,.62),Vector3(.09,6.05,.09))
	await physics_frame; await physics_frame
	var controller := Controller.new(); controller.configure(world.get_world_3d().direct_space_state,1)
	controller.register_ladders([_source("support-recheck")])
	var candidate: Dictionary = controller.nearest_prompt(Vector3(0,0,1))
	check(controller.try_begin(Vector3(0,0,1),candidate,&"interact").started, "route admits while all five terminal support rays are valid")
	roof.queue_free(); await physics_frame; await physics_frame
	var frames := 0
	while controller.active() and not bool(controller.state().get("blocked",false)) and frames < 1200:
		var step: Dictionary = controller.propose_step(1.0/60.0)
		controller.commit_step(step)
		frames += 1
	var stopped: Dictionary = controller.state()
	check(controller.active() and stopped.blocked and stopped.reason == "terminal_unsupported", "support loss is revalidated and blocks the terminal commit")
	check(not stopped.done and stopped.root_position.distance_to(Vector3(0,5,-1.65)) > .001, "support loss retains the last safe active root")
	controller.abort("test_cleanup")
	scene.queue_free(); await physics_frame


func _source(id: String, exclusions: Array[RID] = []) -> Dictionary:
	return {"id":id,"lower":Vector3(0,0,1),"upper":Vector3(0,5,-.9),"outward":Vector3(0,0,1),"route_exclude_rids":exclusions}


func _exception_rids(actor: PhysicsBody3D) -> Array[RID]:
	var result: Array[RID] = []
	for body: PhysicsBody3D in actor.get_collision_exceptions():
		if is_instance_valid(body): result.append(body.get_rid())
	return result


func _actor(parent: Node3D) -> CharacterBody3D:
	var actor := CharacterBody3D.new(); actor.name="actor"; actor.safe_margin=.001; actor.collision_layer=1; actor.collision_mask=1
	var collider := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius=.30; capsule.height=1.9
	collider.shape=capsule; collider.position.y=.95; actor.add_child(collider); parent.add_child(actor); return actor


func _shape(parent: PhysicsBody3D, center: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=size; collider.shape=shape; collider.position=center; parent.add_child(collider)


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name=node_name; body.position=position; body.collision_layer=1
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=size; collider.shape=shape; body.add_child(collider); parent.add_child(body); return body


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
