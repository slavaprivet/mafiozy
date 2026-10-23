extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const Melee=preload("res://scripts/combat/melee_pose.gd")
var failures:Array=[]
var checks:=0
var worst:Dictionary={"matrix":0.0,"offset":0.0,"rotation":0.0,"case":0,"bone":""}
var singular_cases:Array=[]
var skin_metrics:Array=[]
var correspondence:Array=[]
var import_weight_error:=0.0
var max_contact_error:=0.0
var max_length_error:=0.0
var rest_translation_error:=0.0
var rest_world_error:=0.0
var rest_length_error:=0.0
func _initialize():run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func quat(a:Array)->Quaternion:return Quaternion(a[0],a[1],a[2],a[3])
func matrix(a:Array)->Transform3D:return Transform3D(Basis(Vector3(a[0],a[1],a[2]),Vector3(a[4],a[5],a[6]),Vector3(a[8],a[9],a[10])),Vector3(a[12],a[13],a[14]))
func difference(a:Transform3D,b:Transform3D)->float:return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func poses(p:CharacterBody3D,source:Dictionary)->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	for i in 28:result.append(matrix(source[str(p._pose_skeleton.get_bone_name(i))]))
	return result
func selected(p:CharacterBody3D,source:Dictionary)->Dictionary:return {"valid":true,"poses":poses(p,source.poses),"visual_offset":vec(source.visual_offset),"visual_rotation":quat(source.visual_rotation),"scaled_offset":vec(source.scaled_offset),"authority_epoch":4,"host_tag":"preserve"}
func snapshot(p:CharacterBody3D)->Array:
	var out:Array=[p.global_transform,p.velocity,p._pose_motion.transform,p._pose_epoch,p._pose_authority]
	for i in 28:out.append(p._pose_skeleton.get_bone_pose(i))
	return out
func bone_world(p:CharacterBody3D,s:Dictionary)->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	var local:Array[Transform3D]=[]
	var frame:Transform3D=Transform3D(Basis(s.visual_rotation),s.visual_offset)*p._pose_motion.global_transform.affine_inverse()*p._pose_skeleton.global_transform
	for i in 28:
		var parent:int=p._pose_skeleton.get_bone_parent(i)
		local.append(s.poses[i] if parent<0 else local[parent]*s.poses[i]);result.append(frame*local[i])
	return result
func stats(a:Array)->Dictionary:
	a.sort();return {"samples":a.size(),"p50_us":a[a.size()/2],"p95_us":a[int(a.size()*.95)]} if not a.is_empty() else {}
func skinned(p:CharacterBody3D,s:Dictionary,layout:Array)->PackedVector3Array:
	var global:Array[Transform3D]=[]
	var parent_frame:Transform3D=p._pose_motion.global_transform.affine_inverse()*p._pose_skeleton.global_transform
	var visual:=Transform3D(Basis(s.visual_rotation),s.visual_offset)
	for i in 28:
		var parent:int=p._pose_skeleton.get_bone_parent(i)
		global.append(s.poses[i] if parent<0 else global[parent]*s.poses[i])
	var surfaces:Dictionary={}
	for mesh:MeshInstance3D in p._visual.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var arrays:Array=mesh.mesh.surface_get_arrays(surface);surfaces[arrays[Mesh.ARRAY_VERTEX].size()]={"arrays":arrays,"skin":mesh.skin}
	var result:=PackedVector3Array()
	for row:Dictionary in layout:
		var source:Dictionary=surfaces[int(row.vertices)];var arrays:Array=source.arrays;var skin:Skin=source.skin
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		if correspondence.size()<7:correspondence.append({"name":row.name,"first_native":vertices[0],"first_source":row.first,"weights_native":Array(weights.slice(0,4)),"weights_source":row.keys[0].influences})
		var matrices:Array[Transform3D]=[]
		for b in skin.get_bind_count():matrices.append(visual*parent_frame*global[p._pose_skeleton.find_bone(str(skin.get_bind_name(b)))]*skin.get_bind_pose(b))
		var lookup:Dictionary={};var points:=PackedVector3Array()
		for v in vertices.size():
			var point:=Vector3.ZERO;var influences:Array=[]
			for j in 4:
				var at:=v*4+j
				if weights[at]>0:point+=(matrices[bones[at]]*vertices[v])*weights[at];influences.append([str(skin.get_bind_name(bones[at])),float(weights[at])])
			influences.sort_custom(func(a:Array,b:Array):return a[0]<b[0])
			if not lookup.has(vertices[v]):lookup[vertices[v]]=[]
			lookup[vertices[v]].append({"weights":influences,"point":point})
		for key:Dictionary in row.keys:
			var found:=false
			for candidate:Dictionary in lookup.get(vec(key.p),[]):
				if candidate.weights.size()!=key.influences.size():continue
				var error:=0.0;var same_names:=true
				for w in key.influences.size():
					same_names=same_names and candidate.weights[w][0]==key.influences[w][0]
					error=maxf(error,absf(candidate.weights[w][1]-key.influences[w][1]))
				if same_names and error<=1.0/65535.0+1e-7:
					import_weight_error=maxf(import_weight_error,error);result.append(candidate.point);found=true;break
			if not found:check(false,"native_source_vertex_identity");result.append(Vector3(INF,INF,INF))
	return result
func run()->void:
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_pose_oracle.json"))
	var skin_manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_pose_skin.json"))
	for name:String in oracle.hashes:check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/"+name)==oracle.hashes[name].sha256,"original_source_hash:"+name)
	check(FileAccess.get_sha256("res://assets/hero.glb")==oracle.asset_sha,"actual_native_asset_hash")
	check(FileAccess.get_sha256("res://scripts/tests/fixtures/melee_pose_skin.bin")==skin_manifest.sha256,"skin_oracle_binary_hash")
	var skin_data:=FileAccess.get_file_as_bytes("res://scripts/tests/fixtures/melee_pose_skin.bin").to_float64_array()
	var world:=Node3D.new();root.add_child(world);var p:=Player.new();world.add_child(p);p.set_physics_process(false)
	var pose:=Melee.new();var start:=Time.get_ticks_usec()
	check(pose.configure(p._pose_skeleton,p._pose_motion,p._locomotion._rest_poses,p._model_scale,p._visual),"configure_actual28")
	var setup:=Time.get_ticks_usec()-start
	for i in 28:
		var source_raw:Array=oracle.rest[str(p._pose_skeleton.get_bone_name(i))]
		var source_rest:=matrix(source_raw)
		var native_origin:Vector3=p._locomotion._rest_poses[i].origin
		# Compare scalar doubles BEFORE constructing a float32 Vector3.
		for axis in 3:rest_translation_error=maxf(rest_translation_error,absf(float(native_origin[axis])-float(source_raw[12+axis])))
		check(difference(p._locomotion._rest_poses[i],source_rest)<1e-5,"actual_authored_rest")
		var name:=str(p._pose_skeleton.get_bone_name(i))
		for axis in 3:rest_world_error=maxf(rest_world_error,absf(float(pose._records[name].p[axis])-float(oracle.restWorld[name][axis])))
		if oracle.restLengths.has(name):rest_length_error=maxf(rest_length_error,absf(float(pose._records[name].length)-float(oracle.restLengths[name])))
	var before:=snapshot(p);var samples:Array=[];var drop_cost:Array=[];var ordinary_cost:Array=[];var noop_cost:Array=[];var authored_scale:=1.0
	for index in oracle.cases.size():
		var row:Dictionary=oracle.cases[index];var base:=selected(p,row.base);var immutable:=base.duplicate(true)
		start=Time.get_ticks_usec();var got:Dictionary=pose.sample(base,row.action,row.posture,row.phase,row.gait,4);var cost:=Time.get_ticks_usec()-start
		check(got.get("valid",false),"valid:"+str(index));check(base==immutable,"base_immutable");check(got.host_tag=="preserve","host_metadata")
		if row.result==null:check(is_same(got,base),"noop_identity:"+str(index));noop_cost.append(cost)
		else:
			if row.action.type=="dropkick":drop_cost.append(cost)
			else:ordinary_cost.append(cost)
			for key:String in row.result:
				var expected:Variant=row.result[key];var actual:Variant=got.get("melee",{}).get(key)
				check(absf(float(actual)-float(expected))<1e-6 if expected is float or expected is int else actual==expected,"metadata:"+str(index)+":"+key)
		var expected:=selected(p,row.selected)
		for bone in 28:
			var delta:=difference(got.poses[bone],expected.poses[bone]);var scale:Vector3=(got.poses[bone] as Transform3D).basis.get_scale();authored_scale=maxf(authored_scale,maxf(scale.x,maxf(scale.y,scale.z)))
			if delta>worst.matrix:worst.matrix=delta;worst.case=index;worst.bone=str(p._pose_skeleton.get_bone_name(bone));worst.actual=got.poses[bone];worst.expected=expected.poses[bone];worst.action=row.action
			var leg_name:=str(p._pose_skeleton.get_bone_name(bone))
			# Near-straight two-link IK amplifies float32 world-frame arithmetic.
			# Only the ten observed leg canaries get the relaxed local basis bound;
			# each has mandatory independent all8338 source skin evidence below.
			var singular_allowed:bool=skin_manifest.cases.has(float(index)) and leg_name in ["thigh_l","shin_l","foot_l","thigh_r","shin_r","foot_r"]
			check(delta<(.0005 if singular_allowed else .00005),"matrix:"+str(index)+":"+leg_name)
			if delta>=.00005 and not singular_cases.has(index):singular_cases.append(index)
		worst.offset=maxf(worst.offset,(got.visual_offset as Vector3).distance_to(expected.visual_offset));worst.rotation=maxf(worst.rotation,1-absf((got.visual_rotation as Quaternion).dot(expected.visual_rotation)))
		check((got.visual_offset as Vector3).distance_to(expected.visual_offset)<.00005,"offset:"+str(index));check(1-absf((got.visual_rotation as Quaternion).dot(expected.visual_rotation))<.000001,"rotation:"+str(index))
		var actual_frames:=bone_world(p,got);var expected_frames:=bone_world(p,expected)
		for name:String in ["foot_l","foot_r","socket_hand_l","socket_hand_r"]:
			var bone:int=p._pose_skeleton.find_bone(name);var error:=actual_frames[bone].origin.distance_to(expected_frames[bone].origin)
			max_contact_error=maxf(max_contact_error,error);check(error<.0001,"contact_position:"+str(index)+name)
		for pair:Array in [["thigh_l","shin_l"],["shin_l","foot_l"],["thigh_r","shin_r"],["shin_r","foot_r"],["upperarm_l","forearm_l"],["forearm_l","hand_l"],["upperarm_r","forearm_r"],["forearm_r","hand_r"]]:
			var a:int=p._pose_skeleton.find_bone(pair[0]);var b:int=p._pose_skeleton.find_bone(pair[1]);var length_error:=absf(actual_frames[a].origin.distance_to(actual_frames[b].origin)-expected_frames[a].origin.distance_to(expected_frames[b].origin))
			max_length_error=maxf(max_length_error,length_error);check(length_error<.00001,"source_authored_segment_length")
		if skin_manifest.cases.has(float(index)):
			var actual_skin:=skinned(p,got,skin_manifest.layout);var offset:int=skin_manifest.cases.find(float(index))*int(skin_manifest.vertices)*3
			var max_error:=0.0;var squared:=0.0;var minimum:=INF
			for vertex in actual_skin.size():
				var at:=offset+vertex*3;var point:=Vector3(skin_data[at],skin_data[at+1],skin_data[at+2]);var error:=actual_skin[vertex].distance_to(point)
				max_error=maxf(max_error,error);squared+=error*error;minimum=minf(minimum,actual_skin[vertex].y)
			skin_metrics.append({"case":index,"vertices":actual_skin.size(),"max_m":max_error,"rms_m":sqrt(squared/actual_skin.size()),"min_y":minimum,"source_min_y":row.min_skin})
			check(actual_skin.size()==8338 and max_error<.0001 and sqrt(squared/actual_skin.size())<.00002,"fullskin100micrometre_bound:"+str(index))
	check(snapshot(p)==before,"pure_no_scene_bone_body_writes")
	var writer_worst:=0.0
	for index:int in [112,450,461]:
		var row:Dictionary=oracle.cases[index];var got:Dictionary=pose.sample(selected(p,row.base),row.action,row.posture,row.phase,row.gait,4)
		p._apply_selected_pose(got)
		for i in 28:writer_worst=maxf(writer_worst,difference(p._pose_skeleton.get_bone_pose(i),got.poses[i]))
	check(writer_worst<.000002,"actual_single_writer_preserves_authored_matrices")
	var valid_base:=selected(p,oracle.cases[0].base)
	var attack:Dictionary={"type":"punch","progress":.2}
	for malformed:Variant in [null,"bad",NAN,INF,{}]:
		check(not pose.sample(valid_base,attack,{"prone":malformed}).get("valid",true),"malformed_posture_rejected")
	check(not pose.sample(valid_base,attack,{},NAN).get("valid",true),"nan_phase")
	check(not pose.sample(valid_base,attack,{},0,0,-1).get("valid",true),"negative_epoch")
	check(not pose.sample(valid_base,{"type":"invented"}).get("valid",true),"unknown_action")
	check(pose.sample(valid_base,attack).get("valid",false),"valid_after_rejections")
	check(not pose.configure(p._pose_skeleton,p._pose_motion,p._locomotion._rest_poses,p._model_scale,p._visual),"no_rebind")
	p.queue_free()
	check(not pose.sample(valid_base,attack).get("valid",true),"queued_ancestor_retires_binding")
	var report:Dictionary={"checks":checks,"failures":failures,"worst":worst,"cases":oracle.cases.size(),"configure_us":setup,"ordinary":stats(ordinary_cost),"dropkick":stats(drop_cost),"noop":stats(noop_cost),"diagnostics":pose.diagnostics(),"sha":FileAccess.get_sha256("res://scripts/combat/melee_pose.gd"),"source":oracle.hashes,"qualification":"Actual28hero localTransform3D/fullbasis source parity. Original JS realGLB oracle, headless CPU only, no gameplay admission/provider/physics/GPU/FPS claim."}
	report.max_authored_local_scale=authored_scale
	report.actual_writer_matrix_error=writer_worst;report.skin_metrics=skin_metrics;report.singular_cases=singular_cases
	report.correspondence=correspondence
	report.import_weight_quantization_max=import_weight_error
	report.max_contact_position_m=max_contact_error;report.max_segment_length_m=max_length_error;report.rest_translation_import_error=rest_translation_error
	report.rest_world_frame_float32_error=rest_world_error;report.rest_segment_length_float32_error=rest_length_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../../outputs/coordinator21_melee_pose"))
	var f:=FileAccess.open("res://../../outputs/coordinator21_melee_pose/report.json",FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(report,"\t"));f.close()
	print("MELEE_POSE ",JSON.stringify(report));world.free();quit(0 if failures.is_empty() and f!=null else 1)
