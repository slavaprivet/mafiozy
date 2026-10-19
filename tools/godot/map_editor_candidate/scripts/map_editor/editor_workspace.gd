extends Node
## One input/UI owner for objects and ground. Main calls handle_input first and
## gates gameplay whenever editor.active, including events left to native GUI.
## Dependencies are injected by the host: no scene loading or source-hash bypass.
var editor: Node
var brush: RefCounted
var ground_panel: CanvasLayer
var renderer: Node
var ground_preview: Node3D
var mode := "objects"
var _persistence: Callable
var _transaction_ready: Callable
var _cleanup_blocked := false
var _recovery_required := false

static func accepted(result: Variant) -> bool:
	return (result is bool and result) or (result is Dictionary and result.get("ok", false) == true)

func setup(object_editor: Node, ground_brush: RefCounted, terrain_panel: CanvasLayer, terrain_renderer: Node, persistence: Callable, transaction_ready: Callable, terrain_preview: Node3D = null) -> Dictionary:
	if editor != null or not is_inside_tree() or not is_instance_valid(object_editor) or ground_brush == null or not is_instance_valid(terrain_panel) or not is_instance_valid(terrain_renderer):
		return {"ok": false, "error": "Нужны готовые редакторы объектов и земли"}
	if not persistence.is_valid() or not transaction_ready.is_valid():
		return {"ok": false, "error": "Нужны единое сохранение карты и проверка завершённых транзакций"}
	if not object_editor.has_method("handle_input") or not ground_brush.has_method("handle_input") or not terrain_renderer.has_method("finalize") or not terrain_panel.has_signal("mode_requested"):
		return {"ok": false, "error": "Несовместимые части редактора"}
	if not is_instance_valid(object_editor.panel) or not object_editor.panel.has_signal("mode_requested") or not is_instance_valid(object_editor.camera):
		return {"ok": false, "error": "Несовместимые части редактора"}
	if terrain_preview != null and (not terrain_preview.has_method("show_cursor") or not terrain_preview.has_method("clear_preview") or not terrain_preview.has_method("hide_cursor")): return {"ok": false, "error": "Несовместимая подсветка кисти"}
	editor = object_editor
	brush = ground_brush
	ground_panel = terrain_panel
	renderer = terrain_renderer
	ground_preview = terrain_preview
	_persistence = persistence
	_transaction_ready = transaction_ready
	# Replace the single panel handler, not add a second save/mutation handler.
	if editor.panel.action_requested.is_connected(editor.handle_action):
		editor.panel.action_requested.disconnect(editor.handle_action)
	editor.panel.action_requested.connect(handle_action)
	ground_panel.action_requested.connect(handle_action)
	editor.panel.mode_requested.connect(set_mode)
	ground_panel.mode_requested.connect(set_mode)
	brush.status_changed.connect(_status)
	brush.committed.connect(_ground_committed)
	_sync_panels()
	return {"ok": true}

func _status(message: String) -> void:
	if is_instance_valid(editor): editor.panel.set_status(message)
	if is_instance_valid(ground_panel): ground_panel.set_status(message)

func _ready_for_action() -> bool:
	return not _cleanup_blocked and not _recovery_required and _transaction_ready.is_valid() and accepted(_transaction_ready.call())

func _sync_panels() -> void:
	if not is_instance_valid(editor): return
	editor.panel.set_active(editor.active and mode == "objects")
	ground_panel.set_active(editor.active and mode == "ground")
	brush.set_active(editor.active and mode == "ground" and _ready_for_action())
	if is_instance_valid(ground_preview) and (not editor.active or mode != "ground" or not _ready_for_action()): ground_preview.clear_preview()
	if mode == "ground" or not editor.active: editor.outline.visible = false
	elif not editor.selected_id.is_empty(): editor.outline.show_bounds(editor.registry.world_bounds(editor.selected_id))

func set_mode(value: String) -> Dictionary:
	if editor == null or not editor.active: return {"ok": false, "error": "Откройте редактор клавишей K"}
	if value not in ["objects", "ground"]: return {"ok": false, "error": "Неизвестный режим редактора"}
	if not _ready_for_action(): return {"ok": false, "error": "Сначала завершите обновление карты"}
	brush.cancel_preview()
	if is_instance_valid(ground_preview): ground_preview.clear_preview()
	editor.camera.clear_motion()
	editor._right_pressed = false
	mode = value
	_sync_panels()
	_status("Объекты: ЛКМ — выбор, короткий ПКМ — удаление" if mode == "objects" else "Земля: выберите покрытие и проведите кистью с зажатой ЛКМ")
	return {"ok": true}

func _ground_committed(_result: Dictionary) -> void:
	var result: Dictionary = renderer.finalize(true)
	_cleanup_blocked = not result.get("ok", false)
	if _cleanup_blocked:
		brush.set_active(false)
		_status(str(result.get("error", "Обновление земли ещё не завершено. Игра остаётся остановленной.")))

func retry_finalize() -> Dictionary:
	if _recovery_required: return {"ok": false, "error": "Сначала владелец должен восстановить игровую сцену"}
	if not _cleanup_blocked: return {"ok": true}
	var result: Dictionary = renderer.finalize(true)
	_cleanup_blocked = not result.get("ok", false)
	_sync_panels()
	return result

func restore_session(owner_restore: Callable) -> Dictionary:
	if editor == null or not editor.active or not owner_restore.is_valid(): return {"ok": false, "error": "Восстановление требует остановленной сессии и владельца сцены"}
	if not accepted(owner_restore.call()): return {"ok": false, "error": "Восстановление сцены не подтверждено"}
	if not accepted(_transaction_ready.call()): return {"ok": false, "error": "Сцена ещё не готова"}
	_recovery_required = false
	_cleanup_blocked = false
	_sync_panels()
	return {"ok": true}

func handle_action(action: String, payload: Dictionary = {}) -> Dictionary:
	if editor == null or not editor.active: return {"ok": false, "error": "Откройте редактор клавишей K"}
	if action == "retry_pending":
		if _recovery_required: return {"ok": false, "error": "Нужно восстановление сцены её владельцем"}
		if _cleanup_blocked:
			var cleanup := retry_finalize()
			if not cleanup.ok: return cleanup
		var retried: Variant = _persistence.call(action, payload)
		var retry_result: Dictionary = retried if retried is Dictionary else {"ok": false, "error": "Владелец не подтвердил повтор завершения"}
		_sync_panels()
		if retry_result.get("ok", false) and not _ready_for_action(): retry_result = {"ok": false, "error": "Владелец ещё не подтвердил готовность игровой сцены"}
		_status("Откат карты завершён" if retry_result.get("rolled_back", false) else ("Обновление завершено" if retry_result.get("ok", false) else str(retry_result.get("error", "Обновление ещё удерживается"))))
		return retry_result
	if not _ready_for_action():
		_status("Обновление карты не завершено. Новые действия пока запрещены.")
		return {"ok": false, "error": "Транзакция карты не завершена"}
	var result: Dictionary
	match action:
		"save", "load", "import", "export":
			brush.cancel_preview()
			var value: Variant = _persistence.call(action, payload)
			result = value if value is Dictionary else {"ok": false, "error": "Владелец не подтвердил работу с файлом карты"}
		"ground_tile": result = brush.set_selected_tile(int(payload.get("tile", -1)))
		"ground_layer": result = brush.set_named_layer(str(payload.get("layer", "invalid")))
		"ground_radius": result = brush.set_radius(int(payload.get("radius", 0)))
		"ground_undo": result = brush.undo()
		"ground_redo": result = brush.redo()
		_: result = editor.handle_action(action, payload)
	if action in ["ground_undo", "ground_redo"] and not brush.active and not _cleanup_blocked: _recovery_required = true
	if _cleanup_blocked and result.get("ok", false): result = {"ok": false, "committed": true, "retry_finalize": true, "error": "Изменение сохранено, но освобождение ресурсов ещё не завершено"}
	if not result.get("ok", false): _status(str(result.get("error", "Действие не выполнено")))
	_sync_panels()
	return result

func handle_input(event: InputEvent) -> bool:
	if editor == null: return false
	var toggle: bool = event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_K or event.physical_keycode == KEY_K)
	if toggle:
		if editor.active:
			if mode == "ground" and ground_panel.is_text_focused(): return false
			if not _ready_for_action():
				_status("K: игра остаётся остановленной, пока обновление карты не завершено.")
				return true
			brush.cancel_preview()
		var handled: bool = editor.handle_input(event)
		_sync_panels()
		return handled
	if not editor.active: return false
	if not _ready_for_action():
		editor.camera.clear_motion()
		return true
	if mode == "objects": return editor.handle_input(event)
	var guarded: Dictionary = ground_panel.input_guard(event)
	var painted: bool = brush.handle_input(event, editor.camera, ground_panel.input_guard)
	if is_instance_valid(ground_preview) and (event is InputEventMouseMotion or event is InputEventMouseButton):
		if guarded.text_focused or guarded.pointer_over_panel or not brush.active:
			ground_preview.hide_cursor()
		else:
			var picked: Dictionary = brush.pick_screen(event.position, editor.camera)
			if picked.ok: ground_preview.show_cursor(picked.row, picked.col, brush.radius)
			else: ground_preview.hide_cursor()
	if not brush.active and not _cleanup_blocked:
		_recovery_required = true
		_status("Откат не подтверждён. Владелец должен восстановить сцену; игра остаётся остановленной.")
	if guarded.text_focused or guarded.pointer_over_panel:
		editor.camera.clear_motion()
		return false # Native GUI owns it; main still gates gameplay.
	if painted: return true
	# Ground mode never forwards RMB clicks to object deletion/picking.
	editor.camera.input_handle(event)
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and brush != null:
		brush.focus_lost()
		if is_instance_valid(ground_preview): ground_preview.clear_preview()
		if is_instance_valid(editor): editor.camera.clear_motion()
