extends RefCounted
## Portable data-only publication envelope. Checksums are integrity, NOT authority.
## Resource resolution and protected-object admission remain at the trusted host.
const Patch = preload("res://scripts/map_editor/map_patch.gd")
const Document = preload("res://scripts/map_editor/map_document.gd")
const SCHEMA := "mafiozi.godot.map-bundle/v1"
const MAX_BYTES := 64 * 1024 * 1024

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for letter: String in value:
		if letter not in "0123456789abcdef": return false
	return true

static func _ground_valid(ground: Dictionary, validator: Callable) -> bool:
	if ground.is_empty(): return true
	if not validator.is_valid(): return false
	var result: Variant = validator.call(ground.duplicate(true))
	return result is Dictionary and result.get("ok") == true

static func _refs(records: Array, requirements: Dictionary) -> Dictionary:
	var unique := {}
	for record: Dictionary in records:
		var model: String = str(record.get("model", ""))
		if not requirements.has(model) or not requirements[model] is Array:
			return _failure("Нет доверенного описания ресурсов модели: " + model)
		for hash: Variant in requirements[model]:
			if not _sha(hash): return _failure("Неверная контрольная сумма ресурса")
			unique[hash] = true
	var hashes: Array = unique.keys()
	hashes.sort()
	return {"ok": true, "hashes": hashes}

static func create(baseline: Dictionary, edited: Dictionary, model_requirements: Dictionary, label: String = "Моя карта", ground: Dictionary = {}, ground_validator: Callable = Callable()) -> Dictionary:
	if label.strip_edges().is_empty() or label.length() > 200: return _failure("Название карты: от 1 до 200 символов")
	var delta: Dictionary = Patch.derive_patch(baseline, edited)
	if not delta.ok: return delta
	var checked: Dictionary = Document.validate_document(edited)
	if not checked.ok: return checked
	var refs := _refs(checked.document.objects, model_requirements)
	if not refs.ok: return refs
	if not _ground_valid(ground, ground_validator): return _failure("Слой земли не прошёл проверку владельца")
	var payload := {"schema": SCHEMA, "label": label, "object_patch": delta.patch, "ground_patch": ground.duplicate(true), "resource_sha256": refs.hashes}
	# Canonical JSON treats an exact integer and its parsed float identically.
	var bundle := payload.duplicate(true)
	bundle["payload_sha256"] = Patch._canonical(payload).sha256_text()
	return {"ok": true, "bundle": bundle}

static func validate(baseline: Dictionary, bundle: Variant, model_requirements: Dictionary, available_resources: Dictionary, ground_validator: Callable = Callable()) -> Dictionary:
	if not bundle is Dictionary or not Document._json_safe(bundle): return _failure("Небезопасный файл карты")
	var keys: Array = bundle.keys()
	keys.sort()
	if keys != ["ground_patch", "label", "object_patch", "payload_sha256", "resource_sha256", "schema"]: return _failure("Неподдерживаемые поля публикации")
	if bundle.schema != SCHEMA or not bundle.label is String or bundle.label.strip_edges().is_empty() or bundle.label.length() > 200:
		return _failure("Неверный формат публикации")
	if not bundle.object_patch is Dictionary or not bundle.ground_patch is Dictionary or not bundle.resource_sha256 is Array or not _sha(bundle.payload_sha256):
		return _failure("Повреждённые данные публикации")
	var payload: Dictionary = bundle.duplicate(true)
	payload.erase("payload_sha256")
	if Patch._canonical(payload).sha256_text() != bundle.payload_sha256: return _failure("Контрольная сумма файла не совпадает")
	var expanded: Dictionary = Patch.apply_patch(baseline, bundle.object_patch)
	if not expanded.ok: return expanded
	var expected := _refs(expanded.document.objects, model_requirements)
	if not expected.ok: return expected
	if bundle.resource_sha256 != expected.hashes: return _failure("Подменён или неполон список ресурсов")
	for hash: String in expected.hashes:
		if available_resources.get(hash) != true: return _failure("Не установлен и не проверен исходный ресурс: " + hash)
	if not _ground_valid(bundle.ground_patch, ground_validator): return _failure("Слой земли требует проверенного адаптера")
	return {"ok": true, "document": expanded.document, "ground_patch": bundle.ground_patch.duplicate(true), "label": bundle.label}

static func export_json(bundle: Dictionary) -> Dictionary:
	if not Document._json_safe(bundle): return _failure("Небезопасные данные")
	var encoded := JSON.stringify(bundle, "\t", true, true)
	if encoded.to_utf8_buffer().size() > MAX_BYTES: return _failure("Файл карты слишком большой")
	return {"ok": true, "text": encoded}

static func import_json(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _failure("Файл карты слишком большой")
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary or not Document._json_safe(json.data): return _failure("Файл карты повреждён")
	# Caller MUST validate against its trusted baseline/resources before install.
	return {"ok": true, "bundle": json.data}
