extends "res://scripts/procedural_factory.gd"
## Tools-only exact shared-batch slice of the pinned V3 factory.
## Caller must yield between steps; one buffer/mesh/batch may still be expensive.

var _incremental_phase := "NEW"
var _incremental_cursor := 0
var _incremental_busy := false
var _incremental_catalog_rows: Array = []
var _expected_batch_counts: Dictionary = {}
var _completed_batch_counts: Dictionary = {}
var _road_cursor := 0

func configure(_expected_sha: String, _trusted_road_adapter: Callable = Callable()) -> bool:
	return false # No accidental eager path on this candidate.

func _incremental_fail(message: String) -> Dictionary:
	_error(message)
	_incremental_phase = "FAILED"
	return {"ok":false,"phase":_incremental_phase,"error":message}

func begin_configure(expected_sha: String, trusted_road_adapter: Callable = Callable()) -> Dictionary:
	if _incremental_phase != "NEW" or is_instance_valid(_root) or is_instance_valid(_roads_root): return {"ok":false,"error":"already-started"}
	errors.clear()
	if not _sha_valid(expected_sha): return _incremental_fail("Host SHA admission required")
	var raw := FileAccess.get_file_as_bytes("res://manifest.json")
	if _hash(raw) != expected_sha: return _incremental_fail("Manifest changed")
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not decoded is Dictionary or decoded.get("schema", "") != "mafiozi.godot.map-editor-procedural-source/v1" or str(decoded.get("threeRevision", "")) != "180": return _incremental_fail("Unsupported source manifest")
	_manifest = decoded
	_road_adapter = trusted_road_adapter
	var contract: Dictionary = _manifest.coordinateContract
	if not _vector_valid(contract.get("originM", null)) or float(contract.get("metresPerCell", 0)) != 4.1: return _incremental_fail("Invalid native coordinate contract")
	_origin = _v3(contract.originM)
	_buffers.clear(); _geometry_arrays.clear(); _meshes.clear(); _materials.clear()
	_source_frames.clear(); _current_frames.clear(); _source_records.clear()
	_expected_batch_counts.clear(); _completed_batch_counts.clear()
	_incremental_phase = "BUFFERS"; _incremental_cursor = 0
	return {"ok":true,"phase":_incremental_phase,"total":_manifest.buffers.size(),"complete":false}

func configure_step(max_items: int = 1) -> Dictionary:
	if _incremental_busy or max_items < 1 or max_items > 64 or _incremental_phase in ["NEW", "FAILED", "BUILD", "BUILT", "ROADS", "COMPLETE"]: return {"ok":false,"phase":_incremental_phase,"error":"invalid-step"}
	if _incremental_phase == "READY": return {"ok":true,"phase":"READY","complete":true,"processed":0}
	_incremental_busy = true
	var processed := 0
	var refused := false
	while processed < max_items:
		match _incremental_phase:
			"BUFFERS":
				if _incremental_cursor >= _manifest.buffers.size():
					_incremental_phase = "GEOMETRIES"; _incremental_cursor = 0; continue
				var receipt: Dictionary = _manifest.buffers[_incremental_cursor]
				var sha := str(receipt.get("sha256", ""))
				if not _sha_valid(sha) or str(receipt.get("file", "")) != "buffers/" + sha + ".bin" or _buffers.has(sha): refused = true; break
				var bytes := FileAccess.get_file_as_bytes("res://buffers/" + sha + ".bin")
				if bytes.size() != int(receipt.get("bytes", -1)) or _hash(bytes) != sha: refused = true; break
				_buffers[sha] = bytes
			"GEOMETRIES":
				if _incremental_cursor >= _manifest.geometries.size():
					_incremental_phase = "MATERIALS"; _incremental_cursor = 0; continue
				var geometry: Dictionary = _manifest.geometries[_incremental_cursor]
				if _meshes.has(geometry.id): refused = true; break
				var arrays := _arrays(geometry)
				if arrays.is_empty() or not errors.is_empty(): refused = true; break
				_geometry_arrays[geometry.id] = arrays
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.set_meta("source_geometry", geometry.duplicate(true))
				_meshes[geometry.id] = mesh
			"MATERIALS":
				if _incremental_cursor >= _manifest.materials.size():
					_incremental_phase = "CATALOG"; _incremental_cursor = 0; continue
				var descriptor: Dictionary = _manifest.materials[_incremental_cursor]
				var material := StandardMaterial3D.new()
				material.albedo_color = _color(descriptor.colorLinear).linear_to_srgb()
				material.roughness = float(descriptor.get("roughness", 1.0))
				material.metallic = float(descriptor.get("metalness", 0.0))
				material.emission_enabled = descriptor.emissiveLinear != [0, 0, 0]
				material.emission = _color(descriptor.emissiveLinear).linear_to_srgb()
				material.emission_energy_multiplier = float(descriptor.get("emissiveIntensity", 0.0))
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.cull_mode = BaseMaterial3D.CULL_DISABLED if int(descriptor.side) == 2 else (BaseMaterial3D.CULL_FRONT if int(descriptor.side) == 1 else BaseMaterial3D.CULL_BACK)
				material.albedo_color.a = float(descriptor.opacity)
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if descriptor.transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if descriptor.type == "MeshBasicMaterial" else BaseMaterial3D.SHADING_MODE_PER_PIXEL
				material.set_meta("source_material", descriptor.duplicate(true))
				material.set_meta("native_gpu_parity", "native-importer-color/emission-transfer-proved-render/depth-bias-pending")
				_materials[descriptor.id] = material
			"CATALOG":
				var source_raw := FileAccess.get_file_as_bytes("res://catalog.json")
				var expected_source_sha := ""
				for receipt: Dictionary in _manifest.dependencies:
					if str(receipt.path) == "godot/mafiozi_walk/data/map_editor/catalog.json": expected_source_sha = receipt.sha256
				if _hash(source_raw) != expected_source_sha: refused = true; break
				var catalog: Dictionary = JSON.parse_string(source_raw.get_string_from_utf8())
				_incremental_catalog_rows = catalog.generatedPlans.explorationDecor.objects + catalog.generatedPlans.roadDressing.signs + catalog.generatedPlans.roadDressing.signals + catalog.generatedPlans.roadDressing.markings
				_incremental_phase = "RECORDS"; _incremental_cursor = 0; continue
			"RECORDS":
				if _incremental_cursor >= _incremental_catalog_rows.size():
					_incremental_catalog_rows.clear(); _incremental_phase = "INDEX"; _incremental_cursor = 0; continue
				var source: Dictionary = _incremental_catalog_rows[_incremental_cursor]
				var basis := Basis(Vector3.UP, float(source.get("yaw", 0))).scaled(Vector3.ONE * float(source.get("scale", 1)))
				var frame := Transform3D(basis, Vector3(float(source.x), float(source.y), float(source.z)))
				_source_frames[str(source.id)] = frame
				_current_frames[str(source.id)] = Transform3D(basis, frame.origin - _origin)
				_source_records[str(source.id)] = source.duplicate(true)
			"INDEX":
				if _incremental_cursor >= _manifest.exploration.batches.size() + _manifest.roads.batches.size():
					if _expected_batch_counts.size() != 9394: refused = true
					else: _incremental_phase = "READY"
					break
				var source_batch: Dictionary = _manifest.exploration.batches[_incremental_cursor] if _incremental_cursor < _manifest.exploration.batches.size() else _manifest.roads.batches[_incremental_cursor - _manifest.exploration.batches.size()]
				var unique: Dictionary = {}
				for id in source_batch.objectIds:
					if not _source_records.has(str(id)): refused = true; break
					unique[str(id)] = true
				if refused: break
				for id in unique: _expected_batch_counts[id] = int(_expected_batch_counts.get(id, 0)) + 1
			_: break
		_incremental_cursor += 1; processed += 1
	if refused or (_incremental_phase != "READY" and (not errors.is_empty() or processed == 0)):
		_incremental_busy = false
		return _incremental_fail("Incremental configure source refusal")
	_incremental_busy = false
	return {"ok":true,"phase":_incremental_phase,"cursor":_incremental_cursor,"processed":processed,"complete":_incremental_phase == "READY"}

func begin_exploration() -> Dictionary:
	if _incremental_busy or _incremental_phase != "READY" or not errors.is_empty() or is_instance_valid(_root) or is_instance_valid(_roads_root): return {"ok":false,"error":"not-configured-or-already-built"}
	_root = Node3D.new()
	_root.name = "OriginalExplorationGeometry"
	_root.position = -_origin
	_root.set_meta("gameplay_active", false)
	_parts.clear(); _batched_reset(); initial_upload_calls = 0
	_incremental_phase = "BUILD"; _incremental_cursor = 0
	return {"ok":true,"phase":"BUILD","totalBatches":_manifest.exploration.batches.size(),"renderedIds":0}

func _mark_batch_complete(source_batch: Dictionary) -> void:
	var unique: Dictionary = {}
	for id in source_batch.objectIds: unique[str(id)] = true
	for id in unique: _completed_batch_counts[id] = int(_completed_batch_counts.get(id, 0)) + 1

func source_stage_complete(id: String) -> bool:
	return _expected_batch_counts.has(id) and int(_completed_batch_counts.get(id, 0)) == int(_expected_batch_counts[id]) and _incremental_phase in ["BUILD", "BUILT", "ROADS", "COMPLETE"]

func build_batch_step(max_batches: int = 1) -> Dictionary:
	if _incremental_busy or _incremental_phase != "BUILD" or max_batches < 1 or max_batches > 4: return {"ok":false,"error":"invalid-build-step"}
	if not is_instance_valid(_root) or _root.is_queued_for_deletion() or _root.get_parent() != null: return _incremental_fail("Exploration root lifetime/parent drift")
	_incremental_busy = true
	var processed := 0
	while processed < max_batches and _incremental_cursor < _manifest.exploration.batches.size():
		var batch: Dictionary = _manifest.exploration.batches[_incremental_cursor]
		var chunk_key := str(batch.chunk)
		if not _chunks.has(chunk_key):
			var chunk := Node3D.new()
			chunk.name = chunk_key.validate_node_name()
			_root.add_child(chunk)
			_chunks[chunk_key] = {"node": chunk, "bounds": batch.chunkBounds.duplicate(true), "level": 0, "batches": []}
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[batch.geometry]
		mm.instance_count = int(batch.count)
		var matrices := _float_data(batch.instanceMatrices)
		var colors := _float_data(batch.instanceColors)
		var instance_transforms: Array[Transform3D] = []
		var instance_colors: Array[Color] = []
		var native_buffer := PackedFloat32Array()
		native_buffer.resize(int(batch.count) * 16)
		for index in int(batch.count):
			var transform := _transform(matrices, index * 16)
			var tint := Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2], 1.0)
			var base := index * 16
			for row in 3:
				for column in 4:
					native_buffer[base + row * 4 + column] = matrices[base + column * 4 + row]
			native_buffer[base + 12] = tint.r
			native_buffer[base + 13] = tint.g
			native_buffer[base + 14] = tint.b
			native_buffer[base + 15] = 1.0
			instance_transforms.append(transform)
			instance_colors.append(tint)
			var id := str(batch.objectIds[index])
			if not _parts.has(id): _parts[id] = []
			_parts[id].append({"batch": batch.key, "index": index, "original": transform, "color": tint})
		mm.buffer = native_buffer
		initial_upload_calls += 1
		var node := MultiMeshInstance3D.new()
		node.name = str(batch.key).validate_node_name()
		node.multimesh = mm
		node.material_override = _materials[batch.material]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("source_batch", batch.duplicate(true))
		_chunks[chunk_key].node.add_child(node)
		_chunks[chunk_key].batches.append(batch.key)
		_batches[batch.key] = {"node": node, "mesh": mm, "source": batch, "chunk": chunk_key, "transforms": instance_transforms, "colors": instance_colors, "initial_native_buffer": native_buffer}
		_mark_batch_complete(batch)
		_incremental_cursor += 1; processed += 1
	_incremental_busy = false
	if not errors.is_empty(): return _incremental_fail("Incremental exploration source refusal")
	return {"ok":true,"phase":"BUILD","cursor":_incremental_cursor,"processed":processed,"complete":_incremental_cursor == _manifest.exploration.batches.size(),"renderedIds":0}

func finish_exploration() -> Dictionary:
	if _incremental_busy or _incremental_phase != "BUILD" or _incremental_cursor != 464 or not is_instance_valid(_root) or _root.is_queued_for_deletion() or _root.get_parent() != null or _manifest.exploration.batches.size() != 464 or _batches.size() != 464 or _parts.size() != 2440 or initial_upload_calls != 464 or not errors.is_empty(): return {"ok":false,"error":"incomplete-exploration"}
	_incremental_phase = "BUILT"
	return {"ok":true,"objects":_parts.size(),"batches":_batches.size(),"status":"detached-exploration-stage-only","renderedIds":0}

func begin_roads() -> Dictionary:
	if _incremental_busy or _incremental_phase != "BUILT" or not errors.is_empty() or not is_instance_valid(_root) or _root.is_queued_for_deletion() or _root.get_parent() != null or is_instance_valid(_roads_root) or _manifest.roads.batches.size() != 67: return {"ok":false,"error":"exploration-not-detached-or-road-source-drift"}
	_roads_root = Node3D.new()
	_roads_root.name = "OriginalRoadGeometry"
	_roads_root.position = -_origin
	_roads_root.set_meta("gameplay_active", false)
	road_upload_calls = 0
	_road_ids.clear(); _paint_ids.clear(); _paint_batches.clear()
	_road_cursor = 0; _incremental_phase = "ROADS"
	return {"ok":true,"phase":"ROADS","totalBatches":67,"renderedIds":0}

func build_road_batch_step(max_batches: int = 1) -> Dictionary:
	if _incremental_busy or _incremental_phase != "ROADS" or max_batches < 1 or max_batches > 4: return {"ok":false,"error":"invalid-road-step"}
	if not is_instance_valid(_root) or _root.is_queued_for_deletion() or _root.get_parent() != null or not is_instance_valid(_roads_root) or _roads_root.is_queued_for_deletion() or _roads_root.get_parent() != null: return _incremental_fail("Procedural root lifetime/parent drift")
	_incremental_busy = true
	var processed := 0
	while processed < max_batches and _road_cursor < _manifest.roads.batches.size():
		var source: Dictionary = _manifest.roads.batches[_road_cursor]
		if source.kind == "merged-original-paint":
			var paint := MeshInstance3D.new()
			paint.name = str(source.key).validate_node_name()
			paint.mesh = _meshes[source.geometry]
			paint.material_override = _materials[source.material]
			paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			paint.transform = _transform_array(source.sourceWorldMatrix)
			_roads_root.add_child(paint)
			var arrays: Array = _geometry_arrays[source.geometry]
			_paint_batches[source.key] = {"node": paint, "source": source, "arrays": arrays, "base": arrays[Mesh.ARRAY_VERTEX], "current": arrays[Mesh.ARRAY_VERTEX]}
			for index in source.objectIds.size():
				_paint_ids[str(source.objectIds[index])] = {"batch": source.key, "first": index * 6, "count": 6}
			_mark_batch_complete(source)
			_road_cursor += 1; processed += 1
			continue
		var has_colors: bool = source.has("instanceColors")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = has_colors
		mm.mesh = _meshes[source.geometry]
		mm.instance_count = int(source.count)
		var values := _float_data(source.instanceMatrices)
		var colors := _float_data(source.instanceColors) if has_colors else PackedFloat32Array()
		var stride := 16 if has_colors else 12
		var buffer := PackedFloat32Array()
		buffer.resize(int(source.count) * stride)
		var transforms: Array[Transform3D] = []
		var tints: Array[Color] = []
		for index in int(source.count):
			var transform := _transform(values, index * 16)
			var tint := Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2], 1.0) if has_colors else Color.WHITE
			transforms.append(transform)
			tints.append(tint)
			for row in 3:
				for col in 4:
					buffer[index * stride + row * 4 + col] = values[index * 16 + col * 4 + row]
			if has_colors:
				buffer[index * stride + 12] = tint.r
				buffer[index * stride + 13] = tint.g
				buffer[index * stride + 14] = tint.b
				buffer[index * stride + 15] = 1.0
			var id := str(source.objectIds[index])
			_road_ids[id] = true
			if not _parts.has(id):
				_parts[id] = []
			_parts[id].append({"batch": source.key, "index": index, "original": transform, "color": tint})
		mm.buffer = buffer
		road_upload_calls += 1
		var node := MultiMeshInstance3D.new()
		node.name = str(source.key).validate_node_name()
		node.multimesh = mm
		node.material_override = _materials[source.material]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.transform = _transform_array(source.sourceWorldMatrix)
		_roads_root.add_child(node)
		_batches[source.key] = {"node": node, "mesh": mm, "source": source, "chunk": "", "transforms": transforms, "colors": tints, "initial_native_buffer": buffer, "stride": stride}
		_recompute_road_bounds(source.key)
		_mark_batch_complete(source)
		_road_cursor += 1; processed += 1
	_incremental_busy = false
	if not errors.is_empty(): return _incremental_fail("Incremental road source refusal")
	return {"ok":true,"phase":"ROADS","cursor":_road_cursor,"processed":processed,"complete":_road_cursor == 67,"renderedIds":0}

func finish_all() -> Dictionary:
	if _incremental_busy or _incremental_phase != "ROADS" or _road_cursor != 67 or not is_instance_valid(_root) or not is_instance_valid(_roads_root) or _root.is_queued_for_deletion() or _roads_root.is_queued_for_deletion() or _root.get_parent() != null or _roads_root.get_parent() != null or _parts.size() != 2945 or _road_ids.size() != 505 or _paint_ids.size() != 6449 or _paint_batches.size() != 59 or _batches.size() != 472 or initial_upload_calls != 464 or road_upload_calls != 8 or _expected_batch_counts.size() != 9394 or _completed_batch_counts.size() != 9394 or not errors.is_empty(): return {"ok":false,"error":"incomplete-procedural-closure"}
	for id in _expected_batch_counts:
		if not source_stage_complete(str(id)): return {"ok":false,"error":"incomplete-source-id:" + str(id)}
	_incremental_phase = "COMPLETE"
	return {"ok":true,"explorationRoot":_root,"roadsRoot":_roads_root,"geometryReadyIds":9394,"renderedIds":0,"status":"detached-native-procedural-geometry-only","pending":["source-collider-navigation-traffic-owner","native-road-visual-policy","GPU-material-depth-parity","editor-atomic-publication"]}

func build_exploration() -> Dictionary:
	return {"ok":false,"status":"use-incremental-exploration"}

func build_roads() -> Dictionary:
	return {"ok":false,"status":"use-incremental-road-batches"}

func update_lod(focus_native: Vector3) -> Dictionary:
	return super.update_lod(focus_native) if _incremental_phase == "COMPLETE" else {"ok":false,"error":"incomplete-procedural-geometry"}

func set_object_transform(id: String, frame_native: Transform3D) -> bool:
	return super.set_object_transform(id, frame_native) if _incremental_phase == "COMPLETE" else false

func delete_object(id: String) -> bool:
	return super.delete_object(id) if _incremental_phase == "COMPLETE" else false

func undo() -> bool:
	return super.undo() if _incremental_phase == "COMPLETE" else false

func redo() -> bool:
	return super.redo() if _incremental_phase == "COMPLETE" else false
