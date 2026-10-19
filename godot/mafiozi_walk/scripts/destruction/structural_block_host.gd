extends Node3D
## Structural support for destructible masonry/props.
##
## Blocks hold themselves up while a block below them survives.  Removing a
## load-bearing block makes every block above it unsupported; the owner then
## turns those blocks into physical falling debris instead of silently deleting
## them.  This is deliberately generic: the fort and, later, the hull and castle
## can register their own panels without changing their damage code.

var _blocks: Array[Dictionary] = []
var _owner: Node3D
var _next_id := 0

func configure(owner_in: Node3D) -> void:
	_owner = owner_in

func add_block(node: Node3D, body: StaticBody3D, size: Vector3, hp: float,
		is_base: bool) -> int:
	var id := _next_id
	_next_id += 1
	_blocks.append({
		"id": id, "node": node, "body": body, "size": size,
		"hp": hp, "base": is_base, "alive": true,
	})
	return id

func apply_hit(point: Vector3, damage: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for block: Dictionary in _blocks:
		if not bool(block.get("alive", false)):
			continue
		var node: Node3D = block.get("node")
		if not is_instance_valid(node):
			continue
		var d := _distance_to_box(point, node.global_position, block.get("size"))
		if d < best_d:
			best = block
			best_d = d
	if best.is_empty():
		return {"ok": false, "reason": "no_block"}
	best["hp"] = float(best.get("hp", 30.0)) - damage
	if float(best["hp"]) <= 0.0:
		_destroy(best, true)
		_resolve_support()
		return {"ok": true, "zone": "structure", "destroyed": true,
			"hp": 0.0, "damage": damage}
	return {"ok": true, "zone": "structure", "destroyed": false,
		"hp": best["hp"], "damage": damage}

func _distance_to_box(point: Vector3, center: Vector3, size: Variant) -> float:
	if not size is Vector3:
		return point.distance_to(center)
	var half := (size as Vector3) * 0.5
	var clamped := Vector3(
		clampf(point.x, center.x - half.x, center.x + half.x),
		clampf(point.y, center.y - half.y, center.y + half.y),
		clampf(point.z, center.z - half.z, center.z + half.z))
	return point.distance_to(clamped)

func _destroy(block: Dictionary, spawn_panel: bool) -> void:
	if not bool(block.get("alive", false)):
		return
	block["alive"] = false
	var node: Node3D = block.get("node")
	var body: StaticBody3D = block.get("body")
	if is_instance_valid(node):
		if is_instance_valid(_owner) and _owner.has_method("_spawn_falling_panel"):
			_owner.call("_spawn_falling_panel", node.global_transform, block.get("size"))
		node.visible = false
	if is_instance_valid(body):
		body.collision_layer = 0
		body.collision_mask = 0

func _resolve_support() -> void:
	var alive: Array[Dictionary] = []
	for block: Dictionary in _blocks:
		if bool(block.get("alive", false)):
			alive.append(block)
	# Process bottom-up: a block is supported only by a surviving block directly
	# under it (horizontal overlap, vertical contact).  Side neighbours are not
	# load-bearing.
	alive.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["node"] as Node3D).global_position.y < (b["node"] as Node3D).global_position.y)
	var supported: Array[Dictionary] = []
	for block: Dictionary in alive:
		if bool(block.get("base", false)):
			supported.append(block)
			continue
		var node: Node3D = block.get("node")
		var center := node.global_position
		var size: Vector3 = block.get("size", Vector3.ONE)
		var bottom := center.y - size.y * 0.5
		var found := false
		for lower: Dictionary in supported:
			var lower_node: Node3D = lower.get("node")
			var lcenter := lower_node.global_position
			var lsize: Vector3 = lower.get("size", Vector3.ONE)
			if absf(lcenter.x - center.x) > (lsize.x + size.x) * 0.5 - 0.05:
				continue
			if absf(lcenter.z - center.z) > (lsize.z + size.z) * 0.5 - 0.05:
				continue
			var lower_top := lcenter.y + lsize.y * 0.5
			if absf(lower_top - bottom) <= 0.40:
				found = true
				break
		if found:
			supported.append(block)
		else:
			_destroy(block, true)
