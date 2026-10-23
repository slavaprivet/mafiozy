extends SceneTree
## Actual block-bounds and real NativeVehicleBody collision proof. Headless only;
## no main wiring, renderer/GPU claim, fabricated world floor, water, or source ID.

const Boundary = preload("res://scripts/preview_boundary.gd")
const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const BLOCK := "res://data/block.json"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PROFILE_ID := "city_hatchback"
const PARKING_ID := "parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-004:bay:0"
const TEST_SPEED_MPS := 6.5

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _v3(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", NAN)), float(value.get("y", NAN)), float(value.get("z", NAN)))
	return Vector3(NAN, NAN, NAN)

func _profile(document: Dictionary) -> Dictionary:
	for row: Dictionary in document.get("profiles", []):
		if str(row.get("profile_id", "")) == PROFILE_ID:
			return row
	return {}

func _parking(document: Dictionary) -> Dictionary:
	for row: Dictionary in document.get("parking", {}).get("bays", []):
		if str(row.get("parking_id", "")) == PARKING_ID:
			return row
	return {}

func _build_exact_dry_surface(block: Dictionary) -> Node3D:
	# This is the same source-grid strip construction as main._build_surface().
	# It deliberately skips non-solid cells instead of filling the crop.
	var world := Node3D.new()
	world.name = "ActualBlockDrySurface"
	var origin := _v3(block.get("originM", []))
	var surface: Dictionary = block.get("surface", {})
	var grid: Array = surface.get("grid", [])
	var palette: Dictionary = surface.get("palette", {})
	var cell := float(surface.get("cellSize", 0.0))
	for row in grid.size():
		var column := 0
		while column < grid[row].size():
			var key := str(int(grid[row][column]))
			if not bool(palette[key].solid):
				column += 1
				continue
			var first := column
			while column < grid[row].size() and str(int(grid[row][column])) == key:
				column += 1
			var body := StaticBody3D.new()
			body.set_meta("vehicle_surface_id", str(palette[key].kind))
			var shape := BoxShape3D.new()
			shape.size = Vector3(float(column - first) * cell, 0.16, cell)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.position = Vector3(
				(float(surface.startCol) + float(first + column) * 0.5) * cell - origin.x,
				float(palette[key].heightM) - 0.08,
				(float(surface.startRow) + float(row) + 0.5) * cell - origin.z)
			body.add_child(collision)
			world.add_child(body)
	return world

func _world_x_half_extent(body: RigidBody3D, half: Vector3) -> float:
	var basis := body.global_basis
	return absf(basis.x.x) * half.x + absf(basis.y.x) * half.y + absf(basis.z.x) * half.z

func _run() -> void:
	var block_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLOCK))
	var descriptors_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(block_value is Dictionary, "actual block parses")
	_check(descriptors_value is Dictionary, "actual descriptors parse")
	if not block_value is Dictionary or not descriptors_value is Dictionary:
		_finish({})
		return
	var block := block_value as Dictionary
	var descriptors := descriptors_value as Dictionary
	var descriptor := _profile(descriptors)
	var parking := _parking(descriptors)
	_check(not descriptor.is_empty(), "actual hatchback descriptor exists")
	_check(not parking.is_empty(), "actual first parking bay exists")
	var surface: Dictionary = block.get("surface", {})
	var bounds_value: Variant = surface.get("boundsLocalM")
	_check(bounds_value is Dictionary, "actual surface bounds exist")
	if descriptor.is_empty() or parking.is_empty() or not bounds_value is Dictionary:
		_finish({})
		return
	var minimum := _v3(bounds_value.min)
	var maximum := _v3(bounds_value.max)
	_check(minimum.is_equal_approx(Vector3(-84.05, -0.18, -45.10)), "actual block minimum is exact")
	_check(maximum.is_equal_approx(Vector3(43.05, 0.0, 82.0)), "actual block east and maximum are exact")
	var anchored_boundary := Boundary.new()
	_check(anchored_boundary.configure(bounds_value, Vector3(37.05, 0.0, -9.75)),
		"optional local label anchor is accepted")
	var anchored_label := anchored_boundary.get_node_or_null("BoundaryLabel") as Label3D
	_check(anchored_label != null and is_equal_approx(anchored_label.position.x, 37.05)
		and is_equal_approx(anchored_label.position.z, -9.75), "optional label anchor remains near actual parking")
	anchored_boundary.free()
	var boundary := Boundary.new()
	_check(boundary.configure(bounds_value), "boundary accepts actual block bounds")
	_check(not boundary.configure(bounds_value), "boundary configure is single-admission")
	root.add_child(boundary)
	await process_frame
	_check(boundary.get_child_count() == 5, "four walls plus one label only")
	_check(boundary.get_node_or_null("BoundaryLabel") is Label3D, "east-entry label exists")
	var label := boundary.get_node_or_null("BoundaryLabel") as Label3D
	_check(label != null and label.text == Boundary.LABEL_TEXT and label.position.x < maximum.x,
		"label is visible inside east edge")
	var expected := {
		"west": {"axis": "x", "outer": minimum.x},
		"east": {"axis": "x", "outer": maximum.x},
		"north": {"axis": "z", "outer": minimum.z},
		"south": {"axis": "z", "outer": maximum.z},
	}
	for side: String in expected:
		var body := boundary.get_node_or_null("Boundary" + side.capitalize()) as StaticBody3D
		_check(body != null, side + " static body exists")
		if body == null:
			continue
		var collision := body.get_node_or_null("Collision") as CollisionShape3D
		var visible_wall := body.get_node_or_null("VisibleWall") as MeshInstance3D
		_check(collision != null and collision.shape is BoxShape3D, side + " box collision exists")
		_check(visible_wall != null and visible_wall.mesh is BoxMesh, side + " matching visible mesh exists")
		if collision == null or not collision.shape is BoxShape3D:
			continue
		var size := (collision.shape as BoxShape3D).size
		var low := body.position - size * 0.5
		var high := body.position + size * 0.5
		_check(low.x >= minimum.x - 0.00001 and high.x <= maximum.x + 0.00001
			and low.z >= minimum.z - 0.00001 and high.z <= maximum.z + 0.00001,
			side + " wall remains within crop")
		var outer: float = low.x if side == "west" else high.x if side == "east" else low.z if side == "north" else high.z
		_check(absf(outer - float(expected[side].outer)) < 0.00001, side + " outer face matches actual bound")
		_check(absf(low.y - maximum.y) < 0.00001 and absf(high.y - maximum.y - Boundary.WALL_HEIGHT_M) < 0.00001,
			side + " wall starts at dry surface top and is 2.5m high")
	var factory := Factory.new()
	var origin := _v3(block.get("originM", []))
	var spawn := _v3(parking.get("position_m", {})) - origin
	_check(spawn.is_equal_approx(Vector3(37.05, 0.0, -9.75)), "actual first parking pose is exact")
	var actual_surface := _build_exact_dry_surface(block)
	root.add_child(actual_surface)
	var east_car := factory.spawn_from_descriptor({
		"vehicle_id":"actual-east-boundary", "life_generation":1,
		"profile_id":PROFILE_ID, "active":true, "position_m":spawn,
		"yaw_rad":-PI * 0.5, "source_clock":1,
	}, descriptor)
	_check(east_car != null, "actual east scenario native body spawns")
	var actual_east: Dictionary = {}
	if east_car != null:
		root.add_child(east_car)
		for tick in 120:
			await physics_frame
		_check(int(east_car.snapshot_state().grounded_wheel_mask) == 15,
			"actual east scenario settles on four source-floor rays")
		east_car.linear_velocity = Vector3(TEST_SPEED_MPS, 0.0, 0.0)
		var maximum_front_x := -INF
		var minimum_root_y := INF
		for tick in 180:
			await physics_frame
			var half: Vector3 = east_car.profile.chassis_half_extents_m()
			maximum_front_x = maxf(maximum_front_x,
				east_car.global_position.x + _world_x_half_extent(east_car, half))
			minimum_root_y = minf(minimum_root_y, east_car.global_position.y)
		var final_state: Dictionary = east_car.snapshot_state()
		_check(maximum_front_x <= maximum.x + 0.03,
			"actual full-gravity east impact cannot cross exact crop edge")
		_check(minimum_root_y > -0.5 and int(final_state.grounded_wheel_mask) != 0,
			"actual full-gravity east impact neither enters edge void nor loses all support")
		_check(east_car.linear_velocity.x <= 0.25,
			"actual full-gravity east 6.5mps motion is stopped")
		actual_east = {"spawn_local_m":spawn, "maximum_front_x_m":maximum_front_x,
			"minimum_root_y_m":minimum_root_y, "final_position_m":east_car.global_position,
			"final_velocity_mps":east_car.linear_velocity,
			"final_grounded_wheel_mask":int(final_state.grounded_wheel_mask),
			"gravity_scale":east_car.gravity_scale,
			"axis_lock_linear_y":east_car.axis_lock_linear_y,
			"axis_lock_angular_x":east_car.axis_lock_angular_x,
			"axis_lock_angular_z":east_car.axis_lock_angular_z}
		east_car.queue_free()
		await process_frame
	var sides := [
		{"id":"west", "start":Vector3(minimum.x + 8.0, 0.0, (minimum.z + maximum.z) * 0.5), "velocity":Vector3(-TEST_SPEED_MPS, 0.0, 0.0)},
		{"id":"east", "start":Vector3(maximum.x - 8.0, 0.0, (minimum.z + maximum.z) * 0.5), "velocity":Vector3(TEST_SPEED_MPS, 0.0, 0.0)},
		{"id":"north", "start":Vector3((minimum.x + maximum.x) * 0.5, 0.0, minimum.z + 8.0), "velocity":Vector3(0.0, 0.0, -TEST_SPEED_MPS)},
		{"id":"south", "start":Vector3((minimum.x + maximum.x) * 0.5, 0.0, maximum.z - 8.0), "velocity":Vector3(0.0, 0.0, TEST_SPEED_MPS)},
	]
	var results: Dictionary = {}
	for test: Dictionary in sides:
		var side := str(test.id)
		var record := {"vehicle_id":"boundary-" + side, "life_generation":1,
			"profile_id":PROFILE_ID, "active":true, "position_m":test.start,
			"yaw_rad":0.0, "source_clock":1}
		var car := factory.spawn_from_descriptor(record, descriptor)
		_check(car != null, side + " real native body spawns")
		if car == null:
			continue
		car.gravity_scale = 0.0
		car.axis_lock_linear_y = true
		car.axis_lock_angular_x = true
		car.axis_lock_angular_z = true
		root.add_child(car)
		await physics_frame
		car.linear_velocity = test.velocity
		for tick in 150:
			await physics_frame
		var half: Vector3 = car.profile.chassis_half_extents_m()
		var p: Vector3 = car.global_position
		var outward_speed: float = car.linear_velocity.dot((test.velocity as Vector3).normalized())
		var contained: bool = p.x - half.x >= minimum.x - 0.03 and p.x + half.x <= maximum.x + 0.03 \
			and p.z - half.z >= minimum.z - 0.03 and p.z + half.z <= maximum.z + 0.03
		_check(p.is_finite() and contained, side + " impact cannot cross crop edge")
		_check(outward_speed <= 0.25, side + " 6.5mps outward motion is stopped")
		results[side] = {"position_m": p, "velocity_mps": car.linear_velocity,
			"outward_speed_mps": outward_speed, "contained": contained}
		car.queue_free()
		await process_frame
	actual_surface.queue_free()
	_finish({"bounds_min_m": minimum, "bounds_max_m": maximum, "speed_mps": TEST_SPEED_MPS,
		"wall_height_m": Boundary.WALL_HEIGHT_M, "wall_thickness_m": Boundary.WALL_THICKNESS_M,
		"actual_east_source_surface":actual_east, "isolated_wall_results": results,
		"qualification":"actual east: exact block dry strips + gravity/free roll-pitch real NativeVehicleBody; other four: locked geometry isolation; headless physics, no GPU/LIVE/main wiring"})

func _finish(evidence: Dictionary) -> void:
	var result := {"checks": checks, "failures": failures, "passed": failures.is_empty(), "evidence": evidence}
	print("VEHICLE_PREVIEW_BOUNDARY_TEST ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
