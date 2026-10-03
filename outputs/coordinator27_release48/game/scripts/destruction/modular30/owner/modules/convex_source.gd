extends RefCounted
## Exact convex SOURCE admission, not solid-building physical admission.
## The source bound encloses air. hollow_shell.gd creates explicit wall material.
const Slab = preload("geometry.gd")
const Strength = preload("../material_strength.gd")
const EPS := .00001
const MAX_SOURCE_TRIANGLES := 128
const MAX_SOURCE_POINTS := 64
const MAX_SOURCE_FACES := 128
const MAX_SOURCE_SURFACES := 64
const MAX_COMPONENT_VOLUME := 1000000000.0
const MAX_COMPONENT_THICKNESS := 1024.0
const MAX_COMPONENT_LENGTH := 1024.0

static func _parse(source: Dictionary, frame: Transform3D, profile: Dictionary) -> Dictionary:
	if not source.get("mesh") is ArrayMesh: return _no("original_array_mesh_required")
	if source.get("breakable_glass",false)==true: return _no("glass_has_separate_owner")
	if str(source.get("source_id","")).is_empty() or str(source.get("source_part_id","")).is_empty(): return _no("source_identity")
	if profile.get("geometry_mode","")!="hollow_convex_shell": return _no("explicit_component_mode_required")
	var family:=str(profile.get("material_class","UNKNOWN")).to_lower()
	if not Strength.DEFAULTS.has(family): return _no("explicit_physical_material_required")
	if str(profile.get("profile_id","")).is_empty() or not profile.get("reveal_material") is Material: return _no("explicit_profile_and_reveal_required")
	if not frame.is_finite() or frame.basis.determinant()<=.000000001: return _no("positive_finite_frame_required")
	# Orthogonal authored placement only; rotation/nonuniform scale is supported,
	# but shearing a beveled component into another physical shape is not inferred.
	var axes: Array[Vector3]=[frame.basis.x.normalized(),frame.basis.y.normalized(),frame.basis.z.normalized()]
	if absf(axes[0].dot(axes[1]))>.00001 or absf(axes[0].dot(axes[2]))>.00001 or absf(axes[1].dot(axes[2]))>.00001: return _no("sheared_component_frame")
	var mesh: ArrayMesh=source.mesh
	if mesh.get_surface_count()<1 or mesh.get_surface_count()>MAX_SOURCE_SURFACES or mesh.get_blend_shape_count()!=0: return _no("component_surface_budget")
	var box:=mesh.get_aabb()
	if not box.position.is_finite() or not box.size.is_finite() or box.size.x<=EPS or box.size.y<=EPS or box.size.z<=EPS: return _no("positive_source_bounds")
	var physical_size:=box.size*Vector3(frame.basis.x.length(),frame.basis.y.length(),frame.basis.z.length())
	var thin: int=physical_size.min_axis_index()
	if physical_size[physical_size.max_axis_index()]>MAX_COMPONENT_LENGTH or box.get_volume()*frame.basis.determinant()>MAX_COMPONENT_VOLUME: return _no("source_shell_geometry_limits")
	var chunk: Variant=profile.get("chunk_size_m",.65)
	if not Slab._number(chunk) or float(chunk)<.1 or float(chunk)>1.0: return _no("chunk_size_limits")
	var effective_profile: Dictionary=profile.duplicate(true)
	effective_profile.material_class=family
	var snapshots: Array=[]; var materials: Array[Material]=[]
	var points: Array[Vector3]=[]; var triangles: Array[Dictionary]=[]
	var edges: Dictionary={}
	var overrides: Variant=source.get("materials",[])
	if not overrides is Array or (not overrides.is_empty() and overrides.size()!=mesh.get_surface_count()): return _no("effective_surface_materials")
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _no("triangle_source_required")
		var material: Material=overrides[surface] if not overrides.is_empty() else mesh.surface_get_material(surface)
		if material==null: return _no("explicit_source_material_required")
		if Strength.classify(str(source.get("label",mesh.resource_name)),material,family,mesh.get_surface_count()>1)=="glass" or float(material.get_meta("transmission",0.0))>0.0: return _no("glass_has_separate_owner")
		materials.append(material)
		var arrays: Array=mesh.surface_get_arrays(surface)
		for slot: int in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			if arrays[slot]!=null and not arrays[slot].is_empty(): return _no("unsupported_source_attributes")
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL]==null or arrays[Mesh.ARRAY_TEX_UV]==null or arrays[Mesh.ARRAY_NORMAL].size()!=vertices.size() or arrays[Mesh.ARRAY_TEX_UV].size()!=vertices.size(): return _no("authored_normals_uv_required")
		for slot: int in [Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV2]:
			if arrays[slot]!=null and not arrays[slot].is_empty() and arrays[slot].size()!=vertices.size(): return _no("source_attribute_count")
		if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty() and arrays[Mesh.ARRAY_TANGENT].size()!=vertices.size()*4: return _no("source_tangent_count")
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count: int=indices.size() if not indices.is_empty() else vertices.size()
		if count%3!=0 or triangles.size()+count/3>MAX_SOURCE_TRIANGLES: return _no("source_triangle_budget")
		for offset: int in range(0,count,3):
			var attributes: Array=[]; var ids: Array[int]=[]
			for corner: int in 3:
				var index: int=indices[offset+corner] if not indices.is_empty() else offset+corner
				if index<0 or index>=vertices.size(): return _no("source_index")
				var vertex: Array=Slab._vertex(arrays,index)
				if not _finite_vertex(vertex): return _no("finite_source_attributes")
				attributes.append(vertex)
				var id:=_weld_id(points,vertex[0],frame)
				if points.size()>MAX_SOURCE_POINTS: return _no("source_point_budget")
				ids.append(id)
			var a: Vector3=attributes[0][0]; var b: Vector3=attributes[1][0]; var c: Vector3=attributes[2][0]
			var outward: Vector3=-(b-a).cross(c-a)
			if outward.length_squared()<.00000000000001: return _no("degenerate_source_triangle")
			outward=outward.normalized()
			# Authored shading normals are attributes, not the geometric plane.
			# Native bevel corners deliberately shade both noncoplanar triangles
			# as one rounded quad. Preserve their original interpolation instead
			# of flattening geometry or substituting the shading normal as a plane.
			for corner: int in 3:
				var from: int=ids[corner]; var to: int=ids[(corner+1)%3]
				if from==to: return _no("collapsed_source_edge")
				var key:=str(mini(from,to))+":"+str(maxi(from,to))
				if not edges.has(key): edges[key]={"count":0,"balance":0}
				edges[key].count+=1; edges[key].balance+=1 if from<to else -1
			triangles.append({"vertices":attributes,"ids":ids,"normal":outward,"surface":surface,"triangle_index":offset/3})
		snapshots.append(arrays.duplicate(true))
	for edge: Dictionary in edges.values():
		if edge.count!=2 or edge.balance!=0: return _no("source_not_closed_oriented_manifold")
	var source_faces: Array[Dictionary]=[]
	var normal_matrix:=frame.basis.inverse().transposed()
	var thickness:=INF
	for triangle: Dictionary in triangles:
		var anchor: Vector3=triangle.vertices[0][0]
		var world_normal: Vector3=(normal_matrix*triangle.normal).normalized()
		var separation:=0.0
		for point: Vector3 in points:
			var plane_distance:=world_normal.dot(frame.basis*(point-anchor))
			if plane_distance>EPS: return _no("source_not_convex")
			separation=maxf(separation,-plane_distance)
		thickness=minf(thickness,separation)
		var group_index:=-1
		for i: int in source_faces.size():
			var group: Dictionary=source_faces[i]
			if triangle.normal.dot(group.normal)>.999999 and absf(world_normal.dot(frame.basis*(anchor-group.anchor)))<EPS:
				if group.surface!=triangle.surface: return _no("coplanar_material_discontinuity")
				group_index=i; break
		if group_index<0:
			if source_faces.size()>=MAX_SOURCE_FACES: return _no("source_face_budget")
			source_faces.append({"normal":triangle.normal,"anchor":anchor,"surface":triangle.surface,"triangles":[],"ids":[]})
			group_index=source_faces.size()-1
		var group: Dictionary=source_faces[group_index]
		group.triangles.append(triangle)
		for id: int in triangle.ids:
			if not group.ids.has(id): group.ids.append(id)
	if not is_finite(thickness) or thickness<.02 or thickness>MAX_COMPONENT_THICKNESS: return _no("not_a_bounded_solid_component")
	
	effective_profile.thickness_m=thickness
	# Only merge source triangles when all authored channels have the same
	# affine field. Keep native seams as their original triangles, not resampled
	# quads. This stays within the already admitted source-triangle budget.
	var attribute_faces: Array[Dictionary]=[]
	for group: Dictionary in source_faces:
		var affine:=true
		for triangle: Dictionary in group.triangles:
			for vertex: Array in triangle.vertices:
				if not Slab._attributes_match(vertex,Slab._sample(group,vertex[0])): affine=false
		if affine: attribute_faces.append(group)
		else:
			for triangle: Dictionary in group.triangles:
				attribute_faces.append({"normal":triangle.normal,"anchor":triangle.vertices[0][0],"surface":triangle.surface,"triangles":[triangle],"ids":triangle.ids.duplicate()})
	source_faces=attribute_faces
	var faces: Array[Dictionary]=[]
	for index: int in source_faces.size():
		var group: Dictionary=source_faces[index]
		if group.ids.size()<3 or group.ids.size()>4 or group.triangles.size()!=group.ids.size()-2: return _no("convex_face_must_be_authored_triangle_or_quad")
		var polygon: Array[Vector3]=[]; var centre:=Vector3.ZERO
		for id: int in group.ids: polygon.append(points[id]); centre+=points[id]
		centre/=polygon.size()
		var u: Vector3=(polygon[0]-centre).normalized(); var v: Vector3=group.normal.cross(u)
		polygon.sort_custom(func(a: Vector3,b: Vector3) -> bool: return atan2((a-centre).dot(v),(a-centre).dot(u))<atan2((b-centre).dot(v),(b-centre).dot(u)))
		var authored_area:=0.0; var polygon_area:=0.0
		for triangle: Dictionary in group.triangles:
			var a: Vector3=triangle.vertices[0][0]; var b: Vector3=triangle.vertices[1][0]; var c: Vector3=triangle.vertices[2][0]
			authored_area+=(frame.basis*(b-a)).cross(frame.basis*(c-a)).length()*.5
			for vertex: Array in triangle.vertices:
				if not Slab._attributes_match(vertex,Slab._sample(group,vertex[0])): return _no("non_affine_authored_face_attributes")
		for i: int in range(1,polygon.size()-1): polygon_area+=(frame.basis*(polygon[i]-polygon[0])).cross(frame.basis*(polygon[i+1]-polygon[0])).length()*.5
		if absf(authored_area-polygon_area)>maxf(.000001,authored_area*.0001): return _no("incomplete_convex_face")
		faces.append({"polygon":polygon,"normal":group.normal,"source_face":index,"surface":group.surface,"grid_axis":-1,"grid_plane":-1})
	var volume: float=Slab._volume(faces,frame)
	if volume<=.000001 or volume>MAX_COMPONENT_VOLUME: return _no("positive_convex_outer_volume_required")
	var world_bounds:=AABB(frame*points[0],Vector3.ZERO)
	for point: Vector3 in points: world_bounds=world_bounds.expand(frame*point)
	var binding: Dictionary={"mesh":mesh,"arrays":snapshots,"materials":materials,"frame":frame,"source_id":str(source.source_id),"source_part_id":str(source.source_part_id),"profile":effective_profile.duplicate(true)}
	return {"ok":true,"mesh":mesh,"box":box,"frame":frame,"thin_axis":thin,"thickness":thickness,"original_volume":volume,"triangle_count":triangles.size(),"points":points,"faces":faces,"source_faces":source_faces,"materials":materials,"world_bounds":world_bounds,"chunk_size":float(chunk),"reveal_material":profile.reveal_material,"source":{"source_id":str(source.source_id),"source_part_id":str(source.source_part_id)},"profile":effective_profile,"binding":binding}

static func _weld_id(points: Array[Vector3], point: Vector3, frame: Transform3D) -> int:
	for i: int in points.size():
		if (frame.basis*(points[i]-point)).length_squared()<=EPS*EPS: return i
	points.append(point); return points.size()-1

static func _finite_vertex(vertex: Array) -> bool:
	return vertex[0].is_finite() and vertex[1].is_finite() and vertex[1].length_squared()>.99 and vertex[2].is_finite() and is_finite(vertex[3].r) and is_finite(vertex[3].g) and is_finite(vertex[3].b) and is_finite(vertex[3].a) and vertex[4].is_finite() and vertex[5].is_finite()

static func _no(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"scene_mutated":false}
