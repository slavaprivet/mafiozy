extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const Source=preload("res://scripts/combat/melee_pose.gd")
const Retarget=preload("res://scripts/combat/melee_physical_pose.gd")
const Driver=preload("res://scripts/character_physics/character_physics_driver.gd")
const Local=preload("res://scripts/character_physics/local_hit_reaction.gd")
var checks:=0
var failures:=[]
var serial:=0
var binding={"actor_id":"TEST_ONLY_physical_melee","life_generation":1,"session_id":"TEST_ONLY","session_generation":1}
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func command(p:CharacterBody3D,d:RefCounted)->Dictionary:
	serial+=1
	var frames=d.body.capture_world_frames();var point:Vector3=frames.chest.origin
	var owner=binding.duplicate();owner.merge(d.impact_owner_state());owner.merge({"pose_epoch":p._pose_epoch,"pose_owner":str(p._pose_authority),"physics_tick":Engine.get_physics_frames(),"transport_state":"none"})
	return {"event_key":"TEST_ONLY_"+str(serial),"binding":binding.duplicate(),"owner_before":owner,"physical_input":{"delivery":"command_unapplied","world_point":point,"impulse_ns":Vector3.ZERO,"physics_tick":Engine.get_physics_frames()},"admitted":{"world_point":point},"action":"begin_point_impulse","apply_impulse_ns":Vector3.ZERO,"final_dead":false}
func globals(p:CharacterBody3D,selected:Dictionary)->Array:
	var out:=[]
	var visual=Transform3D(Basis(selected.get("visual_rotation",Quaternion.IDENTITY)),selected.visual_offset)
	var rig_to_motion=p._pose_motion.global_transform.affine_inverse()*p._pose_skeleton.global_transform
	for i in 28:
		var parent=p._pose_skeleton.get_bone_parent(i)
		out.append(selected.poses[i] if parent<0 else out[parent]*selected.poses[i])
	for i in 28:out[i]=visual*rig_to_motion*out[i]
	return out
func stats(a:Array)->Dictionary:
	a.sort();return {"samples":a.size(),"p50_us":a[a.size()/2],"p95_us":a[int(a.size()*.95)]}
func max_angle(a:Array,b:Array)->float:
	var result:=0.0
	for i in 28:
		var q:Quaternion=a[i].basis.get_rotation_quaternion().inverse()*b[i].basis.get_rotation_quaternion()
		result=maxf(result,2.0*atan2(Vector3(q.x,q.y,q.z).length(),absf(q.w)))
	return result
func run():
	var paths={"source":"res://scripts/combat/melee_pose.gd","player":"res://scripts/preview_player.gd","driver":"res://scripts/character_physics/character_physics_driver.gd","local":"res://scripts/character_physics/local_hit_reaction.gd","adapter":"res://scripts/combat/melee_physical_pose.gd"}
	var before:={};for key in paths:before[key]=FileAccess.get_sha256(paths[key])
	var world=Node3D.new();root.add_child(world);var p=Player.new();world.add_child(p);p.set_physics_process(false)
	p.set_meta("actor_id",binding.actor_id);p.set_meta("life_generation",1)
	var d=Driver.new();check(d.configure(p,world).ok,"actual physical driver configure");check(d.bind_impact_session(binding).ok,"actual identity bound")
	var source=Source.new();check(source.configure(p._pose_skeleton,p._pose_motion,p._locomotion._rest_poses,p._model_scale,p._visual),"exact source configure")
	var retarget=Retarget.new();check(retarget.configure(p._pose_skeleton,p._locomotion._rest_poses),"actual rest configure")
	check(not retarget.configure(p._pose_skeleton,p._locomotion._rest_poses),"no implicit rebind")
	var rig={"names":[],"parents":[],"rest_local":p._locomotion._rest_poses,"inertia_kg_m2":{}}
	for i in 28:rig.names.append(str(p._pose_skeleton.get_bone_name(i)));rig.parents.append(p._pose_skeleton.get_bone_parent(i))
	for name in Local.SELECTED:rig.inertia_kg_m2[name]=Vector3.ONE*.2
	await physics_frame;await process_frame
	var timing:=[];var summaries:={};var last_source:={};var last_base:={}
	for kind in ["punch","kick","heavy","dropkick"]:
		var metrics={"samples":0,"max_source_joint_deviation_m":0.0,"max_linear_speed_m_s":0.0,"max_local_angular_speed_rad_s":0.0,"worst_progress":0.0}
		for side in [-1,1]:
			for speed in [0.0,2.0,5.0]:
				retarget.reset()
				p._locomotion.reset_state()
				for warm in 40:p._locomotion.sample(1.0/60.0,Vector3(speed,0,0),true)
				var local=Local.new();check(local.bind(binding.actor_id,p._pose_epoch,rig).ok,"real weak recipient bind")
				var previous:=[];var previous_poses:=[]
				var duration:float=Source.DURATIONS[kind];var dt=duration/100.0
				for tick in 101:
					var progress=tick/100.0
					var base=p._locomotion.sample(dt,Vector3(speed,0,0),true);base.authority_epoch=p._pose_epoch
					var authored=source.sample(base,{"type":kind,"progress":progress,"side":side},{},p._locomotion._phase,p._locomotion._gait,p._pose_epoch)
					var source_copy=authored.duplicate(true);var base_copy=base.duplicate(true)
					var started=Time.get_ticks_usec();var got=retarget.sample(authored,base,p._pose_epoch,dt);timing.append(Time.get_ticks_usec()-started)
					check(got.get("valid",false),kind+" valid "+str(progress)+":"+str(got.get("error","")))
					if not got.get("valid",false):continue
					check(authored==source_copy and base==base_copy,"inputs immutable")
					check(got.visual_offset==authored.visual_offset and got.get("visual_rotation",Quaternion.IDENTITY)==authored.get("visual_rotation",Quaternion.IDENTITY) and got.get("melee")==authored.get("melee"),"source visual/root/action metadata retained")
					if tick in [0,100]:check(got.poses==base.poses,"exact entry/end ordinary bone pose")
					p._apply_selected_pose(got)
					var physical=d.preflight_impact(command(p,d));check(physical.ok,kind+" physical "+str(progress)+":"+str(physical.get("error","")))
					var displayed=d.body.capture_world_frames()
					var event={"actor_id":binding.actor_id,"epoch_id":p._pose_epoch,"event_id":kind+str(side)+str(speed)+str(tick),"world_point":displayed.head.origin+Vector3(.03,0,0),"impulse_ns":Vector3(0,.1,0)}
					var admission=local.can_add_hit(event,displayed);check(admission.ok,kind+" weak preflight "+str(progress)+":"+str(admission.get("error","")))
					check(local.add_hit(event,displayed).ok,"actual weak commit")
					var weak=local.apply_to_selected(dt,got);check(weak.get("valid",false),kind+" weak sample "+str(progress)+":"+str(weak.get("error","")))
					var frames=globals(p,got);var original=globals(p,authored)
					for i in 28:
						check(got.poses[i].origin==p._locomotion._rest_poses[i].origin,"canonical exact joint offsets")
						var difference=frames[i].origin.distance_to(original[i].origin)
						if difference>metrics.max_source_joint_deviation_m:metrics.max_source_joint_deviation_m=difference;metrics.worst_progress=progress
						if not previous.is_empty():
							metrics.max_linear_speed_m_s=maxf(metrics.max_linear_speed_m_s,frames[i].origin.distance_to(previous[i].origin)/dt)
							var q:Quaternion=got.poses[i].basis.get_rotation_quaternion();var old:Quaternion=previous_poses[i].basis.get_rotation_quaternion()
							var angular=2*acos(clampf(absf(q.dot(old)),-1,1))/dt
							if angular>metrics.max_local_angular_speed_rad_s:
								metrics.max_local_angular_speed_rad_s=angular
								metrics.angular_case={"side":side,"speed":speed,"bone":str(p._pose_skeleton.get_bone_name(i)),"progress":progress,"angle_rad":angular*dt}
					previous=frames;previous_poses=got.poses;metrics.samples+=1
					last_source=authored;last_base=base
		summaries[kind]=metrics
		check(metrics.max_local_angular_speed_rad_s<24.0,kind+" continuous local rotations across all tested phases")
	# Pure output mutation / lease / queued lifecycle checks on a genuine active source result.
	retarget.reset()
	for tick in 120:
		var gait=p._locomotion.sample(1.0/60.0,Vector3(5,0,0),true);gait.authority_epoch=p._pose_epoch
		check(retarget.sample(gait,gait,p._pose_epoch)==gait,"untouched ordinary running from fresh adapter")
	var abrupt=last_base.duplicate(true)
	abrupt.poses[7].basis=Basis(Vector3.RIGHT,2.0)*abrupt.poses[7].basis
	check(retarget.sample(abrupt,abrupt,p._pose_epoch)==abrupt,"idle adapter never limits unrelated ordinary motion")
	var guard_peak:=0.0
	for action in [{"type":"none","blocking":true},{"type":"none","charge":1.0}]:
		retarget.reset()
		var previous:Array=last_base.poses
		var shown:Dictionary={}
		for tick in 60:
			var guard=source.sample(last_base,action,{},0,0,p._pose_epoch)
			shown=retarget.sample(guard,last_base,p._pose_epoch,1.0/60.0)
			check(shown.get("valid",false),"actual guard/charge valid")
			guard_peak=maxf(guard_peak,max_angle(previous,shown.poses)*60.0)
			previous=shown.poses
			p._apply_selected_pose(shown)
			check(d.preflight_impact(command(p,d)).ok,"actual guard/charge physical admission")
		check(shown.poses!=last_base.poses,"inactive metadata does not erase raised arms")
		var heavy=source.sample(last_base,{"type":"heavy","progress":0.0},{},0,0,p._pose_epoch)
		var start=retarget.sample(heavy,last_base,p._pose_epoch,1.0/60.0)
		check(start.poses==shown.poses,"heavy begins at exact displayed guard/charge pose")
		for tick in 120:
			var idle=retarget.sample(last_base,last_base,p._pose_epoch,1.0/60.0)
			guard_peak=maxf(guard_peak,max_angle(previous,idle.poses)*60.0)
			previous=idle.poses
		check(previous==last_base.poses,"guard/charge release settles exactly to ordinary")
		check(retarget.sample(abrupt,abrupt,p._pose_epoch)==abrupt,"settled adapter stops limiting ordinary gait")
	check(guard_peak<20.01,"guard/charge on/off bounded angular motion")
	retarget.reset()
	var guard=source.sample(last_base,{"type":"none","blocking":true},{},0,0,p._pose_epoch)
	retarget.sample(guard,last_base,p._pose_epoch)
	var next_epoch=last_base.duplicate(true);next_epoch.authority_epoch=p._pose_epoch+1
	check(retarget.sample(next_epoch,next_epoch,p._pose_epoch+1)==next_epoch,"new owner epoch immediately discards old residual")
	summaries.guard_charge={"max_local_angular_speed_rad_s":guard_peak}
	var authored=source.sample(last_base,{"type":"kick","progress":.4},{},0,0,p._pose_epoch)
	retarget.reset()
	var saved=retarget.sample(authored,last_base,p._pose_epoch);var snapshot=saved.duplicate(true)
	saved.poses.clear();saved.melee.contactSides.append("tamper")
	retarget.reset()
	check(retarget.sample(authored,last_base,p._pose_epoch)==snapshot,"returned arrays do not poison sampler or source")
	check(not retarget.sample(authored,last_base,-1).get("valid",true),"negative epoch")
	var bad=last_base.duplicate(true);bad.poses[0].origin.x+=.1
	check(retarget.sample(authored,bad,p._pose_epoch).get("error")=="ordinary_rig","reject changed ordinary rig")
	check(not retarget.sample(snapshot,last_base,p._pose_epoch).get("valid",true),"prevent double retarget")
	p._pose_skeleton.queue_free();check(not retarget.sample(authored,last_base,p._pose_epoch).get("valid",true),"queued rig cannot sample")
	d.dispose();world.free()
	var after:={};for key in paths:after[key]=FileAccess.get_sha256(paths[key])
	check(before==after,"all production bytes stable")
	var report={"checks":checks,"passed":failures.is_empty(),"failures":failures,"actions":summaries,"adapter_cpu":stats(timing),"sha_before":before,"sha_after":after,"scope":"Actual hero/writer/driver/local weak recipient, both sides, real rest/walk/run bases,101 phases each. Weak inertia .2 TEST_ONLY, no source calibration or physics dispatch/GPU/FPS claim."}
	DirAccess.make_dir_recursive_absolute("../../outputs/coordinator21_melee_physical_pose")
	FileAccess.open("../../outputs/coordinator21_melee_physical_pose/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MELEE_PHYSICAL_POSE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
