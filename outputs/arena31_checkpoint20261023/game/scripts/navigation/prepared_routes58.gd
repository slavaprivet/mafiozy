extends RefCounted
## DSH_ROUTES58: the prepared pedestrian network.
##
## The graph is DATA, built once from the opened city by scripts/owner58/build_routes58.gd:
## every node is a point where the real capsule was proved to stand, and every edge is a
## straight segment that was proved walkable end to end. Nothing here searches the world or
## invents a connection. The runtime only asks this file for a line between two known points,
## and the walker keeps its physical checks for the first metres, the last metres and any
## obstacle that appeared after the graph was built.
##
## Positions are converted to Vector3 ONCE, on load. A first version read the JSON arrays as
## if they were vectors, which made every distance zero and every route degenerate; that
## mistake is why this file converts explicitly and never touches the raw arrays again.
const DATA_PATH := "res://data/routes58.json"
static var _nodes: Dictionary = {}
static var _neighbours: Dictionary = {}
static var _by_kind: Dictionary = {}
static var _loaded := false
static var _load_reason := ""
static var _nearest_calls := 0
static var _astar_calls := 0
static var _astar_expanded := 0
static var _astar_failed := 0

static func loaded() -> bool:
	if not _loaded: _load()
	return not _nodes.is_empty()

static func reason() -> String:
	if not _loaded: _load()
	return _load_reason

static func _load() -> void:
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		_load_reason = "graph_data_missing"
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		_load_reason = "graph_data_unreadable"
		return
	var nodes_raw: Array = parsed.get("nodes", [])
	var edges_raw: Array = parsed.get("edges", [])
	if nodes_raw.is_empty() or edges_raw.is_empty():
		_load_reason = "graph_data_empty"
		return
	for row: Dictionary in nodes_raw:
		var id: String = str(row.get("id", ""))
		if id.is_empty() or row.get("walkable", false) != true: continue
		var pos: Variant = row.get("pos")
		if not pos is Array or pos.size() < 3: continue
		var point := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		if not point.is_finite(): continue
		_nodes[id] = {"id": id, "kind": str(row.get("kind", "")), "label": str(row.get("label", "")),
			"pos": point, "from": str(row.get("from", "")), "venue_id": str(row.get("venue_id", "")),
			"residents": row.get("residents", [])}
		_neighbours[id] = []
		var kind: String = str(row.get("kind", ""))
		if not _by_kind.has(kind): _by_kind[kind] = []
		(_by_kind[kind] as Array).append(id)
	for row: Dictionary in edges_raw:
		var a: String = str(row.get("a", "")); var b: String = str(row.get("b", ""))
		if not _nodes.has(a) or not _nodes.has(b): continue
		var from_point: Vector3 = _nodes[a].pos
		var to_point: Vector3 = _nodes[b].pos
		var length: float = from_point.distance_to(to_point)
		# A zero-length edge cannot be walked and must never enter the network.
		if length <= .01: continue
		(_neighbours[a] as Array).append({"id": b, "cost": length})
		(_neighbours[b] as Array).append({"id": a, "cost": length})
	_load_reason = "ok" if not _nodes.is_empty() else "graph_data_empty"
	if not _nodes.is_empty():
		print("OWNER58_RUNTIME_GRAPH nodes=", _nodes.size(), " edges=", _edges(), " kinds=", JSON.stringify(_kinds()))

static func _edges() -> int:
	var total := 0
	for id: String in _neighbours.keys(): total += (_neighbours[id] as Array).size()
	return total / 2

static func stats() -> Dictionary:
	if not loaded(): return {"loaded": false, "reason": _load_reason}
	return {"loaded": true, "reason": _load_reason, "nodes": _nodes.size(), "edges": _edges(),
		"kinds": _kinds(), "nearest_calls": _nearest_calls, "astar_calls": _astar_calls,
		"astar_expanded": _astar_expanded, "astar_failed": _astar_failed}

static func _kinds() -> Dictionary:
	var rows: Dictionary = {}
	for kind: String in _by_kind.keys(): rows[kind] = (_by_kind[kind] as Array).size()
	return rows

## Every named place of one kind, for choosing a destination without scanning the scene.
static func places(kind: String) -> Array:
	if not loaded(): return []
	var rows: Array = []
	for id: String in _by_kind.get(kind, []):
		var node: Dictionary = _nodes[id]
		if str(node.from).is_empty(): rows.append(node.duplicate())
	return rows

static func place(id: String) -> Dictionary:
	if not loaded(): return {}
	if _nodes.has(id): return (_nodes[id] as Dictionary).duplicate()
	for key: String in _nodes.keys():
		var node: Dictionary = _nodes[key]
		if str(node.from) == id or str(node.venue_id) == id: return node.duplicate()
	return {}

## The nearest graph node to a point, with the real distance so a caller can refuse a far snap.
static func nearest(point: Vector3, maximum: float = 6.0) -> Dictionary:
	if not loaded(): return {"ok": false, "reason": _load_reason}
	if not point.is_finite(): return {"ok": false, "reason": "nonfinite_point"}
	_nearest_calls += 1
	var best_id := ""
	var best_distance := maximum
	for id: String in _nodes.keys():
		var node: Dictionary = _nodes[id]
		var at: Vector3 = node.pos
		var distance: float = Vector2(at.x - point.x, at.z - point.z).length()
		if distance < best_distance:
			best_distance = distance; best_id = id
	if best_id.is_empty(): return {"ok": false, "reason": "no_graph_node_within_%.1fm" % maximum}
	var found: Dictionary = _nodes[best_id]
	return {"ok": true, "id": best_id, "pos": found.pos, "kind": found.kind, "label": found.label, "snap_m": best_distance}

## Distance to the closest node of the whole graph, so a refusal names the real gap.
static func nearest_distance(point: Vector3) -> float:
	if not loaded() or not point.is_finite(): return -1.0
	var best := INF
	for id: String in _nodes.keys():
		var at: Vector3 = _nodes[id].pos
		best = minf(best, Vector2(at.x - point.x, at.z - point.z).length())
	return best if is_finite(best) else -1.0

## The route from one node to another, as graph node ids in walking order. A* over the
## prepared edges only; no live physics query is made here.
static func path_ids(from_id: String, to_id: String) -> Array:
	if not loaded() or not _nodes.has(from_id) or not _nodes.has(to_id): return []
	if from_id == to_id: return [from_id]
	_astar_calls += 1
	var goal: Vector3 = _nodes[to_id].pos
	var open: Array = [from_id]
	var came: Dictionary = {}
	var cost: Dictionary = {from_id: 0.0}
	while not open.is_empty():
		var best_index := 0
		var best_score := INF
		for index: int in open.size():
			var id: String = open[index]
			var at: Vector3 = _nodes[id].pos
			var score: float = float(cost[id]) + Vector2(at.x - goal.x, at.z - goal.z).length()
			if score < best_score: best_score = score; best_index = index
		var current: String = open[best_index]
		open.remove_at(best_index)
		_astar_expanded += 1
		if current == to_id:
			var route: Array = [current]
			while came.has(route[0]): route.push_front(came[route[0]])
			return route
		for edge: Dictionary in _neighbours.get(current, []):
			var next: String = str(edge.id)
			var next_cost: float = float(cost[current]) + float(edge.cost)
			if cost.has(next) and next_cost >= float(cost[next]) - .001: continue
			cost[next] = next_cost; came[next] = current
			if not open.has(next): open.append(next)
	_astar_failed += 1
	return []

## The prepared polyline between two points: the body's own position snapped to the graph,
## then the graph route, then the destination. Each leg is walked physically by the caller.
static func route_between(from: Vector3, to: Vector3, maximum_snap: float = 8.0) -> Dictionary:
	if not loaded(): return {"ok": false, "reason": _load_reason}
	var start: Dictionary = nearest(from, maximum_snap)
	if not start.get("ok", false):
		return {"ok": false, "reason": "start_no_node_within_%.0fm_nearest_%.1fm" % [maximum_snap, nearest_distance(from)]}
	var finish: Dictionary = nearest(to, maximum_snap)
	if not finish.get("ok", false):
		return {"ok": false, "reason": "finish_no_node_within_%.0fm_nearest_%.1fm" % [maximum_snap, nearest_distance(to)]}
	var ids: Array = path_ids(str(start.id), str(finish.id))
	if ids.is_empty():
		return {"ok": false, "reason": "no_prepared_route", "from_node": start.id, "to_node": finish.id,
			"graph_nodes": _nodes.size()}
	# The body and its goal can already be inside the same network node. Then no long stretch
	# exists: the resident is on the network and the last metres belong to the physical step.
	if str(start.id) == str(finish.id):
		return {"ok": true, "reason": "already_on_network_node", "points": PackedVector3Array([from, to]),
			"from_node": start.id, "to_node": finish.id, "graph_nodes": 1,
			"length_m": from.distance_to(to), "snap_start_m": start.snap_m, "snap_finish_m": finish.snap_m,
			"kinds": []}
	var points: PackedVector3Array = PackedVector3Array()
	points.append(from)
	for id: String in ids: points.append(_nodes[id].pos)
	points.append(to)
	var cleaned: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in points:
		if cleaned.is_empty() or cleaned[-1].distance_to(point) > .05: cleaned.append(point)
	if cleaned.size() < 2: return {"ok": false, "reason": "route_degenerate"}
	return {"ok": true, "reason": "prepared", "points": cleaned, "from_node": start.id, "to_node": finish.id,
		"graph_nodes": ids.size(), "length_m": _length(cleaned), "snap_start_m": start.snap_m,
		"snap_finish_m": finish.snap_m, "kinds": _route_kinds(ids)}

static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for index: int in range(1, points.size()): total += points[index - 1].distance_to(points[index])
	return total

static func _route_kinds(ids: Array) -> Array:
	var kinds: Array = []
	for id: String in ids:
		var kind: String = str(_nodes[id].kind)
		if kind == "street": continue
		if not kinds.has(kind): kinds.append(kind)
	return kinds
