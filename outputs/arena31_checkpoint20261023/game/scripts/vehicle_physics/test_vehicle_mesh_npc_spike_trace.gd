extends "res://scripts/vehicle_physics/test_vehicle_runover_sedan_visual_variant.gd"
## TEST_ONLY post-step trace for real cached NPC rigs. No damage authority.

const MeshVariant = preload("res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd")
const NoBumperVariant = preload("res://scripts/vehicle_physics/vehicle_mesh_spike_no_bumper_fixture.gd")
const CorrectedInertiaVariant = preload("res://scripts/vehicle_physics/vehicle_mesh_spike_corrected_inertia_fixture.gd")
const Base = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")

var _car: RigidBody3D
var _actor := ""
var _tick_index := 0
var _trace: Array[Dictionary] = []
var _first_inverse_inertia := Vector3.ZERO
var _first_inertia_kgm2 := Vector3.ZERO

func actual_car_body(world: Node3D, x: float, _onset_target: CollisionObject3D = null) -> RigidBody3D:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan": descriptor = row.duplicate(true); break
	descriptor["vehicle_id"] = "TEST_ONLY_spike_trace_" + _actor
	descriptor["life_generation"] = 1
	descriptor["source_clock"] = 1
	var user_args := OS.get_cmdline_user_args()
	var car: RigidBody3D = Base.new() if user_args.has("--production") else (CorrectedInertiaVariant.new() if user_args.has("--corrected-inertia") else (NoBumperVariant.new() if user_args.has("--no-bumper") else MeshVariant.new()))
	check(car.configure(descriptor), "trace car exact compact_sedan profile")
	car.position = Vector3(x, 0, -5)
	car.rotation.y = PI
	world.add_child(car)
	car.submit_control(.55, 0, 0, false, 1)
	car.linear_velocity = Vector3(0, 0, 4.5)
	_car = car
	_tick_index = 0
	return car

func tick() -> void:
	await super.tick()
	if not is_instance_valid(_car) or not _car.is_inside_tree(): return
	var physical_root: Node = _car.get_parent().get_node_or_null("PhysicalCharacterBody")
	if physical_root == null: return
	_tick_index += 1
	var max_speed := 0.0
	var fastest := ""
	var fastest_velocity := Vector3.ZERO
	var npc_energy_j := 0.0
	var car_contacts := 0
	var floor_contacts := 0
	var shape_roles: Dictionary = {}
	var fastest_car_contact := false
	var fastest_floor_contact := false
	var fastest_mass := 0.0
	for node in physical_root.get_children():
		if not node is RigidBody3D: continue
		var body: RigidBody3D = node
		if body.collision_layer == 0: continue
		var speed := body.linear_velocity.length()
		npc_energy_j += 0.5 * body.mass * speed * speed
		var body_car_contact := false
		var body_floor_contact := false
		var direct := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if direct != null:
			for j in direct.get_contact_count():
				var collider = direct.get_contact_collider_object(j)
				if collider == _car:
					body_car_contact = true
					car_contacts += 1
					var shape_index: int = direct.get_contact_collider_shape(j)
					var owner_id: int = _car.shape_find_owner(shape_index)
					var owner = _car.shape_owner_get_owner(owner_id) if owner_id >= 0 else null
					var role: String = owner.name if owner is Node else "unknown_" + str(shape_index)
					shape_roles[role] = int(shape_roles.get(role, 0)) + 1
				elif collider is StaticBody3D:
					body_floor_contact = true
					floor_contacts += 1
		if speed > max_speed:
			max_speed = speed
			fastest = body.name
			fastest_velocity = body.linear_velocity
			fastest_mass = body.mass
			fastest_car_contact = body_car_contact
			fastest_floor_contact = body_floor_contact
	var car_state := PhysicsServer3D.body_get_direct_state(_car.get_rid())
	if car_state != null and _first_inverse_inertia == Vector3.ZERO:
		_first_inverse_inertia = car_state.inverse_inertia
		_first_inertia_kgm2 = Vector3(
			1.0 / maxf(0.000000001, car_state.inverse_inertia.x),
			1.0 / maxf(0.000000001, car_state.inverse_inertia.y),
			1.0 / maxf(0.000000001, car_state.inverse_inertia.z))
	_trace.append({"actor":_actor,"tick":_tick_index,"npc_max_speed_mps":max_speed,
		"npc_fastest_bone":fastest,"fastest_velocity_mps":fastest_velocity,
		"fastest_mass_kg":fastest_mass,"fastest_car_contact":fastest_car_contact,
		"fastest_floor_contact":fastest_floor_contact,"npc_kinetic_energy_j":npc_energy_j,
		"car_speed_mps":_car.linear_velocity.length(),"car_linear_velocity_mps":_car.linear_velocity,
		"car_angular_speed_radps":_car.angular_velocity.length(),
		"car_contacts":car_contacts,"floor_contacts":floor_contacts,"shape_roles":shape_roles})

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "visual_manifest.json"))
	check(manifest.entries.size() == 3, "three actual cached resident rigs")
	var summary: Array[Dictionary] = []
	for entry: Dictionary in manifest.entries:
		_actor = entry.bridge_id
		_car = null
		_first_inverse_inertia = Vector3.ZERO
		_first_inertia_kgm2 = Vector3.ZERO
		var begin := _trace.size()
		await physical_scenario(entry, true)
		var peak := 0.0
		var peak_tick := -1
		var first_20 := -1
		var contact_first := -1
		for i in range(begin, _trace.size()):
			var row: Dictionary = _trace[i]
			if row.npc_max_speed_mps > peak:
				peak = row.npc_max_speed_mps
				peak_tick = row.tick
			if first_20 < 0 and row.npc_max_speed_mps >= 20.0: first_20 = row.tick
			if contact_first < 0 and row.car_contacts > 0: contact_first = row.tick
		summary.append({"actor":_actor,"peak_npc_speed_mps":peak,"peak_tick":peak_tick,
			"first_speed_20_tick":first_20,"first_car_contact_tick":contact_first,
			"inverse_inertia":_first_inverse_inertia,"inertia_kgm2":_first_inertia_kgm2,
			"sample_count":_trace.size()-begin})
		_car = null
	var production_mode := OS.get_cmdline_user_args().has("--production")
	var no_bumper_mode := OS.get_cmdline_user_args().has("--no-bumper")
	var corrected_inertia_mode := OS.get_cmdline_user_args().has("--corrected-inertia")
	var report := {"test_only":true,"production_mode":production_mode,"no_bumper_mode":no_bumper_mode,"corrected_inertia_mode":corrected_inertia_mode,"summary":summary,
		"trace":_trace,"fixture_rows":rows,"fixture_errors":errors,
		"source_candidate_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd"),
		"source_production_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"gpu_fps_verified":false}
	var output_dir := "../../outputs/vehicle_runover_mesh_spike_trace"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var suffix := "PRODUCTION" if production_mode else ("CORRECTED_INERTIA" if corrected_inertia_mode else ("NO_BUMPER" if no_bumper_mode else "MESH"))
	var file := FileAccess.open(output_dir + "/" + suffix + "_RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEHICLE_SPIKE_TRACE ", JSON.stringify({"production_mode":production_mode,"no_bumper_mode":no_bumper_mode,"corrected_inertia_mode":corrected_inertia_mode,"summary":summary,"fixture_errors":errors,"trace_rows":_trace.size()}))
	quit(0 if errors.is_empty() else 1)
