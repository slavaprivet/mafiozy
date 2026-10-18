extends RefCounted
const MapProjection = preload("res://addons/walk_minimap/map_projection.gd")
const ROUTE_POINT_LIMIT := 4096
var _waypoint: Variant = null
var _route: Variant = null
var normalizations := 0
var distance_scans := 0

func set_waypoint(value: Variant, bounds: Dictionary) -> Variant:
	_waypoint = MapProjection.bounded_point(value, bounds)
	_route = null
	if _waypoint != null:
		_waypoint.name = value.get("name", "") if value.get("name") is String else ""
		for key in ["id", "kind", "buildingId", "lotId"]:
			if value.has(key) and (value[key] == null or value[key] is String or MapProjection.finite_number(value[key])):
				_waypoint[key] = value[key]
	return get_waypoint()

func get_waypoint() -> Variant:
	return _waypoint.duplicate(true) if _waypoint != null else null

func get_route() -> Variant:
	return _route.duplicate(true) if _route != null else null

func info(position: Variant, yaw := 0.0) -> Variant:
	if not MapProjection.valid_point(position) or _waypoint == null:
		return null
	var delta := MapProjection.point(_waypoint) - MapProjection.point(position)
	var bearing := atan2(delta.x, delta.y)
	return {"distance": delta.length(), "bearing": bearing, "relativeBearing": atan2(sin(bearing - yaw), cos(bearing - yaw)), "arrived": delta.length() < 5.0}

static func route_distance(points: Variant) -> Variant:
	if not points is Array or points.is_empty() or points.size() > ROUTE_POINT_LIMIT:
		return null
	var distance := 0.0
	var previous: Variant = null
	for value in points:
		if not MapProjection.valid_point(value):
			return null
		if previous != null:
			distance += MapProjection.point(previous).distance_to(MapProjection.point(value))
		previous = value
	return distance if is_finite(distance) else null

func set_route(data: Variant) -> Variant:
	normalizations += 1
	if _waypoint == null or data == null:
		_route = null
		return null
	var status := str(data.get("status", "blocked")) if data is Dictionary else "blocked"
	if status != "pending" and status != "ready":
		status = "blocked"
	if status == "ready":
		distance_scans += 1
	var measured: Variant = route_distance(data.get("points")) if status == "ready" else null
	if status == "ready" and measured == null:
		status = "blocked"
	if status != "ready":
		if _route != null and _route.status == status:
			return _route
		_route = {"status": status, "points": [], "distance": null}
	else:
		var declared: Variant = data.get("distance")
		var distance: float = declared if MapProjection.finite_number(declared) and declared >= 0 else measured
		var reuse: bool = _route != null and _route.status == "ready" and _route.points.size() == data.points.size()
		if reuse:
			for i in data.points.size():
				if data.points[i].x != _route.points[i].x or data.points[i].z != _route.points[i].z:
					reuse = false
					break
		if reuse and _route.distance == distance:
			return _route
		var points: Array = []
		if reuse:
			points = _route.points
		else:
			for value in data.points:
				var point := {"x": value.x, "z": value.z}
				point.make_read_only()
				points.append(point)
		_route = {"status": "ready", "points": points, "distance": distance}
	_route.points.make_read_only()
	_route.make_read_only()
	return _route

func status_text(position: Variant) -> String:
	if _waypoint == null:
		return "Нажмите на карту — поставить метку"
	var suffix: String = " · " + _waypoint.name if _waypoint.name else ""
	if _route != null:
		if _route.status == "pending":
			return "Строю маршрут…"
		if _route.status != "ready":
			return "Нет доступного автомобильного пути"
		return "По дороге: %d м%s" % [floori(_route.distance + 0.5), suffix]
	var result: Variant = info(position)
	return "До метки: %d м%s" % [floori(result.distance + 0.5), suffix] if result != null else "Нажмите на карту — поставить метку"

## Host decides removal. Walk checks walking/seat/transition/jump and terrain Y.
static func reached_waypoint(actor: Variant, target: Variant, radius := 1.15, height_tolerance := 0.9) -> bool:
	if not MapProjection.valid_point(actor) or not MapProjection.valid_point(target) or not MapProjection.finite_number(actor.get("y")) or not MapProjection.finite_number(target.get("y")):
		return false
	return MapProjection.point(actor).distance_to(MapProjection.point(target)) <= radius and absf(actor.y - target.y) <= height_tolerance

static func can_auto_remove(actor: Variant, target: Variant, flags: Dictionary) -> bool:
	return flags.get("walking", false) == true and not flags.get("occupiedSeat", false) and not flags.get("transition", false) and not flags.get("jump", false) and reached_waypoint(actor, target)
