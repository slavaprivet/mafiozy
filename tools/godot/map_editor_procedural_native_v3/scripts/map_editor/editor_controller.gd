extends Node
## Explicit edit/play lease supplied by the gameplay owner. Never pauses the
## whole SceneTree; host must stop input/physics/navigation and rebuild on exit.
const Document = preload("res://scripts/map_editor/map_document.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
const EditorCamera = preload("res://scripts/map_editor/editor_camera.gd")
const EditorPanel = preload("res://scripts/map_editor/editor_panel.gd")
const MapPatch = preload("res://scripts/map_editor/map_patch.gd")
const SelectionOutline = preload("res://scripts/map_editor/selection_outline.gd")
const TrustedJSON = preload("res://scripts/map_editor/trusted_json.gd")
var document := Document.new()
var registry: RefCounted
var camera: Camera3D
var panel: CanvasLayer
var outline: MeshInstance3D
var game_camera: Camera3D
var active := false
var atomic_install_active := false
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
	if registry != null or index == null or not index.has_method("apply_document") or not begin_edit.is_valid() or not end_edit.is_valid() or not is_instance_valid(player_camera):
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
	outline = SelectionOutline.new()
	add_child(outline)
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
	outline.show_bounds(registry.world_bounds(selected_id))
	panel.set_status("Режим редактирования. Игра остановлена владельцем сцены.")
	set_process(true)
	return {"ok": true}

func exit_editor() -> Dictionary:
	if atomic_install_active: return {"ok": false, "error": "Общая загрузка ещё удерживает остановленную сессию"}
	if not active:
		return {"ok": true}
	# Owner invalidates old source geometry receipts and rebuilds physics/nav.
	var result: Variant = _end_gate.call(document.to_dictionary())
	if not result is Dictionary or not result.get("ok", false):
		panel.set_status("Игра ещё не возобновлена: требуется обновить коллизии и маршруты.")
		return {"ok": false, "error": "Play session rebuild failed"}
	camera.deactivate_to(game_camera)
	panel.set_active(false)
	outline.visible = false
	active = false
	_right_pressed = false
	set_process(false)
	return {"ok": true}

func _process(delta: float) -> void:
	if active and not atomic_install_active:
		camera.process_motion(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(camera):
		camera.clear_motion()
		_right_pressed = false

## Main's input owner calls this FIRST, before player/transport E/W/mouse.
func handle_input(event: InputEvent) -> bool:
	if atomic_install_active: return true
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
	outline.show_bounds(registry.world_bounds(selected_id))
	return selected_id

func _preview_record_action(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"delete":
			if not document.has_record(selected_id): return {"ok": false, "error": "Выберите объект на карте"}
			return {"ok": true, "id": selected_id, "record": null, "changes": {}, "model_action": "delete"}
		"rotate", "move":
			var record: Dictionary = document.get_record(selected_id)
			if record.is_empty(): return {"ok": false, "error": "Выберите объект на карте"}
			var transform_data: Dictionary = record.transform.duplicate(true)
			if action == "rotate":
				var degrees: Variant = payload.get("degrees", 15.0)
				if not (degrees is float or degrees is int) or not is_finite(float(degrees)): return {"ok": false, "error": "Поворот должен быть числом"}
				transform_data.rotation[1] += deg_to_rad(float(degrees))
			else:
				var delta: Variant = payload.get("delta", [0, 0, 0])
				if not delta is Array or delta.size() != 3: return {"ok": false, "error": "Неверное перемещение"}
				for component: Variant in delta:
					if not (component is float or component is int) or not is_finite(float(component)):
						return {"ok": false, "error": "Координаты должны быть числами"}
				for axis in range(3): transform_data.position[axis] += float(delta[axis])
			var changes := {"transform": transform_data}
			var result: Dictionary = document.preview_update_record(selected_id, changes)
			if result.ok:
				result.changes = changes
				result.model_action = "update"
			return result
	return {"ok": false, "error": "Действие ещё не подключено: " + action}

func _apply_record_preview(preview: Dictionary) -> Dictionary:
	if not preview.ok: return preview
	var id: String = preview.id
	var candidate: Variant = preview.record
	var preflight: Dictionary = registry.apply_record(id, candidate, true)
	if not preflight.ok: return preflight
	# No change signal between document mutation and scene apply; a failed second
	# preflight restores exactly the old record/order/history, not a new action.
	return document.transact_record_action(preview.model_action, id, preview.get("changes", {}), func(): return registry.apply_record(id, candidate))

func handle_action(action: String, payload: Dictionary = {}) -> Dictionary:
	if atomic_install_active: return {"ok": false, "error": "Общая загрузка карты ещё не завершена"}
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
			var template_id: String = str(payload.get("catalog_id", ""))
			var source_frame: Transform3D = registry.template_frame(template_id)
			var point: Vector3 = camera.global_position + -camera.global_basis.z * 12.0
			point.y = source_frame.origin.y
			result = registry.create_copy(template_id, id, Transform3D(source_frame.basis, point))
			if result.ok:
				result = document.add_record(result.record)
				if result.ok: selected_id = id
				else: registry.discard_copy(id)
		"export":
			result = Store.export_json(document)
			if result.ok: DisplayServer.clipboard_set(result.text)
		"load", "import":
			result = Store.load_document(_save_path) if action == "load" else Store.import_json(DisplayServer.clipboard_get())
			if result.ok: result = install_document(result.document)
		"undo", "redo":
			result = document.peek_undo_operation() if action == "undo" else document.peek_redo_operation()
			if result.ok:
				result.model_action = action
				result = _apply_record_preview(result)
		_:
			result = _apply_record_preview(_preview_record_action(action, payload))
	panel.set_status("Готово: " + action if result.ok else str(result.get("error", "Ошибка")))
	panel.set_selection(document.get_record(selected_id))
	outline.show_bounds(registry.world_bounds(selected_id))
	return result

func begin_atomic_install() -> Dictionary:
	if not active or atomic_install_active: return {"ok": false, "error": "Нет свободной остановленной сессии редактора"}
	atomic_install_active = true
	camera.clear_motion()
	return {"ok": true}

func end_atomic_install() -> void:
	atomic_install_active = false

func prepare_install_document(source: Dictionary) -> Dictionary:
	if not active:
		return {"ok": false, "error": "Изменение карты требует edit/play gate"}
	var checked: Dictionary = Document.validate_document(source)
	if not checked.ok: return checked
	if checked.document.map_id != _baseline.map_id or not _json_equal(_baseline.get("metadata", {}), checked.document.get("metadata", {})):
		return {"ok": false, "error": "Карта относится к другой исходной версии"}
	# Imported JSON may edit transforms, not replace trusted source/model/authority.
	var originals: Dictionary = {}
	var transform_extras: Dictionary = {}
	for baseline_row: Dictionary in _baseline.objects:
		var trusted := baseline_row.duplicate(true)
		trusted.erase("transform")
		originals[baseline_row.id] = trusted
		var extra: Dictionary = baseline_row.transform.duplicate(true)
		for key in ["position", "rotation", "scale"]: extra.erase(key)
		transform_extras[baseline_row.id] = extra
	for row: Dictionary in checked.document.objects:
		var supplied := row.duplicate(true)
		supplied.erase("transform")
		var expected: Dictionary
		var source_template: String = row.id
		if originals.has(row.id):
			expected = originals[row.id]
		else:
			var template_id: String = str(row.get("template_id", ""))
			source_template = template_id
			if not row.id.begins_with("editor:") or not originals.has(template_id) or not registry.is_editable(template_id):
				return {"ok": false, "error": "Неизвестный или защищённый шаблон"}
			expected = originals[template_id].duplicate(true)
			expected.id = row.id
			expected["template_id"] = template_id
		if not _json_equal(expected, supplied): return {"ok": false, "error": "Нельзя подменить исходные данные объекта"}
		var supplied_extra: Dictionary = row.transform.duplicate(true)
		for key in ["position", "rotation", "scale"]: supplied_extra.erase(key)
		if not _json_equal(transform_extras[source_template], supplied_extra): return {"ok": false, "error": "Нельзя подменить исходные параметры преобразования"}
		# Admission does not let a file replace source data, even by transport
		# rounding. Keep the exact trusted descriptor across repeated save cycles.
		var supplied_transform: Dictionary = transform_extras[source_template].duplicate(true)
		for key in ["position", "rotation", "scale"]: supplied_transform[key] = row.transform[key]
		row.clear()
		row.merge(expected.duplicate(true))
		row["transform"] = supplied_transform
	checked.document["metadata"] = _baseline.get("metadata", {}).duplicate(true)
	return checked

func install_document(source: Dictionary) -> Dictionary:
	if atomic_install_active: return {"ok": false, "error": "Общая транзакция уже удерживает карту"}
	var checked := prepare_install_document(source)
	if not checked.ok: return checked
	var created: Array[String] = []
	for row: Dictionary in checked.document.objects:
		if registry.has_object(row.id): continue
		var frame: Variant = registry.decode_transform(row.transform)
		if frame == null:
			for id: String in created: registry.discard_copy(id)
			return {"ok": false, "error": "Неверный масштаб объекта"}
		var creation: Dictionary = registry.create_copy(row.template_id, row.id, frame)
		if not creation.ok:
			for id: String in created: registry.discard_copy(id)
			return creation
		created.append(row.id)
	var result: Dictionary = registry.apply_document(checked.document, true)
	if not result.ok:
		for id: String in created: registry.discard_copy(id)
		return result
	# The real registry repeats its complete preflight before any mutation.
	# Do not replace the model/history or notify UI before this succeeds: scene
	# dependencies may have changed after the earlier dry-run admission.
	result = registry.apply_document(checked.document)
	if not result.ok:
		for id: String in created: registry.discard_copy(id)
		return result
	# checked.document is detached and already validated; no callback can change
	# it before this synchronous replacement. Observers now see scene + data agree.
	return document.load_document(checked.document)

static func _json_equal(a: Variant, b: Variant) -> bool:
	return TrustedJSON.matches(a, b)

func get_versioned_patch() -> Dictionary:
	return MapPatch.derive_patch(_baseline, document.to_dictionary())

func install_versioned_patch(patch: Dictionary) -> Dictionary:
	if not active: return {"ok": false, "error": "Откройте редактор клавишей K"}
	var expanded: Dictionary = MapPatch.apply_patch(_baseline, patch)
	if not expanded.ok: return expanded
	return install_document(expanded.document)
