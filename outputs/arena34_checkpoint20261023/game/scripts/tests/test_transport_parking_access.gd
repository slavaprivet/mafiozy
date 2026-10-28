extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const Parking = preload("res://scripts/transport/transport_parking_access.gd")
const SOURCE = "res://data/transport/parking_access.v1.json"
const TEMP = "user://transport_parking_access_test.json"
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func reject(catalog: RefCounted, base: Dictionary, mode: String) -> void:
	var candidate: Dictionary = base.duplicate(true)
	match mode:
		"descriptor_sha": candidate.authority.descriptor_sha256 = "0".repeat(64)
		"source_sha": candidate.authority.parking_source_sha256 = "0".repeat(64)
		"missing_bay": candidate.lots[0].bay_ids.pop_back()
		"missing_walk": candidate.walking_routes_source_m.pop_back()
		"foreign_bay": candidate.lots[0].bay_ids[0] = "parking:fake:bay:0"
		"bad_point": candidate.lots[0].entry_paths_source_m[0][0].x = "NaN"
		"bad_surface": candidate.surface_rects_source_m[0].minX = "NaN"
		"wrong_lot": candidate.lots[0].building_id = "other"
		"coverage_owner": candidate.coverage[0].lotId = "parking:invented"
		"coverage_distance": candidate.coverage[0].walkingDistance = 99999.0
		"coverage_duplicate": candidate.coverage[1].buildingId = candidate.coverage[0].buildingId
		"road_crossing_rule": candidate.walking_routes_source_m[0].roadCrossingRule = "unmapped_crossings_allowed"
		"driveway_rule": candidate.walking_routes_source_m[0].drivewayRule = "vehicles_have_priority"
		"foreign_sign": candidate.signs_source_m[0].lotId = "parking:invented"
		"missing_sign_collider": candidate.sign_colliders_source_grid.pop_back()
		"missing_sign_pair": candidate.signs_source_m.pop_back(); candidate.sign_colliders_source_grid.pop_back()
		"bad_sign_polygon": candidate.sign_colliders_source_grid[0].polygonCR[0][0] += 10.0
	var file := FileAccess.open(TEMP, FileAccess.WRITE)
	if file == null:
		check(false, mode + " test fixture write")
		return
	file.store_string(JSON.stringify(candidate)); file.close()
	var reader := Parking.new()
	check(not reader.load_file(catalog, TEMP), mode + " rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))

func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file(), "source descriptors load")
	var reader := Parking.new()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var started := Time.get_ticks_usec()
	check(reader.load_file(catalog), "source parking access loads: " + reader.error)
	var load_us := Time.get_ticks_usec() - started
	var memory_delta := Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before
	var stats: Dictionary = reader.stats()
	check(stats.lots == 39 and stats.bays == 59 and stats.walking_routes == 46 and stats.surface_rects == 78 and stats.signs == 57 and stats.sign_colliders == 57, "complete source parking route and sign inventory")
	var sign_id := "parking:REBUILD-VISUAL-hospital-001:parking"
	var sign: Dictionary = reader.sign(sign_id)
	var collider_vertices: Array = reader.sign_colliders_native()
	check(sign.id == sign_id and collider_vertices.size() == 57 and collider_vertices[0].id == sign_id and collider_vertices[0].vertices_m.size() == 16, "all source sign collider octagons retained")
	check(collider_vertices[0].vertices_m[0].distance_to(Vector3(sign.x + .15, 0, sign.z)) < .000001 and collider_vertices[0].vertices_m[1].distance_to(Vector3(sign.x + .15, 2.9, sign.z)) < .000001, "source grid octagon converts to exact native metre prism")
	var id := "parking:REBUILD-VISUAL-hospital-001"
	var lot: Dictionary = reader.lot(id)
	check(lot.bay_ids.size() == 4 and lot.entry_paths_source_m.size() == 2 and lot.entry_paths_source_m[0].size() == 49, "hospital retains four bays and both 49-point source entry curves")
	var paths: Array = reader.entry_paths_native(id)
	var source_point: Dictionary = lot.entry_paths_source_m[0][0]
	check(paths.size() == 2 and paths[0].size() == 49 and paths[0][0].position_m.distance_to(Vector3(source_point.x, 0, source_point.z)) < .000001, "entry point metres are retained")
	check(absf(wrapf(paths[0][0].yaw_rad - wrapf(float(source_point.yaw) + PI, -PI, PI), -PI, PI)) < .000001, "source yaw converts to Godot yaw")
	var all_points_ok := true
	var point_count := 0
	for raw_lot in parsed_lots(SOURCE):
		var native_paths: Array = reader.entry_paths_native(raw_lot.id)
		if native_paths.size() != raw_lot.entry_paths_source_m.size(): all_points_ok = false; break
		for path_index in raw_lot.entry_paths_source_m.size():
			var raw_path: Array = raw_lot.entry_paths_source_m[path_index]
			if native_paths[path_index].size() != raw_path.size(): all_points_ok = false; break
			for point_index in raw_path.size():
				var raw_point: Dictionary = raw_path[point_index]
				var native_point: Dictionary = native_paths[path_index][point_index]
				point_count += 1
				if native_point.position_m.distance_to(Vector3(raw_point.x, raw_lot.ground_y_m, raw_point.z)) > .000001 or absf(wrapf(native_point.yaw_rad - wrapf(float(raw_point.yaw) + PI, -PI, PI), -PI, PI)) > .000001:
					all_points_ok = false; break
	check(all_points_ok and point_count == 3129, "all 3129 source entry points and headings survive native conversion")
	check(not reader.walking_route(id, "REBUILD-VISUAL-hospital-001").is_empty(), "actual hospital entrance walking route retained")
	check(reader.walking_route(id, "invented-building").is_empty(), "unknown walking route is never invented")
	var rect: Dictionary = lot.lot_rect_source_m
	check(reader.source_surface_contains((rect.minX + rect.maxX) * .5, (rect.minZ + rect.maxZ) * .5), "actual parking surface indexed")
	check(not reader.source_surface_contains(INF, 0) and not reader.source_surface_contains(-100000, -100000), "invalid and remote surface rejected")
	lot.bay_ids.clear()
	check(reader.lot(id).bay_ids.size() == 4, "returned lot cannot mutate internal route data")
	var parse_started := Time.get_ticks_usec()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var parse_us := Time.get_ticks_usec() - parse_started
	if parsed is Dictionary:
		for mode in ["descriptor_sha", "source_sha", "missing_bay", "missing_walk", "foreign_bay", "bad_point", "bad_surface", "wrong_lot", "coverage_owner", "coverage_distance", "coverage_duplicate", "road_crossing_rule", "driveway_rule", "foreign_sign", "missing_sign_collider", "missing_sign_pair", "bad_sign_polygon"]:
			reject(catalog, parsed, mode)
	else:
		check(false, "source JSON parse")
	var query_started := Time.get_ticks_usec()
	for i in 10000:
		reader.source_surface_contains(679.25, 5.5)
	var query_us := Time.get_ticks_usec() - query_started
	print("TRANSPORT_PARKING_ACCESS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "load_us": load_us, "parse_us": parse_us, "memory_delta_bytes": memory_delta, "surface_query_10000_us": query_us, "scope": "source route geometry only; occupancy/collision/AI remain host-owned"}))
	quit(0 if failures.is_empty() else 1)

func parsed_lots(path: String) -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.get("lots", []) if data is Dictionary else []
