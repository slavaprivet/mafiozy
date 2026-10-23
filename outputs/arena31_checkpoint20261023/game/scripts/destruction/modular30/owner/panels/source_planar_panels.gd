extends RefCounted
## Pure, incremental decomposition of AUTHORED SKIN triangles, never fitted solids.
## Coplanar, edge-connected faces retain source surface/triangle/vertex identities.
## A closed source component is labelled, not converted into independent slab volume.
const MAX_TRIANGLES := 65536
const MAX_VERTICES := MAX_TRIANGLES*3
const MAX_SURFACES := 64
const MAX_PANELS := 8192
const MAX_PANEL_TRIANGLES := 256
const MAX_EDGE_INCIDENTS := 8
const MAX_PLANE_CANDIDATES := 16
const PLANE_EPS_M := .00001
const NORMAL_EPS := .000001
const PLANE_HASH_NORMAL := .00001
const DEGENERATE_CROSS_SQUARED := .0000000000000001
const MAX_SCALED_COORDINATE_M := 100000.0

class Preparation extends RefCounted:
	var source: Dictionary={}
	var mesh: ArrayMesh
	var frame:=Transform3D.IDENTITY
	var source_id: String
	var source_part_id: String
	var surface_counts:=PackedInt32Array()
	var arrays: Array=[]
	var materials: Array=[]
	var triangles: Array[Dictionary]=[]
	var planes: Array[Dictionary]=[]
	var plane_buckets: Dictionary={}
	var edges: Array[Dictionary]=[]
	var edge_lookup: Dictionary={}
	var planar_parents: Array[int]=[]
	var solid_parents: Array[int]=[]
	var planar_ranks: Array[int]=[]
	var solid_ranks: Array[int]=[]
	var components: Array[Dictionary]=[]
	var component_lookup: Dictionary={}
	var panels: Array[Dictionary]=[]
	var panel_lookup: Dictionary={}
	var triangle_to_panel: Array=[]
	var assigned_counts:=PackedInt32Array()
	var total:=0
	var assigned:=0
	var degenerate:=0
	var cursor:=0
	var surface:=0
	var face:=0
	var panel_cap:=MAX_PANEL_TRIANGLES
	var panel_count_cap:=MAX_PANELS
	var phase:="snapshot"
	var dirty:=false
	var result: Dictionary={}
	var diagnostics: Dictionary={"steps":0,"max_step_usec":0,"max_step_items":0,"snapshot_usec":0,"scan_usec":0,"topology_usec":0,"classify_usec":0,"finalize_usec":0,"source_mutated":false}
	func _source_changed() -> void: dirty=true
	func disconnect_source() -> void:
		if is_instance_valid(mesh) and mesh.changed.is_connected(_source_changed): mesh.changed.disconnect(_source_changed)

static func begin(source: Dictionary,frame: Transform3D,options: Dictionary={}) -> Dictionary:
	if not source.get("mesh") is ArrayMesh or str(source.get("source_id","")).is_empty() or str(source.get("source_part_id","")).is_empty(): return _no("source_identity_and_array_mesh_required")
	if not frame.is_finite() or frame.basis.determinant()<=.000000001: return _no("positive_finite_frame_required")
	var mesh: ArrayMesh=source.mesh
	if mesh.get_blend_shape_count()!=0 or mesh.get_surface_count()<1 or mesh.get_surface_count()>MAX_SURFACES: return _no("surface_or_blend_shape_budget")
	var total_cap: Variant=options.get("max_source_triangles",MAX_TRIANGLES)
	var panel_cap: Variant=options.get("max_panel_triangles",MAX_PANEL_TRIANGLES)
	var count_cap: Variant=options.get("max_panels",MAX_PANELS)
	if not total_cap is int or total_cap<1 or total_cap>MAX_TRIANGLES or not panel_cap is int or panel_cap<1 or panel_cap>MAX_PANEL_TRIANGLES or not count_cap is int or count_cap<1 or count_cap>MAX_PANELS: return _no("budget_options")
	var effective: Variant=source.get("materials",[])
	if not effective is Array or (not effective.is_empty() and effective.size()!=mesh.get_surface_count()): return _no("effective_material_count")
	var job:=Preparation.new(); job.source=source; job.mesh=mesh; job.frame=frame
	job.source_id=str(source.source_id); job.source_part_id=str(source.source_part_id)
	job.panel_cap=panel_cap; job.panel_count_cap=count_cap
	var vertices:=0
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _no("triangle_source_required")
		var unsupported: int=Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS|Mesh.ARRAY_FORMAT_CUSTOM0|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|Mesh.ARRAY_FORMAT_CUSTOM3
		if mesh.surface_get_format(surface)&unsupported: return _no("unsupported_source_attributes")
		vertices+=mesh.surface_get_array_len(surface)
		if vertices>MAX_VERTICES: return _no("source_vertex_budget")
		var count: int=mesh.surface_get_array_index_len(surface)
		if count==0: count=mesh.surface_get_array_len(surface)
		if count%3!=0: return _no("triangle_index_count")
		job.surface_counts.append(count/3); job.assigned_counts.append(0); job.total+=count/3
		if job.total>total_cap: return _no("source_triangle_budget")
		var mapping: Array[int]=[]; mapping.resize(count/3); mapping.fill(-1); job.triangle_to_panel.append(mapping)
		var material: Variant=effective[surface] if not effective.is_empty() else mesh.surface_get_material(surface)
		if material!=null and not material is Material: return _no("effective_material_type")
		job.materials.append(material)
	if job.total==0: return _no("empty_triangle_source")
	mesh.changed.connect(job._source_changed)
	return {"ok":true,"preparation":job,"source_triangles":job.total,"scene_mutated":false,"coverage":"source_skin_only"}

static func advance(job: Preparation,max_items: int=64,budget_usec: int=2000) -> Dictionary:
	if job==null or max_items<1 or max_items>256 or budget_usec<100 or budget_usec>10000: return _no("bounded_step_required")
	if job.phase=="cancelled": return _no("preparation_cancelled")
	if job.phase=="done": return {"ok":job.result.get("ok",false),"done":true,"result":job.result,"processed_this_step":0}
	if job.dirty or job.source.get("mesh")!=job.mesh: return _fail(job,"source_changed_during_preparation")
	var started:=Time.get_ticks_usec(); var processed:=0
	while processed<max_items and job.phase!="done":
		var phase: String=job.phase
		var unit_started:=Time.get_ticks_usec()
		var step: Dictionary
		if phase=="snapshot": step=_snapshot_surface(job)
		elif phase=="scan": step=_scan_triangle(job)
		elif phase=="topology": step=_topology_edge(job)
		elif phase=="classify": step=_classify_triangle(job)
		elif phase=="finalize": step=_finalize_panel(job)
		elif phase=="validate": step=_validate_surface(job)
		else: return _fail(job,"invalid_phase")
		var timing_key: String=phase+"_usec" if phase!="validate" else "finalize_usec"
		job.diagnostics[timing_key]=int(job.diagnostics.get(timing_key,0))+Time.get_ticks_usec()-unit_started
		if not step.get("ok",false): return _fail(job,str(step.get("reason","preparation_failed")))
		if step.get("worked",false): processed+=1
		if Time.get_ticks_usec()-started>=budget_usec: break
	var elapsed:=Time.get_ticks_usec()-started
	job.diagnostics.steps+=1; job.diagnostics.max_step_usec=maxi(job.diagnostics.max_step_usec,elapsed); job.diagnostics.max_step_items=maxi(job.diagnostics.max_step_items,processed)
	if job.phase=="done": job.result.diagnostics=job.diagnostics.duplicate()
	return {"ok":true,"done":job.phase=="done","phase":job.phase,"processed_this_step":processed,"assigned_triangles":job.assigned,"source_triangles":job.total,"result":job.result if job.phase=="done" else {},"scene_mutated":false}

static func cancel(job: Preparation) -> void:
	if job==null or job.phase=="done" or job.phase=="cancelled": return
	job.disconnect_source(); job.phase="cancelled"; job.arrays.clear(); job.triangles.clear(); job.edges.clear(); job.edge_lookup.clear(); job.planes.clear(); job.plane_buckets.clear(); job.panels.clear(); job.components.clear()

static func _snapshot_surface(job: Preparation) -> Dictionary:
	if job.cursor>=job.surface_counts.size(): job.cursor=0; job.phase="scan"; return {"ok":true}
	var arrays: Array=job.mesh.surface_get_arrays(job.cursor)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for slot: int in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
		if arrays[slot]!=null and not arrays[slot].is_empty() and arrays[slot].size()!=vertices.size(): return _no("vertex_attribute_count")
	if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty() and arrays[Mesh.ARRAY_TANGENT].size()!=vertices.size()*4: return _no("vertex_tangent_count")
	job.arrays.append(arrays.duplicate(true)); job.cursor+=1
	return {"ok":true,"worked":true}

static func _scan_triangle(job: Preparation) -> Dictionary:
	while job.surface<job.surface_counts.size() and job.face>=job.surface_counts[job.surface]: job.surface+=1; job.face=0
	if job.surface>=job.surface_counts.size(): job.cursor=0; job.phase="topology"; return {"ok":true}
	var arrays: Array=job.arrays[job.surface]
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var points: Array[Vector3]=[]; var scaled: Array[Vector3]=[]; var source_indices:=PackedInt32Array()
	for corner: int in 3:
		var index: int=indices[job.face*3+corner] if not indices.is_empty() else job.face*3+corner
		if index<0 or index>=vertices.size() or not vertices[index].is_finite(): return _no("vertex_index_or_position")
		for slot: int in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if arrays[slot]!=null and not arrays[slot].is_empty() and not arrays[slot][index].is_finite(): return _no("finite_vertex_attributes")
		if arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty():
			var color: Color=arrays[Mesh.ARRAY_COLOR][index]
			if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a): return _no("finite_vertex_color")
		if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty():
			for component: int in 4:
				if not is_finite(arrays[Mesh.ARRAY_TANGENT][index*4+component]): return _no("finite_vertex_tangent")
		var transformed: Vector3=job.frame.basis*vertices[index]
		if not transformed.is_finite() or maxf(absf(transformed.x),maxf(absf(transformed.y),absf(transformed.z)))>MAX_SCALED_COORDINATE_M: return _no("finite_scaled_vertex_budget")
		points.append(vertices[index]); scaled.append(transformed); source_indices.append(index)
	var cross: Vector3=(scaled[1]-scaled[0]).cross(scaled[2]-scaled[0])
	var degenerate: bool=cross.length_squared()<=DEGENERATE_CROSS_SQUARED
	var plane_id: int=-1
	if not degenerate:
		plane_id=_plane(job,points,scaled,-cross.normalized())
		if plane_id<0: return _no("plane_bucket_budget")
	else: job.degenerate+=1
	var index: int=job.triangles.size()
	var bounds:=AABB(scaled[0]+job.frame.origin,Vector3.ZERO)
	for point: Vector3 in scaled: bounds=bounds.expand(point+job.frame.origin)
	var triangle: Dictionary={"surface":job.surface,"face":job.face,"indices":source_indices,"plane":plane_id,"edges":PackedInt32Array(),"degenerate":degenerate,"area_m2":cross.length()*.5,"bounds":bounds,"open_edges":0,"ambiguous_edges":0}
	job.triangles.append(triangle); job.planar_parents.append(index); job.solid_parents.append(index); job.planar_ranks.append(0); job.solid_ranks.append(0)
	if not degenerate:
		for corner: int in 3:
			var edge_id: int=_edge(job,points[corner],points[(corner+1)%3],index)
			if edge_id<0: return _no("edge_incident_budget")
			triangle.edges.append(edge_id)
	job.face+=1
	return {"ok":true,"worked":true}

static func _plane(job: Preparation,points: Array[Vector3],scaled: Array[Vector3],normal: Vector3) -> int:
	var distance: float=normal.dot(scaled[0])
	var bin:=Vector3i((normal/PLANE_HASH_NORMAL).round())
	var key: String=str(job.surface)+":"+str(bin)+":"+str(roundi(distance/PLANE_EPS_M))
	var candidates: Array=job.plane_buckets.get(key,[])
	for id: int in candidates:
		var plane: Dictionary=job.planes[id]
		if (normal-plane.normal).length_squared()>NORMAL_EPS*NORMAL_EPS: continue
		var fits:=true
		for point: Vector3 in scaled:
			if absf((point-plane.point_scaled).dot(plane.normal))>PLANE_EPS_M: fits=false; break
		if fits: return id
	if candidates.size()>=MAX_PLANE_CANDIDATES: return -1
	var local_normal: Vector3=-(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	var id: int=job.planes.size()
	job.planes.append({"normal":normal,"point_scaled":scaled[0],"plane_scaled":Plane(normal,distance),"plane_local":Plane(local_normal,local_normal.dot(points[0]))})
	candidates.append(id); job.plane_buckets[key]=candidates
	return id

static func _less(a: Vector3,b: Vector3) -> bool:
	if a.x!=b.x: return a.x<b.x
	if a.y!=b.y: return a.y<b.y
	return a.z<b.z

static func _edge(job: Preparation,a: Vector3,b: Vector3,triangle: int) -> int:
	var forward: bool=_less(a,b)
	var low: Vector3=a if forward else b; var high: Vector3=b if forward else a
	var ends: Dictionary=job.edge_lookup.get(low,{})
	var id: int=int(ends.get(high,-1))
	if id<0:
		id=job.edges.size(); ends[high]=id; job.edge_lookup[low]=ends
		job.edges.append({"a":low,"b":high,"triangles":PackedInt32Array(),"forward":[]})
	var edge: Dictionary=job.edges[id]
	if edge.triangles.size()>=MAX_EDGE_INCIDENTS: return -1
	edge.triangles.append(triangle); edge.forward.append(forward)
	return id

static func _find_root(parents: Array[int],index: int) -> int:
	# Union by rank bounds each read by O(log source_triangles). Parent/rank
	# Arrays are shared by reference; no whole-source copy occurs per edge.
	while parents[index]!=index: index=parents[index]
	return index

static func _union(job: Preparation,a: int,b: int,planar: bool) -> void:
	var parents: Array[int]=job.planar_parents if planar else job.solid_parents
	var ranks: Array[int]=job.planar_ranks if planar else job.solid_ranks
	var one: int=_find_root(parents,a); var two: int=_find_root(parents,b)
	if one==two: return
	if ranks[one]<ranks[two]:
		var temporary:=one; one=two; two=temporary
	parents[two]=one
	if ranks[one]==ranks[two]: ranks[one]+=1
	if planar: job.planar_parents=parents; job.planar_ranks=ranks
	else: job.solid_parents=parents; job.solid_ranks=ranks

static func _topology_edge(job: Preparation) -> Dictionary:
	if job.cursor>=job.edges.size(): job.cursor=0; job.phase="classify"; job.edge_lookup.clear(); job.plane_buckets.clear(); return {"ok":true}
	var edge: Dictionary=job.edges[job.cursor]
	var manifold: bool=edge.triangles.size()==2 and edge.forward[0]!=edge.forward[1]
	var first: int=edge.triangles[0]
	for id: int in edge.triangles:
		_union(job,first,id,false)
		if edge.triangles.size()==1: job.triangles[id].open_edges+=1
		elif not manifold: job.triangles[id].ambiguous_edges+=1
	if manifold:
		var one: Dictionary=job.triangles[first]; var second: int=edge.triangles[1]; var two: Dictionary=job.triangles[second]
		if one.plane==two.plane and one.surface==two.surface: _union(job,first,second,true)
	job.cursor+=1
	return {"ok":true,"worked":true}

static func _classify_triangle(job: Preparation) -> Dictionary:
	if job.cursor>=job.triangles.size(): job.cursor=0; job.phase="finalize"; return {"ok":true}
	var triangle: Dictionary=job.triangles[job.cursor]
	var solid_root: int=_find_root(job.solid_parents,job.cursor)
	var component_id: int=int(job.component_lookup.get(solid_root,-1))
	if component_id<0:
		component_id=job.components.size(); job.component_lookup[solid_root]=component_id
		job.components.append({"component_id":component_id,"source_triangles":0,"source_faces":[],"source_panels":{},"open_edge_incidents":0,"ambiguous_edge_incidents":0,"degenerate_triangles":0,"planes":{},"area_m2":0.0,"bounds":triangle.bounds,"coverage":"source_skin_only"})
	var component: Dictionary=job.components[component_id]
	component.source_triangles+=1; component.open_edge_incidents+=triangle.open_edges; component.ambiguous_edge_incidents+=triangle.ambiguous_edges
	component.source_faces.append(Vector2i(triangle.surface,triangle.face))
	component.degenerate_triangles+=1 if triangle.degenerate else 0; component.planes[triangle.plane]=true
	component.area_m2+=triangle.area_m2; component.bounds=component.bounds.merge(triangle.bounds)
	var island: int=_find_root(job.planar_parents,job.cursor)
	var panel_id: int=int(job.panel_lookup.get(island,-1))
	if panel_id<0 or job.panels[panel_id].source_triangle_ids.size()>=job.panel_cap:
		if job.panels.size()>=job.panel_count_cap: return _no("panel_count_budget")
		panel_id=job.panels.size(); job.panel_lookup[island]=panel_id
		job.panels.append({"panel_id":panel_id,"source_id":job.source_id,"source_part_id":job.source_part_id,"source_surface":triangle.surface,"source_triangle_ids":PackedInt32Array(),"source_island_id":island,"source_component_id":component_id,"plane_id":triangle.plane,"material":job.materials[triangle.surface],"frame":job.frame,"bounds":triangle.bounds,"area_m2":0.0,"degenerate":triangle.degenerate,"coverage":"source_skin_only","volume_admitted":false,"geometry_kind":"authored_planar_skin" if not triangle.degenerate else "authored_degenerate_skin","bounded_subset":true})
	var panel: Dictionary=job.panels[panel_id]
	if panel.source_surface!=triangle.surface or panel.source_component_id!=component_id or panel.plane_id!=triangle.plane: return _no("partition_identity_mismatch")
	var mapping: Array[int]=job.triangle_to_panel[triangle.surface]
	if mapping[triangle.face]!=-1: return _no("duplicate_source_triangle")
	mapping[triangle.face]=panel_id; job.triangle_to_panel[triangle.surface]=mapping
	panel.source_triangle_ids.append(triangle.face); panel.bounds=panel.bounds.merge(triangle.bounds); panel.area_m2+=triangle.area_m2
	component.source_panels[panel_id]=true
	job.assigned_counts[triangle.surface]+=1; job.assigned+=1; job.cursor+=1
	return {"ok":true,"worked":true}

static func _finalize_panel(job: Preparation) -> Dictionary:
	if job.cursor>=job.panels.size(): job.cursor=0; job.phase="validate"; return {"ok":true}
	var panel: Dictionary=job.panels[job.cursor]
	var component: Dictionary=job.components[panel.source_component_id]
	component.closed_manifold=component.open_edge_incidents==0 and component.ambiguous_edge_incidents==0 and component.degenerate_triangles==0
	component.nonplanar=component.planes.size()>1
	panel.source_component_closed=component.closed_manifold
	panel.source_component_nonplanar=component.nonplanar
	panel.topology_ambiguous=component.ambiguous_edge_incidents>0
	panel.damage_admitted=false
	panel.physical_profile_required=true
	if not panel.degenerate:
		var plane: Dictionary=job.planes[panel.plane_id]
		panel.plane_local=plane.plane_local; panel.plane_scaled=plane.plane_scaled
		panel.plane_world=Plane(plane.normal,plane.plane_scaled.d+plane.normal.dot(job.frame.origin))
	job.cursor+=1
	return {"ok":true,"worked":true}

static func _validate_surface(job: Preparation) -> Dictionary:
	if str(job.source.get("source_id",""))!=job.source_id or str(job.source.get("source_part_id",""))!=job.source_part_id: return _no("source_identity_changed")
	if job.cursor>=job.surface_counts.size():
		if job.assigned!=job.total: return _no("source_coverage_incomplete")
		job.disconnect_source(); job.phase="done"
		job.result={"ok":true,"panels":job.panels,"source_components":job.components,"triangle_to_panel":job.triangle_to_panel,"source_snapshot":{"mesh":job.mesh,"surface_arrays":job.arrays,"materials":job.materials,"surface_counts":job.surface_counts,"source_id":job.source_id,"source_part_id":job.source_part_id,"frame":job.frame},"coverage":{"complete":true,"source_triangles":job.total,"assigned_triangles":job.assigned,"degenerate_triangles":job.degenerate,"duplicates":0,"missing":0,"scope":"source_skin_only"},"diagnostics":job.diagnostics.duplicate(),"scene_mutated":false,"physical_materials_assigned":false,"source_volume_admitted":false}
		return {"ok":true}
	var surface: int=job.cursor
	if job.mesh.get_surface_count()!=job.surface_counts.size() or job.mesh.surface_get_arrays(surface)!=job.arrays[surface] or job.assigned_counts[surface]!=job.surface_counts[surface]: return _no("source_changed_or_coverage_incomplete")
	var effective: Variant=job.source.get("materials",[])
	if not effective is Array or (not effective.is_empty() and effective.size()!=job.surface_counts.size()): return _no("effective_material_count")
	var material: Variant=effective[surface] if not effective.is_empty() else job.mesh.surface_get_material(surface)
	if material!=job.materials[surface]: return _no("source_material_changed")
	job.triangle_to_panel[surface]=PackedInt32Array(job.triangle_to_panel[surface])
	job.cursor+=1
	return {"ok":true,"worked":true}

static func lookup_panel(result: Dictionary,source_surface: int,source_triangle: int) -> Dictionary:
	if result.get("ok")!=true or source_surface<0 or source_surface>=result.triangle_to_panel.size(): return _no("source_surface")
	var mapping: PackedInt32Array=result.triangle_to_panel[source_surface]
	if source_triangle<0 or source_triangle>=mapping.size(): return _no("source_triangle")
	var id: int=mapping[source_triangle]
	return {"ok":true,"panel_id":id,"panel":result.panels[id],"source_surface":source_surface,"source_triangle":source_triangle}

static func panel_mesh(result: Dictionary,panel_id: int) -> Dictionary:
	if result.get("ok")!=true or panel_id<0 or panel_id>=result.panels.size(): return _no("panel_id")
	return subset_mesh(result,panel_id,result.panels[panel_id].source_triangle_ids)

static func component_mesh(result: Dictionary,component_id: int,max_triangles: int=MAX_PANEL_TRIANGLES) -> Dictionary:
	# This only copies the original connected component skin. Closed topology
	# does not prove convexity, physical thickness or destruction admission.
	if result.get("ok")!=true or component_id<0 or component_id>=result.source_components.size(): return _no("component_id")
	var component: Dictionary=result.source_components[component_id]
	if max_triangles<1 or max_triangles>MAX_PANEL_TRIANGLES or component.source_triangles>max_triangles: return _no("component_triangle_budget")
	var surfaces: Dictionary={}
	for reference: Vector2i in component.source_faces:
		if not surfaces.has(reference.x): surfaces[reference.x]=PackedInt32Array()
		surfaces[reference.x].append(reference.y)
	var mesh:=ArrayMesh.new(); var provenance: Array[Dictionary]=[]; var source_surfaces:=PackedInt32Array(); var exact_arrays: Array=[]
	for source_surface: int in surfaces:
		var source: Array=result.source_snapshot.surface_arrays[source_surface]
		var emitted: Array=[]; emitted.resize(Mesh.ARRAY_MAX)
		for slot: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if source[slot]!=null and not source[slot].is_empty(): emitted[slot]=source[slot].slice(0,0)
		var indices: PackedInt32Array=source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var output_surface: int=mesh.get_surface_count(); var output_triangle:=0
		for triangle: int in surfaces[source_surface]:
			var corners:=PackedInt32Array()
			for corner: int in 3:
				var index: int=indices[triangle*3+corner] if not indices.is_empty() else triangle*3+corner
				corners.append(index)
				for slot: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
					if emitted[slot]!=null: emitted[slot].append(source[slot][index])
				if emitted[Mesh.ARRAY_TANGENT]!=null:
					for axis: int in 4: emitted[Mesh.ARRAY_TANGENT].append(source[Mesh.ARRAY_TANGENT][index*4+axis])
			provenance.append({"output_surface":output_surface,"output_triangle":output_triangle,"source_surface":source_surface,"source_triangle":triangle,"source_vertex_indices":corners})
			output_triangle+=1
		exact_arrays.append(emitted)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,emitted); mesh.surface_set_material(output_surface,result.source_snapshot.materials[source_surface]); source_surfaces.append(source_surface)
	var saved: Dictionary=result.source_snapshot
	return {"ok":true,"mesh":mesh,"surface_arrays":exact_arrays,"render_normal_tangent_codec":true,"frame":saved.frame,"source_id":saved.source_id,"source_part_id":saved.source_part_id,"source_component_id":component_id,"source_surfaces":source_surfaces,"face_provenance":provenance,"source_triangles":component.source_triangles,"closed_manifold":component.closed_manifold,"coverage":"source_skin_only","volume_admitted":false,"scene_mutated":false,"snapshot_only":true}

static func subset_mesh(result: Dictionary,panel_id: int,source_triangle_ids: PackedInt32Array) -> Dictionary:
	if result.get("ok")!=true or panel_id<0 or panel_id>=result.panels.size(): return _no("panel_id")
	if source_triangle_ids.is_empty() or source_triangle_ids.size()>MAX_PANEL_TRIANGLES: return _no("subset_triangle_budget")
	var panel: Dictionary=result.panels[panel_id]
	var source: Array=result.source_snapshot.surface_arrays[panel.source_surface]
	var emitted: Array=[]; emitted.resize(Mesh.ARRAY_MAX)
	for slot: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if source[slot]!=null and not source[slot].is_empty(): emitted[slot]=source[slot].slice(0,0)
	var indices: PackedInt32Array=source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var mapping: PackedInt32Array=result.triangle_to_panel[panel.source_surface]
	var seen: Dictionary={}; var provenance: Array[Dictionary]=[]
	for triangle: int in source_triangle_ids:
		if triangle<0 or triangle>=mapping.size() or mapping[triangle]!=panel_id or seen.has(triangle): return _no("subset_membership_or_duplicate")
		seen[triangle]=true
		var corners:=PackedInt32Array()
		for corner: int in 3:
			var index: int=indices[triangle*3+corner] if not indices.is_empty() else triangle*3+corner
			corners.append(index)
			for slot: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
				if emitted[slot]!=null: emitted[slot].append(source[slot][index])
			if emitted[Mesh.ARRAY_TANGENT]!=null:
				for component: int in 4: emitted[Mesh.ARRAY_TANGENT].append(source[Mesh.ARRAY_TANGENT][index*4+component])
		provenance.append({"output_triangle":provenance.size(),"source_surface":panel.source_surface,"source_triangle":triangle,"source_vertex_indices":corners})
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,emitted); mesh.surface_set_material(0,panel.material)
	return {"ok":true,"mesh":mesh,"surface_arrays":[emitted],"render_normal_tangent_codec":true,"frame":panel.frame,"panel_id":panel_id,"face_provenance":provenance,"source_id":panel.source_id,"source_part_id":panel.source_part_id,"source_surface":panel.source_surface,"source_component_id":panel.source_component_id,"coverage":"source_skin_only","scene_mutated":false,"snapshot_only":true}

static func validate_result(result: Dictionary,source: Dictionary,frame: Transform3D) -> Dictionary:
	if result.get("ok")!=true: return _no("completed_result_required")
	var saved: Dictionary=result.source_snapshot
	if source.get("mesh")!=saved.mesh or frame!=saved.frame or str(source.get("source_id",""))!=saved.source_id or str(source.get("source_part_id",""))!=saved.source_part_id: return _no("source_binding_changed")
	var mesh: ArrayMesh=source.mesh
	if mesh.get_surface_count()!=saved.surface_arrays.size() or mesh.get_blend_shape_count()!=0: return _no("source_geometry_changed")
	var effective: Variant=source.get("materials",[])
	if not effective is Array or (not effective.is_empty() and effective.size()!=mesh.get_surface_count()): return _no("effective_material_count")
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or mesh.surface_get_arrays(surface)!=saved.surface_arrays[surface]: return _no("source_geometry_changed")
		var material: Variant=effective[surface] if not effective.is_empty() else mesh.surface_get_material(surface)
		if material!=saved.materials[surface]: return _no("source_material_changed")
	return {"ok":true,"coverage":"source_skin_only"}

static func _fail(job: Preparation,reason: String) -> Dictionary:
	job.disconnect_source(); job.phase="done"; job.result=_no(reason)
	return {"ok":false,"done":true,"reason":reason,"result":job.result,"scene_mutated":false}

static func _no(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"scene_mutated":false,"partial_result_rejected":true}
