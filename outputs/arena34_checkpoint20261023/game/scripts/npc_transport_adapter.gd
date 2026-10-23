extends RefCounted
## Isolated native handoff candidate. The existing vehicle owner creates one
## instance after explicitly granting its unoccupied new-session factory car.
## This does not import ownership or implement an autonomous road planner.
const Runtime = preload("res://scripts/transport/transport_runtime.gd")
const OccupantPose = preload("res://scripts/vehicle_visual/vehicle_occupant_pose.gd")
const Driver = preload("npc_native_trip_driver.gd")
const DoorGuard = preload("npc_vehicle_door_guard.gd")
const SEAT := "front_left"
var _owner: WeakRef
var _host: RefCounted
var _binding: Dictionary
var _serial := 0
var _actor: Dictionary
var _vehicle: Dictionary
var _runtime: Node3D
var _phase := "NEW"
var _reason := ""
var _interaction := ""
var _pose: RefCounted
var _motion: Node3D
var _old_meta := {}
var _cancel_requested := false
var _exit_requested := false
var _control := {}
var _last_clock := -1
var _door := 0.0
var _registered := false
var _had_movement := false
var _events: Array[String] = []
var _driver: RefCounted
var _door_guard: RefCounted

func configure(owner: Node3D, host: RefCounted, binding: Dictionary, activity_owner: RefCounted = null) -> Dictionary:
	if _phase!="NEW" or not Thread.is_main_thread() or not is_instance_valid(owner) or not owner.ready_for_play or owner.phase!="ON_FOOT": return _fail("owner_not_on_foot")
	if not is_instance_valid(host) or not host.has_method("acquire_transport_body") or not host.target_current(binding) or binding.get("source_id")=="player": return _fail("current_original_resident_required")
	var session: Dictionary=owner.runtime.host.diagnostics().session
	if session.get("mode")!="NEW_SESSION_BOOTSTRAP": return _fail("imported_source_authority_required")
	var record: Dictionary=owner.runtime.host.vehicle_record(owner._vehicle_ref)
	if record.get("birth",{}).get("kind")!="SOURCE_NEW_SESSION_FACTORY" or not owner.runtime.host.driver(owner._vehicle_ref).is_empty() or owner.body.linear_velocity.length()>.05: return _fail("unoccupied_factory_car_required")
	for occupant: Variant in record.get("seats",{}).values():
		if occupant!=null: return _fail("occupied_vehicle")
	if not owner.token.is_empty() or owner.runtime.host.diagnostics().leases!=0: return _fail("active_transport_claim")
	if binding.body.get_world_3d()!=owner.body.get_world_3d() or binding.body.global_position.distance_to(owner.approach(SEAT))>.25: return _fail("walk_to_actual_driver_door_first")
	_owner=weakref(owner);_host=host;_binding=binding.duplicate();_vehicle=owner._vehicle_ref.duplicate()
	_actor={"actor_id":binding.source_id,"life_generation":binding.life_generation}
	_door_guard=DoorGuard.new()
	if not _door_guard.configure(owner): return _fail("source_door_geometry_required")
	if not _door_guard.clear(binding.body,owner.body,owner.approach(SEAT),owner._seat_position(SEAT)): return _fail("current_source_square_door_corridor_blocked")
	var pose_binding: Dictionary=host.walking_pose_binding(_binding)
	_pose=OccupantPose.new()
	if pose_binding.is_empty() or not _pose.configure(pose_binding.rig,pose_binding.motion,pose_binding.rest,pose_binding.scale):
		return _fail("original_rig_pose_binding")
	_motion=pose_binding.motion
	# The registered identity is the original resident ID, never ACTOR/player.
	for key: String in ["actor_id","life_generation"]:
		_old_meta[key]={"present":binding.body.has_meta(key),"value":binding.body.get_meta(key) if binding.body.has_meta(key) else null}
		if _old_meta[key].present and _old_meta[key].value!=_actor[key]:
			return _fail("foreign_actor_metadata")
	var acquired: Dictionary=host.acquire_transport_body(self,_binding,activity_owner)
	if not acquired.get("ok",false): return _fail(str(acquired.get("reason")))
	_serial=acquired.serial
	for key: String in _actor: binding.body.set_meta(key,_actor[key])
	# This per-NPC runtime shares the ONE logical host/roster, but owns a generic
	# physical transition provider. It never borrows player's ragdoll controller.
	_runtime=Runtime.new();owner.add_child(_runtime)
	_runtime.host=owner.runtime.host;_runtime.catalog=owner.runtime.catalog
	_runtime.actor_transition.configure(_runtime.access)
	_runtime.initialized=owner.runtime.initialized
	if not _publish_actor(true): return _setup_failed("actor_roster_registration")
	_registered=true
	# Registration advanced the shared owner clock, so this is the single native
	# sync for that new clock. Later ticks use the existing owner's earlier sync.
	if _runtime.sync_native_vehicle_pose(_vehicle,owner.body,owner._clock).get("code")!="OK": return _setup_failed("native_body_binding")
	_phase="OPENING";_events.append("REGISTERED")
	return {"ok":true,"actor":_actor.duplicate(),"vehicle":_vehicle.duplicate(),"serial":_serial,"phase":_phase}

func active() -> bool:
	return _phase not in ["NEW","FAILED","DONE","RETIRED"]

func state() -> Dictionary:
	var driver_state: Dictionary=_driver.snapshot() if _driver!=null else {}
	var blocked: bool=_phase in ["FAILED","RETIRED"] or (_phase=="SEATED" and driver_state.get("status")=="BLOCKED")
	return {"phase":_phase,"status":"BLOCKED" if blocked else _phase,"released":_phase=="DONE","reason":driver_state.get("reason",_reason) if blocked and _reason.is_empty() else _reason,"actor":_actor.duplicate(),"vehicle":_vehicle.duplicate(),"serial":_serial,"events":_events.duplicate(),"driver":driver_state,"source_original_agenda":false,"autonomous_road_route":_driver!=null}

func drive_to(route_path: String, expected_sha256: String) -> Dictionary:
	if not driver_current() or _driver!=null or _cancel_requested or _exit_requested: return {"ok":false,"reason":"current_idle_driver_required"}
	var candidate:=Driver.new()
	var result: Dictionary=candidate.configure(self,_owner.get_ref(),route_path,expected_sha256)
	if result.get("ok",false): _driver=candidate;_events.append("AUTO_DRIVE_STARTED")
	return result

func _owner_current() -> bool:
	var owner: Node3D=_owner.get_ref() if _owner!=null else null
	if not is_instance_valid(owner) or not owner.ready_for_play or owner._npc_trip!=self or not is_instance_valid(owner.body) or owner.body.is_queued_for_deletion(): return false
	if owner._vehicle_ref!=_vehicle or owner.body.get_meta("vehicle_id","")!=_vehicle.vehicle_id or owner.body.get_meta("life_generation",0)!=_vehicle.life_generation: return false
	if _runtime==null or not is_instance_valid(_runtime) or _runtime.host!=owner.runtime.host: return false
	var session: Dictionary=owner.runtime.host.diagnostics().session
	return session.get("session_id")==owner._session.session_id and session.get("session_generation")==owner._session.session_generation

func _current() -> bool:
	return _owner_current() and _host.transport_body_current(self,_binding,_serial) and _binding.body.get_meta("actor_id","")==_actor.actor_id and _binding.body.get_meta("life_generation",0)==_actor.life_generation

func driver_current() -> bool:
	if not _current() or _phase!="SEATED": return false
	return _runtime.host.driver(_vehicle)==_actor

## Called by the trusted scene owner/road producer, not by a source dictionary.
## One next-tick command only; missing/frozen producer means brake, not throttle.
func submit_control(throttle: float, steering: float, brake: float, handbrake: bool) -> bool:
	if not driver_current() or _cancel_requested or _exit_requested: return false
	if not is_finite(throttle) or not is_finite(steering) or not is_finite(brake): return false
	var owner: Node3D=_owner.get_ref()
	_control={"throttle":clampf(throttle,-1,1),"steering":clampf(steering,-1,1),"brake":clampf(brake,0,1),"handbrake":handbrake,"sequence":owner._sequence+1}
	return true

func request_exit() -> bool:
	if not driver_current(): return false
	_exit_requested=true;_control={};return true

func cancel() -> bool:
	if not _current(): return false
	_cancel_requested=true;_control={}
	# Mid-boarding cancellation completes the physical entry, then exits. It
	# never releases a walking capsule in the middle of the car's body.
	return true

func door_amount(seat_id: String) -> float:
	return _door if seat_id==SEAT and active() else 0.0

## Sole caller: existing preview_transport physics tick, after its native pose
## sync and using that owner's clock/sequence. No independent body tick exists.
func tick(delta: float) -> void:
	if not active(): return
	if not _current(): _retire("life_or_owner_changed");return
	var owner: Node3D=_owner.get_ref()
	var clock: int=owner._clock
	if clock<=_last_clock or not is_finite(delta) or delta<=0 or delta>.05: return
	_last_clock=clock
	if _cancel_requested and _phase in ["OPENING","HOLDING"]:
		if not _interaction.is_empty(): _runtime.cancel_interaction(_interaction);_interaction=""
		_finish_walking();return
	if _phase in ["OPENING","HOLDING","BOARDING","EXIT_HOLD","EXITING"]:
		if not _door_guard.clear(_binding.body,owner.body,owner.approach(SEAT),owner._seat_position(SEAT)):
			owner.body.submit_authoritative_control(0,0,1,true,owner._sequence,_vehicle.vehicle_id,_vehicle.life_generation,clock)
			_reason="current_source_square_door_corridor_blocked";return
	# Entry/exit reservation owns brake too, so player neutral input cannot race.
	var command: Dictionary={"throttle":0.0,"steering":0.0,"brake":1.0,"handbrake":true}
	if driver_current() and not _cancel_requested and not _exit_requested and _control.get("sequence",-1)==owner._sequence: command=_control
	if _driver!=null and driver_current() and not _cancel_requested and not _exit_requested:
		command=_driver.command(delta)
		if _driver.snapshot().status=="PARKED": _exit_requested=true;_events.append("ACTUAL_BAY_PARKED")
	_control={}
	if not owner.body.submit_authoritative_control(command.throttle,command.steering,command.brake,command.handbrake,owner._sequence,_vehicle.vehicle_id,_vehicle.life_generation,clock):
		_reason="vehicle_control_refused";return
	if _phase=="OPENING":
		if _cancel_requested: _finish_walking();return
		_door=move_toward(_door,1.0,delta*2.0)
		# Require the actual previous-frame visible door to have reached its pose.
		if _door<1.0 or owner._door_amounts.get(SEAT,0.0)<.999: return
		var begun: Dictionary=_runtime.begin_board(_actor,_vehicle,SEAT,clock,_binding.body.global_position,true,[_binding.body.get_rid(),owner.body.get_rid()])
		if begun.get("code")!="HOLDING": _reason="begin_board:"+str(begun.get("code"));return
		_interaction=begun.token;_phase="HOLDING";_events.append("HOLDING")
	elif _phase in ["HOLDING","EXIT_HOLD"]:
		if _cancel_requested and _phase=="HOLDING":
			_runtime.cancel_interaction(_interaction);_interaction="";_finish_walking();return
		if _phase=="EXIT_HOLD": _follow_seat()
		var held: Dictionary=_runtime.advance_interaction(_interaction,true,clock,_binding.body.global_position,owner._door_amounts.get(SEAT,0.0)>=.999,[_binding.body.get_rid(),owner.body.get_rid()])
		if held.get("code")=="TRANSITION_REQUIRED":
			if _phase=="EXIT_HOLD" and not _host.set_transport_seated(self,_binding,_serial,false): _retire("exit_body_owner_changed");return
			var started: Dictionary=_runtime.begin_actor_transition(_interaction,clock,_binding.body,owner.body)
			if started.get("code")!="ACTIVE":
				_runtime.cancel_interaction(_interaction);_interaction="";_reason="transition:"+str(started.get("code"))
				if _phase=="EXIT_HOLD": _host.set_transport_seated(self,_binding,_serial,true);_phase="SEATED"
				else: _phase="OPENING"
				return
			_phase="BOARDING" if _phase=="HOLDING" else "EXITING";_events.append(_phase)
		elif held.get("code")!="HOLDING":
			_reason="hold:"+str(held.get("code"));_interaction="";_phase="OPENING" if _phase=="HOLDING" else "SEATED"
	elif _phase in ["BOARDING","EXITING"]:
		var before: Vector3=_binding.body.global_position
		var advanced: Dictionary=_runtime.advance_actor_transition(_interaction,delta,clock)
		_had_movement=_had_movement or _binding.body.global_position.distance_to(before)>.000001
		var pose_state: Dictionary=advanced.get("physical",advanced).get("pose",{})
		if not pose_state.is_empty(): _apply_pose(pose_state,delta)
		if advanced.get("code")=="BOARDED":
			if _runtime.host.driver(_vehicle)!=_actor or not _host.set_transport_seated(self,_binding,_serial,true): _retire("boarded_occupant_or_body_changed");return
			_interaction="";_phase="SEATED";_events.append("BOARDED");_follow_seat()
		elif advanced.get("code")=="EXITED":
			_interaction="";_phase="RELEASING";_events.append("EXITED");_finish_walking()
		elif advanced.get("code") not in ["ACTIVE","BLOCKED"]: _reason="transition:"+str(advanced.get("code"))
		elif advanced.get("code")=="BLOCKED": _reason="physical_transition_blocked"
	elif _phase=="SEATED":
		if _runtime.host.driver(_vehicle)!=_actor: _retire("seat_ownership_changed");return
		_follow_seat();_apply_pose({"fold":1.0,"phase":"SEATED"},delta)
		_door=move_toward(_door,1.0 if _exit_requested or _cancel_requested else 0.0,delta*2.0)
		if (_exit_requested or _cancel_requested) and owner.body.linear_velocity.length()<=.05 and _door>=1.0 and owner._door_amounts.get(SEAT,0.0)>=.999:
			var begun: Dictionary=_runtime.begin_exit(_actor,_vehicle,SEAT,clock,_binding.body.global_position,true,[_binding.body.get_rid(),owner.body.get_rid()])
			if begun.get("code")=="HOLDING": _interaction=begun.token;_phase="EXIT_HOLD";_events.append("EXIT_HOLD")
			else: _reason="begin_exit:"+str(begun.get("code"))
	elif _phase=="RELEASING": _finish_walking()

func _follow_seat() -> void:
	if not _current() or _runtime.host.driver(_vehicle)!=_actor: return
	var owner: Node3D=_owner.get_ref()
	var seat: Dictionary=_runtime.catalog.seat(owner.body.get_meta("profile_id"),SEAT)
	var p: Dictionary=seat.anchor_local_m
	_binding.body.global_transform=Transform3D(owner.body.global_basis.orthonormalized(),owner.body.global_transform*Vector3(p.x,p.y,p.z))
	_binding.body.velocity=Vector3.ZERO

func _apply_pose(source_pose: Dictionary, delta: float) -> void:
	if not _current(): return
	var owner: Node3D=_owner.get_ref()
	var seat: Dictionary=_runtime.catalog.seat(owner.body.get_meta("profile_id"),SEAT)
	var profile: Dictionary=_runtime.catalog.profile(owner.body.get_meta("profile_id"))
	var options: Dictionary={"fold":float(source_pose.get("fold",0.0)),"reach":float(source_pose.get("reach",0.0)),"pose":source_pose,"side":seat.source_side,"dt":delta,"steer":float(owner.body.snapshot_state().steering_angle_rad)}
	for source_key: String in {"inner_leg":"innerLeg","outer_leg":"outerLeg","hand_reach":"handReach","close_reach":"closeReach"}:
		if source_pose.has(source_key): options[{"inner_leg":"innerLeg","outer_leg":"outerLeg","hand_reach":"handReach","close_reach":"closeReach"}[source_key]]=source_pose[source_key]
	var selected: Dictionary=_pose.sample({"id":SEAT,"can_drive":seat.can_drive,"side":seat.source_side,"recline":profile.cabin_derivation.seat_recline_rad},options,null,_binding.rig_epoch)
	if selected.get("valid",false):
		# NPC visuals already retain their canonical RY(pi) wrapper. Pose pivot
		# composes under it instead of replacing that source orientation.
		selected.visual_rotation=Quaternion(Vector3.UP,PI)*selected.visual_rotation
		_pose.apply(selected)
	else: _reason="original_occupant_pose_refused"

func _publish_actor(add: bool, retired_life: bool = false) -> bool:
	var owner: Node3D=_owner.get_ref()
	var diagnostic: Dictionary=owner.runtime.host.diagnostics()
	if diagnostic.roster_revision!=owner._roster_revision or diagnostic.actors!=owner._npc_roster.actors.size() or diagnostic.vehicles!=owner._npc_roster.vehicles.size(): return false
	var roster: Dictionary=owner._npc_roster.duplicate(true)
	var actors: Array=[]
	for entry: Dictionary in roster.actors:
		if entry.actor_id==_actor.actor_id:
			if entry.life_generation!=_actor.life_generation: return false
			if add: return false
		else: actors.append(entry)
	if add: actors.append({"actor_id":_actor.actor_id,"life_generation":_actor.life_generation,"active":true})
	roster.actors=actors
	for index in roster.vehicles.size():
		var previous: Dictionary=roster.vehicles[index]
		var current: Dictionary=owner.runtime.host.vehicle_record({"vehicle_id":previous.vehicle_id,"life_generation":previous.life_generation})
		if current.is_empty(): return false
		if not add:
			for seat_id: String in current.seats:
				if current.seats[seat_id]==_actor:
					if not retired_life: return false
					current.seats[seat_id]=null
		roster.vehicles[index]=current
	owner._clock=maxi(owner._clock,int(diagnostic.source_clock))+1
	roster.source_clock=owner._clock;roster.roster_revision=owner._roster_revision+1
	if owner.runtime.publish_roster(roster).get("code")!="OK": return false
	owner._roster_revision=roster.roster_revision;owner._npc_roster=roster
	return true

func _finish_walking() -> void:
	if not _current(): _retire("release_owner_changed");return
	if not _runtime.host.driver(_vehicle).is_empty(): _reason="physical_exit_required";return
	var result: Dictionary=_host.release_transport_body(self,_binding,_serial)
	if not result.get("ok",false): _phase="RELEASING";_reason=str(result.get("reason"));return
	# The completed physical exit is the only same-life release route.
	_restore_meta()
	if _registered and not _publish_actor(false): _reason="roster_cleanup_refused"
	_registered=false;_phase="DONE";_events.append("WALKING_RESUMED");_door=0.0
	if _driver!=null: _driver.release()
	if is_instance_valid(_runtime): _runtime.queue_free()

func _restore_meta() -> void:
	if not _host.physical_life_current(_binding): return
	for key: String in _old_meta:
		if not _binding.body.has_meta(key) or _binding.body.get_meta(key)!=_actor[key]: continue
		if _old_meta[key].present: _binding.body.set_meta(key,_old_meta[key].value)
		else: _binding.body.remove_meta(key)

func _retire(reason: String) -> void:
	_reason=reason;_control={};_phase="RETIRED"
	if _driver!=null: _driver.release()
	# A stale life may share an Object ID with a replacement. Do not call the
	# old physical provider's cancel(), restore filters, or write that body.
	if is_instance_valid(_runtime) and _owner_current():
		if not _interaction.is_empty(): _runtime.host.cancel(_interaction)
		if _registered and not _host.transport_life_current(_binding):
			if _publish_actor(false,true): _registered=false
	_host.retire_transport_body(self,_binding,_serial)
	if is_instance_valid(_runtime): _runtime.queue_free()

func retire_from_owner(reason: String) -> void:
	if not active(): return
	if not _had_movement and _host.transport_body_current(self,_binding,_serial):
		var released: Dictionary=_host.release_transport_body(self,_binding,_serial)
		if released.get("ok",false): _restore_meta()
	_retire(reason)

func _setup_failed(reason: String) -> Dictionary:
	if _registered:
		_publish_actor(false);_registered=false
	var released: Dictionary=_host.release_transport_body(self,_binding,_serial)
	if not released.get("ok",false):
		_phase="RELEASING";_reason=reason+":"+str(released.get("reason"))
		return {"ok":false,"reason":_reason,"cleanup_pending":true}
	_restore_meta()
	if is_instance_valid(_runtime): _runtime.queue_free()
	return _fail(reason)

func _fail(reason: String) -> Dictionary:
	_phase="FAILED";_reason=reason
	return {"ok":false,"reason":reason}
