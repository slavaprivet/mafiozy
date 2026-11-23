extends SceneTree

var failures: Array[String]=[]
var checks:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func button(host: Node, index: MouseButton, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=index; event.pressed=pressed
	host.input_event(event)

func motion(host: Node, x: float, y: float=0.0) -> void:
	var event:=InputEventMouseMotion.new()
	event.relative=Vector2(x,y)
	host.input_event(event)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	main.castle_map=true
	root.add_child(main); current_scene=main
	for i in 120:
		if main.preview_ready: break
		await process_frame
	check(main.preview_ready,"castle loaded")
	var player: CharacterBody3D=main._player
	var host: Node=main.preview_melee
	check(is_instance_valid(host) and player._melee_practice==host and host.free_mode(),"free fist host")
	if not is_instance_valid(host): finish(); return
	player.set_mouse_captured(true)
	for i in 4: await physics_frame
	check(host._allowed(),"unarmed control allowed")
	check(not player._weapon_host.armed(),"spawn starts with empty hands")
	check(host.contact_checks==0,"idle has no contact queries")
	button(host,MOUSE_BUTTON_LEFT,true)
	motion(host,-55,-25)
	for i in 3: await physics_frame
	var first: Vector2=host._free_hand.left
	check(first.x<-.05 and first.y>.02,"left fist follows both mouse axes")
	check(int(host._source.snapshot().attackSeq)==0,"mouse movement does not start timed attack")
	check(host.steering(),"held fist owns mouse steering")
	var rig: Skeleton3D=player._pose_skeleton
	var left_bone:=rig.find_bone("socket_hand_r")
	var right_bone:=rig.find_bone("socket_hand_l")
	check(left_bone>=0 and right_bone>=0,"mirrored rig hand mapping")
	var left_before: Vector3=rig.get_bone_global_pose(left_bone).origin
	for i in 14: await physics_frame
	var left_settled: Vector3=rig.get_bone_global_pose(left_bone).origin
	for i in 30: await physics_frame
	var left_held: Vector3=rig.get_bone_global_pose(left_bone).origin
	check(left_held.distance_to(left_settled)<.06 and (host._free_hand.left as Vector2).distance_to(first)<.01,"held fist keeps its position without mouse events")
	motion(host,80,50)
	for i in 4: await physics_frame
	var left_after: Vector3=rig.get_bone_global_pose(left_bone).origin
	check(left_after.distance_to(left_held)>.08,"left hand follows broad reverse mouse movement")
	motion(host,0,-120)
	for i in 14: await physics_frame
	var left_raised: Vector3=rig.get_bone_global_pose(left_bone).origin
	check(left_raised.y>left_after.y+.10,"vertical mouse movement raises held hand")
	check(not host._free_pose_stamp.is_empty(),"free pose reaches final skin writer")
	button(host,MOUSE_BUTTON_RIGHT,true)
	motion(host,55,-25)
	for i in 3: await physics_frame
	check(host._free_hand.right.x>.05 and host._free_hand.right.y>.02,"right fist follows both mouse axes")
	check(host._free_side=="right","right gesture selects right hand when both held")
	check(rig.get_bone_global_pose(right_bone).origin.is_finite(),"right hand pose valid")
	button(host,MOUSE_BUTTON_LEFT,false); button(host,MOUSE_BUTTON_RIGHT,false)
	for i in 4: await physics_frame
	check(not host.steering(),"release restores camera steering")
	check(host.confirmed_hits==0,"no remote hit from standing still")
	await create_timer(.4).timeout
	var sword: Node=main.preview_sword_prototype
	var npc: CharacterBody3D=sword.get("_npc_body")
	if is_instance_valid(npc):
		sword.set_physics_process(false)
		main._castle_spawn_frames=0
		player.global_position=npc.global_position+Vector3(0,0,-0.8)
		player._heading=-PI
		player._visual.rotation.y=0.0
		for i in 5: await physics_frame
		var hp_before: float=float(sword.get("_npc_hp"))
		button(host,MOUSE_BUTTON_LEFT,true)
		for i in 8:
			motion(host,-30,-5)
			await physics_frame
		check(host.confirmed_hits>0 and float(sword.get("_npc_hp"))<hp_before,"moving fist damages knight")
		var hits_after: int=host.confirmed_hits
		var hp_after: float=float(sword.get("_npc_hp"))
		for i in 12: await physics_frame
		check(host.confirmed_hits==hits_after and is_equal_approx(float(sword.get("_npc_hp")),hp_after),"held still fist does not hit again")
		check(int(sword.get("_npc_bleed_until_ms"))==0 and sword.get("_npc_severed").is_empty(),"fist does not bleed or sever")
		button(host,MOUSE_BUTTON_LEFT,false)
		await create_timer(.4).timeout
		player.global_position=npc.global_position+Vector3(0,0,-0.8)
		player._heading=-PI; player._visual.rotation.y=0.0
		for i in 5: await physics_frame
		var right_hp_before: float=float(sword.get("_npc_hp"))
		button(host,MOUSE_BUTTON_RIGHT,true)
		for i in 8:
			motion(host,30,-5)
			await physics_frame
		check(host.confirmed_hits>hits_after and float(sword.get("_npc_hp"))<right_hp_before,"moving right fist damages knight")
		button(host,MOUSE_BUTTON_RIGHT,false)
	sword.set_selected(false)
	var routed_button:=InputEventMouseButton.new()
	routed_button.button_index=MOUSE_BUTTON_LEFT; routed_button.pressed=true
	sword._input(routed_button); player._unhandled_input(routed_button)
	check(host._left_held and not bool(sword.get("_hold_left")),"window click reaches fist controller")
	var command_before: Vector2=host._free_command.left
	var routed_motion:=InputEventMouseMotion.new()
	routed_motion.relative=Vector2(-55,25)
	sword._input(routed_motion); player._unhandled_input(routed_motion)
	check((host._free_command.left as Vector2).distance_to(command_before)>.1,"window mouse motion controls held fist")
	for i in 20: await physics_frame
	var held_heading: float=player._heading
	Input.action_press(&"preview_move_left")
	for i in 8: await physics_frame
	Input.action_release(&"preview_move_left")
	check(absf(angle_difference(held_heading,player._heading))<.01,"walking does not steal fist steering")
	routed_button.pressed=false
	sword._input(routed_button); player._unhandled_input(routed_button)
	for side in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		host.cancel("cross_body_test")
		var across := 1 if side==MOUSE_BUTTON_LEFT else -1
		button(host,side,true)
		motion(host,across*500)
		for i in 24: await physics_frame
		var forward: Vector3=-player._camera.global_basis.z
		var yaw_error:=angle_difference(atan2(forward.x,forward.z),float(player._visual.global_rotation.y))
		check(yaw_error*across<-.3,"body turns toward horizontal sweep")
		var hand_index:=left_bone if across==1 else right_bone
		var socket: Vector3=host._pose._actor*rig.get_bone_global_pose(hand_index).origin
		var chest: Vector3=host._pose._actor*rig.get_bone_global_pose(rig.find_bone("chest")).origin
		check(socket.z-chest.z>.48,"crossing fist clears front of chest")
		button(host,side,false)
	finish()

func finish() -> void:
	print("UNARMED_FREE_20261123 ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
