extends SceneTree
class Probe:
	extends Node
	var received: Array=[]
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:received.append({"relative":[event.relative.x,event.relative.y],"screen_relative":[event.screen_relative.x,event.screen_relative.y],"position":[event.position.x,event.position.y]})

var input_probe: Node

var game: Node3D
var player: CharacterBody3D
var sword: Node
var storage: Node
var rows: Array=[]
var output_path := "D:/MafioziCombat31/resume51_controls/BASELINE.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output_path=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func button(down: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e)
func motion(dx: float,dy: float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);e.button_mask=MOUSE_BUTTON_MASK_LEFT;e.position=Vector2(640,360);e.global_position=e.position;Input.parse_input_event(e)
func xyz(v: Vector3) -> Array:return [v.x,v.y,v.z]
func arm(side: StringName) -> Dictionary:
	var a: Dictionary=sword._arm_set(side)
	var sh: Vector3=sword._chain_global(a.upper).origin
	var elbow: Vector3=sword._chain_global(a.fore).origin
	var wrist: Vector3=sword._chain_global(a.hand).origin
	var len1: float=a.rest_fore.origin.length()
	var len2: float=a.rest_hand.origin.length()
	var visual: Basis=player._visual.global_basis.orthonormalized()
	var palm: Vector3=sword._palm_position(side)
	var shoulder: Vector3=sword._rig.global_transform*sh
	return {"reach":sh.distance_to(wrist)/(len1+len2),"elbow_angle":rad_to_deg((sh-elbow).angle_to(wrist-elbow)),"palm_from_shoulder":xyz(visual.inverse()*(palm-shoulder)),"palm_world":xyz(palm),"wrist_angle":rad_to_deg(sword._rig.get_bone_pose_rotation(a.hand).get_angle())}
func sample(tick: int,phase: String) -> Dictionary:
	return {"tick":tick,"phase":phase,"held":sword._held,"hand":[sword._hand.x,sword._hand.y],"dir":xyz(sword._dir),"origin":xyz(sword._sword_origin-player.global_position),"tip":xyz(sword._sword_origin+sword._dir*(sword._weapon_length+0.06)-player.global_position),"omega":sword._omega.length(),"camera_yaw":player._camera_yaw,"mouse_sensitivity":player.mouse_sensitivity,"input_count":input_probe.received.size(),"omega_vector":xyz(sword._omega),"target":xyz(sword._target_direction()),"steer_target":xyz(sword._steer_target),"camera_forward":xyz(-sword._camera.global_basis.z),"visual_forward":xyz(player._visual.global_basis.z),"self_restores":sword._self_pose_restores45,"body_camera_yaw_deg":rad_to_deg(Vector3(player._visual.global_basis.z.x,0,player._visual.global_basis.z.z).normalized().signed_angle_to(Vector3(-sword._camera.global_basis.z.x,0,-sword._camera.global_basis.z.z).normalized(),Vector3.UP)),"local_dir":xyz(player._visual.global_basis.orthonormalized().inverse()*sword._dir),"local_tip":xyz(player._visual.global_basis.orthonormalized().inverse()*(sword._sword_origin+sword._dir*(sword._weapon_length+0.06)-player.global_position)),"local_origin":xyz(player._visual.global_basis.orthonormalized().inverse()*(sword._sword_origin-player.global_position)),"clear":sword._self_pose_clear,"grip":sword._grip_hand_error,"left_grip":sword._left_hand_error,"left":arm(&"left"),"right":arm(&"right")}
func one_case(weapon: String,side: float) -> void:
	button(false)
	if not storage._hand_weapon.is_empty(): storage.drop_held(false)
	var equip: Dictionary=storage.acquire_or_select(weapon)
	if not equip.get("ok",false) and storage._fallen.has(weapon):equip=storage._claim_display(weapon,true)
	sword=game.preview_sword_prototype
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO
	player._camera_yaw=0.0;player._camera_pitch=-0.1;player._heading=0.0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(90)
	var row={"weapon":weapon,"direction":side,"equip":equip,"samples":[]}
	button(true)
	for tick in 150:
		var phase:="rest"
		if tick<30:
			motion(side*10.0,0.0);phase="windup"
		elif tick<50:phase="hold"
		elif tick<85:
			motion(-side*14.0,0.0);phase="strike"
		elif tick==110:button(false)
		await frames(1)
		row.samples.append(sample(tick,phase))
	rows.append(row)
	button(false);await frames(30)
func run() -> void:
	root.size=Vector2i(1280,720)
	input_probe=Probe.new();root.add_child(input_probe)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0;player=game._player;storage=game.preview_castle.armory_storage
	for weapon: String in ["sword","sledge"]:
		for side: float in [-1.0,1.0]:await one_case(weapon,side)
	var report={"rows":rows,"input_received":input_probe.received,"root_size":str(root.size),"visible_rect":str(root.get_visible_rect()),"content_scale_size":str(root.content_scale_size),"scope":"Native free held LMB and mouse events; horizontal load 30 ticks x10, hold20, reverse35 x14; no direct pose edits during sampled motion. Raw metrics only, no visual acceptance."}
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("CONTROL_TRACE_DONE "+output_path);quit()
