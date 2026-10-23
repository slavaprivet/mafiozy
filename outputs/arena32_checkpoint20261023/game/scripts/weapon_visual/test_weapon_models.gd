extends SceneTree
const Catalog = preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
const Visual = preload("res://scripts/weapon_visual/weapon_visual.gd")
const Prepare = preload("res://scripts/weapon_visual/prepare_weapon_models.gd")
var source_dir := ""
var asset_dir := ""
var report_path := ""
var checks := 0
var failures: Array[String] = []
var max_position_error := 0.0
var max_normal_error := 0.0
var evidence: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 40: failures.append(label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source_dir = arg.trim_prefix("--source=")
		if arg.begins_with("--assets="): asset_dir = arg.trim_prefix("--assets=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	call_deferred("run")

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("manifest.json")))
	var catalog := Catalog.new()
	check(catalog.open(asset_dir.path_join("manifest.json")).ok,"catalog opens")
	check(catalog.retained_count() == 0,"lazy cache empty")
	check(not catalog.instantiate_weapon("invented_gun").ok,"unknown ID rejected")
	var total_start := Time.get_ticks_usec()
	var memory_before := OS.get_static_memory_usage()
	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	for entry: Dictionary in source.entries:
		var start := Time.get_ticks_usec()
		var result: Dictionary = catalog.instantiate_weapon(entry.id)
		var cold_us := Time.get_ticks_usec() - start
		check(result.ok,entry.id+": native scene load")
		if not result.ok: continue
		var visual: Node3D = result.visual
		get_root().add_child(visual)
		check(visual.profile().id == entry.id,entry.id+": profile identity")
		check(visual.profile().source_metadata == entry.source_metadata,entry.id+": full factory metadata")
		check(visual.transform.is_equal_approx(Transform3D.IDENTITY),entry.id+": no extra yaw/scale")
		check(catalog.get_entry(entry.id).profile.bounds_source==entry.bounds,"metadata-only catalogue exact source bounds")
		check(visual.geometry_nodes().size()==entry.native_draw_surfaces,"borrowed geometry node count")
		if entry.bounds!=null:
			var native_low := Vector3(INF,INF,INF);var native_high := Vector3(-INF,-INF,-INF)
			for mesh_node: MeshInstance3D in visual.geometry_nodes():
				for point: Vector3 in mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var transformed := mesh_node.transform*point
					native_low=native_low.min(transformed);native_high=native_high.max(transformed)
			check(visual.local_bounds().position.is_equal_approx(native_low) and visual.local_bounds().end.is_equal_approx(native_high),"exact native AABB API")
		var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join(entry.id+".oracle.json")))
		var triangles := 0
		var batches: Dictionary = {}
		for batch: Dictionary in entry.batches:
			var node := visual.get_node(NodePath(batch.key)) as MeshInstance3D
			check(node != null,entry.id+": batch "+batch.key)
			if node == null: continue
			check(node.mesh.get_surface_count()==1 and node.mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES,"triangle surface")
			check(node.transform.is_equal_approx(Prepare.matrix(batch.local_matrix)),"batch transform")
			check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"source shadow casting")
			var arrays := node.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_VERTEX].size()*3 == int(batch.positions.count),"all vertices retained")
			check(arrays[Mesh.ARRAY_INDEX].size() == int(batch.indices.count),"all triangle indices retained")
			triangles += arrays[Mesh.ARRAY_INDEX].size()/3
			batches[batch.key] = {"node":node,"arrays":arrays}
			mesh_ids[node.mesh.get_instance_id()] = true
			var material := node.mesh.surface_get_material(0) as StandardMaterial3D
			material_ids[material.get_instance_id()] = true
			var mat: Dictionary = entry.materials[int(batch.material)]
			var linear := material.albedo_color.srgb_to_linear()
			check(Vector3(linear.r,linear.g,linear.b).distance_to(Prepare.vector(mat.color_linear))<2e-6,"linear material RGB")
			check(absf(material.albedo_color.a-mat.opacity)<1e-6 and absf(material.metallic-mat.metallic)<1e-6 and absf(material.roughness-mat.roughness)<1e-6,"alpha/metallic/roughness")
			check((material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)==mat.transparent,"lens transparency")
			check(material.cull_mode == BaseMaterial3D.CULL_BACK,"source front-face culling")
			check(material.get_meta("weapon_source_material")==mat,"full source material metadata")
			if mat.transparent: check(material.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_ALWAYS,"source transparent depth write")
		check(triangles == int(entry.triangles),entry.id+": full triangle count")
		for part: Dictionary in oracle.parts:
			var batch: Dictionary = batches[part.batch]
			var arrays: Array = batch.arrays
			var original := Prepare.matrix(part.local_matrix)
			var original_normal := original.basis.inverse().transposed()
			var native: Transform3D = batch.node.transform
			var native_normal := native.basis.inverse().transposed()
			for i: int in int(part.vertex_count):
				var at := i*3
				var p := Vector3(part.positions[at],part.positions[at+1],part.positions[at+2])
				var n := Vector3(part.normals[at],part.normals[at+1],part.normals[at+2])
				var index := int(part.vertex_start)+i
				var position_error: float = (native*arrays[Mesh.ARRAY_VERTEX][index]).distance_to(original*p)
				var normal_error: float = (native_normal*arrays[Mesh.ARRAY_NORMAL][index]).normalized().distance_to((original_normal*n).normalized())
				max_position_error=maxf(max_position_error,position_error)
				max_normal_error=maxf(max_normal_error,normal_error)
				check(position_error<1e-6,entry.id+": source vertex transform")
				check(normal_error<0.0002,entry.id+": source normal transform")
				check(arrays[Mesh.ARRAY_TEX_UV][index].distance_to(Vector2(part.uvs[i*2],part.uvs[i*2+1]))<1e-6,"source UV")
			for i: int in int(part.index_count):
				var corner := i%3
				var source_corner := 0 if corner==0 else 3-corner
				var source_index := (i/3)*3+source_corner
				check(arrays[Mesh.ARRAY_INDEX][int(part.index_start)+i]==int(part.vertex_start)+int(part.indices[source_index]),"source triangle corner order")
		var anchors := {"GripOrigin":entry.source_metadata.gripOrigin,"PrimaryHandGrip":entry.primary_hand_grip,"Muzzle":entry.source_metadata.muzzle,"EjectionPort":entry.source_metadata.ejectionPort,"SupportGrip":entry.source_metadata.supportGrip}
		var mount := Node3D.new(); get_root().add_child(mount)
		mount.transform=Transform3D(Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,0.27),Vector3(3,1.2,-5)).scaled_local(Vector3.ONE*0.368)
		visual.reparent(mount,false)
		for name: String in anchors:
			var got: Dictionary = visual.anchor_world(name)
			check(got.ok == (anchors[name]!=null),"anchor presence "+name)
			if got.ok: check(got.position.distance_to(mount.global_transform*Prepare.vector(anchors[name]))<1e-6,"source scaled/rotated anchor "+name)
		var shot: Dictionary = visual.shot_transform()
		check(shot.ok == (entry.id!="none"),"none has no shot transform")
		if shot.ok:
			check(shot.direction.distance_to((mount.global_basis*Vector3.BACK).normalized())<1e-6,"source +Z muzzle direction")
			if entry.source_metadata.ejectionPort==null: check(shot.ejection_origin==shot.origin,"ejection fallback to muzzle")
		var second: Node3D = catalog.instantiate_weapon(entry.id).visual
		for batch: Dictionary in entry.batches:
			check(second.get_node(NodePath(batch.key)) != visual.get_node(NodePath(batch.key)),"private part nodes")
			check(second.get_node(NodePath(batch.key)).mesh == visual.get_node(NodePath(batch.key)).mesh,"shared immutable geometry")
		for sample: Dictionary in source.reload_samples:
			var got := Visual.sample_reload(sample.input)
			for key: String in ["progress","lower","grab","pull","bolt"]: check(absf(got[key]-sample[key])<1e-10,"source reload envelope "+key)
			check(got.active==sample.active,"source reload active")
			for prone: float in [0.0,0.5,1.0]:
				check(visual.apply_reload(sample.input,prone).ok,"reload accepts source input")
				for batch: Dictionary in entry.batches:
					var expected := Prepare.matrix(batch.local_matrix)
					if batch.slot=="magazine": expected.origin += Vector3(-sample.pull*.25*prone,-sample.pull*.62*(1-prone),0)
					elif batch.slot=="slide": expected.origin.z -= sample.bolt*.12
					check(visual.get_node(NodePath(batch.key)).transform.is_equal_approx(expected),"source reload slot transform")
					check(second.get_node(NodePath(batch.key)).transform.is_equal_approx(Prepare.matrix(batch.local_matrix)),"other instance unaffected")
		check(not visual.apply_reload(.5,2).ok,"invalid prone rejected")
		visual.apply_reload(NAN)
		for batch: Dictionary in entry.batches: check(visual.get_node(NodePath(batch.key)).transform.is_equal_approx(Prepare.matrix(batch.local_matrix)),"nonfinite reload restores rest")
		second.free(); mount.free()
		var times: Array[int] = []
		for repeat: int in 40:
			start=Time.get_ticks_usec();var warm: Node3D=catalog.instantiate_weapon(entry.id).visual;warm.free();times.append(Time.get_ticks_usec()-start)
		times.sort()
		evidence.append({"id":entry.id,"source_meshes":entry.source_meshes,"native_surfaces":entry.native_draw_surfaces,"triangles":entry.triangles,"cold_hash_load_instance_us":cold_us,"warm_instance_free_p50_us":times[20],"warm_instance_free_p95_us":times[38]})
	var retained_memory_delta := OS.get_static_memory_usage()-memory_before
	check(catalog.retained_count()==15,"bounded all-ID scene cache")
	catalog.close();check(catalog.retained_count()==0,"cache releases scenes")
	check(not catalog.instantiate_weapon("nagan").ok,"closed catalogue rejects")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"max_position_error":max_position_error,"max_normal_error":max_normal_error,
		"meshes_retained_all_ids":mesh_ids.size(),"materials_retained_all_ids":material_ids.size(),"process_static_memory_delta_including_test_oracles":retained_memory_delta,
		"elapsed_ms":(Time.get_ticks_usec()-total_start)/1000.0,"entries":evidence,"scope":"Headless source/native geometry/material/anchor/reload parity and component costs only; GPU/fullscene unmeasured"}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WEAPON_VISUAL_TEST ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
