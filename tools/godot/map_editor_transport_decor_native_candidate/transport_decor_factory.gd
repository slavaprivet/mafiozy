extends RefCounted
## Separate companion consumer. No scene scripts or user-selected resources load.
## Native geometry/resources only; runtime owners must admit all edits/motion.
const SCHEMA := "mafiozi.godot.map-editor-transport-decor-source/v1"
var _manifest: Dictionary = {}
var _buffers: Dictionary = {}
var _meshes: Dictionary = {}
var _arrays: Dictionary = {}
var _materials: Dictionary = {}
var _material_descriptors: Dictionary = {}
var _records: Dictionary = {}
var _source_frames: Dictionary = {}
var _current: Dictionary = {}
var _parts: Dictionary = {}
var _batches: Dictionary = {}
var _roots: Dictionary = {}
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _hooks: Dictionary = {}
var _origin := Vector3.ZERO
var _source_dir := ""
var _source_sha := ""
var _broken_transaction := false
var _train_roots: Array[Node3D] = []
var _motion_metadata: Dictionary = {}
var last_changed_parts := 0
var initial_uploads := 0
var errors: Array[String] = []

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _sha_valid(value: String) -> bool:
	if value.length() != 64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Variant, size: int = 3) -> bool:
	if not value is Array or value.size() != size: return false
	for number in value:
		if not _number(number): return false
	return true

static func _readonly(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values(): _readonly(item)
		value.make_read_only()
	elif value is Array:
		for item in value: _readonly(item)
		value.make_read_only()

func configure(source_dir: String, expected_sha: String, trusted_hooks: Dictionary = {}) -> Dictionary:
	if not _roots.is_empty(): return _failure("Dispose native scene before reconfiguration")
	if not _sha_valid(expected_sha): return _failure("Host manifest SHA admission required")
	var raw := FileAccess.get_file_as_bytes(source_dir.path_join("manifest.json"))
	if _hash(raw) != expected_sha: return _failure("Source manifest SHA mismatch")
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not decoded is Dictionary or decoded.get("schema") != SCHEMA or str(decoded.get("threeRevision")) != "180": return _failure("Unsupported source manifest")
	if not _vector(decoded.coordinateContract.originM) or decoded.coordinateContract.metresPerCell != 4.1: return _failure("Unsafe source coordinate contract")
	# Admit all checksummed buffers before any mesh/material or scene mutation.
	var admitted := {}
	for receipt in decoded.buffers:
		if not receipt is Dictionary or not _sha_valid(str(receipt.get("sha256"))) or receipt.get("file") != "buffers/" + str(receipt.sha256) + ".bin" or admitted.has(receipt.sha256): return _failure("Unsafe or duplicate buffer path")
		var bytes := FileAccess.get_file_as_bytes(source_dir.path_join(receipt.file))
		if bytes.size() != int(receipt.bytes) or _hash(bytes) != receipt.sha256: return _failure("Source buffer SHA mismatch")
		admitted[receipt.sha256] = bytes
	_manifest = decoded
	_buffers = admitted
	_source_dir = source_dir
	_source_sha = expected_sha
	_hooks = trusted_hooks.duplicate()
	_origin = Vector3(decoded.coordinateContract.originM[0], decoded.coordinateContract.originM[1], decoded.coordinateContract.originM[2])
	_records.clear()
	_source_frames.clear()
	_current.clear()
	for record: Dictionary in _manifest.semanticObjects:
		if _records.has(record.key): return _failure("Duplicate semantic source identity")
		_records[record.key] = record.duplicate(true)
		var source: Dictionary = record.sourceRecord
		var proxy: Dictionary = source.get("proxy", {})
		var x := float(source.get("x", proxy.get("x", 0)))
		var z := float(source.get("z", proxy.get("z", 0)))
		var y := float(source.get("y", 0))
		var frame := Transform3D(Basis(Vector3.UP, float(source.get("yaw", 0))), Vector3(x, y, z))
		_source_frames[record.key] = frame
		_current[record.key] = {"frame": Transform3D(frame.basis, frame.origin - _origin), "deleted": false}
	_meshes.clear()
	_arrays.clear()
	errors.clear()
	for geometry: Dictionary in _manifest.geometries:
		var data := _geometry_arrays(geometry)
		if data.is_empty(): return _failure("Invalid source geometry: " + geometry.id)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
		mesh.set_meta("source_geometry", geometry.duplicate(true))
		_meshes[geometry.id] = mesh
		_arrays[geometry.id] = data
	_materials.clear()
	_material_descriptors.clear()
	for descriptor: Dictionary in _manifest.materials:
		_material_descriptors[descriptor.id] = descriptor.duplicate(true)
		if descriptor.textureBindings.is_empty(): _materials[descriptor.id] = _make_material(descriptor)
	_history.clear()
	_redo.clear()
	_broken_transaction = false
	_motion_metadata = _manifest.railway.sourcePlan.duplicate(true)
	_readonly(_motion_metadata)
	return {"ok": true, "objects": _records.size(), "meshes": _meshes.size(), "materials": _materials.size(), "status": "native-resource-CPU-only"}

func _float_data(descriptor: Dictionary) -> PackedFloat32Array:
	if descriptor.get("arrayType") != "Float32Array" or not _buffers.has(descriptor.get("buffer")) or int(descriptor.get("itemSize", 0)) < 1:
		errors.append("Unsupported float source attribute")
		return PackedFloat32Array()
	var raw: PackedByteArray = _buffers[descriptor.buffer]
	if raw.size() != int(descriptor.count) * int(descriptor.itemSize) * 4:
		errors.append("Float source attribute capacity mismatch")
		return PackedFloat32Array()
	return raw.to_float32_array()

func _geometry_arrays(geometry: Dictionary) -> Array:
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	var attributes: Dictionary = geometry.attributes
	if not attributes.has("position"): return []
	for row in [["position", Mesh.ARRAY_VERTEX], ["normal", Mesh.ARRAY_NORMAL]]:
		if not attributes.has(row[0]): continue
		var values := _float_data(attributes[row[0]])
		if values.is_empty() or values.size() % 3 != 0: return []
		var vectors := PackedVector3Array()
		for index in range(0, values.size(), 3): vectors.append(Vector3(values[index], values[index + 1], values[index + 2]))
		result[row[1]] = vectors
	for row in [["uv", Mesh.ARRAY_TEX_UV], ["uv2", Mesh.ARRAY_TEX_UV2]]:
		if not attributes.has(row[0]): continue
		var values := _float_data(attributes[row[0]])
		if values.size() % 2 != 0: return []
		var vectors := PackedVector2Array()
		for index in range(0, values.size(), 2): vectors.append(Vector2(values[index], values[index + 1]))
		result[row[1]] = vectors
	if attributes.has("color"):
		var values := _float_data(attributes.color)
		var stride: int = attributes.color.itemSize
		if stride not in [3, 4]: return []
		var colors := PackedColorArray()
		for index in range(0, values.size(), stride): colors.append(Color(values[index], values[index + 1], values[index + 2], values[index + 3] if stride == 4 else 1.0))
		result[Mesh.ARRAY_COLOR] = colors
	var indices := PackedInt32Array()
	if geometry.index != null:
		var descriptor: Dictionary = geometry.index
		if not _buffers.has(descriptor.buffer) or descriptor.arrayType not in ["Uint16Array", "Uint32Array"]: return []
		var raw: PackedByteArray = _buffers[descriptor.buffer]
		var width := 2 if descriptor.arrayType == "Uint16Array" else 4
		if raw.size() != int(descriptor.count) * width: return []
		for index in int(descriptor.count): indices.append(raw.decode_u16(index * 2) if width == 2 else raw.decode_u32(index * 4))
	else:
		for index in result[Mesh.ARRAY_VERTEX].size(): indices.append(index)
	if indices.size() % 3 != 0: return []
	for index in range(0, indices.size(), 3):
		var temporary := indices[index + 1]
		indices[index + 1] = indices[index + 2]
		indices[index + 2] = temporary # Three CCW -> native CW; vertices/normals intact.
	result[Mesh.ARRAY_INDEX] = indices
	return result

static func _make_material(descriptor: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Native glTF importer oracle confirms material resource colors are sRGB.
	# Original instance and vertex data remain linear, no second conversion.
	material.albedo_color = Color(descriptor.colorLinear[0], descriptor.colorLinear[1], descriptor.colorLinear[2], descriptor.opacity).linear_to_srgb()
	material.roughness = float(descriptor.get("roughness", 1))
	material.metallic = float(descriptor.get("metalness", 0))
	material.emission_enabled = descriptor.emissiveLinear != [0, 0, 0]
	material.emission = Color(descriptor.emissiveLinear[0], descriptor.emissiveLinear[1], descriptor.emissiveLinear[2]).linear_to_srgb()
	material.emission_energy_multiplier = float(descriptor.emissiveIntensity)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if int(descriptor.side) == 2 else (BaseMaterial3D.CULL_FRONT if int(descriptor.side) == 1 else BaseMaterial3D.CULL_BACK)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if descriptor.transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if descriptor.type == "MeshBasicMaterial" else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.set_meta("source_material", descriptor.duplicate(true))
	material.set_meta("native_gpu_parity", "pending-original-render/shadow/depth/texture-proof")
	return material

static func _transform(values: PackedFloat32Array, offset: int = 0) -> Transform3D:
	return Transform3D(Basis(Vector3(values[offset], values[offset + 1], values[offset + 2]), Vector3(values[offset + 4], values[offset + 5], values[offset + 6]), Vector3(values[offset + 8], values[offset + 9], values[offset + 10])), Vector3(values[offset + 12], values[offset + 13], values[offset + 14]))

func required_station_captures() -> Dictionary:
	return {"status": "HOLD-exact-browser-station-pixels", "source_manifest_sha256": _source_sha, "textures": _manifest.get("textures", []).duplicate(true), "gate": "host must admit exact recipe-matching browser Arial RGBA pixels; no font/image substitute"}

func _admit_station_captures() -> Dictionary:
	var callback: Variant = _hooks.get("station_capture_gate")
	if not callback is Callable or not callback.is_valid(): return _failure("HOLD: exact original station CanvasTexture pixels required")
	var response: Variant = callback.call(required_station_captures())
	if not response is Dictionary or not response.get("ok", false) or response.get("source_manifest_sha256") != _source_sha or not response.get("captures") is Array:
		return _failure("HOLD: station live-capture admission absent")
	var captures := {}
	for row in response.captures:
		if not row is Dictionary or captures.has(row.get("texture_id")) or not row.get("texture") is Texture2D or not row.get("live_capture_verified", false) or not _sha_valid(str(row.get("capture_sha256", ""))): return _failure("HOLD: unverified station capture")
		var expected: Dictionary = {}
		for texture: Dictionary in _manifest.textures:
			if texture.id == row.texture_id: expected = texture
		if expected.is_empty() or row.texture.get_width() != int(expected.image.width) or row.texture.get_height() != int(expected.image.height) or row.get("recipe") != expected.image.recipe: return _failure("HOLD: source station recipe/size mismatch")
		var image: Image = row.texture.get_image()
		if image == null or _hash(image.get_data()) != row.capture_sha256: return _failure("HOLD: captured station pixel hash mismatch")
		captures[row.texture_id] = row.texture
	if captures.size() != _manifest.textures.size(): return _failure("HOLD: missing station texture capture")
	for descriptor: Dictionary in _manifest.materials:
		if descriptor.textureBindings.is_empty(): continue
		var material := _make_material(descriptor)
		if not descriptor.textureBindings.has("map") or descriptor.textureBindings.size() != 1 or not captures.has(descriptor.textureBindings.map): return _failure("Unsupported original station texture binding")
		material.albedo_texture = captures[descriptor.textureBindings.map]
		_materials[descriptor.id] = material
	return {"ok": true}

func _build_batches(dataset: String, source_batches: Array) -> Dictionary:
	if _manifest.is_empty() or _roots.has(dataset): return _failure("Consumer not configured or dataset already built")
	for source: Dictionary in source_batches:
		if not _meshes.has(source.geometry) or not _materials.has(source.material): return _failure("HOLD: source geometry/material resource not admitted")
	var root := Node3D.new()
	root.name = "Original_" + dataset
	root.position = -_origin
	root.set_meta("source_manifest_sha256", _source_sha)
	root.set_meta("gameplay_active", false)
	for source: Dictionary in source_batches:
		if source.has("dynamicTrainCar"): continue # Only host-admitted actual train roots.
		var parent_frame := _transform(PackedFloat32Array(source.sourceWorldMatrix))
		var node: GeometryInstance3D
		var batch := {"source": source.duplicate(true), "parent": parent_frame, "cpu_transforms": [], "cpu_colors": [], "originals": [], "node": null}
		if source.kind == "source-instanced":
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = source.get("instanceColors") is Dictionary
			mm.mesh = _meshes[source.geometry]
			mm.instance_count = int(source.count) # Active count, not backing capacity.
			var matrices := _float_data(source.instanceMatrices)
			var colors := _float_data(source.instanceColors) if mm.use_colors else PackedFloat32Array()
			var stride := 16 if mm.use_colors else 12
			var upload := PackedFloat32Array()
			upload.resize(mm.instance_count * stride)
			for index in mm.instance_count:
				var frame := _transform(matrices, index * 16)
				var tint := Color(colors[index * 3], colors[index * 3 + 1], colors[index * 3 + 2]) if mm.use_colors else Color.WHITE
				batch.cpu_transforms.append(frame)
				batch.originals.append(frame)
				batch.cpu_colors.append(tint)
				for row in 3:
					for col in 4: upload[index * stride + row * 4 + col] = matrices[index * 16 + col * 4 + row]
				if mm.use_colors:
					upload[index * stride + 12] = tint.r
					upload[index * stride + 13] = tint.g
					upload[index * stride + 14] = tint.b
					upload[index * stride + 15] = 1.0
			mm.buffer = upload
			initial_uploads += 1
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			instance.material_override = _materials[source.material]
			node = instance
			batch.multimesh = mm
		else:
			var instance := MeshInstance3D.new()
			instance.mesh = _meshes[source.geometry]
			instance.material_override = _materials[source.material]
			node = instance
			batch.originals.append(Transform3D.IDENTITY)
			batch.cpu_transforms.append(Transform3D.IDENTITY)
		batch.node = node
		node.name = str(source.key).validate_node_name()
		node.transform = parent_frame
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("source_batch", source.duplicate(true))
		root.add_child(node)
		_batches[source.key] = batch
		for index in source.objectKeys.size():
			var key: String = source.objectKeys[index]
			if not _parts.has(key): _parts[key] = []
			_parts[key].append({"batch": source.key, "index": index})
	_roots[dataset] = root
	return {"ok": true, "root": root, "batches": source_batches.size(), "status": "native-source-geometry-only-gameplay-locked"}

func build_parking() -> Dictionary:
	if _manifest.is_empty(): return _failure("Consumer not configured")
	return _build_batches("parking", _manifest.parking.batches)

func build_railway() -> Dictionary:
	if _manifest.is_empty(): return _failure("Consumer not configured")
	var capture := _admit_station_captures()
	if not capture.ok:
		capture.required_captures = required_station_captures()
		return capture
	var factory: Variant = _hooks.get("train_factory")
	if not factory is Callable or not factory.is_valid(): return _failure("HOLD: trusted actual three-car train factory required")
	var reply: Variant = factory.call({"asset": _manifest.railway.trainAsset.duplicate(true), "source_manifest_sha256": _source_sha, "batches": _manifest.railway.batches.filter(func(row): return row.has("dynamicTrainCar")).duplicate(true), "meshes": _meshes.duplicate(), "materials": _materials.duplicate(), "source_car_frames": _manifest.railway.trainCars.duplicate(true)})
	if not reply is Dictionary or not reply.get("ok", false) or reply.get("asset_sha256") != _manifest.railway.trainAsset.sha256 or reply.get("source_manifest_sha256") != _source_sha or not reply.get("car_roots") is Array or reply.car_roots.size() != 3: return _failure("HOLD: actual train asset admission missing")
	for car in reply.car_roots:
		if not car is Node3D or car.get_parent() != null: return _failure("HOLD: invalid actual train car roots")
	# Admit the original merged detailed buffers only, never an empty box/group
	# despite a callback claiming the correct GLB SHA. The host factory receives
	# the exact resources; each mesh must bind its trusted source batch identity.
	for index in 3:
		var expected := {}
		for row: Dictionary in _manifest.railway.batches:
			if row.get("dynamicTrainCar", -1) == index: expected[row.key] = row
		var found := {}
		var pending: Array[Node] = [reply.car_roots[index]]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			pending.append_array(node.get_children())
			if not node is MeshInstance3D: continue
			var key := str(node.get_meta("source_train_batch", ""))
			if not expected.has(key) or found.has(key): return _failure("HOLD: placeholder or duplicate train mesh")
			var row: Dictionary = expected[key]
			if node.get_parent() != reply.car_roots[index] or node.mesh != _meshes[row.geometry] or node.material_override != _materials[row.material] or not node.transform.is_equal_approx(_transform(PackedFloat32Array(row.carLocalMatrix))): return _failure("HOLD: actual train buffers/material/offset mismatch")
			found[key] = true
		if found.size() != expected.size(): return _failure("HOLD: detailed original train meshes missing")
	var result := _build_batches("railway", _manifest.railway.batches)
	if not result.ok: return result
	_train_roots.clear()
	for index in 3:
		var car: Node3D = reply.car_roots[index]
		car.transform = _transform(PackedFloat32Array(_manifest.railway.trainCars[index].sourceWorldMatrix))
		result.root.add_child(car)
		_train_roots.append(car)
		var car_key := "TrustedTrainCar:" + str(index)
		var owner: String = ""
		for row: Dictionary in _manifest.railway.batches:
			if row.get("dynamicTrainCar", -1) == index:
				owner = row.objectKeys[0]
				break
		_batches[car_key] = {"source": {"key": car_key, "objectKeys": [owner]}, "parent": car.transform, "originals": [Transform3D.IDENTITY], "cpu_transforms": [car.transform], "node": car}
		if not _parts.has(owner): _parts[owner] = []
		_parts[owner].append({"batch": car_key, "index": 0})
	result.train_cars = 3
	return result

func source_metadata(dataset: String) -> Dictionary:
	return _manifest.get(dataset, {}).duplicate(true)

func source_record(key: String) -> Dictionary:
	return _records[key].duplicate(true) if _records.has(key) else {}

func current_state(key: String) -> Dictionary:
	return _current[key].duplicate(true) if _current.has(key) else {}

func resolve_part(batch: String, instance: int) -> String:
	if not _batches.has(batch) or instance < 0 or instance >= _batches[batch].source.objectKeys.size(): return ""
	return _batches[batch].source.objectKeys[instance]

func cpu_instance(batch: String, index: int) -> Variant:
	if not _batches.has(batch) or index < 0 or index >= _batches[batch].cpu_transforms.size(): return null
	return _batches[batch].cpu_transforms[index]

func shared_resources() -> Dictionary:
	return {"meshes": _meshes.duplicate(), "materials": _materials.duplicate(), "arrays": _arrays.duplicate(true)}

static func _frame_valid(frame: Transform3D) -> bool:
	return frame.origin.is_finite() and frame.basis.x.is_finite() and frame.basis.y.is_finite() and frame.basis.z.is_finite() and frame.basis.determinant() > 0.000001

func _edit(key: String, after: Dictionary, record_history: bool = true) -> Dictionary:
	if _broken_transaction or not _records.has(key) or not _parts.has(key): return _failure("Source identity unavailable or prior transaction broken")
	if not _frame_valid(after.frame): return _failure("Invalid source object transform")
	var lease: Variant = _hooks.get("edit_lease")
	var adapter: Variant = _hooks.get("edit_adapter")
	if not lease is Callable or not lease.is_valid() or lease.call() != true or not adapter is Callable or not adapter.is_valid(): return _failure("Protected source requires paused lease and trusted owner adapter")
	var before: Dictionary = _current[key].duplicate(true)
	var admission: Variant = adapter.call({"key": key, "before": before.duplicate(true), "after": after.duplicate(true), "record": source_record(key), "source_manifest_sha256": _source_sha})
	if not admission is Dictionary or not admission.get("ok", false) or not admission.get("commit") is Callable or not admission.commit.is_valid() or not admission.get("rollback") is Callable or not admission.rollback.is_valid(): return _failure("Source authority/routing rebuild not admitted")
	for part: Dictionary in _parts[key]:
		if not is_instance_valid(_batches[part.batch].node): return _failure("Source batch invalidated; rebuild required")
	_apply_state(key, after)
	if admission.commit.call() != true:
		_apply_state(key, before)
		if admission.rollback.call() != true: _broken_transaction = true
		return {"ok": false, "error": "Owner commit failed; exact source state restored", "rollback_ok": not _broken_transaction}
	_current[key] = after.duplicate(true)
	if record_history:
		_history.append({"key": key, "before": before, "after": after.duplicate(true)})
		if _history.size() > 100: _history.pop_front()
		_redo.clear()
	return {"ok": true, "key": key, "changed_parts": last_changed_parts}

func transform_object(key: String, frame_native: Transform3D) -> Dictionary:
	return _edit(key, {"frame": frame_native, "deleted": false})

func delete_object(key: String) -> Dictionary:
	if not _current.has(key): return _failure("Source identity missing")
	return _edit(key, {"frame": _current[key].frame, "deleted": true})

func undo() -> Dictionary:
	if _history.is_empty(): return _failure("Nothing to undo")
	var command: Dictionary = _history.back()
	var result := _edit(command.key, command.before, false)
	if result.ok: _redo.append(_history.pop_back())
	return result

func redo() -> Dictionary:
	if _redo.is_empty(): return _failure("Nothing to redo")
	var command: Dictionary = _redo.back()
	var result := _edit(command.key, command.after, false)
	if result.ok: _history.append(_redo.pop_back())
	return result

func _apply_state(key: String, state: Dictionary) -> void:
	var target: Transform3D = state.frame
	var source_target := Transform3D(target.basis, target.origin + _origin)
	var delta: Transform3D = source_target * (_source_frames[key] as Transform3D).affine_inverse()
	last_changed_parts = 0
	var dirty_batches := {}
	for part: Dictionary in _parts[key]:
		var batch: Dictionary = _batches[part.batch]
		var original: Transform3D = batch.originals[part.index]
		if batch.has("multimesh"):
			var transform: Transform3D = batch.parent.affine_inverse() * delta * batch.parent * original
			if state.deleted: transform.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			batch.multimesh.set_instance_transform(part.index, transform)
			batch.cpu_transforms[part.index] = transform
			dirty_batches[part.batch] = true
		else:
			batch.node.transform = delta * batch.parent
			batch.node.visible = not state.deleted
			batch.cpu_transforms[part.index] = batch.node.transform
		last_changed_parts += 1
	# Resource-local bounds must include moved instances, not merely the source
	# sphere used by the explicit parking visibility filter. CPU shadow only.
	for batch_key in dirty_batches:
		var batch: Dictionary = _batches[batch_key]
		var bounds := AABB()
		var found := false
		var mesh_bounds: AABB = _meshes[batch.source.geometry].get_aabb()
		for frame: Transform3D in batch.cpu_transforms:
			if absf(frame.basis.determinant()) <= 0.0000001: continue
			var part_bounds: AABB = frame * mesh_bounds
			bounds = bounds.merge(part_bounds) if found else part_bounds
			found = true
		batch.multimesh.custom_aabb = bounds

func update_parking_culling(focus_native: Vector3) -> void:
	if not focus_native.is_finite(): return
	var focus := focus_native + _origin
	for batch: Dictionary in _batches.values():
		if not str(batch.source.key).begins_with("ParkingBatch:"): continue
		# Keep original source sphere; edited conservative AABB adds moved objects.
		var sphere: Dictionary = batch.source.sourceBoundingSphere
		var center := Vector3(sphere.center[0], sphere.center[1], sphere.center[2])
		var visible := Vector2(center.x - focus.x, center.z - focus.z).length() < 300 + float(sphere.radius)
		for index in batch.cpu_transforms.size():
			if visible: break
			var transform: Transform3D = batch.cpu_transforms[index]
			if absf(transform.basis.determinant()) > 0.0000001:
				var bounds: AABB = transform * _meshes[batch.source.geometry].get_aabb()
				visible = Vector2(bounds.get_center().x - focus.x, bounds.get_center().z - focus.z).length() < 300 + bounds.size.length() * 0.5
		batch.node.visible = visible

func update_railway(dt: float, context: Dictionary = {}) -> Dictionary:
	var callback: Variant = _hooks.get("motion_adapter")
	if _train_roots.size() != 3 or not callback is Callable or not callback.is_valid(): return _failure("Railway motion/signal owner not connected")
	var reply: Variant = callback.call(dt, context, _motion_metadata)
	if not reply is Dictionary or not reply.get("ok", false) or not reply.get("car_frames") is Array or reply.car_frames.size() != 3 or not reply.get("signal_intensities") is Dictionary: return _failure("Invalid trusted motion/signal result")
	for frame in reply.car_frames:
		if not frame is Transform3D or not _frame_valid(frame): return _failure("Invalid trusted actual-car pose")
	for lamp: Dictionary in _manifest.railway.signalLamps:
		if not reply.signal_intensities.has(lamp.batch) or not _number(reply.signal_intensities[lamp.batch]) or reply.signal_intensities[lamp.batch] < 0: return _failure("Invalid trusted signal state")
	for index in 3: _train_roots[index].transform = reply.car_frames[index]
	for lamp: Dictionary in _manifest.railway.signalLamps:
		var descriptor: Dictionary = _batches[lamp.batch].source
		(_materials[descriptor.material] as StandardMaterial3D).emission_energy_multiplier = float(reply.signal_intensities[lamp.batch])
	return {"ok": true, "cars": 3, "lamps": _manifest.railway.signalLamps.size()}

func dispose() -> void:
	for root in _roots.values():
		if is_instance_valid(root): root.free()
	_roots.clear()
	_batches.clear()
	_parts.clear()
	_train_roots.clear()
