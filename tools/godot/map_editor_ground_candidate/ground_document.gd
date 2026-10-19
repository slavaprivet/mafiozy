extends RefCounted
## Sparse native ground edits. Pointer painting costs only touched cells.
## Geometry/material ownership remains at the host; no scene/resource loading.
const VERSION := 1
const CELL_SIZE := 4.1
const CHUNK_SIZE := 16
const PAINT_TILES := [0, 8, 9, 14, 16]
const SOURCE_TILES := [0, 8, 9, 14, 16, 19]
const NAMED_LAYERS := ["dirt", "earth"]
const MASK_NAMES := ["roadMask", "walkableMask", "protectedMask", "policeMask", "bridgeDeckMask"]
const DEFAULT_PALETTE := {"0": {"solid": true, "heightM": 0.0}, "8": {"solid": true, "heightM": 0.0}, "9": {"solid": true, "heightM": 0.0}, "14": {"solid": true, "heightM": 0.0}, "16": {"solid": false, "heightM": -0.18}, "19": {"solid": true, "heightM": 0.0}}
var _source: Dictionary = {}
var _grid: Array = []
var _masks: Dictionary = {}
var _palette: Dictionary = {}
var _origin := Vector3.ZERO
var _start := Vector2i.ZERO # X=source col, Y=source row.
var _size := Vector2i.ZERO
var _baseline_hash := ""
var _tiles: Dictionary = {}
var _layers: Dictionary = {}
var _stroke: Dictionary = {}
var _stroke_active := false
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _history_limit := 100
var _cell_touch_count := 0
var install_guard_active := false

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floor(float(value))

static func _safe_json(value: Variant, depth: int = 0) -> bool:
	if depth > 32: return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not _safe_json(item, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is StringName) or not _safe_json(value[key], depth + 1): return false
			return true
	return false

static func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			var parts: PackedStringArray = []
			for key in keys: parts.append(JSON.stringify(str(key)) + ":" + _canonical(value[key]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for item in value: parts.append(_canonical(item))
			return "[" + ",".join(parts) + "]"
		TYPE_FLOAT:
			if absf(value) <= 9007199254740991.0 and value == floor(value): return str(int(value))
	return JSON.stringify(value, "", true, true)

func setup_baseline(source: Dictionary, origin_m: Vector3 = Vector3.ZERO, history_limit: int = 100) -> Dictionary:
	if not _safe_json(source) or not origin_m.is_finite(): return _failure("Небезопасные исходные данные земли")
	var surface_value: Variant = source.get("surface", source)
	if not surface_value is Dictionary: return _failure("Неверная исходная поверхность")
	var surface: Dictionary = surface_value
	var map_info: Variant = surface.get("map", {})
	if not map_info is Dictionary: return _failure("Неверный размер карты")
	var rows: Variant = surface.get("rows", map_info.get("rows"))
	var cols: Variant = surface.get("cols", map_info.get("cols"))
	var cell_size: Variant = surface.get("cellSize", map_info.get("worldUnitsPerCell"))
	var start_row: Variant = surface.get("startRow", 0)
	var start_col: Variant = surface.get("startCol", 0)
	if not _integer(rows) or not _integer(cols) or rows < 1 or cols < 1 or rows > 4096 or cols > 4096 or rows * cols > 1000000:
		return _failure("Неверные границы сетки земли")
	if not _integer(start_row) or not _integer(start_col) or start_row < 0 or start_col < 0 or start_row + rows > 1000000 or start_col + cols > 1000000:
		return _failure("Неверные исходные координаты сетки")
	if not _number(cell_size) or absf(float(cell_size) - CELL_SIZE) > 0.000000001:
		return _failure("Земля должна сохранять исходный масштаб 4,1 м")
	var grid: Variant = surface.get("grid")
	if not grid is Array or grid.size() != int(rows): return _failure("Неверная сетка земли")
	for row in grid:
		if not row is Array or row.size() != int(cols): return _failure("Неверная строка земли")
		for tile in row:
			if not _integer(tile) or int(tile) not in SOURCE_TILES: return _failure("Неизвестный исходный тип земли")
	var source_masks: Variant = surface.get("masks", surface)
	if not source_masks is Dictionary: return _failure("Неверные исходные маски")
	var validated_masks := {}
	for name in MASK_NAMES:
		var mask: Variant = source_masks.get(name)
		if not mask is Array or mask.size() != int(rows): return _failure("Отсутствует исходная маска: " + name)
		for row in mask:
			if not row is Array or row.size() != int(cols): return _failure("Неверная строка маски: " + name)
			for flag in row:
				if not (flag is bool or (_number(flag) and (flag == 0 or flag == 1))): return _failure("Неверное значение маски: " + name)
		validated_masks[name] = mask.duplicate(true)
	var palette: Variant = surface.get("palette", DEFAULT_PALETTE)
	if not palette is Dictionary: return _failure("Неверная палитра земли")
	for tile in SOURCE_TILES:
		var definition: Variant = palette.get(str(tile))
		if not definition is Dictionary or not definition.get("solid") is bool or not _number(definition.get("heightM")):
			return _failure("Неверная исходная палитра типа " + str(tile))
		if int(tile) == 16 and definition.solid: return _failure("Вода не может иметь пол земли")
	_source = source.duplicate(true)
	_grid = grid.duplicate(true)
	_masks = validated_masks
	_palette = palette.duplicate(true)
	_origin = origin_m
	_start = Vector2i(int(start_col), int(start_row))
	_size = Vector2i(int(cols), int(rows))
	_baseline_hash = _canonical({"source": _source, "origin_m": [_origin.x, _origin.y, _origin.z]}).sha256_text()
	_tiles.clear()
	_layers.clear()
	_stroke.clear()
	_stroke_active = false
	_undo.clear()
	_redo.clear()
	_history_limit = clampi(history_limit, 0, 1000)
	_cell_touch_count = 0
	return {"ok": true, "rows": _size.y, "cols": _size.x, "baseline_sha256": _baseline_hash}

func original_source() -> Dictionary:
	return _source.duplicate(true)

func dimensions() -> Vector2i:
	return _size

func coordinate_info() -> Dictionary:
	return {"start_row": _start.y, "start_col": _start.x, "rows": _size.y, "cols": _size.x, "cell_size": CELL_SIZE, "origin_m": _origin}

func surface_palette() -> Dictionary:
	return _palette.duplicate(true)

static func cell_id(row: int, col: int) -> String:
	return "cell:%d:%d" % [row, col]

func contains_cell(row: int, col: int) -> bool:
	return row >= _start.y and col >= _start.x and row < _start.y + _size.y and col < _start.x + _size.x

func pick_cell(world_xz: Vector2) -> Dictionary:
	if not world_xz.is_finite() or _grid.is_empty(): return _failure("Неверные координаты земли")
	var source_xz := world_xz + Vector2(_origin.x, _origin.z)
	var source_col: float = float(source_xz.x) / CELL_SIZE
	var source_row: float = float(source_xz.y) / CELL_SIZE
	# Native Vector2/3 are float32. Snap representational boundary noise only.
	if absf(source_col - round(source_col)) < 0.00001: source_col = round(source_col)
	if absf(source_row - round(source_row)) < 0.00001: source_row = round(source_row)
	if source_col < _start.x or source_row < _start.y or source_col >= _start.x + _size.x or source_row >= _start.y + _size.y:
		return _failure("Курсор за пределами исходной карты")
	var row: int = int(floor(source_row))
	var col: int = int(floor(source_col))
	if not contains_cell(row, col): return _failure("Курсор за пределами исходной карты")
	return {"ok": true, "row": row, "col": col, "id": cell_id(row, col)}

func _baseline_tile(row: int, col: int) -> int:
	return int(_grid[row - _start.y][col - _start.x])

func is_editable(row: int, col: int) -> bool:
	if not contains_cell(row, col): return false
	for name in ["protectedMask", "policeMask", "bridgeDeckMask"]:
		if bool(_masks[name][row - _start.y][col - _start.x]): return false
	return _baseline_tile(row, col) != 19

func cell_state(row: int, col: int, include_pending: bool = true) -> Dictionary:
	if not contains_cell(row, col): return {}
	var id := cell_id(row, col)
	if include_pending and _stroke.has(id): return _stroke[id].after.duplicate(true)
	return {"row": row, "col": col, "id": id, "tile": int(_tiles.get(id, _baseline_tile(row, col))), "layer": str(_layers.get(id, ""))}

func begin_stroke() -> Dictionary:
	if install_guard_active: return _failure("Общая загрузка удерживает землю")
	if _grid.is_empty(): return _failure("Исходная земля не загружена")
	if _stroke_active: return _failure("Закончите предыдущий мазок")
	_stroke.clear()
	_stroke_active = true
	return {"ok": true}

func _touch(row: int, col: int) -> Dictionary:
	if install_guard_active: return _failure("Общая загрузка удерживает землю")
	if not _stroke_active: return _failure("Сначала начните мазок")
	if not is_editable(row, col): return _failure("Ячейка защищена или находится за пределами карты")
	var id := cell_id(row, col)
	if not _stroke.has(id):
		var before := cell_state(row, col, false)
		_stroke[id] = {"before": before, "after": before.duplicate(true)}
	_cell_touch_count += 1
	return {"ok": true, "id": id}

func set_tile(row: int, col: int, tile: int) -> Dictionary:
	if tile not in PAINT_TILES: return _failure("Неизвестная кисть земли")
	var touched := _touch(row, col)
	if not touched.ok: return touched
	_stroke[touched.id].after.tile = tile
	if tile == 16: _stroke[touched.id].after.layer = ""
	return {"ok": true, "id": touched.id}

func set_named_layer(row: int, col: int, layer: String) -> Dictionary:
	if not layer.is_empty() and layer not in NAMED_LAYERS: return _failure("Неизвестный дополнительный слой")
	if not contains_cell(row, col) or (not layer.is_empty() and cell_state(row, col).tile == 16):
		return _failure("Земля и просёлок не подменяют воду")
	var touched := _touch(row, col)
	if not touched.ok: return touched
	_stroke[touched.id].after.layer = layer
	return {"ok": true, "id": touched.id}

func cancel_stroke() -> void:
	if install_guard_active: return
	_stroke.clear()
	_stroke_active = false

func _delta(changes: Dictionary, backwards: bool = false) -> Dictionary:
	var cells: Array = []
	var rows := {}
	var chunks := {}
	var desired := {}
	for id in changes:
		var before: Dictionary = changes[id].after if backwards else changes[id].before
		var after: Dictionary = changes[id].before if backwards else changes[id].after
		if before == after: continue
		cells.append({"before": before.duplicate(true), "after": after.duplicate(true)})
		desired[id] = after
		rows[int(after.row)] = true
		chunks[Vector2i((int(after.col) - _start.x) / CHUNK_SIZE, (int(after.row) - _start.y) / CHUNK_SIZE)] = true
	var physical_rows: Array = []
	for row in rows: physical_rows.append({"row": row, "strips": _row_strips(int(row), desired)})
	return {"ok": true, "cells": cells, "dirty_rows": rows.keys(), "dirty_chunks": chunks.keys(), "physical_rows": physical_rows, "desired": desired}

func prepare_stroke() -> Dictionary:
	if not _stroke_active: return _failure("Нет активного мазка")
	return _delta(_stroke)

static func _hook_ok(result: Variant) -> bool:
	return (result is bool and result) or (result is Dictionary and result.get("ok") is bool and result.ok)

static func _rolled_back(rollback: Callable, delta: Dictionary, message: String) -> Dictionary:
	var result := _failure(message)
	result.rollback_ok = _hook_ok(rollback.call(delta.duplicate(true)))
	if not result.rollback_ok: result.error += ". Физический откат не подтверждён; хозяин сцены должен остановить редактор."
	return result

func _apply_transaction(changes: Dictionary, backwards: bool, physical_apply: Callable, nav_invalidate: Callable, physical_rollback: Callable) -> Dictionary:
	var delta := _delta(changes, backwards)
	if delta.cells.is_empty(): return {"ok": true, "unchanged": true, "changed_cells": 0}
	if not physical_apply.is_valid() or not nav_invalidate.is_valid() or not physical_rollback.is_valid():
		return _failure("Нужны обработчики физики, навигации и отката")
	if not _hook_ok(physical_apply.call(delta.duplicate(true))):
		return _rolled_back(physical_rollback, delta, "Обновление физических полос не принято")
	if not _hook_ok(nav_invalidate.call(delta.duplicate(true))):
		return _rolled_back(physical_rollback, delta, "Навигация не подтвердила изменение земли")
	for cell: Dictionary in delta.cells:
		var after: Dictionary = cell.after
		if int(after.tile) == _baseline_tile(after.row, after.col): _tiles.erase(after.id)
		else: _tiles[after.id] = int(after.tile)
		if str(after.layer).is_empty(): _layers.erase(after.id)
		else: _layers[after.id] = str(after.layer)
	return {"ok": true, "changed_cells": delta.cells.size(), "dirty_chunks": delta.dirty_chunks, "dirty_rows": delta.dirty_rows}

func commit_stroke(physical_apply: Callable, nav_invalidate: Callable, physical_rollback: Callable) -> Dictionary:
	if install_guard_active: return _failure("Общая загрузка удерживает землю")
	if not _stroke_active: return _failure("Нет активного мазка")
	var result := _apply_transaction(_stroke, false, physical_apply, nav_invalidate, physical_rollback)
	if not result.ok: return result
	if not result.get("unchanged", false):
		if _history_limit > 0:
			_undo.append(_stroke.duplicate(true))
			if _undo.size() > _history_limit: _undo.pop_front()
		_redo.clear()
	cancel_stroke()
	return result

func undo(physical_apply: Callable, nav_invalidate: Callable, physical_rollback: Callable) -> Dictionary:
	if install_guard_active: return _failure("Общая загрузка удерживает землю")
	if _stroke_active or _undo.is_empty(): return _failure("Отмена недоступна")
	var result := _apply_transaction(_undo.back(), true, physical_apply, nav_invalidate, physical_rollback)
	if result.ok: _redo.append(_undo.pop_back())
	return result

func redo(physical_apply: Callable, nav_invalidate: Callable, physical_rollback: Callable) -> Dictionary:
	if install_guard_active: return _failure("Общая загрузка удерживает землю")
	if _stroke_active or _redo.is_empty(): return _failure("Повтор недоступен")
	var result := _apply_transaction(_redo.back(), false, physical_apply, nav_invalidate, physical_rollback)
	if result.ok: _undo.append(_redo.pop_back())
	return result

func _state_with(row: int, col: int, desired: Dictionary) -> Dictionary:
	var id := cell_id(row, col)
	return desired[id] if desired.has(id) else cell_state(row, col, false)

func _row_strips(row: int, desired: Dictionary = {}) -> Array:
	var result: Array = []
	var col := _start.x
	while col < _start.x + _size.x:
		var state := _state_with(row, col, desired)
		var tile: int = state.tile
		var definition: Dictionary = _palette[str(tile)]
		if not definition.solid:
			col += 1
			continue
		var first := col
		while col < _start.x + _size.x and _state_with(row, col, desired).tile == tile: col += 1
		result.append({"id": "strip:%d:%d:%d" % [row, first, col], "row": row, "first_col": first, "end_col": col, "tile": tile,
			"size": Vector3((col - first) * CELL_SIZE, 0.16, CELL_SIZE),
			"position": Vector3((first + col) * 0.5 * CELL_SIZE - _origin.x, float(definition.heightM) - 0.08, (row + 0.5) * CELL_SIZE - _origin.z)})
	return result

func row_strips(row: int) -> Dictionary:
	if row < _start.y or row >= _start.y + _size.y: return _failure("Неизвестная физическая строка земли")
	return {"ok": true, "row": row, "strips": _row_strips(row)}

func preview_chunk_cells(chunk_col: int, chunk_row: int) -> Dictionary:
	# Editor-only descriptors: bounded one-chunk scan, no physics/nav staging.
	var first_col := _start.x + chunk_col * CHUNK_SIZE
	var first_row := _start.y + chunk_row * CHUNK_SIZE
	if chunk_col < 0 or chunk_row < 0 or not contains_cell(first_row, first_col): return _failure("Неизвестный чанк подсветки")
	var cells: Array = []
	for row in range(first_row, mini(first_row + CHUNK_SIZE, _start.y + _size.y)):
		for col in range(first_col, mini(first_col + CHUNK_SIZE, _start.x + _size.x)):
			var id := cell_id(row, col)
			if _stroke.has(id) and _stroke[id].before != _stroke[id].after: cells.append(_stroke[id].after.duplicate(true))
	return {"ok": true, "chunk": Vector2i(chunk_col, chunk_row), "cells": cells}

func build_chunk(chunk_col: int, chunk_row: int, include_pending: bool = false) -> Dictionary:
	return _build_chunk_plan(chunk_col, chunk_row, include_pending, {})

func build_chunk_delta(chunk_col: int, chunk_row: int, desired: Dictionary) -> Dictionary:
	# Desired states are explicit after-records from prepare_stroke/undo/import.
	# No active stroke is required and the immutable source is never modified.
	for id in desired:
		var state: Variant = desired[id]
		if not state is Dictionary or not _exact_keys(state, ["row", "col", "id", "tile", "layer"]) or not _integer(state.row) or not _integer(state.col) or not _integer(state.tile):
			return _failure("Неверное желаемое состояние земли")
		if state.row < _start.y or state.col < _start.x or state.row >= _start.y + _size.y or state.col >= _start.x + _size.x:
			return _failure("Желаемая ячейка земли за пределами карты")
		if id != cell_id(state.row, state.col) or state.id != id or int(state.tile) not in SOURCE_TILES or not state.layer is String or (not state.layer.is_empty() and state.layer not in NAMED_LAYERS) or (state.tile == 16 and not state.layer.is_empty()):
			return _failure("Неверный тип или идентификатор желаемой земли")
		if not is_editable(state.row, state.col) and state != cell_state(state.row, state.col, false):
			return _failure("Желаемая ячейка земли защищена")
	return _build_chunk_plan(chunk_col, chunk_row, false, desired)

func _build_chunk_plan(chunk_col: int, chunk_row: int, include_pending: bool, desired: Dictionary) -> Dictionary:
	var first_col := _start.x + chunk_col * CHUNK_SIZE
	var first_row := _start.y + chunk_row * CHUNK_SIZE
	if chunk_col < 0 or chunk_row < 0 or not contains_cell(first_row, first_col): return _failure("Неизвестный чанк земли")
	var groups := {}
	var count := 0
	for row in range(first_row, mini(first_row + CHUNK_SIZE, _start.y + _size.y)):
		for col in range(first_col, mini(first_col + CHUNK_SIZE, _start.x + _size.x)):
			var id := cell_id(row, col)
			var state: Dictionary = desired[id] if desired.has(id) else cell_state(row, col, include_pending)
			var key := str(state.tile)
			if not groups.has(key): groups[key] = []
			var height: float = _palette[key].heightM
			var position := Vector3((col + 0.5) * CELL_SIZE - _origin.x, height - 0.02, (row + 0.5) * CELL_SIZE - _origin.z)
			groups[key].append(Transform3D(Basis.IDENTITY, position))
			if not str(state.layer).is_empty():
				var layer_key := "layer:" + str(state.layer)
				if not groups.has(layer_key): groups[layer_key] = []
				groups[layer_key].append(Transform3D(Basis.IDENTITY, position + Vector3(0, 0.021, 0)))
			count += 1
	return {"ok": true, "chunk": Vector2i(chunk_col, chunk_row), "groups": groups, "cell_count": count, "box_size": Vector3(CELL_SIZE, 0.04, CELL_SIZE), "layer_plane_size": Vector2(CELL_SIZE, CELL_SIZE), "materials_policy": "reuse host SurfaceMaterials by group; never mutate shared resources; water requires water host"}

static func build_multimesh_resources(plan: Dictionary, materials: Dictionary, existing_mesh_cache: Dictionary = {}, water_host_enabled: bool = true) -> Dictionary:
	# Resource-only factory: one shared primitive per kind, one MultiMesh per chunk
	# kind. It creates no scene node and never changes an input mesh/material.
	if not plan.get("ok", false) or not plan.get("groups") is Dictionary:
		return _failure("Неверный план чанка земли")
	for key in plan.groups:
		if water_host_enabled and key == "16": continue
		if not materials.get(key) is Material: return _failure("Нет исходного материала для группы " + str(key))
		if existing_mesh_cache.has(key) and not existing_mesh_cache[key] is Mesh: return _failure("Неверный кеш геометрии земли")
	var mesh_cache := existing_mesh_cache.duplicate()
	var multimeshes := {}
	for key in plan.groups:
		if water_host_enabled and key == "16": continue
		var mesh: Mesh
		if mesh_cache.has(key): mesh = mesh_cache[key]
		elif str(key).begins_with("layer:"):
			var plane := PlaneMesh.new()
			plane.size = plan.layer_plane_size
			plane.material = materials[key]
			mesh = plane
			mesh_cache[key] = mesh
		else:
			var box := BoxMesh.new()
			box.size = plan.box_size
			box.material = materials[key]
			mesh = box
			mesh_cache[key] = mesh
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = plan.groups[key].size()
		for index in multi.instance_count: multi.set_instance_transform(index, plan.groups[key][index])
		multimeshes[key] = multi
	return {"ok": true, "multimeshes": multimeshes, "mesh_cache": mesh_cache, "water_host_dirty": plan.groups.has("16")}

func export_patch() -> Dictionary:
	var tile_overrides: Array = []
	var layers := {"dirt": [], "earth": []}
	for id in _tiles:
		var coordinates: PackedStringArray = str(id).split(":")
		tile_overrides.append({"id": id, "row": int(coordinates[1]), "col": int(coordinates[2]), "tile": _tiles[id]})
	for id in _layers:
		var coordinates: PackedStringArray = str(id).split(":")
		layers[_layers[id]].append({"id": id, "row": int(coordinates[1]), "col": int(coordinates[2])})
	var sort_cell := func(a, b): return a.row < b.row or (a.row == b.row and a.col < b.col)
	tile_overrides.sort_custom(sort_cell)
	for name in layers: layers[name].sort_custom(sort_cell)
	return {"schema_version": VERSION, "baseline_sha256": _baseline_hash, "cell_size": CELL_SIZE, "origin_m": [_origin.x, _origin.y, _origin.z], "start_row": _start.y, "start_col": _start.x, "tile_overrides": tile_overrides, "layers": layers}

static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true

func validate_patch(patch: Variant) -> Dictionary:
	if _grid.is_empty() or not patch is Dictionary or not _safe_json(patch): return _failure("Неверный патч земли")
	if not _exact_keys(patch, ["schema_version", "baseline_sha256", "cell_size", "origin_m", "start_row", "start_col", "tile_overrides", "layers"]): return _failure("Неизвестные поля патча земли")
	if patch.schema_version != VERSION or patch.baseline_sha256 != _baseline_hash or patch.cell_size != CELL_SIZE or patch.origin_m != [_origin.x, _origin.y, _origin.z] or patch.start_row != _start.y or patch.start_col != _start.x:
		return _failure("Патч не соответствует исходной карте земли")
	if not patch.tile_overrides is Array or patch.tile_overrides.size() > _size.x * _size.y or not patch.layers is Dictionary or not _exact_keys(patch.layers, NAMED_LAYERS): return _failure("Неверные изменения земли")
	var tiles := {}
	var layers := {}
	for record in patch.tile_overrides:
		if not record is Dictionary or not _exact_keys(record, ["id", "row", "col", "tile"]): return _failure("Неверная ячейка земли")
		if not _integer(record.row) or not _integer(record.col) or not _integer(record.tile) or int(record.tile) not in PAINT_TILES: return _failure("Неверные значения ячейки земли")
		if record.row < _start.y or record.col < _start.x or record.row >= _start.y + _size.y or record.col >= _start.x + _size.x: return _failure("Ячейка земли за пределами карты")
		var id := cell_id(record.row, record.col)
		if record.id != id or tiles.has(id) or not is_editable(record.row, record.col): return _failure("Повторная, защищённая или неизвестная ячейка земли")
		tiles[id] = int(record.tile)
	for name in NAMED_LAYERS:
		if not patch.layers[name] is Array or patch.layers[name].size() > _size.x * _size.y: return _failure("Неверный дополнительный слой земли")
		for record in patch.layers[name]:
			if not record is Dictionary or not _exact_keys(record, ["id", "row", "col"]) or not _integer(record.row) or not _integer(record.col): return _failure("Неверная ячейка слоя земли")
			if record.row < _start.y or record.col < _start.x or record.row >= _start.y + _size.y or record.col >= _start.x + _size.x: return _failure("Ячейка слоя земли за пределами карты")
			var id := cell_id(record.row, record.col)
			if record.id != id or layers.has(id) or not is_editable(record.row, record.col) or int(tiles.get(id, _baseline_tile(record.row, record.col))) == 16: return _failure("Слой земли нельзя накладывать на воду или защищённую ячейку")
			layers[id] = name
	return {"ok": true, "tiles": tiles, "layers": layers}

func load_patch(patch: Variant, physical_apply: Callable, nav_invalidate: Callable, physical_rollback: Callable) -> Dictionary:
	if install_guard_active: return _failure("Общая загрузка удерживает землю")
	if _stroke_active: return _failure("Закончите мазок перед загрузкой")
	var checked := validate_patch(patch)
	if not checked.ok: return checked
	var ids := {}
	for container in [_tiles, _layers, checked.tiles, checked.layers]:
		for id in container: ids[id] = true
	var changes := {}
	for id in ids:
		var coordinates: PackedStringArray = str(id).split(":")
		var row := int(coordinates[1])
		var col := int(coordinates[2])
		var before := cell_state(row, col, false)
		var after := before.duplicate(true)
		after.tile = int(checked.tiles.get(id, _baseline_tile(row, col)))
		after.layer = str(checked.layers.get(id, ""))
		changes[id] = {"before": before, "after": after}
	var result := _apply_transaction(changes, false, physical_apply, nav_invalidate, physical_rollback)
	if result.ok:
		_undo.clear()
		_redo.clear()
	return result

func debug_cost() -> Dictionary:
	return {"pointer_cell_touches": _cell_touch_count, "staged_cells": _stroke.size(), "tile_overrides": _tiles.size(), "layer_overrides": _layers.size(), "undo_actions": _undo.size(), "redo_actions": _redo.size()}

func capture_install_checkpoint() -> Dictionary:
	return {"tiles": _tiles.duplicate(), "layers": _layers.duplicate(), "stroke": _stroke.duplicate(true), "active": _stroke_active, "undo": _undo.duplicate(true), "redo": _redo.duplicate(true)}

func begin_install_guard() -> bool:
	if install_guard_active or _stroke_active: return false
	install_guard_active = true
	return true

func end_install_guard() -> void:
	install_guard_active = false

func restore_install_checkpoint(checkpoint: Dictionary) -> void:
	_tiles = checkpoint.tiles.duplicate()
	_layers = checkpoint.layers.duplicate()
	_stroke = checkpoint.stroke.duplicate(true)
	_stroke_active = checkpoint.active
	_undo.assign(checkpoint.undo)
	_redo.assign(checkpoint.redo)

func prepare_patch(patch: Dictionary) -> Dictionary:
	if _stroke_active: return _failure("Закончите мазок перед общей загрузкой")
	var checked := validate_patch(patch)
	if not checked.ok: return checked
	var ids := {}
	for container in [_tiles, _layers, checked.tiles, checked.layers]:
		for id in container: ids[id] = true
	var changes := {}
	for id in ids:
		var coordinates: PackedStringArray = str(id).split(":")
		var row := int(coordinates[1])
		var col := int(coordinates[2])
		var before := cell_state(row, col, false)
		var after := before.duplicate(true)
		after.tile = int(checked.tiles.get(id, _baseline_tile(row, col)))
		after.layer = str(checked.layers.get(id, ""))
		changes[id] = {"before": before, "after": after}
	return {"ok": true, "baseline_sha256": _baseline_hash, "delta": _delta(changes), "tiles": checked.tiles.duplicate(), "layers": checked.layers.duplicate()}

func commit_prepared_patch(prepared: Dictionary) -> Dictionary:
	if not install_guard_active: return _failure("Нет владельца общей транзакции земли")
	if _stroke_active or prepared.get("baseline_sha256") != _baseline_hash: return _failure("Исходная земля или активный мазок изменились")
	for cell: Dictionary in prepared.delta.cells:
		if cell_state(cell.before.row, cell.before.col, false) != cell.before: return _failure("Земля изменилась после подготовки")
	_tiles = prepared.tiles.duplicate()
	_layers = prepared.layers.duplicate()
	_undo.clear()
	_redo.clear()
	return {"ok": true}
