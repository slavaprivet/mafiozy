extends SceneTree
## TEST_ONLY bounded physical regression for the compact-sedan visual shape.
## This verifies finite, bounded behavior on a simple floor, curbs and peers;
## it does not establish city-wide handling, visual quality or exact realism.

const Candidate = preload("res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd")
const MeshCandidate = preload("res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd")
const Production = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
const CURB_TICKS := 240
const PEER_TICKS := 220

var errors: Array[String] = []
var rows: Array[Dictionary] = []
var descriptor: Dictionary

func _initialize() -> void:
	call_deferred("run")

func step() -> void:
	await physics_frame
	await process_frame

func make_world() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.name = "FlatFloor"
	floor.position.y = -0.1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000.0, 0.2, 1000.0)
	collision.shape = box
	floor.add_child(collision)
	world.add_child(floor)
	return world

func make_car(world: Node3D, candidate: bool, label: String, z: float, yaw: float) -> RigidBody3D:
	var mesh := OS.get_cmdline_user_args().has("--mesh")
	var car: RigidBody3D = (MeshCandidate.new() if mesh else Candidate.new()) if candidate else Production.new()
	var own_descriptor := descriptor.duplicate(true)
	own_descriptor["vehicle_id"] = "TEST_ONLY_" + label
	if not car.configure(own_descriptor): errors.append(label + " descriptor rejected")
	car.position = Vector3(0.0, 0.0, z)
	car.rotation.y = yaw
	world.add_child(car)
	return car

func settle() -> void:
	for tick in 80: await step()

func check_finite(car: RigidBody3D, label: String) -> void:
	if not car.global_position.is_finite() or not car.linear_velocity.is_finite() or not car.angular_velocity.is_finite():
		errors.append(label + " non-finite state")
	if car.linear_velocity.length() > 40.0 or car.angular_velocity.length() > 20.0:
		errors.append(label + " explosive velocity")
	if car.global_position.y < -0.5 or car.global_position.y > 3.0:
		errors.append(label + " lost floor support")

func run_curb(height: float) -> void:
	var world := make_world()
	var car := make_car(world, true, "curb_" + str(height), -5.0, PI)
	var curb := StaticBody3D.new()
	curb.name = "Curb"
	curb.position = Vector3(0.0, height * 0.5, 3.0)
	var curb_collision := CollisionShape3D.new()
	var curb_box := BoxShape3D.new()
	curb_box.size = Vector3(4.0, height, 0.45)
	curb_collision.shape = curb_box
	curb.add_child(curb_collision)
	world.add_child(curb)
	await settle()
	var grounded_start: int = car.snapshot_state().grounded_wheel_mask
	var open_sweep: Dictionary = car.body_sweep(car.global_transform.translated(Vector3(0, 0, 1)))
	var curb_sweep: Dictionary = car.body_sweep(car.global_transform.translated(Vector3(0, 0, 9)))
	var max_speed := 0.0
	var min_y := INF
	var max_y := -INF
	var max_z := -INF
	var max_step_m := 0.0
	var previous_position := car.global_position
	var max_curb_contact := 0
	car.submit_control(0.48, 0.0, 0.0, false, 1)
	for tick in CURB_TICKS:
		await step()
		check_finite(car, "curb " + str(height))
		max_speed = maxf(max_speed, car.linear_velocity.length())
		min_y = minf(min_y, car.global_position.y)
		max_y = maxf(max_y, car.global_position.y)
		max_z = maxf(max_z, car.global_position.z)
		max_step_m = maxf(max_step_m, car.global_position.distance_to(previous_position))
		previous_position = car.global_position
		for body in car.get_colliding_bodies():
			if body == curb: max_curb_contact += 1
	var row := {"kind":"curb","height_m":height,"grounded_start":grounded_start,
		"open_sweep":open_sweep,"curb_sweep":curb_sweep,
		"max_speed_mps":max_speed,"min_root_y":min_y,"max_root_y":max_y,
		"max_z":max_z,"max_step_m":max_step_m,"curb_contact_ticks":max_curb_contact}
	rows.append(row)
	if grounded_start != 15: errors.append("curb start unsupported: " + str(row))
	if not open_sweep.get("valid", false) or open_sweep.get("safe_fraction", 0.0) < 0.99:
		errors.append("curb open sweep blocked: " + str(row))
	if not curb_sweep.get("valid", false) or curb_sweep.get("safe_fraction", 1.0) >= 0.99:
		errors.append("curb sweep missed obstacle: " + str(row))
	if max_curb_contact == 0: errors.append("curb physical contact missing: " + str(row))
	# A low curb can legitimately be traversed; a no-contact crossing or a
	# per-tick teleport is the bounded tunnelling signal here.
	if max_step_m > 0.8: errors.append("curb motion jumped discontinuously: " + str(row))
	world.free()
	await process_frame

func run_peer(moving_peer: bool) -> void:
	var world := make_world()
	var car := make_car(world, true, "candidate_peer_" + str(moving_peer), -6.0, PI)
	var peer := make_car(world, false, "production_peer_" + str(moving_peer), 6.0, 0.0)
	await settle()
	var grounded_start := [car.snapshot_state().grounded_wheel_mask, peer.snapshot_state().grounded_wheel_mask]
	var car_sweep: Dictionary = car.body_sweep(car.global_transform.translated(Vector3(0, 0, 11)))
	if not moving_peer:
		peer.freeze = true
	car.linear_velocity = Vector3(0, 0, 4.0)
	if moving_peer: peer.linear_velocity = Vector3(0, 0, -3.0)
	var contact_ticks := 0
	var min_gap := INF
	var max_car_speed := 0.0
	var max_peer_speed := 0.0
	var final_gap := 0.0
	for tick in PEER_TICKS:
		await step()
		check_finite(car, "candidate peer")
		check_finite(peer, "production peer")
		var gap: float = peer.global_position.z - car.global_position.z
		min_gap = minf(min_gap, gap)
		final_gap = gap
		max_car_speed = maxf(max_car_speed, car.linear_velocity.length())
		max_peer_speed = maxf(max_peer_speed, peer.linear_velocity.length())
		if car.get_colliding_bodies().has(peer): contact_ticks += 1
	var row := {"kind":"peer","moving_peer":moving_peer,"grounded_start":grounded_start,
		"sweep":car_sweep,"contact_ticks":contact_ticks,"min_center_gap_z":min_gap,
		"final_gap_z":final_gap,"max_candidate_speed_mps":max_car_speed,
		"max_peer_speed_mps":max_peer_speed}
	rows.append(row)
	if grounded_start != [15, 15]: errors.append("peer starts unsupported: " + str(row))
	if not car_sweep.get("valid", false) or car_sweep.get("safe_fraction", 1.0) >= 0.99:
		errors.append("peer sweep missed obstacle: " + str(row))
	if contact_ticks == 0: errors.append("peer physical contact missing: " + str(row))
	if min_gap < 1.5: errors.append("peer may tunnel/interpenetrate: " + str(row))
	world.free()
	await process_frame

func run() -> void:
	var mesh := OS.get_cmdline_user_args().has("--mesh")
	var candidate_path := "res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd" if mesh else "res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd"
	var output_dir := "../../outputs/vehicle_runover_mesh_envelope_variant" if mesh else "../../outputs/vehicle_runover_sedan_visual_variant"
	var profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	for row: Dictionary in profiles.get("profiles", []):
		if row.get("profile_id") == "compact_sedan": descriptor = row.duplicate(true); break
	if descriptor.is_empty():
		print("VEHICLE_CURB_PEER FAIL no compact_sedan profile")
		quit(1)
		return
	descriptor["life_generation"] = 1
	descriptor["source_clock"] = 1
	for height in [0.08, 0.2]: await run_curb(height)
	for moving in [false, true]: await run_peer(moving)
	var report := {"test_only":true,"gpu_fps_verified":false,"exact_realism_verified":false,
		"candidate_sha256":FileAccess.get_sha256(candidate_path),
		"production_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),
		"rows":rows,"errors":errors}
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir + "/CURB_PEER_RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEHICLE_CURB_PEER ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
