extends RefCounted
## Read-only shoreline admission, additional to the caller's full capsule sweep.
## Grid labels never create support: every wet/bridge footprint needs live floors.
const EDGE_MARGIN := 0.002
const DRY_CLEARANCE := 0.02
const SUPPORT_DELTA := 0.18
const RIM_SAMPLES := 16
var _scene: Node3D
var _body: CharacterBody3D
var _shape: CollisionShape3D
var _grid: Array = []
var _palette: Dictionary = {}
var _origin := Vector3.ZERO
var _start := Vector2i.ZERO
var _cell_size := 0.0
var _water_y := -INF
var ready := false
var queries := 0

func configure(scene: Node3D, actor: CharacterBody3D) -> bool:
	ready = false
	if not is_instance_valid(scene) or not is_instance_valid(actor): return false
	# main._build_surface uses source X/Z minus origin; height is not origin-relative.
	var block: Variant = scene.get("_block")
	var origin: Variant = scene.get("_origin")
	if not block is Dictionary or not origin is Vector3: return false
	var surface: Variant = block.get("surface")
	if not surface is Dictionary or not surface.get("grid") is Array or not surface.get("palette") is Dictionary: return false
	_cell_size = float(surface.get("cellSize", 0.0))
	if _cell_size <= 0.0 or not scene.global_basis.is_equal_approx(Basis.IDENTITY): return false
	_scene = scene; _body = actor; _origin = origin
	_grid = surface.grid; _palette = surface.palette
	_start = Vector2i(int(surface.get("startCol", 0)), int(surface.get("startRow", 0)))
	_shape = null
	for child: Node in actor.get_children():
		if child is CollisionShape3D and not child.disabled:
			if _shape != null or not child.shape is CapsuleShape3D: return false
			_shape = child
	if _shape == null or _grid.is_empty(): return false
	# This route's actor position is its feet. Do not silently shrink/offset a capsule.
	if not is_equal_approx(_shape.position.y, (_shape.shape as CapsuleShape3D).height * 0.5): return false
	_water_y = -INF
	for entry: Variant in _palette.values():
		if entry is Dictionary and str(entry.get("kind", "")) == "water":
			_water_y = maxf(_water_y, float(entry.get("heightM", 0.0)) + scene.global_position.y)
	ready = is_finite(_water_y) and _upright_capsule()
	return ready

func _upright_capsule() -> bool:
	return is_instance_valid(_scene) and is_instance_valid(_body) and is_instance_valid(_shape) and not _shape.disabled and _shape.shape is CapsuleShape3D and _scene.global_basis.is_equal_approx(Basis.IDENTITY) and _shape.global_basis.is_equal_approx(_shape.global_basis.orthonormalized()) and _shape.global_basis.y.is_equal_approx(Vector3.UP)

func footprint_radius() -> float:
	return (_shape.shape as CapsuleShape3D).radius + EDGE_MARGIN if ready and _upright_capsule() else 0.0

## Public source evidence. Coordinates match main._build_surface, including crop.
func source_at(world: Vector3) -> Dictionary:
	if not ready or not is_instance_valid(_scene): return {"class":"unknown", "kind":"unconfigured"}
	var local: Vector3 = world - _scene.global_position
	var col: int = floori((local.x + _origin.x) / _cell_size) - _start.x
	var row: int = floori((local.z + _origin.z) / _cell_size) - _start.y
	return _cell(col, row)

func _cell(col: int, row: int) -> Dictionary:
	if row < 0 or row >= _grid.size() or not _grid[row] is Array or col < 0 or col >= _grid[row].size():
		return {"class":"unknown", "kind":"outside_grid", "col":col, "row":row}
	var key: String = str(int(_grid[row][col]))
	var entry: Variant = _palette.get(key)
	if not entry is Dictionary or not entry.has("heightM"):
		return {"class":"unknown", "kind":"invalid_palette", "col":col, "row":row}
	var kind: String = str(entry.get("kind", ""))
	var category := "water" if kind == "water" else ("land" if bool(entry.get("solid", false)) else "unknown")
	return {"class":category, "kind":kind, "tile":key, "col":col, "row":row,
		"surface_y":float(entry.heightM) + _scene.global_position.y}

## at is the proposed actor root X/Z; floor_hit is the caller's REAL down-ray hit.
## Call from physics processing. ok is terrain admission only, never route success.
func check(at: Vector3, floor_hit: Dictionary) -> Dictionary:
	queries = 0
	if not ready or not _upright_capsule(): return _reject("surface_or_capsule_unavailable")
	if not floor_hit.get("position") is Vector3 or not floor_hit.get("normal") is Vector3 or not _fixed_support(floor_hit.get("collider")):
		return _reject("real_fixed_floor_required")
	if (floor_hit.normal as Vector3).dot(Vector3.UP) < 0.7: return _reject("floor_slope")
	var floor_y: float = floor_hit.position.y
	var center: Vector3 = at + _body.global_basis * _shape.position
	center.y = floor_y
	# Circumscribed polygon: its edges enclose the actual disk, never cut corners.
	var radius: float = footprint_radius() / cos(PI / float(RIM_SAMPLES))
	var stamp: Dictionary = source_at(center)
	var wet := false
	var samples: Array[Vector3] = [center]
	var local: Vector3 = center - _scene.global_position
	var col0: int = floori((local.x - radius + _origin.x) / _cell_size) - _start.x
	var col1: int = floori((local.x + radius + _origin.x) / _cell_size) - _start.x
	var row0: int = floori((local.z - radius + _origin.z) / _cell_size) - _start.y
	var row1: int = floori((local.z + radius + _origin.z) / _cell_size) - _start.y
	# Exact disk/cell overlap catches tiny diagonal water corners between rim rays.
	for row in range(row0, row1 + 1):
		for col in range(col0, col1 + 1):
			var lower := Vector2((col + _start.x) * _cell_size - _origin.x + _scene.global_position.x, (row + _start.y) * _cell_size - _origin.z + _scene.global_position.z)
			var upper: Vector2 = lower + Vector2.ONE * _cell_size
			var nearest := Vector2(clampf(center.x, lower.x, upper.x), clampf(center.z, lower.y, upper.y))
			var distance: float = nearest.distance_to(Vector2(center.x, center.z))
			if distance > radius: continue
			var cell: Dictionary = _cell(col, row)
			if cell["class"] == "unknown": return _reject("footprint_outside_known_surface", stamp)
			if cell["class"] != "water" and cell.kind != "bridge": continue
			wet = true
			# Probe just inside the touched cell, not its ambiguous shared edge.
			nearest = nearest.move_toward((lower + upper) * 0.5, minf(EDGE_MARGIN, maxf(0.0, radius - distance) * 0.5))
			samples.append(Vector3(nearest.x, floor_y, nearest.y))
	if not wet:
		return {"ok":true, "reason":"dry_source_floor", "source":stamp, "support":"land", "queries":queries}
	if floor_y <= _water_y + DRY_CLEARANCE: return _reject("submerged_floor", stamp)
	# Shoreline/bridge-only cost: no extra physics rays on ordinary inland ground.
	for i in range(RIM_SAMPLES):
		var angle: float = TAU * float(i) / float(RIM_SAMPLES)
		samples.append(center + Vector3(cos(angle), 0.0, sin(angle)) * radius)
	var space: PhysicsDirectSpaceState3D = _body.get_world_3d().direct_space_state
	for sample: Vector3 in samples:
		var ray := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * (SUPPORT_DELTA + 0.02), sample - Vector3.UP * (SUPPORT_DELTA + 0.02), _body.collision_mask, [_body.get_rid()])
		queries += 1
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or not _fixed_support(hit.get("collider")):
			return _reject("footprint_has_no_dry_walkway", stamp)
		if (hit.normal as Vector3).dot(Vector3.UP) < 0.7 or absf(float(hit.position.y) - floor_y) > SUPPORT_DELTA:
			return _reject("footprint_support_slope_or_height", stamp)
		if float(hit.position.y) <= _water_y + DRY_CLEARANCE:
			return _reject("footprint_support_submerged", stamp)
	return {"ok":true, "reason":"live_dry_walkway", "source":stamp, "support":"bridge_over_water" if stamp["class"] == "water" else "dry_shore_or_bridge", "queries":queries, "footprint_radius":radius}

func _fixed_support(collider: Variant) -> bool:
	if not collider is PhysicsBody3D or not is_instance_valid(collider) or not collider.is_inside_tree() or collider.is_queued_for_deletion(): return false
	# Parked/detached rubble is not a substitute for an intact walkway.
	var node: Node = collider
	while node != null and node != _scene:
		if bool(node.get_meta("detached", false)) or bool(node.get_meta("parked", false)) or bool(node.get_meta("retired_geometry", false)): return false
		node = node.get_parent()
	if collider is StaticBody3D: return true
	# Intact Palazzo slabs are frozen RigidBody3D with building identity.
	return collider is RigidBody3D and collider.freeze and collider.has_meta("building_id")

func _reject(reason: String, stamp: Dictionary = {}) -> Dictionary:
	return {"ok":false, "reason":reason, "source":stamp, "queries":queries}
