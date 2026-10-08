extends RefCounted
## Source: exploration_minimap.mjs kinds, BUILDING_MAP_KINDS,
## drawBuildingIcon and selectMapPOIs. The source catalog has 27 categories.
const MapProjection = preload("res://addons/walk_minimap/map_projection.gd")

const KINDS: Dictionary = {
	"parking": {"name": "Парковки", "color": "#76a4c1", "symbol": "P"},
	"station": {"name": "Станции", "color": "#f0c77d", "symbol": "Ж"},
	"railway": {"name": "Железная дорога", "color": "#514e43", "symbol": ""},
	"train": {"name": "Поезд", "color": "#cf875f", "symbol": ""},
	"bank": {"name": "Банк", "color": "#bd9c59", "symbol": "Б"},
	"police": {"name": "Полиция", "color": "#70a0b0", "symbol": "П"},
	"hospital": {"name": "Больница", "color": "#d9ece1", "symbol": ""},
	"shop": {"name": "Магазин", "color": "#c8ae83", "symbol": ""},
	"gunshop": {"name": "Оружейный", "color": "#bb957d", "symbol": ""},
	"pawnshop": {"name": "Ломбард", "color": "#cab17a", "symbol": ""},
	"printshop": {"name": "Типография", "color": "#d8d3b3", "symbol": ""},
	"nightclub": {"name": "Ночной клуб", "color": "#ab92ae", "symbol": ""},
	"stripclub": {"name": "Стрип-клуб", "color": "#c597a0", "symbol": ""},
	"bookmaker": {"name": "Букмекер", "color": "#adbc87", "symbol": ""},
	"residential": {"name": "Жилой дом", "color": "#cec3a9", "symbol": ""},
	"civic": {"name": "Общественный зал", "color": "#dfd1b4", "symbol": ""},
	"building": {"name": "Здания", "color": "#c9bea7", "symbol": ""},
	"tree": {"name": "Деревья", "color": "#426958", "symbol": ""},
	"forest": {"name": "Лес", "color": "#6e8d68", "symbol": "♠"},
	"water": {"name": "Вода", "color": "#69afb5", "symbol": "≈"},
	"mountain": {"name": "Горы", "color": "#baa88a", "symbol": "▲"},
	"fountain": {"name": "Фонтаны", "color": "#8fcccc", "symbol": "○"},
	"monument": {"name": "Памятники", "color": "#d3b672", "symbol": "◆"},
	"bench": {"name": "Скамейки", "color": "#b89970", "symbol": ""},
	"lamp": {"name": "Фонари", "color": "#d9ca95", "symbol": ""},
	"landmark": {"name": "Места", "color": "#d7b572", "symbol": "◆"},
	"object": {"name": "Декор", "color": "#baaa8b", "symbol": ""},
}
const BUILDING_MAP_KINDS: Array[String] = [
	"bank", "police", "hospital", "shop", "gunshop", "pawnshop", "printshop",
	"nightclub", "stripclub", "bookmaker", "residential", "civic", "building",
]
const POI_KINDS: Array[String] = ["station", "monument", "fountain", "mountain", "forest", "landmark", "water"]
const DEFAULT_PRIORITIES: Dictionary = {
	"station": 120, "mountain": 105, "forest": 100, "water": 95,
	"landmark": 85, "police": 55, "monument": 45, "fountain": 40, "bank": 25,
}
const ICON_INK: Color = Color("#183237")
const ICON_STROKE: float = 1.55

static func kind_color(kind: String) -> Color:
	var entry: Dictionary = KINDS.get(kind, KINDS["object"])
	return Color(String(entry["color"]))

static func kind_name(kind: String) -> String:
	var entry: Dictionary = KINDS.get(kind, KINDS["object"])
	return String(entry["name"])

static func _source_truthy(value: Variant) -> bool:
	# JavaScript truthiness, including truthy empty containers and falsy NaN.
	if value == null:
		return false
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return float(value) != 0.0 and not is_nan(float(value))
	if value is String:
		return not String(value).is_empty()
	return true

static func select_pois(objects: Array) -> Array:
	var ids: Dictionary = {}
	var result: Array = []
	for raw: Variant in objects:
		if not MapProjection.valid_point(raw):
			continue
		var object: Dictionary = raw
		var kind: String = str(object.get("kind", ""))
		if not _source_truthy(object.get("name")):
			continue
		if not (_source_truthy(object.get("poi")) or kind in BUILDING_MAP_KINDS or kind in POI_KINDS):
			continue
		var object_id: Variant = object.get("id")
		if _source_truthy(object_id):
			if ids.has(object_id):
				continue
			ids[object_id] = true
		result.append(object)
	var counts: Dictionary = {}
	for object: Dictionary in result:
		var object_name: Variant = object["name"]
		counts[object_name] = int(counts.get(object_name, 0)) + 1
	var ranked: Array[Dictionary] = []
	for index: int in range(result.size()):
		var object: Dictionary = result[index]
		var priority: Variant = object.get("mapPriority")
		var score: float = float(priority) if MapProjection.finite_number(priority) else float(DEFAULT_PRIORITIES.get(object.get("kind"), 20))
		if int(counts[object["name"]]) > 1:
			score -= 25.0
		ranked.append({"object": object, "index": index, "score": score})
	# Explicit index tie-break preserves source order despite an unstable sort.
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["score"]) == float(b["score"]):
			return int(a["index"]) < int(b["index"])
		return float(a["score"]) > float(b["score"])
	)
	result.clear()
	for entry: Dictionary in ranked:
		result.append(entry["object"])
	return result

static func _line(canvas: Control, at: Vector2, scale_factor: float, vertices: Array) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Array in vertices:
		points.append(at + Vector2(float(vertex[0]), float(vertex[1])) * scale_factor)
	var width: float = ICON_STROKE * scale_factor
	canvas.draw_polyline(points, ICON_INK, width, true)
	# Canvas source uses round joins and caps. Godot's polyline does not supply
	# those, so round disks complete the same stroke geometry at every vertex.
	for point: Vector2 in points:
		canvas.draw_circle(point, width * 0.5, ICON_INK, true, -1.0, true)

static func _fill_rect(canvas: Control, at: Vector2, scale_factor: float, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(at + rect.position * scale_factor, rect.size * scale_factor), ICON_INK)

static func _stroke_rect(canvas: Control, at: Vector2, scale_factor: float, rect: Rect2) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	_line(canvas, at, scale_factor, [[x, y], [right, y], [right, bottom], [x, bottom], [x, y]])

static func _circle(canvas: Control, at: Vector2, scale_factor: float, center: Vector2, radius: float) -> void:
	canvas.draw_arc(at + center * scale_factor, radius * scale_factor, 0.0, TAU, 64, ICON_INK, ICON_STROKE * scale_factor, true)

static func draw_building_icon(canvas: Control, kind: String, at: Vector2, size: float) -> void:
	if size <= 0.0 or not is_finite(size):
		return
	var s: float = size / 12.0
	match kind:
		"bank", "civic":
			_line(canvas, at, s, [[-5, -2], [0, -5], [5, -2], [-5, -2]])
			_line(canvas, at, s, [[-5, 5], [5, 5]])
			for x: int in [-3, 0, 3]:
				_line(canvas, at, s, [[x, -1], [x, 3]])
		"hospital":
			_fill_rect(canvas, at, s, Rect2(-1.6, -5, 3.2, 10))
			_fill_rect(canvas, at, s, Rect2(-5, -1.6, 10, 3.2))
		"police":
			_line(canvas, at, s, [[-4, -4], [0, -5], [4, -4], [4, 1], [0, 5], [-4, 1], [-4, -4]])
			_line(canvas, at, s, [[0, -2], [0, 2], [-2, 0], [2, 0]])
		"residential", "building":
			_line(canvas, at, s, [[-5, -1], [0, -5], [5, -1]])
			_line(canvas, at, s, [[-3, -1], [-3, 5], [3, 5], [3, -1]])
			_line(canvas, at, s, [[-1, 5], [-1, 1], [1, 1], [1, 5]])
		"shop":
			_stroke_rect(canvas, at, s, Rect2(-4, -1, 8, 6))
			_line(canvas, at, s, [[-2, -1], [-2, -4], [2, -4], [2, -1]])
		"gunshop":
			_line(canvas, at, s, [[-5, -3], [5, -3], [5, -1], [0, -1], [0, 1], [-2, 1], [-2, 5], [-4, 5], [-3, -1], [-5, -1], [-5, -3]])
		"pawnshop":
			_line(canvas, at, s, [[-5, -1], [-2, -4], [2, -4], [5, -1], [0, 5], [-5, -1], [5, -1]])
			_line(canvas, at, s, [[-2, -4], [0, 5], [2, -4]])
		"printshop":
			_stroke_rect(canvas, at, s, Rect2(-3, -5, 6, 10))
			for y: int in [-2, 1, 3]:
				_line(canvas, at, s, [[-1, y], [2, y]])
		"nightclub":
			_line(canvas, at, s, [[0, 3], [0, -4], [4, -5], [4, 2]])
			_circle(canvas, at, s, Vector2(-2, 3), 1.7)
			_circle(canvas, at, s, Vector2(2, 3), 1.7)
		"stripclub":
			_line(canvas, at, s, [[0, -5], [1.5, -1.5], [5, -1.5], [2, 1], [3, 5], [0, 2.5], [-3, 5], [-2, 1], [-5, -1.5], [-1.5, -1.5], [0, -5]])
		"bookmaker":
			_stroke_rect(canvas, at, s, Rect2(-4, -5, 8, 10))
			_fill_rect(canvas, at, s, Rect2(-2, -3, 1.5, 1.5))
			_fill_rect(canvas, at, s, Rect2(1, 1, 1.5, 1.5))
			_line(canvas, at, s, [[-2, 3], [2, -1]])
