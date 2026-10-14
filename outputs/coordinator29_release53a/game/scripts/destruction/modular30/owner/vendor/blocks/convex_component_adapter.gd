extends RefCounted
## Pure, opt-in staging for SMALL authored convex solids, including real bevels.
## Never fits an AABB as geometry and never assigns physical material from finish.
const Slab = preload("../interior/thin_slab_adapter.gd")
const Strength = preload("../material_strength.gd")
const Rubble = preload("../rubble/rubble_manager.gd")
const EPS := 0.00001
const MAX_SOURCE_TRIANGLES := 128
const MAX_SOURCE_POINTS := 64
# A source triangle is the maximum geometric facet subdivision: bevel quads
# can share shading normals without being coplanar. Never flatten their planes.
const MAX_SOURCE_FACES := MAX_SOURCE_TRIANGLES
const MAX_SOURCE_SURFACES := 6
const MAX_COMPONENT_VOLUME := 3.0
const MAX_COMPONENT_THICKNESS := 1.0
const MAX_COMPONENT_LENGTH := 8.0
const MAX_BOUNDARY_FACES := 1024

class Admission extends RefCounted:
	var _parsed: Dictionary = {}
	var _profile: Dictionary = {}
	var _label := ""

class Preparation extends RefCounted:
	var parsed: Dictionary = {}
	var previous: Dictionary = {}
	var old_brushes: Array[AABB] = []
	var brushes: Array[AABB] = []
	var grid: Array = []
	var cursor := 0
	var candidates := 0
	var cells := 0
	var kept_volume := 0.0
	var removed_volume := 0.0
	var new_removed_volume := 0.0
	var boundary: Array[Dictionary] = []
	var shared: Dictionary = {}
	var pieces: Array[Dictionary] = []
	var result: Dictionary = {}
	var assembly: Dictionary = {}
	var cell_work: Dictionary = {}
	var descriptors: Array[Dictionary] = []
	var stage := "cells"
	var diagnostics := {"parse_usec":0,"geometry_cache_hit":false,"grid_usec":0,"cell_batches":0,"max_batch_usec":0,"max_cell_usec":0,"max_kernel_step_usec":0,"finalize_usec":0,"max_finalize_step_usec":0,"finalize_steps":0,"processed_cells":0}

static func inspect(source: Dictionary, frame: Transform3D, profile: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var parsed := _parse(source,frame,profile)
	if not parsed.ok: return parsed
	var admitted:=Admission.new(); admitted._parsed=parsed; admitted._profile=profile.duplicate(true); admitted._label=str(source.get("label",parsed.mesh.resource_name))
	return {"ok":true,"admission":admitted,"thickness_m":parsed.thickness,"thin_axis":parsed.thin_axis,"true_volume_m3":parsed.original_volume,"bounds_volume_m3":parsed.box.get_volume()*frame.basis.determinant(),"triangles":parsed.triangle_count,"welded_points":parsed.points.size(),"convex_faces":parsed.faces.size(),"materials":parsed.materials.size(),"parse_usec":Time.get_ticks_usec()-started,"scene_mutated":false}

static func validate_admission(source: Dictionary, frame: Transform3D, profile: Dictionary, admission: Admission) -> Dictionary:
	if admission==null: return _no("component_admission_required")
	var checked:=_cached_parse(source,frame,profile,admission)
	if not checked.ok: return checked
	return {"ok":true,"scene_mutated":false}

static func prepare(source: Dictionary, frame: Transform3D, brushes_world: Array[AABB], profile: Dictionary, previous: Dictionary = {}) -> Dictionary:
	# Synchronous convenience for bounded fixture/offline preparation only.
	# A live owner should begin/advance over separate physics ticks, then reserve
	# support/debris before atomically committing these completed resources.
	var beginning := begin_prepare(source,frame,brushes_world,profile,previous)
	if not beginning.ok: return beginning
	while true:
		var step := advance(beginning.preparation,4,2000)
		if not step.ok: return step
		if step.done: return step.result
	return _no("unreachable")

static func begin_prepare(source: Dictionary, frame: Transform3D, brushes_world: Array[AABB], profile: Dictionary, previous: Dictionary = {}, admission: Admission = null) -> Dictionary:
	var started := Time.get_ticks_usec()
	var parsed := _parse(source,frame,profile) if admission==null else _cached_parse(source,frame,profile,admission)
	if not parsed.ok: return parsed
	if not previous.is_empty() and (previous.get("schema")!="bounded-convex-component-state/v1" or previous.get("binding")!=parsed.binding): return _no("previous_source_binding")
	var current: Variant = source.get("current_mesh",source.get("mesh"))
	if current != previous.get("wall_mesh",source.mesh): return _no("current_mesh_does_not_match_committed_state")
	var job := Preparation.new()
	job.parsed=parsed; job.previous=previous
	job.diagnostics.parse_usec=Time.get_ticks_usec()-started
	job.diagnostics.geometry_cache_hit=admission!=null
	started=Time.get_ticks_usec()
	for value: Variant in previous.get("brushes_world",[]):
		if not value is AABB or not Slab._valid_brush(value): return _no("previous_brushes")
		job.old_brushes.append(value)
	job.brushes=job.old_brushes.duplicate()
	for brush: AABB in brushes_world:
		if not Slab._valid_brush(brush): return _no("finite_positive_world_brush")
		if parsed.world_bounds.intersects(brush) and not job.brushes.has(brush): job.brushes.append(brush)
	if job.brushes.size()>Slab.MAX_BRUSHES: return _no("brush_budget")
	job.candidates=1
	for axis: int in 3:
		var breaks: Array[float]=[parsed.world_bounds.position[axis],parsed.world_bounds.end[axis]]
		for brush: AABB in job.brushes:
			Slab._add_break(breaks,brush.position[axis]); Slab._add_break(breaks,brush.end[axis])
			if parsed.world_bounds.size[axis]<=parsed.chunk_size: continue
			var first: int=floori(maxf(brush.position[axis],breaks[0])/parsed.chunk_size)+1
			var last: int=ceili(minf(brush.end[axis],breaks[1])/parsed.chunk_size)
			if last-first>64: return _no("grid_axis_budget")
			for index: int in range(first,last): Slab._add_break(breaks,index*parsed.chunk_size)
		breaks.sort(); job.grid.append(breaks); job.candidates*=breaks.size()-1
	if job.candidates>Slab.MAX_GRID_CELLS: return _no("grid_cell_budget")
	job.diagnostics.grid_usec=Time.get_ticks_usec()-started
	return {"ok":true,"preparation":job,"candidate_cells":job.candidates,"thickness_m":parsed.thickness,"scene_mutated":false}

static func advance(job: Preparation, max_cells: int = 4, budget_usec: int = 2000) -> Dictionary:
	if job==null or max_cells<1 or max_cells>8 or budget_usec<100 or budget_usec>10000: return _no("bounded_preparation_step_required")
	if job.stage=="cancelled": return _no("preparation_cancelled")
	if job.parsed.is_empty(): return _no("bounded_preparation_step_required")
	if job.stage=="done": return {"ok":job.result.get("ok",false),"done":true,"result":job.result,"scene_mutated":false}
	var started:=Time.get_ticks_usec()
	if job.stage!="cells":
		# Facets are much smaller work units than clipped solids. Keep a
		# separate hard bound, otherwise max_cells=1 would delay a small cut
		# hundreds of physics ticks while spending only tens of microseconds.
		var finalized:=_advance_finalize(job,64,budget_usec)
		var elapsed:=Time.get_ticks_usec()-started
		job.diagnostics.finalize_usec+=elapsed; job.diagnostics.finalize_steps+=1
		job.diagnostics.max_finalize_step_usec=maxi(job.diagnostics.max_finalize_step_usec,elapsed)
		if not finalized.ok: job.result=finalized; job.stage="done"
		if job.stage=="done":
			job.result["diagnostics"]=job.diagnostics.duplicate()
			return {"ok":job.result.ok,"done":true,"result":job.result,"reason":job.result.get("reason",""),"scene_mutated":false}
		return {"ok":true,"done":false,"stage":job.stage,"processed_cells":job.cursor,"candidate_cells":job.candidates,"scene_mutated":false}
	var processed:=0
	while job.cursor<job.candidates and processed<max_cells:
		var cell_started:=Time.get_ticks_usec()
		var step:=_cell(job)
		var elapsed:=Time.get_ticks_usec()-cell_started
		job.diagnostics.max_kernel_step_usec=maxi(job.diagnostics.max_kernel_step_usec,elapsed)
		if not step.ok:
			job.result=step; job.stage="done"
			return {"ok":false,"done":true,"result":step,"reason":step.reason,"scene_mutated":false}
		if step.get("cell_done",false):
			job.diagnostics.max_cell_usec=maxi(job.diagnostics.max_cell_usec,int(job.cell_work.get("elapsed_usec",0))+elapsed)
			job.cell_work.clear(); job.cursor+=1; processed+=1
		else: job.cell_work.elapsed_usec=int(job.cell_work.get("elapsed_usec",0))+elapsed
		if Time.get_ticks_usec()-started>=budget_usec: break
	job.diagnostics.cell_batches+=1
	job.diagnostics.processed_cells=job.cursor
	job.diagnostics.max_batch_usec=maxi(job.diagnostics.max_batch_usec,Time.get_ticks_usec()-started)
	if job.cursor>=job.candidates: job.stage="finalize"
	return {"ok":true,"done":false,"stage":job.stage,"processed_cells":job.cursor,"candidate_cells":job.candidates,"scene_mutated":false}

static func cancel(job: Preparation) -> void:
	if job==null or job.stage=="done": return
	# The admitted parsed dictionary is shared read-only by other preparations.
	job.parsed={}; job.boundary.clear(); job.shared.clear(); job.pieces.clear(); job.assembly.clear(); job.cell_work.clear(); job.descriptors.clear(); job.stage="cancelled"

static func _cell(job: Preparation) -> Dictionary:
	var parsed: Dictionary=job.parsed
	if job.cell_work.is_empty():
		var nz: int=job.grid[2].size()-1; var ny: int=job.grid[1].size()-1
		var z: int=job.cursor%nz; var y: int=(job.cursor/nz)%ny; var x: int=job.cursor/(ny*nz)
		var cell:=AABB(Vector3(job.grid[0][x],job.grid[1][y],job.grid[2][z]),Vector3(job.grid[0][x+1]-job.grid[0][x],job.grid[1][y+1]-job.grid[1][y],job.grid[2][z+1]-job.grid[2][z]))
		job.cell_work={"indices":Vector3i(x,y,z),"cell":cell,"faces":parsed.faces.duplicate(true),"clip":0,"elapsed_usec":0}
		return {"ok":true,"cell_done":false}
	var work: Dictionary=job.cell_work
	var indices: Vector3i=work.indices; var cell: AABB=work.cell
	if work.clip<6:
		var axis: int=int(work.clip)/2; var upper: bool=int(work.clip)%2==1
		work.faces=Slab._clip_solid(work.faces,parsed.frame,axis,cell.end[axis] if upper else cell.position[axis],upper,indices[axis]+(1 if upper else 0))
		work.clip+=1
		return {"ok":true,"cell_done":work.faces.is_empty()}
	var faces: Array[Dictionary]=work.faces
	var volume: float=Slab._volume(faces,parsed.frame)
	if volume<=.000000001: return {"ok":true,"cell_done":true}
	job.cells+=1
	if job.cells>Slab.MAX_SOLID_CELLS: return _no("solid_cell_budget")
	if Slab._inside_brushes(cell.get_center(),job.brushes):
		job.removed_volume+=volume
		if not Slab._inside_brushes(cell.get_center(),job.old_brushes):
			if job.pieces.size()>=Slab.MAX_DEBRIS: return _no("debris_budget")
			var piece: Dictionary=Slab._debris(faces,parsed,volume,cell)
			if not piece.ok: return piece
			job.pieces.append(piece); job.new_removed_volume+=volume
		return {"ok":true,"cell_done":true}
	job.kept_volume+=volume
	for face: Dictionary in faces:
		if int(face.grid_axis)<0: job.boundary.append(face)
		else:
			var axis: int=int(face.grid_axis)
			var key:=str(axis)+":"+str(face.grid_plane)+":"+str(indices[(axis+1)%3])+":"+str(indices[(axis+2)%3])
			if job.shared.has(key):
				if job.shared[key]==null or face.normal.dot(job.shared[key].normal)>-.99: return _no("nonmanifold_cell_boundary")
				job.shared[key]=null
			else: job.shared[key]=face
	if job.boundary.size()+job.shared.size()>MAX_BOUNDARY_FACES: return _no("component_boundary_budget")
	return {"ok":true,"cell_done":true}

static func _advance_finalize(job: Preparation, max_items: int, budget_usec: int) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var parsed: Dictionary=job.parsed
	if job.stage=="finalize":
		var error: float=absf(job.kept_volume+job.removed_volume-parsed.original_volume)
		if error>maxf(.00001,parsed.original_volume*.00005): return _no("true_convex_volume_conservation")
		for face: Variant in job.shared.values():
			if face!=null: job.boundary.append(face)
		if job.new_removed_volume<=.000000001:
			job.assembly={"mesh":job.previous.get("wall_mesh",parsed.mesh),"provenance":job.previous.get("wall_provenance",[])}
			job.stage="collision"
		else:
			var surfaces: Array=[]
			for surface: int in parsed.materials.size()+1:
				surfaces.append({"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"tangents":PackedFloat32Array(),"uv2":PackedVector2Array()})
			job.assembly={"mesh":ArrayMesh.new(),"provenance":[],"surfaces":surfaces,"cursor":0,"bins":{},"exact":{},"faces":[],"total_vertices":0}
			job.stage="wall_weld"
		return {"ok":true}
	var assembly: Dictionary=job.assembly
	var processed:=0
	while processed<max_items:
		if job.stage=="wall_weld":
			if assembly.cursor>=job.boundary.size(): assembly.cursor=0; assembly.bins.clear(); assembly.exact.clear(); job.stage="wall_faces"; break
			_weld_one_face(job,job.boundary[assembly.cursor])
			assembly.cursor+=1
		elif job.stage=="wall_faces":
			if assembly.cursor>=assembly.faces.size(): assembly.cursor=0; assembly.faces.clear(); job.stage="wall_surfaces"; break
			var emitted:=_emit_wall_face(job,assembly.faces[assembly.cursor])
			if not emitted.ok: return emitted
			assembly.cursor+=1
		elif job.stage=="wall_surfaces":
			if assembly.cursor>=assembly.surfaces.size(): assembly.cursor=0; assembly.surfaces.clear(); job.stage="collision"; break
			var surface: int=assembly.cursor
			var buffers: Dictionary=assembly.surfaces[surface]
			if buffers.vertices.is_empty():
				for i: int in 3:
					buffers.vertices.append(Vector3.ZERO); buffers.normals.append(Vector3.UP); buffers.uv.append(Vector2.ZERO); buffers.colors.append(Color.WHITE); buffers.uv2.append(Vector2.ZERO); buffers.tangents.append_array(PackedFloat32Array([1,0,0,1]))
			var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=buffers.vertices; arrays[Mesh.ARRAY_NORMAL]=buffers.normals; arrays[Mesh.ARRAY_TEX_UV]=buffers.uv
			arrays[Mesh.ARRAY_COLOR]=buffers.colors; arrays[Mesh.ARRAY_TANGENT]=buffers.tangents; arrays[Mesh.ARRAY_TEX_UV2]=buffers.uv2
			assembly.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			assembly.mesh.surface_set_material(surface,parsed.materials[surface] if surface<parsed.materials.size() else parsed.reveal_material)
			assembly.cursor+=1
		elif job.stage=="collision":
			# Direct array extraction avoids the snapped TriangleMesh cache.
			var faces:=PackedVector3Array()
			var raw:=_exact_mesh_faces(assembly.mesh)
			for i: int in range(0,raw.size(),3):
				var a: Vector3=parsed.frame*raw[i]; var b: Vector3=parsed.frame*raw[i+1]; var c: Vector3=parsed.frame*raw[i+2]
				if (b-a).cross(c-a).length_squared()>.00000000000001: faces.append_array(PackedVector3Array([a,b,c]))
			assembly["collision_faces"]=faces; assembly.cursor=0; job.stage="descriptors"; break
		elif job.stage=="descriptors":
			if assembly.cursor>=job.pieces.size(): job.result=_finish(job); job.stage="done"; break
			var adapted: Dictionary=Rubble.adapt_slab_descriptor(job.pieces[assembly.cursor])
			if not adapted.ok: return _no("pool_descriptor:"+str(adapted.reason))
			job.descriptors.append(adapted.descriptor); assembly.cursor+=1
		processed+=1
		if Time.get_ticks_usec()-started>=budget_usec: break
	return {"ok":true}

static func _weld_one_face(job: Preparation, face: Dictionary) -> void:
	var assembly: Dictionary=job.assembly
	var polygon: Array[Vector3]=[]
	for point: Vector3 in face.polygon:
		var canonical: Vector3=point
		if assembly.exact.has(point): canonical=assembly.exact[point]
		else:
			var world: Vector3=job.parsed.frame*point
			var bin:=Vector3i(floori(world.x/EPS),floori(world.y/EPS),floori(world.z/EPS))
			var found:=false
			for dx: int in range(-1,2):
				if found: break
				for dy: int in range(-1,2):
					if found: break
					for dz: int in range(-1,2):
						for candidate: Dictionary in assembly.bins.get(bin+Vector3i(dx,dy,dz),[]):
							if candidate.world.distance_squared_to(world)<=EPS*EPS: canonical=candidate.local; found=true; break
						if found: break
			if not found:
				if not assembly.bins.has(bin): assembly.bins[bin]=[]
				assembly.bins[bin].append({"world":world,"local":point})
			assembly.exact[point]=canonical
		if not polygon.has(canonical): polygon.append(canonical)
	if polygon.size()>=3:
		var copy: Dictionary=face.duplicate(); copy.polygon=polygon; assembly.faces.append(copy)

static func _emit_wall_face(job: Preparation, face: Dictionary) -> Dictionary:
	var parsed: Dictionary=job.parsed; var assembly: Dictionary=job.assembly
	var surface: int=int(face.surface) if int(face.source_face)>=0 else parsed.materials.size()
	var buffers: Dictionary=assembly.surfaces[surface]
	for index: int in range(1,face.polygon.size()-1):
		var triangle: Array[Vector3]=[face.polygon[0],face.polygon[index+1],face.polygon[index]]
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()<.00000000000001: continue
		var triangle_index: int=buffers.vertices.size()/3
		for point: Vector3 in triangle:
			var attributes: Array
			if int(face.source_face)>=0: attributes=_sample_authored(parsed.source_faces[face.source_face],point)
			else: attributes=Slab._reveal_attributes(face,point,parsed.frame)
			var normal: Vector3=attributes[1]
			var tangent:=Vector3(attributes[4].x,attributes[4].y,attributes[4].z)
			# Exact native authored samples stay untouched. Interpolated samples
			# retain their original shading field and are normalized for rendering.
			if attributes.size()<=6:
				normal=normal.normalized(); tangent=(tangent-normal*tangent.dot(normal)).normalized()
			buffers.vertices.append(point); buffers.normals.append(normal); buffers.uv.append(attributes[2]); buffers.colors.append(attributes[3]); buffers.uv2.append(attributes[5])
			buffers.tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,attributes[4].w]))
		var source_triangles: Array[int]=[]
		if int(face.source_face)>=0:
			for authored: Dictionary in parsed.source_faces[face.source_face].triangles: source_triangles.append(int(authored.triangle_index))
		assembly.provenance.append({"surface":surface,"triangle":triangle_index,"source_face":int(face.source_face),"source_surface":int(face.surface),"source_triangles":source_triangles,"generated_reveal":int(face.source_face)<0})
		assembly.total_vertices+=3
		if assembly.total_vertices>Slab.MAX_VERTICES: return _no("mesh_vertex_budget")
	return {"ok":true}

static func _sample_authored(face: Dictionary, point: Vector3) -> Array:
	for triangle: Dictionary in face.triangles:
		for vertex: Array in triangle.vertices:
			if vertex[0]==point:
				var exact: Array=vertex.duplicate(); exact.append(true); return exact
	return Slab._sample(face,point)

static func _finish(job: Preparation) -> Dictionary:
	var parsed: Dictionary=job.parsed
	var error: float=absf(job.kept_volume+job.removed_volume-parsed.original_volume)
	var changed: bool=job.new_removed_volume>.000000001
	var built: Dictionary=job.assembly
	var state: Dictionary={"schema":"bounded-convex-component-state/v1","binding":parsed.binding,"brushes_world":job.brushes.duplicate(),"wall_mesh":built.mesh,"wall_provenance":built.provenance}
	return {"ok":true,"changed":changed,"geometry_kind":"closed_authored_convex_component","wall_mesh":built.mesh,"wall_frame":parsed.frame,"wall_collision_faces_world":built.collision_faces,"wall_face_provenance":built.provenance,"debris":job.pieces,"debris_descriptors":job.descriptors,"next_state":state,"source_id":parsed.source.source_id,"source_part_id":parsed.source.source_part_id,"material_class":parsed.profile.material_class,"profile_id":parsed.profile.profile_id,"thickness_m":parsed.thickness,"original_volume_m3":parsed.original_volume,"remaining_volume_m3":job.kept_volume,"total_removed_volume_m3":job.removed_volume,"new_removed_volume_m3":job.new_removed_volume,"volume_error_m3":error,"solid_cells":job.cells,"candidate_cells":job.candidates,"scene_mutated":false}

static func _cached_parse(source: Dictionary, frame: Transform3D, profile: Dictionary, admission: Admission) -> Dictionary:
	var parsed: Dictionary=admission._parsed
	if parsed.is_empty() or source.get("mesh")!=parsed.mesh or frame!=parsed.frame or profile!=admission._profile or str(source.get("source_id",""))!=parsed.source.source_id or str(source.get("source_part_id",""))!=parsed.source.source_part_id: return _no("stale_component_admission")
	if source.get("breakable_glass",false)==true or str(source.get("label",parsed.mesh.resource_name))!=admission._label: return _no("stale_component_admission")
	var mesh: ArrayMesh=parsed.mesh
	if mesh.get_surface_count()!=parsed.binding.arrays.size() or mesh.get_blend_shape_count()!=0: return _no("stale_component_admission")
	var overrides: Variant=source.get("materials",[])
	if not overrides is Array or (not overrides.is_empty() and overrides.size()!=mesh.get_surface_count()): return _no("effective_surface_materials")
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or mesh.surface_get_arrays(surface)!=parsed.binding.arrays[surface]: return _no("stale_component_admission")
		var material: Material=overrides[surface] if not overrides.is_empty() else mesh.surface_get_material(surface)
		if material!=parsed.materials[surface] or material==null: return _no("stale_component_admission")
		if Strength.classify(admission._label,material,parsed.profile.material_class,mesh.get_surface_count()>1)=="glass" or float(material.get_meta("transmission",0.0))>0.0: return _no("glass_has_separate_owner")
	return parsed

static func _parse(source: Dictionary, frame: Transform3D, profile: Dictionary) -> Dictionary:
	if not source.get("mesh") is ArrayMesh: return _no("original_array_mesh_required")
	if source.get("breakable_glass",false)==true: return _no("glass_has_separate_owner")
	if str(source.get("source_id","")).is_empty() or str(source.get("source_part_id","")).is_empty(): return _no("source_identity")
	if profile.get("geometry_mode","")!="bounded_convex_component": return _no("explicit_component_mode_required")
	var family:=str(profile.get("material_class","UNKNOWN")).to_lower()
	if not Strength.DEFAULTS.has(family): return _no("explicit_physical_material_required")
	if str(profile.get("profile_id","")).is_empty() or not profile.get("reveal_material") is Material: return _no("explicit_profile_and_reveal_required")
	if not frame.is_finite() or frame.basis.determinant()<=.000000001: return _no("positive_finite_frame_required")
	# Orthogonal authored placement only; rotation/nonuniform scale is supported,
	# but shearing a beveled component into another physical shape is not inferred.
	var axes: Array[Vector3]=[frame.basis.x.normalized(),frame.basis.y.normalized(),frame.basis.z.normalized()]
	if absf(axes[0].dot(axes[1]))>.00001 or absf(axes[0].dot(axes[2]))>.00001 or absf(axes[1].dot(axes[2]))>.00001: return _no("sheared_component_frame")
	var mesh: ArrayMesh=source.mesh
	if mesh.get_surface_count()<1 or mesh.get_surface_count()>MAX_SOURCE_SURFACES or mesh.get_blend_shape_count()!=0: return _no("component_surface_budget")
	var box:=mesh.get_aabb()
	if not box.position.is_finite() or not box.size.is_finite() or box.size.x<=EPS or box.size.y<=EPS or box.size.z<=EPS: return _no("positive_source_bounds")
	var physical_size:=box.size*Vector3(frame.basis.x.length(),frame.basis.y.length(),frame.basis.z.length())
	var thin: int=physical_size.min_axis_index()
	if physical_size[physical_size.max_axis_index()]>MAX_COMPONENT_LENGTH or box.get_volume()*frame.basis.determinant()>MAX_COMPONENT_VOLUME: return _no("not_a_bounded_solid_component")
	var chunk: Variant=profile.get("chunk_size_m",.65)
	if not Slab._number(chunk) or float(chunk)<.1 or float(chunk)>1.0: return _no("chunk_size_limits")
	var effective_profile: Dictionary=profile.duplicate(true)
	effective_profile.material_class=family
	var snapshots: Array=[]; var materials: Array[Material]=[]
	var points: Array[Vector3]=[]; var triangles: Array[Dictionary]=[]
	var edges: Dictionary={}
	var overrides: Variant=source.get("materials",[])
	if not overrides is Array or (not overrides.is_empty() and overrides.size()!=mesh.get_surface_count()): return _no("effective_surface_materials")
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _no("triangle_source_required")
		var material: Material=overrides[surface] if not overrides.is_empty() else mesh.surface_get_material(surface)
		if material==null: return _no("explicit_source_material_required")
		if Strength.classify(str(source.get("label",mesh.resource_name)),material,family,mesh.get_surface_count()>1)=="glass" or float(material.get_meta("transmission",0.0))>0.0: return _no("glass_has_separate_owner")
		materials.append(material)
		var arrays: Array=mesh.surface_get_arrays(surface)
		for slot: int in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			if arrays[slot]!=null and not arrays[slot].is_empty(): return _no("unsupported_source_attributes")
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL]==null or arrays[Mesh.ARRAY_TEX_UV]==null or arrays[Mesh.ARRAY_NORMAL].size()!=vertices.size() or arrays[Mesh.ARRAY_TEX_UV].size()!=vertices.size(): return _no("authored_normals_uv_required")
		for slot: int in [Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV2]:
			if arrays[slot]!=null and not arrays[slot].is_empty() and arrays[slot].size()!=vertices.size(): return _no("source_attribute_count")
		if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty() and arrays[Mesh.ARRAY_TANGENT].size()!=vertices.size()*4: return _no("source_tangent_count")
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count: int=indices.size() if not indices.is_empty() else vertices.size()
		if count%3!=0 or triangles.size()+count/3>MAX_SOURCE_TRIANGLES: return _no("source_triangle_budget")
		for offset: int in range(0,count,3):
			var attributes: Array=[]; var ids: Array[int]=[]
			for corner: int in 3:
				var index: int=indices[offset+corner] if not indices.is_empty() else offset+corner
				if index<0 or index>=vertices.size(): return _no("source_index")
				var vertex: Array=Slab._vertex(arrays,index)
				if not _finite_vertex(vertex): return _no("finite_source_attributes")
				attributes.append(vertex)
				var id:=_weld_id(points,vertex[0],frame)
				if points.size()>MAX_SOURCE_POINTS: return _no("source_point_budget")
				ids.append(id)
			var a: Vector3=attributes[0][0]; var b: Vector3=attributes[1][0]; var c: Vector3=attributes[2][0]
			var outward: Vector3=-(b-a).cross(c-a)
			if outward.length_squared()<.00000000000001: return _no("degenerate_source_triangle")
			outward=outward.normalized()
			# Authored shading normals are attributes, not the geometric plane.
			# Native bevel corners deliberately shade both noncoplanar triangles
			# as one rounded quad. Preserve their original interpolation instead
			# of flattening geometry or substituting the shading normal as a plane.
			for corner: int in 3:
				var from: int=ids[corner]; var to: int=ids[(corner+1)%3]
				if from==to: return _no("collapsed_source_edge")
				var key:=str(mini(from,to))+":"+str(maxi(from,to))
				if not edges.has(key): edges[key]={"count":0,"balance":0}
				edges[key].count+=1; edges[key].balance+=1 if from<to else -1
			triangles.append({"vertices":attributes,"ids":ids,"normal":outward,"surface":surface,"triangle_index":offset/3})
		snapshots.append(arrays.duplicate(true))
	for edge: Dictionary in edges.values():
		if edge.count!=2 or edge.balance!=0: return _no("source_not_closed_oriented_manifold")
	var source_faces: Array[Dictionary]=[]
	var normal_matrix:=frame.basis.inverse().transposed()
	var thickness:=INF
	for triangle: Dictionary in triangles:
		var anchor: Vector3=triangle.vertices[0][0]
		var world_normal: Vector3=(normal_matrix*triangle.normal).normalized()
		var separation:=0.0
		for point: Vector3 in points:
			var plane_distance:=world_normal.dot(frame.basis*(point-anchor))
			if plane_distance>EPS: return _no("source_not_convex")
			separation=maxf(separation,-plane_distance)
		thickness=minf(thickness,separation)
		var group_index:=-1
		for i: int in source_faces.size():
			var group: Dictionary=source_faces[i]
			if triangle.normal.dot(group.normal)>.999999 and absf(world_normal.dot(frame.basis*(anchor-group.anchor)))<EPS:
				if group.surface!=triangle.surface: return _no("coplanar_material_discontinuity")
				group_index=i; break
		if group_index<0:
			if source_faces.size()>=MAX_SOURCE_FACES: return _no("source_face_budget")
			source_faces.append({"normal":triangle.normal,"anchor":anchor,"surface":triangle.surface,"triangles":[],"ids":[]})
			group_index=source_faces.size()-1
		var group: Dictionary=source_faces[group_index]
		group.triangles.append(triangle)
		for id: int in triangle.ids:
			if not group.ids.has(id): group.ids.append(id)
	if not is_finite(thickness) or thickness<.02 or thickness>MAX_COMPONENT_THICKNESS: return _no("not_a_bounded_solid_component")
	if profile.has("thickness_m") and (not Slab._number(profile.thickness_m) or absf(float(profile.thickness_m)-thickness)>.00002): return _no("explicit_thickness_mismatch")
	effective_profile.thickness_m=thickness
	# Only merge source triangles when all authored channels have the same
	# affine field. Keep native seams as their original triangles, not resampled
	# quads. This stays within the already admitted source-triangle budget.
	var attribute_faces: Array[Dictionary]=[]
	for group: Dictionary in source_faces:
		var affine:=true
		for triangle: Dictionary in group.triangles:
			for vertex: Array in triangle.vertices:
				if not Slab._attributes_match(vertex,Slab._sample(group,vertex[0])): affine=false
		if affine: attribute_faces.append(group)
		else:
			for triangle: Dictionary in group.triangles:
				attribute_faces.append({"normal":triangle.normal,"anchor":triangle.vertices[0][0],"surface":triangle.surface,"triangles":[triangle],"ids":triangle.ids.duplicate()})
	source_faces=attribute_faces
	var faces: Array[Dictionary]=[]
	for index: int in source_faces.size():
		var group: Dictionary=source_faces[index]
		if group.ids.size()<3 or group.ids.size()>4 or group.triangles.size()!=group.ids.size()-2: return _no("convex_face_must_be_authored_triangle_or_quad")
		var polygon: Array[Vector3]=[]; var centre:=Vector3.ZERO
		for id: int in group.ids: polygon.append(points[id]); centre+=points[id]
		centre/=polygon.size()
		var u: Vector3=(polygon[0]-centre).normalized(); var v: Vector3=group.normal.cross(u)
		polygon.sort_custom(func(a: Vector3,b: Vector3) -> bool: return atan2((a-centre).dot(v),(a-centre).dot(u))<atan2((b-centre).dot(v),(b-centre).dot(u)))
		var authored_area:=0.0; var polygon_area:=0.0
		for triangle: Dictionary in group.triangles:
			var a: Vector3=triangle.vertices[0][0]; var b: Vector3=triangle.vertices[1][0]; var c: Vector3=triangle.vertices[2][0]
			authored_area+=(frame.basis*(b-a)).cross(frame.basis*(c-a)).length()*.5
			for vertex: Array in triangle.vertices:
				if not Slab._attributes_match(vertex,Slab._sample(group,vertex[0])): return _no("non_affine_authored_face_attributes")
		for i: int in range(1,polygon.size()-1): polygon_area+=(frame.basis*(polygon[i]-polygon[0])).cross(frame.basis*(polygon[i+1]-polygon[0])).length()*.5
		if absf(authored_area-polygon_area)>maxf(.000001,authored_area*.0001): return _no("incomplete_convex_face")
		faces.append({"polygon":polygon,"normal":group.normal,"source_face":index,"surface":group.surface,"grid_axis":-1,"grid_plane":-1})
	var volume: float=Slab._volume(faces,frame)
	if volume<=.000001 or volume>MAX_COMPONENT_VOLUME: return _no("bounded_true_convex_volume_required")
	var world_bounds:=AABB(frame*points[0],Vector3.ZERO)
	for point: Vector3 in points: world_bounds=world_bounds.expand(frame*point)
	var binding: Dictionary={"mesh":mesh,"arrays":snapshots,"materials":materials,"frame":frame,"source_id":str(source.source_id),"source_part_id":str(source.source_part_id),"profile":effective_profile.duplicate(true)}
	return {"ok":true,"mesh":mesh,"box":box,"frame":frame,"thin_axis":thin,"thickness":thickness,"original_volume":volume,"triangle_count":triangles.size(),"points":points,"faces":faces,"source_faces":source_faces,"materials":materials,"world_bounds":world_bounds,"chunk_size":float(chunk),"reveal_material":profile.reveal_material,"source":{"source_id":str(source.source_id),"source_part_id":str(source.source_part_id)},"profile":effective_profile,"binding":binding}

static func _weld_id(points: Array[Vector3], point: Vector3, frame: Transform3D) -> int:
	for i: int in points.size():
		if (frame.basis*(points[i]-point)).length_squared()<=EPS*EPS: return i
	points.append(point); return points.size()-1

static func _exact_mesh_faces(mesh: Mesh) -> PackedVector3Array:
	var result:=PackedVector3Array()
	for surface: int in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty(): result.append_array(vertices)
		else:
			for index: int in indices: result.append(vertices[index])
	return result

static func _finite_vertex(vertex: Array) -> bool:
	return vertex[0].is_finite() and vertex[1].is_finite() and vertex[1].length_squared()>.99 and vertex[2].is_finite() and is_finite(vertex[3].r) and is_finite(vertex[3].g) and is_finite(vertex[3].b) and is_finite(vertex[3].a) and vertex[4].is_finite() and vertex[5].is_finite()

static func _no(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"scene_mutated":false}
