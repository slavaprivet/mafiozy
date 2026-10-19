extends SceneTree
const Factory = preload("res://scripts/procedural_factory.gd")
const EXPECTED_SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array[String] = []
var failure_counts: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var factory := Factory.new()
	_expect(factory.configure(EXPECTED_SHA), "SHA admitted buffers/materials")
	if not factory.errors.is_empty():
		print("NATIVE_SOURCE_ERRORS ", factory.errors)
		quit(1)
		return
	var result: Dictionary = factory.build_exploration()
	_expect(result.ok and result.objects == 2440 and result.batches == 464, "all exploration object slots imported")
	var imported_root: Node3D = result.root
	get_root().add_child(imported_root)
	_expect(factory._buffers.size() == 982 and factory._meshes.size() == 86 and factory._materials.size() == 10, "all original resource counts")
	var vertices := 0
	var normals_decode_max_error := 0.0
	var normal_sample: Dictionary = {}
	var normalized_direction_max_error := 0.0
	var zero_source_normals := 0
	for descriptor: Dictionary in factory._manifest.geometries:
		var arrays: Array = factory._geometry_arrays[descriptor.id]
		var source: PackedByteArray = factory._buffers[descriptor.attributes.position.buffer]
		_expect((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array() == source, "exact source Float32 positions")
		vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if descriptor.attributes.has("normal"):
			_expect((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array() == factory._buffers[descriptor.attributes.normal.buffer], "exact source normal input bytes")
		if descriptor.attributes.has("uv"):
			_expect((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).to_byte_array() == factory._buffers[descriptor.attributes.uv.buffer], "exact source UV input bytes")
		var mesh: ArrayMesh = factory._meshes[descriptor.id]
		var native: Array = mesh.surface_get_arrays(0)
		_expect((native[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array() == source, "native surface positions remain exact")
		if descriptor.attributes.has("normal"):
			var before: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var after: PackedVector3Array = native[Mesh.ARRAY_NORMAL]
			for index in before.size():
				var difference := before[index].distance_to(after[index])
				if difference > normals_decode_max_error:
					normals_decode_max_error = difference
					normal_sample = {"geometry": descriptor.label, "source": str(before[index]), "native": str(after[index])}
				if before[index].length_squared() < 0.0000000001:
					zero_source_normals += 1
				else:
					normalized_direction_max_error = maxf(normalized_direction_max_error, before[index].normalized().distance_to(after[index].normalized()))
		var flipped: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var source_indices: PackedInt32Array = []
		if descriptor.index != null:
			var index_bytes: PackedByteArray = factory._buffers[descriptor.index.buffer]
			for index in int(descriptor.index.count):
				source_indices.append(index_bytes.decode_u16(index * 2) if descriptor.index.arrayType == "Uint16Array" else index_bytes.decode_u32(index * 4))
		else:
			for index in arrays[Mesh.ARRAY_VERTEX].size():
				source_indices.append(index)
		for index in range(0, flipped.size(), 3):
			_expect(flipped[index] == source_indices[index] and flipped[index + 1] == source_indices[index + 2] and flipped[index + 2] == source_indices[index + 1], "native winding corrected without vertex loss")
	var parts := 0
	for batch: Dictionary in factory._batches.values():
		var source: Dictionary = batch.source
		var values := factory._float_data(source.instanceMatrices)
		var colors := factory._float_data(source.instanceColors)
		_expect(batch.node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "original exploration shadow-off retained")
		for index in batch.mesh.instance_count:
			var submitted: Transform3D = batch.transforms[index]
			_expect(submitted == factory._transform(values, index * 16), "exact native MultiMesh transform submission input")
			_expect(batch.colors[index] == Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2], 1.0), "exact native MultiMesh linear color submission input")
			for row in 3:
				for column in 4:
					_expect(batch.initial_native_buffer[index * 16 + row * 4 + column] == values[index * 16 + column * 4 + row], "native row-major bulk transform exact")
			_expect(batch.initial_native_buffer[index * 16 + 12] == colors[index * 3] and batch.initial_native_buffer[index * 16 + 13] == colors[index * 3 + 1] and batch.initial_native_buffer[index * 16 + 14] == colors[index * 3 + 2] and batch.initial_native_buffer[index * 16 + 15] == 1.0, "native bulk RGB-linear color exact")
			parts += 1
	_expect(parts == 28718, "all original individual parts retained")
	_expect(factory.initial_upload_calls == 464, "only464 shared batch uploads, not57436 per-part setters")
	var mesh_ids: Dictionary = {}
	var mm_ids: Dictionary = {}
	for key in factory._batches:
		mesh_ids[key] = factory._batches[key].mesh.mesh.get_instance_id()
		mm_ids[key] = factory._batches[key].mesh.get_instance_id()
	var id: String = factory._parts.keys()[0]
	var original_parts: Array[Transform3D] = []
	for part: Dictionary in factory._parts[id]:
		original_parts.append(factory._batches[part.batch].transforms[part.index])
	var original_frame := factory.object_transform(id)
	var moved := original_frame
	moved.origin += Vector3(11, 2, -7)
	_expect(factory.set_object_transform(id, moved), "original object move")
	_expect(factory.last_changed_instances == factory._parts[id].size(), "only selected part indices changed")
	_expect(factory.undo(), "move undo")
	for index in original_parts.size():
		var part: Dictionary = factory._parts[id][index]
		_expect(factory._batches[part.batch].transforms[part.index] == original_parts[index], "undo source instance transform input exact")
	_expect(factory.delete_object(id), "original object delete")
	_expect(factory.undo(), "delete undo")
	for key in factory._batches:
		_expect(factory._batches[key].mesh.mesh.get_instance_id() == mesh_ids[key] and factory._batches[key].mesh.get_instance_id() == mm_ids[key], "undo reuses exact same geometry/MultiMesh resources")
	_expect(not factory.delete_object("forged") and not factory.set_object_transform("forged", Transform3D.IDENTITY), "unadmitted IDs cannot edit")
	var rejected := Factory.new()
	_expect(not rejected.configure("../../private"), "unsafe manifest admission rejected")
	var lod_factory := Factory.new()
	_expect(lod_factory.configure(EXPECTED_SHA), "fresh LOD oracle factory")
	var lod_result: Dictionary = lod_factory.build_exploration()
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://lod_oracle.json"))
	for sample: Dictionary in oracle.samples:
		lod_factory.update_lod(lod_factory._v3(sample.focusNative))
		for key in lod_factory._chunks:
			var chunk: Dictionary = lod_factory._chunks[key]
			var expected: Dictionary = sample.chunks[key]
			_expect(chunk.level == expected.level and chunk.node.visible == expected.visible, "all original chunk LOD/visibility source oracle states")
	lod_result.root.free()
	var original_materials := 0
	for descriptor: Dictionary in factory._manifest.materials:
		var material: StandardMaterial3D = factory._materials[descriptor.id]
		_expect(material.albedo_color.is_equal_approx(factory._color(descriptor.colorLinear).linear_to_srgb()), "material albedo follows verified native GLTF linear-to-sRGB contract")
		_expect(is_equal_approx(material.roughness, float(descriptor.roughness)) and is_equal_approx(material.metallic, float(descriptor.metalness)), "original material roughness/metal stored")
		original_materials += 1
	print("MAP_EDITOR_PROCEDURAL_NATIVE_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "geometries": 86, "sourceVertices": vertices, "buffers": 982, "materials": original_materials, "objects": 2440, "partInstances": parts, "batches": 464, "maxNativeNormalDecodeError": normals_decode_max_error, "normalSample": normal_sample, "maxNormalizedNormalDirectionError": normalized_direction_max_error, "zeroSourceNormals": zero_source_normals, "scope": "exploration-only native geometry+exact submission CPU inputs; headless Dummy MultiMesh GPU storage unavailable; GPU shader/material parity and roads/physics/gameplay pending", "failures": failures, "failureCounts": failure_counts}))
	imported_root.free()
	quit(0 if failures.is_empty() else 1)

func _expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failure_counts[description] = int(failure_counts.get(description, 0)) + 1
		if not description in failures:
			failures.append(description)
