extends SceneTree
var checks:=0
var failures:Array[String]=[]
var folder:String
var scene:Node3D
var p:CharacterBody3D
var host:Node
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func sync(n:int)->void:
	for i:int in n:await physics_frame;await process_frame
func mouse(button:MouseButton,down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=down;p._unhandled_input(e)
func run()->void:
	folder=get_script().resource_path.get_base_dir();create_timer(15).timeout.connect(func():quit(3))
	var model:Script=load("res://scripts/weapons/walk_weapon_crosshair.gd")
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("ORACLE.json")))
	for row:Dictionary in oracle.rows:
		var got:Dictionary=model.sample_gap(row.state,row.input,row.view.height,row.view.fov)
		check(absf(got.gap-row.gap)<.00001,"source gap "+row.id)
		check(absf(got.spread-row.spread)<.00000001,"source cone "+row.id)
		check(got.rounded_gap==row.rounded_gap,"source pixel rounding "+row.id)
		var rects:Array=model.arm_rects(got.rounded_gap)
		for i:int in 4:check(rects[i]==Rect2(row.rects[i][0],row.rects[i][1],row.rects[i][2],row.rects[i][3]),"source arm rect "+row.id)
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_residents_enabled=false;root.add_child(scene)
	while not scene.preview_ready:await physics_frame
	p=scene._player;host=scene.preview_weapons;p._free_mouse_look=true
	check(is_instance_valid(host),"host configured")
	if not is_instance_valid(host):finish();return
	check(host.equip("ak74").ok,"real AK equip");await sync(6)
	var cross:Control=host._walk_ui.crosshair
	check(not cross.visible,"carried gun hides source reticle")
	mouse(MOUSE_BUTTON_RIGHT,true);await sync(20)
	check(cross.visible and cross.arms and cross.gap==3,"RMB shows four-arm source rest reticle")
	check(cross.position==cross.get_viewport_rect().size*.5,"exact viewport center")
	check(cross.mouse_filter==Control.MOUSE_FILTER_IGNORE and cross.focus_mode==Control.FOCUS_NONE,"reticle never steals controls")
	Input.action_press(p.ACTION_BACK);await sync(25);var moving_gap:int=cross.gap;check(moving_gap>3,"actual movement widens gap")
	Input.action_release(p.ACTION_BACK);await sync(30)
	var redraws:int=cross.redraws;await sync(15);check(cross.redraws==redraws,"settled same integer gap avoids redraw")
	var ammo:int=host.fire_state.magazine;mouse(MOUSE_BUTTON_LEFT,true);await sync(8);mouse(MOUSE_BUTTON_LEFT,false);await sync(1)
	check(host.shots_count>0 and host.fire_state.magazine<ammo,"real fire and ammo drive bloom")
	check(cross.spread>0 and cross.gap>3,"actual sustained fire bloom visible")
	mouse(MOUSE_BUTTON_RIGHT,false);await sync(3);check(not cross.visible,"release hides source ordinary crosshair")
	mouse(MOUSE_BUTTON_LEFT,true);await sync(1);check(cross.visible,"hip held trigger shows reticle");mouse(MOUSE_BUTTON_LEFT,false)
	check(host.equip("sniper").ok,"real sniper equip");mouse(MOUSE_BUTTON_RIGHT,true);await sync(5);check(host.aim_camera.scoped() and not cross.visible,"scope replaces ordinary reticle")
	host.set_menu(true);await sync(2);check(not cross.visible,"menu hides reticle")
	host.set_menu(false);p._free_mouse_look=true;check(host.equip("none").ok,"real unarmed equip");host.set_cargo_reticle(true);await sync(2);check(cross.visible and not cross.arms,"unarmed cargo keeps small center dot")
	host.set_cargo_reticle(false);await sync(2);check(not cross.visible,"cargo target leaves dot hidden")
	check(host.equip("ak74").ok,"AK return");mouse(MOUSE_BUTTON_RIGHT,true);await sync(2);p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await sync(2);check(not cross.visible,"blur hides reticle")
	finish()
func finish()->void:
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Original JS oracle geometry/cone and actual candidate04 main/player input/ammo/movement/camera/UI; all modules loaded from res://, no source/module overrides; headless, no GPU acceptance"}
	result["runtime_sha"]={}
	for file:String in ["scripts/main.gd","scripts/preview_player.gd","scripts/weapons/preview_weapons.gd","scripts/weapons/walk_weapon_ui.gd","scripts/weapons/walk_weapon_crosshair.gd","scripts/weapons/weapon_aim_camera.gd"]:result.runtime_sha[file]=FileAccess.get_sha256("res://"+file)
	result["oracle_sha"]=FileAccess.get_sha256(folder.path_join("ORACLE.json"))
	result["resource_root"]=ProjectSettings.globalize_path("res://")
	FileAccess.open(folder.path_join("ROOT_RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("ROOT_RETICLE ",JSON.stringify(result));if is_instance_valid(scene):scene.free()
	quit(0 if failures.is_empty() else 1)
