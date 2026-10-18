extends SceneTree
class Probe:
	extends Node
	var received:Array=[]
	func _input(e:InputEvent)->void:
		if e is InputEventMouseMotion:received.append([e.relative.x,e.relative.y])
var game:Node3D
var player:CharacterBody3D
var bow:Node
var storage:Node
var probe:Node
var rows:Array=[]
var output_path:="D:/MafioziCombat31/coordinator34_merged53/bow_high/BASELINE.json"
func _initialize()->void:
	for a:String in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):output_path=a.trim_prefix("--qa-out=")
	run.call_deferred()
func frames(n:int)->void:
	for i in n:await physics_frame
func button(which:int,down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=which;e.pressed=down;Input.parse_input_event(e)
func motion(dy:float)->void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(0,dy);e.button_mask=MOUSE_BUTTON_MASK_RIGHT;e.position=Vector2(640,360);e.global_position=e.position;Input.parse_input_event(e)
func key(k:int)->void:
	var e:=InputEventKey.new();e.keycode=k;e.physical_keycode=k;e.pressed=true;Input.parse_input_event(e);await frames(2)
	e=InputEventKey.new();e.keycode=k;e.physical_keycode=k;e.pressed=false;Input.parse_input_event(e);await frames(8)
func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
func dots()->int:
	var n:=0
	for d in bow._aim_dots:if is_instance_valid(d) and d.visible:n+=1
	return n
func shot(degrees:float)->void:
	button(MOUSE_BUTTON_RIGHT,false);await frames(10)
	player._camera_yaw=0.0;player._camera_pitch=-0.1;player._heading=0.0;player._visual.rotation.y=PI;player._update_camera_rotation()
	button(MOUSE_BUTTON_RIGHT,true)
	var total:float=-(deg_to_rad(degrees)+0.1)/player.mouse_sensitivity
	for i in 20:motion(total/20.0);await frames(1)
	await frames(100)
	var row:Dictionary={"requested_degrees":degrees,"pitch_degrees":rad_to_deg(player._camera_pitch),"aim":xyz(bow._aim_direction()),"camera":xyz(-bow._camera.global_basis.z),"dots":dots(),"ready":bow.ready_to_fire(),"pose":bow._pose_metrics.duplicate(),"shots_before":bow._shots,"before_muzzle":xyz(bow._muzzle_point())}
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/MafioziCombat31/coordinator34_merged53/bow_high/bow_high_"+str(int(degrees))+".png")
	var last:=Vector3.ZERO
	for d in bow._aim_dots:if is_instance_valid(d) and d.visible:last=d.global_position
	row.preview_last=xyz(last)
	button(MOUSE_BUTTON_LEFT,true);await frames(1);button(MOUSE_BUTTON_LEFT,false)
	var index:int=bow._last_fired_index
	await frames(180)
	row.shots_after=bow._shots
	if index>=0:
		var arrow:Dictionary=bow._arrows[index]
		row.stuck=arrow.get("stuck",false);row.hit=xyz(arrow.get("hit_point",Vector3.ZERO));row.hit_parent=str(arrow.node.get_parent().name);row.hit_height=arrow.get("hit_point",Vector3.ZERO).y-player.global_position.y
	rows.append(row)
	button(MOUSE_BUTTON_RIGHT,false);await frames(30)
func run()->void:
	root.size=Vector2i(1280,720);probe=Probe.new();root.add_child(probe)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0;player=game._player;storage=game.preview_castle.armory_storage;bow=game.preview_bow_prototype
	storage.acquire_or_select("bow");bow=game.preview_bow_prototype;player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO;player.set_mouse_captured(true);await frames(90)
	var wall:=StaticBody3D.new();wall.name="HighWall52";wall.collision_layer=1;wall.collision_mask=1;game.add_child(wall);wall.global_position=Vector3(0,34,980)
	var shape:=BoxShape3D.new();shape.size=Vector3(14,60,1);var col:=CollisionShape3D.new();col.shape=shape;wall.add_child(col)
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=shape.size;mesh.mesh=box;wall.add_child(mesh)
	await frames(5)
	await shot(50.0);await shot(76.0)
	button(MOUSE_BUTTON_RIGHT,true);await frames(65);var before:int=dots();await key(KEY_G);var after_g:int=dots();await key(KEY_E);await frames(10)
	rows.append({"kind":"GE","before_dots":before,"after_g_dots":after_g,"after_e_dots":dots(),"held":storage._hand_weapon,"selected":bow._selected,"grounded":bow._grounded,"bow_active":storage._bow_active,"carried":storage._carried.duplicate(),"fire_weapon":game.preview_weapons.fire_state.weaponId})
	button(MOUSE_BUTTON_RIGHT,false);await frames(2)
	var result={"rows":rows,"input_received":probe.received,"root_size":str(root.size),"scope":"Real RMB aim+mouse elevation then LMB shot; static elevated wall installed before input. Native arrow flight/contact; no injected damage."}
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("BOW52_DONE "+output_path);quit()

