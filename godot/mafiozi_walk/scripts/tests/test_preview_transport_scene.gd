extends SceneTree
var failures: Array[String] = []
var checks := 0
var phases: Array[String] = []
var scene: Node3D
var transport: Node3D
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		if is_instance_valid(transport) and (phases.is_empty() or phases[-1] != transport.phase):
			phases.append(transport.phase)
			print("TRANSPORT_SCENE_PHASE ", transport.phase, " error=", transport.error, " player=", scene._player.position,
				" body=", transport.body.global_transform, " seat=", transport._seat_position("front_left"), " exceptions=", scene._player.get_collision_exceptions().size())
func _run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled = true
	root.add_child(scene)
	var deadline := Time.get_ticks_msec()+15000
	while not scene.preview_ready and Time.get_ticks_msec()<deadline: await physics_frame
	scene._player.set_mouse_captured(true) # This QA explicitly acquires control.
	transport = scene.preview_transport
	check(scene.preview_ready, "actual main ready")
	check(scene.transport_status == "ready", "transport setup: " + scene.transport_status)
	if scene.transport_status != "ready":
		finish()
		return
	await frames(90)
	check(scene._player.is_on_floor(), "source parking approach has actual floor")
	check(transport.body.global_position.distance_to(Vector3(37.05, 0.0, -9.75)) < 0.7, "vehicle stays at source parking after settling")
	check(transport.visual.profile_id == "city_hatchback", "source factory profile")
	check(transport.body.get_meta("vehicle_id") == "local_vehicle_1", "source local vehicle identity")
	transport._e_down = true
	await frames(310)
	check(transport.phase == "SEATED", "actual player physically boarded: " + transport.phase + "/" + transport.error)
	check(transport.runtime.host.driver(transport._vehicle_ref).get("actor_id") == "player", "driver committed after actual seat arrival")
	check(scene._player.get_preview_status().pose_authority == &"vehicle", "single vehicle pose writer")
	if transport.phase == "SEATED":
		transport._e_down = false
		var before: Vector3 = transport.body.global_position
		Input.action_press("preview_move_forward")
		await frames(90)
		Input.action_release("preview_move_forward")
		check(transport.body.global_position.distance_to(before) > 0.15, "native vehicle drives")
		transport._e_down = true
		transport._pending_exit = true
		await frames(300)
		check(transport.phase == "ON_FOOT", "actual exit and recovery: " + transport.phase + "/" + transport.error)
		check(transport.runtime.host.driver(transport._vehicle_ref).is_empty(), "driver released after outside arrival")
		check(scene._player.get_preview_status().pose_authority == &"on_foot", "walking restored")
		check(scene._player.is_on_floor(), "physical grounded after exit")
	finish()
func finish() -> void:
	print(JSON.stringify({"checks": checks, "failures": failures, "phases": phases, "pose_error": transport.error if is_instance_valid(transport) else ""}))
	if is_instance_valid(scene): scene.free()
	quit(0 if failures.is_empty() else 1)
