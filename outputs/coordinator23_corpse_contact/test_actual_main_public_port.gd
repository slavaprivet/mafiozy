extends "../artist23_combat_next/test_combined_eyes_input.gd"
## FUTURE acceptance harness. Public owner port is mandatory, no private force.
## All original actual weapon/HP/medical/death/eye checks remain inherited.
var port:Object
var port_path:=""
var ready_method:="player_final_dead_contact_ready"
var admit_method:="admit_player_final_dead_contact"
var contact_started:=false
var contact_completed:=false
var port_bound:=false
var records:Array=[]
var cases:Array=[]
var first_accept_before:Dictionary={}
var first_accept_after:Dictionary={}
var first_request:Dictionary={}
var physical_baseline:Dictionary={}
var harness_started:=0
var observer_pixels_before:Dictionary={}
var corpse_observer_frame:=Transform3D.IDENTITY
func _initialize()->void:
	harness_started=Time.get_ticks_msec();Engine.max_fps=60
	if DisplayServer.get_name()!="headless":
		root.unfocusable=true;DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-32000,-32000))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--contact-port="):port_path=arg.trim_prefix("--contact-port=")
		if arg.begins_with("--contact-ready-method="):ready_method=arg.trim_prefix("--contact-ready-method=")
		if arg.begins_with("--contact-admit-method="):admit_method=arg.trim_prefix("--contact-admit-method=")
	if not out.is_absolute_path():push_error("Absolute --qa-out required");quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	var player_script:Script=load("res://scripts/preview_player.gd")
	if not script_method(player_script,"set_final_dead_contact_owner"):skip("root_player_binding_not_integrated");return
	if port_path.is_empty():
		var population_script:Script=load("res://scripts/preview_population.gd")
		if not script_method(population_script,ready_method) or not script_method(population_script,admit_method):skip("public_NPC_owner_port_not_delivered");return
	else:
		if not port_path.is_absolute_path() or not FileAccess.file_exists(port_path):skip("supplied_port_path_missing");return
		var port_script:Script=load(port_path)
		if port_script==null or not script_method(port_script,"bind_to_preview") or not script_method(port_script,ready_method) or not script_method(port_script,admit_method):skip("supplied_port_contract_missing");return
	super._initialize()
func script_method(script:Script,method:String)->bool:
	for row:Dictionary in script.get_script_method_list():
		if row.name==method:return true
	return false
func json_safe(value:Variant)->Variant:
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Vector2:return [value.x,value.y]
	if value is RID:return {"rid_id":value.get_id()}
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[str(key)]=json_safe(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item:Variant in value:result.append(json_safe(item))
		return result
	if value is Object or value is Transform3D or value is Basis:return str(value)
	return value
func skip(reason:String)->void:
	var result:Dictionary={"status":"SKIP","pass":false,"reason":reason,"force_acceptance":false,"main_loaded":false,"production_modified":false}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("PUBLIC_PORT_SKIP ",reason);done=true;quit(0)
func bind_port()->bool:
	if port_bound:return true
	if port_path.is_empty():port=scene.preview_population
	else:
		port=load(port_path).new()
		var binding:Variant=port.call("bind_to_preview",scene)
		if not binding is Dictionary or not binding.get("ok",false):check(false,"public_port_bind_rejected");return false
	port_bound=player.set_final_dead_contact_owner(ready_proxy,admit_proxy)
	check(port_bound,"root_player_bound_to_public_port");return port_bound
func ready_proxy()->Dictionary:
	var value:Variant=port.call(ready_method)
	return value if value is Dictionary else {}
func admit_proxy(request:Dictionary)->Dictionary:
	var before:=read_physical()
	var value:Variant=port.call(admit_method,request)
	var result:Dictionary=value if value is Dictionary else {"ok":false,"reason":"port_return_type"}
	records.append({"request":request.duplicate(true),"result":result.duplicate(true)})
	if result.get("ok",false) and first_request.is_empty():
		first_request=request.duplicate(true);first_accept_before=before;first_accept_after=read_physical()
	return result
func health_receipt()->Dictionary:
	var state:Dictionary=owner.snapshot();var row:Dictionary=state.row
	return {"hp":row.get("hp"),"dead":row.get("dead",false),"medical":row.get("_medicalDowned",false),"deadAt":row.get("deadAt"),"death_from_downed":row.get("_deathFromDowned",false),"damage_revision":state.last_result.get("revision"),"blood_revision":owner.blood._last_revision if owner.blood!=null else -1}
func read_physical()->Dictionary:
	if owner==null or not is_instance_valid(scene):return {}
	var physical:RefCounted=scene.preview_population.residents._ragdolls.get(owner._token.source_id)
	if physical==null:return {}
	var bodies:Array=physical.owned_bodies();var positions:Dictionary={};var sleeping:=0;var mass:=0.0
	for body:RigidBody3D in bodies:
		positions[body.get_instance_id()]=body.global_position;mass+=body.mass
		if body.sleeping:sleeping+=1
	var raw:Dictionary=physical._body.snapshot() if physical._body!=null else {}
	return {"positions":positions,"sleeping":sleeping,"bodies":bodies.size(),"joints":raw.get("joints",0),"mass":mass,"joint_error":raw.get("max_joint_anchor_error_m",INF),"paused":raw.get("paused",false),"status":physical.status(),"health":health_receipt()}
func release_walk()->void:
	for action:StringName in [player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_RUN]:Input.action_release(action)
func fixture_near_target()->Dictionary:
	release_walk();await sync(14) # Let normal production acceleration stop drift.
	var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	var bodies:Array=physical.owned_bodies();var point:Vector3=owner._token.body.global_position+Vector3.UP*.2
	if physical.status().mode=="ACTIVE":
		# Read-only actual foot/shin position, no body placement or force fixtures.
		for body:RigidBody3D in bodies:
			if str(body.name).contains("foot") or str(body.name).contains("shin"):point=body.global_position;break
	for direction:Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var position:=point-direction*.62
		var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*3,1,[player.get_rid()])
		var floor:=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		if floor.is_empty() or floor.normal.y<.8:continue
		position.y=floor.position.y+.003
		var capsule:CollisionShape3D=player.get_node("PlayerCapsule")
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape;query.transform=Transform3D(capsule.global_basis,position+capsule.global_position-player.global_position);query.collision_mask=257;query.exclude=[player.get_rid()];query.margin=.001
		if not scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		query.collision_mask=256;query.motion=-direction*1.2
		var away_sweep:PackedFloat32Array=scene.get_world_3d().direct_space_state.cast_motion(query)
		if away_sweep.size()!=2 or away_sweep[0]<1:continue
		var from:=player.global_position;player.global_position=position;release_walk();await sync(5)
		check(player.is_on_floor(),"fixture_original_floor")
		cases.append({"fixture_from":str(from),"fixture_to":str(position),"actual_body_point":str(point),"direction":str(direction),"player_placement_only":true})
		return {"direction":direction,"point":point}
	check(false,"no_clear_supported_contact_approach");return {}
func walk_case(label:String,mode:String,expect_accept:bool)->void:
	if not bind_port():return
	tracking=false;release_walk()
	var before_count:=records.size();var before:=health_receipt()
	var approach:Dictionary=await fixture_near_target()
	if approach.is_empty():return
	var obstruction:StaticBody3D
	if mode=="wall":
		obstruction=StaticBody3D.new();scene.add_child(obstruction);obstruction.collision_layer=1
		obstruction.global_position=player.global_position+approach.direction*.34+Vector3.UP*.4
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.04,.8,1) if absf(approach.direction.x)>.5 else Vector3(1,.8,.04);shape.shape=box;obstruction.add_child(shape)
		await sync(3)
	if mode!="stationary":
		var direction:Vector3=approach.direction*(-1 if mode=="away" else 1)
		var local:Vector3=Basis(Vector3.UP,player._camera_yaw).inverse()*direction
		Input.action_press(player.ACTION_RIGHT,maxf(0,local.x));Input.action_press(player.ACTION_LEFT,maxf(0,-local.x))
		Input.action_press(player.ACTION_BACK,maxf(0,local.z));Input.action_press(player.ACTION_FORWARD,maxf(0,-local.z))
	await sync(18);release_walk();await sync(5)
	if is_instance_valid(obstruction):obstruction.queue_free();await sync(2)
	var accepted_count:=0
	for i:int in range(before_count,records.size()):
		if records[i].result.get("ok",false):accepted_count+=1
	check(accepted_count>0 if expect_accept else accepted_count==0,label+":public_owner_acceptance")
	check(health_receipt()==before,label+":HP_blood_death_revision_unchanged")
	cases.append({"case":label,"requests":records.size()-before_count,"accepted":accepted_count,"health":health_receipt()})
	tracking=not contact_started
func capture(label:String)->void:
	if label in ["01_before_hit","02_medical_fall"]:
		var previous:=player.global_position
		await walk_case("alive_no_force" if label=="01_before_hit" else "medical_no_force","toward",false)
		release_walk();await sync(14);player.global_position=previous;await sync(5)
		cases.append({"restore_previous_supported_player_fixture":str(previous)})
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_position(Vector2i(-32000,-32000))
		if label.begins_with("04_") or label.begins_with("05_"):
			if label.begins_with("04_"):
				observer.global_position=target_point()+Vector3(4.2,2.0,4.2);observer.look_at(target_point(),Vector3.UP);corpse_observer_frame=observer.global_transform
			observer.global_transform=corpse_observer_frame;observer.make_current()
			await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
			var positions:Dictionary=read_physical().positions;var maximum_pixels:=0.0
			for id:Variant in positions:
				var pixel:=observer.unproject_position(positions[id])
				if label.begins_with("04_"):observer_pixels_before[id]=pixel
				elif observer_pixels_before.has(id):maximum_pixels=maxf(maximum_pixels,pixel.distance_to(observer_pixels_before[id]))
			if label.begins_with("05_"):check(maximum_pixels>1,"fixed_observer_visible_displacement_over_1pixel");cases.append({"maximum_observer_pixels":maximum_pixels})
			var error:int=root.get_texture().get_image().save_png(out.path_join(label+".png"));check(error==OK,"capture:"+label)
			if error==OK:images.append(label+".png")
		else:await super.capture(label)
func finish()->void:
	if done:return
	if not contact_started and failures.is_empty() and owner!=null and owner.snapshot().row.get("dead",false):
		contact_started=true;tracking=false;contact_run.call_deferred();return
	if contact_started and not contact_completed and failures.is_empty():return
	super.finish()
	if not out.is_empty() and FileAccess.file_exists(out.path_join("RESULT.json")):
		var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("RESULT.json")))
		report.public_contact={"completed":contact_completed,"cases":cases,"records":records,"before":first_accept_before,"after":first_accept_after,"native_player_movement":true,"observer_camera_parity":false,"private_force_calls":false,"visual_GPU_accepted":DisplayServer.get_name()!="headless" and failures.is_empty(),"performance_valid":false}
		FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(json_safe(report),"\t"))
func contact_run()->void:
	if not bind_port():contact_completed=true;finish();return
	release_walk()
	var sleeping:=false
	for i:int in 480:
		var state:=read_physical()
		if state.bodies==16 and state.sleeping==16 and not state.paused:sleeping=true;break
		await sync()
	check(sleeping,"original_final_dead_naturally_sleeping")
	if not sleeping:contact_completed=true;finish();return
	physical_baseline=read_physical();await capture("04_natural_sleep_before_contact")
	await walk_case("dead_stationary","stationary",false)
	await walk_case("dead_away","away",false)
	await walk_case("dead_wall","wall",false)
	await walk_case("dead_actual_walking_contact","toward",true)
	await sync(90)
	var after:=read_physical();var maximum_displacement:=0.0
	for id:Variant in physical_baseline.positions:
		if after.positions.has(id):maximum_displacement=maxf(maximum_displacement,physical_baseline.positions[id].distance_to(after.positions[id]))
	check(not first_request.is_empty(),"actual_sampler_request_accepted")
	check(not first_accept_after.is_empty() and first_accept_after.sleeping<first_accept_before.sleeping,"native_contact_wakes_sleeping_segment")
	check(maximum_displacement>.01,"real_segment_displacement_over_1cm")
	check(after.bodies==16 and after.joints==15 and is_equal_approx(after.mass,physical_baseline.mass),"joints_and_mass_preserved")
	check(after.joint_error<.08,"bounded_joint_anchor_error")
	check(after.health==physical_baseline.health,"entire_contact_phase_health_unchanged")
	cases.append({"maximum_segment_displacement_m":maximum_displacement,"snapshot":str(after)})
	await capture("05_actual_physical_response")
	if not first_request.is_empty():
		for kind:String in ["replay","owner_epoch"]:
			var request:Dictionary=first_request.duplicate(true)
			if kind=="owner_epoch":request.owner_epoch+=1;request.event_id+="_invalid_epoch"
			var result:Variant=port.call(admit_method,request)
			check(result is Dictionary and not result.get("ok",false),"public_reject:"+kind)
			cases.append({"negative":kind,"result":str(result),"reason_is_owner_reported_not_isolated_guard_proof":true})
		# Public disposal only, after all physical/visual checks. No private thaw.
		if port.has_method("dispose"):
			port.call("dispose")
			var result:Variant=port.call(admit_method,first_request.duplicate(true))
			check(result is Dictionary and not result.get("ok",false),"public_reject:disposed")
		else:check(false,"public_port_dispose_contract_missing")
	contact_completed=true;finish()
