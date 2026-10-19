extends RefCounted
## Roaming capsule clears only a live door sweep blocked by that same body.
## Temporary physical backoff keeps the caller's original goal and guide intact.
const Swing = preload("res://scripts/city/runtime/npc_city_clone_door_swing.gd")
const POLL_MS := 250
const DEADLINE_MS := 6000
var _owner: WeakRef
var _body_id := 0
var _next_poll := 0
var _started := 0
var _way := 0
var _phase := ""
var _stage := Vector3.ZERO
var _reason := ""
var _activity := "idle"
var _events: Array = []

static func _flat(a:Vector3,b:Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()

func active()->bool:return not _phase.is_empty()

func cancel()->void:
	_owner=null;_body_id=0;_phase="";_next_poll=0

func _event(name:String,body:CharacterBody3D)->void:
	_events.append({"event":name,"frame":Engine.get_physics_frames(),"position":body.global_position,"stage":_stage})
	if _events.size()>12:_events.pop_front()

func snapshot()->Dictionary:
	return {"phase":_phase,"activity":_activity,"stage":_stage,"reason":_reason,"events":_events.duplicate(true)}

func poll(physical:RefCounted)->bool:
	if active():return true
	var now:int=Time.get_ticks_msec()
	if now<_next_poll:return false
	_next_poll=now+POLL_MS
	var body:CharacterBody3D=physical.body
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or body.collision_layer!=1:return false
	var own_reason:String="sweep_body:"+str(body.get_path())
	for door:Variant in Swing.doors():
		if door._blocked_reason!=own_reason or not door._available():continue
		if not door.opening_requested31() or float(door.fraction)>=.999:continue
		if _flat(body.global_position,door.anchor)>3.0:continue
		var stage:Variant=_safe_stage(door,physical)
		if not stage is Vector3:_reason="no_supported_door_backoff31";continue
		_owner=weakref(door);_body_id=body.get_instance_id();_stage=stage;_started=now;_way=0;_phase="retreat";_reason=""
		_event("native_backoff_begin",body)
		if physical.begin(_stage):return true
		cancel();_reason="backoff_plan_refused31"
	return false

func _safe_stage(door:Node3D,physical:RefCounted)->Variant:
	var body:CharacterBody3D=physical.body
	var leaf:Node3D=door.leaf
	var parent:Node3D=leaf.get_parent_node_3d()
	var closed:Transform3D=door.leaf_closed
	var hinge:Vector3=parent.to_global(door.hinge)
	var radius:=0.0
	for part:Node in leaf.get_children():
		if not part is CollisionShape3D or part.disabled:continue
		if not part.shape is BoxShape3D:return null
		var half:Vector3=part.shape.size*.5
		var frame:Transform3D=parent.global_transform*closed*part.transform
		for x:float in [-half.x,half.x]:
			for y:float in [-half.y,half.y]:
				for z:float in [-half.z,half.z]:radius=maxf(radius,_flat(frame*Vector3(x,y,z),hinge))
	if radius<=0.0 or not physical.shape.shape is CapsuleShape3D:return null
	var normal:Vector3=(parent.global_basis*closed.basis.z).normalized();normal.y=0;normal=normal.normalized()
	var side:float=1.0 if (body.global_position-door.anchor).dot(normal)>=0.0 else -1.0
	var tangent:=Vector3(-normal.z,0,normal.x)
	for depth:float in [2.3,2.2,2.1,2.0]:
		for offset:float in [0.0,.4,-.4,.8,-.8]:
			var at:Vector3=door.anchor+normal*side*depth+tangent*offset
			if _flat(at,door.anchor)>2.4:continue
			if _flat(at,hinge)<radius+float(physical.shape.shape.radius)+.12:continue
			var floor:Variant=physical.floor_at(at,body.global_position.y)
			if not floor is Vector3 or absf(floor.y-body.global_position.y)>.1:continue
			# The backoff is on the current side of the leaf. Reject any candidate
			# whose supported capsule segment crosses a wall, door, player or edge.
			if physical.standing(floor) and physical.edge_clear(body.global_position,floor):return floor
	return null

## Return idle/working/resume/blocked. All movement uses the native physical route.
func step(physical:RefCounted,delta:float,speed:float)->String:
	_activity="idle"
	if not active():return "idle"
	var body:CharacterBody3D=physical.body
	var door:Variant=_owner.get_ref() if _owner!=null else null
	if not is_instance_valid(body) or body.get_instance_id()!=_body_id or not body.is_inside_tree() or body.is_queued_for_deletion() or body.collision_layer!=1:
		cancel();_reason="door_backoff_actor_retired31";return "blocked"
	if not is_instance_valid(door) or not door._available():
		cancel();_reason="door_backoff_owner_retired31";return "resume"
	if not door.opening_requested31():
		_event("open_intent_revoked",body);cancel();return "resume"
	if Time.get_ticks_msec()-_started>=DEADLINE_MS:
		_event("bounded_backoff_timeout",body);cancel();_reason="door_backoff_timeout31";return "blocked"
	if _phase=="opening":
		physical.hold(delta)
		if float(door.door_fraction("public"))<.999:return "working"
		_event("fully_open_original_goal_resume",body);cancel();return "resume"
	if physical.status=="searching":_activity="planning";physical.tick();physical.hold(delta);return "working"
	if physical.status!="ready":cancel();_reason="door_backoff_path_blocked31";return "blocked"
	var points:Array=physical.route
	while _way<points.size()-1 and _flat(body.global_position,points[_way])<.08:_way+=1
	if points.is_empty():cancel();_reason="door_backoff_empty31";return "blocked"
	var waypoint:Vector3=points[_way]
	var remaining:float=_flat(body.global_position,waypoint)
	if _way==points.size()-1 and remaining<.025 and body.is_on_floor() and absf(body.global_position.y-waypoint.y)<.08:
		physical.hold(delta);_phase="opening";_event("safe_stage_arrived",body);return "working"
	var direction:Vector3=waypoint-body.global_position;direction.y=0
	if direction.length_squared()<.000001:physical.hold(delta);return "working"
	var ahead:Vector3=body.global_position+direction.normalized()*minf(.4,remaining)
	var floor:Variant=physical.floor_at(ahead,body.global_position.y)
	if not floor is Vector3 or absf(floor.y-body.global_position.y)>.1:
		cancel();_reason="door_backoff_floor_changed31";return "blocked"
	_activity="walking";physical.move(direction.normalized(),minf(speed*delta,remaining),delta)
	return "working"
