extends RefCounted
## Original .738m square, contact-local floor and current native obstacles.
## Only the exact participating car is excluded, as source civilianDoorPath.
const Contact = preload("npc_contact_sweep.gd")
const HALF := .738
var _owner: WeakRef
var _block: Dictionary
var _origin: Array
var _solids: Array=[]
var _sweep:=Contact.new()
var _box:=BoxShape3D.new()
var _query:=PhysicsShapeQueryParameters3D.new()
var _ray:=PhysicsRayQueryParameters3D.new()
func configure(owner: Node3D) -> bool:
	if owner._npc_block.is_empty(): return false
	_owner=weakref(owner);_block=owner._npc_block;_origin=_block.originM
	for building: Dictionary in _block.buildings:
		for solid: Dictionary in building.collisionBodiesM:
			var polygon: Array=[]
			for pair: Array in solid.polygonXZ: polygon.append([(float(pair[0])+float(_origin[0]))/4.1,(float(pair[1])+float(_origin[2]))/4.1])
			_solids.append({"polygon":polygon,"min":float(solid.minY),"max":float(solid.maxY)})
	_box.size=Vector3(HALF*2.0,1.9,HALF*2.0);_query.shape=_box;_query.collision_mask=1;_query.margin=.001
	_ray.collision_mask=1
	return true
func _floor_at(world_x: float, world_z: float) -> float:
	var surface: Dictionary=_block.surface
	var r:=int(floor(world_z/4.1))-int(surface.startRow);var c:=int(floor(world_x/4.1))-int(surface.startCol)
	if r<1 or c<0 or r>=int(surface.rows) or c>=int(surface.cols): return NAN
	var tile: int=surface.grid[r][c]
	var palette: Dictionary=surface.palette[str(tile)]
	if tile not in [0,8,9,14] or not palette.solid: return NAN
	return float(palette.heightM)
func clear(actor: CharacterBody3D, vehicle: RigidBody3D, approach: Vector3, seat: Vector3) -> bool:
	var outward: Vector3=(approach-seat).slide(Vector3.UP).normalized()
	# Includes the bounded stopped-car exit recovery, and the real initial
	# approach tolerance. A moving-car tumble is deliberately unsupported here.
	return _segment(actor,vehicle,actor.global_position,seat) and _segment(actor,vehicle,approach+outward*.25,seat)
func _segment(actor: CharacterBody3D, vehicle: RigidBody3D, from: Vector3, to: Vector3) -> bool:
	var from_xz: Array=[float(from.x)+float(_origin[0]),float(from.z)+float(_origin[2])]
	var to_xz: Array=[float(to.x)+float(_origin[0]),float(to.z)+float(_origin[2])]
	if not _sweep.begin_segment(from_xz,to_xz,HALF,1.9): return false
	for solid: Dictionary in _solids:
		if _sweep.blocks_polygon(solid.polygon,_floor_at,solid.min,solid.max): return false
	var owner: Node3D=_owner.get_ref();var space:=owner.get_world_3d().direct_space_state
	_query.exclude=[actor.get_rid(),vehicle.get_rid()];_ray.exclude=_query.exclude
	var steps:=maxi(1,int(ceil(Vector2(to.x-from.x,to.z-from.z).length()/.1)))
	if steps>64: return false
	var previous:=Vector3.ZERO
	for index in range(steps+1):
		var point:=from.lerp(to,float(index)/steps)
		var center_floor:=_floor_at(float(point.x)+float(_origin[0]),float(point.z)+float(_origin[2]))
		if not is_finite(center_floor): return false
		for offset: Vector2 in [Vector2.ZERO,Vector2(-HALF,-HALF),Vector2(-HALF,HALF),Vector2(HALF,-HALF),Vector2(HALF,HALF)]:
			var probe:=point+Vector3(offset.x,0,offset.y)
			var floor_y:=_floor_at(float(probe.x)+float(_origin[0]),float(probe.z)+float(_origin[2]))
			if not is_finite(floor_y): return false
			_ray.from=Vector3(probe.x,floor_y+.3,probe.z);_ray.to=Vector3(probe.x,floor_y-.3,probe.z)
			var hit: Dictionary=space.intersect_ray(_ray)
			if hit.is_empty() or hit.normal.y<.7 or absf(float(hit.position.y)-floor_y)>.025: return false
		var position:=Vector3(point.x,center_floor+.975,point.z)
		_query.motion=Vector3.ZERO;_query.transform=Transform3D(Basis.IDENTITY,position)
		if not space.intersect_shape(_query,1).is_empty(): return false
		if index>0:
			_query.transform.origin=previous;_query.motion=position-previous
			var cast: PackedFloat32Array=space.cast_motion(_query)
			if cast.size()!=2 or cast[0]<.999999: return false
		previous=position
	return true
