extends RefCounted
## Authored visuals only. No editor mutation, collision or gameplay owner admission.
const CATALOG_SHA := "ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e"
const ACTIVATION_SHA := "47c8fd105dea7b87d12c63eeb0e5c10373c9832e947def2ac870f1618996d08c"
const AuthoredFactory = preload("res://scripts/map_editor/catalog_factory.gd")
const LiveOwner = preload("res://scripts/map_editor/live_authored_owner.gd")
var _host: Node3D
var _preview: Node3D
var _factory: RefCounted
var _rows: Array[Dictionary] = []
var _resources: Dictionary = {}
var _live_owner: RefCounted
var _borrowed: Dictionary = {}
var _owned: Dictionary = {}
var _covered: Dictionary = {}
var _cursor := 0
var _state := "NEW"
var _failure := ""
var _step_count := 0
var _max_step_usec := 0

func begin(host: Node3D, borrow_live: bool = false) -> Dictionary:
	if _state != "NEW" or not is_instance_valid(host) or not host.is_inside_tree(): return {"ok": false, "error": "invalid-host-or-lifecycle"}
	var catalog_bytes := FileAccess.get_file_as_bytes("res://data/map_editor/catalog.json")
	var activation_bytes := FileAccess.get_file_as_bytes("res://data/map_editor/activation_manifest.json")
	if _sha(catalog_bytes) != CATALOG_SHA or _sha(activation_bytes) != ACTIVATION_SHA: return {"ok": false, "error": "source-lineage-drift"}
	var catalog: Variant = JSON.parse_string(catalog_bytes.get_string_from_utf8())
	var activation: Variant = JSON.parse_string(activation_bytes.get_string_from_utf8())
	if not catalog is Dictionary or not activation is Dictionary or activation.get("schema", "") != "mafiozi.map-editor-canonical-activation-plan/v1" or activation.get("mode", "") != "outputs-only-not-installed": return {"ok": false, "error": "invalid-source-documents"}
	if catalog.get("schema", "") != "mafiozi.godot.map-editor-catalog/v1" or catalog.get("counts", {}).get("objects", -1) != 9901 or catalog.get("counts", {}).get("resources", -1) != 196: return {"ok": false, "error": "catalog-scope-drift"}
	var resources: Dictionary = {}
	for resource: Dictionary in catalog.resources:
		resources[str(resource.id)] = resource
	if resources.size() != 196 or activation.get("rows", []).size() != 196: return {"ok": false, "error": "resource-scope-drift"}
	_resources = resources
	var activation_ids: Dictionary = {}
	for receipt: Dictionary in activation.rows:
		var id := str(receipt.get("id", ""))
		if not resources.has(id) or activation_ids.has(id) or str(receipt.get("resPath", "")) != "res://assets/map_editor/" + id + ".glb" or int(receipt.get("bytes", -1)) != int(resources[id].bytes): return {"ok": false, "error": "activation-resource-mismatch"}
		activation_ids[id] = true
	var keys: Dictionary = {}
	var ids: Dictionary = {}
	for row: Dictionary in catalog.objects:
		if not row.has("resourceId"): continue
		var key := str(row.get("key", ""))
		var id := str(row.get("id", ""))
		if key.is_empty() or id.is_empty() or keys.has(key) or ids.has(id) or not resources.has(str(row.resourceId)): return {"ok": false, "error": "authored-identity-drift"}
		keys[key] = true
		ids[id] = key
		_rows.append(row)
	if _rows.size() != 242: return {"ok": false, "error": "authored-count-drift"}
	if borrow_live:
		# Only the script-pinned actual-main owner may enumerate live roots.
		# A caller dictionary is never treated as a receipt.
		_live_owner = LiveOwner.new()
		var admission: Dictionary = _live_owner.begin(host, catalog)
		if not admission.get("ok", false): return {"ok": false, "error": str(admission.get("error", "owner-refused")), "verifiedOrdinary": admission.get("verifiedOrdinary", 0)}
		_borrowed = _live_owner.verified_roots()
		if _borrowed.size() != 16: return {"ok": false, "error": "incomplete-live-owner-receipt"}
	_host = host
	_factory = AuthoredFactory.new()
	if not _factory.configure(catalog): return {"ok": false, "error": "factory-source-refusal"}
	_preview = Node3D.new()
	_preview.name = "MapEditorAuthoredReadOnly"
	_preview.visible = false
	_host.add_child(_preview)
	_state = "BUILDING"
	return {"ok": true, "state": _state, "total": _rows.size(), "borrowed": _borrowed.size()}

func step(max_objects: int = 1, max_usec: int = 2000) -> Dictionary:
	if _state != "BUILDING" or not is_instance_valid(_host) or not is_instance_valid(_preview) or not _host.is_inside_tree(): return _refuse("stale-builder-or-host")
	if _live_owner != null and not _live_owner.verify().get("ok", false): return _refuse("live-owner-receipt-drift")
	if max_objects < 1 or max_objects > 8 or max_usec < 100 or max_usec > 1000000: return _refuse("invalid-step-budget")
	var started := Time.get_ticks_usec()
	var processed := 0
	while _cursor < _rows.size() and processed < max_objects:
		if processed > 0 and Time.get_ticks_usec() - started >= max_usec: break
		var row: Dictionary = _rows[_cursor]
		var key := str(row.key)
		var id := str(row.id)
		if _covered.has(key): return _refuse("duplicate-source-key")
		if _borrowed.has(key):
			var live: Node3D = _borrowed[key]
			if not is_instance_valid(live) or str(live.get_meta("source_id", "")) != id: return _refuse("live-owner-root-drift")
			_covered[key] = {"id": id, "ownership": "owner-verified-live-readonly"}
		else:
			var built: Dictionary = _factory.spawn_key(key, {})
			if not built.get("ok", false): return _refuse("factory-refused:" + key + ":" + str(built.get("status", "")))
			var native_root: Node3D = built.get("root")
			var visual: Node3D = built.get("visual")
			if not is_instance_valid(native_root) or not is_instance_valid(visual) or not _verify_visual(visual, int(_resource(str(row.resourceId)).get("materialCount", 0))):
				if is_instance_valid(native_root): native_root.free()
				return _refuse("missing-native-mesh-or-material:" + key)
			if str(native_root.get_meta("source_id", "")) != id or str(native_root.get_meta("source_key", "")) != key or built.get("gameplayActive", true) or not built.get("colliders", []).is_empty():
				native_root.free()
				return _refuse("readonly-factory-contract-drift:" + key)
			_preview.add_child(native_root)
			_owned[key] = native_root
			_covered[key] = {"id": id, "ownership": "preview-visual-only", "pendingOwner": built.get("pending", []).duplicate()}
		_cursor += 1
		processed += 1
	_step_count += 1
	var elapsed := Time.get_ticks_usec() - started
	_max_step_usec = maxi(_max_step_usec, elapsed)
	if _cursor == _rows.size():
		if _covered.size() != 242 or _owned.size() + _borrowed.size() != 242: return _refuse("incomplete-authored-coverage")
		if _preview.get_child_count() != _owned.size(): return _refuse("preview-root-count-drift")
		var root_ids: Dictionary = {}
		for row: Dictionary in _rows:
			var key := str(row.key)
			var node: Node3D = _borrowed[key] if _borrowed.has(key) else _owned[key]
			if not is_instance_valid(node) or root_ids.has(node.get_instance_id()) or str(node.get_meta("source_id", "")) != str(row.id): return _refuse("duplicate-or-stale-native-root")
			if not _borrowed.has(key) and node.get_parent() != _preview: return _refuse("preview-parent-drift")
			root_ids[node.get_instance_id()] = true
		_preview.visible = true
		_state = "COMPLETE_READONLY"
	return {"ok": true, "state": _state, "processed": processed, "covered": _covered.size(), "owned": _owned.size(), "borrowed": _borrowed.size(), "elapsed_usec": elapsed, "budget_exceeded": elapsed > max_usec, "max_step_usec": _max_step_usec, "steps": _step_count, "editorReady": false}

func status() -> Dictionary:
	return {"state": _state, "failure": _failure, "covered": _covered.size(), "owned": _owned.size(), "borrowed": _borrowed.size(), "max_step_usec": _max_step_usec, "editorReady": false}

func close() -> void:
	if is_instance_valid(_preview): _preview.free()
	_owned.clear()
	_borrowed.clear()
	_covered.clear()
	_live_owner = null
	_state = "CLOSED"

func _refuse(reason: String) -> Dictionary:
	_failure = reason
	close()
	_state = "FAILED"
	return {"ok": false, "state": _state, "error": reason, "editorReady": false}

func _resource(id: String) -> Dictionary:
	return _resources.get(id, {})

func _verify_visual(node: Node, expected_materials: int) -> bool:
	var stack: Array[Node] = [node]
	var mesh_count := 0
	var material_found := false
	while not stack.is_empty():
		var item: Node = stack.pop_back()
		if item is MeshInstance3D:
			var mesh_node := item as MeshInstance3D
			if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() == 0: return false
			mesh_count += 1
			for surface in mesh_node.mesh.get_surface_count():
				if mesh_node.get_active_material(surface) != null: material_found = true
		for child: Node in item.get_children(): stack.append(child)
	return mesh_count > 0 and (expected_materials == 0 or material_found)

func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
