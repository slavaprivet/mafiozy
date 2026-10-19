extends SceneTree
## DSH temporary: parity + timing for the bullet-marks renderer configure().
const Orig = preload("res://scripts/npc_marks_orig.gd")
const New = preload("res://scripts/npc_marks_new.gd")

func _initialize() -> void:
	var dir := DirAccess.open("res://assets")
	if dir == null:
		print("DSH_MARKS no_bench_dir")
		quit()
		return
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".scn"):
			files.append(f)
	files.sort()
	var orig_total: int = 0
	var new_total: int = 0
	var mismatch: int = 0
	for f in files:
		var packed: Variant = load("res://assets/" + f)
		if packed == null:
			continue
		var inst: Node = packed.instantiate()
		var actor := Node3D.new()
		actor.name = "actor"
		root.add_child(actor)
		actor.add_child(inst)
		var rig: Skeleton3D = _find_rig(inst)
		if rig == null:
			actor.free()
			continue
		var o: RefCounted = Orig.new()
		var t0: int = Time.get_ticks_usec()
		var ok_o: bool = o.configure(actor, rig, 1.0)
		var us_o: int = Time.get_ticks_usec() - t0
		var n: RefCounted = New.new()
		var t1: int = Time.get_ticks_usec()
		var ok_n: bool = n.configure(actor, rig, 1.0)
		var us_n: int = Time.get_ticks_usec() - t1
		orig_total += us_o
		new_total += us_n
		var parity: bool = (ok_o == ok_n) and (o._surfaces.size() == n._surfaces.size())
		if parity:
			for si in o._surfaces.size():
				var a: Dictionary = o._surfaces[si]
				var b: Dictionary = n._surfaces[si]
				if a.clusters.size() != b.clusters.size():
					parity = false
					break
				for ci in a.clusters.size():
					if a.clusters[ci].indices != b.clusters[ci].indices:
						parity = false
						break
		if not parity:
			mismatch += 1
		print("DSH_MARKS ", f.substr(0, 8), " orig_us=", us_o, " new_us=", us_n, " ok=", ok_o, "/", ok_n, " parity=", "OK" if parity else "MISMATCH")
		o.dispose()
		n.dispose()
		actor.free()
	print("DSH_MARKS TOTAL orig_us=", orig_total, " new_us=", new_total, " speedup=", "%.2f" % (float(orig_total) / max(1.0, float(new_total))), " mismatches=", mismatch)
	quit()

func _find_rig(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var r := _find_rig(c)
		if r != null:
			return r
	return null

