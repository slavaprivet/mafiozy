extends "res://scripts/incremental_factory.gd"
## Detached, source-exact CPU slice of the incremental V3 factory.
## `max_parts` bounds loop iterations, not milliseconds. Float32 conversion,
## one final MultiMesh upload, JSON parsing and geometry creation remain atomic.

var _slice: Dictionary = {}

func build_batch_step(_max_batches: int = 1) -> Dictionary:
	return {"ok":false,"error":"use-step-exploration-parts"}

func build_road_batch_step(_max_batches: int = 1) -> Dictionary:
	return {"ok":false,"error":"use-step-road-parts"}

func source_stage_complete(id: String) -> bool:
	if _slice.has("seen") and (_slice.seen as Dictionary).has(id):
		return false
	return super.source_stage_complete(id)

func _slice_refusal(message: String) -> Dictionary:
	_slice.clear()
	return _incremental_fail(message)

func _root_is_detached(road: bool) -> bool:
	if not is_instance_valid(_root) or _root.is_queued_for_deletion() or _root.get_parent() != null:
		return false
	if road and (not is_instance_valid(_roads_root) or _roads_root.is_queued_for_deletion() or _roads_root.get_parent() != null):
		return false
	return true

func _begin_slice(road: bool) -> bool:
	var cursor: int = _road_cursor if road else _incremental_cursor
	var batches: Array = _manifest.roads.batches if road else _manifest.exploration.batches
	if cursor >= batches.size():
		return true
	var source: Dictionary = batches[cursor]
	var paint: bool = road and str(source.kind) == "merged-original-paint"
	if not _meshes.has(source.geometry) or not _materials.has(source.material):
		return false
	if source.objectIds.size() != int(source.count) and not paint:
		return false
	var count: int = source.objectIds.size() if paint else int(source.count)
	var matrices := PackedFloat32Array()
	var colors := PackedFloat32Array()
	var stride := 0
	if not paint:
		matrices = _float_data(source.instanceMatrices)
		var has_colors: bool = source.has("instanceColors")
		colors = _float_data(source.instanceColors) if has_colors else PackedFloat32Array()
		stride = 16 if has_colors else 12
		if matrices.size() != count * 16 or (has_colors and colors.size() != count * 3):
			return false
	var buffer := PackedFloat32Array()
	buffer.resize(count * stride)
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	_slice = {"source":source,"road":road,"paint":paint,"cursor":0,"count":count,"stride":stride,
		"matrices":matrices,"colors":colors,"buffer":buffer,"transforms":transforms,"tints":tints,"seen":{}}
	return errors.is_empty()

func _stage_part() -> bool:
	var index: int = _slice.cursor
	var source: Dictionary = _slice.source
	var id := str(source.objectIds[index])
	if not _source_records.has(id):
		return false
	if not (_slice.seen as Dictionary).has(id):
		_slice.seen[id] = true
		# The public completion query masks every ID in the active batch until
		# its one original submission is committed. No 505-ID closure loop.
		_completed_batch_counts[id] = int(_completed_batch_counts.get(id, 0)) + 1
	if _slice.paint:
		_paint_ids[id] = {"batch":source.key,"first":index * 6,"count":6}
		_slice.cursor = index + 1
		return true
	var matrices: PackedFloat32Array = _slice.matrices
	var colors: PackedFloat32Array = _slice.colors
	var buffer: PackedFloat32Array = _slice.buffer
	var stride: int = _slice.stride
	var transform := _transform(matrices, index * 16)
	var tint := Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2], 1.0) if stride == 16 else Color.WHITE
	for row in 3:
		for col in 4:
			buffer[index * stride + row * 4 + col] = matrices[index * 16 + col * 4 + row]
	if stride == 16:
		buffer[index * stride + 12] = tint.r
		buffer[index * stride + 13] = tint.g
		buffer[index * stride + 14] = tint.b
		buffer[index * stride + 15] = 1.0
	(_slice.transforms as Array).append(transform)
	(_slice.tints as Array).append(tint)
	if not _parts.has(id):
		_parts[id] = []
	_parts[id].append({"batch":source.key,"index":index,"original":transform,"color":tint})
	if _slice.road:
		_road_ids[id] = true
	_slice.cursor = index + 1
	return true

func _finish_slice() -> bool:
	var source: Dictionary = _slice.source
	var road: bool = _slice.road
	if _slice.cursor != _slice.count or (_slice.seen as Dictionary).is_empty():
		return false
	if _slice.paint:
		var paint := MeshInstance3D.new()
		paint.name = str(source.key).validate_node_name()
		paint.mesh = _meshes[source.geometry]
		paint.material_override = _materials[source.material]
		paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paint.transform = _transform_array(source.sourceWorldMatrix)
		_roads_root.add_child(paint)
		var arrays: Array = _geometry_arrays[source.geometry]
		_paint_batches[source.key] = {"node":paint,"source":source,"arrays":arrays,"base":arrays[Mesh.ARRAY_VERTEX],"current":arrays[Mesh.ARRAY_VERTEX]}
	else:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = _slice.stride == 16
		mm.mesh = _meshes[source.geometry]
		mm.instance_count = int(source.count)
		mm.buffer = _slice.buffer
		var node := MultiMeshInstance3D.new()
		node.name = str(source.key).validate_node_name()
		node.multimesh = mm
		node.material_override = _materials[source.material]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if road:
			node.transform = _transform_array(source.sourceWorldMatrix)
			_roads_root.add_child(node)
			_batches[source.key] = {"node":node,"mesh":mm,"source":source,"chunk":"","transforms":_slice.transforms,"colors":_slice.tints,"initial_native_buffer":_slice.buffer,"stride":_slice.stride}
			_recompute_road_bounds(source.key)
			road_upload_calls += 1
		else:
			var chunk_key := str(source.chunk)
			if not _chunks.has(chunk_key):
				var chunk := Node3D.new()
				chunk.name = chunk_key.validate_node_name()
				_root.add_child(chunk)
				_chunks[chunk_key] = {"node":chunk,"bounds":source.chunkBounds.duplicate(true),"level":0,"batches":[]}
			_chunks[chunk_key].node.add_child(node)
			_chunks[chunk_key].batches.append(source.key)
			_batches[source.key] = {"node":node,"mesh":mm,"source":source,"chunk":chunk_key,"transforms":_slice.transforms,"colors":_slice.tints,"initial_native_buffer":_slice.buffer}
			initial_upload_calls += 1
	_slice.clear()
	if road:
		_road_cursor += 1
	else:
		_incremental_cursor += 1
	return true

func _step_parts(road: bool, max_parts: int) -> Dictionary:
	var phase := "ROADS" if road else "BUILD"
	if _incremental_busy or _incremental_phase != phase or max_parts < 1 or max_parts > 64:
		return {"ok":false,"error":"invalid-part-step"}
	if not _root_is_detached(road):
		return _slice_refusal("Procedural root lifetime/parent drift")
	_incremental_busy = true
	var cursor: int = _road_cursor if road else _incremental_cursor
	var batches: Array = _manifest.roads.batches if road else _manifest.exploration.batches
	if cursor < batches.size() and _slice.is_empty() and not _begin_slice(road):
		_incremental_busy = false
		return _slice_refusal("Source batch decode refusal")
	var processed := 0
	while not _slice.is_empty() and processed < max_parts:
		if _slice.cursor == _slice.count:
			break
		if not _stage_part():
			_incremental_busy = false
			return _slice_refusal("Source part refusal")
		processed += 1
	if not _slice.is_empty() and _slice.cursor == _slice.count and not _finish_slice():
		_incremental_busy = false
		return _slice_refusal("Source batch closure refusal")
	_incremental_busy = false
	return {"ok":true,"phase":phase,"cursor":_road_cursor if road else _incremental_cursor,"processedParts":processed,
		"complete":(_road_cursor if road else _incremental_cursor) == batches.size(),"renderedIds":0}

func step_exploration_parts(max_parts: int = 64) -> Dictionary:
	return _step_parts(false, max_parts)

func step_road_parts(max_parts: int = 64) -> Dictionary:
	return _step_parts(true, max_parts)

func finish_exploration() -> Dictionary:
	if not _slice.is_empty():
		return {"ok":false,"error":"partial-exploration-batch"}
	return super.finish_exploration()

func finish_all() -> Dictionary:
	if not _slice.is_empty():
		return {"ok":false,"error":"partial-road-batch"}
	return super.finish_all()
