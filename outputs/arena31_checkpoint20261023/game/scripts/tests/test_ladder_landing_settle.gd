extends SceneTree

const Settle = preload("res://scripts/traversal/ladder_landing_settle_probe.gd")
const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/printshop_ladder_source.json"))
	var descriptor: Dictionary = Descriptor.normalize(fixture.descriptor)
	var original_descriptor := descriptor.duplicate(true)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var player: CharacterBody3D = scene._player
	var original_position := player.global_position
	var original_exceptions := player.get_collision_exceptions()
	var helper := Settle.new()
	check(not helper.inspect(descriptor.step_off_point).valid,"unconfigured fails closed")
	helper.configure(scene.get_world_3d().direct_space_state,1,player.get_rid())
	var receipt: Dictionary = helper.inspect(descriptor.step_off_point)
	check(receipt.valid,"actual source roof landing admitted")
	if receipt.valid:
		check(absf(receipt.grounded_feet.y-6.47)<.00001,"actual roof floor query retained")
		check(absf(receipt.drop_m-.115)<.00001,"exact authored115mm gap settled")
		check(receipt.grounded_feet.x == descriptor.step_off_point.x and receipt.grounded_feet.z == descriptor.step_off_point.z,"no horizontal motion")
		check(receipt.ordered_roots.size() == 4,"bounded40mm ordered sweep")
		check(receipt.ordered_roots[0] == descriptor.step_off_point and receipt.ordered_roots[-1] == receipt.grounded_feet,"exact start and grounded end")
		for i in range(1,receipt.ordered_roots.size()):
			var a: Vector3 = receipt.ordered_roots[i-1]
			var b: Vector3 = receipt.ordered_roots[i]
			check(b.y<=a.y and a.distance_to(b)<=.040001,"downward bounded sweep %d" % i)
		check(receipt.supports.size() == 5,"five current physical support receipts")
		check(helper.revalidate(receipt).valid,"unchanged actual source support revalidates")
		var wrong := receipt.duplicate(true)
		wrong.supports[0].source_id = "foreign"
		check(not helper.revalidate(wrong).valid,"tampered source ID rejected")
		wrong = receipt.duplicate(true)
		wrong.supports[0].transform.origin.x += .01
		check(not helper.revalidate(wrong).valid,"moved support receipt rejected")
		wrong = receipt.duplicate(true)
		wrong.grounded_feet.y -= .02
		check(not helper.revalidate(wrong).valid,"tampered support height rejected")
		wrong = receipt.duplicate(true)
		wrong.supports.pop_back()
		check(not helper.revalidate(wrong).valid,"incomplete support receipt rejected")
		var grounded: Dictionary = helper.inspect(receipt.grounded_feet)
		check(grounded.valid and absf(grounded.drop_m)<.00001,"already grounded stable")
	check(not helper.inspect(descriptor.step_off_point,.1).valid,"cannot settle beyond requested10cm envelope")
	for invalid: float in [-.1,.281,INF,NAN]:
		check(not helper.inspect(descriptor.step_off_point,invalid).valid,"invalid drop bound rejected")
	check(not helper.inspect(Vector3(NAN,0,0)).valid,"invalid feet rejected")
	check(descriptor == original_descriptor,"source route endpoints unchanged")
	check(player.global_position == original_position,"helper never moves actual player")
	check(player.get_collision_exceptions() == original_exceptions,"helper never changes actual player filters")
	check(not helper.revalidate({}).valid,"empty receipt rejected")
	helper.configure(scene.get_world_3d().direct_space_state,2,player.get_rid())
	check(not helper.revalidate(receipt).valid,"changed mask lease rejected")
	helper.configure(scene.get_world_3d().direct_space_state,1,RID())
	check(not helper.revalidate(receipt).valid,"changed actor lease rejected")
	helper.configure(scene.get_world_3d().direct_space_state,0,player.get_rid())
	check(not helper.inspect(descriptor.step_off_point).valid,"zero query mask cannot certify support")
	helper.configure(scene.get_world_3d().direct_space_state,1,player.get_rid())
	var costs: Array[int] = []
	for i in 160:
		var begin := Time.get_ticks_usec()
		var measured: Dictionary = helper.inspect(descriptor.step_off_point)
		check(measured.valid,"warm actual-main grounding query remains valid")
		if i>=32: costs.append(Time.get_ticks_usec()-begin)
	costs.sort()
	var fixture_actor := CharacterBody3D.new()
	fixture_actor.collision_layer = 2
	fixture_actor.collision_mask = 1
	var actor_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .33
	capsule.height = 1.9
	actor_shape.shape = capsule
	actor_shape.position.y = .962
	fixture_actor.add_child(actor_shape)
	scene.add_child(fixture_actor)
	fixture_actor.global_position = descriptor.step_off_point
	await physics_frame
	await physics_frame
	var player_before_physical_samples := player.global_position
	helper.configure(scene.get_world_3d().direct_space_state,1,fixture_actor.get_rid())
	var physical_receipt: Dictionary = helper.inspect(descriptor.step_off_point)
	check(physical_receipt.valid,"actual native test actor root admitted")
	if physical_receipt.valid:
		for next: Vector3 in physical_receipt.ordered_roots:
			check(helper.revalidate(physical_receipt).valid,"live native test actor rechecks support before each move")
			var collision := fixture_actor.move_and_collide(next-fixture_actor.global_position)
			check(collision == null,"native CharacterBody accepted ordered grounding sample")
			check(fixture_actor.global_position.distance_to(next)<.00001,"physical root matches accepted sample")
		check(fixture_actor.global_position.distance_to(physical_receipt.grounded_feet)<.00001,"native physical actor reaches real roof")
		check(fixture_actor.get_collision_exceptions().is_empty(),"physical grounding needs no body exceptions")
	check(player.global_position == player_before_physical_samples,"grounding test never writes real main player during synchronous native samples")
	fixture_actor.free()
	helper.dispose()
	check(not helper.inspect(descriptor.step_off_point).valid,"disposed query fails closed")
	check(not helper.revalidate(physical_receipt).valid,"disposed lease cannot revalidate old physical receipt")
	print("LADDER_LANDING_SETTLE_TEST ",JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,
		"source_authored_feet":descriptor.step_off_point,"grounded_feet":receipt.get("grounded_feet"),"drop_m":receipt.get("drop_m"),
		"cpu_us":{"p50":costs[64],"p95":costs[121],"samples":128},"scope":"actual-main headless proposal; no physical host/rig/LIVE hookup"}))
	scene.free()
	quit(0 if failures.is_empty() else 1)

func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition: failures.append(label)
