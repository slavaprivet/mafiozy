extends RefCounted
## Static weapon visuals only. Physics nodes and moving bow strings stay separate.

static func finish(root: Node3D, excluded: Array = []) -> Dictionary:
	var groups: Dictionary = {}
	var before := 0
	var triangles_before := 0
	for node in root.get_children():
		if not node is MeshInstance3D or excluded.has(node): continue
		var part := node as MeshInstance3D
		if part.mesh == null: continue
		before += 1
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			triangles_before += (indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		if part.mesh is CylinderMesh:
			part.mesh.radial_segments = mini(part.mesh.radial_segments, 12)
			part.mesh.rings = 1
		elif part.mesh is SphereMesh:
			part.mesh.radial_segments = 12
			part.mesh.rings = 6
		elif part.mesh is TorusMesh:
			part.mesh.rings = 16
			part.mesh.ring_segments = 6
		var material := part.material_override
		if material == null: continue
		var key := material.get_instance_id()
		if not groups.has(key): groups[key] = {"material":material,"parts":[]}
		groups[key].parts.append(part)
	var after := 0
	var triangles_after := 0
	for key in groups:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in groups[key].parts:
			for surface in part.mesh.get_surface_count(): tool.append_from(part.mesh, surface, part.transform)
		tool.set_material(groups[key].material)
		var mesh := tool.commit()
		var merged := MeshInstance3D.new()
		merged.name = "StaticMaterial" + str(after)
		merged.mesh = mesh
		merged.material_override = groups[key].material
		root.add_child(merged)
		after += 1
		var arrays := mesh.surface_get_arrays(0)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		triangles_after += (indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		for part: MeshInstance3D in groups[key].parts:
			root.remove_child(part)
			part.free()
	var report := {"parts_before":before,"parts_after":after,"triangles_before":triangles_before,"triangles_after":triangles_after}
	root.set_meta("visual_budget31", report)
	return report

static func sword_blade() -> ArrayMesh:
	# A continuous tapered diamond section with actual cutting edges and a point.
	# The end is exactly the sword's existing collision reach (0.06 + 1.15 m).
	var stations := [Vector3(0.155,0.030,0.010),Vector3(0.62,0.025,0.008),Vector3(1.05,0.016,0.005),Vector3(1.21,0,0)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in stations.size() - 1:
		var a: Vector3 = stations[i]
		var b: Vector3 = stations[i+1]
		var ring_a := [Vector3(a.x,a.y,0),Vector3(a.x,0,a.z),Vector3(a.x,-a.y,0),Vector3(a.x,0,-a.z)]
		var ring_b := [Vector3(b.x,b.y,0),Vector3(b.x,0,b.z),Vector3(b.x,-b.y,0),Vector3(b.x,0,-b.z)]
		for edge in 4:
			var next := (edge+1)%4
			var points := [ring_a[edge],ring_b[next],ring_a[next]]
			if b.y > 0.0: points.append_array([ring_a[edge],ring_b[edge],ring_b[next]])
			for point in points:
				tool.set_uv(Vector2(point.x, point.y))
				tool.add_vertex(point)
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()

static func _shield_outline31() -> PackedVector2Array:
	# Clockwise seen from the front (+Z); a plain heater silhouette.
	return PackedVector2Array([Vector2(-0.33,0.40),Vector2(0.33,0.40),Vector2(0.30,-0.03),Vector2(0.20,-0.23),Vector2(0,-0.40),Vector2(-0.20,-0.23),Vector2(-0.30,-0.03)])

static func _quad31(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a,b,c,a,c,d]:
		tool.set_uv(Vector2(point.x,point.y))
		tool.add_vertex(point)

static func shield_plate() -> ArrayMesh:
	var outline := _shield_outline31()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := Vector3(outline[i].x,outline[i].y,0.0275)
		var b := Vector3(outline[(i+1)%outline.size()].x,outline[(i+1)%outline.size()].y,0.0275)
		var back_a := Vector3(a.x,a.y,-0.0275)
		var back_b := Vector3(b.x,b.y,-0.0275)
		for point: Vector3 in [Vector3(0,0,0.0275),a,b,Vector3(0,0,-0.0275),back_b,back_a]:
			tool.set_uv(Vector2(point.x,point.y))
			tool.add_vertex(point)
		_quad31(tool,a,back_a,back_b,b)
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()

static func shield_rim() -> ArrayMesh:
	var outline := _shield_outline31()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var outer_a := Vector3(a.x*1.04,a.y*1.035,0.035)
		var outer_b := Vector3(b.x*1.04,b.y*1.035,0.035)
		var inner_a := Vector3(a.x*0.95,a.y*0.96,0.035)
		var inner_b := Vector3(b.x*0.95,b.y*0.96,0.035)
		var outer_back_a := Vector3(outer_a.x,outer_a.y,-0.035)
		var outer_back_b := Vector3(outer_b.x,outer_b.y,-0.035)
		var inner_back_a := Vector3(inner_a.x,inner_a.y,-0.035)
		var inner_back_b := Vector3(inner_b.x,inner_b.y,-0.035)
		_quad31(tool,outer_a,outer_b,inner_b,inner_a)
		_quad31(tool,outer_back_a,inner_back_a,inner_back_b,outer_back_b)
		_quad31(tool,outer_a,outer_back_a,outer_back_b,outer_b)
		_quad31(tool,inner_a,inner_b,inner_back_b,inner_back_a)
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()


static func resting_transform(model: Node3D, basis: Basis, floor_point: Vector3) -> Transform3D:
	# Rest the lowest vertex bound on the floor for every weapon silhouette.
	var lowest := INF
	for child in model.get_children():
		if not child is MeshInstance3D or child.mesh == null: continue
		var bounds: AABB = child.mesh.get_aabb()
		for corner in 8:
			var point := bounds.get_endpoint(corner)
			lowest = minf(lowest, (basis * (child.transform * point)).y)
	if not is_finite(lowest): lowest = 0.0
	return Transform3D(basis, floor_point + Vector3.UP * (0.008 - lowest))
