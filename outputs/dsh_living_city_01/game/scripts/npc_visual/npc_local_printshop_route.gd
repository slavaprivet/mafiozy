extends RefCounted
## Isolated one-entry movement adapter. Owns only a leased original walking body.
## The parent host still owns the sole physics/gait tick. No source progress/HP.
const Sweep = preload("res://scripts/npc_visual/npc_local_printshop_contact_sweep.gd")
const SourceFloor = preload("res://scripts/npc_visual/npc_local_printshop_source_floor.gd")
const ENTRY_SHA := "3bda89bb0017b2d1ee5f5fca9c066d28a8e0f11a09670be43c771a027ce3518c"
const GEOMETRY_SHA := "e1bcf7b5ba88008b17362aaedb1d0c094dd7cefd756ec0e7afec0923a2aad618"
const BUILDING := "REBUILD-VISUAL-print_shop-001"
const HALF := .738
const OFFSETS := [Vector2.ZERO,Vector2(-HALF,-HALF),Vector2(-HALF,HALF),Vector2(HALF,-HALF),Vector2(HALF,HALF)]
var host: RefCounted
var policy: RefCounted
var base_nav: RefCounted
var scene: Node3D
var interior: Node3D
var token := {}
var body: CharacterBody3D
var outside := Vector3.ZERO
var inside := Vector3.ZERO
var lane_outside := Vector3.ZERO
var lane_inside := Vector3.ZERO
var lane_offset := 0.0
var _return := Vector3.ZERO
var _street_return := Vector3.ZERO
var _open_solids: Array = []
var _closed_solids: Array = []
var _static_solids: Array = []
var _sweep := Sweep.new()
var _source_floor := SourceFloor.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _square_query := PhysicsShapeQueryParameters3D.new()
var _floors := {}
var _active := -1
static var _next_id := 1000000
var _requests := {}
var _version := -1
var _phase := "UNBOUND"
var _busy := false
var _disposed := false
var _geometry_pins: Array = []
var _geometry_invalid := false
var _resources: Array[Resource] = []
var _entry_rids: Array[RID] = []
var _door_pins := {}
var _shape_parents: Array[Node] = []
var diagnostics := {"steps":0,"floor_queries":0,"blocked":0,"source_sweeps":0,"max_step_m":0.0,"floor_frames":0,"travel_m":0.0,"last_reason":"","last_polygon":{},"times_us":[]}

func _v(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func configure(owner: RefCounted, outdoor: RefCounted, navigation: RefCounted, root: Node3D, actor_token: Dictionary, entry_bytes: PackedByteArray, geometry_bytes: PackedByteArray) -> bool:
	if host!=null or owner._navigation!=navigation or not owner.target_current(actor_token): return false
	var previous_owner: Variant=owner._records[actor_token.source_id].get("local_route_owner")
	if previous_owner is WeakRef and previous_owner.get_ref()!=null:return false
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(entry_bytes)
	if hash.finish().hex_encode()!=ENTRY_SHA: return false
	hash.start(HashingContext.HASH_SHA256);hash.update(geometry_bytes)
	if hash.finish().hex_encode()!=GEOMETRY_SHA:return false
	var geometry: Dictionary=JSON.parse_string(geometry_bytes.get_string_from_utf8())
	var entry: Dictionary=JSON.parse_string(entry_bytes.get_string_from_utf8())
	if entry.source_id!=BUILDING or geometry.get("source_entry_sha256")!=ENTRY_SHA or absf(geometry.get("half_extent_m",0)-HALF)>.0000001 or geometry.get("registered_original_session")!=false: return false
	if not geometry.has("selected_lane") or not geometry.has("states"): return false
	host=owner;policy=outdoor;base_nav=navigation;scene=root;interior=root.get("_printshop");token=actor_token.duplicate();body=token.body
	if not is_instance_valid(interior) or not interior.ready_for_use: return false
	outside=_v(entry.public_approach_preview);inside=_v(entry.public_inside_preview)
	var lane: Dictionary=geometry.selected_lane
	if not lane.admitted:return false
	lane_outside=_v(lane.outside);lane_inside=_v(lane.inside);lane_offset=float(lane.offset_cells)
	if lane_inside==Vector3.ZERO:return false
	_open_solids=geometry.openedEntryBodies.duplicate(true);_closed_solids=geometry.closedEntryBodies.duplicate(true)
	if _open_solids.is_empty() or _closed_solids.is_empty():return false
	_static_solids=geometry.get("stationBodies",[]).duplicate(true)
	for building: Dictionary in scene.get("_block").buildings+scene.get("_block").decor:
		if building.id==BUILDING:continue
		for shape: Dictionary in building.collisionBodiesM:
			var cr: Array=[]
			for p: Array in shape.polygonXZ:cr.append([(float(p[0])+395.65)/4.1,(float(p[1])+45.1)/4.1])
			_static_solids.append({"polygonCR":cr,"minYM":shape.minY,"maxYM":shape.maxY,"node":building.id})
	_open_solids=_nearby(_open_solids);_closed_solids=_nearby(_closed_solids);_static_solids=_nearby(_static_solids)
	_query.shape=body.get_child(0).shape;_query.collision_mask=1|256;_query.margin=.001;_query.exclude=[body.get_rid()]
	var square:=BoxShape3D.new();square.size=Vector3(HALF*2,1.9,HALF*2)
	_square_query.shape=square;_square_query.collision_mask=1|256;_square_query.margin=.001
	_ray.collision_mask=1;_ray.exclude=[body.get_rid()]
	_version=policy.access_version()
	if not _source_floor.configure(geometry.floorParameters,geometry.originM,_validated_terrain_world):return false
	# Frozen source walls may authorize only this unchanged native geometry.
	for node: Node in interior.find_children("*","CollisionShape3D",true,false):
		_geometry_pins.append({"node":weakref(node),"parent":node.get_parent(),"shape":node.shape,"disabled":node.disabled,"frame":node.global_transform,"local":node.transform,"layer":node.get_parent().collision_layer,"door":node.get_parent().get_meta("interior_kind","").begins_with("door:")})
		if not node.shape in _resources:_resources.append(node.shape);node.shape.changed.connect(_changed)
		if not node.get_parent().get_rid() in _entry_rids:_entry_rids.append(node.get_parent().get_rid())
		if not node.get_parent() in _shape_parents:
			_shape_parents.append(node.get_parent());node.get_parent().child_entered_tree.connect(_child_changed);node.get_parent().child_exiting_tree.connect(_child_changed)
	for key: String in ["public","service"]:
		var door: Dictionary=interior._doors[key]
		_door_pins[key]={"node":door.node,"base":door.base,"angle":door.spec.angle,"spec":door.spec.duplicate(true)}
	_resources.append(_query.shape);_query.shape.changed.connect(_changed)
	_phase="READY"
	if not _current():return false
	host._records[token.source_id]["local_route_owner"]=weakref(self)
	return true

func _changed() -> void:_geometry_invalid=true
func _child_changed(_node: Node) -> void:_geometry_invalid=true

func _nearby(solids: Array) -> Array:
	var kept: Array=[]
	for solid: Dictionary in solids:
		var min_x:=INF;var max_x:=-INF;var min_z:=INF;var max_z:=-INF
		for p: Array in solid.polygonCR:
			min_x=minf(min_x,float(p[0])*4.1-395.65);max_x=maxf(max_x,float(p[0])*4.1-395.65)
			min_z=minf(min_z,float(p[1])*4.1-45.1);max_z=maxf(max_z,float(p[1])*4.1-45.1)
		if max_x>=3.3 and min_x<=9.6 and max_z>=4.4 and min_z<=6.8:kept.append(solid)
	return kept

func _current(full_geometry: bool=true) -> bool:
	if _disposed or _phase=="SUPERSEDED" or _geometry_invalid or host==null or host._disposed or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or not is_instance_valid(interior) or not interior.ready_for_use:return false
	if policy.access_version()!=_version or not policy._owner_allowed(token.source_id,token.life_generation) or not host._records.has(token.source_id):return false
	var record: Dictionary=host._records[token.source_id]
	var local_owner: Variant=record.get("local_route_owner")
	if local_owner is WeakRef and local_owner.get_ref()!=self:return false
	if _active>=0 and record.request!=_active:return false
	if record.body!=body or not host._living(record) or record.generation!=token.life_generation or host._physical_occupied(token.source_id) or record.get("physical_failed",false):return false
	if body.get_parent()!=scene or not scene.global_transform.is_equal_approx(Transform3D.IDENTITY) or not interior.global_transform.is_equal_approx(Transform3D.IDENTITY) or body.get_instance_id()!=token.body_instance_id or body.get_rid()!=token.body_rid or body.collision_layer!=1 or body.collision_mask!=1:return false
	if body.get_meta("source_id","")!=token.source_id or body.get_meta("session_id","")!=token.session_id or body.get_meta("descriptor_sha256","")!=token.descriptor_sha256:return false
	if not is_instance_valid(token.rig) or token.rig.get_instance_id()!=token.rig_instance_id or not body.is_ancestor_of(token.rig):return false
	var shape: CollisionShape3D=body.get_child(0)
	if shape.disabled or shape.shape!=_query.shape or not is_equal_approx(shape.shape.radius,.36) or not is_equal_approx(shape.shape.height,1.9) or not shape.position.is_equal_approx(Vector3(0,.95,0)) or not shape.basis.is_equal_approx(Basis.IDENTITY):return false
	if not body.global_basis.is_equal_approx(body.global_basis.orthonormalized()) or not body.global_basis.y.is_equal_approx(Vector3.UP):return false
	if full_geometry:
		for pin: Dictionary in _geometry_pins:
			var node: CollisionShape3D=pin.node.get_ref()
			if not is_instance_valid(node) or node.get_parent()!=pin.parent or node.get_parent().collision_layer!=pin.layer or node.disabled!=pin.disabled or node.shape!=pin.shape or node.transform!=pin.local or (not pin.door and not node.global_transform.is_equal_approx(pin.frame)):return false
	if interior.door_fraction("service")!=0.0:return false
	for key: String in ["public","service"]:
		var door: Dictionary=interior._doors[key]
		var pin: Dictionary=_door_pins[key]
		if door.node!=pin.node or door.base!=pin.base or door.spec.angle!=pin.angle or (full_geometry and door.spec!=pin.spec) or door.node.get_parent()!=interior:return false
		var angle: float=float(door.spec.angle)*float(door.fraction)*float(door.fraction)*(3.0-2.0*float(door.fraction))
		var expected: Transform3D=door.base*Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)
		if not door.node.transform.is_equal_approx(expected):return false
	return true

func _floor_world(x: float,z: float) -> float:
	if _source_floor.in_domain_preview(x-395.65,z-45.1):return _source_floor.floor_world(x,z)
	return _validated_terrain_world(x,z)
func _valid_terrain(rid: RID) -> bool:
	if not policy._floors.has(rid):return false
	var record: Dictionary=policy._floors[rid]
	var collider: StaticBody3D=record.body.get_ref();var shape: CollisionShape3D=record.shape.get_ref()
	return is_instance_valid(collider) and is_instance_valid(shape) and collider.get_parent()==scene and collider.global_transform.is_equal_approx(record.frame) and collider.collision_layer==1 and not shape.disabled and shape.transform.is_equal_approx(Transform3D.IDENTITY) and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(record.size)
func _validated_terrain_world(x: float,z: float) -> float:
	var point:=Vector3(x-395.65,0,z-45.1);var index: int=policy._index(point)
	if index<0 or policy._land[index]==0:return NAN
	_ray.from=point+Vector3.UP*.30;_ray.to=point-Vector3.UP*.30
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty() or not _valid_terrain(hit.rid) or hit.normal.y<.70 or absf(hit.position.y-policy._heights[index])>.00001:return NAN
	return float(policy._heights[index])
func _floor_preview(x: float,z: float) -> float:
	var key:=str(x)+":"+str(z)
	if _floors.has(key):return _floors[key]
	if x<3.25 or x>9.65 or z<4.35 or z>6.9:return NAN
	var point:=Vector3(x,0,z);var index: int=policy._index(point)
	if index<0 or policy._land[index]==0:return NAN
	_ray.from=Vector3(x,.75,z);_ray.to=Vector3(x,-.25,z)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(_ray);diagnostics.floor_queries+=1
	var result:=NAN
	if not hit.is_empty() and hit.normal.y>=.70:
		var collider: CollisionObject3D=hit.collider
		if _valid_terrain(hit.rid) or (hit.rid in _entry_rids and interior.is_ancestor_of(collider) and collider.get_meta("source_id","")==BUILDING and collider.get_meta("interior_kind","")=="source-floor-ceiling"):
			var reference:=_floor_world(x+395.65,z+45.1)
			if is_finite(reference) and absf(reference-hit.position.y)<.002:result=hit.position.y
	_floors[key]=result;return result

func _source_segment(from: Vector3,to: Vector3,full_geometry:bool=true) -> bool:
	if not _current(full_geometry) or not from.is_finite() or not to.is_finite():diagnostics.last_reason="lease";return false
	if from.distance_to(to)>5.1:return false
	var fraction: float=interior.door_fraction("public")
	if fraction!=0.0 and fraction!=1.0:diagnostics.last_reason="door_moving";return false
	var sample_count:=maxi(1,ceili(Vector2(to.x-from.x,to.z-from.z).length()/(.14*4.1)))
	for i in sample_count+1:
		var centre:=from.lerp(to,float(i)/sample_count)
		if centre.x<inside.x-.035 or centre.x>9.0 or absf(centre.z-outside.z)>.20:diagnostics.last_reason="outside_lease_corridor";return false
		for offset: Vector2 in OFFSETS:
			if not is_finite(_floor_preview(centre.x+offset.x,centre.z+offset.y)):diagnostics.last_reason="corner_floor_or_land";return false
		if not host._owned_clear(centre,token.source_id):diagnostics.last_reason="occupant";return false
	if not _sweep.begin_segment([float(from.x)+395.65,float(from.z)+45.1],[float(to.x)+395.65,float(to.z)+45.1],.18*4.1):return false
	for solid: Dictionary in (_open_solids if fraction==1.0 else _closed_solids)+_static_solids:
		diagnostics.source_sweeps+=1
		if _sweep.blocks_polygon(solid.polygonCR,_floor_world,float(solid.get("minYM",NAN)),float(solid.get("maxYM",NAN))):
			diagnostics.last_reason="source_square_solid";diagnostics.last_polygon=solid;return false
	return _current(false)

func _capsule_clear(point: Vector3) -> bool:
	var floor_y:=_floor_preview(point.x,point.z)
	if not is_finite(floor_y):return false
	_query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,floor_y+.95+.02,point.z));_query.motion=Vector3.ZERO
	return scene.get_world_3d().direct_space_state.intersect_shape(_query,1).is_empty()

func _native_square_clear(from: Vector3,to: Vector3) -> bool:
	# Source polygon tests already prove the unchanged entry solids. Keep every
	# unknown/current obstacle at the original square size, including cars and
	# newly inserted blockers outside the smaller walking capsule.
	var excluded: Array[RID]=[body.get_rid()];excluded.append_array(_entry_rids)
	var first_y:=_floor_preview(from.x,from.z);var last_y:=_floor_preview(to.x,to.z)
	if not is_finite(first_y) or not is_finite(last_y):return false
	_square_query.exclude=excluded;_square_query.motion=Vector3.ZERO
	_square_query.transform=Transform3D(Basis.IDENTITY,Vector3(from.x,first_y+.95+.025,from.z))
	for hit: Dictionary in scene.get_world_3d().direct_space_state.intersect_shape(_square_query,64):
		if not _valid_terrain(hit.rid):diagnostics.last_reason="current_square_obstacle";return false
		excluded.append(hit.rid)
	_square_query.transform=Transform3D(Basis.IDENTITY,Vector3(to.x,last_y+.95+.025,to.z));_square_query.exclude=excluded
	for hit: Dictionary in scene.get_world_3d().direct_space_state.intersect_shape(_square_query,64):
		if not _valid_terrain(hit.rid):diagnostics.last_reason="current_square_obstacle";return false
		excluded.append(hit.rid)
	_square_query.transform=Transform3D(Basis.IDENTITY,Vector3(from.x,first_y+.95+.025,from.z));_square_query.exclude=excluded
	_square_query.motion=Vector3(to.x-from.x,last_y-first_y,to.z-from.z)
	var cast:=scene.get_world_3d().direct_space_state.cast_motion(_square_query)
	return cast.size()==2 and cast[0]>=.99999

func request_route(target: Vector3,phase: String,tolerance: float,actor_token: Dictionary) -> Dictionary:
	# Give each admission rejection its own reason; a previous negative probe
	# must not be reported as the cause of a later phase handoff refusal.
	if _busy:diagnostics.last_reason="request_busy";return {"accepted":false}
	if not _current():diagnostics.last_reason="request_lease_not_current";return {"accepted":false}
	if not host.target_current(actor_token):diagnostics.last_reason="request_actor_not_current";return {"accepted":false}
	if actor_token!=token:diagnostics.last_reason="request_token_mismatch";return {"accepted":false}
	if phase not in ["WALK_TO_ENTRY","ENTERING","EXITING","RETURNING_TO_STREET"]:diagnostics.last_reason="request_phase_unsupported:"+phase;return {"accepted":false}
	if not target.is_finite():diagnostics.last_reason="request_target_nonfinite";return {"accepted":false}
	var points: Array[Vector3]=[]
	if phase=="WALK_TO_ENTRY":
		if _phase!="READY" or target.distance_to(outside)>.001 or body.global_position.distance_to(outside)>1.6:return {"accepted":false}
		points.append(outside)
	elif phase=="ENTERING":
		if _phase!="WALK_TO_ENTRY" or target.distance_to(inside)>.001 or interior.door_fraction("public")!=1.0:return {"accepted":false}
		points.assign([lane_outside,lane_inside])
	elif phase=="EXITING":
		if _phase!="ENTERING" or target.distance_to(_return)>.001:return {"accepted":false}
		points.assign([lane_outside,_return])
	else:
		if _phase!="EXITING" or target.distance_to(_street_return)>.001 or _active<0 or _requests[_active].status!="ARRIVED":diagnostics.last_reason="street_return_state";return {"accepted":false}
		var record: Dictionary=host._records[token.source_id]
		if not host._source_admits(_street_return,record,"route"):diagnostics.last_reason="street_return_source_admission";return {"accepted":false}
		# This call crosses the RefCounted host interface: preserve Array[RID]
		# explicitly instead of passing an untyped literal to the typed method.
		var excluded: Array[RID]=[body.get_rid()]
		if not host._physical_clear(_street_return,excluded):diagnostics.last_reason="street_return_native_admission";return {"accepted":false}
		points.append(_street_return)
	_floors.clear();var previous:=body.global_position
	for point: Vector3 in points:
		if not _source_segment(previous,point) or not _capsule_clear(point):return {"accepted":false}
		previous=point
	if phase=="WALK_TO_ENTRY":_street_return=body.global_position
	if _active>=0:cancel(_active)
	if phase=="ENTERING":_return=body.global_position
	if host._records[token.source_id].request>=0:base_nav.cancel(host._records[token.source_id].request)
	_next_id+=1;_active=_next_id;_phase=phase
	_requests[_active]={"status":"READY","points":points,"edge":0,"tolerance":minf(.025,tolerance),"reason":""}
	host._records[token.source_id].request=_active
	return {"accepted":true,"request_id":_active}

func poll(id: int) -> Dictionary:
	if id<1000000:return base_nav.poll(id)
	if not _requests.has(id):return {"status":"CANCELLED"}
	if not _current() or (id==_active and host._records[token.source_id].request!=id):_requests[id].status="STALE";_requests[id].reason="actor_or_access_lease"
	return {"status":_requests[id].status,"reason":_requests[id].reason}

func request(owner: RefCounted,walker: CharacterBody3D,target: Vector3,admit: Callable) -> int:
	var result: int=base_nav.request(owner,walker,target,admit)
	if result>=0 and walker==body and _active>=0:
		_requests[_active].status="CANCELLED";_requests[_active].reason="new_native_request"
		_active=-1;_phase="SUPERSEDED"
	return result

func state() -> String:return base_nav.state()

func step(id: int,delta: float,speed: float,gravity: float) -> Dictionary:
	if id<1000000:return base_nav.step(id,delta,speed,gravity)
	var current:=poll(id)
	if _busy or current.status!="READY" or id!=_active or not is_finite(delta) or delta<=0 or delta>.05:return current
	_busy=true;var began:=Time.get_ticks_usec();_floors.clear()
	var request: Dictionary=_requests[id];var before:=body.global_position
	var target: Vector3=request.points[request.edge]
	var distance:=Vector2(target.x-before.x,target.z-before.z).length()
	if distance<=float(request.tolerance) and body.is_on_floor() and absf(before.y-_floor_preview(before.x,before.z))<.05:
		request.edge+=1
		if request.edge>=request.points.size():request.status="ARRIVED";body.velocity=Vector3.ZERO;_busy=false;return {"status":request.status,"reason":request.reason}
		target=request.points[request.edge];distance=Vector2(target.x-before.x,target.z-before.z).length()
	var velocity:=Vector3(target.x-before.x,0,target.z-before.z).normalized()*minf(speed,distance/delta)
	var after:=before+velocity*delta
	var floor_y:=_floor_preview(before.x,before.z)
	var allowed:=is_finite(floor_y) and absf(before.y-floor_y)<.05 and _source_segment(before,after,false) and _capsule_clear(after) and _native_square_clear(before,after)
	if allowed:
		_query.transform=Transform3D(Basis.IDENTITY,Vector3(before.x,floor_y+.95+.02,before.z))
		_query.motion=Vector3(after.x-before.x,_floor_preview(after.x,after.z)-floor_y,after.z-before.z)
		var cast:=scene.get_world_3d().direct_space_state.cast_motion(_query)
		allowed=cast.size()==2 and cast[0]>=.99999
	if allowed and _current(false):
		velocity.y=-2.0 if body.is_on_floor() else body.velocity.y-gravity*delta
		body.velocity=velocity;body.move_and_slide()
		var moved:=body.global_position.distance_to(before)
		diagnostics.travel_m+=moved;diagnostics.max_step_m=maxf(diagnostics.max_step_m,moved)
		if body.is_on_floor():diagnostics.floor_frames+=1
		if moved<.00001:request.status="BLOCKED";request.reason="native_movement_blocked"
	else:request.status="BLOCKED";request.reason=str(diagnostics.last_reason);body.velocity=Vector3.ZERO;diagnostics.blocked+=1
	diagnostics.steps+=1;diagnostics.times_us.append(Time.get_ticks_usec()-began);_busy=false
	return {"status":request.status,"reason":request.reason}

func _owns_current_life() -> bool:
	if host==null or not host.physical_life_current(token):return false
	var claim: Variant=host._records[token.source_id].get("local_route_owner")
	return claim is WeakRef and claim.get_ref()==self

func cancel(id: int) -> void:
	if id<1000000:base_nav.cancel(id);return
	if not _requests.has(id):return
	_requests[id].status="CANCELLED"
	if _active==id:
		_active=-1
		if _owns_current_life() and host._records[token.source_id].get("request",-1)==id:body.velocity=Vector3.ZERO

func cancel_visit(id:int) -> void:
	if id>=1000000:cancel(id)

func dispose() -> void:
	if _disposed:return
	if _active>=0:cancel(_active)
	for resource: Resource in _resources:
		if resource.changed.is_connected(_changed):resource.changed.disconnect(_changed)
	_resources.clear()
	for parent: Node in _shape_parents:
		if is_instance_valid(parent):
			if parent.child_entered_tree.is_connected(_child_changed):parent.child_entered_tree.disconnect(_child_changed)
			if parent.child_exiting_tree.is_connected(_child_changed):parent.child_exiting_tree.disconnect(_child_changed)
	_shape_parents.clear()
	if host!=null and host._records.has(token.get("source_id","")):
		var record: Dictionary=host._records[token.source_id]
		var local_owner: Variant=record.get("local_route_owner")
		if _owns_current_life() and record.request>=1000000 and _requests.has(record.request):record.request=-1
		if local_owner is WeakRef and local_owner.get_ref()==self:record.erase("local_route_owner")
		if host._navigation==self:host._navigation=base_nav
	_disposed=true
