extends SceneTree

const Factory=preload("res://scripts/transport/transport_damage_mark_geometry.gd")
const FIXTURE_PATH="res://data/transport/damage_mark_geometry.json"
const FIXTURE_SHA="d05b5114ef6ada70e8690f99752052ac00121aaf774ac6a1bae874c1edd46bf0"
const ITERATIONS:=100

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var bytes:=FileAccess.get_file_as_bytes(FIXTURE_PATH); var fixture: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(_sha(bytes)==FIXTURE_SHA,"pinned actual private-pool geometry fixture")
	check(fixture is Dictionary and fixture.schema=="mafiozi.transport-damage-mark-geometry.v1" and fixture.source.vehicle_damage.sha256==Factory.SOURCE_SHA and fixture.source.three_revision=="180","source and Three receipt")
	var prepared:=Factory.prepare(); check(prepared.ok,"prepare two source resources")
	if not prepared.ok: finish({}); return
	check(prepared.meshes.size()==2 and prepared.materials.size()==2 and prepared.slot_types.size()==32,"bounded two-resource/32-slot contract")
	check(prepared.slot_types==fixture.slot_types and prepared.slot_types.count("scratch")==11 and prepared.slot_types.count("crater")==21,"exact physical slot mapping")
	check(String(prepared.limitations[0]).contains("polygonOffset") and String(prepared.limitations[0]).contains("no exact"),"unsupported raster bias is explicit")
	for kind in ["scratch","crater"]:
		_check_mesh(kind,prepared.meshes[kind],prepared.materials[kind],prepared.source_buffers[kind],fixture.geometries[kind])
		_check_material(kind,prepared.materials[kind],fixture.materials[kind])
	var second:=Factory.prepare(); check(second.ok,"second private preparation")
	check(second.meshes.scratch!=prepared.meshes.scratch and second.meshes.crater!=prepared.meshes.crater and second.materials.scratch!=prepared.materials.scratch and second.materials.crater!=prepared.materials.crater,"resources are private per car, not global or per hit")
	check(Factory.prepare("res://data/transport/local_dent_oracle.json").error=="path","unbound fixture path rejected")
	var begin:=Time.get_ticks_usec(); var total_vertices:=0
	for i in ITERATIONS:
		var sample:=Factory.prepare(); total_vertices+=sample.meshes.scratch.surface_get_array_len(0)+sample.meshes.crater.surface_get_array_len(0)
	var elapsed:=Time.get_ticks_usec()-begin
	check(total_vertices==ITERATIONS*112,"preparation benchmark consumed both meshes")
	finish({"iterations":ITERATIONS,"benchmark_us":elapsed,"us_per_prepare":float(elapsed)/ITERATIONS,"vertices_per_car":112,"resource_count_per_car":4})

func _check_mesh(kind: String,mesh: ArrayMesh,material: StandardMaterial3D,source_buffers: Dictionary,expected: Dictionary) -> void:
	check(mesh.get_surface_count()==1 and mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES,"one triangle surface "+kind)
	check(mesh.surface_get_material(0)==material,"private material bound "+kind)
	var arrays:=mesh.surface_get_arrays(0); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	check(_flatten3(vertices).to_byte_array()==_f32(expected.position.array).to_byte_array(),"exact Float32 positions "+kind)
	check(source_buffers.position.to_byte_array()==_f32(expected.position.array).to_byte_array() and source_buffers.normal.to_byte_array()==_f32(expected.normal.array).to_byte_array(),"exact retained Float32 position/normal source "+kind)
	check(_near_array(_flatten3(normals),_f32(expected.normal.array),1.6e-5),"native octahedral normal representation "+kind)
	var all_xy_plus_z:=true
	for vertex in vertices:
		if absf(vertex.z)>.0011: all_xy_plus_z=false
	for normal in normals:
		if absf(normal.x)>1.6e-5 or absf(normal.y)>1.6e-5 or absf(normal.z-1.0)>1.6e-5: all_xy_plus_z=false
	check(all_xy_plus_z,"complete canonical XY/+Z geometry orientation "+kind)
	if expected.color!=null:
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		check(source_buffers.color.to_byte_array()==_f32(expected.color.array).to_byte_array(),"exact retained Float32 vertex colors "+kind)
		var exact_rgba8:=true
		for i in colors.size():
			for channel in 3:
				var wanted: float=floor(clampf(float(expected.color.array[i*3+channel]),0.0,1.0)*255.0)/255.0
				if absf(colors[i][channel]-wanted)>1e-7: exact_rgba8=false
			if colors[i].a!=1.0: exact_rgba8=false
		check(exact_rgba8,"exact native RGBA8 truncation including alpha "+kind)
	else: check(arrays[Mesh.ARRAY_COLOR]==null,"no invented vertex colors "+kind)
	if expected.uv!=null:
		var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]; var flat:=PackedFloat32Array(); flat.resize(uvs.size()*2)
		for i in uvs.size(): flat[i*2]=uvs[i].x; flat[i*2+1]=uvs[i].y
		check(flat.to_byte_array()==_f32(expected.uv.array).to_byte_array(),"exact Float32 UVs "+kind)
	else: check(arrays[Mesh.ARRAY_TEX_UV]==null,"no invented UVs "+kind)
	var source_indices:=PackedInt32Array()
	if expected.index!=null:
		for value in expected.index.array: source_indices.append(int(value))
	var native_indices:=PackedInt32Array()
	if source_indices.is_empty():
		native_indices.resize(vertices.size())
		for triangle in vertices.size()/3: native_indices[triangle*3]=triangle*3; native_indices[triangle*3+1]=triangle*3+2; native_indices[triangle*3+2]=triangle*3+1
	else:
		native_indices=source_indices.duplicate()
		for triangle in native_indices.size()/3:
			var second:=native_indices[triangle*3+1]; native_indices[triangle*3+1]=native_indices[triangle*3+2]; native_indices[triangle*3+2]=second
	check(source_buffers.index==source_indices,"exact source index order retained "+kind)
	check(arrays[Mesh.ARRAY_INDEX]==native_indices,"Three CCW converted once to Godot clockwise "+kind)
	var clockwise:=true
	for triangle in native_indices.size()/3:
		var a:=vertices[native_indices[triangle*3]]; var b:=vertices[native_indices[triangle*3+1]]; var c:=vertices[native_indices[triangle*3+2]]
		if (b-a).cross(c-a).z>=0.0: clockwise=false
	check(clockwise,"native +Z front-face winding "+kind)

func _check_material(kind: String,material: StandardMaterial3D,expected: Dictionary) -> void:
	var linear:=material.albedo_color.srgb_to_linear()
	check(_near(linear.r,float(expected.color_linear[0])) and _near(linear.g,float(expected.color_linear[1])) and _near(linear.b,float(expected.color_linear[2])) and _near(material.albedo_color.a,float(expected.opacity)),"source linear color through native sRGB material property "+kind)
	check(_near(material.roughness,float(expected.roughness)) and _near(material.metallic,float(expected.metalness)),"roughness/metalness "+kind)
	check(material.vertex_color_use_as_albedo==bool(expected.vertex_colors) and not material.vertex_color_is_srgb and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and material.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK,"native supported material flags "+kind)

func _flatten3(values: PackedVector3Array) -> PackedFloat32Array:
	var result:=PackedFloat32Array(); result.resize(values.size()*3)
	for i in values.size(): result[i*3]=values[i].x; result[i*3+1]=values[i].y; result[i*3+2]=values[i].z
	return result
func _f32(values: Array) -> PackedFloat32Array:
	var result:=PackedFloat32Array(); result.resize(values.size())
	for i in values.size(): result[i]=float(values[i])
	return result
func _near(a: float,b: float) -> bool: return absf(a-b)<=1e-6
func _near_array(actual: PackedFloat32Array,expected: PackedFloat32Array,tolerance: float) -> bool:
	if actual.size()!=expected.size(): return false
	for i in actual.size():
		if absf(actual[i]-expected[i])>tolerance: return false
	return true
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DAMAGE_MARK_GEOMETRY "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fixture_sha":FIXTURE_SHA,"source_sha":Factory.SOURCE_SHA,"metrics":metrics,"scope":"two private prepared resources per car; no nodes, pool runtime, raster-bias claim or authority"}))
	quit(0 if failures.is_empty() else 1)
