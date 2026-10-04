extends SceneTree
func _initialize() -> void:
	var dir := DirAccess.open("res://assets")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".scn"): files.append(f)
	files.sort()
	var sigs := {}
	for f in files:
		var packed: Variant = load("res://assets/" + f)
		if packed == null: continue
		var inst: Node = packed.instantiate()
		var rig: Skeleton3D = _find_rig(inst)
		if rig == null: inst.free(); continue
		var sig := ""
		var surf_us := 0
		for node: Node in rig.get_parent().find_children("*","MeshInstance3D",true,false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null or mesh.skin == null: continue
			for s in mesh.mesh.get_surface_count():
				var t0: int = Time.get_ticks_usec()
				var arrays: Array = mesh.mesh.surface_get_arrays(s)
				surf_us += Time.get_ticks_usec() - t0
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var h: int = verts.size() * 31 + bones.size()
				for vi in range(0, verts.size(), 37):
					h = (h * 31 + int(verts[vi].x * 1000.0)) & 0x7fffffff
				sig += str(h) + ":"
		var key := sig
		sigs[key] = int(sigs.get(key, 0)) + 1
		print("DSH_SIG ", f.substr(0,8), " surf_get_arrays_us=", surf_us, " meshes_sig=", key.substr(0, 60))
		inst.free()
	print("DSH_SIG distinct_geometries=", sigs.size(), " of models=", files.size())
	for k in sigs: print("DSH_SIG count=", sigs[k], " sig=", k.substr(0,60))
	quit()
func _find_rig(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children():
		var r := _find_rig(c)
		if r != null: return r
	return null
