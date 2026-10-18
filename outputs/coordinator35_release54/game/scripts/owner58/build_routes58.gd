extends SceneTree
## Owner58 route builder: turns the measured geometry of the opened city into the connected
## pedestrian graph the residents walk on.
##
## Shape of the network (measured, not guessed):
##   * a REGULAR STREET GRID sampled with the real capsule - one node per grid cell where the
##     capsule stands, linked to its neighbouring cells by segments proved walkable end to end.
##     A grid is used because the first two attempts produced a tree of near-duplicate points
##     (1328 zero-length edges, 21 components) that answered "no prepared route" to every
##     request. A grid cannot fragment that way: a cell is always reachable from its neighbour.
##   * NAMED ANCHORS - homes, venue fronts, benches - each snapped to the nearest grid node and
##     linked to it, so a resident can leave a building and enter the network.
## Connectivity is computed on the finished edge set and reported; it is never assumed.
const OUT_NAME := "routes58.json"
const CELL_M := 26.0
const SAMPLE_M := 1.5
const ANCHOR_LINK_M := 40.0
var _out := ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt-dir="): _out = argument.trim_prefix("--receipt-dir=")
		elif argument.begins_with("--qa-out="): _out = argument.trim_prefix("--qa-out=")
	_start.call_deferred()

func _start() -> void:
	var scene: Node3D = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline: int = Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline:
		if scene.get("preview_ready") == true: break
		await process_frame
	for tick: int in 30: await process_frame
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var probe := Probe.new()
	probe.setup(scene)
	if probe.shape == null:
		print("OWNER58_GRAPH refused=no_capsule"); quit(1); return

	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/homes58.json"))
	var venue_packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/venue_sites29.json"))
	var anchors: Array = []
	for entry: Dictionary in packet.get("entries", []):
		anchors.append({"id": "home:" + str(entry.id), "kind": "home", "label": str(entry.sign),
			"point": _vec(entry.road_point), "residents": entry.residents})
	for entry: Dictionary in venue_packet.get("entries", []):
		anchors.append({"id": "venue:" + str(entry.id), "kind": str(entry.kind), "label": str(entry.sign),
			"point": _vec(entry.road_point), "venue_id": str(entry.id)})
	var registry: Variant = scene.get_meta("npc_ambient_benches29", null)
	if registry is WeakRef: registry = registry.get_ref()
	if is_instance_valid(registry):
		for row: Dictionary in registry.rows():
			var bench: Node3D = row.bench.get_ref()
			if is_instance_valid(bench):
				anchors.append({"id": "bench:" + str(bench.get_path()), "kind": "bench", "label": "лавка",
					"point": bench.to_global(Vector3(0, 0, .72))})

	# The grid is laid around the places the city actually uses, not over the whole map.
	var bounds := AABB()
	var first := true
	for anchor: Dictionary in anchors:
		var point: Vector3 = _vec(anchor.point)
		var box := AABB(point - Vector3(CELL_M * 2.0, 0, CELL_M * 2.0), Vector3(CELL_M * 4.0, 0, CELL_M * 4.0))
		bounds = box if first else bounds.merge(box)
		first = false
	var nodes: Array = []
	var cell_node: Dictionary = {}
	var tested := 0
	var x := floorf(bounds.position.x / CELL_M) * CELL_M
	while x <= bounds.end.x:
		var z := floorf(bounds.position.z / CELL_M) * CELL_M
		while z <= bounds.end.z:
			var at := Vector3(x, 0.0, z)
			var standing: Dictionary = probe.snap_walkable(space, at, CELL_M * .5)
			if standing.ok:
				var id := "s%d_%d" % [roundi(x), roundi(z)]
				cell_node[_cell(Vector3(standing.point))] = id
				nodes.append({"id": id, "kind": "street", "label": "", "pos": _v3(standing.point),
					"walkable": true, "grid": true, "snap_m": standing.distance})
			z += CELL_M
		x += CELL_M

	# Street edges: each grid node to the neighbouring cells, proved segment by segment.
	var edges: Array = []
	var by_id: Dictionary = {}
	for node: Dictionary in nodes: by_id[str(node.id)] = node
	for node: Dictionary in nodes:
		var from_point: Vector3 = _vec(node.pos)
		for offset: Array in [[CELL_M, 0.0], [0.0, CELL_M], [CELL_M, CELL_M], [CELL_M, -CELL_M]]:
			var neighbour_id := "s%d_%d" % [roundi(from_point.x + float(offset[0])), roundi(from_point.z + float(offset[1]))]
			if not by_id.has(neighbour_id): continue
			var to_point: Vector3 = _vec(by_id[neighbour_id].pos)
			tested += 1
			if not probe.segment_walkable(space, from_point, to_point): continue
			edges.append({"a": str(node.id), "b": neighbour_id, "length_m": from_point.distance_to(to_point)})

	# Named anchors: snapped onto the grid and linked to it, so a home or a shop front is part
	# of the same network instead of a separate island.
	var unlinked: Array = []
	for anchor: Dictionary in anchors:
		var snap: Dictionary = probe.snap_walkable(space, _vec(anchor.point), 22.0)
		if not snap.ok:
			unlinked.append({"id": anchor.id, "reason": snap.reason})
			continue
		var anchor_id := str(anchor.id)
		nodes.append({"id": anchor_id, "kind": anchor.kind, "label": anchor.label, "pos": _v3(snap.point),
			"walkable": true, "snap_m": snap.distance, "residents": anchor.get("residents", []),
			"venue_id": anchor.get("venue_id", "")})
		by_id[anchor_id] = nodes[nodes.size() - 1]
		# The closest grid nodes, proved, so leaving the building is a real step.
		var candidates: Array = []
		for node: Dictionary in nodes:
			if str(node.id) == anchor_id or node.get("grid", false) != true: continue
			var distance: float = snap.point.distance_to(_vec(node.pos))
			if distance <= ANCHOR_LINK_M: candidates.append({"id": str(node.id), "distance": distance})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
		var made := 0
		for row: Dictionary in candidates:
			if made >= 3: break
			tested += 1
			if not probe.segment_walkable(space, snap.point, _vec(by_id[str(row.id)].pos)): continue
			edges.append({"a": anchor_id, "b": str(row.id), "length_m": float(row.distance)})
			made += 1
		if made == 0: unlinked.append({"id": anchor.id, "reason": "no_grid_link_within_%.0fm" % ANCHOR_LINK_M})

	# Connectivity repair: link the closest reachable pair of two different components, one at
	# a time, until the network is one piece again. Measured: a 26 m grid over this city leaves
	# islands where a large building occupies several cells, and those islands blocked 9 of 60
	# tested routes. The closest pair is therefore searched WITHOUT a distance cap - a long
	# proven link is still a real walk - and every link is proved the same way as any other.
	var repairs := 0
	var unreachable: Array = []
	for repair: int in 400:
		var groups: Array = _components_of(nodes, edges)
		if groups.size() <= 1: break
		var main_members: Array = groups[0].members
		var best_a := ""
		var best_b := ""
		var best_distance := INF
		for other_index: int in range(1, groups.size()):
			for id: String in groups[other_index].members:
				if not by_id.has(id): continue
				var from_point: Vector3 = _vec(by_id[id].pos)
				for main_id: String in main_members:
					if not by_id.has(main_id): continue
					var distance: float = from_point.distance_to(_vec(by_id[main_id].pos))
					if distance < best_distance:
						best_distance = distance; best_a = id; best_b = main_id
			if not best_a.is_empty(): break
		if best_a.is_empty(): break
		tested += 1
		if not probe.segment_walkable(space, _vec(by_id[best_a].pos), _vec(by_id[best_b].pos)):
			# This pair cannot be joined. Drop the island instead of pretending it is linked,
			# and report it, so a place the graph cannot reach is named rather than hidden.
			var dropped: Array = []
			for other_index: int in range(1, groups.size()):
				for member: String in groups[other_index].members:
					if member == best_a: dropped = groups[other_index].members; break
				if not dropped.is_empty(): break
			unreachable.append({"component_size": dropped.size(), "nearest_m": best_distance,
				"members": dropped.slice(0, 6)})
			var keep: Array = []
			var drop_set: Dictionary = {}
			for id: String in dropped: drop_set[id] = true
			for node: Dictionary in nodes:
				if not drop_set.has(str(node.id)): keep.append(node)
			nodes = keep
			var kept_edges: Array = []
			for edge: Dictionary in edges:
				if not drop_set.has(str(edge.a)) and not drop_set.has(str(edge.b)): kept_edges.append(edge)
			edges = kept_edges
			continue
		edges.append({"a": best_a, "b": best_b, "length_m": best_distance})
		repairs += 1

	var components: Array = _components_of(nodes, edges)
	var report := {
		"schema": "mafiozi.owner58.routes/v1",
		"source": "measured on the opened common scene; every edge proved walkable for the real capsule",
		"grid_m": CELL_M, "nodes": nodes, "edges": edges, "probe": probe.stats(),
		"components": components,
		"counts": {"nodes": nodes.size(), "street_nodes": maxi(0, nodes.size() - anchors.size()),
			"edges": edges.size(), "edges_tested": tested, "anchors": anchors.size(),
			"anchor_links_missing": unlinked.size(), "repair_links": repairs,
			"islands_dropped": unreachable.size(),
			"components": components.size(), "largest_component": maxi(0, _largest(components))},
		"anchors_unlinked": unlinked,
	}
	if not _out.is_empty():
		var file := FileAccess.open(_out.path_join(OUT_NAME), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t")); file.close()
	var shipped := FileAccess.open("res://data/" + OUT_NAME, FileAccess.WRITE)
	if shipped != null:
		shipped.store_string(JSON.stringify(report, "\t")); shipped.close()
		print("OWNER58_GRAPH_SHIPPED res://data/", OUT_NAME)
	print("OWNER58_GRAPH ", JSON.stringify(report.counts))
	quit(0)

static func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _vec(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3: return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Vector3: return value
	return Vector3.ZERO

static func _cell(point: Vector3) -> String:
	return "%d:%d" % [floori(point.x / (CELL_M * .5)), floori(point.z / (CELL_M * .5))]

static func _largest(components: Array) -> int:
	return int(components[0].size) if components.size() > 0 else 0

static func _components_of(nodes: Array, edges: Array) -> Array:
	var parent: Dictionary = {}
	for node: Dictionary in nodes: parent[str(node.id)] = str(node.id)
	for edge: Dictionary in edges:
		var a: String = str(edge.a); var b: String = str(edge.b)
		if not parent.has(a) or not parent.has(b): continue
		var root_a := a
		while parent[root_a] != root_a: root_a = parent[root_a]
		var root_b := b
		while parent[root_b] != root_b: root_b = parent[root_b]
		if root_a != root_b: parent[root_a] = root_b
	var groups: Dictionary = {}
	for node: Dictionary in nodes:
		var id: String = str(node.id)
		var root := id
		while parent[root] != root: root = parent[root]
		if not groups.has(root): groups[root] = []
		(groups[root] as Array).append(id)
	var rows: Array = []
	for root: String in groups.keys(): rows.append({"root": root, "size": (groups[root] as Array).size(), "members": groups[root]})
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.size) > int(y.size))
	return rows

class Probe extends RefCounted:
	var shape: CapsuleShape3D
	var local := Transform3D.IDENTITY
	var queries := 0
	var segments := 0
	var segment_failures := 0
	var last_failure := ""
	func setup(scene: Node3D) -> void:
		for node: Node in scene.find_children("*", "CharacterBody3D", true, false):
			if not node is CharacterBody3D: continue
			for child: Node in node.get_children():
				if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
					shape = child.shape; local = child.transform; return
	func stats() -> Dictionary:
		return {"shape_queries": queries, "segments": segments, "segment_failures": segment_failures,
			"last_failure": last_failure, "capsule_radius": shape.radius if shape != null else -1.0}
	func floor_at(space: PhysicsDirectSpaceState3D, at: Vector3) -> Variant:
		queries += 1
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 1.6, at.z), Vector3(at.x, at.y - 1.4, at.z), 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or Vector3(hit.normal).dot(Vector3.UP) < .7: return null
		return float(hit.position.y)
	func standing_at(space: PhysicsDirectSpaceState3D, at: Vector3, floor_y: float) -> bool:
		if shape == null: return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, floor_y + .003, at.z)) * local
		query.collision_mask = 1
		query.margin = .001
		return space.intersect_shape(query, 1).is_empty()
	func standing_point(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
		var floor_y: Variant = floor_at(space, at)
		if not floor_y is float: return {"ok": false, "reason": "no_floor"}
		if not standing_at(space, at, floor_y): return {"ok": false, "reason": "capsule_blocked"}
		return {"ok": true, "point": Vector3(at.x, floor_y + .003, at.z)}
	func snap_walkable(space: PhysicsDirectSpaceState3D, at: Vector3, radius: float) -> Dictionary:
		var direct: Dictionary = standing_point(space, at)
		if direct.ok: return {"ok": true, "point": direct.point, "distance": 0.0}
		var ring := 1.0
		while ring <= radius:
			for index: int in 16:
				var angle: float = TAU * float(index) / 16.0
				var candidate := Vector3(at.x + cos(angle) * ring, at.y, at.z + sin(angle) * ring)
				var found: Dictionary = standing_point(space, candidate)
				if found.ok: return {"ok": true, "point": found.point, "distance": ring}
			ring += 1.5
		return {"ok": false, "reason": "no_walkable_point_within_%.1fm" % radius}
	func segment_walkable(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
		segments += 1
		var length: float = a.distance_to(b)
		if length <= .05: return false
		var count: int = maxi(1, ceili(length / SAMPLE_M))
		var previous_y: float = a.y
		for index: int in range(0, count + 1):
			var t: float = float(index) / float(count)
			var at: Vector3 = a.lerp(b, t)
			var floor_y: Variant = floor_at(space, at)
			if not floor_y is float: segment_failures += 1; last_failure = "no_floor_at_%.1fm" % (t * length); return false
			if absf(float(floor_y) - previous_y) > .45: segment_failures += 1; last_failure = "step_too_high_at_%.1fm" % (t * length); return false
			previous_y = float(floor_y)
			if not standing_at(space, at, float(floor_y)): segment_failures += 1; last_failure = "blocked_at_%.1fm" % (t * length); return false
		return true
