extends SceneTree
const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
var rows: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var profile: Dictionary = {}
	for item: Dictionary in document.profiles:
		if item.profile_id == "city_hatchback": profile = item
	var floor := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500,0.5,500)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.25
	floor.add_child(collision)
	root.add_child(floor)
	var catalogue := Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var visual_result := Visual.instantiate_visual(catalogue.entries.city_hatchback, catalogue.base_path)
	var visual: RefCounted = visual_result.visual
	root.add_child(visual.root)
	visual.update_wheels(0.3, 0.0)
	var front_pivot: Node3D = visual.wheels.front_left.pivot
	var authored_forward := front_pivot.global_basis.z.normalized()
	print("STEERING_VISUAL_PHYSICS_AXES ",JSON.stringify({"authored_visual_forward":authored_forward,
		"positive_steer_rad":0.3,"expected_direction":"vehicle left (-X), positive chassis yaw"}))
	visual.dispose()
	for scenario in [{"speed":3.0,"steer":1.0},{"speed":8.0,"steer":1.0},
		{"speed":16.0,"steer":1.0},{"speed":28.0,"steer":1.0},
		{"speed":3.0,"steer":-1.0},{"speed":8.0,"steer":-1.0},
		{"speed":16.0,"steer":-1.0},{"speed":28.0,"steer":-1.0}]:
		var speed: float = scenario.speed
		var steer: float = scenario.steer
		var body := Factory.new().spawn_from_descriptor({"vehicle_id":"steer-probe","life_generation":1,
			"profile_id":"city_hatchback","source_clock":1,"active":true,"position_m":Vector3.ZERO,"yaw_rad":0.0}, profile)
		root.add_child(body)
		for tick in 180: await physics_frame
		body.linear_velocity = Vector3(0,0,-speed)
		body.submit_control(1.0,steer,0.0,false,1)
		var initial := body.global_position
		for tick in 120: await physics_frame
		var snapshot: Dictionary = body.snapshot_state()
		if body.global_rotation.y * steer < 0.05 or (body.global_position.x - initial.x) * steer > -0.10:
			failures.append("signed steering must follow authored wheel: speed=" + str(speed) + " steer=" + str(steer))
		rows.append({"initial_speed_mps":speed,"input_steer":steer,"displacement_m":body.global_position-initial,
			"yaw_rad":body.global_rotation.y,"yaw_rate_radps":body.angular_velocity.y,
			"steer_rad":snapshot.steering_angle_rad,"velocity_mps":body.linear_velocity,
			"up_dot":body.global_basis.y.dot(Vector3.UP)})
		body.free()
	print("NATIVE_STEERING_RESPONSE ",JSON.stringify({"rows":rows,"passed":failures.is_empty(),"failures":failures,"body_sha":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd")}))
	floor.free()
	quit(0 if failures.is_empty() else 1)
