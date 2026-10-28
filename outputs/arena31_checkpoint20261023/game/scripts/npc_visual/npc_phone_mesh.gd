extends RefCounted
## Source phone geometry only. Caller leases transform/visibility, never resources.
const DATA_SHA256 := "a8ba2f665f2a91645ee010a3d05cc4290d513a8a9e84fe0cd32f7b9e9dce4324"
const SOURCE_SHA256 := "ae866463e4ab393dd39243d68cbab7ddd7f18172a1b2c4c5e2d93cede3232997"
const SELF_PATH := "res://scripts/npc_visual/npc_phone_mesh.gd"
const MAX_BYTES := 32768
var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _positions_guard := PackedByteArray()
var _colors_guard := PackedByteArray()
var _material_properties: Array[String] = []
var _material_values: Array = []
var _surface_format := 0
var _nodes: Dictionary = {}
var _active: Dictionary = {}
var _owners: Dictionary = {}
var _idle: Array[WeakRef] = []
var _created := 0
var _disposed := false
var _node_defaults: Dictionary = {}
const NODE_CANONICAL_PROPERTIES := ["layers", "transparency", "material_overlay", "cast_shadow", "gi_mode", "extra_cull_margin", "custom_aabb", "ignore_occlusion_culling", "sorting_offset", "sorting_use_aabb_center", "lod_bias", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "skeleton"]

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()

static func load_file(path: String, expected_data_sha256: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("phone_data_missing")
	var size := file.get_length()
	if size <= 0 or size > MAX_BYTES:
		return _fail("phone_data_size")
	var bytes := file.get_buffer(size)
	file.close()
	return load_bytes(bytes, expected_data_sha256)

static func load_bytes(bytes: PackedByteArray, expected_data_sha256: String) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		return _fail("phone_data_size")
	if expected_data_sha256 != DATA_SHA256 or _hash(bytes) != expected_data_sha256:
		return _fail("phone_data_sha256")
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary or data.get("schema") != "mafiozi.npc-phone-geometry/v1":
		return _fail("phone_data_schema")
	var source: Variant = data.get("source")
	var geometry: Variant = data.get("geometry")
	if not source is Dictionary or not geometry is Dictionary:
		return _fail("phone_data_fields")
	if source.get("sha256") != SOURCE_SHA256 or source.get("three_revision") != "180" or source.get("default_color_hex") != "171a1e":
		return _fail("phone_source_receipt")
	var corner_order: Variant = geometry.get("native_corner_order")
	if not corner_order is Array or corner_order.size() != 3 or corner_order[0] != 0 or corner_order[1] != 2 or corner_order[2] != 1:
		return _fail("phone_corner_order")
	if geometry.get("vertex_count") != 330 or geometry.get("triangle_count") != 110 or geometry.get("component_type") != "FLOAT32_LE" or geometry.get("source_winding") != "CCW":
		return _fail("phone_geometry_contract")
	var positions_raw := Marshalls.base64_to_raw(geometry.get("positions_base64", ""))
	var colors_raw := Marshalls.base64_to_raw(geometry.get("linear_rgb_base64", ""))
	if positions_raw.size() != 3960 or colors_raw.size() != 3960 or _hash(positions_raw) != geometry.get("positions_sha256") or _hash(colors_raw) != geometry.get("linear_rgb_sha256"):
		return _fail("phone_attributes_sha256")
	var positions := positions_raw.to_float32_array()
	var colors := colors_raw.to_float32_array()
	var vertices := PackedVector3Array()
	var native_colors := PackedColorArray()
	vertices.resize(330)
	native_colors.resize(330)
	for triangle in range(110):
		for corner in range(3):
			var native_index := triangle * 3 + corner
			var source_index := triangle * 3 + (0 if corner == 0 else 2 if corner == 1 else 1)
			var offset := source_index * 3
			for axis in range(3):
				if not is_finite(positions[offset + axis]) or not is_finite(colors[offset + axis]) or colors[offset + axis] < 0.0 or colors[offset + axis] > 1.0:
					return _fail("phone_nonfinite_or_hdr")
			vertices[native_index] = Vector3(positions[offset], positions[offset + 1], positions[offset + 2])
			native_colors[native_index] = Color(colors[offset], colors[offset + 1], colors[offset + 2], 1.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = native_colors
	var pool: RefCounted = load(SELF_PATH).new()
	pool._material = StandardMaterial3D.new()
	pool._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool._material.albedo_color = Color.WHITE
	pool._material.vertex_color_use_as_albedo = true
	pool._material.vertex_color_is_srgb = false
	pool._material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	pool._material.cull_mode = BaseMaterial3D.CULL_BACK
	pool._material.disable_receive_shadows = true
	pool._mesh = ArrayMesh.new()
	pool._mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	pool._mesh.surface_set_material(0, pool._material)
	var actual: Array = pool._mesh.surface_get_arrays(0)
	pool._positions_guard = actual[Mesh.ARRAY_VERTEX].to_byte_array()
	pool._colors_guard = actual[Mesh.ARRAY_COLOR].to_byte_array()
	pool._surface_format = pool._mesh.surface_get_format(0)
	pool._capture_material_guard()
	return {"ok": true, "pool": pool, "data_sha256": DATA_SHA256, "source_sha256": SOURCE_SHA256, "material_fidelity": "HOLD_RGBA8_AND_TONEMAPPER"}

func _capture_material_guard() -> void:
	for property: Dictionary in _material.get_property_list():
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var value: Variant = _material.get(property.name)
		_material_properties.append(property.name)
		_material_values.append(value)

func _material_valid() -> bool:
	for i in range(_material_properties.size()):
		if _material.get(_material_properties[i]) != _material_values[i]:
			return false
	return true

func _resources_valid() -> bool:
	if _disposed or _mesh == null or _material == null or _mesh.get_surface_count() != 1:
		return false
	if _mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES or _mesh.surface_get_material(0) != _material:
		return false
	if _mesh.surface_get_format(0) != _surface_format or _mesh.shadow_mesh != null or _mesh.custom_aabb != AABB() or not _material_valid():
		return false
	if _material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or _material.albedo_color != Color.WHITE or not _material.vertex_color_use_as_albedo or _material.vertex_color_is_srgb or _material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or _material.cull_mode != BaseMaterial3D.CULL_BACK or not _material.disable_receive_shadows or _material.albedo_texture != null:
		return false
	var arrays := _mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX].to_byte_array() == _positions_guard and arrays[Mesh.ARRAY_COLOR].to_byte_array() == _colors_guard and (arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty())

func _reset_node(node: MeshInstance3D) -> void:
	node.visible = false
	node.top_level = false
	node.transform = Transform3D.IDENTITY
	node.mesh = _mesh
	node.material_override = null
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for surface in range(node.get_surface_override_material_count()):
		node.set_surface_override_material(surface, null)
	node.set_meta("npc_phone_visual_only", true)
	node.set_meta("npc_phone_source_sha256", SOURCE_SHA256)
	if _node_defaults.is_empty():
		for property: String in NODE_CANONICAL_PROPERTIES:
			_node_defaults[property] = node.get(property)

func _node_valid(node: MeshInstance3D) -> bool:
	if node.get_script() != null or node.mesh != _mesh or node.material_override != null or node.get_child_count() != 0 or node.top_level:
		return false
	for property: String in NODE_CANONICAL_PROPERTIES:
		if node.get(property) != _node_defaults[property]:
			return false
	for surface in range(node.get_surface_override_material_count()):
		if node.get_surface_override_material(surface) != null:
			return false
	return true

func _prune_freed() -> void:
	var removed := false
	for node_id: int in _nodes.keys():
		var node: Variant = _nodes[node_id].get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			continue
		if _active.has(node_id):
			var owner: String = _active[node_id]
			if _owners.get(owner) == node_id:
				_owners.erase(owner)
			_active.erase(node_id)
		_nodes.erase(node_id)
		removed = true
	if removed:
		var remaining: Array[WeakRef] = []
		for node_ref: WeakRef in _idle:
			var node: Variant = node_ref.get_ref()
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				remaining.append(node_ref)
		_idle = remaining

func acquire(owner_key: String) -> Dictionary:
	if owner_key.is_empty() or owner_key.length() > 240:
		return _fail("phone_owner_key")
	if not _resources_valid():
		return _fail("phone_disposed_or_mutated_template")
	_prune_freed()
	if _owners.has(owner_key):
		var existing: Variant = _nodes.get(_owners[owner_key])
		if existing is WeakRef and is_instance_valid(existing.get_ref()):
			return _fail("phone_owner_already_leased")
		_active.erase(_owners[owner_key])
		_nodes.erase(_owners[owner_key])
		_owners.erase(owner_key)
	var node: MeshInstance3D
	while not _idle.is_empty() and node == null:
		var candidate: Variant = _idle.pop_back().get_ref()
		if is_instance_valid(candidate) and candidate is MeshInstance3D and not candidate.is_queued_for_deletion():
			if not _node_valid(candidate):
				_idle.push_back(weakref(candidate))
				return _fail("phone_mutated_idle")
			node = candidate
	if node == null:
		node = MeshInstance3D.new()
		node.name = "NPC_Phone_Visual"
		_created += 1
	_reset_node(node)
	var node_id := node.get_instance_id()
	_nodes[node_id] = weakref(node)
	_active[node_id] = owner_key
	_owners[owner_key] = node_id
	node.set_meta("npc_phone_visual_lease", owner_key)
	return {"ok": true, "node": node}

func release(node: Variant, owner_key: String) -> Dictionary:
	if _disposed:
		return _fail("phone_pool_disposed")
	if not is_instance_valid(node) or not node is MeshInstance3D:
		return _fail("phone_node_missing")
	var node_id: int = node.get_instance_id()
	if not _active.has(node_id) or _active[node_id] != owner_key or not _nodes.has(node_id) or _nodes[node_id].get_ref() != node:
		return _fail("phone_foreign_lease")
	if not _node_valid(node) or not _resources_valid():
		return _fail("phone_mutated_lease")
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_reset_node(node)
	node.remove_meta("npc_phone_visual_lease")
	_active.erase(node_id)
	_owners.erase(owner_key)
	_idle.push_back(weakref(node))
	return {"ok": true}

func dispose() -> Dictionary:
	if _disposed:
		return {"ok": true, "already_disposed": true}
	for node_ref: WeakRef in _nodes.values():
		var node: Variant = node_ref.get_ref()
		if is_instance_valid(node) and node.get_child_count() != 0:
			return _fail("phone_unknown_children")
	for node_ref: WeakRef in _nodes.values():
		var node: Variant = node_ref.get_ref()
		if is_instance_valid(node):
			# All owned nodes passed the child preflight. Drop bindings on this
			# private node only; never edit a borrowed/shared material or mesh.
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			# A caller may have cleared/replaced the mesh after rejection. The
			# override list can then outlive native surface slots; only address
			# slots still present, and drop the mesh binding for the remainder.
			var current_surface_count: int = node.mesh.get_surface_count() if node.mesh != null else 0
			for surface in range(mini(node.get_surface_override_material_count(), current_surface_count)):
				node.set_surface_override_material(surface, null)
			node.material_override = null
			node.material_overlay = null
			node.mesh = null
			node.free()
	_nodes.clear()
	_active.clear()
	_owners.clear()
	_idle.clear()
	_mesh = null
	_material = null
	_positions_guard.clear()
	_colors_guard.clear()
	_material_properties.clear()
	_material_values.clear()
	_disposed = true
	return {"ok": true}

func stats() -> Dictionary:
	_prune_freed()
	return {"disposed": _disposed, "created": _created, "active": _active.size(), "idle": _idle.size(), "shared_surfaces": 0 if _mesh == null else _mesh.get_surface_count(), "vertex_count": 330, "triangles": 110, "material_fidelity": "HOLD_RGBA8_AND_TONEMAPPER"}
