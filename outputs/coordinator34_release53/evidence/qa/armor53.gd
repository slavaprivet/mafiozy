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
	var loadout:Dictionary=host.npc_armor_snapshot31()
	for slot in ["head","torso","hands","legs","feet"]:
		if loadout.get(slot)!="heavy_"+slot:errors.append("missing_"+slot)
	if host._npc_body.find_child("PeasantTornOvershirt",true,false)!=null:errors.append("old_tunic_present")
	if host._npc_armor_visual31.get_script().resource_path!="res://scripts/combat/castle_armor_visual.gd":errors.append("not_shared_armor")
	npc.global_position=Vector3(15,.1,1000);player.global_position=Vector3(15,.1,1002.2);player.velocity=Vector3.ZERO;npc.velocity=Vector3.ZERO
	player._camera_yaw=0;player._camera_pitch=-.1;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	if visual:
		host.set_physics_process(false);host.set_process(false)
		player.global_position += Vector3(6,0,0)
		var visual_armor:Node=host._npc_armor_visual31
		var hair_before:Dictionary={}
		visual_armor.clear_piece("head")
		for mesh:MeshInstance3D in npc.find_children("*","MeshInstance3D",true,false):
			if str(mesh.name).begins_with("npc_hair") or str(mesh.name).begins_with("npc_combed_lock") or str(mesh.name).begins_with("npc_crew_top"):
				hair_before[mesh]=mesh.visible
		visual_armor.set_armor("head","heavy_head")
		for mesh:MeshInstance3D in hair_before:
			if mesh.visible:errors.append("hair_visible_in_helmet:"+str(mesh.name))
		visual_armor.clear_piece("head")
		for mesh:MeshInstance3D in hair_before:
			if mesh.visible!=hair_before[mesh]:errors.append("hair_not_restored:"+str(mesh.name))
		visual_armor.set_armor("head","heavy_head")
		var camera:=Camera3D.new();game.add_child(camera);camera.current=true
		for label in ["back","side","front"]:
			var offset:=Vector3(0,1.1,3.2) if label=="back" else (Vector3(3,1.1,0) if label=="side" else Vector3(0,1.1,-3.2))
			camera.global_position=npc.global_position+offset;camera.look_at(npc.global_position+Vector3.UP*.95)
			await frames(12);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join(label+".png"))
		FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors,"loadout":loadout,"visual":host._npc_armor_visual31.snapshot()},"\t"));quit(0 if errors.is_empty() else 1);return
	var equipment:Node=game.get_node("CastleArmorEquipment")
	for slot in ["head","torso","hands","legs","feet"]:equipment.equip_ground("heavy_"+slot)
	host._npc_engaged=true;host._npc_state="approach";host._npc_timer=0
	var start:Vector3=npc.global_position
	var lateral:=0.0
	var reaction_ok:=true
	for tick in 1100:
		if tick%180==0:mouse(true)
		if tick%180<45:motion(14.0 if tick%180<15 or tick%180>=30 else -28.0,0)
		if tick%180==46:mouse(false)
		await frames(1)
		lateral=maxf(lateral,absf(npc.global_position.x-start.x))
		if not host._npc_observed53.is_empty() and host.now_ms()-int(host._npc_observed53.at)<180:reaction_ok=false
		if tick%10==0:rows.append({"tick":tick,"state":host._npc_state,"gap":npc.global_position.distance_to(player.global_position),"guard":host._npc_guard_entries,"counter":host._npc_counters53,"threat":host._npc_threat53,"npc_hp":host._npc_hp,"player_hp":host._sparring_hp})
		if game.preview_dead or host._npc_dead:break
	mouse(false)
	if not reaction_ok:errors.append("reaction_under180ms")
	if host._npc_guard_entries<1:errors.append("no_guard")
	if host._npc_counters53<1:errors.append("no_counter")
	if host._npc_swings<1:errors.append("no_attack")
	if lateral<.25:errors.append("no_lateral_footwork")
	var report:Dictionary={"passed":errors.is_empty(),"errors":errors,"rows":rows,"loadout":loadout,"reaction180ms":reaction_ok,"lateral":lateral,"guards":host._npc_guard_entries,"counters":host._npc_counters53,"swings":host._npc_swings,"hits":host._npc_hits,"player_dead":game.preview_dead,"npc_dead":host._npc_dead,"scope":"Initial positions and rack equipment only. Real mouse strokes, autonomous opponent motion, default HP/damage/armor; no health or contact injection."}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if errors.is_empty() else 1)
