extends RefCounted
## Assigned-home movement and bed dwell. No source/actor position or cash writes.
const HomeRoute = preload("npc_home_route58.gd")
const Claims = preload("npc_home_claim58.gd")
const Pose = preload("npc_home_pose58.gd")
const META := "npc_home_registry58"
const RETRY_MS := 1500
const RETRY_WORK_US := 500000
var _life: WeakRef
var _scene: WeakRef
var _host: RefCounted
var _token: Dictionary={}
var _body: CharacterBody3D
var _map:=RID()
var _claims: RefCounted
var _lease: Dictionary={}
var _slot: Dictionary={}
var _visit: RefCounted
var _phase:="IDLE"
var _intent:=""
var _reason:=""
var _serial:=0
var _frame:=-1
var _anchor:=Vector3.ZERO
var _elapsed:=0.0
var _weight:=0.0
var _pose_frames:=0
var _pose_frame:=-1
var _support_current:=false
var _exit_requested:=false
var _exit_retries:=0
var _retry_at:=0
var _total_work_us:=0
var _last_route_id:=0
var _last_route_work:=0

func configure(life: RefCounted, scene: Node3D, map: RID) -> bool:
	if _life!=null or not is_instance_valid(life) or not is_instance_valid(scene): return false
	var token: Dictionary=life.get("_token")
	var body: Variant=token.get("body")
	var host: Variant=life.get("_host")
	if not body is CharacterBody3D or not is_instance_valid(host) or not host.target_current(token): return false
	_life=weakref(life);_scene=weakref(scene);_host=host;_token=token.duplicate();_body=body;_map=map
	_claims=Claims.new();_claims.configure(scene)
	body.tree_exiting.connect(Callable(self,"cancel").bind("body_exiting"))
	return true

func _current() -> bool:
	var life: Variant=_life.get_ref() if _life!=null else null
	return is_instance_valid(life) and not life._disposed and is_instance_valid(_host) and is_instance_valid(_body) and _body.is_inside_tree() and not _body.is_queued_for_deletion() and _host.target_current(_token)

func _registry() -> Variant:
	var scene: Variant=_scene.get_ref() if _scene!=null else null
	var registry: Variant=scene.get_meta(META,null) if is_instance_valid(scene) else null
	return registry if is_instance_valid(registry) and registry.has_method("assigned") and registry.has_method("current") else null

func geometry_current58() -> bool:
	var registry: Variant=_registry()
	return not _slot.is_empty() and registry!=null and bool(registry.current(_slot))

func route_geometry_current58() -> bool:
	var registry: Variant=_registry()
	# A broken mattress wakes its resident but does not invalidate an intact
	# doorway: ordinary safe staging/opening must still precede physical exit.
	return not _slot.is_empty() and registry!=null and registry.has_method("route_current") and bool(registry.route_current(_slot))

func _valid_slot(slot: Dictionary) -> bool:
	if str(slot.get("source_id",""))!=str(_token.get("source_id","")): return false
	for key: String in ["home_id","bed_id","revision"]:
		if not slot.has(key): return false
	for key: String in ["house","door_owner","bed_node","bed_support"]:
		if not slot.get(key) is WeakRef or not is_instance_valid(slot[key].get_ref()): return false
	for key: String in ["door","normal","outside","inner","bed_approach","bed_surface","bed_face","bed_right"]:
		if not slot.get(key) is Vector3 or not Vector3(slot[key]).is_finite(): return false
	return slot.get("bounds") is AABB and Vector3(slot.normal).length()>.9 and Vector3(slot.bed_face).length()>.9

func available() -> bool:
	if not _current(): return false
	var registry: Variant=_registry()
	if registry==null: return false
	var slot: Dictionary=registry.assigned(str(_token.source_id))
	return _valid_slot(slot) and bool(registry.current(slot))

func begin(intent: Dictionary) -> bool:
	if active() or not available() or str(intent.get("kind","")) not in ["home_sleep","home_rest"]: return false
	if intent.has("source_id") and str(intent.source_id)!=str(_token.source_id): return false
	_slot=_registry().assigned(str(_token.source_id))
	_lease=_claims.claim(_slot,_token,self)
	if _lease.is_empty(): _slot={};_reason="assigned_bed_claimed";return false
	_serial+=1;_intent=str(intent.kind);_reason="";_phase="HOME_APPROACH";_frame=-1
	_pose_frames=0;_pose_frame=-1;_elapsed=0;_weight=0;_exit_requested=false;_exit_retries=0
	_total_work_us=0;_last_route_id=0;_last_route_work=0;_support_current=false
	_visit=HomeRoute.new()
	if not _visit.begin_home58(self,_slot,_scene.get_ref(),_body,_map,str(_token.source_id)):
		_finish("home_approach_refused");return false
	return true

func active() -> bool:
	return _phase!="IDLE"

func claim_current58() -> bool:
	return _current() and _claims!=null and _claims.matches(_lease,self,_body)

func claim_alive58(serial: int) -> bool:
	return active() and int(_lease.get("serial",-1))==serial and _current()

func needs_exit() -> bool:
	return active() and _visit!=null and _visit.needs_exit()

func _clear_pose() -> void:
	if not is_instance_valid(_body): return
	var value: Variant=_body.get_meta(Pose.META,{})
	if value is Dictionary and value.get("owner") is WeakRef and value.owner.get_ref()==self: _body.remove_meta(Pose.META)

func request_wake(reason: String) -> bool:
	if not active(): return true
	if _exit_requested: return true
	_reason=reason;_exit_requested=true;_elapsed=0.0
	# A new threat/health owner must never see an active sleep sample.
	_clear_pose()
	if not needs_exit(): _finish(reason);return true
	_phase="HOME_WAKE"
	return true

func _work() -> void:
	if _visit==null or _visit._drive==null or _visit._drive._route==null: return
	var route: RefCounted=_visit._drive._route
	var id: int=route.get_instance_id()
	var work: int=int(route.service_us29)
	_total_work_us+=maxi(0,work-(_last_route_work if id==_last_route_id else 0))
	_last_route_id=id;_last_route_work=work

func _bed_supported() -> bool:
	if not geometry_current58() or not _body.is_on_floor() or _body.global_position.distance_to(_anchor)>.06: return false
	var mattress: Variant=_slot.bed_node.get_ref()
	if not mattress is CollisionObject3D: return false
	var space: PhysicsDirectSpaceState3D=_body.get_world_3d().direct_space_state
	for offset: float in [-.65,0.0,.65]:
		var at: Vector3=Vector3(_slot.bed_surface)+Vector3(_slot.bed_face)*offset
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.10,at-Vector3.UP*.10,1|512,[_body.get_rid()])
		var hit: Dictionary=space.intersect_ray(query)
		if hit.is_empty() or hit.get("collider")!=mattress or Vector3(hit.normal).dot(Vector3.UP)<.95 or absf(Vector3(hit.position).y-at.y)>.04: return false
	return true

func _publish(delta: float) -> void:
	_body.set_meta(Pose.META,{"active":true,"owner":weakref(self),"serial":_serial,"frame":_frame,"delta":delta,"body_id":_body.get_instance_id(),"generation":int(_token.get("life_generation",-1)),"weight":_weight,"bed_surface":_slot.bed_surface,"bed_face":_slot.bed_face,"bed_id":_slot.bed_id})

func _begin_exit() -> bool:
	_work();_clear_pose()
	if _visit.begin_exit(): _phase="HOME_EXIT";return true
	_phase="HOME_BLOCKED";_retry_at=Time.get_ticks_msec()+RETRY_MS
	return false

func step(delta: float, row: Dictionary) -> String:
	if not active(): return "done"
	if not is_finite(delta) or delta<=0.0 or delta>.05: return "active"
	if not _current() or row.get("dead",false) or float(row.get("hp",0.0))<=0.0:
		cancel("life_ended");return "blocked"
	var frame: int=Engine.get_physics_frames()
	if frame==_frame: return "active"
	_frame=frame;_work()
	if not _claims.matches(_lease,self,_body): cancel("home_claim_lost");return "blocked"
	if not geometry_current58() and not _exit_requested: request_wake("home_or_bed_destroyed")
	if not active(): return "done"
	if _phase=="HOME_WAKE":
		_begin_exit()
		return "active"
	if _phase=="HOME_BLOCKED":
		_visit.stand(delta)
		# Retry a transient obstruction while the same monotonic incident work
		# budget remains. Three cheap failures must not permanently lock a home.
		if Time.get_ticks_msec()>=_retry_at and _total_work_us<RETRY_WORK_US:
			_exit_retries+=1;_begin_exit()
		elif _total_work_us>=RETRY_WORK_US:
			_reason="home_exit_work_exhausted58"
		return "blocked"
	if _phase in ["HOME_SETTLE","HOME_SLEEP","HOME_REST"]:
		_visit.stand(delta)
		_support_current=_bed_supported()
		if not _support_current:
			request_wake("live_bed_support_lost");return "active"
		_elapsed+=delta;_weight=minf(1.0,_elapsed/.75)
		_publish(delta)
		if _phase=="HOME_SETTLE":
			if _pose_frames>=8 and _weight>=1.0: _phase="HOME_SLEEP" if _intent=="home_sleep" else "HOME_REST"
			elif _elapsed>3.0: request_wake("native_bed_pose_not_committed")
		return "active"
	var result: String=_visit.step(delta)
	_work()
	if result=="entered":
		_anchor=_body.global_position;_phase="HOME_SETTLE";_elapsed=0;_weight=0;_pose_frames=0
		return "active"
	if result=="exited":
		_finish(_reason if not _reason.is_empty() else "physical_home_exit")
		return "done"
	if result=="blocked":
		_reason=_visit.last_reason()
		if not needs_exit(): _finish(_reason);return "blocked"
		_exit_requested=true;_clear_pose();_phase="HOME_BLOCKED";_retry_at=Time.get_ticks_msec()+RETRY_MS
		return "blocked"
	if _phase!="HOME_EXIT":
		_phase="HOME_BED_APPROACH" if _visit._entered else ("HOME_ENTER" if _visit._leg>=1 else "HOME_APPROACH")
	return "active"

## Host-busy sampling deliberately never calls host.target_current recursively.
func sample_current(value: Dictionary) -> bool:
	return _phase in ["HOME_SETTLE","HOME_SLEEP","HOME_REST"] and _support_current and int(value.get("serial",-1))==_serial and int(value.get("frame",-1))==_frame and int(value.get("generation",-2))==int(_token.get("life_generation",-1)) and _claims.matches(_lease,self,_body) and _body.global_position.distance_to(_anchor)<=.06

func pose_committed(rig: Skeleton3D, value: Dictionary) -> void:
	if not sample_current(value) or rig!=_token.get("rig") or float(value.get("pose_weight",0.0))<.1: return
	_pose_frames+=1;_pose_frame=_frame

func _finish(reason: String) -> void:
	_clear_pose();_work()
	if _visit!=null:
		# Death/replacement may already have handed this body to another owner.
		# Cancel only planner jobs in that case; never zero a new life's velocity
		# or remove its current physical-drive sample through Driver.cancel().
		var life: Variant=_life.get_ref() if _life!=null else null
		var motion_owned: bool=_current() and is_instance_valid(life) and not life._health.should_pause_walk() and reason not in ["life_ended","body_exiting","death","dispose"]
		if motion_owned: _visit.cancel()
		elif _visit._drive!=null:
			if _visit._drive._route!=null: _visit._drive._route.cancel()
			if _visit._drive._guide!=null: _visit._drive._guide.cancel()
		_visit=null
	if _claims!=null: _claims.release(_lease,self)
	_lease={};_slot={};_support_current=false;_phase="IDLE";_reason=reason;_weight=0.0

func cancel(reason: String="cancelled") -> void:
	_finish(reason)

func snapshot() -> Dictionary:
	return {"active":active(),"phase":_phase,"intent":_intent,"reason":_reason,"inside":needs_exit(),"sleeping":_phase=="HOME_SLEEP" and _support_current and _pose_frame==Engine.get_physics_frames(),"claim_current":_claims.matches(_lease,self,_body) if _claims!=null else false,"support_current":_support_current,"pose_committed_frame":_pose_frame,"pose_frames":_pose_frames,"home_id":_slot.get("home_id",""),"bed_id":_slot.get("bed_id",""),"life_generation":_token.get("life_generation",-1),"serial":_serial,"exit_requested":_exit_requested,"exit_retries":_exit_retries,"exit_work_exhausted":_total_work_us>=RETRY_WORK_US,"planning_service_us":_total_work_us,"route":_visit.snapshot() if _visit!=null else {}}
