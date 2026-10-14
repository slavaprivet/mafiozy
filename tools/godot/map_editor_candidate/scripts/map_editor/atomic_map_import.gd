extends RefCounted
## Cross-owner import candidate: scene staging first, both silent model commits,
## cleanup receipts second, notifications last. Never resumes gameplay itself.
signal committed
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
var _controller: Node
var _ground: RefCounted
var _renderer: Node
var _lease: Callable
var _navigation: Callable # (phase, detached_payload) -> {ok, receipt?}
var _admission: Callable # Optional trusted checkpoint refusal, never authority JSON.
var _requirements := {}
var _resources := {}
var _busy := false
var _finalizing := false
var _aborting := false
var _context: Dictionary = {}

static func accepted(result: Variant) -> bool:
	return (result is bool and result) or (result is Dictionary and result.get("ok", false) == true)

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func configure(controller: Node, ground: RefCounted, renderer: Node, paused_lease: Callable, navigation_adapter: Callable, requirements: Dictionary, verified_resources: Dictionary, admission: Callable = Callable()) -> Dictionary:
	if _controller != null or not is_instance_valid(controller) or ground == null or not is_instance_valid(renderer) or not paused_lease.is_valid() or not navigation_adapter.is_valid(): return failure("Нужны владельцы объектов, земли, воды, навигации и остановленной сессии")
	_controller = controller
	_ground = ground
	_renderer = renderer
	_lease = paused_lease
	_navigation = navigation_adapter
	_admission = admission
	_requirements = requirements.duplicate(true)
	_resources = verified_resources.duplicate(true)
	return {"ok": true}

func _paused() -> bool:
	return _lease.is_valid() and accepted(_lease.call())

func _payload() -> Dictionary:
	return {"objects": _context.get("object_document", {}).duplicate(true), "ground_delta": _context.get("ground_plan", {}).get("delta", {}).duplicate(true), "navigation_receipt": _context.get("navigation_receipt")}

func _gate(phase: String) -> Dictionary:
	if not _paused(): return failure("Сессия должна оставаться остановленной")
	if _admission.is_valid() and not accepted(_admission.call(phase, _payload())): return failure("Хозяин не принял этап: " + phase)
	if not _paused(): return failure("Хозяин изменил остановленную сессию во время проверки")
	return {"ok": true}

func _unlock() -> void:
	if _context.get("object_guard", false): _controller.document.end_install_guard()
	if _context.get("ground_guard", false): _ground.end_install_guard()
	_controller.end_atomic_install()
	_context.clear()
	_busy = false

func _abort(message: String) -> Dictionary:
	if _aborting or _context.get("models_committed", false): return {"ok": false, "error": "Нельзя откатывать только сцену после общего принятия моделей", "committed": bool(_context.get("models_committed", false))}
	if not _paused(): return {"ok": false, "error": message + "; требуется остановить игру для отката", "committed": false, "rollback_ok": false, "retry_rollback": true}
	_aborting = true
	var navigation_ok := true
	if _context.get("navigation_started", false): navigation_ok = accepted(_navigation.call("rollback", _payload()))
	if not _paused():
		_aborting = false
		return {"ok": false, "error": message + "; владелец изменил остановку при откате навигации", "committed": false, "rollback_ok": false, "retry_rollback": true}
	var ground_result: Dictionary = _renderer.rollback()
	if not _paused():
		_aborting = false
		return {"ok": false, "error": message + "; требуется остановка для завершения физического отката", "committed": false, "rollback_ok": false, "retry_rollback": true}
	var object_result: Dictionary = _controller.registry.restore_install_checkpoint(_context.scene_checkpoint)
	_controller.document.restore_install_checkpoint(_context.object_checkpoint)
	_ground.restore_install_checkpoint(_context.ground_checkpoint)
	_aborting = false
	var restored: bool = navigation_ok and ground_result.ok and object_result.ok
	if restored:
		_unlock()
		return {"ok": false, "error": message, "committed": false, "rollback_ok": true}
	return {"ok": false, "error": message + "; физический откат не подтверждён всеми владельцами", "committed": false, "rollback_ok": false, "retry_rollback": true}

func retry_rollback() -> Dictionary:
	if not _busy or _context.is_empty() or _context.get("models_committed", false): return failure("Нет незавершённого отката")
	return _abort("Повтор подтверждения отката")

func install_bundle(bundle: Dictionary) -> Dictionary:
	if _controller == null: return failure("Общая загрузка не подключена")
	if _busy: return {"ok": false, "error": "Общая загрузка уже удерживает сессию", "committed": bool(_context.get("models_committed", false))}
	if _controller.document.install_guard_active or _ground.install_guard_active: return failure("Документ уже удерживается другим владельцем")
	if not _paused(): return failure("Нельзя загружать карту во время игры")
	var lease_result: Dictionary = _controller.begin_atomic_install()
	if not lease_result.ok: return lease_result
	_busy = true
	# Capture the exact scene, current documents and history, not just source poses.
	var checkpoint: Dictionary = _controller.registry.capture_install_checkpoint()
	if not checkpoint.ok:
		_unlock()
		return checkpoint
	_context = {"scene_checkpoint": checkpoint, "object_checkpoint": _controller.document.capture_install_checkpoint(), "ground_checkpoint": _ground.capture_install_checkpoint(), "models_committed": false, "navigation_started": false, "ground_changed": false, "ground_finalized": false, "navigation_finalized": false, "object_guard": false, "ground_guard": false}
	_context.object_guard = _controller.document.begin_install_guard()
	_context.ground_guard = _ground.begin_install_guard()
	if not _context.object_guard or not _context.ground_guard: return _abort("Документы или активный мазок уже удерживают сессию")
	var admitted: Dictionary = Bundle.validate(_controller._baseline, bundle, _requirements, _resources, _ground.validate_patch)
	if not admitted.ok: return _abort(str(admitted.error))
	var objects: Dictionary = _controller.prepare_install_document(admitted.document)
	if not objects.ok: return _abort(str(objects.error))
	var ground_patch: Dictionary = admitted.ground_patch if not admitted.ground_patch.is_empty() else _ground.export_patch()
	var ground_plan: Dictionary = _ground.prepare_patch(ground_patch)
	if not ground_plan.ok: return _abort(str(ground_plan.error))
	_context.object_document = objects.document
	_context.ground_plan = ground_plan
	_context.ground_changed = not ground_plan.delta.cells.is_empty()
	var step := _gate("prepared")
	if not step.ok: return _abort(str(step.error))
	for row: Dictionary in objects.document.objects:
		if _controller.registry.has_object(row.id): continue
		var frame: Variant = _controller.registry.decode_transform(row.transform)
		if frame == null: return _abort("Неверное преобразование нового объекта")
		var copy: Dictionary = _controller.registry.create_copy(row.template_id, row.id, frame)
		if not copy.ok: return _abort(str(copy.error))
	step = _controller.registry.apply_document(objects.document, true)
	if not step.ok: return _abort(str(step.error))
	step = _controller.registry.apply_document(objects.document)
	if not step.ok: return _abort(str(step.error))
	step = _gate("objects_staged")
	if not step.ok: return _abort(str(step.error))
	if _context.ground_changed:
		step = _renderer.apply(ground_plan.delta)
		if not step.ok: return _abort(str(step.error))
	step = _gate("ground_staged")
	if not step.ok: return _abort(str(step.error))
	if _context.ground_changed:
		step = _renderer.validate_navigation(ground_plan.delta)
		if not step.ok: return _abort(str(step.error))
	_context.navigation_started = true
	var nav_result: Variant = _navigation.call("prepare", _payload())
	if not accepted(nav_result): return _abort("Общая навигация не подготовила изменения объектов и земли")
	if nav_result is Dictionary: _context.navigation_receipt = nav_result.get("receipt")
	step = _gate("before_commit")
	if not step.ok: return _abort(str(step.error))
	if _controller.document.capture_install_checkpoint() != _context.object_checkpoint or _ground.capture_install_checkpoint() != _context.ground_checkpoint:
		return _abort("Модели или история изменились во время подготовки")
	# No external callback or notification occurs between these two assignments.
	step = _controller.document.commit_install_document(objects.document)
	if not step.ok: return _abort(str(step.error))
	step = _ground.commit_prepared_patch(ground_plan)
	if not step.ok: return _abort(str(step.error))
	_context.models_committed = true
	return retry_finalize()

func retry_finalize() -> Dictionary:
	if _finalizing or not _busy or not _context.get("models_committed", false): return failure("Нет завершённых моделей, ожидающих освобождения ресурсов")
	_finalizing = true
	var step := _gate("finalize")
	if step.ok and _context.ground_changed and not _context.ground_finalized:
		step = _renderer.finalize()
		if step.ok: _context.ground_finalized = true
	if step.ok and not _context.navigation_finalized:
		if not accepted(_navigation.call("finalize", _payload())): step = failure("Хозяин навигации ещё удерживает подготовленные ресурсы")
		else: _context.navigation_finalized = true
	if step.ok and not _paused(): step = failure("Владелец изменил остановленную сессию при освобождении ресурсов")
	if not step.ok:
		_finalizing = false
		return {"ok": false, "error": str(step.error) + "; игра остаётся остановленной", "committed": true, "retry_finalize": true}
	# Both models and both scene owners agree; observers cannot enter a second
	# import or gameplay while these final coherent notifications are emitted.
	_controller.document.changed.emit()
	committed.emit()
	_finalizing = false
	_unlock()
	return {"ok": true, "committed": true}

func busy_status() -> Dictionary:
	return {"busy": _busy, "committed": bool(_context.get("models_committed", false)), "retry_finalize": _busy and bool(_context.get("models_committed", false)), "retry_rollback": _busy and not bool(_context.get("models_committed", false))}

