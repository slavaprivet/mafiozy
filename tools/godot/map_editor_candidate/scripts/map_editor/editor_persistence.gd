extends RefCounted
## Unified UI file workflow. Imported bundles only install through the trusted
## cross-owner transaction; never call sequential object/ground installation.
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
const BundleStore = preload("res://scripts/map_editor/map_bundle_store.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
var _controller: Node
var _ground: RefCounted
var _atomic: RefCounted
var _requirements: Dictionary
var _resources: Dictionary
var _ready: Callable
var _read_text: Callable
var _write_text: Callable
var _save_path: String
var _export_path: String
var _busy := false

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
static func _accepted(value: Variant) -> bool:
	return (value is bool and value) or (value is Dictionary and value.get("ok", false) == true)

func configure(controller: Node, ground: RefCounted, atomic_import: RefCounted, requirements: Dictionary, resources: Dictionary, transaction_ready: Callable, text_io: Dictionary, save_path: String = "user://maps/current-map.json", export_path: String = "user://maps/published.json") -> Dictionary:
	if _controller != null or not is_instance_valid(controller) or ground == null or atomic_import == null or not transaction_ready.is_valid(): return _failure("Нужны редактор и единый владелец загрузки карты")
	if not ground.has_method("export_patch") or not ground.has_method("validate_patch") or not atomic_import.has_method("install_bundle") or not atomic_import.has_method("busy_status"): return _failure("Несовместимые владельцы карты")
	if not text_io.get("read") is Callable or not text_io.read.is_valid() or not text_io.get("write") is Callable or not text_io.write.is_valid(): return _failure("Нет обработчиков импорта и экспорта текста")
	if not Store.valid_path(save_path) or not Store.valid_path(export_path): return _failure("Неверные пути карты")
	_controller = controller
	_ground = ground
	_atomic = atomic_import
	_requirements = requirements.duplicate(true)
	_resources = resources.duplicate(true)
	_ready = transaction_ready
	_read_text = text_io.read
	_write_text = text_io.write
	_save_path = save_path
	_export_path = export_path
	return {"ok": true}

func _create(label: String) -> Dictionary:
	return Bundle.create(_controller._baseline, _controller.document.to_dictionary(), _requirements, label, _ground.export_patch(), _ground.validate_patch)

func _install(bundle: Dictionary) -> Dictionary:
	# Atomic admission repeats native source/template checks after data validation.
	return _atomic.install_bundle(bundle)

func handle_action(action: String, payload: Dictionary = {}) -> Dictionary:
	if _controller == null or not is_instance_valid(_controller) or not _controller.active: return _failure("Откройте редактор клавишей K")
	if _busy: return _failure("Работа с файлом карты уже выполняется")
	if action == "retry_pending":
		var state: Dictionary = _atomic.busy_status()
		if not state.get("busy", false): return {"ok": true, "unchanged": true}
		_busy = true
		var retried: Dictionary = _atomic.retry_finalize() if state.get("committed", false) else _atomic.retry_rollback()
		_busy = false
		return {"ok": true, "rolled_back": true} if retried.get("rollback_ok", false) else retried
	if not _accepted(_ready.call()) or _atomic.busy_status().get("busy", false): return _failure("Сначала завершите обновление карты")
	if action not in ["save", "load", "export", "import"]: return _failure("Неизвестное действие с файлом карты")
	_busy = true
	var result: Dictionary
	match action:
		"save", "export":
			var created := _create(str(payload.get("label", "Моя карта")))
			result = created
			if created.ok:
				var path := _save_path if action == "save" else _export_path
				result = BundleStore.save_bundle(created.bundle, _controller._baseline, _requirements, _resources, path, _ground.validate_patch)
				if result.ok and action == "export":
					var encoded := Bundle.export_json(created.bundle)
					if not encoded.ok: result = encoded
					elif not _accepted(_write_text.call(encoded.text)): result = {"ok": false, "path": path, "file_saved": true, "error": "Файл публикации сохранён, но текст не удалось скопировать"}
		"load":
			var loaded := BundleStore.load_bundle(_controller._baseline, _requirements, _resources, _save_path, _ground.validate_patch)
			result = loaded
			if loaded.ok:
				result = _install(loaded.bundle)
				if loaded.get("recovered", false): result["warning"] = loaded.warning
		"import":
			var text: Variant = _read_text.call()
			result = _failure("Импорт требует текста JSON")
			if text is String:
				var parsed := Bundle.import_json(text)
				result = parsed
				if parsed.ok:
					var checked := Bundle.validate(_controller._baseline, parsed.bundle, _requirements, _resources, _ground.validate_patch)
					result = _install(parsed.bundle) if checked.ok else checked
	_busy = false
	return result
