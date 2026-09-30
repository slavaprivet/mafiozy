extends SceneTree
## External QA input driver. Normal visible/unfocused window; no focus stealing.
## All game updates, native collisions, Fire/ammo, HP and force owners stay active.
var scene:Node3D
var player:CharacterBody3D
var weapons:Node
var target:RefCounted
var observer:Camera3D
var output:=""
var side:="baseline"
var pck_path:=""
var behavior_only:=false
var finished:=false
var started:=0
var tick_count:=0
var draw_count:=0
var track_aim:=false
var held_fire:=false
var walk:=Vector3.ZERO
var phase_name:="setup"
var samples:Array=[]
var events:Array=[]
var phases:Array=[]
var errors:Array[String]=[]
var placements:Array=[]
var input_actions:Array=[]
var fixed_camera:=Transform3D.IDENTITY
var target_anchor:=Vector3.ZERO
var observed_serial:=0
var bound_contact:=false
var last_draw_us:=0
var contact_health:Dictionary={}
var expected_sleep:=false
var foot_origin:=Vector3.ZERO
var foot_direction:=Vector3.ZERO
var sight_details:Dictionary={}
var foot_accepted_observed:=0
var foot_receipts:Array=[]
const BASELINE_SHA:="ec737f864181031e574bc4eb9e179a6d70cf3be6282a6068371b388b25167179"
const SOURCE_IDS:=["resident_169","resident_252","resident_72"]

func _initialize()->void:
	started=Time.get_ticks_usec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
		if arg.begins_with("--side="):side=arg.trim_prefix("--side=")
		if arg.begins_with("--pack="):pck_path=arg.trim_prefix("--pack=")
		if arg=="--behavior-only":behavior_only=true
	physics_frame.connect(drive)
	RenderingServer.frame_pre_draw.connect(render_camera)
	RenderingServer.frame_post_draw.connect(drawn)
	run.call_deferred()
func check(value:bool,label:String)->bool:
	if not value:errors.append(label);print("PAIR_FAIL ",label)
	return value
func event(kind:String,data:Dictionary={})->void:
	events.append({"kind":kind,"at_us":Time.get_ticks_usec()-started,"physics_frame":Engine.get_physics_frames(),"draw":draw_count,"phase":phase_name,"data":data})
func button(button_id:int,down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=button_id;e.pressed=down
	player._unhandled_input(e)
func release()->void:
	walk=Vector3.ZERO;held_fire=false
	for action:Variant in input_actions:Input.action_release(action)
	if is_instance_valid(player):button(MOUSE_BUTTON_LEFT,false)
func drive()->void:
	if finished:return
	tick_count+=1
	if not is_instance_valid(player):return
	# Explicit scripted logical controls isolate OS focus without bypassing owner gates.
	player._free_mouse_look=true
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if track_aim:aim()
	for action:Variant in input_actions:Input.action_release(action)
	if walk.length_squared()>.001:
		var local:Vector3=Basis(Vector3.UP,player._camera_yaw).inverse()*walk
		Input.action_press(player.ACTION_RIGHT,maxf(0,local.x));Input.action_press(player.ACTION_LEFT,maxf(0,-local.x))
		Input.action_press(player.ACTION_BACK,maxf(0,local.z));Input.action_press(player.ACTION_FORWARD,maxf(0,-local.z))
	if held_fire:button(MOUSE_BUTTON_LEFT,true)
	if target!=null and target._serial!=observed_serial:
		observed_serial=target._serial;event("completed_HP",health())
	if phase_name=="actual_walk_into_corpse":
		var sample:Variant=player.get("_corpse_contact_sampler")
		if sample!=null and sample.accepted>foot_accepted_observed:
			foot_accepted_observed=sample.accepted;foot_receipts.append(sample.last_result.duplicate(true));event("accepted_foot_contact",sample.last_result.duplicate(true))
func target_point()->Vector3:
	var physical:RefCounted=scene.preview_population.residents._ragdolls[target._token.source_id]
	if physical.mode=="ACTIVE" and physical._body!=null:return physical._body._bodies.chest.global_position
	return target._token.body.global_position+Vector3.UP*1.1
func aim()->void:
	var camera:Camera3D=player.get_preview_camera()
	# Feed the native attached spring-camera angles, not a top-level camera that
	# SpringArm's own scheduled update would reposition after this driver.
	var direction:Vector3=(target_point()-camera.global_position).normalized()
	player._camera_yaw=atan2(-direction.x,-direction.z)
	player._camera_pitch=asin(clampf(direction.y,-.85,.40))
	player._update_camera_rotation()
func render_camera()->void:
	if is_instance_valid(observer):observer.global_transform=fixed_camera;observer.fov=45.0;observer.make_current()
func drawn()->void:
	if finished:return
	draw_count+=1
	var now:=Time.get_ticks_usec()
	if not phase_name.begins_with("setup") and last_draw_us>0 and is_instance_valid(scene):
		samples.append({"at_us":now-started,"phase":phase_name,"wall_ms":(now-last_draw_us)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"process_monitor_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"vram_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"drawcalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"active_bodies":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)})
	last_draw_us=now
func sync(count:int=1)->void:
	for i in count:
		if finished:return
		await physics_frame;await process_frame
func health()->Dictionary:
	if target==null:return {}
	var row:Dictionary=target._row
	var marks:Variant=target.get("marks")
	return {"id":target._token.source_id,"hp":row.get("hp"),"dead":row.get("dead",false),"medical":row.get("_medicalDowned",false),"dead_at":row.get("deadAt"),"hp_commits":target._serial,"revision":target.last_result.get("revision",0),"blood_revision":target.blood._last_revision if target.blood!=null else -1,"blood_emitted":target.blood.renderer.emitted if target.blood!=null else 0,"marks":marks.renderer._marks.size() if marks!=null and marks.renderer!=null else 0}
func stable_health()->Dictionary:
	var r:=health();r.erase("blood_emitted");return r
func physical()->Dictionary:
	var host:RefCounted=scene.preview_population.residents._ragdolls[target._token.source_id]
	var bodies:Array=host.owned_bodies();var sleeping:=0;var mass:=0.0;var positions:Dictionary={}
	for body:RigidBody3D in bodies:
		if body.sleeping:sleeping+=1
		mass+=body.mass;positions[str(body.name)]=body.global_position
	var snap:Dictionary=host._body.snapshot() if host._body!=null else {}
	return {"mode":host.mode,"bodies":bodies.size(),"sleeping":sleeping,"mass":mass,"joints":snap.get("joints",0),"joint_error":snap.get("max_joint_anchor_error_m",0),"max_linear_speed":snap.get("max_linear_speed",0),"max_angular_speed":snap.get("max_angular_speed",0),"kinetic_energy_j":snap.get("kinetic_energy_j",0),"settled":snap.get("settled",false),"paused":snap.get("paused",false),"positions":positions,"status":host.status()}
func all_sleeping()->bool:
	var host:RefCounted=scene.preview_population.residents._ragdolls[target._token.source_id]
	var parts:Array=host.owned_bodies()
	if parts.size()!=16:return false
	for part:RigidBody3D in parts:
		if not part.sleeping:return false
	return true
func sampler()->Dictionary:
	var obj:Variant=player.get("_corpse_contact_sampler")
	if obj==null:return {"present":false,"accepted":0,"attempts":0}
	return {"present":true,"accepted":obj.accepted,"attempts":obj.attempts,"last_result":obj.last_result.duplicate(true)}
func geometry()->Array:
	var rows:Array=[]
	for own:RefCounted in scene.preview_population.hit_owners:
		var body:CharacterBody3D=own._token.body
		var shapes:Array=[]
		for shape:CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
			shapes.append({"type":shape.shape.get_class(),"disabled":shape.disabled,"height":shape.shape.height if shape.shape is CapsuleShape3D else -1,"radius":shape.shape.radius if shape.shape is CapsuleShape3D else -1})
		rows.append({"id":own._token.source_id,"life_generation":own._token.life_generation,"rig_bones":own._token.rig.get_bone_count(),"render_id":own._token.render_id,"layer":body.collision_layer,"mask":body.collision_mask,"shapes":shapes,"hp":own._row.hp,"position":body.global_position})
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.id<b.id)
	return rows
func snapshot()->Dictionary:
	return {"health":health(),"physical":physical(),"sampler":sampler(),"actors":geometry(),"buildings":scene._block.counts.buildings,"source_colliders":scene._block.counts.collisionBodies,"collision_objects":scene.find_children("*","CollisionObject3D",true,false).size(),"collision_shapes":scene.find_children("*","CollisionShape3D",true,false).size(),"mesh_nodes":scene.find_children("*","MeshInstance3D",true,false).size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"vram_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"player":player.global_position,"camera":fixed_camera,"ammo":weapons.fire_state.magazine,"shots":weapons.shots_count,"physics_frame":Engine.get_physics_frames(),"draw_count":draw_count}
func begin_phase(label:String)->void:
	phase_name=label;last_draw_us=0
	phases.append({"id":label,"start_us":Time.get_ticks_usec()-started,"before":snapshot()})
func end_phase()->void:
	phases[-1]["after"]=snapshot();phases[-1]["end_us"]=Time.get_ticks_usec()-started
	phase_name="setup_transition";last_draw_us=0
func image_at(label:String)->void:
	if behavior_only or finished:return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"PNG "+label)
func own_collider(value:Variant)->bool:
	if value==target._token.body:return true
	if not value is RigidBody3D:return false
	return value in scene.preview_population.residents._ragdolls[target._token.source_id].owned_bodies()
func sight()->bool:
	var camera:Camera3D=player.get_preview_camera()
	var hit:Dictionary=weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":100.0})
	var muzzle:Dictionary=weapons.presentation.current_muzzle()
	if not hit.has("point") or not muzzle.get("ok",false):return false
	var ray:Dictionary=weapons._projectile_ray({"origin":muzzle.origin,"direction":(hit.point-muzzle.origin).normalized(),"range":muzzle.origin.distance_to(hit.point)+.03})
	sight_details={"camera":camera.global_transform,"target":target_point(),"camera_hit":str(hit),"muzzle":str(muzzle),"muzzle_hit":str(ray)}
	return own_collider(hit.get("collider")) and own_collider(ray.get("collider"))
func place_player(point:Vector3,distance:float,require_away:bool,diagonal:bool=false)->Dictionary:
	release();await sync(14)
	var directions:Array=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
	if diagonal:directions=[Vector3(-1,0,-1).normalized(),Vector3(-1,0,1).normalized(),Vector3(1,0,-1).normalized(),Vector3(1,0,1).normalized()]
	for direction:Vector3 in directions:
		var position:Vector3=point-direction*distance
		var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*3,1,[player.get_rid()])
		var floor:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		if floor.is_empty() or floor.normal.y<.8:continue
		position.y=floor.position.y+.003
		var capsule:CollisionShape3D=player.get_node("PlayerCapsule")
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape;query.transform=Transform3D(capsule.global_basis,position+capsule.global_position-player.global_position);query.collision_mask=257;query.exclude=[player.get_rid()];query.margin=.001
		var space:PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
		if not space.intersect_shape(query,1).is_empty():continue
		if require_away:
			query.collision_mask=257;query.motion=-direction*1.2
			var sweep:PackedFloat32Array=space.cast_motion(query)
			if sweep.size()!=2 or sweep[0]<1:continue
		var from:=player.global_position;player.global_position=position
		await sync(6)
		if not player.is_on_floor():continue
		placements.append({"at_us":Time.get_ticks_usec()-started,"from":from,"to":position,"direction":direction,"reference":point,"outside_measured_phase":phase_name.begins_with("setup")})
		return {"position":position,"direction":direction}
	check(false,"no original-floor clear player placement");return {}
func fire(label:String)->bool:
	for i in 120:
		if float(weapons.fire_state.cooldown)<=0 and sight():break
		await sync()
	if not check(sight(),label+": actual camera AND presented muzzle contact"):
		event("unreachable_target",sight_details);return false
	var ammo:int=weapons.fire_state.magazine;var count:int=weapons.shots_count;var hp_count:int=target._serial
	event("input_LMB",{"label":label,"ammo":ammo,"target":target._token.source_id})
	held_fire=true;button(MOUSE_BUTTON_LEFT,true);await sync(2);held_fire=false;button(MOUSE_BUTTON_LEFT,false)
	for i in 60:
		if target._serial>hp_count:break
		await sync()
	return check(weapons.shots_count==count+1 and weapons.fire_state.magazine==ammo-1 and target._serial==hp_count+1,label+": exactly one actual round/HP commit")
func run()->void:
	if output.is_empty() or side not in ["baseline","candidate"]:quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(58.0).timeout.connect(func():check(false,"58 second deadline");finish())
	if behavior_only!= (DisplayServer.get_name()=="headless"):check(false,"headless requires behavior-only; GPU cannot use behavior-only");finish();return
	if not behavior_only:
		if pck_path.is_empty() or not FileAccess.file_exists(pck_path):check(false,"exact --pack required");finish();return
		if side=="baseline" and FileAccess.get_sha256(pck_path)!=BASELINE_SHA:check(false,"baseline PCK SHA mismatch");finish();return
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_title("Мафиози — сравнение боя: "+side)
	Engine.max_fps=60 if behavior_only else 0
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.use_taa=true;root.msaa_3d=Viewport.MSAA_4X
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		if scene.preview_ready:break
		await sync()
	if not check(scene.preview_ready and scene.preview_population!=null and scene.preview_population.hit_owners.size()==3 and int(scene._block.counts.buildings)==8,"full 3 NPC / 8 building scene ready"):finish();return
	player=scene._player;weapons=scene.preview_weapons
	input_actions=[player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_RUN,player.ACTION_JUMP]
	for action:Variant in input_actions:InputMap.action_erase_events(action)
	for own:RefCounted in scene.preview_population.hit_owners:
		if own._token.source_id=="resident_252":target=own
	if not check(target!=null,"exact target resident252"):finish();return
	target_anchor=target._token.body.global_position
	observer=Camera3D.new();scene.add_child(observer);observer.global_position=target_anchor+Vector3(5.2,3.4,7.2);observer.look_at(target_anchor+Vector3.UP,Vector3.UP);fixed_camera=observer.global_transform;observer.make_current()
	if side=="candidate":
		if not check(scene.has_method("_bind_final_dead_contact_port"),"candidate real root contact registration exists"):finish();return
		if player.get("_corpse_contact_sampler")==null:bound_contact=scene._bind_final_dead_contact_port()
		else:bound_contact=true
		if not check(bound_contact and player.get("_corpse_contact_sampler")!=null,"candidate real contact port bound"):finish();return
	else:check(player.get("_corpse_contact_sampler")==null,"baseline port absent expected")
	await sync(180)
	var setup:Dictionary=await place_player(target_anchor,3.6,true)
	if setup.is_empty():finish();return
	begin_phase("walk_alive_3")
	var walk_start:=player.global_position;walk=-setup.direction;await sync(60)
	check(player.global_position.distance_to(walk_start)>.1,"ordinary InputMap walking covered real ground")
	walk=setup.direction;await sync(60);release();await sync(30)
	end_phase();await image_at("01_alive")
	setup=await place_player(target._token.body.global_position,4.25,false,true)
	if setup.is_empty():finish();return
	track_aim=true;await sync(3)
	check(weapons.equip("revolver").get("ok",false),"ordinary equipped inventory revolver")
	button(MOUSE_BUTTON_RIGHT,true);await sync(20)
	weapons.shot_emitted.connect(func(shot:Dictionary,muzzle:Dictionary,_origin:Vector3,_direction:Vector3):event("shot_committed",{"id":shot.shotId,"ammo":weapons.fire_state.magazine,"pose_revision":muzzle.get("pose_revision"),"current_pose":player._pose_revision}))
	weapons.effects.cosmetic_impact.connect(func(hit:Dictionary):event("native_impact",{"shot":hit.shotId,"point":hit.point,"normal":hit.normal,"owned":own_collider(hit.get("collider"))}))
	# Shared source RNG fixture: first lethal torso shot chooses medical survival.
	var rng:=RandomNumberGenerator.new()
	for value in 100:
		rng.seed=value;rng.randf()
		if rng.randf()<.72:target._rng.seed=value;event("source_survival_seed",{"value":value});break
	begin_phase("cold_first_hit_and_medical_fall")
	if not await fire("first_hit"):finish();return
	await sync(90)
	check(target._row.hp==1 and target._row.get("_medicalDowned",false),"actual first hit source medical survival")
	end_phase();await image_at("02_medical")
	begin_phase("second_hit_and_final_fall")
	if not await fire("second_hit"):finish();return
	await sync(90)
	check(target._row.hp==0 and target._row.get("dead",false),"actual final death")
	if side=="candidate":check(health().marks>0,"candidate persistent wounds reached actual renderer")
	end_phase();track_aim=false;button(MOUSE_BUTTON_RIGHT,false);release()
	begin_phase("natural_settle")
	for i in 600:
		if all_sleeping():expected_sleep=true
		await sync()
	end_phase()
	# Fixed duration on both sides. Rest may remain physically awake; record it
	# honestly. Separate main07_02 owns the proven sleeping-body wake acceptance.
	begin_phase("resting_corpse_1_other_2_alive");await sync(180);end_phase();await image_at("03_rest")
	var host:RefCounted=scene.preview_population.residents._ragdolls[target._token.source_id]
	var part:RigidBody3D=host._body._bodies.foot_l
	setup=await place_player(part.global_position,.62,true)
	if setup.is_empty():finish();return
	foot_origin=player.global_position;foot_direction=setup.direction;contact_health=stable_health()
	begin_phase("actual_walk_into_corpse")
	var accepted_before:int=sampler().accepted
	foot_accepted_observed=accepted_before
	walk=foot_direction;await sync(30);release();await sync(90)
	check(player.global_position.distance_to(foot_origin)>.01,"foot phase real completed movement")
	check(stable_health()==contact_health,"foot touch preserves HP/blood damage/death/wound revisions")
	var accepted_after:int=sampler().accepted
	check(accepted_after>accepted_before if side=="candidate" else accepted_after==0,"candidate accepted physical foot contact / baseline zero control")
	var after:=physical();check(after.bodies==16 and after.joints==15 and after.joint_error<.08,"original body/joint integrity after walking contact")
	end_phase();await image_at("04_foot_response")
	finish()
func summary(rows:Array,key:String)->Dictionary:
	var values:Array=[]
	for row:Dictionary in rows:values.append(float(row[key]))
	if values.is_empty():return {"n":0}
	values.sort();return {"n":values.size(),"p50":values[clampi(int(ceil(values.size()*.5))-1,0,values.size()-1)],"p95":values[clampi(int(ceil(values.size()*.95))-1,0,values.size()-1)],"max":values.back()}
func finish()->void:
	if finished:return
	finished=true;release()
	for phase:Dictionary in phases:
		var rows:Array=[]
		for row:Dictionary in samples:
			if row.phase==phase.id:rows.append(row)
		phase["raw_samples"]=rows
		for key:String in ["wall_ms","gpu_ms","render_cpu_ms","static_bytes","vram_bytes","drawcalls","primitives"]:phase[key]=summary(rows,key)
		if not behavior_only:check(rows.size()>=30 and phase.gpu_ms.get("p95",0)>0,phase.id+": actual rendered GPU samples")
	var result:Dictionary={"schema":"loaded-combat-pair/v1","side":side,"errors":errors,"behavior_pass":errors.is_empty(),"performance_valid":not behavior_only and errors.is_empty(),"scope":"3 original NPC / 8 buildings, walking enabled; one resident252 medical/final/natural-rest/foot path, other2 remain alive. Rest can be awake: sleep/wake proved separately. No 3-corpse or positive headshot performance claim.","rendered":not behavior_only,"elapsed_s":(Time.get_ticks_usec()-started)/1000000.0,"pack_sha256":FileAccess.get_sha256(pck_path) if not pck_path.is_empty() else "source-stage","test_sha256":FileAccess.get_sha256(get_script().resource_path),"bound_contact":bound_contact,"all16_sleep_observed":expected_sleep,"foot_receipts":foot_receipts,"phases":phases,"events":events,"placements":placements,"camera":fixed_camera,"images_outside_measured_phases":true,"physics_hz":Engine.physics_ticks_per_second,"settings":{"size":[1280,720],"taa":root.use_taa,"msaa":root.msaa_3d,"vsync":"disabled","observer_fov":45},"coarse_monitors_not_per_frame_cpu_timings":true}
	FileAccess.open(output.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LOADED_COMBAT_PAIR ",side," errors=",errors," seconds=",result.elapsed_s)
	quit(0 if errors.is_empty() else 2)
