extends "observer_soak58_v4.gd"
## Home/routine read-only extension. No native queries, clock/input, or route writes.
func _slow_owner31(life:RefCounted)->Array:
	if life._home58!=null and life._home58.active() and life._home58._visit!=null:
		return [life._home58._visit,life._home58._visit._drive]
	return super._slow_owner31(life)

func _route_state31(life:RefCounted,row:Dictionary)->void:
	super._route_state31(life,row)
	row.routine58=life._routine58.snapshot() if life._routine58!=null else {}
	row.home58=life._home58.snapshot() if life._home58!=null else {}
	var clock:RefCounted=life._routine58_clock()
	row.clock58={"hour":clock.hour,"day":clock.day_index,"running":clock.running} if clock!=null else {}
	row.ambient58=life._ambient29.snapshot() if life._ambient29!=null else {}
	# The main observer samples after the current frame's host pose commit.
	var valid_bed:bool=not row.home58.is_empty() and row.home58.phase in ["HOME_SETTLE","HOME_SLEEP","HOME_REST"] and row.home58.claim_current and row.home58.support_current and row.home58.pose_committed_frame==Engine.get_physics_frames()
	var active_home:bool=not row.home58.is_empty() and row.home58.active
	if active_home:
		row.required_motion=not valid_bed
		var visit:RefCounted=life._home58._visit
		if visit!=null:
			row.outer_phase=visit._phase;row.venue=visit._venue;row.door_stage=visit._exit_door_state56
			row.queue_kind="portal" if visit._phase in ["PORTAL_WAIT_IN","PORTAL_WAIT_OUT"] else ""
			if is_instance_valid(visit._door_owner):
				row.door_fraction=visit._door_owner.fraction;row.door_blocked_reason=visit._door_owner._blocked_reason
			var driver:RefCounted=visit._drive
			if driver!=null:
				row.route_phase=driver._phase;row.route_reason=driver._last_reason
				row.service_watch=driver._service_watch30.duplicate(true)
				row.route_status=driver._route.status if driver._route!=null else ""
				row.guide_status=driver._guide.status if driver._guide!=null else ""
				row.route_attempts=driver._attempts;row.driver_target=_v31(driver._target)
				if driver._route!=null and driver._way>=0 and driver._way<driver._route.route.size():row.driver_waypoint=_v31(driver._route.route[driver._way])
	var rest_until:float=float(row.routine58.get("rest_until_ms",0.0))
	var timed_rest:bool=str(row.routine58.get("intent",{}).get("kind",""))=="rest" and rest_until>life._now
	var animated_rest:bool=bool(row.ambient58.get("active",false)) and int(row.ambient58.get("pose_frames",0))>0 and float(row.ambient58.get("elapsed_s",0.0))<=float(row.ambient58.get("duration_s",0.0))+1.0
	row.rest_evidence58={"supported_bed_pose":valid_bed,"bounded_routine_rest":timed_rest,"rest_remaining_s":maxf(0.0,(rest_until-life._now)/1000.0),"ambient_pose_active":animated_rest,"life_now_ms":life._now,"next_decision_ms":life._next_decision,"reason":life._reason,"on_floor":life._token.body.is_on_floor()}
	# A rolling one-second decision poll is recorded, but never proves a rest
	# duration by itself. The separate audit can distinguish such repeated waits.
	row.unexplained_idle58=life._phase in ["IDLE","RESTING"] and not row.required_motion and not active_home and not timed_rest and not animated_rest and not row.attention and not row.threat.active
