extends SceneTree

const Car = preload("res://scripts/vehicle_physics/vehicle_runover_tunnel_variant.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan":
			descriptor = row.duplicate(true)
			break
	descriptor["vehicle_id"] = "TEST_ONLY_sweep"
	descriptor["life_generation"] = 1
	descriptor["source_clock"] = 1
	var car := Car.new()
	if not car.configure(descriptor):
		print("SWEEP_INDEPENDENT configure failed")
		quit(1)
		return
	world.add_child(car)
	var npc := StaticBody3D.new()
	npc.collision_layer = 256
	npc.collision_mask = 1
	npc.position = Vector3(0.0, 1.0, -4.0)
	var body_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	body_shape.shape = box
	npc.add_child(body_shape)
	world.add_child(npc)
	await physics_frame
	var sweep: Dictionary = car.body_sweep(car.global_transform.translated(Vector3(0.0, 0.0, -3.0)))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = car.get_node("NativeVehicleCollision").shape
	query.transform = car.get_node("NativeVehicleCollision").global_transform
	query.motion = Vector3(0.0, 0.0, -3.0)
	query.collision_mask = 257
	query.exclude = [car.get_rid()]
	var all_layers: PackedFloat32Array = world.get_world_3d().direct_space_state.cast_motion(query)
	var report := {"candidate_sweep": sweep, "all_layers_chassis_sweep": all_layers, "car_mask": car.collision_mask, "npc_layer": npc.collision_layer}
	print("SWEEP_INDEPENDENT ", JSON.stringify(report))
	quit(0 if sweep.valid and sweep.safe_fraction < 0.99 and all_layers.size() == 2 and all_layers[0] < 0.99 else 1)
