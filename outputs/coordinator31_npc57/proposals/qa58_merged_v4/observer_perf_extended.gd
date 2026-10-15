extends Node
## Read-only resident telemetry. A separate stationary QA camera retains the
## original projection/transform; it never moves the player or any resident.
const RouteBudget=preload("res://scripts/hospital/npc_route_budget29.gd")
const NavWork=preload("res://scripts/navigation/npc_navigation_work29.gd")
var _out := ""
var _warmup_s := 20.0
var _measure_s := 180.0
var _expected_staff := 0
var _start_ms := 0
var _ready_ms := 0
var _sample_start_ms := 0
var _sample_start_unix_ms := 0.0
var _last_tick := 0
var _last_sample := -100000
var _frame_count := 0
var _sample_count := 0
var _frame_ms := PackedFloat64Array()
var _frame_at_s := PackedFloat64Array()
var _samples: Array[Dictionary]=[]
var _finished := false
var _camera: Camera3D
var _camera_record: Dictionary={}
var _requested_camera: Dictionary={}
var _pop: RefCounted
var _staff: Node
var _venues := 0
var _new_venues := 0
var _moved_m := 0.0
var _previous_position := Vector3.INF
var _max_sample_us := 0
var _max_frame_observer_us := 0
var _coverage: Dictionary={}

func _ready() -> void:
	_start_ms=Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):_out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-warmup="):_warmup_s=float(arg.trim_prefix("--qa-warmup="))
		if arg.begins_with("--qa-samples="):_measure_s=float(arg.trim_prefix("--qa-samples="))
		if arg.begins_with("--qa-expected-staff="):_expected_staff=int(arg.trim_prefix("--qa-expected-staff="))
		if arg.begins_with("--qa-fixed-camera-json="):
			var parsed: Variant=JSON.parse_string(arg.trim_prefix("--qa-fixed-camera-json="))
			if parsed is Dictionary:_requested_camera=parsed
	if _out.is_empty() or _warmup_s<0 or _measure_s<1 or _measure_s>1200:_finish("invalid_qa_arguments");return
	# Fixed capacity before warmup avoids measuring the observer's own growing arrays.
	_frame_ms.resize(int(ceil(_measure_s*1000.0))+12000)
	_frame_at_s.resize(_frame_ms.size())
	for index in int(ceil(_measure_s+_warmup_s))+5:_samples.append(_blank_sample())

func _blank_sample() -> Dictionary:
	return {"elapsed_ms":0,"measure_ms":0,"unix_ms":0.0,"frame":0,"static_memory":0,"static_max":0,"objects":0,"nodes":0,"orphans":0,"resources":0,"draw_calls":0,"primitives":0,"video_memory":0,"texture_memory":0,"buffer_memory":0,"process_ms":0.0,"physics_ms":0.0,"residents":0,"lives":0,"records":0,"staff":0,"venues":0,"new_venues":0,"position":Vector3.ZERO,"hp":0.0,"energy":0.0,"phase":"","kind":"","attention":false,"roam_completed":0,"hospital_completed":0,"shop_completed":0,"bank_completed":0,"restaurant_completed":0,"route_jobs":0,"route_nodes":0,"route_heap":0,"route_service_us":0,"nav_pending":0,"nav_guides":0,"nav_maps":0,"nav_started":0,"nav_completed":0,"registry_entries":0,"registry_actors":0,"service_keys":0}

func _has(object: Object,key: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property.name)==key:return true
	return false

func _camera_values(camera: Camera3D) -> Dictionary:
	var at: Vector3=camera.global_position
	var rot: Vector3=camera.global_rotation
	var axes: Basis=camera.global_basis
	var screen: Vector2=get_viewport().get_visible_rect().size
	return {"position":[at.x,at.y,at.z],"rotation":[rot.x,rot.y,rot.z],"basis":[[axes.x.x,axes.x.y,axes.x.z],[axes.y.x,axes.y.y,axes.y.z],[axes.z.x,axes.z.y,axes.z.z]],"fov":camera.fov,"near":camera.near,"far":camera.far,"projection":camera.projection,"viewport":[screen.x,screen.y],"render_size":[get_viewport().get_texture().get_width(),get_viewport().get_texture().get_height()]}

func _fix_camera() -> bool:
	var original: Camera3D=get_viewport().get_camera_3d()
	if original==null:return false
	_camera=Camera3D.new();_camera.name="Perf30FixedCamera"
	_camera.projection=original.projection;_camera.fov=original.fov
	_camera.size=original.size;_camera.near=original.near;_camera.far=original.far
	_camera.keep_aspect=original.keep_aspect;_camera.cull_mask=original.cull_mask
	_camera.attributes=original.attributes;_camera.environment=original.environment
	_camera.h_offset=original.h_offset;_camera.v_offset=original.v_offset
	get_tree().current_scene.add_child(_camera)
	_camera.global_transform=original.global_transform;_camera.make_current()
	# Candidate gets the recorded baseline view, not an independently settled view.
	if not _requested_camera.is_empty():
		var at: Array=_requested_camera.get("position",[])
		var axes: Array=_requested_camera.get("basis",[])
		if at.size()!=3 or axes.size()!=3:return false
		_camera.global_transform=Transform3D(Basis(Vector3(axes[0][0],axes[0][1],axes[0][2]),Vector3(axes[1][0],axes[1][1],axes[1][2]),Vector3(axes[2][0],axes[2][1],axes[2][2])),Vector3(at[0],at[1],at[2]))
		_camera.fov=float(_requested_camera.fov);_camera.near=float(_requested_camera.near);_camera.far=float(_requested_camera.far)
	_camera_record=_camera_values(_camera)
	return true

func _process(_delta: float) -> void:
	if _finished:return
	var observer_start: int=Time.get_ticks_usec()
	var now: int=Time.get_ticks_msec()
	var scene: Node3D=get_tree().current_scene
	if _ready_ms==0:
		_pop=scene.get("preview_population")
		if _pop!=null and _pop.get("city_ready")==true:
			_ready_ms=now
			if not _fix_camera():_finish("camera_missing");return
			if _has(scene,"preview_venue_staff29"):_staff=scene.get("preview_venue_staff29") as Node
			for child: Node in scene.get_children():
				if child.get_meta("dsh_town_extra",false) and child.get_node_or_null("TownCloneSign") is Label3D:_venues+=1
				if str(child.name).begins_with("CompactService29_"):_new_venues+=1
		elif now-_start_ms>100000:_finish("bootstrap_timeout")
		return
	if _sample_start_ms==0 and now-_ready_ms>=int(_warmup_s*1000.0):
		_sample_start_ms=now;_sample_start_unix_ms=Time.get_unix_time_from_system()*1000.0
		_last_tick=Time.get_ticks_usec()
		var marker: FileAccess=FileAccess.open(_out.path_join("MEASURE_START.json"),FileAccess.WRITE)
		marker.store_string(JSON.stringify({"pid":OS.get_process_id(),"unix_ms":_sample_start_unix_ms,"warmup_s":_warmup_s,"measure_s":_measure_s,"camera":_camera_record}));marker.close()
		_last_tick=Time.get_ticks_usec();return
	var tick: int=Time.get_ticks_usec()
	if _sample_start_ms>0 and tick>_last_tick:
		if _frame_count>=_frame_ms.size():_finish("frame_capacity_exceeded");return
		_frame_ms[_frame_count]=float(tick-_last_tick)/1000.0
		_frame_at_s[_frame_count]=float(now-_sample_start_ms)/1000.0
		_frame_count+=1
	_last_tick=tick
	if now-_last_sample>=1000:
		# Keep the1Hz cadence on its original clock grid instead of accumulating frame rounding.
		_last_sample += maxi(1, int((now-_last_sample)/1000))*1000
		_sample(now,scene)
	if _sample_start_ms>0 and now-_sample_start_ms>=int(_measure_s*1000.0):_finish("")
	_max_frame_observer_us=maxi(_max_frame_observer_us,Time.get_ticks_usec()-observer_start)

func _sample(now: int,scene: Node3D) -> void:
	var started: int=Time.get_ticks_usec()
	if _sample_count>=_samples.size():_finish("sample_capacity_exceeded");return
	var row: Dictionary=_samples[_sample_count];_sample_count+=1
	row.elapsed_ms=now-_ready_ms;row.measure_ms=now-_sample_start_ms if _sample_start_ms>0 else -1
	row.unix_ms=Time.get_unix_time_from_system()*1000.0;row.frame=Engine.get_physics_frames()
	row.static_memory=Performance.get_monitor(Performance.MEMORY_STATIC);row.static_max=Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	row.objects=Performance.get_monitor(Performance.OBJECT_COUNT);row.nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	row.orphans=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT);row.resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	row.draw_calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);row.primitives=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	row.video_memory=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED);row.texture_memory=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED);row.buffer_memory=Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	row.process_ms=1000.0*Performance.get_monitor(Performance.TIME_PROCESS);row.physics_ms=1000.0*Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	row.residents=_pop.hit_owners.size();row.lives=_pop.daily._lives.size();row.records=_pop.residents._records.size();row.venues=_venues;row.new_venues=_new_venues
	row.staff=_staff.get("_rows").size() if is_instance_valid(_staff) else 0
	var life: RefCounted=_pop.daily._lives.get("resident_1")
	if life!=null:
		var body: Node3D=life._token.get("body")
		if is_instance_valid(body):
			row.position=body.global_position
			if _previous_position.is_finite() and body.global_position.distance_to(_previous_position)<4.0:_moved_m+=body.global_position.distance_to(_previous_position)
			_previous_position=body.global_position
		row.hp=float(life._health._row.get("hp",0));row.energy=life._energy;row.phase=life._phase;row.kind=str(life._goal.get("kind",""));row.attention=life._attention29.active
		row.roam_completed=int(life._completed.walk);row.hospital_completed=int(life._completed.hospital);row.shop_completed=int(life._completed.shop);row.bank_completed=int(life._completed.bank);row.restaurant_completed=int(life._completed.restaurant)
		var cover: String=str(row.phase)+":"+str(row.kind);_coverage[cover]=int(_coverage.get(cover,0))+1
	row.route_jobs=RouteBudget._jobs.size();row.route_nodes=RouteBudget._nodes;row.route_heap=RouteBudget._heap_items;row.route_service_us=RouteBudget._last_us
	row.nav_pending=NavWork._pending.size();row.nav_guides=NavWork._guides.size();row.nav_maps=NavWork._maps.size();row.nav_started=NavWork._started;row.nav_completed=NavWork._completed
	var registry: Variant=scene.get_meta("npc_venue_registry29",null)
	if registry is RefCounted:
		row.registry_entries=registry.get("_entries").size();row.registry_actors=registry.get("_actors").size()
		# The staff queue is candidate content; never instantiate it in the baseline.
		if _has(registry,"_service29"):
			var service: Variant=registry.get("_service29")
			if service is RefCounted:row.service_keys=service.get("keys").size()
	_max_sample_us=maxi(_max_sample_us,Time.get_ticks_usec()-started)

func _finish(reason: String) -> void:
	if _finished:return
	_finished=true
	var usable: Array[Dictionary]=_samples.slice(0,_sample_count)
	var measured: Array[Dictionary]=usable.filter(func(r:Dictionary)->bool:return int(r.measure_ms)>=0)
	var errors: Array[String]=[]
	if not reason.is_empty():errors.append(reason)
	if measured.size()<int(_measure_s)-3:errors.append("insufficient_measurement_samples")
	if measured.any(func(r:Dictionary)->bool:return int(r.residents)!=1 or int(r.lives)!=1):errors.append("one_resident_contract")
	if measured.any(func(r:Dictionary)->bool:return int(r.venues)!=12 or int(r.new_venues)!=8):errors.append("twelve_total_eight_new_venue_contract")
	if measured.any(func(r:Dictionary)->bool:return int(r.staff)!=_expected_staff):errors.append("staff_content_changed_or_missing")
	if _moved_m<3.0:errors.append("resident_motion_not_exercised")
	var final_camera: Dictionary=_camera_values(_camera) if is_instance_valid(_camera) else {}
	if final_camera!=_camera_record:errors.append("fixed_camera_changed")
	var result: Dictionary={"schema":"mafiozi.perf30.native/v2","ok":errors.is_empty(),"errors":errors,"pid":OS.get_process_id(),"warmup_seconds":_warmup_s,"measurement_seconds":_measure_s,"measurement_start_unix_ms":_sample_start_unix_ms,"measurement_end_unix_ms":Time.get_unix_time_from_system()*1000.0,"frame_count":_frame_count,"frame_ms":_frame_ms.slice(0,_frame_count),"frame_at_s":_frame_at_s.slice(0,_frame_count),"samples":usable,"camera":_camera_record,"final_camera":final_camera,"moved_m":_moved_m,"coverage":_coverage,"expected_staff":_expected_staff,"max_sample_us":_max_sample_us,"max_observer_us":_max_frame_observer_us,"observer_frame_capacity":_frame_ms.size(),"observer_sample_capacity":_samples.size(),"observer_arrays_preallocated":true,"npc_or_hp_writes":false,"performance_accepted":false,"scope":"1 resident, 12 venues including 8 new compact sites; candidate retains 12 staff actors. Short bounded observation cannot establish absence of all leaks."}
	if not _out.is_empty():
		var file: FileAccess=FileAccess.open(_out.path_join("PERF30.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result));file.close()
	print("PERF30_RESULT ",JSON.stringify({"ok":result.ok,"errors":errors,"frames":_frame_count,"samples":measured.size(),"moved_m":_moved_m,"camera":_camera_record}))
	get_tree().quit(0 if errors.is_empty() else 1)
