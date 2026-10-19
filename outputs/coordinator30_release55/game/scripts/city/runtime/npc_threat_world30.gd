extends RefCounted
## Native, bounded perception. This owns observations, never HP or police actors.
const META := "npc_threat_world30"
const MAX_PENDING := 128
const MAX_RECORDS := 256
const MAX_ISSUED := 2048 # Four threat kinds per current owner; bounded for the full 288 catalogue.
const SENSE_INTERVAL := .10
const FOV_DOT := .3420201433
const SHOT_RADIUS := 41.0
const CLOSE_HEARING := 18.45
const VISIBLE_RADIUS := 28.7
const LOS_MASK := 5 | 256
var _weapons: WeakRef
var _population: WeakRef
var _report_port := Callable()
var _pending: Array[Dictionary] = []
var _shot_jobs30: Array[Dictionary] = []
const MAX_SHOT_JOBS30 := 8
const SHOT_TTL30 := 4.0
var _issued: Dictionary = {}
var _calls: Dictionary = {}
var _seen_hits: Dictionary = {}
var _seen_shots: Dictionary = {}
var _now := 0.0
var _sense_at := 0.0
var _cleanup_at := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _los_left := 0
var _burst := ""
var _burst_at := -100.0
var _burst_origin := Vector3.ZERO
var _weapon := "none"
var _display_serial := 0
var _serial := 0
var _disposed := false
var _stats := {"shots":0,"observed":0,"delivered":0,"los_queries":0,"aim_queries":0,"queue_drops":0,"stale":0,"reports_completed":0,"reports_accepted":0,"dispatch_unavailable":0,"max_pending":0,"coalesced_shots":0,"max_step_us":0,"raw_queue_drops":0,"raw_expired":0,"raw_empty_retries":0,"raw_batches":0,"max_raw_jobs":0,"los_deferred":0}

func configure(weapons: Node, population: RefCounted, report_port: Callable=Callable()) -> Dictionary:
	if _weapons!=null or _disposed or not is_instance_valid(weapons) or not is_instance_valid(population):return {"ok":false,"reason":"owners"}
	for method: String in ["query_near30","health_from_body30","incident_game_paused"]:
		if not population.has_method(method):return {"ok":false,"reason":"population_port:"+method}
	if not weapons.has_signal("shot_emitted"):return {"ok":false,"reason":"committed_shot_signal"}
	_weapons=weakref(weapons);_population=weakref(population);_report_port=report_port
	_ray.collision_mask=LOS_MASK;_ray.hit_from_inside=true
	weapons.shot_emitted.connect(_on_shot)
	weapons.get_tree().current_scene.set_meta(META,self)
	return {"ok":true,"source":"native_weapon_and_health_owners","police_dispatch_connected":_report_port.is_valid(),"spatial_query_required":true}

func _current() -> bool:
	return not _disposed and _weapons!=null and _population!=null and is_instance_valid(_weapons.get_ref()) and is_instance_valid(_population.get_ref())

func _observation(owner: RefCounted) -> Dictionary:
	if not is_instance_valid(owner) or not owner.has_method("incident_witness_snapshot"):return {}
	var row: Dictionary=owner.incident_witness_snapshot()
	if row.get("role_scope")!="ordinary_unarmed_civilian" or not row.get("eligible",false):return {}
	return row

func _on_shot(shot: Dictionary, muzzle: Dictionary, _camera: Vector3, _direction: Vector3) -> void:
	if not _current() or _population.get_ref().incident_game_paused():return
	var shot_id: String=str(shot.get("shotId",""))
	var origin: Variant=muzzle.get("origin")
	if shot_id.is_empty() or not origin is Vector3 or not origin.is_finite() or not shot.get("projectiles") is Array:return
	if _seen_shots.has(shot_id):return
	_remember(_seen_shots,shot_id,_now)
	if _now-_burst_at>1.5 or origin.distance_to(_burst_origin)>4.0:
		_serial+=1;_burst="gunfire:%s:%d"%[_weapons.get_ref().get_instance_id(),_serial];_burst_origin=origin
	_burst_at=_now;_stats.shots+=1
	# Keep the actual shot independently of spatial budget. Empty means retry,
	# never no witnesses. An automatic burst updates one bounded incident job.
	for job: Dictionary in _shot_jobs30:
		if job.incident_id==_burst:
			job.event_id="shot:"+shot_id;job.origin=origin;job.weapon=str(shot.get("weaponId",""));job.expires=_now+SHOT_TTL30
			_stats.coalesced_shots+=1;return
	if _shot_jobs30.size()>=MAX_SHOT_JOBS30:_stats.raw_queue_drops+=1;return
	_shot_jobs30.append({"origin":origin,"event_id":"shot:"+shot_id,"incident_id":_burst,"weapon":str(shot.get("weaponId","")),"expires":_now+SHOT_TTL30,"seen":{}})
	_stats.max_raw_jobs=maxi(_stats.max_raw_jobs,_shot_jobs30.size())

func _pump_shots30() -> void:
	for index: int in range(_shot_jobs30.size()-1,-1,-1):
		if _shot_jobs30[index].expires<_now:_shot_jobs30.remove_at(index);_stats.raw_expired+=1
	if _shot_jobs30.is_empty():return
	var job: Dictionary=_shot_jobs30.pop_front()
	# Process no more witnesses than the delivery lane can consume this tick.
	var capacity: int=mini(16,MAX_PENDING-_pending.size())
	if capacity<=0:_shot_jobs30.append(job);return
	var nearby: Array=_population.get_ref().query_near30(job.origin,SHOT_RADIUS,capacity,128,"shot")
	_stats.raw_batches+=1
	if nearby.is_empty():_stats.raw_empty_retries+=1
	for candidate: Dictionary in nearby:
		var owner: RefCounted=candidate.get("health")
		var observation: Dictionary=_observation(owner)
		if observation.is_empty():continue
		var owner_key: String=str(owner.get_instance_id())
		if job.seen.get(owner_key,"")==job.event_id:continue
		var queued := false
		for pending: Dictionary in _pending:
			if pending.owner_id==owner.get_instance_id() and pending.incident_id==job.incident_id:queued=true;break
		if queued:continue
		_remember(job.seen,owner_key,job.event_id,512)
		_pending.append({"owner_id":owner.get_instance_id(),"owner":weakref(owner),"observation":observation,"origin":job.origin,"event_id":job.event_id,"incident_id":job.incident_id,"weapon":job.weapon,"expires":job.expires})
	_stats.max_pending=maxi(_stats.max_pending,_pending.size())
	# Cursor progress is opaque. Retain until TTL instead of mistaking an empty
	# or duplicate batch for a complete spatial scan. All storage stays bounded.
	_shot_jobs30.append(job)

static func in_fov(observation: Dictionary, target: Vector3) -> bool:
	var toward: Vector3=target-Vector3(observation.position);toward.y=0.0
	var forward: Vector3=observation.forward;forward.y=0.0
	return toward.length_squared()<=.16 or (forward.length_squared()>.0001 and forward.normalized().dot(toward.normalized())>=FOV_DOT)

func _line_clear(observation: Dictionary, target: Vector3) -> bool:
	if _los_left<=0:return false
	var body: CharacterBody3D=observation.body
	if not is_instance_valid(body):return false
	_los_left-=1;_stats.los_queries+=1
	_ray.from=Vector3(observation.position)+Vector3.UP*1.35;_ray.to=target
	_ray.exclude=[body.get_rid(),_weapons.get_ref().player.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

func _same(observed: Dictionary, current: Dictionary) -> bool:
	return not current.is_empty() and observed.owner_instance_id==current.owner_instance_id and observed.body_instance_id==current.body_instance_id and observed.life_generation==current.life_generation and observed.session_id==current.session_id

func _deliver(owner: RefCounted, observation: Dictionary, kind: String, incident: String, event_id: String, origin: Vector3, identified: bool, weapon: String="") -> void:
	var pop: RefCounted=_population.get_ref()
	var life: RefCounted=pop.daily._lives.get(str(observation.source_id)) if pop.daily!=null else null
	if life==null or life._health!=owner or not life.has_method("threat_event30"):return
	var event: Dictionary={"schema":"native_threat30/v1","kind":kind,"incident_id":incident,"event_id":event_id,"owner_id":owner.get_instance_id(),"body_id":observation.body_instance_id,"source_id":observation.source_id,"generation":observation.life_generation,"session_id":observation.session_id,"escape_from":origin,"source_identified":identified,"weapon_id":weapon if identified else "","at":_now,"expires":_now+60.0}
	var key: String="%d:%s"%[owner.get_instance_id(),kind]
	_remember(_issued,key,event,MAX_ISSUED)
	_stats.observed+=1
	var result: Dictionary=life.threat_event30(event,self)
	if result.get("accepted",false):
		_stats.delivered+=1
		if pop.daily.has_method("wake_physical30"):pop.daily.wake_physical30(str(observation.source_id))

func authentic(life: RefCounted, event: Dictionary) -> bool:
	if not _current() or not is_instance_valid(life) or life._health==null:return false
	var key: String="%d:%s"%[life._health.get_instance_id(),str(event.get("kind",""))]
	if not _issued.has(key) or _issued[key]!=event or float(event.get("expires",0))<_now:return false
	var observation: Dictionary=_observation(life._health)
	return not observation.is_empty() and int(event.body_id)==int(observation.body_instance_id) and int(event.generation)==int(observation.life_generation) and str(event.session_id)==str(observation.session_id)

func confirmed_hit(life: RefCounted) -> void:
	if not _current() or not is_instance_valid(life) or life._health==null:return
	var owner: RefCounted=life._health
	var result: Dictionary=owner.last_result
	var event_id: String=str(result.get("event_id",""))
	if event_id.is_empty() or not result.get("applied",false) or result.get("hit",{}).is_empty() or _seen_hits.has(event_id):return
	var observation: Dictionary=_observation(owner)
	if observation.is_empty():return
	_remember(_seen_hits,event_id,_now)
	var origin: Vector3=owner._last_player
	var incident: String=_burst if _now-_burst_at<1.5 else "hit:"+event_id
	_deliver(owner,observation,"actual_hit",incident,event_id,origin,true,str(result.hit.get("weapon_id","")))

func _sense_weapon() -> void:
	var weapons: Node=_weapons.get_ref()
	var visible: bool=weapons.armed() and weapons._owner_current() and weapons.player._pose_authority==&"on_foot" and not bool(weapons.scene.get("preview_dead")) and not bool(weapons.scene.get("preview_physics_fault"))
	visible=visible and weapons.presentation!=null and is_instance_valid(weapons.presentation._visual) and weapons.presentation._visual.is_visible_in_tree()
	var weapon: String=str(weapons.fire_state.get("weaponId","none")) if visible else "none"
	if weapon!=_weapon:_weapon=weapon;_display_serial+=1
	if weapon=="none":return
	var player: CharacterBody3D=weapons.player
	var origin: Vector3=player.global_position+Vector3.UP*1.1
	var incident: String="weapon:%d:%d"%[weapons.get_instance_id(),_display_serial]
	var aimed_owner: RefCounted
	if bool(weapons._aiming):
		var camera: Camera3D=player.get_preview_camera()
		_stats.aim_queries+=1
		var hit: Dictionary=weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":VISIBLE_RADIUS})
		var body: Node=hit.get("collider")
		for depth: int in 4:
			if body==null or body is CharacterBody3D:break
			body=body.get_parent()
		if body is CharacterBody3D:aimed_owner=_population.get_ref().health_from_body30(body)
		var observed: Dictionary=_observation(aimed_owner)
		if not observed.is_empty() and in_fov(observed,origin) and _line_clear(observed,origin):
			_deliver(aimed_owner,observed,"aimed_at",incident,"aim:"+incident,origin,true,weapon)
	if _los_left<=0:return
	var nearby: Array=_population.get_ref().query_near30(origin,VISIBLE_RADIUS,_los_left,64,"perception")
	for candidate: Dictionary in nearby:
		if _los_left<=0:break
		var owner: RefCounted=candidate.get("health")
		if owner==aimed_owner:continue
		var observed: Dictionary=_observation(owner)
		if observed.is_empty() or not in_fov(observed,origin):continue
		if _line_clear(observed,origin):_deliver(owner,observed,"visible_weapon",incident,"visible:"+incident,origin,true,weapon)

func step(delta: float) -> void:
	if not _current() or not is_finite(delta) or delta<=0 or delta>.1 or _population.get_ref().incident_game_paused():return
	var started: int=Time.get_ticks_usec()
	_now+=delta
	if _now+.000001>=_sense_at:
		_sense_at=_now+SENSE_INTERVAL;_los_left=2
		_pump_shots30()
		# Shots have priority but are time sliced; automatic fire cannot restart actors.
		for count: int in mini(16,_pending.size()):
			var pending: Dictionary=_pending.pop_front()
			var owner: RefCounted=pending.owner.get_ref()
			var observed: Dictionary=_observation(owner)
			if pending.expires<_now or not _same(pending.observation,observed):_stats.stale+=1;continue
			var distance: float=Vector3(pending.observation.position).distance_to(pending.origin)
			if distance>CLOSE_HEARING and _los_left<=0:
				# This is unknown visibility, not a blocked ray. Keep the exact
				# captured witness until its actual LOS turn, life change or TTL.
				_pending.append(pending);_stats.los_deferred+=1;continue
			var clear: bool=_line_clear(pending.observation,pending.origin) if _los_left>0 else false
			var visual: bool=clear and in_fov(pending.observation,pending.origin)
			if visual or distance<=CLOSE_HEARING:
				_deliver(owner,observed,"near_shot",pending.incident_id,pending.event_id,pending.origin,visual,pending.weapon)
			elif clear:
				_deliver(owner,observed,"near_shot",pending.incident_id,pending.event_id,pending.origin,false)
		_sense_weapon()
	if _now>=_cleanup_at:
		_cleanup_at=_now+1.0
		for key: String in _issued.keys():
			if _issued[key].expires<_now:_issued.erase(key)
		for key: String in _calls.keys():
			if _calls[key].expires<_now:_calls.erase(key)

	_stats.max_step_us=maxi(_stats.max_step_us,Time.get_ticks_usec()-started)

func reserve_call(life: RefCounted, event: Dictionary) -> bool:
	if not authentic(life,event):return false
	var key: String=str(event.incident_id)
	if _calls.has(key):return int(_calls[key].owner_id)==life.get_instance_id() and not _calls[key].completed
	var active := 0
	for row: Dictionary in _calls.values():
		if not row.completed:active+=1
	if active>=2:return false
	_remember(_calls,key,{"owner_id":life.get_instance_id(),"completed":false,"expires":_now+8.0})
	return true

func release_call(life: RefCounted, event: Dictionary) -> void:
	var key: String=str(event.get("incident_id",""))
	if _calls.has(key) and int(_calls[key].owner_id)==life.get_instance_id() and not _calls[key].completed:_calls.erase(key)

func finish_call(life: RefCounted, event: Dictionary, retreat_m: float, pose_frames: int) -> Dictionary:
	var key: String=str(event.get("incident_id",""))
	if not authentic(life,event) or not _calls.has(key) or _calls[key].completed or int(_calls[key].owner_id)!=life.get_instance_id() or retreat_m<2.0 or pose_frames<8:return {"accepted":false,"reason":"call_proof_or_lifetime"}
	_calls[key].completed=true;_calls[key].expires=_now+60.0;_stats.reports_completed+=1
	var report: Dictionary={"schema":"native_police_report30/v1","report_id":"call:"+key,"incident_id":key,"kind":event.kind,"witness_source_id":event.source_id,"witness_generation":event.generation,"witness_session_id":event.session_id,"witness_body_id":event.body_id,"observed_scene_instance_id":_weapons.get_ref().get_tree().current_scene.get_instance_id(),"accepted_time_ms":_now*1000.0,"source_identified":event.source_identified,"weapon_id":event.weapon_id,"crime_position":event.escape_from if event.source_identified else null,"retreat_m":retreat_m,"committed_phone_frames":pose_frames,"call_completed":true}
	var result: Dictionary={"accepted":false,"reason":"dispatch_unavailable","report":report,"police_arrival":false}
	if _report_port.is_valid():
		var response: Variant=_report_port.call(report)
		if response is Dictionary and response.get("accepted",false) and not str(response.get("case_id","")).is_empty():result={"accepted":true,"case_id":response.case_id,"report":report,"police_arrival":false};_stats.reports_accepted+=1
	if not result.accepted:_stats.dispatch_unavailable+=1
	_calls[key]["result"]=result
	return result

func _remember(book: Dictionary, key: String, value: Variant, cap: int=MAX_RECORDS) -> void:
	if not book.has(key) and book.size()>=cap:book.erase(book.keys()[0])
	book[key]=value

func snapshot() -> Dictionary:
	var value: Dictionary=_stats.duplicate()
	value.merge({"raw_jobs":_shot_jobs30.size(),"pending":_pending.size(),"issued":_issued.size(),"calls":_calls.size(),"seen_hits":_seen_hits.size(),"seen_shots":_seen_shots.size(),"native_police_dispatch":_report_port.is_valid(),"all_npc_scan":false})
	return value

func dispose() -> void:
	if _current():
		var weapons: Node=_weapons.get_ref()
		if weapons.shot_emitted.is_connected(_on_shot):weapons.shot_emitted.disconnect(_on_shot)
		# Main scene may dispose us after the weapon child already left the tree.
		if weapons.is_inside_tree():
			var scene: Node=weapons.get_tree().current_scene
			if is_instance_valid(scene) and scene.get_meta(META,null)==self:scene.remove_meta(META)
	_disposed=true;_shot_jobs30.clear();_pending.clear();_issued.clear();_calls.clear();_seen_hits.clear();_seen_shots.clear();_report_port=Callable();_weapons=null;_population=null
