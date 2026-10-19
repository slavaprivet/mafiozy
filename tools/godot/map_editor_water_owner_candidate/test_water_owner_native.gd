extends SceneTree
const Guard = preload("res://diagnostic/water_owner_guard.gd")
const Surface = preload("res://scripts/preview_water_surface.gd")
const MaterialFactory = preload("res://scripts/preview_water_material.gd")

class FakeMain extends Node3D:
	var _water_host: RefCounted
	var water_status := "baseline_fallback"

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main := FakeMain.new()
	root.add_child(main)
	var absent: Dictionary = Guard.snapshot(main)
	check(absent.get("ok", false) and not absent.get("present", true), "legitimate fallback water absent")
	main.water_status = "detail_ready"
	check(not Guard.snapshot(main).get("ok", true), "ready status without host refused")
	main._water_host = RefCounted.new()
	check(not Guard.snapshot(main).get("ok", true), "foreign host refused before property dereference")
	var host: RefCounted = Surface.new()
	main._water_host = host
	check(not Guard.snapshot(main).get("ok", true), "unbuilt host refused")
	var factory: RefCounted = MaterialFactory.new()
	var instance := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, factory.material_for(Vector3.ZERO, true))
	instance.mesh = mesh
	main.add_child(instance)
	host._factory = factory
	host._instance = instance
	host._built = true
	var original: Dictionary = Guard.snapshot(main)
	check(original.get("ok", false) and original.get("present", false), "live exact owner admitted")
	var other_factory: RefCounted = MaterialFactory.new()
	other_factory.material_for(Vector3.ZERO, true)
	host._factory = other_factory
	var changed: Dictionary = Guard.snapshot(main)
	check(changed != original, "factory replacement changes receipt or faults")
	host._factory = factory
	factory.dispose()
	check(not Guard.snapshot(main).get("ok", true), "disposed factory refused")
	host.dispose()
	check(not Guard.snapshot(main).get("ok", true), "disposed host with null factory refused safely")
	main._water_host = null
	check(not Guard.snapshot(main).get("ok", true), "removed detail-ready host refused")
	main.free()
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"water owner native negative fixture; no map or LIVE"}))
	quit(0 if failures.is_empty() else 1)
