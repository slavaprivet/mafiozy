extends RefCounted
## Accepted ordinary outdoor session only. No agenda, indoor visitation rights,
## owner creation or navigation. Source map lease + current physical floor proof.
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const PACKET_SHA := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const SESSION := "godot-preview-new-session-20260927-01"
const RADIUS := .738
const ORIGIN := Vector3(395.65, 0, 45.1)
const OFFSETS := [Vector2.ZERO, Vector2(-RADIUS, -RADIUS), Vector2(-RADIUS, RADIUS), Vector2(RADIUS, -RADIUS), Vector2(RADIUS, RADIUS)]
var _scene: WeakRef
var _owners := {}
var _states := {}
var _version := -1
var _land := PackedByteArray()
var _heights := PackedFloat64Array()
var _cells: Array = []
var _floors := {}
var _ray := PhysicsRayQueryParameters3D.new()
var _disposed := false
var _busy := false

func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene != null: return {"ok": false, "error": "lifetime"}
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not scene.global_transform.is_equal_approx(Transform3D.IDENTITY): return {"ok": false, "error": "scene"}
	if not trust.get("accepted") is bool or not trust.accepted or trust.get("packet_sha256") != PACKET_SHA or trust.get("block_sha256") != BLOCK_SHA or trust.get("session_id") != SESSION: return {"ok": false, "error": "accepted_source_required"}
	var bytes := FileAccess.get_file_as_bytes("res://assets/npc_visual/session/" + PACKET_SHA + ".json")
	if Loader._hash(bytes) != PACKET_SHA: return {"ok": false, "error": "packet_bytes"}
	var packet: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	if packet_rows != packet.rows or owners.size() != packet.rows.size(): return {"ok": false, "error": "exact_rows_required"}
	var source_bytes := FileAccess.get_file_as_bytes(str(scene.get("block_data_path")))
	if Loader._hash(source_bytes) != BLOCK_SHA: return {"ok": false, "error": "source_block_bytes"}
	var block: Dictionary = JSON.parse_string(source_bytes.get_string_from_utf8())
	if scene.get("_block") != block or scene.get("_origin") != ORIGIN: return {"ok": false, "error": "current_block"}
	var checked := {}
	for row: Dictionary in packet_rows:
		var owner: Variant = owners.get(row.source_id)
		if not owner is Queue.Owner or owner.dead or owner.source_id != row.source_id or owner.life_generation != 1: return {"ok": false, "error": "owner_identity"}
		checked[row.source_id] = {"owner": owner, "dead_seen": false}
	var states: Variant = access.get("states")
	var version: Variant = access.get("version")
	if not version is int or version < 1 or not _valid_states(states, checked): return {"ok": false, "error": "access_snapshot"}
	# The exact accepted crop bounds exclude source arena (c61..71), prison
	# (r>=55.65), lair (r>=100) and pit (r>=156). This does not generalize them.
	var surface: Dictionary = block.surface
	if surface.startRow != 0 or surface.startCol != 76 or surface.rows != 31 or surface.cols != 31 or surface.cellSize != 4.1: return {"ok": false, "error": "unsupported_crop"}
	_land.resize(31 * 31); _heights.resize(31 * 31); _cells.resize(31 * 31)
	for i in _cells.size(): _cells[i] = []
	for r in 31:
		for c in 31:
			var index := r * 31 + c; var tile := int(surface.grid[r][c])
			var palette: Dictionary = surface.palette[str(tile)]
			var police: Variant = surface.masks.policeMask[r][c]
			# Exact nativePedestrianLand numeric police exception; ordinary native
			# npcPassable/npcWaypointOk additionally exclude road and all water.
			var native_land: bool = bool(surface.masks.walkableMask[r][c]) or (tile == 9 and (police is int or police is float) and police == 1)
			_land[index] = int(r >= 1 and native_land and not bool(surface.masks.roadMask[r][c]) and tile != 16 and bool(palette.solid))
			_heights[index] = float(palette.heightM)
	# Retain the accepted exterior-only building envelopes, including their
	# authored public-approach gaps. Opening an interior door does not grant new
	# visitation permission. A later interior source provider needs a new scope.
	for building: Dictionary in block.buildings:
		for body: Dictionary in building.collisionBodiesM:
			var polygon := PackedVector2Array()
			var bounds := Rect2()
			for value: Array in body.polygonXZ:
				var point := Vector2(value[0], value[1]); polygon.append(point)
				bounds = Rect2(point, Vector2.ZERO) if polygon.size() == 1 else bounds.expand(point)
			var record := {"polygon": polygon, "bounds": bounds.grow(.00001)}
			var first_c := maxi(0, int(floor((bounds.position.x + ORIGIN.x) / 4.1)) - 76)
			var last_c := mini(30, int(floor((bounds.end.x + ORIGIN.x) / 4.1)) - 76)
			var first_r := maxi(0, int(floor((bounds.position.y + ORIGIN.z) / 4.1)))
			var last_r := mini(30, int(floor((bounds.end.y + ORIGIN.z) / 4.1)))
			for r in range(first_r, last_r + 1):
				for c in range(first_c, last_c + 1): _cells[r * 31 + c].append(record)
	_scene = weakref(scene)
	if not _capture_floors(scene, surface): _scene = null; _land.clear(); _cells.clear(); _heights.clear(); _floors.clear(); return {"ok": false, "error": "source_floor_identity"}
	_owners = checked; _states = states.duplicate(); _version = version
	_ray.collision_mask = 1
	scene.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	return {"ok": true, "version": _version, "owners": _owners.size(), "source_floors": _floors.size()}

func _floor_key(size: Vector3, position: Vector3) -> String:
	return PackedVector3Array([size, position]).to_byte_array().hex_encode()

func _capture_floors(scene: Node3D, surface: Dictionary) -> bool:
	var expected := {}
	for r in 31:
		var c := 0
		while c < 31:
			var tile := str(int(surface.grid[r][c])); var palette: Dictionary = surface.palette[tile]
			if not palette.solid: c += 1; continue
			var first := c
			while c < 31 and str(int(surface.grid[r][c])) == tile: c += 1
			var size := Vector3((c - first) * 4.1, .16, 4.1)
			var position := Vector3((76 + (first + c) * .5) * 4.1 - ORIGIN.x, float(palette.heightM) - .08, (r + .5) * 4.1 - ORIGIN.z)
			expected[_floor_key(size, position)] = true
	var seen := {}
	for node: Node in scene.get_children():
		if not node is StaticBody3D or node.get_child_count() != 1: continue
		var shape: Node = node.get_child(0)
		if not shape is CollisionShape3D or not shape.shape is BoxShape3D: continue
		var key := _floor_key(shape.shape.size, node.global_position)
		if not expected.has(key): continue
		if seen.has(key) or shape.disabled or node.collision_layer != 1 or not node.global_basis.is_equal_approx(Basis.IDENTITY) or not shape.transform.is_equal_approx(Transform3D.IDENTITY): return false
		seen[key] = true
		_floors[node.get_rid()] = {"body": weakref(node), "shape": weakref(shape), "frame": node.global_transform, "size": shape.shape.size}
	return seen.size() == expected.size()

func _valid_states(states: Variant, owners: Dictionary) -> bool:
	if not states is Dictionary or states.size() > owners.size(): return false
	for id: Variant in states:
		if not id is String or not owners.has(id) or not states[id] is String or states[id] not in ["ordinary_outdoor", "deny", "unknown"]: return false
	return true

func _owner_allowed(id: String, generation: int) -> bool:
	if _disposed or _scene == null or not is_instance_valid(_scene.get_ref()) or generation != 1 or not _owners.has(id) or _states.get(id, "unknown") != "ordinary_outdoor": return false
	if not _scene.get_ref().global_transform.is_equal_approx(Transform3D.IDENTITY): return false
	var record: Dictionary = _owners[id]; var owner: RefCounted = record.owner
	if owner.dead or owner.source_id != id or owner.life_generation != generation: record.dead_seen = true
	return not record.dead_seen

func _index(point: Vector3) -> int:
	if not point.is_finite(): return -1
	# Keep coordinate arithmetic float64; Vector3 origin storage is float32.
	var c := (float(point.x) + 395.65) / 4.1 - 76
	var r := (float(point.z) + 45.099999999999994) / 4.1
	if point.x >= Vector3(43.05, 0, 0).x or point.z >= 82.0: return -1
	if r < 1 or r >= 31 or c < 0 or c >= 31: return -1
	return int(floor(r)) * 31 + int(floor(c))

func _point_allowed(point: Vector3) -> bool:
	var index := _index(point)
	if index < 0 or _land[index] == 0 or absf(point.y - _heights[index]) > .30: return false
	var xz := Vector2(point.x, point.z)
	for record: Dictionary in _cells[index]:
		if record.bounds.has_point(xz) and Geometry2D.is_point_in_polygon(xz, record.polygon): return false
	return true

func source_admit(point: Vector3, id: String, generation: int, radius: float, purpose: String) -> bool:
	if not Thread.is_main_thread() or _busy or not _owner_allowed(id, generation) or not is_finite(radius) or absf(radius - RADIUS) > .000001 or purpose not in ["placement", "target", "route"]: return false
	for offset: Vector2 in OFFSETS:
		if not _point_allowed(point + Vector3(offset.x, 0, offset.y)): return false
	return true

func support_height(point: Vector3, id: String, generation: int) -> float:
	if not Thread.is_main_thread() or _busy or not _owner_allowed(id, generation) or not point.is_finite(): return NAN
	var index := _index(point)
	if index < 0: return NAN
	var reference := Vector3(point.x, _heights[index], point.z)
	if not source_admit(reference, id, generation, RADIUS, "placement"): return NAN
	_busy = true
	_ray.from = reference + Vector3.UP * .30; _ray.to = reference - Vector3.UP * .30
	var scene: Node3D = _scene.get_ref()
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(_ray)
	var result := NAN
	if not hit.is_empty() and _floors.has(hit.rid) and hit.normal.y >= .70 and absf(hit.position.y - reference.y) < .0001:
		var floor_record: Dictionary = _floors[hit.rid]
		var body: StaticBody3D = floor_record.body.get_ref()
		var shape: CollisionShape3D = floor_record.shape.get_ref()
		if is_instance_valid(body) and is_instance_valid(shape) and body.get_parent() == scene and body.global_transform.is_equal_approx(floor_record.frame) and body.collision_layer == 1 and not shape.disabled and shape.transform.is_equal_approx(Transform3D.IDENTITY) and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(floor_record.size): result = hit.position.y
	_busy = false
	return result

func callbacks() -> Dictionary:
	return {"source_admit": Callable(self, "source_admit"), "support_height": Callable(self, "support_height")}

func update_access(version: int, states: Dictionary) -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null or version <= _version or not _valid_states(states, _owners): return false
	_states = states.duplicate(); _version = version
	return true

func access_version() -> int: return _version

func dispose() -> void:
	if not Thread.is_main_thread() or _busy or _disposed: return
	_disposed = true
	var scene: Node3D = _scene.get_ref() if _scene != null else null
	if is_instance_valid(scene) and scene.tree_exiting.is_connected(dispose): scene.tree_exiting.disconnect(dispose)
	_owners.clear(); _states.clear(); _floors.clear(); _cells.clear(); _land.clear(); _heights.clear(); _ray = null
