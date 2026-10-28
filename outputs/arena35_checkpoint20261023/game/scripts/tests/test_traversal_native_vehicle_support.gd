extends SceneTree

const Probe = preload("res://scripts/traversal/traversal_probe.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.preview_residents_enabled = false
	root.add_child(main)
	for _frame in 90:
		await physics_frame
	var transport: Node = main.preview_transport
	var body: RigidBody3D = transport.body if is_instance_valid(transport) else null
	check(body != null and body.is_in_group("native_vehicle_body"), "actual preview NativeVehicleBody is available")
	if body != null:
		var probe := Probe.new()
		probe.configure(main.get_world_3d().direct_space_state, 1, main._player.get_rid())
		var state: Dictionary = body.snapshot_state()
		check(not body.sleeping and not body.freeze and int(state.get("grounded_wheel_mask",0)) == 0b1111,
			"actual parked preview body is awake and grounded")
		check(body.linear_velocity.length() <= Probe.PARKED_AWAKE_SPEED_MPS and probe._vehicle_is_stable(body,{}),
			"awake parked preview vehicle admits traversal on first request")
		body.linear_velocity = Vector3(.05,0,0)
		check(not probe._vehicle_is_stable(body,{}), "slow deliberate vehicle drift remains blocked")
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3(0,.02,0)
		check(not probe._vehicle_is_stable(body,{}), "awake rotating vehicle remains blocked")
		body.angular_velocity = Vector3.ZERO
		body.set_meta("traversal_vehicle_blocked",true)
		check(not probe._vehicle_is_stable(body,{}), "authoritative blocked vehicle state wins")
	print("TRAVERSAL_NATIVE_VEHICLE_SUPPORT_TEST ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"scope":"actual headless preview NativeVehicleBody stability seam; no GPU/LIVE claim"}))
	main.free()
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
