extends RefCounted
## SHA-bound preparation of the two private per-car source mark resources.
## This creates resources only; the host owns the bounded 32 MeshInstance pool.

const DEFAULT_PATH="res://data/transport/damage_mark_geometry.json"
const FIXTURE_SHA="d05b5114ef6ada70e8690f99752052ac00121aaf774ac6a1bae874c1edd46bf0"
const SOURCE_SHA="e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92"
const MAX_FILE_BYTES:=524288
const MAX_VERTICES:=1024
const POOL_SIZE:=32

static func prepare(path: String=DEFAULT_PATH) -> Dictionary:
	if path!=DEFAULT_PATH: return _error("path")
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or bytes.size()>MAX_FILE_BYTES: return _error("file")
	if _sha(bytes)!=FIXTURE_SHA: return _error("sha")
	var parsed: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary: return _error("json")
	var fixture: Dictionary=parsed
	if fixture.get("schema","")!="mafiozi.transport-damage-mark-geometry.v1": return _error("schema")
	if not fixture.has("source") or not fixture.source is Dictionary or not fixture.source.has("vehicle_damage") or fixture.source.vehicle_damage.get("sha256","")!=SOURCE_SHA or fixture.source.get("three_revision","")!="180": return _error("source")
	if not fixture.has("slot_types") or not fixture.slot_types is Array or fixture.slot_types.size()!=POOL_SIZE: return _error("slots")
	for i in POOL_SIZE:
		if fixture.slot_types[i]!=("scratch" if i%3==0 else "crater"): return _error("slots")
	if not fixture.has("geometries") or not fixture.geometries is Dictionary or not fixture.has("materials") or not fixture.materials is Dictionary: return _error("resources")
	var scratch_material_result:=_material(fixture.materials.get("scratch")); if not scratch_material_result.ok: return scratch_material_result
	var crater_material_result:=_material(fixture.materials.get("crater")); if not crater_material_result.ok: return crater_material_result
	var scratch_mesh_result:=_mesh(fixture.geometries.get("scratch"),scratch_material_result.material); if not scratch_mesh_result.ok: return scratch_mesh_result
	var crater_mesh_result:=_mesh(fixture.geometries.get("crater"),crater_material_result.material); if not crater_mesh_result.ok: return crater_mesh_result
	return {
		"ok":true,
		"meshes":{"scratch":scratch_mesh_result.mesh,"crater":crater_mesh_result.mesh},
		"materials":{"scratch":scratch_material_result.material,"crater":crater_material_result.material},
		"source_buffers":{"scratch":scratch_mesh_result.source_buffers,"crater":crater_mesh_result.source_buffers},
		"slot_types":fixture.slot_types.duplicate(),
		"limitations":["Three polygonOffset/polygonOffsetFactor has no exact StandardMaterial3D equivalent; native raster bias remains an integration limitation","ArrayMesh stores standard normals in octahedral form and vertex colors as RGBA8; exact source Float32 buffers are retained separately"],
		"source_sha":SOURCE_SHA,"fixture_sha":FIXTURE_SHA,
	}

static func _mesh(value: Variant,material: StandardMaterial3D) -> Dictionary:
	if not value is Dictionary or value.get("primitive","")!="triangles": return _error("geometry")
	var position_result:=_attribute(value.get("position"),3,"Float32Array",false); if not position_result.ok: return position_result
	var positions: PackedFloat32Array=position_result.values; var vertex_count:=positions.size()/3
	if vertex_count<3 or vertex_count>MAX_VERTICES: return _error("geometry")
	var normal_result:=_attribute(value.get("normal"),3,"Float32Array",false); if not normal_result.ok or normal_result.values.size()!=positions.size(): return _error("normal")
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array(); var normals:=PackedVector3Array(); vertices.resize(vertex_count); normals.resize(vertex_count)
	for i in vertex_count:
		vertices[i]=Vector3(positions[i*3],positions[i*3+1],positions[i*3+2]); normals[i]=Vector3(normal_result.values[i*3],normal_result.values[i*3+1],normal_result.values[i*3+2])
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	if value.get("color")!=null:
		var color_result:=_attribute(value.color,3,"Float32Array",false); if not color_result.ok or color_result.values.size()!=positions.size(): return _error("color")
		var colors:=PackedColorArray(); colors.resize(vertex_count)
		for i in vertex_count: colors[i]=Color(color_result.values[i*3],color_result.values[i*3+1],color_result.values[i*3+2],1.0)
		arrays[Mesh.ARRAY_COLOR]=colors
	if value.get("uv")!=null:
		var uv_result:=_attribute(value.uv,2,"Float32Array",false); if not uv_result.ok or uv_result.values.size()!=vertex_count*2: return _error("uv")
		var uvs:=PackedVector2Array(); uvs.resize(vertex_count)
		for i in vertex_count: uvs[i]=Vector2(uv_result.values[i*2],uv_result.values[i*2+1])
		arrays[Mesh.ARRAY_TEX_UV]=uvs
	var source_indices:=PackedInt32Array()
	if value.get("index")!=null:
		var index_result:=_attribute(value.index,1,"Uint16Array",true); if not index_result.ok or index_result.values.size()%3!=0: return _error("index")
		source_indices.resize(index_result.values.size())
		for i in source_indices.size():
			var index:=int(index_result.values[i]); if index<0 or index>=vertex_count: return _error("index")
			source_indices[i]=index
	elif vertex_count%3!=0: return _error("geometry")
	var native_indices:=PackedInt32Array()
	if source_indices.is_empty():
		native_indices.resize(vertex_count)
		for triangle in vertex_count/3:
			native_indices[triangle*3]=triangle*3; native_indices[triangle*3+1]=triangle*3+2; native_indices[triangle*3+2]=triangle*3+1
	else:
		native_indices=source_indices.duplicate()
		for triangle in native_indices.size()/3:
			var second:=native_indices[triangle*3+1]; native_indices[triangle*3+1]=native_indices[triangle*3+2]; native_indices[triangle*3+2]=second
	arrays[Mesh.ARRAY_INDEX]=native_indices
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,material)
	var source_buffers={"position":positions.duplicate(),"normal":normal_result.values.duplicate(),"color":PackedFloat32Array(),"uv":PackedFloat32Array(),"index":source_indices.duplicate()}
	if value.get("color")!=null: source_buffers.color=_attribute(value.color,3,"Float32Array",false).values.duplicate()
	if value.get("uv")!=null: source_buffers.uv=_attribute(value.uv,2,"Float32Array",false).values.duplicate()
	return {"ok":true,"mesh":mesh,"source_buffers":source_buffers,"vertex_count":vertex_count}

static func _attribute(value: Variant,item_size: int,array_type: String,integer: bool) -> Dictionary:
	if not value is Dictionary or int(value.get("item_size",0))!=item_size or bool(value.get("normalized",true)) or value.get("array_type","")!=array_type or not value.get("array") is Array: return _error("attribute")
	var source: Array=value.array
	if source.is_empty() or source.size()%item_size!=0: return _error("attribute")
	if integer:
		var values:=PackedInt32Array(); values.resize(source.size())
		for i in source.size():
			if not source[i] is int and not (source[i] is float and float(source[i])==floor(float(source[i]))): return _error("attribute")
			values[i]=int(source[i])
		return {"ok":true,"values":values}
	var values:=PackedFloat32Array(); values.resize(source.size())
	for i in source.size():
		if not (source[i] is int or source[i] is float) or not is_finite(float(source[i])): return _error("attribute")
		values[i]=float(source[i])
	return {"ok":true,"values":values}

static func _material(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("type","")!="MeshStandardMaterial" or not value.get("color_linear") is Array or value.color_linear.size()!=3: return _error("material")
	for field in ["roughness","metalness","opacity","polygon_offset_factor","polygon_offset_units"]:
		if not (value.get(field) is int or value.get(field) is float) or not is_finite(float(value[field])): return _error("material")
	for component in value.color_linear:
		if not (component is int or component is float) or not is_finite(float(component)): return _error("material")
	if not value.get("transparent") is bool or not value.get("depth_write") is bool or not value.get("vertex_colors") is bool or not value.get("polygon_offset") is bool: return _error("material")
	if float(value.roughness)<0.0 or float(value.roughness)>1.0 or float(value.metalness)<0.0 or float(value.metalness)>1.0 or float(value.opacity)<0.0 or float(value.opacity)>1.0 or int(value.get("side",-1))!=0: return _error("material")
	if not bool(value.transparent) or bool(value.depth_write) or not bool(value.polygon_offset) or float(value.polygon_offset_factor)!=-2.0 or float(value.polygon_offset_units)!=0.0: return _error("material_semantics")
	var linear_color:=Color(float(value.color_linear[0]),float(value.color_linear[1]),float(value.color_linear[2]),float(value.opacity))
	var material:=StandardMaterial3D.new(); material.albedo_color=linear_color.linear_to_srgb(); material.albedo_color.a=float(value.opacity); material.roughness=float(value.roughness); material.metallic=float(value.metalness)
	material.vertex_color_use_as_albedo=bool(value.vertex_colors); material.vertex_color_is_srgb=false; material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED; material.cull_mode=BaseMaterial3D.CULL_BACK
	return {"ok":true,"material":material}

static func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
static func _error(reason: String) -> Dictionary: return {"ok":false,"error":reason}
