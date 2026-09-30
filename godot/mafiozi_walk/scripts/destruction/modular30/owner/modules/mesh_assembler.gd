extends RefCounted
## Pure staged assembly: source-owned state must stay immutable until completion.
## Scheduling is cooperative. Native mesh uploads are indivisible and timed.
const G = preload("geometry.gd")
const EPS := .00001
const MAX_SOLIDS := 2048
const MAX_FACES := 16384
const MAX_FACE_POINTS := 256
const MAX_WELD_CORNERS := 65536
const MAX_VERTICES := 65536
const MAX_SOURCE_FACES := 128
const MAX_SOURCE_TRIANGLES := 128
const MAX_SOURCE_SURFACES := 64
const MAX_BIN_OCCUPANCY := 16
const MAX_ITEMS_PER_ADVANCE := 128
const MAX_BUDGET_USEC := 1000

class Surface extends RefCounted:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var tangents := PackedFloat32Array()
	var uv2 := PackedVector2Array()
	var faces: Array[Dictionary] = []

class Job extends RefCounted:
	var state: Dictionary = {}
	var parsed: Dictionary = {}
	var stage := "validate"
	var validate_index := 0
	var final_validation := false
	var source_index := 0
	var source_ids: Array = []
	var source_samples: Array = []
	var surfaces: Array[Surface] = []
	var bins: Dictionary = {}
	var canonical_exact: Dictionary = {}
	var solid_index := 0
	var face_index := 0
	var corner_index := 0
	var face: Dictionary = {}
	var polygon: Array[Vector3] = []
	var surface_index := 0
	var emit_face_index := 0
	var triangle_index := 1
	var total_vertices := 0
	var face_count := 0
	var input_corners := 0
	var welded_points := 0
	var mesh := ArrayMesh.new()
	var provenance: Array[Dictionary] = []
	var collision_faces_world := PackedVector3Array()
	var source_triangle_audit := {"source_faces":0,"source_triangles":0,"source_output_triangles":0,"reveal_output_triangles":0,"exact_authored_corners":0,"interpolated_corners":0,"degenerate_triangles_skipped":0,"covered_source_triangles":{}}
	var diagnostics := {"calls":0,"items":0,"total_active_usec":0,"max_advance_usec":0,"max_item_usec":0,"max_upload_usec":0,"max_source_validation_usec":0,"budget_overrun_calls":0,"max_overrun_usec":0,"max_items_in_call":0,"max_triangles_in_call":0,"max_weld_candidates":0,"max_bin_occupancy":0,"canonical_exact_cache_hits":0,"stage_usec":{},"cooperative_budget_usec":1000,"hard_deadline_guaranteed":false,"loaded_scene_fps_verified":false}
	var result: Dictionary = {}

static func begin(state: Dictionary) -> Job:
	var job := Job.new()
	if not state.get("ok",false) or not state.get("parsed") is Dictionary or not state.get("solids") is Array:
		_fail(job,"hollow_state_required"); return job
	job.state=state; job.parsed=state.parsed
	var p: Dictionary=job.parsed
	if not p.get("mesh") is ArrayMesh or not p.get("frame") is Transform3D or not p.get("source_faces") is Array or not p.get("materials") is Array or not p.get("binding") is Dictionary:
		_fail(job,"parsed_source_required"); return job
	if not p.frame.is_finite() or p.frame.basis.determinant()<=0 or not p.get("reveal_material") is Material:
		_fail(job,"finite_frame_and_reveal_required"); return job
	if state.solids.size()>MAX_SOLIDS or p.source_faces.size()>MAX_SOURCE_FACES or p.materials.is_empty() or p.materials.size()>MAX_SOURCE_SURFACES:
		_fail(job,"assembly_source_budget"); return job
	if not p.binding.get("arrays") is Array or p.binding.arrays.size()!=p.materials.size():
		_fail(job,"source_binding_required"); return job
	if not p.get("original_mesh_materials") is Array or p.original_mesh_materials.size()!=p.materials.size():
		_fail(job,"raw_source_material_snapshot_required"); return job
	# At most 65 small buffers; no geometry is walked by begin().
	for index: int in p.materials.size()+1: job.surfaces.append(Surface.new())
	return job

static func advance(job: Job, maxitems: int=32, budgetusec: int=1000) -> Dictionary:
	if job==null: return _no("job_required")
	if maxitems<1 or maxitems>MAX_ITEMS_PER_ADVANCE or budgetusec<1 or budgetusec>MAX_BUDGET_USEC: return _no("bounded_advance_required")
	if job.stage=="cancelled": return _no("cancelled")
	if job.stage=="done": return {"ok":job.result.ok,"done":true,"result":job.result,"scene_mutated":false}
	var started := Time.get_ticks_usec()
	var count := 0
	var before_triangles := job.total_vertices/3
	while count<maxitems and job.stage!="done":
		var stage := job.stage
		var item_started := Time.get_ticks_usec()
		_step(job)
		var elapsed := Time.get_ticks_usec()-item_started
		job.diagnostics.max_item_usec=maxi(job.diagnostics.max_item_usec,elapsed)
		job.diagnostics.stage_usec[stage]=int(job.diagnostics.stage_usec.get(stage,0))+elapsed
		job.diagnostics.items+=1; count+=1
		if Time.get_ticks_usec()-started>=budgetusec: break
	var elapsed := Time.get_ticks_usec()-started
	job.diagnostics.calls+=1; job.diagnostics.total_active_usec+=elapsed
	job.diagnostics.max_advance_usec=maxi(job.diagnostics.max_advance_usec,elapsed)
	job.diagnostics.max_items_in_call=maxi(job.diagnostics.max_items_in_call,count)
	job.diagnostics.max_triangles_in_call=maxi(job.diagnostics.max_triangles_in_call,job.total_vertices/3-before_triangles)
	if elapsed>budgetusec:
		job.diagnostics.budget_overrun_calls+=1
		job.diagnostics.max_overrun_usec=maxi(job.diagnostics.max_overrun_usec,elapsed-budgetusec)
	if job.stage=="done":
		job.result.diagnostics=job.diagnostics.duplicate(true)
		job.result.materialize_usec=job.diagnostics.total_active_usec
		return {"ok":job.result.ok,"done":true,"result":job.result,"items":count,"elapsed_usec":elapsed,"scene_mutated":false}
	return {"ok":true,"done":false,"stage":job.stage,"items":count,"elapsed_usec":elapsed,"scene_mutated":false}

static func cancel(job: Job) -> void:
	if job==null or job.stage=="done": return
	job.stage="cancelled"
	job.state={}; job.parsed={}; job.bins={}; job.canonical_exact={}; job.face={}; job.polygon=[]
	job.surfaces=[]; job.source_ids=[]; job.source_samples=[]
	job.mesh=null; job.provenance=[]; job.collision_faces_world=PackedVector3Array()

static func _step(job: Job) -> void:
	match job.stage:
		"validate": _validate_one(job)
		"source": _source_one(job)
		"weld": _weld_one(job)
		"emit": _emit_one(job)
		"upload": _upload_one(job)
		_: _fail(job,"invalid_assembly_stage")

static func _validate_one(job: Job) -> void:
	var p: Dictionary=job.parsed
	var mesh: ArrayMesh=p.mesh
	if mesh.get_surface_count()!=p.binding.arrays.size(): _fail(job,"source_mutated"); return
	if job.validate_index>=p.materials.size():
		if job.final_validation: _finish(job)
		else: job.stage="source"
		return
	var started := Time.get_ticks_usec()
	var index := job.validate_index
	# Source admission caps the WHOLE source at 128 triangles; one native read
	# and array equality are explicitly timed, not hidden in begin().
	if mesh.surface_get_arrays(index)!=p.binding.arrays[index] or mesh.surface_get_material(index)!=p.original_mesh_materials[index]:
		_fail(job,"source_mutated"); return
	job.diagnostics.max_source_validation_usec=maxi(job.diagnostics.max_source_validation_usec,Time.get_ticks_usec()-started)
	job.validate_index+=1

static func _source_one(job: Job) -> void:
	if job.source_index>=job.parsed.source_faces.size(): job.stage="weld"; return
	var face: Dictionary=job.parsed.source_faces[job.source_index]
	if not face.get("triangles") is Array or face.triangles.is_empty() or face.triangles.size()>2:
		_fail(job,"source_triangle_or_affine_quad_required"); return
	var ids: Array[int]=[]
	var samples: Dictionary={}
	for triangle: Dictionary in face.triangles:
		if not triangle.get("vertices") is Array or triangle.vertices.size()!=3 or not triangle.has("triangle_index"):
			_fail(job,"source_triangle_attributes_required"); return
		ids.append(int(triangle.triangle_index))
		for vertex: Array in triangle.vertices:
			if vertex.size()!=6: _fail(job,"source_six_attribute_channels_required"); return
			# Same first-authored occurrence as Blocks._sample_authored.
			if not samples.has(vertex[0]): samples[vertex[0]]=vertex
	job.source_triangle_audit.source_triangles+=ids.size()
	if job.source_triangle_audit.source_triangles>MAX_SOURCE_TRIANGLES: _fail(job,"source_triangle_budget"); return
	job.source_ids.append(ids); job.source_samples.append(samples)
	job.source_triangle_audit.source_faces+=1; job.source_index+=1

static func _weld_one(job: Job) -> void:
	if job.face.is_empty():
		if job.solid_index>=job.state.solids.size(): job.stage="emit"; return
		var solid: Array=job.state.solids[job.solid_index]
		if solid.size()>MAX_FACES: _fail(job,"face_budget"); return
		if job.face_index>=solid.size(): job.solid_index+=1; job.face_index=0; return
		var face: Dictionary=solid[job.face_index]
		if not face.get("polygon") is Array or face.polygon.size()<3 or face.polygon.size()>MAX_FACE_POINTS:
			_fail(job,"face_point_budget"); return
		if not face.get("normal") is Vector3 or not face.normal.is_finite() or not face.has("source_face") or not face.has("surface"):
			_fail(job,"face_attributes_required"); return
		var id := int(face.source_face)
		if id< -1 or id>=job.source_ids.size() or (id>=0 and (int(face.surface)<0 or int(face.surface)>=job.parsed.materials.size())):
			_fail(job,"source_face_mapping"); return
		if id>=0 and int(face.surface)!=int(job.parsed.source_faces[id].surface): _fail(job,"source_surface_mapping"); return
		job.face_count+=1; job.input_corners+=face.polygon.size()
		if job.face_count>MAX_FACES or job.input_corners>MAX_WELD_CORNERS: _fail(job,"weld_memory_budget"); return
		job.face=face; job.polygon=[]; job.corner_index=0
		return
	if job.corner_index>=job.face.polygon.size():
		if job.polygon.size()>=3:
			var copy: Dictionary=job.face.duplicate(); copy.polygon=job.polygon
			var surface: int=int(copy.surface) if int(copy.source_face)>=0 else job.parsed.materials.size()
			job.surfaces[surface].faces.append(copy)
		job.face={}; job.polygon=[]; job.face_index+=1; return
	var point: Vector3=job.face.polygon[job.corner_index]
	if not point.is_finite(): _fail(job,"finite_polygon_required"); return
	# Cache ONLY a point inserted as a canonical point itself. A later newly
	# inserted canonical cannot be within EPS of it, so first-bin selection
	# cannot change. Caching arbitrary near-mapped points would be incorrect:
	# a later canonical in an earlier neighbor bin could supersede that match.
	if job.canonical_exact.has(point):
		if not job.polygon.has(point): job.polygon.append(point)
		job.corner_index+=1; job.diagnostics.canonical_exact_cache_hits+=1; return
	var world: Vector3=job.parsed.frame*point
	if not world.is_finite(): _fail(job,"finite_world_point_required"); return
	var x := floori(world.x/EPS); var y := floori(world.y/EPS); var z := floori(world.z/EPS)
	var canonical := point
	var found := false
	var candidates := 0
	# One work unit is one vertex: <=27 bins * 16 bounded candidates.
	# String keys avoid Vector3i overflow for far-world coordinates and retain
	# geometry.gd's exact neighbor traversal and first-match tie selection.
	for dx: int in range(-1,2):
		if found: break
		for dy: int in range(-1,2):
			if found: break
			for dz: int in range(-1,2):
				var key := str(x+dx)+":"+str(y+dy)+":"+str(z+dz)
				for candidate: Dictionary in job.bins.get(key,[]):
					candidates+=1
					if candidate.world.distance_squared_to(world)<=EPS*EPS:
						canonical=candidate.local; found=true; break
				if found: break
	if not found:
		var key := str(x)+":"+str(y)+":"+str(z)
		if not job.bins.has(key): job.bins[key]=[]
		if job.bins[key].size()>=MAX_BIN_OCCUPANCY: _fail(job,"weld_bin_budget"); return
		job.bins[key].append({"world":world,"local":point}); job.welded_points+=1
		job.canonical_exact[point]=true
		job.diagnostics.max_bin_occupancy=maxi(job.diagnostics.max_bin_occupancy,job.bins[key].size())
	job.diagnostics.max_weld_candidates=maxi(job.diagnostics.max_weld_candidates,candidates)
	if not job.polygon.has(canonical): job.polygon.append(canonical)
	job.corner_index+=1

static func _emit_one(job: Job) -> void:
	if job.surface_index>=job.surfaces.size():
		job.stage="validate"; job.validate_index=0; job.final_validation=true; return
	var buffer: Surface=job.surfaces[job.surface_index]
	if job.emit_face_index>=buffer.faces.size():
		job.stage="upload"; return
	var face: Dictionary=buffer.faces[job.emit_face_index]
	if job.triangle_index>=face.polygon.size()-1:
		job.emit_face_index+=1; job.triangle_index=1; return
	var index := job.triangle_index
	job.triangle_index+=1
	var triangle: Array[Vector3]=[face.polygon[0],face.polygon[index+1],face.polygon[index]]
	if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()<.00000000000001:
		job.source_triangle_audit.degenerate_triangles_skipped+=1; return
	if job.total_vertices+3>MAX_VERTICES: _fail(job,"mesh_vertex_budget"); return
	var triangle_id: int=buffer.vertices.size()/3
	var source_id := int(face.source_face)
	for point: Vector3 in triangle:
		var attributes: Array
		var exact: bool=source_id>=0 and job.source_samples[source_id].has(point)
		if exact:
			attributes=job.source_samples[source_id][point]
			job.source_triangle_audit.exact_authored_corners+=1
		elif source_id>=0:
			attributes=G._sample(job.parsed.source_faces[source_id],point)
			job.source_triangle_audit.interpolated_corners+=1
		else: attributes=G._reveal_attributes(face,point,job.parsed.frame)
		var normal: Vector3=attributes[1]
		var tangent := Vector3(attributes[4].x,attributes[4].y,attributes[4].z)
		if not exact:
			normal=normal.normalized(); tangent=(tangent-normal*tangent.dot(normal)).normalized()
		buffer.vertices.append(point); buffer.normals.append(normal); buffer.uv.append(attributes[2]); buffer.colors.append(attributes[3]); buffer.uv2.append(attributes[5])
		buffer.tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,attributes[4].w]))
		job.collision_faces_world.append(job.parsed.frame*point)
	var ids: Array[int]=[]
	if source_id>=0:
		ids=job.source_ids[source_id]
		job.source_triangle_audit.source_output_triangles+=1
		for authored_id: int in ids: job.source_triangle_audit.covered_source_triangles[str(face.surface)+":"+str(authored_id)]=true
	else: job.source_triangle_audit.reveal_output_triangles+=1
	job.provenance.append({"surface":job.surface_index,"triangle":triangle_id,"source_face":source_id,"source_surface":int(face.surface),"source_triangles":ids,"generated_reveal":source_id<0})
	job.total_vertices+=3

static func _upload_one(job: Job) -> void:
	# Empty complete state matches Shell.materialize(): zero surfaces.
	if job.face_count==0:
		job.surface_index=job.surfaces.size(); job.stage="emit"; return
	var buffer: Surface=job.surfaces[job.surface_index]
	if buffer.vertices.is_empty():
		for index: int in 3:
			buffer.vertices.append(Vector3.ZERO); buffer.normals.append(Vector3.UP); buffer.uv.append(Vector2.ZERO); buffer.colors.append(Color.WHITE); buffer.uv2.append(Vector2.ZERO)
			buffer.tangents.append_array(PackedFloat32Array([1,0,0,1]))
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=buffer.vertices; arrays[Mesh.ARRAY_NORMAL]=buffer.normals; arrays[Mesh.ARRAY_TEX_UV]=buffer.uv
	arrays[Mesh.ARRAY_COLOR]=buffer.colors; arrays[Mesh.ARRAY_TANGENT]=buffer.tangents; arrays[Mesh.ARRAY_TEX_UV2]=buffer.uv2
	var started := Time.get_ticks_usec()
	job.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	job.mesh.surface_set_material(job.surface_index,job.parsed.materials[job.surface_index] if job.surface_index<job.parsed.materials.size() else job.parsed.reveal_material)
	job.diagnostics.max_upload_usec=maxi(job.diagnostics.max_upload_usec,Time.get_ticks_usec()-started)
	job.surface_index+=1; job.emit_face_index=0; job.triangle_index=1; job.stage="emit"

static func _finish(job: Job) -> void:
	job.result={"ok":true,"mesh":job.mesh,"provenance":job.provenance,"collision_faces_world":job.collision_faces_world,"source_triangle_audit":job.source_triangle_audit,"scene_mutated":false,"source_unchanged":true,"memory_bounds":{"solids":MAX_SOLIDS,"faces":MAX_FACES,"face_points":MAX_FACE_POINTS,"input_corners":MAX_WELD_CORNERS,"output_real_vertices":MAX_VERTICES,"surfaces_including_reveal":MAX_SOURCE_SURFACES+1,"candidates_per_bin":MAX_BIN_OCCUPANCY},"counts":{"faces":job.face_count,"input_corners":job.input_corners,"welded_points":job.welded_points,"real_vertices":job.total_vertices,"collision_vertices":job.collision_faces_world.size(),"provenance_rows":job.provenance.size()}}
	job.stage="done"

static func _fail(job: Job, reason: String) -> void:
	job.result=_no(reason); job.stage="done"

static func _no(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"scene_mutated":false}
