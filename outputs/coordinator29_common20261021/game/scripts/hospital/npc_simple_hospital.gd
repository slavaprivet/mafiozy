extends RefCounted
## Private52: generic physical route drive. No raw position assignment or collider edits.
const Avoidance29 = preload("res://scripts/navigation/npc_avoidance_world29.gd")
const PreparedRoutes = preload("res://scripts/navigation/prepared_routes58.gd")
const Route = preload("res://scripts/hospital/npc_physical_route51.gd")
const LongRoute = preload("res://scripts/hospital/npc_long_route28.gd")
const RoamWait = preload("res://scripts/hospital/npc_roam_wait29.gd")
const DoorClearance31 = preload("res://scripts/hospital/npc_door_clearance31.gd")
const Swing = preload("res://scripts/city/runtime/npc_city_clone_door_swing.gd")
const FLAG := "--city-simple-hospital="
const TARGET_FLAG := "--city-simple-hospital-target="
const SPEED_MPS := 1.8
const ARRIVE_M := .30
## One no-progress episode across inner replans; queue/attention hold is not motion.
const SERVICE_PLAN_US30 := 500000
const SERVICE_LOCAL_WAIT_MS30 := 15000.0
const SERVICE_MOTION_MS30 := 4000.0
const SERVICE_PROGRESS_M30 := .25
static var _flag := -1
var _arrival_m56 := ARRIVE_M
var _id := ""
var _target := Vector3.ZERO
var _target_source := ""
var _roam_watch29: RefCounted
var _roam_service29_us := 0
var _roam_step29_phase := "planning"
var _roam_watch29_state: Dictionary = {}
var _service_watch30: Dictionary = {}
var _service_anchor30 := Vector3.ZERO
var _service_last_us30 := 0
# Attempted movement must get closer to its current waypoint. Sideways loops
# around a changed door must not reset progress merely by travelling .25m.
var _service_ready_frame56 := -1
var _service_way56 := -1
var _service_best_distance56 := INF
var _service_way_idle_s56 := 0.0
var _body: CharacterBody3D
var _avoidance29: RefCounted
var _avoidance29_state: Dictionary = {}
var _route: RefCounted
var _guide: RefCounted
var _guide_map := RID()
var _guide_revision := -1
var _active := false
var _attention_paused29 := false
var _attention_ready29 := false
var _attention_position29 := Vector3.ZERO
var _attention_map29 := RID()
var _attention_iteration29 := -1
var _phase := "idle"
var _attempts := 0
var _moved_m := 0.0
var _last_reason := ""
var _frame := -1
var _way := 0
var _stall_s := 0.0
var _replan_s := 0.0
var _door_owner: Node
var _door := Vector3.ZERO
var _door_valid := false
var _inside_normal := Vector3.ZERO
var _room := Vector3.ZERO
var _outside := Vector3.ZERO
var _hospital_frame := false
var _legs: Array[Vector3] = []
var _leg := 0
var _print_ms := -1000
var _event := "idle"
var _door_retry_ms := 0
var _door_reason := ""
var _door_clear31: RefCounted
# DSH_GOALSUPPORT58: the result of resolving this goal to a supported standing point.
var _last_goal_support58: Dictionary = {}
# DSH_ROUTES58: how the prepared graph was used by this driver, so a run can name the
# prepared stretches and the exact reason a fallback happened.
var _prepared58_used := 0
var _prepared58_reason := ""
var _prepared58_length_m := 0.0
var _prepared58_plan_ok := false
var _prepared58_plan_points := 0
# The prepared arc being walked: one waypoint list, one owner, one stall clock.
var _prepared58_points: Array[Vector3] = []
var _prepared58_way := 0
var _prepared58_stall := 0.0

static func enabled() -> bool:  # DSH_SIMPLEHOSP
	if _flag < 0:
		_flag = 0
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with(FLAG): _flag = 1 if int(argument.trim_prefix(FLAG)) != 0 else 0
	return _flag == 1


static func _arg(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""


static func parse_vector(text: String) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 3: return null
	var values := PackedFloat64Array()
	for part: String in parts:
		if not part.strip_edges().is_valid_float(): return null
		var number := part.strip_edges().to_float()
		if not is_finite(number): return null
		values.append(number)
	return Vector3(values[0], values[1], values[2])


## A supported interior point measured from the copy's real closed doorway.
## The native actor capsule is checked when supplied; no marker grants admission.
## `--city-simple-hospital-target=x,y,z` overrides it for a manual check.
static func target_of(scene: Node3D, actor: CharacterBody3D = null) -> Dictionary:
	var explicit: Variant = parse_vector(_arg(TARGET_FLAG))
	if explicit is Vector3: return {"ok":true,"point":explicit,"source":"flag"}
	if not is_instance_valid(scene): return {"ok":false,"reason":"no_scene"}
	var info: Dictionary = _door_info(scene)
	if info.is_empty(): return {"ok":false,"reason":"closed_door_frame_unresolved"}
	return _interior_floor(scene, info, actor)



static func disable_standing_hospital(scene: Node3D, site: Node3D, source_id: String) -> Dictionary:  # DSH_SIMPLEHOSP
	var hidden := 0
	if is_instance_valid(site) and site is Node3D:
		(site as Node3D).visible = false
		hidden += 1
	if is_instance_valid(scene):
		for node: Node in scene.get_children():
			if str(node.get_meta("source_id", "")) != source_id: continue
			if node is Node3D:
				(node as Node3D).visible = false
				hidden += 1
	print("DSH_SIMPLEHOSP standing_hospital=disabled source_id=", source_id, " hidden_nodes=", hidden,
		" geometry_kept=true reason=city_bootstrap_requires_the_real_site")
	return {"ok":hidden > 0, "hidden": hidden}


static func _clone_in(scene: Node3D) -> Node3D:
	if not is_instance_valid(scene):return null
	for node: Node in scene.get_children():
		if not node is Node3D or node.get_meta("dsh_town_extra",false)!=true:continue
		var sign_node: Node=node.get_node_or_null("TownCloneSign")
		if sign_node is Label3D and str(sign_node.text).to_upper().contains("БОЛЬНИЦ"):return node
	return null

static func _door_info(scene: Node3D) -> Dictionary:
	var clone: Node3D=_clone_in(scene)
	if clone==null:return {}
	var measured: Dictionary=_clone_bounds(clone)
	if not measured.ok:return {}
	var box: AABB=measured.box
	for owner: Variant in Swing.doors():
		if not is_instance_valid(owner) or owner.get("clone_node")!=clone:continue
		var leaf: Variant=owner.get("leaf")
		var closed: Variant=owner.get("leaf_closed")
		var anchor: Variant=owner.get("anchor")
		if not leaf is Node3D or not is_instance_valid(leaf) or not closed is Transform3D or not anchor is Vector3:continue
		var parent: Node3D=leaf.get_parent_node_3d()
		if parent==null:continue
		# Never infer a doorway plane from a rotating leaf or from the room marker.
		var normal: Vector3=parent.global_basis*(closed as Transform3D).basis.z
		normal.y=0.0
		if normal.length_squared()<.0001:continue
		normal=normal.normalized()
		var side: float=(box.get_center()-(anchor as Vector3)).dot(normal)
		if absf(side)<.25:side=(clone.global_position-(anchor as Vector3)).dot(normal)
		if absf(side)<.25:continue
		if side<0.0:normal=-normal
		return {"point":anchor,"owner":owner,"normal":normal,"bounds":box}
	# A free-entry stub cannot establish a stable CLOSED inpatient doorway frame.
	return {}

static func _clone_bounds(clone: Node3D) -> Dictionary:
	var stack: Array[Node]=[clone]
	var box:=AABB()
	var found:=false
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is MeshInstance3D and node.mesh!=null:
			var part: AABB=node.global_transform*node.get_aabb()
			box=box.merge(part) if found else part
			found=true
		for child: Node in node.get_children():stack.append(child)
	return {"ok":found,"box":box}

static func _interior_floor(scene: Node3D, info: Dictionary, actor: CharacterBody3D = null) -> Dictionary:
	var anchor: Vector3=info.point
	var normal: Vector3=info.normal
	var tangent: Vector3=Vector3.UP.cross(normal)
	var box: AABB=info.bounds
	var physical: RefCounted=null
	var exclude: Array[RID]=[]
	var mask: int=1
	if is_instance_valid(actor):
		physical=Route.new()
		if not physical.configure(actor):return {"ok":false,"reason":"actor_capsule_missing"}
		exclude.append(actor.get_rid());mask=actor.collision_mask
	# Bounded candidates within the measured copy envelope, beyond its actual door.
	# Every point needs native support. With an actor, its own full capsule must fit.
	for depth: float in [2.2,2.8,1.7,3.4]:
		for offset: float in [0.0,.5,-.5]:
			var candidate: Vector3=anchor+normal*depth+tangent*offset
			if candidate.x<box.position.x+.4 or candidate.x>box.end.x-.4 or candidate.z<box.position.z+.4 or candidate.z>box.end.z-.4:continue
			var query:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*.65,candidate-Vector3.UP*.65,mask,exclude)
			var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP)<.7:continue
			var floor_point: Vector3=hit.position+Vector3.UP*.003
			if absf(floor_point.y-anchor.y)>.5:continue
			if physical!=null and not physical.standing(floor_point):continue
			return {"ok":true,"point":floor_point,"source":"measured_interior"}
	return {"ok":false,"reason":"no_supported_interior_capsule" if physical!=null else "no_supported_interior_floor"}

static func door_of(scene: Node3D) -> Variant:
	var info: Dictionary=_door_info(scene)
	return info.get("point")

func _scene_of_body() -> Node3D:
	return _body.get_tree().current_scene as Node3D if is_instance_valid(_body) and _body.is_inside_tree() else null

func begin(goal: Vector3, body: CharacterBody3D, map: RID, id: String, source: String) -> bool:
	if _door_clear31!=null:_door_clear31.cancel()
	_door_clear31=DoorClearance31.new() if source=="roam" else null
	if not goal.is_finite() or not is_instance_valid(body) or not body.is_inside_tree():return false
	_active=false;_attention_paused29=false;_attention_ready29=false
	if _guide!=null:_guide.cancel()
	_body=body;_id=id;_target=goal;_target_source=source;_guide_map=map
	_arrival_m56=ARRIVE_M
	_roam_watch29=null;_roam_service29_us=0;_roam_watch29_state.clear()
	_service_watch30.clear();_service_last_us30=0;_service_anchor30=body.global_position
	if source=="service_approach":
		_service_watch30={"blocked":false,"reason":"","planning_service_us":0,"local_wait_ms":0.0,"motion_idle_ms":0.0,"total_service_us":0,"progress_resets":0}
	if source=="roam":
		_roam_watch29=RoamWait.new();_roam_watch29.begin(Time.get_ticks_msec())
	if _route!=null:_route.cancel()
	_route=Route.new()
	if not _route.configure(body):return false
	_active=false;_phase="searching";_attempts=0;_moved_m=0.0;_last_reason=""
	_frame=-1;_way=0;_stall_s=0;_replan_s=0;_legs.clear();_leg=0
	_door_retry_ms=0;_door_reason=""
	var scene: Node3D=_scene_of_body()
	# steer returns the core-owned output Dictionary: never clear that shared value.
	_avoidance29=Avoidance29.for_scene(scene);_avoidance29_state={}
	var medical: bool=source not in ["hospital_exit","roam","service_approach"]
	if medical:
		_room=goal;_hospital_frame=false;_door_valid=false
		var info: Dictionary=_door_info(scene)
		if info.is_empty():return _refuse("closed_door_frame_unresolved")
		_door=info.point;_door_owner=info.owner;_inside_normal=info.normal;_door_valid=true
		if (_room-_door).dot(_inside_normal)<=.8:return _refuse("room_outside_door_plane")
		var support: Variant=_route.floor_at(_room,_room.y)
		if not support is Vector3 or absf(support.y-_room.y)>.12 or not _route.standing(support):return _refuse("room_floor_or_capsule_invalid")
		_room=support;_target=support
		_outside=_door-_inside_normal*1.65;_outside.y=_room.y
		_hospital_frame=true
		if (_body.global_position-_door).dot(_inside_normal)<.55 or _flat(_body.global_position,_room)>4.0 or absf(_body.global_position.y-_room.y)>.12:
			_legs.append(_outside)
			_legs.append(Vector3(_door.x,_room.y,_door.z)+_inside_normal*.85)
	elif source in ["roam","service_approach"]:
		_hospital_frame=false;_door_valid=false;_door_owner=null
		# DSH_GOALSUPPORT58: a stroll, errand or bench goal is only a place to STAND.
		# Measured defect: resident_5 was 0.73 m from its own roam goal, the planner
		# rejected that goal as standing_blocked and searched 720 nodes / 5.9 k queries
		# for 7 s while the resident stood still. The goal is therefore resolved to a
		# supported standing point BEFORE any search, with a bounded probe budget. A
		# goal that has no standing point nearby is refused here, in microseconds, and
		# the caller is free to choose another place instead of paying for a dead search.
		var resolved: Variant=_resolve_supported_goal(goal,_target_source)
		if not resolved is Vector3:return _refuse("goal_has_no_supported_standing_point")
		_target=resolved
	if source=="hospital_exit":
		if not _hospital_frame:return _refuse("exit_interior_frame_missing")
		_legs.append(Vector3(_door.x,_room.y,_door.z)+_inside_normal*.85)
		_legs.append(_outside)
	if _legs.is_empty() or _flat(_legs[-1],_target)>.01:_legs.append(_target)
	# DSH_ROUTES58: the long way is the PREPARED pedestrian graph, not a fresh search. This
	# runs for ordinary walks (roam / service approach) before the guided leg would start a
	# local search. If the graph has no prepared line, or a point on it is no longer
	# walkable, this refuses and the ordinary physical planner keeps its exact old role.
	if source in ["roam", "service_approach"]:
		# DSH_ROUTES58: one line per ordinary goal, naming whether the prepared network was
		# asked at all and what it answered. This is the only honest way to tell "the graph
		# carried this walk" apart from "the graph was never in the way".
		print("NPC_GRAPH58 id=", _id, " source=", source, " allowed=", _prepared58_allowed(),
			" on=", prepared58_on(), " loaded=", PreparedRoutes.loaded(), " reason=", PreparedRoutes.reason())
		if _prepared58_allowed() and _begin_prepared58():
			_active=true
			_emit("begin")
			return true
	_active=true
	if not _begin_guided_leg():return _refuse("guide:"+_guide.reason)
	_emit("begin")
	return true

## DSH_ROUTES58: --city-prepared-routes58 (default on) uses the prepared graph for the
## long stretches. --city-prepared-routes58=0 keeps the shipped physical search only.
static var _prepared58_flag := -1
static func prepared58_on() -> bool:
	if _prepared58_flag < 0:
		_prepared58_flag = 1
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-prepared-routes58="):
				_prepared58_flag = 1 if int(argument.trim_prefix("--city-prepared-routes58=")) > 0 else 0
	return _prepared58_flag == 1

func _prepared58_allowed() -> bool:
	# The guide object is created only when a guided leg starts, so it must not be required
	# here: the prepared arc replaces that leg entirely and never needs the guide to exist.
	return prepared58_on() and _route != null and PreparedRoutes.loaded()

## Walk the prepared line, checking every step against the live floor and capsule. The many
## points of the graph line are thinned to waypoints the physical loop can follow, and the
## last approach stays with the same floor/edge/arrival checks as any other leg.
func _begin_prepared58() -> bool:
	var plan: Dictionary = PreparedRoutes.route_between(_body.global_position, _target, 120.0)
	# DSH_ROUTES58: the loop-level truth. `source=plan_no_route` means the graph was asked and
	# answered; an empty source with waypoints<=1 means this function never got to answer.
	_prepared58_plan_ok = bool(plan.get("ok", false))
	_prepared58_plan_points = (plan.get("points", PackedVector3Array()) as PackedVector3Array).size()
	if not _prepared58_plan_ok:
		_prepared58_reason = "plan_" + str(plan.get("reason", "unavailable"))
		# DSH_ROUTES58: a refused plan must name its reason in the run log, not only in memory.
		print("NPC_GRAPH58 id=", _id, " refused=", _prepared58_reason,
			" from=(%.1f,%.1f,%.1f)" % [_body.global_position.x, _body.global_position.y, _body.global_position.z],
			" to=(%.1f,%.1f,%.1f)" % [_target.x, _target.y, _target.z], " frame=", Engine.get_physics_frames())
		return false
	var points: PackedVector3Array = plan.points
	var accepted: Array[Vector3] = []
	var previous: Vector3 = _body.global_position
	var refused_at := -1
	var refused_reason := ""
	for point: Vector3 in points:
		if accepted.is_empty() and previous.distance_to(point) <= .05: continue
		# Changed obstacle check: the line was proved when the graph was built; this proves
		# it still holds NOW for the real capsule, at the same spacing the builder used.
		if not _prepared58_segment_clear(previous, point):
			refused_at = accepted.size()
			refused_reason = _prepared58_reason
			break
		accepted.append(point)
		previous = point
	if refused_at >= 0:
		# DSH_ROUTES58: one refused segment does not throw the whole graph away. The prefix
		# that IS clear is walked on the graph, and the remaining metres stay with the
		# physical planner, which is exactly the check a changed obstacle needs.
		_prepared58_reason = "prefix_%d_of_%d_%s" % [refused_at, points.size(), refused_reason]
	if accepted.size() < 2:
		_prepared58_reason = "graph_line_degenerate" if refused_at < 0 else _prepared58_reason
		return false
	if accepted[-1].distance_to(_target) > .05: accepted.append(_target)
	# The prepared arc is walked by _prepared58_step; the local planner keeps its old role for
	# anything the arc cannot cover, and nothing here starts a search for this route.
	_guide.cancel()
	_route.cancel()
	_prepared58_points = accepted
	_prepared58_way = 0
	_prepared58_stall = 0.0
	_route.route = accepted
	_route.status = "ready"
	_route._ready_frame = Engine.get_physics_frames()
	_way = 0
	_phase = "walking_prepared58"
	_prepared58_used += 1
	_prepared58_length_m = float(plan.get("length_m", 0.0))
	if refused_at < 0: _prepared58_reason = "prepared"
	_emit("prepared_route")
	return true

func _prepared58_segment_clear(a: Vector3, b: Vector3) -> bool:
	var length: float = a.distance_to(b)
	var count: int = maxi(1, ceili(length / 1.5))
	var previous_y: float = a.y
	for index: int in range(0, count + 1):
		var along: float = float(index) / float(count) * length
		var at: Vector3 = a.lerp(b, float(index) / float(count))
		var direction: Vector3 = (b - a); direction.y = 0.0
		direction = direction.normalized() if direction.length() > .001 else Vector3.ZERO
		# DSH_ROUTES58: a single missed ray is not proof of a hole. Measured: one sample on a
		# proven graph line fell between two floor colliders and refused the whole walk. The
		# support is therefore confirmed by a small cross-section, and a real gap - where the
		# body would fall - still refuses, because none of the samples finds a floor.
		var ground: Variant = _prepared58_ground(at, direction, previous_y)
		if not ground is Vector3:
			_prepared58_reason = "graph_line_no_floor_m%.1f" % along
			return false
		var ground_y: float = Vector3(ground).y
		if absf(ground_y - previous_y) > .45:
			_prepared58_reason = "graph_line_step_m%.1f" % along
			return false
		previous_y = ground_y
		if not _route.standing(Vector3(at.x, ground_y + .003, at.z)):
			_prepared58_reason = "graph_line_blocked_m%.1f_at_(%.1f,%.1f,%.1f)" % [along, at.x, at.y, at.z]
			return false
	return true

## The floor under a sample, confirmed across a short cross-section of the walking line.
func _prepared58_ground(at: Vector3, direction: Vector3, reference_y: float) -> Variant:
	var offsets: Array = [0.0, .35, -.35]
	var found: Array[Vector3] = []
	for offset: float in offsets:
		var probe: Vector3 = at + direction * offset
		var hit: Variant = _route.floor_at(probe, reference_y)
		if hit is Vector3 and Vector3(hit).is_finite(): found.append(Vector3(hit))
	if found.size() < 2: return null
	var lowest: Vector3 = found[0]
	for row: Vector3 in found:
		if row.y < lowest.y: lowest = row
	return lowest

## DSH_GOALSUPPORT58: resolve one walking goal to a point where this exact body can
## actually stand. The goal itself is tried first, so an already valid goal keeps its
## exact coordinates and this changes nothing for a healthy goal. Only when the goal
## is unsupported is a bounded ring of nearby points probed (three radii, eight
## directions, both the fine step and the direct corridor). Returns null when there is
## no supported standing point within GOAL_SUPPORT_R_M - the caller must then choose
## another place rather than pay for a search that cannot succeed.
const GOAL_SUPPORT_R_M := 1.6
const GOAL_SUPPORT_RINGS := [.4, .9, 1.6]
const GOAL_SUPPORT_DIRECTIONS := 8
func _resolve_supported_goal(goal: Vector3, source: String) -> Variant:
	if _route==null or not goal.is_finite():return null
	if _supported_goal_point(goal,goal,source):return goal
	for radius: float in GOAL_SUPPORT_RINGS:
		var step: float=TAU/float(GOAL_SUPPORT_DIRECTIONS)
		for index: int in GOAL_SUPPORT_DIRECTIONS:
			var angle: float=float(index)*step
			var candidate: Vector3=Vector3(goal.x+cos(angle)*radius,goal.y,goal.z+sin(angle)*radius)
			if not _supported_goal_point(candidate,goal,source):continue
			_last_goal_support58={"resolved":true,"radius_m":radius,"from":goal,"to":candidate}
			return candidate
	_last_goal_support58={"resolved":false,"radius_m":GOAL_SUPPORT_R_M,"from":goal,"to":goal,
		"reason":str(_route._last_query_failure),"queries":int(_route.queries)}
	return null

func _supported_goal_point(at: Vector3, goal: Vector3, source: String) -> bool:
	var floor: Variant=_route.floor_at(at,goal.y)
	if not floor is Vector3 or absf(floor.y-goal.y)>=.5:return false
	if not _route.standing(floor):return false
	# A point the body cannot walk to is not a reachable goal either. The direct
	# corridor is the same admission the planner uses, so an accepted point here
	# cannot be rejected later as an unreachable first connector.
	if _flat(_body.global_position,floor)<=.35:return true
	return _route.sweep(_body.global_position,floor)

## A door staging leg needs an actual supported stop inside its request radius.
## The ordinary .30m completion tolerance remains the default for every other leg.
func set_service_arrival56(distance: float) -> bool:
	if _target_source != "service_approach" or not is_finite(distance) or distance < .025 or distance > ARRIVE_M: return false
	_arrival_m56 = distance
	return true

## The guide is topology only. Each checkpoint still needs the unchanged live
## capsule planner, water checks and native movement before advance() is called.
func _begin_guided_leg() -> bool:
	if _route!=null:_route.cancel()
	if _guide!=null:_guide.cancel()
	_guide=LongRoute.new();_guide_revision=-1
	var local_domain: float=LongRoute.SERVICE_LOCAL_M if _target_source=="service_approach" else LongRoute.LOCAL_ONLY_M
	return _guide.begin(_body,_guide_map,_legs[_leg],local_domain,_route if _target_source=="service_approach" else null)

func _sync_guide() -> String:
	if _guide==null:return "blocked"
	var state: String=_guide.tick()
	if state=="ready" and _guide_revision!=int(_guide.revision):
		var checkpoint: Variant=_guide.waypoint()
		if not checkpoint is Vector3:return "blocked"
		_guide_revision=int(_guide.revision)
		_route.begin(checkpoint);_way=0;_stall_s=0;_replan_s=0;_phase="searching"
	elif state=="searching":_phase="searching_guide"
	return state

func _guide_blocked(before: Vector3, delta: float) -> String:
	_active=false;_phase="blocked"
	_last_reason="guide:"+str(_guide.reason) if _guide!=null else "guide:missing"
	if _route!=null:_route.cancel()
	if _guide!=null:_guide.cancel()
	_emit("blocked")
	return _finish_step(before,delta,"blocked")

func _refuse(reason: String) -> bool:
	if _route!=null:_route.cancel()
	if _guide!=null:_guide.cancel()
	# DSH_ROUTES58: a refused start must not leave a prepared arc behind that would keep
	# moving the body under a goal the driver has already given up.
	_prepared58_finish("refused:"+reason)
	_active=false;_phase="blocked";_last_reason=reason
	_emit("begin_refused")
	return false

func active() -> bool:return _active
func target() -> Vector3:return _target
func target_source() -> String:return _target_source
func phase() -> String:return _phase
func attempts() -> int:return _attempts
func moved_m() -> float:return _moved_m
func last_reason() -> String:return _last_reason
func roam_watch_state29() -> Dictionary:return _roam_watch29_state.duplicate()
func service_watch_state30() -> Dictionary:return _service_watch30.duplicate()
static func roam_retry_delay_ms29(actor_id: String, attempt: int, reason: String) -> int:
	return RoamWait.retry_delay_ms(actor_id,attempt,reason)
func outside_point() -> Variant:return _outside if _hospital_frame else null
func is_inside() -> bool:
	if not _hospital_frame or not is_instance_valid(_body) or not _body.is_inside_tree() or _route==null:return false
	if (_body.global_position-_door).dot(_inside_normal)<=.55 or _flat(_body.global_position,_room)>.40:return false
	if not _body.is_on_floor() or absf(_body.global_position.y-_room.y)>.12:return false
	var support: Variant=_route.floor_at(_body.global_position,_body.global_position.y)
	return support is Vector3 and absf(support.y-_body.global_position.y)<.08 and absf(support.y-_room.y)<.12 and _route.standing(support)
func distance_m() -> float:return _flat(_body.global_position,_target) if is_instance_valid(_body) and _body.is_inside_tree() else -1.0
static func _flat(a: Vector3,b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()
func cancel() -> void:
	if _door_clear31!=null:_door_clear31.cancel()
	_attention_paused29=false;_attention_ready29=false
	# DSH_ROUTES58: cancelling the driver cancels the prepared arc with it. Otherwise a stale
	# arc would keep stepping a body whose route the caller has already released.
	_prepared58_finish("cancelled")
	if _route!=null:_route.cancel()
	_active=false;_phase="cancelled"
	if _guide!=null:_guide.cancel()
	if is_instance_valid(_body):
		_body.velocity.x=0.0;_body.velocity.z=0.0
		# Cancellation has no caller delta; do not manufacture a current pose sample.
		# During teardown the body may already have left the tree: no global transform.
		if _body.has_meta("npc_physical_drive51"):_body.remove_meta("npc_physical_drive51")

## Attention owns no new destination. A ready route has no queued search and
## can be retained; pending work is cancelled. Gaze/alarm/facing belong to caller.
func attention_pause29() -> bool:
	if not _active:return false
	if not is_instance_valid(_body) or not _body.is_inside_tree() or _body.is_queued_for_deletion():
		cancel();return false
	if _attention_paused29:return true
	var was_door_backoff31:bool=_door_clear31!=null and _door_clear31.active()
	if _door_clear31!=null:_door_clear31.cancel()
	_attention_paused29=true;_phase="attention_paused"
	_attention_position29=_body.global_position;_attention_map29=_guide_map
	_attention_iteration29=-1
	if _guide_map.is_valid() and NavigationServer3D.get_maps().has(_guide_map):
		_attention_iteration29=NavigationServer3D.map_get_iteration_id(_guide_map)
	_attention_ready29=not was_door_backoff31 and _route!=null and _route.status=="ready" and _way<_route.route.size() and _guide!=null and _guide.status=="ready"
	if _attention_ready29 and bool(_guide.diagnostics().get("distant",false)):
		_attention_ready29=int(_guide.diagnostics().get("map_iteration",-2))==_attention_iteration29
	if not _attention_ready29:
		if _route!=null:_route.cancel()
		if _guide!=null:_guide.cancel()
	_body.velocity.x=0.0;_body.velocity.z=0.0
	if _body.has_meta("npc_physical_drive51"):_body.remove_meta("npc_physical_drive51")
	return true

func attention_hold29(delta: float) -> void:
	if _attention_paused29 and _active:hold(delta)

func _attention_same_map29() -> bool:
	if _guide_map!=_attention_map29:return false
	if not _guide_map.is_valid():return _attention_iteration29==-1
	return NavigationServer3D.get_maps().has(_guide_map) and NavigationServer3D.map_get_iteration_id(_guide_map)==_attention_iteration29

func attention_resume29() -> bool:
	if not _attention_paused29:return _active
	_attention_paused29=false
	if not _active or not is_instance_valid(_body) or not _body.is_inside_tree() or _body.is_queued_for_deletion():
		cancel();return false
	if _target_source=="roam":
		_roam_watch29=RoamWait.new();_roam_watch29.begin(Time.get_ticks_msec())
		_roam_service29_us=int(_route.service_us29);_roam_watch29_state.clear()
	# Keep waypoint and guide revision so the next physics step moves directly.
	# Small vertical settling during hold is expected; an actual displacement,
	# a changed map or an invalidated route instead restarts the same outer leg.
	var ready: bool=_attention_ready29 and _route!=null and _route.status=="ready" and _route._actor_live() and _way<_route.route.size() and _guide!=null and _guide.status=="ready"
	ready=ready and _flat(_body.global_position,_attention_position29)<.015 and absf(_body.global_position.y-_attention_position29.y)<.04 and _attention_same_map29()
	_attention_ready29=false
	if ready:
		_phase="walking"
		return true
	_attempts=0;_way=0;_stall_s=0.0;_replan_s=0.0;_phase="searching"
	if not _begin_guided_leg():return _refuse("guide:"+str(_guide.reason))
	return true

func _publish(before: Vector3, after: Vector3, delta: float) -> void:
	var velocity: Vector3=(after-before)/maxf(delta,.0001)
	_body.set_meta("npc_physical_drive51",{"frame":Engine.get_physics_frames(),"body_id":_body.get_instance_id(),"from":before,"to":after,"velocity":velocity,"delta":delta,"walking":Vector2(velocity.x,velocity.z).length()>.03})

func _occupants() -> Array:
	var scene: Node3D=_scene_of_body()
	var rows: Array=[]
	if scene==null:return rows
	var population: Variant=scene.get("preview_population")
	if population!=null:
		var residents: Variant=population.get("residents")
		if residents!=null and residents.has_method("occupants"):
			rows=residents.occupants().duplicate()
	var player: Variant=scene.get("_player")
	if player is Node3D and is_instance_valid(player) and player.is_inside_tree():
		rows.append({"position":player.global_position,"radius":.36,"height":1.8})
	# Include the caller even if the public population snapshot has not refreshed yet.
	rows.append({"position":_body.global_position,"radius":_route.shape.shape.radius,"height":_route.shape.shape.height})
	return rows

func _door_tick() -> void:
	if not _door_valid or not is_instance_valid(_door_owner) or _flat(_body.global_position,_door)>=2.4:return
	if float(_door_owner.get("target"))>=1.0:return
	var now: int=Time.get_ticks_msec()
	if now<_door_retry_ms:return
	_door_retry_ms=now+250
	var result: Variant=_door_owner.call("request_door","public",true,_body.global_position,_occupants())
	_door_reason=str(result.get("reason","accepted" if result.get("accepted",false) else "refused")) if result is Dictionary else "invalid_result"

func _restart(reason: String) -> void:
	_attempts+=1;_last_reason=reason;_way=0;_stall_s=0;_replan_s=0
	var checkpoint: Variant=_guide.waypoint() if _guide!=null else null
	if checkpoint is Vector3:_route.begin(checkpoint)
	_phase="searching"
	_emit("replan")

## DSH_ROUTES58: the prepared line walked PHYSICALLY. One waypoint at a time, each step paid
## for by a live floor/step/clearance check, exactly like the shipped physical loop. The
## resident walks the whole arc in one prepared route: no local search has to be paid for it.
## A refused step (changed obstacle, blocked line) hands the remaining metres back to the
## ordinary physical planner, which is the check the owner asked to keep.
func _prepared58_step(before: Vector3, delta: float) -> String:
	_roam_step29_phase = "walking"
	if _prepared58_way >= _prepared58_points.size():
		_prepared58_finish("prepared_complete")
		return _finish_step(before, delta, "arrived", false)
	var waypoint: Vector3 = _prepared58_points[_prepared58_way]
	var current: Vector3 = _body.global_position
	var remaining: float = _flat(current, waypoint)
	while _prepared58_way < _prepared58_points.size() - 1 and remaining <= .12:
		_prepared58_way += 1
		waypoint = _prepared58_points[_prepared58_way]
		remaining = _flat(current, waypoint)
	if _prepared58_way == _prepared58_points.size() - 1 and remaining < _arrival_m56 and _body.is_on_floor() and absf(current.y - waypoint.y) < .12:
		_prepared58_finish("prepared_complete")
		if _target_source == "roam" and _roam_watch29 != null:
			_roam_watch29_state = _roam_watch29.observe(Time.get_ticks_msec(), "arrived", _moved_m, 0)
		return _finish_step(before, delta, "arrived", false)
	var direction: Vector3 = waypoint - current; direction.y = 0.0
	if direction.length() < .001:
		_prepared58_way += 1
		return _finish_step(before, delta, "walking", false)
	direction = direction.normalized()
	var distance: float = minf(SPEED_MPS * delta, remaining)
	# The same live window the physical loop uses: floor ahead, step height, then the sweep.
	var ahead: Vector3 = current + direction * minf(.4, remaining)
	var ground: Variant = _route.floor_at(ahead, current.y)
	if not ground is Vector3 or absf(Vector3(ground).y - current.y) > Route.STEP + .01:
		_prepared58_finish("prepared_step_refused")
		_restart("prepared_arc_changed")
		return _finish_step(before, delta, "walking", false)
	if not _route.edge_clear(current, current + direction * distance):
		_prepared58_finish("prepared_blocked")
		_restart("prepared_arc_blocked")
		return _finish_step(before, delta, "walking", false)
	var displacement: Vector3 = _route.move(direction, distance, delta)
	var travel: float = Vector2(displacement.x, displacement.z).length()
	_moved_m += travel
	if travel < distance * .2:
		_prepared58_stall += delta
		if _prepared58_stall > 1.0:
			_prepared58_finish("prepared_stalled")
			_restart("prepared_arc_stalled")
			return _finish_step(before, delta, "walking", false)
	else:
		_prepared58_stall = 0.0
	_event = "walking_prepared58"
	return _finish_step(before, delta, "walking", false)

func _prepared58_finish(reason: String) -> void:
	# Handing back to the planner keeps the same actor, target and lease; the arc itself is
	# dropped here, so a stale arc can never move a body the planner has taken over.
	_prepared58_points.clear()
	_prepared58_way = 0
	_prepared58_stall = 0.0
	_prepared58_reason = reason

## Only actual serviced local search and attempted motion accumulate. The guide
## already bounds native/authority waits. Hold/dwell/attention never enter here.
## Reset only after a real .25m displacement, never on replan or gaze resume.
func _service_observe30(before: Vector3, delta: float) -> String:
	if _service_watch30.is_empty():return ""
	var serviced: int=int(_route.service_us29)
	var work: int=maxi(0,serviced-_service_last_us30)
	_service_last_us30=serviced
	_service_watch30.total_service_us=int(_service_watch30.total_service_us)+work
	_service_watch30.planning_service_us=int(_service_watch30.planning_service_us)+work
	if _flat(_service_anchor30,_body.global_position)>=SERVICE_PROGRESS_M30:
		_service_anchor30=_body.global_position
		_service_watch30.planning_service_us=0;_service_watch30.local_wait_ms=0.0;_service_watch30.motion_idle_ms=0.0
		_service_watch30.progress_resets=int(_service_watch30.progress_resets)+1
	elif _roam_step29_phase=="walking":
		if _flat(before,_body.global_position)<=.005:
			_service_watch30.motion_idle_ms=float(_service_watch30.motion_idle_ms)+delta*1000.0
	elif _guide!=null and _guide.status=="ready":
		_service_watch30.local_wait_ms=float(_service_watch30.local_wait_ms)+delta*1000.0
	var why:=""
	if int(_service_watch30.planning_service_us)>=SERVICE_PLAN_US30:why="service_planning_work_limit30"
	elif float(_service_watch30.local_wait_ms)>=SERVICE_LOCAL_WAIT_MS30:why="service_local_wait_limit30"
	elif float(_service_watch30.motion_idle_ms)>=SERVICE_MOTION_MS30:why="service_motion_stalled30"
	_service_watch30.blocked=not why.is_empty();_service_watch30.reason=why
	return why

# Called only on attempted service/roam movement, after peer waits. Track
# the current waypoint, not the final goal: a planned detour may lead away
# from that goal. Replan uses the same route and cumulative work budget.
func _service_waypoint_stalled56(ready_frame: int, way: int, remaining: float, delta: float) -> bool:
	if ready_frame != _service_ready_frame56 or way != _service_way56:
		_service_ready_frame56 = ready_frame; _service_way56 = way
		_service_best_distance56 = remaining; _service_way_idle_s56 = 0.0
	elif remaining < _service_best_distance56 - .10:
		_service_best_distance56 = remaining; _service_way_idle_s56 = 0.0
	else:
		_service_way_idle_s56 += delta
	return _service_way_idle_s56 >= 3.0

func _finish_step(before: Vector3, delta: float, result: String, idle: bool = true) -> String:
	if idle:_route.hold(delta)
	if _active and result=="walking" and _target_source=="roam" and _roam_watch29!=null:
		# Count this route's serviced search, even if another caller pumped it.
		# Ready/live-guard/debug queries are not planner service or queue wait.
		var serviced: int=int(_route.service_us29)
		_roam_watch29_state=_roam_watch29.observe(Time.get_ticks_msec(),_roam_step29_phase,
			_flat(before,_body.global_position),maxi(0,serviced-_roam_service29_us))
		_roam_service29_us=serviced
		if bool(_roam_watch29_state.blocked):
			_last_reason=str(_roam_watch29_state.reason);_active=false;_phase="blocked"
			_route.cancel()
			if _guide!=null:_guide.cancel()
			_body.velocity.x=0.0;_body.velocity.z=0.0
			result="blocked";_event="roam_watch_blocked"
	if _active and result=="walking" and not _attention_paused29 and _target_source=="service_approach":
		var service_reason: String=_service_observe30(before,delta)
		if not service_reason.is_empty():
			_last_reason=service_reason;_active=false;_phase="blocked"
			_route.cancel()
			if _guide!=null:_guide.cancel()
			_body.velocity.x=0.0;_body.velocity.z=0.0
			result="blocked";_event="service_watch_blocked30"
	_publish(before,_body.global_position,delta)
	_emit(_event)
	return result

## Life calls this during treatment/retry. Fresh gravity and measured idle metadata
## preserve the same actor and inpatient doorway frame while its route is inactive.
func hold(delta: float) -> void:
	if not is_instance_valid(_body) or not _body.is_inside_tree() or _route==null or not is_finite(delta) or delta<=0:return
	var frame: int=Engine.get_physics_frames()
	if _frame==frame:return
	_frame=frame
	var before: Vector3=_body.global_position
	_door_tick()
	_finish_step(before,delta,"")

## Called only for a skipped stationary planning wait; no movement/arrival occurs.
func wait_clock56(delta: float) -> void:
	if not _active or _attention_paused29 or not is_finite(delta) or delta<=0.0:return
	_replan_s+=delta
	if not _service_watch30.is_empty() and _guide!=null and _guide.status=="ready":
		_service_watch30.local_wait_ms=float(_service_watch30.local_wait_ms)+delta*1000.0

func step(delta: float) -> String:
	if not _active or not is_instance_valid(_body) or not _body.is_inside_tree() or not is_finite(delta) or delta<=0:return ""
	if _attention_paused29:
		attention_hold29(delta);return "walking"
	var frame: int=Engine.get_physics_frames()
	if _frame==frame:return ""
	_frame=frame
	var before: Vector3=_body.global_position
	_roam_step29_phase="planning"
	_door_tick()
	# DSH_ROUTES58: a prepared arc owns the motion until it ends, is refused, or the resident
	# is asked to stop. It never coexists with the local search, so no second route exists.
	if not _prepared58_points.is_empty():
		if _door_clear31!=null and (_door_clear31.active() or _door_clear31.poll(_route)):
			var clearance:String=_door_clear31.step(_route,delta,SPEED_MPS)
			_roam_step29_phase=str(_door_clear31._activity)
			if clearance=="blocked":
				_last_reason=str(_door_clear31.snapshot().reason);_active=false;_phase="blocked"
				_prepared58_finish("prepared_door_blocked")
				_route.cancel();_guide.cancel()
				return _finish_step(before,delta,"blocked",false)
			if clearance=="resume":
				_restart("door_clear_original_goal31")
				return _finish_step(before,delta,"walking",false)
			_phase="door_clear_"+str(_door_clear31._phase)
			return _finish_step(before,delta,"walking",false)
		return _prepared58_step(before,delta)
		var clearance:String=_door_clear31.step(_route,delta,SPEED_MPS)
		_roam_step29_phase=str(_door_clear31._activity)
		if clearance=="blocked":
			_last_reason=str(_door_clear31.snapshot().reason);_active=false;_phase="blocked"
			_route.cancel();_guide.cancel()
			return _finish_step(before,delta,"blocked",false)
		if clearance=="resume":
			_restart("door_clear_original_goal31")
			return _finish_step(before,delta,"walking",false)
		_phase="door_clear_"+str(_door_clear31._phase)
		return _finish_step(before,delta,"walking",false)
	_replan_s+=delta
	var guide_state: String=_sync_guide()
	if guide_state=="blocked":return _guide_blocked(before,delta)
	if guide_state!="ready":return _finish_step(before,delta,"walking")
	if _attempts>12:
		if _guide.retry("local_detour_exhausted"):
			_attempts=0;_phase="searching_guide"
			return _finish_step(before,delta,"walking")
		return _guide_blocked(before,delta)
	if _route.status=="searching":
		_route.tick()
		if _route.status=="ready":
			_phase="walking";_way=0;_emit("route_ready")
		elif _route.status=="blocked":
			_phase="waiting_obstacle";_emit("no_route")
		return _finish_step(before,delta,"walking")
	if _route.status=="blocked":
		if _replan_s>1.0:_restart("live_obstacle_retry")
		return _finish_step(before,delta,"walking")
	var points: Array=_route.route
	while _way<points.size()-1 and _flat(_body.global_position,points[_way])<.12:_way+=1
	if points.is_empty():
		_restart("empty_path")
		return _finish_step(before,delta,"walking")
	# A route is ready: unsupported edges and native collision now count as
	# attempted motion. Internal replan pauses, but never clears, stalled time.
	_roam_step29_phase="walking"
	var waypoint: Vector3=points[_way]
	var current: Vector3=_body.global_position
	var remaining: float=_flat(current,waypoint)
	if _way==points.size()-1 and remaining<_arrival_m56 and _body.is_on_floor() and absf(current.y-waypoint.y)<.12 and _route.edge_clear(current,waypoint):
		# A local route completion is only a guide checkpoint. It cannot complete
		# treatment/meal approach until every checkpoint and outer door leg is done.
		var guide_result: String=_guide.advance(current)
		if guide_result=="blocked":return _guide_blocked(before,delta)
		if guide_result!="complete":
			_sync_guide();_emit("guide_checkpoint")
			return _finish_step(before,delta,"walking")
		if _leg<_legs.size()-1:
			# A closed/opening leaf remains physical. Wait at outside until it clears.
			_leg+=1;_way=0;_phase="searching";_replan_s=0
			if not _begin_guided_leg():return _guide_blocked(before,delta)
			_emit("leg_complete")
			return _finish_step(before,delta,"walking")
		_active=false;_phase="arrived"
		if _route!=null:_route.cancel()
		_emit("arrived")
		return _finish_step(before,delta,"arrived")
	var direction: Vector3=waypoint-current;direction.y=0
	if direction.length()<.001:
		# A flat-aligned waypoint can still fail its floor/height/edge arrival
		# checks. Do not let that early return bypass roaming progress.
		if _target_source == "roam" and _service_waypoint_stalled56(int(_route._ready_frame), _way, remaining, delta):
			_roam_step29_phase = "planning"; _restart("roam_waypoint_no_progress58")
		return _finish_step(before,delta,"walking")
	direction=direction.normalized()
	var distance: float=minf(SPEED_MPS*delta,remaining)
	if _avoidance29!=null:
		_avoidance29.refresh(_scene_of_body(),_body,_id)
		_avoidance29_state=_avoidance29.steer(_body,direction,SPEED_MPS)
		if bool(_avoidance29_state.replan):
			_roam_step29_phase="planning";_restart("peer_detour_no_progress")
			return _finish_step(before,delta,"walking")
		if bool(_avoidance29_state.waiting):
			_roam_step29_phase="planning";_stall_s=0.0
			return _finish_step(before,delta,"walking")
		direction=_avoidance29_state.direction
		distance=minf(SPEED_MPS*float(_avoidance29_state.ratio)*delta,remaining)
	if _target_source in ["service_approach", "roam"] and _service_waypoint_stalled56(int(_route._ready_frame), _way, remaining, delta):
		_roam_step29_phase = "planning"
		_restart("roam_waypoint_no_progress58" if _target_source == "roam" else "service_waypoint_no_progress56")
		return _finish_step(before, delta, "walking")
	# Revalidate current local edge; changed furniture/rubble cannot be traversed from a stale plan.
	var ahead: Vector3=current+direction*minf(.4,remaining)
	var floor: Variant=_route.floor_at(ahead,current.y)
	# Native motion owns collision response along this already planned segment.
	# Grounding an intermediate query at the NEXT floor would put a capsule into
	# the side of a step before its body has climbed or cleared the platform.
	# Recheck support; actual move_and_slide/test_move below rechecks every wall.
	if not floor is Vector3 or absf(floor.y-current.y)>Route.STEP+.01:
		_stall_s+=delta
		if _stall_s>.6:_restart("path_changed")
		return _finish_step(before,delta,"walking")
	var displacement: Vector3=_route.move(direction,distance,delta)
	var travel: float=Vector2(displacement.x,displacement.z).length()
	_moved_m+=travel
	var progress: float=maxf(0.0,displacement.dot(direction))
	if progress<distance*.2:_stall_s+=delta
	else:_stall_s=0
	if _stall_s>1.0:_restart("physical_stall")
	_event="walking"
	return _finish_step(before,delta,"walking",false)

func _emit(result: String) -> void:
	_event=result
	if not preload("res://scripts/city/runtime/npc_runtime_trace30.gd").enabled():return
	var now: int=Time.get_ticks_msec()
	if now-_print_ms<1000:return
	_print_ms=now
	var alive: bool=is_instance_valid(_body) and _body.is_inside_tree()
	var pos: Vector3=_body.global_position if alive else Vector3.INF
	var point: Variant=_route.route[_way] if _route!=null and _way<_route.route.size() else null
	var floor_point: Variant=_route.floor_at(pos,pos.y) if _route!=null and alive else null
	var state: Dictionary=_route.diagnostics() if _route!=null else {}
	print("DSH_SIMPLEHOSP ",JSON.stringify({"id":_id,"result":_event,"phase":_phase,"source":_target_source,"position":[pos.x,pos.y,pos.z],"target":[_target.x,_target.y,_target.z],"leg":_leg,"legs":_legs.size(),"way":_way,"waypoint":[point.x,point.y,point.z] if point is Vector3 else [],"dist_m":distance_m() if alive else -1.0,"moved_m":_moved_m,"attempts":_attempts,"reason":_last_reason,"door_reason":_door_reason,"on_floor":_body.is_on_floor() if alive else false,"floor":[floor_point.x,floor_point.y,floor_point.z] if floor_point is Vector3 else [],"route":state,"guide":_guide.diagnostics() if _guide!=null else {},"roam_watch":_roam_watch29_state,"service_watch30":_service_watch30,"avoidance":_avoidance29_state,"frame":Engine.get_physics_frames(),"time_ms":now}))
