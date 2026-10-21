extends SceneTree
## CPU actual-main regression. No OS/GPU input, network authority or fake hits.
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
var checks:=0
var failures:Array[String]=[]
var scene:Node3D
var actor:CharacterBody3D
var host:Node
var notifications:Array[Dictionary]=[]
var interrupt_kind:=""
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func mouse(pressed:bool)->InputEventMouseButton:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;return event
func receive(shot:Dictionary,muzzle:Dictionary,_origin:Vector3,_direction:Vector3)->void:
	notifications.append({"shot":shot.duplicate(true),"muzzle":muzzle.duplicate(true),"fx_count":host.effects.stats().totalShots})
	if notifications.size()==1:
		if interrupt_kind=="epoch":actor.set_preview_pose_authority(&"vehicle",true)
		elif interrupt_kind=="queue_free":host.queue_free()
func pose()->void:actor._update_owned_pose(.016)
func press()->void:actor._unhandled_input(mouse(true))
func release()->void:actor._unhandled_input(mouse(false));host.cancel_inputs()
func check_reload_inventory()->void:
	# The actual preceding pistol shot left a partial magazine. Route real R.
	var before:Dictionary=host.fire_state.duplicate(true)
	var event:=InputEventKey.new();event.physical_keycode=KEY_R;event.keycode=KEY_R;event.pressed=true;actor._unhandled_input(event)
	var source:Dictionary=Fire.step(before,{"reload":true},.1)
	check(source.state.cooldown<0 and source.state.reloadRemaining>0,"raw source reload early return has expired negative cooldown")
	host.advance(.1);pose()
	check(host.fire_state.cooldown>=0 and host.fire_state.reloadRemaining>0,"host canonical cooldown is nonnegative during reload")
	check(host.fire_state==host.inventory.snapshot().fireStates.tt_pistol,"actual R keeps full host/inventory state equal")
	check(host.fire_state==host._inventory_state(source.state),"only source expired cooldown is canonicalized")
	for i in 3:
		host.advance(.1);pose()
		check(host.fire_state==host.inventory.snapshot().fireStates.tt_pistol and host.fire_state.cooldown>=0,"ongoing reload persists identically "+str(i))
	var current:Dictionary=host.fire_state.duplicate(true);var effects_before:int=host.effects.stats().totalShots
	var reservation:Dictionary=host.inventory.begin_cargo_export(host.fire_state)
	check(reservation.get("ok",false),"reload state admits real cargo export reservation")
	host.advance(.1);pose()
	check(host.fire_state==current,"failed non-shot inventory update cannot advance host state alone")
	check(host.inventory.snapshot().fireStates.tt_pistol==current and host.effects.stats().totalShots==effects_before,"failed non-shot update preserves inventory and effects")
	if reservation.get("ok",false):host.inventory.cancel_cargo_transfer(reservation.token)
	check(host.equip("ak74").ok,"equip during reload accepts canonical inventory state")
	var stored:Dictionary=host.inventory.snapshot().fireStates.tt_pistol
	check(stored.magazine==current.magazine and stored.reserveAmmo==current.reserveAmmo and stored.reloadRemaining==0,"source stow cancels reload without loading or losing rounds")
	check(host.equip("tt_pistol").ok and host.fire_state==stored,"re-equipping interrupted reload preserves exact stowed state")
	# All14 original Fire profiles: compare full next-step states and shots, not
	# only ammo, from raw overdue reload cooldown and its persistent equivalent.
	for id:String in Fire.ids():
		var fired:Dictionary=Fire.step(Fire.create_state(id),{"triggerPressed":true},0)
		var raw:Dictionary=Fire.step(fired.state,{"reload":true},0).state
		var guard:=0
		while raw.cooldown>=0 and guard<50:
			raw=Fire.step(raw,{},.1).state;guard+=1
		check(raw.cooldown<0,"source overdue reload reached "+id)
		var canonical:Dictionary=host._inventory_state(raw)
		for delta:float in [0.0,.016,.1,2.0]:
			for input:Dictionary in [{},{"triggerHeld":true,"triggerPressed":true}]:
				check(Fire.step(raw,input,delta)==Fire.step(canonical,input,delta),"raw/canonical next complete state and shots "+id+":"+str(delta)+":"+str(input.size()))
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_residents_enabled=false;scene.preview_weapons_enabled=true;root.add_child(scene)
	var waits:=0
	while not scene.preview_ready and waits<600:waits+=1;await physics_frame
	check(scene.preview_ready,"main ready within watchdog")
	if not scene.preview_ready:scene.free();finish();return
	actor=scene._player;host=scene.preview_weapons;actor.set_mouse_captured(true);host.shot_emitted.connect(receive)
	for i in 8:await physics_frame
	check(host.equip("tt_pistol").ok,"real inventory/model equipped")
	host.advance(.016);pose();var start_ammo:int=host.fire_state.magazine
	press();host.advance(0);pose();host.advance(.5);pose();press();host.advance(0);pose()
	check(notifications.size()==1 and host.fire_state.magazine==start_ammo-1,"duplicate pressed mouse cannot retrigger semi")
	release();notifications.clear()
	check_reload_inventory();notifications.clear()
	var life:int=actor.get_meta("life_generation");actor.set_meta("life_generation",life+1)
	start_ammo=host.fire_state.magazine;host.advance(.5);press();host.advance(0);pose()
	check(host.fire_state.magazine==start_ammo and notifications.is_empty(),"stale target life cannot consume round")
	actor.set_meta("life_generation",life);release();check(host.equip("ak74").ok,"restore live presentation")
	host.advance(.016);pose();start_ammo=host.fire_state.magazine
	press();host.advance(.3)
	check(host.fire_state.magazine==start_ammo,"proposal does not consume authoritative ammo before pose")
	host.cancel_inputs();pose()
	check(host.fire_state.magazine==start_ammo and notifications.is_empty(),"cancelled candidate preserves rounds")
	# Real inventory reservation excludes mutation; failed commit cannot emit FX.
	var reserved:Dictionary=host.inventory.begin_cargo_export(host.fire_state)
	check(reserved.get("ok",false),"actual item export reservation")
	var effects_before:int=host.effects.stats().totalShots
	press();host.advance(.3);pose()
	check(host.fire_state.magazine==start_ammo and host.effects.stats().totalShots==effects_before,"failed inventory commit cannot spend or emit")
	if reserved.get("ok",false):host.inventory.cancel_cargo_transfer(reserved.token)
	release()
	# A pending candidate may not replace a subsequently equipped item.
	press();host.advance(.3);check(host.equip("tt_pistol").ok,"equip while old candidate pending")
	pose();check(host.fire_state.weaponId=="tt_pistol" and notifications.is_empty(),"old candidate cannot overwrite new weapon")
	check(host.equip("ak74").ok and host.fire_state.magazine==start_ammo,"old item retains finite ammo after candidate cancellation")
	host.advance(.016);pose();release();notifications.clear()
	# All effects/ammo are committed before external notifications can end the epoch.
	interrupt_kind="epoch";effects_before=host.effects.stats().totalShots;start_ammo=host.fire_state.magazine
	press();host.advance(1);pose()
	check(notifications.size()>1,"actual automatic catch-up batch")
	var accepted:int=host.effects.stats().totalShots-effects_before
	check(notifications[0].fx_count-effects_before==accepted and accepted==notifications.size(),"whole batch admitted before first external callback")
	check(host.fire_state.magazine==start_ammo-accepted,"one round per accepted FX shot")
	var intact:=true
	for row:Dictionary in notifications:
		if not row.muzzle.get("ok",false) or not row.muzzle.has("pose_epoch") or row.muzzle.weapon_id!=row.shot.weaponId:intact=false
	check(intact,"historical muzzle receipts survive first-callback invalidation")
	actor.set_preview_pose_authority(&"on_foot",true);interrupt_kind="";host.equip("tt_pistol")
	host.advance(.016);pose();release();notifications.clear()
	# Real host exit during callback: no second callback, no use after free.
	check(host.equip("uzi").ok,"equip for lifecycle batch");host.advance(.016);pose()
	effects_before=host.effects.stats().totalShots;interrupt_kind="queue_free";press();host.advance(.5);pose()
	check(host.is_queued_for_deletion() and notifications.size()==1,"queued host exit stops external notifications")
	check(notifications[0].fx_count-effects_before>1,"already accepted effects precede queued host exit")
	await process_frame;await process_frame
	check(not is_instance_valid(host),"host teardown completed")
	scene.free();await process_frame;finish()
func finish()->void:
	print("WEAPON_ADMISSION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"CPU actual main, source finite ammo; no GPU/HP claims"}))
	quit(0 if failures.is_empty() else 1)
