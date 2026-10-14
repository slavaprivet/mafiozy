extends RefCounted
## JSON only. Never loads scripts/scenes from imported map records.
const Document = preload("res://scripts/map_editor/map_document.gd")
const MAX_FILE_BYTES := 64 * 1024 * 1024
const DEFAULT_PATH := "user://maps/current.json"

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func valid_path(path: String) -> bool:
	if not path.begins_with("user://maps/") or not path.ends_with(".json"):
		return false
	var relative := path.trim_prefix("user://maps/")
	if relative.contains("\\") or relative.contains(":"):
		return false
	for index in relative.length():
		if relative.unicode_at(index) < 32: return false
	for segment in relative.split("/"):
		if segment.is_empty() or segment == "." or segment == "..": return false
		# Windows strips trailing dots/spaces and recognises device filenames.
		# Reject these aliases rather than trusting textual traversal checks.
		if segment.ends_with(".") or segment.ends_with(" "): return false
		for forbidden in ["<", ">", "\"", "|", "?", "*"]:
			if segment.contains(forbidden): return false
		var basename: String = segment.split(".")[0].to_lower()
		if basename in ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]: return false
	return true

static func import_json(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES: return _failure("Файл карты слишком большой")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("Повреждён JSON карты: строка " + str(parser.get_error_line()))
	return Document.validate_document(parser.data)

static func export_json(document: Variant) -> Dictionary:
	var data: Variant = document.to_dictionary() if document is RefCounted and document.has_method("to_dictionary") else document
	var validated := Document.validate_document(data)
	if not validated.ok: return validated
	var text := JSON.stringify(validated.document, "\t", false, true)
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES: return _failure("Файл карты слишком большой")
	return {"ok": true, "text": text}

static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("Не удалось открыть карту: " + error_string(FileAccess.get_open_error()))
	if file.get_length() > MAX_FILE_BYTES: return _failure("Файл карты слишком большой")
	return import_json(file.get_as_text())

static func load_document(path: String = DEFAULT_PATH) -> Dictionary:
	if not valid_path(path): return _failure("Карта должна находиться в user://maps/ и иметь расширение .json")
	var result := _read(path)
	if result.ok:
		result.recovered = false
		return result
	var backup := _read(path + ".bak")
	if backup.ok:
		backup.recovered = true
		backup.warning = "Основной файл повреждён или недоступен. Загружена резервная карта."
		return backup
	return result

static func save_document(document: Variant, path: String = DEFAULT_PATH) -> Dictionary:
	if not valid_path(path): return _failure("Неверный путь сохранения карты")
	var encoded := export_json(document)
	if not encoded.ok: return encoded
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK: return _failure("Не удалось создать папку карты: " + error_string(error))
	var temp := absolute + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return _failure("Не удалось записать карту: " + error_string(FileAccess.get_open_error()))
	file.store_string(encoded.text)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return _failure("Ошибка записи карты: " + error_string(error))
	# Validate bytes read back before replacing any good save.
	var verified := _read(temp)
	if not verified.ok: return _failure("Проверка сохранённого файла не пройдена")
	var backup := absolute + ".bak"
	if FileAccess.file_exists(absolute):
		# A corrupt primary must never overwrite the last healthy backup.
		if _read(absolute).ok:
			error = DirAccess.copy_absolute(absolute, backup)
			if error != OK: return _failure("Не удалось сохранить резервную копию: " + error_string(error))
		error = DirAccess.remove_absolute(absolute)
		if error != OK: return _failure("Не удалось заменить файл карты: " + error_string(error))
	error = DirAccess.rename_absolute(temp, absolute)
	if error != OK:
		if FileAccess.file_exists(backup): DirAccess.copy_absolute(backup, absolute)
		return _failure("Не удалось завершить сохранение: " + error_string(error))
	return {"ok": true, "path": path, "bytes": encoded.text.to_utf8_buffer().size()}
