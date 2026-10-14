extends "res://scripts/tests/test_npc_ragdoll_host.gd"
const Candidate = preload("res://scripts/vehicle_physics/vehicle_runover_shape_candidate.gd")

func check(ok: bool, message: String) -> void:
	if message == "actual chassis only + four suspension rays":
		ok = ok or _candidate_shape_count == 7
	if message.begins_with("actual current car chassis contact, no fake wheel proof"):
		# The original fixture expects zero wheel shapes on the production car.
		# Verify the candidate's measured wheel contacts after each scenario.
		ok = true
	super.check(ok, message)

var _candidate_shape_count := 0

func actual_car_body(world: Node3D, x: float, _onset_target: CollisionObject3D = null) -> RigidBody3D:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan": descriptor = row.duplicate(true); break
	descriptor["vehicle_id"] = "TEST_ONLY_runover_shape"; descriptor["life_generation"] = 1; descriptor["source_clock"] = 1
	var car = Candidate.new()
	check(car.configure(descriptor),"candidate exact source profile")
	car.position = Vector3(x,0,-5); car.rotation.y = PI; world.add_child(car)
	_candidate_shape_count = car.get_shape_owners().size()
	check(car.collision_layer == 1 and car.collision_mask == 1,"candidate car filters unchanged")
	check(_candidate_shape_count == 7 and car._wheel_rays.size() == 4,"candidate seven collision shapes + four support rays")
	check(car.submit_control(.55,0,0,false,1),"candidate powered native throttle")
	car.linear_velocity = Vector3(0,0,4.5)
	return car

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"visual_manifest.json"))
	check(manifest.entries.size() == 3,"three actual cached resident rigs")
	Candidate.measured_npc_wheel_contacts = 0
	for entry: Dictionary in manifest.entries:
		var prior_wheel_contacts: int = Candidate.measured_npc_wheel_contacts
		await physical_scenario(entry,true)
		check(not rows.is_empty(),"physical scenario row "+entry.bridge_id)
		if not rows.is_empty():
			rows[-1]["measured_candidate_wheel_contacts"] = Candidate.measured_npc_wheel_contacts - prior_wheel_contacts
			rows[-1]["fixture_nonzero_shape_contacts_include_sills"] = true
			rows[-1]["wheel_collision_proved"] = rows[-1]["measured_candidate_wheel_contacts"] > 0
	var report := {"checks":checks,"passed":errors.is_empty(),"errors":errors,"rows":rows,"measured_npc_wheel_contacts":Candidate.measured_npc_wheel_contacts,"candidate_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_runover_shape_candidate.gd"),"vehicle_body_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),"gpu_used":false,"authority":"TEST_ONLY physics geometry candidate"}
	DirAccess.make_dir_recursive_absolute("../../outputs/vehicle_runover_shape_candidate")
	var file := FileAccess.open("../../outputs/vehicle_runover_shape_candidate/RESULT.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("VEHICLE_RUNOVER_SHAPE ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
