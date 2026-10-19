extends RefCounted
## Source-exact exploration/road geometry consumer. No gameplay authority.
var _manifest: Dictionary = {}
var _buffers: Dictionary = {}
var _geometry_arrays: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _parts: Dictionary = {}
var _chunks: Dictionary = {}
var _source_frames: Dictionary = {}
var _current_frames: Dictionary = {}
var _deleted: Dictionary = {}
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _root: Node3D
var _origin := Vector3.ZERO
var errors: Array[String] = []
var last_changed_instances := 0
var initial_upload_calls := 0
var road_upload_calls := 0
var _road_adapter := Callable()
var _road_ids: Dictionary = {}
var _source_records: Dictionary = {}
var _paint_ids: Dictionary = {}
var _paint_batches: Dictionary = {}
var _roads_root: Node3D

func configure(expected_sha: String, trusted_road_adapter: Callable = Callable()) -> bool:
	errors.clear()
	if not _sha_valid(expected_sha):
		return _error("Host SHA admission required")
	var raw := FileAccess.get_file_as_bytes("res://manifest.json")
	if _hash(raw) != expected_sha:
		return _error("Manifest changed")
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not decoded is Dictionary or decoded.get("schema", "") != "mafiozi.godot.map-editor-procedural-source/v1" or str(decoded.get("threeRevision", "")) != "180":
		return _error("Unsupported source manifest")
	_manifest = decoded
	_road_adapter = trusted_road_adapter
	var contract: Dictionary = _manifest.coordinateContract
	if not _vector_valid(contract.get("originM", null)) or float(contract.get("metresPerCell", 0)) != 4.1:
		return _error("Invalid native coordinate contract")
	_origin = _v3(contract.originM)
	_buffers.clear()
	for receipt: Dictionary in _manifest.buffers:
		var sha := str(receipt.get("sha256", ""))
		if not _sha_valid(sha) or str(receipt.get("file", "")) != "buffers/" + sha + ".bin" or _buffers.has(sha):
			return _error("Unsafe/duplicate buffer receipt")
		var bytes := FileAccess.get_file_as_bytes("res://buffers/" + sha + ".bin")
		if bytes.size() != int(receipt.get("bytes", -1)) or _hash(bytes) != sha:
			return _error("Buffer SHA/size changed")
		_buffers[sha] = bytes
	_geometry_arrays.clear()
	_meshes.clear()
	for geometry: Dictionary in _manifest.geometries:
		if _meshes.has(geometry.id):
			return _error("Duplicate geometry")
		var arrays := _arrays(geometry)
		if arrays.is_empty():
			return false
		_geometry_arrays[geometry.id] = arrays
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.set_meta("source_geometry", geometry.duplicate(true))
		_meshes[geometry.id] = mesh
	_materials.clear()
	for descriptor: Dictionary in _manifest.materials:
		var material := StandardMaterial3D.new()
		# Match actual Godot glTF importer: resource albedo is sRGB-encoded;
		# the original source descriptor and instance colors remain linear.
		material.albedo_color = _color(descriptor.colorLinear).linear_to_srgb()
		material.roughness = float(descriptor.get("roughness", 1.0))
		material.metallic = float(descriptor.get("metalness", 0.0))
		material.emission_enabled = descriptor.emissiveLinear != [0, 0, 0]
		material.emission = _color(descriptor.emissiveLinear).linear_to_srgb()
		material.emission_energy_multiplier = float(descriptor.get("emissiveIntensity", 0.0))
		material.vertex_color_use_as_albedo = true # Source instance tint, not new art.
		material.vertex_color_is_srgb = false # Source Float32 RGB is already linear.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED if int(descriptor.side) == 2 else (BaseMaterial3D.CULL_FRONT if int(descriptor.side) == 1 else BaseMaterial3D.CULL_BACK)
		material.albedo_color.a = float(descriptor.opacity)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if descriptor.transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if descriptor.type == "MeshBasicMaterial" else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.set_meta("source_material", descriptor.duplicate(true))
		material.set_meta("native_gpu_parity", "native-importer-color/emission-transfer-proved-render/depth-bias-pending")
		_materials[descriptor.id] = material
	var source_raw := FileAccess.get_file_as_bytes("res://catalog.json")
	var expected_source_sha := ""
	for receipt: Dictionary in _manifest.dependencies:
		if str(receipt.path) == "godot/mafiozi_walk/data/map_editor/catalog.json":
			expected_source_sha = receipt.sha256
	if _hash(source_raw) != expected_source_sha:
		return _error("Source object frame receipt changed")
	var catalog: Dictionary = JSON.parse_string(source_raw.get_string_from_utf8())
	_source_frames.clear()
	_current_frames.clear()
	var all_records: Array = catalog.generatedPlans.explorationDecor.objects + catalog.generatedPlans.roadDressing.signs + catalog.generatedPlans.roadDressing.signals + catalog.generatedPlans.roadDressing.markings
	_source_records.clear()
	for source: Dictionary in all_records:
		var basis := Basis(Vector3.UP, float(source.get("yaw", 0))).scaled(Vector3.ONE * float(source.get("scale", 1)))
		var frame := Transform3D(basis, Vector3(float(source.x), float(source.y), float(source.z)))
		_source_frames[str(source.id)] = frame
		_current_frames[str(source.id)] = Transform3D(basis, frame.origin - _origin)
		_source_records[str(source.id)] = source.duplicate(true)
	return errors.is_empty()

func build_roads() -> Dictionary:
	if not errors.is_empty() or _manifest.is_empty() or is_instance_valid(_roads_root):
		return {"ok": false, "status": "not-configured-or-already-built"}
	_roads_root = Node3D.new()
	_roads_root.name = "OriginalRoadGeometry"
	_roads_root.position = -_origin
	_roads_root.set_meta("gameplay_active", false)
	road_upload_calls = 0
	for source: Dictionary in _manifest.roads.batches:
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
	return {"ok": true, "root": _roads_root, "status": "native-road-geometry-only-authority-locked", "controls": _road_ids.size(), "markings": _paint_ids.size(), "batches": _manifest.roads.batches.size(), "pending": ["traffic/nav/collider-author-adapter", "native-phase-runtime", "source-equipment-bucket-range-culling", "native-paint-polygon-offset-GPU-equivalence"]}

func resolve_part(batch_key: String, index: int) -> String:
	if not _batches.has(batch_key) or index < 0 or index >= _batches[batch_key].source.objectIds.size():
		return ""
	return str(_batches[batch_key].source.objectIds[index])

func resolve_paint_vertex(batch_key: String, vertex: int) -> String:
	if not _paint_batches.has(batch_key) or vertex < 0:
		return ""
	var source: Dictionary = _paint_batches[batch_key].source
	var index := floori(float(vertex) / 6.0)
	return str(source.objectIds[index]) if index < source.objectIds.size() else ""

func build_exploration() -> Dictionary:
	if not errors.is_empty() or _manifest.is_empty() or is_instance_valid(_root) or is_instance_valid(_roads_root):
		return {"ok": false, "status": "not-configured-or-already-built"}
	_root = Node3D.new()
	_root.name = "OriginalExplorationGeometry"
	_root.position = -_origin
	_root.set_meta("gameplay_active", false)
	_parts.clear()
	_batched_reset()
	initial_upload_calls = 0
	for batch: Dictionary in _manifest.exploration.batches:
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
			# Official 3D+color layout is row-major12 transform floats+RGBA4.
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
			if not _parts.has(id):
				_parts[id] = []
			_parts[id].append({"batch": batch.key, "index": index, "original": transform, "color": tint})
		mm.buffer = native_buffer #464 whole uploads instead of57,436 setter calls.
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
	return {"ok": true, "root": _root, "status": "native-exploration-geometry-only", "objects": _parts.size(), "batches": _batches.size(), "geometries": _meshes.size(), "materials": _materials.size(), "pending": ["roads/traffic/markings-native-consumer", "native-shader-GPU-parity", "source-collider/navigation/gameplay-authority"]}

func update_lod(focus_native: Vector3) -> Dictionary:
	var focus := focus_native + _origin
	var levels := [0, 0, 0]
	var policy: Dictionary = _manifest.exploration.lodPolicy
	var near := float(policy.near)
	var far := float(policy.far)
	var hysteresis := float(policy.hysteresis)
	for chunk: Dictionary in _chunks.values():
		var bounds: Dictionary = chunk.bounds
		var dx := maxf(float(bounds.minX) - focus.x, maxf(0.0, focus.x - float(bounds.maxX)))
		var dz := maxf(float(bounds.minZ) - focus.z, maxf(0.0, focus.z - float(bounds.maxZ)))
		var distance := Vector2(dx, dz).length()
		chunk.node.visible = distance <= float(policy.maxDistance)
		if not chunk.node.visible:
			continue
		var previous := int(chunk.level)
		var level := 0 if distance <= near else (2 if distance > far + hysteresis else (0 if previous == 0 and distance <= near + hysteresis else (2 if previous == 2 and distance > far else 1)))
		if level != previous:
			for batch_key in chunk.batches:
				var batch: Dictionary = _batches[batch_key]
				for prototype: Dictionary in _manifest.exploration.prototypes:
					if prototype.shape == batch.source.shape and int(prototype.lod) == level:
						batch.mesh.mesh = _meshes[prototype.geometry]
			chunk.level = level
		levels[level] += 1
	return {"levels": levels, "visibleChunks": levels[0] + levels[1] + levels[2]}

func object_transform(id: String) -> Transform3D:
	return _current_frames.get(id, Transform3D.IDENTITY)

func set_object_transform(id: String, frame_native: Transform3D) -> bool:
	if not frame_native.is_finite() or frame_native.basis.determinant() <= 0.000001:
		return false
	if _paint_ids.has(id):
		if not frame_native.basis.y.normalized().is_equal_approx(Vector3.UP):
			return false
		return _paint_commit(id, frame_native, false)
	if not _parts.has(id):
		return false
	var source_frame: Transform3D = _source_frames[id]
	var desired_source := Transform3D(frame_native.basis, frame_native.origin + _origin)
	var delta := desired_source * source_frame.affine_inverse()
	var transforms: Array[Transform3D] = []
	for part: Dictionary in _parts[id]:
		transforms.append(delta * part.original)
	return _commit(id, transforms, false, frame_native)

func delete_object(id: String) -> bool:
	if _paint_ids.has(id):
		return _paint_commit(id, _current_frames[id], true)
	if not _parts.has(id):
		return false
	var transforms: Array[Transform3D] = []
	for part: Dictionary in _parts[id]:
		transforms.append(Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), part.original.origin))
	return _commit(id, transforms, true, _current_frames[id])

func undo() -> bool:
	if _history.is_empty():
		return false
	var command: Dictionary = _history.back()
	if not _perform(command, false, "undo"):
		return false
	_history.pop_back()
	_deleted[command.id] = command.deletedBefore
	_current_frames[command.id] = command.frameBefore
	_redo.append(command)
	return true

func redo() -> bool:
	if _redo.is_empty():
		return false
	var command: Dictionary = _redo.back()
	if not _perform(command, true, "redo"):
		return false
	_redo.pop_back()
	_deleted[command.id] = command.deletedAfter
	_current_frames[command.id] = command.frameAfter
	_history.append(command)
	return true

func _commit(id: String, after: Array[Transform3D], deleted: bool, frame: Transform3D) -> bool:
	var before: Array[Transform3D] = []
	for part: Dictionary in _parts[id]:
		before.append(_batches[part.batch].transforms[part.index])
	var command := {"kind": "instances", "id": id, "before": before, "after": after, "deletedBefore": _deleted.get(id, false), "deletedAfter": deleted, "frameBefore": _current_frames[id], "frameAfter": frame}
	if not _perform(command, true, "delete" if deleted else "transform"):
		return false
	_deleted[id] = deleted
	_current_frames[id] = frame
	_history.append(command)
	_redo.clear()
	return true

func _paint_commit(id: String, frame: Transform3D, deleted: bool) -> bool:
	if not _road_adapter.is_valid():
		return false
	var part: Dictionary = _paint_ids[id]
	var batch: Dictionary = _paint_batches[part.batch]
	var vertices: PackedVector3Array = batch.current.duplicate()
	var delta := Transform3D(frame.basis, frame.origin + _origin) * (_source_frames[id] as Transform3D).affine_inverse()
	for index in range(int(part.first), int(part.first) + 6):
		vertices[index] = (_source_frames[id] as Transform3D).origin if deleted else delta * batch.base[index]
	var arrays: Array = batch.arrays.duplicate(true)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var replacement := ArrayMesh.new()
	replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	replacement.set_meta("source_geometry", _meshes[batch.source.geometry].get_meta("source_geometry"))
	var command := {"kind": "paint", "id": id, "batch": part.batch, "before": batch.current, "after": vertices, "meshBefore": batch.node.mesh, "meshAfter": replacement, "deletedBefore": _deleted.get(id, false), "deletedAfter": deleted, "frameBefore": _current_frames[id], "frameAfter": frame}
	if not _perform(command, true, "delete" if deleted else "transform"):
		return false
	_deleted[id] = deleted
	_current_frames[id] = frame
	_history.append(command)
	_redo.clear()
	return true

func _perform(command: Dictionary, forward: bool, operation: String) -> bool:
	var road := _road_ids.has(command.id) or _paint_ids.has(command.id)
	var admission: Dictionary = {}
	if road:
		if not _road_adapter.is_valid():
			return false
		var prepared: Variant = _road_adapter.call({"sourceId": command.id, "sourceRecord": _source_records[command.id].duplicate(true), "operation": operation, "frameBefore": _current_frames[command.id], "frameAfter": command.frameAfter if forward else command.frameBefore, "deletedAfter": command.deletedAfter if forward else command.deletedBefore, "geometryOnly": true})
		if not prepared is Dictionary or prepared.get("approved", false) != true:
			return false
		admission = prepared
		if not admission.get("commit", null) is Callable or not admission.commit.is_valid() or not admission.get("rollback", null) is Callable or not admission.rollback.is_valid():
			return false
	_apply_command(command, forward)
	if road and admission.commit.call() != true:
		_apply_command(command, not forward)
		admission.rollback.call()
		return false
	return true

func _apply_command(command: Dictionary, forward: bool) -> void:
	if command.kind == "paint":
		var batch: Dictionary = _paint_batches[command.batch]
		batch.current = command.after if forward else command.before
		batch.node.mesh = command.meshAfter if forward else command.meshBefore
		last_changed_instances = 6
	else:
		_apply(command.id, command.after if forward else command.before)

func _apply(id: String, transforms: Array) -> void:
	last_changed_instances = 0
	var dirty_chunks: Dictionary = {}
	var dirty_roads: Dictionary = {}
	for index in _parts[id].size():
		var part: Dictionary = _parts[id][index]
		var batch: Dictionary = _batches[part.batch]
		batch.mesh.set_instance_transform(part.index, transforms[index])
		batch.transforms[part.index] = transforms[index]
		if not str(batch.chunk).is_empty():
			dirty_chunks[batch.chunk] = true
		else:
			dirty_roads[part.batch] = true
		last_changed_instances += 1
	for chunk_key in dirty_chunks:
		_recompute_bounds(chunk_key)
	for batch_key in dirty_roads:
		_recompute_road_bounds(batch_key)

func _recompute_road_bounds(batch_key: String) -> void:
	var batch: Dictionary = _batches[batch_key]
	var box := AABB()
	var first := true
	for transform: Transform3D in batch.transforms:
		if absf(transform.basis.determinant()) <= 0.0000001:
			continue
		var instance_box: AABB = transform * _meshes[batch.source.geometry].get_aabb()
		box = instance_box if first else box.merge(instance_box)
		first = false
	batch.mesh.custom_aabb = box

func _recompute_bounds(chunk_key: String) -> void:
	var chunk: Dictionary = _chunks[chunk_key]
	var base: Dictionary = _batches[chunk.batches[0]].source.chunkBounds
	var bounds := base.duplicate(true) # Never shrink the original conservative grid envelope.
	for key in chunk.batches:
		var batch: Dictionary = _batches[key]
		var box := AABB()
		var first := true
		for index in batch.mesh.instance_count:
			var transform: Transform3D = batch.transforms[index]
			if absf(transform.basis.determinant()) <= 0.0000001:
				continue
			var instance_box: AABB = transform * _meshes[batch.source.geometry].get_aabb()
			box = instance_box if first else box.merge(instance_box)
			first = false
		if not first:
			batch.mesh.custom_aabb = box
			bounds.minX = minf(float(bounds.minX), box.position.x)
			bounds.maxX = maxf(float(bounds.maxX), box.end.x)
			bounds.minZ = minf(float(bounds.minZ), box.position.z)
			bounds.maxZ = maxf(float(bounds.maxZ), box.end.z)
	chunk.bounds = bounds

func _arrays(geometry: Dictionary) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var attributes: Dictionary = geometry.attributes
	if not attributes.has("position"):
		_error("Missing vertices")
		return []
	arrays[Mesh.ARRAY_VERTEX] = _vectors3(_float_data(attributes.position))
	if attributes.has("normal"):
		arrays[Mesh.ARRAY_NORMAL] = _vectors3(_float_data(attributes.normal))
	if attributes.has("uv"):
		arrays[Mesh.ARRAY_TEX_UV] = _vectors2(_float_data(attributes.uv))
	if attributes.has("uv2"):
		arrays[Mesh.ARRAY_TEX_UV2] = _vectors2(_float_data(attributes.uv2))
	var indices := PackedInt32Array()
	if geometry.index != null:
		var descriptor: Dictionary = geometry.index
		var raw: PackedByteArray = _buffers[descriptor.buffer]
		for index in int(descriptor.count):
			indices.append(raw.decode_u16(index * 2) if descriptor.arrayType == "Uint16Array" else raw.decode_u32(index * 4))
	else:
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			indices.append(index)
	if indices.size() % 3 != 0:
		_error("Nontriangle source range")
		return []
	# Source Three front winding CCW -> native Godot front winding CW. Vertex
	# normals, UV and original Float32 positions are not normalized or modified.
	for index in range(0, indices.size(), 3):
		var second := indices[index + 1]
		indices[index + 1] = indices[index + 2]
		indices[index + 2] = second
	arrays[Mesh.ARRAY_INDEX] = indices
	# Single original material per batch => original groups do NOT cause extra
	# submissions. Group/draw-range metadata is retained, never silently dropped.
	return arrays

func _float_data(descriptor: Dictionary) -> PackedFloat32Array:
	if descriptor.arrayType != "Float32Array" or not _buffers.has(descriptor.buffer):
		_error("Unsupported attribute type")
		return PackedFloat32Array()
	return (_buffers[descriptor.buffer] as PackedByteArray).to_float32_array()

func _vectors3(values: PackedFloat32Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in range(0, values.size(), 3):
		result.append(Vector3(values[index], values[index + 1], values[index + 2]))
	return result

func _vectors2(values: PackedFloat32Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(0, values.size(), 2):
		result.append(Vector2(values[index], values[index + 1]))
	return result

func _transform(values: PackedFloat32Array, offset: int) -> Transform3D:
	return Transform3D(Basis(Vector3(values[offset], values[offset + 1], values[offset + 2]), Vector3(values[offset + 4], values[offset + 5], values[offset + 6]), Vector3(values[offset + 8], values[offset + 9], values[offset + 10])), Vector3(values[offset + 12], values[offset + 13], values[offset + 14]))

func _transform_array(values: Array) -> Transform3D:
	return _transform(PackedFloat32Array(values), 0)

func _batched_reset() -> void:
	_batches.clear()
	_chunks.clear()
	_history.clear()
	_redo.clear()
	_deleted.clear()

func _color(value: Array) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]), 1.0)

func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _vector_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not typeof(component) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
			return false
	return true

func _sha_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

func _hash(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()

func _error(message: String) -> bool:
	errors.append(message)
	return false
