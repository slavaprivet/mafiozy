extends RefCounted
## Source-only contract for the three banks and three district detention sites.
## It never mutates native geometry itself: the actual special-building owner must
## atomically move/rotate/delete its complete visual, collision and gameplay graph.
const CATALOG_SHA := "ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e"
const SPECIAL_IDS := [
	"REBUILD-bank:large", "REBUILD-bank:medium", "REBUILD-bank:small",
	"REBUILD-DETENTION-chinatown", "REBUILD-DETENTION-iron_harbor", "REBUILD-DETENTION-southside",
]
const CLAIMS := ["visual", "collisions", "interior", "entrance", "navigation", "traffic", "source_id", "undo"]

var _owner: Node
var _row: Dictionary = {}
var _receipt: Dictionary = {}
var _history: Array[Dictionary] = []
var _state := "NEW"

func select(owner: Node, source_id: String) -> Dictionary:
	if _state != "NEW": return _refuse("already-selected")
	if not SPECIAL_IDS.has(source_id): return _refuse("not-six-special-building-ids")
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return _refuse("invalid-owner-lifetime")
	if _sha(FileAccess.get_file_as_bytes("res://data/map_editor/catalog.json")) != CATALOG_SHA: return _refuse("catalog-lineage-drift")
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/catalog.json"))
	if not catalog is Dictionary or not catalog.get("objects") is Array: return _refuse("invalid-catalog")
	for candidate: Dictionary in catalog.objects:
		if str(candidate.get("id", "")) == source_id: _row = candidate
	if _row.is_empty(): return _refuse("missing-source-row")
	var role := str(_row.get("sourceRecord", {}).get("role", ""))
	if not ((str(_row.get("dataset", "")) == "buildings" and role == "bank_shell") or (str(_row.get("dataset", "")) == "detention" and role == "district_detention")): return _refuse("special-role-drift")
	# The current cropped main has none of these six. A future full-world owner must
	# implement this API and return a revisioned, complete native graph receipt.
	if not owner.has_method("map_editor_resolve_special_building"): return _refuse("missing-special-owner-api")
	var result: Variant = owner.call("map_editor_resolve_special_building", source_id, CATALOG_SHA)
	if not _valid_receipt(result, source_id): return _refuse("incomplete-special-owner-receipt")
	_owner = owner
	_receipt = result
	_state = "SELECTED_READONLY"
	return {"ok": true, "source_id": source_id, "editable": false, "owner_revision": result.revision}

func move(delta: Vector3) -> Dictionary:
	if not delta.is_finite() or delta.length_squared() < 0.00000001: return _refuse("invalid-move")
	return _execute("move", {"delta": [delta.x, delta.y, delta.z]})

func rotate(yaw_radians: float) -> Dictionary:
	if not is_finite(yaw_radians) or absf(yaw_radians) < 0.000001: return _refuse("invalid-rotation")
	return _execute("rotate", {"yaw_radians": yaw_radians})

func delete() -> Dictionary:
	return _execute("delete", {})

func undo() -> Dictionary:
	if _history.is_empty(): return _refuse("empty-history")
	return _execute("undo", {"prior_owner_receipt": _history.back()})

func _execute(action: String, payload: Dictionary) -> Dictionary:
	if _state != "SELECTED_READONLY" or not is_instance_valid(_owner) or not _owner.is_inside_tree() or _owner.is_queued_for_deletion(): return _refuse("stale-owner")
	if not _owner.get_tree().paused or Engine.is_in_physics_frame(): return _refuse("paused-owner-required")
	if not _owner.has_method("map_editor_resolve_special_building") or not _owner.has_method("map_editor_prepare_special_edit"): return _refuse("missing-special-owner-api")
	var current: Variant = _owner.call("map_editor_resolve_special_building", str(_row.id), CATALOG_SHA)
	if not _valid_receipt(current, str(_row.id)) or current != _receipt: return _refuse("special-owner-revision-drift")
	# Owner is responsible for a single reversible transaction spanning all claims.
	# The generic document/import protected guard remains in force; no local bypass.
	var prepared: Variant = _owner.call("map_editor_prepare_special_edit", str(_row.id), CATALOG_SHA, action, payload, _receipt)
	if not prepared is Dictionary or not prepared.get("ok", false) or not prepared.get("token") is RefCounted: return _refuse("special-owner-prepare-refused")
	var token: RefCounted = prepared.token
	if not token.has_method("verify") or not token.has_method("commit") or not token.has_method("rollback"): return _refuse("invalid-special-owner-token")
	if not _token_ok(token.verify()): return _rollback(token, "special-owner-token-drift")
	var committed: Variant = token.commit()
	if not _token_ok(committed): return _rollback(token, "special-owner-commit-refused")
	if not _owner.get_tree().paused: return _rollback(token, "pause-released-during-special-edit")
	var after: Variant = _owner.call("map_editor_resolve_special_building", str(_row.id), CATALOG_SHA)
	if not _valid_receipt(after, str(_row.id)) or after.revision == _receipt.revision: return _rollback(token, "missing-complete-owner-revision")
	if not _token_ok(token.verify()): return _rollback(token, "special-owner-postcommit-drift")
	if action == "undo": _history.pop_back()
	else: _history.append({"source_id": _row.id, "before_revision": _receipt.revision, "after_revision": after.revision, "owner_undo": committed.get("owner_undo")})
	_receipt = after
	return {"ok": true, "source_id": _row.id, "action": action, "owner_revision": after.revision, "history": _history.size(), "editorOwnerReady": false}

func _valid_receipt(value: Variant, source_id: String) -> bool:
	if not value is Dictionary or not value.get("ok", false) or str(value.get("source_id", "")) != source_id: return false
	if str(value.get("catalog_sha", "")) != CATALOG_SHA or str(value.get("revision", "")).is_empty(): return false
	if not value.get("claims") is Dictionary: return false
	for claim: String in CLAIMS:
		if value.claims.get(claim) != true: return false
	# An editable six-building receipt also needs an owner-authored exact graph seal.
	return str(value.get("graph_sha", "")).length() == 64

func _rollback(token: RefCounted, error: String) -> Dictionary:
	var rolled: Variant = token.rollback()
	var clean := _token_ok(rolled)
	if clean:
		var restored: Variant = _owner.call("map_editor_resolve_special_building", str(_row.id), CATALOG_SHA)
		clean = _valid_receipt(restored, str(_row.id)) and restored == _receipt
	if not clean: _state = "HOLD_ROLLBACK_INCOMPLETE"
	return {"ok": false, "error": error, "rolled_back": clean, "state": _state}

func _token_ok(value: Variant) -> bool:
	return value is Dictionary and value.get("ok", false) and value.get("ready", false) and not value.get("pending", true)

func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "state": _state}

func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
