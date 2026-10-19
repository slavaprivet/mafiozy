extends RefCounted
## Bounded local A* proposal around current physical blockers. No body writes,
## no navigation requests and no authority: caller authorizes and executes each
## resulting leg through the existing daily host, then rechecks at movement.
const CELL := 1.25
const RANGE := 8.0
const MAX_NODES := 160
const MAX_CHECKS := 640
const CHECKS_PER_FRAME := 3
const USEC_PER_FRAME := 750
const MAX_FRAMES := 240
const DIRECTIONS := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1),Vector2i(1,-1)]
var _host: RefCounted
var _policy: RefCounted
var _owner: WeakRef
var _token := {}
var _navigation: RefCounted
var _map := RID()
var _iteration := 0
var _claim_serial := -1
var _origin := Vector3.ZERO
var _goals: Array=[]
var _nodes: Array=[]
var _by_key := {}
var _open: Array[int]=[]
var _active := -1
var _candidates: Array=[]
var _cursor := 0
var _checks := 0
var _frames := 0
var _frame := -1
var _status := "UNBOUND"
var _reason := ""
var _result := PackedVector3Array()
var _rejoin := -1
var _max_step_us := 0

func begin(host: RefCounted, policy: RefCounted, activity_owner: RefCounted, token: Dictionary, map: RID, iteration: int, route: PackedVector3Array, first_index: int) -> Dictionary:
	if _status!="UNBOUND" or not is_instance_valid(host) or not is_instance_valid(policy) or not is_instance_valid(activity_owner) or first_index<0 or first_index>=route.size(): return {"ok":false,"reason":"detour_arguments"}
	for method: String in ["native_clear_segment","_ordinary_navigation"]:
		if not policy.has_method(method): return {"ok":false,"reason":"native_detour_policy_required"}
	if not host.has_method("_local_walker_current") or not host._local_walker_current(token): return {"ok":false,"reason":"current_original_walker_required"}
	_host=host;_policy=policy;_owner=weakref(activity_owner);_token=token.duplicate();_map=map;_iteration=iteration
	_navigation=policy._ordinary_navigation(host)
	_claim_serial=int(host.daily_activity_status(token.source_id).get("serial",-1))
	_origin=token.body.global_position
	if not _current(): return _fail("detour_current_idle_actor_required")
	# Rejoin only a short prefix of the still-desired path. A blocked next goal
	# may be inside the car; later real goals let us get around its far end.
	for index in range(first_index,mini(route.size(),first_index+4)):
		var point: Vector3=route[index]
		if not point.is_finite() or Vector2(point.x-_origin.x,point.z-_origin.z).length()>RANGE+.01: continue
		var projected:=NavigationServer3D.map_get_closest_point(_map,point)
		if projected.distance_to(point)>.12: continue
		_goals.append({"point":projected,"index":index})
	if _goals.is_empty(): return _fail("no_bounded_native_rejoin_goal")
	_nodes.append({"point":_origin,"key":Vector2i.ZERO,"g":0.0,"parent":-1,"closed":false})
	_by_key[Vector2i.ZERO]=0;_open.append(0);_status="SEARCHING"
	return {"ok":true,"status":_status,"movement_owner":"existing_daily_host"}

func _current() -> bool:
	if not Thread.is_main_thread() or not is_instance_valid(_host) or not is_instance_valid(_policy) or _owner==null or not is_instance_valid(_owner.get_ref()) or not _host._local_walker_current(_token): return false
	var lease: Dictionary=_host.daily_activity_status(_token.source_id)
	if not lease.get("current",false) or lease.get("owner")!=_owner.get_ref() or lease.get("serial")!=_claim_serial or lease.get("life_generation")!=_token.life_generation: return false
	# Cancel the exact old request publicly before beginning search. A newer
	# request or physical move immediately invalidates this old proposal.
	if int(_host._records[_token.source_id].get("request",-2))!=-1 or _token.body.global_position.distance_to(_origin)>.05: return false
	if _navigation==null or _policy._ordinary_navigation(_host)!=_navigation or not _map.is_valid(): return false
	var backend: Variant=_navigation.get("_backend")
	return backend!=null and backend.map_rid()==_map and NavigationServer3D.map_get_iteration_id(_map)==_iteration

func step() -> Dictionary:
	if _status!="SEARCHING": return snapshot()
	var frame:=Engine.get_physics_frames()
	if frame==_frame: return snapshot()
	_frame=frame;_frames+=1
	if not _current(): _fail("detour_actor_claim_request_or_map_changed");return snapshot()
	if _frames>MAX_FRAMES: _fail("detour_frame_budget");return snapshot()
	var began:=Time.get_ticks_usec();var count:=0
	while count<CHECKS_PER_FRAME and Time.get_ticks_usec()-began<USEC_PER_FRAME:
		if _checks>=MAX_CHECKS: _fail("detour_query_budget");break
		if _active<0:
			_active=_pop_best()
			if _active<0: _fail("bounded_native_detour_exhausted");break
			_prepare_candidates()
		if _cursor>=_candidates.size(): _active=-1;continue
		var candidate: Dictionary=_candidates[_cursor];_cursor+=1
		var start: Vector3=_nodes[_active].point
		var point: Vector3=candidate.point
		if Vector2(point.x-_origin.x,point.z-_origin.z).length()>RANGE+.01 or point.distance_to(start)>5.0: continue
		if not candidate.get("goal",false) and _by_key.has(candidate.key) and _nodes[_by_key[candidate.key]].closed: continue
		var projected:=NavigationServer3D.map_get_closest_point(_map,point)
		if projected.distance_to(point)>.12: continue
		_checks+=1;count+=1
		if not _policy.native_clear_segment(_token,start,projected): continue
		if not _current(): _fail("detour_owner_changed_during_native_probe");break
		if candidate.get("goal",false):
			_finish(projected,int(candidate.index));break
		var cost: float=float(_nodes[_active].g)+start.distance_to(projected)
		if _by_key.has(candidate.key):
			var known: int=_by_key[candidate.key]
			if cost<float(_nodes[known].g): _nodes[known].g=cost;_nodes[known].parent=_active
		else:
			if _nodes.size()>=MAX_NODES: _fail("detour_node_budget");break
			var next:=_nodes.size()
			_by_key[candidate.key]=next
			_nodes.append({"point":projected,"key":candidate.key,"g":cost,"parent":_active,"closed":false});_open.append(next)
	_max_step_us=maxi(_max_step_us,Time.get_ticks_usec()-began)
	return snapshot()

func _pop_best() -> int:
	var best:=-1;var score:=INF
	for index in _open.size():
		var node: Dictionary=_nodes[_open[index]]
		var heuristic:=INF
		for goal: Dictionary in _goals: heuristic=minf(heuristic,(node.point as Vector3).distance_to(goal.point))
		if float(node.g)+heuristic<score: score=float(node.g)+heuristic;best=index
	if best<0: return -1
	var selected: int=_open[best];_open.remove_at(best);_nodes[selected].closed=true
	return selected

func _prepare_candidates() -> void:
	_candidates=[];_cursor=0
	var node: Dictionary=_nodes[_active]
	for goal: Dictionary in _goals:
		if (node.point as Vector3).distance_to(goal.point)<=3.0: _candidates.append({"goal":true,"point":goal.point,"index":goal.index})
	for direction: Vector2i in DIRECTIONS:
		var key: Vector2i=node.key+direction
		_candidates.append({"goal":false,"key":key,"point":_origin+Vector3(key.x*CELL,0.0,key.y*CELL)})

func _finish(point: Vector3, rejoin_index: int) -> void:
	var reverse: Array[Vector3]=[point];var index:=_active
	while index>=0:
		reverse.append(_nodes[index].point);index=int(_nodes[index].parent)
	_result.clear()
	for p in range(reverse.size()-1,-1,-1):
		if _result.is_empty() or _result[-1].distance_to(reverse[p])>.02: _result.append(reverse[p])
	_rejoin=rejoin_index;_status="FOUND";_reason=""

func cancel() -> void:
	if _status in ["SEARCHING","FOUND"]: _status="CANCELLED"
	_result.clear()

func snapshot() -> Dictionary:
	return {"status":_status,"reason":_reason,"points":_result.duplicate(),"rejoin_index":_rejoin,"nodes":_nodes.size(),"native_checks":_checks,"frames":_frames,"max_step_us":_max_step_us,"actor_transform_written":false,"movement_authority":false}

func _fail(reason: String) -> Dictionary:
	_status="BLOCKED";_reason=reason;_result.clear()
	return {"ok":false,"status":_status,"reason":reason}
