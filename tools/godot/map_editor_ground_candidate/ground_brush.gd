extends RefCounted
## Input adapter only; the host owns render preview, physics and navigation.
signal status_changed(message: String)
signal committed(result: Dictionary)
var active := false
var selected_tile := 0
var named_layer := ""
var _use_named_layer := false
var radius := 1
var _document: RefCounted
var _preview_chunks: Callable
var _physical_apply: Callable
var _nav_invalidate: Callable
var _rollback: Callable
var _ground_frame := Transform3D.IDENTITY
var _plane_y := 0.0
var _painting := false
var _painted: Dictionary = {}
var _has_last := false
var _last_cell := Vector2i.ZERO
var _dirty_chunks: Dictionary = {}
var _event_dirty_chunks: Dictionary = {}
var _source_start := Vector2i.ZERO
var _blocked_cells := 0
var _sampled_cells := 0

func setup(document: RefCounted, hooks: Dictionary, ground_frame: Transform3D = Transform3D.IDENTITY, plane_y: float = 0.0) -> Dictionary:
	if document == null or not document.has_method("begin_stroke") or not document.has_method("pick_cell"):
		return {"ok": false, "error": "Кисть требует документ земли"}
	for name in ["preview_chunks", "physical_apply", "nav_invalidate", "rollback"]:
		if not hooks.get(name) is Callable or not hooks[name].is_valid(): return {"ok": false, "error": "Нет обработчика кисти: " + name}
	if not ground_frame.origin.is_finite() or not ground_frame.basis.x.is_finite() or not ground_frame.basis.y.is_finite() or not ground_frame.basis.z.is_finite() or ground_frame.basis.determinant() <= 0.000001 or not is_finite(plane_y):
		return {"ok": false, "error": "Неверная система координат земли"}
	cancel_preview()
	_document = document
	var coordinates: Dictionary = document.coordinate_info()
	_source_start = Vector2i(coordinates.start_col, coordinates.start_row)
	_preview_chunks = hooks.preview_chunks
	_physical_apply = hooks.physical_apply
	_nav_invalidate = hooks.nav_invalidate
	_rollback = hooks.rollback
	_ground_frame = ground_frame
	_plane_y = plane_y
	return {"ok": true}

func set_active(value: bool) -> void:
	if not value: cancel_preview()
	active = value and _document != null

func set_selected_tile(tile: int) -> Dictionary:
	if tile not in [0, 8, 9, 14, 16]: return {"ok": false, "error": "Неизвестная кисть земли"}
	cancel_preview()
	selected_tile = tile
	named_layer = ""
	_use_named_layer = false
	return {"ok": true}

func set_named_layer(layer: String) -> Dictionary:
	if layer not in ["", "dirt", "earth"]: return {"ok": false, "error": "Неизвестный отдельный слой земли"}
	cancel_preview()
	named_layer = layer
	_use_named_layer = true
	return {"ok": true}

func set_radius(value: int) -> Dictionary:
	if value < 1 or value > 8: return {"ok": false, "error": "Размер кисти — от 1 до 8 клеток"}
	cancel_preview()
	radius = value
	return {"ok": true}

func is_painting() -> bool:
	return _painting

func _guarded(event: InputEvent, guard: Callable) -> bool:
	if not guard.is_valid(): return true # Missing UI guard must not paint through UI.
	var state: Variant = guard.call(event)
	if state is bool: return state
	if state is Dictionary: return bool(state.get("text_focused", false)) or bool(state.get("pointer_over_panel", false))
	return true

func pick_screen(position: Vector2, camera: Camera3D) -> Dictionary:
	if _document == null or not is_instance_valid(camera) or not camera.is_inside_tree(): return {"ok": false, "error": "Камера редактора недоступна"}
	var origin: Vector3 = camera.project_ray_origin(position)
	var direction: Vector3 = camera.project_ray_normal(position)
	var normal: Vector3 = _ground_frame.basis.y.normalized()
	var point: Vector3 = _ground_frame * Vector3(0, _plane_y, 0)
	var denominator := normal.dot(direction)
	if not origin.is_finite() or not direction.is_finite() or absf(denominator) < 0.000001: return {"ok": false, "error": "Луч камеры не пересекает землю"}
	var distance := normal.dot(point - origin) / denominator
	if distance < 0.0 or not is_finite(distance): return {"ok": false, "error": "Земля находится за камерой"}
	var local: Vector3 = _ground_frame.affine_inverse() * (origin + direction * distance)
	return _document.pick_cell(Vector2(local.x, local.z))

func _paint_cell(row: int, col: int) -> void:
	var id: String = _document.cell_id(row, col)
	if _painted.has(id): return
	_painted[id] = true
	_sampled_cells += 1
	var result: Dictionary = _document.set_named_layer(row, col, named_layer) if _use_named_layer else _document.set_tile(row, col, selected_tile)
	if not result.ok: _blocked_cells += 1
	else:
		var chunk := Vector2i((col - _source_start.x) / 16, (row - _source_start.y) / 16)
		_dirty_chunks[chunk] = true
		_event_dirty_chunks[chunk] = true

func _paint_center(cell: Vector2i) -> void:
	var reach := radius - 1 # Size 1 paints precisely the pointed cell.
	for offset_row in range(-reach, reach + 1):
		for offset_col in range(-reach, reach + 1):
			if offset_row * offset_row + offset_col * offset_col <= reach * reach:
				_paint_cell(cell.y + offset_row, cell.x + offset_col)

func _paint_line(from: Vector2i, to: Vector2i) -> void:
	# Integer cell line: large pointer events leave no gaps and never scan the grid.
	var cursor := from
	var dx := absi(to.x - cursor.x)
	var dy := -absi(to.y - cursor.y)
	var sx := 1 if cursor.x < to.x else -1
	var sy := 1 if cursor.y < to.y else -1
	var error := dx + dy
	while true:
		_paint_center(cursor)
		if cursor == to: break
		var twice := error * 2
		if twice >= dy:
			error += dy
			cursor.x += sx
		if twice <= dx:
			error += dx
			cursor.y += sy

func _notify_preview(cancelled: bool = false, event_only: bool = false) -> bool:
	var chunks: Array = []
	var dirty: Dictionary = _event_dirty_chunks if event_only else _dirty_chunks
	if dirty.is_empty(): return true
	for chunk: Vector2i in dirty:
		chunks.append(_document.build_chunk(chunk.x, chunk.y, not cancelled))
	var result: Variant = _preview_chunks.call({"dirty_chunks": dirty.keys(), "chunks": chunks, "cancelled": cancelled, "preview": not cancelled})
	return (result is bool and result) or (result is Dictionary and result.get("ok") is bool and result.ok)

func _sample(position: Vector2, camera: Camera3D) -> void:
	_event_dirty_chunks.clear()
	var picked := pick_screen(position, camera)
	if not picked.ok:
		_has_last = false
		status_changed.emit(str(picked.error))
		return
	var cell := Vector2i(picked.col, picked.row)
	if _has_last: _paint_line(_last_cell, cell)
	else: _paint_center(cell)
	_last_cell = cell
	_has_last = true
	if not _notify_preview(false, true):
		cancel_preview()
		status_changed.emit("Предпросмотр земли не принят. Мазок отменён.")
	elif _blocked_cells > 0:
		status_changed.emit("Защищённые участки, мосты и границы пропущены: %d" % _blocked_cells)
	else:
		status_changed.emit("Предпросмотр · отпустите ЛКМ, чтобы применить мазок")

func handle_input(event: InputEvent, camera: Camera3D, panel_rect_guard: Callable) -> bool:
	if not active: return false
	if _guarded(event, panel_rect_guard):
		if _painting: cancel_preview()
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cancel_preview()
			var started: Dictionary = _document.begin_stroke()
			if not started.ok:
				status_changed.emit(str(started.error))
				return true
			_painting = true
			_sample(event.position, camera)
		elif _painting:
			_sample(event.position, camera)
			if not _painting: return true
			var result: Dictionary = _document.commit_stroke(_physical_apply, _nav_invalidate, _rollback)
			if not result.ok:
				cancel_preview()
				if result.has("rollback_ok") and not result.rollback_ok: active = false
				status_changed.emit(str(result.error))
			else:
				_painting = false
				_notify_preview(true)
				status_changed.emit("Мазок применён · изменено клеток: %d" % result.changed_cells)
				_reset_input()
			if not result.get("unchanged", false): committed.emit(result)
		return true
	if event is InputEventMouseMotion and _painting:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_sample(event.position, camera)
		else: cancel_preview()
		return true
	return false

func _reset_input() -> void:
	_painted.clear()
	_dirty_chunks.clear()
	_event_dirty_chunks.clear()
	_has_last = false
	_blocked_cells = 0

func cancel_preview() -> void:
	if _painting and _document != null:
		_document.cancel_stroke()
		if _preview_chunks.is_valid(): _notify_preview(true)
	_painting = false
	_reset_input()

func focus_lost() -> void:
	cancel_preview()

func undo() -> Dictionary:
	if not active: return {"ok": false, "error": "Откройте режим кисти земли"}
	cancel_preview()
	var result: Dictionary = _document.undo(_physical_apply, _nav_invalidate, _rollback)
	if not result.ok and result.has("rollback_ok") and not result.rollback_ok: active = false
	if result.ok:
		for chunk: Vector2i in result.dirty_chunks: _dirty_chunks[chunk] = true
		_notify_preview(true)
		_dirty_chunks.clear()
	status_changed.emit("Мазок отменён" if result.ok else str(result.error))
	if result.ok and not result.get("unchanged", false): committed.emit(result)
	return result

func redo() -> Dictionary:
	if not active: return {"ok": false, "error": "Откройте режим кисти земли"}
	cancel_preview()
	var result: Dictionary = _document.redo(_physical_apply, _nav_invalidate, _rollback)
	if not result.ok and result.has("rollback_ok") and not result.rollback_ok: active = false
	if result.ok:
		for chunk: Vector2i in result.dirty_chunks: _dirty_chunks[chunk] = true
		_notify_preview(true)
		_dirty_chunks.clear()
	status_changed.emit("Мазок повторён" if result.ok else str(result.error))
	if result.ok and not result.get("unchanged", false): committed.emit(result)
	return result

func debug_cost() -> Dictionary:
	return {"sampled_cells": _sampled_cells, "stroke_unique_cells": _painted.size(), "dirty_chunks": _dirty_chunks.size(), "blocked_cells": _blocked_cells}
