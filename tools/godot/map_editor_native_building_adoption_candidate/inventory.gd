extends RefCounted
## Read-only diagnostic. A resolved node is NOT an editor/authority admission.
const PRINTSHOP := "REBUILD-VISUAL-print_shop-001"

func inspect(owner: Node3D, records: Array, full_buildings: Array, interior: Node3D = null) -> Dictionary:
	var errors: Array[String] = []
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion():
		return {"ok": false, "errors": ["missing-native-owner"]}
	var known: Dictionary = {}
	for record: Dictionary in full_buildings:
		if not record.get("id") is String or str(record.id).is_empty() or known.has(str(record.id)):
			errors.append("invalid-or-duplicate-full-source-id")
			continue
		known[str(record.id)] = true
	var roots: Dictionary = {}
	var siblings: Dictionary = {}
	for node: Node in owner.get_children():
		if not node is Node3D or not node.has_meta("source_id"): continue
		var id := str(node.get_meta("source_id"))
		if node is StaticBody3D:
			if not siblings.has(id): siblings[id] = []
			siblings[id].append(node)
		else:
			if roots.has(id): errors.append("duplicate-visual:" + id)
			roots[id] = node
	var rows: Array = []
	var present: Dictionary = {}
	for record: Dictionary in records:
		if not record.get("id") is String or str(record.id).is_empty():
			errors.append("invalid-record-source-id"); continue
		var id := str(record.id)
		if present.has(id): errors.append("duplicate-record-source-id:" + id); continue
		present[id] = true
		if not known.has(id): errors.append("unknown-record-source-id:" + id); continue
		if not record.get("collisionBodiesM") is Array: errors.append("missing-collision-records:" + id); continue
		if not roots.has(id):
			errors.append("missing-visual:" + id)
			continue
		var visual: Node3D = roots[id]
		if visual.is_queued_for_deletion(): errors.append("queued-visual:" + id)
		var bodies: Array = siblings.get(id, [])
		var indices: Array = []
		for body: StaticBody3D in bodies:
			if body.is_queued_for_deletion(): errors.append("queued-collider:" + id)
			if not body.has_meta("source_index"): errors.append("missing-source-index:" + id)
			var index := int(body.get_meta("source_index", -1))
			if index in indices: errors.append("duplicate-native-source-index:" + id)
			indices.append(index)
		var expected: Array = []
		for spec: Dictionary in record.collisionBodiesM:
			if not spec.has("sourceIndex"): errors.append("missing-record-source-index:" + id); continue
			var index := int(spec.sourceIndex)
			if index in expected: errors.append("duplicate-record-source-index:" + id)
			expected.append(index)
		indices.sort(); expected.sort()
		var special := id == PRINTSHOP and is_instance_valid(interior)
		if special:
			if interior.is_queued_for_deletion() or not interior.is_inside_tree() or interior.get_parent() != owner:
				errors.append("invalid-special-owner-lifetime")
			if not bodies.is_empty(): errors.append("printshop-envelope-still-present")
		else:
			if indices != expected: errors.append("source-collider-identity-mismatch:" + id)
		var special_bodies: Array = []
		if special: _bodies(interior, special_bodies)
		for body: StaticBody3D in special_bodies:
			if body.is_queued_for_deletion(): errors.append("queued-special-collider:" + id)
		rows.append({"source_id": id, "registry_id": "buildings:" + id,
			"visual": visual, "native_sibling_bodies": bodies, "source_indices": indices,
			"special_owner": interior if special else null,
			"special_bodies": special_bodies, "special": special,
			"owner_id": owner.get_instance_id(), "parent_id": visual.get_parent().get_instance_id(),
			"editable_admitted": false})
	var outside: Array[String] = []
	for record: Dictionary in full_buildings:
		if not present.has(str(record.id)): outside.append(str(record.id))
	outside.sort()
	return {"ok": errors.is_empty(), "errors": errors, "rows": rows,
		"outside_crop_building_ids": outside, "full_building_count": full_buildings.size(),
		"crop_building_count": records.size(), "authority_admitted": false}

func _bodies(node: Node, result: Array) -> void:
	if node is StaticBody3D: result.append(node)
	for child: Node in node.get_children(): _bodies(child, result)

func fingerprint(node: Node) -> Array:
	var result: Array = []
	_capture(node, result)
	return result

func _capture(node: Node, result: Array) -> void:
	var row: Array = [node.get_instance_id(), node.get_parent().get_instance_id() if node.get_parent() else 0, node.get_child_count()]
	if node is Node3D: row.append_array([node.transform, node.visible])
	if node is CollisionObject3D: row.append_array([node.collision_layer, node.collision_mask])
	if node is CollisionShape3D:
		row.append_array([node.shape, node.disabled])
		if node.shape is ConvexPolygonShape3D: row.append(node.shape.points)
		if node.shape is ConcavePolygonShape3D: row.append(node.shape.get_faces())
	if node is MeshInstance3D:
		row.append_array([node.mesh, node.material_override, node.cast_shadow])
		if node.mesh:
			for i: int in node.mesh.get_surface_count(): row.append(node.get_active_material(i))
	if node is MultiMeshInstance3D: row.append_array([node.multimesh, node.material_override, node.cast_shadow])
	result.append(row)
	for child: Node in node.get_children(): _capture(child, result)
