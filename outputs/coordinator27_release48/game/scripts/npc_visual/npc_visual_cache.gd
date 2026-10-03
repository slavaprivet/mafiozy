extends RefCounted
## Presentation cache only. Never inserts actors or grants world authority.
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const Bridge = preload("res://scripts/npc_visual/npc_float_color_bridge.gd")
const SCHEMA := "mafiozi.npc-prepared/v1"
const BRIDGE_VERSION := "float-custom0/v1"
const LOADER_PATH := "res://scripts/npc_visual/npc_visual_loader.gd"
const BRIDGE_PATH := "res://scripts/npc_visual/npc_float_color_bridge.gd"
var _template: PackedScene
var _receipt: Dictionary

static func engine_id() -> String:
	return str(Engine.get_version_info().string)

static func _same_string(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _entry_types(entry: Dictionary) -> bool:
	# Guard the source Loader's scalar comparisons before delegated admission.
	for key in ["bridge_id", "descriptor_json", "descriptor_sha256", "canonical_source_sha256", "asset_sha256", "asset_file", "material_fidelity"]:
		if not entry.get(key) is String:
			return false
	var descriptor: Variant = entry.get("descriptor")
	if not descriptor is Dictionary or not descriptor.get("id") is String or not descriptor.get("sex") is String or not JSON.parse_string(entry.descriptor_json) is Dictionary:
		return false
	for key in ["appearance_application_count", "normalization_application_count", "animation_count"]:
		var count: Variant = entry.get(key)
		if not (count is int or count is float):
			return false
	return true

static func _localize_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var owned := mesh.duplicate(true) as ArrayMesh
	owned.resource_local_to_scene = true
	if mesh.shadow_mesh != null:
		owned.shadow_mesh = _localize_mesh(mesh.shadow_mesh)
	for surface in owned.get_surface_count():
		var material := owned.surface_get_material(surface)
		if material != null:
			material = material.duplicate(true)
			material.resource_local_to_scene = true
			owned.surface_set_material(surface, material)
	return owned

static func _own_resources(visual: Node) -> void:
	for key in visual.get_meta_list():
		var value: Variant = visual.get_meta(key)
		if value is Dictionary or value is Array:
			visual.set_meta(key, value.duplicate(true))
	for child in visual.get_children():
		_own_resources(child)
	if visual is MeshInstance3D:
		visual.mesh = _localize_mesh(visual.mesh)
		if visual.skin != null:
			visual.skin = visual.skin.duplicate(true)
			visual.skin.resource_local_to_scene = true
		if visual.material_override != null:
			visual.material_override = visual.material_override.duplicate(true)
			visual.material_override.resource_local_to_scene = true
		for surface in visual.mesh.get_surface_count():
			var override: Material = visual.get_surface_override_material(surface)
			if override != null:
				override = override.duplicate(true)
				override.resource_local_to_scene = true
				visual.set_surface_override_material(surface, override)

static func _owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_owners(child, root)

static func prepare_entry(entry: Dictionary, asset_directory: String, output_directory: String, use_float_bridge: bool = false) -> Dictionary:
	if not _entry_types(entry):
		return Loader._fail("prepared_source_entry_types")
	var result := Loader.load_file(entry, str(entry.get("bridge_id", "")), asset_directory)
	if not result.ok:
		return result
	var visual: Node3D = result.visual
	if use_float_bridge:
		var bytes := FileAccess.get_file_as_bytes(asset_directory.path_join(entry.asset_file))
		var plan := Bridge.prepare(visual, bytes, entry.asset_sha256)
		var applied := Bridge.apply(plan) if plan.ok else plan
		if not applied.ok:
			visual.free()
			return applied
	_own_resources(visual)
	visual.set_meta("npc_shader_bound", false)
	_owners(visual, visual)
	var scene := PackedScene.new()
	var error := scene.pack(visual)
	visual.free()
	if error != OK:
		return Loader._fail("pack_%s" % error)
	DirAccess.make_dir_recursive_absolute(output_directory)
	var temporary := output_directory.path_join(entry.descriptor_sha256 + ".scn")
	error = ResourceSaver.save(scene, temporary, ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if error != OK:
		return Loader._fail("save_%s" % error)
	var digest := FileAccess.get_sha256(temporary)
	var target := output_directory.path_join(digest + ".scn")
	if temporary != target:
		error = DirAccess.rename_absolute(temporary, target)
		if error != OK:
			return Loader._fail("rename_%s" % error)
	return {"ok": true, "entry": entry.duplicate(true), "prepared_file": digest + ".scn", "prepared_sha256": digest, "engine": engine_id(), "loader_sha256": FileAccess.get_sha256(LOADER_PATH), "bridge_sha256": FileAccess.get_sha256(BRIDGE_PATH), "bridge_version": BRIDGE_VERSION, "float_bridge": use_float_bridge, "shader_bound": false}

static func load_verified(bytes: PackedByteArray, trusted_sha: String, bridge_id: String, expected_descriptor_sha: String, directory: String) -> Dictionary:
	if not Loader._valid_hash(trusted_sha) or bytes.size() > 2097152 or Loader._hash(bytes) != trusted_sha:
		return Loader._fail("prepared_manifest_hash")
	var manifest: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not manifest is Dictionary or not _same_string(manifest.get("schema"), SCHEMA) or not _same_string(manifest.get("engine"), engine_id()) or not Loader._valid_hash(manifest.get("source_manifest_sha256")) or not manifest.get("entries") is Array or manifest.entries.size() > 64:
		return Loader._fail("prepared_manifest_schema_engine")
	var selected := {}
	var ids := {}
	for receipt in manifest.entries:
		if not receipt is Dictionary or not receipt.get("entry") is Dictionary:
			return Loader._fail("prepared_entry")
		var entry: Dictionary = receipt.entry
		if not _entry_types(entry):
			return Loader._fail("prepared_source_entry_types")
		var admission := Loader.validate_entry(entry, str(entry.get("bridge_id", "")))
		if not admission.ok or ids.has(entry.bridge_id):
			return Loader._fail("prepared_identity")
		ids[entry.bridge_id] = true
		if not _same_string(receipt.get("engine"), engine_id()) or not _same_string(receipt.get("bridge_version"), BRIDGE_VERSION) or not Loader._valid_hash(receipt.get("loader_sha256")) or not _same_string(receipt.get("loader_sha256"), FileAccess.get_sha256(LOADER_PATH)) or not Loader._valid_hash(receipt.get("bridge_sha256")) or not _same_string(receipt.get("bridge_sha256"), FileAccess.get_sha256(BRIDGE_PATH)) or not receipt.get("shader_bound") is bool or receipt.shader_bound or not receipt.get("float_bridge") is bool or not Loader._valid_hash(receipt.get("prepared_sha256")) or not _same_string(receipt.get("prepared_file"), receipt.prepared_sha256 + ".scn"):
			return Loader._fail("prepared_receipt")
		if entry.bridge_id == bridge_id:
			selected = receipt
	if selected.is_empty() or selected.entry.descriptor_sha256 != expected_descriptor_sha:
		return Loader._fail("prepared_descriptor")
	var path := directory.path_join(selected.prepared_file)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Loader._fail("prepared_scene_unavailable")
	var scene_size := file.get_length()
	file.close()
	if scene_size < 20 or scene_size > 33554432 or FileAccess.get_sha256(path) != selected.prepared_sha256:
		return Loader._fail("prepared_scene_hash")
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null:
		return Loader._fail("prepared_scene_load")
	var probe := scene.instantiate()
	var audit := Loader._audit_tree(probe)
	var metadata_ok: bool = _same_string(probe.get_meta("npc_bridge_id"), bridge_id) and _same_string(probe.get_meta("npc_descriptor_sha256"), expected_descriptor_sha) and probe.get_meta("npc_descriptor") is Dictionary and probe.get_meta("npc_descriptor") == selected.entry.descriptor and _same_string(probe.get_meta("npc_asset_sha256"), selected.entry.asset_sha256) and probe.get_meta("npc_shader_bound") is bool and not probe.get_meta("npc_shader_bound")
	if audit.ok:
		for mesh: MeshInstance3D in audit.meshes:
			if mesh.material_override != null or mesh.material_overlay != null:
				metadata_ok = false
			for surface in mesh.mesh.get_surface_count():
				if mesh.get_surface_override_material(surface) != null:
					metadata_ok = false
	probe.free()
	if not audit.ok or not metadata_ok:
		return Loader._fail("prepared_scene_audit")
	var cache := new()
	cache._template = scene
	cache._receipt = selected.duplicate(true)
	return {"ok": true, "cache": cache}

func instantiate_actor() -> Dictionary:
	if _template == null:
		return Loader._fail("disposed_cache")
	var started := Time.get_ticks_usec()
	var visual := _template.instantiate()
	_own_resources(visual)
	# Template was fully admitted once. Warm creation copies native resources and
	# gathers references only: no GLTF parser, vertex scan or Float32 mapper.
	var meshes: Array[MeshInstance3D] = []
	var attachments: Array[BoneAttachment3D] = []
	var skeleton: Skeleton3D
	var pending: Array[Node] = [visual]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			meshes.append(node)
		elif node is Skeleton3D:
			skeleton = node
		elif node is BoneAttachment3D:
			attachments.append(node)
		for child in node.get_children():
			pending.append(child)
	var bone_indices := {}
	if skeleton == null or skeleton.get_bone_count() != Loader.BONES.size() or meshes.is_empty():
		visual.free()
		return Loader._fail("warm_rig_identity")
	for bone in skeleton.get_bone_count():
		bone_indices[str(skeleton.get_bone_name(bone))] = bone
	for mesh in meshes:
		if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) != skeleton:
			visual.free()
			return Loader._fail("warm_skin_link")
	for attachment in attachments:
		if attachment.get_parent() != skeleton or attachment.use_external_skeleton:
			visual.free()
			return Loader._fail("warm_attachment_link")
	visual.set_meta("npc_descriptor", _receipt.entry.descriptor.duplicate(true))
	return {"ok": true, "visual": visual, "skeleton": skeleton, "meshes": meshes, "attachments": attachments, "bone_indices": bone_indices, "descriptor": _receipt.entry.descriptor.duplicate(true), "shader_bound": false, "creation_usec": Time.get_ticks_usec() - started}

func dispose() -> void:
	_template = null
	_receipt.clear()
