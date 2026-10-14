extends RefCounted
## Read-only diagnostic receipt for the immutable actual-main checkpoint.
## It never authorizes borrowing: Printshop has no owner revision/seal API.
const Trusted = preload("res://scripts/map_editor/trusted_json.gd")
const MAIN_SHA := "faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const CATALOG_SHA := "ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e"
const INTERIOR_SHA := "f6f082584ada23dcd55b384c629505730c80a59080768910a17c653d7eb1b5df"
const FINISH_SHA := "666bb28093d3bc9fbf17b702dda9c460d1364c64dee63c236b02fc9d80519ced"
const PACKAGE_SHA := "958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b"
const MODEL_SHA := "ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97"
const SOURCE_ID := "REBUILD-VISUAL-print_shop-001"
const MODEL_PATH := "res://assets/buildings/print_shop.ad7b8ef7e7e4.glb"
const HOLD := "printshop-owner-revision-or-seal-required"
var _main: Node3D
var _root: Node3D
var _interior: Node3D
var _scene: WeakRef
var _scene_id := 0
var _rows: Array[Dictionary] = []
var _refs: Array[WeakRef] = []
var _caches: Dictionary = {}
var _doors: Dictionary = {}
var _restores_snapshot: Array[Dictionary] = []
var _state := "NEW"

static func _sha(path: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes(path))
	return hash.finish().hex_encode()

func _failure(error: String) -> Dictionary:
	_state = "FAILED"
	_rows.clear()
	_refs.clear()
	_caches.clear()
	_doors.clear()
	_restores_snapshot.clear()
	return {"ok": false, "error": error, "verifiedRoot": false}

func _hold() -> Dictionary:
	return {"ok": false, "error": HOLD, "state": "HOLD", "verifiedRoot": false, "nodes": _rows.size(), "materialCache": _caches.get("materials", {}).size(), "meshCache": _caches.get("meshes", {}).size(), "doors": _doors.size()}

func _watch(value: Object) -> int:
	if not is_instance_valid(value): return 0
	_refs.append(weakref(value))
	return value.get_instance_id()

func _resource_id(value: Variant) -> int:
	return _watch(value) if value is Object and is_instance_valid(value) else 0

func _materials(mesh: Mesh, instance: MeshInstance3D) -> Array:
	var ids: Array = []
	if mesh == null: return ids
	for surface in mesh.get_surface_count():
		ids.append(_resource_id(instance.get_active_material(surface)))
	return ids

func _collect(node: Node, address: String) -> Dictionary:
	var row := {"address": address, "id": _watch(node), "parent": node.get_parent().get_instance_id() if node.get_parent() != null else 0, "class": node.get_class(), "name": str(node.name), "children": node.get_child_count()}
	if node is Node3D:
		row["transform"] = var_to_bytes((node as Node3D).transform)
		row["visible"] = (node as Node3D).visible
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		row["mesh"] = _resource_id(mesh)
		row["materials"] = _materials(mesh, node as MeshInstance3D)
		row["material_override"] = _resource_id((node as MeshInstance3D).material_override)
		row["material_overlay"] = _resource_id((node as MeshInstance3D).material_overlay)
	if node is MultiMeshInstance3D:
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		row["multimesh"] = _resource_id(multi)
		row["mesh"] = _resource_id(multi.mesh) if multi != null else 0
		row["instances"] = multi.instance_count if multi != null else -1
		row["material_override"] = _resource_id((node as MultiMeshInstance3D).material_override)
		row["material_overlay"] = _resource_id((node as MultiMeshInstance3D).material_overlay)
		var multi_materials: Array = []
		if multi != null and multi.mesh != null:
			for surface in multi.mesh.get_surface_count(): multi_materials.append(_resource_id(multi.mesh.surface_get_material(surface)))
		row["materials"] = multi_materials
	if node is CollisionObject3D:
		row["layer"] = (node as CollisionObject3D).collision_layer
		row["mask"] = (node as CollisionObject3D).collision_mask
		row["source_id"] = str(node.get_meta("source_id", ""))
		row["interior_kind"] = str(node.get_meta("interior_kind", ""))
	if node is CollisionShape3D:
		row["shape"] = _resource_id((node as CollisionShape3D).shape)
		row["disabled"] = (node as CollisionShape3D).disabled
	_rows.append(row)
	for index in node.get_child_count():
		_collect(node.get_child(index), address + "/" + str(index))
	return row

func _cache_ids(source: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in source:
		if not source[key] is Resource: return {}
		result[str(key)] = _resource_id(source[key])
	return result

func _restore_ids(source: Array, visual: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for saved: Variant in source:
		if not saved is Dictionary or not saved.get("node") is MeshInstance3D or not is_instance_valid(saved.node) or not visual.is_ancestor_of(saved.node) or not saved.get("mesh") is Mesh or not saved.get("visible") is bool: return []
		result.append({"node": _watch(saved.node), "mesh": _resource_id(saved.mesh), "visible": saved.visible})
	return result

func _door_ids(interior: Node3D, package: Dictionary) -> Dictionary:
	var source: Variant = interior.get("_doors")
	if not source is Dictionary or source.size() != 2: return {}
	var result := {}
	for key in ["public", "service"]:
		if not source.has(key) or not source[key] is Dictionary: return {}
		var door: Dictionary = source[key]
		if not door.get("node") is Node3D or not is_instance_valid(door.node) or door.node.get_parent() != interior or not Trusted.equal(door.get("spec", {}), package.doors[key]): return {}
		if not door.get("base") is Transform3D or not door.get("bounds") is Array: return {}
		var fraction := float(door.get("fraction", -1.0))
		var target := float(door.get("target", -1.0))
		if not is_finite(fraction) or not is_finite(target) or fraction < 0.0 or fraction > 1.0 or target < 0.0 or target > 1.0: return {}
		result[key] = {"node": _watch(door.node), "base": var_to_bytes(door.base), "fraction": var_to_bytes(fraction), "target": var_to_bytes(target), "bounds": var_to_bytes(door.bounds), "transform": var_to_bytes(door.node.transform)}
	return result

func begin(main: Node3D, catalog: Dictionary) -> Dictionary:
	if _state != "NEW" or not is_instance_valid(main) or not main.is_inside_tree(): return _failure("invalid-main-lifetime")
	if _sha("res://scripts/main.gd") != MAIN_SHA or _sha("res://data/block.json") != BLOCK_SHA or _sha("res://data/map_editor/catalog.json") != CATALOG_SHA: return _failure("immutable-main-block-catalog-drift")
	if _sha("res://scripts/preview_printshop_interior.gd") != INTERIOR_SHA or _sha("res://scripts/preview_interior_finish.gd") != FINISH_SHA or _sha("res://data/printshop_interior.json") != PACKAGE_SHA or _sha(MODEL_PATH) != MODEL_SHA: return _failure("printshop-package-model-or-adapter-drift")
	if main.get_script() != load("res://scripts/main.gd") or str(main.get("printshop_status")) != "ready" or str(main.get("static_batch_status")) != "disabled" or main.get("_static_batch_lease") != null: return _failure("not-ready-unbatched-actual-main")
	var block: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	var package: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var source_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/catalog.json"))
	if not block is Dictionary or not package is Dictionary or not source_catalog is Dictionary or not Trusted.equal(catalog, source_catalog) or not Trusted.equal(main.get("_block"), block) or not Trusted.equal(main.get("_printshop_data"), package): return _failure("actual-owner-data-revision-drift")
	if package.get("schema") != "mafiozi-printshop-interior-v1" or package.get("sourceId") != SOURCE_ID or package.get("assetSha256") != MODEL_SHA: return _failure("printshop-source-package-identity-drift")
	var source_row: Dictionary = {}
	for row: Dictionary in block.get("buildings", []) + block.get("decor", []):
		if row.get("id") == SOURCE_ID:
			if not source_row.is_empty(): return _failure("duplicate-printshop-source-id")
			source_row = row
	if source_row.is_empty() or source_row.get("path") != MODEL_PATH or source_row.get("binding", {}).get("sha256") != MODEL_SHA or not Trusted.equal(source_row.get("transform", {}), package.get("transform", {})): return _failure("printshop-block-model-drift")
	var catalog_count := 0
	for row: Dictionary in catalog.get("objects", []):
		if row.get("id") == SOURCE_ID:
			catalog_count += 1
			if row.get("resourceId") != MODEL_SHA: return _failure("printshop-catalog-resource-drift")
	if catalog_count != 1: return _failure("printshop-catalog-identity-drift")
	var root_count := 0
	for child: Node in main.get_children():
		if child is Node3D and child.get_meta("source_id", "") == SOURCE_ID:
			root_count += 1
			_root = child
	if root_count != 1 or _root.get_child_count() != 1 or not _root.get_child(0) is Node3D: return _failure("printshop-live-root-drift")
	var visual: Node3D = _root.get_child(0)
	var placement: Dictionary = source_row.transform
	var local: Array = source_row.positionLocalM
	var horizontal: Array = placement.horizontalScale
	var uniform := float(placement.uniformScale)
	if _root.position != Vector3(float(local[0]), float(local[1]), float(local[2])) or _root.rotation.y != deg_to_rad(float(placement.yawDegrees)) or _root.scale != Vector3(uniform * float(horizontal[0]), uniform, uniform * float(horizontal[1])): return _failure("printshop-live-root-placement-drift")
	var offset: Array = placement.modelLocalOffsetM
	if visual.position != Vector3(float(offset[0]), float(offset[1]), float(offset[2])): return _failure("printshop-visual-offset-drift")
	var interior: Variant = main.get("_printshop")
	if not interior is Node3D or not is_instance_valid(interior) or interior.get_parent() != main or interior.get_script() != load("res://scripts/preview_printshop_interior.gd") or not interior.get("ready_for_use") or interior.get("_visual") != visual or not visual.has_meta("printshop_interior_attached"): return _failure("printshop-interior-lifetime-or-binding-drift")
	if not Trusted.equal(interior.get("_data"), package): return _failure("printshop-interior-package-revision-drift")
	_interior = interior
	var scenes: Variant = main.get("_resource_scenes")
	if not scenes is Dictionary or not scenes.get(MODEL_PATH) is PackedScene: return _failure("printshop-imported-model-scene-missing")
	_scene = weakref(scenes[MODEL_PATH])
	_scene_id = scenes[MODEL_PATH].get_instance_id()
	var mesh_cache: Variant = interior.get("_mesh_cache")
	var material_cache: Variant = interior.get("_material_cache")
	var restores: Variant = interior.get("_restores")
	if not mesh_cache is Dictionary or not material_cache is Dictionary or not restores is Array or restores.size() != package.overrides.size() + package.hideOriginalNames.size(): return _failure("printshop-generated-cache-or-restore-drift")
	_caches = {"meshes": _cache_ids(mesh_cache), "materials": _cache_ids(material_cache)}
	if _caches.meshes.size() != mesh_cache.size() or _caches.materials.size() != material_cache.size(): return _failure("printshop-resource-cache-identity-drift")
	_restores_snapshot = _restore_ids(restores, visual)
	if _restores_snapshot.size() != restores.size(): return _failure("printshop-original-mesh-restoration-identity-drift")
	_doors = _door_ids(interior, package)
	if _doors.size() != 2: return _failure("printshop-door-identity-drift")
	_main = main
	_collect(_root, "root")
	_collect(_interior, "interior")
	var colliders := 0
	for row: Dictionary in _rows:
		if row.get("class") == "StaticBody3D" and row.get("source_id") == SOURCE_ID and row.get("interior_kind") in ["door:public", "door:service", "source-static", "source-floor-ceiling"]: colliders += 1
	if colliders != 111: return _failure("printshop-collider-count-or-owner-drift")
	_state = "HOLD"
	return _hold()

func verify() -> Dictionary:
	if _state != "HOLD" or not is_instance_valid(_main) or not _main.is_inside_tree() or not is_instance_valid(_root) or not is_instance_valid(_interior) or _root.get_parent() != _main or _interior.get_parent() != _main: return _failure("printshop-owner-lifetime-drift")
	if _sha("res://scripts/main.gd") != MAIN_SHA or _sha("res://data/block.json") != BLOCK_SHA or _sha("res://data/map_editor/catalog.json") != CATALOG_SHA or _sha("res://scripts/preview_printshop_interior.gd") != INTERIOR_SHA or _sha("res://scripts/preview_interior_finish.gd") != FINISH_SHA or _sha("res://data/printshop_interior.json") != PACKAGE_SHA or _sha(MODEL_PATH) != MODEL_SHA: return _failure("printshop-source-revision-drift")
	if _main.get("_printshop") != _interior or str(_main.get("printshop_status")) != "ready" or str(_main.get("static_batch_status")) != "disabled" or _main.get("_static_batch_lease") != null or not _interior.get("ready_for_use") or _root.get_child_count() != 1 or _interior.get("_visual") != _root.get_child(0): return _failure("printshop-owner-binding-revision-drift")
	if _scene == null or not is_instance_valid(_scene.get_ref()) or _scene.get_ref().get_instance_id() != _scene_id: return _failure("printshop-imported-scene-lifetime-drift")
	var scenes: Variant = _main.get("_resource_scenes")
	if not scenes is Dictionary or scenes.get(MODEL_PATH) != _scene.get_ref(): return _failure("printshop-imported-scene-binding-drift")
	var package: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	if not package is Dictionary or not Trusted.equal(_main.get("_printshop_data"), package) or not Trusted.equal(_interior.get("_data"), package): return _failure("printshop-source-package-revision-drift")
	for ref: WeakRef in _refs:
		if not is_instance_valid(ref.get_ref()): return _failure("printshop-node-or-resource-lifetime-drift")
	var prior_rows: Array[Dictionary] = _rows.duplicate(true)
	var prior_caches: Dictionary = _caches.duplicate(true)
	var prior_doors: Dictionary = _doors.duplicate(true)
	var prior_restores: Array[Dictionary] = _restores_snapshot.duplicate(true)
	_rows.clear()
	_refs.clear()
	_collect(_root, "root")
	_collect(_interior, "interior")
	if _rows != prior_rows: return _failure("printshop-node-mesh-material-or-collider-drift")
	var mesh_cache: Variant = _interior.get("_mesh_cache")
	var material_cache: Variant = _interior.get("_material_cache")
	if not mesh_cache is Dictionary or not material_cache is Dictionary: return _failure("printshop-cache-lifetime-drift")
	_caches = {"meshes": _cache_ids(mesh_cache), "materials": _cache_ids(material_cache)}
	if _caches != prior_caches: return _failure("printshop-generated-resource-identity-drift")
	var restores: Variant = _interior.get("_restores")
	if not restores is Array or _root.get_child_count() != 1: return _failure("printshop-source-restore-inventory-drift")
	_restores_snapshot = _restore_ids(restores, _root.get_child(0))
	if _restores_snapshot != prior_restores: return _failure("printshop-original-mesh-restoration-identity-drift")
	_doors = _door_ids(_interior, package)
	if _doors != prior_doors: return _failure("printshop-door-state-or-lifetime-drift")
	# Snapshot equality cannot attest transient mutation/restore between calls.
	return _hold()

func verified_root() -> Node3D:
	return null # Deliberately no positive receipt without an owner revision/seal.
