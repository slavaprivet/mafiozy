extends RefCounted
## Existing-world adapter. No population, permission defaults, navigation agents,
## rendering mesh reads, new physics nodes or modifications to the scene owner.
const Backend = preload("res://scripts/navigation/preview_engine_navigation.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Interior = preload("res://scripts/preview_printshop_interior.gd")
const PalazzoOnly = preload("res://scripts/palazzo_only_preview.gd")
const SOURCE_BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const MAX_RECORDS := 128
const MODULAR_NO_ENTRY_SOURCE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
var _retired_nav: Dictionary = {}
var _retired_nav_host: WeakRef
var _retired_nav_replacement: WeakRef
var _retired_nav_runtime_id := 0
var _root: WeakRef
var _interior: WeakRef
var _outdoor_only := false
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
var _stats := {"captures": 0, "static_shapes": 0, "door_shapes": 0, "triangles": 0, "capture_us": 0, "publications": 0, "transition_starts": 0, "steps": 0, "blocked_steps": 0, "step_us_total": 0, "step_us_max": 0}

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
	for body: Dictionary in data.get("staticBodies", []):
		var points := PackedVector3Array()
		for p: Array in body.polygonXZ:
			points.append(Vector3(p[0], body.minY, p[1])); points.append(Vector3(p[0], body.maxY, p[1]))
		var key := "interior:" + _points_key(points)
		if result.has(key): _fail("duplicate-interior-collision"); return {}
		result[key] = {"points": points, "frame": Transform3D.IDENTITY, "kind": "convex"}
	for door: String in data.get("doors", {}):
		for body: Dictionary in data.doors[door].bodies:
			var points := PackedVector3Array()
			for p: Array in body.pointsLocal: points.append(_v(p))
			var key := "door:" + door + ":" + _points_key(points)
			if result.has(key): _fail("duplicate-door-collision"); return {}
			result[key] = {"points": points, "kind": "door", "door": door}
	# These CPU source arrays are also what the current interior adapter stores
	# in its ConcavePolygonShape3D; no render resource is read back.
	for spec: Dictionary in data.get("meshes", []):
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


## Explicit conservative NAV-ONLY envelope for one inactive source. Physics
## ownership stays with Modular30Host; no hull/layer/shape is restored here.
func _prepare_retired_navigation(scene: Node3D, block: Dictionary) -> bool:
	var host: Variant = scene.get("preview_modular30")
	if not is_instance_valid(host): return true
	if host.get("status") not in ["geometry_ready_waiting_native_weapons","ready"]: return true
	if host.get_parent()!=scene or host.get_script()==null or host.get_script().resource_path!="res://scripts/destruction/modular30/modular30_host.gd" or not host.has_method("navigation_retirement_receipt"): return _fail("unverified-modular-navigation-owner")
	var source: Dictionary = {}
	for row: Dictionary in block.buildings:
		if row.get("id")==MODULAR_NO_ENTRY_SOURCE:
			if not source.is_empty(): return _fail("duplicate-modular-navigation-source")
			source=row
	if source.get("assetId")!="old_town_narrow_townhouse_v1" or source.get("gameplayActive")!=false or source.get("sourceGameplayActive")!=false or source.get("gameplayId")!=null or source.get("collisionBodiesM",[]).size()!=2: return _fail("modular-navigation-no-entry-policy-required")
	var receipt: Dictionary = host.navigation_retirement_receipt()
	if receipt.get("ok")!=true or receipt.get("enabled")!=true or receipt.get("gameplayActive")!=false or receipt.get("sourceGameplayActive")!=false or receipt.get("schema")!="modular30_nav_no_entry/v1" or receipt.get("policy")!="conservative_original_hulls_no_entry" or receipt.get("source_id")!=MODULAR_NO_ENTRY_SOURCE or receipt.get("world_instance_id")!=scene.get_instance_id() or receipt.get("world_rid")!=scene.get_world_3d().space or receipt.get("host_instance_id")!=host.get_instance_id() or not receipt.get("retired") is Array or receipt.retired.size()!=2: return _fail("modular-navigation-retirement-receipt")
	var indices: Dictionary = {}
	for body: Variant in receipt.retired:
		if not body is StaticBody3D or not is_instance_valid(body) or body.get_parent()!=scene or body.get_script()!=null or body.get_meta("source_id","")!=MODULAR_NO_ENTRY_SOURCE or body.get_child_count()!=1 or body.collision_layer!=0 or body.collision_mask!=0: return _fail("modular-navigation-retired-native-identity")
		var index: Variant = body.get_meta("source_index",null)
		var shape: Node = body.get_child(0)
		if (not index is int and not index is float) or not is_finite(float(index)): return _fail("modular-navigation-source-index-type")
		var normalized_index := int(index)
		if float(index)!=float(normalized_index) or normalized_index not in [0,1] or indices.has(normalized_index) or not shape is CollisionShape3D or shape.disabled or not shape.shape is ConvexPolygonShape3D: return _fail("modular-navigation-original-two-shapes")
		indices[normalized_index]=true
		_retired_nav[body.get_instance_id()]={"body":weakref(body),"rid":body.get_rid(),"shape_node":weakref(shape),"shape":shape.shape,"points":shape.shape.points.duplicate(),"index":normalized_index}
	_retired_nav_host=weakref(host)
	var replacement: Variant = receipt.get("replacement_body")
	if not replacement is StaticBody3D or not is_instance_valid(replacement): return _fail("modular-navigation-replacement-required")
	_retired_nav_replacement=weakref(replacement); _retired_nav_runtime_id=int(receipt.get("runtime_instance_id",0))
	# The unchanged capture below still checks exact original points, frames,
	# uniqueness and every other source shape. No generic layer0 exception.
	return _retired_navigation_current(scene)

func _retired_navigation_current(scene: Node3D = null) -> bool:
	if _retired_nav.is_empty(): return true
	if scene==null: scene=_root.get_ref() if _root!=null else null
	var host: Variant = _retired_nav_host.get_ref() if _retired_nav_host!=null else null
	var replacement: Variant = _retired_nav_replacement.get_ref() if _retired_nav_replacement!=null else null
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree() or scene.get("preview_modular30")!=host or host.get_parent()!=scene or not is_instance_valid(replacement) or not replacement.is_inside_tree() or replacement.is_queued_for_deletion(): return false
	var receipt: Dictionary = host.navigation_retirement_receipt()
	if receipt.get("ok")!=true or receipt.get("enabled")!=true or receipt.get("gameplayActive")!=false or receipt.get("sourceGameplayActive")!=false or receipt.get("schema")!="modular30_nav_no_entry/v1" or receipt.get("policy")!="conservative_original_hulls_no_entry" or receipt.get("source_id")!=MODULAR_NO_ENTRY_SOURCE or receipt.get("world_instance_id")!=scene.get_instance_id() or receipt.get("world_rid")!=scene.get_world_3d().space or receipt.get("host_instance_id")!=host.get_instance_id() or receipt.get("replacement_body")!=replacement or receipt.get("runtime_instance_id")!=_retired_nav_runtime_id or not receipt.get("generation") is int or receipt.generation<1 or not receipt.get("retired") is Array or receipt.retired.size()!=2: return false
	if replacement.get_parent()==null or replacement.get_parent().get_instance_id()!=_retired_nav_runtime_id or not host.is_ancestor_of(replacement) or replacement.collision_layer!=1 or replacement.collision_mask!=1 or replacement.get_meta("source_id","")!=MODULAR_NO_ENTRY_SOURCE or replacement.get_meta("destruction_surface_body",false)!=true or replacement.get_child_count()!=1 or not replacement.global_transform.is_equal_approx(Transform3D.IDENTITY): return false
	var native_shape: Node = replacement.get_child(0)
	if not native_shape is CollisionShape3D or native_shape.disabled or not native_shape.shape is ConcavePolygonShape3D or not native_shape.transform.is_equal_approx(Transform3D.IDENTITY) or receipt.get("replacement_shape_id")!=native_shape.shape.get_instance_id(): return false
	var seen: Dictionary = {}
	for body: Variant in receipt.retired:
		if not body is StaticBody3D or not is_instance_valid(body) or body.is_queued_for_deletion() or not _retired_nav.has(body.get_instance_id()) or seen.has(body.get_instance_id()): return false
		seen[body.get_instance_id()]=true
		var pinned: Dictionary = _retired_nav[body.get_instance_id()]
		var shape: Variant = pinned.shape_node.get_ref()
		if pinned.body.get_ref()!=body or body.get_rid()!=pinned.rid or body.get_parent()!=scene or body.collision_layer!=0 or body.collision_mask!=0 or body.get_meta("source_id","")!=MODULAR_NO_ENTRY_SOURCE or body.get_meta("source_index",-1)!=pinned.index or body.get_child_count()!=1 or not is_instance_valid(shape) or body.get_child(0)!=shape or shape.disabled or shape.shape!=pinned.shape or shape.shape.points!=pinned.points or not shape.global_transform.is_equal_approx(Transform3D.IDENTITY): return false
	return true

func _guard_retired_navigation() -> bool:
	if _retired_navigation_current(): return true
	if _geometry_valid:
		_invalidate("modular-no-entry-lease-ended"); _fail("modular-no-entry-lease-ended")
	_geometry_valid=false
	return false

## Data must be the already-validated records used to build these exact nodes.
## root and interior are scene-root coordinates; physics owner remains main.
func attach_existing(scene: Node3D, interior: Node3D, block: Dictionary, data: Dictionary, queue: RefCounted, authority: String, generation: int, access_version: int) -> bool:
	if not Thread.is_main_thread() or _disposed or _backend != null: return false
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return _fail("missing-existing-world")
	if not scene.global_transform.is_equal_approx(Transform3D.IDENTITY): return _fail("unexpected-world-frame")
	if not queue is Queue or authority.is_empty() or generation < 1 or access_version < 0: return _fail("invalid-authority-or-queue")
	if block != scene.get("_block"): return _fail("data-not-current-built-world")
	_outdoor_only = scene.get_meta("preview_building_mode", "") == PalazzoOnly.MODE
	if _outdoor_only:
		# Explicit composition only: never retain a hidden/fake interior for NPCs.
		if interior != null or scene.get("_printshop") != null or scene.get("preview_modular30") != null or not data.is_empty() or scene.get("_printshop_data") != data: return _fail("outdoor-only-owner-mismatch")
		var source_path := str(scene.get("block_data_path"))
		if FileAccess.get_sha256(source_path) != SOURCE_BLOCK_SHA: return _fail("outdoor-only-source-bytes")
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		if not PalazzoOnly.is_current(source, block): return _fail("outdoor-only-runtime-projection")
	else:
		if not is_instance_valid(interior) or not interior is Interior or not interior.ready_for_use or interior.get_parent() != scene: return _fail("missing-existing-world")
		if not interior.global_transform.is_equal_approx(Transform3D.IDENTITY): return _fail("unexpected-world-frame")
		if data != interior.get("_data"): return _fail("data-not-current-built-world")
	var started := Time.get_ticks_usec()
	var expected := _expected(block, data)
	if not _errors.is_empty() or expected.is_empty(): return false
	if not _prepare_retired_navigation(scene,block): return false
	var seen: Dictionary = {}
	var candidates: Array[Node] = []
	# No traversal of render assets, actors, sensors or arbitrary descendants.
	for child: Node in scene.get_children():
		if child is StaticBody3D: candidates.append(child)
	if not _outdoor_only:
		for child: Node in interior.get_children():
			if child is StaticBody3D: candidates.append(child)
			elif str(child.name) in ["SourceDoor_public", "SourceDoor_service"]:
				for leaf: Node in child.get_children():
					if leaf is StaticBody3D: candidates.append(leaf)
	if candidates.size() > 512: return _capture_failed("source-shape-limit")
	for body: StaticBody3D in candidates:
		var retired_navigation_only: bool = _retired_nav.has(body.get_instance_id())
		if (body.collision_layer != 1 and not retired_navigation_only) or body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D: return _capture_failed("unsupported-static-body")
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
	if seen.size() != expected.size(): return _capture_failed("missing-source-shapes")
	_root = weakref(scene); _interior = null if _outdoor_only else weakref(interior); _queue = queue
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
	if not Thread.is_main_thread() or _disposed or _busy or _backend == null or _outdoor_only or not key in ["public", "service"] or not target_fraction in [0.0, 1.0]: return false
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
	if not _guard_retired_navigation(): return
	# Outdoor-only still pumps the real navigation backend on every normal
	# population tick. There are no printshop leaves or visits to settle.
	var interior: Node3D = _interior.get_ref() if _interior != null else null
	if not _outdoor_only and (not is_instance_valid(interior) or not interior.ready_for_use): dispose(); return
	if _outdoor_only:
		var scene: Node3D = _root.get_ref() if _root != null else null
		if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.get_meta("preview_building_mode", "") != PalazzoOnly.MODE or scene.get("_printshop") != null or scene.get("preview_modular30") != null: dispose(); return
	var settled := false
	for key: String in _transitions.keys():
		if is_equal_approx(interior.door_fraction(key), _transitions[key]): _transitions.erase(key); settled = true
	# Only publish after all known transitions settle. No per-fraction rebuild.
	if settled and _transitions.is_empty():
		if not _publish(): _invalidate("door-publication-failed"); return
	if not _transitions.is_empty(): return
	for leaf: Dictionary in _leaves:
		var node: CollisionShape3D = leaf.node.get_ref()
		if not is_instance_valid(node) or not node.global_transform.is_equal_approx(leaf.frame):
			if _geometry_valid: _invalidate("unannounced-door-motion"); _fail("unannounced-door-motion")
			_geometry_valid = false; return
	if not _geometry_valid: return
	_busy = true
	_backend.pump(frame_id)
	_busy = false

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
	if not _guard_retired_navigation(): return -1
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

func poll(id: int) -> Dictionary:
	if not Thread.is_main_thread(): return {"status": "INVALID_THREAD"}
	if not _records.has(id): return {"status": "CANCELLED"}
	var record: Dictionary = _records[id]
	var owner: RefCounted = record.owner.get_ref()
	if owner == null or owner.dead: cancel(id); return {"status": "CANCELLED"}
	if not is_instance_valid(record.body.get_ref()): cancel(id); return {"status": "CANCELLED"}
	if record.status in ["PENDING", "READY", "ARRIVED"]:
		var result: Dictionary = _backend.poll(record.backend_id)
		if result.status != "READY": record.status = result.status; record.reason = result.get("reason", "")
		elif record.status == "PENDING": record.path = result.path; record.status = "READY"
	return {"status": record.status, "reason": record.reason, "revision": record.revision, "access_version": record.access_version, "geometry_version": record.geometry_version, "current_access_version": _access_version, "current_geometry_version": _geometry_version, "source_id": record.source_id, "life_generation": record.life_generation}

## Caller must own the body's physics tick (never run two movement controllers).
## Does not override floor/safe_margin/capsule settings or create an Agent.
func step(id: int, delta: float, speed: float, gravity: float) -> Dictionary:
	if not Thread.is_main_thread() or _disposed or _busy or not _geometry_valid or not _transitions.is_empty() or not is_finite(delta) or delta <= 0.0 or delta > .05 or not is_finite(speed) or speed <= 0.0 or speed > 5.0 or not is_finite(gravity) or gravity < 0.0 or gravity > 30.0: return {"status": "INVALID_STEP"}
	if not _guard_retired_navigation(): return {"status":"INVALID_GEOMETRY"}
	var status := poll(id)
	if status.status != "READY": return status
	var record: Dictionary = _records[id]
	var body: CharacterBody3D = record.body.get_ref()
	if not is_instance_valid(body): cancel(id); return {"status": "CANCELLED"}
	if not _body_supported(body): return {"status": "UNSUPPORTED_BODY"}
	var started := Time.get_ticks_usec(); var position := body.global_position
	var goal: Vector3 = record.target
	if Vector2(goal.x - position.x, goal.z - position.z).length() < .15 and absf(goal.y - position.y) < .30:
		record.status = "ARRIVED"; body.velocity = Vector3.ZERO; return poll(id)
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
	_busy = true
	var allowed: bool = _backend.admit_motion(record.backend_id, position, position + admitted_velocity * delta)
	_busy = false
	if allowed:
		body.velocity = velocity; body.move_and_slide()
	else:
		body.velocity = Vector3.ZERO; _stats.blocked_steps += 1
	_stats.steps += 1
	var spent := Time.get_ticks_usec() - started
	_stats.step_us_total += spent; _stats.step_us_max = maxi(_stats.step_us_max, spent)
	return {"status": "READY" if allowed else "BLOCKED", "position": body.global_position, "step_metres": body.global_position.distance_to(position)}

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
	return {"outdoor_only": _outdoor_only, "runtime_geometry_mode": PalazzoOnly.MODE if _outdoor_only else "source_block", "conservative_nav_only_retired_hulls":_retired_nav.size(), "conservative_nav_only_source":MODULAR_NO_ENTRY_SOURCE if not _retired_nav.is_empty() else "", "npc_breach_entry":false, "state": state(), "errors": _errors.duplicate(), "stats": _stats.duplicate(), "records": _records.size(), "transitions": _transitions.size(), "disposed": _disposed, "backend": _backend.diagnostics() if _backend != null else {}}

func dispose() -> void:
	if not Thread.is_main_thread() or _disposed or _busy: return
	for id: int in _records.keys(): cancel(id)
	if _backend != null: _backend.dispose()
	var scene: Node3D = _root.get_ref() if _root != null else null
	if is_instance_valid(scene) and scene.tree_exiting.is_connected(dispose): scene.tree_exiting.disconnect(dispose)
	_disposed = true; _static.clear(); _leaves.clear(); _transitions.clear(); _queue = null
	_retired_nav.clear(); _retired_nav_host=null; _retired_nav_replacement=null
