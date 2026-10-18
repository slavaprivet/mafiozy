extends SceneTree
var game: Node3D
var host: Node
var player: CharacterBody3D
var errors: Array[String] = []
var rows: Array = []
var out := ""
var visual := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out=arg.trim_prefix("--qa-out=")
		if arg=="--visual":visual=true
	run.call_deferred()
func frames(n:int) -> void:
	for i in n: await physics_frame
func mouse(down:bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e)
func motion(dx:float,dy:float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);Input.parse_input_event(e)
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while not game.preview_ready:await process_frame
	await frames(120);game._castle_spawn_frames=0;player=game._player
	var storage:Node=game.preview_castle.armory_storage
	storage.acquire_or_select("sword");host=game.preview_sword_prototype
	while not is_instance_valid(host._npc_body):await frames(1)
	var npc:CharacterBody3D=host._npc_body
	npc.global_position=Vector3(15,.1,1000);player.global_position=Vector3(15,.1,1002.2);player.velocity=Vector3.ZERO;npc.velocity=Vector3.ZERO
	player._camera_yaw=0;player._camera_pitch=-.1;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	var equipment:Node=game.get_node("CastleArmorEquipment")
	for slot in ["head","torso","hands","legs","feet"]:equipment.equip_ground("heavy_"+slot)
	host._npc_engaged=true;host._npc_state="approach";host._npc_timer=0
	host.set_npc_armor31({"head":"heavy_head","torso":"heavy_torso","hands":"heavy_hands","legs":"heavy_legs","feet":"heavy_feet"})
	var start:Vector3=npc.global_position
	var player_start:Vector3=player.global_position
	var player_motion:=0.0
	var clashes:=0
	var previous_clash:int=host._last_clash_ms
	var guards:=0
	var old_state:=""
	var lateral:=0.0
	var reaction_ok:=true
	for tick in 1200:
		for a in ["preview_move_left","preview_move_right","preview_move_forward","preview_move_back"]:Input.action_release(a)
		var phase:=tick%240
		if phase<35:Input.action_press("preview_move_right")
		elif phase<70:Input.action_press("preview_move_left")
		elif phase<95:Input.action_press("preview_move_back")
		elif phase<120:Input.action_press("preview_move_forward")
		if tick%180==0:mouse(true)
		if tick%180<45:motion(14.0 if tick%180<15 or tick%180>=30 else -28.0,0)
		if tick%180==46:mouse(false)
		await frames(1)
		lateral=maxf(lateral,absf(npc.global_position.x-start.x))
		player_motion=maxf(player_motion,player.global_position.distance_to(player_start))
		if host._last_clash_ms!=previous_clash:clashes+=1;previous_clash=host._last_clash_ms
		if host._npc_state=="guard" and old_state!="guard":guards+=1
		old_state=host._npc_state
		if tick%10==0:rows.append({"tick":tick,"state":host._npc_state,"gap":npc.global_position.distance_to(player.global_position),"guard":host._npc_guard_entries,"clashes":clashes,"npc_hp":host._npc_hp,"player_hp":host._sparring_hp})
		if game.preview_dead or host._npc_dead:break
	mouse(false)
	for a in ["preview_move_left","preview_move_right","preview_move_forward","preview_move_back"]:Input.action_release(a)
	if player_motion<.5:errors.append("player_did_not_move")
	if host._npc_swings<1:errors.append("no_attack")
	var report:Dictionary={"passed":errors.is_empty(),"errors":errors,"rows":rows,"lateral":lateral,"player_motion":player_motion,"guards":guards,"clashes":clashes,"swings":host._npc_swings,"hits":host._npc_hits,"player_hp":host._sparring_hp,"npc_hp":host._npc_hp,"player_dead":game.preview_dead,"npc_dead":host._npc_dead,"scope":"Same heavy armor both actors, same movement/real mouse attack sequence. Initial positions only, no teleport after start, no HP or damage changes. Physical clashes counted from actual register_clash timestamps."}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if errors.is_empty() else 1)
