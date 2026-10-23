extends SceneTree
## DSH_CLONEDOOR: coordinate facts for the copy doorway and the geometry the capsule
## probe keeps reporting. Read-only; creates nothing and changes nothing.

const SCENE := "res://scenes/main_city.tscn"
const WAIT_FRAMES := 20000


func _initialize() -> void:
	root.add_child(load(SCENE).instantiate())


func _walk(node: Node, out: Array) -> Array:
	out.append(node)
	for child: Node in node.get_children():
		_walk(child, out)
	return out


func _aabb_of(node: Node) -> String:
	var bounds := AABB()
	var found := false
	for sub: Node in _walk(node, []):
		if sub is VisualInstance3D:
			var vi: VisualInstance3D = sub
			var box: AABB = vi.get_aabb()
			var world: AABB = vi.global_transform * box
			if not found:
				bounds = world
				found = true
			else:
				bounds = bounds.merge(world)
	return str(bounds.position.snappedf(0.01)) + " size " + str(bounds.size.snappedf(0.01)) if found else "no_mesh"


func _frames() -> int:
	return Engine.get_physics_frames()


var _n := 0


func _process(_delta: float) -> bool:
	_n += 1
	if _n > WAIT_FRAMES:
		quit()
		return true
	var scene: Node = root.get_node_or_null("MafioziWalkMigration")
	if scene == null:
		return false
	var clone: Node = scene.get_node_or_null("TownClone_1")
	if clone == null or _n < 40:
		return false
	print("FACTS clone_origin=", str((clone as Node3D).global_position))
	var leaf: Node = clone.get_node_or_null("Palazzo_Destructible/Entrance6")
	if leaf == null:
		print("FACTS no_leaf")
		quit()
		return true
	print("FACTS leaf_global=", str((leaf as Node3D).global_transform.origin.snappedf(0.001)),
		" parent=", str(leaf.get_parent().name), " parent_global=", str((leaf.get_parent() as Node3D).global_transform.origin))
	var sizes: Array = []
	for sub: Node in _walk(leaf, []):
		if sub is CollisionShape3D and (sub as CollisionShape3D).shape is BoxShape3D:
			var cs: CollisionShape3D = sub
			var world := cs.global_transform
			sizes.append({"at": str(world.origin.snappedf(0.001)), "size": str((cs.shape as BoxShape3D).size.snappedf(0.001)), "layer": (cs.get_parent() as CollisionObject3D).collision_layer})
	print("FACTS leaf_shapes=", JSON.stringify(sizes))
	# The bodies the capsule probe keeps reporting.
	for name_now: String in ["@StaticBody3D@11428", "@StaticBody3D@11205"]:
		var node: Node = _walk(scene, []).filter(func(n: Node) -> bool: return str(n.name) == name_now).front() if not _walk(scene, []).filter(func(n: Node) -> bool: return str(n.name) == name_now).is_empty() else null
		if node == null:
			print("FACTS ", name_now, " not_found")
			continue
		print("FACTS ", name_now, " global=", str((node as Node3D).global_transform.origin.snappedf(0.001)),
			" parent=", str(node.get_parent().name), " shape=", str(((node.get_child(0) as CollisionShape3D).shape as BoxShape3D).size) if node.get_child_count() > 0 and node.get_child(0) is CollisionShape3D else "-",
			" layer=", (node as CollisionObject3D).collision_layer)
	var printshop: Node = scene.get_node_or_null("PrintshopInterior")
	if printshop != null:
		print("FACTS printshop_global=", str((printshop as Node3D).global_transform.origin.snappedf(0.001)))
		# Bodies within 5 m of the copy doorway.
		var doorway := Vector3(94.5, 1.57, 3.0)
		var near: Array = []
		for body: Node in _walk(printshop, []):
			if not body is CollisionObject3D:
				continue
			var at: Vector3 = (body as Node3D).global_transform.origin
			var box := AABB()
			var have := false
			for sub2: Node in _walk(body, []):
				if sub2 is CollisionShape3D and (sub2 as CollisionShape3D).shape is BoxShape3D:
					var half: Vector3 = (sub2 as CollisionShape3D).shape.size * 0.5
					var world2: AABB = (sub2 as Node3D).global_transform * AABB(-half, half * 2.0)
					box = world2 if not have else box.merge(world2)
					have = true
			if not have:
				continue
			if box.position.distance_to(doorway) > 12.0 and (box.position + box.size * 0.5).distance_to(doorway) > 12.0:
				continue
			near.append({"name": str(body.name), "aabb_pos": str(box.position.snappedf(0.01)), "aabb_size": str(box.size.snappedf(0.01)), "distance": snappedf(box.position.distance_to(doorway), 0.01)})
		print("FACTS printshop_bodies_near_doorway=", JSON.stringify(near))
	print("FACTS clone_aabb=", _aabb_of(clone))
	quit()
	return true
