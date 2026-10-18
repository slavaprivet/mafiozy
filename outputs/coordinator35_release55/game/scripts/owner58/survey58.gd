extends SceneTree
## Owner58 survey: measures the real walking geometry of the opened city once, so the
## pedestrian graph can be built from measured points instead of guessed coordinates.
## Read-only: it moves nothing, claims nothing and writes only a report file.
const OUT_NAME := "SURVEY58.json"
var _out := ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt-dir="): _out = argument.trim_prefix("--receipt-dir=")
		elif argument.begins_with("--qa-out="): _out = argument.trim_prefix("--qa-out=")
	_start.call_deferred()

func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _start() -> void:
	var scene: Node3D = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline: int = Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline:
		if scene.get("preview_ready") == true: break
		await process_frame
	for tick: int in 30: await process_frame

	var report: Dictionary = {"schema": "mafiozi.owner58.survey/v1", "sections": {}}
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state

	# 1. The real benches the ambience registry already accepts.
	var benches: Array = []
	var registry: Variant = scene.get_meta("npc_ambient_benches29", null)
	if registry is WeakRef: registry = registry.get_ref()
	if is_instance_valid(registry):
		for row: Dictionary in registry.rows():
			var bench: Node3D = row.bench.get_ref()
			if not is_instance_valid(bench): continue
			benches.append({"path": str(bench.get_path()), "pos": _v3(bench.global_position),
				"approach": _v3(bench.to_global(Vector3(0, 0, .72)))})
	report.sections["benches"] = benches

	# 2. The homes the home registry assigned, with the door and bed geometry it proved.
	var homes: Array = []
	var home_registry: Variant = scene.get_meta("npc_home_registry58", null)
	if home_registry is WeakRef: home_registry = home_registry.get_ref()
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/homes58.json"))
	for entry: Dictionary in packet.get("entries", []):
		homes.append({"id": entry.id, "sign": entry.sign, "position": entry.position,
			"road_point": entry.road_point, "apron": entry.apron_xz, "residents": entry.residents})
	report.sections["homes"] = homes

	# 3. The venues the venue host knows, with the approach point of each.
	var venues: Array = []
	var sites: Variant = scene.get("preview_service_sites29")
	if is_instance_valid(sites) and sites.has_method("current_sites"):
		for site: Variant in sites.current_sites():
			var node: Node3D = site if site is Node3D else null
			venues.append({"id": str(site.get("id") if site is Object else "?"),
				"kind": str(site.get("kind") if site is Object else "?"),
				"pos": _v3(node.global_position) if is_instance_valid(node) else []})
	report.sections["venues"] = venues

	# 4. Real walkable sample: probe a lattice of candidate street points around every home
	# and venue, with the same floor+standing test the walker uses, so the graph edges are
	# built only between points where a capsule is proven to stand.
	var probe := _Probe.new()
	probe.setup(scene)
	report["world_probe"] = probe.world_report(space)
	var samples: Array = []
	var centres: Array = []
	for home: Dictionary in homes:
		centres.append({"kind": "home", "id": home.id, "point": home.road_point})
	for venue: Dictionary in venues:
		if venue.pos.is_empty(): continue
		centres.append({"kind": "venue", "id": venue.id, "point": venue.pos})
	for centre: Dictionary in centres:
		var base: Vector3 = _vec(centre.point)
		var local: Array = []
		for ring: float in [4.0, 9.0, 16.0]:
			for index: int in 12:
				var angle: float = TAU * float(index) / 12.0
				var at := Vector3(base.x + cos(angle) * ring, base.y, base.z + sin(angle) * ring)
				var standing: Dictionary = probe.standing_point(space, at)
				if standing.ok: local.append({"pos": _v3(standing.point), "ring": ring, "index": index})
		samples.append({"kind": centre.kind, "id": centre.id, "base": _v3(base), "walkable": local})
	report.sections["walkable"] = samples
	report["probe"] = probe.stats()

	if not _out.is_empty():
		var file := FileAccess.open(_out.path_join(OUT_NAME), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("OWNER58_SURVEY ", JSON.stringify({"benches": benches.size(), "homes": homes.size(),
		"venues": venues.size(), "walkable_groups": samples.size(), "probe": probe.stats()}))
	quit(0)

static func _vec(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3: return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

class _Probe extends RefCounted:
	var shape: CapsuleShape3D
	## DSH_SURVEY58: the capsule's own local transform inside a real resident body. A shape
	## query with a bare point as its transform buries the capsule in the floor, which is why
	## a first attempt found zero walkable points while the floor rays hit correctly. Copying
	## the standing body's own placement is the only honest way to ask "can this body stand".
	var local := Transform3D.IDENTITY
	var queries := 0
	var misses := 0
	var bodies_seen := 0
	var capsules_seen := 0
	var _query_shape_calls := 0
	var _shape_hits := 0
	var _blocked_by := ""
	func setup(scene: Node3D) -> void:
		var bodies: Array[Node] = scene.find_children("*", "CharacterBody3D", true, false)
		bodies_seen = bodies.size()
		for node: Node in bodies:
			if not node is CharacterBody3D: continue
			for child: Node in node.get_children():
				if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
					capsules_seen += 1
					if shape == null:
						shape = child.shape
						local = child.transform
			if shape != null: break
	func stats() -> Dictionary:
		return {"queries": queries, "misses": misses, "capsule_radius": shape.radius if shape != null else -1.0,
			"capsule_height": shape.height if shape != null else -1.0,
			"local_origin": [local.origin.x, local.origin.y, local.origin.z],
			"bodies_seen": bodies_seen, "capsules_seen": capsules_seen,
			"shape_queries": _query_shape_calls, "shape_hits": _shape_hits, "blocked_by": _blocked_by}
	## DSH_SURVEY58: is the physics world answering at all, and on which mask? Without this
	## a survey that misses every ray cannot be told apart from an empty world.
	func world_report(space: PhysicsDirectSpaceState3D) -> Dictionary:
		var rows: Array = []
		for mask: int in [1, 2, 4, 8, 512, 1 | 512, 0x7FFFFFFF]:
			var hit_count := 0
			for point: Array in [[42.3, -6.2], [-145.6, 386.6], [108.7, 527.8], [45.1, 197.6], [0.0, 0.0]]:
				var ray := PhysicsRayQueryParameters3D.create(Vector3(point[0], 60.0, point[1]), Vector3(point[0], -25.0, point[1]), mask)
				if not space.intersect_ray(ray).is_empty(): hit_count += 1
			rows.append({"mask": mask, "hits_of_5": hit_count})
		# Same points, measured over the SHORT window the walker actually uses.
		var shorts: Array = []
		for point: Array in [[42.3, -6.2], [-145.6, 386.6], [108.7, 527.8], [45.1, 197.6], [0.0, 0.0]]:
			var row := {"point": point}
			for span: float in [1.4, 3.0, 8.0, 20.0]:
				var ray := PhysicsRayQueryParameters3D.create(Vector3(point[0], span, point[1]), Vector3(point[0], -1.2, point[1]), 1)
				var hit: Dictionary = space.intersect_ray(ray)
				row["from_y_%.1f" % span] = "%.2f" % float(hit.position.y) if not hit.is_empty() else "miss"
			shorts.append(row)
		return {"space_state_present": space != null, "rays": rows, "short_window": shorts}
	func standing_point(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
		queries += 1
		if shape == null: misses += 1; return {"ok": false}
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 1.4, at.z), Vector3(at.x, at.y - 1.2, at.z), 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or Vector3(hit.normal).dot(Vector3.UP) < .7: misses += 1; return {"ok": false}
		var point := Vector3(at.x, float(hit.position.y) + .003, at.z)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		# The real body's capsule sits at its own local offset above the floor point.
		query.transform = Transform3D(Basis.IDENTITY, point) * local
		_query_shape_calls += 1
		query.collision_mask = 1
		query.margin = .001
		var hits: Array[Dictionary] = space.intersect_shape(query, 1)
		_shape_hits += hits.size()
		if not hits.is_empty():
			_blocked_by = str(hits[0].get("collider"))
			misses += 1; return {"ok": false}
		return {"ok": true, "point": point}
