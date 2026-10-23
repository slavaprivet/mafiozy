extends SceneTree
## Bounded TEST_ONLY headless comparison. Never selects the candidate in production.
## Frame wall includes one isolated physics tick plus engine overhead, not FPS.
## Test-only subclasses separately time the GDScript integrator. Alternating
## cases temper drift; neither measurement is a whole-city/GPU result.

const Production = preload("res://scripts/vehicle_physics/vehicle_shape_cost_production_probe.gd")
const Candidate = preload("res://scripts/vehicle_physics/vehicle_shape_cost_candidate_probe.gd")
const MeshCandidate = preload("res://scripts/vehicle_physics/vehicle_shape_cost_mesh_probe.gd")
const WARMUP_TICKS := 75
const SAMPLE_TICKS := 180

var _descriptor: Dictionary
var _rows: Array[Dictionary] = []
var _errors: Array[String] = []
var _mesh_mode := false

func _initialize() -> void:
	call_deferred("_run")

func _sorted_stat(values: Array[float], quantile: float) -> float:
	if values.is_empty(): return 0.0
	values.sort()
	return values[clampi(int(round((values.size() - 1) * quantile)), 0, values.size() - 1)]

func _find_descriptor() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	if not document is Dictionary: return {}
	for entry in document.get("profiles", []):
		if entry is Dictionary and entry.get("profile_id") == "compact_sedan":
			var found: Dictionary = entry.duplicate(true)
			found["life_generation"] = 1
			found["source_clock"] = 1
			return found
	return {}

func _run_case(candidate: bool, moving: bool, repeat_index: int) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.position.y = -0.1
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(1000.0, 0.2, 1000.0)
	floor_collision.shape = floor_box
	floor.add_child(floor_collision)
	world.add_child(floor)
	var descriptor := _descriptor.duplicate(true)
	descriptor["vehicle_id"] = "TEST_ONLY_%d_%d_%d" % [int(candidate), int(moving), repeat_index]
	var car: RigidBody3D = (MeshCandidate.new() if _mesh_mode else Candidate.new()) if candidate else Production.new()
	if not car.configure(descriptor): _errors.append("profile configure rejected")
	car.position = Vector3(0.0, 0.0, 0.0)
	car.rotation.y = PI
	world.add_child(car)
	for tick in WARMUP_TICKS:
		await physics_frame
		await process_frame
	if moving:
		car.submit_control(0.55, 0.15, 0.0, false, 1)
	else:
		car.submit_control(0.0, 0.0, 1.0, false, 1)
		for tick in 30:
			await physics_frame
			await process_frame
		car.clear_control(2)
	var physical_shapes := 0
	var probes := 0
	for child in car.get_children():
		if child is CollisionShape3D and not child.disabled: physical_shapes += 1
		if child is RayCast3D: probes += 1
	var integrator_us: Array[float] = []
	var frame_us: Array[float] = []
	var contacts: Array[float] = []
	var grounded: Array[float] = []
	var slept := 0
	for tick in SAMPLE_TICKS:
		var start_us := Time.get_ticks_usec()
		await physics_frame
		await process_frame
		frame_us.append(float(Time.get_ticks_usec() - start_us))
		integrator_us.append(float(car.integrator_us))
		contacts.append(float(car.get_colliding_bodies().size()))
		grounded.append(float(car.snapshot_state().grounded_wheel_mask))
		if car.sleeping: slept += 1
	var row := {
		"variant": ("mesh_envelope_candidate" if _mesh_mode else "visual_candidate") if candidate else "production_AE4D",
		"phase": "active" if moving else "resting_idle",
		"repeat": repeat_index,
		"integrator_us_p10": _sorted_stat(integrator_us, 0.1),
		"integrator_us_p50": _sorted_stat(integrator_us, 0.5),
		"integrator_us_p90": _sorted_stat(integrator_us, 0.9),
		"frame_wall_us_p50": _sorted_stat(frame_us, 0.5),
		"frame_wall_us_p90": _sorted_stat(frame_us, 0.9),
		"floor_contact_bodies_p50": _sorted_stat(contacts, 0.5),
		"grounded_mask_p50": _sorted_stat(grounded, 0.5),
		"sleeping_ticks": slept,
		"physical_shapes": physical_shapes,
		"suspension_probes": probes,
		"car_speed_mps_end": car.linear_velocity.length(),
	}
	_rows.append(row)
	if probes != 4: _errors.append("unexpected wheel probe count: " + str(row))
	if moving and _sorted_stat(grounded, 0.5) != 15.0: _errors.append("active car lost ground: " + str(row))
	world.free()
	car = null
	floor = null
	await process_frame

func _run() -> void:
	_mesh_mode = OS.get_cmdline_user_args().has("--mesh")
	_descriptor = _find_descriptor()
	if _descriptor.is_empty():
		print("VEHICLE_SHAPE_COST FAIL missing compact_sedan profile")
		quit(1)
		return
	# ABBA per state; the second pair reverses temporal order.
	for moving in [false, true]:
		for entry in [false, true, true, false]:
			await _run_case(entry, moving, _rows.size())
	var report := {
		"test_only": true,
		"gpu_fps_verified": false,
	"measurement": "Godot isolated frame wall plus test-only GDScript integrator timer; resting car does not remain engine-asleep",
		"production_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"candidate_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd" if _mesh_mode else "res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd"),
		"mesh_mode": _mesh_mode,
		"sample_ticks_each": SAMPLE_TICKS,
		"warmup_ticks_each": WARMUP_TICKS,
		"rows": _rows,
		"errors": _errors,
	}
	var output_dir := "../../outputs/vehicle_runover_mesh_envelope_variant" if _mesh_mode else "../../outputs/vehicle_runover_sedan_visual_variant"
	var path := output_dir + "/SHAPE_COST_RESULT.json"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEHICLE_SHAPE_COST ", JSON.stringify(report))
	quit(0 if _errors.is_empty() else 1)
