class_name MeshMerge
extends RefCounted
## DSH_OPT: merge static meshes by material.
##
## The set of weapons and the catapult are built from many small boxes and cylinders -
## forty-odd separate MeshInstance3D nodes on the machine alone. Each one is a draw call,
## and none of them move independently, so they can be welded into ONE surface per
## material with no visual change at all.
##
## Animated parts must NOT be passed through here: anything whose own transform changes
## (wheels, the arm, the rope, the spoon) has to stay its own node.


## Welds every MeshInstance3D under `root` that is not in `keep` into one node per
## material. Returns {"merged": int, "surfaces": int, "nodes": int}.
static func weld_children(root: Node3D, keep: Array[Node] = []) -> Dictionary:
	if root == null: return {"merged": 0, "surfaces": 0, "nodes": 0}
	# Gather the static meshes, grouped by the material they use.
	var groups: Dictionary = {}
	var consumed: Array[Node3D] = []
	for child: Node in root.get_children():
		var mesh_node := child as MeshInstance3D
		if not is_instance_valid(mesh_node) or mesh_node.mesh == null: continue
		if keep.has(mesh_node): continue
		var material: Material = mesh_node.material_override
		if material == null: continue
		var key := material.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material": material, "meshes": []}
		(groups[key].meshes as Array).append(mesh_node)
		consumed.append(mesh_node)
	if consumed.is_empty(): return {"merged": 0, "surfaces": 0, "nodes": 0}
	var welded := Node3D.new()
	welded.name = String(root.name) + "Welded"
	root.add_child(welded)
	var surface_count := 0
	for key: int in groups.keys():
		var group: Dictionary = groups[key]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		for mesh_node: Node3D in group.meshes:
			var mesh: Mesh = mesh_node.mesh
			# The mesh's own transform inside the node, times the node's transform inside
			# the root: that is where its triangles actually are.
			# EXACT: the node placement relative to the root, including its rotation and
			# its parent chain. The first version reversed the basis by hand, which is
			# only correct while the root happens to be unrotated.
			var place: Transform3D = root.global_transform.affine_inverse() * mesh_node.global_transform
			for surface: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(surface)
				if arrays.is_empty(): continue
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var vertex_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var surface_indices = arrays[Mesh.ARRAY_INDEX]
				var base := vertices.size()
				for i: int in positions.size():
					vertices.append(place * positions[i])
					if vertex_normals.size() == positions.size():
						normals.append((place.basis * vertex_normals[i]).normalized())
					else:
						normals.append(Vector3.UP)
				if surface_indices is PackedInt32Array and (surface_indices as PackedInt32Array).size() > 0:
					for index: int in (surface_indices as PackedInt32Array):
						indices.append(base + index)
				else:
					for i: int in positions.size():
						indices.append(base + i)
		if vertices.is_empty(): continue
		var arrays_out: Array = []
		arrays_out.resize(Mesh.ARRAY_MAX)
		arrays_out[Mesh.ARRAY_VERTEX] = vertices
		arrays_out[Mesh.ARRAY_NORMAL] = normals
		arrays_out[Mesh.ARRAY_INDEX] = indices
		var merged_mesh := ArrayMesh.new()
		merged_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
		merged_mesh.surface_set_material(0, group.material)
		var piece := MeshInstance3D.new()
		piece.name = "Welded" + str(surface_count)
		piece.mesh = merged_mesh
		welded.add_child(piece)
		surface_count += 1
	for mesh_node: Node3D in consumed:
		mesh_node.get_parent().remove_child(mesh_node)
		mesh_node.queue_free()
	return {"merged": consumed.size(), "surfaces": surface_count,
		"nodes": root.get_child_count()}
