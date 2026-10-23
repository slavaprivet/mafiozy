extends SceneTree
var out:String
var tier:="none"
var shot_count:=1
var aim_up:=0.0
var plate_target31:=false
var target_point31:=Vector3.INF
var tissue_impacts31:Array=[]
var rebound_geometry31:Array=[]
var checks:Dictionary={}
var rows:Array=[]
var scene:Node
var player:CharacterBody3D
var host:Node
var axes:Node
func _initialize():
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--tier="):tier=arg.trim_prefix("--tier=")
		if arg.begins_with("--shots="):shot_count=int(arg.trim_prefix("--shots="))
		if arg.begins_with("--aim-up="):aim_up=float(arg.trim_prefix("--aim-up="))
		if arg=="--plate":plate_target31=true
	run.call_deferred()
func ticks(n:int):
	for i in n:await physics_frame;await create_timer(0).timeout
func mouse(button:int,down:bool):
	var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func key(code:int):
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func aim():
	for i in 18:
		var rig:Skeleton3D=host._npc_rig
		var target:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin+Vector3.UP*aim_up
		if target_point31.is_finite():target=target_point31
		var camera:Camera3D=player.get_preview_camera()
		var direction:Vector3=(target-camera.global_position).normalized()
		var yaw:=atan2(-direction.x,-direction.z)
		var pitch:=asin(direction.y)
		var e:=InputEventMouseMotion.new()
		e.relative=Vector2(clampf(wrapf(player._camera_yaw-yaw,-PI,PI)/player.mouse_sensitivity,-25,25),clampf((player._camera_pitch-pitch)/player.mouse_sensitivity,-25,25));e.screen_relative=e.relative
		Input.parse_input_event(e);Input.flush_buffered_events();await ticks(1)
func choose(id:String):
	var arsenal:Node=scene.get("preview_weapons")
	if not arsenal.menu_open:key(KEY_Q)
	await ticks(3)
	var button:Button=arsenal.get("_buttons")[id]
	arsenal.get("_walk_ui").scroll.ensure_control_visible(button);await ticks(2)
	var point:=button.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await ticks(1)
	await ticks(15)
func run():
	root.size=Vector2i(1280,900);change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	scene=current_scene;checks.startup=is_instance_valid(scene) and scene.lab_ready
	if not checks.startup:finish();return
	player=scene._player;host=scene.lab;axes=host._hatchet32
	player.global_position=Vector3(0,.05,2.5);player.velocity=Vector3.ZERO;player.set_mouse_captured(true)
	await ticks(30);await choose("hatchet")
	var ids:Array=[];var ground_ids:Array=[]
	for item:Dictionary in axes.pool:ids.append(item.node.get_instance_id())
	for i in 3:
		var model:Node3D=host._sword;var id:=model.get_instance_id()
		key(KEY_G);await ticks(4)
		checks["g%d_consumes_one"%i]=axes.count()==2-i
		checks["g%d_same_model_ground"%i]=host._ground_swords.has(model) and model.get_parent() is RigidBody3D
		ground_ids.append(id)
		await choose("hatchet")
		checks["q%d_no_remote_recall"%i]=axes.count()==2-i and (host._sword==axes.empty or not ground_ids.has(host._sword.get_instance_id()))
		rows.append({"phase":"gq%d"%i,"state":axes.snapshot()})
	checks["zero_empty_visible_token"]=host._sword==axes.empty and host._sword.find_children("*","MeshInstance3D",true,false).is_empty()
	var ground_count:int=host._ground_swords.size();key(KEY_G);await ticks(2)
	checks.zero_g_no_ghost=host._ground_swords.size()==ground_count
	mouse(MOUSE_BUTTON_RIGHT,true);mouse(MOUSE_BUTTON_LEFT,true);await ticks(20);mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
	checks.zero_no_throw=axes.launched==0
	await choose("sword")
	var sword:Node3D=host._sword
	key(KEY_E);await ticks(4)
	checks.e_with_other_weapon_adds_one=axes.count()==1 and host._weapon_id=="sword" and host._sword==sword
	key(KEY_E);await ticks(3);key(KEY_E);await ticks(3)
	checks.all_three_recovered=axes.count()==3
	var ids_after:Array=[]
	for item:Dictionary in axes.pool:ids_after.append(item.node.get_instance_id())
	checks.same_three_identities=ids_after==ids
	key(KEY_E);await ticks(3);checks.no_duplicate_fourth=axes.count()==3 and axes.pool.size()==3
	await choose("hatchet")
	checks.reselected_held_actual=host._sword!=axes.empty and host._sword.is_visible_in_tree()
	key(KEY_G);await ticks(3);await choose("hatchet")
	var kept:Node3D=host._sword;key(KEY_E);await ticks(4)
	var visible_available:=0
	for item:Dictionary in axes.pool:
		if item.state in ["reserve","held"] and item.node.is_visible_in_tree():visible_available+=1
	checks.e_retains_current_hatchet_and_one_visible=host._sword==kept and visible_available==1 and axes.count()==3
	checks.hud_count_correct="3 / 3" in scene.preview_weapons._walk_ui.ammo.text
	rows.append({"final":axes.snapshot(),"ground_count":host._ground_swords.size(),"hud":scene.preview_weapons._walk_ui.ammo.text})
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/lifecycle.png")
	finish()
func finish():
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows},"  "))
	var old:Node=current_scene;current_scene=null
	if is_instance_valid(old):old.queue_free()
	await ticks(4);quit(0 if not checks.values().has(false) else 1)
