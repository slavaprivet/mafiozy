extends RefCounted
## Exact native port of vehicle_crash.mjs subdivideVehicleGeometry.
## Run during preparation, never on the collision frame.

const MAX_DEPTH := 7
const SUPPORTED_SLOTS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
const UNSUPPORTED_SLOTS := [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]

static func subdivide(original: ArrayMesh, max_edge_m: float = .15, max_triangles: int = 9000) -> Dictionary:
	if original == null or not is_finite(max_edge_m) or max_edge_m <= 0.0 or max_triangles < 0:
		return {"ok":false,"error":"contract"}
	if original.get_blend_shape_count() != 0:
		return {"ok":false,"error":"unsupported_blend_shapes"}
	if original.get_surface_count() == 0:
		return {"ok":false,"error":"surfaces"}
	var prepared: Array = []
	var attribute_slots: Array[int] = []
	var total_triangles := 0
	for surface in original.get_surface_count():
		if original.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return {"ok":false,"error":"unsupported_primitive","surface":surface}
		var storage: Dictionary = RenderingServer.mesh_get_surface(original.get_rid(), surface)
		if storage.has("lods") and _attribute_count(storage["lods"]) > 0:
			return {"ok":false,"error":"unsupported_lods","surface":surface}
		var arrays: Array = original.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			return {"ok":false,"error":"positions","surface":surface}
		for slot in UNSUPPORTED_SLOTS:
			if _attribute_count(arrays[slot]) > 0:
				return {"ok":false,"error":"unsupported_attribute","surface":surface,"slot":slot}
		var slots: Array[int] = []
		for slot in SUPPORTED_SLOTS:
			if _attribute_count(arrays[slot]) > 0: slots.append(slot)
		if slots.is_empty() or slots[0] != Mesh.ARRAY_VERTEX:
			return {"ok":false,"error":"positions","surface":surface}
		if surface == 0: attribute_slots = slots
		elif slots != attribute_slots:
			return {"ok":false,"error":"attribute_layout","surface":surface}
		var vertex_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if vertex_count == 0:
			return {"ok":false,"error":"positions","surface":surface}
		for slot in slots:
			if not _valid_attribute(arrays[slot], slot, vertex_count):
				return {"ok":false,"error":"attribute_size","surface":surface,"slot":slot}
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var triangle_indices: PackedInt32Array
		if indices.is_empty():
			if vertex_count % 3 != 0: return {"ok":false,"error":"triangle_count","surface":surface}
			triangle_indices = PackedInt32Array(); triangle_indices.resize(vertex_count)
			for i in vertex_count: triangle_indices[i] = i
		else:
			if indices.size() % 3 != 0: return {"ok":false,"error":"index_count","surface":surface}
			triangle_indices = indices
			for index in triangle_indices:
				if index < 0 or index >= vertex_count: return {"ok":false,"error":"index_range","surface":surface}
		total_triangles += triangle_indices.size() / 3
		prepared.append({"arrays":arrays,"indices":triangle_indices,"material":original.surface_get_material(surface),"name":original.surface_get_name(surface)})
	var layout := _layout(attribute_slots)
	var remaining: Array[int] = [maxi(0, max_triangles - total_triangles)]
	var output := ArrayMesh.new()
	var output_triangles := 0
	var max_edge_sq := max_edge_m * max_edge_m
	for surface in prepared.size():
		var row: Dictionary = prepared[surface]
		var emitted: Array[PackedFloat64Array] = []
		var ids: PackedInt32Array = row.indices
		for at in range(0, ids.size(), 3):
			var a := _vertex(row.arrays, ids[at], layout)
			var b := _vertex(row.arrays, ids[at + 1], layout)
			var c := _vertex(row.arrays, ids[at + 2], layout)
			_split(a, b, c, 0, max_edge_sq, remaining, emitted)
		var result_arrays := _encode(emitted, layout)
		if result_arrays.is_empty(): return {"ok":false,"error":"encode","surface":surface}
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result_arrays)
		var target := output.get_surface_count() - 1
		output.surface_set_material(target, row.material)
		output.surface_set_name(target, row.name)
		output_triangles += emitted.size() / 3
	return {"ok":true,"mesh":output,"input_triangles":total_triangles,"triangles":output_triangles,"splits":output_triangles-total_triangles,"remaining_budget":remaining[0],"surfaces":output.get_surface_count()}

static func _layout(slots: Array[int]) -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var offset := 0
	for slot in slots:
		var size := 4 if slot in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR] else 2 if slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2] else 3
		layout.append({"slot":slot,"size":size,"offset":offset})
		offset += size
	return layout

static func _vertex(arrays: Array, index: int, layout: Array[Dictionary]) -> PackedFloat64Array:
	var stride := int(layout[-1].offset) + int(layout[-1].size)
	var out := PackedFloat64Array(); out.resize(stride)
	for item in layout:
		var slot: int = item.slot; var offset: int = item.offset
		match slot:
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
				var value: Vector3 = arrays[slot][index]; out[offset]=value.x; out[offset+1]=value.y; out[offset+2]=value.z
			Mesh.ARRAY_TANGENT:
				var values: PackedFloat32Array = arrays[slot]; var at := index*4
				for component in 4: out[offset+component]=values[at+component]
			Mesh.ARRAY_COLOR:
				var color: Color = arrays[slot][index]; out[offset]=color.r; out[offset+1]=color.g; out[offset+2]=color.b; out[offset+3]=color.a
			Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2:
				var uv: Vector2 = arrays[slot][index]; out[offset]=uv.x; out[offset+1]=uv.y
	return out

static func _midpoint(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array(); out.resize(a.size())
	for i in a.size(): out[i]=(a[i]+b[i])*.5
	return out

static func _length_sq(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var x:=a[0]-b[0]; var y:=a[1]-b[1]; var z:=a[2]-b[2]
	return x*x+y*y+z*z

static func _split(a: PackedFloat64Array, b: PackedFloat64Array, c: PackedFloat64Array, depth: int, max_edge_sq: float, remaining: Array[int], out: Array[PackedFloat64Array]) -> void:
	var ab:=_length_sq(a,b); var bc:=_length_sq(b,c); var ca:=_length_sq(c,a)
	var longest:=maxf(ab,maxf(bc,ca))
	if depth < MAX_DEPTH and longest > max_edge_sq and remaining[0] > 0:
		remaining[0]-=1
		if ab>=bc and ab>=ca:
			var m:=_midpoint(a,b); _split(a,m,c,depth+1,max_edge_sq,remaining,out); _split(m,b,c,depth+1,max_edge_sq,remaining,out)
		elif bc>=ca:
			var m:=_midpoint(b,c); _split(a,b,m,depth+1,max_edge_sq,remaining,out); _split(a,m,c,depth+1,max_edge_sq,remaining,out)
		else:
			var m:=_midpoint(c,a); _split(a,b,m,depth+1,max_edge_sq,remaining,out); _split(m,b,c,depth+1,max_edge_sq,remaining,out)
		return
	out.append(a); out.append(b); out.append(c)

static func _encode(vertices: Array[PackedFloat64Array], layout: Array[Dictionary]) -> Array:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	for item in layout:
		match int(item.slot):
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL: arrays[item.slot]=PackedVector3Array()
			Mesh.ARRAY_TANGENT: arrays[item.slot]=PackedFloat32Array()
			Mesh.ARRAY_COLOR: arrays[item.slot]=PackedColorArray()
			Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2: arrays[item.slot]=PackedVector2Array()
	for vertex in vertices:
		for item in layout:
			var slot: int=item.slot; var at: int=item.offset
			match slot:
				Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL: arrays[slot].append(Vector3(vertex[at],vertex[at+1],vertex[at+2]))
				Mesh.ARRAY_TANGENT:
					for component in 4: arrays[slot].append(vertex[at+component])
				Mesh.ARRAY_COLOR: arrays[slot].append(Color(vertex[at],vertex[at+1],vertex[at+2],vertex[at+3]))
				Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2: arrays[slot].append(Vector2(vertex[at],vertex[at+1]))
	return arrays

static func _attribute_count(value: Variant) -> int:
	if value == null: return 0
	return value.size()

static func _valid_attribute(value: Variant, slot: int, vertices: int) -> bool:
	match slot:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL: return value is PackedVector3Array and value.size()==vertices
		Mesh.ARRAY_TANGENT: return value is PackedFloat32Array and value.size()==vertices*4
		Mesh.ARRAY_COLOR: return value is PackedColorArray and value.size()==vertices
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2: return value is PackedVector2Array and value.size()==vertices
	return false
