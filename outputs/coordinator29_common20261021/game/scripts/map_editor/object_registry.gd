extends RefCounted
## Editor-only identity index. No per-frame world traversal or resource mutation.
## Detached source collision siblings follow the same affine delta as the visual.
var _entries: Dictionary = {}

func register_object(id: String, root: Node3D, record: Dictionary, dependencies: Array = [], editable: bool = true) -> Dictionary:
	if id.is_empty() or _entries.has(id) or not is_instance_valid(root):
		return {"ok": false, "error": "Invalid or duplicate identity"}
	if not root.is_inside_tree() or not root.global_transform.basis.determinant() > 0.000001:
		return {"ok": false, "error": "Invalid source transform"}
	var participants: Array = []
	var seen: Dictionary = {}
	for node: Variant in [root] + dependencies:
		if not node is Node3D or not is_instance_valid(node) or not node.is_inside_tree():
			return {"ok": false, "error": "Missing dependent node"}
		if seen.has(node.get_instance_id()):
			continue
		seen[node.get_instance_id()] = true
		# Descendants inherit their ancestor transform: never apply the delta twice.
		if node != root and root.is_ancestor_of(node):
			continue
		participants.append({"node": weakref(node), "frame": node.global_transform, "visible": node.visible})
	var bodies: Array = []
	for participant: Dictionary in participants:
		_collect_bodies(participant.node.get_ref(), bodies, {})
	var bounds: Array = []
	_collect_bounds(root, root.global_transform.affine_inverse(), bounds)
	_entries[id] = {"root": weakref(root), "base": root.global_transform, "participants": participants, "bodies": bodies, "record": record.duplicate(true), "editable": editable, "bounds": bounds, "deleted": false}
	return {"ok": true}

func _collect_bodies(node: Node, result: Array, seen: Dictionary) -> void:
	if node is CollisionObject3D and not seen.has(node.get_instance_id()):
		seen[node.get_instance_id()] = true
		result.append({"node": weakref(node), "layer": node.collision_layer, "mask": node.collision_mask})
	for child: Node in node.get_children():
		_collect_bodies(child, result, seen)

func _collect_bounds(node: Node, inverse: Transform3D, bounds: Array) -> void:
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		bounds.append((inverse * node.global_transform) * node.get_aabb())
	for child: Node in node.get_children():
		_collect_bounds(child, inverse, bounds)

func ids() -> Array:
	return _entries.keys()

func source_document(map_id: String) -> Dictionary:
	var objects: Array = []
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var row: Dictionary = entry.record.duplicate(true)
		row["id"] = id
		row["transform"] = encode_transform(entry.base)
		objects.append(row)
	return {"schema_version": 1, "map_id": map_id, "metadata": {}, "objects": objects}

static func encode_transform(frame: Transform3D) -> Dictionary:
	var rotation: Vector3 = frame.basis.get_euler()
	var scale: Vector3 = frame.basis.get_scale()
	return {"position": [frame.origin.x, frame.origin.y, frame.origin.z], "rotation": [rotation.x, rotation.y, rotation.z], "scale": [scale.x, scale.y, scale.z]}

static func decode_transform(data: Dictionary) -> Variant:
	var vectors: Array[Vector3] = []
	for key: String in ["position", "rotation", "scale"]:
		var value: Variant = data.get(key)
		if not value is Array or value.size() != 3:
			return null
		for number: Variant in value:
			if not (number is float or number is int) or not is_finite(float(number)):
				return null
		vectors.append(Vector3(value[0], value[1], value[2]))
	if vectors[2].x <= 0.0001 or vectors[2].y <= 0.0001 or vectors[2].z <= 0.0001:
		return null
	return Transform3D(Basis.from_euler(vectors[1]).scaled(vectors[2]), vectors[0])

func apply_document(document: Dictionary, dry_run: bool = false) -> Dictionary:
	var rows: Variant = document.get("objects")
	if not rows is Array:
		return {"ok": false, "error": "Missing objects"}
	var desired: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary or not _entries.has(row.get("id", "")) or desired.has(row.id):
			return {"ok": false, "error": "Unknown or duplicate object"}
		var frame: Variant = decode_transform(row.get("transform", {}))
		if frame == null:
			return {"ok": false, "error": "Invalid transform"}
		desired[row.id] = frame
	# Complete preflight before any visible or physics mutation.
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var changed: bool = not desired.has(id) or not desired[id].is_equal_approx(entry.base)
		if changed and not entry.editable:
			return {"ok": false, "error": "Object requires gameplay adapter: " + id}
		for participant: Dictionary in entry.participants:
			if not is_instance_valid(participant.node.get_ref()):
				return {"ok": false, "error": "Scene changed; rebuild index"}
		for body: Dictionary in entry.bodies:
			if not is_instance_valid(body.node.get_ref()):
				return {"ok": false, "error": "Collision changed; rebuild index"}
	if dry_run:
		return {"ok": true}
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var deleted: bool = not desired.has(id)
		var delta: Transform3D = Transform3D.IDENTITY if deleted else desired[id] * entry.base.affine_inverse()
		for participant: Dictionary in entry.participants:
			var node: Node3D = participant.node.get_ref()
			node.global_transform = delta * participant.frame
			node.visible = participant.visible and not deleted
		for body: Dictionary in entry.bodies:
			var node: CollisionObject3D = body.node.get_ref()
			node.collision_layer = 0 if deleted else body.layer
			node.collision_mask = 0 if deleted else body.mask
		entry.deleted = deleted
	return {"ok": true}

func pick(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> String:
	var selected := ""
	var nearest := distance
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001:
		return selected
	var end: Vector3 = origin + direction.normalized() * distance
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var root: Node3D = entry.root.get_ref()
		if entry.deleted or not is_instance_valid(root) or not root.is_visible_in_tree():
			continue
		var inverse: Transform3D = root.global_transform.affine_inverse()
		for box: AABB in entry.bounds:
			var hit: Variant = box.intersects_segment(inverse * origin, inverse * end)
			if hit is Vector3:
				var length: float = origin.distance_to(root.global_transform * hit)
				if length < nearest:
					nearest = length
					selected = id
	return selected

func is_editable(id: String) -> bool:
	return _entries.has(id) and _entries[id].editable

func create_copy(template_id: String, id: String, frame: Transform3D) -> Dictionary:
	if not id.begins_with("editor:") or _entries.has(id) or not is_editable(template_id):
		return {"ok": false, "error": "Недоступный шаблон или идентификатор"}
	var template: Dictionary = _entries[template_id]
	if template.deleted:
		return {"ok": false, "error": "Шаблон удалён; сначала восстановите исходный объект"}
	var clones: Array = []
	var delta: Transform3D = frame * template.base.affine_inverse()
	for participant: Dictionary in template.participants:
		var original: Node3D = participant.node.get_ref()
		if not is_instance_valid(original):
			for clone: Node in clones: clone.free()
			return {"ok": false, "error": "Шаблон отсутствует в сцене"}
		# Only admitted static owners can reach here. Resources are shared; no
		# user path/script loads, GLB materials and internal offsets stay intact.
		var clone := original.duplicate(0) as Node3D
		if clone == null:
			for existing: Node in clones: existing.free()
			return {"ok": false, "error": "Не удалось создать объект"}
		original.get_parent().add_child(clone)
		clone.global_transform = delta * participant.frame
		clone.visible = participant.visible
		clone.set_meta("source_id", id)
		clones.append(clone)
	var record: Dictionary = template.record.duplicate(true)
	record.id = id
	record["template_id"] = template_id
	record.transform = encode_transform(frame)
	var root: Node3D = clones.pop_front()
	var result := register_object(id, root, record, clones)
	if not result.ok:
		root.free()
		for clone: Node in clones: clone.free()
		return result
	return {"ok": true, "record": record}
