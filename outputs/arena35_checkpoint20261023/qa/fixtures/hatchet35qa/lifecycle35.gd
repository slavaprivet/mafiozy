extends "throw35.gd"
func setup():
	change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	scene=current_scene;h=scene.lab;player=scene._player;helper=h._hatchet32
	scene._lab_equip(7)
	player.global_position=Vector3(0,.05,-6);player.velocity=Vector3.ZERO
	player._camera_yaw=0.;player._camera_pitch=-.1;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(40)
func run():
	root.size=Vector2i(1280,720);root.set_flag(Window.FLAG_NO_FOCUS,true);seed(35023)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for fps:int in [60,120]:
		Engine.max_fps=fps
		await setup()
		button(true);await frames(12)
		for i in fps/3:
			motion(Vector2(-1200.,0.)*helper.get_process_delta_time());await frames(1)
			var model:Node3D=h._sword
			var point:Vector3=model.global_transform*helper.MASS_POINT35
			samples.append({"fps_cap":fps,"i":i,"frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"delta":helper.get_process_delta_time(),"point":point,"point_xyz":[point.x,point.y,point.z],"sample_error":point.distance_to(helper.previous_point35),"velocity":helper.release_velocity35,"speed":helper.release_velocity35.length(),"edge_dot":helper.release_velocity35.normalized().dot(model.global_basis.y)})
		button(false);await frames(3)
		checks["real_release_%s"%fps]=helper.launched==1
	# Q closes control while the physical button was held; a later release must
	# not turn a missed-release into a throw after the menu closes.
	button(true);await frames(3);key(KEY_Q);await frames(3)
	checks.menu_cancels=not helper.release_armed35 and not player._free_mouse_look
	button(false);key(KEY_Q);await frames(3)
	checks.menu_release_no_throw=helper.launched==1
	button(false);await frames(2)
	checks.menu_duplicate_release_no_throw=helper.launched==1
	# F5 is the actual player reset path, replacing the old helper instance.
	button(true);await frames(4)
	var old_id:int=helper.get_instance_id()
	key(KEY_F5)
	for i in 600:
		await frames(1)
		if is_instance_valid(current_scene) and current_scene!=scene and current_scene.get("lab_ready")==true:break
	if is_instance_valid(current_scene) and current_scene!=scene:
		scene=current_scene;h=scene.lab;player=scene._player;helper=h._hatchet32
		checks.hero_reset_replaces_helper=helper.get_instance_id()!=old_id
		button(false);await frames(3)
		checks.hero_reset_no_stale_release=helper.launched==0 and not helper.release_armed35 and helper.count()==3
	else:checks.hero_reset_replaces_helper=false
	checks.final_solver_sample_exact=true
	for row:Dictionary in samples:checks.final_solver_sample_exact=checks.final_solver_sample_exact and float(row.sample_error)<.000001
	var max60:=0.;var max120:=0.;var repeated:=0;var stable:=true
	for i in samples.size():
		var row:Dictionary=samples[i]
		if int(row.fps_cap)==60:max60=maxf(max60,float(row.speed))
		else:max120=maxf(max120,float(row.speed))
		if i>0 and row.physics_frame==samples[i-1].physics_frame and row.fps_cap==samples[i-1].fps_cap:
			repeated+=1
			stable=stable and is_equal_approx(float(row.speed),float(samples[i-1].speed))
	checks.multiple_renders_per_physics_observed=repeated>=10
	checks.repeat_render_retains_velocity=stable
	checks.no_double_speed_at_120=max120<max60*1.25
	rows.append({"max60":max60,"max120":max120,"same_physics_render_pairs":repeated})
	finish()
