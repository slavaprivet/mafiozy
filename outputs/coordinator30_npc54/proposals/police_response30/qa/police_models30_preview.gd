extends SceneTree
const Model30 = preload("res://scripts/police/npc_police_model30.gd")
const Gait30 = preload("res://scripts/preview_locomotion.gd")
var output := ""
var failures: Array[String]=[]
var checks: Array[String]=[]
var evidence: Dictionary={"presentation_only":true,"world_spawned":false,"ai_enabled":false,"models":[]}
func check(ok: bool,label: String) -> void:
	checks.append(label)
	if not ok:failures.append(label)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var marker := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-ready="):marker=arg.trim_prefix("--qa-ready=")
	var deadline: int=Time.get_ticks_msec()+30000
	while not marker.is_empty() and not FileAccess.file_exists(marker):
		if Time.get_ticks_msec()>deadline:quit(2);return
		await create_timer(.05).timeout
	create_timer(60.0).timeout.connect(func():check(false,"bounded preview deadline");finish())
	var scene:=Node3D.new();scene.name="TwoPoliceModelsPreview30";root.add_child(scene);current_scene=scene
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.14,.19,.24);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.87,1);env.environment.ambient_light_energy=.55;scene.add_child(env)
	var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.4;light.shadow_enabled=true
	var fill:=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-25,155,0);fill.light_energy=.55
	var ground:=MeshInstance3D.new();ground.mesh=PlaneMesh.new();ground.mesh.size=Vector2(25,25);scene.add_child(ground)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.20,.24,.27);ground.material_override=mat
	var camera:=Camera3D.new();camera.fov=40;scene.add_child(camera);camera.current=true
	check(not Model30.create_model30(-1).get("ok",false) and not Model30.create_model30(2).get("ok",false),"factory accepts exactly the two explicit variants")
	var models: Array=[];var gaits: Array=[]
	for variant: int in 2:
		var source: Dictionary=Model30.SOURCES30[variant]
		var admission: Dictionary=Model30.Cache30.load_verified(FileAccess.get_file_as_bytes(Model30.MANIFEST30),Model30.MANIFEST_SHA30,source.bridge,source.descriptor,Model30.DIRECTORY30)
		check(admission.get("ok",false),"canonical source admitted "+str(variant))
		if not admission.get("ok",false):evidence.admission=admission;finish();return
		var baseline: Dictionary=admission.cache.instantiate_actor();admission.cache.dispose()
		var made: Dictionary=Model30.create_model30(variant)
		check(made.get("ok",false),"police model factory "+str(variant))
		if not made.get("ok",false):baseline.visual.free();evidence.factory=made;finish();return
		scene.add_child(made.model);made.model.position.x=-.65 if variant==0 else .65
		var rig: Skeleton3D=made.appearance.skeleton
		var unchanged:=true
		for bone: int in 28:
			unchanged=unchanged and rig.get_bone_name(bone)==baseline.skeleton.get_bone_name(bone) and rig.get_bone_parent(bone)==baseline.skeleton.get_bone_parent(bone) and rig.get_bone_rest(bone)==baseline.skeleton.get_bone_rest(bone) and rig.get_bone_pose(bone)==baseline.skeleton.get_bone_pose(bone)
		check(unchanged,"all 28 canonical bones/rests/poses unchanged "+str(variant))
		for original: MeshInstance3D in baseline.meshes:
			var mesh: MeshInstance3D=made.appearance.visual.find_child(str(original.name),true,false)
			check(mesh!=null and mesh.mesh.get_surface_count()==original.mesh.get_surface_count(),"source mesh preserved "+str(variant)+":"+str(original.name))
			if mesh==null:continue
			for surf: int in original.mesh.get_surface_count():
				var before: Array=original.mesh.surface_get_arrays(surf);var after: Array=mesh.mesh.surface_get_arrays(surf)
				for attr: int in Mesh.ARRAY_MAX:
					if str(original.name)=="player_male_DEMO_core_FABRIC" and attr==Mesh.ARRAY_COLOR:continue
					check(before[attr]==after[attr],"source buffer "+str(variant)+":"+str(original.name)+":"+str(attr))
		check(made.model.get_meta("presentation_only30",false) and made.service_id.begins_with("police_service_"),"separate service-model identity "+str(variant))
		var after_stats: Dictionary=_stats(made.model)
		check(after_stats.colliders==0 and after_stats.bones==28,"model adds no collision or extra skeleton "+str(variant))
		check(not made.model.is_processing() and not made.model.is_physics_processing(),"model has no automatic behaviour "+str(variant))
		check(Model30.dress30(rig,variant).get("ok",false) and after_stats==_stats(made.model),"uniform application idempotent "+str(variant))
		evidence.models.append({"service_id":made.service_id,"source_bridge":made.source_bridge_id,"receipt":made.receipt,"baseline":_stats(baseline.visual),"model":after_stats,"source_descriptor":baseline.descriptor})
		baseline.visual.free();models.append(made)
		var gait:=Gait30.new();check(gait.bind(made.appearance.visual,made.motion,true),"existing canonical locomotion binds "+str(variant));gaits.append(gait)
		var support_y: float=gait._support_minimum_y(gait._rest_poses);evidence.models[-1]["rest_boot_support_y"]=support_y
		check(absf(support_y)<.001,"canonical rest boots at model ground "+str(variant))
	check(models[0].service_id!=models[1].service_id,"two distinct service identities")
	for view: String in ["front","side_a","side_b","cap"]:
		var target:=Vector3(0,1.0,0);var point:=Vector3(0,1.4,-5.0)
		if view=="side_a":target=Vector3(-.65,1.0,0);point=Vector3(-3.4,1.25,-.85)
		if view=="side_b":target=Vector3(.65,.9,0);point=Vector3(3.25,1.25,-.75)
		if view=="cap":target=Vector3(-.65,1.68,0);point=Vector3(-1.0,1.92,-1.25)
		camera.global_position=point;camera.look_at(target)
		for frame: int in 8:await process_frame
		await capture(view)
	for frame: int in 40:
		for gait: RefCounted in gaits:gait.update_pose(1.0/60.0,Vector3(0,0,-1.2),true)
		await process_frame
	camera.global_position=Vector3(0,1.3,-5);camera.look_at(Vector3(0,.95,0));await capture("gait")
	for made: Dictionary in models:
		var finite := true
		for bone: int in 28:finite=finite and made.appearance.skeleton.get_bone_global_pose(bone).is_finite()
		check(finite,"canonical gait has finite skeleton transforms "+made.service_id)
	var refs: Array=[]
	for made: Dictionary in models:refs.append(weakref(made.model));made.model.queue_free()
	models.clear();gaits.clear()
	await process_frame;await process_frame
	for ref30: WeakRef in refs:check(ref30.get_ref()==null,"model and attached geometry freed")
	finish()
func capture(view: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("police_"+view+".png"))==OK,"render "+view)
func finish() -> void:
	var result: Dictionary={"ok":failures.is_empty(),"checks":checks,"failures":failures,"evidence":evidence,"performance_accepted":false}
	var file:=FileAccess.open(output.path_join("POLICE_MODELS30.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"	"));file.close();print("POLICE_MODELS30 ",result.ok," checks=",checks.size());quit(0 if result.ok else 1)
func _stats(node: Node) -> Dictionary:
	var value: Dictionary={"nodes":1,"meshes":0,"vertices":0,"triangles":0,"colliders":0,"bones":0,"visible_meshes":0,"visible_vertices":0,"visible_triangles":0}
	if node is MeshInstance3D and node.mesh!=null:
		value.meshes=1
		if node.visible:value.visible_meshes=1
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			value.vertices+=arrays[Mesh.ARRAY_VERTEX].size()
			value.triangles+=(arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3)
		if node.visible:value.visible_vertices=value.vertices;value.visible_triangles=value.triangles
	if node is CollisionShape3D:value.colliders=1
	if node is Skeleton3D:value.bones=node.get_bone_count()
	for child: Node in node.get_children():
		var part: Dictionary=_stats(child)
		for key: String in value:value[key]+=part[key]
	return value
