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
	return false
func check(ok:bool,label:String)->void:
	report.checks+=1
	if not ok:report.errors.append(label);print("FAIL ",label)
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func drawn(n:int=2)->void:
	for i in n:await RenderingServer.frame_post_draw
func count_npc()->int:
	return scene.preview_population.residents.occupants().size() if scene.preview_population!=null and scene.preview_population.residents!=null else -1
func fixture()->Dictionary:
	return {"npc":count_npc(),"buildings":scene._block.counts.buildings,"bodies":scene.find_children("*","CollisionObject3D",true,false).size(),"shapes":scene.find_children("*","CollisionShape3D",true,false).size(),"population":scene.preview_population.snapshot(),"frames":Engine.get_frames_drawn(),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"camera":str(p.get_preview_camera().global_transform)}
func key(code:int)->void:
	if code in [KEY_F,KEY_Q] and is_instance_valid(c) and not c.window_open and not p._free_mouse_look:
		# Explicit synthetic admission after the no-focus runtime suspend guard.
		p._free_mouse_look=true;qa_reacquisitions+=1
	for pressed:bool in [true,false]:
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e);Input.flush_buffered_events()
func pointer(at:Vector2)->void:
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion);Input.flush_buffered_events()
func gui_click(button:Button,label:String,safe_close:bool=false)->void:
	var rect:=button.get_global_rect();var position:=rect.get_center()
	check(button.is_visible_in_tree() and not button.disabled,label+": visible enabled button")
	check(root.get_visible_rect().encloses(rect),label+": button entirely inside viewport")
	var before_shots:int=w.shots_count
	if safe_close:p._free_mouse_look=false # Avoid OS capture in production close; dispatch is synchronous.
	var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;Input.parse_input_event(motion);Input.flush_buffered_events()
	for pressed:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=position;e.global_position=position;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e);Input.flush_buffered_events()
	if safe_close:p._free_mouse_look=true
	report.clicks.append({"label":label,"button_text":button.text,"rect":str(rect),"position":str(position),"dispatch":"Input.parse_input_event motion+LMB press/release, no signal emission"})
	await drawn(3)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,label+": OS cursor remains free")
	check(w.shots_count==before_shots,label+": GUI click never fires")
func pct(values:Array,q:float)->float:
	if values.is_empty():return -1.0
	var sorted:=values.duplicate();sorted.sort();return float(sorted[clampi(int(ceil(sorted.size()*q))-1,0,sorted.size()-1)])
func stats(values:Array)->Dictionary:return {"n":values.size(),"p50":pct(values,.5),"p95":pct(values,.95),"max":pct(values,1)}
func phase(label:String)->void:
	await drawn(12)
	var before:=fixture();var frames:Array=[];var gpu:Array=[];var draws:Array=[];var previous:=Time.get_ticks_usec()
	for i in 60:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		gpu.append(RenderingServer.call("viewport_get_measured_render_time_gpu",root.get_viewport_rid()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var after:=fixture()
	check(before.npc==3 and after.npc==3 and before.buildings==8 and after.buildings==8,label+": full population and buildings retained")
	check(before.bodies==377 and after.bodies==377 and before.shapes==377 and after.shapes==377,label+": original 377 collision objects/shapes retained")
	check(after.frames-before.frames>=58 and pct(draws,.5)>0 and pct(gpu,.95)>0,label+": rendered GPU work measured")
	report.phases.append({"label":label,"frame_wall_ms":stats(frames),"gpu_ms":stats(gpu),"draw_calls":stats(draws),"before":before,"after":after,"raw_frame_ms":frames,"raw_gpu_ms":gpu})
func image_save(label:String,target:Vector2i)->void:
	await drawn(3)
	var image:=root.get_texture().get_image()
	check(image.get_size()==target,label+": exact PNG dimensions")
	check(image.save_png(out.path_join(label+".png"))==OK,label+": PNG written")
	var info:Dictionary={"name":label+".png","pixels":str(image.get_size()),"viewport":str(root.get_visible_rect()),"npc":count_npc(),"mouse_mode":Input.mouse_mode,"arsenal_open":w.menu_open,"cargo_open":c.window_open}
	if c.window_open:
		info.panel=str(c._window.panel.get_global_rect());info.scroll=str(c._window.scroll.get_global_rect());info.summary=c._window.summary.text;info.cards=c._window.cards.size();info.columns=c._window.grid.columns
		check(root.get_visible_rect().encloses(c._window.panel.get_global_rect()),label+": outer panel has no overflow")
		check(root.get_visible_rect().encloses(c._window.store_button.get_global_rect()),label+": store button accessible")
	report.images.append(info)
func resize(size:Vector2i)->void:
	root.size=size;root.content_scale_size=size;await drawn(5)
func world_photo(id:String,index:int)->void:
	p._free_mouse_look=true
	var uid:String=originals[id].uid
	var camera:Camera3D=p.get_preview_camera()
	var prior_local:Transform3D=camera.transform;var prior_top:bool=camera.top_level
	camera.top_level=true
	var access:Dictionary=t.compartments.access_profile("trunk")
	var origin:Vector3=t.body.to_global(access.position_local_m+access.outward_local*1.5)+Vector3.UP*.7
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
	if found:
		c._refresh=0;c._process(0);await drawn(3)
		var hover:Dictionary=c.renderer.hover_snapshot()
		check(hover.get("active",false) and hover.get("item_uid")==uid,"actual rendered depth-tested model highlight "+id)
		report.get_or_add("world_observers",[]).append({"id":id,"uid":uid,"attempts":attempts,"camera":str(camera.global_transform),"hover":hover,"hint":str(c._hint.get_global_rect()),"scope":"Explicit near-rear QA observer, <=12part AABBcenters; no triangle scan, no ordinary camera behavioral claim"})
		await image_save("world_%02d_%s_hover"%[index,id],Vector2i(1280,720))
		key(KEY_E);await drawn(3)
		check(not c.window_open and w.inventory.get_item_uid(id)==uid,"actual world E takes highlighted exact UID "+id)
		check(w.fire_state.magazine==originals[id].magazine and w.fire_state.reserveAmmo==originals[id].reserve,"actual world E preserves ammunition "+id)
		key(KEY_G);await drawn(3)
		check(c.cargo.snapshot(c.generation).used_units==100,"actual world G restores exact cargo "+id)
	camera.top_level=prior_top;camera.transform=prior_local;p._update_camera_rotation();await step(3)

func finish()->void:
	if done:return
	done=true;report.capture_samples=capture_samples;report.qa_virtual_reacquisitions=qa_reacquisitions;report.seconds=(Time.get_ticks_msec()-begun)/1000.0;report.valid=report.errors.is_empty()
	if is_instance_valid(p):p._free_mouse_look=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRUNK_GUI_RESULT ",JSON.stringify({"checks":report.checks,"errors":report.errors,"seconds":report.seconds}))
	quit(0 if report.valid else 2)
func run()->void:
	if not out.is_absolute_path() or revision.is_empty() or DisplayServer.get_name()=="headless":quit(3);return
	if not RenderingServer.has_method("viewport_get_measured_render_time_gpu"):check(false,"renderer timing API unavailable");finish();return
	RenderingServer.call("viewport_set_measure_render_time",root.get_viewport_rid(),true)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	# Synchronous rendered backend capability probe, no await/focus/gameplay claim.
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var capture_readback:int=Input.mouse_mode
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	report.backend_capture_probe={"requested":Input.MOUSE_MODE_CAPTURED,"read_back":capture_readback,"released":Input.mouse_mode,"focused":root.has_focus(),"scope":"Backend setter/readback only; no focus and no await while captured"}
	check(capture_readback==Input.MOUSE_MODE_CAPTURED and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"rendered backend capture/read/release synchronous")
	report.cursor_rasters=[]
	for cursor_name:String in ["arrow","hand"]:
		var texture:Texture2D=load("res://assets/ui/cursor_"+cursor_name+".svg")
		check(texture!=null,"compiled imported cursor "+cursor_name)
		if texture!=null:
			var cursor_image:=texture.get_image();var cursor_file:="cursor_"+cursor_name+"_actual_raster.png"
			check(cursor_image.save_png(out.path_join(cursor_file))==OK,"actual native cursor raster saved "+cursor_name)
			report.cursor_rasters.append({"file":cursor_file,"pixels":str(cursor_image.get_size()),"scope":"Exact imported texture pixels; hardware cursor is outside viewport PNG and is not composited here"})
	var notes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	report.revision=notes.get("runtime_revision","");check(report.revision==revision,"exact requested runtime revision")
	for path:String in ["res://scripts/weapons/walk_trunk_window.gd","res://scripts/weapons/preview_weapon_cargo.gd","res://scripts/weapons/weapon_cargo_bridge.gd","res://scripts/preview_player.gd","res://scripts/weapons/cargo_aim_picker.gd","res://scripts/weapons/weapon_pickup_visuals.gd"]:
		var script:Script=load(path);report.compiled[path]=script!=null and not script.has_source_code();check(report.compiled[path],"compiled PCK script "+path)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready:await step()
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo");p._free_mouse_look=true
	var ready_until:=Time.get_ticks_msec()+5000
	while count_npc()!=3 and Time.get_ticks_msec()<ready_until:await step()
	check(count_npc()==3,"all three actual residents admitted")
	if count_npc()!=3:finish();return
	await step(45)
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	var rear:Vector3=p.global_position-t.body.global_position
	p._camera_yaw=atan2(rear.x,rear.z);p._camera_pitch=-.32;p._update_camera_rotation()
	await step(5)
	t.compartments.set_open("trunk",true);await step(100)
	check(c._window_access(),"actual open rear hatch and unobstructed access")
	if not c._window_access():finish();return
	for id:String in load("res://scripts/weapons/weapon_fire.gd").ids():
		check(w.equip(id).get("ok",false),"equip real source item "+id)
		originals[id]={"uid":w.inventory.get_item_uid(id),"magazine":int(w.fire_state.magazine),"reserve":int(w.fire_state.reserveAmmo)}
		check(c.open_window(),"open valid contents "+id)
		check(c.window_store().get("ok",false),"transfer real inventory item "+id)
	var full:Dictionary=c.cargo.snapshot(c.generation)
	check(full.items.size()==14 and full.used_units==100 and w.inventory.get_owned_ids().is_empty(),"14 original UIDs, 100 units, no synthetic inventory")
	report.originals=originals;report.full_contents=full
	c.close_window(false)
	check(c.renderer.has_method("set_hover") and c.renderer.has_method("hover_snapshot"),"merged actual world hover renderer installed")
	await step(20)
	await phase("1280_loaded_cargo_window_closed")
	check(c._hint.visible,"compact world trunk hint actually visible in attached orbit")
	check(c._hint.action_rows[0].key.text=="E" and c._hint.action_rows[1].key.text=="F","compact world prompt uses E and F")
	check(c._hint.size.x<=380 and c._hint.size.y<=180,"compact world hint bounded footprint")
	report.world_hint={"rect":str(c._hint.get_global_rect()),"heading":c._hint.heading.text,"layout":c._hint.layout_receipt,"actions":[c._hint.action_rows[0].label.text,c._hint.action_rows[1].label.text],"aim":c.aim_context()}
	await image_save("01_compact_world_hint_1280x720",Vector2i(1280,720))
	# A normal orbit looking away proves E is not intercepted by contents UI.
	var saved_yaw:float=p._camera_yaw
	p._camera_yaw+=PI;p._update_camera_rotation();await step(5)
	check(str(c.aim_context().item_uid).is_empty(),"unhovered world E fixture has no picked weapon")
	key(KEY_E);await step(3)
	check(not c.window_open and not t.compartments.is_open("trunk") and not t._e_down,"unhovered world E closes real hatch through transport")
	key(KEY_F);await step(2);check(not c.window_open,"F never opens closed hatch")
	key(KEY_E);await step(100)
	check(t.compartments.is_open("trunk") and not c.window_open,"world E opens hatch without opening contents")
	p._camera_yaw=saved_yaw;p._update_camera_rotation();await step(5)
	key(KEY_F);await drawn(3)
	check(c.window_open and not w.menu_open and not t._e_down and t.phase=="ON_FOOT","native F opens trunk without seat fallthrough")
	var first_id:String=originals.keys()[0]
	var first:Dictionary=originals[first_id]
	var first_button:Button=c._window.cards[first.uid].button
	c._window.scroll.ensure_control_visible(first_button);await drawn(3)
	pointer(first_button.get_global_rect().get_center());await drawn(3)
	check(c._window.hovered_item_uid()==first.uid,"real mouse hover selects first exact UID")
	check(c._window.cards[first.uid].panel.get_theme_stylebox("panel")==c._window._hover_card,"hovered card uses gold highlight material")
	await image_save("02_hovered_card_1280x720",Vector2i(1280,720))
	await phase("1280_loaded_cargo_window_open")
	var no_shots:int=w.shots_count
	key(KEY_E);await drawn(4)
	check(not c.window_open and w.inventory.get_item_uid(first_id)==first.uid and w.fire_state.weaponId==first_id,"hover E takes exact UID and auto closes")
	check(w.fire_state.magazine==first.magazine and w.fire_state.reserveAmmo==first.reserve,"hover E retains finite ammunition")
	check(not p._free_mouse_look and not w.controls_blocked() and not w._held and w.shots_count==no_shots,"hover E suspends safely in NO_FOCUS without rogue shot")
	capture_samples.append({"action":"hover E","logical_free":p._free_mouse_look,"controls_blocked":w.controls_blocked(),"os_mode":Input.mouse_mode,"focused":root.has_focus(),"expected":"free=false and visible due NO_FOCUS suspend; focused gameplay capture intentionally untested"})
	key(KEY_F);await drawn(3);check(c.window_open,"F reopens after hover take")
	var before_stale:Dictionary=w.inventory.snapshot()
	check(not c.window_take(first.uid).get("ok",false) and c.window_open and w.inventory.snapshot()==before_stale,"stale UID fails and leaves modal open")
	await gui_click(c._window.store_button,"store first item after F reopen")
	check(c.cargo.snapshot(c.generation).used_units==100,"first item returns to cargo capacity100")
	pointer(c._window.panel.position+Vector2(8,8));await drawn(2)
	var no_hover:Dictionary=w.inventory.snapshot();key(KEY_E);await drawn(3)
	check(c.window_open and w.inventory.snapshot()==no_hover and t.compartments.is_open("trunk") and not t._e_down,"modal E without card hover never takes/closes/seats")
	var second_id:String=originals.keys()[1];var second:Dictionary=originals[second_id]
	var second_button:Button=c._window.cards[second.uid].button
	c._window.scroll.ensure_control_visible(second_button);await drawn(3)
	await gui_click(second_button,"real mouse Take returns to game")
	check(not c.window_open and w.inventory.get_item_uid(second_id)==second.uid and w.fire_state.weaponId==second_id,"real LMB transfers exact second UID and auto closes")
	check(w.fire_state.magazine==second.magazine and w.fire_state.reserveAmmo==second.reserve,"real LMB retains finite ammunition")
	await drawn(4)
	check(not p._free_mouse_look and not w.controls_blocked() and not w._held and w.shots_count==no_shots,"real LMB suspends in NO_FOCUS and activation release never leaks into firing")
	capture_samples.append({"action":"GUI LMB","logical_free":p._free_mouse_look,"controls_blocked":w.controls_blocked(),"os_mode":Input.mouse_mode,"focused":root.has_focus(),"expected":"free=false and visible due NO_FOCUS suspend; focused gameplay capture intentionally untested"})
	key(KEY_F);await drawn(3);check(c.window_open,"F reopens after mouse Take")
	await gui_click(c._window.store_button,"store second item after F reopen")
	check(c.cargo.snapshot(c.generation).used_units==100,"second item returns to cargo capacity100")
	c.close_window(false)
	await world_photo("tt_pistol",1);await world_photo("nagan",2)
	key(KEY_F);await drawn(3);check(c.window_open,"F opens after real world E/G checks")
	await resize(Vector2i(800,600));c._window.scroll.scroll_vertical=0;await drawn(3)
	var highlight_uid:String=c._window.cards.keys()[0]
	pointer(c._window.cards[highlight_uid].button.get_global_rect().get_center());await drawn(3)
	check(c._window.hovered_item_uid()==highlight_uid,"800 card hover uses actual layout")
	await image_save("03_hovered_card_800x600",Vector2i(800,600))
	var last_id:String=originals.keys()[-1];var last_uid:String=originals[last_id].uid
	var last_button:Button=c._window.cards[last_uid].button
	c._window.scroll.ensure_control_visible(last_button);await drawn(3)
	check(c._window.scroll.get_global_rect().encloses(last_button.get_global_rect()),"last item reachable by real scroll at800")
	pointer(last_button.get_global_rect().get_center());await drawn(3)
	await image_save("04_last_row_hover_800x600",Vector2i(800,600))
	await gui_click(last_button,"take last card at800")
	check(not c.window_open and w.inventory.get_item_uid(last_id)==last_uid,"800 actual last-card click takes UID and auto closes")
	key(KEY_F);await drawn(3);check(c.window_open,"F reopens at800 after auto return")
	await gui_click(c._window.store_button,"store last item at800")
	var close_button:Button
	for node:Node in c._window.panel.find_children("*","Button",true,false):
		check(node.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"UI button requests custom pointing hand")
		if node.text=="Закрыть  ×":close_button=node
	check(close_button!=null,"visible close button exists")
	if close_button!=null:await gui_click(close_button,"close at800")
	check(not c.window_open and not w.menu_open,"close button dismisses only cargo")
	key(KEY_Q);await drawn(3);check(w.menu_open and not c.window_open,"native Q arsenal never overlaps trunk")
	await image_save("05_arsenal_800x600",Vector2i(800,600))
	p._free_mouse_look=false;w.set_menu(false);p._free_mouse_look=true
	key(KEY_F);await drawn(2);check(c.window_open,"reopen by native F")
	key(KEY_Q);await drawn(2);check(not c.window_open and not w.menu_open,"Q closes trunk without opening arsenal")
	key(KEY_F);await drawn(2)
	var final_before:Dictionary=c.cargo.snapshot(c.generation)
	t.compartments.set_open("trunk",false)
	check(not c.window_take(last_uid).get("ok",false),"same-frame closed-lid stale take rejected")
	await step(12)
	check(not c.window_open and c.cargo.snapshot(c.generation).items==final_before.items,"closed lid closes window and preserves all contents")
	check(not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"automatic invalidation leaves consistent released controls")
	check(c.cargo.snapshot(c.generation).used_units==100 and c.cargo.snapshot(c.generation).items.size()==14,"all 14 exact original items retained")
	report.final_contents=c.cargo.snapshot(c.generation);report.final_fixture=fixture()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"no OS mouse capture at completion")
	finish()
