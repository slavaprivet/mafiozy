extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node3D = load("res://scenes/castle.tscn").instantiate()
	root.add_child(game)
	var errors: Array[String] = []
	if not game._install_sword_prototype(): errors.append("install")
	var sword: Node = game.get("preview_sword_prototype")
	sword.set_process(false)
	sword.set_physics_process(false)
	var player: Node3D = game.get("_player")
	if not sword._spawn_resident_knight(player.global_position+Vector3(4,0,0)): errors.append("spawn")
	var loadout := {}
	for slot: String in ["head","torso","hands","legs","feet"]: loadout[slot]="heavy_"+slot
	if not sword.set_npc_armor31(loadout).get("ok",false): errors.append("equip")
	var visual: Node = sword._npc_armor_visual31
	var healthy: Array[Node3D] = []
	for slot: String in ["legs","feet"]:
		for overlay: Node3D in visual._skinned.get(slot,[]):
			if int(overlay.get_meta("armor_side",0)) == -1: healthy.append(overlay)
	if healthy.is_empty(): errors.append("no_healthy_leg_overlays")
	var rig: Skeleton3D = sword._npc_rig
	var point: Vector3 = rig.global_transform*rig.get_bone_global_pose(rig.find_bone("forearm_l")).origin
	var healthy_before := protected_area(sword)
	var debris_before: int = sword._npc_debris.size()
	sword._npc_take_blade_part("forearm_l",point,18.0,rig.global_basis*Vector3.LEFT,200.0,true,true)
	if not sword._npc_severed.has("forearm_l"): errors.append("no_actual_sever")
	var healthy_after := protected_area(sword)
	if absf(healthy_after-healthy_before) > maxf(0.001,healthy_before*0.001): errors.append("unrelated_surface_changed")
	if not sword._npc_mesh_cut_parts39.has("forearm_l"): errors.append("mesh_cut_fallback")
	sword._apply_npc_severed()
	if rig.get_bone_pose_scale(rig.find_bone("forearm_l")).x < 0.9: errors.append("cap_bone_collapsed")
	var visible := 0
	for overlay: Node3D in healthy:
		if overlay.visible: visible += 1
		else: errors.append("healthy_hidden:"+str(overlay.name))
	var report := {"protected_before":healthy_before,"protected_after":healthy_after,"passed":errors.is_empty(),"errors":errors,"severed":sword._npc_severed.keys(),"healthy_leg_overlays":healthy.size(),"healthy_visible":visible,"new_mesh_debris":sword._npc_debris.size()-debris_before,"scope":"Native NPC damage handler with physical sever; injected localized blade damage, not natural player swing or FPS"}
	var destination := "D:/MafioziArmorSever39/actual_baseline.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): destination=arg.trim_prefix("--report=")
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ARMOR_ACTUAL39 ",JSON.stringify(report))
	await process_frame
	quit(0 if errors.is_empty() else 1)

func protected_area(sword: Node) -> float:
	var area := 0.0
	for node: MeshInstance3D in sword._npc_skinned_meshes():
		var protected := {}
		for part in ["head","chest","thigh_l","thigh_r"]:
			protected.merge(sword._npc_limb_bind_ids(node,part))
		var arm: Dictionary = sword._npc_limb_bind_ids(node,"upperarm_l")
		var other_arm: Dictionary = sword._npc_limb_bind_ids(node,"upperarm_r")
		for key in arm: protected.erase(key)
		for key in other_arm: protected.erase(key)
		for surface in node.mesh.get_surface_count():
			var a: Array = node.mesh.surface_get_arrays(surface)
			var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var b=a[Mesh.ARRAY_BONES];var w=a[Mesh.ARRAY_WEIGHTS];var indices=a[Mesh.ARRAY_INDEX]
			if b==null or w==null:continue
			var count: int=indices.size() if indices!=null and not indices.is_empty() else v.size()
			for j in range(0,count,3):
				var ids: Array[int]=[];var keep:=true
				for k in 3:
					var index: int=indices[j+k] if indices!=null and not indices.is_empty() else j+k
					ids.append(index);var weight:=0.0
					for slot in 4:
						if protected.has(b[index*4+slot]):weight+=w[index*4+slot]
					if weight<0.99:keep=false
				if keep:area+=(v[ids[1]]-v[ids[0]]).cross(v[ids[2]]-v[ids[0]]).length()*0.5
	return area
