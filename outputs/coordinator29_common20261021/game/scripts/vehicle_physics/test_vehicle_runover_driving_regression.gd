extends SceneTree
const BaseCar = preload("res://scripts/vehicle_physics/vehicle_native_body.gd")
const TunnelCar = preload("res://scripts/vehicle_physics/vehicle_runover_tunnel_variant.gd")
const VisualCar = preload("res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd")
const MeshCar = preload("res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd")
var errors: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func step() -> void:
	await physics_frame
	await process_frame

func sample(label: String, base: RigidBody3D, tunnel: RigidBody3D) -> void:
	rows.append({"phase":label,"base_speed_mps":base.linear_velocity.length(),"candidate_speed_mps":tunnel.linear_velocity.length(),"base_forward_mps":base.linear_velocity.z,"candidate_forward_mps":tunnel.linear_velocity.z,"base_yaw":base.rotation.y,"candidate_yaw":tunnel.rotation.y,"base_root_y":base.position.y,"candidate_root_y":tunnel.position.y,"base_grounded_mask":base.snapshot_state().grounded_wheel_mask,"candidate_grounded_mask":tunnel.snapshot_state().grounded_wheel_mask})
	for car in [base,tunnel]:
		if not car.linear_velocity.is_finite() or not car.global_position.is_finite(): errors.append("nonfinite "+label)

func run() -> void:
	var visual := OS.get_cmdline_user_args().has("--visual")
	var mesh := OS.get_cmdline_user_args().has("--mesh")
	var candidate_script = MeshCar if mesh else (VisualCar if visual else TunnelCar)
	var candidate_path := "res://scripts/vehicle_physics/vehicle_runover_mesh_envelope_variant.gd" if mesh else ("res://scripts/vehicle_physics/vehicle_runover_sedan_visual_variant.gd" if visual else "res://scripts/vehicle_physics/vehicle_runover_tunnel_variant.gd")
	var output_dir := "../../outputs/vehicle_runover_mesh_envelope_variant" if mesh else ("../../outputs/vehicle_runover_sedan_visual_variant" if visual else "../../outputs/vehicle_runover_tunnel_variant")
	var world := Node3D.new(); root.add_child(world)
	var floor := StaticBody3D.new(); floor.position.y = -.1
	var floor_shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(1000,.2,1000); floor_shape.shape = box; floor.add_child(floor_shape); world.add_child(floor)
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var descriptor := {}
	for row: Dictionary in profiles.profiles:
		if row.profile_id == "compact_sedan": descriptor = row.duplicate(true); break
	descriptor.life_generation = 1; descriptor.source_clock = 1
	var base := BaseCar.new(); descriptor.vehicle_id = "TEST_ONLY_base"; base.configure(descriptor); base.position = Vector3(-50,0,0); base.rotation.y = PI; world.add_child(base)
	var tunnel = candidate_script.new(); descriptor.vehicle_id = "TEST_ONLY_candidate"; tunnel.configure(descriptor); tunnel.position = Vector3(50,0,0); tunnel.rotation.y = PI; world.add_child(tunnel)
	for i in 60: await step()
	sample("equilibrium",base,tunnel)
	var base_sweep: Dictionary = base.body_sweep(base.global_transform.translated(Vector3(0,0,1)))
	var tunnel_sweep: Dictionary = tunnel.body_sweep(tunnel.global_transform.translated(Vector3(0,0,1)))
	rows[-1]["base_open_sweep"] = base_sweep
	rows[-1]["candidate_open_sweep"] = tunnel_sweep
	if not tunnel_sweep.get("valid",false) or tunnel_sweep.get("safe_fraction",0.0) < 0.99:
		errors.append("compound sweep blocked by resting floor")
	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(2,2,1)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	obstacle.position = Vector3(50,1,4.5)
	world.add_child(obstacle)
	await step()
	var blocked_sweep: Dictionary = tunnel.body_sweep(tunnel.global_transform.translated(Vector3(0,0,4)))
	rows[-1]["candidate_obstacle_sweep"] = blocked_sweep
	if not blocked_sweep.get("valid",false) or blocked_sweep.get("safe_fraction",1.0) >= .99:
		errors.append("compound sweep missed obstacle")
	obstacle.free()
	if base.snapshot_state().grounded_wheel_mask != 15 or tunnel.snapshot_state().grounded_wheel_mask != 15 or absf(base.position.y-tunnel.position.y) > .05:
		errors.append("equilibrium support or root height differs")
	for car in [base,tunnel]: car.submit_control(.55,0,0,false,1)
	for i in 120: await step()
	sample("acceleration",base,tunnel)
	if absf(base.linear_velocity.length()-tunnel.linear_velocity.length()) > .2:
		errors.append("acceleration differs from production")
	for car in [base,tunnel]: car.submit_control(0,0,1,false,2)
	for i in 90: await step()
	sample("braking",base,tunnel)
	if base.linear_velocity.length() > .15 or tunnel.linear_velocity.length() > .15:
		errors.append("braking did not stop both cars")
	for car in [base,tunnel]: car.submit_control(.55,.45,0,false,3)
	for i in 120: await step()
	sample("steering",base,tunnel)
	if absf(base.rotation.y-tunnel.rotation.y) > .05 or absf(base.linear_velocity.length()-tunnel.linear_velocity.length()) > .25:
		errors.append("steering deviated from production")
	var report := {"errors":errors,"rows":rows,"candidate_sha256":FileAccess.get_sha256(candidate_path),"production_sha256":FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_native_body.gd"),"gpu_used":false,"visual_variant":visual,"mesh_variant":mesh}
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir+"/DRIVING_RESULT.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("VEHICLE_RUNOVER_DRIVING ",JSON.stringify(report))
	world.free()
	base = null
	tunnel = null
	floor = null
	await process_frame
	quit(0 if errors.is_empty() else 1)
