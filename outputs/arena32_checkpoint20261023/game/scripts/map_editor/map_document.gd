extends RefCounted
## Native data-only map model. Callers never receive owned mutable containers.
signal changed

const SCHEMA_VERSION := 1
const MAX_OBJECTS := 100000
const MAX_JSON_DEPTH := 32
var _header: Dictionary = {"schema_version": SCHEMA_VERSION, "map_id": "untitled", "metadata": {}}
var _records: Dictionary = {}
var _order: Array[String] = []
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _history_limit: int

func _init(history_limit: int = 100) -> void:
	_history_limit = clampi(history_limit, 0, 1000)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_JSON_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not _json_safe(item, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is StringName) or not _json_safe(value[key], depth + 1): return false
			return true
	return false

static func validate_record(record: Variant) -> Dictionary:
	if not record is Dictionary or not _json_safe(record):
		return _failure("Объект должен содержать только безопасные JSON-данные")
	for key in ["id", "kind"]:
		if not record.get(key) is String or record[key].strip_edges().is_empty() or record[key].length() > 512:
			return _failure("Неверное поле объекта: " + key)
	if record.has("model") and not record.model is String:
		return _failure("Модель должна быть строкой каталога")
	if record.has("source") and not record.source is Dictionary:
		return _failure("Исходные данные объекта должны быть словарём")
	var normalized: Dictionary = record.duplicate(true)
	var transform_data: Variant = normalized.get("transform", {})
	if not transform_data is Dictionary:
		return _failure("Неверное преобразование объекта")
	for key in ["position", "rotation", "scale"]:
		var vector: Variant = transform_data.get(key, [1.0, 1.0, 1.0] if key == "scale" else [0.0, 0.0, 0.0])
		if not vector is Array or vector.size() != 3:
			return _failure("Неверный вектор: " + key)
		for component in vector:
			if not (component is float or component is int) or not is_finite(float(component)):
				return _failure("Нечисловая координата: " + key)
			if key == "scale" and float(component) < 0.0001:
				return _failure("Масштаб объекта должен быть положительным")
		transform_data[key] = vector.duplicate()
	normalized.transform = transform_data
	return {"ok": true, "record": normalized}

static func validate_document(document: Variant) -> Dictionary:
	if not document is Dictionary or not _json_safe(document):
		return _failure("Карта должна содержать только безопасные JSON-данные")
	if document.get("schema_version") != SCHEMA_VERSION:
		return _failure("Версия формата карты не поддерживается")
	if not document.get("map_id") is String or document.map_id.strip_edges().is_empty():
		return _failure("Неверный идентификатор карты")
	if not document.get("metadata", {}) is Dictionary:
		return _failure("Неверные метаданные карты")
	var objects: Variant = document.get("objects")
	if not objects is Array or objects.size() > MAX_OBJECTS:
		return _failure("Неверный список объектов карты")
	var ids := {}
	var normalized: Dictionary = document.duplicate(true)
	normalized.objects = []
	for record in objects:
		var result := validate_record(record)
		if not result.ok: return result
		if ids.has(result.record.id): return _failure("Повторный идентификатор: " + result.record.id)
		ids[result.record.id] = true
		normalized.objects.append(result.record)
	return {"ok": true, "document": normalized}

func load_document(document: Dictionary) -> Dictionary:
	var result := validate_document(document)
	if not result.ok: return result
	_header = result.document.duplicate(true)
	_header.erase("objects")
	_records.clear()
	_order.clear()
	for record in result.document.objects:
		_records[record.id] = record
		_order.append(record.id)
	_undo.clear()
	_redo.clear()
	changed.emit()
	return {"ok": true}

func to_dictionary() -> Dictionary:
	var result := _header.duplicate(true)
	result.objects = all_records()
	return result

func all_records() -> Array:
	var result: Array = []
	for id in _order: result.append(_records[id].duplicate(true))
	return result

func get_record(id: String) -> Dictionary:
	return _records[id].duplicate(true) if _records.has(id) else {}

func has_record(id: String) -> bool:
	return _records.has(id)

func object_count() -> int:
	return _records.size()

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func _preview_history(history: Array[Dictionary], backwards: bool) -> Dictionary:
	if history.is_empty(): return _failure("Нет действий для отмены или повтора")
	var candidate = get_script().new(0)
	var loaded: Dictionary = candidate.load_document(to_dictionary())
	if not loaded.ok: return loaded
	var operation: Dictionary = history.back()
	candidate._apply(operation, backwards)
	return {"ok": true, "id": operation.id, "document": candidate.to_dictionary()}

func peek_undo() -> Dictionary:
	return _preview_history(_undo, true)

func peek_redo() -> Dictionary:
	return _preview_history(_redo, false)

func _commit(id: String, before: Dictionary, after: Dictionary, index: int) -> Dictionary:
	var operation := {"id": id, "before": before.duplicate(true), "after": after.duplicate(true), "index": index}
	_apply(operation, false)
	_redo.clear()
	if _history_limit > 0:
		_undo.append(operation)
		if _undo.size() > _history_limit: _undo.pop_front()
	changed.emit()
	return {"ok": true, "id": id}

func _apply(operation: Dictionary, backwards: bool) -> void:
	var value: Dictionary = operation.before if backwards else operation.after
	var id: String = operation.id
	if value.is_empty():
		_records.erase(id)
		_order.erase(id)
	else:
		if not _records.has(id): _order.insert(clampi(operation.index, 0, _order.size()), id)
		_records[id] = value.duplicate(true)

func add_record(record: Dictionary) -> Dictionary:
	var result := validate_record(record)
	if not result.ok: return result
	var id: String = result.record.id
	if _records.has(id): return _failure("Объект с этим идентификатором уже существует")
	if _records.size() >= MAX_OBJECTS: return _failure("Достигнут предел объектов карты")
	return _commit(id, {}, result.record, _order.size())

func update_record(id: String, changes: Dictionary) -> Dictionary:
	if not _records.has(id): return _failure("Объект не найден")
	if changes.has("id") and changes.id != id: return _failure("Идентификатор объекта нельзя менять")
	var updated: Dictionary = _records[id].duplicate(true)
	# Top-level replacement is explicit, except transform components can be patched.
	updated.merge(changes.duplicate(true), true)
	if changes.get("transform") is Dictionary:
		var transform_data: Dictionary = _records[id].transform.duplicate(true)
		transform_data.merge(changes.transform.duplicate(true), true)
		updated.transform = transform_data
	var result := validate_record(updated)
	if not result.ok: return result
	if result.record == _records[id]: return {"ok": true, "id": id, "unchanged": true}
	return _commit(id, _records[id], result.record, _order.find(id))

func delete_record(id: String) -> Dictionary:
	if not _records.has(id): return _failure("Объект не найден")
	return _commit(id, _records[id], {}, _order.find(id))

func undo() -> Dictionary:
	if _undo.is_empty(): return _failure("Нет действий для отмены")
	var operation: Dictionary = _undo.pop_back()
	_apply(operation, true)
	_redo.append(operation)
	changed.emit()
	return {"ok": true, "id": operation.id}

func redo() -> Dictionary:
	if _redo.is_empty(): return _failure("Нет действий для повтора")
	var operation: Dictionary = _redo.pop_back()
	_apply(operation, false)
	_undo.append(operation)
	changed.emit()
	return {"ok": true, "id": operation.id}
