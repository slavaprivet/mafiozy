extends RefCounted
## Presentation-only importer. Caller owns body identity, authority and scene insertion.
const SCHEMA := "mafiozi.npc-visual/v1"
const MAX_ASSET_BYTES := 8388608
const MAX_NODES := 512
const MAX_VERTICES := 100000
const MALE_SHA := "8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00"
const FEMALE_SHA := "298d50e6244a7f17cf9cb66530fc34645fec0f19b575fe99d1df514709e90c40"
const BONES := ["root", "pelvis", "spine_01", "chest", "neck", "head", "socket_head", "clavicle_l", "upperarm_l", "forearm_l", "hand_l", "socket_hand_l", "clavicle_r", "upperarm_r", "forearm_r", "hand_r", "socket_hand_r", "socket_weapon", "socket_back", "socket_steering_l", "socket_steering_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "socket_seat"]
const PARENTS := [-1, 0, 1, 2, 3, 4, 5, 3, 7, 8, 9, 10, 3, 12, 13, 14, 15, 15, 3, 3, 3, 1, 21, 22, 1, 24, 25, 1]

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()

static func _valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

static func validate_entry(entry: Dictionary, bridge_id: String) -> Dictionary:
	if bridge_id.is_empty() or bridge_id.length() > 256 or entry.get("bridge_id") != bridge_id:
		return _fail("bridge_id")
	var descriptor: Variant = entry.get("descriptor")
	var encoded: Variant = entry.get("descriptor_json")
	if not descriptor is Dictionary or not encoded is String or encoded.length() > 16384:
		return _fail("descriptor")
	if descriptor.get("id") != bridge_id or JSON.parse_string(encoded) != descriptor:
		return _fail("descriptor_binding")
	if not _valid_hash(entry.get("descriptor_sha256")) or _hash(encoded.to_utf8_buffer()) != entry.descriptor_sha256:
		return _fail("descriptor_hash")
	var sex: Variant = descriptor.get("sex")
	if sex != "male" and sex != "female":
		return _fail("sex")
	if entry.get("canonical_source_sha256") != (MALE_SHA if sex == "male" else FEMALE_SHA):
		return _fail("canonical_source")
	var height: Variant = descriptor.get("height")
	if not (height is float or height is int) or not is_finite(float(height)) or height < 1.65 or height > 2.05:
		return _fail("height")
	if entry.get("appearance_application_count") != 1 or entry.get("normalization_application_count") != 1 or entry.get("animation_count") != 0:
		return _fail("application_count")
	if entry.get("material_fidelity") != "HOLD":
		return _fail("unproved_material_fidelity")
	if not _valid_hash(entry.get("asset_sha256")) or entry.get("asset_file") != entry.asset_sha256 + ".glb":
		return _fail("asset_path")
	return {"ok": true}

static func select_entry(manifest_bytes: PackedByteArray, trusted_manifest_sha256: String, bridge_id: String, expected_descriptor_sha256: String) -> Dictionary:
	# Both fingerprints must come from admitted source/export receipts, not the file
	# being verified. An asset's self-declared source SHA is not source derivation proof.
	if not _valid_hash(trusted_manifest_sha256) or not _valid_hash(expected_descriptor_sha256) or manifest_bytes.size() > 2097152 or _hash(manifest_bytes) != trusted_manifest_sha256:
		return _fail("trusted_manifest")
	var manifest: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not manifest is Dictionary or manifest.get("schema") != SCHEMA or not manifest.get("entries") is Array or manifest.entries.size() > 64:
		return _fail("manifest_schema")
	var ids := {}
	var selected := {}
	for entry in manifest.entries:
		if not entry is Dictionary or not entry.get("bridge_id") is String or ids.has(entry.bridge_id):
			return _fail("manifest_entry_identity")
		if entry.get("kind") == "synthetic_fixture" or entry.get("test_only", false) or manifest.get("tests_only", false):
			return _fail("test_only_manifest")
		ids[entry.bridge_id] = true
		var admission := validate_entry(entry, entry.bridge_id)
		if not admission.ok:
			return admission
		if entry.bridge_id == bridge_id:
			selected = entry
	if selected.is_empty() or selected.descriptor_sha256 != expected_descriptor_sha256:
		return _fail("manifest_descriptor_unavailable")
	return {"ok": true, "entry": selected.duplicate(true)}

static func load_file(entry: Dictionary, bridge_id: String, asset_directory: String) -> Dictionary:
	var admission := validate_entry(entry, bridge_id)
	if not admission.ok:
		return admission
	var file := FileAccess.open(asset_directory.path_join(entry.asset_file), FileAccess.READ)
	if file == null:
		return _fail("asset_unavailable")
	var size := file.get_length()
	if size < 20 or size > MAX_ASSET_BYTES:
		return _fail("asset_size")
	var bytes := file.get_buffer(size)
	if bytes.size() != size:
		return _fail("asset_short_read")
	return load_bytes(entry, bridge_id, bytes)

static func load_bytes(entry: Dictionary, bridge_id: String, bytes: PackedByteArray) -> Dictionary:
	var started := Time.get_ticks_usec()
	var admission := validate_entry(entry, bridge_id)
	if not admission.ok:
		return admission
	if bytes.size() < 20 or bytes.size() > MAX_ASSET_BYTES or _hash(bytes) != entry.asset_sha256:
		return _fail("asset_bytes")
	if bytes.decode_u32(0) != 0x46546c67 or bytes.decode_u32(4) != 2 or bytes.decode_u32(8) != bytes.size():
		return _fail("glb_header")
	var container := _admit_container(bytes)
	if not container.ok:
		return container
	var admitted_at := Time.get_ticks_usec()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	# Preserve source Float32 positions. Skin weights/COLOR_0 still use the native
	# packed formats; their measured tolerances are separate from material fidelity.
	var error := document.append_from_buffer(bytes, "", state, GLTFDocument.IMPORT_FLAG_FORCE_DISABLE_MESH_COMPRESSION)
	if error != OK:
		return _fail("gltf_parse_%s" % error)
	var parsed_at := Time.get_ticks_usec()
	if not state.animations.is_empty():
		return _fail("unexpected_animation")
	var visual := document.generate_scene(state)
	if visual == null:
		return _fail("gltf_scene")
	var generated_at := Time.get_ticks_usec()
	var audit := _audit_tree(visual)
	if not audit.ok:
		visual.free()
		return audit
	visual.set_meta("npc_bridge_id", bridge_id)
	visual.set_meta("npc_descriptor", entry.descriptor.duplicate(true))
	visual.set_meta("npc_descriptor_sha256", entry.descriptor_sha256)
	visual.set_meta("npc_asset_sha256", entry.asset_sha256)
	visual.set_meta("npc_material_fidelity", "HOLD")
	var completed_at := Time.get_ticks_usec()
	return {"ok": true, "visual": visual, "skeleton": audit.skeleton, "meshes": audit.meshes, "attachments": audit.attachments, "bone_indices": audit.bone_indices, "descriptor": entry.descriptor.duplicate(true), "material_fidelity": "HOLD", "normal_degenerate_fidelity": entry.get("normal_degenerate_fidelity", "HOLD"), "creation_usec": completed_at - started, "creation_phases_usec": {"admission": admitted_at - started, "parse": parsed_at - admitted_at, "generate": generated_at - parsed_at, "private_audit": completed_at - generated_at}, "asset_bytes": bytes.size()}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func _admit_container(bytes: PackedByteArray) -> Dictionary:
	var json_size := bytes.decode_u32(12)
	if bytes.decode_u32(16) != 0x4e4f534a or json_size > 1048576 or json_size < 2 or json_size % 4 != 0 or 20 + json_size + 8 > bytes.size():
		return _fail("glb_json_chunk")
	var data: Variant = JSON.parse_string(bytes.slice(20, 20 + json_size).get_string_from_utf8())
	if not data is Dictionary:
		return _fail("glb_json")
	for pair in [["nodes", MAX_NODES], ["meshes", 128], ["materials", 128], ["accessors", 2048], ["bufferViews", 2048]]:
		if not data.get(pair[0], []) is Array or data.get(pair[0], []).size() > pair[1]:
			return _fail("glb_%s_limit" % pair[0])
	for key in ["animations", "images", "textures", "cameras"]:
		if not data.get(key, []) is Array or not data.get(key, []).is_empty():
			return _fail("glb_unsupported_%s" % key)
	if not data.get("skins") is Array or not data.get("buffers") is Array or data.skins.size() != 1 or data.buffers.size() != 1:
		return _fail("glb_buffers_skins")
	if not data.buffers[0] is Dictionary or data.buffers[0].has("uri"):
		return _fail("glb_external_buffer")
	var bin_offset := 20 + json_size
	if bytes.decode_u32(bin_offset + 4) != 0x004e4942 or bin_offset + 8 + bytes.decode_u32(bin_offset) != bytes.size():
		return _fail("glb_bin_chunk")
	var bin_size := bytes.decode_u32(bin_offset)
	if not _integer(data.buffers[0].get("byteLength"), maxi(0, bin_size - 3), bin_size):
		return _fail("glb_buffer_length")
	var views: Array = data.get("bufferViews", [])
	for view in views:
		if not view is Dictionary or view.get("buffer") != 0 or not _integer(view.get("byteOffset", 0), 0, bin_size) or not _integer(view.get("byteLength"), 0, bin_size):
			return _fail("glb_buffer_view")
		if view.get("byteOffset", 0) + view.byteLength > bin_size or (view.has("byteStride") and not _integer(view.byteStride, 4, 252)):
			return _fail("glb_buffer_view_span")
	var accessors: Array = data.get("accessors", [])
	var decoded_bytes := 0
	for accessor in accessors:
		if not accessor is Dictionary or accessor.has("sparse") or not _integer(accessor.get("count"), 1, MAX_VERTICES * 3) or not _integer(accessor.get("bufferView"), 0, views.size() - 1):
			return _fail("glb_accessor_limit")
		var component_sizes := {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
		var widths := {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
		if not _integer(accessor.get("componentType"), 5120, 5126) or not component_sizes.has(int(accessor.componentType)) or not accessor.get("type") is String or not widths.has(accessor.type):
			return _fail("glb_accessor_type")
		var element_bytes: int = component_sizes[int(accessor.componentType)] * widths[accessor.type]
		var view: Dictionary = views[int(accessor.bufferView)]
		var stride: int = view.get("byteStride", element_bytes)
		if stride < element_bytes or not _integer(accessor.get("byteOffset", 0), 0, view.byteLength) or accessor.get("byteOffset", 0) + (accessor.count - 1) * stride + element_bytes > view.byteLength:
			return _fail("glb_accessor_span")
		decoded_bytes += int(accessor.count) * int(widths[accessor.type]) * 4
		if decoded_bytes > 16777216:
			return _fail("glb_decoded_budget")
	var nodes: Array = data.get("nodes", [])
	if not data.get("scenes") is Array or data.scenes.is_empty() or data.scenes.size() > 1 or not _integer(data.get("scene", 0), 0, data.scenes.size() - 1):
		return _fail("glb_scenes")
	var scene: Variant = data.scenes[0]
	if not scene is Dictionary or not scene.get("nodes") is Array or scene.nodes.is_empty() or scene.nodes.size() > MAX_NODES:
		return _fail("glb_scene_roots")
	var roots := {}
	for scene_root in scene.nodes:
		if not _integer(scene_root, 0, nodes.size() - 1) or roots.has(int(scene_root)):
			return _fail("glb_scene_root_reference")
		roots[int(scene_root)] = true
	for material in data.get("materials", []):
		if not material is Dictionary or not material.get("extensions", {}) is Dictionary or not material.get("pbrMetallicRoughness", {}) is Dictionary:
			return _fail("glb_material")
	var parents := {}
	var primitive_vertices := 0
	var mesh_vertex_counts: Array[int] = []
	for mesh in data.get("meshes", []):
		if not mesh is Dictionary or not mesh.get("primitives") is Array or mesh.primitives.size() > 32:
			return _fail("glb_primitives")
		var mesh_vertex_count := 0
		for primitive in mesh.primitives:
			if not primitive is Dictionary or primitive.has("targets") or primitive.get("mode", 4) != 4 or not primitive.get("attributes") is Dictionary or not _integer(primitive.attributes.get("POSITION"), 0, accessors.size() - 1):
				return _fail("glb_primitive_type")
			for attribute in primitive.attributes.values():
				if not _integer(attribute, 0, accessors.size() - 1):
					return _fail("glb_attribute_reference")
			if primitive.has("indices") and not _integer(primitive.indices, 0, accessors.size() - 1):
				return _fail("glb_index_reference")
			primitive_vertices += int(accessors[int(primitive.attributes.POSITION)].count)
			mesh_vertex_count += int(accessors[int(primitive.attributes.POSITION)].count)
			if primitive_vertices > MAX_VERTICES:
				return _fail("glb_primitive_budget")
		mesh_vertex_counts.append(mesh_vertex_count)
	var instantiated_vertices := 0
	for node_index in nodes.size():
		var node: Variant = nodes[node_index]
		if not node is Dictionary or node.has("camera") or not node.get("extensions", {}) is Dictionary or node.get("extensions", {}).has("KHR_lights_punctual"):
			return _fail("glb_runtime_node")
		if not node.get("children", []) is Array or node.get("children", []).size() > MAX_NODES:
			return _fail("glb_children")
		for child in node.get("children", []):
			if not _integer(child, 0, nodes.size() - 1) or child == node_index or parents.has(int(child)):
				return _fail("glb_child_ownership")
			parents[int(child)] = node_index
		if node.has("mesh") and not _integer(node.mesh, 0, data.get("meshes", []).size() - 1):
			return _fail("glb_mesh_reference")
		if node.has("mesh"):
			instantiated_vertices += mesh_vertex_counts[int(node.mesh)]
			if instantiated_vertices > MAX_VERTICES:
				return _fail("glb_instance_budget")
		if node.has("skin") and node.skin != 0:
			return _fail("glb_skin_reference")
	for node_index in nodes.size():
		var cursor := node_index
		var visited := {}
		while parents.has(cursor):
			if visited.has(cursor):
				return _fail("glb_node_cycle")
			visited[cursor] = true
			cursor = parents[cursor]
	for scene_root in roots:
		if parents.has(scene_root):
			return _fail("glb_root_is_child")
	var skin: Variant = data.skins[0]
	if not skin is Dictionary or not skin.get("joints") is Array or skin.joints.size() != BONES.size() or not _integer(skin.get("inverseBindMatrices"), 0, accessors.size() - 1):
		return _fail("glb_skin")
	var joints := {}
	for joint in skin.joints:
		if not _integer(joint, 0, nodes.size() - 1) or joints.has(int(joint)):
			return _fail("glb_joint")
		joints[int(joint)] = true
	var inverse_bind: Dictionary = accessors[int(skin.inverseBindMatrices)]
	if inverse_bind.type != "MAT4" or inverse_bind.componentType != 5126 or inverse_bind.count != BONES.size():
		return _fail("glb_inverse_bind_accessor")
	return {"ok": true}

static func _audit_tree(visual: Node) -> Dictionary:
	var pending: Array[Node] = [visual]
	var skeletons: Array[Skeleton3D] = []
	var meshes: Array[MeshInstance3D] = []
	var attachments: Array[BoneAttachment3D] = []
	var count := 0
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		count += 1
		if count > MAX_NODES:
			return _fail("node_limit")
		if node is Node3D and not node.transform.is_finite():
			return _fail("node_transform")
		if not node.get_class() in ["Node3D", "Skeleton3D", "MeshInstance3D", "BoneAttachment3D"]:
			return _fail("unexpected_node_type")
		if node is Skeleton3D:
			skeletons.append(node)
		elif node is MeshInstance3D:
			meshes.append(node)
		elif node is BoneAttachment3D:
			attachments.append(node)
		elif node is AnimationPlayer or node is CollisionObject3D:
			return _fail("unexpected_runtime_node")
		if node.get_script() != null:
			return _fail("unexpected_script")
		for child in node.get_children():
			pending.append(child)
	if skeletons.size() != 1 or meshes.is_empty():
		return _fail("rig_count")
	var skeleton := skeletons[0]
	if skeleton.get_bone_count() != BONES.size():
		return _fail("bone_count")
	var bone_indices := {}
	for index in skeleton.get_bone_count():
		var name := String(skeleton.get_bone_name(index))
		if not name in BONES or bone_indices.has(name) or not skeleton.get_bone_rest(index).is_finite():
			return _fail("bone_identity")
		bone_indices[name] = index
	for canonical_index in BONES.size():
		var actual_parent := skeleton.get_bone_parent(bone_indices[BONES[canonical_index]])
		var expected_parent: int = -1 if PARENTS[canonical_index] == -1 else bone_indices[BONES[PARENTS[canonical_index]]]
		if actual_parent != expected_parent:
			return _fail("bone_hierarchy")
	var vertices := 0
	var skinned_meshes := 0
	for instance in meshes:
		if instance.mesh == null or not instance.mesh is ArrayMesh:
			return _fail("mesh_type")
		instance.mesh = instance.mesh.duplicate() as ArrayMesh
		# Fresh GLTFState prevents resources crossing actors. Keep surface materials private
		# within this actor as well, so a clothing mutation cannot recolor an accessory.
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			if vertices > MAX_VERTICES:
				return _fail("vertex_limit")
			var material := instance.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D:
				return _fail("material_type")
			var owned := material.duplicate() as StandardMaterial3D
			owned.vertex_color_is_srgb = false
			owned.vertex_color_use_as_albedo = arrays[Mesh.ARRAY_COLOR] != null
			instance.mesh.surface_set_material(surface, owned)
		if instance.skin != null:
			instance.skin = instance.skin.duplicate() as Skin
			skinned_meshes += 1
			if instance.get_node_or_null(instance.skeleton) != skeleton:
				return _fail("cross_actor_skin")
			if instance.skin.get_bind_count() != BONES.size():
				return _fail("skin_bind_count")
			var bound := {}
			for bind_index in instance.skin.get_bind_count():
				var bound_name := String(instance.skin.get_bind_name(bind_index))
				var bound_bone := instance.skin.get_bind_bone(bind_index)
				if not bound_name.is_empty():
					bound_bone = skeleton.find_bone(bound_name)
				if bound_bone < 0 or bound_bone >= BONES.size() or bound.has(bound_bone) or not instance.skin.get_bind_pose(bind_index).is_finite():
					return _fail("skin_bind_identity")
				bound[bound_bone] = true
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if positions.is_empty():
				return _fail("vertices_missing")
			for position: Vector3 in positions:
				if not position.is_finite():
					return _fail("vertex_nonfinite")
			if arrays[Mesh.ARRAY_NORMAL] == null:
				return _fail("normals_missing")
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if normals.size() != positions.size():
				return _fail("normal_count")
			for normal: Vector3 in normals:
				if not normal.is_finite():
					return _fail("normal_nonfinite")
			if arrays[Mesh.ARRAY_COLOR] != null:
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				if colors.size() != positions.size():
					return _fail("color_count")
				for color: Color in colors:
					if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
						return _fail("color_nonfinite")
			if instance.skin != null:
				if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
					return _fail("skin_attributes_missing")
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var slot_count: int = bones.size() / positions.size()
				if not slot_count in [4, 8] or weights.size() != bones.size() or bones.size() != positions.size() * slot_count:
					return _fail("skin_attribute_count")
				for offset: int in bones.size():
					var bone: int = bones[offset]
					var weight: float = weights[offset]
					if bone < 0 or bone >= BONES.size() or not is_finite(weight) or weight < 0.0:
						return _fail("skin_attribute_value")
	if skinned_meshes == 0:
		return _fail("skinned_mesh_missing")
	for attachment in attachments:
		if attachment.override_pose or attachment.use_external_skeleton or attachment.get_parent() != skeleton or not String(attachment.bone_name) in BONES:
			return _fail("attachment_binding")
	return {"ok": true, "skeleton": skeleton, "meshes": meshes, "attachments": attachments, "bone_indices": bone_indices}
