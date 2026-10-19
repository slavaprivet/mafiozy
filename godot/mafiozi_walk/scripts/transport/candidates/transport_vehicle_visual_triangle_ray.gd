extends RefCounted
## Isolated CPU candidate: current ArrayMesh triangles, never a physics hull.
## Coordinates remain the source world frame. A fresh query reads fresh arrays;
## no cached triangles can survive an in-place dent or mesh replacement.
const EPS:=0.0000001

## mode is "fallback" (recursive 5 m) or "contact" (panel 1.65 m).
## root is the source car.object counterpart. marks holds source meshes whose
## raycast callback is disabled; it does not mean the entire effects subtree.
## Mesh metadata source_material_array=true attests a Three material array:
## direct `mesh.material?.transparent` is then undefined for both modes.
func cast(root: Node3D,origin: Vector3,direction: Vector3,far_m: float,mode: String,marks: Array=[]) -> Dictionary:
	if not is_instance_valid(root) or not origin.is_finite() or not direction.is_finite() or absf(direction.length()-1.0)>0.00001 or not is_finite(far_m) or far_m<=0.0 or mode not in ["fallback","contact"]:
		return {"ok":false,"error":"ray_contract"}
	if (mode=="fallback" and absf(far_m-5.0)>EPS) or (mode=="contact" and absf(far_m-1.65)>EPS):
		return {"ok":false,"error":"source_far"}
	var best: Dictionary={}; var tested:=0; var triangles:=0
	var stack: Array[Node]=[root]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		# Three intersectObject(root,true) traverses children even when parent hidden.
		var children:=node.get_children()
		for i in range(children.size()-1,-1,-1): stack.append(children[i])
		if not node is MeshInstance3D: continue
		var instance:=node as MeshInstance3D
		if instance.mesh==null: continue
		if marks.has(instance) or instance.get_meta("source_raycast_disabled",false): continue
		if mode=="contact":
			if not _contact_chain(instance,root,marks): continue
		elif not instance.visible: continue
		var mesh: Mesh=instance.mesh
		var material_array: Variant=instance.get_meta("source_material_array",false)
		if not material_array is bool: return {"ok":false,"error":"source_material_shape"}
		if mesh.get_surface_count()>1 and not instance.has_meta("source_material_array"):
			return {"ok":false,"error":"source_material_shape"}
		var inverse:=instance.global_transform.affine_inverse()
		if not inverse.is_finite(): return {"ok":false,"error":"mesh_transform"}
		var local_origin: Vector3=inverse*origin
		var local_direction: Vector3=inverse.basis*direction
		# No mesh AABB shortcut: a structural/deformation edit may move current
		# triangles before the native bounding box is rebuilt.
		for surface in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return {"ok":false,"error":"primitive"}
			var material: Material=instance.get_active_material(surface)
			if not material is BaseMaterial3D: return {"ok":false,"error":"material"}
			var base:=material as BaseMaterial3D
			# Both source filters read object.material?.transparent, not the
			# triangle's selected material. Arrays have no transparent property.
			if not material_array and base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: continue
			var arrays: Array=mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			if vertices.is_empty(): continue
			# Recompute bounds from the same current vertex array used below. This
			# safely skips distant surfaces without trusting a stale mesh AABB.
			var bounds:=AABB(vertices[0],Vector3.ZERO)
			for vertex: Vector3 in vertices:
				if not vertex.is_finite(): return {"ok":false,"error":"nonfinite_vertex"}
				bounds=bounds.expand(vertex)
			if not bounds.grow(0.00001).intersects_segment(local_origin,local_origin+local_direction*far_m): continue
			var indices:=PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices=arrays[Mesh.ARRAY_INDEX]
			var count:=indices.size() if not indices.is_empty() else vertices.size()
			if count%3!=0: return {"ok":false,"error":"triangle_count"}
			tested+=1
			for offset in range(0,count,3):
				var ia:=indices[offset] if not indices.is_empty() else offset
				var ib:=indices[offset+1] if not indices.is_empty() else offset+1
				var ic:=indices[offset+2] if not indices.is_empty() else offset+2
				if mini(ia,mini(ib,ic))<0 or maxi(ia,maxi(ib,ic))>=vertices.size(): return {"ok":false,"error":"index_range"}
				triangles+=1
				var a: Vector3=vertices[ia]; var b: Vector3=vertices[ib]; var c: Vector3=vertices[ic]
				var t:=_triangle(local_origin,local_direction,a,b,c,base.cull_mode)
				if t<0.0 or t>far_m or (not best.is_empty() and t>=best.distance_m): continue
				var local_normal: Vector3=(b-a).cross(c-a).normalized()
				var world_normal: Vector3=(inverse.basis.transposed()*local_normal).normalized()
				best={"point_source":origin+direction*t,"normal_source":world_normal,"distance_m":t,"object":instance,"surface":surface,"triangle":offset/3}
	return {"ok":true,"hit":best,"tested_surfaces":tested,"tested_triangles":triangles}

static func _contact_chain(mesh: MeshInstance3D,root: Node3D,marks: Array) -> bool:
	var node: Node=mesh
	while node!=null:
		if marks.has(node): return false
		if node is Node3D and not (node as Node3D).visible: return false
		if node.get_meta("source_name","")=="Vehicle_damage_effects": return false
		if node.has_meta("source_metadata") and (node.get_meta("source_metadata") as Dictionary).has("vehicleWheelId"): return false
		if node==root: return true
		node=node.get_parent()
	return false

static func _triangle(o: Vector3,d: Vector3,a: Vector3,b: Vector3,c: Vector3,cull: int) -> float:
	var edge1:=b-a; var edge2:=c-a
	var p:=d.cross(edge2); var det:=edge1.dot(p)
	if cull==BaseMaterial3D.CULL_BACK and det<=EPS: return -1.0
	if cull==BaseMaterial3D.CULL_FRONT and det>=-EPS: return -1.0
	if absf(det)<=EPS: return -1.0
	var inv:=1.0/det; var tvec:=o-a; var u:=tvec.dot(p)*inv
	if u<0.0 or u>1.0: return -1.0
	var q:=tvec.cross(edge1); var v:=d.dot(q)*inv
	if v<0.0 or u+v>1.0: return -1.0
	var t:=edge2.dot(q)*inv
	return t if t>=0.0 else -1.0
