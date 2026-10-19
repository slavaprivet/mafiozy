extends RefCounted
## Presentation cache only. Never inserts actors or grants world authority.
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const Bridge = preload("res://scripts/npc_visual/npc_float_color_bridge.gd")
const SCHEMA := "mafiozi.npc-prepared/v1"
const BRIDGE_VERSION := "float-custom0/v1"
## The prepared-city manifest carries one entry per resident (287 today). The old 64 bound
## was sized for the palazzo-only asset set and rejected the city manifest outright, which is
## why every city placement attempt failed with prepared_manifest_schema_engine. The
## manifest is already hash-verified above, so this is only an upper sanity bound.
const MAX_MANIFEST_ENTRIES := 512
const LOADER_PATH := "res://scripts/npc_visual/npc_visual_loader.gd"
const BRIDGE_PATH := "res://scripts/npc_visual/npc_float_color_bridge.gd"
var _template: PackedScene
var _receipt: Dictionary

# --- DSH_LOADFAST: session-scope manifest verification ------------------------
# load_verified() re-proved the whole 1.44 MB / 287-entry prepared manifest for every
# resident: one sha256 over the manifest bytes, one get_string_from_utf8 + JSON.parse_string
# of those same bytes, then a 287-entry sweep in which every entry re-parsed its descriptor
# JSON twice and re-hashed the 20 KB loader and bridge scripts from disk (574 file opens and
# hashes per resident). None of that can differ between residents: the document is addressed
# by its trusted sha256 and the two scripts are session constants. It is now proved once and
# held here, keyed by every input the proof depends on, so a change to any of them rebuilds
# the holder and re-runs the complete original verification.
#
# NOT hoisted: everything that belongs to the resident being admitted. The fast path below
# still runs, per admission, _entry_types(), Loader.validate_entry(), the full receipt
# condition including both CURRENT on-disk script hashes, the descriptor binding, the .scn
# size bound, the .scn sha256, ResourceLoader.load(), the complete Loader._audit_tree() tree
# and per-vertex audit, the scene metadata checks and the camera-actor ownership pass. This
# is a cost change, not a strictness change: --city-load-strict=1 restores the original
# per-resident re-verification verbatim for an A/B on one machine.
class VerifiedManifest:
	var manifest_sha := ""
	var manifest_bytes := 0
	var directory := ""
	var engine := ""
	var loader_sha := ""
	var bridge_sha := ""
	var source_manifest_sha := ""
	var entry_count := 0
	var ids := {}
	var receipts := {}

static var _verified = null
static var _verified_builds := 0
static var _engine_cached := ""
static var _strict_flag := -1
static var _reuse_flag := -1

var _prepared_visual


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

# DSH_LOADFAST: the original per-resident body, kept verbatim as the A/B control for
# --city-load-strict=1. It re-proves the complete manifest for every resident.
static func _load_verified_original(bytes: PackedByteArray, trusted_sha: String, bridge_id: String, expected_descriptor_sha: String, directory: String) -> Dictionary:
	if not Loader._valid_hash(trusted_sha) or bytes.size() > 2097152 or Loader._hash(bytes) != trusted_sha:
		return Loader._fail("prepared_manifest_hash")
	var manifest: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not manifest is Dictionary or not _same_string(manifest.get("schema"), SCHEMA) or not _same_string(manifest.get("engine"), engine_id()) or not Loader._valid_hash(manifest.get("source_manifest_sha256")) or not manifest.get("entries") is Array or manifest.entries.size() > MAX_MANIFEST_ENTRIES:
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

# DSH_LOADFAST: --city-load-strict=1 restores the original per-resident re-verification of
# the whole manifest (no session holder is consulted at all). Default 0 uses the holder.
static func _strict_verify() -> bool:
	if _strict_flag < 0:
		_strict_flag = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-load-strict="):
				_strict_flag = maxi(0, int(argument.trim_prefix("--city-load-strict=")))
	return _strict_flag != 0

# DSH_LOADFAST: --city-load-reuse-probe=1 keeps the instance that already passed the full
# scene audit and returns it as the actor visual instead of freeing it and instantiating the
# same PackedScene a second time. The audit runs on that very resource under the same
# conditions, and instantiate_actor() still applies the identical _own_resources() ownership
# pass and the identical rig checks to it. Default 0 keeps the original two-instantiation
# route unchanged.
static func _reuse_probe() -> bool:
	if _reuse_flag < 0:
		_reuse_flag = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-load-reuse-probe="):
				_reuse_flag = maxi(0, int(argument.trim_prefix("--city-load-reuse-probe=")))
	return _reuse_flag != 0

static func _engine_current() -> String:
	if _engine_cached.is_empty():
		_engine_cached = engine_id()
	return _engine_cached

# DSH_LOADFAST: one receipt, exactly the condition the original per-entry loop applied to it.
static func _receipt_ok(receipt: Dictionary, loader_sha: String, bridge_sha: String) -> bool:
	return _same_string(receipt.get("engine"), _engine_current()) and _same_string(receipt.get("bridge_version"), BRIDGE_VERSION) and Loader._valid_hash(receipt.get("loader_sha256")) and _same_string(receipt.get("loader_sha256"), loader_sha) and Loader._valid_hash(receipt.get("bridge_sha256")) and _same_string(receipt.get("bridge_sha256"), bridge_sha) and receipt.get("shader_bound") is bool and not receipt.shader_bound and receipt.get("float_bridge") is bool and Loader._valid_hash(receipt.get("prepared_sha256")) and _same_string(receipt.get("prepared_file"), receipt.prepared_sha256 + ".scn")

# DSH_LOADFAST: prove the whole manifest once, keyed by every input that proof reads. The
# holder is rebuilt (and the whole verification re-run) when the manifest sha or size, the
# prepared directory, the engine version or either current on-disk script hash differs, so a
# mid-run edit of the loader or bridge script is still caught on the next admission with the
# original label.
static func _session(bytes: PackedByteArray, trusted_sha: String, directory: String) -> Dictionary:
	var loader_sha := FileAccess.get_sha256(LOADER_PATH)
	var bridge_sha := FileAccess.get_sha256(BRIDGE_PATH)
	var cached = _verified
	if cached != null and cached.manifest_sha == trusted_sha and cached.manifest_bytes == bytes.size() and cached.directory == directory and cached.engine == _engine_current() and cached.loader_sha == loader_sha and cached.bridge_sha == bridge_sha:
		return {"ok": true, "session": cached, "loader_sha": loader_sha, "bridge_sha": bridge_sha}
	var started := Time.get_ticks_usec()
	if not Loader._valid_hash(trusted_sha) or bytes.size() > 2097152 or Loader._hash(bytes) != trusted_sha:
		return Loader._fail("prepared_manifest_hash")
	var manifest: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not manifest is Dictionary or not _same_string(manifest.get("schema"), SCHEMA) or not _same_string(manifest.get("engine"), _engine_current()) or not Loader._valid_hash(manifest.get("source_manifest_sha256")) or not manifest.get("entries") is Array or manifest.entries.size() > MAX_MANIFEST_ENTRIES:
		return Loader._fail("prepared_manifest_schema_engine")
	var receipts := {}
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
		if not _receipt_ok(receipt, loader_sha, bridge_sha):
			return Loader._fail("prepared_receipt")
		receipts[entry.bridge_id] = receipt
	var session := VerifiedManifest.new()
	session.manifest_sha = trusted_sha
	session.manifest_bytes = bytes.size()
	session.directory = directory
	session.engine = _engine_current()
	session.loader_sha = loader_sha
	session.bridge_sha = bridge_sha
	session.source_manifest_sha = str(manifest.source_manifest_sha256)
	session.entry_count = manifest.entries.size()
	session.ids = ids
	session.receipts = receipts
	_verified = session
	_verified_builds += 1
	print("DSH_LOADFAST session entries=", session.entry_count, " receipts=", receipts.size(), " builds=", _verified_builds, " verify_us=", Time.get_ticks_usec() - started, " manifest_sha=", trusted_sha.substr(0, 12), " loader_sha=", loader_sha.substr(0, 12), " bridge_sha=", bridge_sha.substr(0, 12), " strict=", 1 if _strict_verify() else 0, " reuse_probe=", 1 if _reuse_probe() else 0)
	return {"ok": true, "session": session, "loader_sha": loader_sha, "bridge_sha": bridge_sha}

static func load_verified(bytes: PackedByteArray, trusted_sha: String, bridge_id: String, expected_descriptor_sha: String, directory: String) -> Dictionary:
	# DSH_LOADFAST: --city-load-strict=1 runs the pre-DSH_LOADFAST body verbatim.
	if _strict_verify():
		return _load_verified_original(bytes, trusted_sha, bridge_id, expected_descriptor_sha, directory)
	var resolved := _session(bytes, trusted_sha, directory)
	if not resolved.ok:
		return resolved
	var session = resolved.session
	var loader_sha: String = resolved.loader_sha
	var bridge_sha: String = resolved.bridge_sha
	var receipt: Variant = session.receipts.get(bridge_id)
	# An absent bridge_id left "selected" empty in the original loop: same label here.
	if receipt == null:
		return Loader._fail("prepared_descriptor")
	if not receipt is Dictionary or not receipt.get("entry") is Dictionary:
		return Loader._fail("prepared_entry")
	var entry: Dictionary = receipt.entry
	# Per-resident re-proof of the admitted entry: the original loop body for this entry, in
	# the original order, with the original failure labels.
	if not _entry_types(entry):
		return Loader._fail("prepared_source_entry_types")
	if not Loader.validate_entry(entry, str(entry.get("bridge_id", ""))).ok:
		return Loader._fail("prepared_identity")
	if not _receipt_ok(receipt, loader_sha, bridge_sha):
		return Loader._fail("prepared_receipt")
	if entry.descriptor_sha256 != expected_descriptor_sha:
		return Loader._fail("prepared_descriptor")
	var path := directory.path_join(receipt.prepared_file)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Loader._fail("prepared_scene_unavailable")
	var scene_size := file.get_length()
	file.close()
	if scene_size < 20 or scene_size > 33554432 or FileAccess.get_sha256(path) != receipt.prepared_sha256:
		return Loader._fail("prepared_scene_hash")
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null:
		return Loader._fail("prepared_scene_load")
	var probe := scene.instantiate()
	var audit := Loader._audit_tree(probe)
	var metadata_ok: bool = _same_string(probe.get_meta("npc_bridge_id"), bridge_id) and _same_string(probe.get_meta("npc_descriptor_sha256"), expected_descriptor_sha) and probe.get_meta("npc_descriptor") is Dictionary and probe.get_meta("npc_descriptor") == entry.descriptor and _same_string(probe.get_meta("npc_asset_sha256"), entry.asset_sha256) and probe.get_meta("npc_shader_bound") is bool and not probe.get_meta("npc_shader_bound")
	if audit.ok:
		for mesh: MeshInstance3D in audit.meshes:
			if mesh.material_override != null or mesh.material_overlay != null:
				metadata_ok = false
			for surface in mesh.mesh.get_surface_count():
				if mesh.get_surface_override_material(surface) != null:
					metadata_ok = false
	if not audit.ok or not metadata_ok:
		probe.free()
		return Loader._fail("prepared_scene_audit")
	var cache := new()
	cache._template = scene
	cache._receipt = receipt.duplicate(true)
	# DSH_LOADFAST: the default route frees the audited instance exactly as before.
	if _reuse_probe():
		cache._prepared_visual = probe
	else:
		probe.free()
	return {"ok": true, "cache": cache}

func instantiate_actor() -> Dictionary:
	if _template == null:
		return Loader._fail("disposed_cache")
	var started := Time.get_ticks_usec()
	# DSH_LOADFAST: with --city-load-reuse-probe=1 the instance that already passed the full
	# audit is the actor visual; otherwise the template is instantiated exactly as before.
	# The ownership pass below is identical on either route.
	var visual = _prepared_visual
	if visual != null:
		_prepared_visual = null
	else:
		visual = _template.instantiate()
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
	# DSH_LOADFAST: an audited instance that was never consumed must not leak when the cache
	# is dropped without instantiate_actor().
	if _prepared_visual != null:
		_prepared_visual.free()
		_prepared_visual = null
	_receipt.clear()
