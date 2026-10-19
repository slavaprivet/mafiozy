extends "res://scripts/transport/candidates/transport_vehicle_debris_refresh.gd"
## Candidate transaction for the source explosion-frame debris material copy.
## Exact host order is: char source materials, finish onExplosion callback,
## hide glass, stage+commit this snapshot, then launch/hide source assemblies.
## Damage, callback, glass, explosion selection and authority remain host-owned.

const SOURCE_EXPLOSION_ORDER := [
	"char_source_materials",
	"on_explosion_callback",
	"hide_glass",
	"stage_and_commit_private_materials",
	"launch_and_hide_sources",
]
static var _standard_storage_names: Array[StringName]=[]

class MaterialStageToken extends RefCounted:
	var nonce: int
	func _init(value: int) -> void: nonce=value

var _visual_revision:=0
var _visual_committed:=false
var _visual_sealed:=false
var _pending_materials: Dictionary={}
var _pending_connections: Array=[]
var _committed_rows: Array=[]
var _committed_connections: Array=[]
var _committed_changed:=false
var _next_nonce:=1

func configure(vehicle_root: Node3D, debris_parent: Node3D, ordered: Array, owner: CollisionObject3D=null, initial_revision: int=0, initial_visual_revision: int=0) -> Dictionary:
	if initial_visual_revision<0: return {"ok":false,"error":"visual_revision"}
	if _disposed or _vehicle_root!=null: return {"ok":false,"error":"already_configured"}
	var result: Dictionary=super.configure(vehicle_root,debris_parent,ordered,owner,initial_revision)
	if not result.get("ok",false): return result
	_visual_revision=0; _visual_committed=false; _visual_sealed=false; _pending_materials.clear(); _committed_rows.clear(); _committed_changed=false
	_visual_revision=initial_visual_revision
	result["visual_revision"]=_visual_revision
	result["source_explosion_order"]=SOURCE_EXPLOSION_ORDER.duplicate()
	return result

## Duplicates every effective active source material, but does not mutate any
## prepared mesh or revision. Only one staged transaction may exist.
func stage_material_snapshot(expected_revision: int, revision: int) -> Dictionary:
	if _disposed or _vehicle_root==null: return {"ok":false,"error":"not_configured"}
	if _launched or _visual_sealed: return {"ok":false,"error":"after_launch"}
	if _visual_committed: return {"ok":false,"error":"already_committed"}
	if not _pending_materials.is_empty(): return {"ok":false,"error":"pending"}
	if expected_revision!=_visual_revision or expected_revision==9223372036854775807 or revision!=expected_revision+1: return {"ok":false,"error":"stale_revision"}
	var collected:=_collect_material_rows()
	if not collected.get("ok",false): return collected
	var staged: Array=[]
	for row: Dictionary in collected.rows:
		var source:=row.source as MeshInstance3D
		var private:=row.private as MeshInstance3D
		var source_materials: Array=[]; var private_materials: Array=[]; var copies: Array=[]; var source_signatures: Array=[]; var private_signatures: Array=[]
		for surface in source.mesh.get_surface_count():
			var source_material:=source.get_active_material(surface) as Material
			var private_material:=private.get_active_material(surface) as Material
			if source_material==null or private_material==null: return {"ok":false,"error":"material_missing"}
			var copied:=source_material.duplicate(true) as Material
			if copied==null or copied==source_material: return {"ok":false,"error":"material_duplicate"}
			var source_signature:=_base_material_signature(source_material); var private_signature:=_base_material_signature(private_material)
			if source_signature.is_empty() or private_signature.is_empty(): return {"ok":false,"error":"unsupported_material"}
			source_materials.append(source_material); private_materials.append(private_material); copies.append(copied); source_signatures.append(source_signature); private_signatures.append(private_signature)
		staged.append({"source":source,"private":private,"source_parent":source.get_parent(),"private_parent":private.get_parent(),"template":row.template,"entry_source":row.entry_source,"refresh_row":row.refresh_row,"source_mesh":source.mesh,"private_mesh":private.mesh,"source_materials":source_materials,"private_materials":private_materials,"source_signatures":source_signatures,"private_signatures":private_signatures,"copies":copies})
	var token:=MaterialStageToken.new(_next_nonce); _next_nonce+=1
	_pending_materials={"token":token,"expected_revision":expected_revision,"revision":revision,"rows":staged,"content_changed":false}
	var watched: Array=[]
	for row: Dictionary in staged:
		for material: Material in row.source_materials+row.private_materials:
			var graph:=_resource_graph(material)
			if not graph.ok:
				_pending_materials.clear(); return {"ok":false,"error":"unsupported_material_graph"}
			watched.append_array(graph.resources)
	_pending_connections=_watch_resources(watched,Callable(self,"_mark_pending_changed").bind(token.nonce))
	return {"ok":true,"stage_token":token,"revision":revision,"meshes":staged.size(),"surfaces":_surface_count(staged)}

## Commit is atomic with respect to all validated bindings. The host calls this
## only after its callback and glass step have completed.
func commit_material_snapshot(stage_token: RefCounted) -> Dictionary:
	if _pending_materials.is_empty(): return {"ok":false,"error":"no_pending"}
	if stage_token==null or stage_token!=_pending_materials.token: return {"ok":false,"error":"stage_token"}
	if _disposed or _vehicle_root==null or _launched or _visual_sealed: return {"ok":false,"error":"lifecycle"}
	if _visual_revision!=int(_pending_materials.expected_revision): return {"ok":false,"error":"stale_revision"}
	if _pending_materials.content_changed: return {"ok":false,"error":"material_content_changed"}
	var entry_error:=_validate_all_entries()
	if not entry_error.is_empty(): return {"ok":false,"error":entry_error}
	for row: Dictionary in _pending_materials.rows:
		var error:=_validate_staged_row(row)
		if not error.is_empty(): return {"ok":false,"error":error}
	# All source and prepared identities are validated before the first write.
	for row: Dictionary in _pending_materials.rows:
		var mesh:=row.private_mesh as ArrayMesh
		for surface in row.copies.size(): mesh.surface_set_material(surface,row.copies[surface])
		row.refresh_row.materials=row.copies.duplicate()
	var revision:=int(_pending_materials.revision); var committed_rows: Array=_pending_materials.rows.duplicate(); var meshes:=committed_rows.size(); var surfaces:=_surface_count(committed_rows)
	_disconnect_all(_pending_connections); _pending_connections.clear(); _pending_materials.clear()
	_committed_rows=committed_rows; _committed_changed=false
	var committed_materials: Array=[]
	for row: Dictionary in _committed_rows:
		row["committed_signatures"]=[]
		for material: Material in row.copies:
			row.committed_signatures.append(_base_material_signature(material))
			committed_materials.append_array(_resource_graph(material).resources)
	_committed_connections=_watch_resources(committed_materials,Callable(self,"_mark_committed_changed"))
	_visual_revision=revision; _visual_committed=true
	return {"ok":true,"revision":revision,"meshes":meshes,"surfaces":surfaces}

func abort_material_snapshot(stage_token: RefCounted) -> Dictionary:
	if _pending_materials.is_empty(): return {"ok":false,"error":"no_pending"}
	if stage_token==null or stage_token!=_pending_materials.token: return {"ok":false,"error":"stage_token"}
	_disconnect_all(_pending_connections); _pending_connections.clear(); _pending_materials.clear()
	return {"ok":true,"revision":_visual_revision}

## Prevents bypassing the committed post-callback visual receipt.
func launch(motions: Array) -> Dictionary:
	return {"ok":false,"error":"visual_revision_required"}

func launch_with_visual_revision(motions: Array, expected_visual_revision: int) -> Dictionary:
	if not _pending_materials.is_empty(): return {"ok":false,"error":"pending"}
	if not _visual_committed or expected_visual_revision!=_visual_revision: return {"ok":false,"error":"visual_revision"}
	var snapshot_error:=_validate_committed_snapshot()
	if not snapshot_error.is_empty(): return {"ok":false,"error":snapshot_error}
	var result: Dictionary=super.launch(motions)
	if result.get("ok",false): _visual_sealed=true
	return result

func material_snapshot_receipt() -> Dictionary:
	var ids: Array=[]
	for entry: Dictionary in _entries:
		if not is_instance_valid(entry.get("source")) or not is_instance_valid(entry.get("template")) or entry.source.is_queued_for_deletion() or entry.template.is_queued_for_deletion():
			return {"revision":_visual_revision,"committed":_visual_committed,"sealed":_visual_sealed,"pending":not _pending_materials.is_empty(),"valid":false,"error":"stale_node","material_ids":[]}
		var pairs: Dictionary={}
		if not _pair_subtree(entry.source,entry.template,pairs): return {"revision":_visual_revision,"committed":_visual_committed,"sealed":_visual_sealed,"pending":not _pending_materials.is_empty(),"valid":false,"error":"binding_layout","material_ids":[]}
		for binding: Dictionary in entry.bindings:
			var private:=pairs.get((binding.node as MeshInstance3D).get_instance_id()) as MeshInstance3D
			if private==null or private.mesh==null: return {}
			for surface in private.mesh.get_surface_count():
				var material:=private.get_active_material(surface)
				ids.append(material.get_instance_id() if material!=null else 0)
	return {"revision":_visual_revision,"committed":_visual_committed,"sealed":_visual_sealed,"pending":not _pending_materials.is_empty(),"valid":_visual_committed and _validate_committed_snapshot().is_empty(),"material_ids":ids}

func refresh_geometry(assembly_source: Node3D, dirty_meshes: Array, expected_revision: int, revision: int) -> Dictionary:
	if _visual_committed or not _pending_materials.is_empty() or _visual_sealed: return {"ok":false,"error":"material_snapshot_started"}
	return super.refresh_geometry(assembly_source,dirty_meshes,expected_revision,revision)

func reset() -> void:
	_disconnect_all(_pending_connections); _pending_connections.clear(); _pending_materials.clear()
	_disconnect_all(_committed_connections); _committed_connections.clear(); _committed_rows.clear(); _committed_changed=false
	_visual_committed=false; _visual_sealed=false
	super.reset()

func dispose() -> void:
	_disconnect_all(_pending_connections); _pending_connections.clear(); _pending_materials.clear()
	_disconnect_all(_committed_connections); _committed_connections.clear(); _committed_rows.clear(); _committed_changed=false
	_visual_committed=false; _visual_sealed=false; _visual_revision=0
	super.dispose()

func _collect_material_rows() -> Dictionary:
	var rows: Array=[]; var source_ids: Dictionary={}; var private_ids: Dictionary={}
	for entry: Dictionary in _entries:
		var entry_error:=_validate_entry(entry)
		if not entry_error.is_empty(): return {"ok":false,"error":entry_error}
		if not is_instance_valid(entry.source) or not is_instance_valid(entry.template) or entry.source.is_queued_for_deletion() or entry.template.is_queued_for_deletion(): return {"ok":false,"error":"stale_node"}
		var pairs: Dictionary={}
		if not _pair_subtree(entry.source,entry.template,pairs): return {"ok":false,"error":"binding_layout"}
		for binding: Dictionary in entry.bindings:
			var source:=binding.get("node") as MeshInstance3D
			if not is_instance_valid(source) or source.is_queued_for_deletion() or source.mesh==null: return {"ok":false,"error":"stale_node"}
			if binding.get("mesh")!=source.mesh: return {"ok":false,"error":"mesh_replaced"}
			var private:=pairs.get(source.get_instance_id()) as MeshInstance3D
			if not is_instance_valid(private) or private.is_queued_for_deletion() or private.mesh==null: return {"ok":false,"error":"stale_node"}
			if source_ids.has(source.get_instance_id()) or private_ids.has(private.get_instance_id()): return {"ok":false,"error":"duplicate_binding"}
			source_ids[source.get_instance_id()]=true; private_ids[private.get_instance_id()]=true
			if not source.mesh is ArrayMesh or not private.mesh is ArrayMesh or source.mesh.get_surface_count()!=private.mesh.get_surface_count(): return {"ok":false,"error":"surface_layout"}
			if private.material_override!=null: return {"ok":false,"error":"private_override"}
			var refresh_row:=_find_refresh_row(source)
			if refresh_row.is_empty(): return {"ok":false,"error":"binding_layout"}
			rows.append({"source":source,"private":private,"template":entry.template,"entry_source":entry.source,"refresh_row":refresh_row})
	return {"ok":true,"rows":rows}

func _validate_staged_row(row: Dictionary) -> String:
	var source_value: Variant=row.get("source"); var private_value: Variant=row.get("private")
	if not is_instance_valid(source_value) or not is_instance_valid(private_value): return "stale_node"
	var source:=source_value as MeshInstance3D; var private:=private_value as MeshInstance3D
	if source==null or private==null or source.is_queued_for_deletion() or private.is_queued_for_deletion(): return "stale_node"
	if not is_instance_valid(row.template) or not is_instance_valid(row.entry_source) or row.template.is_queued_for_deletion() or row.entry_source.is_queued_for_deletion(): return "stale_node"
	if source.get_parent()!=row.source_parent or private.get_parent()!=row.private_parent: return "binding_parent"
	if not _vehicle_root.is_ancestor_of(source) or (private!=row.template and not row.template.is_ancestor_of(private)): return "binding_parent"
	if source.mesh!=row.source_mesh or private.mesh!=row.private_mesh: return "mesh_replaced"
	if not source.mesh is ArrayMesh or not private.mesh is ArrayMesh: return "mesh_type"
	if source.mesh.get_surface_count()!=row.source_materials.size() or private.mesh.get_surface_count()!=row.private_materials.size(): return "surface_layout"
	if private.material_override!=null: return "private_override"
	for surface in row.source_materials.size():
		if source.get_active_material(surface)!=row.source_materials[surface]: return "source_material_changed"
		if private.get_active_material(surface)!=row.private_materials[surface]: return "private_material_changed"
		if _base_material_signature(row.source_materials[surface])!=row.source_signatures[surface]: return "material_content_changed"
		if _base_material_signature(row.private_materials[surface])!=row.private_signatures[surface]: return "material_content_changed"
	return ""

func _validate_committed_snapshot() -> String:
	if not _visual_committed: return "visual_revision"
	if _committed_changed: return "private_material_changed"
	var entry_error:=_validate_all_entries()
	if not entry_error.is_empty(): return entry_error
	for row: Dictionary in _committed_rows:
		var private_value: Variant=row.get("private")
		if not is_instance_valid(private_value): return "private_mesh_changed"
		var private:=private_value as MeshInstance3D
		if private==null or private.is_queued_for_deletion() or private.mesh!=row.private_mesh: return "private_mesh_changed"
		if not is_instance_valid(row.template) or row.template.is_queued_for_deletion() or private.get_parent()!=row.private_parent or (private!=row.template and not row.template.is_ancestor_of(private)): return "private_binding_changed"
		if private.mesh.get_surface_count()!=row.copies.size() or private.material_override!=null: return "surface_layout"
		for surface in row.copies.size():
			if private.get_active_material(surface)!=row.copies[surface]: return "private_material_changed"
			if _base_material_signature(row.copies[surface])!=row.committed_signatures[surface]: return "private_material_changed"
	return ""

func _mark_pending_changed(nonce: int) -> void:
	if not _pending_materials.is_empty() and is_instance_valid(_pending_materials.get("token")) and _pending_materials.token.nonce==nonce:
		_pending_materials["content_changed"]=true

func _mark_committed_changed() -> void:
	_committed_changed=true

static func _watch_resources(resources: Array, callback: Callable) -> Array:
	var connections: Array=[]; var seen: Dictionary={}
	for value in resources:
		var resource:=value as Resource
		if resource==null or seen.has(resource.get_instance_id()): continue
		seen[resource.get_instance_id()]=true
		resource.changed.connect(callback)
		connections.append({"resource":resource,"callable":callback})
	return connections

static func _disconnect_all(connections: Array) -> void:
	for row: Dictionary in connections:
		var resource:=row.get("resource") as Resource; var callback: Callable=row.get("callable",Callable())
		if is_instance_valid(resource) and callback.is_valid() and resource.changed.is_connected(callback): resource.changed.disconnect(callback)

## The imported vehicle path uses BaseMaterial3D. Its stored render properties
## are compared byte-for-byte; resource-valued properties are fenced by exact
## identity. ShaderMaterial is rejected instead of claiming incomplete parity.
static func _base_material_signature(material: Material) -> PackedByteArray:
	if not material is StandardMaterial3D: return PackedByteArray()
	var values: Array=[]
	for name: StringName in _storage_names_for(material):
		var value: Variant=material.get(name)
		if value is Object:
			value=value.get_instance_id() if is_instance_valid(value) else 0
		values.append([String(name),typeof(value),value])
	return var_to_bytes(values)

static func _resource_graph(root: Resource) -> Dictionary:
	var resources: Array=[]; var seen: Dictionary={}; var stack: Array=[{"resource":root,"depth":0}]
	while not stack.is_empty():
		var row: Dictionary=stack.pop_back(); var resource:=row.resource as Resource; var depth:=int(row.depth)
		if resource==null or seen.has(resource.get_instance_id()): continue
		if depth>8 or resources.size()>=256: return {"ok":false,"resources":[]}
		seen[resource.get_instance_id()]=true; resources.append(resource)
		for name: StringName in _storage_names_for(resource):
			var value: Variant=resource.get(name)
			if value is Resource: stack.append({"resource":value,"depth":depth+1})
	return {"ok":true,"resources":resources}

static func _storage_names_for(resource: Resource) -> Array[StringName]:
	if resource is StandardMaterial3D and not _standard_storage_names.is_empty(): return _standard_storage_names
	var names: Array[StringName]=[]
	for property: Dictionary in resource.get_property_list():
		if (int(property.get("usage",0))&PROPERTY_USAGE_STORAGE)==0: continue
		var name:=StringName(property.get("name",""))
		if name==&"resource_local_to_scene" or name==&"resource_name" or name==&"resource_path" or name==&"resource_scene_unique_id": continue
		names.append(name)
	if resource is StandardMaterial3D: _standard_storage_names=names
	return names

func _find_refresh_row(source: MeshInstance3D) -> Dictionary:
	for record: Dictionary in _refresh_entries.values():
		for row: Dictionary in record.meshes:
			if row.source==source: return row
	return {}

func _validate_all_entries() -> String:
	for entry: Dictionary in _entries:
		var error:=_validate_entry(entry)
		if not error.is_empty(): return error
	return ""

func _validate_entry(entry: Dictionary) -> String:
	for key in ["source","template","body"]:
		var value: Variant=entry.get(key)
		if not is_instance_valid(value) or value.is_queued_for_deletion(): return "stale_node"
	var source:=entry.source as Node3D; var template:=entry.template as Node3D; var body:=entry.body as RigidBody3D
	if source==null or template==null or body==null: return "stale_node"
	if template.get_parent()!=body: return "prepared_body_changed"
	if body.get_parent()==null:
		if body.get_child_count()!=1: return "prepared_body_changed"
	elif body.get_parent()==_debris_parent:
		if not _ready or body.get_child_count()!=entry.collisions.size()+1: return "prepared_body_changed"
	else: return "prepared_body_changed"
	if not source.is_inside_tree() or not _vehicle_root.is_ancestor_of(source) or not source.visible: return "source_changed"
	if _descendant_node_count(source)!=entry.node_count: return "hierarchy_changed"
	var current_rigid:=Basis(source.global_transform.basis.get_rotation_quaternion())
	if not (current_rigid.inverse()*source.global_transform.basis).is_equal_approx(entry.bake_basis): return "source_scale_changed"
	for state: Dictionary in entry.states:
		var value: Variant=state.get("node")
		if not is_instance_valid(value) or value.is_queued_for_deletion(): return "stale_node"
		var node:=value as Node3D
		if node==null or node.get_parent()!=state.parent or node.visible!=state.visible: return "hierarchy_changed"
		if node!=source and not node.transform.is_equal_approx(state.transform): return "assembly_pose_changed"
		if node is MeshInstance3D and node.mesh!=state.mesh: return "geometry_changed"
	for binding: Dictionary in entry.bindings:
		var value: Variant=binding.get("node")
		if not is_instance_valid(value) or value.is_queued_for_deletion(): return "stale_node"
		var node:=value as MeshInstance3D
		if node==null or node.mesh!=binding.mesh or not (node==source or source.is_ancestor_of(node)): return "geometry_changed"
	return ""

static func _surface_count(rows: Array) -> int:
	var count:=0
	for row: Dictionary in rows: count+=row.copies.size()
	return count
