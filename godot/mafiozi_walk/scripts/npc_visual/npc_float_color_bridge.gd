extends RefCounted
## Source-preserving COLOR_0 transport only. Shader binding stays caller-owned.
const Loader=preload("res://scripts/npc_visual/npc_visual_loader.gd")
const POSITION_TOL:=0.000002
const NORMAL_TOL:=0.0002
const UV_TOL:=0.0005
const WEIGHT_TOL:=1.0/65535.0+0.000001

static func hold(reason:String)->Dictionary:return {"ok":false,"hold":true,"error":reason}
static func _component_error(a:Vector3,b:Vector3)->float:return maxf(absf(a.x-b.x),maxf(absf(a.y-b.y),absf(a.z-b.z)))
static func _decode(data:Dictionary,bin:PackedByteArray,index:int)->Dictionary:
	if index<0 or index>=data.accessors.size():return hold("accessor_reference")
	var accessor:Dictionary=data.accessors[index]
	if accessor.get("normalized",false) or accessor.has("sparse"):return hold("normalized_or_sparse_accessor")
	var widths:Dictionary={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
	var sizes:Dictionary={5121:1,5123:2,5125:4,5126:4}
	if not sizes.has(int(accessor.componentType)) or not widths.has(accessor.type):return hold("accessor_encoding")
	var width:int=widths[accessor.type]
	var size:int=sizes[int(accessor.componentType)]
	var view:Dictionary=data.bufferViews[int(accessor.bufferView)]
	var base:int=int(view.get("byteOffset",0))+int(accessor.get("byteOffset",0))
	var stride:int=int(view.get("byteStride",width*size))
	var values:PackedFloat64Array=[]
	var count:int=int(accessor.count)*width
	if int(accessor.componentType)==5126 and stride==width*size:
		values=PackedFloat64Array(Array(bin.slice(base,base+count*4).to_float32_array()))
		for value in values:
			if not is_finite(value):return hold("nonfinite_accessor")
		return {"ok":true,"values":values,"count":int(accessor.count),"width":width,"component_type":5126,"byte_offset":base,"stride":stride}
	values.resize(count)
	for vertex in int(accessor.count):
		for channel in width:
			var at:int=base+vertex*stride+channel*size
			var value:float
			match int(accessor.componentType):
				5121:value=bin[at]
				5123:value=bin.decode_u16(at)
				5125:value=bin.decode_u32(at)
				5126:value=bin.decode_float(at)
			if not is_finite(value):return hold("nonfinite_accessor")
			values[vertex*width+channel]=value
	return {"ok":true,"values":values,"count":int(accessor.count),"width":width,"component_type":int(accessor.componentType),"byte_offset":base,"stride":stride}
static func _cached_decode(data:Dictionary,bin:PackedByteArray,index:int,cache:Dictionary)->Dictionary:
	if not cache.has(index):cache[index]=_decode(data,bin,index)
	return cache[index]

static func _array_hash(arrays:Array)->String:return Loader._hash(var_to_bytes(arrays))
static func _vec(values:PackedFloat64Array,index:int)->Vector3:return Vector3(values[index*3],values[index*3+1],values[index*3+2])
static func _mesh_signature(mesh:ArrayMesh)->String:return Loader._hash(var_to_bytes([mesh.get("_surfaces"),mesh.custom_aabb,mesh.shadow_mesh.get_instance_id() if mesh.shadow_mesh!=null else 0]))
static func _skin_signature(skin:Skin)->String:
	if skin==null:return "none"
	var binds:Array=[]
	for i in skin.get_bind_count():binds.append([skin.get_bind_name(i),skin.get_bind_bone(i),skin.get_bind_pose(i)])
	return Loader._hash(var_to_bytes(binds))
static func _matrix(v:PackedFloat64Array,i:int)->Transform3D:
	var at:=i*16
	return Transform3D(Basis(Vector3(v[at],v[at+1],v[at+2]),Vector3(v[at+4],v[at+5],v[at+6]),Vector3(v[at+8],v[at+9],v[at+10])),Vector3(v[at+12],v[at+13],v[at+14]))

static func _prepare_surface(instance:MeshInstance3D,surface:int,primitive:Dictionary,data:Dictionary,bin:PackedByteArray,cache:Dictionary)->Dictionary:
	var mesh:ArrayMesh=instance.mesh
	if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or primitive.get("mode",4)!=4 or not primitive.has("indices"):return hold("triangle_index_contract")
	var attrs:Dictionary=primitive.attributes
	if not attrs.has("COLOR_0"):return {"ok":true,"unchanged":true}
	for key in attrs:
		if not key in ["POSITION","NORMAL","TEXCOORD_0","COLOR_0","JOINTS_0","WEIGHTS_0"]:return hold("unknown_source_attribute_"+key)
	var decoded:Dictionary={}
	for key in attrs:
		var result:Dictionary=_cached_decode(data,bin,int(attrs[key]),cache)
		if not result.ok:return result
		decoded[key]=result
	var index_result:=_cached_decode(data,bin,int(primitive.indices),cache)
	if not index_result.ok:return index_result
	if index_result.width!=1 or index_result.component_type==5126:return hold("index_encoding")
	var position:Dictionary=decoded.get("POSITION",{})
	var normal:Dictionary=decoded.get("NORMAL",{})
	var color:Dictionary=decoded.COLOR_0
	var position_values:PackedFloat64Array=position.get("values",PackedFloat64Array())
	var normal_values:PackedFloat64Array=normal.get("values",PackedFloat64Array())
	var color_values:PackedFloat64Array=color.values
	if position.get("width")!=3 or position.get("component_type")!=5126 or normal.get("width")!=3 or normal.get("component_type")!=5126 or color.width!=4 or color.component_type!=5126:return hold("source_attribute_layout")
	for key in decoded:
		if decoded[key].count!=position.count:return hold("source_attribute_vertex_count")
	for vertex in color.count:
		if color_values[vertex*4+3]!=1.0:return hold("nonopaque_source_vertex_alpha")
	var arrays:Array=mesh.surface_get_arrays(surface)
	for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
		if arrays[custom]!=null and arrays[custom].size()>0:return hold("existing_custom_attribute")
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	if normals.size()!=vertices.size() or colors.size()!=vertices.size() or indices.size()!=index_result.count or indices.size()%3!=0:return hold("native_surface_layout")
	if mesh.get_blend_shape_count()!=0:return hold("blend_shapes")
	if not RenderingServer.mesh_get_surface(mesh.get_rid(),surface).get("lods",{}).is_empty():return hold("native_lods")
	var skeleton:Skeleton3D=null
	var source_joint_names:Array[String]=[];var native_bind_names:Array[String]=[]
	var native_bones:PackedInt32Array=[];var native_weights:PackedFloat32Array=[]
	var source_joints:PackedFloat64Array=[];var source_weights:PackedFloat64Array=[]
	if instance.skin!=null:
		skeleton=instance.get_node_or_null(instance.skeleton) as Skeleton3D
		if skeleton==null or not decoded.has("JOINTS_0") or not decoded.has("WEIGHTS_0"):return hold("skin_contract")
		if decoded.JOINTS_0.width!=4 or decoded.WEIGHTS_0.width!=4 or decoded.WEIGHTS_0.component_type!=5126:return hold("skin_attribute_layout")
		if arrays[Mesh.ARRAY_BONES].size()!=vertices.size()*4 or arrays[Mesh.ARRAY_WEIGHTS].size()!=vertices.size()*4:return hold("native_skin_slot_count")
		native_bones=arrays[Mesh.ARRAY_BONES];native_weights=arrays[Mesh.ARRAY_WEIGHTS]
		source_joints=decoded.JOINTS_0.values;source_weights=decoded.WEIGHTS_0.values
		var inverse_binds:=_cached_decode(data,bin,int(data.skins[0].inverseBindMatrices),cache)
		if not inverse_binds.ok or inverse_binds.width!=16 or inverse_binds.component_type!=5126 or instance.skin.get_bind_count()!=data.skins[0].joints.size():return hold("inverse_bind_contract")
		var native_by_name:Dictionary={}
		for bind in instance.skin.get_bind_count():
			var native_name:String=instance.skin.get_bind_name(bind)
			if native_name.is_empty():native_name=skeleton.get_bone_name(instance.skin.get_bind_bone(bind))
			if native_by_name.has(native_name):return hold("ambiguous_native_bind_palette")
			native_by_name[native_name]=bind;native_bind_names.append(native_name)
		for source_joint in data.skins[0].joints.size():
			var source_name:String=data.nodes[int(data.skins[0].joints[source_joint])].get("name","")
			source_joint_names.append(source_name)
			if not native_by_name.has(source_name) or not instance.skin.get_bind_pose(native_by_name[source_name]).is_equal_approx(_matrix(inverse_binds.values,source_joint)):return hold("source_inverse_bind_mismatch")
	elif decoded.has("JOINTS_0") or decoded.has("WEIGHTS_0"):return hold("unexpected_source_skin")
	var mapping:PackedInt32Array=[]
	mapping.resize(vertices.size());mapping.fill(-1)
	var max_position:=0.0;var max_normal:=0.0;var max_uv:=0.0;var max_weight:=0.0;var max_clamped_color:=0.0
	var index_values:PackedFloat64Array=index_result.values
	var uv_values:PackedFloat64Array=decoded.TEXCOORD_0.values if decoded.has("TEXCOORD_0") else PackedFloat64Array()
	var native_uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
	if decoded.has("TEXCOORD_0") and (decoded.TEXCOORD_0.width!=2 or native_uv.size()!=vertices.size()):return hold("uv_contract")
	for corner in indices.size():
		# Source GLB triangles are CCW; native importer stores CW [0,2,1].
		var remainder:int=corner%3
		var native_corner:int=corner if remainder==0 else (corner+1 if remainder==1 else corner-1)
		var ni:int=indices[native_corner]
		var si:int=int(index_values[corner])
		if ni<0 or ni>=vertices.size() or si<0 or si>=position.count:return hold("triangle_index_range")
		if mapping[ni]!=-1:
			if mapping[ni]!=si:return hold("ambiguous_compacted_vertex")
			continue # Topology checked at every corner; attributes once per exact pair.
		mapping[ni]=si
		max_position=maxf(max_position,_component_error(vertices[ni],_vec(position_values,si)))
		var source_normal:=_vec(normal_values,si)
		if source_normal.length_squared()<0.00000001:return hold("used_zero_source_normal")
		max_normal=maxf(max_normal,_component_error(normals[ni],source_normal))
		for channel in 4:
			max_clamped_color=maxf(max_clamped_color,absf(colors[ni][channel]-clampf(color_values[si*4+channel],0.0,1.0)))
		if decoded.has("TEXCOORD_0"):
			var uv:Vector2=native_uv[ni]
			max_uv=maxf(max_uv,maxf(absf(uv.x-uv_values[si*2]),absf(uv.y-uv_values[si*2+1])))
		if skeleton!=null:
			for slot in 4:
				var native_weight:float=native_weights[ni*4+slot]
				var source_weight:float=source_weights[si*4+slot]
				max_weight=maxf(max_weight,absf(native_weight-source_weight))
				if source_weight>0:
					var source_joint:int=int(source_joints[si*4+slot])
					var native_bind:int=native_bones[ni*4+slot]
					if source_joint<0 or source_joint>=source_joint_names.size() or native_bind<0 or native_bind>=native_bind_names.size():return hold("skin_palette_range")
					if source_joint_names[source_joint]!=native_bind_names[native_bind]:return hold("weighted_skin_palette_mismatch")
	if max_position>POSITION_TOL or max_normal>NORMAL_TOL or max_uv>UV_TOL or max_weight>WEIGHT_TOL or max_clamped_color>1.0/255.0+0.000001:return hold("imported_attribute_mismatch:"+str([max_position,max_normal,max_uv,max_weight,max_clamped_color]))
	var raw:PackedFloat32Array=[]
	raw.resize(mapping.size()*4)
	var min_color:=INF;var max_color:=-INF;var outside:=0
	for ni in mapping.size():
		if mapping[ni]<0:return hold("unmapped_native_orphan_vertex")
		for channel in 4:
			var value:float=color_values[mapping[ni]*4+channel]
			raw[ni*4+channel]=value;min_color=minf(min_color,value);max_color=maxf(max_color,value)
			if value<0.0 or value>1.0:outside+=1
	var result_arrays:Array=arrays.duplicate(true)
	result_arrays[Mesh.ARRAY_CUSTOM0]=raw
	return {"ok":true,"arrays":result_arrays,"original_arrays_sha256":_array_hash(arrays),"raw_custom0_sha256":Loader._hash(raw.to_byte_array()),"native_to_source":mapping,"vertices":mapping.size(),"source_vertices":position.count,"corners":indices.size(),"min":min_color,"max":max_color,"outside_unit_values":outside,"max_position_error":max_position,"max_normal_error":max_normal,"max_uv_error":max_uv,"max_weight_error":max_weight,"max_clamped_color_error":max_clamped_color}

static func prepare(visual:Node3D,verified_glb_bytes:PackedByteArray,expected_asset_sha256:String)->Dictionary:
	if visual==null or not Loader._valid_hash(expected_asset_sha256) or Loader._hash(verified_glb_bytes)!=expected_asset_sha256:return hold("verified_asset_fingerprint")
	if verified_glb_bytes.size()<28 or verified_glb_bytes.size()>Loader.MAX_ASSET_BYTES or verified_glb_bytes.decode_u32(0)!=0x46546c67 or verified_glb_bytes.decode_u32(4)!=2 or verified_glb_bytes.decode_u32(8)!=verified_glb_bytes.size():return hold("verified_glb_header")
	if visual.has_meta("npc_asset_sha256") and visual.get_meta("npc_asset_sha256")!=expected_asset_sha256:return hold("visual_asset_fingerprint")
	var admitted:=Loader._admit_container(verified_glb_bytes)
	if not admitted.ok:return hold("source_container:"+admitted.error)
	var json_size:=verified_glb_bytes.decode_u32(12)
	var data:Dictionary=JSON.parse_string(verified_glb_bytes.slice(20,20+json_size).get_string_from_utf8())
	var bin:=verified_glb_bytes.slice(28+json_size)
	var source_by_key:Dictionary={}
	var source_ids:Dictionary={}
	for node:Dictionary in data.nodes:
		if node.get("extras",{}).has("npcId"):source_ids[str(node.extras.npcId)]=true
		if not node.has("mesh"):continue
		var key:String=node.get("extras",{}).get("npc_visual_source_mesh_key","")
		if key.is_empty() or source_by_key.has(key):return hold("source_mesh_key_identity")
		source_by_key[key]=data.meshes[int(node.mesh)]
	if source_ids.size()!=1 or not source_ids.has(str(visual.get_meta("npc_bridge_id",""))):return hold("visual_bridge_identity")
	var native_by_key:Dictionary={};var pending:Array[Node]=[visual]
	while not pending.is_empty():
		var node:Node=pending.pop_back()
		if node is MeshInstance3D:
			var key:String=node.get_meta("extras",{}).get("npc_visual_source_mesh_key","")
			if key.is_empty() or native_by_key.has(key) or not source_by_key.has(key) or not node.mesh is ArrayMesh:return hold("native_mesh_key_identity")
			native_by_key[key]=node
		for child in node.get_children():pending.append(child)
	if native_by_key.size()!=source_by_key.size():return hold("mesh_instance_coverage")
	var prepared:Array=[];var receipts:Array=[];var accessor_cache:Dictionary={}
	for key:String in source_by_key:
		var instance:MeshInstance3D=native_by_key[key]
		var old:ArrayMesh=instance.mesh
		var primitives:Array=source_by_key[key].primitives
		if old.get_surface_count()!=primitives.size():return hold("primitive_surface_count")
		var surfaces:Array=[];var changed:=false
		for surface in primitives.size():
			var part:=_prepare_surface(instance,surface,primitives[surface],data,bin,accessor_cache)
			if not part.ok:return hold(str(key)+":"+part.error)
			surfaces.append(part)
			if not part.get("unchanged",false):changed=true
		if not changed:continue
		var replacement:=ArrayMesh.new()
		replacement.resource_name=old.resource_name
		var stored:Variant=old.get("_surfaces")
		if not stored is Array or stored.size()!=surfaces.size():return hold("packed_storage_unavailable")
		var new_storage:Array=stored.duplicate(true)
		for surface in surfaces.size():
			var part:Dictionary=surfaces[surface]
			var arrays:Array=old.surface_get_arrays(surface) if part.get("unchanged",false) else part.arrays
			if part.get("unchanged",false):continue
			# Preserve native packed normals/tangents/skin/index buffers exactly.
			# add_surface_from_arrays would decode/re-encode oct normals and drift.
			var original:Dictionary=stored[surface]
			var count:int=original.vertex_count
			var old_format:int=original.format
			var new_format:int=old_format|Mesh.ARRAY_FORMAT_CUSTOM0|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			var old_stride:int=RenderingServer.mesh_surface_get_format_attribute_stride(old_format,count)
			var new_stride:int=RenderingServer.mesh_surface_get_format_attribute_stride(new_format,count)
			var offset:int=RenderingServer.mesh_surface_get_format_offset(new_format,count,Mesh.ARRAY_CUSTOM0)
			if new_stride!=old_stride+16 or offset!=old_stride or original.attribute_data.size()!=old_stride*count:return hold("packed_attribute_layout")
			for attr in [Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
				if RenderingServer.mesh_surface_get_format_offset(old_format,count,attr)!=RenderingServer.mesh_surface_get_format_offset(new_format,count,attr):return hold("packed_existing_attribute_offset")
			var raw:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
			var custom_bytes:PackedByteArray=raw.to_byte_array()
			var old_attributes:PackedByteArray=original.attribute_data
			var attribute_bytes:PackedByteArray=[]
			for vertex in count:
				var src:int=vertex*old_stride;var custom_src:int=vertex*16
				attribute_bytes.append_array(old_attributes.slice(src,src+old_stride))
				attribute_bytes.append_array(custom_bytes.slice(custom_src,custom_src+16))
			new_storage[surface].format=new_format
			new_storage[surface].attribute_data=attribute_bytes
		replacement.set("_surfaces",new_storage)
		if replacement.get_surface_count()!=surfaces.size():return hold("packed_surface_construction_failed")
		for surface in surfaces.size():
			var part:Dictionary=surfaces[surface]
			var arrays:Array=old.surface_get_arrays(surface) if part.get("unchanged",false) else part.arrays
			var reread:Array=replacement.surface_get_arrays(surface)
			for attribute in Mesh.ARRAY_MAX:
				if attribute==Mesh.ARRAY_CUSTOM0:continue
				if reread[attribute]!=arrays[attribute]:return hold("repack_changed_native_attribute:"+str(attribute))
			if not part.get("unchanged",false) and reread[Mesh.ARRAY_CUSTOM0]!=arrays[Mesh.ARRAY_CUSTOM0]:return hold("float_custom0_roundtrip")
		replacement.custom_aabb=old.custom_aabb
		replacement.shadow_mesh=old.shadow_mesh
		prepared.append({"instance":weakref(instance),"source_mesh_key":key,"original_skeleton_path":instance.skeleton,"original_parent_id":instance.get_parent().get_instance_id(),"original_mesh":old,"original_mesh_signature":_mesh_signature(old),"original_skin":instance.skin,"original_skin_signature":_skin_signature(instance.skin),"replacement_mesh":replacement,"replacement_signature":_mesh_signature(replacement)})
		for surface in surfaces.size():
			var part:Dictionary=surfaces[surface]
			if part.get("unchanged",false):continue
			var receipt:Dictionary=part.duplicate(true);receipt.erase("arrays")
			receipt.source_mesh_key=key;receipt.surface=surface;receipt.asset_sha256=expected_asset_sha256
			receipts.append(receipt)
	return {"ok":true,"prepared":prepared,"receipts":receipts,"asset_sha256":expected_asset_sha256,"shader_bound":false,"material_fidelity":"HOLD"}

static func apply(plan:Dictionary)->Dictionary:
	if not plan.get("ok",false) or not plan.get("prepared") is Array or not plan.get("receipts") is Array:return hold("unprepared_plan")
	for value:Variant in plan.prepared:
		if not value is Dictionary:return hold("malformed_prepared_item")
		var item:Dictionary=value
		if not item.get("instance") is WeakRef or not item.get("original_mesh") is ArrayMesh or not item.get("replacement_mesh") is ArrayMesh or not item.get("source_mesh_key") is String or not item.get("original_skeleton_path") is NodePath or not item.get("original_parent_id") is int or not item.get("original_mesh_signature") is String or not item.get("original_skin_signature") is String or not item.get("replacement_signature") is String or not item.has("original_skin") or (item.original_skin!=null and not item.original_skin is Skin):return hold("malformed_prepared_item")
		if not item.instance.get_ref() is MeshInstance3D:return hold("malformed_instance_reference")
		var instance:MeshInstance3D=item.instance.get_ref()
		if instance==null or instance.mesh!=item.original_mesh:return hold("stale_private_mesh")
		if instance.get_meta("extras",{}).get("npc_visual_source_mesh_key","")!=item.source_mesh_key or instance.skeleton!=item.original_skeleton_path or instance.get_parent()==null or instance.get_parent().get_instance_id()!=item.original_parent_id:return hold("stale_node_mapping")
		if _mesh_signature(instance.mesh)!=item.original_mesh_signature or instance.skin!=item.original_skin or _skin_signature(instance.skin)!=item.original_skin_signature:return hold("stale_mesh_or_skin_payload")
		if _mesh_signature(item.replacement_mesh)!=item.replacement_signature:return hold("prepared_payload_changed")
	for item:Dictionary in plan.prepared:
		var instance:MeshInstance3D=item.instance.get_ref()
		instance.mesh=item.replacement_mesh
	return {"ok":true,"mesh_count":plan.prepared.size(),"receipts":plan.receipts,"shader_bound":false,"material_fidelity":"HOLD"}
