extends RefCounted
## Versioned transform/add/delete overlay. Never mutates the immutable baseline.
## Original model/source/authority remain owned by the trusted game host.
const Document = preload("res://scripts/map_editor/map_document.gd")
const SCHEMA_VERSION := 1
const ADDED_ID_PREFIX := "editor:"

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			var items: PackedStringArray = []
			for key in keys:
				items.append(JSON.stringify(str(key)) + ":" + _canonical(value[key]))
			return "{" + ",".join(items) + "}"
		TYPE_ARRAY:
			var items: PackedStringArray = []
			for item in value: items.append(_canonical(item))
			return "[" + ",".join(items) + "]"
		TYPE_FLOAT:
			# JSON integer/float round trips compare identically within IEEE exact range.
			if absf(value) <= 9007199254740991.0 and value == floor(value):
				return str(int(value))
	return JSON.stringify(value, "", true, true)

static func baseline_hash(baseline: Dictionary) -> Dictionary:
	var checked := Document.validate_document(baseline)
	if not checked.ok: return checked
	return {"ok": true, "sha256": _canonical(checked.document).sha256_text()}

static func _index(document: Dictionary) -> Dictionary:
	var result := {}
	for row: Dictionary in document.objects: result[row.id] = row
	return result

static func _without_vectors(record: Dictionary) -> Dictionary:
	var result := record.duplicate(true)
	for key in ["position", "rotation", "scale"]: result.transform.erase(key)
	return result

static func _vectors(record: Dictionary) -> Dictionary:
	var result := {}
	for key in ["position", "rotation", "scale"]: result[key] = record.transform[key].duplicate()
	return result

static func derive_patch(baseline: Dictionary, current: Dictionary) -> Dictionary:
	var base_check := Document.validate_document(baseline)
	if not base_check.ok: return base_check
	var current_check := Document.validate_document(current)
	if not current_check.ok: return current_check
	var base: Dictionary = base_check.document
	var edited: Dictionary = current_check.document
	var base_header := base.duplicate(true)
	var edited_header := edited.duplicate(true)
	base_header.erase("objects")
	edited_header.erase("objects")
	if _canonical(base_header) != _canonical(edited_header):
		return _failure("Исходные метаданные карты нельзя менять")
	var base_rows := _index(base)
	var current_rows := _index(edited)
	var patch := {"schema_version": SCHEMA_VERSION, "map_id": base.map_id, "baseline_sha256": _canonical(base).sha256_text(), "deleted": [], "modified": [], "added": []}
	var expected_order: Array = []
	for row: Dictionary in base.objects:
		if not current_rows.has(row.id):
			patch.deleted.append(row.id)
			continue
		expected_order.append(row.id)
		var edited_row: Dictionary = current_rows[row.id]
		if _canonical(_without_vectors(row)) != _canonical(_without_vectors(edited_row)):
			return _failure("Нельзя менять исходную модель, данные или права объекта: " + row.id)
		if _canonical(_vectors(row)) != _canonical(_vectors(edited_row)):
			patch.modified.append({"id": row.id, "transform": _vectors(edited_row)})
	for row: Dictionary in edited.objects:
		if base_rows.has(row.id): continue
		if not row.id.begins_with(ADDED_ID_PREFIX) or row.id.length() <= ADDED_ID_PREFIX.length():
			return _failure("Новый объект должен иметь идентификатор editor:")
		patch.added.append(row.duplicate(true))
		expected_order.append(row.id)
	var actual_order: Array = []
	for row: Dictionary in edited.objects: actual_order.append(row.id)
	if actual_order != expected_order:
		return _failure("Перестановка исходных объектов не поддерживается форматом патча")
	return {"ok": true, "patch": patch}

static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true

static func apply_patch(baseline: Dictionary, patch: Variant) -> Dictionary:
	var checked := Document.validate_document(baseline)
	if not checked.ok: return checked
	var base: Dictionary = checked.document
	if not patch is Dictionary or not _exact_keys(patch, ["schema_version", "map_id", "baseline_sha256", "deleted", "modified", "added"]):
		return _failure("Неверный формат патча карты")
	if patch.schema_version != SCHEMA_VERSION or patch.map_id != base.map_id:
		return _failure("Патч предназначен для другой карты или версии")
	if not patch.baseline_sha256 is String or patch.baseline_sha256.length() != 64 or patch.baseline_sha256 != _canonical(base).sha256_text():
		return _failure("Исходная карта изменена: хеш не совпадает")
	for key in ["deleted", "modified", "added"]:
		if not patch[key] is Array or patch[key].size() > Document.MAX_OBJECTS:
			return _failure("Неверный список операций патча")
	var base_rows := _index(base)
	var deleted := {}
	var modified := {}
	var added: Array = []
	var seen := {}
	for id in patch.deleted:
		if not id is String or not base_rows.has(id) or seen.has(id):
			return _failure("Неизвестное или повторное удаление объекта")
		seen[id] = true
		deleted[id] = true
	for operation in patch.modified:
		if not operation is Dictionary or not _exact_keys(operation, ["id", "transform"]):
			return _failure("Изменение может содержать только id и transform")
		var id: Variant = operation.id
		if not id is String or not base_rows.has(id) or seen.has(id):
			return _failure("Неизвестное или повторное изменение объекта")
		if not operation.transform is Dictionary or not _exact_keys(operation.transform, ["position", "rotation", "scale"]):
			return _failure("Патч может менять только положение, поворот и масштаб")
		var candidate: Dictionary = base_rows[id].duplicate(true)
		candidate.transform.merge(operation.transform.duplicate(true), true)
		var record_check := Document.validate_record(candidate)
		if not record_check.ok: return record_check
		seen[id] = true
		modified[id] = record_check.record
	for record in patch.added:
		var record_check := Document.validate_record(record)
		if not record_check.ok: return record_check
		var id: String = record_check.record.id
		if not id.begins_with(ADDED_ID_PREFIX) or id.length() <= ADDED_ID_PREFIX.length() or base_rows.has(id) or seen.has(id):
			return _failure("Неверный или повторный идентификатор нового объекта")
		seen[id] = true
		added.append(record_check.record)
	var result := base.duplicate(true)
	result.objects = []
	for row: Dictionary in base.objects:
		if not deleted.has(row.id): result.objects.append(modified.get(row.id, row).duplicate(true))
	result.objects.append_array(added)
	return Document.validate_document(result)
