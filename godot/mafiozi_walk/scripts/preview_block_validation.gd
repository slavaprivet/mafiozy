extends RefCounted
## One-time admission for the curated preview-block/v1 format.
## validate is pure. prepare_assets loads each distinct scene once and returns
## no scene map if ANY resource fails. Neither API creates scene-tree nodes.

const SCHEMA: String = "mafiozi.godot.preview-block/v1"
const SurfaceMaterials = preload("res://scripts/preview_surface_materials.gd")
const MAX_ASSETS: int = 256
const MAX_COLLIDERS: int = 1024
const MAX_SIDE: int = 128


static func validate(data: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not data is Dictionary:
		return PackedStringArray(["block: expected dictionary"])
	if data.get("schema") != SCHEMA:
		errors.append("schema: unsupported preview block version")
	if not _vector(data.get("originM"), 3):
		errors.append("originM: expected three finite coordinates")
	if not _number(data.get("metresPerCell"), 0.001, 100.0):
		errors.append("metresPerCell: expected positive finite cell size")
	var surface_cells: int = _surface(data.get("surface"), data.get("metresPerCell"), errors)
	var ids: Dictionary = {}
	var paths: Dictionary = {}
	var collider_count: int = 0
	var asset_count: int = 0
	for category: String in ["buildings", "decor"]:
		var records: Variant = data.get(category)
		if not records is Array or records.size() > MAX_ASSETS:
			errors.append(category + ": expected bounded array")
			continue
		asset_count += records.size()
		if asset_count > MAX_ASSETS:
			errors.append("assets: total exceeds 256")
			return errors
		for index: int in range(records.size()):
			collider_count += _asset(records[index], "%s[%d]" % [category, index], ids, paths, data.get("originM"), errors)
			if collider_count > MAX_COLLIDERS:
				errors.append("colliders: total exceeds 1024")
				return errors
	if asset_count < 1 or asset_count > MAX_ASSETS:
		errors.append("assets: total must be 1..256")
	if collider_count > MAX_COLLIDERS:
		errors.append("colliders: total exceeds 1024")
	if not _id(data.get("anchorId")) or not ids.has(data.get("anchorId")):
		errors.append("anchorId: must name an exported asset")
	var hero: Variant = data.get("hero")
	if not hero is Dictionary:
		errors.append("hero: expected dictionary")
	else:
		if not _path(hero.get("path")):
			errors.append("hero.path: expected local authored scene path")
		else:
			paths[hero["path"]] = true
		if not _vector(hero.get("spawnLocalM"), 3) or not _number(hero.get("targetHeightM"), 0.1, 10.0) or not _number(hero.get("spawnClearanceRadiusM"), 0.01, 10.0):
			errors.append("hero: invalid spawn or body dimensions")
	var counts: Variant = data.get("counts")
	if not counts is Dictionary:
		errors.append("counts: expected dictionary")
	else:
		for key: String in ["buildings", "decor"]:
			var records: Variant = data.get(key)
			if records is Array and (not _integer(counts.get(key), 0, MAX_ASSETS) or int(counts[key]) != records.size()):
				errors.append("counts." + key + ": does not match actual records")
		for pair: Array in [["collisionBodies", collider_count], ["uniqueGlbs", paths.size()], ["surfaceCells", surface_cells]]:
			if not _integer(counts.get(pair[0]), 0, MAX_SIDE * MAX_SIDE) or int(counts[pair[0]]) != int(pair[1]):
				errors.append("counts." + str(pair[0]) + ": does not match actual content")
	return errors


static func prepare_assets(data: Variant, scene_loader: Callable = Callable()) -> Dictionary:
	var errors: PackedStringArray = validate(data)
	if not errors.is_empty():
		return {"errors": errors, "scenes": {}}
	var paths: Dictionary = {str(data["hero"]["path"]): true}
	for record: Dictionary in data["buildings"] + data["decor"]:
		paths[str(record["path"])] = true
	var scenes: Dictionary = {}
	for path: String in paths:
		# Optional loader is a test seam for failed imports, not a second policy.
		var resource: Variant = null
		if scene_loader.is_valid():
			resource = scene_loader.call(path)
		elif ResourceLoader.exists(path, "PackedScene"):
			resource = ResourceLoader.load(path, "PackedScene")
		else:
			errors.append("resource missing or unrecognized: " + path)
			continue
		if not resource is PackedScene or not resource.can_instantiate():
			errors.append("resource failed PackedScene import: " + path)
			continue
		var state: SceneState = resource.get_state()
		var root_type: String = str(state.get_node_type(0)) if state.get_node_count() > 0 else ""
		if root_type != "Node3D" and not ClassDB.is_parent_class(root_type, "Node3D"):
			errors.append("resource root must be Node3D: " + path)
			continue
		scenes[path] = resource
	# A successfully loaded subset must never be mistaken for a complete block.
	return {"errors": errors, "scenes": scenes if errors.is_empty() else {}}


static func _asset(record: Variant, label: String, ids: Dictionary, paths: Dictionary, origin: Variant, errors: PackedStringArray) -> int:
	if not record is Dictionary:
		errors.append(label + ": expected dictionary")
		return 0
	var id: Variant = record.get("id")
	if not _id(id):
		errors.append(label + ".id: expected stable node-safe ID")
	elif ids.has(id):
		errors.append(label + ".id: duplicate ID " + str(id))
	else:
		ids[id] = true
	if not _path(record.get("path")):
		errors.append(label + ".path: expected res://assets scene without traversal")
	else:
		paths[record["path"]] = true
	if not _vector(record.get("positionLocalM"), 3):
		errors.append(label + ".positionLocalM: invalid coordinates")
	var transform: Variant = record.get("transform")
	if not transform is Dictionary:
		errors.append(label + ".transform: expected dictionary")
	else:
		if not _vector(transform.get("positionM"), 3) or not _vector(transform.get("modelLocalOffsetM"), 3):
			errors.append(label + ".transform: invalid position or local offset")
		if not _number(transform.get("yawDegrees"), -36000, 36000) or not _number(transform.get("uniformScale"), 0.0001, 100.0):
			errors.append(label + ".transform: invalid yaw or uniform scale")
		var horizontal: Variant = transform.get("horizontalScale")
		if not _vector(horizontal, 2) or not _number(horizontal[0], 0.0001, 100.0) or not _number(horizontal[1], 0.0001, 100.0):
			errors.append(label + ".transform.horizontalScale: expected two positive scales")
		if _vector(origin, 3) and _vector(transform.get("positionM"), 3) and _vector(record.get("positionLocalM"), 3):
			for axis: int in range(3):
				if absf(float(transform["positionM"][axis]) - float(origin[axis]) - float(record["positionLocalM"][axis])) > 0.0001:
					errors.append(label + ": local position disagrees with source origin")
					break
	var helpers: Variant = record.get("effectiveHiddenNodeNames", [])
	if not helpers is Array or helpers.size() > 128:
		errors.append(label + ".effectiveHiddenNodeNames: invalid helper list")
	else:
		for helper: Variant in helpers:
			if not helper is String or helper.is_empty() or helper.length() > 128:
				errors.append(label + ".effectiveHiddenNodeNames: invalid helper name")
				break
	var bodies: Variant = record.get("collisionBodiesM")
	if not bodies is Array or bodies.size() > 128:
		errors.append(label + ".collisionBodiesM: expected bounded array")
		return 0
	for index: int in range(bodies.size()):
		var body: Variant = bodies[index]
		var body_label: String = label + ".collisionBodiesM[%d]" % index
		if not body is Dictionary:
			errors.append(body_label + ": expected dictionary")
			continue
		if not _number(body.get("minY"), -100000, 100000) or not _number(body.get("maxY"), -100000, 100000) or float(body["maxY"]) <= float(body["minY"]):
			errors.append(body_label + ": invalid finite height bounds")
		if not _convex_polygon(body.get("polygonXZ")):
			errors.append(body_label + ": expected finite simple convex polygon")
	return bodies.size()


static func _surface(surface: Variant, cell_size: Variant, errors: PackedStringArray) -> int:
	if not surface is Dictionary:
		errors.append("surface: expected dictionary")
		return 0
	for key: String in ["rows", "cols"]:
		if not _integer(surface.get(key), 1, MAX_SIDE):
			errors.append("surface." + key + ": expected bounded dimension")
	for key: String in ["startRow", "startCol"]:
		if not _integer(surface.get(key), 0, 100000):
			errors.append("surface." + key + ": expected nonnegative integer")
	for axis: Array in [["startRow", "rows", "sourceMapRows"], ["startCol", "cols", "sourceMapCols"]]:
		if not _integer(surface.get(axis[2]), 1, 100000):
			errors.append("surface." + str(axis[2]) + ": invalid source map dimension")
		elif _integer(surface.get(axis[0]), 0, 100000) and _integer(surface.get(axis[1]), 1, MAX_SIDE):
			if int(surface[axis[0]]) + int(surface[axis[1]]) > int(surface[axis[2]]):
				errors.append("surface: crop extends outside source map")
	if not _number(surface.get("cellSize"), 0.001, 100.0) or not _number(cell_size, 0.001, 100.0) or absf(float(surface["cellSize"]) - float(cell_size)) > 0.000001:
		errors.append("surface.cellSize: invalid or mismatched world scale")
	_material_descriptors(surface.get("materialDescriptors", []), errors)
	var palette: Variant = surface.get("palette")
	var grid: Variant = surface.get("grid")
	if not palette is Dictionary or palette.is_empty() or palette.size() > 32:
		errors.append("surface.palette: expected bounded palette")
		return 0
	var kinds: Dictionary = {}
	for key: Variant in palette:
		var item: Variant = palette[key]
		if not key is String or not key.is_valid_int() or not item is Dictionary:
			errors.append("surface.palette: invalid key or descriptor")
			continue
		if not _id(item.get("kind")) or kinds.has(item.get("kind")):
			errors.append("surface.palette: missing or duplicate node-safe material kind")
		else:
			kinds[item["kind"]] = true
		if not item.get("solid") is bool or not _number(item.get("heightM"), -100000, 100000):
			errors.append("surface.palette: invalid height or solid flag")
		if not item.get("colorSrgb") is String or not Color.html_is_valid(str(item["colorSrgb"])):
			errors.append("surface.palette: invalid sRGB colour")
		if key == "16" and item.get("solid") != false:
			errors.append("surface.palette: water tile 16 must not become solid land")
	if not grid is Array or grid.is_empty() or grid.size() > MAX_SIDE:
		errors.append("surface.grid: expected bounded nonempty row array")
		return 0
	if grid.size() != surface.get("rows"):
		errors.append("surface.grid: row count differs from declared rows")
	var cells: int = 0
	for row: Variant in grid:
		if not row is Array or row.is_empty() or row.size() > MAX_SIDE:
			errors.append("surface.grid: invalid row")
			continue
		if row.size() != surface.get("cols"):
			errors.append("surface.grid: ragged or mismatched columns")
		cells += row.size()
		for tile: Variant in row:
			if not _integer(tile, 0, 255) or not palette.has(str(int(tile))):
				errors.append("surface.grid: tile has no valid palette entry")
				break
			if not SurfaceMaterials.TILE_KIND.has(int(tile)):
				errors.append("surface.grid: unsupported tile in native surface materials: " + str(int(tile)))
				break
	return cells


static func _material_descriptors(descriptors: Variant, errors: PackedStringArray) -> void:
	# Absence/[] keeps the existing native-palette fallback. A supplied descriptor
	# must be complete and valid; it must not fail later during scene construction.
	if not descriptors is Array or descriptors.size() > 128:
		errors.append("surface.materialDescriptors: expected bounded descriptor array")
		return
	var ids: Dictionary = {}
	for index: int in range(descriptors.size()):
		var descriptor: Variant = descriptors[index]
		var label: String = "surface.materialDescriptors[%d]" % index
		if not descriptor is Dictionary:
			errors.append(label + ": expected dictionary")
			continue
		if not _id(descriptor.get("id")):
			errors.append(label + ".id: expected stable material ID")
		elif ids.has(descriptor["id"]):
			errors.append(label + ".id: duplicate material ID " + str(descriptor["id"]))
		else:
			ids[descriptor["id"]] = true
		if descriptor.has("sourceAssetId") and not _id(descriptor["sourceAssetId"]):
			errors.append(label + ".sourceAssetId: invalid source asset ID")
		if descriptor.get("colorSpace") != "linear_srgb":
			errors.append(label + ".colorSpace: expected linear_srgb")
		var factor: Variant = descriptor.get("baseColorFactor")
		if not factor is Array or factor.size() != 4:
			errors.append(label + ".baseColorFactor: expected four finite linear RGBA channels")
		else:
			for channel: Variant in factor:
				if not _number(channel, 0.0, 1.0):
					errors.append(label + ".baseColorFactor: channel outside finite 0..1 range")
					break
		for field: String in ["roughnessFactor", "metallicFactor"]:
			if not _number(descriptor.get(field), 0.0, 1.0):
				errors.append(label + "." + field + ": expected finite 0..1 value")
		if not descriptor.get("doubleSided") is bool:
			errors.append(label + ".doubleSided: expected boolean")


static func _convex_polygon(value: Variant) -> bool:
	if not value is Array or value.size() < 3 or value.size() > 32:
		return false
	var points: PackedVector2Array = []
	for point: Variant in value:
		if not _vector(point, 2):
			return false
		var next: Vector2 = Vector2(float(point[0]), float(point[1]))
		for previous: Vector2 in points:
			if next.distance_squared_to(previous) < 0.0000000001:
				return false
		points.append(next)
	var orientation: float = 0.0
	var area: float = 0.0
	for index: int in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		var c: Vector2 = points[(index + 2) % points.size()]
		area += a.cross(b)
		var turn: float = (b - a).cross(c - b)
		if absf(turn) > 0.0000001:
			if orientation != 0.0 and signf(turn) != orientation:
				return false
			orientation = signf(turn)
		for other: int in range(index + 2, points.size()):
			if index == 0 and other == points.size() - 1:
				continue
			if Geometry2D.segment_intersects_segment(a, b, points[other], points[(other + 1) % points.size()]) != null:
				return false
	return orientation != 0.0 and absf(area) > 0.0000001


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floorf(float(value))


static func _vector(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for coordinate: Variant in value:
		if not _number(coordinate, -1000000.0, 1000000.0):
			return false
	return true


static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128 and value == value.strip_edges() and value.validate_node_name() == value


static func _path(value: Variant) -> bool:
	return value is String and value.begins_with("res://assets/") and value.length() <= 512 and not ".." in value and not "\\" in value and not "?" in value and not "#" in value and value.get_extension().to_lower() in ["glb", "gltf", "tscn", "scn"]
