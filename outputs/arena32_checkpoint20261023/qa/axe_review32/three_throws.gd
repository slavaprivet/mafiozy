extends SceneTree
var out:String
var tier:="none"
var charge_ticks:=40
var shot_count:=1
var aim_up:=0.0
var plate_target31:=false
var pickup_after:=false
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
		if arg.begins_with("--charge-ticks="):charge_ticks=int(arg.trim_prefix("--charge-ticks="))
		if arg.begins_with("--tier="):tier=arg.trim_prefix("--tier=")
		if arg.begins_with("--shots="):shot_count=int(arg.trim_prefix("--shots="))
		if arg.begins_with("--aim-up="):aim_up=float(arg.trim_prefix("--aim-up="))
		if arg=="--plate":plate_target31=true
		if arg=="--pickup":pickup_after=true
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
func closeup(at:Vector3,offset:Vector3,path:String):
	if DisplayServer.get_name()=="headless":return
	var camera:=Camera3D.new();scene.add_child(camera);camera.global_position=at+offset;camera.look_at(at);camera.fov=45.;camera.make_current()
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+path+".png")
	player.get_preview_camera().make_current();camera.queue_free()
func action(name:String,value:float):
	var e:=InputEventAction.new();e.action=name;e.pressed=value>.01;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	root.size=Vector2i(1280,900)
	change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	scene=current_scene;checks["startup"]=is_instance_valid(scene) and scene.get("lab_ready")==true
	if not checks.startup:finish();return
	player=scene.get("_player");host=scene.get("lab");axes=host._hatchet32
	host.lab_regrow=false
	var equipment:Dictionary={}
	if tier!="none":
		for slot:String in ["head","torso","hands","legs","feet"]:equipment[slot]=tier+"_"+slot
	host.lab_armored=tier!="none";host.lab_armor_tier30=tier;host.set_npc_armor31(equipment)
	player.global_position=Vector3(0,.05,2.5);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.1;player._update_camera_rotation();player.set_mouse_captured(true)
	await ticks(20)
	if plate_target31:
		var armor=load("res://scripts/combat/armor_damage31.gd")
		var rig:Skeleton3D=host._npc_rig
		var best:=INF
		for xi in range(-3,4):
			for yi in range(8,17):
				var from:=Vector3(float(xi)*.075,float(yi)*.10,-.8)
				var hits:Array[Dictionary]=host._solid_weapon29.skin_hits(host,from,from+Vector3.FORWARD*2.,"")
				if hits.is_empty():continue
				var hit:Dictionary=hits[0];var bone:=int(hit.bone)
				if bone<0:continue
				var part:=str(rig.get_bone_name(bone))
				if part.begins_with("spine"):part="chest"
				if part=="neck":part="head"
				var proxy:CollisionObject3D=null
				var anchor:=rig.get_node_or_null("Hit"+part)
				if anchor!=null:
					for child in anchor.get_children():
						if child is CollisionObject3D:proxy=child;break
				var incoming:=26.*(2. if part=="head" else 1.)
				var coverage:Dictionary=armor.resolve(equipment,part,"stab",incoming,host._armor_point31(rig,part,hit.point,proxy),1.)
				if str(coverage.region)!=("plate" if tier=="heavy" else ("mail" if tier=="medium" else "cloth")):continue
				var score:float=absf(float(xi))*.02+absf(float(yi)*.1-1.25)
				if score<best:best=score;target_point31=hit.point-Vector3.UP*.08;rows.append({"phase":"plate_aim_candidate","point":hit.point,"part":part,"coverage":coverage})
		checks["actual_protected_plate_target"]=target_point31.is_finite()
	var arsenal:Node=scene.get("preview_weapons")
	key(KEY_Q);await ticks(3)
	var button:Button=arsenal.get("_buttons")["hatchet"]
	arsenal.get("_walk_ui").scroll.ensure_control_visible(button);await ticks(2)
	var point:=button.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await ticks(1)
	await ticks(35)
	checks["q_actual_hatchet"]=host._weapon_id=="hatchet" and not host._unarmed and host._sword.is_visible_in_tree()
	checks["three_unique_instances"]=axes.pool.size()==3 and axes.count()==3
	var original_ids:Array=[]
	for item:Dictionary in axes.pool:original_ids.append(item.node.get_instance_id())
	var hp_before:=float(host._npc_hp)
	for shot in shot_count:
		mouse(MOUSE_BUTTON_RIGHT,true)
		await aim();await ticks(charge_ticks)
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/aim_%d.png"%shot)
		rows.append({"phase":"aim","state":axes.snapshot(),"pose":host._sword.global_transform,"camera":player.get_preview_camera().global_transform})
		await closeup(host._sword.global_position+Vector3.UP*.15,Vector3(1.,.2,.5),"aim_side_%d"%shot)
		mouse(MOUSE_BUTTON_LEFT,true);await ticks(8);await closeup(player.global_position+Vector3.UP*1.5,Vector3(1.4,.4,.4),"release_%d"%shot);await ticks(12);mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
		for i in 40:await ticks(1)
		checks["launch_%d"%shot]=axes.launched==shot+1
		rows.append({"phase":"shot","state":axes.snapshot(),"hp":host._npc_hp})
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/impact_%d.png"%shot)
	var launches_before:int=axes.launched
	mouse(MOUSE_BUTTON_RIGHT,true);await ticks(40);mouse(MOUSE_BUTTON_LEFT,true);await ticks(30);mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
	checks.fourth_empty_attempt_no_launch=axes.launched==launches_before and launches_before==3
	checks.no_negative_ammo=axes.count()==0
	checks.three_original_instances=axes.pool.size()==3
	for i in axes.pool.size():checks.three_original_instances=checks.three_original_instances and is_instance_valid(axes.pool[i].node) and axes.pool[i].node.get_instance_id()==original_ids[i]

	var actual:=false;var embedded:=false;var plate:=false
	for event:Dictionary in axes.events:
		actual=actual or event.get("event","")=="embed" or bool(event.get("actual_skin",false))
		embedded=embedded or event.get("event","")=="embed"
		plate=plate or (event.get("event","")=="bounce" and event.get("protection",{}).get("region","")=="plate")
	checks["actual_skin_contact"]=actual
	checks["consumed_charges"]=axes.count()==3-shot_count
	checks["appropriate_contact"]=plate if tier=="heavy" else embedded
	checks["damage_law"]=is_equal_approx(float(host._npc_hp),hp_before) if tier=="heavy" else float(host._npc_hp)<hp_before
	var max_anchor_error:=0.;var max_wood_inside:=-INF
	for item:Dictionary in axes.pool:
		if item.state!="embedded":continue
		var rig:Skeleton3D=item.skin_rig31.get_ref()
		var expected:Transform3D=rig.global_transform*rig.get_bone_global_pose(int(item.skin_bone31))*Transform3D(item.skin_local31)
		max_anchor_error=maxf(max_anchor_error,expected.origin.distance_to(item.node.global_position))
	checks["bone_follow"]=max_anchor_error<.001
	var wood_outside:=true
	for event:Dictionary in axes.events:
		if event.get("event","")=="embed":wood_outside=wood_outside and float(event.get("wood_exterior_m",-1.))>=.001
	checks.wood_outside=wood_outside
	for item:Dictionary in axes.pool:
		if item.state in ["embedded","ground"]:
			await closeup(item.node.global_position+item.node.global_basis.x*.25,Vector3(1.,.45,1.3),"result_close")
			break
	if pickup_after:
		var item:Dictionary=axes.pool[0];var id:int=item.node.get_instance_id();var before_count:int=axes.count()
		await ticks(90)
		for i in 180:
			var delta:Vector3=item.node.global_position-player.global_position;delta.y=0
			if delta.length()<1.1:break
			delta=delta.normalized()
			action("preview_move_right",maxf(0,delta.x));action("preview_move_left",maxf(0,-delta.x));action("preview_move_forward",maxf(0,-delta.z));action("preview_move_back",maxf(0,delta.z))
			await ticks(1)
		for control in ["preview_move_right","preview_move_left","preview_move_forward","preview_move_back"]:action(control,0)
		await ticks(6);key(KEY_E);await ticks(4)
		checks.actual_bounce_pickup_charge=axes.count()==before_count+1
		checks.actual_bounce_pickup_same_item=item.node.get_instance_id()==id and item.state in ["reserve","held"]
		rows.append({"pickup_player":player.global_position,"pickup_item":item.node.global_position,"state":item.state})
	rows.append({"final":axes.snapshot(),"hp_before":hp_before,"hp_after":host._npc_hp,"anchor_error":max_anchor_error})
	key(KEY_F6);await ticks(30)
	checks.f6_all_three_same_ground=axes.pool.size()==3 and axes.count()==0
	for i in axes.pool.size():checks.f6_all_three_same_ground=checks.f6_all_three_same_ground and is_instance_valid(axes.pool[i].node) and axes.pool[i].node.get_instance_id()==original_ids[i] and axes.pool[i].state=="ground"
	rows.append({"phase":"three_throw_f6","state":axes.snapshot()})

	finish()
func finish():
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows,"tier":tier,"charge_ticks":charge_ticks},"  "))
	var old:Node=current_scene;current_scene=null
	if is_instance_valid(old):old.queue_free()
	await ticks(4);quit(0 if not checks.values().has(false) else 1)
