extends SceneTree
## Visual/physics budget checks for battlefield props. Can install the field standalone
## until main.gd owns it; after integration uses the existing preview_battlefield.

var _scene: Node
var _castle: Node3D
var _battlefield: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _has_property(object: Object, name: String) -> bool:
	for item: Dictionary in object.get_property_list():
		if String(item.get("name", "")) == name:
			return true
	return false

func _install_if_needed() -> bool:
	if _has_property(_scene, "preview_battlefield"):
		_battlefield = _scene.get("preview_battlefield") as Node3D
	if _battlefield != null:
		return true
	var script: GDScript = load("res://scripts/city/battlefield_site.gd") as GDScript
	if script == null:
		return false
	_battlefield = script.new() as Node3D
	if _battlefield == null:
		return false
	_castle.add_child(_battlefield)
	var result: Dictionary = _battlefield.call("install", _scene, _castle)
	if not bool(result.get("ok", true)):
		print("BATTLEFIELD_GEOMETRY_SITE_FAIL ", JSON.stringify(result))
		return false
	var props_script: GDScript = load("res://scripts/city/battlefield_props.gd") as GDScript
	if props_script != null:
		var props: Node3D = props_script.new() as Node3D
		if props != null:
			_battlefield.add_child(props)
			var props_result: Dictionary = props.call("install", _castle)
			if not bool(props_result.get("ok", true)):
				print("BATTLEFIELD_GEOMETRY_PROPS_FAIL ", JSON.stringify(props_result))
				return false
	return true

func _world_bounds(node: MeshInstance3D) -> AABB:
	var bounds := node.get_aabb()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for x: int in 2:
		for y: int in 2:
			for z: int in 2:
				var local := bounds.position + bounds.size * Vector3(float(x), float(y), float(z))
				var world := node.global_transform * local
				low = low.min(world)
				high = high.max(world)
	return AABB(low, high - low)

func _over_road(at: Vector3, margin: float = 0.0) -> bool:
	var local := at - _castle.global_position
	return absf(local.x) <= 4.5 + margin and local.z >= 82.0 - margin \
		and local.z <= 244.0 + margin and local.y > 0.025

func _body_has_shape(node: CollisionObject3D) -> bool:
	if (node.collision_layer & 1) == 0:
		return false
	for child: Node in node.get_children():
		if child is CollisionShape3D:
			var shape := child as CollisionShape3D
			if not shape.disabled and shape.shape != null:
				return true
	return false

func _cover_has_collision(node: Node) -> bool:
	if node is CollisionObject3D and _body_has_shape(node as CollisionObject3D):
		return true
	for child: Node in node.find_children("*", "CollisionObject3D", true, false):
		if child is CollisionObject3D and _body_has_shape(child as CollisionObject3D):
			return true
	return false

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_GEOMETRY_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_castle = _scene.get("preview_castle") as Node3D
	if _castle == null or not _install_if_needed():
		print("BATTLEFIELD_GEOMETRY_FAIL castle_or_field")
		quit(1)
		return
	for tick: int in 3:
		await physics_frame
	var meshes := 0
	var multi_meshes := 0
	var instances := 0
	var colliders := 0
	var lights := 0
	var grass_on_road: Array[String] = []
	var cover_without_collision: Array[String] = []
	var cover_count := 0
	var first_cover: CollisionObject3D
	for node: Node in _battlefield.find_children("*", "", true, false):
		var label: String = String(node.name).to_lower()
		var kind: String = String(node.get_meta("surface_type", node.get_meta("kind", ""))).to_lower()
		var category: String = String(node.get_meta("category", "")).to_lower()
		var is_ground: bool = node.get_meta("surface", "") == "battlefield_ground"
		var grass: bool = String(node.get_meta("vegetation", "")).to_lower() == "grass" or \
			"grass" in label or "tuft" in label or "reed" in label or \
			"vegetation" in kind or category == "vegetation_grass"
		grass = grass and not is_ground
		if node is MultiMeshInstance3D:
			multi_meshes += 1
			var multi := (node as MultiMeshInstance3D).multimesh
			if multi != null:
				var count: int = multi.visible_instance_count
				if count < 0:
					count = multi.instance_count
				instances += count
				if grass:
					for index: int in count:
						var at: Vector3 = (node as Node3D).global_transform * multi.get_instance_transform(index).origin
						if _over_road(at):
							grass_on_road.append("%s[%d] %s" % [node.name, index, at])
		elif node is MeshInstance3D:
			meshes += 1
			if grass:
				var bounds := _world_bounds(node as MeshInstance3D)
				var left := bounds.position - _castle.global_position
				var right := bounds.end - _castle.global_position
				if left.x < 4.5 and right.x > -4.5 and left.z < 244.0 and right.z > 82.0 \
					and right.y > 0.025:
					grass_on_road.append("%s %s" % [node.name, bounds])
		if node is CollisionObject3D and ((node as CollisionObject3D).collision_layer & 1) != 0:
			colliders += 1
		if node is Light3D:
			lights += 1
		if node.get_meta("cover", false) == true or category == "cover":
			cover_count += 1
			if first_cover == null and node is CollisionObject3D:
				first_cover = node as CollisionObject3D
			if not _cover_has_collision(node):
				cover_without_collision.append(String(node.get_path()))
	var break_result := -1
	var cover_released := false
	var props_owner: Node
	for child: Node in _battlefield.find_children("*", "", true, false):
		if child.has_method("apply_damage") and child.has_method("get_stats"):
			props_owner = child
			break
	if first_cover != null and props_owner != null:
		break_result = int(props_owner.call("apply_damage",
			(first_cover as Node3D).global_position, 2.0, 500.0, "stone"))
		for tick: int in 2:
			await physics_frame
		cover_released = not is_instance_valid(first_cover) or (first_cover.collision_layer & 1) == 0
	var passable := grass_on_road.is_empty() and cover_without_collision.is_empty() \
		and meshes <= 1200 and multi_meshes <= 180 and colliders <= 350 and lights <= 12 \
		and cover_count > 0 and break_result > 0 and cover_released
	print("BATTLEFIELD_GEOMETRY ", JSON.stringify({"pass": passable,
		"meshes": meshes, "multimeshes": multi_meshes, "instances": instances,
		"colliders": colliders, "lights": lights, "cover": cover_count,
		"break_result": break_result, "cover_released": cover_released,
		"grass_on_road": grass_on_road.slice(0, 24),
		"grass_on_road_count": grass_on_road.size(),
		"cover_without_collision": cover_without_collision}))
	await create_timer(3.0).timeout
	quit(0 if passable else 1)
