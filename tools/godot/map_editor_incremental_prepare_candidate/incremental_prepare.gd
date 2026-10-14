extends RefCounted
## Opt-in source-only preparation. Never mutates registry, scene or MapDocument.
## A row is the indivisible unit: max_usec is a soft budget, not a hard deadline.
const Document = preload("res://scripts/map_editor/map_document.gd")
const Trusted = preload("res://scripts/map_editor/trusted_json.gd")

var _controller: Node
var _registry: RefCounted
var _identity: Callable
var _pin: Dictionary = {}
var _candidate: Dictionary = {}
var _baseline: Dictionary = {}
var _keys: Array = []
var _key_index := 0
var _row_index := 0
var _phase := "idle"
var _originals := {}
var _extras := {}
var _seen := {}
var _validated: Array = []
var _prepared := {}
var _result := {}
var _processed := 0
var _source_hash: HashingContext
var _stepping := false
var _starting := false

static func _copy_header_exact(document: Dictionary) -> Dictionary:
	var header := {}
	for key in document:
		if key == "objects": continue
		var value: Variant = document[key]
		header[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return header

static func source_digest(source: Dictionary) -> String:
	# Same row-framed digest as the cursor; for fixture/owner admission only.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(JSON.stringify(_copy_header_exact(source)).to_utf8_buffer())
	for row: Variant in source.get("objects", []):
		var bytes := JSON.stringify(row).to_utf8_buffer()
		digest.update(PackedByteArray([0]))
		digest.update(str(bytes.size()).to_utf8_buffer())
		digest.update(PackedByteArray([0]))
		digest.update(bytes)
	return digest.finish().hex_encode()

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _abort(message: String) -> Dictionary:
	_phase = "failed"
	# These are borrowed references. Never clear caller source or controller base.
	_candidate = {}
	_baseline = {}
	_originals.clear()
	_extras.clear()
	_seen.clear()
	_validated.clear()
	_prepared = {}
	_result = _fail(message)
	return _result

func _pinned() -> bool:
	if not is_instance_valid(_controller) or not is_instance_valid(_registry): return false
	if _controller.registry != _registry or not _controller.active or not _controller.atomic_install_active or not _controller.document.install_guard_active: return false
	if not _identity.is_valid(): return false
	var current: Variant = _identity.call()
	if not current is Dictionary or current.get("paused") != true: return false
	for key in ["owner_instance_id", "source_sha256", "source_generation", "candidate_generation", "lease_id"]:
		if not current.has(key) or current[key] != _pin.get(key): return false
	return current.owner_instance_id == _registry.get_instance_id()

## The owner must supply a verified source SHA and monotonically changing
## generations for *all* source/candidate writes. An unversioned owner is HOLD.
func begin(controller: Node, candidate: Dictionary, identity: Callable, expected_source_sha256: String) -> Dictionary:
	if _starting: return _abort("Reentrant preparation begin callback")
	_starting = true
	var result: Dictionary = _begin_owned(controller, candidate, identity, expected_source_sha256)
	_starting = false
	return result

func _begin_owned(controller: Node, candidate: Dictionary, identity: Callable, expected_source_sha256: String) -> Dictionary:
	if _phase != "idle": return _fail("Preparation already used")
	if not is_instance_valid(controller) or not identity.is_valid() or expected_source_sha256.length() != 64 or not expected_source_sha256.is_valid_hex_number(): return _abort("Verified source owner required")
	_controller = controller
	_registry = controller.registry
	_identity = identity
	if not is_instance_valid(_registry): return _abort("Registry owner missing")
	var pin: Variant = identity.call()
	if _phase == "failed": return _result
	if not pin is Dictionary or pin.get("paused") != true or pin.get("source_sha256") != expected_source_sha256 or pin.get("owner_instance_id") != _registry.get_instance_id(): return _abort("Source/owner pin refused")
	if not pin.get("source_generation") is int or not pin.get("candidate_generation") is int or int(pin.source_generation) < 0 or int(pin.candidate_generation) < 0 or not pin.get("lease_id") is String or str(pin.lease_id).is_empty(): return _abort("Unversioned source owner refused")
	_pin = pin.duplicate(true)
	if not _pinned(): return _abort("Stopped editor lease/guard required")
	if _phase == "failed": return _result
	# No deep copy here: immutable-by-contract caller data is copied per row.
	_candidate = candidate
	_baseline = controller._baseline
	_source_hash = HashingContext.new()
	_source_hash.start(HashingContext.HASH_SHA256)
	_source_hash.update(JSON.stringify(_copy_header_exact(_baseline)).to_utf8_buffer())
	_keys = candidate.keys()
	_phase = "json_safety"
	return {"ok": true, "complete": false}

func _safe_unit() -> Dictionary:
	if _key_index >= _keys.size():
		_phase = "header"
		return {"ok": true, "processed": false}
	var key: Variant = _keys[_key_index]
	if not (key is String or key is StringName): return _abort("Карта должна содержать только безопасные JSON-данные")
	var value: Variant = _candidate.get(key)
	if key == "objects" and value is Array:
		if _row_index < value.size():
			# document→objects Array→record Dictionary: same depth as frozen
			# Document._json_safe(document, 0), not validate_record depth0.
			if not Document._json_safe(value[_row_index], 2): return _abort("Карта должна содержать только безопасные JSON-данные")
			_row_index += 1
			return {"ok": true, "processed": true}
	else:
		if not Document._json_safe(value, 1): return _abort("Карта должна содержать только безопасные JSON-данные")
	_key_index += 1
	_row_index = 0
	return {"ok": true, "processed": true}

func _header_unit() -> Dictionary:
	if _candidate.get("schema_version") != Document.SCHEMA_VERSION: return _abort("Версия формата карты не поддерживается")
	if not _candidate.get("map_id") is String or _candidate.map_id.strip_edges().is_empty(): return _abort("Неверный идентификатор карты")
	if not _candidate.get("metadata", {}) is Dictionary: return _abort("Неверные метаданные карты")
	var rows: Variant = _candidate.get("objects")
	if not rows is Array or rows.size() > Document.MAX_OBJECTS: return _abort("Неверный список объектов карты")
	_prepared = _copy_header_exact(_candidate)
	_prepared.objects = []
	_phase = "validate_records"
	_row_index = 0
	return {"ok": true, "processed": false}

func _validate_unit() -> Dictionary:
	if _row_index >= _candidate.objects.size():
		if _candidate.map_id != _baseline.map_id or not Trusted.matches(_baseline.get("metadata", {}), _candidate.get("metadata", {})): return _abort("Карта относится к другой исходной версии")
		_phase = "baseline"
		_row_index = 0
		return {"ok": true, "processed": false}
	var checked: Dictionary = Document.validate_record(_candidate.objects[_row_index])
	if not checked.ok: return _abort(str(checked.error))
	var row: Dictionary = checked.record
	if _seen.has(row.id): return _abort("Повторный идентификатор: " + row.id)
	_seen[row.id] = true
	_validated.append(row)
	_row_index += 1
	return {"ok": true, "processed": true}

func _baseline_unit() -> Dictionary:
	if _row_index >= _baseline.objects.size():
		if _source_hash.finish().hex_encode() != _pin.source_sha256: return _abort("Pinned source SHA does not match actual baseline")
		_phase = "records"
		_row_index = 0
		return {"ok": true, "processed": false}
	var row: Dictionary = _baseline.objects[_row_index]
	var bytes := JSON.stringify(row).to_utf8_buffer()
	_source_hash.update(PackedByteArray([0]))
	_source_hash.update(str(bytes.size()).to_utf8_buffer())
	_source_hash.update(PackedByteArray([0]))
	_source_hash.update(bytes)
	var trusted: Dictionary = row.duplicate(true)
	trusted.erase("transform")
	_originals[row.id] = trusted
	var extra: Dictionary = row.transform.duplicate(true)
	for key in ["position", "rotation", "scale"]: extra.erase(key)
	_extras[row.id] = extra
	_row_index += 1
	return {"ok": true, "processed": true}

func _record_unit() -> Dictionary:
	if _row_index >= _validated.size():
		_prepared.metadata = _baseline.get("metadata", {}).duplicate(true)
		_result = {"ok": true, "document": _prepared}
		_phase = "done"
		return {"ok": true, "processed": false}
	var row: Dictionary = _validated[_row_index]
	var supplied: Dictionary = row.duplicate(true)
	supplied.erase("transform")
	var expected: Dictionary
	var source_template: String = row.id
	if _originals.has(row.id):
		expected = _originals[row.id]
	else:
		var template_id: String = str(row.get("template_id", ""))
		source_template = template_id
		if not row.id.begins_with("editor:") or not _originals.has(template_id) or not _registry.is_editable(template_id): return _abort("Неизвестный или защищённый шаблон")
		expected = _originals[template_id].duplicate(true)
		expected.id = row.id
		expected["template_id"] = template_id
	if not Trusted.matches(expected, supplied): return _abort("Нельзя подменить исходные данные объекта")
	var supplied_extra: Dictionary = row.transform.duplicate(true)
	for key in ["position", "rotation", "scale"]: supplied_extra.erase(key)
	if not Trusted.matches(_extras[source_template], supplied_extra): return _abort("Нельзя подменить исходные параметры преобразования")
	var supplied_transform: Dictionary = _extras[source_template].duplicate(true)
	for key in ["position", "rotation", "scale"]: supplied_transform[key] = row.transform[key]
	row.clear()
	row.merge(expected.duplicate(true))
	row["transform"] = supplied_transform
	_prepared.objects.append(row)
	_row_index += 1
	return {"ok": true, "processed": true}

func step(max_units: int = 64, max_usec: int = 2000) -> Dictionary:
	if _stepping: return _abort("Reentrant preparation callback")
	_stepping = true
	var result: Dictionary = _step_owned(max_units, max_usec)
	_stepping = false
	return result

func _step_owned(max_units: int, max_usec: int) -> Dictionary:
	if _phase == "idle": return _fail("Preparation not started")
	if _phase == "failed": return _result
	if max_units < 1 or max_usec < 1: return _fail("Positive batch limits required")
	if not _pinned(): return _abort("Source/owner/lease changed during preparation")
	if _phase == "failed": return _result
	if _phase == "done": return _result
	var started := Time.get_ticks_usec()
	var units := 0
	while units < max_units:
		var result: Dictionary
		match _phase:
			"json_safety": result = _safe_unit()
			"header": result = _header_unit()
			"validate_records": result = _validate_unit()
			"baseline": result = _baseline_unit()
			"records": result = _record_unit()
			_: return _abort("Invalid cursor state")
		if not result.ok: return result
		if result.processed: units += 1
		if _phase == "done": break
		if units > 0 and Time.get_ticks_usec() - started >= max_usec: break
	_processed += units
	if not _pinned(): return _abort("Source/owner/lease changed during preparation")
	if _phase == "failed": return _result
	if _phase == "done": return _result
	return {"ok": true, "complete": false, "phase": _phase, "processed": _processed, "batch_units": units, "elapsed_usec": Time.get_ticks_usec() - started}

func status() -> Dictionary:
	return {"phase": _phase, "processed": _processed, "complete": _phase == "done", "failed": _phase == "failed"}
