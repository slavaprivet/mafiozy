extends RefCounted
## Pure bounded staging for one authored closed box. No scene mutation/debris spawn.
## The source volume is partitioned once; opposite skins are NEVER extruded twice.
const Strength = preload("../material_strength.gd")
const EPS := 0.00001
const MAX_BRUSHES := 32
const MAX_GRID_CELLS := 1024
const MAX_SOLID_CELLS := 512
const MAX_DEBRIS := 64
const MAX_VERTICES := 65536

static func prepare(source: Dictionary, brushes_world: Array[AABB], profile: Dictionary, previous: Dictionary = {}) -> Dictionary:
	var parsed := _source(source, profile)
	if not parsed.ok: return parsed
	var binding: Dictionary = parsed.binding
	if not previous.is_empty() and (previous.get("schema") != "thin-slab-state/v1" or previous.get("binding") != binding): return _no("previous_source_binding")
	var old_brushes: Array[AABB] = []
	for value: Variant in previous.get("brushes_world", []):
		if not value is AABB or not _valid_brush(value): return _no("previous_brushes")
		old_brushes.append(value)
	var all_brushes: Array[AABB] = old_brushes.duplicate()
	for brush: AABB in brushes_world:
		if not _valid_brush(brush): return _no("finite_positive_world_brush")
		if parsed.world_bounds.intersects(brush) and not all_brushes.has(brush): all_brushes.append(brush)
	if all_brushes.size() > MAX_BRUSHES: return _no("brush_budget")
	var grid: Array = []
	var candidates := 1
	for axis: int in 3:
		var breaks: Array[float] = [parsed.world_bounds.position[axis], parsed.world_bounds.end[axis]]
		for brush: AABB in all_brushes:
			_add_break(breaks, brush.position[axis]); _add_break(breaks, brush.end[axis])
			# Never split a already-thin world extent merely because it crosses
			# grid origin; native parallel walls keep both authored skins per cell.
			if parsed.world_bounds.size[axis] <= parsed.chunk_size: continue
			var start: int = floori(maxf(brush.position[axis], breaks[0]) / parsed.chunk_size) + 1
			var stop: int = ceili(minf(brush.end[axis], breaks[1]) / parsed.chunk_size)
			if stop - start > 64: return _no("grid_axis_budget")
			for step: int in range(start, stop): _add_break(breaks, step * parsed.chunk_size)
		breaks.sort()
		grid.append(breaks)
		candidates *= breaks.size() - 1
	if candidates > MAX_GRID_CELLS: return _no("grid_cell_budget")
	var boundary: Array[Dictionary] = []
	var shared: Dictionary = {}
	var debris: Array[Dictionary] = []
	var solid_cells := 0
	var kept_volume := 0.0
	var total_removed_volume := 0.0
	var new_removed_volume := 0.0
	var original_volume: float = parsed.box.get_volume() * parsed.frame.basis.determinant()
	for x: int in grid[0].size() - 1:
		for y: int in grid[1].size() - 1:
			for z: int in grid[2].size() - 1:
				var indices := Vector3i(x, y, z)
				var cell := AABB(Vector3(grid[0][x], grid[1][y], grid[2][z]), Vector3(grid[0][x + 1] - grid[0][x], grid[1][y + 1] - grid[1][y], grid[2][z + 1] - grid[2][z]))
				var faces: Array[Dictionary] = parsed.faces.duplicate(true)
				for axis: int in 3:
					faces = _clip_solid(faces, parsed.frame, axis, cell.position[axis], false, indices[axis])
					faces = _clip_solid(faces, parsed.frame, axis, cell.end[axis], true, indices[axis] + 1)
					if faces.is_empty(): break
				if faces.is_empty(): continue
				var volume: float = _volume(faces, parsed.frame)
				if volume <= 0.000000001: continue
				solid_cells += 1
				if solid_cells > MAX_SOLID_CELLS: return _no("solid_cell_budget")
				var removed: bool = _inside_brushes(cell.get_center(), all_brushes)
				if removed:
					total_removed_volume += volume
					if not _inside_brushes(cell.get_center(), old_brushes):
						new_removed_volume += volume
						if debris.size() >= MAX_DEBRIS: return _no("debris_budget")
						var piece := _debris(faces, parsed, volume, cell)
						if not piece.ok: return piece
						debris.append(piece)
					continue
				kept_volume += volume
				for face: Dictionary in faces:
					if int(face.grid_axis) < 0: boundary.append(face); continue
					var axis: int = int(face.grid_axis)
					var key := str(axis) + ":" + str(face.grid_plane) + ":" + str(indices[(axis + 1) % 3]) + ":" + str(indices[(axis + 2) % 3])
					if shared.has(key):
						if shared[key] == null or face.normal.dot(shared[key].normal) > -.99: return _no("nonmanifold_cell_boundary")
						shared[key] = null # Exactly two adjacent kept cells: no internal wall surface.
					else: shared[key] = face
	var conservation_error: float = absf(kept_volume + total_removed_volume - original_volume)
	if conservation_error > maxf(0.00001, original_volume * .00005): return _no("volume_conservation")
	for face: Variant in shared.values():
		if face != null: boundary.append(face)
	var changed: bool = new_removed_volume > 0.000000001
	var output: Dictionary
	if not changed:
		var unchanged: Mesh = previous.get("wall_mesh", parsed.mesh)
		output = {"ok": true, "mesh": unchanged, "provenance": previous.get("wall_provenance", [])}
	else: output = _mesh(boundary, parsed, Transform3D.IDENTITY)
	if not output.ok: return output
	var wall_faces := PackedVector3Array()
	var raw_faces: PackedVector3Array = output.mesh.get_faces()
	for index: int in range(0, raw_faces.size(), 3):
		var a: Vector3 = parsed.frame * raw_faces[index]; var b: Vector3 = parsed.frame * raw_faces[index + 1]; var c: Vector3 = parsed.frame * raw_faces[index + 2]
		if (b - a).cross(c - a).length_squared() <= .00000000000001: continue
		wall_faces.append(a); wall_faces.append(b); wall_faces.append(c)
	var state := {"schema": "thin-slab-state/v1", "binding": binding, "brushes_world": all_brushes.duplicate(), "wall_mesh": output.mesh, "wall_provenance": output.provenance}
	return {"ok": true, "changed": changed, "wall_mesh": output.mesh, "wall_frame": parsed.frame, "wall_collision_faces_world": wall_faces, "wall_face_provenance": output.provenance, "debris": debris, "next_state": state, "source_id": str(source.source_id), "source_part_id": str(source.source_part_id), "material_class": str(profile.material_class).to_lower(), "profile_id": str(profile.profile_id), "thickness_m": float(profile.thickness_m), "original_volume_m3": original_volume, "remaining_volume_m3": kept_volume, "total_removed_volume_m3": total_removed_volume, "new_removed_volume_m3": new_removed_volume, "volume_error_m3": conservation_error, "solid_cells": solid_cells, "candidate_cells": candidates, "scene_mutated": false}

static func _source(source: Dictionary, profile: Dictionary) -> Dictionary:
	if not source.get("mesh") is ArrayMesh or not source.get("frame") is Transform3D or not source.get("local_box") is AABB or not source.get("thin_axis") is int: return _no("source_descriptor")
	var mesh: ArrayMesh = source.mesh; var frame: Transform3D = source.frame; var box: AABB = source.local_box
	var thin: int = int(source.thin_axis)
	if str(source.get("source_id", "")).is_empty() or str(source.get("source_part_id", "")).is_empty(): return _no("source_identity")
	if not frame.is_finite() or frame.basis.determinant() <= .000000001 or not box.position.is_finite() or not box.size.is_finite() or box.size.x <= 0 or box.size.y <= 0 or box.size.z <= 0 or thin < 0 or thin > 2: return _no("finite_box_frame")
	var family: String = str(profile.get("material_class", "UNKNOWN")).to_lower()
	if not Strength.DEFAULTS.has(family): return _no("explicit_physical_material_required")
	if str(profile.get("profile_id", "")).is_empty() or not profile.get("reveal_material") is Material: return _no("explicit_profile_and_reveal_material_required")
	if not _number(profile.get("thickness_m")): return _no("explicit_thickness_required")
	var normal_matrix: Basis = frame.basis.inverse().transposed()
	var axis_vector := Vector3.ZERO; axis_vector[thin] = 1.0
	var thickness: float = box.size[thin] / (normal_matrix * axis_vector).length()
	if thickness < .02 or thickness > .3 or absf(thickness - float(profile.thickness_m)) > .00002: return _no("thin_slab_thickness_mismatch")
	var chunk: Variant = profile.get("chunk_size_m", .65)
	if not _number(chunk) or float(chunk) < .1 or float(chunk) > 1.0: return _no("chunk_size_limits")
	if mesh.get_surface_count() == 0 or mesh.get_surface_count() > 6 or mesh.get_blend_shape_count() != 0: return _no("exact_box_mesh_required")
	var source_faces: Array[Dictionary] = []
	var snapshots: Array = []
	var materials: Array[Material] = []
	for face_index: int in 6: source_faces.append({"triangles": [], "surface": -1})
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: return _no("triangle_source_required")
		if Strength.classify(str(mesh.resource_name), mesh.surface_get_material(surface), family) == "glass": return _no("glass_has_separate_owner")
		var arrays: Array = mesh.surface_get_arrays(surface)
		for slot: int in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			if arrays[slot] != null and not arrays[slot].is_empty(): return _no("unsupported_source_attributes")
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		if normals.size() != vertices.size() or uv.size() != vertices.size(): return _no("authored_normals_uv_required")
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		if count % 3 != 0: return _no("triangle_indices")
		for offset: int in range(0, count, 3):
			var triangle: Array = []
			for corner: int in 3:
				var index: int = indices[offset + corner] if not indices.is_empty() else offset + corner
				if index < 0 or index >= vertices.size() or not vertices[index].is_finite() or not normals[index].is_finite() or not uv[index].is_finite(): return _no("finite_source_attributes")
				triangle.append(_vertex(arrays, index))
			var face_id: int = _box_face(triangle, box)
			if face_id < 0: return _no("exact_box_face_required")
			var entry: Dictionary = source_faces[face_id]
			if entry.surface >= 0 and entry.surface != surface: return _no("same_face_material_discontinuity")
			entry.surface = surface; entry.triangles.append({"vertices": triangle, "triangle_index": offset / 3})
		snapshots.append(arrays.duplicate(true)); materials.append(mesh.surface_get_material(surface))
	var faces: Array[Dictionary] = []
	for face_id: int in 6:
		var entry: Dictionary = source_faces[face_id]
		if entry.triangles.size() != 2: return _no("exact_two_triangles_per_box_face")
		var axis: int = face_id / 2; var high: bool = face_id % 2 == 1
		var normal := Vector3.ZERO; normal[axis] = 1.0 if high else -1.0
		var u: int = (axis + 1) % 3; var v: int = (axis + 2) % 3
		var polygon: Array[Vector3] = []
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var point: Vector3 = box.position; point[axis] = box.end[axis] if high else box.position[axis]
			point[u] += box.size[u] * corner.x; point[v] += box.size[v] * corner.y; polygon.append(point)
		if not high: polygon.reverse()
		var distinct: Array[Vector3] = []
		var area := 0.0
		for triangle: Dictionary in entry.triangles:
			var a: Vector3 = triangle.vertices[0][0]; var b: Vector3 = triangle.vertices[1][0]; var c: Vector3 = triangle.vertices[2][0]
			if (b - a).cross(c - a).dot(normal) >= 0: return _no("source_godot_clockwise_winding")
			area += (b - a).cross(c - a).length() * .5
			for vertex: Array in triangle.vertices:
				if not _near_point(vertex[0], polygon): return _no("box_corner_required")
				if not _near_point(vertex[0], distinct): distinct.append(vertex[0])
				if vertex[1].distance_to(normal) > .0001: return _no("authored_box_normal_required")
		if distinct.size() != 4 or absf(area - box.size[u] * box.size[v]) > .0001: return _no("complete_box_face_required")
		entry["normal"] = normal; entry["axis"] = axis
		# Affine BoxGeometry UV/color attributes allow exact quad reconstruction
		# without inventing a back texture or leaving diagonal T-junctions.
		for triangle: Dictionary in entry.triangles:
			for vertex: Array in triangle.vertices:
				var interpolated: Array = _sample(entry, vertex[0])
				if not _attributes_match(vertex, interpolated): return _no("non_affine_authored_box_attributes")
		faces.append({"polygon": polygon, "normal": normal, "source_face": face_id, "surface": entry.surface, "grid_axis": -1, "grid_plane": -1})
	var world_bounds := AABB(frame * box.position, Vector3.ZERO)
	for x: int in 2:
		for y: int in 2:
			for z: int in 2: world_bounds = world_bounds.expand(frame * (box.position + box.size * Vector3(x, y, z)))
	var binding := {"mesh": mesh, "arrays": snapshots, "materials": materials, "frame": frame, "box": box, "thin_axis": thin, "source_id": str(source.source_id), "source_part_id": str(source.source_part_id), "profile": profile.duplicate(true)}
	return {"ok": true, "binding": binding, "mesh": mesh, "frame": frame, "box": box, "faces": faces, "source_faces": source_faces, "materials": materials, "world_bounds": world_bounds, "chunk_size": float(chunk), "reveal_material": profile.reveal_material, "source": source, "profile": profile}

static func _box_face(triangle: Array, box: AABB) -> int:
	for axis: int in 3:
		for side: int in 2:
			var value: float = box.position[axis] if side == 0 else box.end[axis]
			if absf(triangle[0][0][axis] - value) < EPS and absf(triangle[1][0][axis] - value) < EPS and absf(triangle[2][0][axis] - value) < EPS: return axis * 2 + side
	return -1

static func _vertex(arrays: Array, index: int) -> Array:
	var color: Color = arrays[Mesh.ARRAY_COLOR][index] if arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty() else Color.WHITE
	var uv2: Vector2 = arrays[Mesh.ARRAY_TEX_UV2][index] if arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty() else Vector2.ZERO
	var t: Variant = arrays[Mesh.ARRAY_TANGENT]
	var fallback: Vector3 = Vector3.UP if absf(arrays[Mesh.ARRAY_NORMAL][index].x) > .9 else Vector3.RIGHT
	var tangent := Vector4(t[index * 4], t[index * 4 + 1], t[index * 4 + 2], t[index * 4 + 3]) if t != null and not t.is_empty() else Vector4(fallback.x, fallback.y, fallback.z, 1)
	return [arrays[Mesh.ARRAY_VERTEX][index], arrays[Mesh.ARRAY_NORMAL][index], arrays[Mesh.ARRAY_TEX_UV][index], color, tangent, uv2]

static func _sample(face: Dictionary, point: Vector3) -> Array:
	var vertices: Array = face.triangles[0].vertices
	var a: Vector3 = vertices[0][0]; var e: Vector3 = vertices[1][0] - a; var f: Vector3 = vertices[2][0] - a; var d: Vector3 = point - a
	var ee := e.dot(e); var ef := e.dot(f); var ff := f.dot(f)
	var determinant: float = ee * ff - ef * ef
	var b: float = (d.dot(e) * ff - d.dot(f) * ef) / determinant
	var c: float = (d.dot(f) * ee - d.dot(e) * ef) / determinant
	var weight: float = 1.0 - b - c
	return [point, vertices[0][1] * weight + vertices[1][1] * b + vertices[2][1] * c, vertices[0][2] * weight + vertices[1][2] * b + vertices[2][2] * c, vertices[0][3] * weight + vertices[1][3] * b + vertices[2][3] * c, vertices[0][4] * weight + vertices[1][4] * b + vertices[2][4] * c, vertices[0][5] * weight + vertices[1][5] * b + vertices[2][5] * c]

static func _attributes_match(a: Array, b: Array) -> bool:
	return a[1].distance_to(b[1]) < .0001 and a[2].distance_to(b[2]) < .0001 and Vector4(a[3].r, a[3].g, a[3].b, a[3].a).distance_to(Vector4(b[3].r, b[3].g, b[3].b, b[3].a)) < .0001 and a[4].distance_to(b[4]) < .0001 and a[5].distance_to(b[5]) < .0001

static func _clip_solid(input: Array[Dictionary], frame: Transform3D, axis: int, value: float, less: bool, plane_index: int) -> Array[Dictionary]:
	if input.is_empty(): return input
	var inside_count := 0; var outside_count := 0
	for face: Dictionary in input:
		for point: Vector3 in face.polygon:
			var distance: float = ((frame * point)[axis] - value) * (1.0 if less else -1.0)
			if distance > EPS: outside_count += 1
			else: inside_count += 1
	if outside_count == 0: return input
	if inside_count == 0: return []
	var output: Array[Dictionary] = []
	var cap: Array[Vector3] = []
	for face: Dictionary in input:
		var polygon: Array[Vector3] = []
		var last: Vector3 = face.polygon.back()
		var last_distance: float = ((frame * last)[axis] - value) * (1.0 if less else -1.0)
		for point: Vector3 in face.polygon:
			var distance: float = ((frame * point)[axis] - value) * (1.0 if less else -1.0)
			if (distance <= EPS) != (last_distance <= EPS):
				var crossing: Vector3 = last.lerp(point, clampf(last_distance / (last_distance - distance), 0, 1))
				_append_unique(polygon, crossing, frame); _append_unique(cap, crossing, frame)
			if distance <= EPS:
				_append_unique(polygon, point, frame)
				if absf(distance) <= EPS: _append_unique(cap, point, frame)
			last = point; last_distance = distance
		if polygon.size() >= 3:
			var clipped: Dictionary = face.duplicate(); clipped.polygon = polygon; output.append(clipped)
	if cap.size() < 3: return []
	var centre := Vector3.ZERO
	for point: Vector3 in cap: centre += frame * point
	centre /= cap.size()
	var u: int = (axis + 1) % 3; var v: int = (axis + 2) % 3
	cap.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var aw: Vector3 = frame * a - centre; var bw: Vector3 = frame * b - centre
		return atan2(aw[v], aw[u]) < atan2(bw[v], bw[u]))
	if not less: cap.reverse()
	var world_normal := Vector3.ZERO; world_normal[axis] = 1.0 if less else -1.0
	output.append({"polygon": cap, "normal": (frame.basis.transposed() * world_normal).normalized(), "source_face": -1, "surface": -1, "grid_axis": axis, "grid_plane": plane_index})
	return output

static func _append_unique(points: Array[Vector3], point: Vector3, frame: Transform3D) -> void:
	for existing: Vector3 in points:
		if (frame * existing).distance_squared_to(frame * point) <= EPS * EPS: return
	points.append(point)

static func _volume(faces: Array[Dictionary], frame: Transform3D) -> float:
	var origin: Vector3 = frame * faces[0].polygon[0]
	var volume := 0.0
	for face: Dictionary in faces:
		var a: Vector3 = frame * face.polygon[0] - origin
		for index: int in range(1, face.polygon.size() - 1):
			var b: Vector3 = frame * face.polygon[index] - origin; var c: Vector3 = frame * face.polygon[index + 1] - origin
			volume += a.dot(b.cross(c)) / 6.0
	return maxf(volume, 0.0)

static func _debris(faces: Array[Dictionary], parsed: Dictionary, volume: float, cell: AABB) -> Dictionary:
	var local_points: Array[Vector3] = []
	for face: Dictionary in faces:
		for point: Vector3 in face.polygon: _append_unique(local_points, point, parsed.frame)
	var centre := Vector3.ZERO
	for point: Vector3 in local_points: centre += parsed.frame * point
	centre /= local_points.size()
	var fragment_frame := Transform3D(Basis.IDENTITY, centre)
	var conversion: Transform3D = fragment_frame.affine_inverse() * parsed.frame
	var built := _mesh(faces, parsed, conversion)
	if not built.ok: return built
	var points := PackedVector3Array()
	for point: Vector3 in local_points: points.append(conversion * point)
	return {"ok": true, "mesh": built.mesh, "frame": fragment_frame, "convex_points": points, "face_provenance": built.provenance, "volume_m3": volume, "world_cell": cell, "source_id": str(parsed.source.source_id), "source_part_id": str(parsed.source.source_part_id), "material_class": str(parsed.profile.material_class).to_lower(), "profile_id": str(parsed.profile.profile_id), "thickness_m": float(parsed.profile.thickness_m), "closed": true, "synthetic_back": false}

static func _mesh(faces: Array[Dictionary], parsed: Dictionary, conversion: Transform3D) -> Dictionary:
	var output := ArrayMesh.new()
	var provenance: Array[Dictionary] = []
	var total_vertices := 0
	var normal_matrix: Basis = conversion.basis.inverse().transposed()
	# Adjacent analytical faces reach a shared intersection through different
	# clipping orders. Weld those equal-within-EPS source positions ONCE before
	# conversion/packing, so all triangles submit bit-identical shared vertices.
	# This fixes actual mesh topology; no test tolerance is relaxed.
	var welded_faces: Array[Dictionary] = _weld_faces(faces, parsed.frame)
	for surface: int in parsed.materials.size() + 1:
		var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array(); var colors := PackedColorArray(); var tangents := PackedFloat32Array(); var uv2 := PackedVector2Array()
		for face: Dictionary in welded_faces:
			var face_surface: int = int(face.surface) if int(face.source_face) >= 0 else parsed.materials.size()
			if face_surface != surface: continue
			for index: int in range(1, face.polygon.size() - 1):
				var triangle: Array[Vector3] = [face.polygon[0], face.polygon[index + 1], face.polygon[index]] # Godot CW, math faces are CCW.
				if (conversion.basis * (triangle[1] - triangle[0])).cross(conversion.basis * (triangle[2] - triangle[0])).length_squared() < 0.00000000000001: continue
				var triangle_index: int = vertices.size() / 3
				for point: Vector3 in triangle:
					var attributes: Array
					if int(face.source_face) >= 0: attributes = _sample(parsed.source_faces[face.source_face], point)
					else: attributes = _reveal_attributes(face, point, parsed.frame)
					var normal: Vector3 = (normal_matrix * attributes[1]).normalized()
					var tangent: Vector3 = conversion.basis * Vector3(attributes[4].x, attributes[4].y, attributes[4].z)
					tangent = (tangent - normal * tangent.dot(normal)).normalized()
					vertices.append(conversion * point); normals.append(normal); uv.append(attributes[2]); colors.append(attributes[3]); uv2.append(attributes[5])
					tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, attributes[4].w]))
				var source_triangles: Array[int] = []
				if int(face.source_face) >= 0:
					for authored: Dictionary in parsed.source_faces[face.source_face].triangles: source_triangles.append(int(authored.triangle_index))
				provenance.append({"surface": surface, "triangle": triangle_index, "source_face": int(face.source_face), "source_surface": int(face.surface), "source_triangles": source_triangles, "generated_reveal": int(face.source_face) < 0})
		total_vertices += vertices.size()
		if total_vertices > MAX_VERTICES: return _no("mesh_vertex_budget")
		if vertices.is_empty():
			# Stable authored surface indices; callers exclude these zero-area faces.
			for index: int in 3:
				vertices.append(Vector3.ZERO); normals.append(Vector3.UP); uv.append(Vector2.ZERO); colors.append(Color.WHITE); uv2.append(Vector2.ZERO); tangents.append_array(PackedFloat32Array([1, 0, 0, 1]))
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_TANGENT] = tangents; arrays[Mesh.ARRAY_TEX_UV2] = uv2
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		output.surface_set_material(surface, parsed.materials[surface] if surface < parsed.materials.size() else parsed.reveal_material)
	return {"ok": true, "mesh": output, "provenance": provenance}

static func _weld_faces(faces: Array[Dictionary], frame: Transform3D) -> Array[Dictionary]:
	var bins: Dictionary = {}
	var output: Array[Dictionary] = []
	for face: Dictionary in faces:
		var polygon: Array[Vector3] = []
		for point: Vector3 in face.polygon:
			var world: Vector3 = frame * point
			var x: int = floori(world.x / EPS); var y: int = floori(world.y / EPS); var z: int = floori(world.z / EPS)
			var canonical: Vector3 = point
			var found := false
			for dx: int in range(-1, 2):
				if found: break
				for dy: int in range(-1, 2):
					if found: break
					for dz: int in range(-1, 2):
						var key := str(x + dx) + ":" + str(y + dy) + ":" + str(z + dz)
						for candidate: Dictionary in bins.get(key, []):
							if candidate.world.distance_squared_to(world) <= EPS * EPS:
								canonical = candidate.local; found = true; break
						if found: break
			if not found:
				var key := str(x) + ":" + str(y) + ":" + str(z)
				if not bins.has(key): bins[key] = []
				bins[key].append({"world": world, "local": point})
			if not polygon.has(canonical): polygon.append(canonical)
		if polygon.size() >= 3:
			var copy: Dictionary = face.duplicate(); copy.polygon = polygon; output.append(copy)
	return output

static func _reveal_attributes(face: Dictionary, point: Vector3, frame: Transform3D) -> Array:
	var axis: int = int(face.grid_axis); var u: int = (axis + 1) % 3; var v: int = (axis + 2) % 3
	var world: Vector3 = frame * point
	var tangent_world := Vector3.ZERO; tangent_world[u] = 1.0
	var bitangent_world := Vector3.ZERO; bitangent_world[v] = 1.0
	var tangent: Vector3 = (frame.basis.inverse() * tangent_world).normalized()
	var bitangent: Vector3 = (frame.basis.inverse() * bitangent_world).normalized()
	var handedness: float = 1.0 if face.normal.cross(tangent).dot(bitangent) >= 0 else -1.0
	return [point, face.normal, Vector2(world[u], world[v]), Color.WHITE, Vector4(tangent.x, tangent.y, tangent.z, handedness), Vector2.ZERO]

static func _add_break(values: Array[float], value: float) -> void:
	if value <= values[0] + EPS or value >= values[1] - EPS: return
	for existing: float in values:
		if absf(existing - value) <= EPS: return
	values.append(value)

static func _inside_brushes(point: Vector3, brushes: Array[AABB]) -> bool:
	for brush: AABB in brushes:
		if brush.has_point(point): return true
	return false

static func _near_point(point: Vector3, points: Array[Vector3]) -> bool:
	for existing: Vector3 in points:
		if existing.distance_to(point) < EPS: return true
	return false

static func _valid_brush(brush: AABB) -> bool:
	return brush.position.is_finite() and brush.size.is_finite() and brush.end.is_finite() and brush.size.x > EPS and brush.size.y > EPS and brush.size.z > EPS

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "scene_mutated": false}
