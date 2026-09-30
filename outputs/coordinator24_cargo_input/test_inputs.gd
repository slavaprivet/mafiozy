extends SceneTree
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var checks:=0
var errors:Array[String]=[]
var findings:Array=[]
var patched:=false
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
	for arg:String in OS.get_cmdline_user_args():
		if arg=="--patch":
			var candidate:Script=load(get_script().resource_path.get_base_dir().path_join("files/scripts/weapons/preview_weapon_cargo.gd"))
			candidate.take_over_path("res://scripts/weapons/preview_weapon_cargo.gd");patched=true
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_residents_enabled=false;root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"accepted23h actual scene ready")
	if not scene.preview_ready:quit(1);return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p.set_mouse_captured(true);await step(60)
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
	key(KEY_W)
	check(Input.is_physical_key_pressed(KEY_W),"modal retains physical W state")
	check(not Input.is_action_pressed(p.ACTION_FORWARD),"modal deliberately blocks movement")
	key(KEY_E)
	check(w.fire_state.weaponId=="tt_pistol" and w.inventory.get_item_uid("tt_pistol")==uid and not c.window_open,"modal E exact UID taken")
	check(p._free_mouse_look and not w.controls_blocked(),"modal E logical controls restored")
	findings.append({"case":"modal_E_while_W_held","physical_w":Input.is_physical_key_pressed(KEY_W),"action_forward":Input.is_action_pressed(p.ACTION_FORWARD),"free_mouse_look":p._free_mouse_look,"controls_blocked":w.controls_blocked()})
	before=p.global_position;await step(3)
	findings[-1].movement_distance=p.global_position.distance_to(before)
	if patched or OS.get_cmdline_user_args().has("--expect-restored"):
		check(Input.is_action_pressed(p.ACTION_FORWARD),"patched modal restores physically held W action")
		check(p.global_position.distance_to(before)>.005,"patched modal physically held W moves without another click or keypress")
	key(KEY_E,false)
	check(c._take_key_releases.is_empty() and not t._e_down,"modal E release quarantined without seat or lid")
	key(KEY_W,false);key(KEY_W);before=p.global_position;await step(3);key(KEY_W,false)
	check(p.global_position.distance_to(before)>.005,"fresh movement works without extra click")
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
	if patched:
		for pair:Array in [[KEY_A,p.ACTION_LEFT],[KEY_LEFT,p.ACTION_LEFT],[KEY_D,p.ACTION_RIGHT],[KEY_RIGHT,p.ACTION_RIGHT],[KEY_W,p.ACTION_FORWARD],[KEY_UP,p.ACTION_FORWARD],[KEY_S,p.ACTION_BACK],[KEY_DOWN,p.ACTION_BACK],[KEY_SHIFT,p.ACTION_RUN]]:
			check(c.open_window(),"open for held mapping "+str(pair[0]));key(pair[0]);key(KEY_Q)
			check(Input.is_action_pressed(pair[1]),"resume configured physical mapping "+str(pair[0]));key(pair[0],false);key(KEY_Q,false)
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
	print("CARGO_INPUT_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"findings":findings,"patched":patched,"scope":"exact23h compiled pack with optional one-file cargo override; headless real Godot input dispatch; OS focus/capture not reproduced; NPC disabled component fixture"}))
	scene.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
