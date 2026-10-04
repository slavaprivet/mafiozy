extends SceneTree
const Orig = preload("res://scripts/npc_head_zone_orig.gd")
const New = preload("res://scripts/npc_head_zone_new.gd")
func _initialize() -> void:
	var dir := DirAccess.open("res://assets")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".scn"): files.append(f)
	files.sort()
	print("DSH_BENCH models=", files.size())
	var orig_total: int = 0; var new_total: int = 0; var mismatch: int = 0
	for f in files:
		var packed: Variant = load("res://assets/" + f)
		if packed == null: print("DSH_BENCH load_fail ", f); continue
		var inst: Node = packed.instantiate()
		var rig: Skeleton3D = null
		rig = _find_rig(inst)
		if rig == null: print("DSH_BENCH no_rig ", f); inst.free(); continue
		var o: RefCounted = Orig.new()
		var t0: int = Time.get_ticks_usec(); var ok_o: bool = o.configure(rig); var us_o: int = Time.get_ticks_usec() - t0
		var n: RefCounted = New.new()
		var t1: int = Time.get_ticks_usec(); var ok_n: bool = n.configure(rig); var us_n: int = Time.get_ticks_usec() - t1
		orig_total += us_o; new_total += us_n
		var same: bool = (ok_o == ok_n) and (o._head_min == n._head_min) and (o._head_max == n._head_max) and (o._head_triangles.size() == n._head_triangles.size()) and (o._surfaces.size() == n._surfaces.size())
		var leaf_same: bool = true
		if o._surfaces.size() == n._surfaces.size():
			for si in o._surfaces.size():
				var a: Dictionary = o._surfaces[si]; var b: Dictionary = n._surfaces[si]
				if a.head_indices != b.head_indices or a.dynamic_head_indices != b.dynamic_head_indices: leaf_same = false; break
				if a.clusters.size() != b.clusters.size(): leaf_same = false; break
				for ci in a.clusters.size():
					if a.clusters[ci].indices != b.clusters[ci].indices: leaf_same = false; break
		if not same or not leaf_same: mismatch += 1
		print("DSH_BENCH ", f.substr(0,8), " orig_us=", us_o, " new_us=", us_n, " ok=", ok_o, "/", ok_n, " parity=", "OK" if (same and leaf_same) else "MISMATCH")
		inst.free()
	print("DSH_BENCH TOTAL orig_us=", orig_total, " new_us=", new_total, " speedup=", "%.2f" % (float(orig_total) / max(1.0, float(new_total))), " mismatches=", mismatch)
	quit()
func _find_rig(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children():
		var r := _find_rig(c)
		if r != null: return r
	return null
