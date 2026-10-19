extends SceneTree

const Controller = preload("res://scripts/traversal/traversal_controller.gd")
var checks := 0
var failures: Array[String] = []
var world: Node3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor := _box("floor", Vector3(0,-.1,0), Vector3(6,.2,8))
	_box("thin-wall", Vector3(0,.55,.52), Vector3(3,1.1,.34))
	await physics_frame
	await physics_frame
	var controller := Controller.new()
	controller.configure(world.get_world_3d().direct_space_state, 1)
	var started: Dictionary = controller.try_begin(Vector3(0,0,1.5), Vector3(0,0,-1))
	check(started.started and started.receipt.kind == "vault", "physical vault starts through controller seam")
	var frames := 0
	var reach_frames := 0
	var loaded_reach_frames := 0
	var settle_frames := 0
	var frame_costs: Array[int] = []
	while controller.active() and frames < 120:
		var frame_started := Time.get_ticks_usec()
		var step: Dictionary = controller.propose_step(1.0/60.0)
		frame_costs.append(Time.get_ticks_usec()-frame_started)
		check(step.valid and step.pose.valid and step.all_samples_clear, "frame proposal remains physically clear")
		if bool(step.get("pre_contact", false)):
			reach_frames += 1
			if float(step.pose.palms.l.contact_weight) >= .85 and float(step.pose.palms.r.contact_weight) >= .85:
				loaded_reach_frames += 1
			check(step.proposal.sweep_samples.is_empty() and step.pose.pose_stage == "reach" and controller.state().root_position == started.receipt.from_feet, "contact prep holds physical root")
		if bool(step.get("landing_settle", false)):
			settle_frames += 1
			check(step.proposal.sweep_samples.is_empty() and step.pose.pose_stage == "settle", "landing settle is visual-only after physical destination")
		controller.commit_step(step)
		frames += 1
	var completed: Dictionary = controller.state()
	check(completed.done and completed.status == "complete", "controller reaches physical destination")
	check(completed.root_position.distance_to(started.receipt.destination_feet) < .000001, "controller completes at admitted root")
	check(reach_frames >= 7 and settle_frames >= 16, "hands-before-lift and landing-settle phases execute for their full durations")
	check(loaded_reach_frames >= 2, "both palms are fully loaded for two physics frames before lift")

	var at_60 := _run_partition(1.0/60.0)
	var at_30 := _run_partition(1.0/30.0)
	var at_15 := _run_partition(1.0/15.0)
	check(at_60.status == "complete" and at_30.status == "complete" and at_15.status == "complete", "60/30/15Hz partitions all complete")
	check(at_60.root_position.distance_to(at_30.root_position) < .000001 and at_60.root_position.distance_to(at_15.root_position) < .000001, "frame-rate partitions preserve terminal physical root")

	# Admit first, then add a small blocker over a later carry sample. The pose
	# returned by the controller must match the accepted prefix, never the full
	# future proposal target.
	var prefix := Controller.new()
	prefix.configure(world.get_world_3d().direct_space_state, 1)
	var prefix_start: Dictionary = prefix.try_begin(Vector3(0,0,1.5), Vector3(0,0,-1), {"lead_side":"r"})
	check(prefix_start.started, "accepted-prefix fixture starts")
	prefix.commit_step(prefix.propose_step(.2))
	var clear_step: Dictionary = prefix.propose_step(.72)
	var clear_samples: Array = clear_step.proposal.sweep_samples
	check(clear_samples.size() > 8, "accepted-prefix fixture has multiple bounded sweep samples")
	var target_index := clampi(int(clear_samples.size() * .78), 1, clear_samples.size()-1)
	var block_root: Vector3 = clear_samples[target_index].root_position
	var dynamic_block := _box("dynamic-pose-block", block_root + Vector3.UP * .55, Vector3(.12,1.1,.12))
	await physics_frame
	await physics_frame
	var partial: Dictionary = prefix.propose_step(.72)
	var accepted := int(partial.accepted_samples)
	check(accepted > 0 and accepted < partial.proposal.sweep_samples.size(), "dynamic blocker accepts only a physical prefix")
	if accepted > 0:
		var accepted_sample: Dictionary = partial.proposal.sweep_samples[accepted-1]
		check(absf(float(partial.pose.progress)-float(accepted_sample.progress)) < .000001 and partial.pose.root_position == accepted_sample.root_position, "blocked-frame pose equals last accepted sweep root")
	check(partial.pose.lead_side == "r", "lead side remains stable through accepted-prefix selection")
	dynamic_block.queue_free()
	await physics_frame

	var changed := Controller.new()
	changed.configure(world.get_world_3d().direct_space_state, 1)
	var changed_start: Dictionary = changed.try_begin(Vector3(0,0,1.5), Vector3(0,0,-1))
	check(changed_start.started, "second traversal admitted before support change")
	floor.position.x += .04
	await physics_frame
	var terminal: Dictionary = changed.propose_step(.02)
	check(terminal.terminal and terminal.reason == "support_transform_changed", "support transform change aborts before floating")
	check(changed.state().aborted and changed.state().progress == 0.0, "support abort preserves last safe root")

	# A support change after the physical endpoint cancels only the visual settle.
	# It must not leave the controller active or move the already accepted root.
	floor.position.x = 0.0
	await physics_frame
	var settle_abort := Controller.new()
	settle_abort.configure(world.get_world_3d().direct_space_state, 1)
	var settle_start: Dictionary = settle_abort.try_begin(Vector3(0,0,1.5), Vector3(0,0,-1))
	check(settle_start.started, "settle-abort fixture starts")
	var settle_guard := 0
	while settle_abort.active() and not bool(settle_abort.state().get("landing_active", false)) and settle_guard < 120:
		settle_abort.commit_step(settle_abort.propose_step(1.0/60.0))
		settle_guard += 1
	var settled_root: Vector3 = settle_abort.state().root_position
	check(bool(settle_abort.state().get("landing_active", false)), "fixture reaches visual settle after physical destination")
	floor.position.z += .04
	await physics_frame
	var settle_terminal: Dictionary = settle_abort.propose_step(.02)
	check(settle_terminal.terminal and settle_terminal.reason == "support_transform_changed" and not settle_abort.active(), "support change cancels visual settle without an active-state leak")
	check(settle_abort.state().root_position == settled_root, "settle cancellation preserves accepted destination root")
	floor.position.z -= .04

	frame_costs.sort()
	print("TRAVERSAL_CONTROLLER_TEST ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failures":failures, "frames":frames, "propose_cpu_p50_us":frame_costs[frame_costs.size()/2],
		"propose_cpu_p95_us":frame_costs[int(frame_costs.size()*.95)],
		"scope":"proposal-only host seam over real physics; no CharacterBody writes or LIVE claim"}))
	world.free()
	quit(0 if failures.is_empty() else 1)


func _run_partition(delta_s: float) -> Dictionary:
	var controller := Controller.new()
	controller.configure(world.get_world_3d().direct_space_state, 1)
	var begun: Dictionary = controller.try_begin(Vector3(0,0,1.5), Vector3(0,0,-1))
	if not bool(begun.get("started", false)):
		return {"status":"failed", "root_position":Vector3.INF}
	var guard := 0
	while controller.active() and guard < 240:
		var step: Dictionary = controller.propose_step(delta_s)
		if not bool(step.get("valid", false)):
			return {"status":"failed", "root_position":Vector3.INF}
		controller.commit_step(step)
		guard += 1
	return controller.state()


func _box(node_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
