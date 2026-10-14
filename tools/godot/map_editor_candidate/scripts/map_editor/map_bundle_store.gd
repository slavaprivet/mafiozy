extends RefCounted
## Data-only combined object/ground saves. No scene or executable loading.
## Files are admitted against trusted source/resources before read or replacement.
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
const Patch = preload("res://scripts/map_editor/map_patch.gd")
const DEFAULT_PATH := "user://maps/published.json"

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _read(path: String, baseline: Dictionary, requirements: Dictionary, resources: Dictionary, ground_validator: Callable) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("Не удалось открыть файл карты")
	if file.get_length() > Bundle.MAX_BYTES: return _failure("Файл карты слишком большой")
	var parsed := Bundle.import_json(file.get_as_text())
	if not parsed.ok: return parsed
	var admitted := Bundle.validate(baseline, parsed.bundle, requirements, resources, ground_validator)
	if admitted.ok: admitted["bundle"] = parsed.bundle
	return admitted

static func load_bundle(baseline: Dictionary, requirements: Dictionary, resources: Dictionary, path: String = DEFAULT_PATH, ground_validator: Callable = Callable()) -> Dictionary:
	if not Store.valid_path(path): return _failure("Файл карты должен находиться в user://maps/ и иметь расширение .json")
	var result := _read(path, baseline, requirements, resources, ground_validator)
	if result.ok:
		result["recovered"] = false
		return result
	var backup := _read(path + ".bak", baseline, requirements, resources, ground_validator)
	if backup.ok:
		backup["recovered"] = true
		backup["warning"] = "Основной файл недоступен или не прошёл проверку. Открыта резервная карта."
		return backup
	return result

static func save_bundle(bundle: Dictionary, baseline: Dictionary, requirements: Dictionary, resources: Dictionary, path: String = DEFAULT_PATH, ground_validator: Callable = Callable()) -> Dictionary:
	if not Store.valid_path(path): return _failure("Неверный путь сохранения карты")
	var admitted := Bundle.validate(baseline, bundle, requirements, resources, ground_validator)
	if not admitted.ok: return admitted
	var encoded := Bundle.export_json(bundle)
	if not encoded.ok: return encoded
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK: return _failure("Не удалось создать папку карты")
	var temp := absolute + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return _failure("Не удалось записать файл карты")
	file.store_string(encoded.text)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return _failure("Ошибка записи файла карты")
	var verified := _read(temp, baseline, requirements, resources, ground_validator)
	if not verified.ok or Patch._canonical(verified.get("bundle", {})) != Patch._canonical(bundle):
		return _failure("Проверка записанных данных не пройдена")
	var backup := absolute + ".bak"
	if FileAccess.file_exists(absolute):
		# Never replace the last admitted backup with corrupt or stale source data.
		if _read(absolute, baseline, requirements, resources, ground_validator).ok:
			error = DirAccess.copy_absolute(absolute, backup)
			if error != OK: return _failure("Не удалось записать резервную карту")
		error = DirAccess.remove_absolute(absolute)
		if error != OK: return _failure("Не удалось заменить файл карты")
	error = DirAccess.rename_absolute(temp, absolute)
	if error != OK:
		if FileAccess.file_exists(backup) and _read(backup, baseline, requirements, resources, ground_validator).ok:
			DirAccess.copy_absolute(backup, absolute)
		return _failure("Не удалось завершить сохранение карты")
	return {"ok": true, "path": path, "bytes": encoded.text.to_utf8_buffer().size()}
