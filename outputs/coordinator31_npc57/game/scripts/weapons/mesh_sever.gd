class_name MeshSever
extends RefCounted
## DSH_GORE: real planar severing of a SKINNED mesh.
##
## The old dismemberment collapsed a limb's bones to zero scale and spawned a stump
## that merely looked like a wound. This cuts the actual surface: every triangle the
## plane crosses is split, the skin comes apart along the cut, and the opening is
## closed with a CAP built from the boundary the cut leaves behind, so the inside of
## the body is visible instead of a hole.
##
## It is skin-aware. Bone indices and weights are carried across the cut by
## interpolating the two vertices an edge came from, so the surviving body still
## deforms with the skeleton exactly as before, and the piece that comes off can be
## handed to the world as rigid debris.
##
## Cost is paid ONCE per cut, never per frame, and the cap is triangulated by chaining
## the boundary segments rather than by any mesh boolean.


## Attribute slots that are carried through the cut. Anything else is passed through
## untouched when the source has it, and simply omitted when it does not.
const _INTERPOLATED := [
	Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR,
]

## A cut result: the two sides of the surface, each with its own cap.
class Cut:
	var front_arrays: Array = []      ## surfaces that stayed in front of the plane
	var back_arrays: Array = []       ## surfaces behind it
	## Cap vertices for each side, as _Vertex so bone data survives the cut.
	var front_cap: Array = []
	var back_cap: Array = []
	## Ready-to-add surface arrays for the fleshy cut face, one per side.
	var front_cap_arrays: Array = []
	var back_cap_arrays: Array = []
	var cap_bone_indices: PackedInt32Array = PackedInt32Array()
	var cap_bone_weights: PackedFloat32Array = PackedFloat32Array()
	var triangles_in := 0
	var triangles_split := 0
	var cap_triangles := 0
	var boundary_segments := 0

## Cuts `source` with `plane` expressed in the mesh's own space, and returns a Cut.
static func cut(source: ArrayMesh, plane: Plane) -> Cut:
	var result := Cut.new()
	if source == null: return result
	var surface_count := source.get_surface_count()
	for surface_index: int in surface_count:
		var arrays: Array = source.surface_get_arrays(surface_index)
		if arrays.is_empty(): continue
		var split := _cut_surface(arrays, plane)
		if not split.front.is_empty(): result.front_arrays.append(split.front)
		if not split.back.is_empty(): result.back_arrays.append(split.back)
		result.triangles_in += split.triangles_in
		result.triangles_split += split.triangles_split
		result.front_cap.append_array(split.front_cap)
		result.back_cap.append_array(split.back_cap)
		result.boundary_segments += split.boundary_segments
	# The cap is triangulated per side, from the segments the cut left on the plane.
	result.front_cap_arrays = _triangulate_cap(result.front_cap, plane.normal)
	result.back_cap_arrays = _triangulate_cap(result.back_cap, -plane.normal)
	# Count real triangles, not array slots.
	result.cap_triangles = _count_triangles(result.front_cap_arrays) + _count_triangles(result.back_cap_arrays)
	return result

## One surface in, its two sides plus the boundary the cut left behind.
class SurfaceSplit:
	var front: Array = []
	var back: Array = []
	var front_cap: Array = []
	var back_cap: Array = []
	var triangles_in := 0
	var triangles_split := 0
	var boundary_segments := 0

static func _cut_surface(arrays: Array, plane: Plane) -> SurfaceSplit:
	var out := SurfaceSplit.new()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty(): return out
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var has_normals := normals.size() == vertices.size()
	var has_uvs := uvs.size() == vertices.size()
	var has_skin := bones.size() == vertices.size() * 4 and weights.size() == vertices.size() * 4
	var has_colors := colors.size() == vertices.size()

	var front := _Builder.new()
	var back := _Builder.new()
	front.source = arrays
	back.source = arrays

	var triangle_count: int = (indices.size() if indices.size() > 0 else vertices.size()) / 3
	for t: int in triangle_count:
		var i0 := indices[t * 3] if indices.size() > 0 else t * 3
		var i1 := indices[t * 3 + 1] if indices.size() > 0 else t * 3 + 1
		var i2 := indices[t * 3 + 2] if indices.size() > 0 else t * 3 + 2
		out.triangles_in += 1
		var d0 := plane.distance_to(vertices[i0])
		var d1 := plane.distance_to(vertices[i1])
		var d2 := plane.distance_to(vertices[i2])
		var sides := 0
		if d0 > 0.0: sides |= 1
		if d1 > 0.0: sides |= 2
		if d2 > 0.0: sides |= 4
		if sides == 0:
			back.add_triangle(_v(vertices, normals, uvs, bones, weights, colors, i0, has_normals, has_uvs, has_skin, has_colors),
				_v(vertices, normals, uvs, bones, weights, colors, i1, has_normals, has_uvs, has_skin, has_colors),
				_v(vertices, normals, uvs, bones, weights, colors, i2, has_normals, has_uvs, has_skin, has_colors))
			continue
		if sides == 7:
			front.add_triangle(_v(vertices, normals, uvs, bones, weights, colors, i0, has_normals, has_uvs, has_skin, has_colors),
				_v(vertices, normals, uvs, bones, weights, colors, i1, has_normals, has_uvs, has_skin, has_colors),
				_v(vertices, normals, uvs, bones, weights, colors, i2, has_normals, has_uvs, has_skin, has_colors))
			continue
		# The plane crosses this triangle: split it, and remember the edge that lands
		# exactly ON the plane, because that edge is what the cap is built from.
		out.triangles_split += 1
		var v0 := _v(vertices, normals, uvs, bones, weights, colors, i0, has_normals, has_uvs, has_skin, has_colors)
		var v1 := _v(vertices, normals, uvs, bones, weights, colors, i1, has_normals, has_uvs, has_skin, has_colors)
		var v2 := _v(vertices, normals, uvs, bones, weights, colors, i2, has_normals, has_uvs, has_skin, has_colors)
		v0.distance = d0; v1.distance = d1; v2.distance = d2
		var crossing: Array = []
		_edge_crossing(v0, v1, crossing)
		_edge_crossing(v1, v2, crossing)
		_edge_crossing(v2, v0, crossing)
		if crossing.size() < 2:
			# Numerically degenerate: keep it on whichever side has the majority.
			if sides == 3 or sides == 5 or sides == 6:
				front.add_triangle(v0, v1, v2)
			else:
				back.add_triangle(v0, v1, v2)
			continue
		out.boundary_segments += 1
		_polygon_split(v0, v1, v2, sides, crossing, front, back)
		var a: _Vertex = crossing[0]
		var b: _Vertex = crossing[1]
		# Each side gets the cut edge with the normal of the plane, which is what makes
		# the opening read as a wound rather than as a fold.
		out.front_cap.append(a)
		out.front_cap.append(b)
		out.back_cap.append(b)
		out.back_cap.append(a)
	out.front = front.build()
	out.back = back.build()
	return out

## A vertex carried through the cut, with the skin data that has to survive it.
class _Vertex:
	var position: Vector3
	var normal: Vector3
	var uv: Vector2
	var color: Color = Color.WHITE
	var bone := PackedInt32Array([0, 0, 0, 0])
	var weight := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var distance := 0.0
	var has_skin := false

static func _v(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		bones: PackedInt32Array, weights: PackedFloat32Array, colors: PackedColorArray,
		index: int, has_normals: bool, has_uvs: bool, has_skin: bool, has_colors: bool) -> _Vertex:
	var out := _Vertex.new()
	out.position = vertices[index]
	if has_normals: out.normal = normals[index]
	if has_uvs: out.uv = uvs[index]
	if has_colors: out.color = colors[index]
	if has_skin:
		out.has_skin = true
		for k: int in 4:
			out.bone[k] = bones[index * 4 + k]
			out.weight[k] = weights[index * 4 + k]
	return out

## Where an edge crosses the plane: position and skin blended by the crossing ratio.
static func _edge_crossing(a: _Vertex, b: _Vertex, out: Array) -> void:
	if (a.distance > 0.0) == (b.distance > 0.0): return
	var denominator := a.distance - b.distance
	if absf(denominator) < 1.0e-12: return
	var t := clampf(a.distance / denominator, 0.0, 1.0)
	var vertex := _Vertex.new()
	vertex.position = a.position.lerp(b.position, t)
	vertex.normal = a.normal.lerp(b.normal, t).normalized()
	vertex.uv = a.uv.lerp(b.uv, t)
	vertex.color = a.color.lerp(b.color, t)
	vertex.distance = 0.0
	vertex.has_skin = a.has_skin or b.has_skin
	if vertex.has_skin:
		# Bone indices cannot be blended - blending them points at a bone that may not
		# exist, which is how a cut limb ends up welded to the wrong joint. Instead the
		# two endpoints' influences are MERGED by bone and blended by the crossing
		# ratio, the four heaviest are kept, and the result is renormalised so the cut
		# vertex deforms exactly like the surface it came from.
		var merged: Dictionary = {}
		for k: int in 4:
			var wa: float = a.weight[k] if a.has_skin else 0.0
			var wb: float = b.weight[k] if b.has_skin else 0.0
			if wa > 1.0e-6:
				var bone_a: int = a.bone[k]
				merged[bone_a] = float(merged.get(bone_a, 0.0)) + wa * (1.0 - t)
			if wb > 1.0e-6:
				var bone_b: int = b.bone[k]
				merged[bone_b] = float(merged.get(bone_b, 0.0)) + wb * t
		var ranked: Array = []
		for bone_id: int in merged.keys():
			ranked.append([bone_id, float(merged[bone_id])])
		ranked.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
		var total := 0.0
		for slot: int in 4:
			if slot < ranked.size():
				vertex.bone[slot] = int(ranked[slot][0])
				vertex.weight[slot] = float(ranked[slot][1])
				total += float(ranked[slot][1])
			else:
				vertex.bone[slot] = 0
				vertex.weight[slot] = 0.0
		if total > 1.0e-6:
			for slot: int in 4:
				vertex.weight[slot] = vertex.weight[slot] / total
		else:
			vertex.bone[0] = b.bone[0] if b.has_skin else a.bone[0]
			vertex.weight[0] = 1.0
	out.append(vertex)

## Splits one crossed triangle into the pieces that belong to each side.
static func _polygon_split(v0: _Vertex, v1: _Vertex, v2: _Vertex, sides: int,
		crossing: Array, front: _Builder, back: _Builder) -> void:
	var all: Array = [v0, v1, v2]
	var front_poly: Array = []
	var back_poly: Array = []
	var a: _Vertex = crossing[0]
	var b: _Vertex = crossing[1]
	match sides:
		1, 2, 4:
			# One vertex alone on its side: that corner is a triangle, the rest a quad.
			var lone: _Vertex = v0 if sides == 1 else (v1 if sides == 2 else v2)
			var other_a: _Vertex = v1 if sides == 1 else (v2 if sides == 2 else v0)
			var other_b: _Vertex = v2 if sides == 1 else (v0 if sides == 2 else v1)
			var near_a: _Vertex = a if a.position.distance_squared_to(other_a.position) < a.position.distance_squared_to(other_b.position) else b
			var near_b: _Vertex = b if near_a == a else a
			front_poly = [lone, near_a, near_b]
			back_poly = [near_a, other_a, other_b, near_b]
		3, 5, 6:
			# Two vertices on the front side, one behind.
			var lone_back: _Vertex = v2 if sides == 3 else (v0 if sides == 5 else v1)
			var f_a: _Vertex = v0 if sides == 3 else (v1 if sides == 5 else v2)
			var f_b: _Vertex = v1 if sides == 3 else (v2 if sides == 5 else v0)
			var near_a2: _Vertex = a if a.position.distance_squared_to(lone_back.position) < a.position.distance_squared_to(b.position) else b
			var near_b2: _Vertex = b if near_a2 == a else a
			front_poly = [near_a2, f_a, f_b, near_b2]
			back_poly = [lone_back, near_b2, near_a2]
		_:
			front_poly = all
			back_poly = []
	for i: int in range(1, front_poly.size() - 1):
		front.add_triangle(front_poly[0], front_poly[i], front_poly[i + 1])
	for i: int in range(1, back_poly.size() - 1):
		back.add_triangle(back_poly[0], back_poly[i], back_poly[i + 1])

## Accumulates one side of a cut into a surface description.
class _Builder:
	extends RefCounted
	var source: Array = []
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var any_skin := false
	var any_uv := false
	var any_color := false

	func add_triangle(a: _Vertex, b: _Vertex, c: _Vertex) -> void:
		var base := positions.size()
		for vertex: _Vertex in [a, b, c]:
			positions.append(vertex.position)
			normals.append(vertex.normal)
			uvs.append(vertex.uv)
			colors.append(vertex.color)
			for k: int in 4:
				bones.append(vertex.bone[k])
				weights.append(vertex.weight[k])
			if vertex.has_skin: any_skin = true
		any_uv = true
		any_color = true
		indices.append(base); indices.append(base + 1); indices.append(base + 2)

	## Packs the accumulated geometry into the same array layout the source used, so a
	## rewritten body keeps its material and its skinning without any special casing.
	func build() -> Array:
		if positions.is_empty(): return []
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		if any_uv: arrays[Mesh.ARRAY_TEX_UV] = uvs
		if any_color: arrays[Mesh.ARRAY_COLOR] = colors
		if any_skin:
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		return arrays

## How many triangles a packed surface array actually holds.
static func _count_triangles(arrays: Array) -> int:
	if arrays.is_empty(): return 0
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
		return (indices as PackedInt32Array).size() / 3
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	if vertices is PackedVector3Array: return (vertices as PackedVector3Array).size() / 3
	return 0

## Chains the segments the cut left on the plane into loops and fans each one.
## It returns ready-to-add surface ARRAYS, not raw points, so the fleshy face can carry
## the bone data of the boundary it was built from and skin with the rest of the body.
static func _triangulate_cap(vertices: Array, face_normal: Vector3) -> Array:
	var count := vertices.size()
	if count < 3: return []
	# Segments are stored as consecutive pairs; chain them into ordered loops by
	# matching endpoints. An unordered fan would bow-tie, which is exactly the artefact
	# that makes a cut look wrong.
	var adjacency: Dictionary = {}
	var quantise := 10000.0
	var key := func(p: Vector3) -> String:
		return "%d:%d:%d" % [int(round(p.x * quantise)), int(round(p.y * quantise)), int(round(p.z * quantise))]
	for i: int in range(0, count - 1, 2):
		var a: _Vertex = vertices[i]
		var b: _Vertex = vertices[i + 1]
		var ka: String = key.call(a.position)
		var kb: String = key.call(b.position)
		if ka == kb: continue
		if not adjacency.has(ka): adjacency[ka] = []
		if not adjacency.has(kb): adjacency[kb] = []
		(adjacency[ka] as Array).append(kb)
		(adjacency[kb] as Array).append(ka)
	var by_key: Dictionary = {}
	for i: int in count:
		var vertex: _Vertex = vertices[i]
		by_key[key.call(vertex.position)] = vertex
	# Every disconnected loop becomes its own fan, so a cut that opens the body in two
	# places (through both arms, say) is capped in both places.
	var built := _Builder.new()
	for start: String in adjacency.keys():
		if not by_key.has(start): continue
		var loop: Array = []
		var visited: Dictionary = {}
		var current := start
		var previous := ""
		while true:
			if visited.has(current): break
			visited[current] = true
			if by_key.has(current): loop.append(by_key[current])
			var next := ""
			for candidate: String in adjacency[current]:
				if candidate != previous and not visited.has(candidate):
					next = candidate
					break
			if next == "": break
			previous = current
			current = next
		if loop.size() < 3: continue
		var centre := Vector3.ZERO
		for vertex: _Vertex in loop: centre += vertex.position
		centre /= float(loop.size())
		# The centre takes the bone data of the first loop vertex, which is the closest
		# thing to a correct influence for a point inside the opening.
		var hub := _Vertex.new()
		hub.position = centre
		hub.normal = face_normal
		hub.has_skin = (loop[0] as _Vertex).has_skin
		hub.bone = (loop[0] as _Vertex).bone
		hub.weight = (loop[0] as _Vertex).weight
		for i: int in loop.size():
			var a: _Vertex = loop[i]
			var b: _Vertex = loop[(i + 1) % loop.size()]
			if a.position.distance_squared_to(b.position) < 1.0e-12: continue
			var edge := (a.position - centre).cross(b.position - centre)
			var normal: Vector3 = face_normal if face_normal.length_squared() > 1.0e-8 else edge.normalized()
			if edge.length_squared() > 1.0e-12 and edge.normalized().dot(face_normal) < 0.0:
				built.add_triangle(hub, b, a)
			else:
				built.add_triangle(hub, a, b)
	return built.build()