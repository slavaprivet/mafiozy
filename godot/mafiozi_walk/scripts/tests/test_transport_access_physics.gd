extends SceneTree

const Provider = preload("res://scripts/transport/transport_access_provider.gd")
var failures: Array[String] = []
var checks := 0
var scene: Node3D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func body_at(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = position; body.collision_layer = 1; body.collision_mask = 0
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape
	body.add_child(collision); scene.add_child(body); return body

func run() -> void:
	scene = Node3D.new(); root.add_child(scene)
	var floor := body_at(Vector3(0, -.1, 0), Vector3(12, .2, 12))
	var wall := body_at(Vector3(0, .95, 0), Vector3(.3, 1.9, 3.0))
	await physics_frame; await physics_frame
	var provider := Provider.new(); provider.configure(scene.get_world_3d().direct_space_state, 1)
	var actor_ref := {"actor_id": "actor:max", "life_generation": 4}
	var vehicle_ref := {"vehicle_id": "vehicle:source:compact-001", "life_generation": 7}
	var blocked: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "BOARD", 100, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(not blocked.reachable and not blocked.path_clear, "real Godot capsule sweep refuses wall crossing")
	check(blocked.provider == "GODOT_PHYSICS_SPACE_V1" and blocked.vehicle_generation == 7, "receipt binds provider and vehicle lifetime")
	var excluded: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "BOARD", 200, Vector3(-2, 0, 0), Vector3(2, 0, 0), [wall.get_rid()])
	check(excluded.reachable and excluded.path_clear and excluded.destination_clear, "own vehicle RID can be excluded from access sweep")
	var overlap := body_at(Vector3(-2, .95, 0), Vector3(.3, 1.9, .3)); await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var started_inside: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "BOARD", 250, Vector3(-2, 0, 0), Vector3(-1, 0, 0))
	check(not started_inside.reachable and not started_inside.start_clear, "initial capsule overlap fails closed before cast_motion")
	overlap.queue_free(); await physics_frame
	wall.queue_free(); await physics_frame; await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var clear: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 300, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(clear.reachable and clear.path_clear and clear.destination_clear and clear.support_clear, "supported dry capsule exit is admitted")
	var small: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 300, Vector3(-2, 0, 0), Vector3(2, 0, 0), [], .2, .5)
	check(small.reachable and is_equal_approx(provider.get("_capsule").radius, .2) and is_equal_approx(provider.get("_capsule").height, .5), "small valid capsule retains exact custom dimensions")
	var large: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 300, Vector3(-2, 0, 0), Vector3(2, 0, 0), [], .8, 2.2)
	check(large.reachable and is_equal_approx(provider.get("_capsule").radius, .8) and is_equal_approx(provider.get("_capsule").height, 2.2), "large valid capsule retains exact custom dimensions")
	check(not provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 300, Vector3(-2, 0, 0), Vector3(2, 0, 0), [], NAN, 1.9).reachable, "nonfinite custom capsule fails closed")
	var probe_started := Time.get_ticks_usec()
	for i in 500:
		provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 301 + i, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	var probe_500_us := Time.get_ticks_usec() - probe_started
	var seated_low: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 325, Vector3(-2, -.016, 0), Vector3(2, 0, 0))
	check(seated_low.reachable and absf(float(seated_low.start_floor_correction_m) - .016) < .001 and absf(float(seated_low.from_m.y) + .016) < .001, "exact seated anchor within bounded support seam uses query correction while receipt preserves actor provenance")
	var too_low: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 326, Vector3(-2, -.06, 0), Vector3(2, 0, 0))
	check(not too_low.reachable and not too_low.start_clear and is_zero_approx(float(too_low.start_floor_correction_m)), "below-ground start beyond 5cm still fails closed")
	var near_wall := body_at(Vector3(-2, .95, 0), Vector3(.15, 1.9, .5)); await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var low_wall: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 327, Vector3(-2, -.016, 0), Vector3(2, 0, 0))
	check(not low_wall.reachable and not low_wall.start_clear, "seat-floor correction cannot bypass a wall at the seated start")
	near_wall.queue_free(); await physics_frame
	var edge: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 350, Vector3(5, 0, 0), Vector3(7, 0, 0))
	check(not edge.reachable and not edge.support_clear, "unsupported edge landing fails closed")
	var landing := body_at(Vector3(2, .95, 0), Vector3(.7, 1.9, .7)); await physics_frame; await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var occupied: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 400, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(not occupied.reachable and not occupied.destination_clear, "occupied landing refuses physical exit")
	landing.queue_free(); floor.queue_free(); await physics_frame; await physics_frame
	var water := body_at(Vector3(0, -.1, 0), Vector3(12, .2, 12)); water.set_meta("surface_kind", "water"); await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var wet: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 500, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(not wet.reachable and not wet.support_clear, "water-tagged support refuses exit")
	water.queue_free(); await physics_frame
	var sensor := Area3D.new(); sensor.position = Vector3(0, -.1, 0); sensor.collision_layer = 1; sensor.collision_mask = 0
	var sensor_shape := CollisionShape3D.new(); var sensor_box := BoxShape3D.new(); sensor_box.size = Vector3(12, .2, 12); sensor_shape.shape = sensor_box
	sensor.add_child(sensor_shape); scene.add_child(sensor); await physics_frame; await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var sensor_floor: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 550, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(not sensor_floor.reachable and not sensor_floor.support_clear, "Area3D sensor cannot count as physical foot support")
	sensor.queue_free(); scene.queue_free(); await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "probe_500_us": probe_500_us, "engine": Engine.get_version_info().string, "scope": "actual PhysicsDirectSpaceState3D capsule sweeps; headless fixture only"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
