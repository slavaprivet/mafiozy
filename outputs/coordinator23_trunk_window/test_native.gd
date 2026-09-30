extends SceneTree
var checks:=0
var errors:Array[String]=[]
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func key(code:int)->InputEventKey:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true;return e
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_residents_enabled=false;root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"actual main ready")
	if not scene.preview_ready:quit(1);return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p._free_mouse_look=true
	await step(60)
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	await step(5)
	var camera:Camera3D=p.get_preview_camera();camera.top_level=true;camera.global_position=p.global_position+Vector3.UP*2;camera.look_at(camera.global_position+Vector3.RIGHT*20,Vector3.UP)
	check(w.equip("tt_pistol").get("ok",false),"real TT inventory equip")
	var original:Dictionary=w.inventory.snapshot()
	c._input(key(KEY_G));check(w.inventory.snapshot()==original,"closed nearby G never drops")
	check(not c.open_window(),"closed hatch cannot open contents")
	t.compartments.set_open("trunk",true);await step(100)
	camera.look_at(camera.global_position+Vector3.RIGHT*20,Vector3.UP)
	check(c._window_access(),"actual open rear access and unobstructed player path")
	check(c.aim_context().item_uid=="" and not c.aim_context().aimed_trunk,"deliberately looking away from tiny models")
	c._input(key(KEY_E))
	check(c.window_open and c._window.visible and w.controls_blocked() and not w.menu_open,"E opens separate real window without hover")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"modal mouse usable")
	Input.parse_input_event(key(KEY_E));await step()
	check(not c.window_open and t.compartments.is_open("trunk") and t.phase=="ON_FOOT" and not t._e_down,"actual E closes window without seat/lid fallthrough")
	Input.parse_input_event(key(KEY_E));await step()
	check(c.window_open,"actual E reopens list through input routing")
	var ammo:int=w.fire_state.magazine;var shot_count:int=w.shots_count
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	check(w.input_event(click),"modal consumes unhandled fire button");w.advance(1.0/60.0)
	check(w.fire_state.magazine==ammo and w.shots_count==shot_count,"no fire/no spent round while modal")
	Input.action_press(p.ACTION_JUMP);w.input_event(key(KEY_SPACE));await step(2)
	check(p._jump.is_empty() and not Input.is_action_pressed(p.ACTION_JUMP),"modal SPACE action cannot jump")
	var originals:Dictionary={}
	for id:String in load("res://scripts/weapons/weapon_fire.gd").ids():
		c.close_window();check(w.equip(id).get("ok",false),"equip source item "+id)
		originals[id]={"uid":w.inventory.get_item_uid(id),"magazine":int(w.fire_state.magazine),"reserve":int(w.fire_state.reserveAmmo)}
		check(c.open_window(),"open contents for store "+id)
		var stored:Dictionary=c.window_store();check(stored.get("ok",false),"real paired store "+id+" "+str(stored.get("reason","")))
	var full:Dictionary=c.cargo.snapshot(c.generation)
	check(full.items.size()==14 and full.used_units==100 and w.inventory.get_owned_ids().is_empty(),"all14 exact UID source items fill100")
	check(c._window.cards.size()==14 and c._window.summary.text.contains("Свободно 0"),"14 visible large cards and exact free capacity")
	var layout_ok:=true
	for card:Dictionary in c._window.cards.values():layout_ok=layout_ok and card.panel.custom_minimum_size.x>=190 and card.button.custom_minimum_size.y>=40
	check(layout_ok,"large cards and forty-pixel take buttons")
	for id:String in originals:
		var record:Dictionary=originals[id]
		check(c._window.cards.has(record.uid),"card bound exact UID "+id)
		c._window.cards[record.uid].button.pressed.emit()
		check(w.fire_state.weaponId==id and w.inventory.get_item_uid(id)==record.uid,"button takes exact UID and equips "+id)
		check(w.fire_state.magazine==record.magazine and w.fire_state.reserveAmmo==record.reserve,"same finite ammo "+id)
		var owned:Dictionary=w.inventory.snapshot()
		check(not c.window_take(record.uid).get("ok",false) and w.inventory.snapshot()==owned,"stale sameUID cannot duplicate "+id)
		check(c.window_store().get("ok",false),"roundtrip exactitem "+id)
	check(c.cargo.snapshot(c.generation).used_units==100,"all14 roundtrip capacity retained")
	w.input_event(key(KEY_Q));check(not c.window_open and not w.menu_open,"Q closes trunk without competing arsenal")
	check(c.open_window(),"reopen valid original access")
	w.set_menu(true);check(w.menu_open and not c.window_open,"arsenal opener closes cargo modal")
	w.set_menu(false);check(c.open_window(),"cargo reopens after arsenal")
	w.input_event(key(KEY_ESCAPE));check(not c.window_open and not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Esc closes window and frees cursor")
	p._free_mouse_look=true;check(c.open_window(),"reopen after explicit reacquire")
	var still:Dictionary=c.cargo.snapshot(c.generation)
	t.compartments.set_open("trunk",false);c._process(0)
	check(not c.window_open and not c.window_take(originals.tt_pistol.uid).get("ok",false),"closed lid invalidates window and stale callback")
	check(c.cargo.snapshot(c.generation).items==still.items,"closed stale call preserves contents")
	t.compartments.set_open("trunk",true);await step(100)
	check(c.open_window(),"fully open access restored")
	p.set_mouse_captured(false)
	check(not c.window_open and not w.controls_blocked(),"blur/release closes modal owner")
	p._free_mouse_look=true
	var velocity:Vector3=t.body.linear_velocity;t.body.linear_velocity=Vector3(.7,0,0)
	check(not c.open_window(),"moving car cannot open contents");t.body.linear_velocity=velocity
	var profile:Dictionary=t.compartments.access_profile("trunk")
	var end:Vector3=t.body.to_global(profile.position_local_m+profile.outward_local*.12)
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.35,2,.35);shape.shape=box;wall.add_child(shape);scene.add_child(wall);wall.global_position=(p.global_position+Vector3.UP*.9+end)*.5
	await step(2)
	check(not c.open_window(),"real world obstacle blocks near-window access")
	wall.queue_free();await step(2)
	check(c.open_window(),"access revalidates after blocker removed")
	p.global_position+=Vector3(10,0,0);c._refresh=0;c._process(.2)
	check(not c.window_open,"leaving rear range closes modal")
	print("TRUNK_WINDOW_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"scope":"actual hatchback/inventory/cargo/14UID+ammo+UI buttons; source scene headless, no visual/GPU/perf claim"}))
	scene.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
