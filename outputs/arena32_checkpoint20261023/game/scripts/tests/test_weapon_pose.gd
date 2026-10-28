extends SceneTree
const Pose=preload("res://scripts/weapons/weapon_pose.gd")
var checks:=0
var failures:Array[String]=[]
var max_local:=0.0
var max_weapon:=0.0
var max_writer:=0.0
var writer_by_mode:Dictionary={}
var cost_by_mode:Dictionary={}
var worst:Dictionary={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func matrix(v:Array)->Transform3D:
	return Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[4],v[5],v[6]),Vector3(v[8],v[9],v[10])),Vector3(v[12],v[13],v[14]))
func frames(values:Array)->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	for v:Array in values:result.append(matrix(v))
	return result
func error(a:Transform3D,b:Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in ["actor_world","visual_pivot_world","skeleton_world","offset_world"]:result[key]=matrix(value[key])
	return result
func _initialize()->void:call_deferred("run")
func run()->void:
	var args:=OS.get_cmdline_user_args()
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	check(data.source_hash_normalization=="crlf_to_lf","source normalization marker")
	for input:Dictionary in data.source_inputs:
		check(FileAccess.get_file_as_string(args[2].path_join(input.path)).replace("\r\n","\n").sha256_text()==input.sha256,"current source pin "+input.path)
	var hero_path:=args[2].path_join("godot/mafiozi_walk/assets/hero.glb")
	check(FileAccess.get_sha256(hero_path)==data.asset_sha256,"actual hero asset pin")
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	check(document.append_from_buffer(FileAccess.get_file_as_bytes(hero_path),"",state)==OK,"actual hero native GLTF import")
	var hero:Node3D=document.generate_scene(state);get_root().add_child(hero)
	var rig:Skeleton3D=hero.find_children("*","Skeleton3D",true,false)[0]
	check(rig.get_bone_count()==data.names.size(),"actual native rig bone count")
	var native_order:Dictionary={}
	for i:int in rig.get_bone_count():native_order[String(rig.get_bone_name(i))]=i
	for i:int in data.names.size():
		check(native_order.has(data.names[i]),"actual native bone name")
		check(error(rig.get_bone_rest(native_order[data.names[i]]),matrix(data.rest[i]))<1e-6,"actual native rest hierarchy")
	var pose:=Pose.new()
	check(pose.configure(PackedStringArray(data.names),PackedInt32Array(data.parents),frames(data.rest),matrix(data.rest_rig_to_actor)),"configuration")
	var start:=Time.get_ticks_usec()
	for case:Dictionary in data.cases:
		var base:={"valid":true,"poses":frames(case.base),"authority_epoch":7,"visual_offset":Vector3.ZERO}
		var v:Dictionary=case.base_visual
		base.visual_offset=Vector3(v.visual_offset[0],v.visual_offset[1],v.visual_offset[2])
		base.visual_rotation=Quaternion(v.visual_rotation[0],v.visual_rotation[1],v.visual_rotation[2],v.visual_rotation[3])
		base.scaled_offset=Vector3(v.scaled_offset[0],v.scaled_offset[1],v.scaled_offset[2])
		var derived:=Pose.make_frame(matrix(case.frame.actor_world),case.frame.actor_yaw,base,matrix(data.rest_rig_to_actor),matrix(data.rest_offset_to_actor),case.frame.target_height,case.frame.source_height)
		for key:String in ["visual_pivot_world","skeleton_world","offset_world"]:check(error(derived[key],matrix(case.frame[key]))<.000002,"selected base frame reconstruction")
		var before:Array[Transform3D]=base.poses.duplicate()
		var selected:Dictionary=pose.sample(base,case.weapon,context(case.frame),case.aim,case.posture,case.phase,case.gait,7)
		check(selected.get("valid",false),"valid "+case.id+case.mode)
		if not selected.get("valid",false):continue
		check(base.poses==before,"input untouched")
		for i:int in data.names.size():
			var delta:=error(selected.poses[i],matrix(case.selected[i]))
			if delta>max_local:max_local=delta;worst={"id":case.id,"mode":case.mode,"bone":data.names[i],"aim":case.aim,"error":delta}
			check(delta<.00003,"source pose "+case.id+" "+case.mode+" "+data.names[i]+" "+str(delta))
		var local_delta:=error(selected.weapon.local_to_socket,matrix(case.weapon_local))
		var world_delta:=error(selected.weapon.world_before_ground,matrix(case.weapon_world))
		max_weapon=maxf(max_weapon,maxf(local_delta,world_delta))
		check(local_delta<.00001 and world_delta<.00001,"source weapon frame "+case.id+" "+case.mode+" "+str(local_delta))
		# Isolated replica of the root-owned full-matrix writer contract. No game
		# Skeleton is touched; the sampled component itself has no Skeleton handle.
		for i:int in data.names.size():rig.set_bone_pose(native_order[data.names[i]],selected.poses[i])
		var global_poses:Array[Transform3D]=[]
		for i:int in data.names.size():
			var parent:int=data.parents[i]
			global_poses.append(selected.poses[i] if parent<0 else global_poses[parent]*selected.poses[i])
			rig.set_bone_global_pose_override(native_order[data.names[i]],global_poses[i],1.0,true)
		for palm:String in ["socket_hand_l","socket_hand_r"]:
			var actual:Vector3=(matrix(case.frame.skeleton_world)*global_poses[data.names.find(palm)]).origin
			var expected:Array=case.palms[palm]
			check(actual.distance_to(Vector3(expected[0],expected[1],expected[2]))<.00001,"source palm position "+palm)

		for i:int in data.names.size():
			var writer_error:=error(rig.get_bone_global_pose(native_order[data.names[i]]),global_poses[i])
			max_writer=maxf(max_writer,writer_error)
			writer_by_mode[case.mode]=maxf(writer_by_mode.get(case.mode,0.0),writer_error)
			check(error(rig.get_bone_global_pose_override(native_order[data.names[i]]),global_poses[i])==0.0,"full desired override stored exactly")
			if not case.mode.begins_with("affine_"):
				check(writer_error<1e-6,"native original-case writer "+case.id+" "+case.mode+" "+data.names[i]+" "+str(writer_error))
		# Affine stress also measures the engine boundary; it is NOT claimed to
		# pass displayed-matrix parity. Godot interpolates/decomposes overrides.
		var prepared_frame:=context(case.frame)
		if not cost_by_mode.has(case.mode):cost_by_mode[case.mode]=[]
		for repeat:int in 10:
			var stamp:=Time.get_ticks_usec()
			pose.sample(base,case.weapon,prepared_frame,case.aim,case.posture,case.phase,case.gait,7)
			cost_by_mode[case.mode].append(Time.get_ticks_usec()-stamp)
	var parity_ms:=(Time.get_ticks_usec()-start)/1000.0
	var case:Dictionary=data.cases[20]
	var base:={"valid":true,"poses":frames(case.base),"authority_epoch":7}
	var frame:=context(case.frame)
	var times:Array[int]=[]
	for repeat:int in 200:
		start=Time.get_ticks_usec();pose.sample(base,case.weapon,frame,case.aim,case.posture,case.phase,case.gait,7);times.append(Time.get_ticks_usec()-start)
	times.sort()
	check(pose.sample(base,{"id":"none"},{}).poses==base.poses,"none exact no-op")
	check(not pose.sample(base,case.weapon,frame,case.aim,case.posture,case.phase,case.gait,8).valid,"epoch mismatch rejected")
	var corrupted:=frame.duplicate();corrupted.skeleton_world=Transform3D(Basis.from_scale(Vector3(0,1,1)),Vector3.ZERO)
	check(not pose.sample(base,case.weapon,corrupted,case.aim,case.posture,case.phase,case.gait,7).valid,"singular rig frame rejected")
	corrupted=frame.duplicate();corrupted.source_height=0.0
	check(not pose.sample(base,case.weapon,corrupted,case.aim,case.posture,case.phase,case.gait,7).valid,"zero height rejected")
	for invalid:Dictionary in [{"airborne":"yes"},{"airBlend":NAN},{"landingAirBlend":2.0},{"reloadProgress":"half"}]:
		check(not pose.sample(base,case.weapon,frame,invalid,case.posture,case.phase,case.gait,7).valid,"invalid aim "+str(invalid))
	var wrong_weapon:Dictionary=case.weapon.duplicate(true);wrong_weapon.source_metadata.weaponId="rpg"
	check(not pose.sample(base,wrong_weapon,frame,case.aim,case.posture,case.phase,case.gait,7).valid,"profile identity mismatch")
	wrong_weapon=case.weapon.duplicate(true);wrong_weapon.source_metadata.mountOffset=[0,0]
	check(not pose.sample(base,wrong_weapon,frame,case.aim,case.posture,case.phase,case.gait,7).valid,"invalid mount")
	var selected:Dictionary=pose.sample(base,case.weapon,frame,case.aim,case.posture,case.phase,case.gait,7)
	check(not pose.sample(selected,case.weapon,frame,case.aim,case.posture,case.phase,case.gait,7).valid,"duplicate decoration rejected")
	var kept:Array=selected.poses.duplicate()
	pose.sample(base,case.weapon,frame,{"recoil":1.0},case.posture,case.phase,case.gait,7)
	check(selected.poses==kept,"returned poses private across calls")
	pose.dispose();check(not pose.sample(base,case.weapon,frame,case.aim,case.posture,case.phase,case.gait,7).valid,"disposed sampler rejected")
	hero.free()
	var costs:Dictionary={}
	for mode:String in cost_by_mode:
		var samples:Array=cost_by_mode[mode];samples.sort()
		costs[mode]={"count":samples.size(),"p50_us":samples[samples.size()/2],"p95_us":samples[int(samples.size()*.95)],"max_us":samples[-1]}
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"max_local_pose_error":max_local,"max_weapon_frame_error":max_weapon,"max_native_writer_error":max_writer,"native_writer_error_by_mode":writer_by_mode,"native_arbitrary_affine_display_parity_passed":max_writer<1e-6,"native_limitation":"Godot4.7.2 Skeleton3D override uses Transform3D.interpolate_with even at amount1; arbitrary shear is decomposed. Original unmodified source cases are separately asserted.","worst":worst,"parity_and_benchmark_ms":parity_ms,"sample_p50_us":times[100],"sample_p95_us":times[190],"cost_by_mode":costs,"cases":data.cases.size()}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("WEAPON_POSE_TEST ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
