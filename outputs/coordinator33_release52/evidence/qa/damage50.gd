extends SceneTree
var game: Node3D
var player: CharacterBody3D
var sword: Node
var storage: Node
var errors: Array[String]=[]
var cases: Array=[]
var location := "field"
var weapons_to_test := ["sword","sledge"]
var output_path := "D:/MafioziCombat31/jump50/DAMAGE.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output_path=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--weapon="):weapons_to_test=[arg.trim_prefix("--weapon=")]
	run.call_deferred()
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: int, down: bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
func button(down: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e)
func motion(dx: float,dy: float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);Input.parse_input_event(e)
func one_case(weapon: String, dive: bool) -> void:
	if not storage._hand_weapon.is_empty(): storage.drop_held(false)
	var equipped: Dictionary=storage.acquire_or_select(weapon)
	if not equipped.get("ok",false):
		# Already dropped once in the prior case: the physical ground item owns it.
		if storage._fallen.has(weapon):equipped=storage._claim_display(weapon,true)
	if not equipped.get("ok",false):errors.append("equip_"+weapon);return
	sword=game.preview_sword_prototype
	player.global_position=Vector3(0,0.1,990) if location=="field" else game.preview_castle.to_global(Vector3(18,0.1,18));player.velocity=Vector3.ZERO
	player._camera_yaw=0.0;player._camera_pitch=-0.1;player._heading=0.0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(90)
	var base: Vector3=player.global_position
	sword._dummy.global_position=base+Vector3(0.9,0.0 if dive else 0.7,-2.8 if dive else -0.3)
	sword._dummy_hp=100.0;sword._dummy_down=false;sword._hit_ms.clear()
	var hits_before: int=sword._hits
	await frames(5)
	if sword._dummy_hp<100.0:errors.append("idle_damage")
	var rays: int=sword._sweep_rays
	key(KEY_SPACE,true);await frames(1);key(KEY_SPACE,false)
	if dive:
		await frames(3);key(KEY_SPACE,true);await frames(1);key(KEY_SPACE,false)
	await frames(5);button(true)
	var row: Dictionary={"weapon":weapon,"location":location,"guard":game.preview_jump_surface_allowed(base),"dive_requested":dive,"samples":[],"peak":base.y,"air_active":0,"air_held":0,"air_damage_gate":0,"air_grip_max":0.0,"air_left_max":0.0,"omega_max":0.0,"saw_dive":false,"saw_normal":false,"hidden_air":0,"air_hits":0,"air_damage":0.0}
	for tick in 150:
		if tick<35: motion(10.0 if tick<17 else -10.0,-5.0 if tick<17 else 5.0)
		if tick==40:button(false)
		await frames(1)
		var air:=not player.is_on_floor()
		var mode:=str(player._jump_pose.get("mode",""))
		if sword._hits>hits_before:
			if air:row.air_hits+=sword._hits-hits_before;row.air_damage=100.0-sword._dummy_hp
			hits_before=sword._hits
		row.peak=maxf(row.peak,player.global_position.y)
		row.saw_dive=row.saw_dive or mode=="dive";row.saw_normal=row.saw_normal or mode=="normal"
		if air:
			row.air_active+=int(sword._active());row.air_held+=int(sword._held);row.air_damage_gate+=int(sword._swing_can_damage31())
			row.air_grip_max=maxf(row.air_grip_max,sword._grip_hand_error);row.air_left_max=maxf(row.air_left_max,sword._left_hand_error)
			row.omega_max=maxf(row.omega_max,sword._omega.length())
			row.hidden_air+=int(not sword._sword.is_visible_in_tree())
		if tick%5==0:row.samples.append({"tick":tick,"air":air,"mode":mode,"position":player.global_position,"active":sword._active(),"held":sword._held,"damage_gate":sword._swing_can_damage31(),"phase":sword._swing_phase,"omega":sword._omega.length(),"grip":sword._grip_hand_error,"left":sword._left_hand_error,"tilt":player._pose_motion.quaternion.get_angle(),"self_clear":sword._self_pose_clear})
	button(false);await frames(30)
	row.rise=row.peak-base.y;row.travel=Vector2(player.global_position.x-base.x,player.global_position.z-base.z).length();row.rays=sword._sweep_rays-rays
	row.landed=player.is_on_floor() and player._jump.is_empty() and player._jump_pose.is_empty();row.authority=player._pose_authority;row.release_clear=not sword._hold_left and not sword._held_event;row.final_tilt=player._pose_motion.quaternion.get_angle()
	if row.rise<0.45:errors.append(weapon+"_jump_no_rise")
	if dive and not row.saw_dive:errors.append(weapon+"_dive_not_started")
	if row.air_held<5 or row.air_damage_gate<5 or row.omega_max<0.2:errors.append(weapon+"_air_melee_inactive")
	if row.hidden_air>0:errors.append(weapon+"_air_weapon_hidden")
	if not row.landed or row.authority!=&"on_foot" or not row.release_clear or row.final_tilt>0.01:errors.append(weapon+"_landing_incomplete")
	if row.air_grip_max>0.12 or (weapon=="sledge" and row.air_left_max>0.12):errors.append(weapon+"_air_grip_detached")
	if row.air_hits<1:errors.append(weapon+"_no_native_air_damage_"+str(dive))
	cases.append(row)
func run() -> void:
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0;player=game._player;storage=game.preview_castle.armory_storage
	for loc: String in ["field"]:
		location=loc
		for weapon: String in weapons_to_test:
			for dive: bool in [false,true]:await one_case(weapon,dive)
	var origin: Vector3=game.preview_castle.global_position
	var bounds_checks={"inside_field":game.preview_jump_surface_allowed(origin+Vector3(0,0.1,150)),"edge_inside":game.preview_jump_surface_allowed(origin+Vector3(299,0.1,0)),"radius_outside_rejected":not game.preview_jump_surface_allowed(origin+Vector3(299.9,0.1,0)),"outside_rejected":not game.preview_jump_surface_allowed(origin+Vector3(310,0.1,0)),"invalid_radius_rejected":not game.preview_jump_surface_allowed(origin,-1.0)}
	for k in bounds_checks:if not bounds_checks[k]:errors.append("bounds_"+k)
	var report={"bounds_checks":bounds_checks,"passed":errors.is_empty(),"errors":errors,"cases":cases,"scope":"Real space/double-space + mouse hold/motion, airborne controls/grip/sweeps/release/landing. Native existing training target moved once before input, actual swept contacts and damage observed while airborne. Pixel appearance not accepted."}
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if errors.is_empty() else 1)
