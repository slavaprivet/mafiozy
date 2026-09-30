extends SceneTree
var checks:=0
var errors:Array[String]=[]
var hover_us:Array[int]=[]
var old_us:Array[int]=[]
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var camera:Camera3D
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func key(code:int,pressed:bool=true)->InputEventKey:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;return e
func refresh()->void:c._refresh=0;c._process(0)
func aim(uid:String)->bool:
	var row:Dictionary=c.renderer._trunks[c.vehicle_id].items[uid]
	var access:Dictionary=t.compartments.access_profile("trunk")
	camera.global_position=t.body.to_global(access.position_local_m+access.outward_local*1.5)+Vector3.UP*.7
	for part:Dictionary in row.parts:
		if not part.visible:continue
		var faces:PackedVector3Array=part.mesh.get_faces()
		for face:int in range(0,faces.size(),3):
			var point:Vector3=row.visual.global_transform*part.transform*((faces[face]+faces[face+1]+faces[face+2])/3.0)
			camera.look_at(point,Vector3.UP)
			if c.aim_context().item_uid==uid:return true
	return false
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_residents_enabled=false;root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"actual main ready")
	if not scene.preview_ready:quit(1);return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p._free_mouse_look=true;await step(60)
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	await step(5)
	camera=p.get_preview_camera();camera.top_level=true
	t.compartments.set_open("trunk",true);await step(100)
	var bounds:Dictionary=t.compartments.cargo_bounds()
	camera.global_position=p.global_position+Vector3.UP*2;camera.look_at(t.visual.root.to_global((bounds.min+bounds.max)*.5),Vector3.UP)
	var originals:Dictionary={}
	for id:String in load("res://scripts/weapons/weapon_fire.gd").ids():
		check(w.equip(id).get("ok",false),"real equip "+id)
		originals[id]={"uid":w.inventory.get_item_uid(id),"magazine":w.fire_state.magazine,"reserve":w.fire_state.reserveAmmo}
		check(c.store_held().get("ok",false),"paired real store "+id)
	check(c.cargo.snapshot(c.generation).items.size()==14,"14 actual stored originals")
	var builds:int=c.renderer.debug_snapshot().geometry_builds
	for id:String in ["tt_pistol","nagan","ak74"]:
		var uid:String=originals[id].uid
		check(aim(uid),"real triangle camera aim "+id)
		var context:Dictionary=c.aim_context();refresh()
		check(context.item_uid==uid,"fresh context selects exact UID "+id)
		var hover:Dictionary=c.renderer.hover_snapshot()
		check(hover.get("active",false) and hover.get("item_uid")==uid and hover.get("parts",0)>0 and hover.get("depth_test",false),"native hint applies depth-tested hover "+id)
		var before:Dictionary=w.inventory.snapshot();var cargo_before:Dictionary=c.cargo.snapshot(c.generation)
		for i in 30:refresh()
		check(before==w.inventory.snapshot() and cargo_before==c.cargo.snapshot(c.generation),"hover cannot mutate ownership or ammunition "+id)
		Input.parse_input_event(key(KEY_E));await step();Input.parse_input_event(key(KEY_E,false));await step()
		check(not c.window_open and w.inventory.get_item_uid(id)==uid and w.fire_state.weaponId==id,"native player E gets hovered exact item without modal "+id)
		check(w.fire_state.magazine==originals[id].magazine and w.fire_state.reserveAmmo==originals[id].reserve,"native E preserves finite original ammo "+id)
		check(not c.renderer.hover_snapshot().get("active",false),"taken model clears hover "+id)
		check(not c.take_item(uid).get("ok",false),"stale UID cannot duplicate "+id)
		check(c.store_held().get("ok",false),"same UID re-store "+id)
	var uid:String=originals.tt_pistol.uid
	check(aim(uid),"small pistol reaim")
	var center:=camera.get_viewport().get_visible_rect().size*.5
	var assist_found:=false;var max_rays:=0
	# Search fixture pixels around the actual visible pistol boundary. A fixed
	# offset can still intersect its barrel directly; require a true assisted hit.
	for radius:float in [8.0,14.0,20.0,28.0,40.0,56.0,80.0]:
		for index:int in 16:
			var offset:=Vector2(cos(TAU*index/16.0),sin(TAU*index/16.0))*radius
			var hit:Dictionary=c._cargo_picker.pick(camera,center+offset*camera.get_viewport().get_visible_rect().size.y/720.0)
			max_rays=maxi(max_rays,c._cargo_picker.last_stats.rays)
			if hit.get("item_uid")==uid and hit.get("screen_assist_pixels",0)>.25:
				assist_found=true
				check(float(hit.screen_assist_pixels)<=18.0*camera.get_viewport().get_visible_rect().size.y/720.0+.001,"assist remains within18pixel screen radius")
				print("ASSIST_EVIDENCE ",JSON.stringify({"offset":str(offset),"pixels":hit.screen_assist_pixels,"uid":hit.item_uid,"point":str(hit.point),"stats":c._cargo_picker.last_stats}))
				break
		if assist_found:break
	check(assist_found,"bounded screen assist reaches real tiny pistol when center ray misses")
	check(max_rays<=25,"bounded probe cap")
	var old_picker:RefCounted=load(get_script().resource_path.get_base_dir().path_join("old_picker.gd")).new()
	old_picker.configure(c.renderer,t.visual.root,c._cargo_picker._options,Callable(c,"_cargo_ray_clear"))
	for repeat:int in 120:
		var started:=Time.get_ticks_usec();old_picker.pick(camera);old_us.append(Time.get_ticks_usec()-started)
	old_us.sort()
	for repeat:int in 120:
		var started:=Time.get_ticks_usec();c._cargo_picker.pick(camera);hover_us.append(Time.get_ticks_usec()-started)
	hover_us.sort()
	check(not c._cargo_picker.pick(camera,Vector2(-50,20)).get("hit",false),"outside viewport refuses selection")
	refresh();var row:Dictionary=c.renderer._trunks[c.vehicle_id].items[uid]
	var overrides:Array=[]
	for part:Dictionary in row.parts:overrides.append(part.node.get_ref().material_overlay)
	camera.look_at(camera.global_position+Vector3.RIGHT*20,Vector3.UP);refresh()
	check(not c.renderer.hover_snapshot().get("active",false),"aim away clears hover")
	for part:Dictionary in row.parts:check(part.node.get_ref().material_overlay==null,"original material restored")
	check(aim(uid),"reaim before wall")
	var hit:Dictionary=c.aim_context()
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2,2,.12);collision.shape=shape;wall.add_child(collision);scene.add_child(wall)
	wall.global_position=camera.global_position.lerp(hit.point,.5);wall.look_at(hit.point,Vector3.UP)
	await step(3);refresh()
	check(c.aim_context().item_uid.is_empty() and not c.renderer.hover_snapshot().get("active",false),"physical wall blocks selection and highlight")
	wall.queue_free();await step(3);check(aim(uid),"aim recovers after physical blocker removal");refresh()
	w.set_menu(true);c._process(0);check(not c.renderer.hover_snapshot().get("active",false),"arsenal clears highlight immediately");w.set_menu(false)
	check(aim(uid),"reaim after menu");refresh()
	t.compartments.set_open("trunk",false);c._process(0)
	check(c.aim_context().item_uid.is_empty() and not c.renderer.hover_snapshot().get("active",false),"lid close clears and rejects items")
	t.compartments.set_open("trunk",true);await step(100);check(aim(uid),"reaim after lid");refresh()
	p.set_mouse_captured(false);c._process(0);check(not c.renderer.hover_snapshot().get("active",false),"focus/control release clears hover")
	p._free_mouse_look=true;check(aim(uid),"reaim after control return");refresh();p.global_position+=Vector3(10,0,0);refresh()
	check(not c.renderer.hover_snapshot().get("active",false),"leave range clears hover")
	check(c.renderer.debug_snapshot().geometry_builds==builds,"all repeated hover and transfers reuse existing BVHs")
	check(c.cargo.snapshot(c.generation).items.size()==14,"all originals remain stored after checks")
	print("CARGO_HOVER_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"max_probe_rays":max_rays,"old_picker_headless_us":{"p50":old_us[60],"p95":old_us[114],"max":old_us[-1]},"picker_headless_us":{"p50":hover_us[60],"p95":hover_us[114],"max":hover_us[-1]},"scope":"headless actual main, all14 real stored items, native E event, fixtures reposition player/camera only; no GPU or camera parity/performance claim"}))
	scene.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
