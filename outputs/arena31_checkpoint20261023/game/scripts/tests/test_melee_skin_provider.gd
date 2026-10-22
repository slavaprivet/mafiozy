extends SceneTree
const Provider=preload("res://scripts/combat/melee_skin_provider.gd")
const Player=preload("res://scripts/preview_player.gd")
const Source=preload("res://scripts/combat/melee_pose.gd")
const Cache=preload("res://scripts/npc_visual/npc_visual_cache.gd")
var checks:=0
var failures:=[]
var native:Object
var timings:=[]
var actors:=[]
func _initialize():run.call_deferred()
func check(value:bool,label:String):
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func publish(actor:Node,revision:int,epoch:int=1)->void:
	actor.set_meta("melee_skin_pose",{"actor_id":actor.get_meta("actor_id"),"life_generation":actor.get_meta("life_generation"),"pose_epoch":epoch,"pose_revision":revision,"pose_owner":"TEST_ONLY_accepted_writer"})
func identity(actor:Node,id:String)->void:
	actor.set_meta("actor_id",id);actor.set_meta("life_generation",1);publish(actor,1)
func scalar(visual:Node3D,rig:Skeleton3D)->PackedVector3Array:
	var result:=PackedVector3Array()
	for mesh:MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var frames:Array[Transform3D]=[]
		for slot in mesh.skin.get_bind_count():
			var name=mesh.skin.get_bind_name(slot)
			var bone=rig.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(slot)
			frames.append(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(slot))
		for surface in mesh.mesh.get_surface_count():
			var arrays=mesh.mesh.surface_get_arrays(surface)
			for index in arrays[Mesh.ARRAY_VERTEX].size():
				var point:=Vector3.ZERO
				for slot in 4:
					var at=index*4+slot;var weight=arrays[Mesh.ARRAY_WEIGHTS][at]
					if weight>0:point+=(frames[arrays[Mesh.ARRAY_BONES][at]]*arrays[Mesh.ARRAY_VERTEX][index])*weight
				result.append(point)
	return result
func run_actor(actor:Node3D,visual:Node3D,rig:Skeleton3D,label:String)->void:
	var provider=Provider.new();var configured=provider.configure(actor,visual,rig,native,{"actor_id":actor.get_meta("actor_id"),"life_generation":1})
	check(configured.ok,label+" actual configure "+str(configured))
	if not configured.ok:return
	var captures:=[]
	for revision in range(1,5):
		if revision==2:
			rig.set_bone_pose_rotation(rig.find_bone("chest"),Quaternion(Vector3(1,.3,.4).normalized(),.4))
		if revision==3:
			var index=rig.find_bone("upperarm_r");var frame=rig.get_bone_global_pose(index)
			frame.basis.x+=frame.basis.y*.13;frame.basis.z*=1.12
			rig.set_bone_global_pose_override(index,frame,1.0,true)
		if revision==4:actor.transform=Transform3D(Basis.from_euler(Vector3(.13,.42,-.08)).scaled(Vector3(1.1,.9,1.2)),Vector3(8,2,-4))
		publish(actor,revision)
		var t=Time.get_ticks_usec();var captured=provider.capture(revision);timings.append(Time.get_ticks_usec()-t)
		check(captured.ok,label+" displayed capture "+str(revision)+str(captured.get("error")))
		if not captured.ok:continue
		var expected=scalar(visual,rig)
		check(captured.vertices.to_byte_array()==expected.to_byte_array(),label+" every vertex bit-exact scalar "+str(revision))
		check(captured.identity.actor_id==actor.get_meta("actor_id") and captured.pose_revision==revision,"actual identity/revision retained")
		for part:Dictionary in captured.parts:
			check(part.world_vertices==captured.vertices.slice(part.vertex_first,part.vertex_first+part.vertex_count),"exact part world slice")
			check(part.head_slot_weights.size()==part.vertex_count*4,"four original head weight slots")
			for at in part.indices.size():check(part.indices[at]+part.vertex_first==captured.indices[part.triangle_first*3+at],"unaltered local/global original triangle order")
		captures.append({"revision":revision,"vertices":captured.vertices.size(),"parts":captured.parts.size(),"triangles":captured.indices.size()/3})
	var original=provider.capture(4);var saved_indices:PackedInt32Array=original.indices.duplicate();var saved_head=original.parts[0].head_slot_weights.duplicate()
	original.indices[0]=0;original.parts[0].indices[0]=999;original.parts[0].head_slot_weights[0]=.123;original.vertices[0]=Vector3.ZERO
	var fresh=provider.capture(4)
	check(fresh.ok and fresh.indices==saved_indices and fresh.parts[0].head_slot_weights==saved_head,"caller mutation never changes owned topology/weights")
	check(provider.current(fresh.owner_receipt),"captured actual owner/geometry still current")
	var actor_frame=actor.transform;actor.position+=Vector3(.01,0,0)
	check(not provider.current(fresh.owner_receipt),"query guard rejects root motion without published pose revision")
	actor.transform=actor_frame
	check(provider.current(fresh.owner_receipt),"exact unchanged pose restored")
	var mesh:MeshInstance3D=visual.get_node(original.parts[0].mesh_id)
	mesh.visible=false
	check(not provider.capture(4).ok,"visibility change requires new accepted owner revision")
	publish(actor,5);var hidden=provider.capture(5)
	check(hidden.ok and not hidden.parts[0].visible and hidden.indices==saved_indices,"hidden part retained with exact source skip flag and stable face ordinals")
	mesh.visible=true;visual.visible=false;publish(actor,6);hidden=provider.capture(6)
	check(hidden.ok,"hidden ancestor captured coherently")
	if hidden.ok:
		for part:Dictionary in hidden.parts:check(not part.visible,"all hidden ancestor parts marked invisible")
	visual.visible=true;publish(actor,7)
	check(provider.capture(7).ok,"same life visible again with new owner revision")
	check(not provider.capture(0).ok and not provider.capture(6).ok,"zero/stale requested revisions fail")
	rig.set_bone_pose_rotation(rig.find_bone("head"),Quaternion(Vector3.RIGHT,.1))
	check(not provider.capture(7).ok,"unpublished actual pose change rejected")
	publish(actor,8);check(provider.capture(8).ok,"published actual new pose captures")
	var prior_skin=mesh.skin;mesh.skin=prior_skin.duplicate(true)
	check(not provider.capture(8).ok,"replaced actual Skin invalidates binding")
	mesh.skin=prior_skin
	actor.set_meta("life_generation",2);publish(actor,9)
	check(not provider.capture(9).ok,"new actor life never reuses cached binding")
	actor.set_meta("life_generation",1);publish(actor,10)
	check(not provider.capture(10).ok,"observed newlife cannot be rolled back into old cached binding")
	var tree=root.get_tree();provider.dispose();provider.dispose()
	check(not tree.node_added.is_connected(Callable(provider,"_node_added")) and not prior_skin.changed.is_connected(Callable(provider,"_invalidate_resource")),"dispose disconnects external signals")
	actors.append({"label":label,"configured":configured,"captures":captures})
func matrix(a:Array)->Transform3D:return Transform3D(Basis(Vector3(a[0],a[1],a[2]),Vector3(a[4],a[5],a[6]),Vector3(a[8],a[9],a[10])),Vector3(a[12],a[13],a[14]))
func vector(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func source_canaries()->Dictionary:
	var player=Player.new();root.add_child(player);player.set_physics_process(false);identity(player,"TEST_ONLY_source_canary")
	var provider=Provider.new();check(provider.configure(player,player._visual,player._pose_skeleton,native,{"actor_id":player.get_meta("actor_id"),"life_generation":1}).ok,"source canary provider")
	var sampler=Source.new();check(sampler.configure(player._pose_skeleton,player._pose_motion,player._locomotion._rest_poses,player._model_scale,player._visual),"unchanged source sampler")
	var fixture:Dictionary=FileAccess.open("res://../../outputs/coordinator21_melee_native_skin/project/skin_fixture.bin",FileAccess.READ).get_var()
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_pose_oracle.json"))
	var source=FileAccess.get_file_as_bytes("res://scripts/tests/fixtures/melee_pose_skin.bin").to_float64_array();var maximum:=0.0;var revision:=0
	for case_index in fixture.source_manifest.cases:
		var row:Dictionary=oracle.cases[int(case_index)];var poses:Array[Transform3D]=[]
		for i in 28:poses.append(matrix(row.base.poses[str(player._pose_skeleton.get_bone_name(i))]))
		var q=row.base.visual_rotation
		var base={"valid":true,"poses":poses,"visual_offset":vector(row.base.visual_offset),"visual_rotation":Quaternion(q[0],q[1],q[2],q[3]),"scaled_offset":vector(row.base.scaled_offset),"authority_epoch":4}
		var selected=sampler.sample(base,row.action,row.posture,row.phase,row.gait,4);player._apply_selected_pose(selected)
		revision+=1;publish(player,revision,4);var captured=provider.capture(revision);check(captured.ok,"source actual displayed canary "+str(case_index))
		if not captured.ok:continue
		var inverse:Transform3D=player._pose_motion.get_parent().global_transform.affine_inverse()
		for index in 8338:
			var point:Vector3=inverse*captured.vertices[fixture.source_to_native[index]]
			var at=((revision-1)*8338+index)*3;var target=Vector3(source[at],source[at+1],source[at+2])
			maximum=maxf(maximum,point.distance_to(target))
		check(maximum<.0001,"original JS fullskin canary tolerance")
	provider.dispose();player.free();return {"cases":revision,"source_max_m":maximum}
func negatives()->void:
	var player=Player.new();root.add_child(player);player.set_physics_process(false);identity(player,"TEST_ONLY_negatives")
	var rig:Skeleton3D=player._pose_skeleton;var skin=Skin.new();skin.set_bind_count(1)
	skin.set_bind_bone(0,rig.find_bone("chest"));check(Provider.resolve_bind(rig,skin,0)==rig.find_bone("chest"),"empty named bind uses explicit index")
	skin.set_bind_name(0,&"head");check(Provider.resolve_bind(rig,skin,0)==rig.find_bone("head"),"name wins conflicting explicit index")
	skin.set_bind_name(0,&"missing_actual_bone");check(Provider.resolve_bind(rig,skin,0)==-1,"invalid nonempty name never falls back to valid index")
	skin.set_bind_name(0,&"");skin.set_bind_bone(0,999);check(Provider.resolve_bind(rig,skin,0)==-1,"invalid explicit index never guesses bone0")
	var binding={"actor_id":player.get_meta("actor_id"),"life_generation":1}
	var provider=Provider.new();var fake=Object.new()
	check(not provider.configure(player,player._visual,rig,fake,binding).ok,"arbitrary object not accepted as native kernel")
	fake.free();check(provider.configure(player,player._visual,rig,native,binding).ok,"failed configure leaves retry clean")
	var captured=provider.capture(1);check(captured.ok,"negative fixture valid initial capture")
	var mutation=captured.owner_receipt.duplicate();mutation.pose_owner="forged"
	check(not provider.current(mutation),"copied result cannot forge current owner")
	var thread=Thread.new();thread.start(func():return provider.capture(1))
	check(not thread.wait_to_finish().ok,"worker rejects before touching scene")
	player.remove_meta("melee_skin_pose");check(not provider.capture(1).ok,"missing authoritative receipt rejected")
	publish(player,2);check(provider.capture(2).ok,"owner publication after temporary cancellation")
	var mesh:MeshInstance3D=player._visual.find_children("*","MeshInstance3D",true,false)[0]
	var saved_path=mesh.skeleton;mesh.skeleton=NodePath(".")
	check(not provider.capture(2).ok,"same node changed skeleton path rejected")
	mesh.skeleton=saved_path
	var saved_mesh=mesh.mesh;mesh.mesh=saved_mesh.duplicate(true)
	check(not provider.capture(2).ok,"replacement mesh resource rejected")
	mesh.mesh=saved_mesh
	var extra=MeshInstance3D.new();mesh.get_parent().add_child(extra)
	check(not provider.capture(2).ok,"new mesh descendant invalidates old topology")
	extra.free();provider.dispose()
	check(provider.configure(player,player._visual,rig,native,binding).ok,"new binding after explicit retirement")
	mesh.skin.emit_changed();check(not provider.capture(2).ok,"mutated Skin signal invalidates cached bind matrices")
	provider.dispose();check(provider.configure(player,player._visual,rig,native,binding).ok,"rebuild after bind event")
	player.queue_free();check(not provider.capture(2).ok,"queued actor rejected before scene disappears")
	provider.dispose();await process_frame
	check(not provider.capture(2).ok,"disposed provider never returns previous arrays")
func run()->void:
	var sha=FileAccess.get_sha256("res://scripts/combat/melee_skin_provider.gd")
	var loaded=GDExtensionManager.load_extension(ProjectSettings.globalize_path("res://../../outputs/coordinator21_melee_skin_provider/native.gdextension"))
	check(FileAccess.get_sha256("res://../../outputs/coordinator21_melee_combined/project/melee_kernels.dll")=="a5695c0b117e42a4847d10cdef0f7b71485f6243a7f412b6d6cb0eb5924c2add","accepted combined native bytes")
	check(loaded==GDExtensionManager.LOAD_STATUS_OK,"explicit isolated combined DLL load")
	if not ClassDB.class_exists("MeleeNativeSkin"):quit(2);return
	native=ClassDB.instantiate("MeleeNativeSkin")
	var player=Player.new();root.add_child(player);player.set_physics_process(false);identity(player,"TEST_ONLY_actual_hero")
	run_actor(player,player._visual,player._pose_skeleton,"hero")
	player.free()
	var directory="res://assets/npc_visual/session/prepared";var bytes=FileAccess.get_file_as_bytes(directory+"/manifest.json");var manifest:Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	for entry:Dictionary in manifest.entries:
		var loaded_cache=Cache.load_verified(bytes,FileAccess.get_sha256(directory+"/manifest.json"),entry.entry.bridge_id,entry.entry.descriptor_sha256,directory)
		check(loaded_cache.ok,"actual prepared NPC receipt "+str(entry.entry.bridge_id))
		if not loaded_cache.ok:continue
		var actor=Node3D.new();root.add_child(actor);identity(actor,str(entry.entry.descriptor.id))
		var built=loaded_cache.cache.instantiate_actor();check(built.ok,"actual cached NPC instantiate")
		actor.add_child(built.visual);run_actor(actor,built.visual,built.skeleton,str(entry.entry.bridge_id));actor.free()
	var canaries=source_canaries()
	await negatives()
	check(sha==FileAccess.get_sha256("res://scripts/combat/melee_skin_provider.gd"),"provider bytes stable")
	timings.sort();var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"sha":sha,"actors":actors,"source_canaries":canaries,"capture_cpu_us":{"samples":timings.size(),"p50":timings[timings.size()/2],"p95":timings[int(timings.size()*.95)]},"scope":"Explicit isolated native load; actual hero and3prepared NPCs. TEST_ONLY owner receipts, no placement/contact/HP/GPU claims."}
	FileAccess.open("res://../../outputs/coordinator21_melee_skin_provider/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("MELEE_SKIN_PROVIDER ",JSON.stringify(report));native.free();quit(0 if failures.is_empty() else 1)
