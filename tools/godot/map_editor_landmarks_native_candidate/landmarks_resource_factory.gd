extends RefCounted
## Resource-only candidate. No default materials, textures, scene or authority activation.
const SCHEMA := "mafiozi.protected-landmarks-source/v1"
var _manifest := {}
var _buffers := {}
var _geometries := {}
var _meshes := {}
var _multimeshes := {}
var _records := {}
var _parts := {}
var _current := {}
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _source_sha := ""
var _resource_keys := {}
var _upload_arrays := {}
var _instance_shadow := {}
var _instance_bounds := {}
var _poisoned := {}
var _initialized := false

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func fail(reason: String) -> Dictionary:
	return {"ok": false, "status": "HOLD", "error": reason}

func _resource_changed(key: String) -> void:
	_poisoned[key] = true

func configure(directory: String, admitted_manifest_sha: String) -> Dictionary:
	if _initialized: return fail("Dispose before configuring a different source")
	var raw := FileAccess.get_file_as_bytes(directory.path_join("manifest.json"))
	if admitted_manifest_sha.length() != 64 or digest(raw) != admitted_manifest_sha: return fail("Manifest SHA admission mismatch")
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not decoded is Dictionary or decoded.get("schema") != SCHEMA or str(decoded.get("threeRevision")) != "180" or decoded.get("worldScale") != 4.1: return fail("Source schema or coordinate mismatch")
	var admitted := {}
	for receipt in decoded.get("buffers", []):
		var hash: String = str(receipt.get("sha256", ""))
		if hash.length() != 64 or receipt.get("file") != "buffers/" + hash + ".bin" or admitted.has(hash): return fail("Unsafe or duplicate source buffer")
		var bytes := FileAccess.get_file_as_bytes(directory.path_join(receipt.file))
		if bytes.size() != int(receipt.bytes) or digest(bytes) != hash: return fail("Corrupt source buffer")
		admitted[hash] = bytes
	var records := {}
	var parts := {}
	for row in decoded.records:
		if records.has(row.key) or row.get("ownerRequired") != true or row.get("availableUnlock") != false: return fail("Unsafe source owner identity")
		records[row.key] = row.duplicate(true)
	for row in decoded.parts:
		if parts.has(row.id) or not records.has(row.owner) or not finite_matrix(row.worldMatrix): return fail("Invalid source part")
		parts[row.id] = row.duplicate(true)
	_manifest = decoded
	_buffers = admitted
	_records = records
	_parts = parts
	_source_sha = admitted_manifest_sha
	for row in decoded.geometries: _geometries[row.id] = row
	for key in _records: _current[key] = {"delta": Transform3D.IDENTITY, "deleted": false}
	_initialized = true
	return {"ok": true, "parts": parts.size(), "pending_textures": decoded.textures.size(), "scene_admitted": false}

static func finite_matrix(value: Variant) -> bool:
	if not value is Array or value.size() != 16: return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)): return false
	return value[3] == 0 and value[7] == 0 and value[11] == 0 and value[15] == 1

static func source_transform(values: Variant, start: int = 0) -> Transform3D:
	return Transform3D(Basis(Vector3(values[start], values[start + 1], values[start + 2]), Vector3(values[start + 4], values[start + 5], values[start + 6]), Vector3(values[start + 8], values[start + 9], values[start + 10])), Vector3(values[start + 12], values[start + 13], values[start + 14]))

func _float_data(attribute: Dictionary) -> PackedFloat32Array:
	if attribute.get("arrayType") != "Float32Array" or not _buffers.has(attribute.buffer): return PackedFloat32Array()
	return _buffers[attribute.buffer].to_float32_array()

func _vectors(attribute: Dictionary, size: int) -> Variant:
	var data := _float_data(attribute)
	var count := int(attribute.count)
	var stride := int(attribute.get("stride", attribute.itemSize))
	var offset := int(attribute.get("offset", 0))
	if count < 0 or stride < size or offset < 0 or (count > 0 and (count - 1) * stride + offset + size > data.size()): return null
	if size == 2:
		var result := PackedVector2Array()
		result.resize(count)
		for i in range(count): result[i] = Vector2(data[i * stride + offset], data[i * stride + offset + 1])
		return result
	var result := PackedVector3Array()
	result.resize(count)
	for i in range(count): result[i] = Vector3(data[i * stride + offset], data[i * stride + offset + 1], data[i * stride + offset + 2])
	return result

func _indices(geometry: Dictionary) -> PackedInt32Array:
	var result := PackedInt32Array()
	if geometry.index == null:
		result.resize(int(geometry.attributes.position.count))
		for i in range(result.size()): result[i] = i
		return result
	var a: Dictionary = geometry.index
	var data: PackedByteArray = _buffers[a.buffer]
	var width := 2 if a.arrayType == "Uint16Array" else 4
	if a.arrayType not in ["Uint16Array", "Uint32Array"]: return result
	result.resize(int(a.count))
	for i in range(result.size()): result[i] = data.decode_u16(i * width) if width == 2 else data.decode_u32(i * width)
	return result

func _geometry_key(geometry_id: String, primitive: int) -> String:
	var lookup := geometry_id + ":" + str(primitive)
	if _resource_keys.has(lookup): return _resource_keys[lookup]
	var geometry: Dictionary = _geometries[geometry_id]
	var key := digest(JSON.stringify({"attributes": geometry.attributes, "index": geometry.index, "groups": geometry.groups, "drawRange": geometry.drawRange, "primitive": primitive}).to_utf8_buffer())
	_resource_keys[lookup] = key
	return key

func mesh_resource(geometry_id: String, primitive: int = Mesh.PRIMITIVE_TRIANGLES) -> ArrayMesh:
	if not _initialized or not _geometries.has(geometry_id): return null
	var geometry: Dictionary = _geometries[geometry_id]
	# SHA-derived source buffer key, not editable placement identity.
	var key := _geometry_key(geometry_id, primitive)
	if _poisoned.has(key): return null
	if _meshes.has(key): return _meshes[key]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vectors(geometry.attributes.position, 3)
	if arrays[Mesh.ARRAY_VERTEX] == null: return null
	if geometry.attributes.has("normal"): arrays[Mesh.ARRAY_NORMAL] = _vectors(geometry.attributes.normal, 3)
	if geometry.attributes.has("uv"): arrays[Mesh.ARRAY_TEX_UV] = _vectors(geometry.attributes.uv, 2)
	if geometry.attributes.has("color"):
		var source_colors: Variant = _vectors(geometry.attributes.color, 3)
		if source_colors == null: return null
		var colors := PackedColorArray()
		for color: Vector3 in source_colors: colors.append(Color(color.x, color.y, color.z, 1))
		arrays[Mesh.ARRAY_COLOR] = colors
	var index := _indices(geometry)
	if primitive == Mesh.PRIMITIVE_TRIANGLES:
		if index.size() % 3 != 0: return null
		# Source Three front-face CCW -> Godot CW. Vertex/UV/normal bytes unchanged.
		for i in range(0, index.size(), 3):
			var temporary := index[i + 1]
			index[i + 1] = index[i + 2]
			index[i + 2] = temporary
	for vertex in index:
		if vertex < 0 or vertex >= arrays[Mesh.ARRAY_VERTEX].size(): return null
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive, arrays)
	mesh.set_meta("source_geometry", geometry.duplicate(true))
	mesh.set_meta("source_manifest_sha256", _source_sha)
	mesh.changed.connect(_resource_changed.bind(key))
	_upload_arrays[key] = arrays
	_meshes[key] = mesh
	return mesh

func multimesh_resource(part_id: String) -> MultiMesh:
	if _poisoned.has(part_id): return null
	if _multimeshes.has(part_id): return _multimeshes[part_id]
	if not _parts.has(part_id): return null
	var part: Dictionary = _parts[part_id]
	if not part.has("matrices"): return null
	var mesh := mesh_resource(part.geometry)
	if mesh == null: return null
	var matrices := _float_data(part.matrices)
	if matrices.size() != int(part.count) * 16: return null
	var resource := MultiMesh.new()
	resource.transform_format = MultiMesh.TRANSFORM_3D
	resource.use_colors = part.has("colors")
	resource.mesh = mesh
	resource.instance_count = int(part.count)
	var colors := PackedFloat32Array()
	if resource.use_colors: colors = _float_data(part.colors)
	if resource.use_colors and colors.size() != resource.instance_count * 3: return null
	var aggregate := AABB()
	for i in range(resource.instance_count):
		var frame := source_transform(matrices, i * 16)
		resource.set_instance_transform(i, frame)
		var item: AABB = frame * mesh.get_aabb()
		aggregate = aggregate.merge(item) if i > 0 else item
		if resource.use_colors: resource.set_instance_color(i, Color(colors[i * 3], colors[i * 3 + 1], colors[i * 3 + 2], 1))
	resource.custom_aabb = aggregate
	_instance_bounds[part_id] = aggregate
	resource.set_meta("source_part_id", part_id)
	resource.changed.connect(_resource_changed.bind(part_id))
	_instance_shadow[part_id] = matrices
	_multimeshes[part_id] = resource
	return resource

func build_resources() -> Dictionary:
	if not _initialized: return fail("Source not configured")
	for part in _parts.values():
		if part.has("geometry"):
			var primitive := Mesh.PRIMITIVE_LINES if part.type == "LineSegments" else Mesh.PRIMITIVE_TRIANGLES
			if mesh_resource(part.geometry, primitive) == null: return fail("Invalid source geometry " + part.id)
			if part.has("matrices") and multimesh_resource(part.id) == null: return fail("Invalid source instances " + part.id)
	return {"ok": true, "meshes": _meshes.size(), "multimeshes": _multimeshes.size(), "materials": "EXACT_RECIPE_ONLY_HOLD", "scene_admitted": false}

func source_record(key: String) -> Dictionary:
	return _records.get(key, {}).duplicate(true)

func source_part(id: String) -> Dictionary:
	return _parts.get(id, {}).duplicate(true)

func source_materials() -> Array:
	return _manifest.get("materials", []).duplicate(true)

func mesh_upload_arrays(geometry_id: String, primitive: int = Mesh.PRIMITIVE_TRIANGLES) -> Array:
	if mesh_resource(geometry_id, primitive) == null: return []
	var key := _geometry_key(geometry_id, primitive)
	return _upload_arrays[key].duplicate(true)

func instance_transform_shadow(part_id: String, instance_index: int) -> Transform3D:
	if multimesh_resource(part_id) == null or instance_index < 0 or instance_index >= int(_parts[part_id].count): return Transform3D.IDENTITY
	return source_transform(_instance_shadow[part_id], instance_index * 16)

func texture_dependencies() -> Array:
	return _manifest.get("textures", []).duplicate(true)

func state(key: String) -> Dictionary:
	return _current.get(key, {}).duplicate(true)

func placement_plan(key: String, candidate: Dictionary = {}) -> Dictionary:
	if not _records.has(key): return fail("Unknown editor source key")
	var current: Dictionary = candidate if not candidate.is_empty() else _current[key]
	var owned := []
	var detached := []
	var bounds := AABB()
	var has_bounds := false
	for part in _parts.values():
		if part.owner != key: continue
		var item := {"part_id": part.id, "source_frame": source_transform(part.worldMatrix), "frame": source_transform(part.worldMatrix), "visible": part.visible}
		if part.has("detachedDependency"):
			detached.append(item)
		else:
			item.frame = current.delta * item.source_frame
			item.visible = part.visible and not current.deleted
			owned.append(item)
			if part.has("geometry") and part.type != "Sprite" and item.visible:
				var local_bounds: AABB
				if part.has("matrices"):
					var instances := multimesh_resource(part.id)
					if instances == null: return fail("Invalid instances")
					local_bounds = _instance_bounds[part.id]
				else:
					var primitive := Mesh.PRIMITIVE_LINES if part.type == "LineSegments" else Mesh.PRIMITIVE_TRIANGLES
					var mesh := mesh_resource(part.geometry, primitive)
					if mesh == null: return fail("Invalid mesh")
					local_bounds = mesh.get_aabb()
				var moved: AABB = item.frame * local_bounds
				bounds = bounds.merge(moved) if has_bounds else moved
				has_bounds = true
	return {"ok": true, "key": key, "source_record": source_record(key), "owned_parts": owned, "detached_dependencies": detached, "source_collider_recipe": _manifest.recipes.get(_records[key].get("collisionRecipe", ""), {}).duplicate(true), "owner_required": true, "culling_aabb": bounds, "has_visible_bounds": has_bounds}

func preview_edit(key: String, delta: Transform3D, deleted: bool = false) -> Dictionary:
	if not _records.has(key) or _records[key].parts.is_empty(): return fail("No active original placement")
	if not delta.is_finite() or delta.basis.determinant() <= 0.00000001: return fail("Invalid transform")
	var candidate := {"delta": delta, "deleted": deleted}
	var plan := placement_plan(key, candidate)
	plan.candidate = candidate
	plan.before = state(key)
	return plan

func commit_edit(preview: Dictionary, trusted_owner_transaction: Callable) -> Dictionary:
	if not preview.get("ok") or not _records.has(preview.get("key", "")) or not trusted_owner_transaction.is_valid(): return fail("Trusted owner/collider/navigation transaction required")
	if state(preview.key) != preview.before: return fail("Stale editor transaction")
	var checked := preview_edit(preview.key, preview.candidate.delta, preview.candidate.deleted)
	if not checked.get("ok") or checked != preview: return fail("Forged editor transaction")
	var receipt: Variant = trusted_owner_transaction.call(checked.duplicate(true))
	if not receipt is Dictionary or receipt.get("ok") != true or receipt.get("source_sha256") != _source_sha or receipt.get("key") != preview.key or receipt.get("paused_lease") != true or receipt.get("collider_nav_committed") != true: return fail("Owner transaction not admitted")
	_current[preview.key] = preview.candidate.duplicate(true)
	_history.append({"key": preview.key, "before": preview.before.duplicate(true), "after": preview.candidate.duplicate(true)})
	if _history.size() > 128: _history.pop_front()
	_redo.clear()
	return {"ok": true, "history": _history.size(), "scene_admitted": false}

func checkpoint() -> Dictionary:
	return {"source_sha256": _source_sha, "state": _current.duplicate(true), "history": _history.duplicate(true), "redo": _redo.duplicate(true), "mesh_ids": _meshes.values().map(func(r: Resource) -> int: return r.get_instance_id()), "multimesh_ids": _multimeshes.values().map(func(r: Resource) -> int: return r.get_instance_id())}

func _history_apply(undoing: bool, trusted_owner_transaction: Callable) -> Dictionary:
	var stack: Array[Dictionary] = _history if undoing else _redo
	if stack.is_empty() or not trusted_owner_transaction.is_valid(): return fail("History or owner transaction unavailable")
	var row: Dictionary = stack.back()
	var desired: Dictionary = row.before if undoing else row.after
	var plan := preview_edit(row.key, desired.delta, desired.deleted)
	if not plan.get("ok"): return plan
	var receipt: Variant = trusted_owner_transaction.call(plan.duplicate(true))
	if not receipt is Dictionary or receipt.get("ok") != true or receipt.get("source_sha256") != _source_sha or receipt.get("key") != row.key or receipt.get("paused_lease") != true or receipt.get("collider_nav_committed") != true: return fail("Owner history transaction not admitted")
	_current[row.key] = desired.duplicate(true)
	stack.pop_back()
	var other: Array[Dictionary] = _redo if undoing else _history
	other.append(row)
	return {"ok": true, "scene_admitted": false}

func undo(trusted_owner_transaction: Callable) -> Dictionary:
	return _history_apply(true, trusted_owner_transaction)

func redo(trusted_owner_transaction: Callable) -> Dictionary:
	return _history_apply(false, trusted_owner_transaction)

func install_scene(_host: Node3D, trusted: Dictionary = {}) -> Dictionary:
	# Resource recipe/material mapping requires an independently accepted visual adapter.
	# Never turn unadmitted source textures into default white materials or blank signs.
	var missing := []
	for requirement in ["original_texture_capture_sampler", "site_authority", "collider_owner", "navigation_owner", "doors_and_release_owner", "visual_adapter"]:
		if not trusted.get(requirement) is Callable or not trusted[requirement].is_valid(): missing.append(requirement)
	return {"ok": false, "status": "HOLD", "pending": missing, "reason": "Native scene installation requires separate original-visual and owner-adapter acceptance", "scene_admitted": false}

func dispose() -> void:
	# Drop our ownership; external admitted references remain valid, never freed behind host.
	_manifest.clear(); _buffers.clear(); _geometries.clear(); _meshes.clear(); _multimeshes.clear(); _records.clear(); _parts.clear(); _current.clear(); _history.clear(); _redo.clear(); _resource_keys.clear(); _upload_arrays.clear(); _instance_shadow.clear(); _instance_bounds.clear(); _poisoned.clear()
	_source_sha = ""
	_initialized = false
