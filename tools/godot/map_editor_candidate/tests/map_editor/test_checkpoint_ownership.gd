extends SceneTree
const Registry = preload("res://scripts/map_editor/object_registry.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var object := MeshInstance3D.new()
	object.mesh = BoxMesh.new()
	world.add_child(object)
	var body := StaticBody3D.new()
	body.collision_layer = 5
	object.add_child(body)
	var index := Registry.new()
	check(index.register_object("house", object, {"kind": "building", "model": "house"}).ok, "object registered")
	var snapshot := index.capture_install_checkpoint()
	check(snapshot.ok, "current source scene ownership captured")
	var other := Node3D.new()
	world.add_child(other)
	object.reparent(other)
	object.position = Vector3(20, 0, 0)
	var changed := object.global_transform
	check(not index.restore_install_checkpoint(snapshot).ok and object.global_transform == changed, "reparented dependency must not be modified under old owner")
	object.reparent(world)
	check(index.restore_install_checkpoint(snapshot).ok and object.position == Vector3.ZERO, "owner restored before exact rollback")
	object.remove_child(body)
	check(not index.restore_install_checkpoint(snapshot).ok, "live but detached collider refuses rollback")
	check(not index.capture_install_checkpoint().ok, "live but detached collider refuses checkpoint")
	object.add_child(body)
	body.collision_layer = 0
	check(index.restore_install_checkpoint(snapshot).ok and body.collision_layer == 5, "reattached collider exact filters restored")
	world.free()
	for failure: String in failures: push_error(failure)
	print("checkpoint ownership: ", checks, " checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
