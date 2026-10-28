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
	root.size=Vector2i(1280,900)
	for part:String in ["forearm_l","forearm_r"]:
		change_scene_to_file("res://scenes/arena27.tscn")
		for i in 600:
			await process_frame
			if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
		scene=current_scene;player=scene._player;host=scene.lab;axes=host._hatchet32
		player.global_position=Vector3(4,.05,3);player.velocity=Vector3.ZERO;player.set_mouse_captured(true)
		await ticks(30)
		var rig:Skeleton3D=host._rig;var bone:=rig.find_bone(part);var child:=rig.find_bone(part.replace("forearm","hand"))
		var a:Vector3=rig.global_transform*rig.get_bone_global_pose(bone).origin;var b:Vector3=rig.global_transform*rig.get_bone_global_pose(child).origin
		host._player_take_blade(120.,a.lerp(b,.28),(b-a).normalized(),true,part,8.)
		await ticks(10)
		checks[part+"_actual_mesh_sever"]=host._player_severed.has(part) and host._player_mesh_cut_parts50.has(part)
		checks[part+"_survives"]=not bool(scene.preview_dead)
		await choose("hatchet")
		mouse(MOUSE_BUTTON_RIGHT,true);await ticks(35);mouse(MOUSE_BUTTON_LEFT,true);await ticks(35);mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
		checks[part+"_throw_hand_rule"]=axes.launched==0 if part=="forearm_l" else axes.launched==1
		checks[part+"_charge_rule"]=axes.count()==3 if part=="forearm_l" else axes.count()==2
		rows.append({"part":part,"axes":axes.snapshot(),"lost_right":host._hand_lost31(&"right"),"lost_left":host._hand_lost31(&"left")})
		var old:Node=current_scene;current_scene=null;old.queue_free();await ticks(5)
	finish()
func finish():
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows},"  "))
	quit(0 if not checks.values().has(false) else 1)
