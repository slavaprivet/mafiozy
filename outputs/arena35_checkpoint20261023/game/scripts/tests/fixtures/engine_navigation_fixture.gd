extends Node3D
## HEADLESS TEST FIXTURE ONLY. Current crop collision data, no render resources,
## authoritative actor roster, or production actor births.
var block: Dictionary
var printshop: Dictionary
var faces := PackedVector3Array()
var source_body_count := 0
var printshop_body_count := 0
var dry_cells := 0
var water_cells := 0
var staff_ids: Dictionary = {}
var admission_enabled := true
var _origin := Vector3.ZERO
var _room_frame := Transform3D.IDENTITY

func load_data() -> bool:
	var a: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	var b: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	if not a is Dictionary or not b is Dictionary: return false
	block = a; printshop = b; _origin = vec(block.originM)
	return printshop.sourceId == "REBUILD-VISUAL-print_shop-001"

func vec(values: Array) -> Vector3: return Vector3(values[0], values[1], values[2])
func matrix(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[4], a[5], a[6]), Vector3(a[8], a[9], a[10])), Vector3(a[12], a[13], a[14]))

func space() -> PhysicsDirectSpaceState3D: return get_world_3d().direct_space_state
func anchor(key: String) -> Vector3: return vec(printshop.anchors[key])

func _triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	faces.append(a); faces.append(b); faces.append(c)

func _shape(shape: Shape3D, source_id: String, transform: Transform3D = Transform3D.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("source_id", source_id); body.transform = transform
	var collision := CollisionShape3D.new(); collision.shape = shape
	body.add_child(collision); add_child(body)
	return body

func _prism(polygon: Array, bottom: float, top: float, source_id: String) -> void:
	var outline := PackedVector2Array(); var points := PackedVector3Array()
	for p: Array in polygon:
		outline.append(Vector2(p[0], p[1])); points.append(Vector3(p[0], bottom, p[1])); points.append(Vector3(p[0], top, p[1]))
	var shape := ConvexPolygonShape3D.new(); shape.points = points
	_shape(shape, source_id)
	# Current runtime uses exactly these convex collision bodies. The source
	# polygons in this package are convex; triangulation keeps their outline.
	if Geometry2D.is_polygon_clockwise(outline): outline.reverse()
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[i]]; var b: Vector2 = outline[indices[i + 1]]; var c: Vector2 = outline[indices[i + 2]]
		_triangle(Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(c.x, top, c.y))
		_triangle(Vector3(a.x, bottom, a.y), Vector3(c.x, bottom, c.y), Vector3(b.x, bottom, b.y))
	for i in outline.size():
		var a: Vector2 = outline[i]; var b: Vector2 = outline[(i + 1) % outline.size()]
		_triangle(Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3(b.x, top, b.y))
		_triangle(Vector3(a.x, bottom, a.y), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y))
	source_body_count += 1

func _mesh_floor(spec: Dictionary) -> void:
	var geometry: Dictionary = printshop.geometry[int(spec.geometry)]
	var vertices: Array = geometry.attributes.position.values
	var indices: Array = geometry.indices if geometry.indices != null else range(vertices.size() / 3)
	var instances: Array = spec.get("instances", [])
	if instances.is_empty(): instances = [[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]]
	var triangles := PackedVector3Array()
	for instance: Array in instances:
		var transform := matrix(spec.transform) * matrix(instance)
		for i in range(0, indices.size(), 3):
			# Same Three CCW -> Godot CW conversion as current printshop adapter.
			for j: int in [0, 2, 1]:
				var index := int(indices[i + j]) * 3
				triangles.append(transform * Vector3(vertices[index], vertices[index + 1], vertices[index + 2]))
	faces.append_array(triangles)
	var shape := ConcavePolygonShape3D.new(); shape.set_faces(triangles); shape.backface_collision = true
	_shape(shape, printshop.sourceId + ":" + str(spec.name))

func rebuild(public_fraction: float = 0.0, service_fraction: float = 0.0) -> void:
	for child: Node in get_children(): child.free()
	faces = PackedVector3Array(); source_body_count = 0; printshop_body_count = 0; dry_cells = 0; water_cells = 0
	var surface: Dictionary = block.surface
	var cell: float = surface.cellSize
	for r in int(surface.rows):
		for c in int(surface.cols):
			var tile: int = surface.grid[r][c]; var palette: Dictionary = surface.palette[str(tile)]
			if not palette.solid: water_cells += 1; continue
			# Authored navigation mask is distinct from render/physics tile solidity.
			if not surface.masks.walkableMask[r][c]: continue
			dry_cells += 1
			var x: float = (int(surface.startCol) + c) * cell - _origin.x
			var z: float = (int(surface.startRow) + r) * cell - _origin.z
			var y: float = palette.heightM
			_triangle(Vector3(x, y, z), Vector3(x + cell, y, z), Vector3(x + cell, y, z + cell))
			_triangle(Vector3(x, y, z), Vector3(x + cell, y, z + cell), Vector3(x, y, z + cell))
			var shape := BoxShape3D.new(); shape.size = Vector3(cell, .16, cell)
			_shape(shape, "source-tile:" + str(r) + ":" + str(c), Transform3D(Basis.IDENTITY, Vector3(x + cell * .5, y - .08, z + cell * .5)))
	for records: Array in [block.buildings, block.decor]:
		for record: Dictionary in records:
			if record.id == printshop.sourceId: continue # Replaced by the actual 107 bodies below.
			for body: Dictionary in record.get("collisionBodiesM", []): _prism(body.polygonXZ, body.minY, body.maxY, record.id)
	for body: Dictionary in printshop.staticBodies:
		_prism(body.polygonXZ, body.minY, body.maxY, printshop.sourceId)
		printshop_body_count += 1
	for spec: Dictionary in printshop.meshes:
		if spec.name == "Storey_Walls_And_Ceilings": _room_frame = matrix(spec.transform)
		if spec.floorCollision: _mesh_floor(spec)
	for key: String in printshop.doors:
		var door: Dictionary = printshop.doors[key]
		var fraction := public_fraction if key == "public" else service_fraction
		var angle: float = door.angle * fraction * fraction * (3.0 - 2.0 * fraction)
		var transform := matrix(door.transform) * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
		for body: Dictionary in door.bodies:
			var polygon: Array = []; var bottom := INF; var top := -INF
			for i in range(0, body.pointsLocal.size(), 2):
				var low: Vector3 = transform * vec(body.pointsLocal[i]); var high: Vector3 = transform * vec(body.pointsLocal[i + 1])
				polygon.append([low.x, low.z]); bottom = minf(bottom, low.y); top = maxf(top, high.y)
			_prism(polygon, bottom, top, door.id)
			printshop_body_count += 1

func _tile_allowed(point: Vector3) -> bool:
	var surface: Dictionary = block.surface
	var r := int(floor((point.z + _origin.z) / float(surface.cellSize))) - int(surface.startRow)
	var c := int(floor((point.x + _origin.x) / float(surface.cellSize))) - int(surface.startCol)
	return r >= 0 and c >= 0 and r < int(surface.rows) and c < int(surface.cols) and bool(surface.masks.walkableMask[r][c])

func admit(point: Vector3, source_id: String, generation: int) -> bool:
	if not admission_enabled: return false
	if not source_id.begins_with("fixture:engine-") or generation != 1: return false
	for offset: Vector3 in [Vector3.ZERO, Vector3(-.36, 0, -.36), Vector3(.36, 0, -.36), Vector3(-.36, 0, .36), Vector3(.36, 0, .36)]:
		if not _tile_allowed(point + offset): return false
	# The fixture's explicit permission provider demonstrates the real authored
	# room boundary. It is not a replacement for production source access policy.
	var local := _room_frame.affine_inverse() * point
	var rect: Array = printshop.rooms[1].rect
	if local.x >= rect[0] and local.x <= rect[2] and local.z >= rect[1] and local.z <= rect[3] and not staff_ids.has(source_id): return false
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .45, point - Vector3.UP * .45, 1)
	var hit := space().intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y >= .70 and absf(float(hit.position.y) - point.y) <= .30
