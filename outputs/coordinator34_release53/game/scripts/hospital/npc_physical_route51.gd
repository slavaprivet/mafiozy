extends RefCounted
## Incremental physical A*: live full-body queries, no navigation mesh assumption.
## Shared 1800us SOFT deadline per physics frame across all local searches.
## Each service unit examines one neighbour or one direct-path support sample.
const Passage31 = preload("res://scripts/navigation/npc_passage31.gd")
const Surface = preload("res://scripts/hospital/npc_walk_surface28.gd")
const Budget = preload("res://scripts/hospital/npc_route_budget29.gd")
var _surface: RefCounted
var _passage31: Node
const CELL := 0.4
const STEP := 0.34
const CLEARANCE := 0.025
const LIMIT := 18000
const COARSE_CELL := 1.2
const DIRECT_LIMIT_M := 32.0
const DIRECTIONS := [Vector2i(-1,-1), Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,-1), Vector2i(0,1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1)]
var _cell := CELL
var _coarse_fallback := false
var body: CharacterBody3D
var shape: CollisionShape3D
var goal := Vector3.ZERO
var origin := Vector3.ZERO
var status := "idle"
var route: Array[Vector3] = []
var _open: Array = []
var _nodes: Dictionary = {}
var _closed: Dictionary = {}
var _seq := 0
var expanded := 0
var queries := 0
var _goal_y := 0.0
var _last_query_failure := ""
var _last_collider := ""
var _last_tick_us := 0
## Monotonic over this route object: inner begin/cancel must not erase goal work.
var service_us29 := 0
var _max_tick_us := 0
var _phase := "idle"
var _work_key := Vector2i.ZERO
var _work_node: Dictionary = {}
var _neighbour := 0
var _direct_start := Vector3.ZERO
var _direct_end := Vector3.ZERO
var _direct_count := 0
var _direct_index := 0
var _direct_used := false
var _reported_nodes := 0
var _reported_open := 0
var _pruned_lower_bound := 0
var _total_expanded := 0
var _ready_frame := -1
var _reconstruct_cursor := Vector2i.ZERO
var _reverse_route: Array[Vector3] = []

func configure(actor: CharacterBody3D) -> bool:
	cancel()
	if not is_instance_valid(actor) or not actor.is_inside_tree(): return false
	body = actor
	_passage31 = Passage31.for_scene(actor.get_tree().current_scene)
	shape = null
	for child: Node in body.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
			shape = child
			break
	if shape == null:return false
	_surface=Surface.new()
	return _surface.configure(body.get_tree().current_scene,body)

func _space() -> PhysicsDirectSpaceState3D:
	return body.get_world_3d().direct_space_state

func floor_at(at: Vector3, reference_y: float) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, reference_y + STEP + .06, at.z), Vector3(at.x, reference_y - .7, at.z), body.collision_mask, _exclusions31(at))
	queries += 1
	var hit: Dictionary = _space().intersect_ray(q)
	if hit.is_empty():
		_last_query_failure="floor_missing"
		return null
	if (hit.normal as Vector3).dot(Vector3.UP)<.7:
		_last_query_failure="floor_slope"
		return null
	var admission: Dictionary=_surface.check(at,hit)
	queries+=int(admission.get("queries",0))
	if not bool(admission.get("ok",false)):
		_last_query_failure="surface:"+str(admission.get("reason",""))
		return null
	return Vector3(at.x, float(hit.position.y) + .003, at.z)

func _exclusions31(at: Vector3) -> Array[RID]:
	return _passage31.query_exclusions(body, at) if is_instance_valid(_passage31) else [body.get_rid()]

func _query(at: Vector3) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = Transform3D(body.global_basis, at + Vector3.UP * CLEARANCE) * shape.transform
	q.collision_mask = body.collision_mask | 512
	q.exclude = _exclusions31(at)
	q.margin = .001
	return q

func standing(at: Vector3) -> bool:
	queries += 1
	var hits: Array[Dictionary]=_space().intersect_shape(_query(at),1)
	if hits.is_empty():return true
	_last_query_failure="standing_blocked"
	var collider: Variant=hits[0].get("collider")
	_last_collider=str(collider.get_path()) if collider is Node and is_instance_valid(collider) else str(collider)
	return false

func sweep(a: Vector3, b: Vector3) -> bool:
	var q := _query(a)
	q.motion = b - a
	queries += 1
	var fractions: PackedFloat32Array = _space().cast_motion(q)
	var clear: bool=fractions.size()==2 and fractions[0]>=.999
	if not clear:_last_query_failure="sweep_blocked"
	return clear

func edge_clear(a: Vector3, b: Vector3) -> bool:
	# Sample support across the segment, including capsule overlap at water edges.
	var count: int=maxi(1,ceili(Vector2(a.x-b.x,a.z-b.z).length()/maxf(.08,_surface.footprint_radius()*.5)))
	for i: int in range(1,count):
		var between: Vector3=a.lerp(b,float(i)/count)
		if not floor_at(between,between.y) is Vector3:return false
	if absf(a.y-b.y) > STEP + .01 or not standing(b): return false
	if absf(a.y-b.y) < .035: return sweep(a,b)
	var top: float = maxf(a.y,b.y) + .025
	var up := Vector3(a.x,top,a.z)
	var across := Vector3(b.x,top,b.z)
	return sweep(a,up) and sweep(up,across) and sweep(across,b)

func _key(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x-origin.x)/_cell),roundi((p.z-origin.z)/_cell))

func _estimate(p: Vector3) -> float:
	return Vector2(p.x-goal.x,p.z-goal.z).length()

func begin(target: Vector3) -> bool:
	cancel()
	if not _actor_live() or not target.is_finite():
		status="blocked";_last_query_failure="invalid_actor_or_goal"
		return false
	_cell=COARSE_CELL if Vector2(body.global_position.x-target.x,body.global_position.z-target.z).length()>8.0 else CELL
	_coarse_fallback=false
	queries=0;expanded=0;_total_expanded=0;_pruned_lower_bound=0;_direct_used=false
	_last_query_failure="";_last_collider="";_last_tick_us=0;_max_tick_us=0
	_ready_frame=-1;_reported_nodes=0;_reported_open=0
	if not Budget.enqueue(self):
		status="blocked";_last_query_failure="shared_queue_full"
		return false
	if not _begin_grid(target): return false
	var length: float=Vector2(body.global_position.x-target.x,body.global_position.z-target.z).length()
	if length<=DIRECT_LIMIT_M:
		_direct_start=body.global_position
		_phase="direct_probe"
	return true

func _begin_grid(target: Vector3) -> bool:
	goal=target
	_goal_y=target.y
	origin=target
	if not _nodes.is_empty() or not _open.is_empty():
		Budget.claim(self,-_nodes.size(),-_open.size())
	_open.clear(); _nodes.clear(); _closed.clear(); route.clear(); expanded=0
	_work_node.clear();_neighbour=0;_phase="pop"
	var start: Vector3=body.global_position
	var k: Vector2i=_key(start)
	if not Budget.claim(self,1,1):
		_finish("blocked","shared_memory_capacity")
		return false
	_nodes[k]={"at":start,"g":0.0,"parent":k}
	_push(k,_estimate(start),0.0)
	status="searching"
	return true

func _push(k: Vector2i, f: float, g: float) -> void:
	_seq+=1
	var item: Dictionary={"k":k,"f":f,"g":g,"seq":_seq}
	_open.append(item)
	var i: int=_open.size()-1
	while i>0:
		var parent: int=(i-1)/2
		if float(_open[parent].f)<=f: break
		_open[i]=_open[parent];i=parent
	_open[i]=item

func _pop() -> Dictionary:
	Budget.claim(self,0,-1)
	var first: Dictionary=_open[0]
	var last: Dictionary=_open.pop_back()
	if _open.is_empty(): return first
	var i:=0
	while i*2+1<_open.size():
		var child: int=i*2+1
		if child+1<_open.size() and float(_open[child+1].f)<float(_open[child].f):child+=1
		if float(last.f)<=float(_open[child].f):break
		_open[i]=_open[child];i=child
	_open[i]=last
	return first

func tick() -> String:
	if status!="searching":return status
	Budget.touch(self)
	Budget.pump()
	return status

func _actor_live() -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.is_queued_for_deletion() and is_instance_valid(shape) and not shape.disabled

func _budget_live() -> bool:
	return status=="searching" and _actor_live()

## No callback retains self: the shared queue owns WeakRef only.
func cancel() -> void:
	Budget.release(self)
	_open.clear();_nodes.clear();_closed.clear();_work_node.clear();route.clear();_reverse_route.clear()
	status="cancelled";_phase="cancelled"

func _finish(result: String, reason: String = "") -> void:
	_reported_nodes=_nodes.size();_reported_open=_open.size()
	Budget.release(self)
	_open.clear();_nodes.clear();_closed.clear();_work_node.clear();_reverse_route.clear()
	status=result;_phase=result
	if result=="ready":_ready_frame=Engine.get_physics_frames()
	if not reason.is_empty():_last_query_failure=reason

func _budget_step() -> void:
	var since: int=Time.get_ticks_usec()
	_step_unit()
	_note_tick(since)

func _step_unit() -> void:
	if _phase=="reconstruct":
		var node: Dictionary=_nodes[_reconstruct_cursor]
		var parent: Vector2i=node.parent
		if parent==_reconstruct_cursor:
			_phase="reconstruct_emit"
		else:
			_reverse_route.append(node.at)
			_reconstruct_cursor=parent
		return
	if _phase=="reconstruct_emit":
		if not _reverse_route.is_empty():route.append(_reverse_route.pop_back())
		else:_finish("ready")
		return
	if _phase=="direct_probe":
		# Sweep FIRST rejects a wall cheaply. All intervening support/water samples
		# must still pass before direct readiness; no ray alone grants admission.
		_phase="pop"
		var grounded: Variant=floor_at(goal,_direct_start.y)
		if not grounded is Vector3 or absf(grounded.y-_goal_y)>=.5 or absf(_direct_start.y-grounded.y)>=.035:return
		if not standing(grounded) or not sweep(_direct_start,grounded):return
		_direct_end=grounded
		_direct_count=maxi(1,ceili(Vector2(_direct_start.x-grounded.x,_direct_start.z-grounded.z).length()/maxf(.08,_surface.footprint_radius()*.5)))
		_direct_index=1;_phase="direct_support"
		return
	if _phase=="direct_support":
		if _direct_index<_direct_count:
			var between: Vector3=_direct_start.lerp(_direct_end,float(_direct_index)/_direct_count)
			_direct_index+=1
			if not floor_at(between,between.y) is Vector3:_phase="pop"
			return
		goal=_direct_end;route=[goal];_direct_used=true
		_finish("ready")
		return
	if _phase=="pop":
		if _open.is_empty():
			if _cell>CELL:
				# Original fine-grid fallback retains every full-capsule check.
				_cell=CELL;_coarse_fallback=true;_begin_grid(goal)
			else:_finish("blocked","no_physical_route")
			return
		var item: Dictionary=_pop()
		var k: Vector2i=item.k
		if _closed.has(k):return
		var node: Dictionary=_nodes[k]
		if float(item.g)>float(node.g)+.001:return
		_closed[k]=true;expanded+=1;_total_expanded+=1
		_work_key=k;_work_node=node;_neighbour=0
		_phase="goal" if _estimate(node.at)<=_cell*1.5 else "neighbour"
		return
	if _phase=="goal":
		_phase="neighbour"
		var at: Vector3=_work_node.at
		var grounded: Variant=floor_at(goal,at.y)
		if grounded is Vector3 and absf(grounded.y-_goal_y)<.5 and edge_clear(at,grounded):
			goal=grounded;_reconstruct(_work_key)
		return
	if expanded>=LIMIT:
		_finish("blocked","expansion_limit")
		return
	if _neighbour>=DIRECTIONS.size():
		_phase="pop"
		return
	var nk: Vector2i=_work_key+DIRECTIONS[_neighbour]
	_neighbour+=1
	if _closed.has(nk) or absf(nk.x*_cell)>90.0 or absf(nk.y*_cell)>90.0:return
	var at: Vector3=_work_node.at
	var raw:=Vector3(origin.x+nk.x*_cell,at.y,origin.z+nk.y*_cell)
	# A horizontal-distance lower bound can reject an inferior edge BEFORE its
	# floor/water query, because the true 3D edge can never be shorter.
	if _nodes.has(nk) and float(_work_node.g)+at.distance_to(raw)>=float(_nodes[nk].g)-.001:
		_pruned_lower_bound+=1
		return
	var next: Variant=floor_at(raw,at.y)
	if not next is Vector3:return
	var ng: float=float(_work_node.g)+at.distance_to(next)
	if _nodes.has(nk) and ng>=float(_nodes[nk].g)-.001:return
	if not edge_clear(at,next):return
	if not Budget.claim(self,0 if _nodes.has(nk) else 1,1):
		_finish("blocked","shared_memory_capacity")
		return
	_nodes[nk]={"at":next,"g":ng,"parent":_work_key}
	_push(nk,ng+_estimate(next)*1.05,ng)

func _note_tick(since: int) -> void:
	_last_tick_us=Time.get_ticks_usec()-since
	_max_tick_us=maxi(_max_tick_us,_last_tick_us)
	service_us29+=_last_tick_us

func diagnostics() -> Dictionary:
	return {"status":status,"cell_m":_cell,"coarse_fallback":_coarse_fallback,"expanded":expanded,"total_expanded":_total_expanded,"open":_open.size() if status=="searching" else _reported_open,"nodes":_nodes.size() if status=="searching" else _reported_nodes,"queries":queries,"tick_us":_last_tick_us,"service_us29":service_us29,"max_tick_us":_max_tick_us,"last_query_failure":_last_query_failure,"last_collider":_last_collider,"search_phase":_phase,"direct_used":_direct_used,"pruned_lower_bound":_pruned_lower_bound,"ready_frame":_ready_frame,"shared_budget":Budget.diagnostics()}

func hold(delta: float) -> Vector3:
	var before: Vector3=body.global_position
	var vy: float=minf(0.0,body.velocity.y) if body.is_on_floor() else body.velocity.y
	body.velocity=Vector3(0,vy-9.8*delta,0)
	body.move_and_slide()
	return body.global_position-before

func _reconstruct(k: Vector2i) -> void:
	# Append in reverse, then emit one point per service unit. No quadratic
	# push_front loop and no unbudgeted chain walk on a long accepted route.
	route.clear();_reverse_route=[goal];_reconstruct_cursor=k;_phase="reconstruct"

func move(direction: Vector3, distance: float, delta: float) -> Vector3:
	var before: Vector3=body.global_position
	# Debris uses layer512, while health/recovery contracts retain the native mask1.
	# Full-capsule live query blocks movement into rubble without mutating that contract.
	var obstacle:=_query(before)
	obstacle.collision_mask=512
	obstacle.motion=direction*distance
	queries+=2
	var fraction: PackedFloat32Array=_space().cast_motion(obstacle)
	if not _space().intersect_shape(obstacle,1).is_empty() or fraction.size()!=2 or fraction[0]<.999:
		_last_query_failure="debris_motion_blocked"
		return hold(delta)
	var vy: float=0.0 if body.is_on_floor() and body.velocity.y<=0.0 else body.velocity.y-9.8*delta
	body.velocity=direction*(distance/maxf(delta,.0001))+Vector3.UP*vy
	body.move_and_slide()
	var done: float=Vector2(body.global_position.x-before.x,body.global_position.z-before.z).length()
	if done < distance*.5 and distance>.001:
		var rest: float=maxf(0.0,distance-done)
		var here: Vector3=body.global_position
		var ground: Variant=floor_at(here+direction*(rest+.40),here.y)
		if ground is Vector3 and ground.y>here.y+.025 and ground.y-here.y<=STEP:
			var rise: float=ground.y-here.y+.025
			var from: Transform3D=body.global_transform
			var lift: Vector3=Vector3.UP*rise
			var along: Vector3=direction*rest
			if not body.test_move(from,lift):
				from.origin+=lift
				if not body.test_move(from,along):
					# Each real leg is collision-resolved; no position assignment.
					body.move_and_collide(lift)
					body.move_and_collide(along)
					body.move_and_collide(Vector3.DOWN*(rise+.05))
	return body.global_position-before
