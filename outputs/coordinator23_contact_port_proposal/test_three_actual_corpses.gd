extends "../artist23_combat_next/test_combined_eyes_input.gd"
## Headless proposal measurements. Three original main NPCs are killed through
## actual weapon inputs, then source player/capsule move_and_slide samples feed
## the proposed public port. Contact-motion driver is explicit test scaffolding,
## not production hook/full-scene performance acceptance. No NPC force bypass.
const Port=preload("final_dead_contact_port.gd")
var port:RefCounted
var walking:=false
var walk_direction:=Vector3.ZERO
var port_records:Array=[]
var measurements:Array=[]
var replies:Array=[]
var moved_frames:=0
var current_capability:=true
var fake_life:=false
var test_options:Dictionary={"max_impulse_ns":3.0,"impulse_ns_per_mps":1.0,"max_point_delta_energy_j":1.5,"max_linear_speed_mps":2.5,"max_angular_speed_rps":15.0,"cooldown_ms":160}
var began:=0
var full_natural_sleep_proofs:=0
var exact_sleeping_segment_wakes:=0
var response_observation:Dictionary={}
var wake_targets:Dictionary={}
var guard_evidence:Array=[]
var guards_done:=false
var stale_completed_request:Dictionary={}
var public_records:Array=[]
var preferred_part:=0
var preferred_direction:=Vector3.ZERO
var pace_contacts:=false
class ReplacementHost extends RefCounted:
	var original:RefCounted
	func status()->Dictionary:return original.status()
	func owned_bodies()->Array:return original.owned_bodies()
func _initialize()->void:
	began=Time.get_ticks_msec()
	out=get_script().resource_path.get_base_dir()+"/native01"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--j-cap="):test_options.max_impulse_ns=arg.trim_prefix("--j-cap=").to_float()
		if arg.begins_with("--j-gain="):test_options.impulse_ns_per_mps=arg.trim_prefix("--j-gain=").to_float()
	DirAccess.make_dir_recursive_absolute(out);run.call_deferred()
func _process(delta:float)->bool:
	if not done and Time.get_ticks_msec()-began>30000:check(false,"30_second_deadline");finish();return false
	return super._process(delta)
func _physics_process(delta:float)->bool:
	# --fixed-fps accelerates virtual physics independently of owner wall-clock
	# cooldown. Pace only contact scenarios; never replace the owner's clock.
	if pace_contacts:OS.delay_msec(16)
	observe_response()
	if not stale_completed_request.is_empty() and Engine.get_physics_frames()>int(stale_completed_request.physics_frame):
		var stale:=stale_completed_request.duplicate(true);stale.event_id+="_nextframe";stale.physics_frame=Engine.get_physics_frames();stale.now_ms=Time.get_ticks_msec()
		guard_probe(port,stale,"prior_movement_relabelled_current_frame","completed_move_required")
		stale_completed_request={}
	for action:StringName in [&"preview_move_left",&"preview_move_right",&"preview_move_forward",&"preview_move_back"]:
		if InputMap.has_action(action):Input.action_release(action)
	if walking and is_instance_valid(player):
		player._camera_yaw=0.0
		if walk_direction.x>0:Input.action_press(&"preview_move_right",walk_direction.x)
		if walk_direction.x<0:Input.action_press(&"preview_move_left",-walk_direction.x)
		if walk_direction.z>0:Input.action_press(&"preview_move_back",walk_direction.z)
		if walk_direction.z<0:Input.action_press(&"preview_move_forward",-walk_direction.z)
		# Execute the real canonical grounded method, including completed-move
		# receipt and root sampler, exactly once from this physics callback.
		player._physics_process(delta);moved_frames+=1
	return false
func capability_current(binding:Dictionary)->bool:
	if not current_capability:return false
	for record:Dictionary in public_records:
		if record.binding.source_id==binding.get("source_id"):return record.current_life.call(binding)
	return false
func record_admit(request:Dictionary)->Dictionary:
	var before_sleep:=sleep_count(owner)
	if not guards_done:
		guards_done=true;test_admission_guards(request)
	var result:Dictionary=port.admit_player_final_dead_contact(request)
	if result.get("ok",false) and preferred_part==0:
		preferred_part=result.applied_body_instance_id;preferred_direction=walk_direction
	if result.get("ok",false) and stale_completed_request.is_empty() and not guard_evidence.any(func(item:Dictionary):return item.label=="prior_movement_relabelled_current_frame"):
		guard_probe(port,request,"same_event_replay","replay_or_event_id")
		var repeated:=request.duplicate(true);repeated.event_id+="_different_event"
		guard_probe(port,repeated,"same_completed_move_new_event","completed_move_required")
		stale_completed_request=request.duplicate(true)
	if result.get("ok",false) and result.was_sleeping:wake_targets[result.applied_body_instance_id]=false
	replies.append({"request":request.duplicate(true),"result":result.duplicate(true),"before_sleep":before_sleep})
	return result
func guard_probe(candidate:RefCounted,request:Dictionary,label:String,reason:String)->void:
	var before:int=candidate.stats.accepted
	var result:Dictionary=candidate.admit_player_final_dead_contact(request)
	check(not result.get("ok",false) and result.get("reason")==reason and candidate.stats.accepted==before,"guard:"+label+":"+str(result))
	guard_evidence.append({"label":label,"reason":result.get("reason"),"accepted_delta":candidate.stats.accepted-before})
func guarded_life(binding:Dictionary,probe:RefCounted,counter:Array,dispose_at:int)->bool:
	counter[0]+=1
	if counter[0]==dispose_at:probe.dispose()
	return capability_current(binding)
func test_admission_guards(request:Dictionary)->void:
	for test:Array in [["owner_epoch",int(request.owner_epoch)+1,"old_epoch","frame_or_epoch"],["physics_frame",int(request.physics_frame)-1,"old_frame","frame_or_epoch"],["movement_serial",int(request.movement_serial)-1,"old_move_serial","completed_move_required"],["actor_instance_id",0,"wrong_actor","actor_identity"],["now_ms",int(request.now_ms)-1000,"stale_clock","stale_clock"],["shape_index",999,"wrong_shape","native_contact_identity"],["world_point",request.world_point+Vector3.RIGHT*.1,"wrong_contact_point","native_contact_changed"]]:
		var modified:=request.duplicate(true);modified[test[0]]=test[1];modified.event_id+="_"+test[2]
		guard_probe(port,modified,test[2],test[3])
	var replacement:=Port.new()
	check(replacement.configure(player,port_records,test_options).get("ok",false),"guard_replacement_configured")
	check(replacement.player_final_dead_contact_ready().epoch!=request.owner_epoch,"unique_positive_instance_epoch")
	guard_probe(replacement,request,"old_instance_request_to_replacement","frame_or_epoch");replacement.dispose()
	for dispose_at:int in [1,2]:
		var probe:=Port.new();var records:=port_records.duplicate(true);var counter:Array=[0]
		for record:Dictionary in records:record.current_life=guarded_life.bind(probe,counter,dispose_at)
		check(probe.configure(player,records,test_options).get("ok",false),"guard_callback_port_configured")
		var modified:=request.duplicate(true);modified.owner_epoch=probe._epoch;modified.event_id+="_callback_dispose"
		guard_probe(probe,modified,"dispose_in_life_callback_%d"%dispose_at,"not_current_final_dead" if dispose_at==1 else "life_changed_before_commit")
		check(counter[0]==dispose_at,"callback_reached_exact_boundary_%d"%dispose_at)
		probe.dispose()
	current_capability=false
	guard_probe(port,request,"retired_current_life","not_current_final_dead")
	current_capability=true
	# State-filter unit negatives on the real player; no gameplay transition or
	# NPC mutation is claimed. Restore synchronously before the real movement.
	var authority:StringName=player._pose_authority;player._pose_authority=&"vehicle"
	guard_probe(port,request,"injected_vehicle_authority","completed_move_required");player._pose_authority=authority
	var jump:Dictionary=player._jump;player._jump={"guard_fixture":true}
	guard_probe(port,request,"injected_active_jump","actor_not_ground_walking");player._jump=jump
	# Same binding and body pool, different host reference: the real public
	# resident validator must reject this retired/replaced host capability.
	var old_host:=ReplacementHost.new()
	for record:Dictionary in public_records:
		if record.binding.source_id==owner._token.source_id:old_host.original=record.ragdoll_host
	check(not scene.preview_population.residents.public_final_dead_contact_current(old_host.status().binding,old_host),"same_life_replaced_host_public_validator")
	var replaced:=Port.new()
	var retired_record:Dictionary={"ragdoll_host":old_host,"binding":old_host.status().binding,"current_life":Callable(scene.preview_population.residents,"public_final_dead_contact_current").bind(old_host)}
	check(replaced.configure(player,[retired_record],test_options).get("ok",false),"retired_host_same_binding_pool_configured")
	var changed:=request.duplicate(true);changed.owner_epoch=replaced._epoch
	guard_probe(replaced,changed,"same_life_replaced_host_admission","not_current_final_dead");replaced.dispose()
func observe_response()->void:
	if response_observation.is_empty():return
	var snap:Dictionary=physical(owner)._body.snapshot()
	for pair:Array in [["max_joint","max_joint_anchor_error_m"],["max_energy","kinetic_energy_j"],["max_speed","max_linear_speed"],["max_angular","max_angular_speed"]]:response_observation[pair[0]]=maxf(response_observation[pair[0]],snap[pair[1]])
	for body:RigidBody3D in physical(owner).owned_bodies():
		response_observation.max_displacement=maxf(response_observation.max_displacement,response_observation.before[body.get_instance_id()].distance_to(body.global_position))
		if wake_targets.has(body.get_instance_id()) and not body.sleeping:wake_targets[body.get_instance_id()]=true
	response_observation.woke=response_observation.woke or sleep_count(owner)<int(response_observation.initial_sleep)
func health(hit_owner:RefCounted)->Dictionary:
	var snap:Dictionary=hit_owner.snapshot();var row:Dictionary=snap.row
	return {"hp":row.hp,"dead":row.get("dead",false),"medical":row.get("_medicalDowned",false),"deadAt":row.get("deadAt"),"revision":snap.last_result.get("revision"),"blood":hit_owner.blood._last_revision if hit_owner.blood!=null else -1}
func physical(hit_owner:RefCounted)->RefCounted:return scene.preview_population.residents._ragdolls[hit_owner._token.source_id]
func sleep_count(hit_owner:RefCounted)->int:
	var n:=0
	for b:RigidBody3D in physical(hit_owner).owned_bodies():
		if b.sleeping:n+=1
	return n
func points(hit_owner:RefCounted)->Dictionary:
	var result:Dictionary={}
	for b:RigidBody3D in physical(hit_owner).owned_bodies():result[b.get_instance_id()]=b.global_position
	return result
func physical_contract(hit_owner:RefCounted)->Dictionary:
	var result:Dictionary={}
	for body:RigidBody3D in physical(hit_owner).owned_bodies():result[body.get_instance_id()]={"mass":body.mass,"layer":body.collision_layer,"mask":body.collision_mask,"freeze":body.freeze}
	result.joints=physical(hit_owner)._body.snapshot().joints
	return result
func capture(_label:String)->void:pass
func choose_firing_fixture()->bool:
	for offset:Vector3 in [Vector3(3,0,3),Vector3(3,0,-3),Vector3(-3,0,3),Vector3(-3,0,-3),Vector3(4,0,0),Vector3(-4,0,0),Vector3(0,0,4),Vector3(0,0,-4)]:
		var point:Vector3=owner._token.body.global_position+offset
		var floor:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*3,1,[player.get_rid()]))
		if floor.is_empty() or floor.normal.y<.8 or not floor.collider is StaticBody3D:continue
		point.y=floor.position.y+.003
		player.global_position=point;player.velocity=Vector3.ZERO;aim();await sync(10)
		if player.is_on_floor() and real_sight().ok:return true
	return false
func ready_port()->void:
	port=Port.new();port_records=[]
	public_records=scene.preview_population.residents.public_final_dead_contact_capabilities()
	for record:Dictionary in public_records:port_records.append({"ragdoll_host":record.ragdoll_host,"binding":record.binding,"current_life":capability_current})
	var configured:Dictionary=port.configure(player,port_records,test_options)
	check(configured.get("ok",false),"explicit_real_life_port_configured")
	print("PORT_READY ",str(port.player_final_dead_contact_ready()))
	check(player.set_final_dead_contact_owner(Callable(port,"player_final_dead_contact_ready"),record_admit),"canonical_player_sampler_bound")
func check_non_dead_gate(label:String)->void:
	for record:Dictionary in scene.preview_population.residents.public_final_dead_contact_capabilities():
		if record.binding.source_id!=owner._token.source_id:continue
		var probe:=Port.new();var configured:Dictionary=probe.configure(player,[record],test_options)
		check(configured.get("ok",false) and not probe.player_final_dead_contact_ready().get("ready",false),"public_readiness_rejects_"+label)
		probe.dispose();return
	check(false,"public_capability_available_"+label)
func prepare_walk(mode:String)->bool:
	walking=false;tracking=false;player.set_physics_process(false);walk_direction=Vector3.ZERO
	var parts:Array=physical(owner).owned_bodies()
	parts.sort_custom(func(a:RigidBody3D,b:RigidBody3D):
		if a.get_instance_id()==preferred_part or b.get_instance_id()==preferred_part:return a.get_instance_id()==preferred_part
		return a.sleeping if a.sleeping!=b.sleeping else a.global_position.y<b.global_position.y)
	var capsule:CollisionShape3D=player.get_node("PlayerCapsule")
	for body:RigidBody3D in parts:
		if body.global_position.y>.5:continue
		var directions:Array=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
		if preferred_direction!=Vector3.ZERO:directions.erase(preferred_direction);directions.push_front(preferred_direction)
		for direction:Vector3 in directions:
			var position:Vector3=body.global_position-direction*.68
			var floor:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*3,1,[player.get_rid()]))
			if floor.is_empty() or floor.normal.y<.8:continue
			position.y=floor.position.y+.003
			var q:=PhysicsShapeQueryParameters3D.new();q.shape=capsule.shape;q.transform=Transform3D(capsule.global_basis,position+capsule.global_position-player.global_position);q.collision_mask=257;q.exclude=[player.get_rid()];q.margin=.001
			if not scene.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():continue
			q.collision_mask=256;q.motion=-direction*.8
			if scene.get_world_3d().direct_space_state.cast_motion(q)[0]<1:continue
			player.global_position=position
			player.velocity=Vector3.ZERO
			# Native floor acquisition; same move path with zero horizontal request.
			walking=true;walk_direction=Vector3.ZERO;await sync(5)
			check(player.is_on_floor(),"actual_player_supported_"+mode)
			walk_direction=direction*(-1 if mode=="away" else 0 if mode=="stationary" else 1)
			return true
	check(false,"original_corpse_clear_approach_"+mode);return false
func exercise(mode:String)->Dictionary:
	var initial:=replies.size();var before:=points(owner);var saved_health:=health(owner);var initial_sleep:=sleep_count(owner);var saved_contract:=physical_contract(owner)
	var steps:=0
	preferred_part=0;preferred_direction=Vector3.ZERO
	response_observation={"before":before,"max_joint":0.0,"max_energy":0.0,"max_speed":0.0,"max_angular":0.0,"max_displacement":0.0,"woke":false,"initial_sleep":initial_sleep}
	# During actual contacts keep wall-clock rate limits at real 60FPS. Natural
	# settling/measurement can run accelerated; no fake cooldown or event clock.
	Engine.max_fps=60
	pace_contacts=true
	for approach_index:int in (3 if mode=="toward" else 1):
		if not await prepare_walk(mode):Engine.max_fps=0;pace_contacts=false;return {}
		for i:int in (45 if mode=="toward" else 28):
			await sync();steps+=1
		walking=false;walk_direction=Vector3.ZERO;await sync(11)
	Engine.max_fps=0
	pace_contacts=false
	walking=false;walk_direction=Vector3.ZERO
	var woke:=sleep_count(owner)<initial_sleep
	var max_joint:=0.0;var max_energy:=0.0;var max_speed:=0.0;var max_angular:=0.0;var max_displacement:=0.0
	for i:int in 120:
		await sync()
		var snap:Dictionary=physical(owner)._body.snapshot()
		max_joint=maxf(max_joint,snap.max_joint_anchor_error_m);max_energy=maxf(max_energy,snap.kinetic_energy_j);max_speed=maxf(max_speed,snap.max_linear_speed);max_angular=maxf(max_angular,snap.max_angular_speed)
		woke=woke or sleep_count(owner)<initial_sleep
		for body:RigidBody3D in physical(owner).owned_bodies():max_displacement=maxf(max_displacement,before[body.get_instance_id()].distance_to(body.global_position))
	var accepts:=0;var rejects:Dictionary={};var last:Dictionary={}
	for i:int in range(initial,replies.size()):
		var result:Dictionary=replies[i].result
		if result.get("ok",false):
			accepts+=1;last=result
			if result.was_sleeping:exact_sleeping_segment_wakes+=1
		else:rejects[result.get("reason","unknown")]=int(rejects.get(result.get("reason","unknown"),0))+1
	max_joint=response_observation.max_joint;max_energy=response_observation.max_energy;max_speed=response_observation.max_speed;max_angular=response_observation.max_angular;max_displacement=response_observation.max_displacement
	woke=response_observation.woke
	response_observation={}
	check(health(owner)==saved_health,mode+":actual_HP_blood_death_unchanged")
	check(physical_contract(owner)==saved_contract,mode+":mass_joints_filters_freeze_unchanged")
	check(accepts>1 if mode=="toward" else accepts==0,mode+":acceptance")
	if mode=="toward":
		check(woke if initial_sleep>0 else true,"native_impulse_wakes_available_natural_sleep")
		check(max_displacement>.01,"native_repeated_segment_nudge_visible_1cm")
		check(max_joint<.08 and max_speed<3 and max_angular<15 and max_energy<2,"bounded_physical_response")
	var row:Dictionary={"actor":owner._token.source_id,"mode":mode,"accepted":accepts,"rejections":rejects,"last":str(last),"initial_sleep":initial_sleep,"woke":woke,"max_segment_displacement_m":max_displacement,"max_joint_error_m":max_joint,"max_kinetic_energy_j":max_energy,"max_linear_speed":max_speed,"max_angular_speed":max_angular,"health_unchanged":health(owner)==saved_health,"steps":steps}
	measurements.append(row);return row
func run()->void:
	if DisplayServer.get_name()!="headless":check(false,"headless_only_proposal");finish();return
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_resident_walk_enabled=false;root.add_child(scene)
	while not scene.preview_ready:await sync()
	player=scene._player;weapons=scene.preview_weapons;scripted_controls=true;controls()
	check(weapons.equip("revolver").get("ok",false),"actual_revolver")
	weapons.shot_emitted.connect(func(shot:Dictionary,_muzzle:Dictionary,_origin:Vector3,_direction:Vector3):shots.append({"shot_id":shot.shotId}))
	weapons.effects.cosmetic_impact.connect(func(hit:Dictionary):impacts.append(hit))
	for candidate:RefCounted in scene.preview_population.hit_owners:
		owner=candidate;target_fallen=false;tracking=true
		check_non_dead_gate("alive:"+str(owner._token.source_id))
		if not await choose_firing_fixture():check(false,"clear_original_shooting_fixture");continue
		var sample:=RandomNumberGenerator.new()
		for seed_value:int in 100:
			sample.seed=seed_value;sample.randf()
			if sample.randf()<.72:owner._rng.seed=seed_value;break
		await fire_once("actual_medical_hit:"+str(owner._token.source_id))
		check(owner.snapshot().row.get("_medicalDowned",false),"source_medical_survival")
		check_non_dead_gate("medical:"+str(owner._token.source_id))
		target_fallen=true;await sync(60);await fire_once("actual_final_hit:"+str(owner._token.source_id))
		check(owner.snapshot().row.get("dead",false) and physical(owner).status().final_dead,"original_actual_final_dead")
	tracking=false;player.global_position=Vector3(31,.01,-18);await sync(10)
	ready_port()
	for candidate:RefCounted in scene.preview_population.hit_owners:
		owner=candidate
		var sleeping:=false
		for tick:int in 900:
			if sleep_count(owner)==16:sleeping=true;break
			await sync()
		if sleeping:full_natural_sleep_proofs+=1
		if not sleeping:
			var pending:Array=[]
			for body:RigidBody3D in physical(owner).owned_bodies():
				if not body.sleeping:pending.append({"part":str(body.name),"velocity":str(body.linear_velocity),"angular":str(body.angular_velocity)})
			var baseline:Dictionary=physical(owner)._body.snapshot()
			var rested:bool=baseline.kinetic_energy_j<.1 and baseline.max_linear_speed<.15 and baseline.max_angular_speed<2 and baseline.max_joint_anchor_error_m<.02
			measurements.append({"actor":owner._token.source_id,"not_fully_sleeping":true,"rested_low_energy":rested,"sleeping":sleep_count(owner),"awake":pending,"physical":str(baseline)})
			check(rested,"baseline_rested_even_if_not_all_sleeping")
			if not rested:continue
		await exercise("stationary");await exercise("away");await exercise("toward")
	check(full_natural_sleep_proofs>0,"at_least_one_original_all16_natural_sleep")
	exact_sleeping_segment_wakes=0
	for did_wake:bool in wake_targets.values():
		if did_wake:exact_sleeping_segment_wakes+=1
	check(exact_sleeping_segment_wakes>0,"at_least_one_exact_sleeping_part_native_wake")
	finish()
func finish()->void:
	if done:return
	walking=false;tracking=false;scripted_controls=false;done=true
	var report:Dictionary={"pass":failures.is_empty(),"checks":checks,"failures":failures,"options":test_options,"measurements":measurements,"guard_evidence":guard_evidence,"contacts":str(replies),"full_natural_sleep_proofs":full_natural_sleep_proofs,"exact_sleeping_segment_wakes":exact_sleeping_segment_wakes,"port_stats":port.stats if port!=null else {},"elapsed_ms":Time.get_ticks_msec()-began,"scope":"actual main original three NPCs, real weapon HP death, canonical player movement with current receipt and proposed port; not production enable or perf/GPU acceptance"}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("THREE_CORPSES_RESULT ",JSON.stringify(report))
	if port!=null:port.dispose()
	if is_instance_valid(scene):scene.queue_free()
	quit(0 if failures.is_empty() else 1)
