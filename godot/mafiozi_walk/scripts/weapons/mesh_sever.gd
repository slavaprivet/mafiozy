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
	# Empty sides are omitted; preserve their original material-slot identities.
	var front_surface_indices: Array[int] = []
	var back_surface_indices: Array[int] = []
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
	var open_boundary_verified := false
	var body_contour_invalid := false
	var body_contour_edges := 0

## Cuts `source` with `plane` expressed in the mesh's own space, and returns a Cut.
static func cut(source: ArrayMesh, plane: Plane, part_binds: Dictionary = {}, keep_front: bool = true) -> Cut:
	var surfaces: Array = []
	if source != null:
		for i in source.get_surface_count(): surfaces.append(source.surface_get_arrays(i))
	return cut_surfaces28(surfaces, plane, part_binds, keep_front)

## Worker entry: only caller-owned arrays/math; no mesh, renderer or scene access.
static func cut_surfaces28(surfaces: Array, plane: Plane, part_binds: Dictionary = {}, keep_front: bool = true, topology: Dictionary = {}) -> Cut:
	var result := Cut.new()
	if surfaces.is_empty(): return result
	var body_routes: Dictionary = {}
	if part_binds.has("_clay_body_centre"):
		body_routes = _connected_body_surfaces28(surfaces, plane, part_binds["_clay_body_centre"],topology)
		if body_routes.is_empty():
			result.body_contour_invalid = true
			return result
		result.body_contour_edges = body_routes.edges
	var surface_count := surfaces.size()
	for surface_index: int in surface_count:
		var arrays: Array = surfaces[surface_index]
		if arrays.is_empty(): continue
		var split := _cut_surface(arrays, plane, part_binds, keep_front, body_routes.get("front",{}).get(surface_index,{}), body_routes.get("cross",{}).get(surface_index,{}))
		if not split.front.is_empty():
			result.front_arrays.append(split.front)
			result.front_surface_indices.append(surface_index)
		if not split.back.is_empty():
			result.back_arrays.append(split.back)
			result.back_surface_indices.append(surface_index)
		result.triangles_in += split.triangles_in
		result.triangles_split += split.triangles_split
		result.front_cap.append_array(split.front_cap)
		result.back_cap.append_array(split.back_cap)
		result.boundary_segments += split.boundary_segments
	# Both faces walk the same boundary in the same order. Reversing the input
	# edges independently can partition an open/branched garment contour differently.
	var cap_pair := _triangulate_cap_pair29(result.front_cap, plane.normal)
	result.front_cap_arrays = cap_pair[0]
	result.back_cap_arrays = cap_pair[1]
	# Count real triangles, not array slots.
	result.cap_triangles = _count_triangles(result.front_cap_arrays) + _count_triangles(result.back_cap_arrays)
	# Only opt-in clay torso calls may accept an originally open garment sheet.
	# A failed closed-body contour never acquires this exception.
	if part_binds.has("_clay_keep") and (result.front_cap_arrays.is_empty() or result.back_cap_arrays.is_empty()) and not result.front_cap.is_empty():
		result.open_boundary_verified = _verify_open_surfaces28(surfaces, plane, result.front_cap)
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

static func _cut_surface(arrays: Array, plane: Plane, part_binds: Dictionary = {}, keep_front: bool = true, body_front: Dictionary = {}, body_cross: Dictionary = {}) -> SurfaceSplit:
	var out := SurfaceSplit.new()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty(): return out
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
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
	front.set_source(arrays)
	back.set_source(arrays)

	var force_keep: Dictionary = part_binds.get("_clay_keep", {})
	var force_gone: Dictionary = part_binds.get("_clay_gone", {})
	# Vertex weights and plane distances are invariant throughout this surface.
	var scope_weights := _scope_weights29(bones, weights, vertices.size(), part_binds)
	var keep_weights := _scope_weights29(bones, weights, vertices.size(), force_keep)
	var gone_weights := _scope_weights29(bones, weights, vertices.size(), force_gone)
	var distances := PackedFloat64Array()
	distances.resize(vertices.size())
	for i in vertices.size(): distances[i] = plane.distance_to(vertices[i])
	var triangle_count: int = (indices.size() if indices.size() > 0 else vertices.size()) / 3
	for t: int in triangle_count:
		var i0 := indices[t * 3] if indices.size() > 0 else t * 3
		var i1 := indices[t * 3 + 1] if indices.size() > 0 else t * 3 + 1
		var i2 := indices[t * 3 + 2] if indices.size() > 0 else t * 3 + 2
		out.triangles_in += 1
		# A connected body half is classified through ORIGINAL mesh edges. Skin
		# ownership cannot punch holes at a blended shoulder/torso transition.
		if body_front.has(t):
			if body_front[t]: front.add_source_triangle(i0,i1,i2)
			else: back.add_source_triangle(i0,i1,i2)
			continue
		# Optional clay attachment routing: an intact limb follows its shoulder/hip,
		# not the side of an infinite plane where the bent hand/foot happens to lie.
		# Ordinary production calls never supply these dictionaries.
		var attached_keep := not keep_weights.is_empty() and keep_weights[i0]>=0.999 and keep_weights[i1]>=0.999 and keep_weights[i2]>=0.999
		var attached_gone := not gone_weights.is_empty() and gone_weights[i0]>=0.999 and gone_weights[i1]>=0.999 and gone_weights[i2]>=0.999
		if not body_cross.has(t) and (attached_keep or attached_gone):
			if attached_keep == keep_front: front.add_source_triangle(i0, i1, i2)
			else: back.add_source_triangle(i0, i1, i2)
			continue
		# A scoped limb cut keeps every triangle outside the limb intact, even if the
		# infinite plane crosses the opposite leg or the torso. Bind IDs are local to
		# this mesh's Skin and are resolved by the caller from the real skeleton.
		var in_scope := true
		if not part_binds.is_empty():
			if scope_weights.is_empty():
				in_scope = false
			else:
				var total := scope_weights[i0] + scope_weights[i1] + scope_weights[i2]
				# The old loop's accumulation order is retained at the decision boundary.
				in_scope = _triangle_in_part(bones, weights, i0, i1, i2, part_binds) if absf(total-1.5)<0.000000001 else total>=1.5
		if not in_scope:
			if keep_front: front.add_source_triangle(i0, i1, i2)
			else: back.add_source_triangle(i0, i1, i2)
			continue
		var d0 := distances[i0]
		var d1 := distances[i1]
		var d2 := distances[i2]
		var sides := 0
		if d0 > 0.0: sides |= 1
		if d1 > 0.0: sides |= 2
		if d2 > 0.0: sides |= 4
		if sides == 0:
			back.add_source_triangle(i0, i1, i2)
			continue
		if sides == 7:
			front.add_source_triangle(i0, i1, i2)
			continue
		# The plane crosses this triangle: split it, and remember the edge that lands
		# exactly ON the plane, because that edge is what the cap is built from.
		out.triangles_split += 1
		var v0 := _v(vertices, normals, uvs, bones, weights, colors, i0, has_normals, has_uvs, has_skin, has_colors)
		var v1 := _v(vertices, normals, uvs, bones, weights, colors, i1, has_normals, has_uvs, has_skin, has_colors)
		var v2 := _v(vertices, normals, uvs, bones, weights, colors, i2, has_normals, has_uvs, has_skin, has_colors)
		if uv2s.size() == vertices.size():
			v0.uv2=uv2s[i0];v1.uv2=uv2s[i1];v2.uv2=uv2s[i2]
			v0.has_uv2=true;v1.has_uv2=true;v2.has_uv2=true
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

static func _scope_weights29(bones: PackedInt32Array, weights: PackedFloat32Array, count: int, ids: Dictionary) -> PackedFloat64Array:
	var sums := PackedFloat64Array()
	if ids.is_empty() or bones.size()!=weights.size() or bones.size()!=count*4:return sums
	sums.resize(count)
	for i in count:
		var sum := 0.0
		for k in 4:
			if ids.has(bones[i*4+k]):sum+=weights[i*4+k]
		sums[i]=sum
	return sums


static func _triangle_in_part(bones: PackedInt32Array, weights: PackedFloat32Array,
		i0: int, i1: int, i2: int, part_binds: Dictionary) -> bool:
	if bones.size() != weights.size() or bones.size() < (maxi(i0, maxi(i1, i2)) + 1) * 4: return false
	var weight := 0.0
	for vertex: int in [i0, i1, i2]:
		for k: int in 4:
			if part_binds.has(bones[vertex * 4 + k]): weight += weights[vertex * 4 + k]
	return weight >= 1.5

## A vertex carried through the cut, with the skin data that has to survive it.
class _Vertex:
	var position: Vector3
	var normal: Vector3
	var uv: Vector2
	var uv2: Vector2
	var has_uv2 := false
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
	vertex.uv2 = a.uv2.lerp(b.uv2, t)
	vertex.has_uv2 = a.has_uv2 or b.has_uv2
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
static func _polygon_split(v0: _Vertex, v1: _Vertex, v2: _Vertex, _sides: int,
		_crossing: Array, front: _Builder, back: _Builder) -> void:
	# Preserve source winding by walking its edges in order. Distance to the
	# opposite vertex cannot identify which source edge produced an intersection.
	var source_vertices: Array = [v0, v1, v2]
	var edge_vertices: Dictionary = {}
	var crossing_index := 0
	for i in 3:
		var a: _Vertex=source_vertices[i]
		var b: _Vertex=source_vertices[(i+1)%3]
		if (a.distance>0.0)!=(b.distance>0.0) and absf(a.distance-b.distance)>=1.0e-12:
			edge_vertices[i]=_crossing[crossing_index]
			crossing_index+=1
	for keep_front: bool in [true, false]:
		var polygon: Array = []
		for i: int in 3:
			var a: _Vertex = source_vertices[i]
			if (a.distance > 0.0) == keep_front: polygon.append(a)
			if edge_vertices.has(i):polygon.append(edge_vertices[i])
		var builder: _Builder = front if keep_front else back
		for i: int in range(1, polygon.size() - 1):
			builder.add_triangle(polygon[0], polygon[i], polygon[i + 1])

## Accumulates one side of a cut into a surface description.
class _Builder:
	extends RefCounted
	var source: Array = []
	var source_positions := PackedVector3Array()
	var source_normals := PackedVector3Array()
	var source_uvs := PackedVector2Array()
	var source_uv2s := PackedVector2Array()
	var source_colors := PackedColorArray()
	var source_bones := PackedInt32Array()
	var source_weights := PackedFloat32Array()
	var source_has_normals := false
	var source_has_uvs := false
	var source_has_uv2s := false
	var source_has_colors := false
	var source_has_skin := false
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var any_skin := false
	var any_uv := false
	var any_uv2 := false
	var any_color := false
	# Original vertices keep exact attributes and can share an output index.
	var source_remap: Dictionary = {}

	func set_source(arrays: Array) -> void:
		source = arrays
		source_positions = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array: source_normals = arrays[Mesh.ARRAY_NORMAL]
		if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array: source_uvs = arrays[Mesh.ARRAY_TEX_UV]
		if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array: source_uv2s = arrays[Mesh.ARRAY_TEX_UV2]
		if arrays[Mesh.ARRAY_COLOR] is PackedColorArray: source_colors = arrays[Mesh.ARRAY_COLOR]
		if arrays[Mesh.ARRAY_BONES] is PackedInt32Array: source_bones = arrays[Mesh.ARRAY_BONES]
		if arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array: source_weights = arrays[Mesh.ARRAY_WEIGHTS]
		var count := source_positions.size()
		source_has_normals = source_normals.size() == count
		source_has_uvs = source_uvs.size() == count
		source_has_uv2s = source_uv2s.size() == count
		source_has_colors = source_colors.size() == count
		source_has_skin = source_bones.size() == count * 4 and source_weights.size() == count * 4

	## A triangle wholly on one side needs no per-vertex RefCounted objects.
	## It writes the same attributes/order as add_triangle(_v(...)) does.
	func add_source_triangle(i0: int, i1: int, i2: int) -> void:
		indices.append(_source_index29(i0))
		indices.append(_source_index29(i1))
		indices.append(_source_index29(i2))
		any_uv = true
		any_color = true
		if source_has_skin: any_skin = true
		if source_has_uv2s: any_uv2 = true

	func _source_index29(index: int) -> int:
		if source_remap.has(index): return int(source_remap[index])
		var next := positions.size()
		_append_source_vertex(index)
		source_remap[index] = next
		return next

	func _append_source_vertex(index: int) -> void:
		positions.append(source_positions[index])
		normals.append(source_normals[index] if source_has_normals else Vector3.ZERO)
		uvs.append(source_uvs[index] if source_has_uvs else Vector2.ZERO)
		uv2s.append(source_uv2s[index] if source_has_uv2s else Vector2.ZERO)
		colors.append(source_colors[index] if source_has_colors else Color.WHITE)
		var offset := index * 4
		for k: int in 4:
			bones.append(source_bones[offset + k] if source_has_skin else 0)
			weights.append(source_weights[offset + k] if source_has_skin else 0.0)

	func add_triangle(a: _Vertex, b: _Vertex, c: _Vertex) -> void:
		var base := positions.size()
		for vertex: _Vertex in [a, b, c]:
			positions.append(vertex.position)
			normals.append(vertex.normal)
			uvs.append(vertex.uv)
			uv2s.append(vertex.uv2)
			if vertex.has_uv2: any_uv2 = true
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
		if any_uv2: arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		if any_color: arrays[Mesh.ARRAY_COLOR] = colors
		if any_skin:
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		return arrays


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
	# Segments are stored as consecutive pairs. They are chained by walking EDGES, not
	# vertices: a cut through a limb revisits the same point along different segments,
	# and marking vertices as visited abandoned the contour halfway and restarted it as
	# several short loops - which is why a cube with eight boundary segments produced
	# 128 cap triangles instead of 16.
	var quantise := 10000.0
	var key := func(p: Vector3) -> String:
		return "%d:%d:%d" % [int(round(p.x * quantise)), int(round(p.y * quantise)), int(round(p.z * quantise))]
	var edges: Array = []
	var by_key: Dictionary = {}
	var adjacency: Dictionary = {}
	for i: int in range(0, count - 1, 2):
		var a: _Vertex = vertices[i]
		var b: _Vertex = vertices[i + 1]
		var ka: String = key.call(a.position)
		var kb: String = key.call(b.position)
		if ka == kb: continue
		by_key[ka] = a
		by_key[kb] = b
		for endpoint: String in [ka,kb]:
			if not adjacency.has(endpoint):adjacency[endpoint]=[]
			adjacency[endpoint].append(edges.size())
		edges.append([ka, kb])
	if edges.size() < 3: return []
	# Every closed contour becomes its own fan, so a cut that opens the body in two
	# places (through both arms, say) is capped in both places.
	var built := _Builder.new()
	var used: Dictionary = {}
	for contour: int in edges.size():
		var seed := -1
		for candidate: int in edges.size():
			if not used.has(candidate):
				seed = candidate
				break
		if seed < 0: break
		var loop: Array = []
		var current := seed
		# Open garment contours start at an endpoint, so their final segment is
		# retained rather than splitting one chain into two incomplete fans.
		var degree: Dictionary = {}
		for candidate: int in edges.size():
			if used.has(candidate): continue
			for endpoint: String in edges[candidate]:
				degree[endpoint] = int(degree.get(endpoint, 0)) + 1
		for candidate: int in edges.size():
			if used.has(candidate): continue
			var ends: Array = edges[candidate]
			if degree[ends[0]] == 1:
				current = candidate
				break
			if degree[ends[1]] == 1:
				current = candidate
				edges[candidate] = [ends[1], ends[0]]
				break
		var start_key: String = edges[current][0]
		while true:
			used[current] = true
			var edge: Array = edges[current]
			loop.append(by_key[edge[0]])
			var next_key: String = edge[1]
			if next_key == start_key: break
			var found := -1
			for candidate: int in adjacency.get(next_key,[]):
				if used.has(candidate): continue
				var other: Array = edges[candidate]
				if other[0] == next_key:
					found = candidate
					break
				if other[1] == next_key:
					# Walk it the right way round rather than backwards.
					edges[candidate] = [other[1], other[0]]
					found = candidate
					break
			if found < 0:
				loop.append(by_key[next_key])
				break
			current = found
		if loop.size() < 3: continue
		var centre := Vector3.ZERO
		for vertex: _Vertex in loop: centre += vertex.position
		centre /= float(loop.size())
		# The centre takes the bone data of the first loop vertex, which is the closest
		# thing to a correct influence for a point inside the opening.
		var hub := _Vertex.new()
		hub.position = centre
		hub.normal = -face_normal
		hub.has_skin = (loop[0] as _Vertex).has_skin
		hub.bone = (loop[0] as _Vertex).bone
		hub.weight = (loop[0] as _Vertex).weight
		for i: int in loop.size():
			var a: _Vertex = loop[i]
			var b: _Vertex = loop[(i + 1) % loop.size()]
			if a.position.distance_squared_to(b.position) < 1.0e-12: continue
			var edge := (a.position - centre).cross(b.position - centre)
			a.normal = -face_normal
			b.normal = -face_normal
			if edge.length_squared() > 1.0e-12 and edge.normalized().dot(face_normal) < 0.0:
				built.add_triangle(hub, b, a)
			else:
				built.add_triangle(hub, a, b)
	return built.build()

# Confirm that every loose endpoint of the new cut comes from an edge that was
# already open in the ORIGINAL surface. This distinguishes cloth sheets from a
# broken cap on a closed volume, or from a seam introduced by branch routing.
static func _sheet_vertex_key28(point: Vector3) -> Vector3i:
	return Vector3i((point * 100000.0).round())

static func _sheet_edge_key28(a: Vector3, b: Vector3) -> String:
	var ka := str(_sheet_vertex_key28(a))
	var kb := str(_sheet_vertex_key28(b))
	return ka+"|"+kb if ka < kb else kb+"|"+ka

static func _verify_original_open_boundary28(source: ArrayMesh, plane: Plane, segments: Array) -> bool:
	var surfaces: Array = []
	for i in source.get_surface_count(): surfaces.append(source.surface_get_arrays(i))
	return _verify_open_surfaces28(surfaces, plane, segments)

static func _verify_open_surfaces28(surfaces: Array, plane: Plane, segments: Array) -> bool:
	var degrees: Dictionary = {}
	for endpoint: _Vertex in segments:
		var key := _sheet_vertex_key28(endpoint.position)
		degrees[key] = int(degrees.get(key,0))+1
	var loose: Array[Vector3i] = []
	for key: Vector3i in degrees:
		if degrees[key] == 1: loose.append(key)
		elif degrees[key] != 2: return false
	if loose.size() < 2: return false
	var edges: Dictionary = {}
	for surface: int in surfaces.size():
		var arrays: Array = surfaces[surface]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = (indices.size() if not indices.is_empty() else vertices.size()) / 3
		for triangle: int in count:
			for corner: int in 3:
				var ia := indices[triangle*3+corner] if not indices.is_empty() else triangle*3+corner
				var ib := indices[triangle*3+(corner+1)%3] if not indices.is_empty() else triangle*3+(corner+1)%3
				var a := vertices[ia]
				var b := vertices[ib]
				var key := _sheet_edge_key28(a,b)
				if edges.has(key): edges[key].count += 1
				else: edges[key] = {"a":a,"b":b,"count":1}
	var original_crossings: Dictionary = {}
	for edge: Dictionary in edges.values():
		if edge.count != 1: continue
		var da := plane.distance_to(edge.a)
		var db := plane.distance_to(edge.b)
		if (da > 0.0) == (db > 0.0) or absf(da-db) < 1.0e-12: continue
		var point: Vector3 = edge.a.lerp(edge.b, clampf(da/(da-db),0.0,1.0))
		original_crossings[_sheet_vertex_key28(point)] = true
	for endpoint: Vector3i in loose:
		if not original_crossings.has(endpoint): return false
	return true

static func _triangle_fully_in_part28(bones: PackedInt32Array, weights: PackedFloat32Array, i0: int, i1: int, i2: int, ids: Dictionary) -> bool:
	if bones.size()!=weights.size() or bones.size()<(maxi(i0,maxi(i1,i2))+1)*4:return false
	for vertex: int in [i0,i1,i2]:
		var weight:=0.0
		for k: int in 4:
			if ids.has(bones[vertex*4+k]):weight+=weights[vertex*4+k]
		if weight<0.999:return false
	return true

# Select the actual closed section around the torso centre, then cut the original
# mesh graph only along that contour. Intact arms remain connected through their
# shoulders even when a hand is geometrically on the other side of the plane.
# No hull, inferred bridge or additional disc is used to close an open chain.
static func _body_root28(parents: Array[int], vertex: int) -> int:
	while parents[vertex] != vertex:
		parents[vertex] = parents[parents[vertex]]
		vertex = parents[vertex]
	return vertex

static func _body_edge28(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a,b),maxi(a,b))

static func _connected_body_routes28(source: ArrayMesh, plane: Plane, centre: Vector3) -> Dictionary:
	var surfaces: Array = []
	for i in source.get_surface_count(): surfaces.append(source.surface_get_arrays(i))
	return _connected_body_surfaces28(surfaces, plane, centre)

static func _body_topology29(surfaces: Array) -> Dictionary:
	var ids: Dictionary = {}
	var surface_vertex_ids: Array[PackedInt32Array]=[]
	var points := PackedVector3Array()
	var triangles: Array[PackedInt32Array] = []
	var seen_edges: Dictionary={}
	var edges: Array[Vector2i]=[]
	for surface: int in surfaces.size():
		var arrays: Array = surfaces[surface]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var vertex_ids := PackedInt32Array()
		for point: Vector3 in vertices:
			var key := _sheet_vertex_key28(point)
			if not ids.has(key):
				ids[key] = points.size()
				points.append(point)
			vertex_ids.append(ids[key])
		surface_vertex_ids.append(vertex_ids)
		var count: int = (indices.size() if not indices.is_empty() else vertices.size())/3
		for t: int in count:
			var tri := PackedInt32Array([surface,t])
			for c: int in 3: tri.append(vertex_ids[indices[t*3+c] if not indices.is_empty() else t*3+c])
			triangles.append(tri)
			for c in 3:
				var edge:=_body_edge28(tri[2+c],tri[2+(c+1)%3])
				if not seen_edges.has(edge):seen_edges[edge]=true;edges.append(edge)
	return {"points":points,"triangles":triangles,"edges":edges,"vertex_ids":surface_vertex_ids}

static func _repose_body_topology29(surfaces: Array, cached: Dictionary) -> Dictionary:
	# Exact validation of the welded partition, including quantization boundaries.
	# Current point coordinates are rebuilt; only unchanged triangle/edge IDs reuse
	# their cached arrays. Changed welds take the original complete rebuild path.
	if not cached.has("vertex_ids") or cached.vertex_ids.size()!=surfaces.size():return _body_topology29(surfaces)
	var ids: Dictionary={};var points:=PackedVector3Array()
	for surface in surfaces.size():
		var vertices: PackedVector3Array=surfaces[surface][Mesh.ARRAY_VERTEX]
		var expected: PackedInt32Array=cached.vertex_ids[surface]
		if expected.size()!=vertices.size():return _body_topology29(surfaces)
		for index in vertices.size():
			var point:Vector3=vertices[index]
			var key:=_sheet_vertex_key28(point)
			if not ids.has(key):ids[key]=points.size();points.append(point)
			if ids[key]!=expected[index]:return _body_topology29(surfaces)
	var result:=cached.duplicate()
	result.points=points
	return result

static func _connected_body_surfaces28(surfaces: Array, plane: Plane, centre: Vector3, cached_topology: Dictionary = {}) -> Dictionary:
	var topology: Dictionary=cached_topology if not cached_topology.is_empty() else _body_topology29(surfaces)
	var points: PackedVector3Array=topology.points
	var triangles: Array[PackedInt32Array]=topology.triangles
	var distances:=PackedFloat64Array()
	distances.resize(points.size())
	for i in points.size():distances[i]=plane.distance_to(points[i])
	var crossings: Array[Dictionary]=[]
	var boundary: Dictionary={}
	for tri: PackedInt32Array in triangles:
		var front: bool=distances[tri[2]]>0.0
		if front==(distances[tri[3]]>0.0) and front==(distances[tri[4]]>0.0):continue
		var contour := PackedVector3Array()
		var cut_edges: Array[Vector2i] = []
		for c: int in 3:
			var ia := tri[2+c]
			var ib := tri[2+(c+1)%3]
			var da: float = distances[ia]
			var db: float = distances[ib]
			if (da>0.0)==(db>0.0) or absf(da-db)<1.0e-12:continue
			contour.append(points[ia].lerp(points[ib],clampf(da/(da-db),0.0,1.0)))
			cut_edges.append(_body_edge28(ia,ib))
		if contour.size()!=2:continue
		var ka: Vector2i = cut_edges[0]
		var kb: Vector2i = cut_edges[1]
		if ka==kb:continue
		var index := crossings.size()
		crossings.append({"tri":tri,"a":ka,"b":kb,"pa":contour[0],"pb":contour[1],"cut_edges":cut_edges})
		if not boundary.has(ka):boundary[ka]=[]
		if not boundary.has(kb):boundary[kb]=[]
		boundary[ka].append(index);boundary[kb].append(index)
	var n := plane.normal.normalized()
	var u := n.cross(Vector3.UP if absf(n.y)<0.9 else Vector3.RIGHT).normalized()
	var v := n.cross(u).normalized()
	var query := Vector2(centre.dot(u),centre.dot(v))
	var visited: Dictionary = {}
	var selected: Array[int] = []
	var best_area := 0.0
	for seed: int in crossings.size():
		if visited.has(seed):continue
		var component: Array[int] = []
		var pending: Array[int] = [seed]
		var closed := true
		while not pending.is_empty():
			var index: int = pending.pop_back()
			if visited.has(index):continue
			visited[index]=true;component.append(index)
			for key: Vector2i in [crossings[index].a,crossings[index].b]:
				if boundary[key].size()!=2:closed=false
				for neighbour: int in boundary[key]:
					if not visited.has(neighbour):pending.append(neighbour)
		if not closed or component.size()<3:continue
		var polygon := PackedVector2Array()
		var edge := seed
		var start: Vector2i = crossings[seed].a
		var current := start
		for step: int in component.size():
			var item: Dictionary = crossings[edge]
			var point: Vector3 = item.pa if item.a==current else item.pb
			polygon.append(Vector2(point.dot(u),point.dot(v)))
			current=item.b if item.a==current else item.a
			if current==start:break
			var neighbours: Array=boundary[current]
			edge=neighbours[0] if neighbours[0]!=edge else neighbours[1]
		if current!=start or not Geometry2D.is_point_in_polygon(query,polygon):continue
		var area:=0.0
		for i: int in polygon.size():area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area)>best_area:
			best_area=absf(area);selected=component
	if selected.is_empty():return {}
	var blocked: Dictionary={}
	var selected_triangles: Dictionary={}
	for index: int in selected:
		var item: Dictionary=crossings[index]
		for edge: Vector2i in item.cut_edges:blocked[edge]=true
		selected_triangles[Vector2i(item.tri[0],item.tri[1])]=true
	var parents: Array[int]=[]
	var sizes: Array[int]=[]
	for i: int in points.size():parents.append(i);sizes.append(1)
	for edge: Vector2i in topology.edges:
		if blocked.has(edge):continue
		var ra:=_body_root28(parents,edge.x);var rb:=_body_root28(parents,edge.y)
		if ra==rb:continue
		if sizes[ra]<sizes[rb]:parents[ra]=rb;sizes[rb]+=sizes[ra]
		else:parents[rb]=ra;sizes[ra]+=sizes[rb]
	var sides: Dictionary={}
	for index: int in selected:
		var tri: PackedInt32Array=crossings[index].tri
		for c: int in 3:
			var vertex:=tri[2+c];var root:=_body_root28(parents,vertex)
			var side:=1 if distances[vertex]>0.0 else 2
			sides[root]=int(sides.get(root,0))|side
			if sides[root]==3:return {}
	var front: Dictionary={};var cross: Dictionary={}
	for tri: PackedInt32Array in triangles:
		var surface:=tri[0];var t:=tri[1]
		if selected_triangles.has(Vector2i(surface,t)):
			if not cross.has(surface):cross[surface]={}
			cross[surface][t]=true
		else:
			var root:=_body_root28(parents,tri[2])
			if not sides.has(root):continue
			if not front.has(surface):front[surface]={}
			front[surface][t]=sides[root]==1
	return {"front":front,"cross":cross,"edges":selected.size()}

static func _triangulate_cap_pair29(vertices: Array, face_normal: Vector3) -> Array:
	# Contour traversal is independent of normal; preserve both original emitters.
	var loops := _cap_loops29(vertices)
	return [_emit_cap_loops29(loops, face_normal), _emit_cap_loops29(loops, -face_normal)]

static func _cap_loops29(vertices: Array) -> Array:
	var count := vertices.size()
	if count < 3: return []
	# Segments are stored as consecutive pairs. They are chained by walking EDGES, not
	# vertices: a cut through a limb revisits the same point along different segments,
	# and marking vertices as visited abandoned the contour halfway and restarted it as
	# several short loops - which is why a cube with eight boundary segments produced
	# 128 cap triangles instead of 16.
	var quantise := 10000.0
	var key := func(p: Vector3) -> String:
		return "%d:%d:%d" % [int(round(p.x * quantise)), int(round(p.y * quantise)), int(round(p.z * quantise))]
	var edges: Array = []
	var by_key: Dictionary = {}
	var adjacency: Dictionary = {}
	for i: int in range(0, count - 1, 2):
		var a: _Vertex = vertices[i]
		var b: _Vertex = vertices[i + 1]
		var ka: String = key.call(a.position)
		var kb: String = key.call(b.position)
		if ka == kb: continue
		by_key[ka] = a
		by_key[kb] = b
		for endpoint: String in [ka,kb]:
			if not adjacency.has(endpoint):adjacency[endpoint]=[]
			adjacency[endpoint].append(edges.size())
		edges.append([ka, kb])
	if edges.size() < 3: return []
	# Every closed contour becomes its own fan, so a cut that opens the body in two
	# places (through both arms, say) is capped in both places.
	var loops: Array = []
	var used: Dictionary = {}
	for contour: int in edges.size():
		var seed := -1
		for candidate: int in edges.size():
			if not used.has(candidate):
				seed = candidate
				break
		if seed < 0: break
		var loop: Array = []
		var current := seed
		# Open garment contours start at an endpoint, so their final segment is
		# retained rather than splitting one chain into two incomplete fans.
		var degree: Dictionary = {}
		for candidate: int in edges.size():
			if used.has(candidate): continue
			for endpoint: String in edges[candidate]:
				degree[endpoint] = int(degree.get(endpoint, 0)) + 1
		for candidate: int in edges.size():
			if used.has(candidate): continue
			var ends: Array = edges[candidate]
			if degree[ends[0]] == 1:
				current = candidate
				break
			if degree[ends[1]] == 1:
				current = candidate
				edges[candidate] = [ends[1], ends[0]]
				break
		var start_key: String = edges[current][0]
		while true:
			used[current] = true
			var edge: Array = edges[current]
			loop.append(by_key[edge[0]])
			var next_key: String = edge[1]
			if next_key == start_key: break
			var found := -1
			for candidate: int in adjacency.get(next_key,[]):
				if used.has(candidate): continue
				var other: Array = edges[candidate]
				if other[0] == next_key:
					found = candidate
					break
				if other[1] == next_key:
					# Walk it the right way round rather than backwards.
					edges[candidate] = [other[1], other[0]]
					found = candidate
					break
			if found < 0:
				loop.append(by_key[next_key])
				break
			current = found
		if loop.size() < 3: continue
		loops.append(loop)
	return loops

static func _emit_cap_loops29(loops: Array, face_normal: Vector3) -> Array:
	var built := _Builder.new()
	for loop: Array in loops:
		var centre := Vector3.ZERO
		for vertex: _Vertex in loop: centre += vertex.position
		centre /= float(loop.size())
		# The centre takes the bone data of the first loop vertex, which is the closest
		# thing to a correct influence for a point inside the opening.
		var hub := _Vertex.new()
		hub.position = centre
		hub.normal = -face_normal
		hub.has_skin = (loop[0] as _Vertex).has_skin
		hub.bone = (loop[0] as _Vertex).bone
		hub.weight = (loop[0] as _Vertex).weight
		for i: int in loop.size():
			var a: _Vertex = loop[i]
			var b: _Vertex = loop[(i + 1) % loop.size()]
			if a.position.distance_squared_to(b.position) < 1.0e-12: continue
			var edge := (a.position - centre).cross(b.position - centre)
			a.normal = -face_normal
			b.normal = -face_normal
			if edge.length_squared() > 1.0e-12 and edge.normalized().dot(face_normal) < 0.0:
				built.add_triangle(hub, b, a)
			else:
				built.add_triangle(hub, a, b)
	return built.build()

