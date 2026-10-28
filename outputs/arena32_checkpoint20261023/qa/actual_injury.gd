extends SceneTree
var output := ""
var checks := {}
var rows: Array = []
var only := ""
var baseline_distance := 0.0

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): output=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--case="): only=arg.trim_prefix("--case=")
	run.call_deferred()

func action(name: String, down: bool) -> void:
	var event := InputEventAction.new()
	event.action=name;event.pressed=down;event.strength=1.0 if down else 0.0
	Input.parse_input_event(event);Input.flush_buffered_events()

func ticks(count: int) -> void:
	for i in count: await physics_frame
	await create_timer(0).timeout

func ready_scene() -> Node:
	change_scene_to_file("res://scenes/arena27.tscn")
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true: break
	if not is_instance_valid(current_scene) or not current_scene.lab_ready: return null
	var scene: Node=current_scene
	scene._player.global_position=Vector3(7,.05,7)
	scene._player.velocity=Vector3.ZERO
	scene._player.set_mouse_captured(true)
	await ticks(30)
	return scene

func sever(host: Node, part: String) -> bool:
	var rig: Skeleton3D=host._rig
	var bone := rig.find_bone(part)
	var child_name := part.replace("shin","foot").replace("forearm","hand")
	var child := rig.find_bone(child_name)
	var from: Vector3=rig.global_transform*rig.get_bone_global_pose(bone).origin
	var to: Vector3=rig.global_transform*rig.get_bone_global_pose(child).origin
	var at := from.lerp(to,.28)
	host._player_take_blade(120.0,at,(to-from).normalized(),true,part,8.0)
	return bool(host._player_severed.get(part,false)) and bool(host._player_mesh_cut_parts50.get(part,false))

func screenshot(scene: Node, tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var player: Node3D=scene._player
	var camera: Camera3D=scene.get_node_or_null("InjuryCamera32")
	if camera==null:
		camera=Camera3D.new();camera.name="InjuryCamera32";scene.add_child(camera)
	camera.global_position=player.global_position+Vector3(2.6,1.6,3.5)
	camera.look_at(player.global_position+Vector3.UP*.9)
	camera.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(tag+".png"))

func wall_probe(scene: Node, mode: String) -> void:
	var player: CharacterBody3D=scene._player
	await ticks(40)
	var wall := StaticBody3D.new()
	wall.collision_layer=1;wall.collision_mask=2
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new();box.size=Vector3(.2,3,5)
	collider.shape=box;wall.add_child(collider);scene.add_child(wall)
	var direction := 1.0 if mode.ends_with("l") else -1.0
	wall.global_position=player.position+Vector3(direction*1.2,1.5,0)
	var control := "preview_move_right" if direction>0 else "preview_move_left"
	action(control,true)
	var contact := false
	for i in 90:
		await ticks(1)
		for slide in player.get_slide_collision_count():
			if player.get_slide_collision(slide).get_collider()==wall: contact=true
	action(control,false)
	var upper: CollisionShape3D=player._injury32._upper
	var center: Vector3=upper.global_position
	var axis: Vector3=upper.global_basis.y.normalized()
	var extent: float=upper.shape.radius+absf(axis.x)*(upper.shape.height*.5-upper.shape.radius)
	var limit: float=wall.position.x-direction*.1
	var outer: float=center.x+direction*extent
	checks[mode+"_real_wall_contact"]=contact
	checks[mode+"_lean_collider_cannot_cross_wall"]=direction*(outer-limit)<.012
	rows.append({"case":mode,"wall":wall.position,"upper_center":center,"upper_axis":axis,"upper_extent":extent,"outer":outer,"limit":limit,"native_wall_contact":contact,"player_ground_y":player.position.y})
	await screenshot(scene,mode+"_wall")
	wall.queue_free();await ticks(4)

func reset_probe(scene: Node) -> void:
	var old_id: int=scene.get_instance_id()
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.keycode=KEY_F5;key.physical_keycode=KEY_F5;key.pressed=pressed
		Input.parse_input_event(key);Input.flush_buffered_events()
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id and current_scene.get("lab_ready")==true: break
	var fresh: bool=is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id and bool(current_scene.get("lab_ready"))
	checks["actual_F5_reset"]=fresh
	if fresh:
		await ticks(5)
		checks["reset_restores_limbs_and_original_collider"]=current_scene.lab._player_severed.is_empty() and not current_scene._player._injury32._split and is_equal_approx(current_scene._player.get_node("PlayerCapsule").shape.height,current_scene._player.model_target_height)

func run() -> void:
	root.size=Vector2i(1280,720)
	for mode in ["intact","shin_l","shin_r","both_legs","forearm_l","forearm_r"]:
		if only!="" and mode!=only: continue
		var scene: Node=await ready_scene()
		checks[mode+"_ready"]=scene!=null
		if scene==null: continue
		var player: CharacterBody3D=scene._player
		var host: Node=scene.lab
		if mode!="intact":
			checks[mode+"_actual_sever"]=sever(host,"shin_l" if mode=="both_legs" else mode)
			if mode=="both_legs": checks[mode+"_actual_second_sever"]=sever(host,"shin_r")
		await ticks(8)
		var start: Vector3=player.global_position
		var y_min := start.y
		var y_max := start.y
		var vertical_max := 0.0
		var airborne := 0
		var peak_speed := 0.0
		var trajectory: Array=[]
		action("preview_move_forward",true)
		for frame in 120:
			await ticks(1)
			y_min=minf(y_min,player.position.y);y_max=maxf(y_max,player.position.y)
			vertical_max=maxf(vertical_max,player.velocity.y)
			peak_speed=maxf(peak_speed,Vector2(player.velocity.x,player.velocity.z).length())
			if not player.is_on_floor(): airborne+=1
			if frame%10==0: trajectory.append({"frame":frame,"position":player.position,"velocity":player.velocity,"grounded":player.is_on_floor(),"injury":player._injury32.snapshot()})
			if frame in [18,32,70]: await screenshot(scene,mode+"_"+str(frame))
		action("preview_move_forward",false)
		var distance: float=Vector2(player.position.x-start.x,player.position.z-start.z).length()
		if mode=="intact":
			baseline_distance=distance
			checks["intact_no_injury_hops"]=player._injury32.hop_count==0 and y_max-y_min<.025
			checks["intact_original_capsule"]=is_equal_approx(player.get_node("PlayerCapsule").shape.height,player.model_target_height) and not player._injury32._split
		elif mode.begins_with("shin"):
			checks[mode+"_slow"]=peak_speed<=player.walk_speed*.245 and distance>.35
			checks[mode+"_actual_gravity_hops"]=airborne>=25 and y_max-y_min>.06 and y_max-y_min<.4 and player._injury32.hop_count>=3
		elif mode=="both_legs":
			checks["both_legs_no_walk"]=distance<.015 and player._injury32.hop_count==0
		else:
			checks[mode+"_speed_reduced"]=peak_speed<=player.walk_speed*.89 and peak_speed>player.walk_speed*.70
			checks[mode+"_physical_torso_shape"]=player._injury32._split and player._injury32.last.get("support_overlap",-1)>.1
			var rig: Skeleton3D=host._rig
			var chest: int=rig.find_bone("head")
			var pelvis: int=rig.find_bone("spine_01")
			var vector: Vector3=rig.get_bone_global_pose(chest).origin-rig.get_bone_global_pose(pelvis).origin
			checks[mode+"_torso_leans"]=absf(vector.x)>.12 and signf(vector.x)==(-1.0 if mode.ends_with("l") else 1.0)
			checks[mode+"_no_capsule_levitation"]=y_max-y_min<.025 and absf(player.position.y-start.y)<.01
			var bone_diagnostic := {}
			for bone in rig.get_bone_count(): bone_diagnostic[String(rig.get_bone_name(bone))]={"current":rig.get_bone_global_pose(bone),"rest":player._injury32._rest[bone]}
			rows.append({"case":mode,"bones":bone_diagnostic,"helper_bones":player._injury32._bones})
		await ticks(60)
		var before_jumps: int=player._injury32.jump_count
		action("preview_jump",true)
		await ticks(1)
		action("preview_jump",false)
		await ticks(4)
		var first_velocity := player.velocity.y
		if mode.begins_with("shin"):
			checks[mode+"_space_hop"]=player._injury32.jump_count==before_jumps+1 and first_velocity>1.5
			action("preview_jump",true);await ticks(1);action("preview_jump",false)
			checks[mode+"_no_air_double_jump"]=player._injury32.jump_count==before_jumps+1
		if mode=="both_legs": checks["both_legs_no_jump"]=player._injury32.jump_count==0 and player.velocity.y<.1
		rows.append({"case":mode,"distance":distance,"peak_speed":peak_speed,"y_span":y_max-y_min,"airborne_frames":airborne,"vertical_max":vertical_max,"trajectory":trajectory,"injury":player._injury32.snapshot(),"mesh_cut_parts":host._player_mesh_cut_parts50.duplicate(),"alive":not bool(scene.get("preview_dead"))})
		checks[mode+"_alive_preserved"]=not bool(scene.get("preview_dead"))
		if mode.begins_with("forearm"): await wall_probe(scene,mode)
		if mode=="forearm_r": await reset_probe(scene)
		for input in ["preview_move_forward","preview_jump"]: action(input,false)
		var old: Node=current_scene;current_scene=null;old.queue_free();await ticks(8)
	var failures: Array=[]
	for key in checks:
		if not checks[key]: failures.append(key)
	FileAccess.open(output.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"scope":"Real accepted blade sever API, then native movement and jump input; not a natural enemy swing fixture."},"\t"))
	quit(0 if failures.is_empty() else 1)
