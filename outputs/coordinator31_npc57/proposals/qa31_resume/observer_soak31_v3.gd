extends "observer_soak31_v2.gd"
## Additional reads only when observed motion is idle5s or a queue waits15s.
## Never calls planner tick/begin/floor queries, mutates jobs or requests a route.
var _slow_rows31: Array[Dictionary] = []
var _slow_count31 := 0
var _slow_max_us31 := 0
var _slow_motion_threshold31 := 5.0

func _ready() -> void:
	super._ready()
	_slow_rows31.resize((int(ceil(_measure_s))+5)*10)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-slow-motion-threshold="):_slow_motion_threshold31 = float(arg.trim_prefix("--qa-slow-motion-threshold="))

func _v31(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _slow_owner31(life: RefCounted) -> Array:
	var outer: RefCounted
	var driver: RefCounted
	if life._economy28 != null:outer = life._economy28._route
	if outer == null and life._restaurant28 != null:outer = life._restaurant28
	if outer != null:driver = outer._drive
	elif life._roam51_active:driver = life._roam51
	elif life._dsh_simple != null and life._dsh_simple._active:driver = life._dsh_simple
	return [outer,driver]

func _sample(now: int, scene: Node3D) -> void:
	var before: int = _row_count31
	super._sample(now,scene)
	if _finished or _row_count31 == before:return
	var started: int = Time.get_ticks_usec()
	var sample: Dictionary = _rows31[_row_count31-1]
	for index: int in int(sample.count):
		var actor: Dictionary = sample.actors[index]
		if not ((bool(actor.required_motion) and float(actor.motion_idle_s)>=_slow_motion_threshold31) or float(actor.queue_idle_s)>=15.0):continue
		if _slow_count31 >= _slow_rows31.size():_errors31.append("slow_planner_capacity_exceeded");return
		var life: RefCounted = _pop.daily._lives.get(actor.id)
		if life == null or not _pop.residents.target_current(life._token):continue
		var owner: Array = _slow_owner31(life)
		var outer: RefCounted = owner[0]
		var driver: RefCounted = owner[1]
		var entry: Dictionary = {"measure_ms":sample.measure_ms,"physics_frame":sample.frame,
			"actor":actor,"planner":{},"service_geometry":{},"shared_jobs":[],"shared_budget":RouteBudget.diagnostics()}
		if driver != null:
			entry.driver = {"target":_v31(driver._target),"target_source":driver._target_source,
				"leg":driver._leg,"leg_count":driver._legs.size(),"way":driver._way,"phase":driver._phase}
			if driver._route != null:
				entry.planner = driver._route.diagnostics()
				entry.planner.goal = _v31(driver._route.goal);entry.planner.origin = _v31(driver._route.origin)
		if outer != null:
			entry.service_geometry = {"venue":outer._venue,"outer_phase":outer._phase,"leg":outer._leg,
				"entered":outer._entered,"door":_v31(outer._door),"inner":_v31(outer._inner),"outside":_v31(outer._outside),
				"inward":_v31(outer._inward),"room":_v31(outer._room),"staging":_v31(outer._staging),
				"clone":str(outer._clone.get_path()) if is_instance_valid(outer._clone) else "",
				"entry_bounds_valid":outer._entry_bounds_valid30,"entry_bounds_position":_v31(outer._entry_bounds30.position),"entry_bounds_size":_v31(outer._entry_bounds30.size)}
		for key: int in RouteBudget._jobs:
			if entry.shared_jobs.size() >= 16:
				entry.shared_jobs_truncated = true;break
			var claim: Dictionary = RouteBudget._jobs[key]
			var job: RefCounted = claim.ref.get_ref()
			if job == null:continue
			entry.shared_jobs.append({"key":key,"status":job.status,"body":str(job.body.get_path()) if is_instance_valid(job.body) else "",
				"goal":_v31(job.goal),"origin":_v31(job.origin),"expanded":job.expanded,"service_us":job.service_us29,
				"touch_frame":claim.touch,"nodes":claim.nodes,"heap":claim.heap})
		_slow_rows31[_slow_count31] = entry;_slow_count31 += 1
	_slow_max_us31 = maxi(_slow_max_us31,Time.get_ticks_usec()-started)

func _finish(reason: String) -> void:
	if _finished:return
	if not _out.is_empty():
		var file: FileAccess = FileAccess.open(_out.path_join("SLOW_PLANNER31.json"),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"schema":"mafiozi.soak31.slow-planner/v1","read_only":true,
				"sample_count":_slow_count31,"max_sample_us":_slow_max_us31,"capacity":_slow_rows31.size(),
				"motion_threshold_s":_slow_motion_threshold31,"queue_threshold_s":15.0,"samples":_slow_rows31.slice(0,_slow_count31),
				"limitations":"Reads existing diagnostic fields; performs no physics queries. Shared jobs capped16, sample capacity10 per requested second. No collider paths are inferred if the planner did not record one."}));file.close()
	super._finish(reason)
