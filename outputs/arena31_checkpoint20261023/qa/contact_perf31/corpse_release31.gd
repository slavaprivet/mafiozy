extends SceneTree
var reset_case:=false
var out:String
var checks:Dictionary={}
var rows:Array=[]
var released_model:Node3D
var release_seen:=false
var release_player_step:=INF
var release_mass:=0.0
var release_anchor_error:=0.0
var release_depth:=0.0
var release_depth_error:=0.0
var release_wound:=-1
var release_body:RigidBody3D
var release_shape:CollisionShape3D
var release_attachment:Node
var previous_player:=Vector3.ZERO
const P=preload("res://scripts/combat/puncture29.gd")
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
		if a=="--reset-case":reset_case=true
	run.call_deferred()
func key(code:int):
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events()
	event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
func move(action:StringName,value:float):
	var e:=InputEventAction.new();e.action=action;e.pressed=value>0;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
func button(value:bool):
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
	var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func frames(n:int):
	for i in n:await process_frame
func sample(host:Node,label:String,phase:String,tick:int):
	var channel:Dictionary=host.get_meta("puncture29_channel",{})
	var attached:Node=host._embedded29.dropped_attachment31(released_model)
	var extra:Dictionary={}
	if is_instance_valid(attached):
		extra=attached.status()
		if not release_seen:
			release_player_step=host._player.global_position.distance_to(previous_player)
			release_depth=float(extra.depth);release_wound=int(extra.target_id)
			release_body=attached.body;release_mass=release_body.mass
			release_shape=attached.owned_shape;release_attachment=attached
			release_seen=true
		var predicted:Transform3D=attached._anchor()*attached.bone_weapon_local
		release_anchor_error=maxf(release_anchor_error,released_model.global_position.distance_to(predicted.origin))
		release_depth_error=maxf(release_depth_error,absf(float(extra.depth)-release_depth))
	previous_player=host._player.global_position
	rows.append({"weapon":label,"phase":phase,"tick":tick,"dead":host._npc_dead,"depth":channel.get("current_depth",0),"cut_depth":channel.get("cut_depth",0),"valid":channel.get("valid",false),"withdrawn":channel.get("withdrawn",false),"release":channel.get("release_reason",""),"tip":P.tip_world(host),"node":channel.node_ref.get_ref().get_instance_id() if channel.get("node_ref")!=null and is_instance_valid(channel.node_ref.get_ref()) else -1,"embedded":host._embedded29.status(),"solid_safe":host._solid_weapon29._publish_safe})
	rows[-1].attachment=extra
	rows[-1].grounded=host._sword_grounded
	rows[-1].solid_reason=host._solid_weapon29.last_contact.get("reason","")
	if phase!="approach":
		rows[-1].guide=host._sword_puncture_resistance29.last.duplicate(true);rows[-1].active=channel.get("active",false);rows[-1].omega=host._omega;rows[-1].player=host._player.global_position;rows[-1].origin=host._sword.global_position;rows[-1].axis=host._dir
		rows[-1].entry=channel.get("entry_world");rows[-1].bore_axis=channel.get("axis_world")
		rows[-1].contact=host._solid_weapon29.last_contact.duplicate()
		rows[-1].obstruction=host._solid_weapon29._world_obstruction.duplicate()
		rows[-1].solver_usec=host._solid_weapon29.last_solver_usec
		var solid=host._solid_weapon29
		var hit:Dictionary=solid.last_contact
		if hit.has("position") and hit.has("current_transform") and channel.get("node_ref")!=null:
			var node=channel.node_ref.get_ref()
			if is_instance_valid(node):
				var frame:Transform3D=solid._bore_frame(host,node)
				var before:Transform3D=solid._accepted_bore_frame
				rows[-1].bore_debug={"point":frame.affine_inverse()*Vector3(hit.position),"tip":frame.affine_inverse()*(Transform3D(hit.current_transform)*P.tip_local(host)),"prev":before.affine_inverse()*Vector3(hit.previous_sample),"next":frame.affine_inverse()*Vector3(hit.current_sample),"max_depth":channel.get("max_depth"),"radius":channel.get("radius"),"axisdot":Transform3D(hit.current_transform).basis.x.dot(-frame.basis.z.normalized())}

		rows[-1].ragdoll=host._deep_collapse29.ragdoll.status.duplicate(true)
func scenario(label:String,weapon:int):
	var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
	while not scene.lab_ready:await physics_frame
	var host:Node=scene.lab;host.lab_regrow=false;scene._lab_equip(weapon)
	var player:Node=scene._player
	player.global_position=Vector3(.2 if weapon==0 else 0.,.05,1.3);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.00814;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(30)
	released_model=host._sword;previous_player=player.global_position
	var before_pose:Transform3D=released_model.global_transform
	var before_count:int=host._ground_swords.size()
	checks["required_embedded_failure_refuses"]=not host.drop_sword_to_ground(true)
	checks["required_failure_atomic"]=not host._sword_grounded and host._sword==released_model and released_model.global_transform==before_pose and host._ground_swords.size()==before_count
	button(true);motion(Vector2(0,100))
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
		var initial:Dictionary=host.get_meta("puncture29_channel",{})
		var solid=host._solid_weapon29
		var wound:Node3D=initial.node_ref.get_ref()
		var bore:Transform3D=solid._bore_frame(host,wound)
		var inward:Vector3=-bore.basis.z.normalized()
		var point:=bore.origin+inward*.005
		var held:Transform3D=host._sword.global_transform
		checks["verified_bore_accepts_steel"]=solid._channel_allows(host,point,point,held,false,Vector3.INF,"chest")
		checks["bore_rejects_other_limb"]=not solid._channel_allows(host,point,point,held,false,Vector3.INF,"head")
		var lateral:=point+bore.basis.x*.08
		checks["bore_rejects_lateral_passage"]=not solid._channel_allows(host,lateral,lateral,held,false,Vector3.INF,"chest")
		var hilt_pose:=Transform3D(held.basis,point-held.basis.x*.10)
		checks["bore_rejects_guard_and_hilt"]=not solid._channel_allows(host,point,point,hilt_pose,false,Vector3.INF,"chest")
		initial.generation+=1
		checks["bore_rejects_stale_generation"]=not solid._channel_allows(host,point,point,held,false,Vector3.INF,"chest")
		initial.generation-=1
		var last:Dictionary=host.get_meta("puncture29_channel",{})
		var same:=true
		var all_safe:=true;var worst_solver:=0
		for i in 8:
			await physics_frame;await create_timer(0).timeout
			last=host.get_meta("puncture29_channel",{})
			max_after=maxf(max_after,float(last.get("cut_depth",0)))
			same=same and rig.get_instance_id()==rig_id and last.node_ref.get_ref().get_instance_id()==wound_id
			sample(host,label,"continue",i)
			all_safe=all_safe and host._solid_weapon29._publish_safe
			worst_solver=maxi(worst_solver,host._solid_weapon29.last_solver_usec)
		checks[label+"_same_anchor"]=same
		checks[label+"_continued_safe"]=all_safe
		checks[label+"_continued_solver_under50ms"]=worst_solver<50000
		checks[label+"_active_before_backward"]=last.get("active",false) and not last.get("withdrawn",false)
		checks[label+"_continued_insertion"]=max_after>death_depth+.0002 or bool(host._deep_collapse29.last.get("ratio",0)>=.999)
		move("preview_move_forward",0.)
		for i in 90:
			await physics_frame;await create_timer(0).timeout
			sample(host,label,"fall_hold",i)
		checks["corpse_unreachable_releases_hands"]=release_seen and host._sword_grounded
		checks["release_same_model"]=release_seen and host._sword==released_model
		checks["release_original_wound"]=release_seen and release_wound==wound_id
		checks["release_positive_retained_depth"]=release_seen and release_depth>0.0001 and release_depth_error<0.00001
		checks["release_no_holder_jump"]=release_seen and release_player_step<0.03
		checks["release_same_bone_pose"]=release_seen and release_anchor_error<0.00001
		checks["release_mass_once"]=release_seen and is_instance_valid(release_body) and absf(release_body.mass-release_mass)<0.00001 and absf(release_attachment.mass_added-host._weapon_mass)<0.00001
		checks["release_owned_collider"]=release_seen and is_instance_valid(release_shape) and release_shape.get_parent()==release_body and not release_shape.disabled
		var count:=0
		for item in host._ground_swords:
			if is_instance_valid(item) and item==released_model:count+=1
		checks["release_one_inventory_item"]=count==1
		checks["release_not_manual_withdrawal"]=release_seen and not release_attachment.channel.get("withdrawn",false)
	move("preview_move_forward",0.);move("preview_move_back",0.);button(false)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+label+"_end.png")
	if release_seen:
		var owned:WeakRef=weakref(release_shape)
		var helper:WeakRef=weakref(release_attachment)
		var restored_mass:float=release_body.mass-release_attachment.mass_added
		if reset_case:
			var before_reset:int=host.lab_resets
			key(KEY_F6);await frames(10)
			checks["native_F6_reset"]=host.lab_resets>before_reset and not host._npc_dead
			checks["reset_attachment_inactive"]=not is_instance_valid(helper.get_ref()) or not helper.get_ref().active
			checks["reset_owned_collider_gone"]=not is_instance_valid(owned.get_ref())
			checks["reset_same_model_survives"]=is_instance_valid(released_model) and host._sword==released_model and released_model.is_inside_tree()
			var retained_count:=0
			for item in host._ground_swords:
				if is_instance_valid(item) and item==released_model:retained_count+=1
			checks["reset_one_inventory_item"]=retained_count==1
		else:
			release_attachment.prepare_regrab(host)
			checks["retire_removes_own_mass_once"]=absf(release_body.mass-restored_mass)<0.00001
			release_attachment.queue_free();await frames(2)
			checks["retire_owned_collider_gone"]=not is_instance_valid(owned.get_ref())
			checks["retire_helper_gone"]=not is_instance_valid(helper.get_ref())
	current_scene=null;scene.queue_free();await frames(4)
func run():
	root.size=Vector2i(1280,720);root.title="QA31 unreachable corpse grip releases same embedded sword"
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	await scenario("sword",0)
	checks["hold_has_valid_owner"]=rows.all(func(row):return row.phase!="fall_hold" or (row.attachment.get("active",false) if row.grounded else row.solid_safe))
	checks["long_hold_under50ms"]=rows.all(func(row):return row.phase!="fall_hold" or row.solver_usec<50000)
	var ordinary:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(ordinary);current_scene=ordinary
	while not ordinary.lab_ready:await physics_frame
	ordinary._lab_equip(0);ordinary._player.set_mouse_captured(true)
	await frames(30)
	var ordinary_model:Node3D=ordinary.lab._sword
	key(KEY_G);await frames(3)
	checks["default_G_still_drops"]=ordinary.lab._sword_grounded and is_instance_valid(ordinary_model)
	checks["default_G_no_embedded_attachment"]=not is_instance_valid(ordinary.lab._embedded29.dropped_attachment31(ordinary_model))
	current_scene=null;ordinary.queue_free();await frames(4)
	var passed:=true
	for v:bool in checks.values():passed=passed and v
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"release_player_step":release_player_step,"release_anchor_error":release_anchor_error,"release_depth_error":release_depth_error,"release_depth":release_depth},"\t"));quit()
