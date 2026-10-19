extends RefCounted
## Art-only pooled mesh alternative. Same source .035m outer radius and +Z face.
## No texture files, world access, hit/ray/ownership changes, or runtime generation.
const SEGMENTS:=18
const RADIUS:=.035
static func _mesh(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var normals:=PackedVector3Array(); normals.resize(vertices.size()); normals.fill(Vector3.BACK)
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh
static func _disk(points: PackedVector3Array) -> ArrayMesh:
	var vertices:=PackedVector3Array([Vector3.ZERO]); vertices.append_array(points)
	var colors:=PackedColorArray(); colors.resize(vertices.size()); colors.fill(Color.WHITE)
	var indices:=PackedInt32Array()
	for i: int in points.size(): indices.append_array([0,i+1,(i+1)%points.size()+1])
	return _mesh(vertices,colors,indices)
static func build() -> Array[Dictionary]:
	var variants: Array[Dictionary]=[]
	for seed: int in 4:
		var outer:=PackedVector3Array(); var inner:=PackedVector3Array(); var core:=PackedVector3Array()
		for i: int in SEGMENTS:
			var angle: float=TAU*float(i)/SEGMENTS
			var variation: float=fmod(absf(sin((i+1)*17.13+(seed+1)*9.73)*437.19),1.0)
			var direction:=Vector3(cos(angle),sin(angle),0)
			outer.append(direction*RADIUS*(1.0 if i%9==0 else .86+.14*variation))
			inner.append(direction*.017*(.87+.21*variation))
			core.append(direction*.014*(.88+.15*variation)+Vector3(-.001,.001,0))
		var vertices:=PackedVector3Array(); var colors:=PackedColorArray(); var indices:=PackedInt32Array()
		for i: int in SEGMENTS:
			vertices.append(outer[i]); vertices.append(inner[i])
			var angle: float=TAU*float(i)/SEGMENTS
			# Broken bevel: bright upper chips, shaded cavity side. Each source
			# surface's material color still supplies masonry/metal/wood palette.
			var facet: float=.48+.45*maxf(0.0,sin(angle+.7))
			colors.append(Color(facet,facet,facet,1)); colors.append(Color(.32,.30,.27,1))
		for i: int in SEGMENTS:
			if (i+seed*3)%7==0: continue # chipped gaps, not a perfect target ring
			var a:=i*2; var b:=((i+1)%SEGMENTS)*2
			indices.append_array([a,b,a+1,b,b+1,a+1])
		variants.append({"back":_disk(outer),"rim":_mesh(vertices,colors,indices),"core":_disk(core)})
	return variants
