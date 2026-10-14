extends SceneTree
const Lease = preload("res://diagnostic/vehicle_pause_lease.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true
	scene.preview_resident_walk_enabled = false
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and not scene.preview_ready:
		await physics_frame
	if not scene.preview_ready:
		printerr("VEHICLE_LEASE_ACTUAL_FAIL: preview not ready")
		quit(1); return
	var transport: Node3D = scene.preview_transport
	var lease: Node = Lease.new()
	transport.add_child(lease)
	var receipt: Dictionary = {}
	for i in 900:
		await physics_frame
		receipt = lease.acquire()
		if not receipt.is_empty(): break
	var body: RigidBody3D = transport.body
	var result := {"admitted":not receipt.is_empty(), "speed":body.linear_velocity.length(), "angular":body.angular_velocity.length(), "ground":int(body._grounded_wheel_mask), "contacts":body._contact_buffer.size(), "gap":body._contact_buffer.has_gap(), "parked_brake":transport._parked_brake, "phase":transport.phase, "sample_count":lease._samples.size(), "freeze":body.freeze}
	if receipt.is_empty():
		result["owner_resting"] = lease._owner_resting(body)
		result["stable_window"] = lease._stable_window(body)
		if lease._samples.size() == 31:
			var first: Dictionary = lease._samples[0]
			var last: Dictionary = lease._samples.back()
			result["sample_ticks"] = [first.tick, last.tick, int(body._physics_tick)]
			result["drift"] = (last.transform as Transform3D).origin.distance_to((first.transform as Transform3D).origin)
			result["yaw"] = (first.transform as Transform3D).basis.get_rotation_quaternion().angle_to((last.transform as Transform3D).basis.get_rotation_quaternion())
			result["last_transform_matches"] = last.transform == body.global_transform
			result["last_speed_matches"] = last.linear == body.linear_velocity
			result["owner_method"] = transport.has_method("map_editor_vehicle_acquire")
		print("VEHICLE_LEASE_ACTUAL ", JSON.stringify(result))
		scene.free()
		quit(1); return
	result["verified"] = lease.verify(receipt)
	var original_session: Variant = transport._session.duplicate(true)
	transport._session = {"editor_fault_injection":"changed_session"}
	result["changed_session_rejected"] = not lease.verify(receipt) and not lease.release(receipt) and body.freeze
	transport._session = original_session
	result["released"] = lease.release(receipt)
	result["freeze_after"] = body.freeze
	print("VEHICLE_LEASE_ACTUAL ", JSON.stringify(result))
	scene.free()
	quit(0 if result.verified and result.changed_session_rejected and result.released and not result.freeze_after else 1)
