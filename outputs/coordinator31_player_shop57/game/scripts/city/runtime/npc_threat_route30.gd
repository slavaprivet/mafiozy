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
	if _age>LEG_SECONDS or int(_route.service_us29)>PLAN_SERVICE_CAP_US:
		status="blocked";reason="bounded_route_deadline";_route.cancel()
	if status=="blocked":_route.hold(delta);_publish(before,delta);return status
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
	if _route!=null:_route.cancel()
	status="idle"
	if is_instance_valid(_body):_body.velocity.x=0.0;_body.velocity.z=0.0

func snapshot() -> Dictionary:
	return {"status":status,"reason":reason,"normal_speed":normal_speed,"fear_speed":fear_speed,"multiplier":FEAR_MULTIPLIER,"moved_m":moved_m,"age":_age,"goal":_goal,"queries":_route.queries if _route!=null else 0,"service_us":_route.service_us29 if _route!=null else 0}
