extends RefCounted
## Bounded local force follower. Route points are proposals from a pinned source
## export. Current full vehicle footprint, physics and exact seat owner still
## admit every tick. Local traffic stops use pinned original rule semantics.
const Fit = preload("res://scripts/transport/transport_parking_footprint.gd")
const TrafficGate = preload("npc_native_traffic_gate.gd")
const CELL := 4.1
var _trip: WeakRef
var _owner: WeakRef
var _points: Array=[]
var _index := 0
var _status := "UNBOUND"
var _reason := ""
var _origin := Vector3.ZERO
var _surface := {}
var _rects: Array=[]
var _bay: Dictionary
var _half := Vector2.ZERO
var _gear := 1.0
var _gear_wait := 0.0
var _elapsed := 0.0
var _stopped := 0.0
var _last_position := Vector3.ZERO
var _travelled := 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _box := BoxShape3D.new()
var _reservation: RefCounted
var _traffic: RefCounted
var _cumulative: Array[float]=[]
var _source_buckets := {}

func configure(trip: RefCounted, owner: Node3D, path: String, expected_sha256: String) -> Dictionary:
	if _status!="UNBOUND" or not trip.driver_current() or expected_sha256.length()!=64 or FileAccess.get_sha256(path)!=expected_sha256: return _fail("current_driver_and_pinned_route_required")
	var packet: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not packet is Dictionary or packet.get("schema")!="artist24.two-leg-source-world/v1": return _fail("route_schema")
	if packet.get("start",{}).get("bay_id")!=owner.PARKING_ID: return _fail("departure_bay_mismatch")
	var rows: Variant=packet.get("points")
	if not rows is Array or rows.size()<2 or rows.size()>4096: return _fail("bounded_source_route_required")
	var block: Dictionary=owner._npc_block
	if block.is_empty(): return _fail("current_native_block_required")
	# The current block is captured by the trusted scene owner. Its source pins
	# must match the pinned route; bounds are checked on every physical hull.
	for source: Dictionary in block.get("sources",[]):
		if packet.get("sourcePins",{}).has(source.path) and packet.sourcePins[source.path]!=source.sha256: return _fail("route_source_changed:"+str(source.path))
	for required: String in ["assets/maps/city_rebuild_v1/topology_for_placement.json","assets/maps/city_rebuild_v1/buildings_placement.v1.json"]:
		var matched:=false
		for source: Dictionary in block.get("sources",[]):
			if source.path==required and source.sha256==packet.get("sourcePins",{}).get(required): matched=true
		if not matched: return _fail("current_source_pin_required:"+required)
	_origin=Vector3(block.originM[0],block.originM[1],block.originM[2]);_surface=block.surface
	if _surface.get("cellSize")!=CELL or not _surface.get("masks",{}).get("roadMask") is Array: return _fail("source_road_surface_required")
	var parking: RefCounted=owner._npc_parking_data
	if parking==null: return _fail("source_parking_preload_pending")
	_bay=owner.runtime.catalog.parking_bay(str(packet.get("destination",{}).get("bay_id","")))
	if _bay.is_empty(): return _fail("unknown_source_destination_bay")
	var shape: Vector3=owner.body.profile.chassis_half_extents_m()
	var source_shape: Dictionary=packet.get("vehicleShape",{})
	if not source_shape.has("halfWidth") or not source_shape.has("halfLength"): return _fail("full_source_vehicle_shape_required")
	_half=Vector2(maxf(shape.x,float(source_shape.halfWidth)),maxf(shape.z,float(source_shape.halfLength)))
	var fit:=Fit.new()
	if not fit.source_bay_fits(shape.z/CELL,shape.x/CELL,fit.source_slot_from_bay(_bay)): return _fail("source_bay_fit_refused")
	for lot_id: String in [owner.runtime.catalog.parking_bay(owner.PARKING_ID).lot_id,_bay.lot_id]:
		var lot: Dictionary=parking.lot(lot_id)
		if lot.is_empty(): return _fail("source_lot_missing")
		for field: String in ["lot_rect_source_m","driveway_rect_source_m"]: _rects.append(lot[field])
	for row: Variant in rows:
		if not row is Dictionary: return _fail("route_pose")
		for field: String in ["x","z","yaw"]:
			if not (row.get(field) is int or row.get(field) is float) or not is_finite(float(row[field])): return _fail("route_pose")
		if row.get("gear") not in ["forward","reverse"]: return _fail("route_gear")
		_points.append({"position":Vector3(row.x-_origin.x,owner.body.global_position.y,row.z-_origin.z),"yaw":wrapf(float(row.yaw)+PI,-PI,PI),"gear":-1.0 if row.gear=="reverse" else 1.0,"parking":bool(row.get("parking",false))})
		_cumulative.append(0.0 if _points.size()==1 else _cumulative[-1]+(_points[-1].position as Vector3).distance_to(_points[-2].position))
	var bay_point:=Vector3(_bay.position_m.x-_origin.x,owner.body.global_position.y,_bay.position_m.z-_origin.z)
	if _points[0].position.distance_to(owner.body.global_position)>.35 or _points[-1].position.distance_to(bay_point)>.02 or absf(wrapf(_points[-1].yaw-float(_bay.yaw_rad),-PI,PI))>.001: return _fail("actual_start_or_source_bay_endpoint")
	_box.size=shape*2.0;_query.shape=_box;_query.collision_mask=owner.body.collision_mask;_query.exclude=[owner.body.get_rid()];_query.margin=.04
	_trip=weakref(trip);_owner=weakref(owner);_last_position=owner.body.global_position
	_index_source_solids(block)
	_traffic=TrafficGate.new()
	if packet.get("traffic_config_file")!="TRAFFIC_CONTROLS.json": return _fail("traffic_config_path")
	var traffic_result: Dictionary=_traffic.configure(owner,packet,FileAccess.get_file_as_bytes(path.get_base_dir()+"/TRAFFIC_CONTROLS.json"),_origin)
	if not traffic_result.get("ok",false): return _fail(str(traffic_result.get("reason","traffic_config")))
	# This owner has one current car. Claim is an opaque exact trip capability;
	# physical bay occupancy is checked now and again on arrival.
	if owner._npc_parking_reservations.has(_bay.parking_id): return _fail("bay_reserved")
	var target:=Transform3D(Basis(Vector3.UP,float(_bay.yaw_rad)),bay_point)
	if not _pose_clear(target): return _fail("destination_bay_occupied_or_surface_forbidden")
	_reservation=RefCounted.new();owner._npc_parking_reservations[_bay.parking_id]={"token":_reservation,"trip":weakref(trip),"vehicle":owner._vehicle_ref.duplicate()}
	_status="DRIVING";_gear=_points[0].gear
	return {"ok":true,"status":_status,"bay_id":_bay.parking_id,"points":_points.size(),"source_original_trip":false}

func snapshot() -> Dictionary:
	return {"status":_status,"reason":_reason,"index":_index,"points":_points.size(),"travelled_m":_travelled,"bay_id":_bay.get("parking_id",""),"body_transform_written":false,"traffic":{} if _traffic==null else _traffic.snapshot()}

func command(delta: float) -> Dictionary:
	var stopped: Dictionary={"throttle":0.0,"steering":0.0,"brake":1.0,"handbrake":true}
	if _status!="DRIVING": return stopped
	var trip: RefCounted=_trip.get_ref();var owner: Node3D=_owner.get_ref()
	if not is_instance_valid(trip) or not is_instance_valid(owner) or not trip.driver_current() or not _reservation_current(): _fail("driver_or_parking_owner_changed");return stopped
	if not is_finite(delta) or delta<=0 or delta>.05: return stopped
	_elapsed+=delta
	if _elapsed>180.0: _fail("local_trip_deadline");return stopped
	var body: RigidBody3D=owner.body
	_travelled+=body.global_position.distance_to(_last_position);_last_position=body.global_position
	var row: Dictionary=_points[_index]
	var distance: float=Vector2(row.position.x-body.global_position.x,row.position.z-body.global_position.z).length()
	var yaw: float=atan2(body.global_basis.z.x,body.global_basis.z.z)
	var yaw_error: float=wrapf(float(row.yaw)-yaw,-PI,PI)
	var endpoint: bool=_index==_points.size()-1 or (_index<_points.size()-1 and _points[_index+1].gear!=row.gear)
	if distance<.12 and (not endpoint or absf(yaw_error)<.04):
		if _index<_points.size()-1: _index+=1;row=_points[_index];distance=Vector2(row.position.x-body.global_position.x,row.position.z-body.global_position.z).length()
		elif body.linear_velocity.length()<.05 and _pose_clear(body.global_transform):
			_stopped+=delta
			if _stopped>=.35: _status="PARKED"
			return stopped
	if row.gear!=_gear:
		if body.linear_velocity.length()>.05: _gear_wait=0.0;return stopped
		_gear_wait+=delta
		if _gear_wait<.35: return stopped
		_gear=row.gear;_gear_wait=0.0
	# Dense source waypoints are geometry evidence, not compulsory individual
	# stops. Aim along the current same-gear polyline; admission still sweeps
	# the real next physical motion and never writes the body transform.
	var aim: Vector3=row.position
	if not endpoint:
		for look in range(_index+1,mini(_points.size(),_index+16)):
			if _points[look].gear!=_gear: break
			aim=_points[look].position
			if aim.distance_to(body.global_position)>=.8: break
	var direction: Vector3=aim-body.global_position;direction.y=0
	if direction.length_squared()<.000001: _reason="physical_final_alignment_required";return stopped
	var desired_yaw: float=atan2(-direction.x,-direction.z)+(PI if _gear<0 else 0.0)
	var angle_error: float=wrapf(desired_yaw-yaw,-PI,PI)
	if absf(angle_error)>1.2: _reason="physical_route_heading_diverged";return stopped
	var speed: float=body.linear_velocity.slide(Vector3.UP).length()
	var max_speed:=1.35 if row.parking else 2.5
	var traffic: Dictionary=_traffic.evaluate(delta,_progress(body.global_position),speed,_half.y)
	if not traffic.ok: _fail(traffic.reason);return stopped
	max_speed=minf(max_speed,float(traffic.speed_limit))
	if max_speed<.08: _reason=str(traffic.reason);return stopped
	var desired_speed: float=minf(max_speed,sqrt(maxf(0.0,2.0*2.0*(distance if endpoint else direction.length()))))*maxf(.3,1.0-absf(angle_error)*.7)
	if _index==_points.size()-1: desired_speed=minf(desired_speed,maxf(.08,distance*1.1))
	var lookahead:=maxf(.30,speed*speed/4.0+.25)
	var forward: Vector3=-body.global_basis.z*_gear
	var predicted:=body.global_transform
	predicted.origin+=forward*lookahead
	if not _sweep_clear(body.global_transform,predicted): _reason="current_native_or_source_footprint_blocked";return stopped
	_reason=str(traffic.reason)
	return {"throttle":clampf((desired_speed-speed)*.9,.12,.65)*_gear,"steering":clampf(angle_error*1.8*_gear,-1,1),"brake":clampf((speed-desired_speed)*1.2,0,1),"handbrake":false}

func _reservation_current() -> bool:
	var owner: Node3D=_owner.get_ref()
	var row: Dictionary=owner._npc_parking_reservations.get(_bay.parking_id,{})
	return row.get("token")==_reservation and row.get("vehicle")==owner._vehicle_ref and row.get("trip") is WeakRef and row.trip.get_ref()==_trip.get_ref()

func release() -> void:
	if _owner!=null and is_instance_valid(_owner.get_ref()) and _reservation_current(): _owner.get_ref()._npc_parking_reservations.erase(_bay.parking_id)
	if _status=="DRIVING": _status="CANCELLED"

func _sweep_clear(from: Transform3D, to: Transform3D) -> bool:
	var owner: Node3D=_owner.get_ref()
	var native: Dictionary=owner.body.body_sweep(to)
	if not native.get("valid",false) or float(native.get("safe_fraction",0.0))<.999999: return false
	var steps:=maxi(1,int(ceil(from.origin.distance_to(to.origin)/.15)))
	for index in range(steps+1):
		var at:=from;at.origin=from.origin.lerp(to.origin,float(index)/steps)
		if not _pose_clear(at): return false
	return true

func _pose_clear(at: Transform3D) -> bool:
	var owner: Node3D=_owner.get_ref()
	var polygon:=PackedVector2Array()
	var flat:=Basis(Vector3.UP,atan2(at.basis.z.x,at.basis.z.z))
	for corner: Vector2 in [Vector2(-_half.x,-_half.y),Vector2(-_half.x,_half.y),Vector2(_half.x,_half.y),Vector2(_half.x,-_half.y)]:
		var point:=at.origin+flat*Vector3(corner.x,0,corner.y)+_origin;polygon.append(Vector2(point.x,point.z))
	if not _center_route_allowed(at.origin+_origin) or not _covered(polygon) or not _source_solids_clear(polygon): return false
	_query.transform=at.translated_local(owner.body.profile.chassis_center_local_m());_query.motion=Vector3.ZERO
	return owner.get_world_3d().direct_space_state.intersect_shape(_query,1).is_empty()

## Source semantic: centre must stay on road/permitted access; the full hull
## may overlap source dry grass/paving/bridge, never water/police/obstacles.
func _covered(polygon: PackedVector2Array) -> bool:
	var min_x:=INF;var max_x:=-INF;var min_z:=INF;var max_z:=-INF
	for point: Vector2 in polygon: min_x=minf(min_x,point.x);max_x=maxf(max_x,point.x);min_z=minf(min_z,point.y);max_z=maxf(max_z,point.y)
	var remaining: Array=[polygon]
	for r in range(int(floor(min_z/CELL)),int(floor(max_z/CELL))+1):
		for c in range(int(floor(min_x/CELL)),int(floor(max_x/CELL))+1):
			var rr: int=r-int(_surface.startRow);var cc: int=c-int(_surface.startCol)
			if rr<0 or cc<0 or rr>=int(_surface.rows) or cc>=int(_surface.cols): return false
			if int(_surface.grid[rr][cc]) not in [0,8,9,19] or bool(_surface.masks.policeMask[rr][cc]): continue
			remaining=_subtract(remaining,{"minX":c*CELL,"maxX":(c+1)*CELL,"minZ":r*CELL,"maxZ":(r+1)*CELL})
	for rect: Dictionary in _rects: remaining=_subtract(remaining,rect)
	return remaining.is_empty()

func _center_route_allowed(point: Vector3) -> bool:
	for rect: Dictionary in _rects:
		if point.x>=rect.minX and point.x<=rect.maxX and point.z>=rect.minZ and point.z<=rect.maxZ: return true
	var r:=int(floor(point.z/CELL))-int(_surface.startRow);var c:=int(floor(point.x/CELL))-int(_surface.startCol)
	return r>=0 and c>=0 and r<int(_surface.rows) and c<int(_surface.cols) and bool(_surface.masks.roadMask[r][c])

func _progress(at: Vector3) -> float:
	if _index==0: return 0.0
	var a: Vector3=_points[_index-1].position;var b: Vector3=_points[_index].position
	var edge:=b-a;var amount:=clampf((at-a).dot(edge)/maxf(.000001,edge.length_squared()),0.0,1.0)
	return _cumulative[_index-1]+edge.length()*amount

func _index_source_solids(block: Dictionary) -> void:
	for building: Dictionary in block.get("buildings",[]):
		for solid: Dictionary in building.get("collisionBodiesM",[]):
			if float(solid.get("maxY",0))<=.22 or float(solid.get("minY",0))>1.95: continue
			var polygon:=PackedVector2Array()
			for point: Array in solid.get("polygonXZ",[]): polygon.append(Vector2(point[0]+_origin.x,point[1]+_origin.z))
			if polygon.size()<3: continue
			var minv:=polygon[0];var maxv:=minv
			for point: Vector2 in polygon: minv=minv.min(point);maxv=maxv.max(point)
			for r in range(int(floor(minv.y/CELL)),int(floor(maxv.y/CELL))+1):
				for c in range(int(floor(minv.x/CELL)),int(floor(maxv.x/CELL))+1):
					var key:=Vector2i(c,r)
					if not _source_buckets.has(key): _source_buckets[key]=[]
					_source_buckets[key].append(polygon)

func _source_solids_clear(polygon: PackedVector2Array) -> bool:
	var minv:=polygon[0];var maxv:=minv
	for point: Vector2 in polygon: minv=minv.min(point);maxv=maxv.max(point)
	for r in range(int(floor(minv.y/CELL)),int(floor(maxv.y/CELL))+1):
		for c in range(int(floor(minv.x/CELL)),int(floor(maxv.x/CELL))+1):
			for solid: PackedVector2Array in _source_buckets.get(Vector2i(c,r),[]):
				if not Geometry2D.intersect_polygons(polygon,solid).is_empty(): return false
	return true

func _subtract(polygons: Array, rect: Dictionary) -> Array:
	var result: Array=[]
	for polygon: PackedVector2Array in polygons:
		var inner:=polygon
		for cut: Array in [[0,float(rect.minX),true],[0,float(rect.maxX),false],[1,float(rect.minZ),true],[1,float(rect.maxZ),false]]:
			var outside:=_clip(inner,int(cut[0]),float(cut[1]),not bool(cut[2]))
			if outside.size()>=3 and absf(_area(outside))>.0000001: result.append(outside)
			inner=_clip(inner,int(cut[0]),float(cut[1]),bool(cut[2]))
			if inner.size()<3: break
	return result

func _clip(polygon: PackedVector2Array, axis: int, edge: float, above: bool) -> PackedVector2Array:
	var out:=PackedVector2Array()
	if polygon.is_empty(): return out
	var a: Vector2=polygon[-1];var ain: bool=(a[axis]>=edge) if above else (a[axis]<=edge)
	for b: Vector2 in polygon:
		var bin: bool=(b[axis]>=edge) if above else (b[axis]<=edge)
		if bin!=ain:
			var amount: float=(edge-a[axis])/(b[axis]-a[axis]);out.append(a.lerp(b,amount))
		if bin: out.append(b)
		a=b;ain=bin
	return out

func _area(polygon: PackedVector2Array) -> float:
	var area:=0.0
	for index in polygon.size(): area+=polygon[index].cross(polygon[(index+1)%polygon.size()])
	return area*.5

func _fail(reason: String) -> Dictionary:
	_status="BLOCKED";_reason=reason
	return {"ok":false,"reason":reason}
