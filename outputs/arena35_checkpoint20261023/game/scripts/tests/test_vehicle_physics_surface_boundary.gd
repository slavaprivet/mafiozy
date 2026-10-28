extends SceneTree
## Physics-only receipt for the root-owned preview surface boundary beside the
## actual first vehicle. No visual, GPU, main scene or production mutation.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const BLOCK := "res://data/block.json"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PARKING_ID := "parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-004:bay:0"
const PROFILE_ID := "city_hatchback"
const CURRENT_ROOT_OWNED_EAST_BOUNDARY_M := 43.05
const FUTURE_REQUIRED_SUPPORT_X_M := 44.4
const PATH_Z_M := -9.75

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.x), float(value.y), float(value.z))

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
	var world := Node3D.new()
	var origin := Vector3(float(block.originM[0]), float(block.originM[1]), float(block.originM[2]))
	var surface: Dictionary = block.surface
	var grid: Array = surface.grid
	var palette: Dictionary = surface.palette
	var cell := float(surface.cellSize)
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

func _floor_hit(space: PhysicsDirectSpaceState3D, at: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 2.0)
	query.exclude = exclude
	return space.intersect_ray(query)

func _run() -> void:
	var block_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLOCK))
	var descriptor_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(block_value is Dictionary and descriptor_value is Dictionary, "actual block and transport descriptors parse")
	if not block_value is Dictionary or not descriptor_value is Dictionary:
		_finish({})
		return
	var block := block_value as Dictionary
	var descriptors := descriptor_value as Dictionary
	var profile := _profile(descriptors)
	var parking := _parking(descriptors)
	_check(not profile.is_empty() and not parking.is_empty(), "actual hatchback and parking bay exist")
	if profile.is_empty() or parking.is_empty():
		_finish({})
		return
	var origin := Vector3(float(block.originM[0]), float(block.originM[1]), float(block.originM[2]))
	var spawn := _vector(parking.position_m) - origin
	_check(spawn.distance_to(Vector3(37.05, 0.0, PATH_Z_M)) < 0.0001, "actual first vehicle source-local parking pose")
	var surface: Dictionary = block.surface
	var east_boundary := (float(surface.startCol) + float(surface.grid[0].size())) * float(surface.cellSize) - origin.x
	var documented_current_boundary := absf(east_boundary - CURRENT_ROOT_OWNED_EAST_BOUNDARY_M) < 0.0001

	var world := _build_exact_dry_surface(block)
	root.add_child(world)
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var spawn_support := _floor_hit(space, spawn)
	var future_support := _floor_hit(space, Vector3(FUTURE_REQUIRED_SUPPORT_X_M, 0.0, PATH_Z_M))
	_check(not spawn_support.is_empty() and absf(float(spawn_support.position.y)) < 0.001, "actual parking has dry physical support")
	# This is the ownership boundary for the current cropped preview. A future
	# expanded block passes by supplying floor at x=44.4 or farther instead.
	_check(not future_support.is_empty() or documented_current_boundary,
		"expanded floor reaches x=44.4 or current x=43.05 boundary remains explicit root ownership")

	var factory := Factory.new()
	var body := factory.spawn_from_descriptor({
		"vehicle_id": "surface-boundary-hatchback", "life_generation": 1,
		"profile_id": PROFILE_ID, "active": true, "position_m": spawn,
		"yaw_rad": -PI * 0.5, "source_clock": 1,
	}, profile)
	_check(body != null, "actual native hatchback spawns:" + factory.last_error)
	if body == null:
		world.free()
		_finish({})
		return
	world.add_child(body)
	for tick in 120:
		await physics_frame
	_check(int(body.snapshot_state().grounded_wheel_mask) == 15, "actual hatchback initially settles on four rays")
	body.submit_control(1.0, 0.0, 0.0, false, 1)
	var first_ungrounded_tick := -1
	var first_past_required_tick := -1
	var minimum_y := body.global_position.y
	var maximum_tilt := 0.0
	for tick in 240:
		await physics_frame
		var mask := int(body.snapshot_state().grounded_wheel_mask)
		if first_ungrounded_tick < 0 and mask == 0:
			first_ungrounded_tick = tick
		if first_past_required_tick < 0 and body.global_position.x >= FUTURE_REQUIRED_SUPPORT_X_M:
			first_past_required_tick = tick
		minimum_y = minf(minimum_y, body.global_position.y)
		maximum_tilt = maxf(maximum_tilt, acos(clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))
	if future_support.is_empty():
		_check(first_ungrounded_tick >= 0 and first_past_required_tick >= 0, "current eastbound path loses all wheel support beyond crop")
		_check(minimum_y < -1.0 and maximum_tilt > 0.1, "current boundary deterministically reproduces fall and overturn onset")
	var receipt := {
		"block_sha256": FileAccess.get_sha256(BLOCK),
		"descriptors_sha256": FileAccess.get_sha256(DESCRIPTORS),
		"parking_id": PARKING_ID,
		"profile_id": PROFILE_ID,
		"spawn_local_m": spawn,
		"current_east_boundary_m": east_boundary,
		"future_required_support_x_m": FUTURE_REQUIRED_SUPPORT_X_M,
		"future_support_present": not future_support.is_empty(),
		"ownership": "ROOT: expand preview surface or add an admitted drive boundary; vehicle physics does not own map extent",
		"first_ungrounded_tick": first_ungrounded_tick,
		"first_past_required_tick": first_past_required_tick,
		"minimum_root_y_m": minimum_y,
		"maximum_tilt_rad": maximum_tilt,
	}
	body.free()
	world.free()
	_finish(receipt)

func _finish(receipt: Dictionary) -> void:
	print("NATIVE_VEHICLE_SURFACE_BOUNDARY_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"receipt": receipt,
		"qualification": "physics-only exact block dry strips and actual native hatchback; no visual, GPU, main or LIVE authority",
	}))
	quit(0 if failures.is_empty() else 1)
