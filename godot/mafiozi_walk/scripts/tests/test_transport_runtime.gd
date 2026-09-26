extends SceneTree

const Runtime = preload("res://scripts/transport/transport_runtime.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func run() -> void:
	var runtime := Runtime.new(); root.add_child(runtime)
	await physics_frame
	check(runtime.initialized, "runtime loads tracked descriptor: " + runtime.error)
	check(runtime.begin_session({"session_id": "runtime:test", "mode": "NEW_SESSION_BOOTSTRAP", "session_generation": 1, "source_clock": 1000000}).code == "OK", "runtime starts explicit session")
	var actor := {"actor_id": "actor:runtime", "life_generation": 2}
	var vehicle := {"vehicle_id": "vehicle:runtime", "life_generation": 3}
	var snapshot := {"session_id": "runtime:test", "session_generation": 1, "source_clock": 1100000, "roster_revision": 1,
		"actors": [{"actor_id": "actor:runtime", "life_generation": 2, "active": true}],
		"vehicles": [{"vehicle_id": "vehicle:runtime", "life_generation": 3, "active": true, "profile_id": "compact_sedan", "position_m": {"x": 0.0, "y": 0.0, "z": 0.0}, "yaw_rad": 0.0, "seats": {}}]}
	check(runtime.publish_roster(snapshot).code == "OK", "runtime receives explicit roster without inventing births")
	var approach_data: Dictionary = runtime.host.approach_world_pose(vehicle, "front_left")
	var p: Dictionary = approach_data.position_m; var feet := Vector3(float(p.x), float(p.y), float(p.z))
	var started := runtime.begin_board(actor, vehicle, "front_left", 1200000, feet)
	check(started.code == "HOLDING", "runtime combines actual capsule receipt with seat lease")
	var result: Dictionary = {}
	for clock in [1300000, 1400000, 1500000]:
		await physics_frame
		result = runtime.advance_interaction(started.token, true, int(clock), feet)
	check(result.code == "BOARDED", "runtime completes continuous 0.3s E boarding")
	check(runtime.host.driver(vehicle).get("actor_id") == "actor:runtime", "runtime driver is front-left source actor")
	runtime.queue_free(); await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "scope": "headless transport runtime with actual PhysicsDirectSpaceState3D; no GPU/LIVE claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
