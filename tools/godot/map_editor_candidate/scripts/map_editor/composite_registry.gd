extends RefCounted
## Explicit trusted owner composition. No discovery, authority serialization or
## resource conversion. Each ID has exactly one owner; targeted dispatch is O(1).
const Document = preload("res://scripts/map_editor/map_document.gd")
const Native = preload("res://scripts/map_editor/object_registry.gd")
const REQUIRED := ["ids", "source_document", "has_object", "is_editable", "template_frame", "world_bounds", "apply_record", "apply_document", "create_copy", "discard_copy", "capture_install_checkpoint", "restore_install_checkpoint"]
var _owners: Array = []
var _by_id := {}
var _baseline := {}
var _baseline_header := {}
var _busy := false
var _recovery := {}
var _issued := {}
var _checkpoint_sequence := 0
var _last_error := ""

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
static func encode_transform(frame: Transform3D) -> Dictionary:
	return Native.encode_transform(frame)
static func decode_transform(data: Dictionary) -> Variant:
	return Native.decode_transform(data)

func configure(children: Array, map_id: String, metadata: Dictionary = {}) -> Dictionary:
	if not _owners.is_empty() or children.is_empty() or map_id.strip_edges().is_empty() or metadata.has("registry_owners") or not Document._json_safe(metadata): return failure("Invalid composite owner configuration")
	var owners: Array = []
	var index := {}
	var rows: Array = []
	var headers := {}
	var instances := {}
	for value: Variant in children:
		if not value is Dictionary or not value.get("owner_id") is String or value.owner_id.is_empty() or headers.has(value.owner_id): return failure("Duplicate or invalid registry owner identity")
		var owner: Variant = value.get("registry")
		if not owner is RefCounted or instances.has(owner.get_instance_id()): return failure("Invalid or repeated registry instance")
		for method: String in REQUIRED:
			if not owner.has_method(method): return failure("Registry missing API: " + method)
		var checked := Document.validate_document(owner.source_document(map_id))
		if not checked.ok or checked.document.map_id != map_id: return failure("Registry source header rejected")
		var header: Dictionary = checked.document.duplicate(true)
		header.erase("objects")
		headers[value.owner_id] = header.duplicate(true)
		var child_ids: Array = owner.ids()
		var admitted := {}
		for row: Dictionary in checked.document.objects:
			if index.has(row.id) or not owner.has_object(row.id) or admitted.has(row.id): return failure("Duplicate or absent global source identity")
			admitted[row.id] = true
			index[row.id] = owners.size()
			rows.append(row.duplicate(true))
		if admitted.size() != child_ids.size(): return failure("Source document does not represent all registered initial identities")
		for id: Variant in child_ids:
			if not id is String or not admitted.has(id): return failure("Registry identity inventory mismatch")
		instances[owner.get_instance_id()] = true
		owners.append({"id": value.owner_id, "owner": owner, "instance": owner.get_instance_id(), "header": header})
	var merged: Dictionary = metadata.duplicate(true)
	merged.registry_owners = headers
	var source := Document.validate_document({"schema_version": 1, "map_id": map_id, "metadata": merged, "objects": rows})
	if not source.ok: return source
	_owners = owners
	_by_id = index
	_baseline = source.document
	for key in _baseline:
		if key != "objects": _baseline_header[key] = _baseline[key]
	_baseline_header = _baseline_header.duplicate(true)
	return {"ok": true, "owners": owners.size(), "objects": rows.size()}

func _owner(id: String) -> Variant:
	if not _by_id.has(id): return null
	var entry: Dictionary = _owners[_by_id[id]]
	return entry.owner if is_instance_valid(entry.owner) and entry.owner.get_instance_id() == entry.instance else null
func ids() -> Array: return _by_id.keys()
func has_object(id: String) -> bool:
	var owner: Variant = _owner(id)
	return owner != null and owner.has_object(id)
func is_editable(id: String) -> bool:
	var owner: Variant = _owner(id)
	return owner != null and owner.is_editable(id)
func template_frame(id: String) -> Transform3D:
	var owner: Variant = _owner(id)
	return owner.template_frame(id) if owner != null else Transform3D.IDENTITY
func world_bounds(id: String) -> Variant:
	var owner: Variant = _owner(id)
	return owner.world_bounds(id) if owner != null else null
func source_document(map_id: String) -> Dictionary:
	return _baseline.duplicate(true) if not _baseline.is_empty() and map_id == _baseline.map_id else {}
func busy_status() -> Dictionary:
	return {"busy": _busy, "retry_rollback": not _recovery.is_empty(), "error": _last_error}

func pick(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> String:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(distance) or distance <= 0: return ""
	var nearest := distance
	var selected := ""
	var end := origin + direction.normalized() * distance
	for id: String in _by_id:
		var bounds: Variant = world_bounds(id)
		if not bounds is AABB: continue
		var hit: Variant = bounds.intersects_segment(origin, end)
		if hit is Vector3:
			var length := origin.distance_to(hit)
			if length < nearest:
				nearest = length
				selected = id
	return selected

func apply_record(id: String, record: Variant, dry_run: bool = false) -> Dictionary:
	if _busy: return failure("Composite transaction or rollback still pending")
	var owner: Variant = _owner(id)
	if owner == null: return failure("Unknown object owner")
	_busy = true
	var result: Dictionary = owner.apply_record(id, record, true)
	if result.ok and not dry_run: result = owner.apply_record(id, record)
	_busy = false
	return result

func _partition(document: Dictionary) -> Dictionary:
	var checked := Document.validate_document(document)
	if not checked.ok: return checked
	# Header admission must not copy thousands of model/source descriptors just
	# to erase them. Validation already detached the candidate document.
	var header := {}
	for key in checked.document:
		if key != "objects": header[key] = checked.document[key]
	if not Native._semantic_equal(header, _baseline_header): return failure("Composite source schema/map/metadata must remain trusted")
	var parts: Array = []
	for entry: Dictionary in _owners:
		var part: Dictionary = entry.header.duplicate(true)
		part.objects = []
		parts.append(part)
	for row: Dictionary in checked.document.objects:
		if not has_object(row.id): return failure("Unknown global object identity")
		parts[_by_id[row.id]].objects.append(row)
	return {"ok": true, "parts": parts}

func capture_install_checkpoint() -> Dictionary:
	if _busy: return failure("Composite transaction or rollback still pending")
	return _capture()
func _capture() -> Dictionary:
	for issued_id: int in _issued.keys():
		if not is_instance_valid(_issued[issued_id].token.get_ref()): _issued.erase(issued_id)
	var children: Array = []
	for entry: Dictionary in _owners:
		if not is_instance_valid(entry.owner) or entry.owner.get_instance_id() != entry.instance: return failure("Registry owner lifetime ended")
		var capsule: Dictionary = entry.owner.capture_install_checkpoint()
		if not capsule.get("ok", false): return capsule
		children.append({"owner_id": entry.id, "owner": weakref(entry.owner), "instance": entry.instance, "capsule": capsule})
	_checkpoint_sequence += 1
	var token := RefCounted.new()
	_issued[token.get_instance_id()] = {"token": weakref(token), "children": children, "index": _by_id.duplicate(), "issuer": get_instance_id(), "sequence": _checkpoint_sequence}
	return {"ok": true, "issuer": get_instance_id(), "token": token}

func restore_install_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not checkpoint.get("token") is RefCounted or checkpoint.get("issuer") != get_instance_id(): return failure("Unissued or foreign composite checkpoint")
	var token_id: int = checkpoint.token.get_instance_id()
	if not _issued.has(token_id) or _issued[token_id].token.get_ref() != checkpoint.token: return failure("Expired or foreign composite checkpoint")
	if _busy and _recovery.is_empty(): return failure("Composite reentrant restore forbidden")
	_busy = true
	var saved: Dictionary = _issued[token_id]
	var errors: Array = []
	# Check every owner identity before changing any owned scene.
	for i in saved.children.size():
		var child: Dictionary = saved.children[i]
		var owner: Variant = child.owner.get_ref()
		if i >= _owners.size() or not is_instance_valid(owner) or owner != _owners[i].owner or owner.get_instance_id() != child.instance or child.owner_id != _owners[i].id: errors.append("Registry owner identity/lifetime changed")
	if errors.is_empty():
		# Attempt ALL owners even when one refuses, retaining receipt for retry.
		for child: Dictionary in saved.children:
			var result: Dictionary = child.owner.get_ref().restore_install_checkpoint(child.capsule)
			if not result.get("ok", false): errors.append(child.owner_id + ": " + str(result.get("error", "Rollback refused")))
	if errors.is_empty():
		for id: String in saved.index:
			if not _owners[saved.index[id]].owner.has_object(id): errors.append("Restored source identity missing: " + id)
		for i in _owners.size():
			for id: Variant in _owners[i].owner.ids():
				if not saved.index.has(id) or saved.index[id] != i: errors.append("Restored owner inventory mismatch")
	if not errors.is_empty():
		_recovery = checkpoint.duplicate()
		_last_error = "; ".join(errors)
		return {"ok": false, "rollback_ok": false, "retry_rollback": true, "error": _last_error}
	_by_id = saved.index.duplicate()
	_recovery.clear()
	_last_error = ""
	_busy = false
	return {"ok": true, "rollback_ok": true}
func retry_rollback() -> Dictionary:
	return restore_install_checkpoint(_recovery) if not _recovery.is_empty() else {"ok": true, "unchanged": true}
func release_checkpoint(checkpoint: Dictionary) -> void:
	if _recovery.is_empty() and not _busy and checkpoint.get("issuer") == get_instance_id() and checkpoint.get("token") is RefCounted: _issued.erase(checkpoint.token.get_instance_id())

func apply_document(document: Dictionary, dry_run: bool = false) -> Dictionary:
	if _busy: return failure("Composite transaction or rollback still pending")
	var partition := _partition(document)
	if not partition.ok: return partition
	_busy = true
	# Validate record provenance as well as child bulk geometry preflight.
	for i in _owners.size():
		var owner: RefCounted = _owners[i].owner
		for row: Dictionary in partition.parts[i].objects:
			var admitted: Dictionary = owner.apply_record(row.id, row, true)
			if not admitted.ok:
				_busy = false
				return admitted
		var preflight: Dictionary = owner.apply_document(partition.parts[i], true)
		if not preflight.ok:
			_busy = false
			return preflight
	if dry_run:
		_busy = false
		return {"ok": true}
	var checkpoint := _capture()
	if not checkpoint.ok:
		_busy = false
		return checkpoint
	for i in _owners.size():
		var applied: Dictionary = _owners[i].owner.apply_document(partition.parts[i])
		if not applied.ok:
			_recovery = checkpoint
			var restored := restore_install_checkpoint(checkpoint)
			if restored.ok: release_checkpoint(checkpoint)
			return {"ok": false, "rollback_ok": restored.ok, "retry_rollback": not restored.ok, "error": str(applied.get("error", "Owner apply failed")) + ("" if restored.ok else "; " + str(restored.error))}
	_busy = false
	release_checkpoint(checkpoint)
	return {"ok": true}

func create_copy(template_id: String, id: String, frame: Transform3D) -> Dictionary:
	if _busy or _by_id.has(id) or not id.begins_with("editor:") or not is_editable(template_id): return failure("Unavailable template or global copy identity")
	var owner: Variant = _owner(template_id)
	_busy = true
	var result: Dictionary = owner.create_copy(template_id, id, frame)
	if result.get("ok", false):
		if not owner.has_object(id) or not result.get("record") is Dictionary or result.record.get("id") != id:
			owner.discard_copy(id)
			result = failure("Owner copy receipt identity mismatch")
		else: _by_id[id] = _by_id[template_id]
	_busy = false
	return result
func discard_copy(id: String) -> void:
	if _busy or not id.begins_with("editor:"): return
	var owner: Variant = _owner(id)
	if owner == null: return
	_busy = true
	owner.discard_copy(id)
	if not owner.has_object(id): _by_id.erase(id)
	_busy = false
