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
	for pressed:bool in [true,false]:
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e);Input.flush_buffered_events()
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
func finish()->void:
	if done:return
	done=true;report.seconds=(Time.get_ticks_msec()-begun)/1000.0;report.valid=report.errors.is_empty()
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
	var notes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/preview_updates.json"))
	report.revision=notes.get("runtime_revision","");check(report.revision==revision,"exact requested runtime revision")
	for path:String in ["res://scripts/weapons/walk_trunk_window.gd","res://scripts/weapons/preview_weapon_cargo.gd","res://scripts/weapons/weapon_cargo_bridge.gd","res://scripts/preview_player.gd"]:
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
	p._camera_yaw=-PI/2.0;p._camera_pitch=-.32;p._update_camera_rotation()
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
	c.close_window(false);await phase("1280_loaded_cargo_window_closed")
	key(KEY_E);await drawn(3)
	check(c.window_open and not w.menu_open and not t._e_down and t.phase=="ON_FOOT","native E opens trunk without seat fallthrough")
	await image_save("01_trunk_14_1280x720",Vector2i(1280,720));await phase("1280_loaded_cargo_window_open")
	var tested:=0
	for id:String in originals:
		if tested>=2:break
		var record:Dictionary=originals[id]
		var button:Button=c._window.cards[record.uid].button
		c._window.scroll.ensure_control_visible(button);await drawn(3)
		check(c._window.scroll.get_global_rect().encloses(button.get_global_rect()),"take button entirely within scroll clip "+id)
		await gui_click(button,"take "+id)
		check(w.fire_state.weaponId==id and w.inventory.get_item_uid(id)==record.uid,"actual click transfers exact UID "+id)
		check(w.fire_state.magazine==record.magazine and w.fire_state.reserveAmmo==record.reserve,"actual click preserves ammo "+id)
		var owned:Dictionary=w.inventory.snapshot();check(not c.window_take(record.uid).get("ok",false) and w.inventory.snapshot()==owned,"stale UID cannot duplicate "+id)
		await gui_click(c._window.store_button,"store "+id)
		check(not w.inventory.get_owned_ids().has(id) and c.cargo.snapshot(c.generation).used_units==100,"store click returns exact contents "+id)
		tested+=1
	await resize(Vector2i(800,600));c._window.scroll.scroll_vertical=0;await drawn(3)
	await image_save("02_trunk_14_800x600",Vector2i(800,600))
	var last_uid:String=originals[originals.keys()[-1]].uid
	var last_button:Button=c._window.cards[last_uid].button
	c._window.scroll.ensure_control_visible(last_button);await drawn(3)
	check(c._window.scroll.get_global_rect().encloses(last_button.get_global_rect()),"last item reachable by real scroll at800")
	await image_save("03_trunk_last_row_800x600",Vector2i(800,600))
	await gui_click(last_button,"take last card at800")
	check(w.inventory.get_item_uid(originals.keys()[-1])==last_uid,"800 actual last-card click takes UID")
	await gui_click(c._window.store_button,"store at800")
	var close_button:Button
	for node:Node in c._window.panel.find_children("*","Button",true,false):
		if node.text=="Закрыть  ×":close_button=node;break
	check(close_button!=null,"visible close button exists")
	if close_button!=null:await gui_click(close_button,"close at800",true)
	check(not c.window_open and not w.menu_open,"close button dismisses only cargo")
	key(KEY_Q);await drawn(3);check(w.menu_open and not c.window_open,"native Q arsenal never overlaps trunk")
	await image_save("04_arsenal_800x600",Vector2i(800,600))
	p._free_mouse_look=false;w.set_menu(false);p._free_mouse_look=true
	key(KEY_E);await drawn(2);check(c.window_open,"reopen by native E")
	p._free_mouse_look=false;key(KEY_Q);p._free_mouse_look=true;await drawn(2)
	check(not c.window_open and not w.menu_open,"Q closes trunk without opening second menu")
	key(KEY_E);await drawn(2)
	var final_before:Dictionary=c.cargo.snapshot(c.generation)
	t.compartments.set_open("trunk",false)
	check(not c.window_take(last_uid).get("ok",false),"same-frame closed-lid stale take rejected")
	await step(12)
	check(not c.window_open and c.cargo.snapshot(c.generation).items==final_before.items,"closed lid closes window and preserves all contents")
	check(c.cargo.snapshot(c.generation).used_units==100 and c.cargo.snapshot(c.generation).items.size()==14,"all 14 roundtrip items retained")
	report.final_contents=c.cargo.snapshot(c.generation);report.final_fixture=fixture()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"no OS mouse capture at completion")
	finish()
