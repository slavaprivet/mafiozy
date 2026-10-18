extends SceneTree
var mode := "free"
var output_dir := "D:/MafioziCombat31/resume51_opponent"
var report := {"scope":"Native castle opponent, one initial scenario placement and engaged flag only; no damage injection, no movement teleport during observation", "transitions":[], "impacts":[]}
var errors: Array[String] = []
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--case="): mode=a.trim_prefix("--case=")
		if a.begins_with("--qa-out="): output_dir=a.trim_prefix("--qa-out=")
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	await create_timer(1.2).timeout
	var game: Node3D=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true: await process_frame
	await frames(35)
	game._castle_spawn_frames=0
	var player: CharacterBody3D=game._player
	var storage: Node=game.preview_castle.armory_storage
	player.global_position=game.preview_castle.to_global(storage._rack_points[0]);player.velocity=Vector3.ZERO
	storage.interact();await frames(15)
	var sword: Node=game.preview_sword_prototype
	var npc: CharacterBody3D=sword._npc_body
	for i in 300:
		if is_instance_valid(npc):break
		await frames(1)
		npc=sword._npc_body
	if not is_instance_valid(npc): errors.append("no_npc");finish();return
	npc.global_position=Vector3(15,.15,1000);npc.velocity=Vector3.ZERO
	var gap:=6.0 if mode!="retreat" else .82
	player.global_position=npc.global_position+Vector3(0,0,gap);player.velocity=Vector3.ZERO
	player._camera_yaw=0;player._camera_pitch=-.10;player._heading=0;player._visual.rotation.y=PI;player.set_mouse_captured(true)
	var start:Vector3=npc.global_position
	var wall:StaticBody3D=null
	if mode=="detour":
		wall=StaticBody3D.new();wall.collision_layer=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,3,.4);shape.shape=box;wall.add_child(shape);game.add_child(wall)
		wall.global_position=npc.global_position+Vector3(0,1.4,3)
	sword._npc_engaged=mode!="chase";sword._npc_state="approach";sword._npc_timer=0;sword._held=false
	var first_hits:int=sword._npc_hits;var initial_replans:int=sword._npc_replans50
	var samples=[];var max_x:=0.0;var illegal:=false;var first_swing_gap:=-1.0
	for tick in 1200:
		await frames(1)
		var distance:float=player.global_position.distance_to(npc.global_position)
		max_x=maxf(max_x,absf(npc.global_position.x-start.x))
		if tick%30==0:samples.append({"tick":tick,"npc":str(npc.global_position),"gap":distance,"state":sword._npc_state,"hp":sword._sparring_hp})
		if sword._npc_state=="windup" and first_swing_gap<0:first_swing_gap=distance
		if mode=="detour" and absf(npc.global_position.z-wall.global_position.z)<.2 and absf(npc.global_position.x-wall.global_position.x)<1.45:illegal=true
		if mode=="retreat" and tick>=60:break
		if sword._npc_hits>first_hits:break
	report["case"]=mode;report["samples"]=samples;report["max_lateral_m"]=max_x;report["wall_crossed"]=illegal;report["first_windup_gap"]=first_swing_gap
	report["hits"]=sword._npc_hits-first_hits;report["replans"]=sword._npc_replans50-initial_replans;report["final_gap"]=player.global_position.distance_to(npc.global_position);report["last_impact"]=sword._npc_last_impact31
	report["scope"]="Native castle actors: initial positions and detour obstacle only. Chase auto-aggro has no held input; detour/retreat seeds alert. Real move_and_slide, no subsequent actor teleport or damage injection."
	if mode=="retreat":
		if report.final_gap<1.02:errors.append("did_not_retreat")
	else:
		if report.hits<1:errors.append("no_chase_contact")
		if first_swing_gap>1.9:errors.append("attack_outside_reach")
	if illegal:errors.append("crossed_wall")
	if mode=="detour" and max_x<1.65:errors.append("no_clear_detour")
	finish()

func finish() -> void:
	report["errors"]=errors;report["passed"]=errors.is_empty()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if errors.is_empty() else 1)
