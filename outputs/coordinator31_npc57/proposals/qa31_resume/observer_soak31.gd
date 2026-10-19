extends "../../../coordinator30_npc54/proposals/mass30/observer_mass30.gd"
## Companion to the pinned mass/perf observer. Reads all ten live actors once/s.
## It never requests a route, touches a queue, moves an actor or changes HP/RNG.
## Route retries and phase changes do not reset the physical progress anchor.
var _state31: Dictionary = {}
var _rows31: Array[Dictionary] = []
var _row_count31 := 0
var _intervals31: Array[Dictionary] = []
var _max_sample_us31 := 0
var _motion_limit31 := 10.0
var _queue_limit31 := 30.0
var _errors31: Array[String] = []
var _physics_per_render31 := PackedInt32Array()
var _previous_physics31 := -1
var _physics_samples31 := 0
var _last_live_ms31 := -30000

func _ready() -> void:
	super._ready()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-max-motion-idle="):_motion_limit31 = float(arg.trim_prefix("--qa-max-motion-idle="))
		if arg.begins_with("--qa-max-queue-idle="):_queue_limit31 = float(arg.trim_prefix("--qa-max-queue-idle="))
	if _expected30 != 10 or _motion_limit31 <= 0.0 or _queue_limit31 <= 0.0:
		_finish("soak31_requires_ten_and_positive_limits");return
	_rows31.resize(int(ceil(_measure_s))+5)
	for index: int in _rows31.size():
		var actors: Array[Dictionary] = []
		for actor_index: int in 10:actors.append(_blank_actor31())
		_rows31[index] = {"measure_ms":0,"frame":0,"actors":actors,"count":0}
	_physics_per_render31.resize(_frame_ms.size())
	_physics_per_render31.fill(-1)

func _process(delta: float) -> void:
	# One integer read/write per render; no population scan or snapshot here.
	var current_physics: int = Engine.get_physics_frames()
	if _sample_start_ms > 0 and _previous_physics31 >= 0 and _frame_count < _physics_per_render31.size():
		_physics_per_render31[_frame_count] = current_physics-_previous_physics31
		_physics_samples31 = _frame_count+1
	_previous_physics31 = current_physics
	super._process(delta)

func _blank_actor31() -> Dictionary:
	return {"life_phase":"","goal":"","attention":false,"roam_active":false,
		"economy_phase":"","outer_phase":"","route_phase":"","route_reason":"",
		"queue_kind":"","queue_state":"","door_stage":"","venue":"","required_motion":false,
		"service_watch":{"blocked":false,"reason":"","planning_service_us":0,"local_wait_ms":0.0,"motion_idle_ms":0.0,"total_service_us":0,"progress_resets":0},"route_status":"","guide_status":"","route_attempts":0,
		"id":"","generation":0,"position":[0.0,0.0,0.0],"no_progress_s":0.0,
		"motion_idle_s":0.0,"queue_idle_s":0.0,
		"completed":{"bank":0,"drive":0,"hospital":0,"restaurant":0,"shop":0,"walk":0}}

func _route_state31(life: RefCounted, row: Dictionary) -> void:
	row.life_phase = life._phase;row.goal = str(life._goal.get("kind",""))
	row.attention = life._attention29.active;row.roam_active = life._roam51_active
	var outer: RefCounted
	if life._economy28 != null:
		row.economy_phase = life._economy28._phase
		outer = life._economy28._route
	if outer == null and life._restaurant28 != null:outer = life._restaurant28
	var driver: RefCounted
	if outer != null:
		row.outer_phase = outer._phase;row.venue = outer._venue
		row.door_stage = outer._exit_door_state56
		driver = outer._drive
		if outer._phase == "WAITING":row.queue_kind = "capacity"
		elif outer._phase in ["PORTAL_WAIT_IN","PORTAL_WAIT_OUT"]:row.queue_kind = "portal"
		elif outer._phase == "SERVICE_WAIT":row.queue_kind = "service"
		row.required_motion = outer._phase in ["INBOUND","OUTBOUND","SERVICE_APPROACH"]
		if outer._registry != null:
			var claim: Dictionary = outer._registry.ledger.requests.get(outer._key,{})
			row.queue_state = str(claim.get("state",""))
	elif life._roam51_active:
		driver = life._roam51;row.required_motion = true
	elif life._dsh_simple != null and life._dsh_simple._active:
		driver = life._dsh_simple;row.required_motion = true
	if driver != null:
		row.route_phase = driver._phase;row.route_reason = driver._last_reason
		for watch_key: String in driver._service_watch30:row.service_watch[watch_key] = driver._service_watch30[watch_key]
		row.route_status = driver._route.status if driver._route != null else ""
		row.guide_status = driver._guide.status if driver._guide != null else ""
		row.route_attempts = driver._attempts
	# Attention is legitimate visible interaction; raw stillness remains recorded.
	if bool(row.attention):row.required_motion = false

func _close_interval31(state: Dictionary, now: int, closed_by: String) -> void:
	var duration: float = float(now-int(state.anchor_ms))/1000.0
	state.max_no_progress_s = maxf(float(state.max_no_progress_s),duration)
	if duration < 5.0:return
	if _intervals31.size() >= 512:
		if not _errors31.has("interval_capacity_exceeded"):_errors31.append("interval_capacity_exceeded")
		return
	_intervals31.append({"id":state.id,"generation":state.generation,"start_ms":state.anchor_ms,
		"end_ms":now,"duration_s":duration,"closed_by":closed_by,"start_state":state.anchor_state,
		"last_state":state.last_state,"anchor_position":[state.anchor_position.x,state.anchor_position.y,state.anchor_position.z]})

func _sample(now: int, scene: Node3D) -> void:
	super._sample(now,scene)
	if _finished or _sample_start_ms == 0:return
	var observer_start: int = Time.get_ticks_usec()
	if _row_count31 >= _rows31.size():_finish("soak31_sample_capacity_exceeded");return
	var sample: Dictionary = _rows31[_row_count31]
	var actors: Array[Dictionary] = sample.actors
	var actor_index := 0
	for id: String in _pop.daily._lives:
		var life: RefCounted = _pop.daily._lives[id]
		if not _pop.residents.target_current(life._token):continue
		var body: CharacterBody3D = life._token.body
		var generation: int = int(life._token.life_generation)
		var key: String = id+":"+str(generation)
		var position: Vector3 = body.global_position
		if actor_index >= 10:_finish("soak31_ten_actor_capacity_exceeded");return
		var detail: Dictionary = actors[actor_index]
		actor_index += 1
		_route_state31(life,detail)
		if not _state31.has(key):
			if _state31.size() >= 64:_finish("soak31_generation_capacity_exceeded");return
			_state31[key] = {"id":id,"generation":generation,"anchor_position":position,
				"anchor_ms":now,"last_ms":now,"anchor_state":detail.duplicate(true),"last_state":detail,
				"max_no_progress_s":0.0,"motion_idle_s":0.0,"max_motion_idle_s":0.0,
				"queue_idle_s":0.0,"max_queue_idle_s":0.0,"sample_count":0}
		var state: Dictionary = _state31[key]
		var elapsed: float = float(now-int(state.last_ms))/1000.0
		var displacement: float = Vector2(position.x-state.anchor_position.x,position.z-state.anchor_position.z).length()
		var progressed: bool = displacement >= .10
		if progressed:
			_close_interval31(state,now,"physical_progress_10cm")
			state.anchor_ms = now;state.anchor_position = position;state.anchor_state = detail.duplicate(true)
			state.motion_idle_s = 0.0;state.queue_idle_s = 0.0
		else:
			# State/route changes do not erase accumulated physical waiting.
			if bool(detail.required_motion):state.motion_idle_s = float(state.motion_idle_s)+elapsed
			if not str(detail.queue_kind).is_empty():state.queue_idle_s = float(state.queue_idle_s)+elapsed
		state.max_motion_idle_s = maxf(float(state.max_motion_idle_s),float(state.motion_idle_s))
		state.max_queue_idle_s = maxf(float(state.max_queue_idle_s),float(state.queue_idle_s))
		state.max_no_progress_s = maxf(float(state.max_no_progress_s),float(now-int(state.anchor_ms))/1000.0)
		state.last_state = detail;state.last_ms = now;state.sample_count = int(state.sample_count)+1
		detail.id = id;detail.generation = generation
		detail.position[0] = position.x;detail.position[1] = position.y;detail.position[2] = position.z
		detail.no_progress_s = float(now-int(state.anchor_ms))/1000.0
		detail.motion_idle_s = state.motion_idle_s;detail.queue_idle_s = state.queue_idle_s
		for completed_key: String in life._completed:detail.completed[completed_key] = life._completed[completed_key]
	sample.measure_ms = now-_sample_start_ms;sample.frame = Engine.get_physics_frames();sample.count = actor_index
	if actor_index != 10 and not _errors31.has("resident_count_changed"):_errors31.append("resident_count_changed")
	_row_count31 += 1
	_max_sample_us31 = maxi(_max_sample_us31,Time.get_ticks_usec()-observer_start)
	if now-_sample_start_ms-_last_live_ms31 >= 30000:
		_last_live_ms31 = now-_sample_start_ms
		var highlights: Array[Dictionary] = []
		for index: int in actor_index:
			var detail: Dictionary = actors[index]
			if float(detail.motion_idle_s) >= 5.0 or float(detail.queue_idle_s) >= 10.0:
				highlights.append({"id":detail.id,"position":detail.position,"motion_idle_s":detail.motion_idle_s,"queue_idle_s":detail.queue_idle_s,"life_phase":detail.life_phase,"outer_phase":detail.outer_phase,"route_phase":detail.route_phase,"venue":detail.venue,"door_stage":detail.door_stage,"route_reason":detail.route_reason})
		print("SOAK31_LIVE ",JSON.stringify({"measure_ms":now-_sample_start_ms,"actors":actor_index,"highlights":highlights}))

func _finish(reason: String) -> void:
	if _finished:return
	var summaries: Array[Dictionary] = []
	for key: String in _state31:
		var state: Dictionary = _state31[key]
		_close_interval31(state,int(state.last_ms),"observation_end_or_generation_retired")
		var summary: Dictionary = state.duplicate()
		for field: String in ["anchor_state","last_state","anchor_position"]:summary.erase(field)
		summaries.append(summary)
		if float(state.max_motion_idle_s) > _motion_limit31:_errors31.append("motion_idle:"+key)
		if float(state.max_queue_idle_s) > _queue_limit31:_errors31.append("queue_idle:"+key)
	if _row_count31 < int(_measure_s)-3:_errors31.append("insufficient_soak_samples")
	var report: Dictionary = {"schema":"mafiozi.soak31/v1","read_only_observer":true,
		"errors":_errors31,"reason":reason,"sample_period_ms":1000,"progress_anchor_m":.10,
		"motion_idle_limit_s":_motion_limit31,"queue_idle_limit_s":_queue_limit31,
		"resident_summaries":summaries,"intervals":_intervals31,"samples":_rows31.slice(0,_row_count31),
		"max_sample_us":_max_sample_us31,"sample_capacity":_rows31.size(),"interval_capacity":512,
		"physics_steps_per_render":_physics_per_render31.slice(0,_physics_samples31),
		"physics_sample_count":_physics_samples31,"actor_sample_buffers_preallocated":true,
		"performance_accepted":false,"root_cause_established":false,
		"limits":"1Hz position sampling; raw stillness includes intentional activity. Required-motion and queue time are accumulated separately without retry/phase reset. Use accompanying MASS30 for frame/memory/queue telemetry and external OS_MEMORY samples."}
	if not _out.is_empty():
		var file: FileAccess = FileAccess.open(_out.path_join("SOAK31.json"),FileAccess.WRITE)
		if file != null:file.store_string(JSON.stringify(report));file.close()
	var failure: String = reason
	if failure.is_empty() and not _errors31.is_empty():failure = "soak31_liveness_gate"
	super._finish(failure)
