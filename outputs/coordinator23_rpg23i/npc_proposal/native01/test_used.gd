extends SceneTree
## Authentic gate + original three owners/rigs + real Inventory/Fire/Flight.
## QA root-hook composition is explicit here; no fake gate/target/HP receipt.
const Gate=preload("res://scripts/npc_visual/npc_rpg_blast_gate.gd")
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
var scene:Node3D
var w:Node
var gate:RefCounted
var owners:Array[RefCounted]=[]
var errors:Array[String]=[]
var checks:Array[Dictionary]=[]
var impacts:Array[Dictionary]=[]
var mode:=""
var out:=""
var started:=0
var done:=false
func _initialize()->void:
	started=Time.get_ticks_msec()
	for a:String in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
	if out.is_empty() or DisplayServer.get_name()!="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);run.call_deferred()
func _process(_dt:float)->bool:
	if not done and Time.get_ticks_msec()-started>24000:check(false,"24_second_timeout");finish()
	return false
func check(ok:bool,label:String)->void:
	checks.append({"ok":ok,"label":mode+":"+label})
	if not ok:errors.append(mode+":"+label);print("FAIL ",mode,":",label)
func step(n:int=1)->void:
	for i in n:await physics_frame;await process_frame
func query(request:Dictionary)->Dictionary:return gate.native_query(w.rpg_effects,request)
func impact(receipt:Dictionary)->void:
	var result:Dictionary=gate.native_impact(w.rpg_effects,receipt)
	var records:Array[Dictionary]=[]
	for owner:RefCounted in owners:
		var physical:RefCounted=owner._host._ragdolls[owner._token.source_id]
		var momentum:=Vector3.ZERO;var mass:=0.0
		for body:RigidBody3D in physical.owned_bodies():mass+=body.mass;momentum+=body.linear_velocity*body.mass
		var inherited:Vector3=owner._events.get(owner.last_result.get("event_id",""),{}).get("linear_velocity",Vector3.ZERO)
		# Initial bodies inherit the standing velocity; source receipt is also
		# retained under last_impulse event id for precise momentum accounting.
		if not owner.last_impulse.is_empty():inherited=owner._events.get(owner.last_impulse.event_id,{}).get("linear_velocity",Vector3.ZERO)
		records.append({"source_id":owner._token.source_id,"hp":owner._row.hp,"medical":owner._row.get("_medicalDowned",false),"dead":owner._row.get("dead",false),"reason":owner.last_result.get("reason",""),"impulse":owner.last_impulse.duplicate(true),"physical":physical.status(),"bodies":physical.owned_bodies().size(),"total_mass":mass,"incremental_momentum":momentum-inherited*mass,"marks":owner.marks.renderer._marks.size(),"point_events":owner._point_consumed.size()})
	impacts.append({"mode":mode,"gate":result,"records":records,"native_receipt":receipt})
	check(not gate.native_impact(w.rpg_effects,receipt).get("ok",false),"native_impact_replay_rejected")
	w.rpg_effects._impact(receipt)
func context()->Dictionary:
	if mode=="retire_context":gate.dispose()
	return owners[0].current_damage_context()
func seed_survival(want_medical:bool)->void:
	var rng:=RandomNumberGenerator.new()
	for seed_value in 100000:
		rng.seed=seed_value;var good:=true
		for i in 3:
			var value:=rng.randf()
			if (value<.72)!=want_medical:good=false;break
		if good:owners[0]._rng.seed=seed_value;return
	check(false,"deterministic_survival_seed")
func setup()->bool:
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"actual_main_ready")
	if not scene.preview_ready:return false
	w=scene.preview_weapons;owners.assign(scene.preview_population.hit_owners)
	check(owners.size()==3,"original_three_recipients")
	check(not owners[0].bind_native_rpg_gate(RefCounted.new()),"arbitrary_gate_rejected")
	gate=Gate.new()
	check(gate.configure(w,scene.preview_population.residents,owners,context).get("ok",false),"authentic_gate_bound")
	check(not owners[0].accept_native_rpg_blast(gate,Gate.TargetTicket.new()).get("ok",false),"forged_opaque_target_rejected")
	check(not owners[0].bind_native_rpg_gate(gate),"rebind_rejected")
	# Test adapter supplies precisely the two root Flight callbacks. Native
	# Flight/inventory/muzzle owners remain the actual configured main objects.
	w.rpg_effects._flight._query_port=query;w.rpg_effects._flight._impact_port=impact
	w.player.set_mouse_captured(true);check(w.equip("rpg").get("ok",false),"real_RPG_equip")
	await step(8)
	return true
func fire_once(target:Vector3)->bool:
	var old:Dictionary=w.fire_state.duplicate(true)
	var source:Dictionary=Fire.step(old,{"triggerPressed":true,"triggerHeld":true},0.0)
	check(source.shots.size()==1,"one_real_source_shot")
	if source.shots.size()!=1:return false
	var muzzle:Dictionary=w.presentation.current_muzzle()
	var prepared:Dictionary=w.rpg_effects.prepare_shot(source.shots[0],muzzle,target)
	check(prepared.get("ok",false),"actual_flight_prepare")
	if not prepared.get("ok",false):return false
	var proof:Dictionary=gate.before_ammo_commit(w.rpg_effects,prepared.ticket)
	check(proof.get("ok",false),"real_pre_ammo_capability")
	if not proof.get("ok",false):return false
	check(w.inventory.update_fire_state(source.state).get("ok",false),"real_inventory_commit_once")
	w.fire_state=source.state
	check(w.rpg_effects.commit_shot(prepared.ticket),"real_effects_flight_commit")
	check(gate.after_ammo_commit(w.rpg_effects,proof.ticket).get("ok",false),"actual_post_ammo_admitted")
	check(w.inventory.get_fire_state("rpg").magazine==old.magazine-1,"one_RPG_round_spent")
	w.shot_emitted.emit(source.shots[0],muzzle,w.player.get_preview_camera().global_position,(target-muzzle.origin).normalized())
	seed_survival(mode=="medical")
	return true
func run()->void:
	for current_mode:String in ["final","medical","retire_context"]:
		mode=current_mode
		if not await setup():finish();return
		var before:=impacts.size()
		var hp_before:Array[int]=[]
		for owner:RefCounted in owners:hp_before.append(owner._row.hp)
		var target:Vector3=owners[0]._token.body.global_position+Vector3.UP*.8
		if not await fire_once(target):finish();return
		for frame in 180:
			await step()
			if impacts.size()>before:break
		check(impacts.size()==before+1,"real_native_flight_impacted")
		if impacts.size()==before:finish();return
		var result:Dictionary=impacts[-1]
		if mode=="retire_context":
			check(not result.gate.get("ok",false),"retired_context_rejects_blast")
			for i in 3:check(owners[i]._row.hp==hp_before[i] and owners[i].last_impulse.is_empty(),"retire_no_HP_or_force_"+str(i))
		else:
			check(result.gate.get("ok",false) and not result.gate.hits.is_empty(),"authentic_gate_delivers_current_targets")
			for record:Dictionary in result.records:
				if record.reason.is_empty():continue
				check(record.marks==0 and record.point_events==0,"no_fake_bullet_contact_"+record.source_id)
				if record.reason not in ["final_death","medical_downed"]:continue
				check(record.bodies==16 and record.total_mass>0,"original_complete_rig_mass_"+record.source_id)
				var j:Vector3=record.impulse.get("uniform_ns",Vector3.ZERO)
				check(j.length()>0 and record.impulse.get("point_ns",Vector3.ONE)==Vector3.ZERO,"distributed_only_impulse_"+record.source_id)
				check(record.incremental_momentum.distance_to(j)<.05,"mass_partition_conserves_total_J_"+record.source_id)
				if record.reason=="medical_downed":check(record.hp==1 and record.medical and not record.dead and j.length()<=75.001,"medical_survival_cap_"+record.source_id)
				else:check(record.hp==0 and record.dead and record.physical.final_dead,"final_death_preserved_"+record.source_id)
		gate.dispose();scene.queue_free();await step(2);owners.clear();gate=null
	finish()
func finish()->void:
	if done:return
	done=true
	var value:Dictionary={"checks":checks,"errors":errors,"count":checks.size(),"impacts":impacts,"elapsed_ms":Time.get_ticks_msec()-started,"scope":"Actual original main recipients + authentic gate + real Inventory/Fire/Flight/native query. Explicit TEST root-hook callbacks/manual real commit, not ordinary input/production root-hook integration. No sever/body edits; no GPU/performance acceptance."}
	var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(value,"\t"));file.close()
	print("NATIVE_RPG_RECIPIENT_RESULT ",JSON.stringify({"count":checks.size(),"errors":errors,"elapsed_ms":value.elapsed_ms}))
	quit(0 if errors.is_empty() else 1)
