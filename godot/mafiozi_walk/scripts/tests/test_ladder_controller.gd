extends SceneTree

const Controller = preload("res://scripts/traversal/ladder_controller.gd")
var checks := 0
var failures: Array[String] = []
var world: Node3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world = Node3D.new(); root.add_child(world); _fixture()
	await physics_frame; await physics_frame
	var controller := make_controller()
	var bottom: Dictionary = controller.nearest_prompt(Vector3(0,0,1))
	check(not controller.try_begin(Vector3(0,0,1),bottom,&"ladder_slide").claimed, "non-E admission passes through")
	check(not controller.request_slide().claimed, "inactive Ctrl passes through to cover")
	var begun: Dictionary = controller.try_begin(Vector3(0,0,1),bottom,&"interact")
	check(begun.started and begun.claimed, "E starts admitted lower route")
	var slide: Dictionary = controller.request_slide()
	check(slide.claimed and slide.accepted and controller.state().direction == -1, "active Ctrl reverses ascent")
	var first_root: Vector3 = controller.state().root_position
	var frames := 0
	while controller.active() and frames < 600:
		var step: Dictionary = controller.propose_step(1.0/60.0)
		check(step.valid and step.pose.valid and step.pose.weapon_policy == "holster", "active proposal owns holster but not input")
		controller.commit_step(step)
		frames += 1
	check(controller.state().done and controller.state().root_position == Vector3(0,0,1), "reversed route ends safely at lower endpoint")
	check(first_root == Vector3(0,0,1), "Ctrl activation itself never teleports")

	var down := make_controller()
	var top: Dictionary = down.nearest_prompt(Vector3(0,5,-1.65))
	check(down.try_begin(Vector3(0,5,-1.65),top,&"interact").started, "E starts upper descent")
	check(down.request_slide().accepted, "active upper Ctrl starts fast slide")
	for index in 8:
		down.commit_step(down.propose_step(1.0/60.0))
	check(down.request_cancel().accepted and down.state().cancelling and not down.state().sliding, "E during slide keeps safe attached descent")
	while down.active() and frames < 1200:
		down.commit_step(down.propose_step(1.0/60.0)); frames += 1
	check(down.state().root_position == Vector3(0,0,1), "cancelled slide reaches exact bottom")

	var blocked := make_controller()
	var blocked_candidate: Dictionary = blocked.nearest_prompt(Vector3(0,0,1))
	check(blocked.try_begin(Vector3(0,0,1),blocked_candidate,&"interact").started, "dynamic fixture starts clear")
	var obstacle := _box("dynamic",Vector3(0,.8,1),Vector3(.7,.5,.7))
	await physics_frame
	var blocked_step: Dictionary = blocked.propose_step(.25)
	var before: Vector3 = blocked.state().root_position
	blocked.commit_step(blocked_step)
	check(blocked.active() and blocked.state().blocked and blocked.state().root_position == before, "dynamic blocker retains active last-safe root")
	obstacle.queue_free(); await physics_frame
	var resumed: Dictionary = blocked.propose_step(.05)
	blocked.commit_step(resumed)
	check(resumed.all_samples_clear and not blocked.state().blocked and blocked.state().root_position != before, "controller resumes from last-safe root after blocker clears")
	for source_path: String in [
		"res://scripts/traversal/ladder_descriptor.gd", "res://scripts/traversal/ladder_probe.gd",
		"res://scripts/traversal/ladder_motion.gd", "res://scripts/traversal/ladder_pose.gd",
		"res://scripts/traversal/ladder_controller.gd"]:
		var source := FileAccess.get_file_as_string(source_path)
		check(source.find("Input.") < 0 and source.find("_input(") < 0 and source.find("set_input_as_handled") < 0
			and source.find("move_and_slide") < 0 and source.find("global_position =") < 0,
			"package has no input listener or body write: "+source_path.get_file())

	print("LADDER_CONTROLLER_TEST ", JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"frames":frames,"scope":"input-agnostic proposal API over actual Godot physics; no scene/player writes"}))
	world.free(); quit(0 if failures.is_empty() else 1)


func make_controller() -> RefCounted:
	var controller := Controller.new(); controller.configure(world.get_world_3d().direct_space_state,1)
	var report: Dictionary = controller.register_ladders([{"id":"fixture","lower":Vector3(0,0,1),"upper":Vector3(0,5,-.9),"outward":Vector3(0,0,1)}])
	check(report.registered == 1 and report.rejected.is_empty(), "fixture registered once")
	return controller


func _fixture() -> void:
	_box("ground",Vector3(0,-.1,1.5),Vector3(5,.2,4)); _box("roof",Vector3(0,4.9,-2),Vector3(5,.2,4))
	for side: float in [-1.0,1.0]: _box("rail",Vector3(side*.4,3.025,.62),Vector3(.09,6.05,.09))


func _box(node_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name=node_name; body.position=position; body.collision_layer=1
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=size; collider.shape=shape; body.add_child(collider); world.add_child(body); return body


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
