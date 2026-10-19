extends "res://scripts/npc_visual/npc_bullet_marks.gd"
## Original geometry cache only: no added render geometry, no health or pose authority.
func configure_geometry(actor: Node3D, rig: Skeleton3D, unit: float) -> bool:
	if _root != null or not is_instance_valid(actor) or not is_instance_valid(rig) or not actor.is_ancestor_of(rig) or not is_finite(unit) or unit <= 0: return false
	var prepare_start:=Time.get_ticks_usec()
	var prepare_memory:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_root = actor; _rig = rig; _unit = unit
	for node: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh is ArrayMesh or node.get_meta("npc_bullet_mark", false): continue
		var bindings: Array[int] = []
		if node.skin != null:
			for bind in node.skin.get_bind_count():
				var name: String = str(node.skin.get_bind_name(bind))
				var bone: int = rig.find_bone(name) if not name.is_empty() else node.skin.get_bind_bone(bind)
				if bone < 0 or bone >= rig.get_bone_count(): dispose(); return false
				bindings.append(bone)
		for s in node.mesh.get_surface_count():
			if node.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: continue
			var a: Array = node.mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_VERTEX] == null: continue
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in vertices.size(): indices.append(i)
			if indices.size() % 3 != 0: dispose(); return false
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES] if a[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS] if a[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if node.skin != null and (bones.size() != vertices.size() * 4 or weights.size() != bones.size()): dispose(); return false
			var material: Material = node.get_active_material(s)
			var entry:Dictionary={"node":weakref(node), "original":node.mesh, "skin":node.skin, "surface":s, "vertices":vertices, "indices":indices, "bones":bones, "weights":weights, "bindings":bindings, "skin_material":material != null and "SKIN" in material.resource_name.to_upper()}
			entry.clusters=_clusters(entry)
			_surfaces.append(entry)
	if _surfaces.is_empty(): dispose(); return false
	return true

func _valid() -> bool:
	if not is_instance_valid(_root) or not is_instance_valid(_rig) or _root.is_queued_for_deletion():return false
	for surface: Dictionary in _surfaces:
		var mesh: MeshInstance3D=surface.node.get_ref()
		if not is_instance_valid(mesh) or mesh.is_queued_for_deletion() or not _root.is_ancestor_of(mesh) or mesh.mesh!=surface.original or mesh.skin!=surface.skin:return false
	return true
