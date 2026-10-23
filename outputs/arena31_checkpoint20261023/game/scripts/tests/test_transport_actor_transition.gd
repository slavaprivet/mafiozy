extends SceneTree

const Transition = preload("res://scripts/transport/transport_actor_transition.gd")
const Access = preload("res://scripts/transport/transport_access_provider.gd")

var failures: Array[String] = []
var checks := 0
var scene: Node3D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func static_box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = position; body.collision_layer = 1
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; collision.shape = box; body.add_child(collision); scene.add_child(body)
	return body

func actor_at(position: Vector3) -> CharacterBody3D:
	var actor := CharacterBody3D.new(); actor.position = position; actor.collision_layer = 2; actor.collision_mask = 1
	actor.set_meta("actor_id", "actor:max"); actor.set_meta("life_generation", 4)
	var collision := CollisionShape3D.new(); collision.position.y = .95; var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9; collision.shape = capsule; actor.add_child(collision); scene.add_child(actor)
	return actor

func vehicle_at(position: Vector3) -> RigidBody3D:
	var vehicle := RigidBody3D.new(); vehicle.position = position; vehicle.freeze = true; vehicle.collision_layer = 1; vehicle.collision_mask = 3
	vehicle.set_meta("vehicle_id", "vehicle:test"); vehicle.set_meta("life_generation", 2)
	var collision := CollisionShape3D.new(); collision.position.y = .55; var box := BoxShape3D.new(); box.size = Vector3(1.7, 1.1, 3.8); collision.shape = box; vehicle.add_child(collision); scene.add_child(vehicle)
	return vehicle

func advance(provider: RefCounted, token: String, start_clock: int, seconds: float) -> Dictionary:
	var result: Dictionary = {}; var clock := start_clock; var remaining := seconds
	while remaining > .00001:
		var dt := minf(.1, remaining); remaining -= dt; clock += int(round(dt * 1000000.0))
		await physics_frame
		result = provider.step(token, dt, clock)
		if result.code in ["BLOCKED", "COMPLETE"]: break
	return result

func run() -> void:
	scene = Node3D.new(); root.add_child(scene)
	static_box(Vector3(0, -.1, 0), Vector3(40, .2, 40))
	var origin_m := Vector3(395.65, 0, 45.1); var source_vehicle_m := Vector3(400.65, 0, 43.1); var local_vehicle_m := source_vehicle_m - origin_m
	var vehicle := vehicle_at(local_vehicle_m); var actor := actor_at(local_vehicle_m + Vector3(-2.0, 0, 0))
	await physics_frame; await physics_frame
	var provider := Transition.new(); provider.configure(Access.new())
	var actor_ref := {"actor_id":"actor:max", "life_generation":4}; var vehicle_ref := {"vehicle_id":"vehicle:test", "life_generation":2}
	var seat := Vector3(-.42, 0, 0); var approach := Vector3(-2.0, 0, 0)
	check(vehicle.global_position == local_vehicle_m and vehicle.global_position != source_vehicle_m, "transition bodies stay in Godot-local source-minus-origin frame")
	vehicle.linear_velocity = Vector3(.6, 0, 0)
	check(provider.begin("board:moving", "BOARD", actor_ref, vehicle_ref, "front_left", 900000, actor, vehicle, seat, approach).code == "VEHICLE_MOVING", "source boarding limit refuses vehicle faster than 0.5 m/s")
	vehicle.linear_velocity = Vector3.ZERO
	check(provider.begin("board:1", "BOARD", actor_ref, vehicle_ref, "front_left", 1000000, actor, vehicle, seat, approach).code == "ACTIVE", "actual CharacterBody/RigidBody boarding starts from authored approach")
	var board_mid := await advance(provider, "board:1", 1000000, .6)
	check(board_mid.code == "ACTIVE" and float(board_mid.progress) > .49 and float(board_mid.progress) < .51 and float(board_mid.seat_blend) > 0.0 and float(board_mid.seat_blend) < 1.0, "1.2-second boarding keeps a smooth mid-curve body/seat blend")
	check(float(board_mid.door) > 0.0 and float(board_mid.fold) > 0.0, "mid-curve door and fold remain visibly staged")
	var board := await advance(provider, "board:1", 1600000, .6)
	check(board.code == "COMPLETE" and board.receipt.seat_reached, "1.2-second user-paced curve reaches the actual seat body")
	check(board.pose.source_phase == "seated" and is_equal_approx(float(board.pose.seat_blend), 1.0), "boarding exposes exact source pose phase for visuals")
	check(actor.global_position.distance_to(vehicle.global_transform * seat) <= .08, "boarding receipt matches actual CharacterBody seat position")
	check(provider.commit("board:1").code == "COMMITTED", "logical board acceptance commits physical exception ownership")
	check(vehicle in actor.get_collision_exceptions(), "seated actor keeps the vehicle collision exception owned by transition")
	var exit_started := provider.begin("exit:1", "EXIT", actor_ref, vehicle_ref, "front_left", 4000000, actor, vehicle, seat, approach)
	check(exit_started.code == "ACTIVE" and exit_started.exit_kind == "walk", "stationary vehicle selects source walk exit")
	var exit := await advance(provider, "exit:1", 4000000, 1.3)
	check(exit.code == "COMPLETE" and exit.get("receipt", {}).get("outside_reached", false) and exit.get("receipt", {}).get("grounded", false), "release plus recovery proves physical outside arrival: " + JSON.stringify(exit))
	check(exit.pose.source_phase == "exit_body" and is_equal_approx(float(exit.pose.body_progress), 1.0), "exit exposes source recovery pose phase for visuals")
	check(provider.commit("exit:1").code == "COMMITTED", "logical exit acceptance commits collision cleanup")
	check(not (vehicle in actor.get_collision_exceptions()), "owned vehicle exception is removed after complete exit")
	check(actor.global_position.distance_to(vehicle.global_transform * approach) > .02, "walk recovery moves actual actor beyond the door approach")
	actor.queue_free(); vehicle.queue_free(); await physics_frame
	var blocked_vehicle := vehicle_at(Vector3(5, 0, 0)); var blocked_actor := actor_at(Vector3(3, 0, 0)); var wall := static_box(Vector3(4.25, .95, 0), Vector3(.15, 1.9, 2.0))
	await physics_frame; await physics_frame
	check(provider.begin("board:blocked", "BOARD", actor_ref, vehicle_ref, "front_left", 6000000, blocked_actor, blocked_vehicle, seat, approach).code == "ACTIVE", "blocked fixture begins before staged motion reaches wall")
	var blocked := await advance(provider, "board:blocked", 6000000, 1.2)
	check(blocked.code == "BLOCKED" and not blocked.has("receipt"), "real wall collision never emits transition receipt")
	check(provider.cancel("board:blocked").code == "CANCELLED", "blocked transition remains explicitly cancellable")
	check(not (blocked_vehicle in blocked_actor.get_collision_exceptions()), "cancel restores collision relation after failed board")
	wall.queue_free(); blocked_actor.queue_free(); blocked_vehicle.queue_free(); await physics_frame
	var imported_vehicle := vehicle_at(Vector3(-5, 0, 0)); var imported_actor := actor_at(Vector3(-5, 0, 0) + seat); var imported_provider := Transition.new(); imported_provider.configure(Access.new())
	await physics_frame; await physics_frame
	check(imported_provider.begin("exit:imported", "EXIT", actor_ref, vehicle_ref, "front_left", 7000000, imported_actor, imported_vehicle, seat, approach).code == "ACTIVE", "imported seated actor without prior exception begins exit")
	var imported_exit := await advance(imported_provider, "exit:imported", 7000000, 1.3)
	check(imported_exit.code == "COMPLETE" and imported_provider.commit("exit:imported").code == "COMMITTED" and not (imported_vehicle in imported_actor.get_collision_exceptions()), "successful imported exit removes transition-owned collision exception")
	imported_actor.queue_free(); imported_vehicle.queue_free(); await physics_frame
	var moving_vehicle := vehicle_at(Vector3(-8, 0, 0)); var moving_actor := actor_at(Vector3(-8, 0, 0) + seat); var moving_provider := Transition.new(); moving_provider.configure(Access.new())
	var retained_vehicle_velocity := Vector3(0, 0, -6.0); moving_vehicle.linear_velocity = retained_vehicle_velocity
	await physics_frame; await physics_frame
	var moving_begin := moving_provider.begin("exit:moving", "EXIT", actor_ref, vehicle_ref, "front_left", 7400000, moving_actor, moving_vehicle, seat, approach)
	check(moving_begin.code == "ACTIVE" and moving_begin.exit_kind == "tumble", "exit above 15 km/h selects the source tumble path")
	var moving_release := moving_provider.step("exit:moving", .55, 7950000)
	check(moving_release.code == "ACTIVE" and moving_provider.state("exit:moving").phase == "RECOVERY", "moving exit completes its door release before inherited motion")
	var moving_start := moving_actor.global_position; var moving_body := moving_provider.step("exit:moving", .1, 8050000)
	check(moving_body.code == "ACTIVE" and moving_body.source_phase == "exit_body" and float(moving_body.body_progress) > 0.0, "moving exit publishes continuous tumble body progress")
	check(moving_actor.global_position.distance_to(moving_start) > .1, "moving exit inherits actual vehicle velocity instead of dropping beside the door")
	check(moving_vehicle.linear_velocity.is_equal_approx(retained_vehicle_velocity), "actor transition never brakes or mutates the moving vehicle")
	var moving_done := await advance(moving_provider, "exit:moving", 8050000, 1.6)
	var moving_committed := moving_provider.commit("exit:moving") if moving_done.code == "COMPLETE" else {"code":"NOT_COMPLETE"}
	check(moving_done.code == "COMPLETE" and moving_done.get("receipt", {}).get("source_exit_kind", "") == "tumble" and moving_committed.code == "COMMITTED", "moving tumble exit completes with physical receipt and collision cleanup: " + JSON.stringify(moving_done))
	moving_actor.queue_free(); moving_vehicle.queue_free(); await physics_frame
	var clock_vehicle := vehicle_at(Vector3.ZERO); var clock_actor := actor_at(approach); await physics_frame; await physics_frame
	check(provider.begin("board:clock", "BOARD", actor_ref, vehicle_ref, "front_left", 8000000, clock_actor, clock_vehicle, seat, approach).code == "ACTIVE", "clock-coherence fixture begins")
	var slow_clock := 8000000; var clock_result: Dictionary = {}
	for index in 12:
		slow_clock += 1; clock_result = provider.step("board:clock", .1, slow_clock)
	check(clock_result.code == "ACTIVE" and not provider.state("board:clock").is_empty() and not clock_result.has("receipt"), "physical completion waits without erasing state when source clock is behind")
	clock_result = provider.step("board:clock", 0.0, 9200000)
	check(clock_result.code == "COMPLETE" and clock_result.receipt.seat_reached, "retained physical state commits when authoritative clock catches up")
	check(provider.commit("board:clock").code == "COMMITTED", "clock-coherent physical completion accepts explicit logical commit")
	provider.cancel_all(); clock_actor.position = approach; await physics_frame
	check(provider.begin("board:substep", "BOARD", actor_ref, vehicle_ref, "front_left", 11000000, clock_actor, clock_vehicle, seat, approach).code == "ACTIVE", "bounded-substep fixture begins")
	var substep_result: Dictionary = {}; var substep_clock := 11000000
	for index in 6:
		substep_clock += 200000; substep_result = provider.step("board:substep", .2, substep_clock)
	check(substep_result.code == "COMPLETE" and substep_result.receipt.seat_reached, "0.2-second caller delta is consumed as bounded substeps for exact 1.2-second boarding")
	provider.commit("board:substep"); provider.cancel_all(); clock_actor.position = approach; await physics_frame
	check(provider.begin("board:cancel", "BOARD", actor_ref, vehicle_ref, "front_left", 12300000, clock_actor, clock_vehicle, seat, approach).code == "ACTIVE", "accelerated boarding remains cancellable while staged")
	var cancel_pose := provider.step("board:cancel", .2, 12500000)
	check(cancel_pose.code == "ACTIVE" and float(cancel_pose.progress) > 0.0 and provider.cancel("board:cancel").code == "CANCELLED", "mid-curve cancellation removes the transition without a seat receipt")
	check(not (clock_vehicle in clock_actor.get_collision_exceptions()), "cancelled accelerated boarding restores collision ownership")
	provider.cancel_all(); clock_actor.queue_free(); clock_vehicle.queue_free(); scene.queue_free(); await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"actual CharacterBody3D motion against frozen RigidBody3D and StaticBody3D; headless only"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
