extends SceneTree
const Player=preload("res://scripts/preview_player.gd")
const Melee=preload("res://scripts/combat/melee_pose.gd")
const OUT="../../outputs/coordinator21_melee_combined/project/skin_fixture.bin"
func _initialize()->void:run.call_deferred()
func matrix(a:Array)->Transform3D:return Transform3D(Basis(Vector3(a[0],a[1],a[2]),Vector3(a[4],a[5],a[6]),Vector3(a[8],a[9],a[10])),Vector3(a[12],a[13],a[14]))
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func selected(p:CharacterBody3D,row:Dictionary)->Dictionary:
	var poses:Array[Transform3D]=[]
	for i in 28:poses.append(matrix(row.poses[str(p._pose_skeleton.get_bone_name(i))]))
	return {"valid":true,"poses":poses,"visual_offset":vec(row.visual_offset),"visual_rotation":Quaternion(row.visual_rotation[0],row.visual_rotation[1],row.visual_rotation[2],row.visual_rotation[3]),"scaled_offset":vec(row.scaled_offset),"authority_epoch":4}
func resolve(skeleton:Skeleton3D,skin:Skin,bind:int)->int:
	var name:=str(skin.get_bind_name(bind))
	var index:=skeleton.find_bone(name) if not name.is_empty() else skin.get_bind_bone(bind)
	return index if index>=0 and index<skeleton.get_bone_count() else -1
func run()->void:
	var world:=Node3D.new();root.add_child(world);var player:=Player.new();world.add_child(player);player.set_physics_process(false)
	var rig:Skeleton3D=player._pose_skeleton
	var vertices:=PackedVector3Array();var joints:=PackedInt32Array();var weights:=PackedFloat32Array();var indices:=PackedInt32Array()
	var bone_ids:=PackedInt32Array();var binds:Array[Transform3D]=[];var bindings:Array=[];var lookup:={};var errors:Array=[]
	for mesh:MeshInstance3D in player._visual.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var bind_offset:=binds.size()
		for bind in mesh.skin.get_bind_count():
			var bone:=resolve(rig,mesh.skin,bind)
			if bone<0:errors.append("invalid_actual_bind");continue
			bone_ids.append(bone);binds.append(mesh.skin.get_bind_pose(bind))
			bindings.append({"mesh":str(mesh.name),"slot":bind,"source_name":str(mesh.skin.get_bind_name(bind)),"source_index":mesh.skin.get_bind_bone(bind),"resolved_bone":bone,"resolved_name":str(rig.get_bone_name(bone))})
		for surface in mesh.mesh.get_surface_count():
			var arrays:Array=mesh.mesh.surface_get_arrays(surface)
			var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var w:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var idx:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var start:=vertices.size();var local_lookup:={}
			for i in points.size():
				vertices.append(points[i]);var influences:Array=[]
				for j in 4:
					var at:=i*4+j;joints.append(ids[at]+bind_offset);weights.append(w[at])
					if w[at]>0:influences.append([str(mesh.skin.get_bind_name(ids[at])),float(w[at])])
				influences.sort_custom(func(a,b):return a[0]<b[0])
				if not local_lookup.has(points[i]):local_lookup[points[i]]=[]
				local_lookup[points[i]].append({"index":start+i,"influences":influences})
			if lookup.has(points.size()):errors.append("ambiguous_layout")
			lookup[points.size()]=local_lookup
			for i in (idx.size() if not idx.is_empty() else points.size()):indices.append(start+(idx[i] if not idx.is_empty() else i))
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_pose_oracle.json"))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_pose_skin.json"))
	var source_skin:=FileAccess.get_file_as_bytes("res://scripts/tests/fixtures/melee_pose_skin.bin").to_float64_array()
	var mapping:=PackedInt32Array()
	for surface:Dictionary in manifest.layout:
		for key:Dictionary in surface.keys:
			var found:=-1
			for candidate:Dictionary in lookup[int(surface.vertices)].get(vec(key.p),[]):
				if candidate.influences.size()!=key.influences.size():continue
				var match_names:=true
				for i in key.influences.size():
					if candidate.influences[i][0]!=key.influences[i][0] or absf(candidate.influences[i][1]-key.influences[i][1])>1.0/65535.0+1e-7:match_names=false
				if match_names:found=candidate.index;break
			mapping.append(found)
			if found<0:errors.append("source_vertex_unmapped")
	var sampler:=Melee.new()
	if not sampler.configure(rig,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._visual):errors.append("sampler_bind")
	var parent_frame:Transform3D=player._pose_motion.global_transform.affine_inverse()*rig.global_transform
	var cases:Array=[]
	var captured_cases:Array=manifest.cases.duplicate()
	# Original twelve source-skin canaries stay first in the binary comparison.
	# Add ordinary punch/heavy/backfist midpoints and animation endpoints.
	for type:String in ["punch","heavy","backfist"]:
		for wanted:float in [0,.5,1]:
			var chosen:=-1;var closest:=INF
			for i in oracle.cases.size():
				if not oracle.cases[i].action is Dictionary:continue
				var action:Dictionary=oracle.cases[i].action
				if action.get("type","")==type and action.get("progress") is float and absf(float(action.progress)-wanted)<closest:
					chosen=i;closest=absf(float(action.progress)-wanted)
			if chosen>=0 and not captured_cases.has(chosen):captured_cases.append(chosen)
	for case_index in captured_cases:
		var row:Dictionary=oracle.cases[int(case_index)]
		var pose:Dictionary=sampler.sample(selected(player,row.base),row.action,row.posture,row.phase,row.gait,4)
		var globals:Array[Transform3D]=[]
		for i in 28:
			var parent:=rig.get_bone_parent(i);globals.append(pose.poses[i] if parent<0 else globals[parent]*pose.poses[i])
		var visual:=Transform3D(Basis(pose.visual_rotation),pose.visual_offset)
		var frames:Array[Transform3D]=[]
		for i in binds.size():frames.append(visual*parent_frame*globals[bone_ids[i]]*binds[i])
		cases.append({"case":int(case_index),"action":row.action,"frames":frames})
	# Distinct world transform with nonuniform scale; retain actual local skin.
	var transformed:Array[Transform3D]=[]
	var world_transform:=Transform3D(Basis.from_euler(Vector3(.3,.8,-.2)).scaled(Vector3(1.1,.8,1.2)),Vector3(10,-2,7))
	for frame:Transform3D in cases[0].frames:transformed.append(world_transform*frame)
	cases.append({"case":-1,"action":{"type":"world_transform_canary"},"frames":transformed})
	# Resolve both actual API bind modes and reject missing/misindexed bindings.
	var probe:=Skin.new();probe.set_bind_count(1);probe.set_bind_bone(0,rig.find_bone("chest"))
	var bind_tests:={"index":resolve(rig,probe,0)==rig.find_bone("chest")}
	probe.set_bind_name(0,&"pelvis");bind_tests.named_priority=resolve(rig,probe,0)==rig.find_bone("pelvis")
	probe.set_bind_name(0,&"missing_bone");bind_tests.missing_name=resolve(rig,probe,0)==-1
	probe.set_bind_name(0,&"");probe.set_bind_bone(0,28);bind_tests.invalid_index=resolve(rig,probe,0)==-1
	var fixture:={"vertices":vertices,"joints":joints,"weights":weights,"indices":indices,"cases":cases,"source_to_native":mapping,"source_skin":source_skin,"source_manifest":manifest,"bindings":bindings,"bind_tests":bind_tests,"errors":errors,"asset_sha":FileAccess.get_sha256("res://assets/hero.glb"),"sampler_sha":FileAccess.get_sha256("res://scripts/combat/melee_pose.gd"),"source_skin_sha":FileAccess.get_sha256("res://scripts/tests/fixtures/melee_pose_skin.bin")}
	var file:=FileAccess.open(OUT,FileAccess.WRITE);file.store_var(fixture);file.close()
	print("SKIN_CAPTURE ",vertices.size()," vertices, ",indices.size()/3," triangles, ",binds.size()," bind slots, ",cases.size()," poses; errors=",errors)
	world.free();quit(0 if errors.is_empty() else 1)
