extends SceneTree

const Receipt = preload("res://scripts/vehicle_physics/vehicle_npc_contact_receipt.gd")

class ProbeVehicle extends NativeVehicleBody:
	var npc: CollisionObject3D
	var receipts: Array[Dictionary] = []
	var receipt_sample_us := 0.0
	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super._integrate_forces(state)
		if npc == null:
			return
		for i in state.get_contact_count():
			var row: Dictionary = Receipt.observe(state, self, i, npc)
			if row.valid:
				receipts.append(row)
				if receipt_sample_us == 0.0:
					var start := Time.get_ticks_usec()
					for sample in 500:
						Receipt.observe(state, self, i, npc)
					receipt_sample_us = float(Time.get_ticks_usec() - start) / 500.0

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func run() -> void:
	var root := Node3D.new()
	root.name = "ReceiptTest"
	get_root().add_child(root)
	var car := ProbeVehicle.new()
	check(car.configure({"vehicle_id": "contact-car", "profile_id": "compact_sedan",
		"life_generation": 1, "source_clock": 1}), "profile configured")
	car.gravity_scale = 0.0
	car.position = Vector3(0, 0.7, -4)
	root.add_child(car)
	var npc := RigidBody3D.new()
	npc.name = "NpcPhysicalHost"
	npc.mass = 80.0
	npc.gravity_scale = 0.0
	npc.position = Vector3(0, 0.7, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.4, 0.6)
	shape.shape = box
	npc.add_child(shape)
	root.add_child(npc)
	car.npc = npc
	check(car.get_shape_owners().size() == 1, "one chassis collision shape")
	check(car.get_children().filter(func(c: Node): return c is RayCast3D).size() == 4,
		"four suspension rays are not shapes")
	car.linear_velocity = Vector3(0, 0, 12)
	for i in 60:
		await physics_frame
		if not car.receipts.is_empty():
			break
	check(not car.receipts.is_empty(), "actual direct-state NPC contact")
	if not car.receipts.is_empty():
		var row := car.receipts[0]
		check(row.collision_part == "chassis" and not row.wheel_collision_proved,
			"shape-proven chassis only")
		check(row.vehicle_mass_kg == car.mass and row.npc_mass_kg == npc.mass,
			"actual body masses")
		check(row.point_on_vehicle_world_m.is_finite() and row.normal_on_vehicle_world.is_finite()
			and row.vehicle_speed_mps > 0.0, "finite point normal speed")
		check(row.measured_npc_delta_v_available and row.bounded_npc_delta_v_mps.length() <= 20.0001,
			"bounded measured delta V")
		check(row.already_solved_by_godot and not row.apply_again and not row.authority,
			"no duplicate impulse or authority")
	check(not Receipt.observe(null, car, 0, npc).valid, "missing state rejected")
	print("VEHICLE_NPC_CONTACT_RECEIPT checks=%d failures=%d receipts=%d sample_mean_us=%.3f" % [checks, failures.size(), car.receipts.size(), car.receipt_sample_us])
	for failure in failures:
		push_error(failure)
	root.queue_free()
	quit(0 if failures.is_empty() else 1)
