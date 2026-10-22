extends SceneTree
## DSH_CLONEDOOR: temporary read-only probe. Loads the city scene with the
## palazzo-clone flag, waits for the world to report ready and dumps the exact
## runtime shape of the copied door subtree so the swing owner can be written
## against real node names instead of a guess. Creates nothing, changes nothing.

const SCENE := "res://scenes/main_city.tscn"
const WAIT_FRAMES := 2400
var _root: Node
var _frames := 0
var _generation := 0


func _initialize() -> void:
	_root = load(SCENE).instantiate()
	root.add_child(_root)


func _walk(node: Node, out: Array) -> Array:
	out.append(node)
	for child: Node in node.get_children():
		_walk(child, out)
	return out


func _describe(node: Node) -> String:
	var shape := "-"
	var layer := -1
	var disabled := "-"
	var size := "-"
	if node is CollisionObject3D:
		layer = (node as CollisionObject3D).collision_layer
	if node is CollisionShape3D:
		var cs: CollisionShape3D = node as CollisionShape3D
		disabled = str(cs.disabled)
		shape = cs.shape.get_class() if cs.shape != null else "null"
		if cs.shape is BoxShape3D:
			size = str((cs.shape as BoxShape3D).size)
	var t: Transform3D = (node as Node3D).transform if node is Node3D else Transform3D.IDENTITY
	return "%-28s %-22s cls=%-20s layer=%d shape=%s size=%s disabled=%s pos=%s rot_y=%.4f" % [
		str(node.name), str(node.get_path()).left(70), node.get_class(), layer, shape, size, disabled,
		str(t.origin.snappedf(0.001)), t.basis.get_euler().y]


func _dump(node: Node, depth: int) -> void:
	print("PROBE  ", "  ".repeat(depth), _describe(node))
	if depth >= 4:
		return
	for child: Node in node.get_children():
		_dump(child, depth + 1)


func _process(_delta: float) -> bool:
	_frames += 1
	var ready_now: bool = false
	if _root != null and _root.get("preview_ready"):
		ready_now = true
	if ready_now:
		_generation += 1
		if _generation < 6:
			return false
		_report()
		quit()
		return true
	if _frames > WAIT_FRAMES:
		print("PROBE timeout frames=", _frames, " preview_ready=", _root.get("preview_ready"))
		_report()
		quit()
		return true
	return false


func _report() -> void:
	print("=== PROBE BEGIN ===")
	var all: Array = _walk(_root, [])
	print("PROBE nodes total=", all.size())
	var doors: Array = []
	for node: Node in all:
		if str(node.name).to_lower().contains("door"):
			doors.append(node)
	print("PROBE door-named nodes=", doors.size())
	for node: Node in doors:
		print("PROBE DOOR ", _describe(node), " parent=", str(node.get_parent().name), " parent_cls=", node.get_parent().get_class(), " class=", node.get_class())
	# What did the clone copy as its door source?
	for node: Node in all:
		if str(node.name).begins_with("TownClone"):
			var meshes := 0
			var bodies := 0
			for sub: Node in _walk(node, []):
				if sub is MeshInstance3D:
					meshes += 1
				if sub is CollisionObject3D:
					bodies += 1
			print("PROBE CLONE ", node.name, " meshes=", meshes, " collision_objects=", bodies,
				" pos=", str((node as Node3D).position), " children=", node.get_child_count())
			for child: Node in node.get_children():
				var child_meshes := 0
				var child_bodies := 0
				for sub: Node in _walk(child, []):
					if sub is MeshInstance3D:
						child_meshes += 1
					if sub is CollisionObject3D:
						child_bodies += 1
				print("PROBE CLONE_CHILD ", node.name, "/", child.name, " cls=", child.get_class(),
					" meshes=", child_meshes, " bodies=", child_bodies)
	# The real palazzo entrance leaf: what a copied palazzo door leaf looks like.
	var doors2: Array = []
	for node: Node in all:
		if str(node.name).begins_with("Entrance") and node is RigidBody3D:
			doors2.append(node)
	print("PROBE ENTRANCE_LEAVES=", doors2.size())
	for node: Node in doors2:
		var path := str(node.get_path())
		var size := "-"
		if node.has_meta("section_size"):
			size = str(node.get_meta("section_size"))
		var frozen := "-"
		if node is RigidBody3D:
			frozen = str((node as RigidBody3D).freeze)
		var parent_t := Transform3D.IDENTITY
		if node.get_parent() is Node3D:
			parent_t = (node.get_parent() as Node3D).transform
		print("PROBE ENTRANCE ", path.left(110), " layer=", (node as CollisionObject3D).collision_layer,
			" size=", size, " frozen=", frozen, " local_pos=", str((node as Node3D).transform.origin),
			" parent=", str(node.get_parent().name), " parent_local_t=", str(parent_t.origin),
			" children=", node.get_child_count())
		for child: Node in node.get_children():
			print("PROBE ENTRANCE_CHILD ", node.name, "/", child.name, " cls=", child.get_class(),
				" pos=", str((child as Node3D).transform.origin) if child is Node3D else "-")
	# The copied printshop door the current stub uses.
	for node: Node in all:
		if str(node.name) == "SourceDoor_public":
			var sub_bodies: Array = []
			for sub: Node in _walk(node, []):
				if sub is CollisionObject3D:
					sub_bodies.append(sub)
			print("PROBE SOURCEDOOR ", str(node.get_path()).left(110), " cls=", node.get_class(),
				" bodies=", sub_bodies.size(), " transform_origin=", str((node as Node3D).transform.origin),
				" global=", str((node as Node3D).global_transform.origin))
			for body: Node in sub_bodies:
				var shape_desc := "-"
				if body.get_child_count() > 0 and body.get_child(0) is CollisionShape3D:
					var cs: CollisionShape3D = body.get_child(0) as CollisionShape3D
					var sh: Shape3D = cs.shape
					if sh is ConvexPolygonShape3D:
						var pts: PackedVector3Array = (sh as ConvexPolygonShape3D).points
						var bounds := AABB(pts[0], Vector3.ZERO)
						for point: Vector3 in pts:
							bounds = bounds.expand(point)
						shape_desc = "convex size=" + str(bounds.size.snappedf(0.001))
					elif sh is BoxShape3D:
						shape_desc = "box size=" + str((sh as BoxShape3D).size)
				print("PROBE SOURCEDOOR_BODY ", body.name, " cls=", body.get_class(), " layer=", (body as CollisionObject3D).collision_layer, " ", shape_desc)
	# The palazzo host door for comparison.
	var palazzo: Node = _root.get("preview_palazzo")
	if palazzo != null:
		var site: Variant = palazzo.get("site")
		if site != null:
			var door: Variant = site.get("_door")
			print("PROBE PALAZZO_DOOR valid=", is_instance_valid(door), " name=", (str(door.name) if is_instance_valid(door) else "-"),
				" cls=", (door.get_class() if is_instance_valid(door) else "-"),
				" meta_size=", (str(door.get_meta("section_size")) if is_instance_valid(door) else "-"))
			print("PROBE PALAZZO_DOOR_PATH ", (str(door.get_path()) if is_instance_valid(door) else "-"))
			print("PROBE PALAZZO_DOOR_CLOSED ", (str(site.get("_door_closed")) if site.get("_door_closed") != null else "-"))
			print("PROBE PALAZZO_DOOR_HINGE ", str(site.get("_door_hinge")))
			if is_instance_valid(door):
				_dump(door, 0)
	print("PROBE population=", _root.get("preview_population") != null, " player=", is_instance_valid(_root.get("_player")))
	var player: Variant = _root.get("_player")
	if is_instance_valid(player):
		print("PROBE PLAYER_POS ", str(player.global_position))
	print("=== PROBE END ===")
