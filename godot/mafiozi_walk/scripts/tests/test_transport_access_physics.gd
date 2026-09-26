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
	wall.queue_free(); await physics_frame; await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var clear: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 300, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(clear.reachable and clear.path_clear and clear.destination_clear, "real empty-space capsule exit is admitted")
	var landing := body_at(Vector3(2, .95, 0), Vector3(.7, 1.9, .7)); await physics_frame; await physics_frame
	provider.configure(scene.get_world_3d().direct_space_state, 1)
	var occupied: Dictionary = provider.probe_access(actor_ref, vehicle_ref, "front_left", "EXIT", 400, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check(not occupied.reachable and not occupied.destination_clear, "occupied landing refuses physical exit")
	landing.queue_free(); scene.queue_free(); await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "scope": "actual PhysicsDirectSpaceState3D capsule sweeps; headless fixture only"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
