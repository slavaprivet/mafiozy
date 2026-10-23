extends SceneTree

const Candidate = preload("res://scripts/transport/candidates/transport_wet_exit_authority.gd")
const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Pose = preload("res://scripts/transport/transport_water_doorway_pose.gd")
const TestKit = preload("res://scripts/tests/test_transport_wet_exit_authority.gd")

var failures: Array[String] = []

func run() -> void:
	var catalog := Catalog.new()
	if not catalog.load_file(): failures.append("catalog")
	var world := Node3D.new(); root.add_child(world)
	var actor := CharacterBody3D.new(); actor.collision_layer = 2; actor.collision_mask = 1
	actor.set_meta("actor_id", "cost-actor"); actor.set_meta("life_generation", 1)
	var collision := CollisionShape3D.new(); collision.name = "PlayerCapsule"; collision.position.y = .95
	var shape := CapsuleShape3D.new(); shape.radius = .36; shape.height = 1.9; collision.shape = shape
	actor.add_child(collision); world.add_child(actor)
	var vehicle := RigidBody3D.new(); vehicle.freeze = true; vehicle.collision_layer = 1; vehicle.collision_mask = 1
	vehicle.set_meta("vehicle_id", "cost-vehicle"); vehicle.set_meta("life_generation", 1); vehicle.set_meta("profile_id", "compact_sedan")
	world.add_child(vehicle); actor.add_collision_exception_with(vehicle)
	var seat: Dictionary = catalog.seat("compact_sedan", "front_left")
	actor.global_position = Pose.water_seat_point(vehicle.global_transform, seat).world_position_m
	await physics_frame; await physics_frame
	var providers := TestKit.Providers.new(); var candidate := Candidate.new()
	if candidate.configure(catalog, 1, providers.water_at, providers.ground, providers.planar, providers.own_vehicle, providers.source_motion).code != "OK": failures.append("configure")
	var actor_ref := {"actor_id": "cost-actor", "life_generation": 1}
	var vehicle_ref := {"vehicle_id": "cost-vehicle", "life_generation": 1}
	var clock := 1
	for warm in range(10):
		var row: Dictionary = candidate.begin_hold(actor_ref, vehicle_ref, "compact_sedan", "front_left", clock, actor, vehicle, TestKit.ActualAdapter.new(), true, 1); clock += 1
		if row.code != "HOLDING": failures.append("warm_begin")
		else: candidate.cancel(row.token, 1, "COST_WARMUP")
	var samples := PackedFloat64Array()
	for block in range(20):
		var started := Time.get_ticks_usec()
		for iteration in range(5):
			var row: Dictionary = candidate.begin_hold(actor_ref, vehicle_ref, "compact_sedan", "front_left", clock, actor, vehicle, TestKit.ActualAdapter.new(), true, 1); clock += 1
			if row.code != "HOLDING": failures.append("measured_begin")
			else: candidate.cancel(row.token, 1, "COST_SAMPLE")
		samples.append(float(Time.get_ticks_usec() - started) / 5.0)
	samples.sort()
	var cost := {"operations": 100, "operation": "begin_hold actual Jolt capsule probes + cancel", "block_mean_us_min": samples[0], "block_mean_us_p50": (samples[9] + samples[10]) * .5, "block_mean_us_p95": samples[18], "block_mean_us_max": samples[19]}
	candidate.dispose(); world.queue_free(); await process_frame
	print(JSON.stringify({"checks": 100, "failures": failures, "engine": Engine.get_version_info().string, "cost": cost,
		"scope": "isolated headless physical admission query; not event/frame/full-scene FPS"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
