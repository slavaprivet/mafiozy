extends RefCounted
## Local scene traffic timer and current native occupancy. Source rule semantics
## come from the pinned pure helper; geometry is queried against real bodies.
const Rules = preload("route/npc_traffic_rules.gd")
var _rules := Rules.new()
var _controls: Array=[]
var _zones := {}
var _committed := {}
var _owner: WeakRef
var _origin := Vector3.ZERO
var _clock := 0.0
var _checks := 0

func configure(owner: Node3D, packet: Dictionary, config: PackedByteArray, origin: Vector3) -> Dictionary:
	var result: Dictionary=_rules.configure(packet,config)
	if not result.get("ok",false): return result
	_owner=weakref(owner);_origin=origin
	_controls=packet.controls.duplicate(true)
	for control: Dictionary in _controls:
		var zones: Dictionary=_rules.zones(control)
		_zones[control.control_key]={"pedestrians":_prepare(zones.pedestrians),"vehicles":_prepare(zones.vehicles)}
	return {"ok":true}

func _prepare(rows: Array) -> Array:
	var prepared: Array=[]
	for row: Dictionary in rows:
		var bb: Dictionary=row.aabb
		var broad:=BoxShape3D.new();broad.size=Vector3(bb.maxX-bb.minX,5.0,bb.maxZ-bb.minZ)
		var zone: Dictionary={"broad":broad,"at":Transform3D(Basis.IDENTITY,Vector3((bb.minX+bb.maxX)*.5-_origin.x,2.0,(bb.minZ+bb.maxZ)*.5-_origin.z)),"segments":[]}
		for index in range(row.points.size()-1):
			var a:=Vector3(row.points[index].x-_origin.x,1.0,row.points[index].z-_origin.z)
			var b:=Vector3(row.points[index+1].x-_origin.x,1.0,row.points[index+1].z-_origin.z)
			if a.distance_squared_to(b)<.000001: continue
			var capsule:=CapsuleShape3D.new();capsule.radius=float(row.radius_m);capsule.height=a.distance_to(b)+2.0*capsule.radius
			zone.segments.append({"shape":capsule,"at":Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5)})
		prepared.append(zone)
	return prepared

func evaluate(delta: float, progress: float, speed: float, front: float) -> Dictionary:
	_clock+=delta
	var speed_limit:=INF;var reason:=""
	for control: Dictionary in _controls:
		var key: String=control.control_key
		if _committed.has(key): continue
		var gap: float=float(control.distanceM)-progress-front
		if gap>maxf(5.0,speed*speed/4.0+2.0): continue
		var zones: Dictionary=_zones[key]
		var pedestrians:=_occupied(zones.pedestrians)
		var vehicles:=_occupied(zones.vehicles)
		var result: Dictionary=_rules.evaluate(control,_clock,pedestrians,vehicles)
		_checks+=1
		if result.allowed:
			if gap<=.30: _committed[key]=true
		else:
			reason=str(result.reason)
			if gap<-.15: return {"ok":false,"speed_limit":0.0,"reason":"stop_line_crossed_without_clearance:"+key}
			speed_limit=minf(speed_limit,sqrt(maxf(0.0,4.0*(gap-.25))))
	return {"ok":true,"speed_limit":speed_limit,"reason":reason}

func _occupied(zones: Array) -> bool:
	var owner: Node3D=_owner.get_ref()
	if not is_instance_valid(owner): return true
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=[owner.body.get_rid()]
	var space:=owner.get_world_3d().direct_space_state
	for zone: Dictionary in zones:
		query.shape=zone.broad;query.transform=zone.at
		var hits: Array=space.intersect_shape(query,64)
		if hits.size()>=64: return true
		if not _moving_body_present(hits): continue
		for segment: Dictionary in zone.segments:
			query.shape=segment.shape;query.transform=segment.at
			hits=space.intersect_shape(query,64)
			if hits.size()>=64 or _moving_body_present(hits): return true
	return false

func _moving_body_present(hits: Array) -> bool:
	for hit: Dictionary in hits:
		var collider: Object=hit.get("collider")
		if collider is CharacterBody3D or collider is RigidBody3D: return true
	return false

func snapshot() -> Dictionary:
	return {"local_time_s":_clock,"checks":_checks,"committed":_committed.size(),"controls":_controls.size(),"server_authority":false}
