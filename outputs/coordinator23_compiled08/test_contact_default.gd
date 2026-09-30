extends "../artist23_combat_next/test_combined_eyes_input.gd"
## Compiled default-ON root binding, normal SCHEDULED player physics. Observer reads only.
var limits:Dictionary={}
var registered:=false
var observed_port:RefCounted
var receipts:Array=[]
var cases:Array=[]
var seen_events:Dictionary={}
var wake_targets:Dictionary={}
var preferred_part:=0
var preferred_direction:=Vector3.ZERO
var walking_direction:=Vector3.ZERO
var response:Dictionary={}
var active_wall:StaticBody3D
var wall_seen:=false
var paced:=false
var began:=0
var observer_frame:=Transform3D.IDENTITY
func _initialize()->void:
	began=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--contact-limits="):
			var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--contact-limits=")))
			if value is Dictionary:limits=value
	if not out.is_absolute_path() or limits.is_empty():push_error("Absolute --qa-out and explicit --contact-limits required");quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	if DisplayServer.get_name()!="headless":
		root.unfocusable=true;DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-32000,-32000))
	run.call_deferred()
func _process(delta:float)->bool:
	if not done and Time.get_ticks_msec()-began>45000:check(false,"45_second_wall_clock_deadline");finish();return false
	super._process(delta);observe();return false
func _physics_process(_delta:float)->bool:
	if paced:OS.delay_msec(16) # Pace actual owner wall-clock cooldown, not fake time.
	observe();return false # NEVER call or disable player._physics_process.
func physical()->RefCounted:return scene.preview_population.residents._ragdolls[owner._token.source_id]
func health()->Dictionary:
	var state:Dictionary=owner.snapshot();var row:Dictionary=state.row
	return {"hp":row.hp,"dead":row.get("dead",false),"medical":row.get("_medicalDowned",false),"deadAt":row.get("deadAt"),"revision":state.last_result.get("revision"),"blood":owner.blood._last_revision if owner.blood!=null else -1}
func points()->Dictionary:
	var result:Dictionary={}
	for body:RigidBody3D in physical().owned_bodies():result[body.get_instance_id()]=body.global_position
	return result
func physical_contract()->Dictionary:
	var result:Dictionary={}
	for body:RigidBody3D in physical().owned_bodies():result[body.get_instance_id()]={"mass":body.mass,"layer":body.collision_layer,"mask":body.collision_mask,"freeze":body.freeze}
	result.joints=physical()._body.snapshot().joints
	return result
func sleep_count()->int:
	var n:=0
	for body:RigidBody3D in physical().owned_bodies():
		if body.sleeping:n+=1
	return n
func observe()->void:
	if not registered or not is_instance_valid(player):return
	var sampler:RefCounted=player._corpse_contact_sampler # Installed root sampler, read only.
	var result:Dictionary=sampler.last_result if sampler!=null else {}
	if result.get("ok",false) and not seen_events.has(result.get("event_id")):
		seen_events[result.event_id]=true;receipts.append(result.duplicate(true))
		if preferred_part==0:preferred_part=result.applied_body_instance_id;preferred_direction=walking_direction
		if result.was_sleeping:wake_targets[result.applied_body_instance_id]=false
	for id:int in wake_targets:
		var body:Object=instance_from_id(id)
		if is_instance_valid(body) and body is RigidBody3D and not body.sleeping:wake_targets[id]=true
	if is_instance_valid(active_wall):
		for i:int in player.get_slide_collision_count():
			if player.get_slide_collision(i).get_collider()==active_wall:wall_seen=true
	if response.is_empty():return
	var snap:Dictionary=physical()._body.snapshot()
	for pair:Array in [["max_joint","max_joint_anchor_error_m"],["max_energy","kinetic_energy_j"],["max_speed","max_linear_speed"],["max_angular","max_angular_speed"]]:response[pair[0]]=maxf(response[pair[0]],snap[pair[1]])
	for body:RigidBody3D in physical().owned_bodies():response.max_displacement=maxf(response.max_displacement,response.before[body.get_instance_id()].distance_to(body.global_position))
func release_walk()->void:
	for action:StringName in [player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_RUN,player.ACTION_JUMP]:Input.action_release(action)
	walking_direction=Vector3.ZERO
func set_walk(direction:Vector3)->void:
	release_walk();player._camera_yaw=0.0;walking_direction=direction
	if direction.x>0:Input.action_press(player.ACTION_RIGHT,direction.x)
	if direction.x<0:Input.action_press(player.ACTION_LEFT,-direction.x)
	if direction.z>0:Input.action_press(player.ACTION_BACK,direction.z)
	if direction.z<0:Input.action_press(player.ACTION_FORWARD,-direction.z)
func firing_fixture()->bool:
	release_walk();tracking=true;await sync(12)
	var anchor:Vector3=target_point()
	for offset:Vector3 in [Vector3(3,0,3),Vector3(3,0,-3),Vector3(-3,0,3),Vector3(-3,0,-3),Vector3(4,0,0),Vector3(-4,0,0),Vector3(0,0,4),Vector3(0,0,-4)]:
		var position:=anchor+offset
		var floor:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*3,position-Vector3.UP*4,1,[player.get_rid()]))
		if floor.is_empty() or floor.normal.y<.8 or not floor.collider is StaticBody3D:continue
		position.y=floor.position.y+.003;player.global_position=position;player.velocity=Vector3.ZERO;aim();await sync(10)
		if player.is_on_floor() and real_sight().ok:return true
	return false
func wall_shape(direction:Vector3)->BoxShape3D:
	var box:=BoxShape3D.new();box.size=Vector3(.06,1.0,.82) if absf(direction.x)>.5 else Vector3(.82,1.0,.06)
	return box
func fixture(wall_reserved:=false)->Dictionary:
	tracking=false;release_walk();await sync(14)
	var parts:Array=physical().owned_bodies()
	parts.sort_custom(func(a:RigidBody3D,b:RigidBody3D):
		if a.get_instance_id()==preferred_part or b.get_instance_id()==preferred_part:return a.get_instance_id()==preferred_part
		return a.sleeping if a.sleeping!=b.sleeping else a.global_position.y<b.global_position.y)
	var targets:Array=[]
	if physical().status().mode!="ACTIVE":targets.append(owner._token.body.global_position+Vector3.UP*.2)
	else:
		for body:RigidBody3D in parts:
			if body.global_position.y<.65:targets.append(body.global_position)
	var capsule:CollisionShape3D=player.get_node("PlayerCapsule")
	for point:Vector3 in targets:
		var directions:Array=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
		if preferred_direction!=Vector3.ZERO:directions.erase(preferred_direction);directions.push_front(preferred_direction)
		for direction:Vector3 in directions:
			var distance:=1.15 if wall_reserved or physical().status().mode!="ACTIVE" else .68
			var position:Vector3=point-direction*distance
			var floor:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*3,1,[player.get_rid()]))
			if floor.is_empty() or floor.normal.y<.8 or not floor.collider is StaticBody3D:continue
			position.y=floor.position.y+.003
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape;query.transform=Transform3D(capsule.global_basis,position+capsule.global_position-player.global_position);query.collision_mask=257;query.exclude=[player.get_rid()];query.margin=.001
			if not scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			query.collision_mask=256;query.motion=-direction*.8
			if scene.get_world_3d().direct_space_state.cast_motion(query)[0]<1:continue
			var wall_position:Vector3=position+direction*.55+Vector3.UP*.51
			if wall_reserved:
				query.shape=wall_shape(direction);query.transform=Transform3D(Basis.IDENTITY,wall_position);query.motion=Vector3.ZERO;query.collision_mask=256
				if not scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			player.global_position=position;player.velocity=Vector3.ZERO;await sync(5)
			check(player.is_on_floor() and player.is_physics_processing(),"supported_fixture_scheduled_player")
			cases.append({"fixture":position,"contact_region":point,"direction":direction,"only_player_placed":true,"wall_reserved":wall_reserved})
			return {"direction":direction,"point":point,"wall_position":wall_position}
	return {}
func walk_case(label:String,mode:String,positive:=false)->void:
	var old_accepts:int=observed_port.stats.accepted;var saved_health:=health();var saved_contract:=physical_contract()
	preferred_part=0;preferred_direction=Vector3.ZERO
	if positive:response={"before":points(),"max_joint":0.0,"max_energy":0.0,"max_speed":0.0,"max_angular":0.0,"max_displacement":0.0}
	paced=true
	for approach:int in (3 if positive else 1):
		var placed:Dictionary=await fixture(mode=="wall")
		check(not placed.is_empty(),label+":clear_supported_approach")
		if placed.is_empty():paced=false;response={};return
		if mode=="wall":
			active_wall=StaticBody3D.new();active_wall.collision_layer=1;active_wall.collision_mask=1
			var shape:=CollisionShape3D.new();shape.shape=wall_shape(placed.direction);active_wall.add_child(shape);scene.add_child(active_wall);active_wall.global_position=placed.wall_position
			await sync(4)
			var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.45,placed.wall_position+placed.direction,1,[player.get_rid()])
			check(scene.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==active_wall,"wall_registered_actual_native_geometry");wall_seen=false
		var start:Vector3=player.global_position
		set_walk(placed.direction*(-1 if mode=="away" else 0 if mode=="stationary" else 1))
		await sync(45 if positive or mode=="wall" else 28)
		release_walk();await sync(11)
		if mode=="wall":
			check(wall_seen and (player.global_position-start).dot(placed.direction)<.35,"actual_wall_blocks_scheduled_movement")
			active_wall.queue_free();active_wall=null;await sync(3)
	paced=false
	if positive:await sync(90)
	observe();var measured:=response.duplicate(true);response={}
	var accepted:int=observed_port.stats.accepted-old_accepts
	check(accepted>1 if positive else accepted==0,label+":root_owner_acceptance")
	check(health()==saved_health,label+":HP_blood_death_unchanged")
	check(physical_contract()==saved_contract,label+":mass_joints_filters_freeze_unchanged")
	if positive:
		check(measured.max_displacement>.01,"actual_scheduled_contact_visible_over_1cm")
		check(measured.max_joint<.08 and measured.max_energy<2 and measured.max_speed<3 and measured.max_angular<15,"actual_scheduled_response_bounded")
	cases.append({"case":label,"accepted":accepted,"response":measured if positive else {},"health":health()})
func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	DisplayServer.window_set_position(Vector2i(-32000,-32000))
	if label.begins_with("04_"):
		observer.global_position=target_point()+Vector3(4.2,2.0,4.2);observer.look_at(target_point(),Vector3.UP);observer_frame=observer.global_transform
	if label.begins_with("04_") or label.begins_with("05_"):
		observer.global_transform=observer_frame;observer.make_current();await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
		var error:int=root.get_texture().get_image().save_png(out.path_join(label+".png"));check(error==OK,"capture:"+label)
		if error==OK:images.append(label+".png")
	else:await super.capture(label)
func run()->void:
	scene=load("res://scenes/main.tscn").instantiate();scene.preview_resident_walk_enabled=false;root.add_child(scene)
	while not scene.preview_ready:await sync()
	player=scene._player;weapons=scene.preview_weapons;scripted_controls=true;controls();release_walk()
	for candidate:RefCounted in scene.preview_population.hit_owners:
		if candidate._token.source_id=="resident_252":owner=candidate
	check(owner!=null and scene.preview_population.combat_status=="new_local_session","original252_actual_main_HP")
	if owner==null:finish();return
	var population:RefCounted=scene.preview_population
	var sampler:RefCounted=player._corpse_contact_sampler
	var startup:Dictionary={"default_enabled":scene.preview_final_dead_contact_enabled,"startup_status":scene.final_dead_contact_status,"port_installed":population._final_dead_contact_port!=null,"sampler_installed":sampler!=null,"binder_called_by_harness":false}
	if sampler!=null:
		startup.ready_hook_is_population=sampler._ready_hook.get_object()==population and sampler._ready_hook.get_method()==&"player_final_dead_contact_ready"
		startup.admit_hook_is_population=sampler._admit_hook.get_object()==population and sampler._admit_hook.get_method()==&"admit_player_final_dead_contact"
	cases.append({"default_startup":startup});print("DEFAULT_CONTACT_STARTUP ",JSON.stringify(startup))
	registered=startup.default_enabled and startup.startup_status=="bound_waiting_final_death" and startup.port_installed and startup.sampler_installed and startup.get("ready_hook_is_population",false) and startup.get("admit_hook_is_population",false)
	check(registered,"actual_default_startup_public_port_and_sampler_already_bound")
	if not registered:finish();return
	observed_port=scene.preview_population._final_dead_contact_port # Read-only stats.
	check(player.is_physics_processing() and player._corpse_contact_sampler!=null,"scheduled_player_production_sampler")
	check(weapons.equip("revolver").get("ok",false),"actual_revolver_equip")
	observer=Camera3D.new();scene.add_child(observer);observer.fov=65
	RenderingServer.frame_post_draw.connect(func():draws+=1)
	weapons.shot_emitted.connect(func(shot:Dictionary,muzzle:Dictionary,_origin:Vector3,_direction:Vector3):
		check(muzzle.get("ok",false) and muzzle.pose_revision==player._pose_revision,"actual_shot_fresh_presented_muzzle");shots.append({"shot_id":shot.shotId}))
	weapons.effects.cosmetic_impact.connect(func(impact:Dictionary):impacts.append(impact))
	check(not scene.preview_population.player_final_dead_contact_ready().get("ready",false),"alive_public_readiness_false")
	await walk_case("alive_no_force","toward")
	target_fallen=false;check(await firing_fixture(),"actual_clear_first_shot_fixture")
	phase("before_hit");await capture("01_before_hit")
	var rng:=RandomNumberGenerator.new()
	for seed_value:int in 100:
		rng.seed=seed_value;rng.randf()
		if rng.randf()<.72:owner._rng.seed=seed_value;break
	await fire_once("first_input_hit")
	var snapshot:Dictionary=owner.snapshot()
	check(snapshot.row.hp==1 and snapshot.row.get("_medicalDowned",false) and not snapshot.row.get("dead",false),"input_hit_genuine_medical_survival")
	check(snapshot.physical.get("ok",false) and not physical()._eyes.closed,"medical_fall_original_eyes_open")
	if not snapshot.row.get("_medicalDowned",false):finish();return
	target_fallen=true;await sync(60);await capture("02_medical_fall")
	check(not scene.preview_population.player_final_dead_contact_ready().get("ready",false),"medical_public_readiness_false")
	await walk_case("medical_no_force","toward")
	check(await firing_fixture(),"actual_clear_finisher_fixture_tracking_restored")
	await fire_once("second_input_hit");snapshot=owner.snapshot()
	check(owner.blood!=null and owner.blood._last_revision==owner.last_result.revision,"real_input_blood_accepted_revision")
	check(snapshot.row.hp==0 and snapshot.row.get("dead",false) and snapshot.row.get("_deathFromDowned",false),"input_fallen_hit_final_death")
	check(physical().status().final_dead and physical()._eyes.closed,"same_body_final_death_original_eyes_closed")
	if not snapshot.row.get("dead",false):finish();return
	await capture("03_final_death");tracking=false;release_walk();await sync(15)
	var natural_sleep:=false
	for tick:int in 1200:
		if sleep_count()==16:natural_sleep=true;break
		await sync()
	check(natural_sleep,"original252_all16_natural_sleep_no_forced_state")
	if not natural_sleep:cases.append({"sleep_failure":str(physical()._body.snapshot())});finish();return
	await capture("04_natural_sleep_before_contact")
	await walk_case("dead_stationary","stationary")
	await walk_case("dead_moving_away","away")
	await walk_case("dead_actual_wall","wall")
	await walk_case("dead_scheduled_player_contact","toward",true)
	check(wake_targets.values().has(true),"exact_contacted_naturally_sleeping_part_wakes")
	check(player.is_physics_processing(),"normal_player_schedule_preserved")
	await capture("05_actual_physical_response");finish()
func json_safe(value:Variant)->Variant:
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[str(key)]=json_safe(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item:Variant in value:result.append(json_safe(item))
		return result
	if value is Object or value is RID or value is Transform3D or value is Basis:return str(value)
	return value
func finish()->void:
	if done:return
	done=true;paced=false;tracking=false;scripted_controls=false
	if is_instance_valid(player):release_walk();player._unhandled_input(mouse(false))
	var report:Dictionary={"pass":failures.is_empty(),"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-began,"root_population_registration":registered,"normal_scheduled_player_physics":true,"direct_player_physics_calls":false,"external_sampler_or_force":false,"read_only_private_observation":true,"limits":limits,"cases":cases,"accepted_receipts":receipts,"exact_part_wake":wake_targets,"shots":shots,"impacts":impacts,"images":images,"phases":phases,"port_stats":observed_port.stats if observed_port!=null else {},"test_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"actual original252 medical/death then root-bound contact through scheduled player InputMap; QA observer camera, no FPS/GPU acceptance"}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(json_safe(report),"\t"));print("ROOT_MAIN_CONTACT_RESULT ",JSON.stringify(json_safe(report)))
	if is_instance_valid(scene):scene.queue_free()
	quit(0 if failures.is_empty() else 1)
