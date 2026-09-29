extends SceneTree
## Root-owned sequential GPU QA. Actual main + unchanged player/vehicle physics.
## Camera is an explicit test view shared by both modes; never move NPC bodies.
var scene: Node3D
var out := ""
var mode := "baseline"
var config := ""
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var origins := {}
var distances := {}
var previous := {}
var observing := false
var last_usec := 0
var hashes_before := {}
var memory_before := {}
var camera: Camera3D
var aborted := false
var watch_input := false
var input_events: Array[String] = []
var drawn_frames := 0
var sampled_drawn_frames := 0
var render_samples: Array[float] = []
var last_draw_usec := 0
class InputObserver extends Node:
	var qa: SceneTree
	func _input(event: InputEvent) -> void:
		var click_to_play: bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed
		var control_active: bool=is_instance_valid(qa.scene) and is_instance_valid(qa.scene._player) and qa.scene._player._free_mouse_look
		if qa.watch_input and (click_to_play or (control_active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion))):
			qa.check(false,"user_input_during_fixed_scenario")
			qa.input_events.append(event.as_text())
			qa.aborted=true
const HASH_FILES := ["res://scripts/main.gd", "res://scripts/preview_population.gd", "res://scripts/npc_visual/preview_resident_host.gd", "res://scripts/npc_visual/preview_resident_world_policy.gd", "res://scripts/preview_player.gd"]

func _initialize() -> void: run.call_deferred()
func check(ok: bool, reason: String) -> void:
	if not ok and not failures.has(reason): failures.append(reason)
func hashes() -> Dictionary:
	var result := {}
	for path: String in HASH_FILES:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "COMPILED"
	return result
func memory() -> Dictionary:
	return {"static_bytes":OS.get_static_memory_usage(), "peak_bytes":OS.get_static_memory_peak_usage(), "objects":Performance.get_monitor(Performance.OBJECT_COUNT), "nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
func frame(_delta: float) -> bool:
	if not observing: return false
	var at := Time.get_ticks_usec()
	if last_usec > 0:
		samples.append({"frame_ms":(at-last_usec)/1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
	last_usec=at
	return false
func _process(delta: float) -> bool: return frame(delta)
func drawn() -> void:
	drawn_frames+=1
	if observing:
		sampled_drawn_frames+=1
		var at:=Time.get_ticks_usec()
		if last_draw_usec>0: render_samples.append((at-last_draw_usec)/1000.0)
		last_draw_usec=at
func _physics_process(_delta: float) -> bool:
	if not observing or mode=="baseline" or not is_instance_valid(scene) or scene.preview_population==null: return false
	for row: Dictionary in scene.preview_population.residents.snapshot().rows:
		var point: Variant=row.position
		if not point is Vector3 or not point.is_finite(): check(false,"resident_missing:"+row.source_id); continue
		if previous.has(row.source_id):
			var moved: float=point.distance_to(previous[row.source_id])
			check(moved<.5,"body_teleport:"+row.source_id)
			distances[row.source_id]=float(distances.get(row.source_id,0.0))+moved
		else: origins[row.source_id]=point
		previous[row.source_id]=point
	return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	phase(name+"_before_render")
	var start_draw:=drawn_frames
	var deadline:=Time.get_ticks_msec()+2000
	while drawn_frames==start_draw and Time.get_ticks_msec()<deadline: await process_frame
	if drawn_frames==start_draw:
		check(false,"render_not_presented:"+name); return
	phase(name+"_before_readback")
	var screenshot:=root.get_texture().get_image()
	phase(name+"_after_readback")
	check(screenshot.save_png(out.path_join(name+".png"))==OK,"capture:"+name)
	phase(name+"_after_png")
func phase(name: String) -> void:
	FileAccess.open(out.path_join("PHASE.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase":name,"at_ms":Time.get_ticks_msec(),"samples":samples.size(),"aborted":aborted,"window_size":DisplayServer.window_get_size(),"root_size":root.size,"input_events":input_events}))
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-mode="): mode=arg.trim_prefix("--qa-mode=")
		if arg.begins_with("--qa-config="): config=arg.trim_prefix("--qa-config=")
	if out.is_empty() or config.is_empty() or mode not in ["baseline","residents"]: quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
		DisplayServer.window_set_size(Vector2i(1280,720))
		DisplayServer.window_move_to_foreground()
	RenderingServer.frame_post_draw.connect(drawn)
	var settings: Variant=JSON.parse_string(FileAccess.get_file_as_string(config))
	if not settings is Dictionary or not settings.get("camera") is Array or not settings.get("look_at") is Array: quit(2); return
	hashes_before=hashes()
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled=mode=="residents"
	root.add_child(scene)
	var input_observer:=InputObserver.new(); input_observer.qa=self; root.add_child(input_observer)
	var deadline:=Time.get_ticks_msec()+25000
	while not scene.preview_ready and Time.get_ticks_msec()<deadline: await physics_frame
	check(scene.preview_ready,"main_ready")
	watch_input=true
	check(scene.transport_status=="ready","transport_ready")
	if mode=="residents":
		check(scene.preview_population!=null,"population_exists")
		if scene.preview_population!=null: check(scene.preview_population.occupants().size()==3,"three_visible_bodies")
	else: check(scene.preview_population==null,"baseline_no_population")
	camera=Camera3D.new(); scene.add_child(camera)
	camera.position=Vector3(settings.camera[0],settings.camera[1],settings.camera[2])
	camera.look_at(Vector3(settings.look_at[0],settings.look_at[1],settings.look_at[2]))
	camera.fov=float(settings.get("fov",65.0)); camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	phase("warmup")
	var warm_end:=Time.get_ticks_msec()+5000
	while not aborted and Time.get_ticks_msec()<warm_end: await process_frame
	memory_before=memory()
	phase("start_capture")
	await capture("start")
	for i in 3: await process_frame
	phase("sampling")
	observing=true; last_usec=0
	var sample_end:=Time.get_ticks_msec()+12000
	while not aborted and Time.get_ticks_msec()<sample_end: await process_frame
	observing=false
	phase("sampled")
	await capture("end")
	watch_input=false
	phase("captured")
	if mode=="residents":
		check(distances.size()==3,"all_three_observed")
		for id: String in distances: check(float(distances[id])>1.0,"actual_movement:"+id)
	check(hashes()==hashes_before,"source_unchanged")
	check(samples.size()>100,"enough_render_frames")
	check(DisplayServer.get_name()=="headless" or render_samples.size()>100,"actual_rendered_frames")
	var metrics: Dictionary={}
	for key: String in ["frame_ms","draw_calls","primitives","process_ms","physics_ms"]:
		var values: Array[float]=[]
		for row: Dictionary in samples: values.append(float(row[key]))
		values.sort()
		if not values.is_empty(): metrics[key]={"p50":values[int((values.size()-1)*.5)],"p95":values[int((values.size()-1)*.95)],"max":values[-1]}
	render_samples.sort()
	if not render_samples.is_empty(): metrics["render_frame_ms"]={"p50":render_samples[int((render_samples.size()-1)*.5)],"p95":render_samples[int((render_samples.size()-1)*.95)],"max":render_samples[-1]}
	var result:={"mode":mode,"failures":failures,"input_events":input_events,"samples":samples.size(),"metrics":metrics,"memory_before":memory_before,"memory_after":memory(),"travel_m":distances,"population":scene.preview_population.snapshot() if scene.preview_population!=null else {},"hashes":hashes_before,"camera":settings,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual bounded quarter; three staged source-model residents. Not full city FPS, original agenda, combat or authenticated progress."}
	result["actual_drawn_frames"]=sampled_drawn_frames
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("RESIDENTS_LIVEQA ",JSON.stringify(result))
	scene.free()
	quit(0 if failures.is_empty() else 1)
