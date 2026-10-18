extends SceneTree
var game:Node
var player:CharacterBody3D
var sword:Node
var bow:Node
var storage:Node
var weapon:="sword"
var out:=""
var errors:Array[String]=[]
var rows:Array=[]
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
		if a.begins_with("--weapon="):weapon=a.trim_prefix("--weapon=")
	run.call_deferred()
func frames(n:int) -> void:
	for i in n:await physics_frame
func mouse(index:int,down:bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=index;e.pressed=down;Input.parse_input_event(e)
func motion(dx:float,dy:float) -> void:
	var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);Input.parse_input_event(e)
func key(code:int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await frames(2)
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await frames(2)
func dots(host:Node) -> int:
	if not is_instance_valid(host):return 0
	var total:=0
	for d in host._aim_dots:
		if is_instance_valid(d) and d.is_visible_in_tree():total+=1
	return total
func sample(label:String) -> void:
	rows.append({"label":label,"storage":storage.snapshot(),"sword_dots":dots(sword),"bow_dots":dots(bow),"sword_selected":sword._selected if is_instance_valid(sword) else false,"bow_selected":bow._selected if is_instance_valid(bow) else false})
	if dots(sword)>0 and dots(bow)>0:errors.append(label+"_double_arc")
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(180);game._castle_spawn_frames=0;player=game._player;storage=game.preview_castle.armory_storage
	var acquired:Dictionary=storage.acquire_or_select(weapon);await frames(25)
	sword=game.preview_sword_prototype;bow=game.preview_bow_prototype
	player.global_position=Vector3(0,.1,990);player.velocity=Vector3.ZERO;player._camera_yaw=0;player._camera_pitch=-.2;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true);await frames(30)
	var before:float=player._camera_yaw;motion(10,0);await frames(1)
	var delivered:float=-wrapf(float(player._camera_yaw)-before,-PI,PI)/float(player.mouse_sensitivity);motion(-10,0);await frames(1)
	rows.append({"acquire":acquired,"input_delivered":delivered,"viewport":root.size})
	if not acquired.get("ok",false):errors.append("acquire")
	if absf(delivered-10)>.05:errors.append("input_not_1to1")
	mouse(MOUSE_BUTTON_RIGHT,true);await frames(60);sample("aim")
	mouse(MOUSE_BUTTON_RIGHT,false);await frames(10);sample("release")
	if weapon != "bow":
		var back_bow:Dictionary=storage.acquire_or_select("bow");bow=game.preview_bow_prototype
		if not back_bow.get("ok",false):errors.append("back_bow_acquire")
		mouse(MOUSE_BUTTON_RIGHT,true);await frames(20)
		await key(KEY_Q);await frames(20);sample("switch_to_bow_held_rmb")
		mouse(MOUSE_BUTTON_RIGHT,false);await frames(3);mouse(MOUSE_BUTTON_RIGHT,true);await frames(60);sample("switch_bow_reaim")
		await key(KEY_Q);await frames(20);sample("switch_back_held_rmb")
		mouse(MOUSE_BUTTON_RIGHT,false);await frames(10)

	await key(KEY_G);await frames(35);sample("drop")
	if storage._carried.has(weapon):errors.append("g_still_carried")
	await key(KEY_E);await frames(35);sample("pickup")
	if not storage._carried.has(weapon):errors.append("e_not_carried")
	var contacts:Array=[]
	if weapon!="bow":
		# Existing native dummy; place once before the first attack, no shape or HP edits.
		sword._dummy.global_position=Vector3(0,.08,987.6 if weapon=="spear" else 988.7)
		var fixed:Transform3D=sword._dummy.global_transform
		var start_hp:float=sword._dummy_hp
		for attempt in 4:
			# Re-aim only via real input, preserving native body's follow.
			motion(wrapf(float(player._camera_yaw),-PI,PI)/float(player.mouse_sensitivity),(float(player._camera_pitch)+.2)/float(player.mouse_sensitivity));await frames(3)
			var hp:float=sword._dummy_hp;var hits:int=sword._hits
			var trace:Array=[]
			mouse(MOUSE_BUTTON_LEFT,true)
			for tick in 36:
				motion((-10.0 if tick<12 or tick>=24 else 20.0)*(1.0 if attempt%2==0 else -1.0),0);await frames(1)
				if tick%3==0:trace.append({"tick":tick,"origin":sword._sword_origin,"tip":sword._sword_origin+sword._dir*(sword._weapon_length+.06),"omega":sword._omega.length(),"phase":sword._swing_phase,"can_damage":sword._swing_can_damage31()})
			mouse(MOUSE_BUTTON_LEFT,false);await frames(25)
			contacts.append({"trace":trace,"attempt":attempt,"hp_before":hp,"hp_after":sword._dummy_hp,"hits":sword._hits-hits,"grip_error":sword._grip_hand_error,"left_error":sword._left_hand_error,"target_unchanged":sword._dummy.global_transform==fixed})
			if sword._dummy_hp<=0:break
		if sword._dummy_hp>=start_hp:errors.append("no_actual_dummy_damage")
	else:
		# Fixed physical backboard, no damage callback; inspect actual embedded arrow surface.
		var target:=StaticBody3D.new();target.name="QA52Backboard";target.collision_layer=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,4,.2);shape.shape=box;target.add_child(shape);game.add_child(target);target.global_position=Vector3(0,2,982)
		motion(0,(float(player._camera_pitch)-.1)/float(player.mouse_sensitivity));await frames(5)
		mouse(MOUSE_BUTTON_RIGHT,true);await frames(100)
		var shots:int=bow._shots;mouse(MOUSE_BUTTON_LEFT,true);await frames(1);mouse(MOUSE_BUTTON_LEFT,false);await frames(120);mouse(MOUSE_BUTTON_RIGHT,false)
		var hit_target:=false
		for arrow:Dictionary in bow._arrows:
			if is_instance_valid(arrow.get("node")) and arrow.node.get_parent()==target and arrow.get("stuck",false):hit_target=true
		contacts.append({"shots":bow._shots-shots,"hit_fixed_collider":hit_target,"aim":bow._aim_direction()})
		if not hit_target:errors.append("no_actual_arrow_backboard_contact")
	var report={"passed":errors.is_empty(),"weapon":weapon,"errors":errors,"lifecycle":rows,"contacts":contacts,"scope":"Real input1:1 G/E aim/strike; rack API equip only. Existing native dummy placed before attacks, original HP/shape unchanged. Bow fixed collider with native arrow embedding, no HP injection."}
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if errors.is_empty() else 2)
