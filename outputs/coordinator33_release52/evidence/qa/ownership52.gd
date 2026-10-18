extends SceneTree
var game: Node
var player: CharacterBody3D
var sword: Node
var bow: Node
var storage: Node
var out := ""
var rows: Array = []
var errors: Array[String] = []
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:await physics_frame
func mouse(index: int, down: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=index;e.pressed=down;Input.parse_input_event(e)
func motion(dx: float,dy: float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);Input.parse_input_event(e)
func key(code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await frames(2)
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await frames(2)
func visible_dots(host: Node) -> int:
	var total:=0
	for dot in host._aim_dots:
		if is_instance_valid(dot) and dot.is_visible_in_tree():total+=1
	return total
func sample(label: String) -> void:
	var sw:int=visible_dots(sword);var bw:int=visible_dots(bow)
	rows.append({"label":label,"sword_dots":sw,"bow_dots":bw,"sword_selected":sword._selected,"bow_selected":bow._selected,"sword_aim":sword._aiming_throw,"bow_aim":bow._aiming,"pitch":player._camera_pitch,"camera_forward":-player._camera.global_basis.z if player.get("_camera")!=null else Vector3.ZERO,"bow_direction":bow._aim_direction(),"spear_direction":sword._dir,"storage":storage.snapshot()})
	if sw>0 and bw>0:errors.append(label+"_double_arc")
	if sw>0 and not sword._selected:errors.append(label+"_inactive_sword_arc")
	if bw>0 and not bow._selected:errors.append(label+"_inactive_bow_arc")
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0;player=game._player;storage=game.preview_castle.armory_storage
	player.global_position=Vector3(0,.1,990);player.velocity=Vector3.ZERO;player._camera_yaw=0;player._camera_pitch=0;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	var spear_result:Dictionary=storage.acquire_or_select("spear")
	var bow_result:Dictionary=storage.acquire_or_select("bow")
	sword=game.preview_sword_prototype;bow=game.preview_bow_prototype;await frames(60)
	var before:float=player._camera_yaw;motion(10,0);await frames(2)
	var delivered:float=-wrapf(float(player._camera_yaw)-before,-PI,PI)/float(player.mouse_sensitivity)
	motion(-10,0);await frames(2)
	if absf(delivered-10)>.05:errors.append("input_not_1to1")
	rows.append({"input_injected":10,"input_delivered":delivered,"viewport":root.size,"spear_acquire":spear_result,"bow_acquire":bow_result})
	mouse(MOUSE_BUTTON_RIGHT,true);await frames(70);sample("spear_rmb")
	await key(KEY_Q);await frames(70);sample("bow_after_q_while_rmb")
	mouse(MOUSE_BUTTON_RIGHT,false);await frames(3);mouse(MOUSE_BUTTON_RIGHT,true);await frames(90);sample("bow_reaim")
	for i in 60:motion(0,-10);await frames(1)
	await frames(30);sample("bow_high_up")
	var shots_before:int=bow._shots;mouse(MOUSE_BUTTON_LEFT,true);await frames(1);mouse(MOUSE_BUTTON_LEFT,false);await frames(1)
	var launch:Dictionary={"shots_delta":bow._shots-shots_before,"pitch":player._camera_pitch,"aim":bow._aim_direction()}
	if bow._shots>shots_before and not bow._arrows.is_empty():launch["projectile_velocity"]=bow._arrows.back().velocity;launch["projectile_alive"]=bow._arrows.back().alive
	rows.append({"high_shot":launch})
	if player._camera_pitch<1.0:errors.append("high_up_camera_limited")
	await key(KEY_Q);await frames(70);sample("spear_after_q_while_rmb")
	mouse(MOUSE_BUTTON_RIGHT,false);await frames(3);mouse(MOUSE_BUTTON_RIGHT,true);await frames(70);sample("spear_reaim_high")
	mouse(MOUSE_BUTTON_RIGHT,false);await frames(5);sample("released")
	var report={"passed":errors.is_empty(),"errors":errors,"rows":rows,"scope":"Native Q switch/RMB/LMB/mouse inputs after rack-acquisition API setup. Actual visible geometry counts; high shot actual projectile velocity. No target contact claimed by this ownership probe."}
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if errors.is_empty() else 2)
