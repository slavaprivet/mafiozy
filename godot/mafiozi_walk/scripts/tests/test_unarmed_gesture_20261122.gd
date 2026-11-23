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

func motion(host: Node, x: float) -> void:
	var event:=InputEventMouseMotion.new()
	event.relative=Vector2(x,0)
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
	check(is_instance_valid(host) and player._melee_practice==host,"castle unarmed host")
	if not is_instance_valid(host): finish(); return
	player.set_mouse_captured(true)
	for i in 4: await physics_frame
	check(host._allowed(),"unarmed control allowed")
	check(host.contact_checks==0,"idle fists make no geometry queries")
	button(host,MOUSE_BUTTON_LEFT,true)
	motion(host,5)
	check(int(host._source.snapshot().attackSeq)==0,"jitter does not punch")
	motion(host,-35)
	check(int(host._source.snapshot().attackSeq)==1 and int(host._state.action.side)==-1,"left punch follows held LMB")
	check(str(host._source.snapshot().animation.get("type"))=="punch" and str(host._source.snapshot().animation.get("hand"))=="left","left gesture cannot roll a kick")
	button(host,MOUSE_BUTTON_LEFT,false)
	for i in 35: await physics_frame
	button(host,MOUSE_BUTTON_RIGHT,true)
	motion(host,32)
	check(int(host._source.snapshot().attackSeq)==2 and int(host._state.action.side)==1,"right punch follows held RMB")
	check(str(host._source.snapshot().animation.get("hand"))=="right","right hand matches contact source")
	button(host,MOUSE_BUTTON_LEFT,true)
	for i in 35: await physics_frame
	motion(host,-34)
	check(int(host._source.snapshot().attackSeq)==3 and int(host._state.action.side)==-1,"both held left gesture")
	for i in 35: await physics_frame
	motion(host,34)
	check(int(host._source.snapshot().attackSeq)==4 and int(host._state.action.side)==1,"both held right gesture")
	for i in 30: await physics_frame
	var rig: Skeleton3D=player._pose_skeleton
	var left_guard: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("hand_l")).origin
	var right_guard: Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("hand_r")).origin
	check(left_guard.y>0.72 and right_guard.y>0.72,"both fists raised in guard")
	button(host,MOUSE_BUTTON_LEFT,false);button(host,MOUSE_BUTTON_RIGHT,false)
	host.cancel("test")
	check(not host._left_held and not host._right_held and host._gesture_x==0.0,"release resets stance")
	var sword: Node=main.preview_sword_prototype
	sword.set_selected(true)
	sword.set_shield_only31(true)
	check(bool(sword.get("_unarmed")) and sword._active(),"active castle sword host is unarmed")
	var routed:=InputEventMouseButton.new()
	routed.button_index=MOUSE_BUTTON_LEFT; routed.pressed=true
	sword._input(routed); player._unhandled_input(routed)
	check(host._left_held and not bool(sword.get("_hold_left")),"unarmed click reaches fist host past sword")
	routed.pressed=false; sword._input(routed); player._unhandled_input(routed)
	host.cancel("routed_test")
	await create_timer(.4).timeout
	var npc: CharacterBody3D=sword.get("_npc_body")
	if is_instance_valid(npc):
		player.global_position=npc.global_position+Vector3(0,0,-0.8)
		player._heading=-PI
		player._visual.rotation.y=0.0
		for i in 5: await physics_frame
		var hp_before: float=float(sword.get("_npc_hp"))
		var bleed_before: int=int(sword.get("_npc_bleed_until_ms"))
		button(host,MOUSE_BUTTON_LEFT,true)
		motion(host,-38)
		for i in 22: await physics_frame
		check(host.confirmed_hits==1 and float(sword.get("_npc_hp"))<hp_before,"left fist damages castle knight once")
		check(int(sword.get("_npc_bleed_until_ms"))==bleed_before and sword.get("_npc_severed").is_empty(),"blunt fist does not bleed or sever")
		button(host,MOUSE_BUTTON_LEFT,false)
		await create_timer(.4).timeout
		sword.set_physics_process(false)
		player.global_position=npc.global_position+Vector3(0,0,-0.72)
		player._heading=-PI; player._visual.rotation.y=0.0
		for i in 5: await physics_frame
		var hp_after_left: float=float(sword.get("_npc_hp"))
		button(host,MOUSE_BUTTON_RIGHT,true)
		motion(host,38)
		for i in 22: await physics_frame
		check(host.confirmed_hits==2 and float(sword.get("_npc_hp"))<hp_after_left,"right fist damages castle knight once")
		button(host,MOUSE_BUTTON_RIGHT,false)
	finish()

func finish() -> void:
	print("UNARMED_GESTURE_20261122 ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
