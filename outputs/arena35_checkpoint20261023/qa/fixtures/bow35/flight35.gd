extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
var scene:Node
var player:CharacterBody3D
var bow:Node
var camera:Camera3D
var requested:Array=[8.,16.,28.,40.]
var initial:Vector3
var initial_v:Vector3
var max_ballistic_error:=0.
var flight_us:Array=[]
func _initialize():
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func ticks(n:int):
	for i in n:await physics_frame;await create_timer(0).timeout
func mouse(button:int,down:bool):
	var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=down
	Input.parse_input_event(e);Input.flush_buffered_events()
func measure(node:Node3D)->Dictionary:
	var low:=Vector2(INF,INF);var high:=-low
	for child:Node in node.get_children():
		if not child is MeshInstance3D:continue
		for vertex:Vector3 in child.mesh.get_faces():
			var p:=camera.unproject_position(child.global_transform*vertex)
			low=low.min(p);high=high.max(p)
	var origin:=node.global_position
	var shaft:float=camera.unproject_position(origin+camera.global_basis.x*.006).distance_to(camera.unproject_position(origin-camera.global_basis.x*.006))
	var scale_xy:float=node.get_child(0).scale.x
	return {"distance_m":camera.global_position.distance_to(origin),"depth_m":-camera.to_local(origin).z,"screen_min":low,"screen_max":high,"screen_size":high-low,"shaft_base_px":shaft,"shaft_visual_px":shaft*scale_xy,"scale_xy":scale_xy,"root_scale":node.scale,"position":[origin.x,origin.y,origin.z],"fov":camera.fov}
func run():
	root.size=Vector2i(1280,720)
	change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	scene=current_scene;checks["startup"]=is_instance_valid(scene) and scene.get("lab_ready")==true
	if not checks.startup:finish();return
	player=scene.get("_player");bow=scene.get("preview_bow_prototype");camera=player.get_preview_camera()
	player.global_position=Vector3(3,.05,2.5);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=.25;player._update_camera_rotation();player.set_mouse_captured(true)
	var arsenal:Node=scene.get("preview_weapons")
	arsenal.equip("bow")
	await ticks(20)
	checks["bow_selected"]=bow._selected and not bow._grounded
	var shots_before:int=bow._shots
	mouse(MOUSE_BUTTON_RIGHT,true)
	for i in 180:
		await ticks(1)
		if bow.ready_to_fire() and bow._draw_amount>=.999:break
	checks["fully_drawn"]=bow.ready_to_fire() and bow._draw_amount>=.999
	initial=bow._nocked_arrow.global_position;initial_v=bow._nocked_arrow.global_basis.z.normalized()*bow.launch_speed(bow._draw_amount)
	mouse(MOUSE_BUTTON_LEFT,true)
	await ticks(1)
	mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
	# Look slightly aside after release with real mouse input: this exposes the
	# projectile instead of letting the back of the hero's head occlude the view.
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(80,0);motion.screen_relative=motion.relative
	Input.parse_input_event(motion);Input.flush_buffered_events()
	checks["real_input_single_shot"]=bow._shots==shots_before+1
	for tick in 135:
		await ticks(1)
		var item:Dictionary=bow._arrows[bow.last_fired_index()]
		var node:Node3D=item.node
		if item.stuck:break
		var age:float=item.age
		var expected:Vector3=initial+initial_v*age+Vector3.DOWN*bow.GRAVITY*.5*age*age
		max_ballistic_error=maxf(max_ballistic_error,node.global_position.distance_to(expected))
		if not requested.is_empty() and camera.global_position.distance_to(node.global_position)>=float(requested[0]):
			var label:float=requested.pop_front()
			await RenderingServer.frame_post_draw
			var sample:=measure(node);sample["requested_m"]=label;sample["age"]=age;sample["velocity"]=item.velocity;sample["physics_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.;sample["process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000.
			rows.append(sample)
			root.get_texture().get_image().save_png(out+"/flight_%02d.png"%label)
		if requested.is_empty():break
	checks["all_distance_frames"]=requested.is_empty()
	checks["actual_ballistic_error_under_mm"]=max_ballistic_error<.001
	checks["root_remains_unscaled"]=true
	for row:Dictionary in rows:checks["root_remains_unscaled"]=checks.root_remains_unscaled and Vector3(row.root_scale).is_equal_approx(Vector3.ONE)
	finish()
func finish():
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows,"max_ballistic_error_m":max_ballistic_error,"note":"Graphical native InputEvents; concurrent user game means not exclusive FPS acceptance."},"  "))
	var old:Node=current_scene;current_scene=null
	if is_instance_valid(old):old.queue_free()
	await ticks(4);quit(0 if not checks.values().has(false) else 1)
