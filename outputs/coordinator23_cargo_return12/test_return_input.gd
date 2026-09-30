extends SceneTree
## Actual main and scheduled player physics. No synthetic pressed-signal emission,
## no direct player/weapon input handlers, no manual fire advance or ammo changes.
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var checks:Array[Dictionary]=[]
var errors:Array[String]=[]
var out:=""
var started:=0
var done:=false
var capture_probe:Dictionary={}
var capture_samples:Array[Dictionary]=[]
func _initialize()->void:
	started=Time.get_ticks_msec();root.size=Vector2i(1280,720);root.unfocusable=true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	# Rendered capture belongs to a separate root-controlled observer: this native
	# regression may keep capture across scheduled frames and is headless-only.
	if out.is_empty() or DisplayServer.get_name()!="headless":quit(2);return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	capture_probe={"requested":Input.MOUSE_MODE_CAPTURED,"read_back":Input.mouse_mode,"supported":Input.mouse_mode==Input.MOUSE_MODE_CAPTURED}
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(out);run.call_deferred()
func _process(_dt:float)->bool:
	if not done and Time.get_ticks_msec()-started>24000:
		check(false,"bounded_24_second_timeout");finish()
	return false
func check(ok:bool,label:String)->void:
	checks.append({"ok":ok,"label":label})
	if not ok:errors.append(label);print("FAIL ",label)
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func send_key(code:int,pressed:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events()
func mouse_at(point:Vector2)->void:
	var e:=InputEventMouseMotion.new();e.position=point;e.global_position=point
	Input.parse_input_event(e);Input.flush_buffered_events()
func mouse_button(point:Vector2,pressed:bool)->void:
	var e:=InputEventMouseButton.new();e.position=point;e.global_position=point
	e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e);Input.flush_buffered_events()
func prepare_item()->Dictionary:
	c.close_window();p.set_mouse_captured(true)
	check(w.equip("tt_pistol").get("ok",false),"real_TT_equip")
	# Each scenario starts ready to shoot. Wait natural fire cooldown from the
	# previous deliberate shot BEFORE storing, never after Take to mask a guard.
	await step(40)
	check(float(w.fire_state.cooldown)<=0.0,"source_fire_cooldown_settled_before_store")
	var record:Dictionary={"uid":w.inventory.get_item_uid("tt_pistol"),"magazine":int(w.fire_state.magazine),"reserve":int(w.fire_state.reserveAmmo)}
	check(c.store_held().get("ok",false),"real_store_exact_TT")
	# F itself is routed through viewport and normal _input, not called directly.
	send_key(KEY_F,true);await step();send_key(KEY_F,false);await step(5)
	check(c.window_open and c._window.visible,"F_opens_modal_through_input")
	if not c.window_open or not c._window.cards.has(record.uid):return {}
	var button:Button=c._window.cards[record.uid].button
	c._window.scroll.ensure_control_visible(button);await step(3)
	record.point=button.get_global_rect().get_center()
	check(button.is_visible_in_tree() and not button.disabled and button.get_global_rect().size.y>=40,"real_visible_take_button")
	mouse_at(record.point);await step(2)
	print("TAKE_GEOMETRY ",JSON.stringify({"point":record.point,"rect":button.get_global_rect(),"viewport":root.get_visible_rect(),"mouse":c._window.get_global_mouse_position(),"hover":c._window.hovered_item_uid(),"uid":record.uid}))
	return record
func check_return(record:Dictionary,label:String,shots:int)->void:
	check(not c.window_open and not c._window.visible and not w.controls_blocked(),label+"_closed_modal")
	check(p._free_mouse_look,label+"_logical_capture")
	capture_samples.append({"label":label,"free":p._free_mouse_look,"mode":Input.mouse_mode})
	if capture_probe.supported:check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,label+"_native_pointer_capture")
	check(w.inventory.get_item_uid("tt_pistol")==record.uid and w.fire_state.weaponId=="tt_pistol",label+"_same_UID_equipped")
	check(int(w.fire_state.magazine)==record.magazine and int(w.fire_state.reserveAmmo)==record.reserve,label+"_ammo_unchanged")
	check(w.shots_count==shots and not w._held and not w._pressed,label+"_no_spurious_shot_or_latch")
func deliberate_shot(label:String)->void:
	var shots:int=w.shots_count;var ammo:int=w.fire_state.magazine
	# Mouse motion has zero relative delta: do not alter ordinary spring-arm camera.
	var point:=Vector2(640,360);mouse_at(point);mouse_button(point,true);await step(3)
	mouse_button(point,false);await step(8)
	check(w.shots_count==shots+1 and int(w.fire_state.magazine)==ammo-1,label+"_next_deliberate_click_fires_exactly_once")
func run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"actual_main_ready")
	if not scene.preview_ready:finish();return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p.set_mouse_captured(true);await step(60)
	var access:Dictionary=t.compartments.access_profile("trunk")
	# Declared QA fixture: only player position, supported stock rear access;
	# original NPCs, vehicle, camera parent, spring arm and physics remain enabled.
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	await step(5);t.compartments.set_open("trunk",true);await step(100)
	check(c._window_access(),"real_open_trunk_rear_access")
	if not c._window_access():finish();return
	var record:Dictionary=await prepare_item()
	if record.is_empty():finish();return
	var shots:int=w.shots_count
	mouse_button(record.point,true);await step(2)
	check(c.window_open and w.shots_count==shots,"release_mode_take_press_does_not_fire_or_take")
	mouse_button(record.point,false);await step(8)
	check_return(record,"GUI_LMB_release_take",shots)
	await deliberate_shot("GUI_LMB_take")
	record=await prepare_item()
	if record.is_empty():finish();return
	shots=w.shots_count
	check(c._window.hovered_item_uid()==record.uid,"native_mouse_hover_exact_UID")
	send_key(KEY_E,true);await step(3);send_key(KEY_E,false);await step(5)
	check_return(record,"hover_E_take",shots)
	await deliberate_shot("hover_E_take")
	record=await prepare_item()
	if record.is_empty():finish();return
	shots=w.shots_count
	# Press GUI Take, activate hover E before releasing LMB. The modal must not
	# transfer this held activation to the newly equipped firearm.
	mouse_button(record.point,true);await step();send_key(KEY_E,true);await step(5)
	check(w.shots_count==shots,"E_take_while_LMB_held_no_shot")
	mouse_button(record.point,false);send_key(KEY_E,false);await step(5)
	check_return(record,"held_LMB_E_take",shots)
	await deliberate_shot("held_LMB_E_take")
	# Explicit ordinary free-mouse reacquisition: first click is capture only.
	await step(40)
	p.set_mouse_captured(false);shots=w.shots_count
	mouse_at(Vector2(640,360));mouse_button(Vector2(640,360),true);await step(2)
	mouse_button(Vector2(640,360),false);await step(3)
	check(p._free_mouse_look and w.shots_count==shots,"ordinary_free_cursor_first_click_captures_without_shot")
	await deliberate_shot("ordinary_capture")
	record=await prepare_item()
	if record.is_empty():finish();return
	shots=w.shots_count
	var owned:Dictionary=w.inventory.snapshot()
	check(not c.window_take("nonexistent-stale-UID").get("ok",false),"stale_take_rejected")
	check(c.window_open and w.inventory.snapshot()==owned and w.shots_count==shots,"failed_take_remains_modal_no_round_spent")
	# Natural scheduled invalidation by leaving rear range, no _process call.
	p.global_position+=Vector3(10,0,0);await step(20)
	check(not c.window_open and not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"range_invalidation_releases_both_capture_owners")
	check(w.shots_count==shots and not w._held and not w._pressed,"invalidation_no_latched_trigger")
	finish()
func finish()->void:
	if done:return
	done=true
	var receipt:Dictionary={"checks":checks,"count":checks.size(),"errors":errors,"display_server":DisplayServer.get_name(),"capture_capability_probe":capture_probe,"capture_samples":capture_samples,"native_pointer_mode_status":"PASS" if capture_probe.get("supported",false) else "SKIP: direct headless setter is a no-op; root rendered acceptance required","elapsed_ms":Time.get_ticks_msec()-started,"scope":"Actual main + scheduled physics + Input.parse_input_event GUI Take LMB/E. Logical capture and immediate shooting behavior asserted. Native pointer mode only checked if direct mode setter works. No GPU or visual/performance claim."}
	var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(receipt,"\t"));file.close()
	print("CARGO_RETURN_RESULT ",JSON.stringify(receipt))
	quit(0 if errors.is_empty() else 1)
