extends SceneTree
const Registry = preload("res://scripts/map_editor/object_registry.gd")
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var house := Node3D.new()
	world.add_child(house)
	house.position = Vector3(4, 0, 3)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	house.add_child(mesh)
	var collision := StaticBody3D.new()
	world.add_child(collision)
	collision.position = Vector3(4, 0, 3)
	collision.collision_layer = 7
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	collision.add_child(shape)
	var registry := Registry.new()
	check(registry.register_object("house", house, {"kind": "building", "model": "house", "source": {"authority": 4}}, [collision]).ok, "registration")
	check(not registry.register_object("house", house, {}).ok, "duplicate")
	var source: Dictionary = registry.source_document("test")
	var changed := source.duplicate(true)
	changed.objects[0].transform.position = [10, 0, 8]
	check(registry.apply_document(changed).ok, "move")
	check(house.position == Vector3(10, 0, 8) and collision.position == house.position, "detached collider follows")
	check(registry.pick(Vector3(10, 5, 8), Vector3.DOWN) == "house", "pick")
	changed.objects[0].transform.rotation = [0, PI / 2, 0]
	check(registry.apply_document(changed).ok, "rotate")
	check(collision.global_transform.is_equal_approx(house.global_transform), "rotation delta")
	check(registry.apply_document({"objects": []}).ok, "delete")
	check(not house.visible and collision.collision_layer == 0, "delete hides collision")
	check(registry.apply_document(source).ok, "restore")
	check(house.visible and collision.collision_layer == 7 and house.position == Vector3(4, 0, 3), "exact restore")
	changed.objects[0].transform.scale = [0, 1, 1]
	check(not registry.apply_document(changed).ok and house.position == Vector3(4, 0, 3), "invalid atomic")
	check(source.objects[0].source.authority == 4, "opaque preserved")
	var locked := Registry.new()
	check(locked.register_object("locked", house, {}, [], false).ok, "locked register")
	check(not locked.apply_document({"objects": []}).ok and house.visible, "protected")
	world.free()
	print("map registry checks: ", checks)
	quit(0)
