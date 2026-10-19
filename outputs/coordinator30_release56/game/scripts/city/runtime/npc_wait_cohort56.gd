extends RefCounted
## Only skips a previously proven stationary wait. This grants no motion/service authority.
const Budget=preload("res://scripts/hospital/npc_route_budget29.gd")
const MAX_STATES:=384
const PERIOD_FRAMES:=6
const MAX_DELAY_MS:=100
const NEAR_M2:=625.0
var _states: Dictionary={}
var _enabled:=true
var skipped:=0
var support_queries:=0
var support_wakes:=0
var ready_wakes:=0
var max_gap_frames:=0
var max_gap_ms:=0

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--city-wait-cohort56=0":_enabled=false

func begin_frame() -> void:
	# Existing budget deduplicates by physics frame. No new units/deadline are added.
	if _enabled:Budget.pump()

func forget(id: String, exact_life: RefCounted=null) -> void:
	if not _states.has(id):return
	if exact_life!=null and _states[id].life.get_ref()!=exact_life:return
	_states.erase(id)

func clear() -> void:_states.clear()

func _driver(life: RefCounted) -> RefCounted:
	if life._disposed or life._busy or life._visit!=null or life._attention29.active or life._interrupting:return null
	if life._threat30!=null and life._threat30.active():return null
	if life._ambient29!=null and life._ambient29.active():return null
	# All medical stages stay on the full dispatcher, including waiting/treatment.
	if str(life._goal.get("kind",""))=="hospital" or life._incident_waiting_release or life._phase=="INCIDENT_REACTING":return null
	var outer: RefCounted
	if life._economy28!=null and life._economy28._phase in ["WAITING","INBOUND"]:outer=life._economy28._route
	elif life._restaurant28!=null:outer=life._restaurant28
	if outer!=null:
		if outer._phase in ["WAITING","PORTAL_WAIT_IN","PORTAL_WAIT_OUT","SERVICE_WAIT"] and not outer._waiting_move:
			if outer._registry==null or not outer._registry.owns(outer._key,outer):return null
			if outer._phase=="WAITING" and outer._registry.ledger.requests[outer._key].state!="waiting":return null
			return outer._drive
		if outer._phase not in ["INBOUND","OUTBOUND","SERVICE_APPROACH"]:return null
		return _planning_driver(outer._drive)
	if life._roam51_active:return _planning_driver(life._roam51)
	return null

func _planning_driver(driver: RefCounted) -> RefCounted:
	if driver==null or not driver._active or driver._attention_paused29 or driver._route==null or driver._guide==null:return null
	# A ready local path must start moving this tick, independent of its cohort.
	if driver._guide.status=="ready" and driver._route.status=="ready":return null
	if driver._guide.status in ["blocked","cancelled","complete"]:return null
	return driver if driver._phase in ["searching","searching_guide","waiting_obstacle"] else null

func _far(body: CharacterBody3D, player: Vector3, camera: Vector3) -> bool:
	if not player.is_finite() and not camera.is_finite():return false
	var p: Vector3=body.global_position
	return (not player.is_finite() or p.distance_squared_to(player)>NEAR_M2) and (not camera.is_finite() or p.distance_squared_to(camera)>NEAR_M2)

func note_full(life: RefCounted, frame: int, now_ms: int, player: Vector3, camera: Vector3) -> void:
	if not _enabled:return
	var id: String=str(life._token.get("source_id",""))
	var driver: RefCounted=_driver(life)
	var body: CharacterBody3D=life._token.get("body") as CharacterBody3D
	if driver==null or not is_instance_valid(body) or not body.is_inside_tree() or not body.is_on_floor() or not _far(body,player,camera):forget(id);return
	if driver._route==null or driver._frame!=frame or body.velocity.length_squared()>.000001:forget(id);return
	var motion: Dictionary=body.get_meta("npc_physical_drive51",{})
	if int(motion.get("frame",-1))!=frame or Vector3(motion.get("velocity",Vector3.INF)).length_squared()>.000001:forget(id);return
	if life._health==null or life._health._adapter==null:return
	var state: Dictionary=_states.get(id,{})
	if state.is_empty():
		if _states.size()>=MAX_STATES:return
		state={"ray":PhysicsRayQueryParameters3D.new(),"motion":{"frame":frame,"body_id":body.get_instance_id(),"velocity":Vector3.ZERO,"walking":false}}
		_states[id]=state
	var delay: int=(absi(id.hash())%PERIOD_FRAMES-frame%PERIOD_FRAMES+PERIOD_FRAMES)%PERIOD_FRAMES
	if delay==0:delay=PERIOD_FRAMES
	state.life=weakref(life);state.body=weakref(body);state.driver=weakref(driver)
	state.shape=weakref(driver._route.shape);state.position=body.global_position
	state.generation=life._token.life_generation;state.health=weakref(life._health);state.revision=life._health._adapter._revision
	state.full_frame=frame;state.full_ms=now_ms;state.next_frame=frame+delay
	var ray: PhysicsRayQueryParameters3D=state.ray
	ray.exclude=[body.get_rid()];ray.collision_mask=body.collision_mask

func skip(life: RefCounted, delta: float, frame: int, now_ms: int, player: Vector3, camera: Vector3) -> bool:
	if not _enabled:return false
	var id: String=str(life._token.get("source_id",""))
	if not _states.has(id):return false
	var s: Dictionary=_states[id]
	if s.life.get_ref()!=life:return false
	if frame>=int(s.next_frame) or now_ms-int(s.full_ms)>=MAX_DELAY_MS:return false
	var driver: RefCounted=_driver(life)
	if driver==null or driver!=s.driver.get_ref():ready_wakes+=1;forget(id);return false
	var body: CharacterBody3D=s.body.get_ref() as CharacterBody3D
	var shape: CollisionShape3D=s.shape.get_ref() as CollisionShape3D
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or not is_instance_valid(shape) or shape.disabled:return false
	if body!=life._token.get("body") or life._token.life_generation!=s.generation or body.collision_layer!=1 or body.collision_mask!=1:return false
	var record: Dictionary=life._host._records.get(id,{})
	if record.get("body")!=body or record.get("generation")!=s.generation:return false
	var health: RefCounted=life._health
	if health==null or health!=s.health.get_ref() or not health._ready or health._adapter==null or health._adapter._revision!=s.revision:return false
	var row: Dictionary=health._row
	if float(row.get("hp",0))<=float(row.get("max_hp",0))*.5 or health.should_pause_walk():return false
	if not body.is_on_floor() or body.velocity.length_squared()>.000001 or body.get_platform_velocity().length_squared()>.000001 or body.global_position.distance_squared_to(s.position)>.000001 or not _far(body,player,camera):return false
	# A live native ray each skipped tick detects removed/moved/disabled support.
	# The full capsule hold runs immediately on a miss; falling is never accumulated.
	var ray: PhysicsRayQueryParameters3D=s.ray
	ray.from=body.global_position+Vector3.UP*.04;ray.to=body.global_position-Vector3.UP*.08
	var hit: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(ray);support_queries+=1
	if hit.is_empty() or not hit.get("collider") is StaticBody3D or (hit.normal as Vector3).dot(Vector3.UP)<.7 or absf(float(hit.position.y)-body.global_position.y)>.04:
		support_wakes+=1;forget(id);return false
	# Planning clocks receive each skipped dt. Motion delta is NEVER scaled.
	driver.wait_clock56(delta)
	var motion: Dictionary=s.motion
	motion.frame=frame;motion.from=body.global_position;motion.to=body.global_position;motion.delta=delta
	body.set_meta("npc_physical_drive51",motion)
	life._frame=frame
	skipped+=1;max_gap_frames=maxi(max_gap_frames,frame-int(s.full_frame));max_gap_ms=maxi(max_gap_ms,now_ms-int(s.full_ms))
	return true

func snapshot() -> Dictionary:
	return {"enabled":_enabled,"states":_states.size(),"skipped":skipped,"support_queries":support_queries,"support_wakes":support_wakes,"ready_wakes":ready_wakes,"max_skipped_gap_frames":max_gap_frames,"max_skipped_gap_ms":max_gap_ms,"max_delay_ms":MAX_DELAY_MS,"moving_delta_scaled":false}
