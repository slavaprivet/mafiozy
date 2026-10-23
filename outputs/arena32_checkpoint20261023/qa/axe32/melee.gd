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
func motion(value:Vector2):
	var event:=InputEventMouseMotion.new();event.relative=value;event.screen_relative=value;Input.parse_input_event(event);Input.flush_buffered_events()
func run():
	root.size=Vector2i(1280,900);change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	scene=current_scene;player=scene._player;host=scene.lab;axes=host._hatchet32;host.lab_regrow=false
	player.global_position=Vector3(0,.05,-1.0);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.1;player._update_camera_rotation();player.set_mouse_captured(true)
	await ticks(30);await choose("hatchet");await ticks(25)
	var hp:float=host._npc_hp;var initial_cuts:int=host.clay_cuts;var initial_wounds:int=host.clay_local_wounds28;var initial_unresolved:int=host._solid_weapon29.unresolved
	var peak:=0.;var max_grip:=0.;var self_clear:=true;var contacts:Array=[]
	for pattern:Dictionary in [{"aim":Vector2(-90,35),"flick":Vector2(180,0)},{"aim":Vector2(0,-80),"flick":Vector2(0,180)},{"aim":Vector2(-80,-70),"flick":Vector2(160,150)}]:
		mouse(MOUSE_BUTTON_LEFT,true);motion(pattern.aim);await ticks(45);motion(pattern.flick)
		for tick in 35:
			await ticks(1);peak=maxf(peak,host._omega.length());max_grip=maxf(max_grip,host._solid_weapon29.max_grip_error)
			self_clear=self_clear and host._self_blade_clear_at51(host._dir,host._sword.global_position)
			contacts.append({"contact":host.clay_last_contact28.duplicate(true),"solid":host._solid_weapon29.last_contact.duplicate(true),"hp":host._npc_hp,"omega":host._omega})
		mouse(MOUSE_BUTTON_LEFT,false);await ticks(15)
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/melee%d.png"%rows.size())
		rows.append({"pattern":pattern,"hp":host._npc_hp,"cuts":host.clay_cuts,"wounds":host.clay_local_wounds28})
	checks.real_melee_contact=float(host._npc_hp)<hp or host.clay_cuts>initial_cuts or host.clay_local_wounds28>initial_wounds
	checks.no_throw_from_lmb=axes.launched==0 and axes.count()==3
	checks.actual_free_swing=peak>2.
	checks.grip_attached=max_grip<.005
	checks.self_clear=self_clear
	checks.solid_resolved=host._solid_weapon29.unresolved==initial_unresolved
	rows.append({"peak_omega":peak,"hp_before":hp,"hp_after":host._npc_hp,"max_grip":max_grip,"contacts":contacts,"solid":host._solid_weapon29.status()})
	finish()
func finish():
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows},"  "))
	var old:Node=current_scene;current_scene=null;old.queue_free();await ticks(4)
	quit(0 if not checks.values().has(false) else 1)
