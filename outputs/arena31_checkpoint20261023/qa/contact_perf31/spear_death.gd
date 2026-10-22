extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
var hold_ticks:int=120
var draw_intervals_usec:Array=[]
var draw_rows:Array=[]
var draw_phase:String="startup"
var last_draw_usec:int=0
func draw_sample():
	var now:=Time.get_ticks_usec()
	if last_draw_usec>0:
		draw_intervals_usec.append(now-last_draw_usec)
		draw_rows.append({"phase":draw_phase,"usec":now-last_draw_usec})
	last_draw_usec=now
const P=preload("res://scripts/combat/puncture29.gd")
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
		if a.begins_with("--hold="):hold_ticks=int(a.trim_prefix("--hold="))
	run.call_deferred()
func move(action:StringName,value:float):
	var e:=InputEventAction.new();e.action=action;e.pressed=value>0;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
func button(value:bool):
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
	var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func frames(n:int):
	for i in n:await process_frame
func sample(host:Node,label:String,phase:String,tick:int):
	draw_phase=phase
	var channel:Dictionary=host.get_meta("puncture29_channel",{})
	rows.append({"weapon":label,"phase":phase,"tick":tick,"dead":host._npc_dead,"depth":channel.get("current_depth",0),"cut_depth":channel.get("cut_depth",0),"valid":channel.get("valid",false),"withdrawn":channel.get("withdrawn",false),"release":channel.get("release_reason",""),"tip":P.tip_world(host),"node":channel.node_ref.get_ref().get_instance_id() if channel.get("node_ref")!=null and is_instance_valid(channel.node_ref.get_ref()) else -1,"embedded":host._embedded29.status(),"solid_safe":host._solid_weapon29._publish_safe})
	if phase!="approach":
		rows[-1].player=host._player.global_position;rows[-1].origin=host._sword.global_position;rows[-1].axis=host._dir
		rows[-1].entry=channel.get("entry_world");rows[-1].bore_axis=channel.get("axis_world")
		rows[-1].contact=host._solid_weapon29.last_contact.duplicate()
		rows[-1].obstruction=host._solid_weapon29._world_obstruction.duplicate()
		rows[-1].solver_usec=host._solid_weapon29.last_solver_usec
		rows[-1].bore_reject=host._solid_weapon29.bore_reject31.duplicate(true)
		rows[-1].ragdoll=host._deep_collapse29.ragdoll.status.duplicate(true)
func scenario(label:String,weapon:int):
	var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
	while not scene.lab_ready:await physics_frame
	var host:Node=scene.lab;host.lab_regrow=false;scene._lab_equip(weapon)
	host.set_meta("debug_bore31",true)
	var player:Node=scene._player
	player.global_position=Vector3(.2 if weapon==0 else 0.,.05,1.3);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.00814;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(30);button(true);motion(Vector2(0,100))
	for i in 60:await physics_frame
	var rig:Skeleton3D=host._npc_rig;var rig_id:=rig.get_instance_id()
	move("preview_move_forward",.6)
	var died:=false;var entry_seen:=false;var death_depth:=0.;var max_after:=0.;var wound_id:=-1
	for i in 450:
		await physics_frame;await create_timer(0).timeout
		var channel:Dictionary=host.get_meta("puncture29_channel",{})
		entry_seen=entry_seen or float(channel.get("cut_depth",0))>.001
		if i%15==0:sample(host,label,"approach",i)
		if host._npc_dead:
			died=true;death_depth=float(channel.get("cut_depth",0));wound_id=channel.node_ref.get_ref().get_instance_id();sample(host,label,"death",i);break
	checks[label+"_actual_entry"]=entry_seen
	checks[label+"_actual_death90"]=died and float(host._deep_collapse29.last.get("ratio",0))>=.90
	if died:
		var last:Dictionary=host.get_meta("puncture29_channel",{})
		var same:=true
		move("preview_move_forward",0.)
		var retained:=true
		for i in hold_ticks:
			await physics_frame;await create_timer(0).timeout
			last=host.get_meta("puncture29_channel",{})
			max_after=maxf(max_after,float(last.get("cut_depth",0)))
			retained=retained and host._embedded29.active(host) and not last.get("withdrawn",false)
			same=same and rig.get_instance_id()==rig_id and last.node_ref.get_ref().get_instance_id()==wound_id
			sample(host,label,"continue",i)
		checks[label+"_same_anchor"]=same
		checks[label+"_held120_until_S"]=retained
		checks[label+"_bounded_native_reaction"]=host._embedded29.max_holder_reaction_step_m<=.04001
		checks[label+"_held_self_world_clear"]=host._embedded29.self_clear and host._embedded29.world_clear
		checks[label+"_continued_insertion"]=max_after>death_depth+.0002 or bool(host._deep_collapse29.last.get("ratio",0)>=.999)
		move("preview_move_forward",0.);move("preview_move_back",.6)
		for i in 90:
			await physics_frame;await create_timer(0).timeout
			last=host.get_meta("puncture29_channel",{})
			if i%5==0:sample(host,label,"withdraw",i)
			if last.get("withdrawn",false):break
		checks[label+"_withdraw"]=last.get("withdrawn",false) and str(last.get("release_reason",""))=="withdrawn_backward"
		checks[label+"_ragdoll_active"]=host._deep_collapse29.ragdoll.active
	move("preview_move_forward",0.);move("preview_move_back",0.);button(false)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+label+"_end.png")
	draw_phase="reset"
	var previous_scene:WeakRef=weakref(scene)
	var previous_weapon:WeakRef=weakref(host._sword)
	var reset:=InputEventKey.new();reset.keycode=KEY_F5;reset.physical_keycode=KEY_F5;reset.pressed=true
	Input.parse_input_event(reset);Input.flush_buffered_events()
	reset=InputEventKey.new();reset.keycode=KEY_F5;reset.physical_keycode=KEY_F5;reset.pressed=false
	Input.parse_input_event(reset);Input.flush_buffered_events()
	for i in 600:
		await process_frame
		if not is_instance_valid(previous_scene.get_ref()) and is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	checks[label+"_F5_replaced_scene"]=not is_instance_valid(previous_scene.get_ref()) and is_instance_valid(current_scene)
	checks[label+"_F5_old_weapon_freed"]=not is_instance_valid(previous_weapon.get_ref())
	if is_instance_valid(current_scene):
		scene=current_scene
		checks[label+"_F5_no_embedded_orphan"]=scene.find_children("EmbeddedAttachment31","",true,false).is_empty() and not scene.lab._embedded29.status().active
	current_scene=null;scene.queue_free();await frames(4)
func run():
	root.size=Vector2i(1280,720);root.title="QA31 continued puncture after physical death"
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		RenderingServer.frame_post_draw.connect(draw_sample)
	await scenario("spear",4)
	var passed:=true
	for v:bool in checks.values():passed=passed and v
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"draw_intervals_usec":draw_intervals_usec,"draw_rows":draw_rows},"\t"));quit()
