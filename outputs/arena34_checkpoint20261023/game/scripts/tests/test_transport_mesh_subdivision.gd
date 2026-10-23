extends SceneTree

const Subdivision = preload("res://scripts/transport/transport_mesh_subdivision.gd")
const FIXTURE := "res://data/transport/mesh_subdivision_oracle.json"
const NAMES := {"position":Mesh.ARRAY_VERTEX,"normal":Mesh.ARRAY_NORMAL,"tangent":Mesh.ARRAY_TANGENT,"color":Mesh.ARRAY_COLOR,"uv":Mesh.ARRAY_TEX_UV,"uv2":Mesh.ARRAY_TEX_UV2}

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:
		print("TRANSPORT_MESH_SUBDIVISION fixture parse failed"); quit(1); return
	var built := _mesh(fixture.input)
	if not built.ok:
		print("TRANSPORT_MESH_SUBDIVISION input failed ",built); quit(1); return
	var original: ArrayMesh = built.mesh
	var original_vertices := original.surface_get_array_len(0)
	var original_indices := original.surface_get_array_index_len(0)
	var measured_us := 0
	for oracle: Dictionary in fixture.cases:
		var started := Time.get_ticks_usec()
		var result: Dictionary = Subdivision.subdivide(original,float(oracle.max_edge_m),int(oracle.max_triangles))
		measured_us += Time.get_ticks_usec()-started
		_check(result.get("ok",false),oracle.id+": result")
		if not result.get("ok",false): continue
		var mesh: ArrayMesh = result.mesh
		_check(int(result.triangles)==int(oracle.output_triangle_count),oracle.id+": triangle count")
		_check(mesh.get_surface_count()==oracle.surfaces.size(),oracle.id+": surface count")
		for surface in mini(mesh.get_surface_count(),oracle.surfaces.size()):
			var expected: Dictionary=oracle.surfaces[surface]
			_check(mesh.surface_get_material(surface)==built.materials[surface],oracle.id+": material "+str(surface))
			_check(mesh.surface_get_array_index_len(surface)==0,oracle.id+": nonindexed "+str(surface))
			_check(mesh.surface_get_array_len(surface)==int(expected.vertex_count),oracle.id+": vertex count "+str(surface))
			var arrays:=mesh.surface_get_arrays(surface)
			for name: String in expected.attributes:
				var actual:=_flat(arrays[NAMES[name]],NAMES[name])
				var wanted: Array=expected.attributes[name].values
				_check(actual.size()==wanted.size(),oracle.id+": "+name+" size")
				var tolerance := _tolerance(name)
				for i in mini(actual.size(),wanted.size()):
					checks+=1
					if absf(float(actual[i])-float(wanted[i])) > tolerance:
						failures.append(oracle.id+": "+name+"["+str(i)+"] "+str(actual[i])+" != "+str(wanted[i])); break
	_check(original.surface_get_array_len(0)==original_vertices and original.surface_get_array_index_len(0)==original_indices,"input immutable")
	var invalid:=ArrayMesh.new(); var line_arrays: Array=[]; line_arrays.resize(Mesh.ARRAY_MAX); line_arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.ONE])
	invalid.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,line_arrays)
	_check(not Subdivision.subdivide(invalid).ok,"reject non-triangles")
	var skinned := ArrayMesh.new()
	var skin_arrays: Array = []
	skin_arrays.resize(Mesh.ARRAY_MAX)
	skin_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	skin_arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	skin_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0])
	skinned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, skin_arrays)
	_check(skinned.get_surface_count() == 1, "skinned fixture")
	_check(not Subdivision.subdivide(skinned).ok, "reject skin attributes")
	print("TRANSPORT_MESH_SUBDIVISION ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"cases":fixture.cases.size(),"source":fixture.source,"preprocess_total_us":measured_us,"scope":"pure pre-impact ArrayMesh preparation; no physics/render/GPU"}))
	quit(0 if failures.is_empty() else 1)

func _mesh(input: Dictionary) -> Dictionary:
	var mesh:=ArrayMesh.new(); var materials: Array[Material]=[]
	for group: Dictionary in input.groups:
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		for name: String in input.attributes:
			var row: Dictionary=input.attributes[name]; arrays[NAMES[name]]=_packed(name,row.values)
		var source_indices: Array=input.indices; var indices:=PackedInt32Array()
		for i in range(int(group.start),int(group.start)+int(group.count)): indices.append(int(source_indices[i]))
		arrays[Mesh.ARRAY_INDEX]=indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material:=StandardMaterial3D.new(); material.set_meta("oracle_material",int(group.material_index)); materials.append(material)
		var surface:=mesh.get_surface_count()-1; mesh.surface_set_material(surface,material); mesh.surface_set_name(surface,"material_"+str(group.material_index))
	return {"ok":true,"mesh":mesh,"materials":materials}

func _packed(name: String, values: Array) -> Variant:
	match name:
		"position","normal":
			var out := PackedVector3Array()
			for i in range(0, values.size(), 3):
				out.append(Vector3(float(values[i]), float(values[i + 1]), float(values[i + 2])))
			return out
		"tangent":
			var out := PackedFloat32Array()
			for value in values:
				out.append(float(value))
			return out
		"color":
			var out := PackedColorArray()
			for i in range(0, values.size(), 4):
				out.append(Color(float(values[i]), float(values[i + 1]), float(values[i + 2]), float(values[i + 3])))
			return out
		"uv","uv2":
			var out := PackedVector2Array()
			for i in range(0, values.size(), 2):
				out.append(Vector2(float(values[i]), float(values[i + 1])))
			return out
	return null

func _flat(value: Variant, slot: int) -> Array:
	var out: Array=[]
	match slot:
		Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL:
			for v: Vector3 in value: out.append_array([v.x,v.y,v.z])
		Mesh.ARRAY_TANGENT:
			for v in value: out.append(v)
		Mesh.ARRAY_COLOR:
			for v: Color in value: out.append_array([v.r,v.g,v.b,v.a])
		Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2:
			for v: Vector2 in value: out.append_array([v.x,v.y])
	return out

func _tolerance(name: String) -> float:
	if name == "color":
		return 1.0 / 255.0 + 0.000001
	if name == "normal" or name == "tangent":
		return 0.00005
	return 0.000002

func _check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
