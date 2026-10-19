extends Node3D
## Output-only terrain owner candidate. Never adopts or edits existing main nodes.
## A trusted paused lease, staged water adapter and navigation gate are mandatory.
const Ground = preload("res://ground_document.gd")
var _ground: RefCounted
var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _chunks: Dictionary = {}
var _rows: Dictionary = {}
var _lease: Callable
var _water: Callable
var _navigation: Callable
var _pending: Dictionary = {}
var _chunk_root: Node3D
var _floor_root: Node3D
var _start := Vector2i.ZERO
var _size := Vector2i.ZERO
var _floor_layer := 1
var _floor_mask := 1
var last_built_chunks := 0
var last_built_rows := 0

static func accepted(value: Variant) -> bool:
	return (value is bool and value) or (value is Dictionary and value.get("ok", false) == true)

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _paused() -> bool:
	return _lease.is_valid() and accepted(_lease.call())

func configure(document: RefCounted, materials: Dictionary, edit_lease: Callable, water_adapter: Callable, navigation_gate: Callable, floor_layer: int = 1, floor_mask: int = 1) -> Dictionary:
	if _ground != null or document == null or not document.has_method("build_chunk_delta") or not document.has_method("row_strips"):
		return failure("Нужен исходный документ земли с delta-aware планами")
	if not is_inside_tree() or not edit_lease.is_valid() or not water_adapter.is_valid() or not navigation_gate.is_valid() or floor_layer < 1 or floor_mask < 0:
		return failure("Нужны отдельный render-root и обработчики остановки, воды и навигации")
	_lease = edit_lease
	_water = water_adapter
	_navigation = navigation_gate
	if not _paused(): return failure("Редактор должен владеть остановленной игровой сессией")
	_ground = document
	_materials = materials.duplicate()
	_floor_layer = floor_layer
	_floor_mask = floor_mask
	var patch: Dictionary = document.export_patch()
	_start = Vector2i(int(patch.start_col), int(patch.start_row))
	_size = document.dimensions()
	_chunk_root = Node3D.new()
	_chunk_root.name = "GroundRenderChunks"
	_floor_root = Node3D.new()
	_floor_root.name = "GroundPhysicalRows"
	add_child(_chunk_root)
	add_child(_floor_root)
	var chunks: Array = []
	var rows: Array = []
	var physical_rows: Array = []
	for row in range((_size.y + Ground.CHUNK_SIZE - 1) / Ground.CHUNK_SIZE):
		for col in range((_size.x + Ground.CHUNK_SIZE - 1) / Ground.CHUNK_SIZE): chunks.append(Vector2i(col, row))
	for row in range(_start.y, _start.y + _size.y):
		rows.append(row)
		physical_rows.append(document.row_strips(row))
	var initial := {"cells": [], "dirty_chunks": chunks, "dirty_rows": rows, "physical_rows": physical_rows, "desired": {}, "initial": true}
	var result := apply(initial)
	if result.ok: result = validate_navigation(initial)
	if not result.ok:
		rollback(initial)
		return result
	return finalize(false)

func _free_staging(stage: Dictionary) -> void:
	for container: String in ["chunks", "rows"]:
		for node: Node in stage.get(container, {}).values():
			if is_instance_valid(node): node.free()

func _chunk_node(plan: Dictionary, resources: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [plan.chunk.x, plan.chunk.y]
	for key: String in resources.multimeshes:
		var instance := MultiMeshInstance3D.new()
		instance.name = "Surface_" + key.replace(":", "_")
		instance.multimesh = resources.multimeshes[key]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(instance)
	return node

func _row_node(row: int, strips: Array) -> Node3D:
	var node := Node3D.new()
	node.name = "Row_%d" % row
	for strip: Dictionary in strips:
		var body := StaticBody3D.new()
		body.name = str(strip.id).replace(":", "_")
		body.position = strip.position
		body.collision_layer = 0 # Detached prebuild cannot join active physics.
		body.collision_mask = 0
		body.set_meta("source_strip", strip.duplicate(true))
		var shape := BoxShape3D.new()
		shape.size = strip.size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func _validate_cells(delta: Dictionary) -> Dictionary:
	if not delta.get("cells") is Array or not delta.get("dirty_chunks") is Array or not delta.get("dirty_rows") is Array or not delta.get("desired") is Dictionary:
		return failure("Неверный delta-план земли")
	var seen := {}
	for cell: Variant in delta.cells:
		if not cell is Dictionary or not cell.get("before") is Dictionary or not cell.get("after") is Dictionary: return failure("Неверная ячейка мазка")
		var before: Dictionary = cell.before
		var after: Dictionary = cell.after
		if not before.has("row") or not before.has("col") or not before.has("id"): return failure("Нет исходной ячейки")
		if not _ground.is_editable(int(before.row), int(before.col)) or _ground.cell_state(int(before.row), int(before.col), false) != before:
			return failure("Мазок устарел или пытается изменить защищённую землю")
		if seen.has(before.id) or after.get("id") != before.id or after.get("row") != before.row or after.get("col") != before.col or after.get("tile") not in Ground.PAINT_TILES or after.get("layer", "") not in ["", "dirt", "earth"]:
			return failure("Неверное желаемое состояние земли")
		if after.tile == 16 and not str(after.get("layer", "")).is_empty(): return failure("Дополнительный слой не может подменить воду")
		if delta.desired.get(before.id) != after: return failure("Delta-план не соответствует ячейкам")
		seen[before.id] = true
	return {"ok": true}

func apply(delta: Dictionary) -> Dictionary:
	if not _paused(): return failure("Изменение земли запрещено во время игры")
	if not _pending.is_empty(): return failure("Завершите предыдущую транзакцию земли")
	var valid := _validate_cells(delta)
	if not valid.ok: return valid
	var stage := {"chunks": {}, "rows": {}, "mesh_cache": _mesh_cache.duplicate(), "water_dirty": bool(delta.get("initial", false))}
	for chunk: Variant in delta.dirty_chunks:
		if not chunk is Vector2i or stage.chunks.has(chunk):
			_free_staging(stage)
			return failure("Неверный dirty-чанк")
		var plan: Dictionary = _ground.build_chunk_delta(chunk.x, chunk.y, delta.desired)
		if not plan.get("ok", false):
			_free_staging(stage)
			return plan
		var resources := Ground.build_multimesh_resources(plan, _materials, stage.mesh_cache, true)
		if not resources.ok:
			_free_staging(stage)
			return resources
		stage.mesh_cache = resources.mesh_cache
		stage.chunks[chunk] = _chunk_node(plan, resources)
	var floor_plans := {}
	for plan: Variant in delta.get("physical_rows", []):
		if not plan is Dictionary or not plan.get("row") is int or not plan.get("strips") is Array or floor_plans.has(plan.row):
			_free_staging(stage)
			return failure("Неверный план физических полос")
		floor_plans[plan.row] = plan.strips
	for row: Variant in delta.dirty_rows:
		if not row is int or row < _start.y or row >= _start.y + _size.y or stage.rows.has(row):
			_free_staging(stage)
			return failure("Неверная dirty-строка")
		if not floor_plans.has(row):
			_free_staging(stage)
			return failure("Нет delta-плана физической строки")
		stage.rows[row] = _row_node(row, floor_plans[row])
	for cell: Dictionary in delta.cells:
		if int(cell.before.tile) == 16 or int(cell.after.tile) == 16: stage.water_dirty = true
	var water_delta := delta.duplicate(true)
	if stage.water_dirty:
		var prepared: Variant = _water.call("prepare", water_delta)
		if not accepted(prepared):
			_water.call("rollback", water_delta)
			_free_staging(stage)
			return failure("Хозяин воды не подготовил изменение")
		if prepared is Dictionary: water_delta["water_receipt"] = prepared.get("receipt")
	if not _paused():
		if stage.water_dirty: _water.call("rollback", water_delta)
		_free_staging(stage)
		return failure("Редактор потерял остановленную сессию при подготовке")
	_pending = {"old_chunks": {}, "old_rows": {}, "old_cache": _mesh_cache, "new_chunks": stage.chunks, "new_rows": stage.rows, "filters": [], "water_dirty": stage.water_dirty, "water_delta": water_delta, "nav_valid": false}
	for key: Vector2i in stage.chunks:
		if _chunks.has(key):
			_pending.old_chunks[key] = _chunks[key]
			_chunk_root.remove_child(_chunks[key])
		_chunk_root.add_child(stage.chunks[key])
		_chunks[key] = stage.chunks[key]
	for row: int in stage.rows:
		if _rows.has(row):
			var old: Node3D = _rows[row]
			_pending.old_rows[row] = old
			for body: StaticBody3D in old.get_children():
				_pending.filters.append({"body": body, "layer": body.collision_layer, "mask": body.collision_mask})
				body.collision_layer = 0
				body.collision_mask = 0
			_floor_root.remove_child(old)
		_floor_root.add_child(stage.rows[row])
		for body: StaticBody3D in stage.rows[row].get_children():
			body.collision_layer = _floor_layer
			body.collision_mask = _floor_mask
		_rows[row] = stage.rows[row]
	_mesh_cache = stage.mesh_cache
	last_built_chunks = stage.chunks.size()
	last_built_rows = stage.rows.size()
	if stage.water_dirty and not accepted(_water.call("apply", water_delta)): return failure("Хозяин воды не принял транзакцию")
	if not _paused(): return failure("Сессия перестала быть остановленной при принятии воды")
	return {"ok": true, "dirty_chunks": last_built_chunks, "dirty_rows": last_built_rows}

func validate_navigation(delta: Dictionary) -> Dictionary:
	if not _paused() or _pending.is_empty(): return failure("Нет остановленной подготовленной транзакции")
	if not accepted(_navigation.call(delta)): return failure("Навигация не приняла подготовленную землю")
	if not _paused(): return failure("Сессия перестала быть остановленной при проверке навигации")
	_pending.nav_valid = true
	return {"ok": true}

func rollback(_delta: Dictionary = {}) -> Dictionary:
	if _pending.is_empty(): return {"ok": true}
	if _pending.get("model_committed", false): return failure("Документ уже принят: сначала завершите освобождение ресурсов, не откатывайте физику отдельно")
	if not _paused(): return failure("Для физического отката хозяин должен остановить игру")
	var water_ok := true
	if _pending.water_dirty: water_ok = accepted(_water.call("rollback", _pending.water_delta))
	if not _paused(): return failure("Для завершения отката после ответа воды хозяин должен остановить игру")
	if not _pending.get("scene_restored", false):
		for key: Vector2i in _pending.new_chunks:
			_chunk_root.remove_child(_chunks[key])
			_chunks[key].free()
			_chunks.erase(key)
			if _pending.old_chunks.has(key):
				_chunks[key] = _pending.old_chunks[key]
				_chunk_root.add_child(_chunks[key])
		for row: int in _pending.new_rows:
			_floor_root.remove_child(_rows[row])
			_rows[row].free()
			_rows.erase(row)
			if _pending.old_rows.has(row):
				_rows[row] = _pending.old_rows[row]
				_floor_root.add_child(_rows[row])
		for filter: Dictionary in _pending.filters:
			filter.body.collision_layer = filter.layer
			filter.body.collision_mask = filter.mask
		_mesh_cache = _pending.old_cache
		_pending["scene_restored"] = true
	if water_ok: _pending.clear()
	return {"ok": water_ok, "error": "Откат воды не подтверждён" if not water_ok else ""}

func finalize(model_committed: bool = true) -> Dictionary:
	if not _paused() or _pending.is_empty() or not _pending.nav_valid: return failure("Нельзя завершить землю до остановки и проверки навигации")
	if model_committed: _pending["model_committed"] = true
	if _pending.water_dirty and not accepted(_water.call("finalize", _pending.water_delta)):
		return {"ok": false, "error": "Хозяин воды ещё удерживает транзакцию. Сессия должна оставаться остановленной.", "committed": bool(_pending.get("model_committed", false)), "retry_finalize": true}
	if not _paused(): return failure("Нельзя освобождать старые ресурсы после потери остановленной сессии")
	for container: String in ["old_chunks", "old_rows"]:
		for node: Node in _pending[container].values(): node.free()
	_pending.clear()
	return {"ok": true}

func commit_stroke() -> Dictionary:
	var result: Dictionary = _ground.commit_stroke(apply, validate_navigation, rollback)
	if result.ok and not result.get("unchanged", false):
		_pending["model_committed"] = true
		return finalize()
	return result

func undo() -> Dictionary:
	var result: Dictionary = _ground.undo(apply, validate_navigation, rollback)
	if result.ok and not result.get("unchanged", false):
		_pending["model_committed"] = true
		return finalize()
	return result

func redo() -> Dictionary:
	var result: Dictionary = _ground.redo(apply, validate_navigation, rollback)
	if result.ok and not result.get("unchanged", false):
		_pending["model_committed"] = true
		return finalize()
	return result

func _exit_tree() -> void:
	for container: String in ["old_chunks", "old_rows"]:
		for node: Node in _pending.get(container, {}).values():
			if is_instance_valid(node) and node.get_parent() == null: node.free()
