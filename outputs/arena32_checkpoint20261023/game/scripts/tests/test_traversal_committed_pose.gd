extends SceneTree

const Traversal = preload("res://scripts/traversal/traversal_controller.gd")
const Ladder = preload("res://scripts/traversal/ladder_controller.gd")
var checks := 0
var failures: Array[String] = []
var world: Node3D
var timings := {}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	check(not Traversal.new().committed_pose().valid, "unbound traversal has no pose")
	check(not Ladder.new().committed_pose().valid, "unbound ladder has no pose")
	await _late_body_blocker()
	await _ladder_prefix()
	print("TRAVERSAL_COMMITTED_POSE_TEST ", JSON.stringify({"passed":failures.is_empty(), "checks":checks, "failures":failures,
		"profile":timings, "scope":"actual CharacterBody blocker after proposal, authoritative post-commit pose; headless CPU, not LIVE/FPS"}))
	world.free()
	quit(0 if failures.is_empty() else 1)

func _late_body_blocker() -> void:
	var fixture := Node3D.new()
	world.add_child(fixture)
	_box(fixture, Vector3(0,-.1,0), Vector3(6,.2,8))
	_box(fixture, Vector3(0,.55,.52), Vector3(3,1.1,.34))
	var actor := _actor(fixture, Vector3(0,0,1.5))
	await physics_frame
	await physics_frame
	var controller := Traversal.new()
	controller.configure(world.get_world_3d().direct_space_state, 1, actor.get_rid())
	check(controller.try_begin(actor.global_position, Vector3.FORWARD).started, "real-body vault admitted")
	var reach: Dictionary = controller.propose_step(.12)
	controller.commit_step(reach)
	check(controller.committed_pose().pose_stage == "traverse" and actor.position == Vector3(0,0,1.5), "contact preparation commits without root movement")
	var step: Dictionary = controller.propose_step(.72)
	var samples: Array = step.proposal.sweep_samples
	check(step.all_samples_clear and samples.size() > 8, "proposal precedes blocker and accepts full route")
	var target: Vector3 = samples[int(samples.size()*.75)].root_position
	_box(fixture, target + Vector3.UP * .55, Vector3(.12,1.1,.12))
	await physics_frame
	await physics_frame
	var accepted := 0
	for sample: Dictionary in samples:
		var height := float(sample.collision_height_m)
		var shape: CollisionShape3D = actor.get_node("Capsule")
		(shape.shape as CapsuleShape3D).height = height
		shape.position.y = height * .5
		var movement: Vector3 = sample.root_position - actor.global_position
		if actor.move_and_collide(movement, true) != null:
			break
		actor.move_and_collide(movement)
		accepted += 1
	check(accepted > 0 and accepted < samples.size(), "late physical blocker truncates earlier clear proposal")
	controller.commit_step(step, accepted, "actual_body_blocked")
	var state: Dictionary = controller.state()
	var pose: Dictionary = controller.committed_pose()
	check(state.done and state.blocked, "host prefix produces blocked terminal state")
	check(pose.root_position.distance_to(actor.global_position) < .0001, "committed pose follows actual body root")
	check(absf(float(pose.progress)-float(state.progress)) < .000001, "committed pose follows accepted progress")
	check(pose.root_position.distance_to(step.pose.root_position) > .01, "prediction cannot replace committed pose after late blocker")
	var repeat: Dictionary = controller.committed_pose()
	check(repeat.root_position == pose.root_position and controller.state().root_position == state.root_position, "read-only repeated sampling preserves authoritative root")
	_benchmark(controller, "traversal")
	fixture.queue_free()
	await physics_frame

func _ladder_prefix() -> void:
	var fixture := Node3D.new()
	world.add_child(fixture)
	_box(fixture, Vector3(0,-.1,1.5), Vector3(5,.2,4))
	_box(fixture, Vector3(0,4.9,-2), Vector3(5,.2,4))
	var actor := _actor(fixture, Vector3(0,0,1))
	await physics_frame
	await physics_frame
	var controller := Ladder.new()
	controller.configure_actor(world.get_world_3d().direct_space_state, 1, actor)
	controller.register_ladders([{"id":"committed-pose", "lower":Vector3(0,0,1), "upper":Vector3(0,5,-.9), "normal":Vector3.BACK, "width":.8, "rung_spacing":.28}])
	var candidate: Dictionary = controller.nearest_prompt(actor.position)
	check(controller.try_begin(actor.position,candidate,&"interact").started, "ladder physical fixture admitted")
	var first: Dictionary = controller.propose_step(.2)
	controller.commit_step(first)
	actor.position = controller.state().root_position
	var prior: Dictionary = controller.state()
	var zero: Dictionary = controller.propose_step(.1)
	controller.commit_step(zero,0,"host_no_move")
	check(controller.committed_pose().root_position == prior.root_position, "zero accepted samples preserve old pose root")
	var step: Dictionary = controller.propose_step(.25)
	var samples: Array = step.proposal.sweep_samples
	var accepted := mini(2, samples.size())
	for i: int in accepted:
		actor.move_and_collide(samples[i].root_position-actor.position)
	controller.commit_step(step,accepted,"host_partial")
	var pose: Dictionary = controller.committed_pose()
	check(pose.root_position.distance_to(actor.position) < .0001, "ladder committed pose follows real accepted prefix")
	check(pose.root_position == controller.state().root_position, "ladder pose and committed state agree")
	check(pose.root_position.distance_to(step.pose.root_position) > .01, "ladder prediction differs from smaller accepted prefix")
	_benchmark(controller, "ladder")
	controller.abort("external_authority")
	check(controller.committed_pose().root_position == pose.root_position, "abort retains last accepted pose root")
	controller.dispose()
	check(not controller.committed_pose().valid, "dispose clears committed pose")
	fixture.queue_free()
	await physics_frame

func _actor(parent: Node3D, position_value: Vector3) -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	parent.add_child(actor)
	actor.position = position_value
	actor.collision_layer = 2
	actor.collision_mask = 1
	actor.safe_margin = .00001
	var shape := CollisionShape3D.new()
	shape.name = "Capsule"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.9
	capsule.radius = .30
	shape.shape = capsule
	shape.position.y = .95
	actor.add_child(shape)
	return actor

func _box(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = at
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _benchmark(controller: RefCounted, key: String) -> void:
	for i in 32: controller.committed_pose()
	var costs: Array[int] = []
	for i in 256:
		var started := Time.get_ticks_usec()
		controller.committed_pose()
		costs.append(Time.get_ticks_usec()-started)
	costs.sort()
	timings[key] = {"samples":256, "p50_us":costs[128], "p95_us":costs[243]}
