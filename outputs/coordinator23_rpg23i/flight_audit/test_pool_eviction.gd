extends "test_current_context.gd"
## Native shared-pool lifecycle pressure, NOT112 invented accepted bullets.
func run()->void:
	if not out.is_absolute_path():quit(3);return
	DirAccess.make_dir_recursive_absolute(out)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i:int in 600:
		await sync()
		if done:return
		if scene.preview_ready and scene.preview_population!=null and scene.preview_population.hit_owners.size()==3:break
	check(scene.preview_ready and scene.preview_population.hit_owners.size()==3,"actual main three owners ready")
	if not report.errors.is_empty():finish();return
	p=scene._player;w=scene.preview_weapons;owners=scene.preview_population.hit_owners.duplicate();gate=w.npc_rpg_gate
	check(gate!=null and gate._live(),"real bound RPG gate")
	check(scene._block.counts.buildings==8 and scene.find_children("*","CollisionObject3D",true,false).size()==377,"original content retained")
	await sync(5)
	camera=p.get_preview_camera();camera.reparent(scene,true);tracked=true;p._free_mouse_look=true
	check(w.equip("rpg").get("ok",false),"normal RPG equip")
	check(choose_fixture(),"real existing physical floor fixture")
	await sync(20)
	if done or not report.errors.is_empty():finish();return
	saved_context=gate._damage_context;saved_impact=w.rpg_effects._flight._impact_port
	w.rpg_effects._flight._impact_port=Callable(self,"impact_callback")
	w.shot_emitted.connect(shot_callback)
	w.rpg_effects.cosmetic_impact.connect(func(hit:Dictionary):cosmetic.append(hit.duplicate(true)))
	var before:Dictionary=w.inventory.get_fire_state("rpg").duplicate(true)
	mouse(true);await sync(1);mouse(false);tracked=false
	check(shots.size()==1 and not launch_row.is_empty(),"actual input admitted one flight")
	if launch_row.is_empty():finish();return
	var spent:Dictionary=w.inventory.get_fire_state("rpg").duplicate(true)
	check(spent.magazine==before.magazine-1,"actual one-round debit")
	var renderer_row:Dictionary={}
	for row:Dictionary in w.rpg_effects._rockets:
		if row.token==launch_row.token:renderer_row=row
	check(not renderer_row.is_empty(),"actual shared renderer token mapping")
	var old_node:Node3D=renderer_row.node
	var borrowed:Array[Dictionary]=[]
	for i:int in w.effects._projectiles.size():borrowed.append(w.effects._take(w.effects._projectiles,"projectiles"))
	check(w.effects._projectiles.size()==112 and borrowed[-1].root==old_node,"112 native pool acquisitions wrap to exact occupied rocket node")
	check(w.rpg_effects._flight._active==0 and gate._slot(launch_row.token).is_empty(),"native shared-slot reuse retires exact original Flight token")
	check(not borrowed[-1].has("external_flight") and not borrowed[-1].has("external_token"),"reused slot has no stale Flight ownership")
	w.rpg_effects.advance(.1)
	check(renderer_row.token==0 and old_node.visible and borrowed[-1].active,"old renderer mapping clears without hiding new slot owner")
	check(impacts.is_empty() and cosmetic.is_empty() and w.rpg_effects.stats().total_explosions==0,"evicted Flight cannot publish terminal or explosion")
	check(state()==launch_hp and w.inventory.get_fire_state("rpg")==spent,"pool eviction causes no HP mutation or ammo refund")
	# Release test-only pressure without pretending these acquisitions are shots.
	for entry:Dictionary in borrowed:w.effects._hide(entry)
	check(gate._launches.has(launch_row.token),"lazy bounded gate cleanup retains canceled entry until next launch attempt")
	var request:={"token":launch_row.token,"origin":launch_row.position,"direction":launch_row.direction,"range":1.0,"item_uid":launch_row.item_uid,"shot_id":launch_row.shot_id}
	check(gate.native_query(w.rpg_effects,request).get("invalid",false),"evicted token cannot query outside native active callback")
	# Actual finite reserve reload; controlled weapon clock, no direct ammo edits.
	var e:=InputEventKey.new();e.physical_keycode=KEY_R;e.pressed=true;p._unhandled_input(e)
	for i:int in 20:w.advance(.1);p._update_owned_pose(1.0/60)
	var reloaded:Dictionary=w.inventory.get_fire_state("rpg").duplicate(true)
	check(reloaded.magazine==1 and reloaded.reserveAmmo==spent.reserveAmmo-1,"actual reload spends finite reserve")
	var shot:Dictionary=w.Fire.step(reloaded,{"triggerPressed":true},0).shots[0]
	var muzzle:Dictionary=w.presentation.current_muzzle()
	var prepared:Dictionary=w.rpg_effects.prepare_shot(shot,muzzle,muzzle.origin+muzzle.direction*20)
	check(prepared.get("ok",false),"new real effects reservation after eviction")
	if prepared.get("ok",false):
		var proof:Dictionary=gate.before_ammo_commit(w.rpg_effects,prepared.ticket)
		check(proof.get("ok",false) and not gate._launches.has(launch_row.token),"next precommit prunes retired native token before issuing proof")
		if proof.get("ok",false):
			gate.cancel_ammo_commit(proof.ticket)
			check(gate._pending.is_empty(),"exact gate proof cancellation consumes pending capability")
			check(not gate.after_ammo_commit(w.rpg_effects,proof.ticket).get("ok",false),"canceled gate proof cannot be admitted")
		w.rpg_effects.cancel_shot(prepared.ticket)
		check(not w.rpg_effects.commit_shot(prepared.ticket),"canceled Flight reservation cannot commit")
	check(w.inventory.get_fire_state("rpg")==reloaded and shots.size()==1 and state()==launch_hp,"negative proof path changes neither ammo/HP nor accepted shot count")
	report.scope="Actual main112-slot eviction lifecycle pressure and gate cancellation. One real player-input RPG launch;112 native _take acquisitions are pressure fixtures, NOT accepted shots or gameplay/performance claim. Scheduled player/world held at accepted launch. No fabricated positive impact/HP/context/ammo."
	report.final=state();finish()
