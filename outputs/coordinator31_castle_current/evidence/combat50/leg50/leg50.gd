extends SceneTree
var game: Node3D
var player: CharacterBody3D
var sword: Node
var errors: Array[String]=[]
var rows: Array=[]
var output_path := "D:/MafioziCombat31/leg50/RESULT.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): output_path=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: int,down: bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
func ready_game() -> void:
	while not is_instance_valid(current_scene):await process_frame
	game=current_scene
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0;player=game._player
	game.preview_castle.armory_storage.acquire_or_select("sword")
	await frames(90);sword=game.preview_sword_prototype
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO
	player._camera_yaw=0;player._camera_pitch=-0.1;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(60)
func damage(part: String,sever: bool) -> void:
	var bone: int=sword._rig.find_bone(part)
	var at: Vector3=sword._rig.global_transform*sword._rig.get_bone_global_pose(bone).origin
	sword._player_take_blade(120.0,at,Vector3.RIGHT,sever,part,3.0)
func walk_case(label: String,expected: float) -> float:
	key(KEY_W,true);await frames(45)
	var start: Vector3=player.global_position
	var sum_speed:=0.0
	for i in 60:
		await frames(1);sum_speed+=Vector2(player.velocity.x,player.velocity.z).length()
	var speed:=sum_speed/60.0
	key(KEY_W,false);await frames(30)
	var before: Vector3=player.global_position
	key(KEY_SPACE,true);await frames(1);key(KEY_SPACE,false)
	var started: bool=not player._jump.is_empty()
	if expected<1.0 and started:errors.append(label+"_jump_allowed")
	if expected>=1.0:await frames(120)
	var row={"case":label,"scale":sword.player_leg_speed_scale50(),"expected":expected,"speed":speed,"distance":Vector2(player.global_position.x-start.x,player.global_position.z-start.z).length(),"jump_started":started,"severed":sword._player_severed.duplicate(),"hp":sword._player_part_hp.duplicate()}
	if absf(row.scale-expected)>0.00001:errors.append(label+"_scale")
	rows.append(row);return speed
func run() -> void:
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	await ready_game()
	var healthy: float=await walk_case("healthy",1.0)
	damage("foot_l",false)
	var hp_only: float=await walk_case("hp_zero_not_severed",1.0)
	if absf(hp_only/healthy-1.0)>0.03:errors.append("hp_only_speed")
	damage("foot_l",true)
	var one: float=await walk_case("left_foot_severed",0.24)
	if absf(one/healthy-0.24)>0.03:errors.append("one_leg_speed")
	damage("shin_r",true)
	var both: float=await walk_case("both_supports_severed",0.0)
	if both>0.001:errors.append("both_legs_move")
	# Same native scene reload used by the R restart path creates a new limb owner.
	var old_id: int=sword.get_instance_id()
	reload_current_scene();await process_frame
	await ready_game()
	var reset_speed: float=await walk_case("scene_restart",1.0)
	if sword.get_instance_id()==old_id or not sword._player_severed.is_empty() or absf(reset_speed/healthy-1.0)>0.03:errors.append("restart_state_leaked")
	key(KEY_SPACE,true);await frames(1);key(KEY_SPACE,false);await frames(3)
	key(KEY_SPACE,true);await frames(1);key(KEY_SPACE,false);await frames(10)
	var dive_started: bool=not player._jump.is_empty() and str(player._jump.get("mode"))=="dive" and not player.is_on_floor()
	var injury_at: Vector3=player.global_position
	var velocity_before: Vector3=player.velocity
	damage("thigh_l",true);damage("foot_r",true)
	var position_unchanged: bool=player.global_position==injury_at
	var samples: Array=[]
	var max_step:=0.0;var last: Vector3=player.global_position;var fall_seen:=false;var done:=false;var min_y:=injury_at.y
	for i in 180:
		await frames(1)
		max_step=maxf(max_step,player.global_position.distance_to(last));last=player.global_position
		min_y=minf(min_y,player.global_position.y);fall_seen=fall_seen or player._source_falling
		if i%10==0:samples.append({"tick":i,"position":player.global_position,"velocity":player.velocity,"jump_empty":player._jump.is_empty(),"falling":player._source_falling,"floor":player.is_on_floor()})
		if player.is_on_floor() and player._jump.is_empty() and not player._source_falling:done=true
	var flight={"case":"dive_midair_both_legs_severed","dive_started":dive_started,"damage_did_not_teleport":position_unchanged,"velocity_before":velocity_before,"fall_seen":fall_seen,"landed":done,"max_frame_step":max_step,"height_drop":injury_at.y-min_y,"samples":samples}
	if not dive_started or not position_unchanged or not fall_seen or not done or max_step>0.7 or injury_at.y-min_y<0.1:errors.append("midair_fall")
	rows.append(flight)
	var result={"passed":errors.is_empty(),"errors":errors,"rows":rows,"scope":"Native W/space/double-space movement. Limb damage calls real shared damage/sever entry directly with exact part (no collision-delivery claim). Restart uses native reload_current_scene. Tests motion/support parity, not visual limp quality or whole-game acceptance."}
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)


