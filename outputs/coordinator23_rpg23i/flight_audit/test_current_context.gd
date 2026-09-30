extends "fixture_actual_main_frozen.gd"
## Explicit clock-scheduling test. Positive events use real player input,
## Fire, inventory, pose and native query. No HP/current-context writes.
var launch_context:Dictionary={}
var nagan_shots:Array[Dictionary]=[]
var launch_row:Dictionary={}
var launch_hp:Dictionary={}
var freeze_at_launch:=true
func shot_callback(shot:Dictionary,muzzle:Dictionary,origin:Vector3,direction:Vector3)->void:
	if shot.weaponId=="rpg":
		super.shot_callback(shot,muzzle,origin,direction)
		launch_context=saved_context.call().duplicate(true)
		launch_row=shots[-1].flight.duplicate(true)
		launch_hp=state()
		if freeze_at_launch:
			# Stop future scheduled weapon/world ticks at the actual accepted signal.
			# No Flight row, clock, ammo, receipt or owner context is edited.
			p.set_physics_process(false);scene.set_physics_process(false)
	elif shot.weaponId=="nagan":
		nagan_shots.append({"shot":shot.duplicate(true),"muzzle":muzzle.duplicate(true),"ammo":w.inventory.get_fire_state("nagan").duplicate(true),"context":saved_context.call().duplicate(true)})
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
	check(scene._block.counts.buildings==8 and scene.find_children("*","CollisionObject3D",true,false).size()==377,"original three residents/eight buildings/377 colliders")
	await sync(60) # Original Nagan guaranteed duel needs >=800ms actual owner time.
	camera=p.get_preview_camera();camera.reparent(scene,true);tracked=true;p._free_mouse_look=true
	check(w.equip("rpg").get("ok",false),"actual inventory RPG equip")
	check(choose_fixture(),"existing physical floor near real residents")
	await sync(20)
	if done or not report.errors.is_empty():finish();return
	# Disclosed deterministic noncritical RPG roll, not a synthetic context.
	var probe:=RandomNumberGenerator.new();var selected_seed:=1
	while true:
		probe.seed=selected_seed
		if probe.randf()>=.12:break
		selected_seed+=1
	owners[0]._rng.seed=selected_seed
	report.rng_seed=selected_seed
	saved_context=gate._damage_context
	saved_impact=w.rpg_effects._flight._impact_port
	w.rpg_effects._flight._impact_port=Callable(self,"impact_callback")
	w.shot_emitted.connect(shot_callback)
	w.rpg_effects.cosmetic_impact.connect(func(hit:Dictionary):cosmetic.append(hit.duplicate(true)))
	var rpg_ammo:Dictionary=w.inventory.get_fire_state("rpg").duplicate(true)
	mouse(true);await sync(1);mouse(false)
	check(shots.size()==1 and not launch_row.is_empty(),"one authentic RPG launch before clock hold")
	if launch_row.is_empty():finish();return
	check(not launch_context.critical,"actual accepted RPG installs noncritical launch context")
	check(w.inventory.get_fire_state("rpg").magazine==rpg_ammo.magazine-1,"actual RPG spends exactly one round")
	check(gate._slot(launch_row.token).travelled==0 and gate._launches.has(launch_row.token),"admitted Flight held at zero travelled before first sweep")
	check(not p.is_physics_processing() and not scene.is_physics_processing(),"test scheduling explicitly pauses player and world ticks")
	check(owners[0]._now()>=800,"original Nagan duel wall-clock window elapsed")
	tracked=false
	check(w.equip("nagan").get("ok",false),"normal weapon switch retains flying RPG")
	# Aim the real second projectile away from residents. No projectile hit/HP is
	# needed to install source current accepted-shot modifiers.
	camera.look_at(camera.global_position+Vector3(.1,1,.1),Vector3.RIGHT)
	w.advance(0);p._update_owned_pose(1.0/60.0)
	var nagan_ammo:Dictionary=w.inventory.get_fire_state("nagan").duplicate(true)
	p._free_mouse_look=true;mouse(true);w.advance(0);p._update_owned_pose(1.0/60.0);mouse(false)
	check(nagan_shots.size()==1,"one actual Nagan player-input Fire/pose/accepted signal")
	check(w.inventory.get_fire_state("nagan").magazine==nagan_ammo.magazine-1,"Nagan actual one-round spend")
	var current:Dictionary=saved_context.call()
	check(current.critical and current.critical_multiplier==1.8,"real source Nagan accepted shot replaces current context with duel multiplier1.8")
	check(gate._slot(launch_row.token).position==launch_row.position and gate._slot(launch_row.token).travelled==0,"zero-delta accepted Nagan did not advance or replace RPG trajectory")
	check(state()==launch_hp and impacts.is_empty(),"no NPC HP/physical mutation before actual RPG sweep")
	for owner:RefCounted in owners:check(owner.current_damage_context()==current,"all three actual owners read shared impact-time context")
	# Only flight/effects elapsed time now resumes. No synthetic callback/contact.
	for i:int in 12:
		w.rpg_effects.advance(.1)
		if w.rpg_effects._flight._active==0:break
	check(impacts.size()==1,"one genuine native RPG impact after context change")
	if impacts.size()==1:
		verify_impact(impacts[0])
		check(impacts[0].context==current and impacts[0].context!=launch_context,"native impact reads new real context rather than launch snapshot")
		for hit:Dictionary in impacts[0].gate_result.hits:
			var pos:Vector3=impacts[0].targets[hit.source_id]
			var distance:=Vector2(pos.x-impacts[0].receipt.point.x,pos.z-impacts[0].receipt.point.z).length()/4.1
			var launch_damage:int=gate.blast_damage(distance,launch_context.marksman,launch_context.critical,launch_context.critical_multiplier)
			check(hit.damage>launch_damage,"real recipient damage differs from stale launch-context result "+hit.source_id)
	report.launch_context=launch_context;report.current_context=current;report.nagan_shots=nagan_shots
	report.clock_scheduling="Paused scheduled player/world ticks in actual RPG shot_emitted. Equip+Nagan real input/Fire ran at delta0; pose-only sampling used1/60 because locomotion rejects dt0; then ONLY real RPG advance(.1) until native terminal. All real geometry/HP/ownership/callbacks retained. No FPS/camera/input-timing claim."
	report.final=state()
	finish()
