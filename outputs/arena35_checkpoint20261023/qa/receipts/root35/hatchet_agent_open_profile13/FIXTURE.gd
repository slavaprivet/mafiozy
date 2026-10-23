extends "D:/MafioziCombat31/c33_coordination/agents/hatchet35qa/lifecycle35.gd"
func run():
	root.size=Vector2i(1280,720);root.set_flag(Window.FLAG_NO_FOCUS,true);seed(35023)
	await setup()
	var wall_z:=-7.05
	var open:=OS.get_cmdline_user_args().has("--open-flight")
	if not open:scene._lab_box(Vector3(-.2,1.5,wall_z),Vector3(3.,3.,.004),Color("b94936"),true)
	await frames(5)
	button(true);await frames(12)
	for i in 16:motion(Vector2(0,24));await frames(1)
	await frames(12)
	for i in 8:motion(Vector2(0,-32));await frames(1)
	var model:Node3D=h._sword
	var release:Transform3D=model.global_transform
	button(false)
	var item:Dictionary=helper.pool[0]
	checks.native_rotating_release=helper.launched==1 and Vector3(item.get("angular_velocity35",Vector3.ZERO)).length()>.5
	checks.exact_displayed_release_pose=model.global_transform==release
	var passed_wall:=false;var rotations:=0.;var previous:Basis=model.global_basis
	for i in 120:
		await physics_frame;await create_timer(0).timeout
		var minz:=INF
		for child:Node in model.find_children("*","MeshInstance3D",true,false):
			for v:Vector3 in child.mesh.get_faces():minz=minf(minz,(child.global_transform*v).z)
		passed_wall=passed_wall or minz<wall_z-.003
		rotations+=previous.get_rotation_quaternion().angle_to(model.global_basis.get_rotation_quaternion())
		previous=model.global_basis
		rows.append({"tick":i,"age":item.age,"state":item.state,"min_z":minz,"position":model.global_position,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,"frame_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"ray_max_usec":item.get("ray_usec",-1),"flight_peak_usec35":item.get("flight_peak_usec35",-1),"flight_last_usec35":item.get("flight_last_usec35",-1)})
		if item.state!="flying":break
	checks.rotated_in_real_flight=rotations>.02
	checks.world_collision_stopped=item.state=="ground" and helper.events[-1].event=="bounce" and not bool(helper.events[-1].actual_skin)
	if not open:checks.thin_4mm_wall_no_tunnel=not passed_wall
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/wall.png")
	finish()
