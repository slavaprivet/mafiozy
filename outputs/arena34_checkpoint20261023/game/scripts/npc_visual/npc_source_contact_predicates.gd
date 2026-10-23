extends RefCounted
## Actual source point polygon / trafficActorBlocks / railway.blocks predicates.
## Scalar Float64 only. No actor, geometry snapshot, admission or authority creation.
## Caller supplies the verified original snapshot; this mathematical port is not it.

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _unknown(error: String) -> Dictionary:
	return {"known": false, "error": error, "physical_admission": false}

static func _answer(blocked: bool) -> Dictionary:
	return {"known": true, "blocked": blocked, "physical_admission": false}

static func contains_polygon(polygon: Array, c: float, r: float) -> Dictionary:
	if not is_finite(c) or not is_finite(r) or polygon.size() > 4096: return _unknown("polygon_input")
	for point: Variant in polygon:
		if not point is Array or point.size() != 2 or not _finite(point[0]) or not _finite(point[1]): return _unknown("polygon_input")
	return _answer(_contains(polygon, c, r))

static func _contains(polygon: Array, c: float, r: float) -> bool:
	var inside := false
	var j := polygon.size() - 1
	for i in polygon.size():
		var a: Array = polygon[i]; var b: Array = polygon[j]
		if (a[1] > r) != (b[1] > r) and c < (b[0] - a[0]) * (r - a[1]) / (b[1] - a[1]) + a[0]: inside = not inside
		j = i
	return inside

static func vehicle_blocks(record: Dictionary, x: float, z: float, y: float, height: float = 1.9) -> Dictionary:
	# Initial-placement source always probes radius0 and supplies finite support.
	# Records normalize *evaluated* source bounds fallbacks in the exporter; no
	# absent source profile/dimensions are guessed here.
	if not is_finite(x) or not is_finite(z) or not is_finite(y) or not is_finite(height): return _unknown("vehicle_query")
	if not record.get("visible") is bool: return _unknown("vehicle_visibility")
	if not record.visible: return _answer(false)
	for key: String in ["x", "y", "z", "yaw", "scale_x", "scale_y", "scale_z", "half_width", "half_length", "bounds_min_y", "bounds_max_y"]:
		if not _finite(record.get(key)): return _unknown("vehicle_snapshot:" + key)
	if record.half_width < 0.0 or record.half_length < 0.0: return _unknown("vehicle_dimensions")
	var half_width: float = record.half_width * absf(record.scale_x)
	var half_length: float = record.half_length * absf(record.scale_z)
	var reach := half_width + half_length
	if absf(x - record.x) > reach or absf(z - record.z) > reach: return _answer(false)
	var low: float = record.y + record.bounds_min_y * record.scale_y
	var high: float = record.y + record.bounds_max_y * record.scale_y
	if y + maxf(0.0, height) < minf(low, high) or y > maxf(low, high): return _answer(false)
	var sine: float = sin(record.yaw); var cosine: float = cos(record.yaw)
	var polygon: Array = []
	for point: Array in [[-half_width, -half_length], [half_width, -half_length], [half_width, half_length], [-half_width, half_length]]:
		polygon.append([record.x + point[0] * cosine + point[1] * sine, record.z - point[0] * sine + point[1] * cosine])
	# Original collisionCircleOverlap at radius0: squared-edge distance < 0
	# cannot accept anything, so exact source ray crossing decides the result.
	var inside := false
	var j := polygon.size() - 1
	for i in polygon.size():
		# collisionCircleOverlap visits a=poly[j], b=poly[i], unlike
		# pointInPolygon. Preserve expression direction near exact boundaries.
		var a: Array = polygon[j]; var b: Array = polygon[i]
		if (a[1] > z) != (b[1] > z) and x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]: inside = not inside
		j = i
	return _answer(inside)

static func train_blocks(cars: Array, x: float, z: float) -> Dictionary:
	if not is_finite(x) or not is_finite(z) or cars.size() > 65536: return _unknown("train_query")
	# Validate every record before evaluating; an early hit cannot certify an
	# incomplete snapshot. The original snapshot itself is caller-owned proof.
	for car: Variant in cars:
		if not car is Dictionary: return _unknown("train_snapshot")
		for key: String in ["x", "z", "tx", "tz", "length", "width"]:
			if not _finite(car.get(key)): return _unknown("train_snapshot:" + key)
		if car.length < 0.0 or car.width < 0.0: return _unknown("train_dimensions")
	for car: Dictionary in cars:
		var dx: float = x - car.x; var dz: float = z - car.z
		if absf(dx * car.tx + dz * car.tz) < car.length / 2.0 and absf(-dx * car.tz + dz * car.tx) < car.width / 2.0: return _answer(true)
	return _answer(false)
