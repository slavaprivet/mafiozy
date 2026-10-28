extends SceneTree
## Headless source-ground alignment proof for one actual exported Walk vehicle.
## This is geometry/physics evidence only; it does not exercise rendering or LIVE.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Visual = preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const VISUAL_MANIFEST := "res://assets/vehicle_visual/manifest.json"
const PROFILE_ID := "compact_sedan"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _vector3(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.x), float(value.y), float(value.z))
	return Vector3(NAN, NAN, NAN)

func _profile(document: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in document.get("profiles", []):
		if str(row.get("profile_id", "")) == id:
			return row
	return {}

func _visual_bounds(visual_root: Node3D, frame_inverse: Transform3D) -> AABB:
	var first := true
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	var stack: Array[Node] = [visual_root]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		for child: Node in node.get_children():
			stack.append(child)
		if not node is MeshInstance3D or not (node as MeshInstance3D).visible:
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var bounds := mesh_node.mesh.get_aabb()
		var transform := frame_inverse * mesh_node.global_transform
		for corner in 8:
			var local := bounds.position + Vector3(
				bounds.size.x if (corner & 1) != 0 else 0.0,
				bounds.size.y if (corner & 2) != 0 else 0.0,
				bounds.size.z if (corner & 4) != 0 else 0.0)
			var point := transform * local
			if first:
				minimum = point
				maximum = point
				first = false
			else:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum) if not first else AABB()

func _run() -> void:
	var descriptors: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(descriptors is Dictionary, "descriptor document parses")
	var descriptor := _profile(descriptors as Dictionary, PROFILE_ID) if descriptors is Dictionary else {}
	_check(not descriptor.is_empty(), "compact sedan descriptor exists")
	var catalogue := Visual.load_catalogue(VISUAL_MANIFEST)
	_check(catalogue.get("ok", false), "actual visual catalogue loads")
	if descriptor.is_empty() or not catalogue.get("ok", false):
		_finish({})
		return
	var entry: Dictionary = catalogue.entries.get(PROFILE_ID, {})
	var visual_result := Visual.instantiate_visual(entry, catalogue.base_path)
	_check(visual_result.get("ok", false), "actual compact sedan visual imports")
	if not visual_result.get("ok", false):
		_finish({"visual_error": visual_result.get("error", "unknown")})
		return
	var factory := Factory.new()
	var body := factory.spawn_from_descriptor({"vehicle_id":"alignment-compact", "life_generation":1,
		"profile_id":PROFILE_ID, "active":true, "position_m":Vector3.ZERO,
		"yaw_rad":0.0, "source_clock":1}, descriptor)
	_check(body != null, "native body accepts current descriptor")
	if body == null:
		visual_result.visual.dispose()
		_finish({"physics_error": factory.last_error})
		return
	var visual: RefCounted = visual_result.visual
	body.add_child(visual.root)
	_check(body.position == Vector3.ZERO and visual.root.transform.is_equal_approx(Transform3D.IDENTITY), "source-ground spawn and visual use no hidden offset or scale")
	var floor := StaticBody3D.new()
	floor.set_meta("vehicle_surface_id", "alignment_floor")
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30.0, 0.5, 30.0)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(0.0, -0.25, 0.0)
	floor.add_child(floor_collision)
	root.add_child(floor)
	root.add_child(body)
	await process_frame
	var initial_bounds := _visual_bounds(visual.root, body.global_transform.affine_inverse())
	var source_bounds: Dictionary = descriptor.runtime_visual_bounds_source_m
	var source_min_raw := _vector3(source_bounds.min)
	var source_max_raw := _vector3(source_bounds.max)
	# Exported Walk geometry is converted from source +Z forward to Godot -Z.
	var source_min := Vector3(source_min_raw.x, source_min_raw.y, -source_max_raw.z)
	var source_max := Vector3(source_max_raw.x, source_max_raw.y, -source_min_raw.z)
	_check(initial_bounds.position.distance_to(source_min) < 0.002, "actual imported visual minimum matches source runtime bounds")
	_check((initial_bounds.position + initial_bounds.size).distance_to(source_max) < 0.002, "actual imported visual maximum matches source runtime bounds")
	var wheel_rows: Dictionary = entry.controls.wheels
	var initial_wheel_bottoms := PackedFloat32Array()
	var authored_wheel_centres := PackedVector3Array()
	var authored_wheel_radii := PackedFloat32Array()
	for wheel_id: String in ["front_left", "front_right", "rear_left", "rear_right"]:
		var wheel: Dictionary = wheel_rows[wheel_id]
		authored_wheel_centres.append(_vector3(wheel.rest_position_m))
		authored_wheel_radii.append(float(wheel.rolling_radius_m))
		initial_wheel_bottoms.append(authored_wheel_centres[-1].y - authored_wheel_radii[-1])
		_check(absf(initial_wheel_bottoms[-1]) < 0.002, "source wheel touches source-ground plane " + wheel_id)
	var native_wheel_mounts: PackedVector3Array = body.profile.wheel_local_positions()
	var max_probe_planar_error := 0.0
	for index in 4:
		var planar_error := Vector2(native_wheel_mounts[index].x - authored_wheel_centres[index].x,
			native_wheel_mounts[index].z - authored_wheel_centres[index].z).length()
		max_probe_planar_error = maxf(max_probe_planar_error, planar_error)
	_check(max_probe_planar_error < 0.06, "native probes remain close to authored wheel centres in the ground plane")
	var visible_half_width := initial_bounds.size.x * 0.5
	var collider_side_margin: float = body.profile.body_half_extents_m.x - visible_half_width
	_check(collider_side_margin >= 0.0 and collider_side_margin <= 0.12, "native collider side margin stays bounded around actual visual")
	var driver_anchor := Vector3.ZERO
	for anchor: Dictionary in entry.anchors:
		if anchor.get("can_drive", false):
			driver_anchor = _vector3(anchor.seat_local_m)
			break
	_check(driver_anchor.is_finite() and driver_anchor.x < 0.0, "left driver anchor remains finite in source-ground frame")
	var stable_ticks := 0
	var settle_ticks := 0
	for tick in 600:
		await physics_frame
		settle_ticks = tick + 1
		var stable := tick >= 179 and int(body.get("_grounded_wheel_mask")) == 15 \
			and body.linear_velocity.length() <= 0.03 and body.angular_velocity.length() <= 0.03 \
			and body.global_transform.is_finite() and body.global_basis.y.dot(Vector3.UP) >= cos(0.035)
		stable_ticks = stable_ticks + 1 if stable else 0
		if stable_ticks >= 60:
			break
	var settled_bounds_world := _visual_bounds(visual.root, Transform3D.IDENTITY)
	var origin_y := body.global_position.y
	var wheel_bottom_world_y := PackedFloat32Array()
	for index in 4:
		wheel_bottom_world_y.append((body.global_transform * authored_wheel_centres[index]).y - authored_wheel_radii[index])
	var hull_base_world_y := settled_bounds_world.position.y
	var driver_world := body.global_transform * driver_anchor
	var state: Dictionary = body.snapshot_state()
	var chassis_bottom_local: float = body.profile.chassis_center_local_m().y - body.profile.chassis_half_extents_m().y
	var result := {
		"descriptor_sha256": FileAccess.get_sha256(DESCRIPTORS),
		"profile_id": PROFILE_ID,
		"settle_ticks": settle_ticks,
		"origin_world_y_m": origin_y,
		"wheel_bottom_world_y_m": wheel_bottom_world_y,
		"visual_hull_base_world_y_m": hull_base_world_y,
		"chassis_bottom_world_y_m": origin_y + chassis_bottom_local,
		"driver_anchor_world_m": driver_world,
		"grounded_wheel_mask": int(state.get("grounded_wheel_mask", 0)),
		"native_ground_clearance_m": body.profile.ground_clearance_m,
		"native_center_of_mass_local_m": body.profile.center_of_mass_local_m,
		"max_probe_planar_error_m": max_probe_planar_error,
		"collider_side_margin_m": collider_side_margin,
		"visual_bounds_local_m": {"min": initial_bounds.position, "max": initial_bounds.position + initial_bounds.size},
		"qualification": "headless actual visual plus native rigid body on flat floor; not GPU, FPS or LIVE",
	}
	_check(int(state.get("grounded_wheel_mask", 0)) == 15, "all four native suspension rays grounded after settle")
	_check(stable_ticks >= 60, "vehicle reaches a stable 60-tick settle window")
	_check(absf(body.rotation.x) < 0.03 and absf(body.rotation.z) < 0.03, "actual visual/native body settle upright")
	for index in 4:
		_check(absf(wheel_bottom_world_y[index]) < 0.03, "actual source wheel settles on floor " + str(index))
	_check(hull_base_world_y > -0.01, "actual visual hull does not penetrate floor")
	# This is the authored actor-root seat target, not a foot or pelvis point; the
	# source compact sedan intentionally places it 12.4 mm below its ground root.
	_check(absf(driver_anchor.y + 0.0124) < 0.000001, "exact authored compact driver root height retained")
	_check(driver_world.y > -0.03 and (driver_world - body.global_position).dot(body.global_basis.x) < 0.0, "authored driver root anchor remains near floor on vehicle-left side")
	visual.root.get_parent().remove_child(visual.root)
	visual.dispose()
	body.free()
	floor.free()
	_finish(result)

func _finish(result: Dictionary) -> void:
	result["checks"] = checks
	result["passed"] = failures.is_empty()
	result["failures"] = failures
	print("NATIVE_VEHICLE_VISUAL_ALIGNMENT_TEST ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
