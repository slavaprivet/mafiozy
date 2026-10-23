extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
var samples:Array=[]
var x:=1.2
var z:=-3.5
var yaw:=0.
var pitch:=-.1
var dx:=-20.
var dy:=0.
var stroke:=8
var wind_y:=0.
var probe:=false
var scene:Node
var h:Node
var player:CharacterBody3D
var helper:Node
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
		if a.begins_with("--x="):x=float(a.trim_prefix("--x="))
		if a.begins_with("--z="):z=float(a.trim_prefix("--z="))
		if a.begins_with("--yaw="):yaw=float(a.trim_prefix("--yaw="))
		if a.begins_with("--pitch="):pitch=float(a.trim_prefix("--pitch="))
		if a.begins_with("--dx="):dx=float(a.trim_prefix("--dx="))
		if a.begins_with("--dy="):dy=float(a.trim_prefix("--dy="))
		if a.begins_with("--stroke="):stroke=int(a.trim_prefix("--stroke="))
		if a.begins_with("--wind-y="):wind_y=float(a.trim_prefix("--wind-y="))
		if a=="--probe":probe=true
	run.call_deferred()
func frames(n:int):
	for i in n:await process_frame;await create_timer(0).timeout
func button(down:bool):
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(v:Vector2):
	var e:=InputEventMouseMotion.new();e.relative=v;e.screen_relative=v;Input.parse_input_event(e);Input.flush_buffered_events()
func key(k:int):
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=k;e.physical_keycode=k;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	root.size=Vector2i(1280,720);root.set_flag(Window.FLAG_NO_FOCUS,true);seed(35023)
	change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	checks.startup=is_instance_valid(current_scene) and current_scene.get("lab_ready")==true
	if not checks.startup:finish();return
	scene=current_scene;h=scene.lab;player=scene._player;helper=h._hatchet32
	h.lab_armored=false;h.lab_armor_tier30="none";h.set_npc_armor31({})
	scene._lab_equip(7)
	player.global_position=Vector3(x,.05,z);player.velocity=Vector3.ZERO
	player._camera_yaw=yaw;player._camera_pitch=pitch;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(40)
	var rig:Skeleton3D=h._npc_rig
	var target:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin
	button(true);await frames(12)
	if wind_y!=0.:
		for i in 16:motion(Vector2(0,wind_y));await frames(1)
		await frames(12)
	for i in stroke:
		motion(Vector2(dx,dy));await frames(1)
		var model:Node3D=h._sword
		var point:Vector3=model.global_transform*helper.MASS_POINT35
		samples.append({"frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"delta":helper.get_process_delta_time(),"point":point,"sample_point":helper.previous_point35,"sample_error":point.distance_to(helper.previous_point35),"velocity":helper.release_velocity35,"speed":helper.release_velocity35.length(),"edge_dot":helper.release_velocity35.normalized().dot(model.global_basis.y)})
	var model:Node3D=h._sword
	var release:Transform3D=model.global_transform
	var velocity:Vector3=helper.release_velocity35
	rows.append({"release":release,"velocity":velocity,"edge_dot":velocity.normalized().dot(model.global_basis.y),"target":target,"player":player.global_position})
	button(false)
	checks.real_release=helper.launched==1
	checks.accepted_pose_sample=true
	for row:Dictionary in samples:checks.accepted_pose_sample=checks.accepted_pose_sample and float(row.sample_error)<.000001
	checks.exact_release_velocity=Vector3(helper.pool[0].velocity).distance_to(velocity)<.000001
	checks.exact_release_pose=model.global_transform==release
	var closest:=INF
	for i in 160:
		await physics_frame;await create_timer(0).timeout
		var edge:Vector3=model.global_transform*Vector3(.34,.17,0.)
		if target.distance_to(edge)<closest:
			closest=target.distance_to(edge);rows.append({"tick":i,"edge":edge,"distance":closest,"state":helper.pool[0].state,"velocity":helper.pool[0].velocity})
		if helper.pool[0].state!="flying":break
	checks.actual_edge_embedded=helper.pool[0].state=="embedded"
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/impact.png")
	if checks.actual_edge_embedded:
		var entry:Dictionary=helper.pool[0]
		await frames(90)
		var bone:int=entry.skin_bone31
		var expected:Transform3D=rig.global_transform*rig.get_bone_global_pose(bone)*Transform3D(entry.skin_local31)
		checks.held_in_body=entry.state=="embedded" and model.global_transform.is_equal_approx(expected)
		rows.append({"embed":helper.last.duplicate(true),"hold_position":model.global_position,"identity":model.get_instance_id()})
		# Evidence camera only after the accepted impact and 90-frame follow check.
		var old_camera:Camera3D=root.get_camera_3d()
		var evidence:=Camera3D.new();scene.add_child(evidence)
		evidence.global_position=model.global_position+Vector3(1.1,.35,.55)
		evidence.look_at(model.global_position+Vector3(0,.12,0));evidence.fov=42.;evidence.make_current()
		await frames(3);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/embedded_side.png")
		old_camera.make_current();evidence.queue_free()
		key(KEY_F6);await frames(15)
		checks.reset_drops_same_model=entry.state=="ground"
		player.global_position=model.global_position+Vector3(.3,0,.3);player.global_position.y=.05;player.velocity=Vector3.ZERO
		await frames(2);key(KEY_E);await frames(3)
		checks.E_reclaims_charge=helper.picked==1 and helper.count()==3
		checks.same_object_reclaimed=entry.node==model and entry.state in ["reserve","held"]
	finish()
func finish():
	var passed:=not checks.values().has(false)
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"samples":samples,"events":helper.events if is_instance_valid(helper) else [],"scope":"Real mouse swing/release/ballistic impacts. Only player initial position is fixture setup; no weapon/contact/velocity injection."},"  "))
	var old:Node=current_scene;current_scene=null;if is_instance_valid(old):old.queue_free()
	await frames(4);quit(0 if passed else 1)
