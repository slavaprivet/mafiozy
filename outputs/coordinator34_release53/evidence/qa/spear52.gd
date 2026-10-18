extends SceneTree
var game: Node3D
var player: CharacterBody3D
var host: Node
var storage: Node
var errors: Array[String]=[]
var samples: Array=[]
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func button(which: int, pressed: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=which;e.pressed=pressed;e.position=Vector2(640,360);Input.parse_input_event(e)
	await frames(3)
func motion(dx: float, dy: float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);e.position=Vector2(640,360);e.global_position=e.position;e.button_mask=MOUSE_BUTTON_MASK_RIGHT;Input.parse_input_event(e)
	await frames(2)
func key(code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await frames(3)
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await frames(3)
func check(value: bool, tag: String) -> void:
	if not value: errors.append(tag)
func snap(tag: String) -> void:
	samples.append({"tag":tag,"held":host._held,"aim":host._aiming_throw,"visible_dots":host._aim_visible,"actual_visible_dots":actual_dots(),"dir":str(host._dir),"desired":str(host._spear_aim_direction52()),"aim_error_deg":rad_to_deg(host._dir.angle_to(host._spear_aim_direction52())),"pitch":player._camera_pitch,"grip":host._grip_hand_error,"support":host._left_hand_error,"self_clear":host._self_pose_clear,"unresolved":host._self_pose_unresolved45,"throwing":host._throwing,"pending":host._spear_cast_pending31})
func actual_dots() -> int:
	var count:=0
	for dot: MeshInstance3D in host._aim_dots:
		if dot.is_visible_in_tree():count+=1
	return count
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0
	player=game._player;storage=game.preview_castle.armory_storage
	check(storage.acquire_or_select("spear").get("ok",false),"equip_spear")
	host=game.preview_sword_prototype
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO;player._camera_yaw=0;player._camera_pitch=-0.1;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
	var wall:=StaticBody3D.new();wall.name="Spear52Target";var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,100,0.5);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=Vector3(0,40,976)
	await frames(30)
	await button(MOUSE_BUTTON_RIGHT,true);await frames(80);snap("rmb_aim")
	check(host._held and host._aiming_throw and actual_dots()>0,"rmb_owns_spear_aim")
	for i in 12:await motion(0,-28)
	await frames(100);snap("aim_up")
	check(host._dir.y>0.25,"upward_camera_aim")
	check(rad_to_deg(host._dir.angle_to(host._spear_aim_direction52()))<8,"upward_alignment")
	for i in 5:await motion(0,-28)
	await frames(100);snap("aim_steep")
	check(host._dir.y>0.90,"steep_upward_aim")
	check(rad_to_deg(host._dir.angle_to(host._spear_aim_direction52()))<8,"steep_alignment")
	for i in 17:await motion(0,28)
	await frames(100);snap("aim_down")
	check(host._dir.y<0.15,"downward_camera_aim")
	await key(KEY_G);await frames(8);snap("drop_while_aiming")
	check(actual_dots()==0,"drop_hides_trajectory")
	await button(MOUSE_BUTTON_RIGHT,false);await key(KEY_E);await frames(20)
	check(storage._hand_weapon=="spear","e_recovers_spear")
	await button(MOUSE_BUTTON_RIGHT,true);await frames(30)
	host.set_selected(false);await frames(3);snap("deselected")
	check(actual_dots()==0 and not host._aiming_throw,"deselect_clears_aim")
	host.set_selected(true);await button(MOUSE_BUTTON_RIGHT,false);await button(MOUSE_BUTTON_RIGHT,true)
	for i in 5:await motion(0,-28)
	await frames(100);snap("precharge")
	await button(MOUSE_BUTTON_LEFT,true);await frames(55);snap("charged")
	var before: int=host._thrown_total
	await button(MOUSE_BUTTON_LEFT,false);await frames(25);snap("released")
	check(host._thrown_total==before+1,"release_one_spear")
	check(actual_dots()==0,"released_hides_trajectory")
	await frames(180)
	var entry: Dictionary=host._thrown.back() if not host._thrown.is_empty() else {}
	check(not entry.is_empty() and not entry.get("alive",true),"real_projectile_contact")
	var projectile: Node3D=entry.get("node")
	if is_instance_valid(projectile):
		player.global_position=projectile.global_position;player.global_position.y=maxf(0.1,projectile.global_position.y-0.5);player.velocity=Vector3.ZERO
		await button(MOUSE_BUTTON_RIGHT,false);await frames(4);await key(KEY_E);await frames(10)
		# The projectile may be high in the wall; report recovery reach separately.
		checks_pickup(projectile)
	var result={"passed":errors.is_empty(),"errors":errors,"samples":samples,"thrown":host._thrown_total,"contact":not entry.get("alive",true),"contact_position":str(projectile.global_position) if is_instance_valid(projectile) else "none","viewport":str(root.size),"scope":"Correct viewport real input aim upward/downward, G/E, ownership selection/reset, charge/release and physical world projectile contact; no NPC damage acceptance."}
	FileAccess.open("D:/MafioziCombat31/coordinator34_merged53/spear_high/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("SPEAR52_RESULT ",JSON.stringify(result));quit(0 if errors.is_empty() else 1)
func checks_pickup(_projectile: Node3D) -> void:
	samples.append({"tag":"post_contact_e","hand":storage._hand_weapon,"unarmed":host._unarmed})
	check(not host._unarmed and storage._hand_weapon=="spear","e_recovers_thrown_spear")
