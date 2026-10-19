extends RefCounted
## Existing-world adapter. No population, permission defaults, navigation agents,
## rendering mesh reads, new physics nodes or modifications to the scene owner.
const Backend = preload("res://scripts/city/runtime/npc_city_engine_navigation.gd")
const Hospital = preload("res://scripts/hospital/npc_hospital_geometry.gd")
const Bank = preload("res://scripts/bank_geometry/npc_bank_geometry.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Interior = preload("res://scripts/preview_printshop_interior.gd")
const MAX_RECORDS := 512
const MAX_CITY_STATIC_BODIES := 16384
var _proposal_sites: Dictionary = {}
var _proposal_count := 0
var _proposal_triangles := 0
var _root: WeakRef
var _interior: WeakRef
var _backend: RefCounted
var _queue: RefCounted
var _static := PackedVector3Array()
var _leaves: Array[Dictionary] = []
var _transitions: Dictionary = {}
var _records: Dictionary = {}
var _owner_records: Dictionary = {}
var _body_records: Dictionary = {}
var _source_records: Dictionary = {}
var _authority := ""
var _generation := 0
var _access_version := -1
var _geometry_version := 0
var _revision := 0
var _next_id := 0
var _disposed := false
var _busy := false
var _geometry_valid := false
var _errors: Array[String] = []
var _stats := {"captures": 0, "static_shapes": 0, "door_shapes": 0, "triangles": 0, "capture_us": 0, "publications": 0, "transition_starts": 0, "steps": 0, "blocked_steps": 0, "step_us_total": 0, "step_us_max": 0, "pump_us": [], "proposals_us": [], "leaf_check_us": []}
var _dsh_step_max_us := 0  # DSH_NAVDAILY: max single step since the last counters() read
var _dsh_pump_every := -1  # DSH_NAVDAILY: resolved --city-nav-pump-every (1 = every tick)
# DSH_MOTION: optional cost levers, parsed once from OS.get_cmdline_user_args().
# Every default (flag absent, or the 0/1 value below) reproduces the previous behaviour.
var _dsh_motion_retry := -1  # --city-motion-retry=N ticks; 0/1 = retry a refused motion every tick
var _dsh_motion_skips := 0  # DSH_MOTION: refused steps deferred to their next due tick
var _dsh_timing := -1  # --city-timing=0 skips the per-call diagnostic sample records only
# DSH_NAVSTEP2: optional hot-path levers, parsed once from OS.get_cmdline_user_args().
# --city-navstep-slim=0 (default) keeps today's exact code path and counters.
var _dsh_slim := -1
# DSH_NAVSTEP3: --city-navsplit=0 (default) reads no clock and touches no counter.
# --city-nav-arrived-static=0 (default) keeps today's backend poll for ARRIVED records.
var _dsh_split := -1
var _dsh_split_on := false
var _dsh_arrived_static := -1
var _dsh_p_ms := 0
var _dsh_p_frame := -1
var _dsh_p_steps := 0
var _dsh_p_calls := 0
var _dsh_p_us := [0, 0, 0, 0, 0, 0, 0, 0]
var _dsh_p_entry := {}
var _dsh_p_end := {}
var _dsh_p_prev := {}

func _record_profile(key: String, started: int) -> void:
	var samples: Array = _stats[key]
	var elapsed := Time.get_ticks_usec() - started
	if elapsed >= 1000 and samples.size() < 128: samples.append(elapsed)

func _v(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])
func _matrix(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[4], a[5], a[6]), Vector3(a[8], a[9], a[10])), Vector3(a[12], a[13], a[14]))
func _fail(reason: String) -> bool:
	if _errors.size() < 32: _errors.append(reason)
	return false

func _points_key(points: PackedVector3Array) -> String:
	# Input comparisons preserve actual float32 points and ordering. Source pairs
	# are emitted in that same order by main/PrintshopInterior.
	return points.to_byte_array().hex_encode()

func _same_floor(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if not a[i].is_finite() or a[i].distance_to(b[i]) > 0.00001: return false
	return true

func _expected(block: Dictionary, data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in block.buildings + block.decor:
		if record.id == Interior.SOURCE_ID: continue
		for body: Dictionary in record.collisionBodiesM:
			var points := PackedVector3Array()
			for p: Array in body.polygonXZ:
				points.append(Vector3(p[0], body.minY, p[1])); points.append(Vector3(p[0], body.maxY, p[1]))
			var key: String = str(record.id) + ":" + str(body.sourceIndex)
			if result.has(key): _fail("duplicate-source-identity"); return {}
			result[key] = {"points": points, "frame": Transform3D.IDENTITY, "kind": "convex"}
	for body: Dictionary in data.staticBodies:
		var points := PackedVector3Array()
		for p: Array in body.polygonXZ:
			points.append(Vector3(p[0], body.minY, p[1])); points.append(Vector3(p[0], body.maxY, p[1]))
		var key := "interior:" + _points_key(points)
		if result.has(key): _fail("duplicate-interior-collision"); return {}
		result[key] = {"points": points, "frame": Transform3D.IDENTITY, "kind": "convex"}
	for door: String in data.doors:
		for body: Dictionary in data.doors[door].bodies:
			var points := PackedVector3Array()
			for p: Array in body.pointsLocal: points.append(_v(p))
			var key := "door:" + door + ":" + _points_key(points)
			if result.has(key): _fail("duplicate-door-collision"); return {}
			result[key] = {"points": points, "kind": "door", "door": door}
	# These CPU source arrays are also what the current interior adapter stores
	# in its ConcavePolygonShape3D; no render resource is read back.
	for spec: Dictionary in data.meshes:
		if not spec.floorCollision: continue
		var source: Dictionary = data.geometry[int(spec.geometry)]
		var values: Array = source.attributes.position.values
		var indices: Array = source.indices if source.indices != null else range(values.size() / 3)
		var instances: Array = spec.get("instances", [])
		if instances.is_empty(): instances = [[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]]
		var points := PackedVector3Array()
		for instance: Array in instances:
			var frame := _matrix(spec.transform) * _matrix(instance)
			for i in range(0, indices.size(), 3):
				for offset: int in [0, 2, 1]:
					var j := int(indices[i + offset]) * 3
					points.append(frame * Vector3(values[j], values[j + 1], values[j + 2]))
		var key := "floor:" + _points_key(points)
		if result.has(key): _fail("duplicate-floor-collision"); return {}
		result[key] = {"points": points, "frame": Transform3D.IDENTITY, "kind": "concave"}
	var surface: Dictionary = block.surface
	var origin := _v(block.originM)
	var cell: float = surface.cellSize
	for row in surface.grid.size():
		var col := 0
		while col < surface.grid[row].size():
			var tile := str(int(surface.grid[row][col]))
			if not surface.palette[tile].solid: col += 1; continue
			var first := col
			while col < surface.grid[row].size() and str(int(surface.grid[row][col])) == tile: col += 1
			var size := Vector3((col - first) * cell, .16, cell)
			var position := Vector3((int(surface.startCol) + (first + col) * .5) * cell - origin.x, float(surface.palette[tile].heightM) - .08, (int(surface.startRow) + row + .5) * cell - origin.z)
			var key := "strip:" + _points_key(PackedVector3Array([size, position]))
			if result.has(key): _fail("duplicate-floor-strip"); return {}
			result[key] = {"size": size, "frame": Transform3D(Basis.IDENTITY, position), "kind": "box"}
	return result

## Data must be the already-validated records used to build these exact nodes.
## root and interior are scene-root coordinates; physics owner remains main.
func attach_existing(scene: Node3D, interior: Node3D, block: Dictionary, data: Dictionary, queue: RefCounted, authority: String, generation: int, access_version: int) -> bool:
	if not Thread.is_main_thread() or _disposed or _backend != null: return false
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not is_instance_valid(interior) or not interior is Interior or not interior.ready_for_use or interior.get_parent() != scene: return _fail("missing-existing-world")
	if not scene.global_transform.is_equal_approx(Transform3D.IDENTITY) or not interior.global_transform.is_equal_approx(Transform3D.IDENTITY): return _fail("unexpected-world-frame")
	if not queue is Queue or authority.is_empty() or generation < 1 or access_version < 0: return _fail("invalid-authority-or-queue")
	if block != scene.get("_block") or data != interior.get("_data"): return _fail("data-not-current-built-world")
	var started := Time.get_ticks_usec()
	var expected := _expected(block, data)
	if not _errors.is_empty() or expected.is_empty(): return false
	var seen: Dictionary = {}
	var candidates: Array[Node] = []
	# No traversal of render assets, actors, sensors or arbitrary descendants.
	for child: Node in scene.get_children():
		if child is StaticBody3D: candidates.append(child)
	for child: Node in interior.get_children():
		if child is StaticBody3D: candidates.append(child)
		elif str(child.name) in ["SourceDoor_public", "SourceDoor_service"]:
			for leaf: Node in child.get_children():
				if leaf is StaticBody3D: candidates.append(leaf)
	if candidates.size() > MAX_CITY_STATIC_BODIES: return _capture_failed("source-shape-limit")
	for body: StaticBody3D in candidates:
		if body.collision_layer != 1 or body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D: return _capture_failed("unsupported-static-body")
		var node: CollisionShape3D = body.get_child(0)
		if node.disabled or node.shape == null or not node.transform.is_equal_approx(Transform3D.IDENTITY): return _capture_failed("unsupported-collision-transform")
		var key := ""
		if body.get_parent() == scene:
			if body.has_meta("source_id"):
				key = str(body.get_meta("source_id")) + ":" + str(body.get_meta("source_index", -1))
			elif node.shape is BoxShape3D:
				key = "strip:" + _points_key(PackedVector3Array([node.shape.size, body.position]))
		else:
			if body.get_meta("source_id", "") != Interior.SOURCE_ID: return _capture_failed("unknown-interior-source")
			var kind: String = body.get_meta("interior_kind", "")
			if kind == "source-static" and node.shape is ConvexPolygonShape3D: key = "interior:" + _points_key(node.shape.points)
			elif kind == "source-floor-ceiling" and node.shape is ConcavePolygonShape3D:
				# ArrayMesh's stored float32 faces can differ by one ULP from the
				# direct source transform. Match ordered triangles within 10µm,
				# then use the ACTUAL physics soup unchanged for navigation.
				for candidate: String in expected:
					if candidate.begins_with("floor:") and _same_floor(node.shape.get_faces(), expected[candidate].points):
						if not key.is_empty(): return _capture_failed("ambiguous-source-floor")
						key = candidate
			elif kind.begins_with("door:") and node.shape is ConvexPolygonShape3D: key = kind + ":" + _points_key(node.shape.points)
		if key.is_empty() or not expected.has(key) or seen.has(key): return _capture_failed("unknown-or-duplicate-source-shape:" + str(body.get_path()) + ":" + key.left(100))
		seen[key] = true
		var spec: Dictionary = expected[key]
		var local := PackedVector3Array()
		if spec.kind == "box":
			if not node.shape is BoxShape3D or node.shape.size != spec.size: return _capture_failed("source-box-mismatch")
			var half: Vector3 = spec.size * .5
			local = _extrusion(PackedVector3Array([Vector3(-half.x, -half.y, -half.z), Vector3(-half.x, half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, half.y, -half.z), Vector3(half.x, -half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(-half.x, -half.y, half.z), Vector3(-half.x, half.y, half.z)]))
		elif spec.kind == "concave":
			if not node.shape is ConcavePolygonShape3D or not _same_floor(node.shape.get_faces(), spec.points): return _capture_failed("source-floor-mismatch")
			local = node.shape.get_faces()
		else:
			if not node.shape is ConvexPolygonShape3D or node.shape.points != spec.points: return _capture_failed("source-convex-mismatch")
			local = _extrusion(node.shape.points)
		if local.is_empty(): return _capture_failed("unsupported-non-extruded-convex")
		for p: Vector3 in local:
			if not p.is_finite(): return _capture_failed("nonfinite-collision")
		if spec.kind == "door":
			_leaves.append({"node": weakref(node), "local": local, "door": spec.door, "frame": node.global_transform})
			_stats.door_shapes += 1
		else:
			if not node.global_transform.is_equal_approx(spec.frame): return _capture_failed("source-static-frame-mismatch")
			_static.append_array(node.global_transform * local); _stats.static_shapes += 1
	# Missing shapes remain errors except the explicitly declared original
	# exterior envelopes of the two typed, attached source service buildings.
	# They are NAVIGATION PROPOSALS, never claimed to be current physics bodies.
	for key: String in expected:
		if seen.has(key): continue
		var proposal_id: String=""
		for id: String in _proposal_sites:
			if key.begins_with(id+":"): proposal_id=id; break
		if proposal_id.is_empty(): return _capture_failed("missing-source-shapes:"+key.left(100))
		var spec: Dictionary=expected[key]
		if spec.kind!="convex" or spec.frame!=Transform3D.IDENTITY: return _capture_failed("unsupported-proposal-envelope")
		var proposal_faces:=_extrusion(spec.points)
		if proposal_faces.is_empty(): return _capture_failed("invalid-proposal-envelope")
		_static.append_array(proposal_faces); seen[key]=true
		_proposal_count+=1; _proposal_triangles+=int(proposal_faces.size()/3)
	if seen.size() != expected.size(): return _capture_failed("missing-source-shapes")
	_root = weakref(scene); _interior = weakref(interior); _queue = queue
	_authority = authority; _generation = generation; _access_version = access_version
	_backend = Backend.new(queue, _space)
	_stats.captures = 1; _stats.capture_us = Time.get_ticks_usec() - started
	scene.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	return _publish()

func _capture_failed(reason: String) -> bool:
	_static.clear(); _leaves.clear(); _stats.static_shapes = 0; _stats.door_shapes = 0
	return _fail(reason)

func _extrusion(points: PackedVector3Array) -> PackedVector3Array:
	if points.size() < 6 or points.size() > 128: return PackedVector3Array()
	for p: Vector3 in points:
		if not p.is_finite(): return PackedVector3Array()
	var bottom := INF; var top := -INF
	for p: Vector3 in points: bottom = minf(bottom, p.y); top = maxf(top, p.y)
	var lower := PackedVector2Array(); var upper := PackedVector2Array()
	for p: Vector3 in points:
		if is_equal_approx(p.y, bottom): lower.append(Vector2(p.x, p.z))
		elif is_equal_approx(p.y, top): upper.append(Vector2(p.x, p.z))
		else: return PackedVector3Array()
	if lower.size() != upper.size() or top <= bottom: return PackedVector3Array()
	for point: Vector2 in lower:
		if not upper.has(point): return PackedVector3Array()
	var polygon := Geometry2D.convex_hull(lower)
	if polygon.size() < 4: return PackedVector3Array()
	polygon.resize(polygon.size() - 1)
	if Geometry2D.is_polygon_clockwise(polygon): polygon.reverse()
	var indices := Geometry2D.triangulate_polygon(polygon)
	var result := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		var a := polygon[indices[i]]; var b := polygon[indices[i + 1]]; var c := polygon[indices[i + 2]]
		result.append_array(PackedVector3Array([Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(c.x, top, c.y), Vector3(a.x, bottom, a.y), Vector3(c.x, bottom, c.y), Vector3(b.x, bottom, b.y)]))
	for i in polygon.size():
		var a := polygon[i]; var b := polygon[(i + 1) % polygon.size()]
		result.append_array(PackedVector3Array([Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3(b.x, top, b.y), Vector3(a.x, bottom, a.y), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y)]))
	return result

func _space() -> PhysicsDirectSpaceState3D:
	var scene: Node3D = _root.get_ref() if _root != null else null
	return scene.get_world_3d().direct_space_state if is_instance_valid(scene) and scene.is_inside_tree() else null

func _publish() -> bool:
	_geometry_valid = false
	var faces := _static.duplicate()
	for leaf: Dictionary in _leaves:
		var node: CollisionShape3D = leaf.node.get_ref()
		if not is_instance_valid(node) or node.disabled: return _fail("door-lifetime-ended")
		leaf.frame = node.global_transform
		faces.append_array(leaf.frame * leaf.local)
	_geometry_version += 1; _stats.triangles = faces.size() / 3
	if not _backend.publish_source(faces, _authority, _generation, _geometry_version): return _fail("backend-snapshot-rejected")
	_stats.publications += 1
	_geometry_valid = true
	return true

func _invalidate(reason: String) -> void:
	_revision += 1
	for record: Dictionary in _records.values():
		_backend.cancel(record.backend_id); record.status = "STALE"; record.reason = reason; record.path.clear()
		var body: CharacterBody3D = record.body.get_ref()
		if is_instance_valid(body): body.velocity = Vector3.ZERO

## Invoke after an accepted request_door, BEFORE the first advance/rotation.
func door_transition_started(key: String, target_fraction: float) -> bool:
	if not Thread.is_main_thread() or _disposed or _busy or _backend == null or not key in ["public", "service"] or not target_fraction in [0.0, 1.0]: return false
	_invalidate("door-transition-started")
	_geometry_valid = false
	_transitions[key] = target_fraction; _stats.transition_starts += 1
	return true

func update_access_version(version: int) -> bool:
	if not Thread.is_main_thread() or _disposed or _busy or _backend == null or version <= _access_version: return false
	_access_version = version; _invalidate("access-version-changed")
	return true # Access-only changes never rebake unchanged geometry.

func pump(frame_id: int) -> void:
	if not Thread.is_main_thread() or _disposed or _busy or _backend == null: return
	var profile_started := Time.get_ticks_usec()
	var section_started := profile_started
	if not _proposals_current():
		_record_profile("proposals_us", section_started)
		if _geometry_valid: _invalidate("conservative-service-proposal-lifetime"); _fail("conservative-service-proposal-lifetime")
		_geometry_valid=false; return
	_record_profile("proposals_us", section_started)
	var interior: Node3D = _interior.get_ref()
	if not is_instance_valid(interior) or not interior.ready_for_use: dispose(); return
	var settled := false
	# DSH_NAVDAILY: no Array is allocated while no door is moving.
	if not _transitions.is_empty():
		for key: String in _transitions.keys():
			if is_equal_approx(interior.door_fraction(key), _transitions[key]): _transitions.erase(key); settled = true
	# Only publish after all known transitions settle. No per-fraction rebuild.
	if settled and _transitions.is_empty():
		if not _publish(): _invalidate("door-publication-failed"); return
	if not _transitions.is_empty(): return
	section_started = Time.get_ticks_usec()
	for leaf: Dictionary in _leaves:
		var node: CollisionShape3D = leaf.node.get_ref()
		if not is_instance_valid(node) or not node.global_transform.is_equal_approx(leaf.frame):
			if _geometry_valid: _invalidate("unannounced-door-motion"); _fail("unannounced-door-motion")
			_geometry_valid = false; return
	_record_profile("leaf_check_us", section_started)
	if not _geometry_valid: return
	# DSH_NAVDAILY: A/B lever, default off. --city-nav-pump-every=N advances the path-job
	# queue on every N-th physics tick. Proposal lifetime, door motion and geometry
	# validity are still validated on EVERY tick above; only queued path work is
	# sampled less often. The skip is refused unless the backend map is READY, so map
	# baking, door settling and the load phases keep their current cadence.
	if _dsh_pump_every != 1:
		var dsh_cadence := _dsh_pump_cadence()
		if dsh_cadence > 1 and frame_id % dsh_cadence != 0 and _backend.state() == "READY": return
	_busy = true
	_backend.pump(frame_id)
	_busy = false
	_record_profile("pump_us", profile_started)

func state() -> String:
	if not Thread.is_main_thread(): return "INVALID_THREAD"
	if _disposed: return "DISPOSED"
	if _backend == null: return "UNATTACHED"
	if not _transitions.is_empty(): return "DOOR_TRANSITION"
	if not _geometry_valid: return "INVALID_GEOMETRY"
	return _backend.state()

func _body_supported(body: CharacterBody3D) -> bool:
	var basis := body.global_transform.basis
	if body.collision_mask != 1 or not basis.is_equal_approx(basis.orthonormalized()) or not basis.y.is_equal_approx(Vector3.UP): return false
	# DSH_NAVSTEP2: --city-navstep-slim=1 walks the same internal child list in the
	# same order through get_child(i), so no Array is allocated, and applies the
	# same checks with the same short-circuit order and the same count == 1 rule.
	if _dsh_slim < 0: _dsh_slim = _slim_flag()
	if _dsh_slim == 1:
		var dsh_count := 0
		var dsh_children := body.get_child_count()
		for dsh_index in dsh_children:
			var dsh_child: Variant = body.get_child(dsh_index)
			if not dsh_child is CollisionShape3D or dsh_child.disabled: continue
			dsh_count += 1
			if not dsh_child.shape is CapsuleShape3D: return false
			if dsh_child.shape.radius <= 0 or dsh_child.shape.radius > Backend.RADIUS + .000001 or dsh_child.shape.height <= 0 or dsh_child.shape.height > Backend.HEIGHT + .000001: return false
			if not dsh_child.transform.basis.is_equal_approx(Basis.IDENTITY) or not dsh_child.position.is_equal_approx(Vector3(0, dsh_child.shape.height * .5, 0)): return false
		return dsh_count == 1
	var count := 0
	for child: Node in body.get_children():
		if not child is CollisionShape3D or child.disabled: continue
		count += 1
		if not child.shape is CapsuleShape3D: return false
		if child.shape.radius <= 0 or child.shape.radius > Backend.RADIUS + .000001 or child.shape.height <= 0 or child.shape.height > Backend.HEIGHT + .000001: return false
		if not child.transform.basis.is_equal_approx(Basis.IDENTITY) or not child.position.is_equal_approx(Vector3(0, child.shape.height * .5, 0)): return false
	return count == 1

func request(owner: RefCounted, body: CharacterBody3D, target: Vector3, trusted_admit: Callable) -> int:
	if not Thread.is_main_thread() or _disposed or _busy or _backend == null or not _geometry_valid or not _transitions.is_empty() or not trusted_admit.is_valid() or not owner is Queue.Owner or owner.dead or not is_instance_valid(body) or not body.is_inside_tree(): return -1
	if owner.source_id.is_empty() or owner.source_id.length() > 256 or owner.life_generation < 1 or body.get_world_3d().direct_space_state != _space() or not _body_supported(body): return -1
	var owner_id := owner.get_instance_id(); var body_id := body.get_instance_id()
	if _source_records.has(owner.source_id) and _records[int(_source_records[owner.source_id])].owner_id != owner_id: return -1
	if _body_records.has(body_id) and _records[int(_body_records[body_id])].owner_id != owner_id: return -1
	if _owner_records.has(owner_id): cancel(int(_owner_records[owner_id]))
	if _records.size() >= MAX_RECORDS: return -1
	var excludes: Array[RID] = [body.get_rid()]
	var native_id: int = _backend.request_path(owner, body.global_position, target, trusted_admit, excludes)
	if native_id < 0: return -1
	_next_id += 1
	_records[_next_id] = {"backend_id": native_id, "owner": weakref(owner), "owner_id": owner_id, "source_id": owner.source_id, "life_generation": owner.life_generation, "body": weakref(body), "body_id": body_id, "revision": _revision, "access_version": _access_version, "geometry_version": _geometry_version, "status": "PENDING", "reason": "", "path": PackedVector3Array(), "edge": 1, "target": target}
	_owner_records[owner_id] = _next_id; _body_records[body_id] = _next_id
	_source_records[owner.source_id] = _next_id
	return _next_id

# DSH_MOTION: the full answer for one already refreshed record. poll() and the
# status-only step() path share this exact field list, so no returned value changes.
func _poll_answer(record: Dictionary) -> Dictionary:
	return {"status": record.status, "reason": record.reason, "revision": record.revision, "access_version": record.access_version, "geometry_version": record.geometry_version, "current_access_version": _access_version, "current_geometry_version": _geometry_version, "source_id": record.source_id, "life_generation": record.life_generation}

# DSH_MOTION: the one status pull shared by poll() and poll_status(). Identical backend
# transitions; the steady-state branch asks the backend for the status string only.
func _refresh(record: Dictionary) -> void:
	# DSH_NAVSTEP2: --city-navstep-slim=1 applies the same three exact String ==
	# tests without building the three-element array literal on every call. Same
	# accepted set, same early return, same transitions below.
	if _dsh_slim < 0: _dsh_slim = _slim_flag()
	if _dsh_slim == 1:
		var dsh_accepted: String = record.status
		if dsh_accepted != "PENDING" and dsh_accepted != "READY" and dsh_accepted != "ARRIVED": return
	elif not record.status in ["PENDING", "READY", "ARRIVED"]: return
	if record.status == "PENDING":
		# One-time handoff: the validated proposal moves onto this record exactly as
		# before, so the full backend answer is taken here.
		var result: Dictionary = _backend.poll(record.backend_id)
		if result.status != "READY": record.status = result.status; record.reason = result.get("reason", "")
		else: record.path = result.path; record.status = "READY"
		return
	# DSH_MOTION: steady state needs only the status string. record.path already holds
	# the proposal, so the backend builds no result Dictionary and copies no array. A
	# terminal transition still takes the full answer once, so every reason string is
	# exactly the one poll() reported.
	# DSH_NAVSTEP3: --city-nav-arrived-static=1 skips this poll for an ARRIVED record.
	# The backend job of an ARRIVED record is READY, and every way it could stop being
	# READY (source republish, access change, door transition, cancel) runs through this
	# host's _invalidate()/cancel() first, which writes STALE into this same record and
	# erases the job. So the poll cannot change an ARRIVED record's status. 0 (default)
	# keeps today's poll.
	if _arrived_static_flag() == 1 and record.status == "ARRIVED": return
	if _backend.poll_status(record.backend_id) != "READY":
		var full: Dictionary = _backend.poll(record.backend_id)
		if full.status != "READY": record.status = full.status; record.reason = full.get("reason", "")
		else: record.path = full.path; record.status = "READY"

# DSH_MOTION: status-only sibling of poll() for callers that read only `status`.
# Same guards, same record bookkeeping, same backend transitions; no Dictionary is built.
func poll_status(id: int) -> String:
	if not Thread.is_main_thread(): return "INVALID_THREAD"
	if not _records.has(id): return "CANCELLED"
	var record: Dictionary = _records[id]
	var owner: RefCounted = record.owner.get_ref()
	if owner == null or owner.dead: cancel(id); return "CANCELLED"
	if not is_instance_valid(record.body.get_ref()): cancel(id); return "CANCELLED"
	_refresh(record)
	return record.status

func poll(id: int) -> Dictionary:
	if not Thread.is_main_thread(): return {"status": "INVALID_THREAD"}
	if not _records.has(id): return {"status": "CANCELLED"}
	var record: Dictionary = _records[id]
	var owner: RefCounted = record.owner.get_ref()
	if owner == null or owner.dead: cancel(id); return {"status": "CANCELLED"}
	if not is_instance_valid(record.body.get_ref()): cancel(id); return {"status": "CANCELLED"}
	_refresh(record)
	return _poll_answer(record)

# DSH_SIMLOD: the resident host may now hand this host a carried delta larger
# than one city step for the SAME per-record tier path it gates behind
# --city-sim-lod=1. Absent or 0 leaves this at .05, today's ceiling.
var _dsh_simlod_delta := -1.0  # DSH_SIMLOD

func _dsh_max_delta() -> float:  # DSH_SIMLOD
	if _dsh_simlod_delta < 0.0:
		_dsh_simlod_delta = .05
		var dsh_lod_on := false
		var dsh_cap := .2
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-sim-lod="):
				dsh_lod_on = int(argument.trim_prefix("--city-sim-lod=")) > 0
			elif argument.begins_with("--city-sim-max-delta="):
				dsh_cap = clampf(float(argument.trim_prefix("--city-sim-max-delta=")), .05, .5)
		if dsh_lod_on: _dsh_simlod_delta = dsh_cap
	return _dsh_simlod_delta

## Caller must own the body's physics tick (never run two movement controllers).
## Does not override floor/safe_margin/capsule settings or create an Agent.
func step(id: int, delta: float, speed: float, gravity: float) -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _busy or not _geometry_valid or not _transitions.is_empty() or not is_finite(delta) or delta <= 0.0 or (delta > .05 and delta > _dsh_max_delta()) or not is_finite(speed) or speed <= 0.0 or speed > 5.0 or not is_finite(gravity) or gravity < 0.0 or gravity > 30.0:
		if _dsh_split_on: _dsh_p_branch("invalid")  # DSH_NAVSTEP3
		return {"status": "INVALID_STEP"}
	if _dsh_split < 0: _dsh_split_flags()  # DSH_NAVSTEP3
	var dsh_t := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_p_enter(id)  # DSH_NAVSTEP3
	# DSH_MOTION: the refused-motion backoff. A record whose previous motion was
	# refused keeps its BLOCKED status and is re-admitted only on its next due tick;
	# a deferred tick performs no admission, no move_and_slide(), and changes neither
	# velocity nor status. --city-motion-retry 0/1 (default) retries every tick.
	var dsh_retry := _motion_retry()
	if _dsh_split_on: _dsh_p_add(0, dsh_t)  # DSH_NAVSTEP3: entry guard
	if dsh_retry > 1:
		var dsh_probe: Dictionary = _records.get(id, {})
		# DSH_NAVSTEP3: the test above can only ever see "BLOCKED" if some other writer
		# stored it; this host stores the refusal below instead, which is exactly the
		# record DSH_MOTION describes ("a record whose previous motion was refused").
		# dsh_tick counts THIS record's own due ticks, so the retry period is exactly N
		# due city steps for every record no matter how the city scheduler maps city
		# steps onto physics frames (a physics-frame modulo can miss every residue when
		# the step stride shares a factor with N and never retry at all). 0/1 (default)
		# never enters this block and is byte for byte today.
		if dsh_probe.get("status", "") == "BLOCKED" or bool(dsh_probe.get("dsh_refused", false)):
			var dsh_tick := int(dsh_probe.get("dsh_tick", 0)) + 1
			dsh_probe["dsh_tick"] = dsh_tick
			if (dsh_tick + _record_phase(dsh_probe)) % dsh_retry != 0:
				var dsh_ref: Variant = dsh_probe.get("body")
				var dsh_held: CharacterBody3D = dsh_ref.get_ref() if dsh_ref is WeakRef else null
				if not is_instance_valid(dsh_held): return poll(id)
				_dsh_motion_skips += 1
				if _dsh_split_on: _dsh_p_branch("retry"); _dsh_p_add(7, dsh_t)  # DSH_NAVSTEP3
				return {"status": "BLOCKED", "position": dsh_held.global_position, "step_metres": 0.0}
	# DSH_MOTION: only the status string is needed to decide this step, so the steady
	# state builds no answer Dictionary; every non-READY path still returns the exact
	# same values poll() returned (the record was refreshed by poll_status above).
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var dsh_polled := poll_status(id)  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_p_add(1, dsh_t)  # DSH_NAVSTEP3: poll / status resolution
	if dsh_polled != "READY":
		var dsh_late: Variant = _records.get(id)  # DSH_NAVSTEP3: one lookup, not has+index
		if not dsh_late is Dictionary:
			if _dsh_split_on: _dsh_p_branch("cancelled")  # DSH_NAVSTEP3
			return {"status": "CANCELLED"}
		# DSH_NAVSTEP2: --city-navstep-slim=1 hands back the record's own answer
		# object, rebuilt only when one of its nine fields changed. Same nine
		# fields, same values, same order as _poll_answer().
		if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
		var dsh_early: Dictionary = _answer_cached(dsh_late) if _dsh_slim == 1 else _poll_answer(dsh_late)  # DSH_NAVSTEP3
		if _dsh_split_on: _dsh_p_add(2, dsh_t); _dsh_p_branch("early")  # DSH_NAVSTEP3
		return dsh_early
	var record: Dictionary = _records[id]
	var body: CharacterBody3D = record.body.get_ref()
	if not is_instance_valid(body):
		if _dsh_split_on: _dsh_p_branch("cancelled")  # DSH_NAVSTEP3
		cancel(id); return {"status": "CANCELLED"}
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var dsh_body_ok: bool = _body_supported(body)  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_p_add(3, dsh_t)  # DSH_NAVSTEP3: _body_supported
	if not dsh_body_ok:
		if _dsh_split_on: _dsh_p_branch("unsupported")  # DSH_NAVSTEP3
		return {"status": "UNSUPPORTED_BODY"}
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var started := Time.get_ticks_usec(); var position := body.global_position
	var goal: Vector3 = record.target
	if Vector2(goal.x - position.x, goal.z - position.z).length() < .15 and absf(goal.y - position.y) < .30:
		record.status = "ARRIVED"; body.velocity = Vector3.ZERO
		if _dsh_split_on: _dsh_p_add(6, dsh_t); _dsh_p_branch("arrived")  # DSH_NAVSTEP3
		return poll(id)
	var path: PackedVector3Array = record.path
	while record.edge < path.size() - 1:
		var offset: Vector3 = path[record.edge] - position
		if Vector2(offset.x, offset.z).length() > .25 or absf(offset.y) > .30: break
		record.edge += 1
	var waypoint: Vector3 = path[mini(record.edge, path.size() - 1)]
	var direction := Vector3(waypoint.x - position.x, 0, waypoint.z - position.z)
	var travel_speed := minf(speed, direction.length() / delta)
	var velocity := direction.normalized() * travel_speed
	velocity.y = -2.0 if body.is_on_floor() else body.velocity.y - gravity * delta
	# Grounded downward bias is intentionally resolved against the floor by
	# move_and_slide/snap. Casting that bias into the floor would reject every
	# ramp crest. Validate the lateral capsule sweep; airborne steps include Y.
	var admitted_velocity := velocity
	if body.is_on_floor(): admitted_velocity.y = 0.0
	if _dsh_split_on: _dsh_p_add(6, dsh_t)  # DSH_NAVSTEP3: goal/path/velocity bookkeeping
	_busy = true
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var allowed: bool = _backend.admit_motion(record.backend_id, position, position + admitted_velocity * delta)
	if _dsh_split_on: _dsh_p_add(4, dsh_t)  # DSH_NAVSTEP3: source proof + swept capsule
	_busy = false
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	if allowed:
		# DSH_TICKSCALE: move_and_slide() advances by the engine's fixed physics delta, so a
		# step that covers several batched ticks must scale the velocity by the same factor.
		# Exactly 1.0 for an ordinary one-tick step: default behaviour is unchanged.
		var dsh_tick_scale := delta * float(Engine.physics_ticks_per_second)
		if dsh_tick_scale < 1.0: dsh_tick_scale = 1.0
		body.velocity = velocity * dsh_tick_scale
		body.move_and_slide()
		if dsh_retry > 1: record["dsh_refused"] = false  # DSH_NAVSTEP3
		if _dsh_split_on: _dsh_p_branch("move")  # DSH_NAVSTEP3
	else:
		body.velocity = Vector3.ZERO; _stats.blocked_steps += 1
		if dsh_retry > 1: record["dsh_refused"] = true; record["dsh_tick"] = 0  # DSH_NAVSTEP3
		if _dsh_split_on: _dsh_p_branch("blocked")  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_p_add(5, dsh_t)  # DSH_NAVSTEP3: move_and_slide + resolution
	_stats.steps += 1
	var spent := Time.get_ticks_usec() - started
	_stats.step_us_total += spent; _stats.step_us_max = maxi(_stats.step_us_max, spent)
	_dsh_step_max_us = maxi(_dsh_step_max_us, spent)  # DSH_NAVDAILY: interval max for DSH_NAVSTEP
	var dsh_result: Dictionary = {"status": "READY" if allowed else "BLOCKED", "position": body.global_position, "step_metres": body.global_position.distance_to(position)}
	if _dsh_split_on: _dsh_p_add(6, dsh_t)  # DSH_NAVSTEP3: stats + answer Dictionary
	return dsh_result

## DSH_NAVDAILY (temporary): additive accessor for the real per-step cost counters.
## step_us_max is the maximum single step since the previous counters() call, so a
## once-per-second probe reports the worst step inside that second; the global running
## maximum stays in _stats.step_us_max and is unchanged.
func counters() -> Dictionary:
	var result := {"steps": int(_stats.steps), "step_us_total": int(_stats.step_us_total), "step_us_max": _dsh_step_max_us, "blocked_steps": int(_stats.blocked_steps), "motion_retry_skips": _dsh_motion_skips}
	# DSH_NAVSTEP3: additive fields of the same counters() the DSH_NAVSTEP line already
	# reads. Every bucket stays 0 while --city-navsplit=0 (default), and no existing key
	# above changed name, meaning or type.
	result["split_on"] = _dsh_split_on
	result["split_steps"] = _dsh_p_steps
	result["split_calls"] = _dsh_p_calls
	result["split_guard_us"] = int(_dsh_p_us[0])
	result["split_poll_us"] = int(_dsh_p_us[1])
	result["split_answer_us"] = int(_dsh_p_us[2])
	result["split_body_us"] = int(_dsh_p_us[3])
	result["split_admit_us"] = int(_dsh_p_us[4])
	result["split_move_us"] = int(_dsh_p_us[5])
	result["split_tail_us"] = int(_dsh_p_us[6])
	result["split_other_us"] = int(_dsh_p_us[7])
	result["split_entry"] = _dsh_p_entry.duplicate()
	result["split_end"] = _dsh_p_end.duplicate()
	_dsh_step_max_us = 0
	return result

func _dsh_pump_cadence() -> int:  # DSH_NAVDAILY
	if _dsh_pump_every < 0:
		_dsh_pump_every = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-pump-every="):
				_dsh_pump_every = maxi(1, int(argument.trim_prefix("--city-nav-pump-every=")))
	return _dsh_pump_every

# DSH_MOTION: --city-motion-retry=N. 0/1 (default) keeps the previous behaviour: a
# refused motion is retried on every tick.
func _motion_retry() -> int:
	if _dsh_motion_retry < 0:
		_dsh_motion_retry = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-motion-retry="):
				_dsh_motion_retry = maxi(0, int(argument.trim_prefix("--city-motion-retry=")))
	return _dsh_motion_retry

# DSH_MOTION: --city-timing=0 skips only the per-call diagnostic sample records.
# DSH_NAVSTEP's counters stay exact. Default 1.
func _timing_records() -> bool:
	if _dsh_timing < 0:
		_dsh_timing = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-timing="):
				_dsh_timing = maxi(0, int(argument.trim_prefix("--city-timing=")))
	return _dsh_timing != 0

## DSH_MOTION: stable per-record stagger phase (the same 31-multiplier shape as the
## engine admit TTL and the resident host's floor-recovery retry).
func _record_phase(record: Dictionary) -> int:
	if record.has("dsh_phase"): return int(record["dsh_phase"])
	var value := 0
	var text_id: String = str(record.get("source_id", ""))
	for index in text_id.length():
		value = (value * 31 + text_id.unicode_at(index)) & 0x7fffffff
	record["dsh_phase"] = value
	return value

# DSH_NAVSTEP2: --city-navstep-slim=1 enables the allocation-free hot-path variants.
# 0 (default) keeps today's code path.
func _slim_flag() -> int:
	if _dsh_slim < 0:
		_dsh_slim = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-navstep-slim="):
				_dsh_slim = maxi(0, int(argument.trim_prefix("--city-navstep-slim=")))
	return _dsh_slim

# DSH_NAVSTEP2: the same nine fields in the same order as _poll_answer(), rebuilt
# only when one of them changed. The returned Dictionary is owned by the record:
# read it in place (every in-tree caller reads `status` immediately) and copy it
# before retaining it.
func _answer_cached(record: Dictionary) -> Dictionary:
	var dsh_cached: Variant = record.get("dsh_answer")
	if dsh_cached is Dictionary:
		var dsh_answer: Dictionary = dsh_cached
		if dsh_answer.status == record.status and dsh_answer.reason == record.reason and dsh_answer.revision == record.revision and dsh_answer.access_version == record.access_version and dsh_answer.geometry_version == record.geometry_version and dsh_answer.current_access_version == _access_version and dsh_answer.current_geometry_version == _geometry_version and dsh_answer.source_id == record.source_id and dsh_answer.life_generation == record.life_generation:
			return dsh_answer
	var dsh_fresh: Dictionary = _poll_answer(record)
	record["dsh_answer"] = dsh_fresh
	return dsh_fresh

# DSH_NAVSTEP3: --city-navsplit=1 only observes. Eight usec buckets and two histograms
# per wall second; --city-navsplit=0 (default) leaves _dsh_split_on false so none of this
# runs and every existing counter keeps its exact meaning.
# --city-nav-arrived-static=1 skips the backend poll for a record whose own status is
# already ARRIVED; 0 (default) keeps today's poll. See apply_nav_step2.py.
func _dsh_split_flags() -> void:
	_dsh_split = 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--city-navsplit="):
			_dsh_split = maxi(0, int(argument.trim_prefix("--city-navsplit=")))
	_dsh_split_on = _dsh_split == 1

func _arrived_static_flag() -> int:
	if _dsh_arrived_static < 0:
		_dsh_arrived_static = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-arrived-static="):
				_dsh_arrived_static = maxi(0, int(argument.trim_prefix("--city-nav-arrived-static=")))
	return _dsh_arrived_static

func _dsh_p_add(bucket: int, started: int) -> void:  # DSH_NAVSTEP3
	_dsh_p_us[bucket] = int(_dsh_p_us[bucket]) + Time.get_ticks_usec() - started

func _dsh_p_branch(name: String) -> void:  # DSH_NAVSTEP3
	_dsh_p_end[name] = int(_dsh_p_end.get(name, 0)) + 1

func _dsh_p_enter(id: int) -> void:  # DSH_NAVSTEP3
	var frame := Engine.get_physics_frames()
	if frame != _dsh_p_frame:
		_dsh_p_frame = frame
		_dsh_p_steps += 1
	_dsh_p_calls += 1
	var rec: Variant = _records.get(id)
	var status := "MISSING"
	if rec is Dictionary: status = str(rec.status)
	_dsh_p_entry[status] = int(_dsh_p_entry.get(status, 0)) + 1
	if Time.get_ticks_msec() - _dsh_p_ms >= 1000: _dsh_p_report()

func _dsh_p_report() -> void:  # DSH_NAVSTEP3
	var now := Time.get_ticks_msec()
	var engine_now: Dictionary = _backend.split_counters() if _backend != null else {}
	if _dsh_p_ms == 0 or now <= _dsh_p_ms:
		_dsh_p_ms = now; _dsh_p_steps = 0; _dsh_p_calls = 0
		_dsh_p_us = [0, 0, 0, 0, 0, 0, 0, 0]; _dsh_p_entry = {}; _dsh_p_end = {}
		_dsh_p_prev = engine_now
		return
	var dt := float(now - _dsh_p_ms) / 1000.0
	var steps := maxi(1, _dsh_p_steps)
	var buckets: Array = _dsh_p_us
	var guard := int(buckets[0]) / steps
	var poll := int(buckets[1]) / steps
	var answer := int(buckets[2]) / steps
	var body := int(buckets[3]) / steps
	var admit := int(buckets[4]) / steps
	var move := int(buckets[5]) / steps
	var tail := int(buckets[6]) / steps
	var other := int(buckets[7]) / steps
	var delta := {}
	for key: String in engine_now:
		delta[key] = int(engine_now[key]) - int(_dsh_p_prev.get(key, 0))
	var e_admit := int(delta.get("admit_us", 0)) / steps
	var e_clear := int(delta.get("clear_us", 0)) / steps
	var e_shape := int(delta.get("clear_shape_us", 0)) / steps
	var e_cast := int(delta.get("clear_cast_us", 0)) / steps
	var e_centry := int(delta.get("clear_entry_us", 0)) / steps
	var e_poll := int(delta.get("poll_us", 0)) / steps
	var e_mapi := int(delta.get("mapi_us", 0)) / steps
	var e_motion := int(delta.get("motion_us", 0)) / steps
	var e_mshape := int(delta.get("move_shape_us", 0)) / steps
	var e_mcast := int(delta.get("move_cast_us", 0)) / steps
	print("DSH_NAVSTEP3 dt=", "%.2f" % dt, " steps=", steps, " calls/s=", _dsh_p_calls,
		" calls/step=", "%.1f" % (float(_dsh_p_calls) / float(steps)),
		" us/step: guard=", guard, " poll=", poll, " answer=", answer, " body=", body,
		" admit=", admit, " move=", move, " tail=", tail, " other=", other,
		" total=", guard + poll + answer + body + admit + move + tail + other,
		" | entry=", _dsh_p_entry, " end=", _dsh_p_end)
	print("DSH_NAVSTEP3B us/step: eng_src_admit=", e_admit, " eng_clear=", e_clear,
		" eng_shape=", e_shape, " eng_cast=", e_cast, " eng_clear_entry=", e_centry,
		" eng_move_shape=", e_mshape, " eng_move_cast=", e_mcast,
		" eng_poll=", e_poll, " eng_mapi=", e_mapi, " eng_motion=", e_motion,
		" | 1s=", delta, " retry_skips_total=", _dsh_motion_skips)
	_dsh_p_ms = now; _dsh_p_steps = 0; _dsh_p_calls = 0
	_dsh_p_us = [0, 0, 0, 0, 0, 0, 0, 0]; _dsh_p_entry = {}; _dsh_p_end = {}
	_dsh_p_prev = engine_now

func cancel(id: int) -> void:
	if not Thread.is_main_thread() or _busy or not _records.has(id): return
	var record: Dictionary = _records[id]
	var body: CharacterBody3D = record.body.get_ref()
	if is_instance_valid(body): body.velocity = Vector3.ZERO
	_backend.cancel(record.backend_id)
	_owner_records.erase(record.owner_id); _body_records.erase(record.body_id); _records.erase(id)
	_source_records.erase(record.source_id)

func diagnostics() -> Dictionary:
	if not Thread.is_main_thread(): return {"state": "INVALID_THREAD"}
	return {"state": state(), "errors": _errors.duplicate(), "stats": _stats.duplicate(), "records": _records.size(), "nav_only_proposal_envelopes":_proposal_count, "nav_only_proposal_triangles":_proposal_triangles, "transitions": _transitions.size(), "disposed": _disposed, "backend": _backend.diagnostics() if _backend != null else {}}

func dispose() -> void:
	if not Thread.is_main_thread() or _disposed or _busy: return
	for id: int in _records.keys(): cancel(id)
	if _backend != null: _backend.dispose()
	var scene: Node3D = _root.get_ref() if _root != null else null
	if is_instance_valid(scene) and scene.tree_exiting.is_connected(dispose): scene.tree_exiting.disconnect(dispose)
	_disposed = true; _static.clear(); _leaves.clear(); _transitions.clear(); _queue = null

## Explicit opt-in API. Supplied nodes must be the real already-attached typed
## source hospital/bank geometry. No other missing body can become a proposal.
func attach_city_existing(scene: Node3D, interior: Node3D, block: Dictionary, data: Dictionary, queue: RefCounted, authority: String, generation: int, access_version: int, sites: Array[Node3D]) -> bool:
	if _backend!=null or _disposed or not _proposal_sites.is_empty() or sites.size()>2: return false
	for site: Node3D in sites:
		if not is_instance_valid(site) or site.get_parent()!=scene or not site.is_inside_tree() or not site.global_transform.is_equal_approx(Transform3D.IDENTITY): return _fail("actual-service-site-required")
		if not site is Hospital and not site is Bank: return _fail("unsupported-service-proposal-site")
		if not site.ready_for_use: return _fail("service-geometry-not-ready")
		var id: String=site.SOURCE_ID
		if _proposal_sites.has(id): return _fail("duplicate-service-proposal")
		var record: Dictionary={}
		for item: Dictionary in block.buildings:
			if item.id==id: record=item; break
		var source: Dictionary=site._data
		if record.is_empty() or source.get("sourceId")!=id or source.get("assetSha256")!=site.ASSET_SHA or record.get("binding",{}).get("sha256")!=site.ASSET_SHA or source.get("transform")!=record.get("transform"): return _fail("service-source-record-mismatch")
		if source.get("originM")!=block.get("originM"): return _fail("service-source-origin-mismatch")
		var count:=3 if site is Hospital else 1
		var indices: Variant=source.get("replaceCollisionSourceIndices",[])
		if record.get("collisionBodiesM",[]).size()!=count or not indices is Array or indices.size()!=count: return _fail("service-exterior-envelope-indices")
		for index in count:
			if typeof(indices[index]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(indices[index])) or float(indices[index])!=float(index): return _fail("service-exterior-envelope-indices")
		_proposal_sites[id]={"node":weakref(site),"script":site.get_script(),"source":source,"record":record.duplicate(true),"asset":site.ASSET_SHA}
	return attach_existing(scene,interior,block,data,queue,authority,generation,access_version)

func _proposals_current() -> bool:
	if _proposal_sites.is_empty(): return true
	var scene: Node3D=_root.get_ref() if _root!=null else null
	if not is_instance_valid(scene): return false
	var block: Dictionary=scene.get("_block")
	for id: String in _proposal_sites:
		var pin: Dictionary=_proposal_sites[id]
		var site: Node3D=pin.node.get_ref()
		if not is_instance_valid(site) or not site.ready_for_use or site.get_parent()!=scene or site.get_script()!=pin.script or not site.global_transform.is_equal_approx(Transform3D.IDENTITY) or not is_same(site._data,pin.source): return false
		if site._data.get("assetSha256")!=pin.asset or site._data.get("sourceId")!=id or site._data.get("transform")!=pin.record.transform: return false
		var matching:=false
		for record: Dictionary in block.buildings:
			if record.id==id: matching=record==pin.record; break
		if not matching: return false
	return true
