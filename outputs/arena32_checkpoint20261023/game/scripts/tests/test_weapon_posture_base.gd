extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const Posture=preload("res://scripts/weapons/weapon_posture_base.gd")
const Weapon=preload("res://scripts/weapons/weapon_pose.gd")
const Presentation=preload("res://scripts/weapons/player_weapon_presentation.gd")
const Occupant=preload("res://scripts/vehicle_visual/vehicle_occupant_pose.gd")
var checks:=0;var failures:Array[String]=[]
var max_posture:=0.0;var max_final:=0.0;var max_floor:=0.0;var max_skin:=0.0
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func matrix(v:Array)->Transform3D:return Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[4],v[5],v[6]),Vector3(v[8],v[9],v[10])),Vector3(v[12],v[13],v[14]))
func vector(v:Array)->Vector3:return Vector3(v[0],v[1],v[2])
func frames(values:Array)->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	for v:Array in values:result.append(matrix(v))
	return result
func frame(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in ["actor_world","visual_pivot_world","skeleton_world","offset_world"]:result[key]=matrix(value[key])
	return result
func base(value:Dictionary)->Dictionary:
	var q:Array=value.visual.visual_rotation
	return {"valid":true,"poses":frames(value.poses),"visual_offset":vector(value.visual.visual_offset),"visual_rotation":Quaternion(q[0],q[1],q[2],q[3]),"scaled_offset":vector(value.visual.scaled_offset),"authority_epoch":0}
func error(a:Transform3D,b:Transform3D)->float:return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func write(player:Node3D,selected:Dictionary)->bool:
	var accepted:=selected.duplicate();accepted.melee={"test_only_writer_route":true}
	return player._apply_selected_pose(accepted,player._pose_epoch)
func skin_min(player:Node3D,poses:Array,rotation:Quaternion)->float:
	# Independent scalar reference scans ALL imported original vertices/weights.
	var globals:Array[Transform3D]=[];var rig:Skeleton3D=player._pose_skeleton
	for i:int in 28:globals.append(poses[i] if rig.get_bone_parent(i)<0 else globals[rig.get_bone_parent(i)]*poses[i])
	var prefix:Transform3D=Transform3D(Basis(rotation),Vector3.ZERO)*(player._pose_motion.global_transform.affine_inverse()*rig.global_transform)
	var lowest:=INF
	for mesh:MeshInstance3D in player._pose_motion.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var binds:Array[Transform3D]=[]
		for b:int in mesh.skin.get_bind_count():binds.append(prefix*globals[rig.find_bone(mesh.skin.get_bind_name(b))]*mesh.skin.get_bind_pose(b))
		for surface:int in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			for i:int in arrays[Mesh.ARRAY_VERTEX].size():
				var point:=Vector3.ZERO
				for j:int in 4:point+=(binds[arrays[Mesh.ARRAY_BONES][i*4+j]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+j]
				lowest=minf(lowest,point.y)
	return lowest
func _initialize()->void:call_deferred("run")
func run()->void:
	var args:=OS.get_cmdline_user_args();var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	check(data.source_hash_normalization=="crlf_to_lf","source normalization")
	for pin:Dictionary in data.source_inputs:check(FileAccess.get_file_as_string(args[2].path_join(pin.path)).replace("\r\n","\n").sha256_text()==pin.sha256,"source pin")
	var player:=Player.new();player.set_meta("actor_id","posture-hero");player.set_meta("life_generation",1);root.add_child(player);player.set_physics_process(false);player.set_process(false)
	check(FileAccess.get_sha256("res://assets/hero.glb")==data.asset_sha256,"actual hero pin")
	var posture:=Posture.new();var bind_start:=Time.get_ticks_usec();check(posture.configure_player(player),"actual cached skin and rest configured");var bind_us:=Time.get_ticks_usec()-bind_start
	var controller_checks:=0
	for item:Dictionary in data.controller:
		var queried:Array=[]
		var callback:=func(height:float,target:String)->bool:queried.append({"height":height,"target":target});return height<=item.input.get("ceiling",3.0)
		if item.input.has("target"):check(posture.request_posture(item.input.target,callback)==item.accepted,"source request rising clearance")
		var actual:=posture.step_posture(item.input.dt,callback)
		check(queried.size()==item.queried.size(),"source exact clearance query count")
		for i:int in mini(queried.size(),item.queried.size()):check(absf(queried[i].height-item.queried[i].height)<1e-10 and queried[i].target==item.queried[i].target,"source requested collision height")
		for key:String in ["value","crouch","prone","height","eyeHeight","maxSpeed","speedMultiplier"]:check(absf(actual[key]-item.output[key])<1e-10,"source controller "+key)
		check(actual.target==item.output.target and actual.blocked==item.output.blocked and actual.crawl==item.output.crawl,"source target blocked crawl")
		controller_checks+=1
	posture.reset_posture()
	var sampler:=Weapon.new();check(sampler.configure(PackedStringArray(data.names),PackedInt32Array(data.parents),frames(data.rest),matrix(data.rest_rig_to_actor)),"source weapon configure")
	var presentation:=Presentation.new();check(presentation.configure(player).ok,"actual presentation configure")
	var times:Array[int]=[];var fulltimes:Array[int]=[];var count:=0;var last_selected:Dictionary={}
	for case:Dictionary in data.cases:
		var b:=base(case.snapshots.base);var context:=frame(case.snapshots.base.frame)
		posture.reset_posture();posture.request_posture("prone" if case.value>1 else "crouch");posture.step_posture(case.value/2.1);posture.seed_gait(0,0)
		var source_motion:Dictionary=case.motion.duplicate();source_motion.actor_world=context.actor_world;source_motion.actor_yaw=context.actor_yaw;source_motion.standing_phase=0.0;source_motion.standing_gait=0.0
		if source_motion.distance==null:source_motion.distance=NAN
		var from_gait:Dictionary=posture.sample_ground(b,source_motion,case.aim.aimYaw,0)
		check(from_gait.valid,"confined source gait valid")
		if from_gait.valid:
			check(absf(from_gait.weapon_posture.phase-case.phase)<1e-10 and absf(from_gait.weapon_posture.gait-case.gait)<1e-10,"original distance/time crawl phase and damping")
			for i:int in 28:check(error(from_gait.poses[i],matrix(case.snapshots.posture.poses[i]))<.00004,"source gait rebuilt then exact posture "+data.names[i])
		var selected:Dictionary=posture.sample_posture(b,context,case.posture,case.phase,case.gait,0,true)
		check(selected.valid,"source posture valid")
		if not selected.valid:continue
		for i:int in 28:
			var difference:=error(selected.poses[i],matrix(case.snapshots.posture.poses[i]));max_posture=maxf(max_posture,difference)
			check(difference<.00004,"original posture "+case.id+" "+str(case.value)+" "+data.names[i]+" "+str(difference))
		var armed:Dictionary=sampler.sample(selected,case.weapon,context,case.aim,case.posture,case.phase,case.gait,0)
		check(armed.valid,"source posture plus weapon")
		if not armed.valid:continue
		for i:int in 28:
			var difference:=error(armed.poses[i],matrix(case.final.poses[i]));max_final=maxf(max_final,difference)
			check(difference<.00005,"full original crouch/prone bone "+case.id+" "+str(case.value)+" "+data.names[i]+" "+str(difference))
		var stamp:=Time.get_ticks_usec();var grounded:=posture.ground_after_weapon(armed);times.append(Time.get_ticks_usec()-stamp)
		check(grounded.valid,"full-skin floor result")
		if case.posture.prone>.001:
			var difference:float=grounded.visual_offset.distance_to(vector(case.final.visual.visual_offset));max_floor=maxf(max_floor,difference)
			check(difference<.00001,"source postweapon ground correction "+str(difference))
		if true:
			var scalar:=skin_min(player,armed.poses,armed.visual_rotation)
			var difference:float=absf(grounded.visual_offset.y+scalar);max_skin=maxf(max_skin,difference)
			check(difference<.000001,"packed support equals full actual8338 scan")
		count+=1
		# Full actual player pipeline uses the native SELECTED LOCOMOTION bones,
		# not a standing rest pose decorated with a pretend crouch/prone flag.
		check(presentation.equip(case.id).ok,"actual original gun")
		var locomotion:Dictionary=player._locomotion.sample(.016,Vector3(0,0,.8) if case.variant>0 else Vector3.ZERO,true)
		var phase:float=player._locomotion._phase;var gait:float=player._locomotion._gait
		stamp=Time.get_ticks_usec()
		var low:Dictionary=posture.sample_ground(locomotion,{"delta":.016,"moving":case.variant>0,"speed":.8 if case.value>1 else 1.55,"distance":.0128 if case.variant>0 else 0.0,"actor_world":player._visual.global_transform,"actor_yaw":player._visual.global_rotation.y,"standing_phase":phase,"standing_gait":gait},case.aim.aimYaw,player._pose_epoch)
		phase=low.weapon_posture.phase;gait=low.weapon_posture.gait
		check(low.valid and low.poses[player._pose_skeleton.find_bone("pelvis")].origin!=locomotion.poses[player._pose_skeleton.find_bone("pelvis")].origin,"actual pelvis lowered/orbited")
		var decorated:Dictionary=presentation.decorate(low,case.aim,case.posture,phase,gait,player._pose_epoch)
		if case.posture.prone>.001:decorated=posture.ground_after_weapon(decorated)
		check(write(player,decorated),"actual source posture solewriter")
		var receipt:=presentation.after_pose_applied(decorated);fulltimes.append(Time.get_ticks_usec()-stamp)
		last_selected=decorated
		check(receipt.ok,"actual posture current muzzle "+case.id+" "+str(case.value))
		if receipt.ok:check(receipt.origin==presentation._visual.get_node("Muzzle").global_position,"same pose actual muzzle")
	var occupant:=Occupant.new();check(occupant.configure(player._pose_skeleton,player._pose_motion,player._locomotion._rest_poses,player._model_scale),"existing passenger sampler")
	var seats:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[2].path_join("godot/mafiozi_walk/scripts/tests/fixtures/vehicle_occupant_pose_oracle.json")))
	var passenger:Dictionary={}
	for trace:Dictionary in seats.traces:
		if not trace.seat.can_drive:passenger=trace.seat;break
	check(not passenger.is_empty(),"existing original passenger seat fixture")
	player.set_preview_pose_authority(&"vehicle")
	for id:String in presentation._catalog.IDS:
		if id=="none":continue
		var seat:Dictionary=occupant.sample(passenger,{"fold":1.0},null,player._pose_epoch)
		check(seat.valid and seat.seat_id==passenger.id and error(seat.poses[player._pose_skeleton.find_bone("thigh_l")],player._locomotion._rest_poses[player._pose_skeleton.find_bone("thigh_l")])>.1,"actual existing passenger pose")
		check(not presentation.equip(id).ok,"vehicle firearm presentation denied "+id)
		check(not presentation.decorate(seat).has("weapon_presentation") and not presentation.current_muzzle().ok,"passenger cannot reuse onfoot muzzle")
	check(not posture.sample_locomotion({},NAN,0,0,Transform3D.IDENTITY,0,0,0).valid,"invalid stance rejected")
	check(not posture.ground_after_weapon({"valid":true,"poses":[]}).valid,"invalid floor pose rejected")
	check(not posture.sample_posture({"valid":true,"poses":[],"weapon":{}},{},{},0,0,0).valid,"posture cannot follow weapon")
	check(not posture.step_posture(-1).get("valid",true),"negative controller delta denied")
	var intervals:Array[Vector2]=[Vector2(-2,-.1),Vector2(2,3)]
	check(Posture.height_query(1.9,0,3,intervals).source_vertical_clear,"source vertical irrelevant bodies skipped")
	intervals=[Vector2(1.5,2)]
	check(not Posture.height_query(1.9,0,3,intervals).source_vertical_clear,"source overlapping height denied")
	check(not Posture.height_query(1.9,0,1.85).source_vertical_clear and Posture.height_query(1.9,0,1.88).source_vertical_clear,"source exact3cm ceiling tolerance")
	check(Posture.height_query(.62,0,INF).query_required and Posture.height_query(.62,0,INF).center_from_feet==Vector3(0,.31,0),"real capsule query still required and feet fixed")
	var exact_vertices:=posture._floor_unique_vertices;var mixed_vertices:=posture._floor_mixed_ends.size()
	var packed_bytes:=posture._floor_mixed_points.size()*12+posture._floor_mixed_bones.size()*4+posture._floor_mixed_weights.size()*4+posture._floor_mixed_ends.size()*4+posture._floor_rigid_bones.size()*4
	for points:PackedVector3Array in posture._floor_rigid_points:packed_bytes+=points.size()*12
	var stable:Dictionary=posture.ground_after_weapon(last_selected);var cached_times:Array[int]=[]
	for i:int in 200:
		var stamp:=Time.get_ticks_usec();var cached:Dictionary=posture.ground_after_weapon(last_selected);cached_times.append(Time.get_ticks_usec()-stamp)
		check(cached.valid and cached.visual_offset==stable.visual_offset,"exact unchanged pose cached floor")
	cached_times.sort();var cache_hits:=posture._floor_cache_hits
	posture._floor_resources[0].emit_changed()
	check(not posture.ground_after_weapon(last_selected).valid,"changed original geometry invalidates floor cache")
	occupant.dispose();presentation.dispose();posture.dispose();sampler.dispose();player.free()
	times.sort();fulltimes.sort()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_cases":data.cases.size(),"controller_source_steps":controller_checks,"exact_unique_support_vertices":exact_vertices,"mixed_unique_support_vertices":mixed_vertices,"bind_us":bind_us,"packed_support_bytes":packed_bytes,"cached_floor_p50_us":cached_times[100],"cached_floor_p95_us":cached_times[190],"cached_floor_hits":cache_hits,"max_posture_error":max_posture,"max_final_pose_error":max_final,"max_source_floor_error":max_floor,"max_scalar_skin_error":max_skin,"floor_p50_us":times[times.size()/2],"floor_p95_us":times[int(times.size()*.95)],"full_posture_weapon_floor_writer_receipt_p50_us":fulltimes[fulltimes.size()/2],"full_posture_weapon_floor_writer_receipt_p95_us":fulltimes[int(fulltimes.size()*.95)],"passenger":"existing actual seated base, all14 onfoot presentation denied; no passenger firing bridge claimed","cover":"native cover state/pose/actual geometry fire gate absent; separate pending source contract, not standbase flag"}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("WEAPON_POSTURE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
