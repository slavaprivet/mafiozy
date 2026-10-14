extends RefCounted
## Native root+sibling geometry transaction. Owner leases are mandatory.
const Inventory = preload("res://scripts/map_editor/native_building_inventory.gd")
const PRINTSHOP := "REBUILD-VISUAL-print_shop-001"
const CATALOG_SHA := "ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const MAIN_SHA := "faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53"
var _main: Node3D
var _row: Dictionary = {}
var _source: Dictionary = {}
var _inventory: RefCounted
var _fingerprint: Array = []
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _state := "NEW"
var _deleted := false

func select(main: Node3D, source_id: String) -> Dictionary:
	if _state != "NEW" or not is_instance_valid(main) or not main.is_inside_tree() or main.is_queued_for_deletion(): return {"ok": false, "error": "invalid-owner-lifetime"}
	if _sha(FileAccess.get_file_as_bytes("res://scripts/main.gd")) != MAIN_SHA or _sha(FileAccess.get_file_as_bytes("res://data/block.json")) != BLOCK_SHA or _sha(FileAccess.get_file_as_bytes("res://data/map_editor/catalog.json")) != CATALOG_SHA: return {"ok": false, "error": "source-lineage-drift"}
	if main.get_script() != load("res://scripts/main.gd"): return {"ok": false, "error": "not-actual-main-owner"}
	if str(main.get("static_batch_status")) != "disabled" or main.get("_static_batch_lease") != null: return {"ok": false, "error": "static-batch-owner-hold"}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/catalog.json"))
	var all_buildings: Array = []
	for candidate: Dictionary in catalog.objects:
		if str(candidate.get("dataset", "")) == "buildings": all_buildings.append(candidate.sourceRecord)
	if all_buildings.size() != 75: return {"ok": false, "error": "full-building-source-count-drift"}
	var catalog_row: Dictionary = {}
	for candidate: Dictionary in catalog.objects:
		if str(candidate.get("id", "")) == source_id:
			catalog_row = candidate
			break
	if catalog_row.is_empty(): return {"ok": false, "error": "unknown-source-id"}
	if source_id == PRINTSHOP or str(catalog_row.get("dataset", "")) == "detention" or str(catalog_row.get("sourceRecord", {}).get("role", "")) in ["bank_shell", "district_detention"] or str(catalog_row.get("assetId", "")).begins_with("bank_"): return {"ok": false, "error": "protected-building-owner-hold"}
	if str(catalog_row.get("dataset", "")) != "buildings": return {"ok": false, "error": "not-a-building"}
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	if main.get("_block") != block: return {"ok": false, "error": "actual-block-revision-drift"}
	for record: Dictionary in block.buildings:
		if str(record.id) == source_id: _source = record
	if _source.is_empty(): return {"ok": false, "error": "not-live-native-building"}
	if str(_source.get("assetId", "")) != str(catalog_row.get("assetId", "")) or _source.get("positionLocalM") != catalog_row.get("positionLocalM"): return {"ok": false, "error": "catalog-live-source-drift"}
	_inventory = Inventory.new()
	var audit: Dictionary = _inventory.inspect(main, [_source], all_buildings)
	if not audit.get("ok", false) or audit.get("rows", []).size() != 1: return {"ok": false, "error": "native-building-inventory-refused", "details": audit.get("errors", [])}
	_main = main
	_row = audit.rows[0]
	if _row.special or _row.native_sibling_bodies.is_empty(): return {"ok": false, "error": "ordinary-sibling-contract-refused"}
	_fingerprint = _capture_fingerprint()
	_state = "SELECTED_READONLY"
	return {"ok": true, "source_id": source_id, "registry_id": _row.registry_id, "sibling_bodies": _row.native_sibling_bodies.size(), "editable": false}

func move(delta: Vector3, leases: Dictionary = {}) -> Dictionary:
	if _deleted: return {"ok": false, "error": "deleted-building-requires-undo"}
	if not delta.is_finite() or delta.length_squared() < 0.00000001: return {"ok": false, "error": "invalid-move"}
	return _execute("move", delta, leases)

func rotate(yaw_radians: float, leases: Dictionary = {}) -> Dictionary:
	if _deleted: return {"ok": false, "error": "deleted-building-requires-undo"}
	if not is_finite(yaw_radians) or absf(yaw_radians) < 0.000001: return {"ok": false, "error": "invalid-rotation"}
	return _execute("rotate", yaw_radians, leases)

func delete(leases: Dictionary = {}) -> Dictionary:
	if _deleted: return {"ok": false, "error": "already-deleted"}
	return _execute("delete", null, leases)

func undo(leases: Dictionary = {}) -> Dictionary:
	if _history.is_empty(): return {"ok": false, "error": "empty-history"}
	return _execute("undo", _history.back().before, leases)

func redo(leases: Dictionary = {}) -> Dictionary:
	if _redo.is_empty(): return {"ok": false, "error": "empty-redo"}
	return _execute("redo", _redo.back().after, leases)

func _execute(action: String, value: Variant, leases: Dictionary) -> Dictionary:
	if _state != "SELECTED_READONLY" or not is_instance_valid(_main) or not _main.is_inside_tree() or _main.is_queued_for_deletion(): return {"ok": false, "error": "stale-owner"}
	if not _main.get_tree().paused or Engine.is_in_physics_frame(): return {"ok": false, "error": "actual-tree-pause-required"}
	if str(_main.get("static_batch_status")) != "disabled" or _main.get("_static_batch_lease") != null: return {"ok": false, "error": "static-batch-owner-hold"}
	if not _participants_valid(): return {"ok": false, "error": "native-participant-lifetime-drift"}
	if _capture_fingerprint() != _fingerprint: return {"ok": false, "error": "native-owner-revision-drift"}
	for domain: String in ["pause", "terrain", "navigation", "traffic"]:
		if not leases.has(domain) or not leases[domain] is Callable: return {"ok": false, "error": "missing-owner-lease:" + domain}
		var provider: Callable = leases[domain]
		if not provider.is_valid(): return {"ok": false, "error": "missing-owner-lease:" + domain}
	var before := _capture_state()
	var tokens: Array[Dictionary] = []
	for domain: String in ["pause", "terrain", "navigation", "traffic"]:
		var provider: Callable = leases[domain]
		var answer: Variant = provider.call({"source_id": _source.id, "action": action, "old_frame": _row.visual.global_transform, "body_count": _row.native_sibling_bodies.size(), "owner_instance_id": _main.get_instance_id()})
		if not answer is Dictionary or not answer.get("ok", false) or not answer.get("token") is RefCounted: return _rollback_prepared(tokens, "owner-lease-refused:" + domain)
		var token: RefCounted = answer.token
		if not token.has_method("verify") or not token.has_method("commit") or not token.has_method("rollback"): return _rollback_prepared(tokens, "invalid-owner-token:" + domain)
		tokens.append({"domain": domain, "token": token})
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.verify()): return _rollback_prepared(tokens, "owner-lease-drift:" + entry.domain)
	if _capture_fingerprint() != _fingerprint: return _rollback_prepared(tokens, "native-owner-drift-before-mutation")
	var mutation := _mutate(action, value)
	if not mutation.ok: return _rollback_after_mutation(before,tokens,mutation.error)
	if not _participants_valid(): return _rollback_after_mutation(before,tokens,"native-participant-drift")
	var staged_fingerprint := _capture_fingerprint()
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.verify()): return _rollback_after_mutation(before,tokens,"owner-lease-drift-after-mutation:" + entry.domain)
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.commit({"source_id": _source.id, "action": action, "new_frame": _row.visual.global_transform, "deleted": bool(value.deleted) if action == "undo" or action == "redo" else action == "delete"})): return _rollback_after_mutation(before,tokens,"owner-commit-refused:" + entry.domain)
	if not _main.get_tree().paused:
		_state = "HOLD_OWNER_RELEASED_PAUSE"
		return {"ok": false, "error": "owner-released-pause-before-final-verification", "state": _state}
	if _capture_fingerprint() != staged_fingerprint: return _rollback_after_mutation(before,tokens,"native-revision-drift-after-owner-commit")
	for entry: Dictionary in tokens:
		if not _token_ok(entry.token.verify()): return _rollback_after_mutation(before,tokens,"owner-receipt-drift-after-commit:" + entry.domain)
	if action == "undo":
		var undone: Dictionary = _history.pop_back()
		_redo.append({"action": undone.action, "before": undone.before, "after": before})
		_deleted = bool(value.deleted)
	elif action == "redo":
		var replayed: Dictionary = _redo.pop_back()
		_history.append({"action": replayed.action, "before": before})
		_deleted = bool(value.deleted)
	else:
		_history.append({"action": action, "before": before})
		_redo.clear()
		if action == "delete": _deleted = true
	_fingerprint = _capture_fingerprint()
	return {"ok": true, "source_id": _source.id, "action": action, "bodies": _row.native_sibling_bodies.size(), "history": _history.size(), "editorOwnerReady": false}

func _mutate(action: String, value: Variant) -> Dictionary:
	if action == "undo" or action == "redo":
		_restore(value)
		return {"ok": true}
	if action == "delete":
		_row.visual.visible = false
		for body: StaticBody3D in _row.native_sibling_bodies:
			body.collision_layer = 0
			body.collision_mask = 0
			for child: Node in body.get_children():
				if child is CollisionShape3D: child.disabled = true
		return {"ok": true}
	var frame: Transform3D = _row.visual.global_transform
	var delta: Transform3D
	if action == "move": delta = Transform3D(Basis.IDENTITY, value)
	elif action == "rotate":
		var basis := Basis(Vector3.UP, value)
		delta = Transform3D(basis, frame.origin - basis * frame.origin)
	else: return {"ok": false, "error": "unsupported-action"}
	_row.visual.global_transform = delta * frame
	for body: StaticBody3D in _row.native_sibling_bodies: body.global_transform = delta * body.global_transform
	return {"ok": true}

func _capture_state() -> Dictionary:
	var bodies: Array = []
	for body: StaticBody3D in _row.native_sibling_bodies:
		var shapes: Array = []
		for child: Node in body.get_children():
			if child is CollisionShape3D: shapes.append({"node": child, "disabled": child.disabled, "shape": child.shape})
		bodies.append({"node": body, "parent": body.get_parent(), "frame": body.global_transform, "visible": body.visible, "layer": body.collision_layer, "mask": body.collision_mask, "shapes": shapes})
	return {"root": _row.visual, "parent": _row.visual.get_parent(), "frame": _row.visual.global_transform, "visible": _row.visual.visible, "bodies": bodies, "deleted": _deleted}

func _restore(state: Dictionary) -> void:
	var root: Node3D = state.root
	root.global_transform = state.frame
	root.visible = state.visible
	for entry: Dictionary in state.bodies:
		var body: StaticBody3D = entry.node
		body.global_transform = entry.frame
		body.visible = entry.visible
		body.collision_layer = entry.layer
		body.collision_mask = entry.mask
		for shape: Dictionary in entry.shapes:
			shape.node.disabled = shape.disabled

func _participants_valid() -> bool:
	if not is_instance_valid(_row.visual) or _row.visual.is_queued_for_deletion() or _row.visual.get_parent() != _main or str(_row.visual.get_meta("source_id", "")) != str(_source.id): return false
	for body: StaticBody3D in _row.native_sibling_bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != _main or str(body.get_meta("source_id", "")) != str(_source.id): return false
	return true

func _capture_fingerprint() -> Array:
	var result: Array = []
	result.append_array(_inventory.fingerprint(_row.visual))
	for body: StaticBody3D in _row.native_sibling_bodies: result.append_array(_inventory.fingerprint(body))
	return result

func _rollback_prepared(tokens: Array[Dictionary], error: String) -> Dictionary:
	var okay := true
	for index in range(tokens.size() - 1, -1, -1): okay = _token_ok(tokens[index].token.rollback()) and okay
	if not okay: _state = "HOLD_ROLLBACK_INCOMPLETE"
	return {"ok": false, "error": error, "rolled_back": okay, "state": _state}

func _rollback_after_mutation(before: Dictionary, tokens: Array[Dictionary], error: String) -> Dictionary:
	var okay := _participants_valid()
	if okay: _restore(before)
	for index in range(tokens.size() - 1, -1, -1): okay = _token_ok(tokens[index].token.rollback()) and okay
	if okay: okay = _capture_fingerprint() == _fingerprint
	if not okay: _state = "HOLD_ROLLBACK_INCOMPLETE"
	return {"ok": false, "error": error, "rolled_back": okay, "state": _state}

func _token_ok(value: Variant) -> bool:
	return value is Dictionary and value.get("ok", false) and value.get("ready", false) and not value.get("pending", true)

func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
