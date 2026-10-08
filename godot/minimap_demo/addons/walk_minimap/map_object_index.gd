extends RefCounted
## Walk mapObjectBounds/createMapObjectIndex: metre-space, conservative cell query.
## Filters affect POI/glyph/hit/hover consumers, never the default geography query.
const DEFAULT_CELL_SIZE: float = 128.0
const MIN_CELL_SIZE: float = 8.0
const Catalog = preload("res://addons/walk_minimap/map_catalog.gd")

var _cell_size: float = DEFAULT_CELL_SIZE
var _objects: Array = []
var _visible: Array = []
var _cells: Dictionary = {}
var _flags: Dictionary = {}
var _indexed_count: int = 0
var _dataset_rebuilds: int = 0
var _filter_rebuilds: int = 0
var _index_rebuilds: int = 0

func _init(cell_size: float = DEFAULT_CELL_SIZE) -> void:
	_cell_size = maxf(MIN_CELL_SIZE, cell_size) if is_finite(cell_size) else DEFAULT_CELL_SIZE

func configure(objects: Array) -> void:
	# Deep snapshot plus recursive read-only containers prevents caller/getter drift.
	_objects = objects.duplicate(true)
	_freeze(_objects)
	_dataset_rebuilds += 1
	_cells.clear()
	_indexed_count = 0
	for object_index: int in range(_objects.size()):
		var object_bounds: Dictionary = map_object_bounds(_objects[object_index])
		if object_bounds.is_empty():
			continue
		_indexed_count += 1
		for cell_z: int in range(floori(float(object_bounds.minZ) / _cell_size), floori(float(object_bounds.maxZ) / _cell_size) + 1):
			for cell_x: int in range(floori(float(object_bounds.minX) / _cell_size), floori(float(object_bounds.maxX) / _cell_size) + 1):
				var key: Vector2i = Vector2i(cell_x, cell_z)
				if not _cells.has(key):
					_cells[key] = []
				var bucket: Array = _cells[key]
				bucket.append(object_index)
	_index_rebuilds += 1
	_rebuild_visible()

func set_kind_enabled(kind: String, enabled: bool) -> bool:
	if is_kind_enabled(kind) == enabled:
		return false
	if enabled:
		_flags.erase(kind)
	else:
		_flags[kind] = false
	_rebuild_visible()
	return true

func is_kind_enabled(kind: String) -> bool:
	return bool(_flags.get(kind, true))

func reset_filters() -> bool:
	if _flags.is_empty():
		return false
	_flags.clear()
	_rebuild_visible()
	return true

func visible_objects() -> Array:
	return _visible.duplicate()

func all_objects() -> Array:
	return _objects.duplicate()

func query(bounds: Dictionary, enabled_only: bool = false) -> Array:
	for field: String in ["minX", "maxX", "minZ", "maxZ"]:
		if not _finite_number(bounds.get(field)):
			return visible_objects() if enabled_only else all_objects()
	var result: Array = []
	var seen: Dictionary = {}
	# Cell overlap is intentionally conservative; do not tighten to AABB overlap.
	for cell_z: int in range(floori(float(bounds.minZ) / _cell_size), floori(float(bounds.maxZ) / _cell_size) + 1):
		for cell_x: int in range(floori(float(bounds.minX) / _cell_size), floori(float(bounds.maxX) / _cell_size) + 1):
			var bucket: Array = _cells.get(Vector2i(cell_x, cell_z), [])
			for object_index: int in bucket:
				if seen.has(object_index):
					continue
				seen[object_index] = true
				var object: Variant = _objects[object_index]
				if not enabled_only or is_kind_enabled(_kind(object)):
					result.append(object)
	return result

func stats() -> Dictionary:
	return {
		"objects": _indexed_count, "cells": _cells.size(), "cellSize": _cell_size,
		"dataset_objects": _objects.size(), "visible_objects": _visible.size(),
		"dataset_rebuilds": _dataset_rebuilds,
		"filter_rebuilds": _filter_rebuilds, "index_rebuilds": _index_rebuilds
	}

func _rebuild_visible() -> void:
	_visible = []
	for object: Variant in _objects:
		if is_kind_enabled(_kind(object)):
			_visible.append(object)
	_visible.make_read_only()
	_filter_rebuilds += 1

static func _kind(object: Variant) -> String:
	if object is Dictionary:
		var value: Variant = object.get("kind", "object")
		return str(value) if Catalog.KINDS.has(str(value)) else "object"
	return "object"

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for child: Variant in value:
			_freeze(child)
		value.make_read_only()

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _number(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is int or value is float or value is bool:
		return float(value)
	if value is String:
		var stripped: String = value.strip_edges()
		if stripped.is_empty():
			return 0.0
		if stripped.is_valid_float():
			return stripped.to_float()
	return NAN

static func map_object_bounds(object: Variant) -> Dictionary:
	if not object is Dictionary:
		return {}
	var points: Variant = object.get("polygon", object.get("points", []))
	if points == null:
		points = object.get("points", [])
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	if points is Array:
		for point: Variant in points:
			var px: Variant = null
			var pz: Variant = null
			if point is Dictionary:
				px = point.get("x")
				pz = point.get("z")
			elif point is Array and point.size() >= 2:
				px = point[0]
				pz = point[1]
			if _finite_number(px) and _finite_number(pz):
				min_x = minf(min_x, float(px))
				max_x = maxf(max_x, float(px))
				min_z = minf(min_z, float(pz))
				max_z = maxf(max_z, float(pz))
	if not is_finite(min_x):
		var radius: float = _number(object.get("radius", NAN))
		if is_nan(radius) or radius == 0.0:
			radius = 1.0
		radius = maxf(0.0, radius)
		var x: float = _number(object.get("x", NAN))
		var z: float = _number(object.get("z", NAN))
		if not is_finite(x + z) or not is_finite(radius):
			return {}
		min_x = x - radius
		max_x = x + radius
		min_z = z - radius
		max_z = z + radius
	if not is_finite(min_x) or not is_finite(max_x) or not is_finite(min_z) or not is_finite(max_z):
		return {}
	return {"minX": min_x, "maxX": max_x, "minZ": min_z, "maxZ": max_z}
