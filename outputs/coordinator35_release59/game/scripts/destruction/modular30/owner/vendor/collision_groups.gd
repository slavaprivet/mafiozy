extends RefCounted
## Bounded spatial grouping of unchanged authored collision triangles.
## Retains an exact triangle -> source part/surface/face map for glass contacts.
const MAX_PARTS=16
const MAX_GROUP_TRIANGLES=2048
const MAX_SOURCE_TRIANGLES=8192
const CELL=4.0
const EPS=.00001

static func source_faces(mesh:Mesh,frame:Transform3D) -> Dictionary:
	if mesh==null or not frame.is_finite() or frame.basis.determinant()<=.00001: return {"ok":false,"reason":"source"}
	var faces=PackedVector3Array(); var surfaces=PackedInt32Array(); var local_faces=PackedInt32Array()
	var input_count=0
	for surface:int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return {"ok":false,"reason":"primitive"}
		var arrays:Array=mesh.surface_get_arrays(surface)
		var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count:int=indices.size() if not indices.is_empty() else points.size()
		if count%3!=0: return {"ok":false,"reason":"index_count"}
		input_count+=count/3
		if input_count>MAX_SOURCE_TRIANGLES: return {"ok":false,"reason":"source_triangle_budget"}
		for start:int in range(0,count,3):
			var triangle:Array[Vector3]=[]
			for j:int in 3:
				var index:int=indices[start+j] if not indices.is_empty() else start+j
				if index<0 or index>=points.size() or not points[index].is_finite(): return {"ok":false,"reason":"vertex"}
				triangle.append(frame*points[index])
			if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()<.0000000001: continue
			faces.append_array(PackedVector3Array(triangle)); surfaces.append(surface); local_faces.append(start/3)
	return {"ok":true,"faces":faces,"surfaces":surfaces,"local_faces":local_faces}

static func prepare(parts:Array) -> Dictionary:
	var groups:Array=[]; var buckets:Dictionary={}
	for part:Dictionary in parts:
		var count:int=part.geometry.faces.size()/3
		var cell=Vector3i((part.bounds.get_center()/CELL).floor())
		var key=str(cell)
		var chosen:Dictionary={}
		# Large shell meshes remain independent; tiny trims share local groups.
		if count<=MAX_GROUP_TRIANGLES and part.bounds.size.max_axis_index()>=0 and part.bounds.size[part.bounds.size.max_axis_index()]<=CELL*2:
			for candidate:Dictionary in buckets.get(key,[]):
				if candidate.parts.size()<MAX_PARTS and candidate.triangles+count<=MAX_GROUP_TRIANGLES:
					chosen=candidate; break
		if chosen.is_empty():
			chosen={"parts":[],"triangles":0,"body":null,"collision":null,"generation":0}
			groups.append(chosen)
			if not buckets.has(key): buckets[key]=[]
			buckets[key].append(chosen)
		chosen.parts.append(part); chosen.triangles+=count
	for group:Dictionary in groups:
		var prepared:Dictionary=rebuild(group)
		if not prepared.ok: return prepared
		group.merge(prepared,true)
	return {"ok":true,"groups":groups}

static func rebuild(group:Dictionary,replacement_node:MeshInstance3D=null,replacement_mesh:Mesh=null,originals:bool=false) -> Dictionary:
	var faces=PackedVector3Array(); var owners=PackedInt32Array(); var surfaces=PackedInt32Array(); var source_indices=PackedInt32Array()
	for index:int in group.parts.size():
		var part:Dictionary=group.parts[index]
		if not is_instance_valid(part.node) or not part.node.global_transform.is_equal_approx(part.frame): return {"ok":false,"reason":"changed_source_transform"}
		var mesh:Mesh=part.original if originals else part.node.mesh
		if part.node==replacement_node: mesh=replacement_mesh
		var geometry:Dictionary=part.geometry if mesh==part.original else source_faces(mesh,part.frame)
		if not geometry.ok: return geometry
		var count:int=geometry.faces.size()/3
		faces.append_array(geometry.faces); surfaces.append_array(geometry.surfaces); source_indices.append_array(geometry.local_faces)
		for i:int in count: owners.append(index)
	# Original large shell may exceed the ordinary merge cap, but no source can
	# exceed the absolute cap. Regrowth caused by repeated cuts is bounded too.
	if faces.size()/3>MAX_SOURCE_TRIANGLES: return {"ok":false,"reason":"group_triangle_budget"}
	var shape=ConcavePolygonShape3D.new(); shape.backface_collision=true
	shape.set_faces(faces)
	return {"ok":true,"shape":shape,"faces":faces,"owners":owners,"surfaces":surfaces,"source_indices":source_indices,"triangles":faces.size()/3}

static func commit(group:Dictionary,prepared:Dictionary) -> void:
	group.merge(prepared,true); group.generation+=1
	if is_instance_valid(group.collision): group.collision.shape=group.shape

static func resolve(group:Dictionary,point:Vector3,direction:Vector3) -> Dictionary:
	if not point.is_finite() or not direction.is_finite() or direction.length_squared()<.000001: return {"ok":false,"reason":"contact"}
	var ray:Vector3=direction.normalized(); var begin:Vector3=point-ray*.05; var end:Vector3=point+ray*.05
	var best:Dictionary={}; var nearest=INF; var ambiguous=false
	var faces:PackedVector3Array=group.faces
	for face:int in group.owners.size():
		var offset:int=face*3
		var hit:Variant=Geometry3D.segment_intersects_triangle(begin,end,faces[offset],faces[offset+1],faces[offset+2])
		if hit==null: continue
		var distance:float=(hit-begin).dot(ray)
		if distance>nearest+EPS: continue
		var part:Dictionary=group.parts[group.owners[face]]
		if absf(distance-nearest)<=EPS and not best.is_empty():
			if part.node!=best.object or group.surfaces[face]!=best.surface_index: ambiguous=true
			continue
		nearest=distance; ambiguous=false
		var normal:Vector3=(faces[offset+1]-faces[offset]).cross(faces[offset+2]-faces[offset]).normalized()
		if normal.dot(ray)>0: normal=-normal
		best={"ok":true,"object":part.node,"surface_index":group.surfaces[face],"face_index":group.source_indices[face],"position":hit,"local_normal":(part.frame.basis.transposed()*normal).normalized(),"generation":group.generation}
	if ambiguous: return {"ok":false,"reason":"coincident_source_surfaces"}
	return best if not best.is_empty() else {"ok":false,"reason":"no_triangle_on_contact_segment"}
