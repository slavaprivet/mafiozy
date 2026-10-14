extends "res://scripts/transport/candidates/transport_vehicle_debris_material_snapshot.gd"
## Bounded candidate over the frozen post-callback snapshot. It caches only
## reads of the exact same source Material Resource inside one synchronous
## stage or commit-validation phase. No cache survives the phase; private
## materials remain one independently duplicated Resource per copied surface.

class CachedMaterialStageToken extends RefCounted:
	var nonce: int
	func _init(value: int) -> void: nonce=value

func stage_material_snapshot(expected_revision: int, revision: int) -> Dictionary:
	if _disposed or _vehicle_root==null: return {"ok":false,"error":"not_configured"}
	if _launched or _visual_sealed: return {"ok":false,"error":"after_launch"}
	if _visual_committed: return {"ok":false,"error":"already_committed"}
	if not _pending_materials.is_empty(): return {"ok":false,"error":"pending"}
	if expected_revision!=_visual_revision or expected_revision==9223372036854775807 or revision!=expected_revision+1: return {"ok":false,"error":"stale_revision"}
	var collected:=_collect_material_rows()
	if not collected.get("ok",false): return collected
	var source_signature_cache: Dictionary={}
	var source_graph_cache: Dictionary={}
	var metrics:={"source_signature_reads":0,"source_signature_cache_hits":0,"source_graph_reads":0,"source_graph_cache_hits":0}
	var staged: Array=[]
	for row: Dictionary in collected.rows:
		var source:=row.source as MeshInstance3D
		var private:=row.private as MeshInstance3D
		var source_materials: Array=[]; var private_materials: Array=[]; var copies: Array=[]; var source_signatures: Array=[]; var private_signatures: Array=[]
		for surface in source.mesh.get_surface_count():
			var source_material:=source.get_active_material(surface) as Material
			var private_material:=private.get_active_material(surface) as Material
			if source_material==null or private_material==null: return {"ok":false,"error":"material_missing"}
			# This allocation remains per surface even when source_material aliases.
			var copied:=source_material.duplicate(true) as Material
			if copied==null or copied==source_material: return {"ok":false,"error":"material_duplicate"}
			var source_signature:=_cached_source_signature(source_material,source_signature_cache,metrics)
			var private_signature:=_base_material_signature(private_material)
			if source_signature.is_empty() or private_signature.is_empty(): return {"ok":false,"error":"unsupported_material"}
			source_materials.append(source_material); private_materials.append(private_material); copies.append(copied); source_signatures.append(source_signature); private_signatures.append(private_signature)
		staged.append({"source":source,"private":private,"source_parent":source.get_parent(),"private_parent":private.get_parent(),"template":row.template,"entry_source":row.entry_source,"refresh_row":row.refresh_row,"source_mesh":source.mesh,"private_mesh":private.mesh,"source_materials":source_materials,"private_materials":private_materials,"source_signatures":source_signatures,"private_signatures":private_signatures,"copies":copies})
	var token:=CachedMaterialStageToken.new(_next_nonce); _next_nonce+=1
	_pending_materials={"token":token,"expected_revision":expected_revision,"revision":revision,"rows":staged,"content_changed":false}
	var watched: Array=[]
	for row: Dictionary in staged:
		for material: Material in row.source_materials:
			var graph:=_cached_source_graph(material,source_graph_cache,metrics)
			if not graph.ok:
				_pending_materials.clear(); return {"ok":false,"error":"unsupported_material_graph"}
			watched.append_array(graph.resources)
		for material: Material in row.private_materials:
			var graph:=_resource_graph(material)
			if not graph.ok:
				_pending_materials.clear(); return {"ok":false,"error":"unsupported_material_graph"}
			watched.append_array(graph.resources)
	_pending_connections=_watch_resources(watched,Callable(self,"_mark_pending_changed").bind(token.nonce))
	return _with_cache_metrics({"ok":true,"stage_token":token,"revision":revision,"meshes":staged.size(),"surfaces":_surface_count(staged)},metrics)

func commit_material_snapshot(stage_token: RefCounted) -> Dictionary:
	if _pending_materials.is_empty(): return {"ok":false,"error":"no_pending"}
	if stage_token==null or stage_token!=_pending_materials.token: return {"ok":false,"error":"stage_token"}
	if _disposed or _vehicle_root==null or _launched or _visual_sealed: return {"ok":false,"error":"lifecycle"}
	if _visual_revision!=int(_pending_materials.expected_revision): return {"ok":false,"error":"stale_revision"}
	if _pending_materials.content_changed: return {"ok":false,"error":"material_content_changed"}
	var entry_error:=_validate_all_entries()
	if not entry_error.is_empty(): return {"ok":false,"error":entry_error}
	var source_signature_cache: Dictionary={}
	var metrics:={"source_signature_reads":0,"source_signature_cache_hits":0,"source_graph_reads":0,"source_graph_cache_hits":0}
	for row: Dictionary in _pending_materials.rows:
		var error:=_validate_staged_row_cached(row,source_signature_cache,metrics)
		if not error.is_empty(): return _with_cache_metrics({"ok":false,"error":error},metrics)
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
	return _with_cache_metrics({"ok":true,"revision":revision,"meshes":meshes,"surfaces":surfaces},metrics)

func launch_with_visual_revision(motions: Array, expected_visual_revision: int) -> Dictionary:
	var result: Dictionary=super.launch_with_visual_revision(motions,expected_visual_revision)
	# Launch validates only the  independently owned private copies. There is no
	# source read to deduplicate, and no cache is carried from stage or commit.
	return _with_cache_metrics(result,{"source_signature_reads":0,"source_signature_cache_hits":0,"source_graph_reads":0,"source_graph_cache_hits":0})

func _validate_staged_row_cached(row: Dictionary, source_signature_cache: Dictionary, metrics: Dictionary) -> String:
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
		var source_material:=row.source_materials[surface] as Material
		var private_material:=row.private_materials[surface] as Material
		if source.get_active_material(surface)!=source_material: return "source_material_changed"
		if private.get_active_material(surface)!=private_material: return "private_material_changed"
		if _cached_source_signature(source_material,source_signature_cache,metrics)!=row.source_signatures[surface]: return "material_content_changed"
		# Private material reads remain per surface and byte/type exact.
		if _base_material_signature(private_material)!=row.private_signatures[surface]: return "material_content_changed"
	return ""

static func _cached_source_signature(material: Material, cache: Dictionary, metrics: Dictionary) -> PackedByteArray:
	var identity:=material.get_instance_id()
	if cache.has(identity):
		metrics.source_signature_cache_hits=int(metrics.source_signature_cache_hits)+1
		return cache[identity]
	var signature:=_base_material_signature(material)
	cache[identity]=signature
	metrics.source_signature_reads=int(metrics.source_signature_reads)+1
	return signature

static func _cached_source_graph(material: Material, cache: Dictionary, metrics: Dictionary) -> Dictionary:
	var identity:=material.get_instance_id()
	if cache.has(identity):
		metrics.source_graph_cache_hits=int(metrics.source_graph_cache_hits)+1
		return cache[identity]
	var graph:=_resource_graph(material)
	cache[identity]=graph
	metrics.source_graph_reads=int(metrics.source_graph_reads)+1
	return graph

static func _with_cache_metrics(result: Dictionary, metrics: Dictionary) -> Dictionary:
	result["source_signature_reads"]=int(metrics.source_signature_reads)
	result["source_signature_cache_hits"]=int(metrics.source_signature_cache_hits)
	result["source_graph_reads"]=int(metrics.source_graph_reads)
	result["source_graph_cache_hits"]=int(metrics.source_graph_cache_hits)
	return result
