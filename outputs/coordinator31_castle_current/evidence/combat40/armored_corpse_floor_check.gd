extends SceneTree

var scene: Node3D
var out_dir := ""
var errors: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i: int in n: await physics_frame

func _check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)

func _flesh_caps(node: MeshInstance3D, flesh: Material) -> int:
	if node.mesh == null: return 0
	var n := 0
	for surface: int in node.mesh.get_surface_count():
		if node.mesh.surface_get_material(surface) == flesh: n += 1
	return n

func _high_vertices(node: MeshInstance3D, cut_y: float) -> int:
	if node.mesh == null: return 0
	var n := 0
	for surface: int in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX: continue
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if (node.global_transform * vertex).y > cut_y + 0.08: n += 1
	return n

func _run() -> void:
	var packed := load("res://scenes/castle.tscn") as PackedScene
	if packed == null: _finish({"stage":"scene_parse"}); return
	scene = packed.instantiate()
	scene.set("preview_residents_enabled", false)
	scene.set_meta("npc_home_registry58", RefCounted.new())
	root.add_child(scene); current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.get("preview_ready") != true: _finish({"stage":"castle_ready"}); return
	var player: CharacterBody3D = scene.get("_player")
	var storage: Node = scene.get("preview_castle").get("armory_storage")
	if not is_instance_valid(storage): _finish({"stage":"storage"}); return
	var rack: Array = storage.get("_rack_points")
	var original_position: Vector3 = player.global_position
	player.global_position = (scene.get("preview_castle") as Node3D).to_global(rack[0])
	player.velocity = Vector3.ZERO
	var took_sword: bool = storage.interact()
	player.global_position = original_position
	player.velocity = Vector3.ZERO
	var sword: Node = scene.get("preview_sword_prototype")
	if not took_sword or not is_instance_valid(sword): _finish({"stage":"equip", "took_sword":took_sword}); return
	for i: int in 360:
		if is_instance_valid(sword.get("_npc_rig")): break
		await physics_frame
	var rig: Skeleton3D = sword.get("_npc_rig")
	var body: CharacterBody3D = sword.get("_npc_body")
	if not is_instance_valid(rig) or not is_instance_valid(body): _finish({"stage":"npc_bind"}); return
	sword.set_npc_armor31({"head":"heavy_head","torso":"heavy_torso","hands":"heavy_hands","legs":"heavy_legs","feet":"heavy_feet"})
	var head_bone := rig.find_bone("head")
	var neck_bone := rig.find_bone("neck")
	if head_bone < 0 or neck_bone < 0: _finish({"stage":"bones", "head":head_bone, "neck":neck_bone}); return
	var head_world: Vector3 = rig.global_transform * rig.get_bone_global_pose(head_bone).origin
	var neck_world: Vector3 = rig.global_transform * rig.get_bone_global_pose(neck_bone).origin
	var cut_at := neck_world.lerp(head_world, 0.20)
	# Controlled admitted sharp hit, using the production cut path.
	sword._npc_take_blade_part("head", cut_at, 8.0, Vector3.UP, 200.0, true, true)
	var flesh = sword.get("_flesh_material")
	var before = cap_report(sword,rig,flesh)
	sword._apply_npc_severed()
	rig.force_update_all_bone_transforms()
	var after = cap_report(sword,rig,flesh)
	# Clear only transient visual occluders for diagnostic close-up.
	for drop in sword.get("_npc_gore"):
		if is_instance_valid(drop): drop.visible = false
	for piece in sword.get("_npc_debris"):
		if is_instance_valid(piece.get("node")): piece.node.visible = false
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.global_position = cut_at + Vector3(0.3,0.65,0.7)
	camera.look_at(cut_at + Vector3(0,-0.09,0))
	camera.fov=35
	camera.make_current()
	# Capture before gravity changes corpse orientation.
	await process_frame
	var attachments = 0
	for entry in sword.get("_npc_debris"):
		for child in entry.node.get_children():
			if child is Node3D and not child is CollisionShape3D and child.name != "KnightCutPiece": attachments += 1
	var head_hit = rig.get_node_or_null("Hithead")
	var inactive_hitboxes = 0
	if head_hit:
		for child in head_hit.get_children():
			if child is CollisionObject3D and child.collision_layer==0 and child.collision_mask==0: inactive_hitboxes += 1
	var result = {"inactive_head_hitboxes":inactive_hitboxes,"whole_meshes_attached_to_real_debris":attachments,"before":before,"after":after,"cut_count":sword.get("_npc_cut_total"),"head_scale":str(rig.get_bone_pose_scale(head_bone)),"neck_scale":str(rig.get_bone_pose_scale(neck_bone))}
	await _frames(360)
	rig.force_update_all_bone_transforms()
	result["after_120_ticks"] = cap_report(sword,rig,flesh)
	var minimum := INF
	for mesh: MeshInstance3D in sword._npc_skinned_meshes():
		if not mesh.is_visible_in_tree(): continue
		var binds: Array[Transform3D] = sword._cut_skin_transforms39(mesh)
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = sword._cut_skin_arrays39(mesh.mesh.surface_get_arrays(surface),binds,false)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: minimum=minf(minimum,(mesh.global_transform*vertex).y)
	var corpse: RigidBody3D = sword._npc_corpse31
	result["minimum_visible_y"] = minimum
	result["corpse_active"] = is_instance_valid(corpse)
	result["armor_equipped_after_settle"] = sword._npc_armor_visual31.snapshot().equipped.size()
	result["corpse_contacts"] = corpse.get_contact_count() if is_instance_valid(corpse) else 0
	result["corpse_rotation"] = str(corpse.rotation) if is_instance_valid(corpse) else "missing"
	FileAccess.open(out_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	var passed = int(result.cut_count)>0 and inactive_hitboxes==1 and minimum >= -0.06 and is_instance_valid(corpse) and corpse.get_contact_count()>0 and result.armor_equipped_after_settle==5
	for i in before.size():
		if before[i].name.ends_with("SKIN"):
			passed = passed and after[i].area >= before[i].area * 0.999 and result.after_120_ticks[i].area >= before[i].area * 0.999
	quit(0 if passed else 1)

func cap_report(sword,rig,flesh):
	var report = []
	for node in sword._npc_skinned_meshes():
		for surface in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(surface) != flesh: continue
			var arr = node.mesh.surface_get_arrays(surface)
			var vs = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			var ids = arr[Mesh.ARRAY_INDEX]
			var pts = PackedVector3Array()
			for i in vs.size():
				var pos = Vector3.ZERO
				for k in 4:
					var bind = bones[i*4+k]
					pos += rig.get_bone_global_pose(node.skin.get_bind_bone(bind)) * node.skin.get_bind_pose(bind) * vs[i] * weights[i*4+k]
				pts.append(pos)
			var area = 0.0
			for i in range(0,ids.size(),3):
				area += (pts[ids[i+1]]-pts[ids[i]]).cross(pts[ids[i+2]]-pts[ids[i]]).length()*0.5
			report.append({"name":str(node.name),"area":area,"triangles":ids.size()/3})
	return report

func _finish(extra: Dictionary):
	print(JSON.stringify(extra))
	quit(1)
