extends RefCounted
## Read-only owner audit for the immutable actual main; no caller root map accepted.
const MAIN_SHA := "faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const PRINTSHOP_ID := "REBUILD-VISUAL-print_shop-001"
var _main: Node3D
var _ordinary: Dictionary = {}
var _snapshot: Dictionary = {}
var _state := "NEW"

func begin(main: Node3D, catalog: Dictionary) -> Dictionary:
	if _state != "NEW" or not is_instance_valid(main) or not main.is_inside_tree(): return {"ok": false, "error": "invalid-main-lifetime"}
	if _sha(FileAccess.get_file_as_bytes("res://scripts/main.gd")) != MAIN_SHA or _sha(FileAccess.get_file_as_bytes("res://data/block.json")) != BLOCK_SHA: return {"ok": false, "error": "actual-owner-source-drift"}
	var source_script: Script = load("res://scripts/main.gd")
	if main.get_script() != source_script: return {"ok": false, "error": "not-actual-main-owner"}
	if str(main.get("static_batch_status")) != "disabled" or main.get("_static_batch_lease") != null: return {"ok": false, "error": "static-batch-owner-mapping-required"}
	var block: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	if not block is Dictionary or main.get("_block") != block: return {"ok": false, "error": "actual-block-revision-drift"}
	var rows: Array = block.get("buildings", []) + block.get("decor", [])
	if rows.size() != 16: return {"ok": false, "error": "actual-authored-count-drift"}
	var catalog_by_id: Dictionary = {}
	for row: Dictionary in catalog.get("objects", []):
		if row.has("resourceId"): catalog_by_id[str(row.id)] = row
	var roots: Dictionary = {}
	for node: Node in main.get_children():
		if node is Node3D and not node is CollisionObject3D and node.has_meta("source_id"):
			var id := str(node.get_meta("source_id"))
			if roots.has(id): return {"ok": false, "error": "duplicate-live-source-root"}
			roots[id] = node
	if roots.size() != 16: return {"ok": false, "error": "live-root-count-drift"}
	var scenes: Variant = main.get("_resource_scenes")
	if not scenes is Dictionary: return {"ok": false, "error": "actual-scene-registry-missing"}
	_main = main
	for source: Dictionary in rows:
		var id := str(source.get("id", ""))
		if not roots.has(id) or not catalog_by_id.has(id): return _refuse("actual-source-id-missing:" + id)
		var catalog_row: Dictionary = catalog_by_id[id]
		if str(source.get("assetId", "")) != str(catalog_row.get("assetId", "")) or source.get("positionLocalM") != catalog_row.get("positionLocalM") or not _same_source_transform(source.get("transform", {}),catalog_row.get("transform", {})): return _refuse("catalog-live-model-or-transform-drift:" + id)
		var resource_id := str(catalog_row.get("resourceId", ""))
		var source_path := str(source.get("path", ""))
		if _sha(FileAccess.get_file_as_bytes(source_path)) != resource_id or not scenes.has(source_path) or not scenes[source_path] is PackedScene: return _refuse("actual-model-sha-or-import-drift:" + id)
		var owner_root: Node3D = roots[id]
		var expected_position := _v3(source.positionLocalM)
		var placement: Dictionary = source.transform
		var uniform := float(placement.get("uniformScale", 1.0))
		var horizontal: Array = placement.get("horizontalScale", [1.0, 1.0])
		var expected_scale := Vector3(uniform * float(horizontal[0]), uniform, uniform * float(horizontal[1]))
		if owner_root.position != expected_position or owner_root.rotation.y != deg_to_rad(float(placement.get("yawDegrees", 0.0))) or owner_root.scale != expected_scale: return _refuse("actual-root-transform-drift:" + id)
		if owner_root.get_child_count() != 1 or not owner_root.get_child(0) is Node3D: return _refuse("actual-visual-tree-drift:" + id)
		var visual := owner_root.get_child(0) as Node3D
		if visual.position != _v3(placement.get("modelLocalOffsetM", [0.0, 0.0, 0.0])): return _refuse("actual-model-offset-drift:" + id)
		if id == PRINTSHOP_ID: continue # Interior replaces source meshes; separate owner receipt required.
		var reference := (scenes[source_path] as PackedScene).instantiate() as Node3D
		if reference == null: return _refuse("actual-reference-import-failed:" + id)
		reference.position = visual.position # main._add_asset applies this authored offset after instantiation.
		var match := _same_native_tree(reference, visual)
		reference.free()
		if not match: return _refuse("actual-mesh-material-drift:" + id)
		_ordinary[str(catalog_row.key)] = owner_root
		_snapshot[str(catalog_row.key)] = {"id": id, "rootInstanceId": owner_root.get_instance_id(), "resourceId": resource_id, "transform": owner_root.transform, "visualTransform": visual.transform, "scene": scenes[source_path], "path": source_path}
	if _ordinary.size() != 15: return _refuse("ordinary-owner-coverage-drift")
	_state = "HOLD_PRINTSHOP_INTERIOR_RECEIPT"
	return {"ok": false, "error": "printshop-interior-owner-receipt-required", "verifiedOrdinary": 15, "required": 16, "state": _state}

func verify() -> Dictionary:
	if _state != "HOLD_PRINTSHOP_INTERIOR_RECEIPT" or not is_instance_valid(_main) or not _main.is_inside_tree(): return {"ok": false, "error": "stale-owner-receipt"}
	if str(_main.get("static_batch_status")) != "disabled" or _main.get("_static_batch_lease") != null: return {"ok": false, "error": "static-batch-owner-mapping-required"}
	if _sha(FileAccess.get_file_as_bytes("res://scripts/main.gd")) != MAIN_SHA or _sha(FileAccess.get_file_as_bytes("res://data/block.json")) != BLOCK_SHA: return {"ok": false, "error": "actual-owner-source-drift"}
	var scenes: Variant = _main.get("_resource_scenes")
	if not scenes is Dictionary: return {"ok": false, "error": "actual-scene-registry-missing"}
	for key: String in _snapshot:
		var entry: Dictionary = _snapshot[key]
		var root: Node3D = _ordinary[key]
		if not is_instance_valid(root) or root.get_instance_id() != entry.rootInstanceId or root.get_parent() != _main or root.transform != entry.transform or root.get_child_count() != 1: return {"ok": false, "error": "live-root-lifetime-or-transform-drift:" + key}
		var visual := root.get_child(0) as Node3D
		if visual == null or visual.transform != entry.visualTransform: return {"ok": false, "error": "live-visual-transform-drift:" + key}
		if not scenes.has(entry.path) or scenes[entry.path] != entry.scene or _sha(FileAccess.get_file_as_bytes(entry.path)) != entry.resourceId: return {"ok": false, "error": "live-resource-revision-drift:" + key}
		var reference := (entry.scene as PackedScene).instantiate() as Node3D
		if reference == null: return {"ok": false, "error": "live-reference-import-failed:" + key}
		reference.position = visual.position
		var same := _same_native_tree(reference,visual)
		reference.free()
		if not same: return {"ok": false, "error": "live-mesh-material-drift:" + key}
	return {"ok": false, "error": "printshop-interior-owner-receipt-required", "verifiedOrdinary": 15}

func verified_roots() -> Dictionary:
	# No 16/16 receipt exists while Printshop's separate interior owner is HOLD.
	return {}

func _same_native_tree(reference: Node, live: Node) -> bool:
	if reference.get_class() != live.get_class() or reference.name != live.name or reference.get_child_count() != live.get_child_count(): return false
	if reference is Node3D and live is Node3D and reference.transform != live.transform: return false
	if reference is MeshInstance3D:
		var a := reference as MeshInstance3D
		var b := live as MeshInstance3D
		if a.mesh == null or b.mesh == null or a.mesh != b.mesh or a.mesh.get_surface_count() == 0: return false
		for surface in a.mesh.get_surface_count():
			if a.get_active_material(surface) != b.get_active_material(surface): return false
	for i in reference.get_child_count():
		if not _same_native_tree(reference.get_child(i),live.get_child(i)): return false
	return true

func _refuse(error: String) -> Dictionary:
	_state = "FAILED"
	_ordinary.clear()
	_snapshot.clear()
	return {"ok": false, "error": error}

func _same_source_transform(a: Dictionary, b: Dictionary) -> bool:
	return a.get("positionM", []) == b.get("positionM", []) and a.get("yawDegrees", 0.0) == b.get("yawDegrees", 0.0) and a.get("uniformScale", 1.0) == b.get("uniformScale", 1.0) and a.get("modelLocalOffsetM", [0.0,0.0,0.0]) == b.get("modelLocalOffsetM", [0.0,0.0,0.0]) and a.get("horizontalScale", [1.0,1.0]) == b.get("horizontalScale", [1.0,1.0])

func _v3(row: Array) -> Vector3: return Vector3(float(row[0]),float(row[1]),float(row[2]))
func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
