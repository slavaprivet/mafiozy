extends SceneTree
## Small headless geometry regression, never instantiates the game or its actors.
## Calls the actual frozen/overlay renderer with original skinned fixture triangles.
var baseline := ""
var proposed := ""
var out := ""
var checks := 0
var errors: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label); print("FAIL ", label)

func quad(vertices: PackedVector3Array, indices: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, left: float, right: float, bottom: float, top: float, zleft: float, zright: float, bone: int) -> void:
	var start := vertices.size()
	vertices.append_array(PackedVector3Array([Vector3(left,bottom,zleft),Vector3(right,bottom,zright),Vector3(right,top,zright),Vector3(left,top,zleft)]))
	indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	for i in 4:
		bones.append_array(PackedInt32Array([bone,0,0,0]))
		weights.append_array(PackedFloat32Array([1,0,0,0]))

func fixture(frame: Transform3D) -> Dictionary:
	var actor := Node3D.new()
	root.add_child(actor)
	actor.global_transform = frame
	var rig := Skeleton3D.new()
	actor.add_child(rig)
	rig.add_bone("contact_part")
	rig.add_bone("folded_neighbour")
	var skin := Skin.new()
	skin.add_bind(0,Transform3D.IDENTITY)
	skin.add_bind(1,Transform3D.IDENTITY)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	# Contact part bends at x=.04. A separate folded limb sits .12m in front.
	# Incoming ray misses the neighbour, but a normal ray from contact crosses it.
	quad(vertices,indices,bones,weights,-.5,.04,-.5,.5,0,0,0)
	quad(vertices,indices,bones,weights,.04,.5,-.5,.5,0,.46*.35,0)
	quad(vertices,indices,bones,weights,-.1,.2,-.25,.25,.12,.12,1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.resource_name = "CLOTH_fixture"
	source.surface_set_material(0,material)
	var mesh := MeshInstance3D.new()
	rig.add_child(mesh)
	mesh.mesh = source
	mesh.skin = skin
	mesh.skeleton = NodePath("..")
	return {"actor":actor,"rig":rig,"source":source,"mesh":mesh,"frame":frame}

func run_case(script_path: String, fixed: bool, frame: Transform3D, name: String) -> void:
	var data := fixture(frame)
	await process_frame
	var renderer: RefCounted = load(script_path).new()
	check(renderer.configure(data.actor,data.rig,1.0),name+":fixture_configures")
	var incoming: Vector3 = frame.basis * Vector3(.8,0,-.6)
	var contact: Vector3 = frame * Vector3(-.4,0,.3)
	var actual: Vector3 = frame.origin
	# Independent fixture geometry: the incoming segment crosses z=.12 at x=-.16,
	# outside neighbour x[-.1,.2], then reaches contact part at local (0,0,0).
	renderer._query_bones = renderer._bone_poses()
	renderer._prepare_query_frames()
	var coarse: Dictionary = renderer._query(contact,-incoming,1.0)
	var coarse_center: Dictionary = renderer._probe(coarse,contact,-incoming)
	check(not coarse_center.is_empty() and coarse_center.world_point.distance_to(actual)<.00001,name+":native_incoming_ray_selects_contact_part")
	check(renderer.accept(name,contact,-incoming,incoming,1.0),name+":accepts_authenticated_ray_geometry")
	var mark: Dictionary = renderer._marks[-1]
	var centers: Array[Vector3] = []
	var wrong_part := 0
	var furthest_normal := 0.0
	var center_error := 0.0
	for triangle: Dictionary in mark.triangles:
		for anchor: Dictionary in triangle.anchors:
			var local: Vector3 = frame.affine_inverse() * anchor.world_point
			furthest_normal = maxf(furthest_normal,local.z)
			for index: int in [anchor.ids.x,anchor.ids.y,anchor.ids.z]:
				if int(renderer._surfaces[anchor.s].bones[index*4])==1: wrong_part += 1
			if anchor.probe == Vector2.ZERO:
				centers.append(anchor.world_point)
				center_error = maxf(center_error,anchor.world_point.distance_to(actual))
	check(not centers.is_empty(),name+":has_exact_center_anchors")
	if fixed:
		check(center_error<.00001,name+":center_stays_on_actual_incoming_ray")
		check(wrong_part==0 and furthest_normal<.05,name+":rim_follows_bent_contact_part_without_jumping_to_neighbour")
	else:
		check(center_error>.119 and center_error<.121,name+":baseline_reproduces_120mm_false_center_shift")
		check(wrong_part>0,name+":baseline_fray_attaches_to_wrong_bone")
	var before: PackedVector3Array = renderer._positions()
	data.rig.set_bone_pose_position(0,Vector3(.3,0,0))
	await process_frame
	var after: PackedVector3Array = renderer._positions()
	var maximum_follow_error := 0.0
	for i in before.size():
		maximum_follow_error = maxf(maximum_follow_error,(after[i]-before[i]-Vector3(.3,0,0)).length())
	if fixed: check(maximum_follow_error<.00001,name+":all_anchors_follow_original_skin_bone_after_pose_change")
	else: check(maximum_follow_error>.29,name+":baseline_wrong_anchors_stay_with_other_limb")
	check(not renderer.accept(name,contact,-incoming,incoming,1.0),name+":duplicate_receipt_rejected")
	check(not renderer.accept(name+":miss",frame*Vector3(2,0,.3),-incoming,incoming,1.0),name+":proxy_graze_missing_original_mesh_creates_no_mark")
	check(data.mesh.mesh==data.source and renderer._marks.size()==1,name+":original_mesh_and_single_mark_preserved")
	cases.append({"name":name,"fixed":fixed,"center_error_m":center_error,"wrong_part_anchor_corners":wrong_part,"max_local_anchor_z":furthest_normal,"pose_follow_error_m":maximum_follow_error,"marks":renderer._marks.size(),"cost":renderer.last_cost})
	renderer.dispose()
	data.actor.queue_free()
	await process_frame

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
		if arg.begins_with("--proposed="): proposed=arg.trim_prefix("--proposed=")
		if arg.begins_with("--out="): out=arg.trim_prefix("--out=")
	if baseline.is_empty() or proposed.is_empty() or out.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	check(DisplayServer.get_name()=="headless","CPU_only_dummy_rendering")
	await run_case(baseline,false,Transform3D.IDENTITY,"baseline_folded")
	await run_case(proposed,true,Transform3D.IDENTITY,"fixed_folded")
	var lying := Transform3D(Basis.from_euler(Vector3(-PI/2,.4,0)),Vector3(5,2,-3))
	await run_case(baseline,false,lying,"baseline_lying_rotated")
	await run_case(proposed,true,lying,"fixed_lying_rotated")
	var report := {"passed":errors.is_empty(),"checks":checks,"errors":errors,"cases":cases,"scope":"Synthetic bent/skinned competing surfaces through actual baseline/overlay renderer; no game, native HP, projectile flight, population or GPU instantiated. Does not reconstruct the user's screenshot or prove whole-scene performance.","baseline_sha256":FileAccess.get_sha256(baseline),"proposed_sha256":FileAccess.get_sha256(proposed)}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HIT_PROJECTION_RESULT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
