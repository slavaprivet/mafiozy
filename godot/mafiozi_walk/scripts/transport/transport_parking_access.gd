extends RefCounted
## Read-only source parking routes. No occupancy, collision or route authority.
const SCHEMA := "mafiozi.transport.parking-access.v1"
const SOURCE_LOTS := 39
const SOURCE_BAYS := 59
const SOURCE_SIGNS := 57
var error := ""
var _lots: Dictionary = {}
var _walking: Dictionary = {}
var _surfaces: Array = []
var _signs: Dictionary = {}
var _sign_colliders: Array = []
var _document: Dictionary = {}

func load_file(catalog: RefCounted, path: String = "res://data/transport/parking_access.v1.json") -> bool:
	error = ""
	_lots.clear(); _walking.clear(); _surfaces.clear(); _signs.clear(); _sign_colliders.clear(); _document.clear()
	if catalog == null or catalog.get("parking") == null or not catalog.get("parking") is Dictionary:
		error = "CATALOG"; return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "OPEN_FAILED"; return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		error = "JSON"; return false
	var doc: Dictionary = parsed
	if doc.get("schema") != SCHEMA or not doc.get("authority") is Dictionary:
		error = "SCHEMA"; return false
	if doc.authority.get("descriptor_sha256") != FileAccess.get_sha256("res://data/transport/vehicle_descriptors.v1.json"):
		error = "DESCRIPTOR_REVISION"; return false
	var source_rows: Variant = (catalog.get("document") as Dictionary).get("authority", {}).get("sources", [])
	if not source_rows is Array:
		error = "SOURCE_RECEIPT"; return false
	var source_pins: Dictionary = {}
	for row in source_rows:
		if row is Dictionary: source_pins[row.get("path")] = row.get("sha256")
	if doc.authority.get("parking_source_sha256") != source_pins.get("assets/maps/city_rebuild_v1/city_parking_plan.mjs") or doc.authority.get("static_collision_fixture_sha256") != source_pins.get("assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz"):
		error = "SOURCE_RECEIPT"; return false
	if not doc.get("stats") is Dictionary or int(doc.stats.get("lots", -1)) != SOURCE_LOTS or int(doc.stats.get("bays", -1)) != SOURCE_BAYS:
		error = "COUNTS"; return false
	if not doc.get("lots") is Array or not doc.get("walking_routes_source_m") is Array or not doc.get("surface_rects_source_m") is Array or not doc.get("coverage") is Array or not doc.get("signs_source_m") is Array or not doc.get("sign_colliders_source_grid") is Array:
		error = "SHAPE"; return false
	if not _number(doc.get("metres_per_cell")) or not is_equal_approx(float(doc.metres_per_cell), 4.1) or doc.signs_source_m.size() != SOURCE_SIGNS or doc.sign_colliders_source_grid.size() != SOURCE_SIGNS:
		error = "SIGN_COUNTS"; return false
	if doc.lots.size() != SOURCE_LOTS or (catalog.get("parking") as Dictionary).size() != SOURCE_BAYS:
		error = "COUNTS"; return false
	if doc.walking_routes_source_m.size() != int(doc.stats.get("servedBuildings", -1)) or doc.coverage.size() != int(doc.stats.get("servedBuildings", -1)) + int(doc.stats.get("uncoveredBuildings", -1)) or doc.surface_rects_source_m.size() != SOURCE_LOTS * 2:
		error = "ROUTE_COUNTS"; return false
	var bay_ids: Dictionary = {}
	var lots: Dictionary = {}
	for item in doc.lots:
		if not item is Dictionary or not _valid_lot(item):
			error = "LOT"; return false
		var lot: Dictionary = item
		if lots.has(lot.id):
			error = "LOT_DUPLICATE"; return false
		lots[lot.id] = lot
		for bay_id in lot.bay_ids:
			if bay_ids.has(bay_id) or not (catalog.get("parking") as Dictionary).has(bay_id):
				error = "BAY_ID"; return false
			var bay: Dictionary = (catalog.get("parking") as Dictionary)[bay_id]
			if bay.get("lot_id") != lot.id or bay.get("building_id") != lot.building_id:
				error = "BAY_OWNER"; return false
			bay_ids[bay_id] = true
	if bay_ids.size() != SOURCE_BAYS:
		error = "BAY_COUNT"; return false
	var walking: Dictionary = {}
	for item in doc.walking_routes_source_m:
		if not item is Dictionary or not item.get("lotId") is String or not item.get("buildingId") is String or not lots.has(item.lotId) or not item.get("points") is Array or item.points.size() < 2:
			error = "WALKING_ROUTE"; return false
		var key: String = JSON.stringify([item.lotId, item.buildingId])
		if walking.has(key) or not (lots[item.lotId].served_building_ids as Array).has(item.buildingId):
			error = "WALKING_OWNER"; return false
		if not _number(item.get("distance")) or float(item.distance) < 0.0 or item.get("roadCrossingRule") != "mapped_crosswalks_only" or item.get("drivewayRule") != "vehicles_yield_to_pedestrians" or not item.get("crosswalkIds") is Array:
			error = "WALKING_RULE"; return false
		for crosswalk_id in item.crosswalkIds:
			if not crosswalk_id is String or crosswalk_id.is_empty():
				error = "CROSSWALK_ID"; return false
		for point in item.points:
			if not _point(point):
				error = "WALKING_POINT"; return false
		walking[key] = item
	var coverage_ids: Dictionary = {}
	var covered_routes: Dictionary = {}
	for item in doc.coverage:
		if not item is Dictionary or not item.get("buildingId") is String or item.buildingId.is_empty() or coverage_ids.has(item.buildingId):
			error = "COVERAGE_ID"; return false
		coverage_ids[item.buildingId] = true
		if item.get("status") == "served":
			if not item.get("lotId") is String or not _number(item.get("walkingDistance")):
				error = "COVERAGE_ROUTE"; return false
			var key: String = JSON.stringify([item.lotId, item.buildingId])
			if not walking.has(key) or covered_routes.has(key) or not is_equal_approx(float(item.walkingDistance), float((walking[key] as Dictionary).distance)):
				error = "COVERAGE_ROUTE"; return false
			covered_routes[key] = true
		elif item.get("status") != "uncovered" or item.has("lotId"):
			error = "COVERAGE_STATUS"; return false
	if covered_routes.size() != walking.size():
		error = "COVERAGE_COUNT"; return false
	for lot in lots.values():
		for building_id in lot.served_building_ids:
			if not covered_routes.has(JSON.stringify([lot.id, building_id])):
				error = "SERVED_BUILDING"; return false
	var surfaces: Array = []
	for item in doc.surface_rects_source_m:
		if not _rect(item):
			error = "SURFACE"; return false
		surfaces.append(item)
	var signs: Dictionary = {}
	var sign_kinds := {"parking": 0, "yield": 0}
	for item in doc.signs_source_m:
		if not item is Dictionary or not item.get("id") is String or not item.get("lotId") is String or not lots.has(item.lotId) or item.id != item.lotId + ":" + String(item.get("kind", "")) or item.get("kind") not in ["parking", "yield"] or signs.has(item.id) or not _point(item) or not _number(item.get("y")) or not _number(item.get("yaw")):
			error = "SIGN"; return false
		signs[item.id] = item
		sign_kinds[item.kind] += 1
	if sign_kinds.parking != SOURCE_LOTS or sign_kinds.yield != SOURCE_SIGNS - SOURCE_LOTS:
		error = "SIGN_KINDS"; return false
	var sign_colliders: Array = []
	var collider_ids: Dictionary = {}
	for item in doc.sign_colliders_source_grid:
		if not item is Dictionary or not signs.has(item.get("id")) or collider_ids.has(item.id) or item.get("source") != "city_parking" or not _number(item.get("minYM")) or not _number(item.get("maxYM")) or not _number(item.get("groundRadius")) or float(item.maxYM) <= float(item.minYM) or float(item.groundRadius) <= 0.0 or not item.get("polygonCR") is Array or item.polygonCR.size() != 8:
			error = "SIGN_COLLIDER"; return false
		var sign: Dictionary = signs[item.id]
		for pair in item.polygonCR:
			if not pair is Array or pair.size() != 2 or not _number(pair[0]) or not _number(pair[1]) or absf(float(pair[0]) * float(doc.metres_per_cell) - float(sign.x)) > float(item.groundRadius) + 0.000001 or absf(float(pair[1]) * float(doc.metres_per_cell) - float(sign.z)) > float(item.groundRadius) + 0.000001:
				error = "SIGN_POLYGON"; return false
		collider_ids[item.id] = true
		sign_colliders.append(item)
	if collider_ids.size() != signs.size():
		error = "SIGN_COLLIDER_COUNT"; return false
	_lots = lots; _walking = walking; _surfaces = surfaces; _signs = signs; _sign_colliders = sign_colliders; _document = doc
	return true

func lot(id: String) -> Dictionary:
	return (_lots.get(id, {}) as Dictionary).duplicate(true)

func entry_paths_native(lot_id: String) -> Array:
	var source: Dictionary = _lots.get(lot_id, {})
	if source.is_empty(): return []
	var result: Array = []
	for path in source.entry_paths_source_m:
		var converted: Array = []
		for point in path:
			converted.append({"position_m": Vector3(point.x, source.ground_y_m, point.z), "yaw_rad": wrapf(float(point.yaw) + PI, -PI, PI)})
		result.append(converted)
	return result

func walking_route(lot_id: String, building_id: String) -> Dictionary:
	return (_walking.get(JSON.stringify([lot_id, building_id]), {}) as Dictionary).duplicate(true)

func sign(id: String) -> Dictionary:
	return (_signs.get(id, {}) as Dictionary).duplicate(true)

func sign_colliders_native() -> Array:
	var result: Array = []
	if _document.is_empty(): return result
	var scale: float = float(_document.metres_per_cell)
	for item in _sign_colliders:
		var vertices: Array[Vector3] = []
		for pair in item.polygonCR:
			vertices.append(Vector3(float(pair[0]) * scale, float(item.minYM), float(pair[1]) * scale))
			vertices.append(Vector3(float(pair[0]) * scale, float(item.maxYM), float(pair[1]) * scale))
		result.append({"id": item.id, "source": item.source, "vertices_m": vertices})
	return result

func source_surface_contains(x: float, z: float) -> bool:
	if not is_finite(x) or not is_finite(z): return false
	for rect in _surfaces:
		if x >= rect.minX - 0.0000001 and x <= rect.maxX + 0.0000001 and z >= rect.minZ - 0.0000001 and z <= rect.maxZ + 0.0000001: return true
	return false

func stats() -> Dictionary:
	return {"lots": _lots.size(), "bays": SOURCE_BAYS if not _lots.is_empty() else 0, "walking_routes": _walking.size(), "surface_rects": _surfaces.size(), "signs": _signs.size(), "sign_colliders": _sign_colliders.size()}

func _valid_lot(lot: Dictionary) -> bool:
	if not lot.get("id") is String or not lot.get("building_id") is String or lot.id != "parking:" + lot.building_id: return false
	if lot.get("kind") not in ["hospital", "residential"] or lot.get("layout") not in ["parallel", "perpendicular"]: return false
	if lot.get("exit_rule") != "yield_to_road_and_pedestrians" or not _number(lot.get("ground_y_m")): return false
	if not lot.get("bay_ids") is Array or lot.bay_ids.is_empty() or not lot.get("entry_paths_source_m") is Array or lot.entry_paths_source_m.is_empty(): return false
	if not lot.get("served_building_ids") is Array or not _rect(lot.get("lot_rect_source_m")) or not _rect(lot.get("driveway_rect_source_m")): return false
	for path in lot.entry_paths_source_m:
		if not path is Array or path.size() < 2: return false
		for point in path:
			if not _point(point) or not _number(point.get("yaw")): return false
	for bay_id in lot.bay_ids:
		if not bay_id is String or not bay_id.begins_with(lot.id + ":bay:"): return false
	return true

func _point(value: Variant) -> bool:
	return value is Dictionary and _number(value.get("x")) and _number(value.get("z"))

func _rect(value: Variant) -> bool:
	return value is Dictionary and _number(value.get("minX")) and _number(value.get("maxX")) and _number(value.get("minZ")) and _number(value.get("maxZ")) and value.minX <= value.maxX and value.minZ <= value.maxZ

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
