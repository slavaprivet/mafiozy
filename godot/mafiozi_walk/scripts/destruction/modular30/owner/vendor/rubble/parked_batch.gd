extends RefCounted
## Bounded resource preparation only. Caller swaps an entire region atomically.
static func prepare(records: Array,origin: Vector3,limits: Dictionary) -> Dictionary:
	if records.size()>limits.region_records: return {"ok":false,"reason":"region_record_budget","required":records.size(),"limit":limits.region_records}
	var groups: Dictionary={}
	var faces:=PackedVector3Array()
	var vertices:=0
	var margin:=.002
	for record: Dictionary in records:
		var descriptor: Dictionary=record.descriptor
		var frame: Transform3D=record.frame
		for skin: Dictionary in descriptor.surfaces:
			var arrays: Array=skin.arrays
			var source: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			vertices+=source.size()
			if vertices>limits.region_vertices: return {"ok":false,"reason":"region_vertex_budget","required":vertices,"limit":limits.region_vertices}
			var material: Material=skin.material
			var material_id: int=material.get_instance_id() if material!=null else 0
			if not groups.has(material_id):
				if groups.size()>=limits.region_materials: return {"ok":false,"reason":"region_material_budget","required":groups.size()+1,"limit":limits.region_materials}
				groups[material_id]={"material":material,"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array(),"uv2":PackedVector2Array(),"c":PackedColorArray(),"t":PackedFloat32Array()}
			var group: Dictionary=groups[material_id]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
			for i: int in source.size():
				group.v.append(frame*source[i]-origin)
				group.n.append((frame.basis*normals[i]).normalized())
				group.uv.append(uv[i]); group.uv2.append(uv2[i]); group.c.append(colors[i])
				var tangent: Vector3=(frame.basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])).normalized()
				group.t.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,tangents[i*4+3]]))
				faces.append(frame*(source[i]*descriptor.collision_shape_scale)-origin)
		margin=minf(margin,descriptor.collision_margin_m)
	if records.is_empty(): return {"ok":true,"empty":true,"mesh":null,"shape":null,"vertices":0,"surfaces":0}
	var mesh:=ArrayMesh.new()
	for group: Dictionary in groups.values():
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=group.v; arrays[Mesh.ARRAY_NORMAL]=group.n
		arrays[Mesh.ARRAY_TEX_UV]=group.uv; arrays[Mesh.ARRAY_TEX_UV2]=group.uv2
		arrays[Mesh.ARRAY_COLOR]=group.c; arrays[Mesh.ARRAY_TANGENT]=group.t
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,group.material)
	var shape:=ConcavePolygonShape3D.new()
	shape.backface_collision=true; shape.margin=margin; shape.set_faces(faces)
	return {"ok":true,"empty":false,"mesh":mesh,"shape":shape,"vertices":vertices,"surfaces":groups.size()}
