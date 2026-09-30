extends SceneTree
## Headless behavior reproduction only. Original camera remains under original arm.
## No camera reparent/top_level, collider removal, actor/HP/ammo replacement or pick override.
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var camera:Camera3D
var out:=""
var begun:=0
var done:=false
var report:Dictionary={"checks":0,"errors":[],"fixture_search":[],"scope":"Original loaded main and attached spring arm; actual native RMB then E input. Headless behavior only, not OS focus, GPU or performance acceptance."}

func _initialize()->void:
	begun=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
	run.call_deferred()
func _process(_delta:float)->bool:
	if not done and Time.get_ticks_msec()-begun>40000:
		check(false,"40s internal deadline");finish()
	return false
func check(value:bool,label:String)->bool:
	report.checks+=1
	if not value:report.errors.append(label);print("FAIL ",label)
	return value
func step(count:int=1)->void:
	for index:int in count:
		if done:return
		await physics_frame;await process_frame
func key(code:int,down:bool)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func right_button(down:bool)->void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=down
	event.position=root.get_visible_rect().size*.5;event.global_position=event.position
	event.button_mask=MOUSE_BUTTON_MASK_RIGHT if down else 0
	Input.parse_input_event(event);Input.flush_buffered_events()
func view_state()->Dictionary:
	return {"camera_world":str(camera.global_transform),"fov":camera.fov,"arm_position":str(p._spring_arm.position),"arm_length":p._spring_arm.spring_length,"yaw":p._camera_yaw,"pitch":p._camera_pitch,"aiming":w._aiming,"aim_blend":w.aim_camera._blend,"parent_original":camera.get_parent()==p._spring_arm,"top_level":camera.top_level,"free_mouse":p._free_mouse_look,"modal":c.window_open,"menu":w.menu_open,"pose":str(p._pose_authority),"frame":Engine.get_process_frames()}
func contents_have(uid:String)->bool:
	for entry:Dictionary in c.cargo.snapshot(c.generation).items:
		if entry.item.uid==uid:return true
	return false
func original_scene()->Dictionary:
	return {"npc":scene.preview_population.residents.occupants().size(),"buildings":scene._block.counts.buildings,"bodies":scene.find_children("*","CollisionObject3D",true,false).size(),"shapes":scene.find_children("*","CollisionShape3D",true,false).size()}
func aim_at_world_point(point:Vector3)->void:
	# Solve the ordinary yaw/pitch controls around the actual .75m shoulder offset.
	# Spring collision changes distance along the same ray and stays enabled.
	var delta:Vector3=point-p._yaw_pivot.global_position-Vector3.UP*p._spring_arm.position.y
	var horizontal:=Vector2(delta.x,delta.z).length()
	if horizontal<=absf(p._spring_arm.position.x)+.01:return
	var yaw:=atan2(-delta.x,-delta.z)+asin(clampf(p._spring_arm.position.x/horizontal,-1,1))
	var local:Vector3=Basis(Vector3.UP,yaw).inverse()*delta
	p._camera_yaw=yaw
	p._camera_pitch=clampf(atan2(local.y,-local.z),-PI*.5+.0001,PI*.42)
	p._update_camera_rotation()
func find_attached_aim(uid:String)->bool:
	var access:Dictionary=t.compartments.access_profile("trunk")
	var row:Dictionary=c.renderer._trunks[c.vehicle_id].items[uid]
	var points:Array[Vector3]=[]
	for part:Dictionary in row.parts:
		if part.visible:
			points.append(row.visual.global_transform*part.transform*part.mesh.get_aabb().get_center())
			if points.size()>=8:break
	for outward:float in [.9,1.25,1.55]:
		for lateral:float in [0.0,-.5,.5]:
			if done:return false
			p.global_position=t.body.to_global(access.position_local_m+access.outward_local*outward+Vector3.RIGHT*lateral)
			p.global_position.y=.01
			await step(5)
			for point:Vector3 in points:
				for correction:int in 3:
					aim_at_world_point(point);await step(3)
				if done:return false
				var context:Dictionary=c.aim_context()
				if str(context.item_uid)==uid and w._aiming and w.aim_camera._blend>.8:
					report.fixture_search.append({"outward":outward,"lateral":lateral,"point":str(point),"context":context,"view":view_state()})
					return true
			report.fixture_search.append({"outward":outward,"lateral":lateral,"access":c._window_access(),"position":str(p.global_position),"picked":c.aim_context().item_uid})
	return false
func run()->void:
	report.compiled_scripts={}
	for path:String in ["res://scripts/main.gd", "res://scripts/preview_player.gd", "res://scripts/preview_transport.gd", "res://scripts/weapons/preview_weapons.gd", "res://scripts/weapons/preview_weapon_cargo.gd", "res://scripts/weapons/player_weapon_presentation.gd", "res://scripts/weapons/weapon_aim_camera.gd", "res://scripts/weapons/weapon_inventory.gd", "res://scripts/weapons/weapon_cargo_bridge.gd", "res://scripts/weapons/cargo_aim_picker.gd", "res://scripts/weapons/weapon_pickup_visuals.gd", "res://scripts/weapons/walk_trunk_window.gd"]:
		var script:Script=load(path)
		var compiled:bool=script!=null and not script.has_source_code()
		report.compiled_scripts[path]=compiled
		if not check(compiled,"exact compiled runtime: "+path):finish();return
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for index:int in 240:
		await step()
		if done:return
		if scene.preview_ready and scene.preview_population!=null and scene.preview_population.residents!=null and scene.preview_population.residents.occupants().size()==3:break
	if not check(scene.preview_ready,"actual main ready"):finish();return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo");camera=p.get_preview_camera()
	p.set_mouse_captured(true);await step(60)
	if done:return
	report.scene_before=original_scene()
	if not check(report.scene_before.npc==3 and report.scene_before.buildings==8 and report.scene_before.bodies==377 and report.scene_before.shapes==377,"all original loaded scene retained"):finish();return
	if not check(camera.get_parent()==p._spring_arm and not camera.top_level,"original camera hierarchy untouched"):finish();return
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	await step(5)
	t.compartments.set_open("trunk",true);await step(100)
	if not check(w.equip("tt_pistol").get("ok",false),"real TT equipped"):finish();return
	var uid:String=w.inventory.get_item_uid("tt_pistol")
	var mag:int=w.fire_state.magazine;var reserve:int=w.fire_state.reserveAmmo
	if not check(c.open_window(),"actual access allows modal fixture store"):finish();return
	if not check(c.window_store().get("ok",false),"real TT ownership stored"):finish();return
	c.close_window();await step(2)
	if not check(w.equip("ak74").get("ok",false),"real AK held to activate source RMB camera"):finish();return
	var held_uid:String=w.inventory.get_item_uid("ak74")
	var held_mag:int=w.fire_state.magazine;var held_reserve:int=w.fire_state.reserveAmmo
	right_button(true);await step(35)
	if not check(w._aiming and w.aim_camera._blend>.8,"actual RMB entered ordinary attached aim camera"):finish();return
	var found:bool=await find_attached_aim(uid)
	if done:return
	if not check(found,"actual attached aim camera selects stored TT via original geometry"):finish();return
	var inventory_before:Dictionary=w.inventory.snapshot()
	var cargo_before:Dictionary=c.cargo.snapshot(c.generation)
	var context_before:Dictionary=c.aim_context()
	var before_world:Transform3D=camera.global_transform
	report.before={"view":view_state(),"context":context_before,"tt_uid":uid,"ak_uid":held_uid,"tt_ammo":[mag,reserve],"inventory":inventory_before,"cargo":cargo_before}
	if not check(context_before.item_uid==uid and not c.window_open and not w.menu_open,"exact displayed selection remains direct world E"):finish();return
	var started:=Time.get_ticks_usec()
	key(KEY_E,true)
	report.e_dispatch_us=Time.get_ticks_usec()-started
	var took:bool=w.inventory.get_item_uid("tt_pistol")==uid and w.fire_state.weaponId=="tt_pistol" and not contents_have(uid)
	report.after_event={"view":view_state(),"context":c.aim_context(),"took_exact_uid":took,"camera_changed_in_dispatch":camera.global_transform!=before_world,"cargo_still_has_uid":contents_have(uid),"inventory":w.inventory.snapshot(),"cargo":c.cargo.snapshot(c.generation),"feedback":c._feedback}
	check(took,"single native E takes originally aimed exact TT UID")
	if took:
		check(w.fire_state.magazine==mag and w.fire_state.reserveAmmo==reserve,"taken TT finite ammunition unchanged")
		check(w.inventory.get_item_uid("ak74")==held_uid and w.inventory.get_fire_state("ak74").magazine==held_mag and w.inventory.get_fire_state("ak74").reserveAmmo==held_reserve,"previous AK UID and ammunition retained")
	else:
		check(w.inventory.snapshot()==inventory_before and c.cargo.snapshot(c.generation)==cargo_before,"refused baseline transfer keeps exact ownership/ammo")
	check(p._free_mouse_look and not w.controls_blocked() and w.shots_count==0,"E never suspends controls or leaks a shot")
	key(KEY_E,false);right_button(false);await step(20)
	if done:return
	report.after_settle={"view":view_state(),"scene":original_scene()}
	check(not w._aiming and w.aim_camera._blend<.01,"eventual ordinary camera state restored after transfer/released RMB")
	check(original_scene()==report.scene_before,"no original scene content removed")
	finish()
func finish()->void:
	if done:return
	done=true;report.valid=report.errors.is_empty();report.seconds=(Time.get_ticks_msec()-begun)/1000.0
	if not out.is_empty():
		var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ATTACHED_AIM_TAKE_RESULT ",JSON.stringify(report))
	if is_instance_valid(scene):scene.queue_free()
	quit.call_deferred(0 if report.valid else 1)
