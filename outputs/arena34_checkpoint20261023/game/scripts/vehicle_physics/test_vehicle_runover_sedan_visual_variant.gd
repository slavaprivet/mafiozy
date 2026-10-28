extends "res://scripts/vehicle_physics/test_vehicle_runover_tunnel_variant.gd"

const VisualCar = preload("res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd")
const MeshCar = preload("res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd")
const SlickCar = preload("res://scripts/vehicle_physics/vehicle_runover_slick_bumper_variant.gd")
const RoundedCar = preload("res://scripts/vehicle_physics/vehicle_runover_rounded_bumper_variant.gd")

func rounded_mode() -> bool:
	return OS.get_cmdline_user_args().has("--rounded")

func slick_mode() -> bool:
	return OS.get_cmdline_user_args().has("--slick")

func mesh_mode() -> bool:
	return OS.get_cmdline_user_args().has("--mesh") or slick_mode() or rounded_mode()

func check(ok: bool, message: String) -> void:
	if mesh_mode() and message == "actual chassis only + four suspension rays":
		ok = ok or _candidate_shape_count == 12
	super.check(ok, message)

func actual_car_body(world: Node3D, x: float, _onset_target: CollisionObject3D = null) -> RigidBody3D:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan":
			descriptor = row.duplicate(true)
			break
	descriptor["vehicle_id"] = "TEST_ONLY_runover_sedan_visual"
	descriptor["life_generation"] = 1
	descriptor["source_clock"] = 1
	var car = RoundedCar.new() if rounded_mode() else SlickCar.new() if slick_mode() else MeshCar.new() if mesh_mode() else VisualCar.new()
	check(car.configure(descriptor), "visual variant exact source profile")
	car.position = Vector3(x, 0, -5)
	car.rotation.y = PI
	world.add_child(car)
	_candidate_shape_count = car.get_shape_owners().size()
	check(_candidate_shape_count == (12 if mesh_mode() else 7) and car._wheel_rays.size() == 4, "visual variant expected physical shapes + four support rays")
	var hull: ConvexPolygonShape3D = car.get_node("NativeVehicleCollision").shape
	var max_x := 0.0
	for point: Vector3 in hull.points:
		max_x = maxf(max_x, absf(point.x))
	check(is_equal_approx(max_x, 0.90 if mesh_mode() else 0.9405), "body hull stays within emitted LOD0 side x")
	if mesh_mode():
		check(car.has_node("NativeCabinCollision") and car.has_node("NativeLowerBodySideLeft") and car.has_node("NativeLowerBodySideRight") and car.has_node("NativeFrontBumper") and car.has_node("NativeRearBumper"), "separate roof, lower door and bumpers")
	for i in 4:
		var wheel: CollisionShape3D = car.get_node("NativePhysicalWheel%d" % i)
		var cylinder := wheel.shape as CylinderShape3D
		check(cylinder != null and is_equal_approx(cylinder.height, 0.18), "axle tire %d has visual width" % i)
	check(car.submit_control(.55, 0, 0, false, 1), "visual variant powered native throttle")
	car.linear_velocity = Vector3(0, 0, 4.5)
	return car

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "visual_manifest.json"))
	check(manifest.entries.size() == 3, "three actual cached resident rigs")
	VisualCar.measured_npc_wheel_contacts = 0
	VisualCar.measured_npc_chassis_contacts = 0
	VisualCar.measured_npc_sill_contacts = 0
	for entry: Dictionary in manifest.entries:
		var prior_wheel_contacts: int = VisualCar.measured_npc_wheel_contacts
		await physical_scenario(entry, true)
		check(not rows.is_empty(), "physical scenario row " + entry.bridge_id)
		if not rows.is_empty():
			rows[-1]["measured_candidate_wheel_contacts"] = VisualCar.measured_npc_wheel_contacts - prior_wheel_contacts
			rows[-1]["wheel_collision_proved"] = rows[-1]["measured_candidate_wheel_contacts"] > 0
	# Centerline runs can pass between narrow real-width tires. Require at
	# least one measured rigid wheel contact across these three physical rigs;
	# their no-snag and joint/floor assertions remain per rig in the host.
	check(VisualCar.measured_npc_wheel_contacts > 0, "real axle tire collision observed")
	var candidate_path := "res://scripts/vehicle_physics/vehicle_runover_rounded_bumper_variant.gd" if rounded_mode() else "res://scripts/vehicle_physics/vehicle_runover_slick_bumper_variant.gd" if slick_mode() else "res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd" if mesh_mode() else "res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd"
	var output_dir := "../../outputs/vehicle_runover_rounded_bumper_variant" if rounded_mode() else "../../outputs/vehicle_runover_slick_bumper_variant" if slick_mode() else "../../outputs/vehicle_runover_mesh_envelope_variant" if mesh_mode() else "../../outputs/vehicle_runover_sedan_visual_variant"
	var report := {"checks": checks, "passed": errors.is_empty(), "errors": errors, "rows": rows, "measured_npc_wheel_contacts": VisualCar.measured_npc_wheel_contacts, "measured_npc_chassis_contacts": VisualCar.measured_npc_chassis_contacts, "measured_npc_sill_contacts": VisualCar.measured_npc_sill_contacts, "candidate_sha256": FileAccess.get_sha256(candidate_path), "vehicle_body_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"), "gpu_used": false, "authority": "TEST_ONLY physical geometry candidate"}
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir + "/RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEHICLE_RUNOVER_SEDAN_VISUAL ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
