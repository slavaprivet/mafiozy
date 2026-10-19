extends RefCounted
## QA-only, at most once/second. Reads real owners; never creates receipts or moves actors.
static func sample(daily: RefCounted) -> Dictionary:
	var counts: Dictionary={"total":0,"resting":0,"ordinary_rest":0,"optional_retry":0,"urgent_retry":0,"capacity_wait":0,"service_wait":0,"portal_wait":0,"moving_or_planning":0,"ambient":0,"attention":0,"threat":0,"medical":0,"disposed":0}
	var complete: Dictionary={"walk":0,"shop":0,"restaurant":0,"bank":0,"hospital":0}
	var rest_max_s:=0.0
	for life: RefCounted in daily._lives.values():
		counts.total+=1
		for kind: String in complete:complete[kind]+=int(life._completed.get(kind,0))
		if life._disposed:counts.disposed+=1;continue
		if life.threat_physics_active30():counts.threat+=1
		if life._attention29.active:counts.attention+=1
		if life._ambient29!=null and life._ambient29.active():counts.ambient+=1
		var route: RefCounted
		if life._dsh_simple_goal_active():counts.medical+=1;route=life._dsh_simple
		elif life._economy28_active():route=life._economy28._route
		elif life._restaurant28_active():route=life._restaurant28
		if route!=null:
			match route._phase:
				"WAITING":counts.capacity_wait+=1
				"SERVICE_WAIT":counts.service_wait+=1
				"PORTAL_WAIT_IN","PORTAL_WAIT_OUT":counts.portal_wait+=1
				"INBOUND","OUTBOUND","SERVICE_APPROACH":counts.moving_or_planning+=1
		elif life._roam51_active:counts.moving_or_planning+=1
		if life._phase=="RESTING":
			counts.resting+=1
			var left_s: float=maxf(0.0,(life._next_decision-life._now)/1000.0)
			rest_max_s=maxf(rest_max_s,left_s)
			if life._economy28!=null and life._economy28.has_pending_need():
				if life._economy28.optional_retry56(life._now):counts.optional_retry+=1
				else:counts.urgent_retry+=1
			else:counts.ordinary_rest+=1
	return {"counts":counts,"completed":complete,"rest_left_max_s":rest_max_s,"frame":Engine.get_physics_frames(),"physics_dispatch":daily.physical_dispatch_state30(),"classification_only":true}
