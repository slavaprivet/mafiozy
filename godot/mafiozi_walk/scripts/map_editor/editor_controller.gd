extends Node
## Explicit edit/play lease supplied by the gameplay owner. Never pauses the
## whole SceneTree; host must stop input/physics/navigation and rebuild on exit.
const Document = preload("res://scripts/map_editor/map_document.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
const EditorCamera = preload("res://scripts/map_editor/editor_camera.gd")
const EditorPanel = preload("res://scripts/map_editor/editor_panel.gd")
var document := Document.new()
var registry: RefCounted
var camera: Camera3D
var panel: CanvasLayer
var game_camera: Camera3D
var active := false
var selected_id := ""
var _begin_gate: Callable
var _end_gate: Callable
var _baseline: Dictionary
var _right_start: Vector2
var _right_moved := 0.0
var _right_time := 0
var _right_pressed := false
var _save_path := "user://maps/current.json"

func setup(index: RefCounted, source: Dictionary, player_camera: Camera3D, begin_edit: Callable, end_edit: Callable, catalogue: Array = []) -> Dictionary:
	if registry != null or not begin_edit.is_valid() or not end_edit.is_valid() or not is_instance_valid(player_camera):
		return {"ok": false, "error": "Редактор требует edit/play gate владельца сцены"}
	var loaded: Dictionary = document.load_document(source)
	if not loaded.ok:
		return loaded
	registry = index
	_baseline = source.duplicate(true)
	game_camera = player_camera
	_begin_gate = begin_edit
	_end_gate = end_edit
	camera = EditorCamera.new()
	add_child(camera)
	panel = EditorPanel.new()
	add_child(panel)
	panel.set_catalog(catalogue)
	panel.action_requested.connect(handle_action)
	set_process(false)
	return {"ok": true}

func enter_editor() -> Dictionary:
	if active:
		return {"ok": true}
	if registry == null:
		return {"ok": false, "error": "Редактор не подключён"}
	var result: Variant = _begin_gate.call()
	if not result is Dictionary or not result.get("ok", false):
		return {"ok": false, "error": "Не удалось остановить игровую сессию"}
	active = true
	camera.activate_from(game_camera)
	panel.set_active(true)
	panel.set_status("Режим редактирования. Игра остановлена владельцем сцены.")
	set_process(true)
	return {"ok": true}

func exit_editor() -> Dictionary:
	if not active:
		return {"ok": true}
	# Owner invalidates old source geometry receipts and rebuilds physics/nav.
	var result: Variant = _end_gate.call(document.to_dictionary())
	if not result is Dictionary or not result.get("ok", false):
		panel.set_status("Игра ещё не возобновлена: требуется обновить коллизии и маршруты.")
		return {"ok": false, "error": "Play session rebuild failed"}
	camera.deactivate_to(game_camera)
	panel.set_active(false)
	active = false
	_right_pressed = false
	set_process(false)
	return {"ok": true}

func _process(delta: float) -> void:
	if active:
		camera.process_motion(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(camera):
		camera.clear_motion()
		_right_pressed = false

## Main's input owner calls this FIRST, before player/transport E/W/mouse.
func handle_input(event: InputEvent) -> bool:
	if registry == null:
		return false
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_K or event.keycode == KEY_K):
		if active and panel.is_text_focused():
			return false
		var result := exit_editor() if active else enter_editor()
		if not result.ok and is_instance_valid(panel): panel.set_status(str(result.error))
		return true
	if not active:
		return false
	if panel.is_text_focused():
		camera.clear_motion()
		return false # Text input belongs to Control; gameplay remains gated.
	if event is InputEventMouse and panel.is_pointer_over_panel(event.position):
		camera.clear_motion()
		_right_pressed = false
		return false
	camera.input_handle(event)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_at(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_start = event.position
				_right_moved = 0.0
				_right_time = Time.get_ticks_msec()
				_right_pressed = true
			elif _right_pressed:
				_right_pressed = false
				if _right_moved <= 4.0 and event.position.distance_to(_right_start) <= 4.0 and Time.get_ticks_msec() - _right_time <= 500:
					select_at(event.position)
					handle_action("delete", {})
	if event is InputEventMouseMotion and _right_pressed:
		_right_moved += event.relative.length()
	return true

func select_at(position: Vector2) -> String:
	selected_id = registry.pick(camera.project_ray_origin(position), camera.project_ray_normal(position))
	panel.set_selection(document.get_record(selected_id))
	return selected_id

func _candidate_action(action: String, payload: Dictionary, model: RefCounted) -> Dictionary:
	match action:
		"delete": return model.delete_record(selected_id)
		"rotate", "move":
			var record: Dictionary = model.get_record(selected_id)
			if record.is_empty(): return {"ok": false, "error": "Выберите объект на карте"}
			var transform_data: Dictionary = record.transform.duplicate(true)
			if action == "rotate":
				transform_data.rotation[1] += deg_to_rad(float(payload.get("degrees", 15.0)))
			else:
				var delta: Variant = payload.get("delta", [0, 0, 0])
				if not delta is Array or delta.size() != 3: return {"ok": false, "error": "Неверное перемещение"}
				for axis in range(3): transform_data.position[axis] += float(delta[axis])
			return model.update_record(selected_id, {"transform": transform_data})
	return {"ok": false, "error": "Действие ещё не подключено: " + action}

func handle_action(action: String, payload: Dictionary = {}) -> Dictionary:
	if not active:
		return {"ok": false, "error": "Откройте редактор клавишей K"}
	var result: Dictionary
	match action:
		"camera_top", "camera_fly":
			camera.set_view("top" if action == "camera_top" else "fly")
			return {"ok": true}
		"save": result = Store.save_document(document, _save_path)
		"add":
			var id := "editor:" + str(Time.get_ticks_usec()) + "-" + str(get_instance_id())
			var point: Vector3 = camera.global_position + -camera.global_basis.z * 12.0
			point.y = 0.0
			result = registry.create_copy(str(payload.get("catalog_id", "")), id, Transform3D(Basis.IDENTITY, point))
			if result.ok:
				result = document.add_record(result.record)
				if result.ok: selected_id = id
		"export":
			result = Store.export_json(document)
			if result.ok: DisplayServer.clipboard_set(result.text)
		"load", "import":
			result = Store.load_document(_save_path) if action == "load" else Store.import_json(DisplayServer.clipboard_get())
			if result.ok: result = install_document(result.document)
		"undo", "redo":
			result = document.peek_undo() if action == "undo" else document.peek_redo()
			if result.ok:
				result = registry.apply_document(result.document, true)
				if result.ok:
					result = document.undo() if action == "undo" else document.redo()
					if result.ok: result = registry.apply_document(document.to_dictionary())
		_:
			var candidate := Document.new(0)
			candidate.load_document(document.to_dictionary())
			result = _candidate_action(action, payload, candidate)
			if result.ok: result = registry.apply_document(candidate.to_dictionary(), true)
			if result.ok:
				result = _candidate_action(action, payload, document)
				if result.ok: result = registry.apply_document(document.to_dictionary())
	panel.set_status("Готово: " + action if result.ok else str(result.get("error", "Ошибка")))
	panel.set_selection(document.get_record(selected_id))
	return result

func install_document(source: Dictionary) -> Dictionary:
	var checked: Dictionary = Document.validate_document(source)
	if not checked.ok: return checked
	if checked.document.map_id != _baseline.map_id or checked.document.get("metadata", {}) != _baseline.get("metadata", {}):
		return {"ok": false, "error": "Карта относится к другой исходной версии"}
	# Imported JSON may edit transforms, not replace trusted source/model/authority.
	var originals: Dictionary = {}
	for baseline_row: Dictionary in registry.source_document(_baseline.map_id).objects:
		var trusted := baseline_row.duplicate(true)
		trusted.erase("transform")
		originals[baseline_row.id] = trusted
	for row: Dictionary in checked.document.objects:
		if not originals.has(row.id): return {"ok": false, "error": "Объект ещё не подключён к сцене"}
		var supplied := row.duplicate(true)
		supplied.erase("transform")
		if originals[row.id] != supplied: return {"ok": false, "error": "Нельзя подменить исходные данные объекта"}
	var result: Dictionary = registry.apply_document(checked.document, true)
	if not result.ok: return result
	result = document.load_document(checked.document)
	if result.ok: result = registry.apply_document(document.to_dictionary())
	return result
