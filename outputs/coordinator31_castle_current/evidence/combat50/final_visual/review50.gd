extends SceneTree
var errors: Array[String] = []
var rows: Array = []
var game: Node3D
var sword: Node
var storage: Node
var player: CharacterBody3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=InputEventKey.new(); event.keycode=code;event.physical_keycode=code;event.pressed=false
	Input.parse_input_event(event)
	await frames(6)
func snap(label: String) -> void:
	var ground: Dictionary=sword._nearest_ground_sword()
	rows.append({"stage":label,"hand":storage._hand_weapon,"carried":storage._carried.duplicate(),"fallen":storage._fallen.keys(),"selected":sword._selected,"host_weapon":sword._weapon_id,"host_unarmed":sword._unarmed,"host_grounded":sword._sword_grounded,"fire_weapon":game.preview_weapons.fire_state.weaponId,"ground_weapon":sword._ground_weapon_of(ground.node) if not ground.is_empty() else "","owner":game._current_door_action().get("owner", ""),"target_model_id":sword._sword.get_instance_id()})
func model_parts(model: Node3D) -> Array:
	var parts: Array=[]
	for child in model.get_children():
		if child is MeshInstance3D:
			var mat: Material=child.get_active_material(0)
			parts.append({"id":child.get_instance_id(),"name":child.name,"visible":child.is_visible_in_tree(),"color":str(mat.albedo_color) if mat is StandardMaterial3D else "","vertices":child.mesh.surface_get_array_len(0)})
	return parts
func run() -> void:
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true: await process_frame
	await frames(180)
	game._castle_spawn_frames=0
	player=game._player;storage=game.preview_castle.armory_storage
	var equip: Dictionary=storage.acquire_or_select("sledge")
	if not equip.get("ok",false): errors.append("setup_sledge_failed")
	sword=game.preview_sword_prototype
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO;player.set_mouse_captured(true)
	await frames(90)
	# Use the real NPC sword/drop path; only its initial position is controlled.
	if not is_instance_valid(sword._npc_sword):
		sword._npc_sword=sword._build_weapon_model(game,"sword")
	sword._drop_sword(player.global_position+Vector3(0,0.2,-1.6),Vector3.RIGHT,0.0)
	await frames(30)
	var target: Node3D=sword._npc_dropped_sword31
	if not is_instance_valid(target): errors.append("setup_npc_sword_missing");finish();return
	target.freeze=true;target.global_position=player.global_position+Vector3(0,0.15,-1.6)
	var expected_model: Node3D=sword._take_sword_model(target)
	var expected_id:=expected_model.get_instance_id()
	var expected_parts:=model_parts(expected_model)
	snap("before_g")
	await key(KEY_G)
	snap("after_g")
	if not storage._hand_weapon.is_empty():errors.append("g_hand_not_empty")
	if not storage._fallen.has("sledge"):errors.append("g_sledge_not_grounded")
	# Walk away from the dropped sledge, within reach of the NPC sword.
	player.global_position=target.global_position+Vector3(0,0,0.15);player.velocity=Vector3.ZERO
	await frames(6)
	snap("before_e")
	if game._current_door_action().get("owner","")!="castle_pickup":errors.append("wrong_e_owner")
	await key(KEY_E)
	snap("after_e")
	if storage._hand_weapon!="sword":errors.append("sword_not_in_hand")
	if sword._sword.get_instance_id()!=expected_id:errors.append("not_original_npc_model")
	if game.preview_weapons.fire_state.weaponId!="sword":errors.append("fire_weapon_not_sword")
	if not storage._fallen.has("sledge"):errors.append("sledge_lost_or_reacquired")
	if errors.is_empty():
		if sword.try_pickup_sword(true):errors.append("occupied_hand_pickup_allowed")
		await key(KEY_G);snap("foreign_sword_dropped")
		await key(KEY_E);snap("foreign_sword_recovered")
		if storage._hand_weapon!="sword" or sword._sword.get_instance_id()!=expected_id:errors.append("foreign_sword_roundtrip_failed")
	if errors.is_empty():
		# Put the external sword far enough away to select the other physical drop.
		player.global_position=Vector3(0,0.1,996);player.velocity=Vector3.ZERO
		await frames(4);await key(KEY_G)
		var saved_root: Node3D=expected_model
		var sword_point: Vector3=saved_root.global_position
		player.global_position=game.preview_castle.to_global(storage._fallen["sledge"]);player.velocity=Vector3.ZERO
		await frames(5);await key(KEY_E);snap("sledge_recovered_while_sword_grounded")
		if storage._hand_weapon!="sledge":errors.append("sledge_recovery_failed")
		await key(KEY_G)
		player.global_position=sword_point;player.velocity=Vector3.ZERO
		await frames(5);snap("before_whole_root_e")
		await key(KEY_E);await frames(12);snap("after_whole_root_e")
		if not is_instance_valid(saved_root) or saved_root.is_queued_for_deletion():errors.append("whole_root_deleted")
		if sword._sword.get_instance_id()!=expected_id:errors.append("whole_root_replaced_by_child")
		var actual_parts:=model_parts(sword._sword)
		rows.append({"stage":"whole_model_evidence","expected_parts":expected_parts,"actual_parts":actual_parts})
		if actual_parts!=expected_parts:errors.append("handle_guard_pommel_parts_changed")
		if storage._hand_weapon!="sword" or not storage._fallen.has("sledge"):errors.append("whole_root_ledger_failed")
		if errors.is_empty():
			await key(KEY_G);await key(KEY_E);await frames(10)
			if sword._sword.get_instance_id()!=expected_id or model_parts(sword._sword)!=expected_parts:errors.append("whole_model_repeat_failed")
	await visual_review()
func finish() -> void:
	quit(1)
var review_camera: Camera3D
var pose_rows: Array = []
var active_stage := ""
func mouse_button(which: int, down: bool) -> void:
	var event := InputEventMouseButton.new();event.button_index=which;event.pressed=down;Input.parse_input_event(event)
func mouse_motion(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new();event.relative=delta;Input.parse_input_event(event)
func observe_frame() -> void:
	pose_rows.append({"stage":active_stage,"weapon":sword._weapon_id,"omega":sword._omega.length(),"direction":str(sword._dir),"render_direction":str(sword._sword.global_basis.x),"model_frame":sword._self_model_frame45,"budget_excess":sword._self_motion_excess45,"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"self_restores":sword._self_pose_restores45,"self_unresolved":sword._self_pose_unresolved45,"camera_forward":str(-sword._camera.global_basis.z),"origin":str(sword._sword_origin),"hand":str(sword._hand),"self_clear":sword._self_pose_clear,"grip":sword._grip_hand_error,"support":sword._left_hand_error,"evaluations":sword._self_pose_evaluations45,"solver_usec":sword._self_pose_usec45})
func watch(n: int) -> void:
	for index in n:
		await physics_frame;observe_frame()
func shot(name: String, close := false) -> void:
	var target: Vector3 = sword._sword_origin if close else player.global_position+Vector3(0,1.25,0)
	review_camera.global_position=target+Vector3(0.80,0.20,-0.78) if close else player.global_position+Vector3(2.40,1.65,-1.55)
	review_camera.fov=42.0 if close else 52.0
	review_camera.look_at(target,Vector3.UP)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/MafioziCombat31/merged50/final_visual/"+name+".png")
	observe_frame()
func visual_review() -> void:
	review_camera=Camera3D.new();game.add_child(review_camera);review_camera.current=true
	player._camera_yaw=0.0;player._camera_pitch=-0.12;player._heading=0.0;player._visual.rotation.y=PI;player._update_camera_rotation()
	player.set_mouse_captured(true);await frames(12)
	active_stage="sword_after_G_E";await shot("01_sword_hilt_after_pickup",true)
	mouse_button(MOUSE_BUTTON_LEFT,true)
	active_stage="sword_high"
	for i in 14: mouse_motion(Vector2(0,-28));await watch(2)
	await watch(8);await shot("02_sword_high")
	active_stage="sword_side"
	for i in 14: mouse_motion(Vector2(36,18));await watch(2)
	await shot("03_sword_side")
	mouse_button(MOUSE_BUTTON_LEFT,false);await watch(12)
	# Equipment selection here isolates the real sledge presentation/control
	# on this scene; the earlier ordinary G/E chain has already checked ledger.
	sword.set_weapon("sledge");await frames(12)
	active_stage="sledge_high";mouse_button(MOUSE_BUTTON_LEFT,true)
	for i in 18: mouse_motion(Vector2(-14,-36));await watch(2)
	await watch(10);await shot("04_sledge_high")
	active_stage="sledge_down_early"
	for i in 3: mouse_motion(Vector2(0,70));await watch(2)
	await shot("05_sledge_down_early")
	active_stage="sledge_down_late"
	for i in 12: mouse_motion(Vector2(0,32));await watch(2)
	await shot("06_sledge_down_late")
	mouse_button(MOUSE_BUTTON_LEFT,false)
	var result={"passed":errors.is_empty(),"errors":errors,"pickup_rows":rows,"pose_rows":pose_rows,"scope":"Pinned merged50 graphical six-frame review: full sword after native G/E lifecycle, sword high/side and sledge high/down. Camera is an independent spectator; player steering camera unchanged. Not full game/FPS acceptance."}
	FileAccess.open("D:/MafioziCombat31/merged50/final_visual/REVIEW_NATIVE.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("VISUAL_REVIEW50_DONE errors=",errors)
	quit(0 if errors.is_empty() else 1)
