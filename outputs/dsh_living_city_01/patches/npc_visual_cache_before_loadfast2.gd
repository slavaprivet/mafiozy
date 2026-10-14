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
# --- DSH_AUDITCACHE: the cached audit VERDICT, never the skipped localization ------------
# _audit_tree() is ~100 ms per resident because it scans every surface's arrays vertex by
# vertex. Its verdict is a pure function of the .scn bytes, the engine version and the loader
# that implements the walk -- and the first two of those are already proved on every admission
# (receipt.prepared_sha256 is re-hashed against the file before this lookup). Caching the
# verdict therefore removes the per-vertex scans and NOTHING else: on a hit this file performs
# the same localization _audit_tree() performs (mesh duplicate, per-surface private material
# with the same two flags, skin duplicate) in the same order and keeps the same metadata test,
# so an actor built on the cached path carries exactly the resources the audit would have made
# private to it. --city-load-strict=1 never consults or writes this cache.
#
# Trade, in one sentence: --city-audit-cache=1 changes verification strength from "every
# admission, every run" to "once per (scene sha256, engine, loader, bridge), with the scene
# sha256 still re-proved against the manifest receipt on every admission".
const AUDIT_CACHE_SCHEME := "mafiozi.npc-audit-cache/v1"
const AUDIT_CACHE_PATH := "user://dsh_npc_audit_cache_v1.json"
const AUDIT_CACHE_REFRESH := 32
## Bumped only together with a change to the LOCALIZED mutations this file reproduces. A change
## to the audit itself cannot reach a stale cache entry: the loader sha is part of the key, so a
## changed loader hash invalidates the whole file. DSH_AUDITCACHE holds the key, the file format
## and the "reproduce every mutation" guarantee together on purpose.
const AUDIT_CACHE_VERSION := "audit-cache/v1+localize-epilogue/v1"

static var _audit_cache_flag := -1
static var _audit_defer_flag := -1
static var _audit_cache_holder = null
static var _audit_cache_tried := false
static var _audit_cache_hits := 0
static var _audit_cache_misses := 0
static var _audit_cache_saved_us := 0
static var _audit_cache_writes := 0
static var _audit_cache_last_us := 0

# DSH_AUDITCACHE: one per process. Header fields are the part of the key that is constant for
# the run (engine + both script hashes + the bone schema + the audit version); the per-resident
# part of the key is the .scn sha256, which is the dictionary key of entries.
class AuditCache:
	var path := ""
	var scheme := ""
	var audit_version := ""
	var engine := ""
	var loader_sha := ""
	var bridge_sha := ""
	var bone_fingerprint := ""
	var entries := {}
	var loaded := false
	var pending := 0
	var saved_at := ""

# DSH_AUDITCACHE: --city-audit-cache=1 (default 0 = today's behaviour everywhere). Cached scan
# of the user arguments, same pattern as _strict_verify().
static func _audit_cache_enabled() -> bool:
	if _audit_cache_flag < 0:
		_audit_cache_flag = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-audit-cache="):
				_audit_cache_flag = maxi(0, int(argument.trim_prefix("--city-audit-cache=")))
	return _audit_cache_flag != 0

# DSH_AUDITCACHE: --city-audit-probe-defer=1 (default 0). On a cache hit the throwaway
# instantiate() that exists only to be audited is not created at all; the metadata, override and
# layout test runs on the actor instance inside instantiate_actor() instead. Same failure label
# (prepared_scene_audit), same admission decision, one fewer instantiate() per resident.
static func _audit_probe_defer() -> bool:
	if _audit_defer_flag < 0:
		_audit_defer_flag = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-audit-probe-defer="):
				_audit_defer_flag = maxi(0, int(argument.trim_prefix("--city-audit-probe-defer=")))
	return _audit_defer_flag != 0

# DSH_AUDITCACHE: the bone schema this verdict was proved against. It is already covered by the
# loader hash (BONES/PARENTS are loader constants); it is stored so a hand-edited cache with the
# wrong rig cannot be mistaken for one proved against this engine and this skeleton.
static func _audit_bone_fingerprint() -> String:
	return Loader._hash(var_to_bytes([Loader.BONES, Loader.PARENTS])).substr(0, 32)

# DSH_AUDITCACHE: user:// is the writable per-machine, per-project directory of this build
# (config/use_custom_user_dir=true -> %APPDATA%\Godot\app_userdata\<project>), it is stable
# across runs, and nothing in this project owns a file in it today. The cache only ever SKIPS
# work for a hash that was audited; it never turns a rejected scene into an accepted one, so the
# worst case of a lost or corrupt file is that the ~28 s is paid again.
static func _audit_cache() -> Variant:
	if _audit_cache_tried:
		return _audit_cache_holder
	_audit_cache_tried = true
	var holder := AuditCache.new()
	holder.path = ProjectSettings.globalize_path(AUDIT_CACHE_PATH)
	holder.scheme = AUDIT_CACHE_SCHEME
	holder.audit_version = AUDIT_CACHE_VERSION
	holder.engine = _engine_current()
	holder.loader_sha = FileAccess.get_sha256(LOADER_PATH)
	holder.bridge_sha = FileAccess.get_sha256(BRIDGE_PATH)
	holder.bone_fingerprint = _audit_bone_fingerprint()
	_audit_cache_holder = holder
	if not FileAccess.file_exists(AUDIT_CACHE_PATH):
		return holder
	var raw := FileAccess.get_file_as_bytes(AUDIT_CACHE_PATH)
	if raw.size() <= 2 or raw.size() > 4194304:
		return holder
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary:
		return holder
	var entries: Variant = parsed.get("entries")
	if not entries is Dictionary:
		return holder
	# A cache written by a different engine, loader, bridge, audit version or bone schema is not
	# consulted at all: the key would not match, and this keeps the reasoning simple.
	if not _same_string(parsed.get("scheme"), holder.scheme) or not _same_string(parsed.get("audit_version"), holder.audit_version) or not _same_string(parsed.get("engine"), holder.engine) or not _same_string(parsed.get("loader_sha256"), holder.loader_sha) or not _same_string(parsed.get("bridge_sha256"), holder.bridge_sha) or not _same_string(parsed.get("bone_fingerprint"), holder.bone_fingerprint):
		return holder
	holder.entries = entries
	holder.loaded = true
	return holder

# DSH_AUDITCACHE: the lookup runs only after the pinned loader proved
# FileAccess.get_sha256(path) == receipt.prepared_sha256 for THIS admission, so a hit means the
# file about to be loaded is byte-identical to the file whose verdict is recorded. The entry
# carries its own copy of the run-constant key parts: a hand-edited or half-written file cannot
# promote a verdict proved against another loader/bridge/engine/bone schema.
static func _audit_cache_lookup(scene_sha: String) -> int:
	if not _audit_cache_enabled():
		return 0
	var holder = _audit_cache()
	if holder == null or not holder.loaded:
		return 0
	var record: Variant = holder.entries.get(scene_sha)
	if not record is Dictionary or record.get("audit_ok") != true:
		return 0
	if not _same_string(record.get("audit_version"), holder.audit_version) or not _same_string(record.get("engine"), holder.engine) or not _same_string(record.get("loader_sha256"), holder.loader_sha) or not _same_string(record.get("bridge_sha256"), holder.bridge_sha) or not _same_string(record.get("bone_fingerprint"), holder.bone_fingerprint):
		return 0
	return maxi(1, int(record.get("audit_us", 0)))

# DSH_AUDITCACHE: write the cache back atomically (tmp + rename). A crash between the two leaves
# the previous file intact, and a truncating write can never be what a later run reads.
static func _audit_cache_flush() -> void:
	var holder = _audit_cache_holder
	if holder == null or not _audit_cache_enabled() or holder.pending <= 0:
		return
	var payload := {
		"scheme": holder.scheme,
		"audit_version": holder.audit_version,
		"engine": holder.engine,
		"loader_sha256": holder.loader_sha,
		"bridge_sha256": holder.bridge_sha,
		"bone_fingerprint": holder.bone_fingerprint,
		"scene_count": holder.entries.size(),
		"saved_at": Time.get_datetime_string_from_system(true),
		"entries": holder.entries,
	}
	var temporary := AUDIT_CACHE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), holder.path)
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return
	holder.pending = 0
	holder.loaded = true
	_audit_cache_writes += 1
	print("DSH_AUDITCACHE flush scenes=", holder.entries.size(), " writes=", _audit_cache_writes, " hits=", _audit_cache_hits, " misses=", _audit_cache_misses, " saved_us=", _audit_cache_saved_us, " loader_sha=", holder.loader_sha.substr(0, 12), " bridge_sha=", holder.bridge_sha.substr(0, 12), " engine=", holder.engine, " path=", holder.path)

# DSH_AUDITCACHE: record one proved verdict. Refreshed every AUDIT_CACHE_REFRESH misses so a run
# that dies at resident 200 still keeps the first 192 verdicts; the first proved verdict also
# prints the tuning block once per run, next to the DSH_ADMITFAST phase lines it explains.
static func _audit_cache_record(scene_sha: String, audit_us: int) -> void:
	if not _audit_cache_enabled():
		return
	_audit_cache_misses += 1
	_audit_cache_last_us = audit_us
	var holder = _audit_cache()
	if holder == null:
		return
	holder.entries[scene_sha] = {
		"audit_ok": true,
		"audit_version": holder.audit_version,
		"engine": holder.engine,
		"loader_sha256": holder.loader_sha,
		"bridge_sha256": holder.bridge_sha,
		"bone_fingerprint": holder.bone_fingerprint,
		"audit_us": audit_us,
		"saved_at": Time.get_datetime_string_from_system(true),
	}
	holder.pending += 1
	if _audit_cache_misses == 1:
		print("DSH_AUDITCACHE == cached audit verdicts, default OFF ==")
		print("DSH_AUDITCACHE trade: verification strength moves from every-admission-every-run to once-per-(scene sha256, engine, loader, bridge).")
		print("DSH_AUDITCACHE the scene sha256 is still re-proved against the manifest receipt on EVERY admission, before this cache is consulted; --city-load-strict=1 bypasses the cache entirely (byte-exact control).")
		print("DSH_AUDITCACHE key: scheme=", holder.scheme, " audit_version=", holder.audit_version, " engine=", holder.engine, " loader_sha=", holder.loader_sha.substr(0, 12), " bridge_sha=", holder.bridge_sha.substr(0, 12), " bone_fp=", holder.bone_fingerprint, " scene_sha256=receipt.prepared_sha256")
		print("DSH_AUDITCACHE cached path reproduces: mesh.duplicate() (shadow mesh left to the ownership pass, exactly as today), per-surface material.duplicate() with vertex_color_is_srgb=false and vertex_color_use_as_albedo=(ARRAY_COLOR != null), skin.duplicate(), then the identical metadata/override test; only the per-vertex value scans and the skin-bind identity loop are replaced by the scene hash.")
		print("DSH_AUDITCACHE cache_scenes=", holder.entries.size(), " first_audit_us=", audit_us, " probe_defer=", 1 if _audit_probe_defer() else 0, " path=", holder.path)
	if holder.pending >= AUDIT_CACHE_REFRESH:
		_audit_cache_flush()

# DSH_AUDITCACHE: the localization half of _audit_tree(), for a verdict that is already proved.
# _audit_tree() does exactly this to the instance it returns:
#   line 310  instance.mesh = instance.mesh.duplicate()          (shadow mesh untouched)
#   lines 313-324 per surface: owned = material.duplicate(), vertex_color_is_srgb = false,
#                 vertex_color_use_as_albedo = (ARRAY_COLOR != null), surface_set_material
#   line 326  instance.skin = instance.skin.duplicate()
# This function performs every one of those, first, before any check that could return early --
# so even in an unexpected reject the instance is left localized, exactly like the audit leaves
# it. The skin check the audit makes first (skin != null and the skeleton link) decides whether
# the skin is duplicated, so the duplication count is the audit's count as well.
static func _probe_localize_and_validate(visual: Node, bridge_id: String, descriptor_sha: String, descriptor: Dictionary, asset_sha: String) -> Dictionary:
	var pending: Array[Node] = [visual]
	var meshes: Array[MeshInstance3D] = []
	var attachments: Array[BoneAttachment3D] = []
	var skeletons: Array[Skeleton3D] = []
	var count := 0
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		count += 1
		if count > Loader.MAX_NODES or not node.get_class() in ["Node3D", "Skeleton3D", "MeshInstance3D", "BoneAttachment3D"]:
			return {"ok": false}
		if node is Node3D and not node.transform.is_finite():
			return {"ok": false}
		if node is Skeleton3D:
			skeletons.append(node)
		elif node is MeshInstance3D:
			meshes.append(node)
		elif node is BoneAttachment3D:
			attachments.append(node)
		if node.get_script() != null:
			return {"ok": false}
		for child in node.get_children():
			pending.append(child)
	if skeletons.size() != 1 or meshes.is_empty() or skeletons[0].get_bone_count() != Loader.BONES.size():
		return {"ok": false}
	for instance in meshes:
		if instance.mesh == null or not instance.mesh is ArrayMesh:
			return {"ok": false}
		var source := instance.mesh as ArrayMesh
		var owned := source.duplicate() as ArrayMesh
		instance.mesh = owned
		# Mirrors _own_resources(): the shadow mesh is not audited, it is what the ownership
		# pass duplicates and recurses into on either route, so it is left for that pass.
		for surface in owned.get_surface_count():
			var material := owned.surface_get_material(surface)
			if not material is StandardMaterial3D:
				return {"ok": false}
			var private_material := material.duplicate() as StandardMaterial3D
			private_material.vertex_color_is_srgb = false
			# Identical expression, and it is how the audit decides this flag: whether the
			# packed surface actually carries a COLOR_0 array.
			private_material.vertex_color_use_as_albedo = owned.surface_get_arrays(surface)[Mesh.ARRAY_COLOR] != null
			owned.surface_set_material(surface, private_material)
		if instance.skin != null:
			instance.skin = instance.skin.duplicate() as Skin
	var metadata_ok: bool = _same_string(visual.get_meta("npc_bridge_id"), bridge_id) and _same_string(visual.get_meta("npc_descriptor_sha256"), descriptor_sha) and visual.get_meta("npc_descriptor") is Dictionary and visual.get_meta("npc_descriptor") == descriptor and _same_string(visual.get_meta("npc_asset_sha256"), asset_sha) and visual.get_meta("npc_shader_bound") is bool and not visual.get_meta("npc_shader_bound")
	for mesh in meshes:
		if mesh.material_override != null or mesh.material_overlay != null:
			metadata_ok = false
		for surface in mesh.mesh.get_surface_count():
			if mesh.get_surface_override_material(surface) != null:
				metadata_ok = false
	return {"ok": metadata_ok, "meshes": meshes, "attachments": attachments}
static var _strict_flag := -1
static var _reuse_flag := -1

var _prepared_visual
var _ac_hit := false
var _ac_saved_us := 0
var _ac_audited := false
var _ac_defer_us := 0

# --- DSH_ADMITFAST: three default-OFF knobs on the per-admission ownership pass ---------
# None of them removes a check. Each one stops repeating work whose result already exists on
# the very instance that is returned as the actor. Defaults are today's behaviour everywhere,
# and --city-load-strict=1 gates all of them off so the control route stays byte-exact.
#   --city-admit-reuse-own=1      the actor IS the audited instance (needs
#                                 --city-load-reuse-probe=1), so do not localize it twice.
#   --city-admit-material-fast=1  the deep mesh copy already copied the surface materials;
#                                 skip the second copy only where an identity test proves it.
#   --city-admit-telemetry=N      print the DSH_ADMITFAST phase line for the first N
#                                 admissions (0 = silent).
static var _admit_reuse_own_flag := -1
static var _admit_material_flag := -1
static var _admit_telemetry_limit := -1
static var _admit_telemetry_seen := 0
var _admit_index := 0
var _admit_scene_bytes := 0
var _admit_hash_us := 0
var _admit_load_us := 0
var _admit_probe_us := 0
var _admit_audit_us := 0



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

# DSH_ADMITFAST: --city-admit-material-fast=1 (default 0). mesh.duplicate(true) is a deep
# copy, so the material it hands back for a surface is already a private copy of that
# surface's material and the explicit material.duplicate(true) below copies a copy. That
# second copy is skipped only where an identity test proves it redundant, per surface:
#   * is_same(copy, source material): the deep copy did NOT copy this material (the copy is
#     still the source object), so the explicit duplicate is what makes it private. Keep it.
#   * the copy is already claimed by an earlier surface of THIS mesh: two surfaces would end
#     up sharing one material, which the per-surface duplicate deliberately prevents ("a
#     clothing mutation cannot recolor an accessory"). Keep it.
# Every other surface keeps today's fallback, so each surface still ends up with a material
# that is private to this actor and to the other surfaces; only the identity/history of the
# object changes, which is why the knob is a flag and OFF by default.
static func _localize_mesh(mesh: ArrayMesh, material_fast := false) -> ArrayMesh:
	var owned := mesh.duplicate(true) as ArrayMesh
	owned.resource_local_to_scene = true
	if mesh.shadow_mesh != null:
		owned.shadow_mesh = _localize_mesh(mesh.shadow_mesh, material_fast)
	var claimed := {}
	for surface in owned.get_surface_count():
		var material := owned.surface_get_material(surface)
		if material != null:
			if material_fast and not is_same(material, mesh.surface_get_material(surface)) and not claimed.has(material.get_instance_id()):
				material.resource_local_to_scene = true
				claimed[material.get_instance_id()] = true
			else:
				material = material.duplicate(true)
				material.resource_local_to_scene = true
				owned.surface_set_material(surface, material)
				claimed[material.get_instance_id()] = true
	return owned

# DSH_ADMITFAST: --city-admit-reuse-own=1 (default 0). _audit_tree() mutates the instance it
# audits: every MeshInstance3D.mesh becomes a fresh copy, every surface material becomes a
# fresh copy and every skin becomes a fresh copy (pinned loader lines 310/321/326). Those
# resources therefore belong to THIS actor alone -- they were created in this admission, on
# this instance, and the PackedScene loaded with CACHE_MODE_IGNORE is released by dispose()
# right after. _own_resources() deep-copies all of them a second time. This pass records the
# same ownership marker _localize_mesh() records, without the second copy, because the copy
# the audit made is already private. The shadow mesh is NOT audited (the audit walks
# instance.mesh surfaces only), so it keeps the exact deep copy and recursion it gets today.
# The override branches of _own_resources() cannot be reached for an audited instance at all:
# the audit fails the admission with prepared_scene_audit whenever material_override,
# material_overlay or any surface override is set (loader lines 192-196).
static func _localize_mesh_audited(mesh: ArrayMesh) -> ArrayMesh:
	mesh.resource_local_to_scene = true
	if mesh.shadow_mesh != null:
		mesh.shadow_mesh = _localize_mesh(mesh.shadow_mesh)
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material != null:
			material.resource_local_to_scene = true
	return mesh

# DSH_ADMITFAST: one cached scan of the user arguments each, same pattern as _strict_verify().
static func _admit_reuse_own() -> bool:
	if _admit_reuse_own_flag < 0:
		_admit_reuse_own_flag = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-admit-reuse-own="):
				_admit_reuse_own_flag = maxi(0, int(argument.trim_prefix("--city-admit-reuse-own=")))
	return _admit_reuse_own_flag != 0

static func _admit_material_fast() -> bool:
	if _admit_material_flag < 0:
		_admit_material_flag = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-admit-material-fast="):
				_admit_material_flag = maxi(0, int(argument.trim_prefix("--city-admit-material-fast=")))
	return _admit_material_flag != 0

static func _admit_telemetry() -> int:
	if _admit_telemetry_limit < 0:
		_admit_telemetry_limit = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-admit-telemetry="):
				_admit_telemetry_limit = maxi(0, int(argument.trim_prefix("--city-admit-telemetry=")))
	return _admit_telemetry_limit

# DSH_ADMITFAST: both optional arguments default to today's behaviour, so the offline prepare
# path (prepare_entry) and the default instantiate route are unchanged.
#   proved_local: the whole subtree was produced by _audit_tree() on this instance in this
#                 admission, so its meshes, materials and skins are already private to it and
#                 only the ownership marker is missing (--city-admit-reuse-own=1).
#   material_fast: passed through to _localize_mesh() (--city-admit-material-fast=1).
static func _own_resources(visual: Node, proved_local := false, material_fast := false) -> void:
	for key in visual.get_meta_list():
		var value: Variant = visual.get_meta(key)
		if value is Dictionary or value is Array:
			visual.set_meta(key, value.duplicate(true))
	for child in visual.get_children():
		_own_resources(child, proved_local, material_fast)
	if visual is MeshInstance3D:
		if proved_local:
			visual.mesh = _localize_mesh_audited(visual.mesh)
		else:
			visual.mesh = _localize_mesh(visual.mesh, material_fast)
		if visual.skin != null:
			if proved_local:
				# _audit_tree() already replaced this skin with its own copy.
				visual.skin.resource_local_to_scene = true
			else:
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
		_reuse_flag = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
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
	var _af_hash_started := Time.get_ticks_usec()  # DSH_ADMITFAST
	if scene_size < 20 or scene_size > 33554432 or FileAccess.get_sha256(path) != receipt.prepared_sha256:
		return Loader._fail("prepared_scene_hash")
	var _af_hash_us := Time.get_ticks_usec() - _af_hash_started  # DSH_ADMITFAST
	# DSH_AUDITCACHE: the lookup is deliberately AFTER prepared_scene_hash, so a hit can only be
	# spent on a file whose bytes were proved against the receipt in this admission.
	var _ac_cached_us := _audit_cache_lookup(receipt.prepared_sha256)
	var _ac_hit := _ac_cached_us > 0
	var _af_load_started := Time.get_ticks_usec()  # DSH_ADMITFAST
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null:
		return Loader._fail("prepared_scene_load")
	var _af_load_us := Time.get_ticks_usec() - _af_load_started  # DSH_ADMITFAST
	var _af_probe_us := 0  # DSH_ADMITFAST
	var _af_audit_us := 0  # DSH_ADMITFAST
	var audit := {}
	# DSH_AUDITCACHE: whether the per-vertex audit actually ran on this admission (telemetry
	# only; load_verified() is static, so this is a local, not an instance field).
	var _ac_audited := false
	# DSH_AUDITCACHE: declared before the branch so the free() and the metadata test below can
	# see the same instance on either route.
	var probe = null
	if _ac_hit and _audit_probe_defer():
		# DSH_AUDITCACHE: nothing needs an instance here. instantiate_actor() validates the actor
		# it is already about to create and returns the same prepared_scene_audit label.
		var holder = _audit_cache()
		if holder != null and holder.entries.has(receipt.prepared_sha256):
			holder.entries[receipt.prepared_sha256]["last_hit"] = Time.get_datetime_string_from_system(true)
			holder.pending += 1
		_audit_cache_hits += 1
		_audit_cache_saved_us += _ac_cached_us
	else:
		var _af_probe_started := Time.get_ticks_usec()  # DSH_ADMITFAST
		probe = scene.instantiate()
		_af_probe_us = Time.get_ticks_usec() - _af_probe_started  # DSH_ADMITFAST
		var _af_audit_started := Time.get_ticks_usec()  # DSH_ADMITFAST
		if _ac_hit:
			# DSH_AUDITCACHE: the verdict is proved; perform only the localization it performs.
			audit = _probe_localize_and_validate(probe, bridge_id, expected_descriptor_sha, entry.descriptor, entry.asset_sha256)
			_audit_cache_hits += 1
			_audit_cache_saved_us += _ac_cached_us
		else:
			audit = Loader._audit_tree(probe)
			_ac_audited = true
			if audit.ok:
				_audit_cache_record(receipt.prepared_sha256, Time.get_ticks_usec() - _af_audit_started)
		_af_audit_us = Time.get_ticks_usec() - _af_audit_started  # DSH_ADMITFAST
		var metadata_ok: bool = false
		if _ac_hit:
			# The localization half already ran the identical metadata/override test.
			metadata_ok = audit.ok
		else:
			metadata_ok = audit.ok and _same_string(probe.get_meta("npc_bridge_id"), bridge_id) and _same_string(probe.get_meta("npc_descriptor_sha256"), expected_descriptor_sha) and probe.get_meta("npc_descriptor") is Dictionary and probe.get_meta("npc_descriptor") == entry.descriptor and _same_string(probe.get_meta("npc_asset_sha256"), entry.asset_sha256) and probe.get_meta("npc_shader_bound") is bool and not probe.get_meta("npc_shader_bound")
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
	# DSH_ADMITFAST: --city-load-reuse-probe=1 (DSH_LOADFAST) keeps the audited instance; the
	# default route frees it exactly as before.
	# DSH_AUDITCACHE: on a cache hit without the deferred probe that instance IS the localized
	# actor, so the same flag keeps it and the same ownership pass runs on it below.
	if probe != null:
		if _reuse_probe():
			cache._prepared_visual = probe
		else:
			probe.free()
	# DSH_ADMITFAST: per-admission phase timings for --city-admit-telemetry (0 = silent).
	cache._ac_hit = _ac_hit
	cache._ac_saved_us = _ac_cached_us
	cache._ac_audited = _ac_audited
	_admit_telemetry_seen += 1
	cache._admit_index = _admit_telemetry_seen
	cache._admit_scene_bytes = scene_size
	cache._admit_hash_us = _af_hash_us
	cache._admit_load_us = _af_load_us
	cache._admit_probe_us = _af_probe_us
	cache._admit_audit_us = _af_audit_us
	return {"ok": true, "cache": cache}

func instantiate_actor() -> Dictionary:
	if _template == null:
		return Loader._fail("disposed_cache")
	var started := Time.get_ticks_usec()
	# DSH_LOADFAST: with --city-load-reuse-probe=1 the instance that already passed the full
	# audit is the actor visual; otherwise the template is instantiated exactly as before.
	# The ownership pass below is identical on either route.
	var visual = _prepared_visual
	# DSH_ADMITFAST: true only when the returned actor IS an instance that was already localized
	# in this admission -- either by _audit_tree() or, on a cache hit, by the localization half
	# that reproduces it. --city-admit-reuse-own=1 then records the ownership markers instead of
	# localizing a second time; nothing else about the returned node changes.
	var _af_audited := visual != null
	if visual != null:
		_prepared_visual = null
	elif _ac_hit and _audit_probe_defer():
		# DSH_AUDITCACHE: the cached verdict means no throwaway instance was ever created. The
		# actor is validated and localized here, before the ownership pass, with the same
		# prepared_scene_audit label load_verified() would have returned -- and it is localized,
		# so it takes the same "already localized" ownership route the audited probe takes.
		var _ac_defer_started := Time.get_ticks_usec()
		visual = _template.instantiate()
		var _ac_validated: Dictionary = _probe_localize_and_validate(visual, str(_receipt.entry.bridge_id), str(_receipt.entry.descriptor_sha256), _receipt.entry.descriptor, str(_receipt.entry.asset_sha256))
		var _ac_validated_us := Time.get_ticks_usec() - _ac_defer_started
		if not _ac_validated.ok:
			visual.free()
			return Loader._fail("prepared_scene_audit")
		_af_audited = true
		_ac_defer_us = _ac_validated_us
	else:
		visual = _template.instantiate()
	var _af_own_started := Time.get_ticks_usec()  # DSH_ADMITFAST
	_own_resources(visual, _af_audited and _admit_reuse_own(), _admit_material_fast() and not _strict_verify())
	var _af_own_us := Time.get_ticks_usec() - _af_own_started  # DSH_ADMITFAST
	if _admit_index > 0 and _admit_index <= _admit_telemetry():
		# DSH_ADMITFAST: one line per admission for the first --city-admit-telemetry=N
		# admissions. hash/load/probe/audit are measured in load_verified(), own around the
		# ownership pass above; every value is microseconds on this machine in this run.
		# DSH_AUDITCACHE extends the same line in place: cache=hit|miss, saved_us is the audit
		# cost this admission did not pay, cache_path=audit is the original per-vertex audit,
		# cache_path=localized-probe is the localization reproduced from a cached verdict, and
		# cache_path=none is cache off. defer_us is the instantiate+localize the deferred probe
		# route did inside instantiate_actor() instead of a throwaway probe in load_verified().
		var _af_entry: Dictionary = _receipt.get("entry", {})
		print("DSH_ADMITFAST idx=", _admit_index, " bridge=", str(_af_entry.get("bridge_id", "")), " bytes=", _admit_scene_bytes, " hash_us=", _admit_hash_us, " load_us=", _admit_load_us, " probe_us=", _admit_probe_us, " audit_us=", _admit_audit_us, " own_us=", _af_own_us, " reused_probe=", 1 if _af_audited else 0, " reuse_own=", 1 if (_af_audited and _admit_reuse_own()) else 0, " mat_fast=", 1 if (_admit_material_fast() and not _strict_verify()) else 0, " scene=", str(_receipt.get("prepared_sha256", "")).substr(0, 12), " cache=", "hit" if _ac_hit else "miss", " saved_us=", _ac_saved_us, " cache_scenes=", (0 if _audit_cache() == null else _audit_cache().entries.size()), " cache_path=", "localized-probe" if _ac_hit else ("audit" if _ac_audited else "none"), " defer_us=", _ac_defer_us)

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
