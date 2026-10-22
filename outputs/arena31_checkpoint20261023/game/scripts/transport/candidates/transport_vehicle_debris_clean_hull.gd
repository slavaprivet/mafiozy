extends RefCounted
## Measurement-only candidate for native convex point cleaning. It preserves the
## full private render mesh and requests no convex simplification.

static func stage(source: MeshInstance3D, assembly: Node3D, native_clean: bool) -> Dictionary:
	if not is_instance_valid(source) or not is_instance_valid(assembly) or not source.mesh is ArrayMesh or (source!=assembly and not assembly.is_ancestor_of(source)):
		return {"ok":false,"error":"contract"}
	var assembly_transform:=assembly.global_transform
	if not _finite_transform(assembly_transform) or absf(assembly_transform.basis.determinant())<.000001: return {"ok":false,"error":"transform"}
	var rigid:=Basis(assembly_transform.basis.get_rotation_quaternion())
	var transform:=Transform3D(rigid.inverse()*assembly_transform.basis,Vector3.ZERO)*(assembly_transform.affine_inverse()*source.global_transform)
	if not _finite_transform(transform): return {"ok":false,"error":"transform"}
	var total_begin:=Time.get_ticks_usec()
	var private_begin:=total_begin
	var private_mesh:=source.mesh.duplicate(true) as ArrayMesh
	var private_us:=Time.get_ticks_usec()-private_begin
	var points_begin:=Time.get_ticks_usec(); var raw_points:=PackedVector3Array(); var transformed_mesh:=ArrayMesh.new()
	for surface in source.mesh.get_surface_count():
		var arrays: Array=source.mesh.surface_get_arrays(surface).duplicate(true)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return {"ok":false,"error":"vertices"}
		var vertices: PackedVector3Array=transform*(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		if vertices.is_empty(): return {"ok":false,"error":"vertices"}
		for point in vertices:
			if not point.is_finite(): return {"ok":false,"error":"nonfinite"}
		raw_points.append_array(vertices); arrays[Mesh.ARRAY_VERTEX]=vertices
		transformed_mesh.add_surface_from_arrays(source.mesh.surface_get_primitive_type(surface),arrays)
	var points_us:=Time.get_ticks_usec()-points_begin
	var native_us:=0; var collision_points:=raw_points
	if native_clean:
		var native_begin:=Time.get_ticks_usec()
		var native_shape:=transformed_mesh.create_convex_shape(true,false)
		native_us=Time.get_ticks_usec()-native_begin
		if native_shape==null or not native_shape is ConvexPolygonShape3D or native_shape.points.size()<4: return {"ok":false,"error":"native_clean"}
		collision_points=native_shape.points
	var assign_begin:=Time.get_ticks_usec(); var shape:=ConvexPolygonShape3D.new(); shape.points=collision_points; var assign_us:=Time.get_ticks_usec()-assign_begin
	return {"ok":true,"private_mesh":private_mesh,"shape":shape,"raw_points":raw_points,"collision_points":collision_points,"raw_count":raw_points.size(),"clean_count":collision_points.size(),"private_us":private_us,"points_us":points_us,"native_us":native_us,"assign_us":assign_us,"total_us":Time.get_ticks_usec()-total_begin}

static func _finite_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite()
