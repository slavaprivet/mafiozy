extends SceneTree
var game: Node3D
var host: Node
var rows: Array = []
var stage := "setup"
var total := 0
var durations: Array[int] = []
var evaluations: Array[int] = []
var by_weapon: Dictionary = {}
var penetration := 0
var front_penetration := 0
var grip_max := 0.0
var support_max := 0.0
var worst := 99.0
var weapon := OS.get_environment("SELF45_WEAPON")
func _initialize() -> void: call_deferred("run")
func button(which: int, down: bool) -> void:
	var e := InputEventMouseButton.new(); e.button_index=which;e.pressed=down;Input.parse_input_event(e)
func motion(v: Vector2) -> void:
	var e := InputEventMouseMotion.new();e.relative=v;Input.parse_input_event(e)
func frames(n: int, sample := false) -> void:
	for i in n:
		await physics_frame
		if sample: record()
func record() -> void:
	var rig: Skeleton3D = host._rig
	var head: Vector3 = rig.global_transform * rig.get_bone_global_pose(host._bone_head).origin
	var chest: Vector3 = rig.global_transform * rig.get_bone_global_pose(host._bone_chest).origin
	var pelvis: Vector3 = rig.global_transform * rig.get_bone_global_pose(host._bone_pelvis).origin
	var model: Node3D = host._sword
	var rear: Vector3 = model.global_transform * Vector3(-host.weapon_rear_extent(),0,0)
	var base: Vector3 = model.global_transform * Vector3.ZERO
	var tip: Vector3 = model.global_transform * Vector3(0.06+host._weapon_length,0,0)
	var torso_dist: float = host._segment_distance(rear,tip,chest,pelvis)
	var head_dist: float = host._segment_distance(rear,tip,head,head)
	var forward_torso: float = host._segment_distance(base,tip,chest,pelvis)
	var forward_head: float = host._segment_distance(base,tip,head,head)
	var clearance := minf(torso_dist-0.20,head_dist-0.18)
	total += 1
	durations.append(host._self_pose_usec45)
	evaluations.append(host._self_pose_evaluations45)
	if not by_weapon.has(weapon): by_weapon[weapon]={"ticks":0,"bad":0,"main_grip_max":0.0,"support_grip_max":0.0}
	by_weapon[weapon].ticks += 1
	if clearance < -0.001: by_weapon[weapon].bad += 1
	by_weapon[weapon].main_grip_max=maxf(by_weapon[weapon].main_grip_max,host._grip_hand_error)
	if host._active_side()==&"both": by_weapon[weapon].support_grip_max=maxf(by_weapon[weapon].support_grip_max,host._left_hand_error)
	grip_max = maxf(grip_max,host._grip_hand_error)
	if host._active_side()==&"both": support_max=maxf(support_max,host._left_hand_error)
	if clearance < -0.001: penetration += 1
	if minf(forward_torso-0.20,forward_head-0.18)<-0.001: front_penetration += 1
	if clearance < worst:
		worst=clearance
		rows.append({"stage":stage,"tick":total,"clearance":clearance,"torso":torso_dist,"head":head_dist,"forward_torso":forward_torso,"forward_head":forward_head,"host_self_clear":host._self_pose_clear,"grip":host._grip_hand_error,"origin":str(base),"rear":str(rear),"dir":str(host._dir),"hand":str(host._hand),"head_pos":str(head),"chest_pos":str(chest)})
func run() -> void:
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true: await process_frame
	await frames(180)
	game._castle_spawn_frames=0
	var player: CharacterBody3D=game._player
	var storage: Node=game.preview_castle.armory_storage
	player.global_position=game.preview_castle.to_global(storage._rack_points[0]);player.velocity=Vector3.ZERO
	storage.interact();await frames(10)
	host=game.preview_sword_prototype
	if weapon.is_empty(): weapon="sword"
	host.set_weapon(weapon)
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO;player.set_mouse_captured(true)
	player._camera_yaw=0.0;player._camera_pitch=-0.12;player._heading=0.0;player._visual.rotation.y=PI;player._update_camera_rotation()
	await frames(15)
	var phases := [["high",Vector2(0,-30)],["high_right",Vector2(30,0)],["high_cross",Vector2(-60,0)],["low_cross",Vector2(0,60)],["low_right",Vector2(60,0)],["high_again",Vector2(0,-60)]]
	for current: String in ["sword","mace","axe","sledge","spear"]:
		weapon=current
		host.set_weapon(weapon)
		await frames(10)
		for both in ([false,true] if weapon=="sword" else [false]):
			button(MOUSE_BUTTON_LEFT,true)
			if both: button(MOUSE_BUTTON_RIGHT,true)
			for p in phases:
				stage=str(p[0])+ ("_both" if both else "_one")
				for i in 18:
					motion(p[1]);await frames(2,true)
				await frames(18,true)
			button(MOUSE_BUTTON_LEFT,false);button(MOUSE_BUTTON_RIGHT,false)
			stage="carry";await frames(35,true)
	var sorted_costs := durations.duplicate(); sorted_costs.sort()
	var result={"angular_budget_excess":host._self_motion_excess45,"by_weapon":by_weapon,"component_usec_samples":durations,"evaluation_samples":evaluations,"component_usec_p95":sorted_costs[int(0.95*(sorted_costs.size()-1))],"component_usec_p99":sorted_costs[int(0.99*(sorted_costs.size()-1))],"max_ik_evaluations":host._self_pose_evaluations_max45,"max_solver_usec":host._self_pose_usec_max45,"unresolved":host._self_pose_unresolved45,"cached_pose_restores":host._self_pose_restores45,"weapon":weapon,"passed":host._self_motion_excess45<0.0001 and penetration==0 and grip_max<0.05 and support_max<0.05 and host._self_pose_unresolved45==0 and host._self_pose_evaluations_max45<=24,"total":total,"penetrating_frames":penetration,"forward_penetrating_frames":front_penetration,"minimum_clearance":worst,"max_support_grip_error":support_max,"max_grip_error":grip_max,"worst_events":rows,"scope":"Natural mouse commands, sword one/two-hand high/side/cross/low; head/torso axis check includes hilt. Not full weapon surface/body mesh collision proof."}
	var dest := OS.get_environment("SELF45_RESULT")
	if dest.is_empty(): dest="D:/MafioziCombat31/takeover45_self/RESULT.json"
	FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SELF45_RESULT ",JSON.stringify(result));quit(0 if result.passed else 1)
