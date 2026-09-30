extends SceneTree
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var checks:=0
var errors:Array[String]=[]
var findings:Array=[]
var compiled_candidate:=false
var gpu:=false
var out:=""
var expected_sha:=""
var pack_path:=""
var captures:Array=[]
var content_checks:Array=[]
var started_us:=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:errors.append(label);print("FAIL ",label)
func key(code:int,down:bool=true,echo:bool=false)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.echo=echo
	Input.parse_input_event(event);Input.flush_buffered_events()
func step(count:int=1)->void:
	for i in count:await physics_frame;await process_frame
func move_mouse(at:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;Input.parse_input_event(event);Input.flush_buffered_events()
func motion_sample()->Dictionary:
	return {"serial":p._ground_move_serial,"physics_frame":Engine.get_physics_frames(),"delta":p.get_physics_process_delta_time(),"velocity":[p.velocity.x,p.velocity.z],"position":[p.global_position.x,p.global_position.z],"axes":str(Input.get_vector(p.ACTION_LEFT,p.ACTION_RIGHT,p.ACTION_FORWARD,p.ACTION_BACK)),"forward":Input.is_action_pressed(p.ACTION_FORWARD),"free":p._free_mouse_look,"blocked":w.controls_blocked()}
func verify_released_motion(label:String)->void:
	# A render-frame wait can include multiple physics ticks on GPU. Use the
	# player's completed move serial and its actual pre-release velocity, not
	# a presumed three acceleration ticks, to derive the source stopping bound.
	var start:int=p._ground_move_serial
	var initial:=Vector2(p.velocity.x,p.velocity.z)
	var dt:float=p.get_physics_process_delta_time()
	var deceleration:float=p.acceleration*dt
	check(dt>0.0 and deceleration>0.0,label+" actual positive physics deceleration")
	if dt<=0.0 or deceleration<=0.0:return
	var ticks:int=maxi(1,ceili(maxf(absf(initial.x),absf(initial.y))/deceleration))
	var trace:Dictionary={"case":label,"initial":motion_sample(),"source_acceleration":p.acceleration,"required_completed_ticks":ticks,"samples":[]}
	var last_max:float=maxf(absf(initial.x),absf(initial.y))
	for attempt:int in ticks+12:
		if p._ground_move_serial-start>=ticks:break
		await step()
		var elapsed_ticks:int=p._ground_move_serial-start
		var expected:=Vector2(move_toward(initial.x,0.0,deceleration*elapsed_ticks),move_toward(initial.y,0.0,deceleration*elapsed_ticks))
		var actual:=Vector2(p.velocity.x,p.velocity.z)
		var current_max:float=maxf(absf(actual.x),absf(actual.y))
		trace.samples.append(motion_sample())
		check(not Input.is_action_pressed(p.ACTION_LEFT) and not Input.is_action_pressed(p.ACTION_RIGHT) and not Input.is_action_pressed(p.ACTION_FORWARD) and not Input.is_action_pressed(p.ACTION_BACK),label+" all movement actions remain released at serial "+str(p._ground_move_serial))
		check(current_max<=last_max+.001,label+" velocity never grows after release at serial "+str(p._ground_move_serial))
		check(absf(actual.x)<=absf(expected.x)+.001 and absf(actual.y)<=absf(expected.y)+.001,label+" velocity obeys source deceleration bound at serial "+str(p._ground_move_serial))
		last_max=current_max
	check(p._ground_move_serial-start>=ticks,label+" required completed physics ticks observed")
	check(Vector2(p.velocity.x,p.velocity.z).length()<.001,label+" physical movement stops within source-derived tick budget")
	var stationary:Vector3=p.global_position
	var stationary_serial:int=p._ground_move_serial
	for attempt:int in 15:
		if p._ground_move_serial-stationary_serial>=3:break
		await step()
		trace.samples.append(motion_sample())
		check(not Input.is_action_pressed(p.ACTION_FORWARD) and Vector2(p.velocity.x,p.velocity.z).length()<.001,label+" remains released and stopped at serial "+str(p._ground_move_serial))
	check(p._ground_move_serial-stationary_serial>=3,label+" three completed stationary ticks observed")
	check(Vector2(p.global_position.x-stationary.x,p.global_position.z-stationary.z).length()<.001,label+" no horizontal drift during following three completed ticks")
	trace.actual_completed_ticks=p._ground_move_serial-start;trace.final=motion_sample();findings.append(trace)
func census(label:String)->void:
	var value:Dictionary={"label":label,"npc_hit_owners":scene.preview_population.hit_owners.size(),"buildings":scene._block.counts.buildings,"colliders":scene.find_children("*","CollisionObject3D",true,false).size(),"shapes":scene.find_children("*","CollisionShape3D",true,false).size(),"population":scene.population_status}
	content_checks.append(value)
	check(value.npc_hit_owners==3 and value.buildings==8 and value.colliders==377 and value.shapes==377 and value.population=="ready",label+" intact original3NPC/8buildings/377colliders/377shapes")
func notes_ok(label:String)->Dictionary:
	var panel:Node=scene.find_child("PreviewUpdates",true,false)
	if not is_instance_valid(panel):check(false,label+" notes panel exists");return {}
	var status:Dictionary=panel.get_status()
	check(not status.get("restart_required",true) and status.get("notes",{}).get("items",[]).size()==5,label+" five matching notes without restart banner")
	return status
func capture(label:String)->void:
	if not gpu:return
	await RenderingServer.frame_post_draw
	var notes:Dictionary=notes_ok(label)
	var path:String=out.path_join(label+".png")
	var result:int=root.get_texture().get_image().save_png(path)
	check(result==OK,label+" PNG from actual viewport")
	captures.append({"label":label,"path":path,"notes":notes,"focus":root.has_focus(),"mouse_mode":Input.mouse_mode,"free_mouse_look":p._free_mouse_look,"blocked":w.controls_blocked(),"weapon":w.fire_state.weaponId,"camera_top_level":p.get_preview_camera().top_level})
func finish()->void:
	var result:Dictionary={"checks":checks,"errors":errors,"valid":errors.is_empty(),"findings":findings,"compiled_candidate":compiled_candidate,"gpu":gpu,"pack_sha256":expected_sha,"harness_sha256":FileAccess.get_sha256(get_script().resource_path),"content":content_checks,"captures":captures,"elapsed_seconds":(Time.get_ticks_usec()-started_us)/1000000.0,"scope":"exact compiled20 pack only; real Godot input dispatch with injected key/mouse events; original3NPC/8buildings/377collision content retained; direct-E camera fixture uses top_level triangle targeting; no whole-city FPS or manual OS-input proof"}
	if not out.is_empty():
		var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file=null
	print("CARGO_INPUT_RESULT ",JSON.stringify(result))
	if is_instance_valid(scene):scene.queue_free()
	quit(0 if errors.is_empty() else 1)
func aim(camera:Camera3D,uid:String)->bool:
	var row:Dictionary=c.renderer._trunks[c.vehicle_id].items[uid]
	var access:Dictionary=t.compartments.access_profile("trunk")
	camera.global_position=t.body.to_global(access.position_local_m+access.outward_local*1.5)+Vector3.UP*.7
	for part:Dictionary in row.parts:
		if not part.visible:continue
		var faces:PackedVector3Array=part.mesh.get_faces()
		for face:int in range(0,faces.size(),3):
			var point:Vector3=row.visual.global_transform*part.transform*((faces[face]+faces[face+1]+faces[face+2])/3.0)
			camera.look_at(point,Vector3.UP)
			if c.aim_context().item_uid==uid:return true
	return false
func run()->void:
	started_us=Time.get_ticks_usec()
	for arg:String in OS.get_cmdline_user_args():
		if arg=="--compiled-candidate":compiled_candidate=true
		elif arg=="--gpu":gpu=true
		elif arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		elif arg.begins_with("--expected-sha="):expected_sha=arg.trim_prefix("--expected-sha=")
		elif arg.begins_with("--exact-pack="):pack_path=arg.trim_prefix("--exact-pack=")
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	check(compiled_candidate,"compiled-candidate mode required")
	check(not pack_path.is_empty() and expected_sha.length()==64 and FileAccess.get_sha256(pack_path)==expected_sha,"exact loaded PCK bytes match runner pinned receipt")
	if not errors.is_empty():finish();return
	for path:String in ["res://scripts/main.gd","res://scripts/preview_player.gd","res://scripts/weapons/preview_weapons.gd","res://scripts/weapons/preview_weapon_cargo.gd"]:
		var script:Script=load(path)
		check(script!=null and not script.has_source_code(),"compiled script has no source text: "+path)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	if gpu:
		check(DisplayServer.get_name()!="headless" and not root.unfocusable,"GPU normal focusable window")
		root.grab_focus()
		for i in 120:
			await process_frame
			if root.has_focus():break
		check(root.has_focus(),"actual window focus before fixture setup")
		if not root.has_focus():finish();return
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"compiled20 actual scene ready")
	if not scene.preview_ready:finish();return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p.set_mouse_captured(true);await step(60)
	check(scene.PREVIEW_RUNTIME_REVISION=="s01-20260930-quality24a","runtime revision is delivered24a")
	census("startup");notes_ok("startup")
	if gpu:check(root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"actual focused capture before interaction")
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	await step(5)
	var camera:Camera3D=p.get_preview_camera();camera.top_level=true;camera.global_position=p.global_position+Vector3.UP*2
	t.compartments.set_open("trunk",true);await step(100)
	check(w.equip("tt_pistol").get("ok",false),"TT equipment available")
	var uid:String=w.inventory.get_item_uid("tt_pistol")
	var mag:int=w.fire_state.magazine;var reserve:int=w.fire_state.reserveAmmo
	check(c.open_window(),"real trunk access opens modal")
	check(c.window_store().get("ok",false),"store exact TT through paired owners")
	c.close_window();await step(2)
	# Direct E transfer while W is physically down. No programmatic action_press.
	check(aim(camera,uid),"direct E aims exact stored UID")
	key(KEY_W)
	check(Input.is_physical_key_pressed(KEY_W) and Input.is_action_pressed(p.ACTION_FORWARD),"actual W reaches physical and action state")
	key(KEY_E)
	check(w.fire_state.weaponId=="tt_pistol" and w.inventory.get_item_uid("tt_pistol")==uid,"direct E exact UID taken")
	check(p._free_mouse_look and not w.controls_blocked(),"direct E immediately retains logical controls")
	check(Input.is_action_pressed(p.ACTION_FORWARD),"direct E retains already-held W action")
	var before:Vector3=p.global_position;await step(3)
	check(p.global_position.distance_to(before)>.005,"direct E held movement actually continues without click")
	key(KEY_W,false);key(KEY_E,false);p.global_position=before;await step(2)
	check(w.fire_state.magazine==mag and w.fire_state.reserveAmmo==reserve and w.shots_count==0,"direct E exact ammo no activation shot")
	check(c.open_window() and c.window_store().get("ok",false),"TT stored back for modal test")
	var button:Button=c._window.cards[uid].button;c._window.scroll.ensure_control_visible(button);await step(3)
	move_mouse(button.get_global_rect().get_center());await step(2)
	await capture("01_modal_before_E")
	key(KEY_W)
	check(Input.is_physical_key_pressed(KEY_W),"modal retains physical W state")
	check(not Input.is_action_pressed(p.ACTION_FORWARD),"modal deliberately blocks movement")
	key(KEY_E)
	check(w.fire_state.weaponId=="tt_pistol" and w.inventory.get_item_uid("tt_pistol")==uid and not c.window_open,"modal E exact UID taken")
	check(p._free_mouse_look and not w.controls_blocked(),"modal E logical controls restored")
	if gpu:check(root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"actual focused OS mouse capture restored after modal E without click")
	findings.append({"case":"modal_E_while_W_held","physical_w":Input.is_physical_key_pressed(KEY_W),"action_forward":Input.is_action_pressed(p.ACTION_FORWARD),"free_mouse_look":p._free_mouse_look,"controls_blocked":w.controls_blocked()})
	before=p.global_position;await step(3)
	findings[-1].movement_distance=p.global_position.distance_to(before)
	if compiled_candidate:
		check(Input.is_action_pressed(p.ACTION_FORWARD),"patched modal restores physically held W action")
		check(p.global_position.distance_to(before)>.005,"patched modal physically held W moves without another click or keypress")
	key(KEY_E,false)
	check(c._take_key_releases.is_empty() and not t._e_down,"modal E release quarantined without seat or lid")
	key(KEY_W,false)
	check(not Input.is_physical_key_pressed(KEY_W) and not Input.is_action_pressed(p.ACTION_FORWARD),"resumed W releases immediately on physical key-up")
	await verify_released_motion("modal_resumed_W_release")
	await capture("02_after_E_and_keyup")
	key(KEY_W,false);key(KEY_W);before=p.global_position;await step(3);key(KEY_W,false)
	check(p.global_position.distance_to(before)>.005,"fresh movement works without extra click")
	await verify_released_motion("ordinary_W_release_without_modal")
	check(w.fire_state.magazine==mag and w.fire_state.reserveAmmo==reserve and w.shots_count==0,"modal E exact ammo no activation shot")
	# A key released while the modal is open must never be replayed by resume.
	p.global_position=before;await step(4)
	check(c.open_window() and c.window_store().get("ok",false),"store exact TT for released-key negative")
	button=c._window.cards[uid].button;c._window.scroll.ensure_control_visible(button);await step(3)
	move_mouse(button.get_global_rect().get_center());key(KEY_W);key(KEY_W,false);key(KEY_E)
	check(not Input.is_physical_key_pressed(KEY_W) and not Input.is_action_pressed(p.ACTION_FORWARD),"released W remains released after successful E take")
	check(p._free_mouse_look and not w.controls_blocked() and w.inventory.get_item_uid("tt_pistol")==uid,"released W negative still completes exact take")
	key(KEY_E,false);await step(3)
	# All configured locomotion keys, including arrows and run, resume as held.
	if compiled_candidate:
		for pair:Array in [[KEY_A,p.ACTION_LEFT],[KEY_LEFT,p.ACTION_LEFT],[KEY_D,p.ACTION_RIGHT],[KEY_RIGHT,p.ACTION_RIGHT],[KEY_W,p.ACTION_FORWARD],[KEY_UP,p.ACTION_FORWARD],[KEY_S,p.ACTION_BACK],[KEY_DOWN,p.ACTION_BACK],[KEY_SHIFT,p.ACTION_RUN]]:
			check(c.open_window(),"open for held mapping "+str(pair[0]));key(pair[0]);key(KEY_Q)
			check(Input.is_action_pressed(pair[1]),"resume configured physical mapping "+str(pair[0]));key(pair[0],false);key(KEY_Q,false)
			check(not Input.is_physical_key_pressed(pair[0]) and not Input.is_action_pressed(pair[1]),"resumed mapping immediately releases on physical key-up "+str(pair[0]))
		check(c.open_window(),"open for excluded jump negative");key(KEY_SPACE);key(KEY_Q)
		check(not Input.is_action_pressed(p.ACTION_JUMP) and p._jump.is_empty(),"closing modal never replays held SPACE as jump");key(KEY_SPACE,false);key(KEY_Q,false)
	# Esc and true focus loss suspend even when W is physically still down.
	check(c.open_window(),"open for Esc negative");key(KEY_W);key(KEY_ESCAPE)
	check(not p._free_mouse_look and not c.window_open and not Input.is_action_pressed(p.ACTION_FORWARD),"Esc keeps held W suspended and releases cursor")
	key(KEY_W,false);key(KEY_ESCAPE,false);p.set_mouse_captured(true)
	check(c.open_window(),"open for blur negative");key(KEY_W);p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not c.window_open and not p._free_mouse_look and not Input.is_action_pressed(p.ACTION_FORWARD),"actual focus-out path never restores held movement")
	key(KEY_W,false);p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);p.set_mouse_captured(true)
	check(c.open_window(),"open for authority negative");key(KEY_W);p.set_preview_pose_authority(&"vehicle");c.close_window()
	check(not Input.is_action_pressed(p.ACTION_FORWARD) and not c.window_open,"authority loss prevents movement restoration")
	key(KEY_W,false);p.set_preview_pose_authority(&"on_foot");await step(2)
	check(w.inventory.get_item_uid("tt_pistol")==uid and w.fire_state.magazine==mag and w.fire_state.reserveAmmo==reserve and w.shots_count==0,"all close/cancel paths preserve item and ammo")
	# A real focus notification is the shared path that suspends both routes.
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not p._free_mouse_look,"focus-out suspends logical controls")
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not p._free_mouse_look,"focus-in alone does not resume; current policy requires click")
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(600,400);click.global_position=click.position;Input.parse_input_event(click);Input.flush_buffered_events()
	check(p._free_mouse_look,"first click after focus reacquires controls")
	check(not w._held and not w._pressed and w.shots_count==0,"reacquire click never shoots")
	census("complete");notes_ok("complete")
	finish()
