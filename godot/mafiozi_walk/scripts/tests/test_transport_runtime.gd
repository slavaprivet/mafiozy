extends SceneTree

const Runtime = preload("res://scripts/transport/transport_runtime.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func run() -> void:
	var runtime := Runtime.new(); root.add_child(runtime)
	var floor := StaticBody3D.new(); floor.position = Vector3(0, -.1, 0); floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(20, .2, 20); floor_shape.shape = box; floor.add_child(floor_shape); root.add_child(floor)
	await physics_frame
	check(runtime.initialized, "runtime loads tracked descriptor: " + runtime.error)
	var actor := {"actor_id": "actor:runtime", "life_generation": 2}
	var parking_id := "parking:REBUILD-VISUAL-hospital-001:bay:0"; var bay: Dictionary = runtime.catalog.parking_bay(parking_id); var desired_local := Vector3(2, 0, 1)
	var origin := {"x":float(bay.position_m.x) - desired_local.x,"y":float(bay.position_m.y) - desired_local.y,"z":float(bay.position_m.z) - desired_local.z}
	var boot_request := {"session_id":"runtime:test","session_generation":1,"session_source_clock":1000000,"roster_source_clock":1100000,"factory_slot_id":"parked-sedan","parking_id":parking_id,"origin_m":origin}
	var boot: Dictionary = runtime.bootstrap_new_session(boot_request)
	check(boot.code == "OK", "runtime starts actual nonzero-origin source bootstrap")
	var born: Dictionary = boot.packet.roster.vehicles[0]; var vehicle := {"vehicle_id":born.vehicle_id,"life_generation":born.life_generation}
	check(Vector3(float(born.position_m.x),float(born.position_m.y),float(born.position_m.z)).distance_to(desired_local) < .001, "bootstrap source-world parking reaches intended Godot-local pose")
	born.source_clock = 1110000
	var snapshot := {"session_id": "runtime:test", "session_generation": 1, "source_clock": 1110000, "roster_revision": 2,
		"actors": [{"actor_id": "actor:runtime", "life_generation": 2, "active": true}],
		"vehicles": [born]}
	check(runtime.publish_roster(snapshot).code == "OK", "runtime receives explicit roster without inventing births")
	var vehicle_body := RigidBody3D.new(); vehicle_body.freeze = true; vehicle_body.position = desired_local; vehicle_body.rotation.y = .4; vehicle_body.collision_layer = 1; vehicle_body.set_meta("vehicle_id", born.vehicle_id); vehicle_body.set_meta("life_generation", born.life_generation)
	var vehicle_shape := CollisionShape3D.new(); vehicle_shape.position.y = .55; var vehicle_box := BoxShape3D.new(); vehicle_box.size = Vector3(1.7, 1.1, 3.8); vehicle_shape.shape = vehicle_box; vehicle_body.add_child(vehicle_shape); root.add_child(vehicle_body)
	await physics_frame; await physics_frame
	check(runtime.sync_native_vehicle_pose(vehicle, vehicle_body, 1120000).code == "OK", "bootstrap host accepts exact native body pose")
	var before_duplicate: Dictionary = runtime.host.diagnostics(); var duplicate_boot: Dictionary = runtime.bootstrap_new_session(boot_request)
	check(duplicate_boot.code == "DUPLICATE" and runtime.host.diagnostics() == before_duplicate, "idempotent bootstrap retry is a host and binding no-op")
	var duplicate_vehicle := RigidBody3D.new(); duplicate_vehicle.freeze = true; duplicate_vehicle.position = desired_local; duplicate_vehicle.set_meta("vehicle_id", born.vehicle_id); duplicate_vehicle.set_meta("life_generation", born.life_generation); root.add_child(duplicate_vehicle); await physics_frame
	check(runtime.sync_native_vehicle_pose(vehicle, duplicate_vehicle, 1130000).code == "BODY_BINDING", "same-generation duplicate vehicle body cannot replace bound native instance")
	duplicate_vehicle.queue_free(); await physics_frame
	var synced: Dictionary = runtime.host.vehicle_record(vehicle)
	check(Vector3(float(synced.position_m.x), float(synced.position_m.y), float(synced.position_m.z)).distance_to(vehicle_body.global_position) < .001 and is_equal_approx(float(synced.yaw_rad), .4), "host door anchors use current moving body pose")
	var approach_data: Dictionary = runtime.host.approach_world_pose(vehicle, "front_left")
	var p: Dictionary = approach_data.position_m; var feet := Vector3(float(p.x), float(p.y), float(p.z))
	check(runtime.begin_board(actor, vehicle, "front_left", 1150000, feet + Vector3(100, 0, 0), true).code == "UNSAFE_ACCESS", "boarding from 100m is refused")
	check(runtime.begin_board(actor, vehicle, "front_left", 1160000, feet, false).code == "UNSAFE_ACCESS", "closed/unready authored door refuses boarding")
	var started := runtime.begin_board(actor, vehicle, "front_left", 1200000, feet, true)
	check(started.code == "HOLDING", "runtime combines actual capsule receipt with seat lease")
	check(runtime.sync_native_vehicle_pose(vehicle, vehicle_body, 1210000).code == "OK" and not runtime.host.lease(started.token).is_empty(), "native pose sync preserves an active seat claim")
	var result: Dictionary = {}
	for clock in [1300000, 1400000, 1500000]:
		await physics_frame
		result = runtime.advance_interaction(started.token, true, int(clock), feet, true)
	check(result.code == "TRANSITION_REQUIRED" and runtime.host.driver(vehicle).is_empty(), "runtime hold requires physical seat transition")
	var fabricated := {"provider":"TRANSPORT_ACTOR_TRANSITION_V1","action":"BOARD","token":started.token,"source_clock":4100000,"pose_done":true,"physical_safe":true,"seat_reached":true}
	check(runtime.complete_transition(started.token, 4100000, fabricated).code == "TRANSITION_PROVIDER_REQUIRED", "runtime refuses caller-fabricated transition receipts")
	var actor_body := CharacterBody3D.new(); actor_body.position = feet; actor_body.collision_layer = 2; actor_body.collision_mask = 1; actor_body.set_meta("actor_id", "actor:runtime"); actor_body.set_meta("life_generation", 2)
	var actor_shape := CollisionShape3D.new(); actor_shape.position.y = .95; var actor_capsule := CapsuleShape3D.new(); actor_capsule.radius = .36; actor_capsule.height = 1.9; actor_shape.shape = actor_capsule; actor_body.add_child(actor_shape); root.add_child(actor_body)
	await physics_frame; await physics_frame
	check(runtime.begin_actor_transition(started.token, 1, actor_body, vehicle_body).code == "STALE_CLOCK", "actor transition cannot start before logical transition clock")
	check(runtime.begin_actor_transition(started.token, 1500000, actor_body, vehicle_body).code == "ACTIVE", "runtime binds transition to actual CharacterBody and RigidBody identities")
	var duplicate_actor := CharacterBody3D.new(); duplicate_actor.position = actor_body.position; duplicate_actor.set_meta("actor_id", "actor:runtime"); duplicate_actor.set_meta("life_generation", 2); root.add_child(duplicate_actor); await physics_frame
	check(runtime.begin_actor_transition(started.token, 1500001, duplicate_actor, vehicle_body).code == "BODY_BINDING", "same-generation duplicate actor cannot replace bound native instance")
	duplicate_actor.queue_free(); await physics_frame
	var transition_clock := 1500000
	for index in 12:
		transition_clock += 100000; await physics_frame
		result = runtime.advance_actor_transition(started.token, .1, transition_clock)
	check(result.code == "BOARDED", "runtime boards only after actual shared 1.2s CharacterBody seat arrival: " + JSON.stringify(result))
	check(runtime.host.driver(vehicle).get("actor_id") == "actor:runtime", "runtime driver is front-left source actor")
	vehicle_body.position.x += 1.0; actor_body.position.x += 1.0; await physics_frame
	check(runtime.sync_native_vehicle_pose(vehicle, vehicle_body, 4200000).code == "OK" and runtime.host.driver(vehicle).get("actor_id") == "actor:runtime", "native pose sync preserves occupancy and identity")
	var exit_started := runtime.begin_exit(actor, vehicle, "front_left", 4300000, actor_body.global_position, true, [vehicle_body.get_rid()])
	check(exit_started.code == "HOLDING", "bound seated actor begins physical exit")
	for clock in [4400000, 4500000, 4600000]:
		result = runtime.advance_interaction(exit_started.token, true, int(clock), actor_body.global_position, true, [vehicle_body.get_rid()])
	check(result.code == "TRANSITION_REQUIRED" and runtime.begin_actor_transition(exit_started.token, 4600000, actor_body, vehicle_body).code == "ACTIVE", "exit reaches bound actor transition")
	check(runtime.begin_session({}).code == "INVALID_SESSION" and not runtime.actor_transition.state(exit_started.token).is_empty(), "invalid session packet cannot cancel active physical state")
	check(runtime.begin_session({"session_id":"runtime:replacement","mode":"NEW_SESSION_BOOTSTRAP","session_generation":1,"source_clock":5000000}).code == "OK", "replacement session resets transport runtime")
	check(runtime.advance_actor_transition(exit_started.token, .1, 5100000).code == "TOKEN" and not (vehicle_body in actor_body.get_collision_exceptions()), "session reset cancels stale physical motion and owned exception")
	actor_body.queue_free(); vehicle_body.queue_free(); runtime.queue_free(); floor.queue_free(); await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "scope": "headless transport runtime with actual PhysicsDirectSpaceState3D; no GPU/LIVE claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
