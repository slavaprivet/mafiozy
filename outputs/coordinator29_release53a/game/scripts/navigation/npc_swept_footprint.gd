extends RefCounted
## Scalar float64 port of npc_swept_footprint.mjs. Coordinates are source cells:
## endpoints {r,c}, polygon points [c,r]. Only planar overlap, NOT pathfinding.
## One instance per main-thread caller; no reentry from contact callbacks.
const MAX_COORDINATE := 1e12 # Beyond source-world scope; bounds double products.

var _points: Array = []
var _hull: Array = []
var _hull_count := 0
var _min_c := 0.0
var _min_r := 0.0
var _max_c := 0.0
var _max_r := 0.0
var _valid := false
var _busy := false
var _query_fault := false
var last_error := ""

func _init() -> void:
	for i in range(8): _points.append([0.0, 0.0])
	_hull.resize(16)

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and absf(float(value)) <= MAX_COORDINATE

func _endpoint(value: Variant) -> bool:
	return value is Dictionary and _number(value.get("r")) and _number(value.get("c"))

func _enter() -> bool:
	if not Thread.is_main_thread(): return false
	if _busy:
		_query_fault = true
		last_error = "reentrant-access"
		return false
	_busy = true
	_query_fault = false
	last_error = ""
	return true

func _cross(a: Array, b: Array, c: Array) -> float:
	var ax: float = a[0]
	var ay: float = a[1]
	var bx: float = b[0]
	var by: float = b[1]
	var cx: float = c[0]
	var cy: float = c[1]
	return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)

func set_segment(from_rc: Variant, to_rc: Variant, radius: Variant = 0.18) -> bool:
	if not _enter(): return false
	_valid = false
	if not _endpoint(from_rc) or not _endpoint(to_rc) or not _number(radius) or float(radius) < 0.0:
		last_error = "invalid-segment"
		_busy = false
		return false
	var rad := float(radius)
	for i in range(8):
		var endpoint: Dictionary = from_rc if i < 4 else to_rc
		_points[i][0] = float(endpoint.c) + (rad if (i & 1) != 0 else -rad)
		_points[i][1] = float(endpoint.r) + (rad if (i & 2) != 0 else -rad)
		if not is_finite(_points[i][0]) or not is_finite(_points[i][1]):
			last_error = "segment-overflow"
			_busy = false
			return false
	# Eight fixed points: stable insertion sort retains JS sort ordering while
	# avoiding comparator Callable dispatch and allocating no extra point array.
	for i in range(1, 8):
		var point: Array = _points[i]
		var pc: float = point[0]
		var pr: float = point[1]
		var j := i
		while j > 0 and (_points[j - 1][0] > pc or (_points[j - 1][0] == pc and _points[j - 1][1] > pr)):
			_points[j] = _points[j - 1]
			j -= 1
		_points[j] = point
	var k := 0
	for i in range(8):
		while k >= 2 and _cross(_hull[k - 2], _hull[k - 1], _points[i]) <= 0.0: k -= 1
		_hull[k] = _points[i]
		k += 1
	var lower := k + 1
	for i in range(6, -1, -1):
		while k >= lower and _cross(_hull[k - 2], _hull[k - 1], _points[i]) <= 0.0: k -= 1
		_hull[k] = _points[i]
		k += 1
	_hull_count = maxi(1, k - 1)
	_min_c = minf(float(from_rc.c), float(to_rc.c)) - rad
	_max_c = maxf(float(from_rc.c), float(to_rc.c)) + rad
	_min_r = minf(float(from_rc.r), float(to_rc.r)) - rad
	_max_r = maxf(float(from_rc.r), float(to_rc.r)) + rad
	_valid = true
	_busy = false
	return true

func _inside(p: Array, polygon: Array, count: int) -> bool:
	var inside := false
	var j := count - 1
	var px: float = p[0]
	var py: float = p[1]
	for i in range(count):
		var a: Array = polygon[i]
		var b: Array = polygon[j]
		var ax: float = a[0]
		var ay: float = a[1]
		var bx: float = b[0]
		var by: float = b[1]
		if (ay > py) != (by > py) and px < (bx - ax) * (py - ay) / (by - ay) + ax:
			inside = not inside
		j = i
	return inside

func _edges_touch(a: Array, b: Array, c: Array, d: Array) -> bool:
	if maxf(a[0], b[0]) < minf(c[0], d[0]) - 1e-10 or maxf(c[0], d[0]) < minf(a[0], b[0]) - 1e-10 or maxf(a[1], b[1]) < minf(c[1], d[1]) - 1e-10 or maxf(c[1], d[1]) < minf(a[1], b[1]) - 1e-10:
		return false
	return _cross(a, b, c) * _cross(a, b, d) <= 1e-18 and _cross(c, d, a) * _cross(c, d, b) <= 1e-18

func _contact(test_point: Callable, c: float, r: float) -> bool:
	if not test_point.is_valid(): return true
	var result: Variant = test_point.call(c, r)
	if not result is bool:
		_query_fault = true
		last_error = "invalid-contact-result"
	return _query_fault or result == true

func overlaps(polygon: Variant, test_point: Callable = Callable()) -> bool:
	if not _enter(): return true
	var result := _overlaps(polygon, test_point)
	_busy = false
	return result or _query_fault

func _overlaps(polygon: Variant, test_point: Callable) -> bool:
	# Invalid host input fails closed; valid input retains source semantics.
	if not _valid:
		last_error = "segment-not-ready"
		return true
	if polygon == null: return false
	if not polygon is Array:
		last_error = "invalid-polygon"
		return true
	if polygon.is_empty(): return false
	var pc0 := INF
	var pc1 := -INF
	var pr0 := INF
	var pr1 := -INF
	for p: Variant in polygon:
		if not p is Array or p.size() != 2 or not _number(p[0]) or not _number(p[1]):
			last_error = "invalid-polygon"
			return true
		pc0 = minf(pc0, float(p[0]))
		pc1 = maxf(pc1, float(p[0]))
		pr0 = minf(pr0, float(p[1]))
		pr1 = maxf(pr1, float(p[1]))
	if pc1 < _min_c or pc0 > _max_c or pr1 < _min_r or pr0 > _max_r: return false
	for p: Array in polygon:
		if _inside(p, _hull, _hull_count) and _contact(test_point, p[0], p[1]): return true
	for i in range(_hull_count):
		var p: Array = _hull[i]
		if _inside(p, polygon, polygon.size()) and _contact(test_point, p[0], p[1]): return true
	for i in range(_hull_count):
		for j in range(polygon.size()):
			var a: Array = _hull[i]
			var b: Array = _hull[(i + 1) % _hull_count]
			var c: Array = polygon[j]
			var d: Array = polygon[(j + 1) % polygon.size()]
			if not _edges_touch(a, b, c, d): continue
			if not test_point.is_valid(): return true
			var dx: float = b[0] - a[0]
			var dy: float = b[1] - a[1]
			var ex: float = d[0] - c[0]
			var ey: float = d[1] - c[1]
			var den := dx * ey - dy * ex
			if absf(den) > 1e-15:
				var t: float = ((c[0] - a[0]) * ey - (c[1] - a[1]) * ex) / den
				if _contact(test_point, a[0] + t * dx, a[1] + t * dy): return true
			else:
				var x := (maxf(minf(a[0], b[0]), minf(c[0], d[0])) + minf(maxf(a[0], b[0]), maxf(c[0], d[0]))) / 2.0
				var y := (maxf(minf(a[1], b[1]), minf(c[1], d[1])) + minf(maxf(a[1], b[1]), maxf(c[1], d[1]))) / 2.0
				if _contact(test_point, x, y): return true
	return false

func bounds() -> Dictionary:
	return {"valid": _valid, "minC": _min_c, "minR": _min_r, "maxC": _max_c, "maxR": _max_r, "hull_count": _hull_count}
