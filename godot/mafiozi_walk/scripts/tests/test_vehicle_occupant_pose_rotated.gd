extends SceneTree
const Pose = preload("res://scripts/vehicle_visual/vehicle_occupant_pose.gd")
var checks := 0
var failures: Array[String] = []
var reports: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func bones_in_vehicle(player: CharacterBody3D, car: RigidBody3D) -> Dictionary:
	var rig: Skeleton3D = player._pose_skeleton
	var frame := car.global_transform.affine_inverse() * rig.global_transform
	var result: Dictionary = {}
	for i in rig.get_bone_count(): result[rig.get_bone_name(i)] = frame * rig.get_bone_global_pose(i)
	return result
func position(rig: Skeleton3D, name: String) -> Vector3:
	return (rig.global_transform * rig.get_bone_global_pose(rig.find_bone(name))).origin
func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	main.set_physics_process(false); main.set_process(false)
	var transport: Node3D = main.preview_transport
	check(is_instance_valid(transport) and transport.ready_for_play, "actual main transport ready")
	if not is_instance_valid(transport) or not transport.ready_for_play: main.free(); quit(1); return
	var player: CharacterBody3D = main._player; player.set_physics_process(false)
	transport.set_physics_process(false); transport.set_process(false)
	var car: RigidBody3D = transport.body; car.freeze = true
	var rig: Skeleton3D = player._pose_skeleton
	var reference: Dictionary = {}
	var maximum_position := 0.0; var maximum_basis := 0.0
	# Real imported source wheel/doors and existing transport pose_writer.
	for state: Dictionary in [{"fold": 1.0, "progress": 1.0, "phase": "SEATED"}, {"fold": .72, "progress": .61, "hand_reach": .65, "duck": .5, "inner_leg": 1.0, "outer_leg": .44, "reach": .52, "door": 1.0}]:
		for i in range(3):
			var car_frame := Transform3D.IDENTITY
			if i == 1: car_frame = Transform3D(Basis.from_euler(Vector3(.23, .71, -.34)), Vector3(101, 4, -23))
			if i == 2: car_frame = Transform3D(Basis.from_euler(Vector3(-.49, -1.47, .57)), Vector3(-53, 2, 83))
			car.global_transform = car_frame
			player.global_transform = Transform3D(car_frame.basis, transport._seat_position("front_left"))
			player._visual.basis = Basis(Vector3.UP, PI)
			transport._occupant_pose.reset(player._pose_epoch)
			transport.visual.set_door_amount("front_left", float(state.get("door", 0.0)))
			transport._apply_transport_pose(state, "front_left", car, transport.visual)
			check(transport.error != "occupant_pose_rejected", "actual rotated writer produces a pose")
			var actual := bones_in_vehicle(player, car)
			if i == 0: reference = actual; continue
			for name: String in actual:
				var delta: float = actual[name].origin.distance_to(reference[name].origin)
				maximum_position = maxf(maximum_position, delta)
				var basis_error: float = maxf(actual[name].basis.x.distance_to(reference[name].basis.x), maxf(actual[name].basis.y.distance_to(reference[name].basis.y), actual[name].basis.z.distance_to(reference[name].basis.z)))
				maximum_basis = maxf(maximum_basis, basis_error)
				check(delta < .0003 and basis_error < .0005, "6DOF actual writer covariance " + name)
	# Independent sampler seam diagnostic with the SAME actual wheel world points.
	var component := Pose.new()
	check(component.configure(rig, player._pose_motion, player._locomotion._rest_poses, player._model_scale), "independent actual rig configured")
	var seat: Dictionary = transport.runtime.catalog.seat(car.get_meta("profile_id"), "front_left")
	var profile: Dictionary = transport.runtime.catalog.profile(car.get_meta("profile_id"))
	var actual_seat := {"id": "front_left", "side": seat.source_side, "can_drive": true, "recline": profile.cabin_derivation.seat_recline_rad}
	var wheel: Node3D = transport.visual.nodes[transport.visual.entry.controls.steering_wheel]
	var seam: Dictionary = {}
	for continuous: bool in [false, true]:
		var before := Vector3.ZERO
		for fold: float in [.8799, .8801]:
			component.reset(100)
			var options := {"fold": fold, "dt": 0.0, "steering_left": wheel.to_global(Vector3(.16 * cos(PI / 6), .08, -.023)), "steering_right": wheel.to_global(Vector3(-.16 * cos(PI / 6), .08, -.023))}
			if continuous: options.gripBlend = smoothstep(.62, 1.0, fold)
			var selected: Dictionary = component.sample(actual_seat, options, null, 100)
			check(component.apply(selected), "seam pose applied")
			var palm := position(rig, "socket_hand_l")
			if fold < .88: before = palm
			else: seam["continuous_metres" if continuous else "default_threshold_metres"] = palm.distance_to(before)
	check(seam.continuous_metres < seam.default_threshold_metres * .1, "explicit source continuous gripBlend removes hard .88 palm jump")
	reports.append({"maximum_vehicle_local_bone_metres": maximum_position, "maximum_basis_error": maximum_basis, "wheel_threshold_seam": seam, "profile": car.get_meta("profile_id"), "scope": "actual main pose_writer, actual source imported wheel and door, arbitrary vehicle yaw/pitch/roll and translation; no live GPU"})
	component.dispose(); main.free()
	print(JSON.stringify({"checks": checks, "failures": failures, "reports": reports}))
	quit(0 if failures.is_empty() else 1)
func _initialize() -> void: run.call_deferred()
