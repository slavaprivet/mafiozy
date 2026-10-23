extends RefCounted
## Read-only registration of the current imported block. Does not change main.
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const PRINTSHOP_ID := "REBUILD-VISUAL-print_shop-001"

static func attach(host: Node3D, block: Dictionary, game_camera: Camera3D, begin_edit: Callable, end_edit: Callable, additional_locked_ids: Array = []) -> Dictionary:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return {"ok": false, "error": "World host unavailable"}
	var index := Registry.new()
	var roots: Dictionary = {}
	var siblings: Dictionary = {}
	# One scan on registration; no work in gameplay frames.
	for node: Node in host.get_children():
		if not node is Node3D or not node.has_meta("source_id"):
			continue
		var id: String = str(node.get_meta("source_id"))
		if node is CollisionObject3D:
			if not siblings.has(id): siblings[id] = []
			siblings[id].append(node)
		else:
			if roots.has(id): return {"ok": false, "error": "Ambiguous source identity: " + id}
			roots[id] = node
	var catalog: Array = []
	for category: String in ["buildings", "decor"]:
		for row: Dictionary in block.get(category, []):
			var id: String = str(row.get("id", ""))
			if not roots.has(id): return {"ok": false, "error": "Missing live object: " + id}
			var editable: bool = id != PRINTSHOP_ID and id not in additional_locked_ids
			var record := {"id": id, "kind": category, "model": str(row.get("assetId", "")), "source": row.duplicate(true)}
			var registered: Dictionary = index.register_object(id, roots[id], record, siblings.get(id, []), editable)
			if not registered.ok: return registered
			catalog.append({"id": id, "label": str(row.get("assetId", id)), "category": "Здания" if category == "buildings" else "Городские объекты", "available": editable})
	var source: Dictionary = index.source_document("godot-preview-block")
	source.metadata = {"patch_version": 1, "source_sha256": _hash_file("res://data/block.json"), "originM": block.get("originM", []).duplicate(), "metresPerCell": block.get("metresPerCell", 4.1)}
	var controller := Controller.new()
	controller.name = "MapEditor"
	host.add_child(controller)
	var result: Dictionary = controller.setup(index, source, game_camera, begin_edit, end_edit, catalog)
	if not result.ok:
		controller.free()
		return result
	return {"ok": true, "controller": controller, "registry": index, "source": source, "locked_ids": [PRINTSHOP_ID] + additional_locked_ids}

static func _hash_file(path: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes(path))
	return hash.finish().hex_encode()
