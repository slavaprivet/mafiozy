extends RefCounted
## Presentation consumer of an identity-bound native cage snapshot.
## Preparation must happen before contacts; no impact or HP authority here.
const Subdivision=preload("res://scripts/transport/transport_mesh_subdivision.gd")
const CellBinding=preload("res://scripts/transport/transport_deformation_cell_binding.gd")
class SurfaceDeformationJob extends RefCounted:
	var base: PackedVector3Array
	var offsets: PackedVector3Array
	var node_indices: PackedByteArray
	var node_weights: PackedFloat64Array
	var vertex_bindings: PackedInt32Array
	var inverse_basis: Basis
	var vertices:=PackedVector3Array()
	var displacement_local:=PackedVector3Array()
	var normals:=PackedVector3Array()
	func run() -> void:
		vertices=base.duplicate(); displacement_local.resize(vertices.size())
		var unique_local:=PackedVector3Array(); unique_local.resize(node_indices.size()/8)
		for binding_index in unique_local.size():
			var at:=binding_index*8
			var displacement:=offsets[node_indices[at]]*node_weights[at]+offsets[node_indices[at+1]]*node_weights[at+1]+offsets[node_indices[at+2]]*node_weights[at+2]+offsets[node_indices[at+3]]*node_weights[at+3]+offsets[node_indices[at+4]]*node_weights[at+4]+offsets[node_indices[at+5]]*node_weights[at+5]+offsets[node_indices[at+6]]*node_weights[at+6]+offsets[node_indices[at+7]]*node_weights[at+7]
			unique_local[binding_index]=inverse_basis*displacement
		for i in vertices.size():
			displacement_local[i]=unique_local[vertex_bindings[i]]
			vertices[i]+=displacement_local[i]
		normals.resize(vertices.size())
		for tri in range(0,vertices.size(),3):
			var normal: Vector3=(vertices[tri+1]-vertices[tri]).cross(vertices[tri+2]-vertices[tri]).normalized()
			for corner in 3: normals[tri+corner]=normal
var _body: RigidBody3D
var _visual_root: Node3D
var _ref: Dictionary
var _profile: Dictionary
var _rows: Array=[]
var _cursor:=0
var _revision:=-1
var _disposed:=false

func configure(visual: RefCounted, body: RigidBody3D, vehicle_ref: Dictionary, profile_source: Dictionary) -> bool:
	if _body!=null or visual==null or not is_instance_valid(body) or not is_instance_valid(visual.get("root")): return false
	if not vehicle_ref.get("vehicle_id") is String or (vehicle_ref.get("vehicle_id") as String).is_empty() or not vehicle_ref.get("life_generation") is int or int(vehicle_ref.life_generation)<1: return false
	if not visual.get("nodes") is Dictionary or not visual.get("profile_id") is String or not profile_source.get("id") is String: return false
	if body.get_meta("vehicle_id",null)!=vehicle_ref.get("vehicle_id") or body.get_meta("life_generation",null)!=vehicle_ref.get("life_generation"): return false
	for field in ["halfWidth","halfLength","height"]:
		if not (profile_source.get(field) is float or profile_source.get(field) is int) or not is_finite(float(profile_source[field])) or float(profile_source[field])<=0: return false
	var visual_root: Node3D=visual.get("root")
	if not body.is_inside_tree() or not body.is_ancestor_of(visual_root) or profile_source.get("id")!=visual.get("profile_id") or body.get_meta("profile_id",null)!=visual.get("profile_id"): return false
	var rows: Array=[]
	var seen: Dictionary={}
	for node: Node in (visual.get("nodes") as Dictionary).values():
		if not node is MeshInstance3D or not node.mesh is ArrayMesh or seen.has(node) or not visual_root.is_ancestor_of(node): continue
		seen[node]=true
		var count:=0; var all_transparent:=true
		for surface in node.mesh.get_surface_count():
			count+=node.mesh.surface_get_array_len(surface)
			var material=node.mesh.surface_get_material(surface)
			if not material is BaseMaterial3D or material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED: all_transparent=false
		if all_transparent or count>90000: continue
		var excluded:=false; var parent: Node=node
		while parent!=visual_root and parent!=null:
			var metadata: Dictionary=parent.get_meta("source_metadata",{})
			var name: String=parent.get_meta("source_name","")
			if metadata.has("vehicleWheelId") or metadata.get("crashDeform",true)==false or name.begins_with("Interior_") or name.contains("damage_effects"): excluded=true; break
			parent=parent.get_parent()
		if not excluded: rows.append({"node":node,"original":node.mesh,"prepared":null,"surfaces":[],"last_offsets":PackedVector3Array(),"frame":Transform3D.IDENTITY,"original_positions":[],"external_dirty":false})
	if rows.is_empty(): return false
	_body=body; _visual_root=visual_root; _ref=vehicle_ref.duplicate(true); _profile=profile_source.duplicate(true); _rows=rows
	return true

func prepare_step(mesh_budget: int=1) -> Dictionary:
	if not _valid() or mesh_budget<1: return {"ok":false}
	var gx:=PackedFloat64Array([-float(_profile.halfWidth),0.0,float(_profile.halfWidth)])
	var gy:=PackedFloat64Array([.28,float(_profile.height)*.46,float(_profile.height)*.91])
	var gz:=PackedFloat64Array([-float(_profile.halfLength),-float(_profile.halfLength)*.5,0.0,float(_profile.halfLength)*.5,float(_profile.halfLength)])
	var done:=0
	while _cursor<_rows.size() and done<mesh_budget:
		var row: Dictionary=_rows[_cursor]
		if not is_instance_valid(row.node) or row.node.mesh!=row.original: return {"ok":false,"error":"geometry_changed"}
		var result:=Subdivision.subdivide(row.original,.15,9000)
		if not result.get("ok",false): return result
		row.prepared=result.mesh
		var frame: Transform3D=_body.global_transform.affine_inverse()*row.node.global_transform
		if absf(frame.basis.determinant())<.000001: return {"ok":false,"error":"singular_mesh"}
		row.frame=frame
		row.reach_bounds_source=_source_bounds(frame,row.original.get_aabb())
		for original_surface in row.original.get_surface_count():
			var original_arrays: Array=row.original.surface_get_arrays(original_surface)
			row.original_positions.append((original_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
		for surface in row.prepared.get_surface_count():
			var arrays: Array=row.prepared.surface_get_arrays(surface)
			var base: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			var node_indices:=PackedByteArray()
			var node_weights:=PackedFloat64Array()
			var vertex_bindings:=PackedInt32Array(); vertex_bindings.resize(base.size())
			var bindings_by_point: Dictionary={}
			var mask:=0
			for i in base.size():
				var p: Vector3=frame*base[i]
				if bindings_by_point.has(p):
					vertex_bindings[i]=bindings_by_point[p]
					continue
				var binding_index:=bindings_by_point.size(); bindings_by_point[p]=binding_index; vertex_bindings[i]=binding_index
				var xi:=CellBinding._source_interval(gx,-p.x); var yi:=CellBinding._source_interval(gy,p.y); var zi:=CellBinding._source_interval(gz,-p.z)
				var xt:=CellBinding._source_blend(gx,-p.x,xi); var yt:=CellBinding._source_blend(gy,p.y,yi); var zt:=CellBinding._source_blend(gz,-p.z,zi)
				var lower:=zi*9+yi*3+xi
				for zz in 2:
					for yy in 2:
						for xx in 2:
							var node_index:=lower+zz*9+yy*3+xx; mask|=1<<node_index; node_indices.append(node_index)
							node_weights.append((xt if xx else 1.0-xt)*(yt if yy else 1.0-yt)*(zt if zz else 1.0-zt))
			row.surfaces.append({"arrays":arrays,"base":base.duplicate(),"prepared_base":base.duplicate(),"vertex_bindings":vertex_bindings,"node_indices":node_indices,"node_weights":node_weights,"mask":mask,"material":row.prepared.surface_get_material(surface),"name":row.prepared.surface_get_name(surface),"last_written":PackedVector3Array(),"last_displacement":PackedVector3Array()})
		_cursor+=1; done+=1
	return {"ok":true,"status":"READY" if _cursor==_rows.size() else "PREPARING","prepared":_cursor,"total":_rows.size()}

## Actual snapshot: vehicle_id,life_generation,profile_id,revision,
## positions_native/rest_native PackedVector3Array45 from the mechanical owner.
func apply_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _valid() or _cursor!=_rows.size(): return {"ok":false,"error":"PREPARATION_PENDING"}
	if snapshot.get("vehicle_id")!=_ref.vehicle_id or snapshot.get("life_generation")!=_ref.life_generation or snapshot.get("profile_id")!=_profile.id or not snapshot.get("revision") is int: return {"ok":false,"error":"identity"}
	var revision: int=snapshot.revision
	if revision<0 or revision<_revision: return {"ok":false,"error":"stale_revision"}
	if revision==_revision: return {"ok":true,"revision":revision,"changed_meshes":0,"changed_nodes":[]}
	var positions: Variant=snapshot.get("positions_native"); var rest: Variant=snapshot.get("rest_native")
	if not positions is PackedVector3Array or not rest is PackedVector3Array or positions.size()!=45 or rest.size()!=45: return {"ok":false,"error":"cage"}
	var offsets:=PackedVector3Array(); offsets.resize(45)
	for i in 45:
		if not positions[i].is_finite() or not rest[i].is_finite(): return {"ok":false,"error":"nonfinite_cage"}
		offsets[i]=positions[i]-rest[i]
	# Validate every source-visible mesh before touching any visible instance.
	# The source skips hidden subtrees and excludes the vehicle root's visibility.
	var active: Array=[]
	for row: Dictionary in _rows:
		if not is_instance_valid(row.node): return {"ok":false,"error":"geometry_changed"}
		if not _source_visible(row.node): continue
		if row.node.mesh not in [row.original,row.prepared]: return {"ok":false,"error":"geometry_changed"}
		var current: Transform3D=_body.global_transform.affine_inverse()*row.node.global_transform
		if not current.is_equal_approx(row.frame): return {"ok":false,"error":"assembly_frame_changed"}
		var current_positions: Array=[]
		if row.node.mesh==row.original:
			pass
		else:
			if row.prepared.get_surface_count()!=row.surfaces.size(): return {"ok":false,"error":"geometry_changed"}
			for surface_index in row.surfaces.size():
				var current_arrays: Array=row.prepared.surface_get_arrays(surface_index)
				if not current_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or current_arrays[Mesh.ARRAY_VERTEX].size()!=row.surfaces[surface_index].base.size(): return {"ok":false,"error":"geometry_changed"}
				current_positions.append((current_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
		active.append({"row":row,"current_positions":current_positions})
	var changed:=0
	var changed_nodes: Array[MeshInstance3D]=[]
	var work_rows: Array=[]
	for item: Dictionary in active:
		var row: Dictionary=item.row
		var source_changed: bool=row.external_dirty
		var current_positions: Array=item.current_positions
		for surface_index in current_positions.size():
			var surface: Dictionary=row.surfaces[surface_index]
			var current_vertices: PackedVector3Array=current_positions[surface_index]
			if not _vectors_equal(current_vertices,surface.last_written):
				source_changed=true
				var prior: PackedVector3Array=surface.last_displacement
				for vertex_index in current_vertices.size():
					surface.base[vertex_index]=current_vertices[vertex_index]-(prior[vertex_index] if prior.size()==current_vertices.size() else Vector3.ZERO)
		var affected:=source_changed
		if (row.last_offsets as PackedVector3Array).size()!=45 and not source_changed:
			if not _reaches_mesh(row,offsets): continue
			if not _original_unchanged(row): return {"ok":false,"error":"geometry_changed"}
		for surface: Dictionary in row.surfaces:
			for i in 45:
				if (surface.mask & (1<<i))!=0 and ((row.last_offsets as PackedVector3Array).size()!=45 and offsets[i]!=Vector3.ZERO or (row.last_offsets as PackedVector3Array).size()==45 and offsets[i]!=row.last_offsets[i]): affected=true; break
			if affected: break
		if not affected: continue
		var inverse_basis: Basis=(row.frame as Transform3D).basis.inverse()
		var jobs: Array[SurfaceDeformationJob]=[]
		for surface: Dictionary in row.surfaces:
			var job:=SurfaceDeformationJob.new(); job.base=surface.base; job.offsets=offsets; job.node_indices=surface.node_indices; job.node_weights=surface.node_weights; job.vertex_bindings=surface.vertex_bindings; job.inverse_basis=inverse_basis; jobs.append(job)
		work_rows.append({"row":row,"jobs":jobs,"tasks":[]})
	# Jobs own only packed arrays and one output surface each. They never touch
	# Nodes, ArrayMesh resources or shared writable buffers. Wait synchronously,
	# then commit every result on the main thread in the same source impact frame.
	for work: Dictionary in work_rows:
		for job: SurfaceDeformationJob in work.jobs:
			work.tasks.append(WorkerThreadPool.add_task(job.run,true,"vehicle deformation surface"))
	for work: Dictionary in work_rows:
		for task_id: int in work.tasks: WorkerThreadPool.wait_for_task_completion(task_id)
	for work: Dictionary in work_rows:
		var row: Dictionary=work.row; row.prepared.clear_surfaces()
		for surface_index in row.surfaces.size():
			var surface: Dictionary=row.surfaces[surface_index]; var job: SurfaceDeformationJob=work.jobs[surface_index]
			var arrays: Array=surface.arrays.duplicate(true); arrays[Mesh.ARRAY_VERTEX]=job.vertices; arrays[Mesh.ARRAY_NORMAL]=job.normals
			row.prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var output_surface: int=row.prepared.get_surface_count()-1
			row.prepared.surface_set_material(output_surface,surface.material)
			row.prepared.surface_set_name(output_surface,surface.name)
			surface.last_written=job.vertices.duplicate()
			surface.last_displacement=job.displacement_local
		row.node.mesh=row.prepared; row.last_offsets=offsets.duplicate(); row.external_dirty=false; changed+=1; changed_nodes.append(row.node)
	_revision=revision
	return {"ok":true,"revision":revision,"changed_meshes":changed,"changed_nodes":changed_nodes}

## Call after an external in-place position edit. The next newer cage revision
## preserves that edit exactly as source base=current-position-prior-offset.
func notify_positions_changed(node: MeshInstance3D) -> bool:
	if not _valid() or not is_instance_valid(node): return false
	for row: Dictionary in _rows:
		if row.node==node and node.mesh==row.prepared:
			row.external_dirty=true
			return true
	return false

func reset() -> void:
	for row: Dictionary in _rows:
		if is_instance_valid(row.node): row.node.mesh=row.original
		row.last_offsets=PackedVector3Array()
		row.external_dirty=false
		for surface: Dictionary in row.surfaces:
			surface.base=(surface.prepared_base as PackedVector3Array).duplicate()
			surface.last_written=PackedVector3Array()
			surface.last_displacement=PackedVector3Array()
	_revision=-1

func dispose() -> void:
	if _disposed: return
	reset(); _rows.clear(); _body=null; _visual_root=null; _disposed=true

func _valid() -> bool:
	return not _disposed and is_instance_valid(_body) and _body.is_inside_tree() and _body.get_meta("vehicle_id",null)==_ref.get("vehicle_id") and _body.get_meta("life_generation",null)==_ref.get("life_generation")

static func _interval(value: float, lo: float, hi: float, intervals: int) -> float:
	return clampf((value-lo)/(hi-lo)*intervals,0,intervals)

static func _grid_interval(value: float, grid: PackedFloat64Array) -> float:
	if value<=grid[0]: return 0.0
	if value>=grid[-1]: return float(grid.size()-1)
	for i in grid.size()-1:
		if value<=grid[i+1]: return i+(value-grid[i])/(grid[i+1]-grid[i])
	return float(grid.size()-1)

func _source_visible(node: Node3D) -> bool:
	var current: Node3D=node
	while current!=_visual_root:
		if current==null or not current.visible: return false
		current=current.get_parent() as Node3D
	return true

static func _vectors_equal(a: PackedVector3Array,b: PackedVector3Array) -> bool:
	if a.size()!=b.size(): return false
	for i in a.size():
		if a[i]!=b[i]: return false
	return true

static func _original_unchanged(row: Dictionary) -> bool:
	if row.original.get_surface_count()!=row.original_positions.size(): return false
	for surface in row.original_positions.size():
		var arrays: Array=row.original.surface_get_arrays(surface)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not _vectors_equal(arrays[Mesh.ARRAY_VERTEX],row.original_positions[surface]): return false
	return true

static func _source_bounds(frame: Transform3D,bounds: AABB) -> AABB:
	var result:=AABB()
	for corner in 8:
		var local:=bounds.position+Vector3(bounds.size.x if corner&1 else 0.0,bounds.size.y if corner&2 else 0.0,bounds.size.z if corner&4 else 0.0)
		var native:=frame*local
		var source:=Vector3(-native.x,native.y,-native.z)
		if corner==0: result=AABB(source,Vector3.ZERO)
		else: result=result.expand(source)
	return result

func _reaches_mesh(row: Dictionary,offsets_native: PackedVector3Array) -> bool:
	var bounds: AABB=row.reach_bounds_source
	var gx:=PackedFloat64Array([-float(_profile.halfWidth),0.0,float(_profile.halfWidth)])
	var gy:=PackedFloat64Array([.28,float(_profile.height)*.46,float(_profile.height)*.91])
	var gz:=PackedFloat64Array([-float(_profile.halfLength),-float(_profile.halfLength)*.5,0.0,float(_profile.halfLength)*.5,float(_profile.halfLength)])
	for x in _axis(bounds.position.x,bounds.end.x,gx):
		for y in _axis(bounds.position.y,bounds.end.y,gy):
			for z in _axis(bounds.position.z,bounds.end.z,gz):
				var d:=_sample_offset_native(Vector3(x,y,z),offsets_native,gx,gy,gz)
				if d.length_squared()>=.000001: return true
	return false

static func _axis(lo: float,hi: float,grid: PackedFloat64Array) -> PackedFloat64Array:
	var result:=PackedFloat64Array([lo,hi])
	for value in grid:
		if value>lo and value<hi: result.append(value)
	return result

static func _sample_offset_native(point_source: Vector3,offsets: PackedVector3Array,gx: PackedFloat64Array,gy: PackedFloat64Array,gz: PackedFloat64Array) -> Vector3:
	var xi:=CellBinding._source_interval(gx,point_source.x); var yi:=CellBinding._source_interval(gy,point_source.y); var zi:=CellBinding._source_interval(gz,point_source.z)
	var xt:=CellBinding._source_blend(gx,point_source.x,xi); var yt:=CellBinding._source_blend(gy,point_source.y,yi); var zt:=CellBinding._source_blend(gz,point_source.z,zi); var result:=Vector3.ZERO
	for z in 2:
		for y in 2:
			for x in 2:
				result+=offsets[((zi+z)*3+yi+y)*3+xi+x]*((xt if x else 1.0-xt)*(yt if y else 1.0-yt)*(zt if z else 1.0-zt))
	return result
