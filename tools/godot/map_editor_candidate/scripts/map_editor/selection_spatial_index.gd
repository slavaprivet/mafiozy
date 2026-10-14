extends RefCounted
## WORLD-AABB semantics of Composite/ProceduralRegistry, not NativeRegistry's
## local per-mesh narrowphase. Explicit owner revision prevents stale picking.
var _registry: RefCounted
var _revision_gate: Callable
var _revision := -1
var _rows: Array = []
var _nodes: Array = []
var _leaf_by_id := {}
var _order_by_id := {}
var _root := -1
var _next_order := 0
var _stack: Array[int] = []
var last_bounds_tests := 0
var last_error := ""
var _gate_busy := false
func configure(registry: RefCounted, bounds_revision: Callable) -> Dictionary:
	if _registry != null or not registry.has_method("ids") or not registry.has_method("has_object") or not registry.has_method("world_bounds") or not bounds_revision.is_valid(): return {"ok": false, "error": "Trusted registry and bounds revision owner required"}
	_registry = registry
	_revision_gate = bounds_revision
	return rebuild()
func _current_revision() -> int:
	var value: Variant = _revision_receipt()
	return value.revision if value is Dictionary and value.get("ok", false) and value.get("revision") is int and value.revision >= 0 else -1
func _revision_receipt() -> Dictionary:
	if _gate_busy: return {"ok": false}
	_gate_busy = true
	var value: Variant = _revision_gate.call(_revision)
	_gate_busy = false
	return value if value is Dictionary else {"ok": false}
func rebuild() -> Dictionary:
	var revision := _current_revision()
	if revision < 0: return {"ok": false, "error": "Bounds owner admission refused"}
	var rows: Array = []
	var orders := {}
	for id: String in _registry.ids():
		if orders.has(id): return {"ok": false, "error": "Duplicate spatial identity"}
		orders[id] = orders.size()
		var box: Variant = _registry.world_bounds(id)
		if box is AABB: rows.append({"id": id, "box": box, "order": orders[id]})
	if _current_revision() != revision: return {"ok": false, "error": "Bounds changed while building index"}
	_rows = rows
	_order_by_id = orders
	_next_order = orders.size()
	_nodes.clear()
	_leaf_by_id.clear()
	_root = _build(rows, -1) if not rows.is_empty() else -1
	_revision = revision
	last_error = ""
	return {"ok": true, "objects": orders.size(), "leaves": rows.size()}
func _build(rows: Array, parent: int) -> int:
	var index := _nodes.size()
	var box: AABB = rows[0].box
	for i in range(1, rows.size()): box = box.merge(rows[i].box)
	_nodes.append({"box": box, "valid": true, "parent": parent, "left": -1, "right": -1, "id": "", "order": -1})
	if rows.size() == 1:
		_nodes[index].id = rows[0].id
		_nodes[index].order = rows[0].order
		_leaf_by_id[rows[0].id] = index
		return index
	var axis := 0 if box.size.x >= box.size.y and box.size.x >= box.size.z else (1 if box.size.y >= box.size.z else 2)
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return a.box.get_center()[axis] < b.box.get_center()[axis])
	var middle := rows.size() / 2
	_nodes[index].left = _build(rows.slice(0, middle), index)
	_nodes[index].right = _build(rows.slice(middle), index)
	return index
func refresh_ids(changed_ids: Array) -> Dictionary:
	var receipt := _revision_receipt()
	var revision: int = receipt.get("revision", -1) if receipt.get("ok", false) else -1
	if revision < 0: return {"ok": false, "error": "Bounds owner admission refused"}
	if revision != _revision:
		if receipt.get("from_revision") != _revision or not receipt.get("changed_ids") is Array: return {"ok": false, "error": "Owner must issue exhaustive changed-ID receipt since admitted revision"}
		for id: Variant in receipt.changed_ids:
			if not changed_ids.has(id): return {"ok": false, "error": "Targeted refit omits an owner-reported changed ID"}
	var changed := {}
	for id: Variant in changed_ids:
		if not id is String: return {"ok": false, "error": "Invalid changed spatial identity"}
		changed[id] = {"box": _registry.world_bounds(id), "registered": _registry.has_object(id)}
	if _current_revision() != revision: return {"ok": false, "error": "Bounds changed while refitting index"}
	for id: String in changed:
		var row: Dictionary = changed[id]
		if not row.registered: _order_by_id.erase(id)
		elif not _order_by_id.has(id):
			_order_by_id[id] = _next_order
			_next_order += 1
		if not _leaf_by_id.has(id):
			if row.box is AABB: _insert(id, row.box, _order_by_id[id])
			continue
		var leaf: int = _leaf_by_id[id]
		_nodes[leaf].valid = row.box is AABB
		if _nodes[leaf].valid:
			_nodes[leaf].box = row.box
			_nodes[leaf].order = _order_by_id[id]
		_refit(_nodes[leaf].parent)
	_revision = revision
	last_error = ""
	return {"ok": true, "refitted": changed.size()}
func _refit(parent: int) -> void:
	while parent >= 0:
		var a: Dictionary = _nodes[_nodes[parent].left]
		var b: Dictionary = _nodes[_nodes[parent].right]
		_nodes[parent].valid = a.valid or b.valid
		if a.valid: _nodes[parent].box = a.box.merge(b.box) if b.valid else a.box
		elif b.valid: _nodes[parent].box = b.box
		parent = _nodes[parent].parent
static func _area(box: AABB) -> float:
	return box.size.x * box.size.y + box.size.x * box.size.z + box.size.y * box.size.z
func _insert(id: String, box: AABB, order: int) -> void:
	var leaf := _nodes.size()
	_nodes.append({"box": box, "valid": true, "parent": -1, "left": -1, "right": -1, "id": id, "order": order})
	_leaf_by_id[id] = leaf
	if _root < 0:
		_root = leaf
		return
	var sibling := _root
	while _nodes[sibling].left >= 0:
		var left: int = _nodes[sibling].left
		var right: int = _nodes[sibling].right
		var a: Dictionary = _nodes[left]
		var b: Dictionary = _nodes[right]
		var cost_a: float = _area(a.box.merge(box)) - _area(a.box) if a.valid else -1.0
		var cost_b: float = _area(b.box.merge(box)) - _area(b.box) if b.valid else -1.0
		sibling = left if cost_a <= cost_b else right
	var old_parent: int = _nodes[sibling].parent
	var parent := _nodes.size()
	_nodes.append({"box": box.merge(_nodes[sibling].box), "valid": true, "parent": old_parent, "left": sibling, "right": leaf, "id": "", "order": -1})
	_nodes[sibling].parent = parent
	_nodes[leaf].parent = parent
	if old_parent < 0: _root = parent
	elif _nodes[old_parent].left == sibling: _nodes[old_parent].left = parent
	else: _nodes[old_parent].right = parent
	_refit(parent)
func pick_result(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> Dictionary:
	last_bounds_tests = 0
	if _registry == null or _current_revision() != _revision:
		last_error = "Spatial source revision is stale; owner must refresh/rebuild"
		return {"ok": false, "error": last_error}
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(distance) or distance <= 0: return {"ok": true, "id": ""}
	var end := origin + direction.normalized() * distance
	var nearest := distance
	var selected := ""
	var selected_order := 2147483647
	_stack.clear()
	if _root >= 0: _stack.append(_root)
	while not _stack.is_empty():
		var node: Dictionary = _nodes[_stack.pop_back()]
		if not node.valid: continue
		last_bounds_tests += 1
		var hit: Variant = (node.box as AABB).intersects_segment(origin, end)
		if not hit is Vector3: continue
		if node.left >= 0:
			_stack.append(node.right)
			_stack.append(node.left)
			continue
		var length := origin.distance_to(hit)
		if length < nearest or (not selected.is_empty() and length == nearest and node.order < selected_order):
			nearest = length
			selected = node.id
			selected_order = node.order
	last_error = ""
	return {"ok": true, "id": selected}
func pick(origin: Vector3, direction: Vector3, distance: float = 10000.0) -> String:
	return pick_result(origin, direction, distance).get("id", "")
