extends SceneTree
## Prepared only; root launches sequential exact-PCK pairs. No OS input/capture.
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var output:=""
var side:=""
var pack_path:=""
var expected_sha:=""
var finished:=false
var started:int
var phase_name:=""
var phase_start:int
var last_draw:int
var samples:Array=[]
var phases:Array=[]
var events:Array=[]
var errors:Array[String]=[]
var originals:Dictionary={}
var first_hover:Dictionary={}
var qa_admission_count:=0
var draws:=0
const BASELINE_SHA:="ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e"
const YAW:=-PI/2.0
const PITCH:=-.32
func _initialize()->void:
	started=Time.get_ticks_usec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-side="):side=arg.trim_prefix("--qa-side=")
		if arg.begins_with("--qa-pack="):pack_path=arg.trim_prefix("--qa-pack=")
		if arg.begins_with("--qa-sha="):expected_sha=arg.trim_prefix("--qa-sha=")
	root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000)) # No unfinished demo on the user's desktop; same on both measured sides.
	physics_frame.connect(drive)
	RenderingServer.frame_post_draw.connect(drawn)
	run.call_deferred()
func check(ok:bool,label:String)->bool:
	if not ok:errors.append(label);print("CARGO_PERF_FAIL ",label)
	return ok
func _process(_dt:float)->bool:
	if not finished and Time.get_ticks_usec()-started>55000000:check(false,"55s internal deadline");finish()
	return false
func drive()->void:
	if finished or not is_instance_valid(p):return
	# Explicit QA logical admission separates rendering measurements from desktop
	# focus acceptance. No capture setter or gameplay state/ownership override.
	if not p._free_mouse_look:qa_admission_count+=1;p._free_mouse_look=true
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:
		check(false,"unexpected pointer capture");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func npc_count()->int:
	return scene.preview_population.residents.occupants().size() if scene.preview_population!=null and scene.preview_population.residents!=null else -1
func fixture()->Dictionary:
	var camera:Camera3D=p.get_preview_camera()
	var state:Dictionary=c.cargo.snapshot(c.generation)
	var actors:Array=[]
	for own:RefCounted in scene.preview_population.hit_owners:
		actors.append({"id":own._token.source_id,"bones":own._token.rig.get_bone_count(),"hp":own._row.hp,"position":str(own._token.body.global_position)})
	actors.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.id<b.id)
	var cargo_identity:Dictionary={}
	for entry:Dictionary in state.get("items",[]):cargo_identity[entry.item.weaponId]={"uid":entry.item.uid,"magazine":entry.item.fireState.magazine,"reserve":entry.item.fireState.reserveAmmo}
	return {"actors":actors,"npc":npc_count(),"buildings":scene._block.counts.buildings,"bodies":scene.find_children("*","CollisionObject3D",true,false).size(),"shapes":scene.find_children("*","CollisionShape3D",true,false).size(),"cargo_count":state.get("items",[]).size(),"used_units":state.get("used_units",-1),"cargo_identity":cargo_identity,"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"camera_basis":[camera.global_basis.x.x,camera.global_basis.x.y,camera.global_basis.x.z,camera.global_basis.y.x,camera.global_basis.y.y,camera.global_basis.y.z,camera.global_basis.z.x,camera.global_basis.z.y,camera.global_basis.z.z],"camera_top_level":camera.top_level,"fov":camera.fov,"yaw":p._camera_yaw,"pitch":p._camera_pitch,"player":[p.global_position.x,p.global_position.y,p.global_position.z],"window_open":c.window_open,"lid_open":t.compartments.is_open("trunk"),"mouse_mode":Input.mouse_mode,"window_focused":root.has_focus(),"window_position":[DisplayServer.window_get_position().x,DisplayServer.window_get_position().y],"unfocusable":root.unfocusable,"shots":w.shots_count,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"vram_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
func content_ok(state:Dictionary,label:String)->void:
	check(state.npc==3 and state.buildings==8,label+":3NPC/8buildings")
	check(state.actors.map(func(v:Dictionary)->String:return v.id)==["resident_169","resident_252","resident_72"],label+":original resident IDs")
	check(state.bodies==377 and state.shapes==377,label+":377 original collision bodies/shapes")
	check(state.cargo_count==14 and state.used_units==100 and state.cargo_identity==originals,label+":14 original UID/ammo unchanged")
	check(not state.camera_top_level and is_equal_approx(state.yaw,YAW) and is_equal_approx(state.pitch,PITCH),label+":unchanged attached camera")
	check(state.mouse_mode==Input.MOUSE_MODE_VISIBLE and state.unfocusable,label+":no pointer capture")
func drawn()->void:
	if finished:return
	draws+=1
	var now:=Time.get_ticks_usec()
	if not phase_name.is_empty():
		var row:Dictionary={"phase":phase_name,"at_us":now-started,"wall_ms":(now-last_draw)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"vram_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"drawcalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		samples.append(row)
		if first_hover.is_empty() and c.renderer.has_method("hover_snapshot"):
			var hover:Dictionary=c.renderer.hover_snapshot()
			if hover.get("active",false):
				first_hover={"at_us":now-started,"phase":phase_name,"hover":hover,"first_presented_wall_ms":row.wall_ms};events.append({"kind":"first_real_model_hover_presented","data":first_hover})
	last_draw=now
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func event(kind:String)->void:events.append({"kind":kind,"at_us":Time.get_ticks_usec()-started,"phase":phase_name})
func measure(label:String,open:bool)->void:
	var before:=fixture();content_ok(before,label+" before")
	if label=="01_closed_first_world_hover" and c.renderer.has_method("hover_snapshot"):
		check(not c.renderer.hover_snapshot().get("active",false),"no model hover prewarmed during modal setup")
	phase_name=label;phase_start=Time.get_ticks_usec();last_draw=phase_start
	var begin_index:=samples.size();event("public_open" if open else "public_close_no_capture")
	if open:check(c.open_window(),label+":public open permitted")
	else:c.close_window(false)
	for i in 240:
		await RenderingServer.frame_post_draw
		if finished:return
	phase_name=""
	var after:=fixture();content_ok(after,label+" after")
	check(after.window_open==open,label+":requested modal state")
	check(after.shots==before.shots,label+":no accidental shot")
	var rows:=samples.slice(begin_index)
	check(rows.size()==240,label+":240 rendered frames")
	var phase:Dictionary={"label":label,"transition_us":phase_start-started,"before":before,"after":after,"frames":rows.size()}
	for field:String in ["wall_ms","gpu_ms","render_cpu_ms","static_bytes","vram_bytes","drawcalls","primitives"]:phase[field]=stats(rows,field)
	check(float(phase.gpu_ms.p95)>0,label+":GPU timestamp evidence")
	phases.append(phase)
	# Full-scene scans, ray receipt and image readback are outside timing intervals.
	var context:Dictionary=c.aim_context();phase.actual_aim=context
	phase.end_us=Time.get_ticks_usec()-started
	if not str(context.get("item_uid","")).is_empty():check(originals.values().any(func(v:Dictionary)->bool:return v.uid==context.item_uid),label+":actual aim references original stored UID")
	var image:=root.get_texture().get_image();check(image.save_png(output.path_join(label+".png"))==OK,label+":PNG")
	await RenderingServer.frame_post_draw
func stats(rows:Array,field:String)->Dictionary:
	var values:Array=[]
	for row:Dictionary in rows:values.append(float(row[field]))
	values.sort()
	if values.is_empty():return {"n":0,"p50":0,"p95":0,"max":0}
	return {"n":values.size(),"p50":values[int(ceil(values.size()*.5))-1],"p95":values[int(ceil(values.size()*.95))-1],"max":values[-1]}
func finish()->void:
	if finished:return
	finished=true
	if is_instance_valid(p):p._free_mouse_look=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var result:Dictionary={"schema":"cargo-render-pair/v1","side":side,"pack_sha256":FileAccess.get_sha256(pack_path) if FileAccess.file_exists(pack_path) else "","harness_sha256":FileAccess.get_sha256(get_script().resource_path),"errors":errors,"valid":errors.is_empty(),"seconds":(Time.get_ticks_usec()-started)/1000000.0,"phases":phases,"samples":samples,"events":events,"first_hover":first_hover,"first_hover_status":"observed_real_model" if not first_hover.is_empty() else "SKIP:attached ray did not produce new-model hover; no isolated camera substitution","qa_logical_reacquisitions":qa_admission_count,"settings":{"size":[1280,720],"taa":root.use_taa,"msaa":root.msaa_3d,"vsync":"disabled","window":"offscreen_NO_FOCUS","nominal_window_position":[-32000,-32000],"yaw":YAW,"pitch":PITCH,"frame_samples_per_phase":240},"limitations":["Offscreen NO_FOCUS rates are conditional; compare only same position/flags/settings and desktop conditions","Public API rendering+ownership scenario, not E/F/GUI acceptance","First interval starts at public transition clock; raw frames retain first-use stalls","First actual model hover optional; fixed attached camera never replaced","No true-cold cache claim; root records cache policy","No CPU frame monitor treated as frame timing"]}
	if not output.is_empty():FileAccess.open(output.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"	"))
	print("CARGO_PERF_RESULT ",JSON.stringify({"valid":result.valid,"errors":errors,"phases":phases.size(),"seconds":result.seconds}))
	quit(0 if errors.is_empty() else 2)
func run()->void:
	if DisplayServer.get_name()=="headless" or not output.is_absolute_path() or side not in ["baseline","candidate"] or not FileAccess.file_exists(pack_path):quit(3);return
	if not check(FileAccess.get_sha256(pack_path)==expected_sha,"exact requested PCK") or (side=="baseline" and not check(expected_sha==BASELINE_SHA,"accepted11 baseline")):finish();return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.use_taa=true;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready:
		await step()
		if finished:return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo");p._free_mouse_look=true
	await step(60)
	if not check(npc_count()==3,"native population ready; no forced admission"):finish();return
	var profile:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(profile.position_local_m+profile.outward_local*.9);p.global_position.y=.01
	p._camera_yaw=YAW;p._camera_pitch=PITCH;p._update_camera_rotation();await step(5)
	check(not p.get_preview_camera().top_level,"ordinary spring arm retained")
	t.compartments.set_open("trunk",true);await step(100)
	if not check(c.open_window(),"actual accessible hatch opened"):finish();return
	for id:String in load("res://scripts/weapons/weapon_fire.gd").ids():
		if not check(w.equip(id).get("ok",false),"real equip "+id):finish();return
		originals[id]={"uid":w.inventory.get_item_uid(id),"magazine":int(w.fire_state.magazine),"reserve":int(w.fire_state.reserveAmmo)}
		if not c.window_open:check(c.open_window(),"public contents reopen for store")
		if not check(c.window_store().get("ok",false),"real finite inventory store "+id):finish();return
	# Remain modal through warmup so no new world highlight was drawn yet.
	await step(60)
	content_ok(fixture(),"prepared full scene")
	if not errors.is_empty():finish();return
	await measure("01_closed_first_world_hover",false)
	if finished:return
	await measure("02_open_contents",true)
	if finished:return
	await measure("03_closed_return",false)
	if finished:return
	finish()
