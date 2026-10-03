extends SceneTree
const Restore=preload("restore.gd")
const Checkpoint=preload("checkpoint.gd")
var scene:Node3D
var p:CharacterBody3D
var w:Node
var t:Node3D
var c:Node
var out:=""
var phase:=""
var save_path:=""
var digest:=""
var grant:=""
var checks:=0
var errors:Array[String]=[]
var done:=false
var details:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->bool:
	checks+=1
	if not value:errors.append(label);print("FAIL ",label)
	return value
func tick(n:int=1)->void:
	for i:int in n:await physics_frame;await process_frame
func key(code:int)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
		Input.parse_input_event(e);Input.flush_buffered_events()
func shoot()->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	Input.parse_input_event(e);Input.flush_buffered_events();await tick(2)
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false
	Input.parse_input_event(e);Input.flush_buffered_events()
	for i:int in 180:
		await tick()
		if Checkpoint.capture(scene).ok:break
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
		if arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
		if arg.begins_with("--save="):save_path=arg.trim_prefix("--save=")
		if arg.begins_with("--trusted-digest="):digest=arg.trim_prefix("--trusted-digest=")
		if arg.begins_with("--grant="):grant=arg.trim_prefix("--grant=")
	if out.is_empty():quit(2);return
	create_timer(65).timeout.connect(func():
		if not done:check(false,"65s watchdog");finish())
	if phase=="save":await save_process()
	elif phase=="restore":await restore_process()
	else:check(false,"unknown phase")
	finish()
func load_scene(staged:bool)->bool:
	scene=load("res://scenes/main.tscn").instantiate()
	if staged:scene.process_mode=Node.PROCESS_MODE_DISABLED;scene.visible=false
	root.add_child(scene);current_scene=scene
	for i:int in 180:
		await tick()
		if scene.get_meta("local_restore_staged",false) if staged else scene.preview_ready:break
	if not check(bool(scene.get_meta("local_restore_staged",false)) if staged else scene.preview_ready,"actual native48 scene startup"):return false
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	check(scene.preview_population.hit_owners.size()==3,"three original NPC still present; HP outside restored domain")
	return true
func save_process()->void:
	if not await load_scene(false):return
	p.set_mouse_captured(true);await tick(30)
	check(w.equip("tt_pistol").ok,"real TT equip");await tick(2)
	var initial:=Checkpoint.capture(scene)
	if not check(initial.ok,"initial coherent capture"):return
	await shoot()
	check(w.fire_state.magazine==11 and w.fire_state.sequence==1,"real TT consumes exactly one bullet")
	var dropped:Dictionary=c.drop_held()
	if not check(dropped.ok,"native drop TT"):return
	await tick(15)
	check(c.pickup_ground(dropped.drop.uid).ok,"native pickup preserves TT UID")
	check(w.equip("nagan").ok,"native nagan equip")
	await tick(2)
	check(c.drop_held().ok,"native ground nagan retained in save")
	check(w.equip("tt_pistol").ok,"native TT equip for cargo")
	var access:Dictionary=t.compartments.access_profile("trunk")
	var setup:Vector3=t.body.to_global(access.position_local_m+access.outward_local*.9)
	var ray:=PhysicsRayQueryParameters3D.create(setup+Vector3.UP*2,setup-Vector3.UP*3,1,[p.get_rid(),t.body.get_rid()])
	var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
	if not check(not hit.is_empty(),"rear native ground"):return
	setup.y=hit.position.y+.02;p.global_position=setup # Declared QA access placement, not a saved player pose.
	t.compartments.set_open("trunk",true);await tick(100)
	if not check(c._window_access(),"rear access to actual trunk"):return
	key(KEY_F);await tick(2);key(KEY_G);await tick(2)
	check(c.cargo.snapshot(c.generation).items.size()==1,"real F/G puts TT in cargo")
	c.close_window(false)
	check(w.equip("ak74").ok,"native AK equipped for exact active reload preservation")
	await tick(2);await shoot()
	key(KEY_R);await tick(2)
	check(w.fire_state.reloadRemaining>0,"actual native reload active at save boundary")
	# Freeze this component fixture before read-only export, including native timers.
	scene.process_mode=Node.PROCESS_MODE_DISABLED
	var before:=Checkpoint._state(Checkpoint._owners(scene))
	var saved:=Restore.capture(scene)
	if not check(saved.ok,"strict capture: "+str(saved.get("reason",""))):return
	check(Checkpoint.canonical(before)==Checkpoint.canonical(Checkpoint._state(Checkpoint._owners(scene))),"export changes no native ownership/state")
	var validated:=Restore.validate(saved.document)
	check(validated.items==14 and validated.ammo_total==894,"all14 UIDs, two spent bullets remain spent")
	check(saved.document.checkpoint.inventory.ownedIds.size()==12 and saved.document.checkpoint.inventory.dropped.size()==1 and saved.document.checkpoint.vehicles[0].items.size()==1,"12 owned + 1 ground + 1 cargo")
	var decoded:=Restore.decode(saved.text)
	check(decoded.ok and Checkpoint.canonical(decoded.document)==Checkpoint.canonical(saved.document),"canonical exact saved roundtrip")
	FileAccess.open(out.path_join("save.json"),FileAccess.WRITE).store_string(saved.text)
	details={"save_sha256":saved.text.sha256_text(),"items":validated.items,"ammo_total":validated.ammo_total,"locations":validated.locations,"host_fire_state":saved.document.checkpoint.inventory.host_fire_state,"session":saved.document.checkpoint.session,"inventory_minted":w.inventory.local_restore_minted}
func restore_process()->void:
	var text:String=FileAccess.get_file_as_string(save_path)
	var invalid:=Restore.new()
	check(not invalid.admit(text.substr(0,text.length()-1),digest,grant).ok,"truncated bytes rejected before scene")
	invalid=Restore.new()
	check(not invalid.admit(text.replace('"LOCAL_OFFLINE_FREEZE"','"SERVER_ACK"'),digest,grant).ok,"corruption rejected before scene")
	var decoded:=Restore.decode(text)
	if not check(decoded.ok,"parent pinned save canonical decode"):return
	var original:Dictionary=decoded.document
	for kind:String in ["extra_fire","none_extra","pending","duplicate","missing_owner","stale_vehicle","server"]:
		var changed:Dictionary=original.duplicate(true)
		match kind:
			"extra_fire":changed.checkpoint.inventory.fireStates.ak74["unvalidated_extension"]=1
			"none_extra":changed.checkpoint.inventory.host_fire_state["unvalidated_extension"]=1
			"pending":changed.checkpoint.pending_transactions=[{"id":"uncertain"}]
			"duplicate":changed.checkpoint.inventory.identities.owned.revolver=changed.checkpoint.inventory.identities.owned.ak74
			"missing_owner":changed.checkpoint.actor={}
			"stale_vehicle":changed.transport.life_generation+=1
			"server":changed.checkpoint.authority="server_acknowledged"
		check(not Restore.validate(changed).ok,"strict validation denies "+kind)
	var coordinator:=Restore.new()
	var admitted:Dictionary=coordinator.admit(text,digest,grant)
	if not check(admitted.ok,"external parent provenance grants one attempt"):return
	check(not coordinator.admit(text,digest,grant).ok,"same coordinator replay rejected")
	root.set_meta("private_restore49",coordinator)
	if not await load_scene(true):return
	check(not scene.preview_ready,"staged graph unpublished before commit")
	check(w.inventory.get_owned_ids().is_empty() and w.inventory.local_restore_minted==0 and c.cargo.snapshot(c.generation).items.is_empty(),"no duplicate default arsenal bootstrap")
	check(t.get_meta("local_restore_without_factory",false) and t.runtime.bootstrap._issued.is_empty(),"resume bypasses vehicle new-session factory")
	check(not w.inventory.prepare_local_restore(coordinator,RefCounted.new(),original.checkpoint.inventory).ok,"forged owner capability rejected without adoption")
	var applied:Dictionary=coordinator.commit(scene)
	if not check(applied.ok,"all owners commit: "+str(applied)):return
	check(not coordinator.commit(scene).ok,"committed coordinator cannot replay")
	var after:=Checkpoint.capture(scene)
	if not check(after.ok,"restored native capture: "+str(after.get("reason",""))):return
	var expected:Dictionary=original.checkpoint
	check(Checkpoint.canonical(after.document.inventory)==Checkpoint.canonical(expected.inventory),"every owned/ground UID, serial, finite ammo, exact active fire state preserved")
	check(Checkpoint.canonical(after.document.vehicles)==Checkpoint.canonical(expected.vehicles),"cargo UID/owner/life/revision/geometry preserved")
	check(after.document.session==expected.session and after.document.actor==expected.actor,"explicit local session and logical owner domain preserved")
	check(OS.get_process_id()!=int(original.source_process),"fresh process owns new native instances")
	check(w.inventory.local_restore_minted==0,"zero item UID regeneration during restore")
	check(w.fire_state.reloadRemaining==expected.inventory.host_fire_state.reloadRemaining,"reload freezes across offline interval")
	var remaining_before:float=expected.inventory.dropped[0].expiresAt-expected.capture.mono_ms
	var remaining_after:float=after.document.inventory.dropped[0].expiresAt-after.document.capture.mono_ms
	check(remaining_after<=remaining_before and remaining_before-remaining_after<100,"offline ground TTL frozen; only postcommit local time elapsed")
	check(c.renderer.debug_snapshot().ground.size()==1,"restored ground visual attached to new world")
	details={"adoption":applied,"items":Checkpoint.validate(after.document).items,"ammo_total":Checkpoint.validate(after.document).ammo_total,"remaining_before_ms":remaining_before,"remaining_after_ms":remaining_after,"host_fire_state":w.fire_state.duplicate(true),"session":after.document.session,"new_player_native_id":p.get_instance_id(),"new_vehicle_native_id":t.body.get_instance_id()}
	# The resumed owners must also remain usable after the synchronous boundary.
	scene.visible=true;scene.process_mode=Node.PROCESS_MODE_INHERIT
	await tick(3)
	check(w.fire_state.reloadRemaining<expected.inventory.host_fire_state.reloadRemaining,"fresh process resumes normal native reload progression")
	check(w.inventory.item_identity_snapshot()==expected.inventory.identities,"first live ticks preserve all item identities")
func finish()->void:
	if done:return
	done=true
	var result:Dictionary={"passed":errors.is_empty(),"checks":checks,"errors":errors,"phase":phase,"process_id":OS.get_process_id(),"performance_accepted":false}
	result.merge(details)
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t",true,true))
	if is_instance_valid(scene):scene.queue_free()
	await process_frame
	print("RESTORE49_RESULT ",JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
