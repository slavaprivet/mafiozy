extends SceneTree
## Exact block terrain + actual preview hatchback parking, physics-only.

const Factory = preload("res://scripts/vehicle_physics/vehicle_body_factory.gd")
const Host = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_host_candidate.gd")
const BLOCK := "res://data/block.json"
const DESCRIPTORS := "res://data/transport/vehicle_descriptors.v1.json"
const PARKING_ID := "parking:REBUILD-VISUAL-old_town_narrow_townhouse_v1-004:bay:0"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.x), float(value.y), float(value.z))

func _dry_surface(block: Dictionary) -> Node3D:
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
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(float(column - first) * cell, 0.16, cell)
			collision.shape = box
			body.position = Vector3(
				(float(surface.startCol) + float(first + column) * 0.5) * cell - origin.x,
				float(palette[key].heightM) - 0.08,
				(float(surface.startRow) + float(row) + 0.5) * cell - origin.z)
			body.add_child(collision)
			world.add_child(body)
	return world

func _run() -> void:
	var block_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLOCK))
	var descriptors_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTORS))
	_check(block_value is Dictionary and descriptors_value is Dictionary, "actual block and transport data")
	if not block_value is Dictionary or not descriptors_value is Dictionary:
		_finish({})
		return
	var block := block_value as Dictionary
	var descriptors := descriptors_value as Dictionary
	var profile: Dictionary = {}
	var parking: Dictionary = {}
	for row: Dictionary in descriptors.get("profiles", []):
		if str(row.get("profile_id", "")) == "city_hatchback":
			profile = row
			break
	for row: Dictionary in descriptors.get("parking", {}).get("bays", []):
		if str(row.get("parking_id", "")) == PARKING_ID:
			parking = row
			break
	_check(not profile.is_empty() and not parking.is_empty(), "actual hatchback and parking")
	if profile.is_empty() or parking.is_empty():
		_finish({})
		return
	var origin := Vector3(float(block.originM[0]), float(block.originM[1]), float(block.originM[2]))
	var spawn := _vector(parking.position_m) - origin
	var world := _dry_surface(block)
	root.add_child(world)
	var body = Factory.new().spawn_from_descriptor({
		"vehicle_id": "tyre-source-map-hatchback", "life_generation": 1,
		"profile_id": "city_hatchback", "source_clock": 1,
		"active": true, "position_m": spawn,
		"yaw_rad": -PI * 0.5,
	}, profile)
	_check(body != null, "actual parked native hatchback")
	if body == null:
		_finish({})
		return
	world.add_child(body)
	var host := Host.new()
	world.add_child(host)
	_check(host.configure(body), "host configured beside parked car")
	for tick in 120:
		await physics_frame
	_check(int(body.snapshot_state().grounded_wheel_mask) == 15,
		"all wheels supported by exact block floor")
	var at_rest: Dictionary = body.snapshot_state()
	_check(at_rest.surface_ids.has("grass"),
		"actual parking is grass, so no road mark is fabricated")
	_check(int(host.stats().tracks.count) == 0, "no idle marks at grass parking")
	var surface: Dictionary = block.surface
	var grid: Array = surface.grid
	var road_row := 21
	var road_column := 25
	var road_key := str(int(grid[road_row][road_column]))
	_check(str(surface.palette[road_key].kind) == "road", "source grid road tile")
	var cell := float(surface.cellSize)
	body.global_position = Vector3(
		(float(surface.startCol) + float(road_column) + 0.5) * cell - origin.x,
		0.0,
		(float(surface.startRow) + float(road_row) + 0.5) * cell - origin.z)
	for tick in 12:
		await physics_frame
	_check(body.snapshot_state().surface_ids.has("road"),
		"same physical hatchback reads road-tagged source strip")
	body.submit_control(1.0, 0.0, 0.0, false, 1)
	for tick in 45:
		await physics_frame
	body.submit_control(0.0, 0.4, 0.0, true, 2)
	for tick in 60:
		await physics_frame
	var stats: Dictionary = host.stats()
	_check(stats.configured and int(stats.tracks.count) > 0,
		"source-map physical skid creates tracks")
	_check(body.global_position.x < 43.05 and body.global_position.y > -0.5,
		"test stays on actual dry preview block")
	var details := {"spawn_local_m": spawn, "last_position_m": body.global_position,
		"last_surface_ids": body.snapshot_state().surface_ids,
		"segments": stats.tracks.get("count", -1), "last_tick": stats.last_tick}
	body.queue_free()
	for tick in 3:
		await physics_frame
	_check(not is_instance_valid(host), "source-map vehicle teardown clears track host")
	_finish(details)

func _finish(details: Dictionary) -> void:
	print("NATIVE_VEHICLE_TYRE_SOURCE_MAP_TEST ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"details": details, "block_sha256": FileAccess.get_sha256(BLOCK),
		"descriptors_sha256": FileAccess.get_sha256(DESCRIPTORS),
		"host_sha256": FileAccess.get_sha256("res://scripts/vehicle_physics/vehicle_tyre_tracks_host_candidate.gd"),
	}))
	quit(0 if failures.is_empty() else 1)
