extends SceneTree

const Receipt = preload("res://scripts/vehicle_physics/vehicle_npc_contact_receipt.gd")

class ProbeVehicle extends NativeVehicleBody:
	var npc: CollisionObject3D
	var other_vehicle: RigidBody3D
	var observed: Dictionary = {}
	var cross_body: Dictionary = {}
	var contact_impulses: Array[Vector3] = []
	var index := -1
	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		super._integrate_forces(state)
		if npc == null:
			return
		for i in state.get_contact_count():
			if state.get_contact_collider_object(i) == npc:
				contact_impulses.append(state.get_contact_impulse(i))
				if observed.is_empty():
					index = i
					observed = Receipt.observe(state, self, i, npc)
					if other_vehicle != null:
						cross_body = Receipt.observe(state, other_vehicle, i, npc)
				break

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
	get_root().add_child(root)
	var car := ProbeVehicle.new()
	car.configure({"vehicle_id": "independent-car", "profile_id": "compact_sedan",
		"life_generation": 1, "source_clock": 1})
	car.gravity_scale = 0.0
	car.position = Vector3(0, 0.7, -4)
	root.add_child(car)
	var decoy := ProbeVehicle.new()
	decoy.configure({"vehicle_id": "independent-decoy", "profile_id": "compact_sedan",
		"life_generation": 1, "source_clock": 1})
	decoy.gravity_scale = 0.0
	decoy.collision_layer = 0
	decoy.collision_mask = 0
	decoy.position = Vector3(100, 0.7, 0)
	root.add_child(decoy)
	var npc := RigidBody3D.new()
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
	car.other_vehicle = decoy
	car.linear_velocity = Vector3(0, 0, 12)
	for frame in 60:
		await physics_frame
		if not car.observed.is_empty() and car.contact_impulses.size() >= 3:
			break
	check(not car.observed.is_empty(), "real contact observed")
	if not car.observed.is_empty():
		check(car.observed.valid, "real body accepted")
		check(not car.cross_body.valid, "different vehicle cannot borrow direct state")
		check(car.observed.vehicle_runtime_id == car.get_instance_id(), "self identity")
		check(car.observed.point_on_vehicle_world_m.distance_to(car.global_position) < 3.0,
			"world contact point near real vehicle")
		check(car.observed.normal_on_vehicle_world.length() > 0.999,
			"unit contact normal")
		check(not car.observed.apply_again and car.observed.already_solved_by_godot,
			"no secondary impulse")
		print("INDEPENDENT_DETAIL true_j=%s cross_valid=%s cross_vehicle_runtime_id=%s real_runtime_id=%s" % [
			str(car.observed.impulse_on_vehicle_ns), str(car.cross_body.valid),
			str(car.cross_body.get("vehicle_runtime_id", -1)), str(car.get_instance_id())])
		print("INDEPENDENT_IMPULSES %s npc_velocity=%s" % [str(car.contact_impulses), str(npc.linear_velocity)])
	print("VEHICLE_NPC_CONTACT_RECEIPT_INDEPENDENT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	root.queue_free()
	quit(0 if failures.is_empty() else 1)
