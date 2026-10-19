extends Node3D
## Editor-only hints, not replacement terrain/water/materials or collision.
const Ground = preload("res://ground_document.gd")
var _document: RefCounted
var _lease: Callable
var _coordinates := {}
var _palette := {}
var _mesh: PlaneMesh
var _material: StandardMaterial3D
var _chunks := {}
var _cursor: MultiMeshInstance3D
var _cursor_key := ""
var builds := 0

func configure(document: RefCounted, edit_lease: Callable) -> Dictionary:
	if _document != null or not is_inside_tree() or document == null or not document.has_method("preview_chunk_cells") or not edit_lease.is_valid(): return {"ok": false}
	_document = document
	_lease = edit_lease
	_coordinates = document.coordinate_info()
	_palette = document.surface_palette()
	_mesh = PlaneMesh.new()
	_mesh.size = Vector2(Ground.CELL_SIZE * 0.96, Ground.CELL_SIZE * 0.96)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = false
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {"ok": true}

func _paused() -> bool:
	return _lease.is_valid() and _lease.call() == true

func _marker(cells: Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _mesh
	multi.instance_count = cells.size()
	var buffer := PackedFloat32Array()
	buffer.resize(cells.size() * 16)
	for index in cells.size():
		var cell: Dictionary = cells[index]
		var height: float = _palette[str(cell.tile)].heightM
		var origin: Vector3 = _coordinates.origin_m
		var pos := Vector3((cell.col + 0.5) * Ground.CELL_SIZE - origin.x, height + 0.07, (cell.row + 0.5) * Ground.CELL_SIZE - origin.z)
		var tint := Color("dfb959") if cell.get("blocked", false) else Color("6ddda9")
		tint = tint.srgb_to_linear()
		tint.a = 0.44
		var values := [1.0, 0.0, 0.0, pos.x, 0.0, 1.0, 0.0, pos.y, 0.0, 0.0, 1.0, pos.z, tint.r, tint.g, tint.b, tint.a]
		for offset in 16: buffer[index * 16 + offset] = values[offset]
	multi.buffer = buffer
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builds += 1
	return node

func apply(descriptor: Dictionary) -> Dictionary:
	if descriptor.get("cancelled", false) == true:
		clear_preview()
		return {"ok": true}
	if _document == null or not _paused() or descriptor.get("preview") != true or not descriptor.get("dirty_chunks") is Array: return {"ok": false}
	var plans := {}
	# Obtain trusted pending cells, never use caller-provided transforms/meshes.
	for key: Variant in descriptor.dirty_chunks:
		if not key is Vector2i or plans.has(key): return {"ok": false}
		var plan: Dictionary = _document.preview_chunk_cells(key.x, key.y)
		if not plan.ok: return plan
		plans[key] = plan.cells
	if not _paused(): return {"ok": false}
	for key: Vector2i in plans:
		if _chunks.has(key): _chunks[key].free()
		_chunks.erase(key)
		if not plans[key].is_empty():
			var node := _marker(plans[key])
			add_child(node)
			_chunks[key] = node
	return {"ok": true, "updated_chunks": plans.size()}

func show_cursor(row: int, col: int, radius: int) -> Dictionary:
	if _document == null or not _paused() or radius < 1 or radius > 8 or not _document.contains_cell(row, col):
		hide_cursor()
		return {"ok": false}
	var key := "%d:%d:%d" % [row, col, radius]
	if _cursor_key == key: return {"ok": true, "unchanged": true}
	var cells: Array = []
	var reach := radius - 1
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x*x + y*y > reach*reach or not _document.contains_cell(row+y, col+x): continue
			var cell: Dictionary = _document.cell_state(row+y, col+x)
			cell.blocked = not _document.is_editable(row+y, col+x)
			cells.append(cell)
	hide_cursor()
	_cursor = _marker(cells)
	add_child(_cursor)
	_cursor_key = key
	return {"ok": true, "cells": cells.size()}

func hide_cursor() -> void:
	if is_instance_valid(_cursor): _cursor.free()
	_cursor = null
	_cursor_key = ""

func clear_preview() -> void:
	for node: Node in _chunks.values():
		if is_instance_valid(node): node.free()
	_chunks.clear()
	hide_cursor()
