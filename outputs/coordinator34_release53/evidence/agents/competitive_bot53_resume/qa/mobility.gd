extends SceneTree
var out := ""
var errors: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	var game: Node3D=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while not game.preview_ready:await process_frame
	await frames(120);game._castle_spawn_frames=0
	var player:CharacterBody3D=game._player
	game.preview_castle.armory_storage.acquire_or_select("sword")
	var host:Node=game.preview_sword_prototype
	while not is_instance_valid(host._npc_body):await frames(1)
	player.global_position=Vector3(15,.1,1002.2);player.velocity=Vector3.ZERO
	host._npc_body.global_position=Vector3(15,.1,900);host._npc_body.velocity=Vector3.ZERO
	player._camera_yaw=0;player._camera_pitch=-.1;player._heading=0;player._update_camera_rotation();player.set_mouse_captured(true)
	var rows:Array=[]
	for gear in [{},{"head":"heavy_head","torso":"heavy_torso","hands":"heavy_hands","legs":"heavy_legs","feet":"heavy_feet"},{}]:
		host.set_npc_armor31(gear);await frames(30)
		var factor:float=host.player_leg_speed_scale50()
		if not is_equal_approx(factor,1.0):errors.append("player_factor_depends_on_npc_gear")
		var start:Vector3=player.global_position
		Input.action_press("preview_move_right");await frames(60);Input.action_release("preview_move_right")
		var moved:Vector3=player.global_position-start;moved.y=0
		rows.append({"npc_gear":gear,"player_leg_factor":factor,"player_motion":moved.length(),"npc_factor":host._npc_speed_scale()})
	if absf(float(rows[0].player_motion)-float(rows[1].player_motion))>.08:errors.append("player_speed_changed_with_npc_armor")
	if float(rows[1].npc_factor)>=float(rows[0].npc_factor):errors.append("npc_armor_did_not_slow_npc")
	var report:Dictionary={"passed":errors.is_empty(),"errors":errors,"rows":rows,"scope":"Player bare throughout, ordinary movement input; only NPC gear changed between trials. Initial placement once, no damage or movement injection."}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if errors.is_empty() else 1)
