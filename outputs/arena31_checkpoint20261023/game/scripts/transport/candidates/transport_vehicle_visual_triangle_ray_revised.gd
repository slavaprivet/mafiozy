extends RefCounted
## Isolated candidate. Host MUST call begin_geometry_change before every
## in-place edit/replacement and finish_geometry_change after it. Queries fail
## closed while invalidated. Array snapshots are private; no read-only alias.
const EPS:=0.0000001
var _root: Node3D
var _authority: RefCounted
var _vehicle_id: String
var _generation:=0
var _revision:=-1
var _rows: Dictionary={}
var _blocked:=true
var _pending_node: MeshInstance3D
var _pending_revision:=-1

func configure(root: Node3D,authority: RefCounted,vehicle_id: String,generation: int) -> bool:
	if _authority!=null or not is_instance_valid(root) or authority==null or vehicle_id.is_empty() or generation<1: return false
	_root=root; _authority=authority; _vehicle_id=vehicle_id; _generation=generation
	return true

func prewarm(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or _revision!=-1 or not _blocked or receipt.get("geometry_revision")!=0: return {"ok":false,"error":"prewarm_receipt"}
	var built: Dictionary={}; var count:=0; var triangles:=0
	for node in _mesh_nodes(_root):
		var row:=_build_row(node)
		if not row.ok: return row
		built[node]=row; count+=1; triangles+=row.triangles
	_rows=built; _revision=0; _blocked=false
	return {"ok":true,"meshes":count,"triangles":triangles,"revision":0}

## Host must invoke this BEFORE changing geometry, even when the same ArrayMesh
## resource is edited. This blocks every query immediately until rebuilt.
func begin_geometry_change(receipt: Dictionary,node: MeshInstance3D) -> bool:
	if not _identity(receipt) or _blocked or not _rows.has(node) or receipt.get("geometry_revision")!=_revision or receipt.get("next_revision")!=_revision+1: return false
	_blocked=true; _pending_node=node; _pending_revision=_revision+1
	_rows.erase(node)
	return true

func finish_geometry_change(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or not _blocked or not is_instance_valid(_pending_node) or receipt.get("geometry_revision")!=_pending_revision: return {"ok":false,"error":"change_receipt"}
	var row:=_build_row(_pending_node)
	if not row.ok: return row
	_rows[_pending_node]=row; _revision=_pending_revision; _pending_node=null; _pending_revision=-1; _blocked=false
	return {"ok":true,"revision":_revision,"triangles":row.triangles}

func dispose() -> void:
	_rows.clear(); _blocked=true; _root=null; _authority=null; _pending_node=null

func _identity(receipt: Dictionary) -> bool:
	return _authority!=null and is_instance_valid(_root) and receipt.get("authority")==_authority and receipt.get("vehicle_id")==_vehicle_id and receipt.get("life_generation")==_generation

func _mesh_nodes(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]; var stack: Array[Node]=[root]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		var children:=node.get_children()
		for i in range(children.size()-1,-1,-1): stack.append(children[i])
		if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null: result.append(node)
	return result

func _build_row(node: MeshInstance3D) -> Dictionary:
	if not is_instance_valid(node) or node.mesh==null: return {"ok":false,"error":"missing_mesh"}
	var mesh: Mesh=node.mesh; var surfaces: Array=[]; var triangles:=0
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return {"ok":false,"error":"primitive"}
		var arrays: Array=mesh.surface_get_arrays(surface)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return {"ok":false,"error":"positions"}
		var vertices: PackedVector3Array=(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		var indices:=PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices=(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
		var count:=indices.size() if not indices.is_empty() else vertices.size()
		if count%3!=0: return {"ok":false,"error":"triangle_count"}
		var bounds:=AABB()
		if not vertices.is_empty():
			bounds=AABB(vertices[0],Vector3.ZERO)
			for vertex: Vector3 in vertices:
				if not vertex.is_finite(): return {"ok":false,"error":"nonfinite_vertex"}
				bounds=bounds.expand(vertex)
		for index in indices:
			if index<0 or index>=vertices.size(): return {"ok":false,"error":"index_range"}
		surfaces.append({"vertices":vertices,"indices":indices,"bounds":bounds,"count":count})
		triangles+=count/3
	return {"ok":true,"mesh":mesh,"surfaces":surfaces,"triangles":triangles}

## mode is "fallback" (recursive 5 m) or "contact" (panel 1.65 m).
## root is the source car.object counterpart. marks holds source meshes whose
## raycast callback is disabled; it does not mean the entire effects subtree.
## Mesh metadata source_material_array=true attests a Three material array:
## direct `mesh.material?.transparent` is then undefined for both modes.
func cast(receipt: Dictionary,origin: Vector3,direction: Vector3,far_m: float,mode: String,marks: Array=[]) -> Dictionary:
	if not _identity(receipt) or _blocked or receipt.get("geometry_revision")!=_revision: return {"ok":false,"error":"revision_or_authority"}
	if not origin.is_finite() or not direction.is_finite() or absf(direction.length()-1.0)>0.00001 or not is_finite(far_m) or far_m<=0.0 or mode not in ["fallback","contact"]:
		return {"ok":false,"error":"ray_contract"}
	if (mode=="fallback" and absf(far_m-5.0)>EPS) or (mode=="contact" and absf(far_m-1.65)>EPS):
		return {"ok":false,"error":"source_far"}
	var best: Dictionary={}; var tested:=0; var triangles:=0
	var nodes:=_mesh_nodes(_root)
	if nodes.size()!=_rows.size(): return {"ok":false,"error":"unannounced_mesh_inventory_change"}
	for instance: MeshInstance3D in nodes:
		if not _rows.has(instance) or instance.mesh!=_rows[instance].mesh: return {"ok":false,"error":"unannounced_geometry_change"}
		if marks.has(instance) or instance.get_meta("source_raycast_disabled",false): continue
		if mode=="contact":
			if not _contact_chain(instance,_root,marks): continue
		elif not instance.visible: continue
		var mesh: Mesh=instance.mesh
		var row: Dictionary=_rows[instance]
		if mesh.get_surface_count()!=row.surfaces.size(): return {"ok":false,"error":"unannounced_surface_change"}
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
		for surface in row.surfaces.size():
			var material: Material=instance.get_active_material(surface)
			if not material is BaseMaterial3D: return {"ok":false,"error":"material"}
			var base:=material as BaseMaterial3D
			# Both source filters read object.material?.transparent, not the
			# triangle's selected material. Arrays have no transparent property.
			if not material_array and base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: continue
			var surface_row: Dictionary=row.surfaces[surface]
			var vertices: PackedVector3Array=surface_row.vertices
			if vertices.is_empty(): continue
			var bounds: AABB=surface_row.bounds
			if not bounds.grow(0.00001).intersects_segment(local_origin,local_origin+local_direction*far_m): continue
			var indices: PackedInt32Array=surface_row.indices
			var count: int=surface_row.count
			tested+=1
			for offset in range(0,count,3):
				var ia:=indices[offset] if not indices.is_empty() else offset
				var ib:=indices[offset+1] if not indices.is_empty() else offset+1
				var ic:=indices[offset+2] if not indices.is_empty() else offset+2
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
