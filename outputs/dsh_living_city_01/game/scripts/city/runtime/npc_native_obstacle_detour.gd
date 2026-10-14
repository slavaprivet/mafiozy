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

# DSH_DETOURBUDGET: every lever defaults to the value above, so a run without the
# matching argument is byte-for-byte the previous behaviour. The constants stay the
# source of truth; these only add a bounded override plus one telemetry line so
# "bounded_native_detour_exhausted" can be attributed instead of guessed at.
const CELL_MIN_M := 0.5
const CELL_MAX_M := 5.0
const RANGE_MIN_M := 4.0
const RANGE_MAX_M := 40.0
const NODES_MAX_CAP := 4096
const CHECKS_MAX_CAP := 16384
const FRAMES_MAX_CAP := 4096
static var _dsh_cell := -1.0
static var _dsh_range := -1.0
static var _dsh_nodes := -1
static var _dsh_checks := -1
static var _dsh_frames := -1
static var _dsh_flag := -1
static var _s_ok := 0
static var _s_exhausted := 0
static var _s_other := 0
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
var _began_us := 0
var _checks_at_end := 0
var _nodes_at_end := 0
var _frames_at_end := 0
var _exhausted := false
var _exit_reason := ""
var _verdict := ""
# DSH_DETOURNEIGH: why does the first expansion of the start cell produce no child?
# One counter per rejection class plus a global per-reason tally. Observation only.
var _cells := 0
var _cand_total := 0
var _rejected := {}
var _first_seen := false
var _emit_neigh := false
var _neighbors_total := 0
var _open_after_first := -1
var _start_cell := Vector2i.ZERO
var _goal_dist := -1.0
var _last_policy_reason := ""
static var _s_rejected := {}
static var _s_rejected_searches := 0

# DSH_DETOURBUDGET: argument parsing and the bounded overrides. Shape follows the
# existing levers of this project (cache once, one prefix scan, clamp the value).
static func _dsh_arg_int(prefix: String, fallback: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return int(argument.trim_prefix(prefix))
	return fallback

static func _dsh_arg_float(prefix: String, fallback: float) -> float:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return float(argument.trim_prefix(prefix))
	return fallback

static func _dsh_resolve() -> void:
	if _dsh_flag >= 0: return
	_dsh_flag = 1 if OS.get_cmdline_user_args().has("--city-detour-budget=1") else 0
	_dsh_cell = clampf(_dsh_arg_float("--city-detour-cell-m=", CELL), CELL_MIN_M, CELL_MAX_M)
	_dsh_range = clampf(_dsh_arg_float("--city-detour-range-m=", RANGE), RANGE_MIN_M, RANGE_MAX_M)
	_dsh_nodes = clampi(_dsh_arg_int("--city-detour-max-nodes=", MAX_NODES), 8, NODES_MAX_CAP)
	# "--city-detour-attempts" is the user-facing alias of the query budget.
	_dsh_checks = clampi(_dsh_arg_int("--city-detour-max-checks=", _dsh_arg_int("--city-detour-attempts=", MAX_CHECKS)), 8, CHECKS_MAX_CAP)
	_dsh_frames = clampi(_dsh_arg_int("--city-detour-max-frames=", MAX_FRAMES), 8, FRAMES_MAX_CAP)

static func budget() -> Dictionary:
	_dsh_resolve()
	return {"on": _dsh_flag == 1, "cell_m": _dsh_cell, "range_m": _dsh_range,
		"max_nodes": _dsh_nodes, "max_checks": _dsh_checks, "max_frames": _dsh_frames}

static func counters() -> Dictionary:
	return {"searches_ok": _s_ok, "searches_exhausted": _s_exhausted, "searches_other_stop": _s_other,
		"searches_with_neighbour_line": _s_rejected_searches,
		"neighbour_rejections": _s_rejected.duplicate(),
		"neighbour_rejections_text": _dsh_join(_s_rejected)}

# DSH_DETOURNEIGH: compact "reason:count,..." rendering, counted both for the current
# search and globally, so a broken first expansion is visible in one line.
static func _dsh_tally(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1

static func _dsh_join(counters: Dictionary) -> String:
	var parts: Array[String] = []
	for key: Variant in counters.keys():
		parts.append(str(key) + ":" + str(counters[key]))
	parts.sort()
	return ",".join(parts) if not parts.is_empty() else "-"

## One line per ended search, and a summary every 32 of them. Read-only observation:
## the search has already written its own status/reason by the time this runs.
static func _dsh_emit(snapshot: Dictionary, budget_now: Dictionary, frame: int) -> void:
	if budget_now["on"] != true: return
	print("DSH_DETOUR status=", snapshot.get("status", "?"),
		" reason=", snapshot.get("reason", ""),
		" attempts=", snapshot.get("native_checks", 0), "/", budget_now["max_checks"],
		" nodes=", snapshot.get("nodes", 0), "/", budget_now["max_nodes"],
		" frames=", snapshot.get("frames", 0), "/", budget_now["max_frames"],
		" cell_m=", budget_now["cell_m"], " range_m=", budget_now["range_m"],
		" failing=", snapshot.get("failing", ""),
		" ok=", _s_ok, " exhausted=", _s_exhausted, " other=", _s_other,
		" frame=", frame)

## DSH_DETOURNEIGH: the first expansion of the start cell, in one line. If the search
## dies with nodes=1, this says exactly which check rejected every neighbour, and the
## policy-state fields say whether the refusal came from the gate or from the geometry.
static func _dsh_emit_neigh(snapshot: Dictionary, rejected: Dictionary, start_cell: Vector2i,
		neighbors_total: int, open_after_first: int, goal_dist: float, checks: int, frame: int,
		policy_state: String) -> void:
	print("DSH_DETOUR_NEIGH start_cell=(", start_cell.x, ",", start_cell.y, ")",
		" neighbors_total=", neighbors_total,
		" neighbors_rejected_by=", _dsh_join(rejected),
		" open_after_first=", open_after_first,
		" goal_distance_m=", "%.3f" % goal_dist,
		" native_checks=", checks,
		" nodes=", snapshot.get("nodes", 0),
		" frames=", snapshot.get("frames", 0),
		" status=", snapshot.get("status", "?"),
		" reason=", snapshot.get("reason", ""),
		" policy_state=", policy_state,
		" frame=", frame)

func begin(host: RefCounted, policy: RefCounted, activity_owner: RefCounted, token: Dictionary, map: RID, iteration: int, route: PackedVector3Array, first_index: int) -> Dictionary:
	if _status!="UNBOUND" or not is_instance_valid(host) or not is_instance_valid(policy) or not is_instance_valid(activity_owner) or first_index<0 or first_index>=route.size(): return {"ok":false,"reason":"detour_arguments"}
	for method: String in ["native_clear_segment","_ordinary_navigation"]:
		if not policy.has_method(method): return {"ok":false,"reason":"native_detour_policy_required"}
	if not host.has_method("_local_walker_current") or not host._local_walker_current(token): return {"ok":false,"reason":"current_original_walker_required"}
	_host=host;_policy=policy;_owner=weakref(activity_owner);_token=token.duplicate();_map=map;_iteration=iteration
	_navigation=policy._ordinary_navigation(host)
	_claim_serial=int(host.daily_activity_status(token.source_id).get("serial",-1))
	_origin=token.body.global_position
	_began_us=Time.get_ticks_usec()
	if not _current(): return _fail("detour_current_idle_actor_required")
	# Rejoin only a short prefix of the still-desired path. A blocked next goal
	# may be inside the car; later real goals let us get around its far end.
	var rejoin_range:=_range()
	for index in range(first_index,mini(route.size(),first_index+4)):
		var point: Vector3=route[index]
		if not point.is_finite() or Vector2(point.x-_origin.x,point.z-_origin.z).length()>rejoin_range+.01: continue
		var projected:=NavigationServer3D.map_get_closest_point(_map,point)
		if projected.distance_to(point)>.12: continue
		_goals.append({"point":projected,"index":index})
	if _goals.is_empty(): return _fail("no_bounded_native_rejoin_goal")
	_nodes.append({"point":_origin,"key":Vector2i.ZERO,"g":0.0,"parent":-1,"closed":false})
	_by_key[Vector2i.ZERO]=0;_open.append(0);_status="SEARCHING"
	return {"ok":true,"status":_status,"movement_owner":"existing_daily_host"}

## DSH_DETOURBUDGET: resolved budget of this search. All three fall back to the
## constants above when the matching argument is absent.
func _cell() -> float:
	_dsh_resolve(); return _dsh_cell

func _range() -> float:
	_dsh_resolve(); return _dsh_range

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
	if not _current(): _fail("detour_actor_claim_request_or_map_changed");return _dsh_report(frame)
	if _frames>_dsh_frames: _fail("detour_frame_budget");return _dsh_report(frame)
	var began:=Time.get_ticks_usec();var count:=0
	while count<CHECKS_PER_FRAME and Time.get_ticks_usec()-began<USEC_PER_FRAME:
		if _checks>=_dsh_checks: _fail("detour_query_budget");break
		if _active<0:
			_active=_pop_best()
			if _active<0:
				_exhausted=true
				_fail("bounded_native_detour_exhausted");break
			_prepare_candidates()
		if _cursor>=_candidates.size(): _active=-1;continue
		var candidate: Dictionary=_candidates[_cursor];_cursor+=1
		var start: Vector3=_nodes[_active].point
		var point: Vector3=candidate.point
		if Vector2(point.x-_origin.x,point.z-_origin.z).length()>_range()+.01:
			_cells+=1;_dsh_tally(_rejected,"outside_range");continue
		if point.distance_to(start)>5.0:
			_cells+=1;_dsh_tally(_rejected,"step_too_long");continue
		if not candidate.get("goal",false) and _by_key.has(candidate.key) and _nodes[_by_key[candidate.key]].closed:
			_cells+=1;_dsh_tally(_rejected,"cell_already_closed");continue
		var projected:=NavigationServer3D.map_get_closest_point(_map,point)
		if projected.distance_to(point)>.12:
			_cells+=1;_dsh_tally(_rejected,"off_native_map");continue
		_checks+=1;count+=1;_cand_total+=1
		if not _policy.native_clear_segment(_token,start,projected):
			# DSH_DETOURNEIGH: the policy already stores its refusal reason; read it so
			# a broken first expansion names the exact conjunct that refused.
			_last_policy_reason=str(_policy.get("_last_reason"))
			_dsh_tally(_rejected,"native_clear_refused")
			_dsh_tally(_rejected,"policy:"+_last_policy_reason)
			continue
		if not _current(): _fail("detour_owner_changed_during_native_probe");break
		if candidate.get("goal",false):
			_finish(projected,int(candidate.index));break
		var cost: float=float(_nodes[_active].g)+start.distance_to(projected)
		if _by_key.has(candidate.key):
			var known: int=_by_key[candidate.key]
			if cost<float(_nodes[known].g): _nodes[known].g=cost;_nodes[known].parent=_active
		else:
			if _nodes.size()>=_dsh_nodes: _fail("detour_node_budget");break
			var next:=_nodes.size()
			_by_key[candidate.key]=next
			_nodes.append({"point":projected,"key":candidate.key,"g":cost,"parent":_active,"closed":false});_open.append(next)
	_max_step_us=maxi(_max_step_us,Time.get_ticks_usec()-began)
	return _dsh_report(frame)

## DSH_DETOURBUDGET: the single exit of one search attempt. It records the state of
## the search at the moment the verdict was reached and prints exactly one line per
## attempt when --city-detour-budget=1 is passed. With the flag absent this is one
## integer compare and the original snapshot().
func _dsh_report(frame: int) -> Dictionary:
	var result:=snapshot()
	if _dsh_flag != 1: return result
	_exit_reason=_reason
	if _status=="FOUND": _s_ok+=1
	elif _exhausted: _s_exhausted+=1
	else: _s_other+=1
	_checks_at_end=_checks
	_nodes_at_end=_nodes.size()
	_frames_at_end=_frames
	_open_after_first=_open.size()
	# Fold this search's rejection classes into the run-wide tally.
	_s_rejected_searches+=1
	for key: Variant in _rejected.keys():
		_s_rejected[str(key)]=int(_s_rejected.get(str(key),0))+int(_rejected[key])
	if _verdict == _reason and _status == "SEARCHING": return result
	_verdict=_reason
	var failing := "%s|%d|%d|%d" % [_exit_reason, _checks_at_end, _nodes_at_end, _frames_at_end]
	if _emit_neigh:
		_emit_neigh=false
		var policy_state := _policy_state_text()
		_dsh_emit_neigh(result, _rejected, _start_cell, _neighbors_total, _open_after_first,
			_goal_dist if _goal_dist>=0.0 else -1.0, _checks_at_end, frame, policy_state)
		_dsh_tally(_s_rejected,"searches")
	_dsh_emit({"status": _status, "reason": _reason, "native_checks": _checks_at_end,
		"nodes": _nodes_at_end, "frames": _frames_at_end, "failing": failing}, budget(), frame)
	return result

## DSH_DETOURNEIGH: is the policy gate open right now? `native_clear_segment` refuses
## everything when the policy is busy or the token is no longer current, and that refusal
## is identical to a geometric one from the caller's point of view. Read-only.
func _policy_state_text() -> String:
	if not is_instance_valid(_policy): return "policy_invalid"
	var parts: Array[String] = []
	parts.append("busy=" + str(bool(_policy.get("_busy"))))
	if _policy.has_method("_token_current"):
		parts.append("token_current=" + str(bool(_policy._token_current(_token))))
	parts.append("last_reason=" + str(_policy.get("_last_reason")))
	return "|".join(parts)

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
		_candidates.append({"goal":false,"key":key,"point":_origin+Vector3(key.x*_cell(),0.0,key.y*_cell())})
	if not _first_seen:
		_first_seen=true
		_start_cell=Vector2i.ZERO
		_goal_dist=INF
		for goal: Dictionary in _goals: _goal_dist=minf(_goal_dist,_origin.distance_to(goal.point))
		_neighbors_total=_candidates.size()
		_emit_neigh=true

func _finish(point: Vector3, rejoin_index: int) -> void:
	var reverse: Array[Vector3]=[point];var index:=_active
	while index>=0:
		reverse.append(_nodes[index].point);index=int(_nodes[index].parent)
	_result.clear()
	for p in range(reverse.size()-1,-1,-1):
		if _result.is_empty() or _result[-1].distance_to(reverse[p])>.02: _result.append(reverse[p])
	_rejoin=rejoin_index;_status="FOUND";_reason="";_exhausted=false;_verdict=""

func cancel() -> void:
	if _status in ["SEARCHING","FOUND"]: _status="CANCELLED"
	_result.clear()

func snapshot() -> Dictionary:
	return {"status":_status,"reason":_reason,"points":_result.duplicate(),"rejoin_index":_rejoin,"nodes":_nodes.size(),"native_checks":_checks,"frames":_frames,"max_step_us":_max_step_us,"actor_transform_written":false,"movement_authority":false}

func _fail(reason: String) -> Dictionary:
	_status="BLOCKED";_reason=reason;_result.clear();_verdict=""
	return {"ok":false,"status":_status,"reason":reason}
