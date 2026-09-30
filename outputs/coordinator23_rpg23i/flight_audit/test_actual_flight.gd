extends SceneTree
## Actual frozen main/attached camera/player InputMap/Fire/inventory/Flight.
## Default records the known pre-fix spread defect; --require-source-spread
## turns it into a regression assertion for root's later integrated candidate.
var scene: Node3D
var player: CharacterBody3D
var host: Node
var checks:=0
var failures:Array[String]=[]
var observations:Array[Dictionary]=[]
var strict:=false
var done:=false
var began:=0
var output:=""
var ammo_before:Dictionary={}
func _initialize()->void:
	began=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg=="--require-source-spread":strict=true
		if arg.begins_with("--audit-out="):output=arg.trim_prefix("--audit-out=")
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _process(_dt:float)->bool:
	# Explicit programmatic input ownership: this is not OS focus acceptance.
	if is_instance_valid(player):player._free_mouse_look=true
	if not done and Time.get_ticks_msec()-began>45000:check(false,"45s deadline");finish()
	return false
func frames(n:int)->void:
	for i:int in n:
		if done:return
		await physics_frame;await process_frame
func mouse(pressed:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
	player._unhandled_input(e)
func on_shot(shot:Dictionary,muzzle:Dictionary,origin:Vector3,forward:Vector3)->void:
	var target:=origin+forward*100.0
	var hit:Dictionary=host._projectile_ray({"origin":origin,"direction":forward,"range":100.0})
	if hit.has("point"):target=hit.point
	var base:Vector3=(target-muzzle.origin).normalized()
	var projectile:Dictionary=shot.projectiles[0]
	# Source weapon_effects.mjs:124, Rodrigues rotation via Godot Vector3.
	var expected:=base.rotated(Vector3.UP,float(projectile.yawOffset))
	var right:=expected.cross(Vector3.UP)
	if right.length_squared()>1e-8:expected=expected.rotated(right.normalized(),float(projectile.pitchOffset))
	expected=expected.normalized()
	var flight:RefCounted=host.rpg_effects._flight
	var row:Dictionary={}
	for active:Dictionary in flight._slots:
		if active.get("shot_id")==shot.shotId:row=active
	check(not row.is_empty(),"actual launch present before outward signal")
	if row.is_empty():return
	var ammo:Dictionary=host.inventory.get_fire_state("rpg")
	check(ammo.magazine==int(ammo_before.magazine)-1 and ammo.reserveAmmo==ammo_before.reserveAmmo,"one magazine debit and no reserve spend")
	check(ammo.sequence==int(ammo_before.sequence)+1 and row.sequence==ammo.sequence,"one sequence committed")
	check(row.item_uid==host.inventory.get_item_uid("rpg"),"original inventory UID")
	check(row.origin==muzzle.origin and row.muzzle==muzzle,"actual applied pose receipt frozen")
	check(Vector2(player.velocity.x,player.velocity.z).length()>.1,"actual scheduled movement at shot")
	check(absf(projectile.yawOffset)>1e-7 and absf(projectile.pitchOffset)>1e-7,"real Fire nonzero yaw AND pitch")
	var contexts:Array=[]
	for owner:RefCounted in scene.preview_population.hit_owners:contexts.append(owner.current_damage_context())
	check(contexts.size()==3 and not contexts[0].is_empty() and contexts[0]==contexts[1] and contexts[1]==contexts[2],"all three owners share current accepted-shot context")
	var error:float=row.direction.distance_to(expected)
	if strict:check(error<1e-6,"source yaw/pitch reaches Flight")
	observations.append({"shot_id":shot.shotId,"yaw":projectile.yawOffset,"pitch":projectile.pitchOffset,"speed":Vector2(player.velocity.x,player.velocity.z).length(),"source_direction_error":error,"unspread_direction_error":row.direction.distance_to(base),"ammo_before":ammo_before.duplicate(),"ammo_after":ammo.duplicate(),"token":row.token,"current_context":scene.preview_population.hit_owners[0].current_damage_context()})
func reload_round()->void:
	var e:=InputEventKey.new();e.physical_keycode=KEY_R;e.pressed=true
	player._unhandled_input(e)
	await frames(180)
	check(host.fire_state.magazine==1 and host.fire_state.reloadRemaining==0,"normal finite-reserve R reload")
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready and not done:await frames(1)
	if done:return
	player=scene._player;host=scene.preview_weapons;player._free_mouse_look=true
	check(host.equip("rpg").get("ok",false),"actual inventory RPG equip")
	await frames(5)
	host.shot_emitted.connect(on_shot)
	for i:int in 2:
		if i>0:
			await reload_round()
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(82,-21)
			player._unhandled_input(motion)
		Input.action_press(player.ACTION_LEFT if i==0 else player.ACTION_FORWARD)
		await frames(12)
		ammo_before=host.inventory.get_fire_state("rpg").duplicate(true)
		mouse(true);await frames(1);mouse(false)
		Input.action_release(player.ACTION_LEFT);Input.action_release(player.ACTION_FORWARD)
		await frames(100)
		check(host.rpg_effects.stats().total_impacts==i+1,"one native terminal (contact or range end) per launch")
		check(host.rpg_effects.stats().active_rockets==0,"terminal retires Flight")
	check(observations.size()==2,"exactly two outward accepted shots")
	check(host.effects._projectiles.size()==112,"shared original bounded pool")
	await reload_round()
	var saved:Dictionary=host.inventory.get_fire_state("rpg").duplicate(true)
	var next:Dictionary=host.Fire.step(saved,{"triggerPressed":true},0).shots[0]
	var muzzle:Dictionary=host.presentation.current_muzzle()
	var stale:=muzzle.duplicate();stale.sample_serial+=1
	var denied:Dictionary=host.rpg_effects.prepare_shot(next,stale,muzzle.origin+muzzle.direction*20)
	check(not denied.get("ok",false),"stale pose reservation rejected")
	var prepared:Dictionary=host.rpg_effects.prepare_shot(next,muzzle,muzzle.origin+muzzle.direction*20)
	check(prepared.get("ok",false),"real effects reservation succeeds")
	if prepared.get("ok",false):
		host.rpg_effects.cancel_shot(prepared.ticket)
		check(not host.rpg_effects.commit_shot(prepared.ticket),"cancelled ticket cannot launch")
	check(host.inventory.get_fire_state("rpg")==saved,"negative/cancelled preparations never spend ammo")
	check(host.rpg_effects.stats().total_impacts==2 and observations.size()==2,"negative/cancelled preparations never publish")
	finish()
func finish()->void:
	if done:return
	done=true
	if is_instance_valid(player):
		Input.action_release(player.ACTION_LEFT);Input.action_release(player.ACTION_FORWARD)
	var result:={"checks":checks,"failures":failures,"strict_source_spread":strict,"observations":observations,"elapsed_ms":Time.get_ticks_msec()-began,"scope":"actual root scheduled input/Fire/ammo/Flight; HEADLESS NOT performance or NPC RPG damage acceptance"}
	print(JSON.stringify(result))
	if not output.is_empty():
		var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	if is_instance_valid(scene):scene.queue_free()
	await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
