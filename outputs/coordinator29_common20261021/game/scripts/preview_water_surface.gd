extends RefCounted
## One source-native water batch. Caller owns the sole main-loop advance.
## No collision shapes, floor, auto_process, scene scans or runtime disk writes.
const Water = preload("res://scripts/preview_water_material.gd")
const SCHEMA := "mafiozi.godot.preview-water/v1"
const MAX_CELLS := 4096
const SOURCE_ORDER := [[0,0],[1,1],[1,0],[0,0],[0,1],[1,1]]
const GODOT_INDEX_ORDER := [0,2,1,3,5,4]
var _factory: RefCounted
var _instance: MeshInstance3D
var _built := false
var _cell_count := 0
var _had_ripples := false

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high
static func _vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not _number(component, -1000000, 1000000):
			return false
	return true

static func _source_order(value: Variant) -> bool:
	if not value is Array or value.size() != SOURCE_ORDER.size():
		return false
	for i in range(SOURCE_ORDER.size()):
		if not value[i] is Array or value[i].size() != 2:
			return false
		for j in range(2):
			if not _number(value[i][j],0,1) or value[i][j] != SOURCE_ORDER[i][j]:
				return false
	return true

static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["DATA_REQUIRED"])
	if data.get("schema") != SCHEMA:
		errors.append("SCHEMA")
	if not _vector(data.get("originM")):
		errors.append("ORIGIN")
	if not _number(data.get("metresPerCell"), .001, 100):
		errors.append("CELL_SIZE")
	var native: Variant = data.get("native")
	if not native is Dictionary:
		return errors + PackedStringArray(["NATIVE_REQUIRED"])
	if not _number(native.get("surfaceYM"), -.180001, -.179999):
		errors.append("SOURCE_SURFACE_HEIGHT")
	if not _source_order(native.get("vertexOrder")):
		errors.append("SOURCE_VERTEX_ORDER")
	var cells: Variant = native.get("cells")
	if not cells is Array or cells.size() > MAX_CELLS:
		return errors + PackedStringArray(["BOUNDED_CELLS_REQUIRED"])
	var seen := {}
	for record in cells:
		if not record is Dictionary:
			errors.append("CELL_RECORD")
			continue
		if not _number(record.get("r"), 0, 4095) or not _number(record.get("c"), 0, 4095):
			errors.append("CELL_COORDINATE")
			continue
		if float(record.r) != floorf(float(record.r)) or float(record.c) != floorf(float(record.c)):
			errors.append("CELL_INTEGER_REQUIRED")
			continue
		var key := Vector2i(int(record.r), int(record.c))
		if seen.has(key):
			errors.append("DUPLICATE_CELL")
		seen[key] = true
		var depths: Variant = record.get("depths")
		if not depths is Array or depths.size() != 6:
			errors.append("SIX_DEPTHS_REQUIRED")
			continue
		for depth in depths:
			if not _number(depth, 0, 50):
				errors.append("FINITE_DEPTH_REQUIRED")
	return errors

func build(data: Variant, parent: Node3D) -> Dictionary:
	if _built:
		return {"ok": false, "errors": PackedStringArray(["ALREADY_BUILT"])}
	var errors := validate(data)
	if not is_instance_valid(parent):
		errors.append("PARENT_REQUIRED")
	else:
		var transform := parent.global_transform if parent.is_inside_tree() else parent.transform
		if not transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("IDENTITY_WORLD_PARENT_REQUIRED")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var cells: Array = data.native.cells
	_cell_count = cells.size()
	_built = true
	if cells.is_empty():
		return {"ok": true, "cells": 0, "vertices": 0, "triangles": 0, "mesh_instances": 0}
	var origin := Vector3(data.originM[0], data.originM[1], data.originM[2])
	var cell_size: float = data.metresPerCell
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var depths := PackedFloat32Array()
	var indices := PackedInt32Array()
	positions.resize(cells.size()*6)
	normals.resize(positions.size())
	normals.fill(Vector3.UP)
	depths.resize(positions.size())
	indices.resize(positions.size())
	for i in range(cells.size()):
		var record: Dictionary = cells[i]
		for j in range(6):
			# Vector3 first performs source terrain Float32 conversion BEFORE
			# preview recentering, as Three Float32BufferAttribute does.
			var source := Vector3((record.c + SOURCE_ORDER[j][0])*cell_size, data.native.surfaceYM, (record.r + SOURCE_ORDER[j][1])*cell_size)
			positions[i*6+j] = source-origin
			depths[i*6+j] = record.depths[j]
			# Godot's front faces are clockwise, source Three faces CCW.
			# Reorder only indices; source vertices and their depths stay paired.
			indices[i*6+j] = i*6+GODOT_INDEX_ORDER[j]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = depths
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Water.DEPTH_FLAGS)
	_factory = Water.new()
	var material: ShaderMaterial = _factory.material_for(origin, true)
	material.render_priority = 1
	mesh.surface_set_material(0, material)
	_instance = MeshInstance3D.new()
	_instance.name = "SourceNativeWater"
	_instance.mesh = mesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.set_meta("source_scope", "native water only; no collision")
	parent.add_child(_instance)
	return {"ok": true, "cells": cells.size(), "vertices": positions.size(), "triangles": cells.size()*2, "mesh_instances": 1}

func advance(time_seconds: float, ripple_events: Variant = null) -> bool:
	if not _built or _factory == null:
		return false
	if ripple_events != null or _had_ripples:
		_had_ripples = _factory.set_water_ripples(ripple_events) > 0
	return _factory.update(time_seconds)

func dispose() -> void:
	if is_instance_valid(_instance):
		_instance.free()
	_instance = null
	if _factory != null:
		_factory.dispose()
	_factory = null
	_built = false
	_cell_count = 0
	_had_ripples = false
