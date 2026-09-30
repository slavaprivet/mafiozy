extends SceneTree
# Root-only rendered UI acceptance. Actual compiled main, original population and physics.
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var out:=""
var revision:=""
var report:Dictionary={"checks":0,"errors":[],"images":[],"clicks":[],"phases":[],"compiled":{},"scope":"Offscreen GUI acceptance, not native-camera or statistically comparable performance acceptance. 800x600 uses explicit 1:1 logical viewport to exercise responsive layout."}
var begun:int
var done:=false
var originals:Dictionary={}
var capture_samples:Array=[]
var qa_reacquisitions:=0
var last_pointer:=Vector2.ZERO
func _initialize()->void:
	begun=Time.get_ticks_msec();root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-revision="):revision=arg.trim_prefix("--qa-revision=")
		if arg.begins_with("--qa-pack-sha="):report.pack_sha256=arg.trim_prefix("--qa-pack-sha=")
	run.call_deferred()
func _process(_dt:float)->bool:
	if not done and Time.get_ticks_msec()-begun>37000:check(false,"37 second internal deadline");finish()
	if done:return false
	return false
func check(ok:bool,label:String)->void:
	report.checks+=1
	if not ok:report.errors.append(label);print("FAIL ",label);finish()
func step(n:int=1)->void:
	for i in n:
		if done:return
		await physics_frame;await process_frame
		if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:release_and_record("unexpected between physics frames")
func drawn(n:int=2)->void:
	for i in n:
		if done:return
		await RenderingServer.frame_post_draw
		if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:release_and_record("unexpected between rendered frames")
	if is_instance_valid(c) and c.window_open:pointer_trace("after %d rendered frames"%n)
func count_npc()->int:
	return scene.preview_population.residents.occupants().size() if scene.preview_population!=null and scene.preview_population.residents!=null else -1
func fixture()->Dictionary:
	return {"npc":count_npc(),"buildings":scene._block.counts.buildings,"bodies":scene.find_children("*","CollisionObject3D",true,false).size(),"shapes":scene.find_children("*","CollisionShape3D",true,false).size(),"population":scene.preview_population.snapshot(),"frames":Engine.get_frames_drawn(),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"camera":str(p.get_preview_camera().global_transform)}
func release_and_record(label:String)->void:
	var observed:int=Input.mouse_mode
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var row:Dictionary={"label":label,"observed_before_safety_release":observed,"released":Input.mouse_mode,"frame":Engine.get_process_frames(),"focused_cached":root.has_focus(),"unfocusable":root.unfocusable,"no_focus_flag":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)}
	if is_instance_valid(p):row.logical_free=p._free_mouse_look
	report.get_or_add("input_mode_readbacks",[]).append(row)
	check(observed==Input.MOUSE_MODE_VISIBLE,label+": runtime did not capture NO_FOCUS window (read before safety release)")
	if done:return
func pointer_trace(label:String)->void:
	if not is_instance_valid(c) or not is_instance_valid(c._window):return
	var view:Control=c._window
	var row:Dictionary={"label":label,"event_requested":str(last_pointer),"viewport_polled":str(root.get_mouse_position()),"global_polled":str(view.get_global_mouse_position()),"cached":str(view.get("_pointer_position")),"cached_valid":view.get("_pointer_valid"),"hovered_uid":view.hovered_uid,"frame":Engine.get_process_frames(),"visible":view.visible,"scroll":str(view.scroll.get_global_rect()),"scroll_vertical":view.scroll.scroll_vertical,"focused_cached":root.has_focus(),"unfocusable":root.unfocusable}
	report.get_or_add("pointer_trace",[]).append(row)
func key(code:int)->void:
	if done:return
	if code in [KEY_F,KEY_Q] and is_instance_valid(c) and not c.window_open and not p._free_mouse_look:
		# Explicit synthetic admission after the no-focus runtime suspend guard.
		p._free_mouse_look=true;qa_reacquisitions+=1
	for pressed:bool in [true,false]:
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e);Input.flush_buffered_events()
		release_and_record("key %d down=%s"%[code,pressed])
		if done:return
func pointer(at:Vector2)->void:
	if done:return
	last_pointer=at
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion);Input.flush_buffered_events()
	release_and_record("mouse motion")
	pointer_trace("immediately after accepted motion")
func gui_click(button:Button,label:String,safe_close:bool=false)->void:
	if done:return
	check(is_instance_valid(button),label+": button still live")
	if done:return
	if done:return
	var rect:=button.get_global_rect();var position:=rect.get_center();var button_text:=button.text
	check(button.is_visible_in_tree() and not button.disabled,label+": visible enabled button")
	if done:return
	check(root.get_visible_rect().encloses(rect),label+": button entirely inside viewport")
	if done:return
	var before_shots:int=w.shots_count
	if safe_close:p._free_mouse_look=false # Avoid OS capture in production close; dispatch is synchronous.
	pointer(position)
	if done:return
	for pressed:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=position;e.global_position=position;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e);Input.flush_buffered_events()
		release_and_record(label+" LMB down="+str(pressed))
		if done:return
	if safe_close:p._free_mouse_look=true
	report.clicks.append({"label":label,"button_text":button_text,"rect":str(rect),"position":str(position),"dispatch":"Input.parse_input_event motion+LMB press/release, no signal emission"})
	await drawn(3)
	if done:return
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,label+": OS cursor remains free")
	if done:return
	check(w.shots_count==before_shots,label+": GUI click never fires")
	if done:return
func pct(values:Array,q:float)->float:
	if values.is_empty():return -1.0
	var sorted:=values.duplicate();sorted.sort();return float(sorted[clampi(int(ceil(sorted.size()*q))-1,0,sorted.size()-1)])
func stats(values:Array)->Dictionary:return {"n":values.size(),"p50":pct(values,.5),"p95":pct(values,.95),"max":pct(values,1)}
func phase(label:String)->void:
	await drawn(12)
	if done:return
	var before:=fixture();var frames:Array=[];var gpu:Array=[];var draws:Array=[];var previous:=Time.get_ticks_usec()
	for i in 60:
		await RenderingServer.frame_post_draw
		if done:return
		var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		gpu.append(RenderingServer.call("viewport_get_measured_render_time_gpu",root.get_viewport_rid()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var after:=fixture()
	check(before.npc==3 and after.npc==3 and before.buildings==8 and after.buildings==8,label+": full population and buildings retained")
	if done:return
	check(before.bodies==377 and after.bodies==377 and before.shapes==377 and after.shapes==377,label+": original 377 collision objects/shapes retained")
	if done:return
	check(after.frames-before.frames>=58 and pct(draws,.5)>0 and pct(gpu,.95)>0,label+": rendered GPU work measured")
	if done:return
	report.phases.append({"label":label,"frame_wall_ms":stats(frames),"gpu_ms":stats(gpu),"draw_calls":stats(draws),"before":before,"after":after,"raw_frame_ms":frames,"raw_gpu_ms":gpu})
func image_save(label:String,target:Vector2i)->void:
	await drawn(3)
	if done:return
	var image:=root.get_texture().get_image()
	check(image.get_size()==target,label+": exact PNG dimensions")
	if done:return
	check(image.save_png(out.path_join(label+".png"))==OK,label+": PNG written")
	if done:return
	var info:Dictionary={"name":label+".png","pixels":str(image.get_size()),"viewport":str(root.get_visible_rect()),"npc":count_npc(),"mouse_mode":Input.mouse_mode,"arsenal_open":w.menu_open,"cargo_open":c.window_open}
	if c.window_open:
		info.panel=str(c._window.panel.get_global_rect());info.scroll=str(c._window.scroll.get_global_rect());info.summary=c._window.summary.text;info.cards=c._window.cards.size();info.columns=c._window.grid.columns
		check(root.get_visible_rect().encloses(c._window.panel.get_global_rect()),label+": outer panel has no overflow")
		if done:return
		check(root.get_visible_rect().encloses(c._window.store_button.get_global_rect()),label+": store button accessible")
		if done:return
	report.images.append(info)
func resize(size:Vector2i)->void:
	root.size=size;root.content_scale_size=size;await drawn(5)
	if done:return
func world_photo(id:String,index:int)->void:
	p._free_mouse_look=true
	var uid:String=originals[id].uid
	var camera:Camera3D=p.get_preview_camera()
	var prior_local:Transform3D=camera.transform;var prior_top:bool=camera.top_level
	var prior_parent:Node=camera.get_parent();var prior_index:int=camera.get_index()
	# SpringArm mutates direct camera-child position even when top_level=true.
	# Reparent the SAME camera; player/picker references remain untouched.
	camera.reparent(scene,true)
	var access:Dictionary=t.compartments.access_profile("trunk")
	var origin:Vector3=t.body.to_global(access.position_local_m+access.outward_local*1.5)+Vector3.UP*.7
	check(c.renderer._trunks.has(c.vehicle_id) and c.renderer._trunks[c.vehicle_id].items.has(uid),"world observer exact live cargo model "+id)
	if done:return
	if done:return
	var row:Dictionary=c.renderer._trunks[c.vehicle_id].items[uid]
	var found:=false;var attempts:=0
	for part:Dictionary in row.parts:
		if not part.visible:continue
		attempts+=1
		if attempts>12:break
		var mesh:Mesh=part.mesh
		var point:Vector3=row.visual.global_transform*part.transform*mesh.get_aabb().get_center()
		camera.global_position=origin;camera.look_at(point,Vector3.UP)
		if c.aim_context().item_uid==uid:found=true;break
	check(found,"native world hover visible-part center fixture "+id)
	if done:return
	if found:
		var observer_transform:Transform3D=camera.global_transform
		var pre_hover:Dictionary=c.renderer.hover_snapshot()
		var update_start:=Time.get_ticks_usec();c._refresh=0;c._process(0)
		var update_us:=Time.get_ticks_usec()-update_start
		var hover_frames:Array=[];var hover_gpu:Array=[];var hover_draws:Array=[];var previous:=Time.get_ticks_usec()
		for sample in 12:
			await RenderingServer.frame_post_draw
			if done:return
			var now:=Time.get_ticks_usec();hover_frames.append((now-previous)/1000.0);previous=now
			hover_gpu.append(RenderingServer.call("viewport_get_measured_render_time_gpu",root.get_viewport_rid()))
			hover_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		report.get_or_add("world_first_hover",[]).append({"id":id,"before":pre_hover,"after":c.renderer.hover_snapshot(),"actual_context_refresh_us":update_us,"wall_ms":stats(hover_frames),"gpu_ms":stats(hover_gpu),"draws":hover_draws,"raw_wall_ms":hover_frames,"raw_gpu_ms":hover_gpu,"camera":str(camera.global_transform),"scope":"First actual set_hover and following12 rendered frames at identical observer camera; includes cold first frame, no PNG. No isolated no-overlay baseline claimed."})
		check(camera.global_transform.is_equal_approx(observer_transform),"observer camera retained exact pose through12 rendered/physics frames "+id)
		if done:return
		check(p.get_preview_camera()==camera and camera.get_parent()==scene,"real picker retains same reparented camera object "+id)
		if done:return
		var hover:Dictionary=c.renderer.hover_snapshot()
		check(hover.get("active",false) and hover.get("item_uid")==uid,"actual rendered depth-tested model highlight "+id)
		if done:return
		report.get_or_add("world_observers",[]).append({"id":id,"uid":uid,"attempts":attempts,"camera":str(camera.global_transform),"hover":hover,"hint":str(c._hint.get_global_rect()),"scope":"Explicit near-rear QA observer: SAME original camera reparented to main scene temporarily; player physics/NPC/collisions stay active; <=12part AABBcenters; no triangle scan or ordinary-camera behavioral claim"})
		await image_save("world_%02d_%s_hover"%[index,id],Vector2i(1280,720))
		if done:return
		key(KEY_E);await drawn(3)
		if done:return
		check(not c.window_open and w.inventory.get_item_uid(id)==uid,"actual world E takes highlighted exact UID "+id)
		if done:return
		check(w.fire_state.magazine==originals[id].magazine and w.fire_state.reserveAmmo==originals[id].reserve,"actual world E preserves ammunition "+id)
		if done:return
		key(KEY_G);await drawn(3)
		if done:return
		check(c.cargo.snapshot(c.generation).used_units==100,"actual world G restores exact cargo "+id)
		if done:return
	camera.reparent(prior_parent,true);prior_parent.move_child(camera,prior_index)
	camera.top_level=prior_top;camera.transform=prior_local;p._update_camera_rotation()
	check(p.get_preview_camera()==camera and camera.get_parent()==prior_parent,"original camera and SpringArm parenting restored "+id)
	if done:return
	await step(3)
	if done:return

func finish()->void:
	if done:return
	done=true;report.capture_samples=capture_samples;report.qa_virtual_reacquisitions=qa_reacquisitions;report.seconds=(Time.get_ticks_msec()-begun)/1000.0;report.valid=report.errors.is_empty()
	if is_instance_valid(p):p._free_mouse_look=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRUNK_GUI_RESULT ",JSON.stringify({"checks":report.checks,"errors":report.errors,"seconds":report.seconds}))
	_cleanup_and_quit.call_deferred()
func _cleanup_and_quit()->void:
	# Teardown runs production _exit_tree hooks (including native cursor release).
	# It is deferred so failfast callers first unwind without touching freed owners.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(scene):scene.free()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	report.cleanup={"scene_freed":not is_instance_valid(scene),"one_process_frame_after_exit":true,"mouse_mode":Input.mouse_mode}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if report.valid else 2)
func run()->void:
	if not out.is_absolute_path() or revision.is_empty() or DisplayServer.get_name()=="headless":quit(3);return
	if not RenderingServer.has_method("viewport_get_measured_render_time_gpu"):check(false,"renderer timing API unavailable");finish();return
	if done:return
	RenderingServer.call("viewport_set_measure_render_time",root.get_viewport_rid(),true)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	# Synchronous rendered backend capability probe, no await/focus/gameplay claim.
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var capture_readback:int=Input.mouse_mode
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	report.backend_capture_probe={"requested":Input.MOUSE_MODE_CAPTURED,"read_back":capture_readback,"released":Input.mouse_mode,"focused":root.has_focus(),"scope":"Backend setter/readback only; no focus and no await while captured"}
	if done:return
	check(capture_readback==Input.MOUSE_MODE_CAPTURED and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"rendered backend capture/read/release synchronous")
	if done:return
	report.cursor_rasters=[]
	for cursor_name:String in ["arrow","hand"]:
		var texture:Texture2D=load("res://assets/ui/cursor_"+cursor_name+".svg")
		check(texture!=null,"compiled imported cursor "+cursor_name)
		if done:return
		if texture!=null:
			var cursor_image:=texture.get_image();var cursor_file:="cursor_"+cursor_name+"_actual_raster.png"
			check(cursor_image.save_png(out.path_join(cursor_file))==OK,"actual native cursor raster saved "+cursor_name)
			if done:return
			report.cursor_rasters.append({"file":cursor_file,"pixels":str(cursor_image.get_size()),"scope":"Exact imported texture pixels; hardware cursor is outside viewport PNG and is not composited here"})
	var notes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	report.revision=notes.get("runtime_revision","");check(report.revision==revision,"exact requested runtime revision")
	if done:return
	for path:String in ["res://scripts/weapons/walk_trunk_window.gd","res://scripts/weapons/preview_weapon_cargo.gd","res://scripts/weapons/weapon_cargo_bridge.gd","res://scripts/preview_player.gd","res://scripts/weapons/cargo_aim_picker.gd","res://scripts/weapons/weapon_pickup_visuals.gd"]:
		var script:Script=load(path);report.compiled[path]=script!=null and not script.has_source_code();check(report.compiled[path],"compiled PCK script "+path)
		if done:return
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not done and not scene.preview_ready:await step()
	if done:return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo");p._free_mouse_look=true
	check(root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"actual root NO_FOCUS flags retained after scene startup")
	if done:return
	var ready_until:=Time.get_ticks_msec()+5000
	while not done and count_npc()!=3 and Time.get_ticks_msec()<ready_until:await step()
	if done:return
	check(count_npc()==3,"all three actual residents admitted")
	if done:return
	if count_npc()!=3:finish();return
	await step(45)
	if done:return
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	var rear:Vector3=p.global_position-t.body.global_position
	p._camera_yaw=atan2(rear.x,rear.z);p._camera_pitch=-.32;p._update_camera_rotation()
	await step(5)
	if done:return
	t.compartments.set_open("trunk",true);await step(100)
	if done:return
	check(c._window_access(),"actual open rear hatch and unobstructed access")
	if done:return
	if not c._window_access():finish();return
	for id:String in load("res://scripts/weapons/weapon_fire.gd").ids():
		check(w.equip(id).get("ok",false),"equip real source item "+id)
		if done:return
		originals[id]={"uid":w.inventory.get_item_uid(id),"magazine":int(w.fire_state.magazine),"reserve":int(w.fire_state.reserveAmmo)}
		check(c.open_window(),"open valid contents "+id)
		if done:return
		check(c.window_store().get("ok",false),"transfer real inventory item "+id)
		if done:return
	var full:Dictionary=c.cargo.snapshot(c.generation)
	check(full.items.size()==14 and full.used_units==100 and w.inventory.get_owned_ids().is_empty(),"14 original UIDs, 100 units, no synthetic inventory")
	if done:return
	report.originals=originals;report.full_contents=full
	c.close_window(false)
	check(c.renderer.has_method("set_hover") and c.renderer.has_method("hover_snapshot"),"merged actual world hover renderer installed")
	if done:return
	await step(20)
	if done:return
	await phase("1280_loaded_cargo_window_closed")
	if done:return
	check(c._hint.visible,"compact world trunk hint actually visible in attached orbit")
	if done:return
	check(c._hint.action_rows[0].key.text=="E" and c._hint.action_rows[1].key.text=="F","compact world prompt uses E and F")
	if done:return
	check(c._hint.size.x<=380 and c._hint.size.y<=180,"compact world hint bounded footprint")
	if done:return
	report.world_hint={"rect":str(c._hint.get_global_rect()),"heading":c._hint.heading.text,"layout":c._hint.layout_receipt,"actions":[c._hint.action_rows[0].label.text,c._hint.action_rows[1].label.text],"aim":c.aim_context()}
	await image_save("01_compact_world_hint_1280x720",Vector2i(1280,720))
	if done:return
	# A normal orbit looking away proves E is not intercepted by contents UI.
	var saved_yaw:float=p._camera_yaw
	p._camera_yaw+=PI;p._update_camera_rotation();await step(5)
	if done:return
	check(str(c.aim_context().item_uid).is_empty(),"unhovered world E fixture has no picked weapon")
	if done:return
	key(KEY_E);await step(3)
	if done:return
	check(not c.window_open and not t.compartments.is_open("trunk") and not t._e_down,"unhovered world E closes real hatch through transport")
	if done:return
	key(KEY_F);await step(2);check(not c.window_open,"F never opens closed hatch")
	if done:return
	if done:return
	key(KEY_E);await step(100)
	if done:return
	check(t.compartments.is_open("trunk") and not c.window_open,"world E opens hatch without opening contents")
	if done:return
	p._camera_yaw=saved_yaw;p._update_camera_rotation();await step(5)
	if done:return
	key(KEY_F);await drawn(3)
	if done:return
	check(c.window_open and not w.menu_open and not t._e_down and t.phase=="ON_FOOT","native F opens trunk without seat fallthrough")
	if done:return
	var first_id:String=originals.keys()[0]
	var first:Dictionary=originals[first_id]
	var first_button:Button=c._window.cards[first.uid].button
	c._window.scroll.ensure_control_visible(first_button);await drawn(3)
	if done:return
	pointer(first_button.get_global_rect().get_center());await drawn(3)
	if done:return
	check(c._window.hovered_item_uid()==first.uid,"real mouse hover selects first exact UID")
	if done:return
	check(c._window.cards[first.uid].panel.get_theme_stylebox("panel")==c._window._hover_card,"hovered card uses gold highlight material")
	if done:return
	await image_save("02_hovered_card_1280x720",Vector2i(1280,720))
	if done:return
	await phase("1280_loaded_cargo_window_open")
	if done:return
	var no_shots:int=w.shots_count
	key(KEY_E);await drawn(4)
	if done:return
	check(not c.window_open and w.inventory.get_item_uid(first_id)==first.uid and w.fire_state.weaponId==first_id,"hover E takes exact UID and auto closes")
	if done:return
	check(w.fire_state.magazine==first.magazine and w.fire_state.reserveAmmo==first.reserve,"hover E retains finite ammunition")
	if done:return
	check(not p._free_mouse_look and not w.controls_blocked() and not w._held and w.shots_count==no_shots,"hover E suspends safely in NO_FOCUS without rogue shot")
	if done:return
	capture_samples.append({"action":"hover E","logical_free":p._free_mouse_look,"controls_blocked":w.controls_blocked(),"os_mode":Input.mouse_mode,"focused":root.has_focus(),"expected":"free=false and visible due NO_FOCUS suspend; focused gameplay capture intentionally untested"})
	key(KEY_F);await drawn(3);check(c.window_open,"F reopens after hover take")
	if done:return
	if done:return
	var before_stale:Dictionary=w.inventory.snapshot()
	check(not c.window_take(first.uid).get("ok",false) and c.window_open and w.inventory.snapshot()==before_stale,"stale UID fails and leaves modal open")
	if done:return
	await gui_click(c._window.store_button,"store first item after F reopen")
	if done:return
	check(c.cargo.snapshot(c.generation).used_units==100,"first item returns to cargo capacity100")
	if done:return
	pointer(c._window.panel.position+Vector2(8,8));await drawn(2)
	if done:return
	var no_hover:Dictionary=w.inventory.snapshot();key(KEY_E);await drawn(3)
	if done:return
	check(c.window_open and w.inventory.snapshot()==no_hover and t.compartments.is_open("trunk") and not t._e_down,"modal E without card hover never takes/closes/seats")
	if done:return
	var second_id:String=originals.keys()[1];var second:Dictionary=originals[second_id]
	var second_button:Button=c._window.cards[second.uid].button
	c._window.scroll.ensure_control_visible(second_button);await drawn(3)
	if done:return
	await gui_click(second_button,"real mouse Take returns to game")
	if done:return
	check(not c.window_open and w.inventory.get_item_uid(second_id)==second.uid and w.fire_state.weaponId==second_id,"real LMB transfers exact second UID and auto closes")
	if done:return
	check(w.fire_state.magazine==second.magazine and w.fire_state.reserveAmmo==second.reserve,"real LMB retains finite ammunition")
	if done:return
	await drawn(4)
	if done:return
	check(not p._free_mouse_look and not w.controls_blocked() and not w._held and w.shots_count==no_shots,"real LMB suspends in NO_FOCUS and activation release never leaks into firing")
	if done:return
	capture_samples.append({"action":"GUI LMB","logical_free":p._free_mouse_look,"controls_blocked":w.controls_blocked(),"os_mode":Input.mouse_mode,"focused":root.has_focus(),"expected":"free=false and visible due NO_FOCUS suspend; focused gameplay capture intentionally untested"})
	key(KEY_F);await drawn(3);check(c.window_open,"F reopens after mouse Take")
	if done:return
	if done:return
	await gui_click(c._window.store_button,"store second item after F reopen")
	if done:return
	check(c.cargo.snapshot(c.generation).used_units==100,"second item returns to cargo capacity100")
	if done:return
	c.close_window(false)
	await world_photo("tt_pistol",1);await world_photo("nagan",2)
	if done:return
	key(KEY_F);await drawn(3);check(c.window_open,"F opens after real world E/G checks")
	if done:return
	if done:return
	await resize(Vector2i(800,600));c._window.scroll.scroll_vertical=0;await drawn(3)
	if done:return
	var highlight_uid:String=c._window.cards.keys()[0]
	pointer(c._window.cards[highlight_uid].button.get_global_rect().get_center());await drawn(3)
	if done:return
	check(c._window.hovered_item_uid()==highlight_uid,"800 card hover uses actual layout")
	if done:return
	await image_save("03_hovered_card_800x600",Vector2i(800,600))
	if done:return
	var last_id:String=originals.keys()[-1];var last_uid:String=originals[last_id].uid
	var last_button:Button=c._window.cards[last_uid].button
	c._window.scroll.ensure_control_visible(last_button);await drawn(3)
	if done:return
	check(c._window.scroll.get_global_rect().encloses(last_button.get_global_rect()),"last item reachable by real scroll at800")
	if done:return
	pointer(last_button.get_global_rect().get_center());await drawn(3)
	if done:return
	await image_save("04_last_row_hover_800x600",Vector2i(800,600))
	if done:return
	await gui_click(last_button,"take last card at800")
	if done:return
	check(not c.window_open and w.inventory.get_item_uid(last_id)==last_uid,"800 actual last-card click takes UID and auto closes")
	if done:return
	key(KEY_F);await drawn(3);check(c.window_open,"F reopens at800 after auto return")
	if done:return
	if done:return
	await gui_click(c._window.store_button,"store last item at800")
	if done:return
	var close_button:Button
	for node:Node in c._window.panel.find_children("*","Button",true,false):
		check(node.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"UI button requests custom pointing hand")
		if done:return
		if node.text=="Закрыть  ×":close_button=node
	check(close_button!=null,"visible close button exists")
	if done:return
	if close_button!=null:await gui_click(close_button,"close at800")
	if done:return
	check(not c.window_open and not w.menu_open,"close button dismisses only cargo")
	if done:return
	key(KEY_Q);await drawn(3);check(w.menu_open and not c.window_open,"native Q arsenal never overlaps trunk")
	if done:return
	if done:return
	await image_save("05_arsenal_800x600",Vector2i(800,600))
	if done:return
	p._free_mouse_look=false;w.set_menu(false);p._free_mouse_look=true
	key(KEY_F);await drawn(2);check(c.window_open,"reopen by native F")
	if done:return
	if done:return
	key(KEY_Q);await drawn(2);check(not c.window_open and not w.menu_open,"Q closes trunk without opening arsenal")
	if done:return
	if done:return
	key(KEY_F);await drawn(2)
	if done:return
	var final_before:Dictionary=c.cargo.snapshot(c.generation)
	t.compartments.set_open("trunk",false)
	check(not c.window_take(last_uid).get("ok",false),"same-frame closed-lid stale take rejected")
	if done:return
	await step(12)
	if done:return
	check(not c.window_open and c.cargo.snapshot(c.generation).items==final_before.items,"closed lid closes window and preserves all contents")
	if done:return
	check(not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"automatic invalidation leaves consistent released controls")
	if done:return
	check(c.cargo.snapshot(c.generation).used_units==100 and c.cargo.snapshot(c.generation).items.size()==14,"all 14 exact original items retained")
	if done:return
	report.final_contents=c.cargo.snapshot(c.generation);report.final_fixture=fixture()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"no OS mouse capture at completion")
	if done:return
	finish()
