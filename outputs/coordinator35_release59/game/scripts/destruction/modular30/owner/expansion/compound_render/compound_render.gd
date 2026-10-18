extends RefCounted
## Node-local render composition only. This grants no damage/material ownership.
## Packed vertex/attribute samples are copied without decoding/re-encoding.
const MAX_SOURCE_TRIANGLES:=65536
const MAX_OUTPUT_TRIANGLES:=131072
const MAX_SOURCE_SURFACES:=64
const MAX_INPUT_SURFACES:=4096
const MAX_OUTPUT_SURFACES:=64
const MAX_REPLACEMENTS:=512
const MAX_COMPONENTS:=512
const MAX_PACKED_BYTES:=67108864
const MAX_ITEMS:=128
const MAX_USEC:=1000
const CHANNELS:=[Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]

class Group extends RefCounted:
	var key: Array=[]
	var descriptor: Dictionary={}
	var position_bytes:=PackedByteArray()
	var normal_bytes:=PackedByteArray()
	var attribute_bytes:=PackedByteArray()
	var vertices:=0
	var triangles:=0
	var bounds:=AABB()
	var initialized:=false
	var roles: Dictionary={}
	var material: Material

class Job extends RefCounted:
	var binding: Dictionary={}
	var replacements: Array=[]
	var stage:="validate"
	var cursor:=0
	var triangle:=0
	var inputs: Array=[]
	var replaced: Dictionary={}
	var replacement_cursor:=0
	var selector_stage:="header"
	var selector_cursor:=0
	var selector_expected:=0
	var guard_cursor:=0
	var after_material_guard:="selectors"
	var groups: Array[Group]=[]
	var group_lookup: Dictionary={}
	var descriptors: Array=[]
	var provenance: Array=[]
	var output_lookup: Array=[]
	var mesh: ArrayMesh
	var input_bytes:=0
	var output_bytes:=0
	var input_triangles:=0
	var output_triangles:=0
	var retained_triangles:=0
	var replaced_triangles:=0
	var dirty:=false
	var watches: Array=[]
	var watched_ids: Dictionary={}
	var original_watch_count:=0
	var result: Dictionary={}
	var diagnostics: Dictionary={"begin_usec":0,"calls":0,"items":0,"total_advance_usec":0,"max_advance_usec":0,"max_item_usec":0,"max_upload_usec":0,"budget_overruns":0,"max_items":0,"stage_usec":{},"cooperative_budget_usec":MAX_USEC,"hard_deadline_guaranteed":false,"loaded_scene_fps_verified":false}
	func changed() -> void: dirty=true
	func watch(resource: Resource) -> void:
		if resource!=null and not watched_ids.has(resource.get_instance_id()):
			watches.append(resource); watched_ids[resource.get_instance_id()]=true; resource.changed.connect(changed)
	func disconnect_watches() -> void:
		for resource: Resource in watches:
			if resource.changed.is_connected(changed): resource.changed.disconnect(changed)
		watches.clear(); watched_ids.clear()

static func _no(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"scene_mutated":false}
static func _absent(value: Variant) -> bool: return value==null or value.is_empty()
static func _material_snapshot(material: Material) -> Dictionary:
	if material==null: return {}
	var saved: Dictionary={}
	for property: Dictionary in material.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_STORAGE:
			var value: Variant=material.get(property.name)
			saved[str(property.name)]=value.duplicate(true) if value is Array or value is Dictionary else value
	return saved

static func capture_binding(source: Dictionary,partition: Dictionary,owner_held_component_ids: Array=[]) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if partition.get("ok")!=true or not partition.get("source_snapshot") is Dictionary or not partition.get("source_components") is Array: return _no("completed_panel_partition_required")
	if partition.source_components.size()>MAX_COMPONENTS or owner_held_component_ids.size()>MAX_COMPONENTS: return _no("component_metadata_budget")
	var saved: Dictionary=partition.source_snapshot
	if source.get("mesh")!=saved.get("mesh") or not saved.get("mesh") is ArrayMesh or str(source.get("source_id",""))!=str(saved.get("source_id","")) or str(source.get("source_part_id",""))!=str(saved.get("source_part_id","")): return _no("source_binding_mismatch")
	if str(source.get("source_id","")).is_empty() or str(source.get("source_part_id","")).is_empty(): return _no("source_identity_required")
	var mesh: ArrayMesh=source.mesh
	if mesh.get_surface_count()<1 or mesh.get_surface_count()>MAX_SOURCE_SURFACES or mesh.get_surface_count()!=saved.surface_arrays.size() or mesh.get_blend_shape_count()!=0 or mesh.shadow_mesh!=null: return _no("source_surface_or_morph_budget")
	var effective: Array=source.get("materials",[])
	if not effective.is_empty() and effective.size()!=mesh.get_surface_count(): return _no("effective_material_count")
	var binding: Dictionary={"ok":true,"source":source,"mesh":mesh,"source_id":str(saved.source_id),"source_part_id":str(saved.source_part_id),"arrays":[],"raw_materials":[],"materials":[],"material_guards":[],"packed_surfaces":[],"formats":[],"names":[],"components":[],"triangle_components":[],"held_components":{},"custom_aabb":mesh.custom_aabb,"lightmap_size_hint":mesh.lightmap_size_hint,"packed_bytes":0,"source_triangles":0}
	var material_ids: Dictionary={}
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _no("source_triangles_required")
		var arrays: Array=mesh.surface_get_arrays(surface)
		if arrays!=saved.surface_arrays[surface]: return _no("source_arrays_changed_since_partition")
		var packed: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
		var guard:=_packed_guard(packed,arrays)
		if not guard.ok: return guard
		var raw_material: Material=mesh.surface_get_material(surface)
		var material: Material=effective[surface] if not effective.is_empty() else raw_material
		if material!=saved.materials[surface]: return _no("source_effective_material_changed_since_partition")
		binding.arrays.append(arrays); binding.raw_materials.append(raw_material); binding.materials.append(material)
		for guarded: Material in [raw_material,material]:
			if guarded!=null and not material_ids.has(guarded.get_instance_id()):
				var snapshot:=_material_snapshot(guarded)
				binding.material_guards.append({"material":guarded,"snapshot":snapshot,"keys":snapshot.keys()}); material_ids[guarded.get_instance_id()]=true
		binding.packed_surfaces.append(packed); binding.formats.append(mesh.surface_get_format(surface)); binding.names.append(mesh.surface_get_name(surface))
		var count: int=guard.triangles
		var owners:=PackedInt32Array(); owners.resize(count); owners.fill(-1); binding.triangle_components.append(owners)
		binding.source_triangles+=count; binding.packed_bytes+=guard.bytes
		if binding.source_triangles>MAX_SOURCE_TRIANGLES or binding.packed_bytes>MAX_PACKED_BYTES: return _no("source_memory_or_triangle_budget")
	for index: int in partition.source_components.size():
		var component: Dictionary=partition.source_components[index]
		if component.get("component_id")!=index or not component.get("source_faces") is Array: return _no("partition_component_identity")
		var faces: Array=component.source_faces.duplicate()
		for face: Variant in faces:
			if not face is Vector2i or face.x<0 or face.x>=binding.triangle_components.size() or face.y<0 or face.y>=binding.triangle_components[face.x].size(): return _no("partition_selector_range")
			if binding.triangle_components[face.x][face.y]!=-1: return _no("partition_duplicate_selector")
			binding.triangle_components[face.x][face.y]=index
		binding.components.append(faces)
	for owners: PackedInt32Array in binding.triangle_components:
		if owners.has(-1): return _no("partition_missing_triangle")
	for id: Variant in owner_held_component_ids:
		if not id is int or id<0 or id>=binding.components.size(): return _no("held_component_id")
		binding.held_components[id]=true
	binding.capture_usec=Time.get_ticks_usec()-started
	return binding

static func _packed_guard(packed: Dictionary,arrays: Array) -> Dictionary:
	var unsupported: int=Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS|Mesh.ARRAY_FORMAT_CUSTOM0|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|Mesh.ARRAY_FORMAT_CUSTOM3|Mesh.ARRAY_FLAG_USE_2D_VERTICES
	if int(packed.get("format",0))&unsupported or not packed.get("lods",[]).is_empty() or not packed.get("blend_shape_data",PackedByteArray()).is_empty(): return _no("unsupported_skin_custom_lod_morph_or_2d")
	if arrays.size()!=Mesh.ARRAY_MAX or _absent(arrays[Mesh.ARRAY_VERTEX]): return _no("vertex_arrays_required")
	var vertices: int=arrays[Mesh.ARRAY_VERTEX].size()
	if vertices>MAX_OUTPUT_TRIANGLES*3: return _no("vertex_budget")
	for slot: int in CHANNELS:
		if not _absent(arrays[slot]) and arrays[slot].size()!=vertices*(4 if slot==Mesh.ARRAY_TANGENT else 1): return _no("attribute_count")
	var count: int=vertices if _absent(arrays[Mesh.ARRAY_INDEX]) else arrays[Mesh.ARRAY_INDEX].size()
	if count%3!=0: return _no("triangle_index_count")
	var size_bytes: int=packed.get("vertex_data",PackedByteArray()).size()+packed.get("attribute_data",PackedByteArray()).size()+packed.get("index_data",PackedByteArray()).size()
	return {"ok":true,"triangles":count/3,"bytes":size_bytes}

static func begin(binding: Dictionary,replacements: Array) -> Job:
	var started:=Time.get_ticks_usec(); var job:=Job.new()
	if binding.get("ok")!=true or not binding.get("mesh") is ArrayMesh or not binding.get("components") is Array or replacements.size()>MAX_REPLACEMENTS:
		_fail(job,"captured_binding_and_bounded_replacements_required"); return job
	job.binding=binding
	# Small references only; dictionaries, watchers and provenance rows are
	# admitted by individual work units. Caller keeps replacement inputs immutable.
	job.replacements=replacements.duplicate()
	job.watch(binding.mesh)
	for material: Material in binding.raw_materials: job.watch(material)
	for material: Material in binding.materials: job.watch(material)
	job.original_watch_count=job.watches.size()
	job.diagnostics.begin_usec=Time.get_ticks_usec()-started
	return job

static func advance(job: Job,maxitems: int=32,budgetusec: int=1000) -> Dictionary:
	if job==null or maxitems<1 or maxitems>MAX_ITEMS or budgetusec<1 or budgetusec>MAX_USEC: return _no("bounded_advance_required")
	if job.stage=="cancelled": return _no("cancelled")
	if job.stage=="done": return {"ok":job.result.ok,"done":true,"result":job.result}
	var started:=Time.get_ticks_usec(); var count:=0
	if job.dirty: _fail(job,"watched_source_or_replacement_changed")
	elif not _source_identity_matches(job.binding): _fail(job,"source_binding_or_effective_material_changed")
	while count<maxitems and job.stage!="done":
		var stage: String=job.stage; var item_started:=Time.get_ticks_usec()
		match stage:
			"validate": _validate_source_one(job,false)
			"material_validate": _validate_material_one(job)
			"replacement_snapshot": _replacement_snapshot_one(job)
			"selectors": _replacement_one(job)
			"inputs": _input_one(job)
			"emit": _emit_one(job)
			"descriptors": _descriptor_one(job)
			"final_validate": _validate_source_one(job,true)
			"upload": _upload(job)
			"release": _release_one(job)
			_: _fail(job,"invalid_stage")
		var elapsed:=Time.get_ticks_usec()-item_started
		job.diagnostics.stage_usec[stage]=int(job.diagnostics.stage_usec.get(stage,0))+elapsed
		job.diagnostics.max_item_usec=maxi(job.diagnostics.max_item_usec,elapsed); count+=1
		# Reserve a measured item-sized headroom; native calls remain indivisible.
		if Time.get_ticks_usec()-started>=maxi(1,budgetusec-mini(200,job.diagnostics.max_item_usec+20)): break
	var elapsed:=Time.get_ticks_usec()-started
	job.diagnostics.calls+=1; job.diagnostics.items+=count; job.diagnostics.total_advance_usec+=elapsed
	job.diagnostics.max_advance_usec=maxi(job.diagnostics.max_advance_usec,elapsed); job.diagnostics.max_items=maxi(job.diagnostics.max_items,count)
	if elapsed>budgetusec: job.diagnostics.budget_overruns+=1
	if job.stage=="done": job.result.diagnostics=job.diagnostics.duplicate(true)
	return {"ok":job.result.get("ok",true),"done":job.stage=="done","result":job.result if job.stage=="done" else {},"stage":job.stage,"items":count,"elapsed_usec":elapsed,"scene_mutated":false}

static func _validate_source_one(job: Job,final: bool) -> void:
	var b: Dictionary=job.binding; var source: Dictionary=b.source; var mesh: ArrayMesh=b.mesh
	if source.get("mesh")!=mesh or str(source.get("source_id",""))!=b.source_id or str(source.get("source_part_id",""))!=b.source_part_id or mesh.get_surface_count()!=b.arrays.size() or mesh.custom_aabb!=b.custom_aabb or mesh.lightmap_size_hint!=b.lightmap_size_hint or mesh.get_blend_shape_count()!=0 or mesh.shadow_mesh!=null:
		_fail(job,"source_binding_or_metadata_changed"); return
	var effective: Variant=source.get("materials",[])
	if not effective is Array or (not effective.is_empty() and effective.size()!=b.materials.size()): _fail(job,"effective_material_count"); return
	if job.cursor>=b.arrays.size():
		job.cursor=0; job.guard_cursor=0; job.after_material_guard="upload" if final else "replacement_snapshot"; job.stage="material_validate"; return
	var index: int=job.cursor
	var material: Material=effective[index] if not effective.is_empty() else mesh.surface_get_material(index)
	if mesh.surface_get_arrays(index)!=b.arrays[index] or mesh.surface_get_material(index)!=b.raw_materials[index] or material!=b.materials[index] or mesh.surface_get_format(index)!=b.formats[index] or mesh.surface_get_name(index)!=b.names[index]: _fail(job,"source_raw_arrays_or_material_binding_changed"); return
	job.cursor+=1

static func _source_identity_matches(binding: Dictionary) -> bool:
	var source: Dictionary=binding.source
	if source.get("mesh")!=binding.mesh or str(source.get("source_id",""))!=binding.source_id or str(source.get("source_part_id",""))!=binding.source_part_id: return false
	var effective: Variant=source.get("materials",[])
	return effective is Array and ((effective.is_empty() and binding.raw_materials==binding.materials) or effective==binding.materials)

static func _validate_material_one(job: Job) -> void:
	if job.cursor>=job.binding.material_guards.size(): job.cursor=0; job.stage=job.after_material_guard; return
	var guard: Dictionary=job.binding.material_guards[job.cursor]
	if job.guard_cursor>=guard.keys.size(): job.cursor+=1; job.guard_cursor=0; return
	var key: String=guard.keys[job.guard_cursor]
	if guard.material.get(key)!=guard.snapshot[key]: _fail(job,"source_material_properties_changed"); return
	job.guard_cursor+=1

static func _replacement_snapshot_one(job: Job) -> void:
	if job.cursor>=job.replacements.size(): job.cursor=0; job.stage="selectors"; return
	var input: Variant=job.replacements[job.cursor]
	if not input is Dictionary: _fail(job,"replacement_dictionary_required"); return
	# Ignore unrelated caller fields instead of duplicating unbounded payloads.
	job.replacements[job.cursor]={"component_id":input.get("component_id"),"source_faces":input.get("source_faces"),"mesh":input.get("mesh"),"provenance":input.get("provenance"),"materials":input.get("materials",[])}
	if input.get("mesh") is ArrayMesh: job.watch(input.mesh)
	job.cursor+=1

static func _replacement_one(job: Job) -> void:
	if job.cursor>=job.replacements.size():
		job.cursor=0; job.stage="inputs"; return
	var replacement: Dictionary=job.replacements[job.cursor]
	var id: Variant=replacement.get("component_id")
	if job.selector_stage=="header":
		if not id is int or id<0 or id>=job.binding.components.size() or job.replaced.has(id): _fail(job,"replacement_component_id_or_duplicate"); return
		if job.binding.held_components.has(id): _fail(job,"owner_held_component"); return
		if not replacement.get("source_faces") is Array or replacement.source_faces.size()!=job.binding.components[id].size(): _fail(job,"exact_complete_ordered_component_selectors_required"); return
		if not replacement.get("mesh") is ArrayMesh or not replacement.get("provenance") is Array: _fail(job,"replacement_mesh_and_triangle_provenance_required"); return
		var mesh: ArrayMesh=replacement.mesh
		if mesh.get_blend_shape_count()!=0 or mesh.shadow_mesh!=null or mesh.get_surface_count()>MAX_SOURCE_SURFACES: _fail(job,"replacement_morph_shadow_or_surfaces"); return
		if replacement.provenance.size()>MAX_OUTPUT_TRIANGLES: _fail(job,"replacement_provenance_budget"); return
		var effective: Variant=replacement.get("materials",[])
		if not effective is Array or (not effective.is_empty() and effective.size()!=mesh.get_surface_count()): _fail(job,"replacement_effective_material_count"); return
		replacement.provenance_lookup={}; job.selector_stage="faces"; job.selector_cursor=0; return
	if job.selector_stage=="faces":
		if job.selector_cursor>=replacement.source_faces.size(): job.selector_cursor=0; job.selector_stage="rows"; return
		if replacement.source_faces[job.selector_cursor]!=job.binding.components[id][job.selector_cursor]: _fail(job,"exact_complete_ordered_component_selectors_required"); return
		job.selector_cursor+=1; return
	var mesh: ArrayMesh=replacement.mesh
	var map: Dictionary=replacement.provenance_lookup
	if job.selector_stage=="rows":
		if job.selector_cursor>=replacement.provenance.size(): job.selector_cursor=0; job.selector_expected=0; job.selector_stage="surfaces"; return
		var row: Variant=replacement.provenance[job.selector_cursor]
		if not row is Dictionary or not row.get("surface") is int or not row.get("triangle") is int or not row.get("generated_reveal") is bool or not row.get("source_triangles") is Array: _fail(job,"replacement_provenance_schema"); return
		var key:=Vector2i(row.surface,row.triangle)
		if key.x<0 or key.x>=mesh.get_surface_count() or key.y<0 or map.has(key): _fail(job,"replacement_provenance_duplicate_or_range"); return
		var triangles: int=mesh.surface_get_array_index_len(key.x)
		if triangles==0: triangles=mesh.surface_get_array_len(key.x)
		if key.y>=triangles/3: _fail(job,"replacement_provenance_triangle_range"); return
		if row.generated_reveal:
			if row.get("source_surface",-1)!=-1 or not row.source_triangles.is_empty(): _fail(job,"generated_reveal_has_no_authored_triangle"); return
		else:
			if not row.get("source_surface") is int or row.source_triangles.is_empty() or row.source_triangles.size()>2: _fail(job,"authored_replacement_reference_required"); return
			for triangle: Variant in row.source_triangles:
				var owners: Array=job.binding.triangle_components
				if not triangle is int or row.source_surface<0 or row.source_surface>=owners.size() or triangle<0 or triangle>=owners[row.source_surface].size() or owners[row.source_surface][triangle]!=id: _fail(job,"replacement_reference_outside_selected_component"); return
		map[key]={"surface":row.surface,"triangle":row.triangle,"source_surface":row.get("source_surface",-1),"source_triangles":row.source_triangles.duplicate(),"generated_reveal":row.generated_reveal}; job.selector_cursor+=1; return
	if job.selector_cursor<mesh.get_surface_count():
		var surface: int=job.selector_cursor
		var count: int=mesh.surface_get_array_index_len(surface)
		if count==0: count=mesh.surface_get_array_len(surface)
		job.selector_expected+=count/3
		job.watch(mesh.surface_get_material(surface))
		var effective: Array=replacement.get("materials",[])
		if not effective.is_empty(): job.watch(effective[surface])
		job.selector_cursor+=1; return
	if job.selector_expected!=map.size(): _fail(job,"replacement_provenance_incomplete"); return
	job.replaced[id]=job.cursor; job.replaced_triangles+=job.binding.components[id].size(); job.cursor+=1
	job.selector_stage="header"; job.selector_cursor=0

static func _input_one(job: Job) -> void:
	# One native surface read/copy is indivisible; diagnostics expose its cost.
	var mesh: ArrayMesh; var surface: int=job.triangle; var replacement: Dictionary={}
	if job.cursor==0: mesh=job.binding.mesh
	else: replacement=job.replacements[job.cursor-1]; mesh=replacement.mesh
	if surface>=mesh.get_surface_count():
		job.cursor+=1; job.triangle=0
		if job.cursor>job.replacements.size(): job.cursor=0; job.stage="emit"
		return
	if job.inputs.size()>=MAX_INPUT_SURFACES or mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: _fail(job,"input_surface_or_primitive_budget"); return
	var arrays: Array=mesh.surface_get_arrays(surface)
	var packed: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
	var guard:=_packed_guard(packed,arrays)
	if not guard.ok: _fail(job,guard.reason); return
	job.input_bytes+=guard.bytes; job.input_triangles+=guard.triangles
	if job.input_bytes>MAX_PACKED_BYTES or job.input_triangles>MAX_SOURCE_TRIANGLES+MAX_OUTPUT_TRIANGLES: _fail(job,"input_memory_or_triangle_budget"); return
	var effective: Array=replacement.get("materials",[])
	var material: Material=job.binding.materials[surface] if job.cursor==0 else (effective[surface] if not effective.is_empty() else mesh.surface_get_material(surface))
	var format: int=int(packed.format)&~Mesh.ARRAY_FORMAT_INDEX
	var vertices: int=arrays[Mesh.ARRAY_VERTEX].size()
	var vstride: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,vertices)
	var nstride: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,vertices)
	var astride: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,vertices)
	if packed.vertex_data.size()!=vertices*(vstride+nstride) or packed.get("attribute_data",PackedByteArray()).size()!=vertices*astride: _fail(job,"unsupported_packed_buffer_layout"); return
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if not _absent(arrays[Mesh.ARRAY_INDEX]) else PackedInt32Array()
	job.inputs.append({"mesh":mesh,"surface":surface,"replacement":job.cursor-1,"arrays":arrays,"packed":packed,"material":material,"format":format,"vertices":vertices,"triangles":guard.triangles,"vstride":vstride,"nstride":nstride,"astride":astride,"indices":indices,"group":-1})
	job.triangle+=1

static func _group(job: Job,input: Dictionary,role: String) -> int:
	# Compression decodes positions/UV using per-surface metadata. Merging
	# distinct domains would alter geometry/UV, even with identical materials.
	var packed: Dictionary=input.packed
	var compressed: bool=(input.format&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)!=0
	var key: Array=[input.material.get_instance_id() if input.material!=null else 0,input.format,packed.get("aabb") if compressed else null,packed.get("uv_scale") if compressed else null,role=="reveal"]
	if job.group_lookup.has(key): return job.group_lookup[key]
	if job.groups.size()>=MAX_OUTPUT_SURFACES: return -1
	var group:=Group.new(); group.key=key; group.material=input.material
	group.descriptor=packed.duplicate(); group.descriptor.format=input.format
	group.descriptor.index_count=0; group.descriptor.index_data=PackedByteArray()
	group.descriptor.material=input.material; group.descriptor.name="compound_"+str(job.groups.size())
	group.descriptor.erase("lods"); group.descriptor.erase("blend_shape_data")
	var index:=job.groups.size(); job.groups.append(group); job.output_lookup.append([]); job.group_lookup[key]=index
	return index

static func _emit_one(job: Job) -> void:
	if job.cursor>=job.inputs.size(): job.cursor=0; job.stage="descriptors"; return
	var input: Dictionary=job.inputs[job.cursor]
	if job.triangle>=input.triangles: job.cursor+=1; job.triangle=0; return
	var triangle: int=job.triangle; job.triangle+=1
	var component: int
	var refs: Array=[]; var source_surface: int; var role: String
	if input.replacement<0:
		component=job.binding.triangle_components[input.surface][triangle]
		if job.replaced.has(component): return
		refs=[triangle]; source_surface=input.surface; role="authored"; job.retained_triangles+=1
	else:
		var replacement: Dictionary=job.replacements[input.replacement]
		component=replacement.component_id
		var row: Dictionary=replacement.provenance_lookup[Vector2i(input.surface,triangle)]
		refs=row.source_triangles; source_surface=row.get("source_surface",-1); role="reveal" if row.generated_reveal else "authored_cut"
	var group_id: int=_group(job,input,role)
	if group_id<0: _fail(job,"output_material_codec_surface_budget"); return
	var group: Group=job.groups[group_id]
	var corners:=PackedInt32Array()
	for corner: int in 3:
		var vertex: int=input.indices[triangle*3+corner] if not input.indices.is_empty() else triangle*3+corner
		if vertex<0 or vertex>=input.vertices: _fail(job,"input_vertex_index_range"); return
		corners.append(vertex)
		var point: Vector3=input.arrays[Mesh.ARRAY_VERTEX][vertex]
		if not point.is_finite(): _fail(job,"nonfinite_source_or_replacement_position"); return
		group.position_bytes.append_array(input.packed.vertex_data.slice(vertex*input.vstride,(vertex+1)*input.vstride))
		if input.nstride>0:
			var start: int=input.vertices*input.vstride+vertex*input.nstride
			group.normal_bytes.append_array(input.packed.vertex_data.slice(start,start+input.nstride))
		if input.astride>0: group.attribute_bytes.append_array(input.packed.attribute_data.slice(vertex*input.astride,(vertex+1)*input.astride))
		group.bounds=group.bounds.expand(point) if group.initialized else AABB(point,Vector3.ZERO); group.initialized=true
		group.vertices+=1; job.output_bytes+=input.vstride+input.nstride+input.astride
		if job.output_bytes>MAX_PACKED_BYTES: _fail(job,"output_memory_budget"); return
	var provenance: Dictionary={"output_surface":group_id,"output_triangle":group.triangles,"source_id":job.binding.source_id,"source_part_id":job.binding.source_part_id,"component_id":component,"source_surface":source_surface,"source_triangle":refs[0] if refs.size()==1 else -1,"source_triangles":refs.duplicate(),"role":role,"authored":role!="reveal","generated_reveal":role=="reveal","owner_held":job.binding.held_components.has(component),"input_mesh":input.mesh,"input_surface":input.surface,"input_triangle":triangle,"input_vertex_indices":corners}
	job.output_lookup[group_id].append(job.provenance.size()); job.provenance.append(provenance)
	group.roles[role]=true; group.triangles+=1; job.output_triangles+=1
	if job.output_triangles>MAX_OUTPUT_TRIANGLES: _fail(job,"output_triangle_budget")

static func _descriptor_one(job: Job) -> void:
	if job.cursor>=job.groups.size(): job.cursor=0; job.stage="final_validate"; return
	var group: Group=job.groups[job.cursor]
	var descriptor: Dictionary=group.descriptor
	group.position_bytes.append_array(group.normal_bytes)
	descriptor.vertex_data=group.position_bytes; descriptor.attribute_data=group.attribute_bytes; descriptor.vertex_count=group.vertices
	if not (int(descriptor.format)&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES): descriptor.aabb=group.bounds
	job.descriptors.append(descriptor); job.cursor+=1

static func _upload(job: Job) -> void:
	if job.dirty: _fail(job,"watched_source_or_replacement_changed"); return
	var mesh:=ArrayMesh.new(); mesh.resource_name=job.binding.mesh.resource_name+"_compound"
	mesh.custom_aabb=job.binding.custom_aabb; mesh.lightmap_size_hint=job.binding.lightmap_size_hint
	var started:=Time.get_ticks_usec()
	if not job.descriptors.is_empty(): mesh.set("_surfaces",job.descriptors)
	job.diagnostics.max_upload_usec=Time.get_ticks_usec()-started
	if mesh.get_surface_count()!=job.groups.size(): _fail(job,"native_packed_surface_upload_failed"); return
	job.mesh=mesh; job.stage="release"
	var reasons: Array=[]
	for index: int in job.groups.size():
		var group: Group=job.groups[index]
		reasons.append({"surface":index,"material_id":group.material.get_instance_id() if group.material!=null else 0,"format":group.descriptor.format,"compressed":bool(int(group.descriptor.format)&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES),"roles":group.roles.keys(),"triangles":group.triangles})
	job.result={"ok":true,"mesh":mesh,"provenance":job.provenance,"triangle_lookup":job.output_lookup,"source_id":job.binding.source_id,"source_part_id":job.binding.source_part_id,"counts":{"original_surfaces":job.binding.arrays.size(),"output_surfaces":mesh.get_surface_count(),"original_triangles":job.binding.source_triangles,"retained_triangles":job.retained_triangles,"replaced_source_triangles":job.replaced_triangles,"output_triangles":job.output_triangles,"components":job.binding.components.size(),"replaced_components":job.replaced.size(),"new_mesh_instances":0,"input_packed_bytes":job.input_bytes,"output_packed_bytes":job.output_bytes},"surface_grouping":{"rule":"effective material identity + exact format + compressed AABB/UV decode domain + authored/reveal separation","same_draw_count_guaranteed":false,"groups":reasons},"memory_bounds":{"source_triangles":MAX_SOURCE_TRIANGLES,"output_triangles":MAX_OUTPUT_TRIANGLES,"input_surfaces":MAX_INPUT_SURFACES,"output_surfaces":MAX_OUTPUT_SURFACES,"replacements":MAX_REPLACEMENTS,"input_packed_bytes":MAX_PACKED_BYTES,"output_packed_bytes":MAX_PACKED_BYTES,"note":"Packed input/output caps exclude bounded per-triangle Variant provenance/arrays and native upload copies; not an RSS guarantee."},"packed_codec_preserved":true,"source_unchanged":true,"scene_mutated":false,"physical_ownership_granted":false}

static func lookup(result: Dictionary,surface: int,triangle: int) -> Dictionary:
	if result.get("ok")!=true or surface<0 or surface>=result.triangle_lookup.size() or triangle<0 or triangle>=result.triangle_lookup[surface].size(): return _no("output_triangle_selector")
	return {"ok":true,"provenance":result.provenance[result.triangle_lookup[surface][triangle]]}

static func _release_one(job: Job) -> void:
	# Original mesh/material watchers stay live until the same call that returns
	# the completed result. Incremental cleanup only detaches replacement inputs.
	if job.watches.size()<=job.original_watch_count: job.disconnect_watches(); job.stage="done"; return
	var resource: Resource=job.watches.pop_back()
	if resource.changed.is_connected(job.changed): resource.changed.disconnect(job.changed)

static func _fail(job: Job,reason: String) -> void:
	job.disconnect_watches(); job.stage="done"; job.result=_no(reason)

static func cancel(job: Job) -> void:
	if job==null or job.stage=="done" or job.stage=="cancelled": return
	job.disconnect_watches(); job.stage="cancelled"; job.binding={}; job.replacements=[]; job.inputs=[]; job.groups=[]; job.group_lookup={}; job.descriptors=[]; job.provenance=[]; job.output_lookup=[]; job.mesh=null
	job.result={}; job.replaced={}
