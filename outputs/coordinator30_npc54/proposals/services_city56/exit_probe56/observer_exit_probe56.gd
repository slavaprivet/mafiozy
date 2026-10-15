extends "observer_services56.gd"
## Isolated, observational native geometry probe. It cannot pass acceptance.
## Reads native shapes/test_move; never alters a body, route, door or collider.
var _exit_anchors56: Dictionary = {}
var _exit_frames56: Array = []

func _shape56(shape: Shape3D) -> Dictionary:
	var result: Dictionary = {"class":shape.get_class(),"rid":str(shape.get_rid())}
	if shape is BoxShape3D: result.size = _v(shape.size)
	if shape is CapsuleShape3D: result.radius = shape.radius; result.height = shape.height
	if shape is CylinderShape3D: result.radius = shape.radius; result.height = shape.height
	return result

func _frame56(value: Transform3D) -> Dictionary:
	return {"origin":_v(value.origin),"basis":[_v(value.basis.x),_v(value.basis.y),_v(value.basis.z)]}

func _collider56(value: Variant) -> Dictionary:
	if not value is Node3D or not is_instance_valid(value): return {"value":str(value)}
	var result: Dictionary = {"path":str(value.get_path()),"class":value.get_class(),"id":value.get_instance_id(),"transform":_frame56(value.global_transform),"shapes":[]}
	if value is CollisionObject3D: result.layer = value.collision_layer; result.mask = value.collision_mask
	for child: Node in value.get_children():
		if child is CollisionShape3D:
			result.shapes.append({"path":str(child.get_path()),"disabled":child.disabled,"transform":_frame56(child.global_transform),"shape":_shape56(child.shape)})
	return result

func _hits56(body: CharacterBody3D, shape: CollisionShape3D, at: Vector3, raise_y: float, margin: float) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = Transform3D(body.global_basis,at+Vector3.UP*raise_y)*shape.transform
	q.collision_mask = body.collision_mask | 512
	q.exclude = [body.get_rid()]; q.margin = margin
	var result: Array = []
	for hit: Dictionary in body.get_world_3d().direct_space_state.intersect_shape(q,16):
		result.append({"shape_index":hit.get("shape"),"collider":_collider56(hit.get("collider"))})
	return result

func _motion56(body: CharacterBody3D, from: Vector3, to: Vector3, horizontal: bool) -> Dictionary:
	var transform: Transform3D = body.global_transform; transform.origin = from
	var motion: Vector3 = to-from
	if horizontal: motion.y = 0.0
	var collision := KinematicCollision3D.new()
	var blocked: bool = body.test_move(transform,motion,collision)
	var result: Dictionary = {"from":_v(from),"to":_v(to),"motion":_v(motion),"blocked":blocked}
	if blocked:
		result.travel = _v(collision.get_travel()); result.remainder = _v(collision.get_remainder())
		result.normal = _v(collision.get_normal()); result.position = _v(collision.get_position())
		result.collider = _collider56(collision.get_collider())
	return result

func _cast56(body: CharacterBody3D, shape: CollisionShape3D, from: Vector3, to: Vector3, raise_y: float) -> Array:
	var q := PhysicsShapeQueryParameters3D.new(); q.shape = shape.shape
	q.transform = Transform3D(body.global_basis,from+Vector3.UP*raise_y)*shape.transform
	q.collision_mask = body.collision_mask | 512; q.exclude = [body.get_rid()]; q.margin = .001
	q.motion = to-from
	return Array(body.get_world_3d().direct_space_state.cast_motion(q))

func _point_probe56(body: CharacterBody3D, shape: CollisionShape3D, probe: RefCounted, name: String, at: Vector3) -> Dictionary:
	var current: Vector3 = body.global_position
	var floor: Variant = probe.floor_at(at,current.y)
	var raw := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.7,body.collision_mask,[body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(raw)
	var result: Dictionary = {"name":name,"point":_v(at),"raw_floor":{},"floor":_v(floor) if floor is Vector3 else null,"standing_exact":_hits56(body,shape,at,0.0,0.0),"standing_route":_hits56(body,shape,at,.025,.001),"native_horizontal":_motion56(body,current,at,true),"native_full":_motion56(body,current,at,false),"cast_exact":_cast56(body,shape,current,at,0.0),"cast_route":_cast56(body,shape,current,at,.025)}
	if not hit.is_empty(): result.raw_floor = {"position":_v(hit.position),"normal":_v(hit.normal),"collider":_collider56(hit.collider)}
	if floor is Vector3:
		result.floor_exact_hits = _hits56(body,shape,floor,0.0,0.0)
		result.floor_route_hits = _hits56(body,shape,floor,.025,.001)
		result.route_edge_clear = probe.edge_clear(current,floor)
		result.route_last_failure = probe._last_query_failure; result.route_last_collider = probe._last_collider
	return result

func _geometry56(kind: String, c: Dictionary) -> Dictionary:
	var body: CharacterBody3D = c.body
	var visit: RefCounted = c.life._dsh_simple if kind == "hospital" else c.life._economy28._route
	var drive: RefCounted = visit._drive
	var route: RefCounted = drive._route
	var probe := Physical.new(); probe.configure(body)
	var shape: CollisionShape3D = probe.shape
	var before: Transform3D = body.global_transform
	var result: Dictionary = {"kind":kind,"source_id":c.id,"frame":Engine.get_physics_frames(),"elapsed_s":float(Time.get_ticks_msec()-_ready_ms)/1000.0,"position":_v(body.global_position),"body_transform":_frame56(body.global_transform),"shape_local":_frame56(shape.transform),"shape_global":_frame56(shape.global_transform),"shape":_shape56(shape.shape),"safe_margin":body.safe_margin,"on_floor":body.is_on_floor(),"drive":_route_debug(c,kind),"points":[],"grid_neighbours":[],"native_short_directions":[]}
	var points: Dictionary = {"current":body.global_position,"drive_target":drive._target,"route_goal":route.goal,"inner":visit._inner,"outside":visit._outside,"door":visit._door}
	if drive._way < route.route.size(): points.current_way = route.route[drive._way]
	if is_instance_valid(visit._door_owner):
		var door: Node3D = visit._door_owner
		result.door = {"fraction":door.fraction,"target":door.target,"anchor":_v(door.anchor),"hinge":_v(door.hinge),"leaf":_collider56(door.leaf)}
	for key: String in points:
		result.points.append(_point_probe56(body,shape,probe,key,points[key]))
	var start_key: Vector2i = route._key(body.global_position)
	result.grid_origin = _v(route.origin); result.grid_cell = route._cell; result.start_key = [start_key.x,start_key.y]
	for offset: Vector2i in Physical.DIRECTIONS:
		var key: Vector2i = start_key+offset
		var raw := Vector3(route.origin.x+key.x*route._cell,body.global_position.y,route.origin.z+key.y*route._cell)
		result.grid_neighbours.append(_point_probe56(body,shape,probe,str(offset),raw))
		var direction := Vector3(offset.x,0,offset.y).normalized()
		result.native_short_directions.append(_motion56(body,body.global_position,body.global_position+direction*.03,true))
	result.body_unchanged = body.global_transform == before
	result.production_route_unchanged = drive._route == route
	return result

func _sample(now: int) -> void:
	super._sample(now)
	if _finished: return
	for kind: String in _cases:
		var c: Dictionary = _cases[kind]
		if c.completed or c.route_phase != "OUTBOUND": continue
		var position: Vector3 = c.body.global_position
		if not _exit_anchors56.has(kind): _exit_anchors56[kind] = {"position":position,"ms":now}
		var anchor: Dictionary = _exit_anchors56[kind]
		if _flat(position,anchor.position) > .10: anchor.position = position; anchor.ms = now
		var visit: RefCounted = c.life._dsh_simple if kind == "hospital" else c.life._economy28._route
		if visit == null or visit._drive == null: continue
		var drive: RefCounted = visit._drive
		# Once per second only near an exit waypoint, including the frame before
		# the new watcher replans. No physics mutation is made by test_move.
		if now-int(anchor.ms) >= 1000 and _exit_frames56.size() < 20:
			_exit_frames56.append(_geometry56(kind,c))
		if now-int(anchor.ms) < 12000: continue
		var report: Dictionary = {"schema":"mafiozi.native-exit-geometry56/v1","acceptance_passed":false,"reason":"native_outbound_stall_reproduced","npc_relocations":0,"route_writes":0,"collider_writes":0,"body_writes":0,"samples":_exit_frames56,"final":_geometry56(kind,c)}
		var file := FileAccess.open(_out.path_join("EXIT_PROBE56.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
		print("EXIT_PROBE56_CAPTURED ",JSON.stringify({"kind":kind,"source_id":c.id,"elapsed_s":report.final.elapsed_s,"position":report.final.position,"samples":_exit_frames56.size()}))
		_finish("native_outbound_stall_geometry_captured"); return
