extends "res://scripts/vehicle_physics/test_vehicle_runover_shape_candidate.gd"
const VariantCar = preload("res://scripts/vehicle_physics/vehicle_runover_tunnel_variant.gd")
var _shape_roles: Array[String] = []
var _vehicle_mass_kg := 0.0

func actual_car_body(world: Node3D, x: float, _onset_target: CollisionObject3D = null) -> RigidBody3D:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan": descriptor = row.duplicate(true); break
	descriptor["vehicle_id"] = "TEST_ONLY_runover_tunnel"; descriptor["life_generation"] = 1; descriptor["source_clock"] = 1
	var car = VariantCar.new()
	check(car.configure(descriptor),"tunnel variant exact source profile")
	car.position = Vector3(x,0,-5); car.rotation.y = PI; world.add_child(car)
	_candidate_shape_count = car.get_shape_owners().size()
	check(_candidate_shape_count == 7 and car._wheel_rays.size() == 4,"tunnel variant seven shapes + four support rays")
	_vehicle_mass_kg = car.mass
	check(is_equal_approx(_vehicle_mass_kg,car.profile.mass_kg),"tunnel variant retains exact source mass")
	_shape_roles.clear()
	for child: Node in car.get_children():
		if child is CollisionShape3D: _shape_roles.append(child.name)
	check(_shape_roles.size() == 7 and _shape_roles.has("NativeVehicleCollision") and _shape_roles.has("NativeChassisSillLeft") and _shape_roles.has("NativeChassisSillRight"),"explicit chassis and sill shape roles")
	check(car.submit_control(.55,0,0,false,1),"tunnel variant powered native throttle")
	car.linear_velocity = Vector3(0,0,4.5)
	return car

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"visual_manifest.json"))
	check(manifest.entries.size() == 3,"three actual cached resident rigs")
	VariantCar.measured_npc_wheel_contacts = 0
	VariantCar.measured_npc_chassis_contacts = 0
	VariantCar.measured_npc_sill_contacts = 0
	for entry: Dictionary in manifest.entries:
		var prior_wheel_contacts: int = VariantCar.measured_npc_wheel_contacts
		var prior_chassis_contacts: int = VariantCar.measured_npc_chassis_contacts
		var prior_sill_contacts: int = VariantCar.measured_npc_sill_contacts
		await physical_scenario(entry,true)
		check(not rows.is_empty(),"physical scenario row "+entry.bridge_id)
		if not rows.is_empty():
			rows[-1]["measured_candidate_wheel_contacts"] = VariantCar.measured_npc_wheel_contacts - prior_wheel_contacts
			rows[-1]["measured_candidate_chassis_contacts"] = VariantCar.measured_npc_chassis_contacts - prior_chassis_contacts
			rows[-1]["measured_candidate_sill_contacts"] = VariantCar.measured_npc_sill_contacts - prior_sill_contacts
			rows[-1]["fixture_nonzero_shape_contacts_include_sills"] = true
			rows[-1]["wheel_collision_proved"] = rows[-1]["measured_candidate_wheel_contacts"] > 0
			check(rows[-1]["wheel_collision_proved"],"actual wheel sphere contact by shape owner "+entry.bridge_id)
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"rows":rows,"measured_npc_wheel_contacts":VariantCar.measured_npc_wheel_contacts,"measured_npc_chassis_contacts":VariantCar.measured_npc_chassis_contacts,"measured_npc_sill_contacts":VariantCar.measured_npc_sill_contacts,"vehicle_mass_kg":_vehicle_mass_kg,"shape_count":_candidate_shape_count,"shape_roles":_shape_roles,"compound_body_sweep":true,"candidate_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_runover_tunnel_variant.gd"),"vehicle_body_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),"gpu_used":false,"authority":"TEST_ONLY physics geometry candidate"}
	DirAccess.make_dir_recursive_absolute("../../outputs/vehicle_runover_tunnel_variant")
	var file := FileAccess.open("../../outputs/vehicle_runover_tunnel_variant/RESULT.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("VEHICLE_RUNOVER_TUNNEL ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
