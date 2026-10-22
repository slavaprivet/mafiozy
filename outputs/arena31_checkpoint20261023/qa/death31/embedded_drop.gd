extends SceneTree
const P=preload("res://scripts/combat/puncture29.gd")
var out:String
var weapon:int=4
var corpse:bool=false
var aim_test:bool=false
var leave_dropped:bool=false
var hold_ticks:int=45
var checks:Dictionary={}
var rows:Array=[]
var host:Node
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--weapon="):weapon=int(arg.trim_prefix("--weapon="))
		if arg=="--corpse":corpse=true
		if arg=="--aim-extract":aim_test=true
		if arg=="--leave-dropped":leave_dropped=true
		if arg.begins_with("--hold-ticks="):hold_ticks=int(arg.trim_prefix("--hold-ticks="))
	run.call_deferred()
func action(name:StringName,strength:float):
	var e:=InputEventAction.new();e.action=name;e.pressed=strength>0.;e.strength=strength;Input.parse_input_event(e);Input.flush_buffered_events()
func button(index:int,down:bool):
	var e:=InputEventMouseButton.new();e.button_index=index;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
	var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func key(code:int):
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);Input.flush_buffered_events()
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);Input.flush_buffered_events()
func tick():
	await physics_frame;await create_timer(0).timeout
func frames(n:int):
	for i in n:await tick()
func channel()->Dictionary:return host.get_meta("puncture29_channel",{})
func wound_id(c:Dictionary)->int:
	var ref=c.get("node_ref")
	return ref.get_ref().get_instance_id() if ref!=null and is_instance_valid(ref.get_ref()) else -1
func attachment(model:Node)->Dictionary:
	if not is_instance_valid(model) or not model.has_meta("embedded_drop31"):return {}
	var helper=model.get_meta("embedded_drop31")
	return helper.status() if is_instance_valid(helper) and helper.has_method("status") else {}
func attachment_physics(model:Node)->Dictionary:
	if not is_instance_valid(model) or not model.has_meta("embedded_drop31"):return {}
	var helper:Node=model.get_meta("embedded_drop31")
	var body:PhysicsBody3D=helper.get("body")
	var joint:Joint3D=helper.get("joint")
	var anchor:Node3D=helper.get("live_anchor")
	var target:PhysicsBody3D=joint.get_node_or_null(joint.node_a) if is_instance_valid(joint) else null
	return {"body":body.global_transform if is_instance_valid(body) else null,"server_body":PhysicsServer3D.body_get_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM) if is_instance_valid(body) else null,"server_target":PhysicsServer3D.body_get_state(target.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM) if is_instance_valid(target) else null,"target_node":target.global_transform if is_instance_valid(target) else null,"velocity":body.linear_velocity if body is RigidBody3D else null,"angular_velocity":body.angular_velocity if body is RigidBody3D else null,"joint":joint.global_transform if is_instance_valid(joint) else null,"node_a":str(joint.node_a) if is_instance_valid(joint) else "","node_b":str(joint.node_b) if is_instance_valid(joint) else "","live_anchor":anchor.global_transform if is_instance_valid(anchor) else null,"model_local":model.transform}
func count_id(model:Node)->int:
	var n:=0
	for item in host._ground_swords:
		if is_instance_valid(item) and item==model:n+=1
	return n
func bone_frame(c:Dictionary)->Transform3D:
	var ref=c.get("rig_ref")
	var rig:Skeleton3D=ref.get_ref() if ref!=null else null
	return rig.global_transform*rig.get_bone_global_pose(int(c.bone)) if is_instance_valid(rig) else Transform3D.IDENTITY
func body_shape_count(body:PhysicsBody3D)->int:
	var count:=0
	if not is_instance_valid(body):return count
	for child in body.get_children():
		if child is CollisionShape3D and not child.disabled:count+=1
	return count
func regrab_diagnostic(model:Node3D)->Dictionary:
	var helper:Node=model.get_meta("embedded_drop31",null)
	if not is_instance_valid(helper):return {}
	var rig:Skeleton3D=host._rig;var axis:=model.global_basis.x.normalized()
	var grip:Vector3=model.global_position-axis*float(helper.get("grip_offset"))
	var arms:Array=[]
	for side:StringName in [&"right",&"left"]:
		var arm:Dictionary=host._arm_set(side)
		var shoulder:Vector3=rig.global_transform*rig.get_bone_global_pose(int(arm.upper)).origin
		var desired:Vector3=grip-axis*float(helper.get("support_offset"))*rig.global_basis.get_scale().x if side==&"left" else grip
		var reach:float=(Transform3D(arm.rest_fore).origin.length()+Transform3D(arm.rest_hand).origin.length())*rig.global_basis.get_scale().x
		arms.append({"side":side,"desired":desired,"shoulder":shoulder,"distance":desired.distance_to(shoulder),"reach":reach})
	return {"can_regrab":helper.can_regrab(host),"self_clear":host._self_blade_clear_at51(axis,model.global_position),"arms":arms,"player":host._player.global_position,"nearest":host._nearest_ground_sword(),"menu":current_scene.preview_weapons.menu_open,"active":host._active()}
func sample(phase:String,model:Node):
	var c:=channel()
	rows.append({"phase":phase,"dead":host._npc_dead,"channel_id":wound_id(c),"channel_valid":c.get("valid",false),"channel_active":c.get("active",false),"withdrawn":c.get("withdrawn",false),"release_reason":c.get("release_reason",""),"current_depth":c.get("current_depth",0),"cut_depth":c.get("cut_depth",0),"model_id":model.get_instance_id() if is_instance_valid(model) else -1,"held_id":host._sword.get_instance_id() if is_instance_valid(host._sword) else -1,"ground_count":host.ground_sword_count(),"same_model_ground_count":count_id(model),"grounded":host._sword_grounded,"attachment":attachment(model),"aiming":host._aiming_throw,"throwing":host._throwing,"cast_pending":host._spear_cast_pending31,"thrown_total":host._thrown_total,"embedded":host._embedded29.status(),"player":host._player.global_position,"model_transform":model.global_transform if is_instance_valid(model) else null})
func screenshot(label:String):
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join(label+".png"))
func actual_depth(c:Dictionary,model:Node3D,tip_local:Vector3)->float:
	var frame:=bone_frame(c)
	var tip:=model.global_transform*tip_local
	var entry:Vector3=frame*Vector3(c.entry_local)
	var axis:Vector3=(frame.basis*Vector3(c.axis_local)).normalized()
	return (tip-entry).dot(axis)
func aim_blocked(model:Node3D,label:String):
	var total:int=host._thrown_total
	var saved:=channel().duplicate();var tip_local:=P.tip_local(host)
	var start_depth:=actual_depth(saved,model,tip_local)
	var initial_tip:Vector3=bone_frame(saved).affine_inverse()*(model.global_transform*tip_local)
	var max_axial_back:=0.;var positive_samples:=0;var forbidden:=false;var crossed:=false;var aimed_after:=false
	checks[label+"_starts_inside"]=start_depth>.001 and bool(saved.get("valid",false)) and not bool(saved.get("withdrawn",false))
	button(MOUSE_BUTTON_LEFT,false);button(MOUSE_BUTTON_RIGHT,true);button(MOUSE_BUTTON_LEFT,true)
	if start_depth>0.0001:forbidden=host._aiming_throw or host._throwing or host._spear_cast_pending31 or host._thrown_total!=total
	# Observe every final pose. An actual completed axial extraction may enable aim.
	for i in 180:
		await tick()
		var depth:=actual_depth(saved,model,tip_local)
		var local_tip:Vector3=bone_frame(saved).affine_inverse()*(model.global_transform*tip_local)
		max_axial_back=maxf(max_axial_back,(initial_tip-local_tip).dot(Vector3(saved.axis_local).normalized()))
		if depth>0.0001:
			positive_samples+=1
			forbidden=forbidden or host._aiming_throw or host._throwing or host._spear_cast_pending31 or host._thrown_total!=total
		else:crossed=true
		rows.append({"phase":"aim_extract","tick":i,"actual_depth":depth,"max_axial_backward":max_axial_back,"channel_valid":channel().get("valid",false),"aim":host._aiming_throw,"throw":host._throwing,"cast":host._spear_cast_pending31,"grounded":host._sword_grounded})
		if crossed and bool(channel().get("withdrawn",false)):break
		if host._sword_grounded or host._sword!=model:break
	button(MOUSE_BUTTON_RIGHT,false);button(MOUSE_BUTTON_LEFT,false)
	await frames(2)
	if crossed and not host._sword_grounded:
		button(MOUSE_BUTTON_RIGHT,true);await frames(3);aimed_after=host._aiming_throw;button(MOUSE_BUTTON_RIGHT,false)
	checks[label+"_no_aim_while_inside"]=not forbidden
	checks[label+"_actual_backward_extraction"]=crossed and max_axial_back>=start_depth-.0001 and not host._sword_grounded
	checks[label+"_aim_after_exit"]=aimed_after and host._sword==model
	rows.append({"phase":"aim_summary","positive_depth_samples":positive_samples,"initial_depth":start_depth})
	sample(label,model)
func run():
	root.size=Vector2i(1280,720);root.title="QA31 independent embedded G ownership"
	var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
	while not scene.lab_ready:await physics_frame
	host=scene.lab;host.lab_regrow=false;scene._lab_equip(weapon)
	var player:Node=scene._player
	player.global_position=Vector3(.2 if weapon==0 else 0.,.05,1.3);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.00814;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(30);button(MOUSE_BUTTON_LEFT,true);motion(Vector2(0,100));await frames(60)
	action("preview_move_forward",.6)
	var reached:=false
	for i in 480:
		await tick()
		var c:=channel()
		if (corpse and host._npc_dead) or (not corpse and float(c.get("cut_depth",0))>.003 and float(c.get("current_depth",0))>.001):reached=true;break
	action("preview_move_forward",0.)
	var model:Node3D=host._sword
	var before:=channel();var wid:=wound_id(before);var rig_id:int=host._npc_rig.get_instance_id()
	checks["actual_entry"]=reached and wid>0 and float(before.get("cut_depth",0))>.001
	checks["requested_life_state"]=bool(host._npc_dead)==corpse
	checks["channel_valid_before_G"]=bool(before.get("valid",false)) and not bool(before.get("withdrawn",false))
	sample("entry",model)
	if reached and aim_test:
		await aim_blocked(model,"held_embedded")
	elif reached:
		var drop_pose:=model.global_transform
		var saved_channel:=channel().duplicate()
		var local_drop:=bone_frame(saved_channel).affine_inverse()*drop_pose
		var corpse_segment:RigidBody3D=null
		if corpse and is_instance_valid(host._npc_corpse31) and host._npc_corpse31.has_meta("ragdoll31"):
			corpse_segment=host._npc_corpse31.get_meta("ragdoll31").body_for_bone(int(saved_channel.bone))
		var original_mass:float=corpse_segment.mass if is_instance_valid(corpse_segment) else 0.
		var original_shapes:=body_shape_count(corpse_segment)
		key(KEY_G)
		rows.append({"phase":"drop_immediate","model":model.global_transform,"physics":attachment_physics(model)})
		await tick()
		rows.append({"phase":"drop_tick1","model":model.global_transform,"physics":attachment_physics(model)})
		checks["G_same_weapon_no_teleport"]=is_instance_valid(model) and model.global_position.distance_to(drop_pose.origin)<.05
		checks["G_one_ground_owner"]=host._sword_grounded and count_id(model)==1 and bool(attachment(model).get("active",false))
		if corpse:
			var added_mass:float=float(attachment(model).get("mass_added",0.))
			checks["G_corpse_owned_mass_shape"]=is_instance_valid(corpse_segment) and added_mass>0. and absf(corpse_segment.mass-original_mass-added_mass)<.0001 and body_shape_count(corpse_segment)==original_shapes+1
		var retained:=true;var max_anchor_error:=0.
		for i in hold_ticks:
			await tick();retained=retained and bool(attachment(model).get("active",false))
			if i<7:rows.append({"phase":"drop_tick"+str(i+2),"model":model.global_transform,"physics":attachment_physics(model)})
			if is_instance_valid(model):max_anchor_error=maxf(max_anchor_error,model.global_position.distance_to((bone_frame(saved_channel)*local_drop).origin))
		checks["G_remains_attached_"+str(hold_ticks)+"_ticks"]=retained and host._npc_rig.get_instance_id()==rig_id and is_instance_valid(model)
		checks["G_follows_original_bone"]=max_anchor_error<.08 and wound_id(saved_channel)==wid
		rows.append({"phase":"attachment_error","max_anchor_error_m":max_anchor_error})
		sample("dropped_hold",model);await screenshot("dropped")
		var count_before:int=host.ground_sword_count()
		key(KEY_G);await frames(2)
		checks["repeat_G_no_duplicate"]=count_id(model)==1 and host.ground_sword_count()==count_before
		key(KEY_Q);await frames(2);key(KEY_Q);await frames(2)
		checks["Q_menu_no_duplicate"]=count_id(model)==1 and host.ground_sword_count()==count_before and bool(attachment(model).get("active",false))
		if leave_dropped:
			var leave_start:Vector3=host._player.global_position
			action("preview_move_back",.6);await frames(90);action("preview_move_back",0.);await frames(5)
			var remaining:=attachment(model)
			checks["dropped_owner_grace_cleared"]=host._player.global_position.distance_to(leave_start)>1. and not bool(remaining.get("holder_grace",false)) and bool(remaining.get("holder_grace_cleared",false))
			key(KEY_E);await frames(3)
			checks["distant_E_atomic_refusal"]=host._sword_grounded and count_id(model)==1 and bool(attachment(model).get("active",false)) and actual_depth(saved_channel,model,P.tip_local(host))>.0001
			sample("distant_regrab_refused",model);await screenshot("distant_regrab_refused")
			await finish(scene);return
		rows.append({"phase":"before_E","diagnostic":regrab_diagnostic(model)})
		var grab_before:=regrab_diagnostic(model)
		if not bool(grab_before.get("can_regrab",false)):
			key(KEY_E);await frames(2)
			checks["unsafe_E_atomic_refusal"]=host._sword_grounded and count_id(model)==1 and bool(attachment(model).get("active",false))
			var reach_start:Vector3=host._player.global_position
			action("preview_move_back",.6)
			for i in 20:
				await tick()
				rows.append({"phase":"reach_step","tick":i,"diagnostic":regrab_diagnostic(model)})
				if bool(regrab_diagnostic(model).get("can_regrab",false)):break
				if host._player.global_position.distance_to(reach_start)>=.12:break
			action("preview_move_back",0.)
			rows.append({"phase":"after_reach_step","diagnostic":regrab_diagnostic(model)})
			if not bool(regrab_diagnostic(model).get("can_regrab",false)):
				action("preview_move_forward",.6)
				for i in 20:
					await tick();rows.append({"phase":"face_forward_step","tick":i,"diagnostic":regrab_diagnostic(model)})
					if bool(regrab_diagnostic(model).get("can_regrab",false)):break
				action("preview_move_forward",0.)
		host.set_meta("debug_bore31",true)
		key(KEY_E)
		rows.append({"phase":"E_immediate","actual_depth":actual_depth(saved_channel,model,P.tip_local(host)),"model":model.global_transform,"tip":P.tip_world(host),"channel":channel().get("current_depth",0),"embedded":host._embedded29.status(),"last_good":host._solid_weapon29._last_good_transform,"solid_ready":host._solid_weapon29._ready,"publish_safe":host._solid_weapon29._publish_safe,"bore_reject":host._solid_weapon29.bore_reject31.duplicate(true),"player":host._player.global_position,"velocity":host._player.velocity})
		for i in 3:
			await tick();rows.append({"phase":"E_final_pose","tick":i,"actual_depth":actual_depth(saved_channel,model,P.tip_local(host)),"model":model.global_transform,"tip":P.tip_world(host),"channel":channel().get("current_depth",0),"embedded":host._embedded29.status(),"solid":host._solid_weapon29.last_contact.duplicate(),"last_good":host._solid_weapon29._last_good_transform,"solid_ready":host._solid_weapon29._ready,"publish_safe":host._solid_weapon29._publish_safe,"bore_reject":host._solid_weapon29.bore_reject31.duplicate(true),"player":host._player.global_position,"velocity":host._player.velocity})
		checks["E_regrabs_same_instance"]=host._sword==model and not host._sword_grounded and count_id(model)==0
		checks["E_preserves_original_wound"]=wound_id(channel())==wid and bool(channel().get("valid",false)) and not bool(channel().get("withdrawn",false)) and actual_depth(saved_channel,model,P.tip_local(host))>0.0001
		if corpse:checks["E_restores_only_owned_mass_shape"]=is_instance_valid(corpse_segment) and absf(corpse_segment.mass-original_mass)<.0001 and body_shape_count(corpse_segment)==original_shapes
		sample("regrab",model)
		var before_back:=channel();var held_before_back:bool=not host._sword_grounded and bool(before_back.get("valid",false)) and not bool(before_back.get("withdrawn",false))
		var back_channel:=before_back.duplicate();var back_tip:=P.tip_local(host)
		var depth_before_back:=actual_depth(back_channel,model,back_tip)
		action("preview_move_back",.6)
		for i in 180:
			await tick()
			if bool(channel().get("withdrawn",false)):break
		action("preview_move_back",0.);await frames(2)
		checks["real_S_withdrawal"]=held_before_back and depth_before_back>.0001 and actual_depth(back_channel,model,back_tip)<=.0001 and bool(channel().get("withdrawn",false)) and not host._sword_grounded and host._sword==model
		sample("withdrawn",model)
		if weapon==4:
			button(MOUSE_BUTTON_RIGHT,true);await frames(3)
			checks["aim_allowed_after_withdrawal"]=host._aiming_throw and not host._sword_grounded
			button(MOUSE_BUTTON_RIGHT,false)
		await screenshot("withdrawn")
	await finish(scene)
func finish(scene:Node):
	action("preview_move_forward",0.);action("preview_move_back",0.);button(MOUSE_BUTTON_LEFT,false);button(MOUSE_BUTTON_RIGHT,false)
	var passed:=true
	for v:bool in checks.values():passed=passed and v
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"weapon":weapon,"corpse":corpse,"hold_ticks":hold_ticks,"rows":rows,"scope":"Actual input only after initial scene placement. Same weapon/wound IDs; no direct wound creation, forced death, teleport during strike or API drop/pickup. Sandbox ownership only, production storage needs separate coverage. Nondefault hold_ticks denotes a separate early-regrab scenario, not long-hold acceptance."},"\t"))
	host=null;current_scene=null;scene.queue_free();await frames(5);quit(0 if passed else 1)
