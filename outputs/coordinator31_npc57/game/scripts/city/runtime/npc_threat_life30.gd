extends RefCounted
const Driver = preload("res://scripts/city/runtime/npc_threat_route30.gd")
const Props = preload("res://scripts/npc_ambient/ambient_props28.gd")
const QUIET_SECONDS := 15.0
const PHONE_SECONDS := 4.0
# DSH_SURRENDER58 (--city-surrender58=1, default off): the web walk raises both
# hands while the player aims at a civilian and keeps them up for 850 ms after the
# last aim sample. The aim observation is already re-delivered every 0.10 s, so the
# same lease works here. The pose channel accepts duration_s in [4,8] only, so the
# gesture is published in one fixed 8 s window whose elapsed time is held just
# before its fade-out while the aim stays fresh.
const AIM_LEASE58 := 0.85
const SURRENDER_WINDOW58 := 8.0
const SURRENDER_FADE58 := .35
const SURRENDER_HOLD58 := SURRENDER_WINDOW58 - SURRENDER_FADE58 - .01
static var _surrender58_flag := -1
static func surrender58_on() -> bool:
	if _surrender58_flag < 0: _surrender58_flag = 1 if OS.get_cmdline_user_args().has("--city-surrender58=1") else 0
	return _surrender58_flag == 1
const RECOVER_RETRY_SECONDS31 := 2.0
const FRESH_OBSERVATION_SECONDS31 := 1.0
const TURN_SPEED31 := 6.0
const PRIORITY := {"visible_weapon":1,"aimed_at":2,"near_shot":3,"actual_hit":4}
var _life: WeakRef
var _world: WeakRef
var _event: Dictionary={}
var _phase := "IDLE"
var _last_observation := -100.0
var _same_tick_events56: Dictionary={} # accepted event identities in one world tick only
var _quiet_until := 0.0
var _age := 0.0
var _driver: RefCounted
var _props: RefCounted
var _start := Vector3.ZERO
var _anchor := Vector3.ZERO
var _attempts := 0
var _pose_frames := 0
var _frame := -1
var _serial := 0
var _owned := false
var _called := false
var _last_result: Dictionary={}
var _reason := ""
var _aim_until := 0.0
var _surrender_age := 0.0
var _surrender_release := -1.0
var _surrender_pose_frames := 0

func active() -> bool:return _phase!="IDLE"

func accept(life: RefCounted, event: Dictionary, world: RefCounted) -> Dictionary:
	if not world.authentic(life,event) or str(event.get("kind","")) not in PRIORITY:return {"accepted":false,"reason":"unproven_observation"}
	var row: Dictionary=life._life()
	if row.is_empty() or life._hospital51_below_threshold(row) or str(life._goal.get("kind",""))=="hospital":return {"accepted":false,"reason":"medical_priority"}
	var record: Dictionary=life._host._records.get(str(life._token.source_id),{})
	var retaliation: RefCounted=record.get("melee_retaliation")
	if retaliation!=null and retaliation.engaged():return {"accepted":false,"reason":"combat_owner"}
	var at: float=float(event.at)
	var previous_kind: String=str(_event.get("kind",""))
	var stronger: bool=int(PRIORITY[event.kind])>int(PRIORITY.get(previous_kind,0))
	var new_violent: bool=event.kind in ["near_shot","actual_hit"] and event.event_id!=_event.get("event_id")
	# Perception and native hit can share a world tick. Preserve stronger/new violence,
	# but reject stale observations and exact same-tick replays.
	var observation_key56: String=str(event.kind)+":"+str(event.event_id)
	if at<_last_observation or (at==_last_observation and (_same_tick_events56.has(observation_key56) or (not stronger and not new_violent))):
		return {"accepted":false,"reason":"not_new_observation"}
	if at>_last_observation:_same_tick_events56.clear()
	# Hard bound for pathological same-tick bursts; normal delivery is far below this.
	if _same_tick_events56.size()>=64:return {"accepted":false,"reason":"same_tick_observation_limit"}
	_same_tick_events56[observation_key56]=true
	var new_incident: bool=event.incident_id!=_event.get("incident_id","")
	var restart: bool=_phase in ["PHONE","RECOVER","SURRENDER58"] and (stronger or new_violent or new_incident)
	if restart:_clear_phone() # Release old reservation before changing incident.
	_life=weakref(life);_world=weakref(world);_last_observation=at;_quiet_until=at+QUIET_SECONDS
	# DSH_SURRENDER58: a fresh aim observation only renews the hands-up lease. The
	# 15 s quiet deadline stays the owner of when the whole fear state ends.
	if event.kind=="aimed_at" and surrender58_on(): _aim_until=maxf(_aim_until,at+AIM_LEASE58)
	# A fresh nearby shot renews fear, but cannot downgrade a recent actual injury.
	if not active() or stronger or event.kind==previous_kind or at-float(_event.get("at",-100.0))>=QUIET_SECONDS:_event=event.duplicate()
	life._attention29.clear()
	var came_from: String=_phase
	if not active():_phase="RELEASE_SERVICE";_age=0.0;_attempts=0;_called=false;_owned=false;_serial+=1
	elif event.kind=="aimed_at" and surrender58_on() and came_from in ["ALERT","FLEE","RECOVER"] and _driver!=null:
		# DSH_SURRENDER58: visibility or a retreat becomes a hold-up the moment the
		# player actually aims at this civilian. The web walk stops the actor on the
		# same condition, so a resident who was only alert or already running halts
		# and raises both hands instead of escaping. This is the fix for the first
		# live run, where the earlier visible_weapon/near_shot observation had already
		# chosen ALERT/FLEE and the stronger aimed_at observation upgraded nothing.
		_driver.cancel()
		_phase="SURRENDER58";_surrender_age=0.0;_surrender_release=-1.0
		_aim_until=maxf(_aim_until,at+AIM_LEASE58)
		print("DSH_SURRENDER58 stage=enter id=",str(life._token.source_id),"from=",came_from,"at_s=","%.2f" % at)
	elif restart:
		_phase="FLEE";_age=0.0;_attempts=0
		# DSH_SURRENDER58: a shot or a new incident always breaks the hold.
		_aim_until=0.0;_surrender_release=-1.0
		if new_incident:_called=false
		if _driver!=null:_driver.cancel()
	return {"accepted":true,"phase":_phase,"quiet_until":_quiet_until}

func _current() -> bool:
	if _life==null or _world==null or not is_instance_valid(_life.get_ref()) or not is_instance_valid(_world.get_ref()):return false
	var life: RefCounted=_life.get_ref()
	return not life._disposed and life._host.target_current(life._token) and _world.get_ref().authentic(life,_event)

func _release_service(life: RefCounted) -> bool:
	life._ambient29_cancel("threat")
	if not life._routine58_release_home("threat"): return false
	if life._economy28_active():life._economy28.request_priority("threat");return false
	if life._restaurant28_active():
		if life._restaurant28_stage not in ["OUTBOUND","EXIT_RETRY"]:
			if life._restaurant28.needs_exit():life._restaurant28_request_exit("threat")
			else:life._restaurant28_finish(false,"threat_before_entry")
		return false
	if life._visit!=null:
		if not life._interrupting:life._visit.cancel("threat");life._interrupting=true
		return false
	if life._roam51!=null:life._roam51.cancel();life._roam51_active=false
	var stopped: Dictionary=life._walk.interrupt_current_route()
	if not stopped.get("ok",false):return false
	var body: CharacterBody3D=life._token.body
	var record: Dictionary=life._host._records[str(life._token.source_id)]
	# Current simple daily routes use 1.8 m/s; legacy paths use this record's speed.
	var ordinary_speed: float=1.8 if life._dsh_simple_on() else float(record.speed)
	_driver=Driver.new()
	if not _driver.configure(body,str(life._token.source_id),ordinary_speed):cancel("physical_driver_unavailable");return false
	_start=body.global_position;_owned=true
	life._goal={};life._phase="THREAT30";life._next_decision=INF
	if _event.kind=="aimed_at" and surrender58_on():
		# DSH_SURRENDER58: the web walk stops the civilian and raises both hands
		# instead of running. A minimum lease from now keeps the gesture visible
		# even when releasing ordinary services took longer than the observation.
		_phase="SURRENDER58";_surrender_age=0.0;_surrender_release=-1.0
		_aim_until=maxf(_aim_until,_world.get_ref()._now+AIM_LEASE58)
	else:
		_phase="ALERT" if _event.kind=="visible_weapon" else "FLEE"
	_age=0.0
	return true

func _start_leg(life: RefCounted) -> bool:
	if _attempts>=3:return false
	var attempt: int=_attempts
	_attempts+=1
	return _driver.begin_escape58(Vector3(_event.escape_from),attempt)

func _recover31() -> void:
	_phase="RECOVER";_age=0.0

func _face_known_threat31(body: CharacterBody3D, delta: float) -> void:
	# Use only the observed point, never the hidden player's live position.
	# Service/physical movement keeps authority over both travel and walking yaw.
	if not bool(_event.get("source_identified",false)) or Vector2(body.velocity.x,body.velocity.z).length_squared()>.01:return
	var facing: Vector3=Vector3(_event.escape_from)-body.global_position
	if facing.is_finite() and Vector2(facing.x,facing.z).length_squared()>.0001:
		# A rigid capsule must stay unit scale. Repeated Euler setters can carry
		# accumulated float scale from the host basis into later route admission.
		var yaw: float=lerp_angle(body.rotation.y,atan2(-facing.x,-facing.z),1.0-exp(-TURN_SPEED31*delta))
		body.basis=Basis(Vector3.UP,yaw)

func step(delta: float, row: Dictionary) -> bool:
	if not active():return false
	if not _current():cancel("life_or_observation_expired");return false
	var life: RefCounted=_life.get_ref()
	if life._hospital51_below_threshold(row) or str(life._goal.get("kind",""))=="hospital":cancel("medical_priority");return false
	var record: Dictionary=life._host._records[str(life._token.source_id)]
	var retaliation: RefCounted=record.get("melee_retaliation")
	if row.get("dead",false) or float(row.get("hp",0))<=0 or row.get("_medicalDowned",false) or row.get("_forcedCrawl",false) or (retaliation!=null and retaliation.engaged()):cancel("health_or_combat_priority");return false
	if life._health.should_pause_walk():
		# A real hit-stagger owns the body temporarily. Keep the fear deadline but
		# stop our planner without zeroing the hit owner's velocity or impulse.
		if _driver!=null:_driver._route.cancel();_driver.status="idle"
		if _phase in ["PHONE","SURRENDER58"]:_clear_phone();_phase="FLEE"
		return false
	if _world.get_ref()._now>=_quiet_until:cancel("quiet_15_seconds");return false
	_age+=delta
	if _phase=="RELEASE_SERVICE":
		# Ordinary owners keep moving until they physically release their services.
		if not _release_service(life):
			_face_known_threat31(life._token.body,delta)
			return false
	var body: CharacterBody3D=life._token.body
	if _phase=="SURRENDER58":
		# DSH_SURRENDER58: the ported web hold-up. The civilian stops, faces the
		# observed threat and keeps both hands up while the aim lease is fresh. The
		# lease is renewed by every accepted aimed_at observation (0.10 s cadence),
		# so lowering the weapon releases the pose after AIM_LEASE58 and one pose
		# fade. A shot never reaches this arm: accept() restarts it as FLEE.
		_driver.hold(delta)
		_face_known_threat31(body,delta)
		_surrender_age+=delta
		if _world.get_ref()._now<_aim_until:_surrender_release=-1.0
		elif _surrender_release<0.0:_surrender_release=_surrender_age
		var elapsed58: float=minf(_surrender_age,SURRENDER_HOLD58)
		if _surrender_release>=0.0:
			# Continue the published window through its own fade-out, then release
			# the life so the resident returns to ordinary decisions.
			elapsed58=minf(_surrender_age,SURRENDER_WINDOW58)
			if _surrender_age-_surrender_release>=SURRENDER_FADE58:
				print("DSH_SURRENDER58 stage=release id=",str(_event.get("source_id","")),"held_s=","%.2f" % _surrender_age)
				cancel("aim_released58");return true
		_frame=Engine.get_physics_frames()
		body.set_meta("npc_ambient28",{"active":true,"owner":weakref(self),"serial":_serial,"frame":_frame,"body_id":body.get_instance_id(),"delta":delta,"kind":"surrender58","elapsed_s":elapsed58,"duration_s":SURRENDER_WINDOW58,"surrender_time_s":_surrender_age})
	elif _phase=="ALERT":
		_driver.hold(delta)
		_face_known_threat31(body,delta)
		if _age>=.8:_phase="FLEE";_age=0.0
	elif _phase=="FLEE":
		if _driver.status=="idle" and not _start_leg(life):_recover31()
		else:
			var result: String=_driver.step(delta)
			if result in ["blocked","arrived"]:
				_driver.cancel()
				var retreat: float=Driver._flat(_start,body.global_position)
				if retreat>=2.0 and not _called and _world.get_ref().reserve_call(life,_event):
					_props=Props.new()
					if _props.begin(life._token.rig,"police_phone30"):_phase="PHONE";_age=0.0;_anchor=body.global_position;_pose_frames=0
					else:_clear_phone();_recover31()
				elif result=="arrived" or _attempts>=3:_recover31()
	elif _phase=="PHONE":
		_driver.hold(delta)
		if body.global_position.distance_to(_anchor)>.05:_clear_phone();_recover31()
		elif _age>=PHONE_SECONDS:
			_last_result=_world.get_ref().finish_call(life,_event,Driver._flat(_start,body.global_position),_pose_frames)
			_called=true;_clear_phone();_recover31()
		else:
			_frame=Engine.get_physics_frames()
			body.set_meta("npc_ambient28",{"active":true,"owner":weakref(self),"serial":_serial,"frame":_frame,"body_id":body.get_instance_id(),"delta":delta,"kind":"police_phone30","elapsed_s":_age,"duration_s":PHONE_SECONDS})
	elif _phase=="RECOVER":
		_driver.hold(delta)
		_face_known_threat31(body,delta)
		# Continuing visibility must not pin a frightened resident in one place.
		# Retry bounded physical retreat after a short rest only while observation
		# is fresh. Without renewed evidence the existing quiet deadline releases.
		if _age>=RECOVER_RETRY_SECONDS31 and _world.get_ref()._now-_last_observation<=FRESH_OBSERVATION_SECONDS31:
			_driver.cancel();_phase="FLEE";_age=0.0;_attempts=0
	life._dsh_energy_drain();life._dsh_resdiag_step(row)
	return true

func sample_current(value: Dictionary) -> bool:
	if _life==null or not is_instance_valid(_life.get_ref()):return false
	var body: CharacterBody3D=_life.get_ref()._token.body
	if value.get("kind")=="surrender58":
		# DSH_SURRENDER58: no prop and no anchor, only this exact published frame.
		return _phase=="SURRENDER58" and is_instance_valid(body) and int(value.get("serial",-1))==_serial and int(value.get("frame",-1))==_frame
	if _phase!="PHONE":return false
	return is_instance_valid(body) and value.get("kind")=="police_phone30" and int(value.get("serial",-1))==_serial and int(value.get("frame",-1))==_frame and body.global_position.distance_to(_anchor)<=.05

func pose_committed(rig: Skeleton3D, value: Dictionary) -> void:
	if str(value.get("kind",""))=="surrender58":
		# DSH_SURRENDER58 proof: the resident host calls this only after it accepted
		# our published gesture for this exact physics frame and wrote the composed
		# bones to the skeleton. A non-zero count is therefore "hands really went up".
		if sample_current(value) and _life!=null and is_instance_valid(_life.get_ref()) and rig==_life.get_ref()._token.rig and float(value.get("pose_weight",0))>.01:
			_surrender_pose_frames+=1
		return
	if _props==null:return
	if not sample_current(value) or rig!=_life.get_ref()._token.rig or float(value.get("pose_weight",0))<=.01:_props.hide();return
	_pose_frames+=1;_props.sync_after_pose(rig,"police_phone30")

func pose_suppressed() -> void:
	if _props!=null:_props.hide()

func _clear_phone() -> void:
	if _props!=null:_props.clear();_props=null
	if _life!=null and is_instance_valid(_life.get_ref()):
		var life: RefCounted=_life.get_ref()
		if _world!=null and is_instance_valid(_world.get_ref()):_world.get_ref().release_call(life,_event)
		var body: Variant=life._token.get("body")
		if is_instance_valid(body):
			var value: Dictionary=body.get_meta("npc_ambient28",{})
			if value.get("owner") is WeakRef and value.owner.get_ref()==self:body.remove_meta("npc_ambient28")

func cancel(reason: String="cancelled") -> void:
	_clear_phone()
	if _driver!=null:_driver.cancel();_driver=null
	if _owned and _life!=null and is_instance_valid(_life.get_ref()):
		var life: RefCounted=_life.get_ref()
		if life._phase=="THREAT30":life._phase="IDLE";life._goal={};life._next_decision=life._now
	_owned=false;_phase="IDLE";_reason=reason
	_aim_until=0.0;_surrender_release=-1.0

func snapshot() -> Dictionary:
	return {"phase":_phase,"kind":_event.get("kind",""),"incident_id":_event.get("incident_id",""),"quiet_until":_quiet_until,"last_observation":_last_observation,"reason":_reason,"attempts":_attempts,"pose_frames":_pose_frames,"report":_last_result,"driver":_driver.snapshot() if _driver!=null else {},"normal_speed_unchanged":true,
		"surrender58":surrender58_on(),"aim_until":_aim_until,"surrender_age_s":_surrender_age,"surrender_release_s":_surrender_release,"surrender_pose_frames":_surrender_pose_frames,
		"aim_lease_ms":maxf(0.0,(_aim_until-_world.get_ref()._now)*1000.0) if (_world!=null and is_instance_valid(_world.get_ref())) else 0.0}
