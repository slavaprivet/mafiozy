extends RefCounted
## Walk coordinates are metres: +X east, +Z south. Map is always north-up.
var center: Vector2
var viewport_size: Vector2
var metres_per_pixel: float

func _init(origin := Vector2.ZERO, dimensions := Vector2(230, 194), scale_m := 1.0) -> void:
	center = origin
	viewport_size = dimensions
	metres_per_pixel = scale_m

func is_valid() -> bool:
	return center.is_finite() and viewport_size.is_finite() and viewport_size.x > 0 and viewport_size.y > 0 and is_finite(metres_per_pixel) and metres_per_pixel > 0

func to_screen(world: Vector2) -> Vector2:
	return (world - center) / metres_per_pixel + viewport_size / 2.0

func to_world(screen: Vector2) -> Vector2:
	return (screen - viewport_size / 2.0) * metres_per_pixel + center

static func valid_point(value: Variant) -> bool:
	return value is Dictionary and finite_number(value.get("x")) and finite_number(value.get("z"))

static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func point(value: Dictionary) -> Vector2:
	return Vector2(value.x, value.z)

static func valid_bounds(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["minX", "maxX", "minZ", "maxZ"]:
		if not finite_number(value.get(key)):
			return false
	return value.maxX > value.minX and value.maxZ > value.minZ

static func bounded_point(value: Variant, bounds: Dictionary) -> Variant:
	if not valid_point(value) or not valid_bounds(bounds):
		return null
	return {"x": clampf(value.x, bounds.minX, bounds.maxX), "z": clampf(value.z, bounds.minZ, bounds.maxZ)}

func marker_position(value: Variant) -> Variant:
	if not valid_point(value):
		return null
	var screen := to_screen(point(value))
	return Vector2(clampf(screen.x, 13, viewport_size.x - 13), clampf(screen.y, 16, viewport_size.y - 16))

func marker_hit(pointer: Vector2, value: Variant, radius := 12.0) -> bool:
	var marker: Variant = marker_position(value)
	return marker != null and pointer.is_finite() and pointer.distance_to(marker) <= radius

static func polygon_points(vertices: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for vertex in vertices:
		if valid_point(vertex):
			result.append(point(vertex))
		elif vertex is Array and vertex.size() >= 2 and finite_number(vertex[0]) and finite_number(vertex[1]):
			result.append(Vector2(vertex[0], vertex[1]))
	return result

static func point_in_polygon(position: Vector2, vertices: Array) -> bool:
	if not position.is_finite():
		return false
	var points := polygon_points(vertices)
	if points.size() < 3:
		return false
	var inside := false
	var previous := points[points.size() - 1]
	for current in points:
		var cross := (current.x - previous.x) * (position.y - previous.y) - (current.y - previous.y) * (position.x - previous.x)
		if absf(cross) < 1e-7 and position.x >= minf(previous.x, current.x) - 1e-8 and position.x <= maxf(previous.x, current.x) + 1e-8 and position.y >= minf(previous.y, current.y) - 1e-8 and position.y <= maxf(previous.y, current.y) + 1e-8:
			return true
		if (current.y > position.y) != (previous.y > position.y) and position.x < (previous.x - current.x) * (position.y - current.y) / (previous.y - current.y) + current.x:
			inside = not inside
		previous = current
	return inside

func object_at(pointer: Vector2, objects: Array) -> Variant:
	var nearest: Variant = null
	var distance := INF
	for object in objects:
		if not valid_point(object) or not object.get("name", ""):
			continue
		var candidate := pointer.distance_to(to_screen(point(object)))
		if candidate <= 12 and candidate < distance:
			nearest = object
			distance = candidate
	if nearest != null:
		return nearest
	for object in objects:
		if object.get("name", "") and point_in_polygon(to_world(pointer), object.get("polygon", [])):
			return object
	return null
