extends SceneTree
## ROOT ONLY, PREPARED: exact-PCK sequential pair. No fake HP/force/impact.
const BASELINE_SHA:="8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741"
var scene:Node3D
var p:CharacterBody3D
var w:Node
var owners:Array=[]
var out:=""
var side:=""
var mode:="perf"
var pack:=""
var expected_sha:=""
var started:=0
var done:=false
var errors:Array[String]=[]
var samples:Array=[]
var phases:Array=[]
var events:Array=[]
var captures:Array=[]
var phase_name:=""
var last_draw:=0
var phase_frame:=0
var shots:=0
var impacts:=0
var aim_point:=Vector3.ZERO
var fixture_data:Dictionary={}
var pending_capture:=""
var saved_impact:Callable
var logical_reacquisitions:=0
func _initialize()->void:
	started=Time.get_ticks_usec();seed(231809)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-side="):side=arg.trim_prefix("--qa-side=")
		if arg.begins_with("--qa-mode="):mode=arg.trim_prefix("--qa-mode=")
		if arg.begins_with("--qa-pack="):pack=arg.trim_prefix("--qa-pack=")
		if arg.begins_with("--qa-sha="):expected_sha=arg.trim_prefix("--qa-sha=")
	root.unfocusable=true;DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	physics_frame.connect(drive);RenderingServer.frame_post_draw.connect(drawn)
	run.call_deferred()
func check(ok:bool,label:String)->bool:
	if not ok:errors.append(label);print("RPG_PAIR_FAIL ",label)
	return ok
func _process(_dt:float)->bool:
	if not done and Time.get_ticks_usec()-started>80000000:check(false,"80_second_internal_bound");finish()
	return false
func drive()->void:
	if done or not is_instance_valid(p):return
	# Explicit offline QA input admission, same on both sides; never an OS
	# capture claim. No pose/camera replacement and no gameplay authority edits.
	if not p._free_mouse_look:p._free_mouse_look=true;logical_reacquisitions+=1
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:check(false,"unexpected_OS_capture");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func ray(a:Vector3,b:Vector3)->Dictionary:
	return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,[p.get_rid()]))
func actors()->Array:
	var result:Array=[]
	for owner:RefCounted in owners:
		var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
		var original_body:Node3D=owner._token.body;var original_rig:Skeleton3D=owner._token.rig
		var body_in_tree:bool=is_instance_valid(original_body) and original_body.is_inside_tree() and not original_body.is_queued_for_deletion()
		var rig_in_tree:bool=is_instance_valid(original_rig) and original_rig.is_inside_tree() and not original_rig.is_queued_for_deletion()
		var position:Vector3=original_body.global_position if body_in_tree else Vector3.ZERO
		if physical.mode=="ACTIVE":position=physical._body._bodies.pelvis.global_position # QA read only; avoid a full energy/joint scan inside timing.
		var parts_in_tree:=0
		for part:RigidBody3D in physical.owned_bodies():
			if is_instance_valid(part) and part.is_inside_tree() and not part.is_queued_for_deletion():parts_in_tree+=1
		result.append({"id":owner._token.source_id,"hp":owner._row.hp,"dead":owner._row.get("dead",false),"medical":owner._row.get("_medicalDowned",false),"mode":physical.mode,"bodies":physical.owned_bodies().size(),"parts_in_tree":parts_in_tree,"body_in_tree":body_in_tree,"rig_in_tree":rig_in_tree,"retained":body_in_tree and rig_in_tree,"bones":original_rig.get_bone_count() if rig_in_tree else 0,"position":[position.x,position.y,position.z]})
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.id<b.id)
	return result
func snapshot()->Dictionary:
	var camera:Camera3D=p.get_preview_camera()
	var current_actors:Array=actors()
	# Occupants enumerates living interactive NPCs, intentionally excluding final
	# death. Retained original bodies/rigs measure scene content independently.
	var retained_npc:int=current_actors.filter(func(v:Dictionary)->bool:return v.retained).size()
	return {"actors":current_actors,"npc":retained_npc,"living_npc":scene.preview_population.residents.occupants().size(),"buildings":scene._block.counts.buildings,"colliders":scene.find_children("*","CollisionObject3D",true,false).size(),"shapes":scene.find_children("*","CollisionShape3D",true,false).size(),"camera_top_level":camera.top_level,"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"camera_basis":[camera.global_basis.x.x,camera.global_basis.x.y,camera.global_basis.x.z,camera.global_basis.y.x,camera.global_basis.y.y,camera.global_basis.y.z,camera.global_basis.z.x,camera.global_basis.z.y,camera.global_basis.z.z],"yaw":p._camera_yaw,"pitch":p._camera_pitch,"fov":camera.fov,"player":[p.global_position.x,p.global_position.y,p.global_position.z],"magazine":w.fire_state.magazine,"reserve":w.fire_state.reserveAmmo,"shots":shots,"impacts":impacts,"mouse_mode":Input.mouse_mode,"unfocusable":root.unfocusable}
func content_ok(value:Dictionary,label:String)->void:
	check(value.npc==3 and value.buildings==8 and value.colliders==377 and value.shapes==377,label+":full_original_content")
	check(value.actors.map(func(v:Dictionary)->String:return v.id)==["resident_169","resident_252","resident_72"],label+":original_IDs")
	check(value.actors.all(func(v:Dictionary)->bool:return v.bodies==16 and v.parts_in_tree==16 and v.body_in_tree and v.rig_in_tree and v.bones==28),label+":all_original_physical_parts_and_rigs_retained")
	check(not value.camera_top_level and value.mouse_mode==Input.MOUSE_MODE_VISIBLE and value.unfocusable,label+":attached_camera_no_OS_capture")
func choose_fixture()->bool:
	var center:=Vector3.ZERO
	for owner:RefCounted in owners:center+=owner._token.body.global_position
	center/=owners.size()
	var floor_hit:=ray(center+Vector3.UP*4,center-Vector3.UP*6)
	if floor_hit.is_empty():return false
	aim_point=floor_hit.position
	for dir:Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var proposed:Vector3=aim_point+dir*8
		var floor_under:=ray(proposed+Vector3.UP*4,proposed-Vector3.UP*6)
		if floor_under.is_empty():continue
		proposed=floor_under.position+Vector3.UP*.01
		var obstruction:=ray(proposed+Vector3.UP*1.4,aim_point+Vector3.UP*.03)
		if not obstruction.is_empty() and obstruction.position.distance_to(aim_point)>.2:continue
		p.global_position=proposed
		var pivot:Vector3=proposed+p._yaw_pivot.position
		var direction:Vector3=aim_point-pivot
		p._camera_yaw=atan2(-direction.x,-direction.z)
		p._camera_pitch=atan2(direction.y,Vector2(direction.x,direction.z).length())
		p._update_camera_rotation()
		return true
	return false
func mouse(down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=root.get_visible_rect().get_center();e.global_position=e.position
	Input.parse_input_event(e);Input.flush_buffered_events()
func reload_key()->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=KEY_R;e.physical_keycode=KEY_R;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func on_shot(shot:Dictionary,muzzle:Dictionary,_origin:Vector3,_direction:Vector3)->void:
	shots+=1
	# After the real shot updates shared critical context, seed only the source
	# medical-survival choices. Does not change HP or accept a fabricated hit.
	var rng:=RandomNumberGenerator.new()
	for n in 10000:
		rng.seed=n
		if rng.randf()>=.72 and rng.randf()>=.72 and rng.randf()>=.72:owners[0]._rng.seed=n;break
	events.append({"kind":"real_accepted_shot","shot":shot,"muzzle":muzzle,"phase":phase_name,"phase_frame":phase_frame,"at_us":Time.get_ticks_usec()-started})
func on_impact(receipt:Dictionary)->void:
	var before:Array=actors()
	# Unchanged original/native callback exactly once, before collecting evidence.
	saved_impact.call(receipt);impacts+=1
	var after:Array=actors()
	events.append({"kind":"real_native_impact","receipt":receipt,"before":before,"after":after,"phase":phase_name,"phase_frame":phase_frame,"at_us":Time.get_ticks_usec()-started})
	if impacts==1:
		if side=="candidate":check(after.any(func(v:Dictionary)->bool:return v.dead and v.mode=="ACTIVE"),"candidate_first_blast_actual_final_physical_death")
		else:check(after.all(func(v:Dictionary)->bool:return not v.dead and v.hp==60),"baseline_cosmetic_only_no_HP_change")
	if impacts==2 and side=="candidate":
		var point:Vector3=receipt.point;var corpse_near:=false
		for row:Dictionary in before:
			var xyz:Array=row.position
			if row.dead and Vector2(float(xyz[0])-point.x,float(xyz[2])-point.z).length()<=11.07:corpse_near=true
		check(corpse_near,"second_blast_near_real_lying_body")
		for row:Dictionary in before:
			if row.dead:
				var current:Array=after.filter(func(v:Dictionary)->bool:return v.id==row.id)
				check(current.size()==1 and current[0].hp==row.hp and current[0].dead,"final_dead_not_redamaged_"+row.id)
	if mode=="visual":pending_capture="%02d_impact"%impacts
func drawn()->void:
	if done:return
	var now:=Time.get_ticks_usec()
	if not phase_name.is_empty():
		phase_frame+=1
		samples.append({"phase":phase_name,"frame":phase_frame,"at_us":now-started,"utc":Time.get_unix_time_from_system(),"wall_ms":(now-last_draw)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"drawcalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	last_draw=now
	if mode=="visual" and not pending_capture.is_empty():
		var name:String=pending_capture;pending_capture=""
		var result:=root.get_texture().get_image().save_png(out.path_join(name+".png"))
		check(result==OK,"PNG_"+name);captures.append({"name":name,"at_us":now-started,"actors":actors(),"phase":phase_name,"frame":phase_frame})
func stats(rows:Array,key:String)->Dictionary:
	var values:Array=[]
	for row:Dictionary in rows:values.append(float(row[key]))
	values.sort()
	return {"n":values.size(),"p50":values[int(ceil(values.size()*.5))-1],"p95":values[int(ceil(values.size()*.95))-1],"max":values[-1]} if not values.is_empty() else {"n":0}
func measure(label:String,frames:int,shoot:bool)->void:
	var before:=snapshot();content_ok(before,label+":before")
	var index:=samples.size();phase_name=label;phase_frame=0;last_draw=Time.get_ticks_usec()
	var begin_utc:=Time.get_unix_time_from_system()
	if shoot:
		# Same accepted-shot critical and original spread RNG on both sides.
		# Post-shot callback separately seeds medical survival without HP edits.
		owners[0]._rng.seed=12345+shots;seed(231809+shots)
		mouse(true)
	for i in frames:
		await RenderingServer.frame_post_draw
		if done:return
		if shoot and i==1:mouse(false)
		if shoot and i==120:reload_key()
		if mode=="visual":
			if shoot and i==45:pending_capture=label+"_fall"
			if i==frames-2:pending_capture=label+"_settled" if shoot else "00_before"
	phase_name=""
	var end_utc:=Time.get_unix_time_from_system();var after:=snapshot();content_ok(after,label+":after")
	var rows:Array=samples.slice(index);check(rows.size()==frames,label+":complete_render_frames")
	var row:Dictionary={"label":label,"frames":rows.size(),"begin_utc":begin_utc,"end_utc":end_utc,"before":before,"after":after}
	for field:String in ["wall_ms","gpu_ms","render_cpu_ms","static_bytes","video_bytes","drawcalls","primitives"]:row[field]=stats(rows,field)
	check(float(row.gpu_ms.get("p95",0))>0,label+":GPU_timestamp_evidence")
	phases.append(row)
func run()->void:
	if DisplayServer.get_name()=="headless" or not out.is_absolute_path() or side not in ["baseline","candidate"] or mode not in ["perf","visual"]:quit(3);return
	if not check(FileAccess.get_sha256(pack)==expected_sha,"exact_PCK") or (side=="baseline" and not check(expected_sha==BASELINE_SHA,"accepted16_baseline")):finish();return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.use_taa=true;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready:
		await step()
		if done:return
	p=scene._player;w=scene.preview_weapons;owners=scene.preview_population.hit_owners.duplicate();p._free_mouse_look=true
	await step(60)
	check(owners.size()==3,"actual3owners");check(choose_fixture(),"original_supported_floor_fixture")
	check(w.equip("rpg").get("ok",false),"actual_RPG_equip");await step(20)
	fixture_data=snapshot();fixture_data.aim_point=[aim_point.x,aim_point.y,aim_point.z];content_ok(fixture_data,"fixture")
	if not errors.is_empty():finish();return
	saved_impact=w.rpg_effects._flight._impact_port;w.rpg_effects._flight._impact_port=on_impact
	w.shot_emitted.connect(on_shot)
	await measure("01_idle",240,false)
	if done:return
	await measure("02_first_blast_fall",360,true)
	if done:return
	check(shots==1 and impacts==1,"one_actual_first_launch_and_impact");check(w.fire_state.magazine==1,"real_reload_before_second_blast")
	await measure("03_second_blast_cleanup",360,true)
	if done:return
	check(shots==2 and impacts==2,"two_actual_launches_and_terminal_impacts")
	check(w.rpg_effects._flight._active==0,"all_real_flight_slots_retired")
	check(w.rpg_effects._explosion_count==0,"bounded_explosion_cleanup_complete")
	finish()
func finish()->void:
	if done:return
	done=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(p):p._free_mouse_look=false
	var value:Dictionary={"schema":"rpg-render-pair/v2","valid":errors.is_empty(),"errors":errors,"side":side,"mode":mode,"pack_sha256":expected_sha,"harness_sha256":FileAccess.get_sha256(get_script().resource_path),"seconds":(Time.get_ticks_usec()-started)/1000000.0,"fixture":fixture_data,"phases":phases,"samples":samples,"events":events,"captures":captures,"qa_logical_reacquisitions":logical_reacquisitions,"settings":{"size":[1280,720],"taa":root.use_taa,"msaa":root.msaa_3d,"vsync":"off","fixed_fps":60,"window":"offscreen_NO_FOCUS","position":[-32000,-32000],"frames":[240,360,360]},"limits":["Baseline16 has cosmetic-only blast; candidate includes real HP/ragdoll work. Additional physics cost expected, not identical workload.","All original3NPC/8buildings/377colliders/48parts retained; no culling or HP injection.","Ordinary attached spring arm and deterministic QA placement/clinical RNG; no fake impact.","Perf mode has NO image readbacks. Visual replay image overhead is not performance evidence.","Logical QA control admission bypasses desktop focus only; OS cursor never captured.","Offscreen fixed-delta wall/GPU timings are conditional; use same cache/desktop conditions."]}
	if not out.is_empty():FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(value,"\t"))
	print("RPG_PAIR_RESULT ",JSON.stringify({"valid":value.valid,"errors":errors,"seconds":value.seconds,"mode":mode}))
	quit(0 if errors.is_empty() else 2)
