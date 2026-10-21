extends RefCounted
## The existing physical planner and native capsule remain the movement authority.
const Route = preload("res://scripts/hospital/npc_physical_route51.gd")
const Avoidance = preload("res://scripts/navigation/npc_avoidance_world29.gd")
const FEAR_MULTIPLIER := 1.10
const PLAN_SERVICE_CAP_US := 200000
const LEG_SECONDS := 8.0
var _route: RefCounted
var _avoidance: RefCounted
var _body: CharacterBody3D
var _id := ""
var _way := 0
var _age := 0.0
var _frame := -1
var _goal := Vector3.ZERO
var normal_speed := 0.0
var fear_speed := 0.0
var moved_m := 0.0
var status := "idle"
var reason := ""
# A hint for the existing physical planner, never movement permission. Probe one
# bounded candidate per physics frame; charge these queries to the SAME work cap.
const ESCAPE_ANGLES58 := [0.0, .75, -.75, PI * .5, -PI * .5]
const ESCAPE_LENGTHS58 := [8.0, 4.0]
var _selecting58 := false
var _selection_cursor58 := 0
var _selection_us58 := 0
var _selection_max_us58 := 0
var _selection_origin58 := Vector3.ZERO
var _known_from58 := Vector3.ZERO
var _away58 := Vector3.ZERO
var _fallback58 := Vector3.ZERO
var _tried58: Array[Vector3] = []
var _selection58: Array[Dictionary] = []

func configure(body: CharacterBody3D, source_id: String, ordinary_speed: float) -> bool:
	if not is_instance_valid(body) or not is_finite(ordinary_speed) or ordinary_speed<=0:return false
	_body=body;_id=source_id;normal_speed=ordinary_speed
	# Never modify record.speed or multiply an already boosted value.
	fear_speed=normal_speed*FEAR_MULTIPLIER
	_route=Route.new()
	if not _route.configure(body):return false
	_avoidance=Avoidance.for_scene(body.get_tree().current_scene)
	return true

func begin(goal: Vector3) -> bool:
	if _route==null or not goal.is_finite():return false
	_goal=goal;_age=0.0;_way=0;status="searching";reason=""
	if not _route.begin(goal):status="blocked";reason="route_admission";return false
	return true

func begin_escape58(known_from: Vector3, attempt: int) -> bool:
	if _route==null or not _route._actor_live() or not known_from.is_finite() or attempt<0 or attempt>=3:return false
	if attempt==0:_tried58.clear()
	_route.cancel();_selection_origin58=_body.global_position;_known_from58=known_from
	_away58=_selection_origin58-known_from;_away58.y=0.0
	if _away58.length_squared()<.01:_away58=-_body.global_basis.z;_away58.y=0.0
	_away58=_away58.normalized()
	_fallback58=_selection_origin58+_away58.rotated(Vector3.UP,[0.0,.75,-.75][attempt])*8.0
	_selection_cursor58=0;_selection58.clear();_selecting58=true
	_age=0.0;_way=0;status="selecting";reason=""
	return true

func _work_us58() -> int:
	return int(_route.service_us29)+_selection_us58

func _tried_goal58(goal: Vector3) -> bool:
	for previous: Vector3 in _tried58:
		if _flat(previous,goal)<.5:return true
	return false

func _choose_escape58() -> void:
	var index: int=_selection_cursor58
	_selection_cursor58+=1
	var angle: float=ESCAPE_ANGLES58[index%ESCAPE_ANGLES58.size()]
	var length: float=ESCAPE_LENGTHS58[index/ESCAPE_ANGLES58.size()]
	var target: Vector3=_selection_origin58+_away58.rotated(Vector3.UP,angle)*length
	var why := "already_tried"
	var accepted := false
	# Orthogonal retreat increases distance without initially approaching the
	# last OBSERVED threat. Do not inspect the hidden player's current location.
	if not _tried_goal58(target):
		why="not_farther"
		if _flat(target,_known_from58)>_flat(_selection_origin58,_known_from58)+.1:
			var floor: Variant=_route.floor_at(target,_selection_origin58.y)
			why="no_floor"
			if floor is Vector3:
				why="capsule_blocked"
				if _route.standing(floor) and _route.sweep(_selection_origin58,floor):
					target=floor;accepted=true;why="direct_corridor_hint"
	_selection58.append({"index":index,"goal":target,"reason":why,"accepted":accepted})
	if accepted:
		_selecting58=false;_tried58.append(target);begin(target)
	elif _selection_cursor58>=ESCAPE_ANGLES58.size()*ESCAPE_LENGTHS58.size():
		_selecting58=false
		# A blocked straight sweep does not prove no path. Retain the old bounded
		# planner's opportunity to find a detour, with the remaining incident cap.
		if _tried_goal58(_fallback58):status="blocked";reason="escape_candidates_exhausted"
		else:_tried58.append(_fallback58);begin(_fallback58)

func _publish(before: Vector3, delta: float) -> void:
	var after: Vector3=_body.global_position
	var velocity: Vector3=(after-before)/delta
	_body.set_meta("npc_physical_drive51",{"frame":Engine.get_physics_frames(),"body_id":_body.get_instance_id(),"from":before,"to":after,"velocity":velocity,"delta":delta,"walking":Vector2(velocity.x,velocity.z).length()>.03})

func hold(delta: float) -> void:
	if _route==null or not is_instance_valid(_body) or delta<=0 or delta>.05 or _frame==Engine.get_physics_frames():return
	_frame=Engine.get_physics_frames()
	var before: Vector3=_body.global_position
	_route.hold(delta);_publish(before,delta)

func step(delta: float) -> String:
	if _route==null or not is_instance_valid(_body) or not _body.is_inside_tree():return "blocked"
	if delta<=0 or delta>.05 or _frame==Engine.get_physics_frames():return status
	_frame=Engine.get_physics_frames();_age+=delta
	var before: Vector3=_body.global_position
	if _age>LEG_SECONDS or _work_us58()>PLAN_SERVICE_CAP_US:
		status="blocked";reason="bounded_route_deadline";_route.cancel()
	if status=="blocked":_route.hold(delta);_publish(before,delta);return status
	if _selecting58:
		var since: int=Time.get_ticks_usec()
		_choose_escape58()
		var used: int=Time.get_ticks_usec()-since
		_selection_us58+=used;_selection_max_us58=maxi(_selection_max_us58,used)
		if _work_us58()>PLAN_SERVICE_CAP_US:
			status="blocked";reason="bounded_route_deadline";_selecting58=false;_route.cancel()
		_route.hold(delta);_publish(before,delta);return status
	if _route.status=="searching":_route.tick()
	if _route.status=="blocked":status="blocked";reason="native_route_blocked"
	if _route.status!="ready":_route.hold(delta);_publish(before,delta);return status
	status="walking"
	while _way<_route.route.size()-1 and _flat(_body.global_position,_route.route[_way])<.14:_way+=1
	if _route.route.is_empty():status="blocked";reason="no_route";_route.hold(delta);_publish(before,delta);return status
	var point: Vector3=_route.route[_way]
	var direction: Vector3=point-_body.global_position;direction.y=0.0
	var distance: float=direction.length()
	if _way==_route.route.size()-1 and distance<.30 and _body.is_on_floor():
		status="arrived";_route.cancel();_route.hold(delta);_publish(before,delta);return status
	if distance<.001:_route.hold(delta);_publish(before,delta);return status
	direction/=distance
	var speed: float=fear_speed
	if _avoidance!=null:
		_avoidance.refresh(_body.get_tree().current_scene,_body,_id)
		var peer: Dictionary=_avoidance.steer(_body,direction,speed)
		if peer.waiting or peer.replan:_route.hold(delta);_publish(before,delta);return status
		direction=peer.direction;speed*=float(peer.ratio)
	var ahead: Vector3=_body.global_position+direction*minf(.35,distance)
	if not _route.floor_at(ahead,_body.global_position.y) is Vector3:
		status="blocked";reason="live_floor_changed";_route.cancel();_route.hold(delta)
	else:
		var travel: Vector3=_route.move(direction,minf(speed*delta,distance),delta)
		moved_m+=Vector2(travel.x,travel.z).length()
	_publish(before,delta)
	return status

static func _flat(a: Vector3,b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()

func cancel() -> void:
	_selecting58=false
	if _route!=null:_route.cancel()
	status="idle"
	if is_instance_valid(_body):_body.velocity.x=0.0;_body.velocity.z=0.0

func snapshot() -> Dictionary:
	return {"status":status,"reason":reason,"normal_speed":normal_speed,"fear_speed":fear_speed,"multiplier":FEAR_MULTIPLIER,"moved_m":moved_m,"age":_age,"goal":_goal,"queries":_route.queries if _route!=null else 0,"service_us":_route.service_us29 if _route!=null else 0,"selection_us58":_selection_us58,"selection_max_us58":_selection_max_us58,"total_work_us58":_work_us58() if _route!=null else 0,"selection58":_selection58.duplicate(true)}
