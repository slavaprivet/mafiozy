extends SceneTree

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
const Probe = preload("res://scripts/traversal/ladder_probe.gd")
var checks := 0
var failures: Array[String] = []
var world: Node3D
var probe: RefCounted
var descriptor: Dictionary


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_build_fixture()
	await physics_frame
	await physics_frame
	probe = Probe.new()
	probe.configure(world.get_world_3d().direct_space_state,1)
	descriptor = Descriptor.normalize({"id":"fixture", "lower":Vector3(0,0,1), "upper":Vector3(0,5,-.9), "outward":Vector3(0,0,1)})
	var bottom: Dictionary = probe.nearest_prompt(descriptor.lower,[descriptor])
	var top: Dictionary = probe.nearest_prompt(descriptor.step_off_point,[descriptor])
	check(bottom.end == "lower" and bottom.input_action == &"interact", "bottom exposes E-only candidate")
	check(top.end == "upper" and top.input_action == &"interact", "roof exposes E-only candidate")
	check(probe.nearest_prompt(Vector3(0,0,-.9),[descriptor]) == null, "upper candidate cannot be selected through floor")
	var up_points: Array = [descriptor.lower]
	up_points.append_array(descriptor.path)
	up_points.append(descriptor.step_off_point)
	var up: Dictionary = probe.inspect_route(up_points,descriptor,"upper")
	check(up.clear, "full ascent capsule and roof support clear")
	var down_points: Array = [descriptor.step_off_point]
	var reversed: Array = descriptor.path.duplicate(); reversed.reverse(); down_points.append_array(reversed)
	check(probe.inspect_route(down_points,descriptor,"lower").clear, "full descent capsule and lower support clear")
	var blocker := _box("route-blocker",Vector3(0,2.5,1),Vector3(.5,1.0,.5))
	await physics_frame
	check(not probe.inspect_route(up_points,descriptor,"upper").clear, "full capsule rejects blocked route")
	blocker.queue_free()
	await physics_frame
	var costs: Array[int] = []
	for index in 96:
		var started := Time.get_ticks_usec()
		probe.inspect_route(up_points,descriptor,"upper")
		if index >= 16:
			costs.append(Time.get_ticks_usec()-started)
	costs.sort()
	print("LADDER_PROBE_TEST ", JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"profile":{"samples":costs.size(),"route_p50_us":costs[39],"route_p95_us":costs[75]},
		"scope":"actual Godot physics, headless only"}))
	world.free()
	quit(0 if failures.is_empty() else 1)


func _build_fixture() -> void:
	_box("ground",Vector3(0,-.1,1.5),Vector3(5,.2,4))
	_box("roof",Vector3(0,4.9,-2),Vector3(5,.2,4))
	for side: float in [-1.0,1.0]:
		_box("rail",Vector3(side*.4,3.025,.62),Vector3(.09,6.05,.09))


func _box(node_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name=node_name; body.position=position; body.collision_layer=1
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=size; collider.shape=shape; body.add_child(collider); world.add_child(body)
	return body


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
