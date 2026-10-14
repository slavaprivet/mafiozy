extends RefCounted
## Conservative no-impact publication token for the actual checkpoint preview.
## An associated parking lot is NOT movable through this adapter.
const MAIN_SHA := "faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const CATALOG_SHA := "ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e"
const DESCRIPTOR_SHA := "99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a"

class TrafficToken extends RefCounted:
	var owner: RefCounted
	var source_id := ""
	var main_id := 0
	var original_root: Transform3D
	var transport_state: Dictionary = {}
	var bodies: Array = []
	var published := false
	var previous_revision := 0
	var previous_row: Dictionary = {}
	var applied_row: Dictionary = {}
	func verify() -> Dictionary: return owner._verify(self)
	func commit(next: Dictionary) -> Dictionary: return owner._commit(self, next)
	func rollback() -> Dictionary: return owner._rollback(self)
	func finalize() -> Dictionary: return owner._finalize(self)

var _main: Node3D
var _block: Dictionary = {}
var _catalog: Dictionary = {}
var _descriptors: Dictionary = {}
var _constraints: Dictionary = {}
var _active: TrafficToken
var _revision := 0
var _published: Dictionary = {}
var _terminal_hold := false
var last_clear_error := ""

func configure(main: Node3D) -> Dictionary:
	if _main != null or not is_instance_valid(main) or not main.is_inside_tree(): return {"ok":false,"error":"OWNER"}
	if FileAccess.get_sha256("res://scripts/main.gd") != MAIN_SHA or FileAccess.get_sha256("res://data/block.json") != BLOCK_SHA or FileAccess.get_sha256("res://data/map_editor/catalog.json") != CATALOG_SHA or FileAccess.get_sha256("res://data/transport/vehicle_descriptors.v1.json") != DESCRIPTOR_SHA: return {"ok":false,"error":"SOURCE_DRIFT"}
	if main.get_script() != load("res://scripts/main.gd") or str(main.get("transport_status")) != "ready": return {"ok":false,"error":"ACTUAL_OWNER"}
	_block = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/catalog.json"))
	_descriptors = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	_constraints = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/traffic_constraints.json"))
	if _block.is_empty() or _catalog.is_empty() or _descriptors.is_empty() or _constraints.is_empty() or str(_constraints.get("catalog_sha256", "")) != CATALOG_SHA or str(_constraints.get("descriptor_sha256", "")) != DESCRIPTOR_SHA: return {"ok":false,"error":"CONSTRAINTS"}
	if main.get("_block") != _block: return {"ok":false,"error":"BLOCK_DRIFT"}
	_main = main
	return {"ok":true,"ready":true,"pending":false,"parking_bays":_descriptors.parking.bays.size(),"blocked_rects":_constraints.rects.size()}

func lease(request: Dictionary) -> Dictionary:
	if _terminal_hold or not _valid_main() or not _main.get_tree().paused or Engine.is_in_physics_frame(): return {"ok":false,"error":"PAUSE_OR_OWNER"}
	if _active != null and not _active.published: return {"ok":false,"error":"ACTIVE_TOKEN"}
	var id := str(request.get("source_id", ""))
	var record: Dictionary = {}
	for row: Dictionary in _block.buildings:
		if str(row.id) == id: record = row; break
	if record.is_empty(): return {"ok":false,"error":"NOT_LIVE_BUILDING"}
	# The source parking plan owns lots, routes, signs, support and bay IDs.
	# A linked building requires a genuine replan + roster/geometry publisher.
	for lot: Dictionary in _catalog.generatedPlans.parking.lots:
		if str(lot.get("buildingId", "")) == id: return {"ok":false,"error":"PARKING_REPLAN_REQUIRED"}
	for bay: Dictionary in _descriptors.parking.bays:
		if str(bay.get("building_id", "")) == id: return {"ok":false,"error":"PARKING_REPLAN_REQUIRED"}
	var root: Node3D = null
	var bodies: Array = []
	for child: Node in _main.get_children():
		if str(child.get_meta("source_id", "")) != id: continue
		if child is StaticBody3D: bodies.append(child)
		elif child is Node3D and root == null: root = child
	if root == null or bodies.is_empty() or root.global_transform != request.get("old_frame") or int(request.get("body_count", -1)) != bodies.size() or int(request.get("owner_instance_id", -1)) != _main.get_instance_id(): return {"ok":false,"error":"BUILDING_BINDING"}
	var transport := _transport_state()
	if transport.is_empty(): return {"ok":false,"error":"TRANSPORT_BINDING"}
	var token := TrafficToken.new()
	token.owner = self; token.source_id = id; token.main_id = _main.get_instance_id(); token.original_root = root.global_transform; token.transport_state = transport; token.bodies = _body_identity(bodies)
	if token.bodies.size() != bodies.size(): return {"ok":false,"error":"BODY_BINDING"}
	token.previous_revision = _revision; token.previous_row = (_published.get(id, {}) as Dictionary).duplicate(true)
	_active = token
	return {"ok":true,"token":token}

func _valid_main() -> bool:
	return is_instance_valid(_main) and not _main.is_queued_for_deletion() and _main.is_inside_tree() and str(_main.get("transport_status")) == "ready"

func _transport_state() -> Dictionary:
	if not _valid_main(): return {}
	var transport: Node3D = _main.get("preview_transport")
	if not is_instance_valid(transport) or not transport.is_inside_tree() or not bool(transport.get("ready_for_play")): return {}
	var runtime: Node3D = transport.get("runtime")
	var body: RigidBody3D = transport.get("body")
	if not is_instance_valid(runtime) or not is_instance_valid(body) or not body.is_inside_tree() or runtime.get("host") == null or runtime.get("catalog") == null: return {}
	return {"transport_id":transport.get_instance_id(),"body_id":body.get_instance_id(),"body_rid":body.get_rid(),"frame":body.global_transform,"linear":body.linear_velocity,"angular":body.angular_velocity,"phase":transport.get("phase"),"vehicle_ref":transport.get("_vehicle_ref").duplicate(true),"host":runtime.host.diagnostics(),"parking":runtime.catalog.parking.duplicate(true)}

func _body_identity(bodies: Array) -> Array:
	var rows: Array = []
	for body: StaticBody3D in bodies:
		if not body.is_inside_tree() or body.is_queued_for_deletion() or body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D: return []
		var collision: CollisionShape3D = body.get_child(0)
		if not collision.shape is ConvexPolygonShape3D: return []
		rows.append({"body":body,"id":body.get_instance_id(),"rid":body.get_rid(),"shape_id":collision.shape.get_instance_id(),"points":collision.shape.points,"source_index":body.get_meta("source_index", -1)})
	return rows

func _verify(token: TrafficToken) -> Dictionary:
	if _terminal_hold or token != _active or not _valid_main() or not _main.get_tree().paused or _main.get_instance_id() != token.main_id or _transport_state() != token.transport_state: return {"ok":false,"ready":false,"pending":false}
	for row: Dictionary in token.bodies:
		var body: StaticBody3D = row.body
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != _main or body.get_instance_id() != row.id or body.get_rid() != row.rid or str(body.get_meta("source_id", "")) != token.source_id or body.get_meta("source_index", -1) != row.source_index: return {"ok":false,"ready":false,"pending":false}
		var shape: CollisionShape3D = body.get_child(0)
		if not is_instance_valid(shape) or shape.shape.get_instance_id() != row.shape_id or shape.shape.points != row.points: return {"ok":false,"ready":false,"pending":false}
	if token.published and _published.get(token.source_id, {}) != token.applied_row: return {"ok":false,"ready":false,"pending":false}
	return {"ok":true,"ready":true,"pending":false}

func _commit(token: TrafficToken, next: Dictionary) -> Dictionary:
	if token.published or not _verify(token).ok or str(next.get("source_id", "")) != token.source_id or not next.get("new_frame") is Transform3D: return {"ok":false,"ready":false,"pending":false}
	var root: Node3D = null
	for child: Node in _main.get_children():
		if str(child.get_meta("source_id", "")) == token.source_id and child is Node3D and not child is StaticBody3D: root = child; break
	if root == null or root.global_transform != next.new_frame: return {"ok":false,"ready":false,"pending":false}
	var deleted := bool(next.get("deleted", false))
	if deleted:
		if root.visible: return {"ok":false,"ready":false,"pending":false}
	else:
		if not root.visible or not _clear_of_traffic(token): return {"ok":false,"ready":false,"pending":false}
	_revision += 1
	token.applied_row = {"revision":_revision,"frame":root.global_transform,"deleted":deleted,"source_id":token.source_id}
	_published[token.source_id] = token.applied_row.duplicate(true)
	token.published = true
	return {"ok":true,"ready":true,"pending":false,"revision":_revision}

func _clear_of_traffic(token: TrafficToken) -> bool:
	last_clear_error = ""
	var origin: Array = _block.originM
	var surface: Dictionary = _block.surface
	var cell := float(surface.cellSize)
	for row: Dictionary in token.bodies:
		var body: StaticBody3D = row.body
		var min_x := INF; var max_x := -INF; var min_z := INF; var max_z := -INF
		for point: Vector3 in row.points:
			var world: Vector3 = body.global_transform * point
			min_x = minf(min_x, world.x + float(origin[0])); max_x = maxf(max_x, world.x + float(origin[0]))
			min_z = minf(min_z, world.z + float(origin[2])); max_z = maxf(max_z, world.z + float(origin[2]))
		if not [min_x,max_x,min_z,max_z].all(func(value): return is_finite(value)):
			last_clear_error = "non-finite-bounds"; return false
		# Only the 31x31 live crop is known to native traffic. Outside it is HOLD.
		var c0 := int(floor(min_x / cell)) - int(surface.startCol)
		var c1 := int(floor(max_x / cell)) - int(surface.startCol)
		var r0 := int(floor(min_z / cell)) - int(surface.startRow)
		var r1 := int(floor(max_z / cell)) - int(surface.startRow)
		if c0 < 0 or r0 < 0 or c1 >= int(surface.cols) or r1 >= int(surface.rows):
			last_clear_error = "outside-known-crop"; return false
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				if int(surface.grid[r][c]) in [0,19]:
					last_clear_error = "blocked-surface:%d:%d:%d" % [r,c,int(surface.grid[r][c])]; return false
		for constraint: Dictionary in _constraints.rects:
			if min_x < float(constraint.maxX) and max_x > float(constraint.minX) and min_z < float(constraint.maxZ) and max_z > float(constraint.minZ):
				last_clear_error = "constraint:" + str(constraint.get("kind", "")); return false
	return true

func _rollback(token: TrafficToken) -> Dictionary:
	if token != _active or not _valid_main() or not _main.get_tree().paused: return {"ok":false,"ready":false,"pending":false}
	if token.published:
		if _revision != int(token.applied_row.revision) or _published.get(token.source_id, {}) != token.applied_row:
			_terminal_hold = true
			return {"ok":false,"ready":false,"pending":false}
		_revision = token.previous_revision
		if token.previous_row.is_empty(): _published.erase(token.source_id)
		else: _published[token.source_id] = token.previous_row.duplicate(true)
	_active = null
	return {"ok":true,"ready":true,"pending":false}

func _finalize(token: TrafficToken) -> Dictionary:
	# The committed revision is retained, but the owner/token cycle is not.
	if token != _active or not token.published or not _valid_main() or _revision != int(token.applied_row.get("revision", -1)) or _published.get(token.source_id, {}) != token.applied_row:
		_terminal_hold = true
		return {"ok":false,"ready":false,"pending":false}
	_active = null
	token.owner = null
	return {"ok":true,"ready":true,"pending":false,"revision":_revision}
