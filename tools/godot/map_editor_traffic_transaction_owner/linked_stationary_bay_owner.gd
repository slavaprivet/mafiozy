extends RefCounted
## Fixed-delta source-plan route publication with unchanged parked bay/car.
## Tool-only mechanics prototype; source packet is hash-pinned, not a general planner.
const SOURCE_ID := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-004"
const PARKING_ID := "parking:" + SOURCE_ID + ":bay:0"
const PACKET_SHA := "259ede19883bf73da85f3436661f77ab1ca1cba5fc7bc1d3f49c392d4671689c"
const CATALOG_SHA := "ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e"
const DESCRIPTOR_SHA := "99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a"

class Token extends RefCounted:
	var owner: RefCounted
	var source_id := ""
	var main_id := 0
	var original_root: Transform3D
	var original_bodies: Array = []
	var car: Dictionary = {}
	var before_plan: Dictionary = {}
	var target_plan: Dictionary = {}
	var action := ""
	var previous_revision := 0
	var published := false
	var applied_revision := 0
	func verify() -> Dictionary: return owner._verify(self)
	func commit(next: Dictionary) -> Dictionary: return owner._commit(self,next)
	func rollback() -> Dictionary: return owner._rollback(self)

var _main: Node3D
var _packet: Dictionary = {}
var _current_plan: Dictionary = {}
var _active: Token
var _revision := 0
var _terminal_hold := false

func configure(main: Node3D) -> Dictionary:
	if _main != null or not is_instance_valid(main) or not main.is_inside_tree(): return {"ok":false,"error":"OWNER"}
	if FileAccess.get_sha256("res://data/map_editor/linked_stationary_bay_packet.json") != PACKET_SHA or FileAccess.get_sha256("res://data/map_editor/catalog.json") != CATALOG_SHA or FileAccess.get_sha256("res://data/transport/vehicle_descriptors.v1.json") != DESCRIPTOR_SHA: return {"ok":false,"error":"SOURCE_DRIFT"}
	var packet: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/linked_stationary_bay_packet.json"))
	if not packet is Dictionary: return {"ok":false,"error":"PACKET"}
	_packet = packet
	var declared_delta: Variant = _packet.get("delta_m")
	if _packet.get("schema","") != "mafiozi.map-editor-linked-parking-stationary-bay/v1" or _packet.get("source_id","") != SOURCE_ID or not declared_delta is Array or declared_delta.size() != 3 or absf(float(declared_delta[0])-.25) > .000001 or absf(float(declared_delta[1])) > .000001 or absf(float(declared_delta[2])) > .000001 or _packet.get("catalog_sha256","") != CATALOG_SHA or _packet.get("descriptor_sha256","") != DESCRIPTOR_SHA: return {"ok":false,"error":"PACKET_BINDING"}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/catalog.json"))
	var descriptors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transport/vehicle_descriptors.v1.json"))
	var bay: Dictionary = {}
	for row: Dictionary in descriptors.parking.bays:
		if str(row.parking_id) == PARKING_ID: bay = row; break
	if bay.is_empty() or not _native_bay_matches(bay): return {"ok":false,"error":"NATIVE_BAY_DRIFT"}
	var found := false
	for row: Dictionary in catalog.generatedPlans.parking.bays:
		if str(row.id) == PARKING_ID:
			found = true
			if absf(float(row.x)-float(bay.position_m.x)) > .00001 or absf(float(row.z)-float(bay.position_m.z)) > .00001 or absf(float(row.yaw)-float(_packet.parked_bay.source_yaw_rad)) > .00001: return {"ok":false,"error":"SOURCE_BAY_DRIFT"}
	if not found or not _packet.get("bay_ids",[]).has(PARKING_ID) or _packet.baseline.is_empty() or _packet.revised.is_empty(): return {"ok":false,"error":"PLAN_BINDING"}
	_main = main
	_current_plan = _packet.baseline.duplicate(true)
	return {"ok":true,"ready":true,"pending":false,"bay_unchanged":true,"route_rows":_current_plan.walkingRoutes.size()}

func lease(request: Dictionary) -> Dictionary:
	if _terminal_hold or not _valid_main() or not _main.get_tree().paused or Engine.is_in_physics_frame(): return {"ok":false,"error":"PAUSE_OR_OWNER"}
	if _active != null and not _active.published: return {"ok":false,"error":"ACTIVE_TOKEN"}
	var action := str(request.get("action",""))
	if str(request.get("source_id","")) != SOURCE_ID or action not in ["move","undo","redo"] or int(request.get("owner_instance_id",-1)) != _main.get_instance_id(): return {"ok":false,"error":"FIXED_MOVE_ONLY"}
	if (action == "undo" and _current_plan != _packet.revised) or (action != "undo" and _current_plan != _packet.baseline): return {"ok":false,"error":"PLAN_REVISION"}
	var row := _building_row()
	if row.visual == null or row.bodies.is_empty() or row.visual.global_transform != request.get("old_frame") or row.bodies.size() != int(request.get("body_count",-1)): return {"ok":false,"error":"BUILDING_BINDING"}
	var car := _car_state()
	if car.is_empty(): return {"ok":false,"error":"CAR_AUTHORITY"}
	var token := Token.new()
	token.owner=self; token.source_id=SOURCE_ID; token.main_id=_main.get_instance_id(); token.original_root=row.visual.global_transform; token.before_plan=_current_plan.duplicate(true); token.target_plan=(_packet.baseline if action == "undo" else _packet.revised).duplicate(true); token.action=action; token.previous_revision=_revision; token.car=car
	for body: StaticBody3D in row.bodies: token.original_bodies.append({"body":body,"id":body.get_instance_id(),"rid":body.get_rid(),"frame":body.global_transform,"layer":body.collision_layer,"mask":body.collision_mask})
	_active=token
	return {"ok":true,"token":token}

func _valid_main() -> bool:
	return is_instance_valid(_main) and not _main.is_queued_for_deletion() and _main.is_inside_tree() and str(_main.get("transport_status")) == "ready"

func _native_bay_matches(bay: Dictionary) -> bool:
	if bay.is_empty() or str(bay.get("parking_id","")) != PARKING_ID: return false
	var position: Dictionary = bay.get("position_m",{})
	var expected: Dictionary = _packet.parked_bay.position_m
	if position.is_empty(): return false
	for axis: String in ["x","y","z"]:
		if absf(float(position.get(axis,INF))-float(expected.get(axis,-INF))) > .00001: return false
	return absf(float(bay.get("yaw_rad",INF))-float(_packet.parked_bay.native_yaw_rad)) < .00001

func _building_row() -> Dictionary:
	var visual: Node3D
	var bodies: Array[StaticBody3D] = []
	for child: Node in _main.get_children():
		if str(child.get_meta("source_id","")) != SOURCE_ID: continue
		if child is StaticBody3D: bodies.append(child)
		elif child is Node3D: visual=child
	return {"visual":visual,"bodies":bodies}

func _car_state() -> Dictionary:
	if not _valid_main(): return {}
	var transport: Node3D = _main.get("preview_transport")
	if not is_instance_valid(transport) or not bool(transport.get("ready_for_play")) or str(transport.get("phase")) != "ON_FOOT" or bool(transport.get("_seat_collision_owned")): return {}
	var runtime: Node3D = transport.get("runtime")
	var body: RigidBody3D = transport.get("body")
	if not is_instance_valid(runtime) or not is_instance_valid(body) or not body.is_inside_tree(): return {}
	var ref: Dictionary = transport.get("_vehicle_ref")
	var record: Dictionary = runtime.host.vehicle_record(ref)
	var host: Dictionary = runtime.host.diagnostics()
	if record.is_empty() or str(record.get("parking_id","")) != PARKING_ID or int(host.get("leases",-1)) != 0 or int(host.get("vehicles",-1)) != 1: return {}
	for seat: Variant in record.get("seats",{}).values():
		if seat != null: return {}
	if body.linear_velocity.length() > .25 or body.angular_velocity.length() > .25 or not bool(transport.get("_parked_brake")): return {}
	var bay: Dictionary = runtime.catalog.parking_bay(PARKING_ID)
	if not _native_bay_matches(bay): return {}
	return {"transport_id":transport.get_instance_id(),"body_id":body.get_instance_id(),"rid":body.get_rid(),"frame":body.global_transform,"linear":body.linear_velocity,"angular":body.angular_velocity,"record":record,"host":host,"bay":bay,"ref":ref.duplicate(true),"phase":transport.get("phase")}

func _verify(token: Token) -> Dictionary:
	if _terminal_hold or token != _active or not _valid_main() or not _main.get_tree().paused or _main.get_instance_id() != token.main_id or _car_state() != token.car: return {"ok":false,"ready":false,"pending":false}
	var row := _building_row()
	if row.visual == null or row.bodies.size() != token.original_bodies.size(): return {"ok":false,"ready":false,"pending":false}
	for i in token.original_bodies.size():
		var before: Dictionary = token.original_bodies[i]
		var body: StaticBody3D = row.bodies[i]
		if body != before.body or body.get_instance_id() != before.id or body.get_rid() != before.rid or body.collision_layer != before.layer or body.collision_mask != before.mask: return {"ok":false,"ready":false,"pending":false}
	if token.published and (_revision != token.applied_revision or _current_plan != token.target_plan): return {"ok":false,"ready":false,"pending":false}
	return {"ok":true,"ready":true,"pending":false}

func _commit(token: Token, next: Dictionary) -> Dictionary:
	if token.published or not _verify(token).ok or str(next.get("source_id","")) != SOURCE_ID or str(next.get("action","")) != token.action or bool(next.get("deleted",true)): return {"ok":false,"ready":false,"pending":false}
	var row := _building_row()
	var delta := Vector3(-.25,0,0) if token.action == "undo" else Vector3(.25,0,0)
	var wanted: Transform3D = token.original_root.translated(delta)
	if row.visual.global_transform != wanted or next.get("new_frame") != wanted: return {"ok":false,"ready":false,"pending":false}
	for i in token.original_bodies.size():
		if row.bodies[i].global_transform != token.original_bodies[i].frame.translated(delta): return {"ok":false,"ready":false,"pending":false}
	_current_plan = token.target_plan.duplicate(true)
	_revision += 1
	token.published = true; token.applied_revision = _revision
	return {"ok":true,"ready":true,"pending":false,"revision":_revision,"parked_car_moved":false}

func _rollback(token: Token) -> Dictionary:
	if token != _active or not _valid_main() or not _main.get_tree().paused or _car_state() != token.car: return {"ok":false,"ready":false,"pending":false}
	if token.published:
		if _revision != token.applied_revision or _current_plan != token.target_plan:
			_terminal_hold = true
			return {"ok":false,"ready":false,"pending":false}
		_current_plan = token.before_plan.duplicate(true)
		_revision = token.previous_revision
	_active = null
	return {"ok":true,"ready":true,"pending":false}

func route_plan() -> Dictionary:
	return _current_plan.duplicate(true)

func dispose() -> bool:
	if not _valid_main() or not _main.get_tree().paused or (_active != null and not _active.published): return false
	_active = null
	_main = null
	_packet.clear(); _current_plan.clear()
	return true
