extends "res://scripts/transport/transport_vehicle_debris.gd"
## Candidate exact geometry refresh seam. Damage/event authority remains with host.
## In-place edits cannot be discovered; caller must report every dirty mesh.
var _refresh_entries: Dictionary={}
var _refresh_sealed:=false
var _refresh_total_vertices:=0

func configure(vehicle_root: Node3D, debris_parent: Node3D, ordered: Array, owner: CollisionObject3D=null, initial_revision: int=0) -> Dictionary:
	if initial_revision<0: return {"ok":false,"error":"revision"}
	var result: Dictionary=super.configure(vehicle_root,debris_parent,ordered,owner)
	if not result.get("ok",false): return result
	var source_meshes: Dictionary={}
	for entry: Dictionary in _entries:
		if entry.bindings.size()!=entry.hulls.size() or entry.bindings.size()!=entry.collisions.size():
			dispose(); return {"ok":false,"error":"unsupported_hull_layout"}
		var pairs: Dictionary={}
		if not _pair_subtree(entry.source,entry.template,pairs):
			dispose(); return {"ok":false,"error":"private_layout"}
		var mesh_rows: Array=[]
		for index in entry.bindings.size():
			var binding: Dictionary=entry.bindings[index]
			var source_node:=binding.node as MeshInstance3D
			var private_node:=pairs.get(source_node.get_instance_id()) as MeshInstance3D
			var state:=_state_for(entry.states,source_node)
			if state.is_empty() or private_node==null or private_node.mesh==null or private_node.mesh.get_surface_count()!=source_node.mesh.get_surface_count():
				dispose(); return {"ok":false,"error":"private_mesh_layout"}
			var mesh_id:=source_node.mesh.get_instance_id()
			if source_meshes.has(mesh_id):
				dispose(); return {"ok":false,"error":"shared_source_mesh"}
			source_meshes[mesh_id]=true
			var materials: Array=[]
			for surface in private_node.mesh.get_surface_count(): materials.append(private_node.get_active_material(surface))
			var count:=_mesh_vertex_count(source_node.mesh)
			_refresh_total_vertices+=count
			mesh_rows.append({"source":source_node,"private":private_node,"private_mesh":private_node.mesh,"shape":entry.hulls[index],"collision":entry.collisions[index],"binding":binding,"state":state,"materials":materials,"vertex_count":count,"collision_points":entry.hulls[index].points.duplicate()})
		_refresh_entries[entry.source.get_instance_id()]={"entry":entry,"revision":initial_revision,"meshes":mesh_rows}
	result["geometry_revision"]=initial_revision
	return result

## All dirty meshes belong to one configured assembly. expected_revision must
## equal the last committed value; revision must advance. Commit is atomic.
func refresh_geometry(assembly_source: Node3D, dirty_meshes: Array, expected_revision: int, revision: int) -> Dictionary:
	if _disposed or _vehicle_root==null: return {"ok":false,"error":"not_configured"}
	if _launched or _refresh_sealed: return {"ok":false,"error":"after_launch"}
	if not is_instance_valid(assembly_source) or not _refresh_entries.has(assembly_source.get_instance_id()): return {"ok":false,"error":"assembly"}
	var record: Dictionary=_refresh_entries[assembly_source.get_instance_id()]
	if record.entry.source!=assembly_source: return {"ok":false,"error":"assembly_identity"}
	if expected_revision!=record.revision or expected_revision==9223372036854775807 or revision!=expected_revision+1: return {"ok":false,"error":"stale_revision"}
	if dirty_meshes.is_empty(): return {"ok":false,"error":"dirty_meshes"}
	var entry: Dictionary=record.entry
	if not assembly_source.is_inside_tree() or not is_instance_valid(_vehicle_root) or not _vehicle_root.is_ancestor_of(assembly_source) or not _transform_finite(assembly_source.global_transform): return {"ok":false,"error":"source_changed"}
	if not is_instance_valid(entry.body) or not is_instance_valid(entry.template) or entry.template.get_parent()!=entry.body or (entry.body.get_parent()!=null and entry.body.get_parent()!=_debris_parent): return {"ok":false,"error":"prepared_changed"}
	# Validate saved source and prepared targets before dereferencing them or
	# staging any replacement resources.
	for state: Dictionary in entry.states:
		var saved_value: Variant=state.get("node")
		if not is_instance_valid(saved_value): return {"ok":false,"error":"hierarchy"}
		var saved_node:=saved_value as Node3D
		if saved_node==null or saved_node.get_parent()!=state.parent or saved_node.visible!=state.visible or not _transform_finite(saved_node.global_transform): return {"ok":false,"error":"hierarchy"}
		if saved_node!=assembly_source and not saved_node.transform.is_equal_approx(state.transform): return {"ok":false,"error":"source_pose"}
	for row: Dictionary in record.meshes:
		if not is_instance_valid(row.source) or not is_instance_valid(row.private) or not is_instance_valid(row.shape) or not is_instance_valid(row.collision): return {"ok":false,"error":"prepared_changed"}
		if row.binding.node!=row.source or row.state.node!=row.source or row.private.mesh!=row.private_mesh or row.collision.shape!=row.shape or (row.private!=entry.template and not entry.template.is_ancestor_of(row.private)): return {"ok":false,"error":"prepared_changed"}
		if row.private.mesh.get_surface_count()!=row.materials.size(): return {"ok":false,"error":"prepared_changed"}
		for surface in row.materials.size():
			if row.private.get_active_material(surface)!=row.materials[surface]: return {"ok":false,"error":"prepared_changed"}
	var current_mesh_owners: Dictionary={}
	for configured_record: Dictionary in _refresh_entries.values():
		for configured_row: Dictionary in configured_record.meshes:
			if not is_instance_valid(configured_row.source) or configured_row.source.mesh==null: return {"ok":false,"error":"hierarchy"}
			var current_mesh_id: int=configured_row.source.mesh.get_instance_id()
			if current_mesh_owners.has(current_mesh_id): return {"ok":false,"error":"shared_source_mesh"}
			current_mesh_owners[current_mesh_id]=true
	var current_rigid:=Basis(assembly_source.global_transform.basis.get_rotation_quaternion())
	var current_bake:=current_rigid.inverse()*assembly_source.global_transform.basis
	if not current_bake.is_equal_approx(entry.bake_basis) or absf(assembly_source.global_transform.basis.determinant())<.000001: return {"ok":false,"error":"source_scale"}
	if _descendant_node_count(assembly_source)!=entry.node_count: return {"ok":false,"error":"hierarchy"}
	var dirty: Dictionary={}
	for value in dirty_meshes:
		if not value is MeshInstance3D or not is_instance_valid(value) or dirty.has(value.get_instance_id()): return {"ok":false,"error":"dirty_identity"}
		dirty[value.get_instance_id()]=true
	var row_by_id: Dictionary={}
	for row: Dictionary in record.meshes: row_by_id[row.source.get_instance_id()]=row
	for id in dirty:
		if not row_by_id.has(id): return {"ok":false,"error":"outside_assembly"}
	# Validate exact configured hierarchy/pose and require every replacement mesh
	# to be explicitly dirty. In-place edits rely on the same explicit contract.
	for state: Dictionary in entry.states:
		var node:=state.node as Node3D
		if node is MeshInstance3D and node.mesh!=state.mesh and not dirty.has(node.get_instance_id()): return {"ok":false,"error":"unreported_geometry"}
	var inverse:=assembly_source.global_transform.affine_inverse()
	var bake:=Transform3D(entry.bake_basis,Vector3.ZERO)
	var staged: Array=[]; var vertex_count:=0; var hull_point_count:=0; var duplicates_removed:=0; var projected_total:=_refresh_total_vertices
	for id in dirty:
		var row: Dictionary=row_by_id[id]
		var source_node:=row.source as MeshInstance3D
		var private_node:=row.private as MeshInstance3D
		if not _opaque_mesh(source_node) or not source_node.mesh is ArrayMesh or not private_node.mesh is ArrayMesh: return {"ok":false,"error":"mesh_type"}
		if source_node.mesh.get_surface_count()!=private_node.mesh.get_surface_count(): return {"ok":false,"error":"surface_layout"}
		var new_mesh:=source_node.mesh.duplicate(true) as ArrayMesh
		var points:=PackedVector3Array(); var transform: Transform3D=bake*(inverse*source_node.global_transform)
		if not _transform_finite(transform): return {"ok":false,"error":"geometry_nonfinite"}
		for surface in source_node.mesh.get_surface_count():
			var private_material: Material=row.materials[surface]
			if private_material==null: return {"ok":false,"error":"private_material"}
			new_mesh.surface_set_material(surface,private_material)
			var arrays: Array=source_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			vertex_count+=vertices.size()
			if vertices.is_empty() or vertex_count>MAX_VERTICES: return {"ok":false,"error":"vertices"}
			var transformed: PackedVector3Array=transform*vertices
			for point in transformed:
				if not point.is_finite(): return {"ok":false,"error":"geometry_nonfinite"}
			points.append_array(transformed)
		if points.size()<4: return {"ok":false,"error":"hull_points"}
		var exact_points:=_exact_unique_points(points)
		if exact_points.size()<4: return {"ok":false,"error":"hull_points"}
		hull_point_count+=exact_points.size(); duplicates_removed+=points.size()-exact_points.size()
		projected_total+=points.size()-int(row.vertex_count)
		if projected_total>MAX_VERTICES: return {"ok":false,"error":"vertex_limit"}
		staged.append({"row":row,"source_mesh":source_node.mesh,"private_mesh":new_mesh,"points":exact_points,"vertex_count":points.size()})
	# No prepared visual, shape, binding or revision mutates before this point.
	for change: Dictionary in staged:
		var row: Dictionary=change.row
		row.private.mesh=change.private_mesh
		row.shape.points=change.points
		row.binding.mesh=change.source_mesh
		row.state.mesh=change.source_mesh
		row.private_mesh=change.private_mesh
		row.vertex_count=change.vertex_count
		row.collision_points=(change.points as PackedVector3Array).duplicate()
	_refresh_total_vertices=projected_total
	record.revision=revision
	return {"ok":true,"revision":revision,"changed_meshes":staged.size(),"vertices":vertex_count,"hull_points":hull_point_count,"duplicates_removed":duplicates_removed}

func launch(motions: Array) -> Dictionary:
	# A successful launch seals geometry permanently. Frozen reset() can restore
	# and relaunch the wreck, but it never reopens damage refresh or rolls back it.
	var result: Dictionary=super.launch(motions)
	if result.get("ok",false): _refresh_sealed=true
	return result

func geometry_receipt(assembly_source: Node3D) -> Dictionary:
	if not is_instance_valid(assembly_source) or not _refresh_entries.has(assembly_source.get_instance_id()): return {}
	var record: Dictionary=_refresh_entries[assembly_source.get_instance_id()]
	var private_mesh_ids: Array=[]; var shape_ids: Array=[]; var material_ids: Array=[]; var maxima: Array=[]; var point_hashes: Array=[]; var point_hashes_by_source: Dictionary={}; var point_sets_by_source: Dictionary={}; var body_id: int=record.entry.body.get_instance_id() if is_instance_valid(record.entry.body) else 0
	for row: Dictionary in record.meshes:
		private_mesh_ids.append(row.private.mesh.get_instance_id()); shape_ids.append(row.shape.get_instance_id())
		for surface in row.private.mesh.get_surface_count(): material_ids.append(row.private.get_active_material(surface).get_instance_id())
		var collision_points: PackedVector3Array=row.get("collision_points",row.shape.points)
		var maximum:=Vector3(-INF,-INF,-INF)
		for point in collision_points: maximum=maximum.max(point)
		var point_hash:=hash(collision_points); maxima.append(maximum); point_hashes.append(point_hash); point_hashes_by_source[row.source.get_instance_id()]=point_hash; point_sets_by_source[row.source.get_instance_id()]=collision_points.duplicate()
	return {"revision":record.revision,"body_id":body_id,"private_mesh_ids":private_mesh_ids,"shape_ids":shape_ids,"material_ids":material_ids,"point_maxima":maxima,"point_hashes":point_hashes,"point_hashes_by_source":point_hashes_by_source,"point_sets_by_source":point_sets_by_source,"bake_basis":record.entry.bake_basis}

func dispose() -> void:
	_refresh_entries.clear()
	_refresh_total_vertices=0
	super.dispose()

func _pair_subtree(source: Node3D, copy: Node3D, pairs: Dictionary) -> bool:
	if source is MeshInstance3D:
		if not copy is MeshInstance3D: return false
		pairs[source.get_instance_id()]=copy
	var copy_index:=0
	for child in source.get_children():
		if not child is Node3D: continue
		if child is MeshInstance3D and not _opaque_mesh(child): continue
		if copy_index>=copy.get_child_count(): return false
		var copy_child:=copy.get_child(copy_index) as Node3D
		if copy_child==null or String(copy_child.name)!=String(child.name) or not _pair_subtree(child,copy_child,pairs): return false
		copy_index+=1
	return copy_index==copy.get_child_count()

static func _state_for(states: Array, node: Node3D) -> Dictionary:
	for state: Dictionary in states:
		if state.node==node: return state
	return {}

static func _mesh_vertex_count(mesh: Mesh) -> int:
	var count:=0
	for surface in mesh.get_surface_count(): count+=mesh.surface_get_array_len(surface)
	return count

## Exact Vector3 hash/equality only: no epsilon, quantization, rounding,
## clustering or point motion. First occurrence order is preserved.
static func _exact_unique_points(points: PackedVector3Array) -> PackedVector3Array:
	var seen: Dictionary={}; var result:=PackedVector3Array()
	for point in points:
		if seen.has(point): continue
		seen[point]=true; result.append(point)
	return result

static func _transform_finite(value: Transform3D) -> bool:
	return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite()
