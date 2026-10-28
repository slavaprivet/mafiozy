extends "res://scripts/transport/transport_vehicle_debris.gd"
## Transactional load-time candidate. It prepares at most one complete private
## mesh + exact convex hull per step, and exposes the inherited provider only
## after all ordered assemblies validate and commit together.

var _preparing:=false
var _prepare_failed:=""
var _prepare_revision:=0
var _pending_vehicle: Node3D
var _pending_parent: Node3D
var _pending_owner: CollisionObject3D
var _pending_rows: Array=[]
var _pending_entries: Array=[]
var _pending_index:=0
var _pending_meshes_total:=0
var _pending_meshes_done:=0
var _pending_vertices:=0
var _current: Dictionary={}

func configure(_vehicle_root_arg: Node3D,_debris_parent_arg: Node3D,_ordered: Array,_owner_arg: CollisionObject3D=null) -> Dictionary:
	return {"ok":false,"error":"incremental_begin_required"}

func begin_configure(vehicle_root: Node3D,debris_parent: Node3D,ordered: Array,owner: CollisionObject3D=null,damage_revision: int=0) -> Dictionary:
	if _disposed or _vehicle_root!=null or _preparing: return {"ok":false,"error":"already_configured"}
	if damage_revision<0: return {"ok":false,"error":"damage_revision"}
	if not is_instance_valid(vehicle_root) or not is_instance_valid(debris_parent) or not vehicle_root.is_inside_tree() or not debris_parent.is_inside_tree(): return {"ok":false,"error":"missing_tree"}
	if absf(vehicle_root.global_transform.basis.determinant())<.000001 or absf(debris_parent.global_transform.basis.determinant())<.000001: return {"ok":false,"error":"singular_transform"}
	if ordered.is_empty(): return {"ok":false,"error":"assemblies"}
	if owner!=null and (not is_instance_valid(owner) or not owner.is_inside_tree()): return {"ok":false,"error":"owner"}
	var seen: Dictionary={}; var rows: Array=[]; var mesh_total:=0
	for i in mini(ordered.size(),MAX_ASSEMBLIES):
		var value: Variant=ordered[i]
		if not value is Dictionary: return {"ok":false,"error":"assembly_row"}
		var source:=value.get("source") as Node3D
		var mass:=float(value.get("mass_kg",NAN)); var layer: Variant=value.get("collision_layer"); var mask: Variant=value.get("collision_mask")
		var linear_damp:=float(value.get("linear_damp",NAN)); var angular_damp:=float(value.get("angular_damp",NAN)); var friction:=float(value.get("friction",NAN)); var bounce:=float(value.get("bounce",NAN))
		if not is_instance_valid(source) or not source.is_inside_tree() or source==vehicle_root or not vehicle_root.is_ancestor_of(source) or seen.has(source): return {"ok":false,"error":"assembly_source"}
		for prior in seen:
			if source.is_ancestor_of(prior) or prior.is_ancestor_of(source): return {"ok":false,"error":"assembly_overlap"}
		if not is_finite(mass) or mass<=0 or not layer is int or not mask is int or layer<0 or mask<0 or not is_finite(linear_damp) or linear_damp<0 or not is_finite(angular_damp) or angular_damp<0 or not is_finite(friction) or friction<0 or friction>1 or not is_finite(bounce) or bounce<0 or bounce>1: return {"ok":false,"error":"physics_contract"}
		var captured:=_capture_source(source)
		if not captured.get("ok",false): return captured
		mesh_total+=captured.meshes.size(); seen[source]=true
		rows.append({"source":source,"mass":mass,"layer":layer,"mask":mask,"linear_damp":linear_damp,"angular_damp":angular_damp,"friction":friction,"bounce":bounce,"states":captured.states,"mesh_nodes":captured.meshes,"mesh_relatives":captured.mesh_relatives,"bake_basis":captured.bake_basis,"node_count":captured.states.size()})
	if mesh_total==0: return {"ok":false,"error":"assembly_geometry"}
	_pending_vehicle=vehicle_root; _pending_parent=debris_parent; _pending_owner=owner; _pending_rows=rows; _pending_entries=[]; _pending_index=0
	_pending_meshes_total=mesh_total; _pending_meshes_done=0; _pending_vertices=0; _prepare_revision=damage_revision; _prepare_failed=""; _current={}; _preparing=true
	return preparation_receipt()

func prepare_step(expected_damage_revision: int,max_meshes: int=1) -> Dictionary:
	if _disposed: return {"ok":false,"error":"disposed"}
	if not _preparing: return {"ok":false,"error":_prepare_failed if not _prepare_failed.is_empty() else "not_preparing"}
	if expected_damage_revision!=_prepare_revision: return {"ok":false,"error":"stale_damage_revision"}
	if max_meshes!=1: return {"ok":false,"error":"budget"}
	var boundary:=_validate_pending_boundary()
	if not boundary.is_empty(): return _fail_preparation(boundary)
	while _pending_index<_pending_rows.size():
		if _current.is_empty():
			var started:=_start_assembly(_pending_rows[_pending_index])
			if not started.get("ok",false): return _fail_preparation(started.get("error","assembly"))
			_current=started
		if _current.mesh_cursor<_current.mesh_nodes.size():
			var built:=_prepare_mesh(_current,_current.mesh_nodes[_current.mesh_cursor])
			if not built.get("ok",false): return _fail_preparation(built.get("error","mesh"))
			_current.mesh_cursor=int(_current.mesh_cursor)+1; _pending_meshes_done+=1
			if _current.mesh_cursor==_current.mesh_nodes.size():
				var finished:=_finish_assembly(_current)
				if not finished.get("ok",false): return _fail_preparation(finished.get("error","assembly_geometry"))
				_pending_entries.append(finished.entry); _current={}; _pending_index+=1
			if _pending_index==_pending_rows.size() and _current.is_empty(): return _commit_preparation()
			return preparation_receipt()
		return _fail_preparation("assembly_geometry")
	return _commit_preparation()

func preparation_receipt() -> Dictionary:
	return {"ok":_preparing and _prepare_failed.is_empty(),"error":_prepare_failed,"state":"PREPARING" if _preparing else ("FAILED" if not _prepare_failed.is_empty() else ("CONFIGURED" if _vehicle_root!=null else "EMPTY")),"damage_revision":_prepare_revision,"assemblies_total":_pending_rows.size(),"assemblies_prepared":_pending_entries.size(),"meshes_total":_pending_meshes_total,"meshes_prepared":_pending_meshes_done,"vertices":_pending_vertices,"partial_provider_exposed":false}

func prewarm_step(budget: int=1,expected_damage_revision: int=-1) -> Dictionary:
	if _preparing: return {"ok":false,"error":"PREPARATION_PENDING","meshes_prepared":_pending_meshes_done,"meshes_total":_pending_meshes_total}
	if _vehicle_root!=null and expected_damage_revision!=_prepare_revision: return {"ok":false,"error":"stale_damage_revision"}
	return super.prewarm_step(budget)

func launch(motions: Array,expected_damage_revision: int=-1) -> Dictionary:
	if _preparing: return {"ok":false,"error":"PREPARATION_PENDING","meshes_prepared":_pending_meshes_done,"meshes_total":_pending_meshes_total}
	if _vehicle_root!=null and expected_damage_revision!=_prepare_revision: return {"ok":false,"error":"stale_damage_revision"}
	return super.launch(motions)

func cancel_preparation() -> bool:
	if not _preparing: return false
	_clear_pending(); _preparing=false; _prepare_failed="cancelled"; return true

func dispose() -> void:
	if _preparing: _clear_pending(); _preparing=false
	super.dispose()

func _capture_source(source: Node3D) -> Dictionary:
	var states: Array=[]; var meshes: Array=[]; var state_stack: Array[Node]=[source]
	while not state_stack.is_empty():
		var node: Node=state_stack.pop_back()
		if node is Node3D:
			if not node.visible: return {"ok":false,"error":"assembly_invisible"}
			states.append({"node":node,"parent":node.get_parent(),"visible":node.visible,"transform":node.transform,"mesh":node.mesh if node is MeshInstance3D else null})
		for child: Node in node.get_children():
			if child is Node3D: state_stack.append(child)
	var stack: Array[Node]=[source]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is MeshInstance3D:
			if not _opaque_mesh(node):
				if node==source: return {"ok":false,"error":"assembly_transparent"}
				continue
			meshes.append(node)
		for child: Node in node.get_children():
			if child is Node3D: stack.append(child)
	var source_transform:=source.global_transform
	if absf(source_transform.basis.determinant())<.000001: return {"ok":false,"error":"singular_transform"}
	var inverse:=source_transform.affine_inverse(); var rigid_basis:=Basis(source_transform.basis.get_rotation_quaternion()); var bake_basis:=rigid_basis.inverse()*source_transform.basis
	var mesh_relatives: Dictionary={}
	for mesh_node: MeshInstance3D in meshes: mesh_relatives[mesh_node.get_instance_id()]=inverse*mesh_node.global_transform
	return {"ok":true,"states":states,"meshes":meshes,"mesh_relatives":mesh_relatives,"bake_basis":bake_basis}

func _start_assembly(row: Dictionary) -> Dictionary:
	var pairs: Dictionary={}; var skeleton:=_copy_skeleton(row.source,true,pairs)
	if not skeleton.get("ok",false): return skeleton
	return {"ok":true,"row":row,"template":skeleton.node,"pairs":pairs,"bake_basis":row.bake_basis,"mesh_relatives":row.mesh_relatives,"mesh_nodes":row.mesh_nodes,"mesh_cursor":0,"hulls":[],"collisions":[],"bindings":[]}

func _copy_skeleton(source: Node3D,root_node: bool,pairs: Dictionary) -> Dictionary:
	if not source.visible: return {"ok":false,"error":"assembly_invisible"}
	if source is MeshInstance3D and not _opaque_mesh(source): return {"ok":false,"error":"assembly_transparent"} if root_node else {"ok":true,"node":null}
	var copy: Node3D=MeshInstance3D.new() if source is MeshInstance3D else Node3D.new(); copy.name=source.name; copy.transform=Transform3D.IDENTITY if root_node else source.transform; pairs[source.get_instance_id()]=copy
	for child: Node in source.get_children():
		if not child is Node3D: continue
		var result:=_copy_skeleton(child,false,pairs)
		if not result.get("ok",false): copy.free(); return result
		if result.node!=null: copy.add_child(result.node)
	return {"ok":true,"node":copy}

func _prepare_mesh(current: Dictionary,source_node: MeshInstance3D) -> Dictionary:
	if not is_instance_valid(source_node) or source_node.mesh==null or not current.pairs.has(source_node.get_instance_id()): return {"ok":false,"error":"geometry_changed"}
	var private_node:=current.pairs[source_node.get_instance_id()] as MeshInstance3D
	var mesh_copy: Mesh=source_node.mesh.duplicate(true)
	if mesh_copy==null or mesh_copy==source_node.mesh: return {"ok":false,"error":"duplicate_failed"}
	for surface in mesh_copy.get_surface_count():
		var material: Material=source_node.get_active_material(surface)
		if material==null: return {"ok":false,"error":"material_missing"}
		mesh_copy.surface_set_material(surface,material.duplicate(true))
	private_node.mesh=mesh_copy; private_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if not current.mesh_relatives.has(source_node.get_instance_id()): return {"ok":false,"error":"geometry_changed"}
	var points:=PackedVector3Array(); var relative: Transform3D=current.mesh_relatives[source_node.get_instance_id()]
	for surface in source_node.mesh.get_surface_count():
		var arrays: Array=source_node.mesh.surface_get_arrays(surface); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		_pending_vertices+=vertices.size()
		if _pending_vertices>MAX_VERTICES: return {"ok":false,"error":"vertex_limit"}
		for vertex in vertices:
			var point: Vector3=current.bake_basis*(relative*vertex)
			if not point.is_finite(): return {"ok":false,"error":"geometry_nonfinite"}
			points.append(point)
	if points.size()<4: return {"ok":false,"error":"assembly_geometry"}
	var shape:=ConvexPolygonShape3D.new(); shape.points=points; var collision:=CollisionShape3D.new(); collision.shape=shape
	current.hulls.append(shape); current.collisions.append(collision); current.bindings.append({"node":source_node,"mesh":source_node.mesh})
	return {"ok":true}

func _finish_assembly(current: Dictionary) -> Dictionary:
	if current.hulls.is_empty(): return {"ok":false,"error":"assembly_geometry"}
	var row: Dictionary=current.row; var body:=RigidBody3D.new(); body.name="Vehicle_debris_"+str(_pending_index)+"_"+String(row.source.name); body.mass=row.mass; body.collision_layer=0; body.collision_mask=0; body.can_sleep=true; body.linear_damp=row.linear_damp; body.angular_damp=row.angular_damp
	var physics_material:=PhysicsMaterial.new(); physics_material.friction=row.friction; physics_material.bounce=row.bounce; body.physics_material_override=physics_material; body.freeze=true
	current.template.visible=false; body.add_child(current.template); body.set_meta("source_assembly",String(row.source.name)); body.set_meta("assembly_index",_pending_index)
	return {"ok":true,"entry":{"source":row.source,"template":current.template,"body":body,"collisions":current.collisions,"hulls":current.hulls,"bindings":current.bindings,"states":row.states,"node_count":row.node_count,"bake_basis":current.bake_basis,"mass":row.mass,"layer":row.layer,"mask":row.mask,"visible":true}}

func _validate_pending_boundary() -> String:
	if not is_instance_valid(_pending_vehicle) or not is_instance_valid(_pending_parent) or not _pending_vehicle.is_inside_tree() or not _pending_parent.is_inside_tree(): return "missing_tree"
	if _pending_owner!=null and (not is_instance_valid(_pending_owner) or not _pending_owner.is_inside_tree()): return "owner_changed"
	for row: Dictionary in _pending_rows:
		var source:=row.source as Node3D
		if not is_instance_valid(source) or not _pending_vehicle.is_ancestor_of(source) or _descendant_node_count(source)!=row.node_count: return "hierarchy_changed"
		var source_basis:=source.global_transform.basis
		if absf(source_basis.determinant())<.000001: return "singular_transform"
		var current_bake:=Basis(source_basis.get_rotation_quaternion()).inverse()*source_basis
		if not current_bake.is_equal_approx(row.bake_basis): return "assembly_pose_changed"
		for state: Dictionary in row.states:
			var node:=state.node as Node3D
			if not is_instance_valid(node) or node.get_parent()!=state.parent or node.visible!=state.visible: return "hierarchy_changed"
			if not node.transform.is_equal_approx(state.transform): return "assembly_pose_changed"
			if node is MeshInstance3D and node.mesh!=state.mesh: return "geometry_changed"
	return ""

func _commit_preparation() -> Dictionary:
	var boundary:=_validate_pending_boundary()
	if not boundary.is_empty(): return _fail_preparation(boundary)
	_vehicle_root=_pending_vehicle; _debris_parent=_pending_parent; _owner=_pending_owner; _entries=_pending_entries
	_pending_vehicle=null; _pending_parent=null; _pending_owner=null; _pending_rows=[]; _pending_entries=[]; _current={}; _preparing=false
	return {"ok":true,"state":"CONFIGURED","damage_revision":_prepare_revision,"assemblies":_entries.size(),"hulls":_hull_count(),"vertices":_pending_vertices,"partial_provider_exposed":false}

func _fail_preparation(error: String) -> Dictionary:
	_clear_pending(); _preparing=false; _prepare_failed=error; return {"ok":false,"error":error,"partial_provider_exposed":false}

func _clear_pending() -> void:
	if not _current.is_empty():
		for collision in _current.get("collisions",[]):
			if is_instance_valid(collision) and collision.get_parent()==null: collision.free()
		if is_instance_valid(_current.get("template")): _current.template.free()
	_free_staged(_pending_entries); _pending_vehicle=null; _pending_parent=null; _pending_owner=null; _pending_rows=[]; _pending_entries=[]; _current={}; _pending_index=0; _pending_meshes_total=0; _pending_meshes_done=0; _pending_vertices=0
